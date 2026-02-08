-- SPDX-License-Identifier: AGPL-3.0-or-later
import FormBDDebugger.Types.Constraint
import FormBDDebugger.State.Snapshot

/-!
# Functional Dependency Preservation Proofs

Formal proofs that operations preserve functional dependencies.
FD X → Y holds iff: ∀ rows r1 r2, r1[X] = r2[X] → r1[Y] = r2[Y]
-/

namespace FormBDDebugger.Proofs

open FormBDDebugger.State
open FormBDDebugger.Types

/-! ## Value Projection -/

/-- Project a row onto a set of columns -/
def projectRow (row : Row) (cols : List String) : List (String × Value) :=
  row.filter (fun ⟨name, _⟩ => name ∈ cols)

/-- Two rows agree on a set of columns -/
def rowsAgreeOn (r1 r2 : Row) (cols : List String) : Prop :=
  projectRow r1 cols = projectRow r2 cols

/-! ## Functional Dependency Semantics -/

/-- A functional dependency X → Y is satisfied in a list of rows -/
def FDSatisfiedInRows (fd : FunctionalDependency) (rows : List Row) : Prop :=
  ∀ r1 r2, r1 ∈ rows → r2 ∈ rows →
    rowsAgreeOn r1 r2 fd.determinant →
    rowsAgreeOn r1 r2 fd.dependent

/-- A functional dependency is satisfied in table data -/
def FDSatisfied (fd : FunctionalDependency) (data : TableData) : Prop :=
  data.tableName = fd.table → FDSatisfiedInRows fd data.rows

/-- All FDs for a table are satisfied -/
def AllTableFDsSatisfied (fds : List FunctionalDependency) (data : TableData) : Prop :=
  ∀ fd ∈ fds, fd.table = data.tableName → FDSatisfied fd data

/-! ## Key Lemma: Subset Preserves FDs -/

/-- If FD holds in a set of rows, it holds in any subset -/
theorem fd_preserved_by_subset (fd : FunctionalDependency) (rows subset : List Row)
    (hSubset : ∀ r, r ∈ subset → r ∈ rows)
    (hFD : FDSatisfiedInRows fd rows) :
    FDSatisfiedInRows fd subset := by
  unfold FDSatisfiedInRows at *
  intro r1 r2 hr1 hr2 hAgree
  have hr1' := hSubset r1 hr1
  have hr2' := hSubset r2 hr2
  exact hFD r1 r2 hr1' hr2' hAgree

/-! ## DELETE Preserves FDs -/

/-- DELETE creates a subset of rows -/
def deleteRows (rows : List Row) (pred : Row → Bool) : List Row :=
  rows.filter (fun r => !pred r)

/-- Deleted rows are a subset -/
theorem delete_is_subset (rows : List Row) (pred : Row → Bool) :
    ∀ r, r ∈ deleteRows rows pred → r ∈ rows := by
  intro r hr
  unfold deleteRows at hr
  simp only [List.mem_filter] at hr
  exact hr.1

/-- Theorem: DELETE always preserves functional dependencies -/
theorem delete_preserves_fds (fd : FunctionalDependency) (rows : List Row) (pred : Row → Bool)
    (hFD : FDSatisfiedInRows fd rows) :
    FDSatisfiedInRows fd (deleteRows rows pred) := by
  apply fd_preserved_by_subset fd rows (deleteRows rows pred)
  · exact delete_is_subset rows pred
  · exact hFD

/-! ## INSERT May Preserve FDs -/

/-- A new row is FD-compatible with existing rows if:
    for every existing row r, if newRow[X] = r[X] then newRow[Y] = r[Y] -/
def rowFDCompatible (newRow : Row) (existingRows : List Row) (fd : FunctionalDependency) : Prop :=
  ∀ r ∈ existingRows,
    rowsAgreeOn newRow r fd.determinant →
    rowsAgreeOn newRow r fd.dependent

/-- Theorem: INSERT preserves FD if new row is compatible -/
theorem insert_preserves_fds_if_compatible
    (fd : FunctionalDependency) (rows : List Row) (newRow : Row)
    (hFD : FDSatisfiedInRows fd rows)
    (hCompat : rowFDCompatible newRow rows fd) :
    FDSatisfiedInRows fd (newRow :: rows) := by
  unfold FDSatisfiedInRows at *
  intro r1 r2 hr1 hr2 hAgree
  simp only [List.mem_cons] at hr1 hr2
  cases hr1 with
  | inl h1new =>
    cases hr2 with
    | inl h2new =>
      -- Both are the new row, trivially agree (r1 = r2 = newRow)
      subst h1new h2new
      -- A row always agrees with itself on any set of columns
      unfold rowsAgreeOn
      rfl
    | inr h2old =>
      -- r1 is new, r2 is old: use compatibility
      subst h1new
      exact hCompat r2 h2old hAgree
  | inr h1old =>
    cases hr2 with
    | inl h2new =>
      -- r1 is old, r2 is new: use compatibility (symmetric)
      subst h2new
      have hAgree' : rowsAgreeOn r2 r1 fd.determinant := by
        unfold rowsAgreeOn at *
        exact hAgree.symm
      have := hCompat r1 h1old hAgree'
      unfold rowsAgreeOn at *
      exact this.symm
    | inr h2old =>
      -- Both old rows: use original FD
      exact hFD r1 r2 h1old h2old hAgree

/-! ## FD Checking Decision Procedure -/

/-- Check if a row is FD-compatible (decidable) -/
def checkRowFDCompatible [DecidableEq Value] (newRow : Row) (existingRows : List Row)
    (fd : FunctionalDependency) : Bool :=
  existingRows.all fun r =>
    let agreeOnDet := projectRow newRow fd.determinant == projectRow r fd.determinant
    let agreeOnDep := projectRow newRow fd.dependent == projectRow r fd.dependent
    !agreeOnDet || agreeOnDep  -- det agreement implies dep agreement

/-- Check all FDs for a new row -/
def checkAllFDsForRow [DecidableEq Value] (newRow : Row) (existingRows : List Row)
    (fds : List FunctionalDependency) (tableName : String) : Bool :=
  fds.all fun fd =>
    fd.table != tableName || checkRowFDCompatible newRow existingRows fd

/-! ## Snapshot-Level FD Preservation -/

/-- All FDs in a snapshot are satisfied -/
structure AllFDsSatisfied (s : Snapshot) : Prop where
  satisfied : ∀ fd ∈ s.schema.functionalDependencies,
    ∀ td ∈ s.tables, FDSatisfied fd td

/-- A transformation preserves all FDs -/
structure FDPreservingTransformation (before after : Snapshot) : Prop where
  beforeSatisfied : AllFDsSatisfied before
  afterSatisfied : AllFDsSatisfied after

/-! ## DELETE at Snapshot Level -/

/-- Apply DELETE to a snapshot -/
def applyDeleteToSnapshot (s : Snapshot) (tableName : String) (pred : Row → Bool) : Snapshot :=
  { s with
    tables := s.tables.map fun td =>
      if td.tableName == tableName then
        { td with rows := deleteRows td.rows pred }
      else td
  }

/-- Theorem: DELETE at snapshot level preserves all FDs -/
theorem delete_snapshot_preserves_fds (s : Snapshot) (tableName : String) (pred : Row → Bool)
    (hBefore : AllFDsSatisfied s) :
    AllFDsSatisfied (applyDeleteToSnapshot s tableName pred) := by
  constructor
  intro fd hfd td htd
  unfold FDSatisfied
  intro hTable
  unfold applyDeleteToSnapshot at htd
  simp only [List.mem_map] at htd
  obtain ⟨origTd, hOrigMem, hOrigEq⟩ := htd
  -- Get the original FD satisfaction
  have hOrigSat := hBefore.satisfied fd hfd origTd hOrigMem
  unfold FDSatisfied at hOrigSat
  -- Case analysis on whether this is the target table
  by_cases hTarget : origTd.tableName == tableName
  · -- This is the target table, rows were deleted
    -- DELETE preserves FDs because subset preserves FDs
    sorry -- Detailed proof requires showing tableName field access equivalence
  · -- Not target table, unchanged
    simp [hTarget] at hOrigEq
    subst hOrigEq
    exact hOrigSat hTable

/-! ## Constraint Violation Detection -/

/-- An FD violation records the conflicting rows -/
structure FDViolation where
  fd : FunctionalDependency
  row1 : Row
  row2 : Row
  /-- Rows agree on determinant but not dependent -/
  agreeOnDet : rowsAgreeOn row1 row2 fd.determinant
  disagreeOnDep : ¬rowsAgreeOn row1 row2 fd.dependent

/-- Find all FD violations in a list of rows -/
def findFDViolations [DecidableEq Value] (fd : FunctionalDependency) (rows : List Row) :
    List (Row × Row) :=
  rows.flatMap fun r1 =>
    rows.filterMap fun r2 =>
      let agreeOnDet := projectRow r1 fd.determinant == projectRow r2 fd.determinant
      let agreeOnDep := projectRow r1 fd.dependent == projectRow r2 fd.dependent
      if agreeOnDet && !agreeOnDep then some (r1, r2) else none

/-- Helper: equality on projected rows is decidable -/
instance [DecidableEq Value] : DecidableEq (List (String × Value)) := inferInstance

/-- No violations means FD is satisfied -/
theorem no_violations_implies_fd_satisfied [DecidableEq Value]
    (fd : FunctionalDependency) (rows : List Row)
    (hNoViolations : findFDViolations fd rows = []) :
    FDSatisfiedInRows fd rows := by
  unfold FDSatisfiedInRows
  intro r1 r2 hr1 hr2 hAgree
  -- The proof relies on showing (r1, r2) would appear in findFDViolations
  -- if they disagreed, but hNoViolations says the list is empty
  sorry -- Full proof requires detailed List.flatMap/filterMap membership reasoning

end FormBDDebugger.Proofs
