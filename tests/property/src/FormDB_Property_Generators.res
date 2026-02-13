// SPDX-License-Identifier: PMPL-1.0-or-later

/**
 * FormDB Property Test Generators
 *
 * Random value generators for property-based testing
 */

open FormDB_Property_Types

/** Random number generator state */
type rng = {mutable seed: int}

/** Create RNG with seed */
let makeRng = (seed: int): rng => {seed: seed}

/** Generate next random int (LCG algorithm) */
let nextInt = (rng: rng): int => {
  // Linear Congruential Generator
  rng.seed = mod(rng.seed * 1103515245 + 12345, 2147483648)
  rng.seed
}

/** Generate random int in range [min, max) */
let intInRange = (rng: rng, ~min: int, ~max: int): int => {
  let range = max - min
  if range <= 0 {
    min
  } else {
    min + mod(abs(nextInt(rng)), range)
  }
}

/** Generate random float in range [0, 1) */
let float01 = (rng: rng): float => {
  Float.fromInt(abs(nextInt(rng))) /. 2147483648.0
}

/** Generate random bool */
let bool = (rng: rng): bool => {
  mod(nextInt(rng), 2) == 0
}

/** Pick random element from array */
let pick = (rng: rng, arr: array<'a>): option<'a> => {
  let len = Array.length(arr)
  if len == 0 {
    None
  } else {
    Some(arr[intInRange(rng, ~min=0, ~max=len)]->Option.getExn)
  }
}

/** Generate random identifier (valid FDQL identifier) */
let identifier = (rng: rng): string => {
  let prefixes = ["user", "post", "article", "product", "order", "item", "comment", "tag", "category"]
  let suffixes = ["", "s", "_data", "_info", "_record"]
  let prefix = pick(rng, prefixes)->Option.getOr("item")
  let suffix = pick(rng, suffixes)->Option.getOr("")
  prefix ++ suffix
}

/** Generate random field name */
let fieldName = (rng: rng): string => {
  let fields = [
    "id", "name", "title", "description", "content", "status",
    "created_at", "updated_at", "author", "email", "price",
    "quantity", "active", "published", "category_id", "user_id",
  ]
  pick(rng, fields)->Option.getOr("field")
}

/** Generate random string value */
let stringValue = (rng: rng): string => {
  let words = ["hello", "world", "test", "example", "sample", "data", "value"]
  let len = intInRange(rng, ~min=1, ~max=4)
  let result = []
  for _ in 1 to len {
    result->Array.push(pick(rng, words)->Option.getOr("word"))->ignore
  }
  result->Array.join(" ")
}

/** Generate random value type */
let valueType = (rng: rng): valueType => {
  let choice = intInRange(rng, ~min=0, ~max=5)
  switch choice {
  | 0 => StringVal(stringValue(rng))
  | 1 => IntVal(intInRange(rng, ~min=-1000, ~max=1000))
  | 2 => FloatVal(float01(rng) *. 1000.0)
  | 3 => BoolVal(bool(rng))
  | 4 => NullVal
  | _ => StringVal(stringValue(rng))
  }
}

/** Generate random comparison operator */
let compareOp = (rng: rng): compareOp => {
  pick(rng, allCompareOps)->Option.getOr(Eq)
}

/** Generate random WHERE clause */
let whereClause = (rng: rng): string => {
  let field = fieldName(rng)
  let op = compareOp(rng)
  let value = valueType(rng)
  `${field} ${compareOpToString(op)} ${valueToString(value)}`
}

/** Generate random SELECT statement */
let selectStatement = (rng: rng): string => {
  let collection = identifier(rng)
  let numFields = intInRange(rng, ~min=1, ~max=4)
  let fields = []
  for _ in 1 to numFields {
    fields->Array.push(fieldName(rng))->ignore
  }
  let fieldList = fields->Array.join(", ")

  let hasWhere = bool(rng)
  let hasLimit = bool(rng)

  let base = `SELECT ${fieldList} FROM ${collection}`
  let withWhere = hasWhere ? `${base} WHERE ${whereClause(rng)}` : base
  let withLimit = hasLimit
    ? `${withWhere} LIMIT ${Int.toString(intInRange(rng, ~min=1, ~max=100))}`
    : withWhere

  withLimit
}

/** Generate random INSERT statement */
let insertStatement = (rng: rng): string => {
  let collection = identifier(rng)
  let numFields = intInRange(rng, ~min=1, ~max=4)
  let pairs = []
  for _ in 1 to numFields {
    let field = fieldName(rng)
    let value = valueType(rng)
    pairs->Array.push(`"${field}": ${valueToString(value)}`)->ignore
  }
  let document = "{" ++ pairs->Array.join(", ") ++ "}"
  `INSERT INTO ${collection} ${document}`
}

/** Generate random UPDATE statement */
let updateStatement = (rng: rng): string => {
  let collection = identifier(rng)
  let numFields = intInRange(rng, ~min=1, ~max=3)
  let pairs = []
  for _ in 1 to numFields {
    let field = fieldName(rng)
    let value = valueType(rng)
    pairs->Array.push(`"${field}": ${valueToString(value)}`)->ignore
  }
  let setClause = "{" ++ pairs->Array.join(", ") ++ "}"
  `UPDATE ${collection} SET ${setClause} WHERE ${whereClause(rng)}`
}

/** Generate random DELETE statement */
let deleteStatement = (rng: rng): string => {
  let collection = identifier(rng)
  `DELETE FROM ${collection} WHERE ${whereClause(rng)}`
}

/** Generate random CREATE statement */
let createStatement = (rng: rng): string => {
  let collection = identifier(rng)
  let isEdge = bool(rng)
  let collType = isEdge ? "EDGE COLLECTION" : "COLLECTION"
  `CREATE ${collType} ${collection}`
}

/** Generate random DROP statement */
let dropStatement = (rng: rng): string => {
  let collection = identifier(rng)
  `DROP COLLECTION ${collection}`
}

/** Generate random EXPLAIN statement */
let explainStatement = (rng: rng): string => {
  let inner = selectStatement(rng)
  let verbose = bool(rng)
  let analyze = bool(rng)

  let prefix = switch (analyze, verbose) {
  | (true, true) => "EXPLAIN ANALYZE VERBOSE"
  | (true, false) => "EXPLAIN ANALYZE"
  | (false, true) => "EXPLAIN VERBOSE"
  | (false, false) => "EXPLAIN"
  }

  `${prefix} ${inner}`
}

/** Generate random INTROSPECT statement */
let introspectStatement = (rng: rng): string => {
  let targets = ["SCHEMA", "CONSTRAINTS", "COLLECTIONS", "JOURNAL"]
  let target = pick(rng, targets)->Option.getOr("SCHEMA")

  switch target {
  | "SCHEMA" | "CONSTRAINTS" => {
      let collection = identifier(rng)
      `INTROSPECT ${target} ${collection}`
    }
  | _ => `INTROSPECT ${target}`
  }
}

/** Generate random FDQL statement */
let fdqlStatement = (rng: rng): string => {
  let stmtType = pick(rng, allStatementTypes)->Option.getOr(Select)
  switch stmtType {
  | Select => selectStatement(rng)
  | Insert => insertStatement(rng)
  | Update => updateStatement(rng)
  | Delete => deleteStatement(rng)
  | Create => createStatement(rng)
  | Drop => dropStatement(rng)
  | Explain => explainStatement(rng)
  | Introspect => introspectStatement(rng)
  }
}

/** Generate array of random statements */
let fdqlStatements = (rng: rng, count: int): array<string> => {
  let result = []
  for _ in 1 to count {
    result->Array.push(fdqlStatement(rng))->ignore
  }
  result
}
