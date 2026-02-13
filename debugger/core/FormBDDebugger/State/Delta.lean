-- SPDX-License-Identifier: PMPL-1.0-or-later
import FormBDDebugger.Types.Query
import FormBDDebugger.State.Snapshot

/-!
# Database Delta

A delta represents the changes between two snapshots.
-/

namespace FormBDDebugger.State

open FormBDDebugger.Types

/-- A single change to the database -/
inductive Change where
  | insertRow : String → Row → Change          -- table, row
  | deleteRow : String → RowId → Change        -- table, rowId
  | updateRow : String → RowId → Row → Change  -- table, rowId, newRow
  | addColumn : String → Column → Value → Change    -- table, column, default
  | dropColumn : String → String → Change           -- table, columnName
  | addTable : Table → Change
  | dropTable : String → Change
  | addConstraint : Constraint → Change
  | dropConstraint : String → Change
  deriving Repr

/-- A delta between two snapshots -/
structure Delta where
  timestamp : Timestamp
  changes : List Change
  actor : String         -- Who made these changes
  rationale : String     -- Why (Lithoglyph provenance)
  deriving Repr

/-- The inverse of a change (for reversibility proofs) -/
def Change.inverse : Change → Option Change
  | Change.insertRow t row => some (Change.deleteRow t ⟨t, 0⟩)  -- Simplified
  | Change.deleteRow t rid => none  -- Need original row data
  | Change.updateRow t rid newRow => none  -- Need original row data
  | Change.addColumn t col _ => some (Change.dropColumn t col.name)
  | Change.dropColumn _ _ => none  -- Need original column definition
  | Change.addTable t => some (Change.dropTable t.name)
  | Change.dropTable _ => none  -- Need original table definition
  | Change.addConstraint c => none  -- Need constraint name
  | Change.dropConstraint _ => none  -- Need original constraint

/-- Check if a change is reversible -/
def Change.isReversible (c : Change) : Bool :=
  c.inverse.isSome

/-- A delta with captured inverse information -/
structure ReversibleDelta extends Delta where
  inverseChanges : List Change
  -- Proof that applying inverseChanges undoes changes

end FormBDDebugger.State
