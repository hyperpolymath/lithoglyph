;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - Project ecosystem position

(ecosystem
 (version "1.0")
 (name "Lithoglyph")
 (formerly "formbd")
 (type "database")
 (purpose "Narrative-first, reversible, audit-grade database core where schemas, constraints, migrations, blocks, and journals are narrative artefacts")

 (position-in-ecosystem
  "Lithoglyph is the foundational database layer for narrative-driven, audit-grade applications. It provides multi-model storage (documents, edges, schemas) with automatic normalization, formal verification, and complete reversibility."

  "Unlike traditional databases that treat structure as opaque infrastructure, Lithoglyph makes the database itself part of the story - every schema change, constraint, migration, block, and journal entry is a narrative artefact that agents and humans can understand."

  "Target domains:"
  "  - Investigative journalism (audit trails, provenance)"
  "  - Governance/compliance (reversible operations, complete history)"
  "  - Agentic ecosystems (agent-understandable schemas and constraints)"
  "  - Long-term cultural/institutional archives (permanence, narrative preservation)")

 (related-projects
  ((project "formbase")
   (relationship "consumer")
   (description "Elixir/Phoenix web server that uses Lithoglyph as storage backend")
   (integration "Elixir NIF bindings to Zig bridge, HTTP API client"))

  ((project "lithoglyph-analytics")
   (formerly "lithoglyph-analytics")
   (relationship "extension")
   (description "Analytics and reporting tools for Lithoglyph databases")
   (integration "Queries Lithoglyph via FQL, provides aggregations and visualizations"))

  ((project "lithoglyph-geo")
   (formerly "lithoglyph-geo")
   (relationship "extension")
   (description "Geospatial extensions for Lithoglyph")
   (integration "Geographic queries and indexing on top of Lithoglyph edge collections"))

  ((project "lithoglyph-beam")
   (formerly "lithoglyph-beam")
   (relationship "runtime-integration")
   (description "BEAM/Elixir native integration")
   (integration "Native Elixir NIFs for Lithoglyph, GenServer wrappers"))

  ((project "lithoglyph-debugger")
   (formerly "lithoglyph-debugger")
   (relationship "tooling")
   (description "Debugging and introspection tools")
   (integration "EXPLAIN visualization, journal replay, provenance tracking"))

  ((project "lithoglyph-studio")
   (formerly "lithoglyph-studio")
   (relationship "tooling")
   (description "GUI/web interface for Lithoglyph management")
   (integration "Schema designer, query builder, journal browser"))

  ((project "fbql-dt")
   (relationship "language-variant")
   (description "FQL with dependent types (Idris2 or Lean)")
   (integration "Type-safe query construction with compile-time verification"))

  ((project "vörðr")
   (relationship "sibling-project")
   (description "Formally verified container orchestration with LSP/MCP integration")
   (integration "Both use Idris2 ABI + Zig FFI pattern, narrative-first philosophy"))

  ((project "svalinn")
   (relationship "sibling-project")
   (description "Gateway for verified container workflows")
   (integration "Both provide MCP servers for LLM/agent integration"))

  ((project "cerro-torre")
   (relationship "sibling-project")
   (description "Ed25519 signing for container bundles")
   (integration "Shared cryptographic verification patterns")))

 (what-this-is
  "Narrative-first database core with formal guarantees"
  "Multi-model storage (documents, edges, schemas, constraints)"
  "Append-only journal with complete reversibility"
  "Automatic functional dependency discovery and normalization"
  "FQL query language with EXPLAIN and provenance tracking"
  "Lean 4 formal proofs for normal form correctness"
  "Zig-only ABI (no C dependency) for FFI"
  "Multi-protocol API server (HTTP, future: gRPC, MCP)"
  "Audit-grade permanence: every operation logged and reversible"
  "Agent-understandable: schemas and constraints as narrative artefacts"
  "Stone-carved metaphor: Forth sculpts data onto disk like carving glyphs in stone")

 (what-this-is-not
  "NOT a key-value store (has rich schema and constraint system)"
  "NOT a graph database exclusively (multi-model: documents + edges + schemas)"
  "NOT a replacement for PostgreSQL/MongoDB (different philosophy, different use cases)"
  "NOT optimized for pure throughput (prioritizes auditability > performance)"
  "NOT a distributed database yet (clustering in Form.ControlPlane, future M14)"
  "NOT a CMS (though lithoglyph-studio provides GUI, not content management)"
  "NOT production-ready for all workloads (M12 in progress: language bindings)"))
