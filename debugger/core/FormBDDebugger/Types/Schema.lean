-- SPDX-License-Identifier: AGPL-3.0-or-later
/-!
# Database Schema Types

Dependent types encoding database schema structure with constraints.
-/

namespace FormBDDebugger.Types

/-- Database column data types -/
inductive DataType where
  | int : DataType
  | text : DataType
  | bool : DataType
  | timestamp : DataType
  | uuid : DataType
  | json : DataType
  | bytes : DataType
  deriving Repr, DecidableEq

/-- A column with its type and nullability -/
structure Column where
  name : String
  dtype : DataType
  nullable : Bool := true
  deriving Repr, DecidableEq

/-- A table with its columns -/
structure Table where
  name : String
  columns : List Column
  primaryKey : List String  -- Column names forming the primary key
  deriving Repr

/-- A database schema with dependent types encoding constraints -/
structure Schema where
  name : String
  tables : List Table
  deriving Repr

/-- Check if a column exists in a table -/
def Table.hasColumn (t : Table) (colName : String) : Bool :=
  t.columns.any (fun c => c.name == colName)

/-- Check if a table exists in a schema -/
def Schema.hasTable (s : Schema) (tableName : String) : Bool :=
  s.tables.any (fun t => t.name == tableName)

/-- Get a table by name -/
def Schema.getTable (s : Schema) (tableName : String) : Option Table :=
  s.tables.find? (fun t => t.name == tableName)

end FormBDDebugger.Types
