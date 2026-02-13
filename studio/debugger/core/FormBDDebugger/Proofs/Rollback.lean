-- SPDX-License-Identifier: PMPL-1.0-or-later
import FormBDDebugger.State.Delta
import FormBDDebugger.State.Transaction
import FormBDDebugger.Proofs.Lossless

/-!
# Rollback/Reversibility Proofs

Proofs that operations are reversible.
-/

namespace FormBDDebugger.Proofs

open FormBDDebugger.State
open FormBDDebugger.Types

/-! ## Operational Delta Type

A simplified delta type for proofs about single operations.
This is distinct from State.Delta which bundles operations with metadata.
-/

/-- An operational delta representing a single reversible operation -/
inductive OpDelta where
  | insert : String → Row → OpDelta
  | delete : String → (Row → Bool) → OpDelta
  | update : String → (Row → Bool) → (Row → Row) → OpDelta

/-! ## Delta Application -/

/-- Apply an operational delta to table data -/
def applyOpDeltaToTableData (td : TableData) (d : OpDelta) : TableData :=
  match d with
  | OpDelta.insert _ row => { td with rows := row :: td.rows }
  | OpDelta.delete _ pred => { td with rows := td.rows.filter (fun r => !pred r) }
  | OpDelta.update _ pred transform =>
    { td with rows := td.rows.map (fun r => if pred r then transform r else r) }

/-- Apply an operational delta to a snapshot -/
def applyOpDelta (s : Snapshot) (d : OpDelta) : Snapshot :=
  let targetTable := match d with
    | OpDelta.insert table _ => table
    | OpDelta.delete table _ => table
    | OpDelta.update table _ _ => table
  { s with
    tables := s.tables.map fun td =>
      if td.tableName == targetTable then applyOpDeltaToTableData td d else td
  }

/-- Apply a list of operational deltas sequentially -/
def applyOpDeltas (s : Snapshot) (ds : List OpDelta) : Snapshot :=
  ds.foldl applyOpDelta s

/-! ## Inverse Operations -/

/-- Compute the inverse of an INSERT (given we know the inserted row) -/
def inverseInsert (tableName : String) (row : Row) : OpDelta :=
  OpDelta.delete tableName (fun r => r == row)

/-- Compute the inverse of a DELETE (given we archived the deleted rows) -/
def inverseDelete (tableName : String) (archivedRows : List Row) : List OpDelta :=
  archivedRows.map (fun r => OpDelta.insert tableName r)

/-! ## Reversibility Structure -/

/-- A proof that an operation is reversible -/
structure ReversibilityProof (original : Snapshot) (delta : OpDelta) : Prop where
  /-- There exists an inverse delta sequence -/
  hasInverse : ∃ inverse : List OpDelta, applyOpDeltas (applyOpDelta original delta) inverse = original
  /-- The inverse can be computed from the delta and original state -/
  inverseComputable : ∃ (f : OpDelta → Snapshot → List OpDelta), ∀ s d, applyOpDeltas (applyOpDelta s d) (f d s) = s

/-! ## Insert Reversibility -/

/-- Theorem: INSERT is reversible via DELETE when row wasn't already present -/
theorem insert_reversible (s : Snapshot) (tableName : String) (row : Row)
    (hNotIn : ¬rowInSnapshot row tableName s) :
    ∃ inverse : List OpDelta, applyOpDeltas (applyOpDelta s (OpDelta.insert tableName row)) inverse = s := by
  -- The inverse is a single DELETE of the inserted row
  exact ⟨[inverseInsert tableName row], sorry⟩ -- Proof requires List.map composition lemmas

/-! ## Recovery Plans -/

/-- A recovery plan is a sequence of operational deltas with proofs -/
structure RecoveryPlan (current target : Snapshot) where
  /-- Steps to transform current to target -/
  steps : List OpDelta
  /-- Archive of any deleted rows for reversibility -/
  archive : Archive
  /-- Proof that steps transform current to target -/
  correctness : applyOpDeltas current steps = target
  /-- Proof that target satisfies all constraints -/
  validity : AllConstraintsSatisfied target
  /-- Proof that the operation is lossless -/
  lossless : LosslessTransformation current target archive

/-- Empty recovery plan (already at target) -/
def RecoveryPlan.identity (s : Snapshot) (hValid : AllConstraintsSatisfied s) : RecoveryPlan s s where
  steps := []
  archive := Archive.empty "" 0
  correctness := by unfold applyOpDeltas; simp only [List.foldl]
  validity := hValid
  lossless := by
    constructor
    · intro tableName row hRow
      left
      exact hRow
    · intro t ht
      simp only [List.mem_map]
      exact ⟨t, ht, rfl⟩

/-! ## Change to OpDelta Conversion -/

/-- Convert a Change to an OpDelta (when possible) -/
def changeToOpDelta : Change → Option OpDelta
  | Change.insertRow table row => some (OpDelta.insert table row)
  | Change.deleteRow table _ => none  -- Need predicate, not row id
  | Change.updateRow _ _ _ => none    -- Complex transformation
  | _ => none  -- Schema changes not supported as OpDelta

/-! ## Transaction Rollback -/

/-- Invert an OpDelta (may require archived data) -/
def invertOpDelta : OpDelta → OpDelta
  | OpDelta.insert table row => OpDelta.delete table (fun r => r == row)
  | OpDelta.delete table _ => OpDelta.insert table []  -- Can't fully invert without archive
  | OpDelta.update table _ _ => OpDelta.update table (fun _ => true) id  -- Identity as placeholder

/-- Theorem: OpDelta insert followed by its inverse restores state -/
theorem opDelta_insert_inverse (s : Snapshot) (tableName : String) (row : Row)
    (hNotIn : ¬rowInSnapshot row tableName s) :
    applyOpDelta (applyOpDelta s (OpDelta.insert tableName row))
                 (invertOpDelta (OpDelta.insert tableName row)) = s := by
  -- The inverse DELETE undoes the INSERT
  sorry -- Proof requires List.map composition and filter lemmas

/-- Theorem: Migration with proven inverse is reversible -/
theorem migration_reversible (before after : Snapshot)
    (migrate : List OpDelta) (inverse : List OpDelta)
    (hForward : applyOpDeltas before migrate = after)
    (hBackward : applyOpDeltas after inverse = before) :
    ∃ inv : List OpDelta, applyOpDeltas (applyOpDeltas before migrate) inv = before :=
  ⟨inverse, hForward ▸ hBackward⟩

end FormBDDebugger.Proofs
