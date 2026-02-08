-- SPDX-License-Identifier: AGPL-3.0-or-later
||| Data Inspector - Type-safe data introspection
module Inspector.Data

import REPL.Core

||| A row with its provenance information
public export
record ProvenancedRow where
  constructor MkProvenancedRow
  rowId : Nat
  data : List (String, String)  -- (column, value)
  addedBy : String
  addedAt : String
  rationale : String

||| Table data with provenance
public export
record TableInspection where
  constructor MkTableInspection
  tableName : String
  rowCount : Nat
  rows : List ProvenancedRow

||| Inspect table data
public export
inspectTable : String -> Nat -> Nat -> IO TableInspection
inspectTable name offset limit =
  pure $ MkTableInspection name 0 []
