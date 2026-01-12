;; STATE.scm - FormDB Project State
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.0.3")
    (schema-version "1.0")
    (created "2026-01-03")
    (updated "2026-01-12")
    (project "formdb")
    (repo "github.com/hyperpolymath/formdb"))

  (project-context
    (name "FormDB")
    (tagline "The database where the database is part of the story")
    (tech-stack
      (truth-core "Forth")
      (runtime "Factor")
      (bridge "Zig")
      (control-plane "Elixir/OTP (optional)")))

  (current-position
    (phase "poc-implementation")
    (overall-completion 65)
    (components
      (Form.Blocks (status "implemented") (completion 90))
      (Form.Model (status "implemented") (completion 85))
      (Form.Bridge (status "implemented") (completion 80))
      (Form.Runtime (status "implemented") (completion 70))
      (Form.Normalizer (status "scaffolded") (completion 40))
      (Form.ControlPlane (status "deferred") (completion 0)))
    (working-features
      "specification document (formdb.scm)"
      "repository structure"
      "self-normalizing database spec (spec/self-normalizing.adoc)"
      "block storage format spec (spec/blocks.adoc)"
      "journal format spec (spec/journal.adoc)"
      "blob encoding spec (spec/encoding.adoc)"
      "FDQL grammar + 10 examples (spec/fql.adoc)"
      "Form.Blocks implementation (core-forth/src/blocks.fs)"
      "Journal implementation (core-forth/src/journal.fs)"
      "Form.Model implementation (core-forth/src/model.fs)"
      "Form.Bridge Zig ABI (core-zig/src/bridge.zig)"
      "CBOR encoding (core-zig/src/cbor.zig)"
      "FDQL parser (core-factor/fdql/fdql.factor)"
      "FD discovery scaffolding (normalizer/factor/fd-discovery.factor)"
      "Lean 4 FD types (normalizer/lean/FunDep.lean)"))

  (route-to-mvp
    (milestone (id "M1") (name "Specification Complete")
      (status "complete")
      (items
        (item "Define block header format" (status "complete") (decision "D-BLOCK-HEADER-001"))
        (item "Define journal entry schema" (status "complete") (decision "D-JOURNAL-ENTRY-001"))
        (item "Choose ABI blob encoding" (status "complete") (decision "D-ABI-BLOBS-001"))
        (item "Define FDQL PoC grammar" (status "complete") (decision "D-FQL-POC-001"))))
    (milestone (id "M2") (name "Form.Blocks PoC")
      (status "complete")
      (items
        (item "Implement fixed-size blocks" (status "complete"))
        (item "Implement append-only journal" (status "complete"))
        (item "Implement crash recovery" (status "complete"))
        (item "Create golden test vectors" (status "complete"))))
    (milestone (id "M3") (name "Form.Model PoC")
      (status "complete")
      (items
        (item "Document collections" (status "complete"))
        (item "Edge collections" (status "complete"))
        (item "Schema metadata" (status "complete"))
        (item "Migration artefacts" (status "pending"))))
    (milestone (id "M4") (name "Form.Bridge ABI")
      (status "complete")
      (items
        (item "Define Zig ABI surface" (status "complete"))
        (item "Implement Zig wrapper" (status "complete"))
        (item "CBOR encoding/decoding" (status "complete"))))
    (milestone (id "M5") (name "Form.Runtime PoC")
      (status "complete")
      (items
        (item "FDQL parser" (status "complete"))
        (item "Query planner" (status "partial"))
        (item "EXPLAIN functionality" (status "complete"))
        (item "Provenance surfaces" (status "partial"))))
    (milestone (id "M6") (name "Form.Normalizer")
      (status "scaffolded")
      (items
        (item "FD discovery algorithm selection" (status "open") (question "Q-NORM-001"))
        (item "Approximate FD policy" (status "open") (question "Q-NORM-002"))
        (item "Denormalization support" (status "open") (question "Q-NORM-003"))
        (item "FDQL-dt integration" (status "open") (question "Q-NORM-004"))
        (item "Query rewriting strategy" (status "open") (question "Q-NORM-005"))
        (item "Implement DFD algorithm" (status "scaffolded"))
        (item "DISCOVER DEPENDENCIES command" (status "scaffolded"))
        (item "Type encoding in Lean 4" (status "complete"))
        (item "Normal form predicates" (status "complete"))
        (item "Proposal generation" (status "scaffolded"))
        (item "Narrative templates" (status "pending")))))

  (blockers-and-issues
    (critical)
    (high)
    (medium
      (issue "Need Forth development environment setup"))
    (low))

  (critical-next-actions
    (immediate
      "Set up Forth development environment (gforth)"
      "Create test-vectors/blocks/ golden files")
    (this-week
      "Implement Form.Blocks fixed-size block primitives"
      "Implement basic journal append")
    (this-month
      "Complete Form.Blocks PoC (M2)"
      "Begin Form.Model implementation"))

  (session-history
    (snapshot (date "2026-01-03") (session "initial-setup")
      (accomplishments
        "Created repository"
        "Added formdb.scm specification"
        "Added README.adoc"
        "Set up RSR-compliant structure"))
    (snapshot (date "2026-01-11") (session "self-normalizing-spec")
      (accomplishments
        "Researched self-normalizing database concepts"
        "Created spec/self-normalizing.adoc specification"
        "Defined FD discovery pipeline (OBSERVE→ENCODE→PROVE→PROPOSE→NARRATE→APPLY)"
        "Specified normal form coverage (1NF-BCNF full, 4NF+ partial)"
        "Designed FQL-dt type encoding for functional dependencies"
        "Added Form.Normalizer milestone (M6)"
        "Added 5 open questions (Q-NORM-001 through Q-NORM-005)"))
    (snapshot (date "2026-01-11") (session "core-specifications")
      (accomplishments
        "Created spec/blocks.adoc - 4096-byte blocks, 64-byte header, CRC32C integrity"
        "Created spec/journal.adoc - 48-byte entry header, CBOR payloads, provenance tracking"
        "Created spec/encoding.adoc - CBOR (RFC 8949) with deterministic encoding, FormDB tags 39001-39008"
        "Created spec/fql.adoc - Full EBNF grammar, 10 canonical examples with expected output"
        "Resolved Q-BLOCK-HEADER-001, Q-JOURNAL-ENTRY-001, Q-ABI-BLOBS-001, Q-FQL-POC-001"
        "Added decisions D-BLOCK-HEADER-001 through D-FQL-POC-001 to formdb.scm"
        "Completed Milestone M1 (Specification Complete)"
        "Project ready for Form.Blocks implementation (M2)"))
    (snapshot (date "2026-01-12") (session "integration-testing")
      (accomplishments
        "Set up development environment (gforth in toolbox, Factor 0.102)"
        "Fixed Forth code compatibility with gforth 64-bit"
        "Renamed blocks.fs to formdb-blocks.fs to avoid gforth BLOCKS extension conflict"
        "Fixed CRC32C function (DO/LOOP return stack conflict)"
        "Fixed 32-bit field access (use l!/l@ instead of !/@ for magic, checksum, etc.)"
        "Fixed block-magic/BLOCK-MAGIC naming collision (renamed to blk-magic)"
        "Created test suite for Form.Blocks (17/17 tests passing)"
        "Fixed FQL parser consume-token stack effect"
        "Fixed Lean FunDep.lean (List.join -> List.flatten)"
        "Added working justfile recipes (test-forth, check-forth, check-lean)"))
    (snapshot (date "2026-01-12") (session "fdql-parser-fixes")
      (accomplishments
        "Renamed FQL to FDQL (FormDB Query Language) throughout codebase"
        "Renamed directory core-factor/fql to core-factor/fdql"
        "Fixed peek-token if-empty branch stack effects"
        "Fixed expect-token stack manipulation (was dropping too many items)"
        "Fixed try-consume branch effects to match properly"
        "Fixed argument ordering in :: functions (tokens before keywords)"
        "All 10 FDQL statement types now parse correctly"
        "SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, EXPLAIN, INTROSPECT all working"))))
