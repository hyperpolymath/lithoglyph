# @formdb/rescript

Type-safe ReScript client for FormDB.

## Installation

### With Deno (Recommended)

```bash
# Add to deno.json imports
{
  "imports": {
    "@formdb/rescript": "jsr:@formdb/rescript@0.0.6"
  }
}
```

### With npm (for ReScript projects)

```bash
npm install @formdb/rescript @rescript/core
```

Add to `rescript.json`:

```json
{
  "bs-dependencies": ["@formdb/rescript", "@rescript/core"]
}
```

## Quick Start

```rescript
open FormDB
open FormDB_Types
open FormDB_Query

// Create client
let client = FormDB.make(~baseUrl="http://localhost:8080")

// Or from environment
let client = FormDB.fromEnv() // Uses FORMDB_URL and FORMDB_API_KEY

// Check health
let healthResult = await client->FormDB.health
switch healthResult {
| Ok(h) => Console.log(`Server is ${h.status == Healthy ? "healthy" : "unhealthy"}`)
| Error(e) => Console.error(e.message)
}
```

## Query Examples

### Using Query Builder

```rescript
// Build a SELECT query
let query = FormDB_Query.make()
  ->from("articles")
  ->select(["id", "title", "author"])
  ->whereField("status", Eq, JSON.Encode.string("published"))
  ->whereField("views", Gt, JSON.Encode.int(100))
  ->orderBy("createdAt", ~ascending=false)
  ->limit(10)
  ->withProvenance({
    actor: "editor@news.org",
    rationale: "Daily review of popular articles"
  })

// Execute
let result = await client->FormDB.queryWith(query)
```

### Raw FDQL

```rescript
let result = await client->FormDB.query(
  ~fdql="SELECT * FROM articles WHERE status = \"published\" LIMIT 10",
  ~provenance={
    actor: "editor@news.org",
    rationale: "Daily review"
  }
)

switch result {
| Ok(r) => {
    Console.log(`Found ${Int.toString(r.rowCount)} articles`)
    r.rows->Array.forEach(row => Console.log(row))
  }
| Error(e) => Console.error(e.message)
}
```

### Insert

```rescript
let insert = FormDB_Query.makeInsert()
  ->into("articles")
  ->values(JSON.Encode.object([
    ("title", JSON.Encode.string("Breaking News")),
    ("author", JSON.Encode.string("reporter@news.org")),
    ("content", JSON.Encode.string("...")),
  ]))
  ->insertWithProvenance({
    actor: "reporter@news.org",
    rationale: "New article submission"
  })

let fdql = insert->insertToFdql
let result = await client->FormDB.query(~fdql)
```

### Update

```rescript
let update = FormDB_Query.makeUpdate()
  ->updateCollection("articles")
  ->set("status", JSON.Encode.string("archived"))
  ->updateWhere(Field("createdAt", Lt, JSON.Encode.string("2025-01-01")))
  ->updateWithProvenance({
    actor: "admin@news.org",
    rationale: "Archive old articles"
  })

let fdql = update->updateToFdql
let result = await client->FormDB.query(~fdql)
```

### Delete

```rescript
let delete = FormDB_Query.makeDelete()
  ->deleteFrom("drafts")
  ->deleteWhere(Field("status", Eq, JSON.Encode.string("abandoned")))
  ->deleteWithProvenance({
    actor: "cleanup@news.org",
    rationale: "Remove abandoned drafts"
  })

let fdql = delete->deleteToFdql
let result = await client->FormDB.query(~fdql)
```

## Collection Operations

```rescript
// List collections
let collections = await client->FormDB.listCollections
switch collections {
| Ok(cols) => cols->Array.forEach(c => Console.log(c.name))
| Error(e) => Console.error(e.message)
}

// Create collection
let newCol = await client->FormDB.createCollection(
  ~name="users",
  ~collectionType=Document,
  ~schema=JSON.Encode.object([
    ("type", JSON.Encode.string("object")),
    ("properties", JSON.Encode.object([
      ("email", JSON.Encode.object([("type", JSON.Encode.string("string"))])),
      ("name", JSON.Encode.object([("type", JSON.Encode.string("string"))])),
    ]))
  ])
)

// Get collection
let col = await client->FormDB.getCollection(~name="articles")

// Delete collection
let _ = await client->FormDB.deleteCollection(~name="temp_data")
```

## Journal Operations

```rescript
// Get recent journal entries
let entries = await client->FormDB.getJournal(
  ~since=1000,
  ~limit=50,
  ~collection="articles"
)

switch entries {
| Ok(journal) => {
    journal->Array.forEach(entry => {
      Console.log(`[${Int.toString(entry.seq)}] ${entry.operation} on ${entry.collection->Option.getOr("?")}`)
    })
  }
| Error(e) => Console.error(e.message)
}
```

## Normalization

```rescript
// Discover functional dependencies
let fds = await client->FormDB.discoverDependencies(
  ~collection="orders",
  ~confidence=0.95
)

switch fds {
| Ok(deps) => {
    deps->Array.forEach(fd => {
      let det = fd.determinant->Array.join(", ")
      Console.log(`${det} -> ${fd.dependent} (${fd.confidence})`)
    })
  }
| Error(e) => Console.error(e.message)
}

// Analyze normal form
let analysis = await client->FormDB.analyzeNormalForm(~collection="orders")

switch analysis {
| Ok(a) => {
    Console.log(`Current: ${a.currentForm}, Target: ${a.targetForm}`)
    a.violations->Array.forEach(v => Console.log(`Violation: ${v}`))
    a.recommendations->Array.forEach(r => Console.log(`Recommendation: ${r}`))
  }
| Error(e) => Console.error(e.message)
}
```

## Migration

```rescript
// Start migration to BCNF
let migration = await client->FormDB.startMigration(
  ~collection="orders",
  ~targetForm=BCNF
)

switch migration {
| Ok(m) => {
    Console.log(`Migration ${m.id} started: ${m.narrative}`)

    // When ready, commit
    let _ = await client->FormDB.commitMigration(~migrationId=m.id)
  }
| Error(e) => Console.error(e.message)
}
```

## Authentication

```rescript
// API Key
let client = FormDB.make(
  ~baseUrl="http://localhost:8080",
  ~auth=ApiKey("your-api-key")
)

// Bearer Token (JWT)
let client = FormDB.make(
  ~baseUrl="http://localhost:8080",
  ~auth=Bearer("your-jwt-token")
)

// No auth
let client = FormDB.make(
  ~baseUrl="http://localhost:8080",
  ~auth=NoAuth
)
```

## Filter Expressions

The query builder supports complex filter expressions:

```rescript
// Simple comparison
let filter = Field("status", Eq, JSON.Encode.string("active"))

// AND
let filter = And(
  Field("status", Eq, JSON.Encode.string("active")),
  Field("views", Gt, JSON.Encode.int(100))
)

// OR
let filter = Or(
  Field("priority", Eq, JSON.Encode.string("high")),
  Field("urgent", Eq, JSON.Encode.bool(true))
)

// NOT
let filter = Not(Field("deleted", Eq, JSON.Encode.bool(true)))

// Complex nested
let filter = And(
  Field("status", Eq, JSON.Encode.string("published")),
  Or(
    Field("category", Eq, JSON.Encode.string("news")),
    Field("featured", Eq, JSON.Encode.bool(true))
  )
)

// Use in query
let query = FormDB_Query.make()
  ->from("articles")
  ->where(filter)
```

## Types

All types are exported from `FormDB_Types`:

- `provenance` - Audit trail metadata
- `queryResult` - Query response
- `collection` - Collection metadata
- `journalEntry` - Journal entry
- `functionalDependency` - Discovered FD
- `normalFormAnalysis` - NF analysis result
- `migrationStatus` - Migration state
- `healthResponse` - Health check response
- `apiError` - Error response
- `config` - Client configuration

## Error Handling

All API methods return `Result.t<'a, apiError>`:

```rescript
let result = await client->FormDB.query(~fdql="SELECT * FROM articles")

switch result {
| Ok(data) => // Handle success
| Error({code, message, details}) => {
    Console.error(`Error ${code}: ${message}`)
    // details contains additional error info if available
  }
}
```

## License

AGPL-3.0-or-later
