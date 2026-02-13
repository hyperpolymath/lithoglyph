-- SPDX-License-Identifier: PMPL-1.0-or-later
import FormBDDebugger.Types.Schema
import FormBDDebugger.Types.Query
import FormBDDebugger.Types.Constraint

/-!
# Database Snapshot

A snapshot represents the complete state of a database at a point in time.
-/

namespace FormBDDebugger.State

open FormBDDebugger.Types

/-- Table data as a list of rows -/
structure TableData where
  tableName : String
  rows : List Row
  deriving Repr

/-- A timestamp (Unix epoch nanoseconds) -/
abbrev Timestamp := Nat

/-- A snapshot of database state at a point in time -/
structure Snapshot where
  schema : ConstrainedSchema
  timestamp : Timestamp
  tables : List TableData
  -- Invariant: all constraints are satisfied
  deriving Repr

/-- Get the data for a specific table -/
def Snapshot.getTableData (s : Snapshot) (tableName : String) : Option TableData :=
  s.tables.find? (fun td => td.tableName == tableName)

/-- Count total rows across all tables -/
def Snapshot.totalRows (s : Snapshot) : Nat :=
  s.tables.foldl (fun acc td => acc + td.rows.length) 0

/-- Check if a snapshot is empty -/
def Snapshot.isEmpty (s : Snapshot) : Bool :=
  s.tables.all (fun td => td.rows.isEmpty)

/-- A proof that all constraints are satisfied in a snapshot -/
structure AllConstraintsSatisfied (s : Snapshot) : Prop where
  foreignKeysSatisfied : True  -- Placeholder for actual FK verification
  uniquesSatisfied : True      -- Placeholder for uniqueness verification
  checksSatisfied : True       -- Placeholder for check constraint verification
  notNullsSatisfied : True     -- Placeholder for not-null verification

end FormBDDebugger.State
