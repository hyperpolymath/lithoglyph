-- SPDX-License-Identifier: AGPL-3.0-or-later
import FormBDDebugger.Types.Schema

/-!
# Database Constraint Types

Types encoding database constraints that can be verified.
-/

namespace FormBDDebugger.Types

/-- Actions on foreign key violation -/
inductive CascadeAction where
  | noAction : CascadeAction
  | cascade : CascadeAction
  | setNull : CascadeAction
  | setDefault : CascadeAction
  | restrict : CascadeAction
  deriving Repr, DecidableEq

/-- A foreign key constraint -/
structure ForeignKey where
  name : String
  sourceTable : String
  sourceColumns : List String
  targetTable : String
  targetColumns : List String
  onDelete : CascadeAction := CascadeAction.noAction
  onUpdate : CascadeAction := CascadeAction.noAction
  deriving Repr

/-- A unique constraint -/
structure UniqueConstraint where
  name : String
  table : String
  columns : List String
  deriving Repr

/-- A check constraint -/
structure CheckConstraint where
  name : String
  table : String
  expression : String  -- SQL expression
  deriving Repr

/-- A not-null constraint -/
structure NotNullConstraint where
  table : String
  column : String
  deriving Repr

/-- All constraint types -/
inductive Constraint where
  | primaryKey : String → String → List String → Constraint
  | foreignKey : ForeignKey → Constraint
  | unique : UniqueConstraint → Constraint
  | check : CheckConstraint → Constraint
  | notNull : NotNullConstraint → Constraint
  deriving Repr

/-- A functional dependency (for normalization proofs) -/
structure FunctionalDependency where
  table : String
  determinant : List String  -- Left side: columns that determine
  dependent : List String    -- Right side: columns that are determined
  deriving Repr

/-- Schema with its constraints -/
structure ConstrainedSchema extends Schema where
  constraints : List Constraint
  functionalDependencies : List FunctionalDependency
  deriving Repr

end FormBDDebugger.Types
