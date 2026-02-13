-- SPDX-License-Identifier: PMPL-1.0-or-later
import FormBDDebugger.Types.Schema

/-!
# Query Types

Types for database queries that can be type-checked and verified.
-/

namespace FormBDDebugger.Types

/-- A value in a database row -/
inductive Value where
  | null : Value
  | int : Int → Value
  | text : String → Value
  | bool : Bool → Value
  | timestamp : Nat → Value  -- Unix epoch
  | uuid : String → Value
  | json : String → Value
  | bytes : List UInt8 → Value  -- ByteArray as List for Repr
  deriving Repr, DecidableEq, BEq

/-- A row is a list of column-value pairs -/
def Row := List (String × Value)
  deriving Repr

instance : DecidableEq Row := inferInstanceAs (DecidableEq (List (String × Value)))
instance : BEq Row := inferInstanceAs (BEq (List (String × Value)))

/-- A unique row identifier -/
structure RowId where
  table : String
  id : Nat
  deriving Repr, DecidableEq

/-- Query predicate expressions -/
inductive Predicate where
  | eq : String → Value → Predicate
  | neq : String → Value → Predicate
  | lt : String → Value → Predicate
  | lte : String → Value → Predicate
  | gt : String → Value → Predicate
  | gte : String → Value → Predicate
  | isNull : String → Predicate
  | isNotNull : String → Predicate
  | and : Predicate → Predicate → Predicate
  | or : Predicate → Predicate → Predicate
  | not : Predicate → Predicate
  deriving Repr

/-- A SELECT query -/
structure SelectQuery where
  tables : List String
  columns : List String  -- Empty = all columns
  predicate : Option Predicate
  orderBy : List (String × Bool)  -- (column, ascending)
  limit : Option Nat
  offset : Option Nat
  deriving Repr

/-- An INSERT operation -/
structure InsertOp where
  table : String
  columns : List String
  values : List Value
  deriving Repr

/-- An UPDATE operation -/
structure UpdateOp where
  table : String
  setColumns : List (String × Value)
  predicate : Option Predicate
  deriving Repr

/-- A DELETE operation -/
structure DeleteOp where
  table : String
  predicate : Option Predicate
  deriving Repr

/-- All query/operation types -/
inductive Query where
  | select : SelectQuery → Query
  | insert : InsertOp → Query
  | update : UpdateOp → Query
  | delete : DeleteOp → Query
  deriving Repr

end FormBDDebugger.Types
