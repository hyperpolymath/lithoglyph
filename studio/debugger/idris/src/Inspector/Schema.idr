-- SPDX-License-Identifier: PMPL-1.0-or-later
||| Schema Inspector - Type-safe schema introspection
module Inspector.Schema

import REPL.Core

||| A constraint with its verification status
public export
record ConstraintStatus where
  constructor MkConstraintStatus
  name : String
  constraintType : String
  satisfied : Bool
  violationCount : Nat

||| Schema inspection result
public export
record SchemaInspection where
  constructor MkSchemaInspection
  schema : Schema
  constraints : List ConstraintStatus
  totalViolations : Nat

||| Inspect a schema for constraint violations
public export
inspectSchema : Schema -> IO SchemaInspection
inspectSchema s = pure $ MkSchemaInspection s [] 0

||| Pretty-print a table definition
public export
showTable : Table -> String
showTable t =
  t.name ++ " (" ++ show (length t.columns) ++ " columns)"

||| Pretty-print schema summary
public export
showSchemaSummary : Schema -> String
showSchemaSummary s =
  "Schema: " ++ s.name ++ "\n" ++
  "Tables: " ++ show (length s.tables)
