;; STATE.scm - FormDB Project State
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.0.3")
    (schema-version "1.0")
    (created "2026-01-03")
    (updated "2026-01-11")
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
    (phase "specification-complete")
    (overall-completion 15)
    (components
      (Form.Blocks (status "specified") (completion 10))
      (Form.Model (status "not-started") (completion 0))
      (Form.Bridge (status "specified") (completion 10))
      (Form.Runtime (status "specified") (completion 10))
      (Form.ControlPlane (status "deferred") (completion 0)))
    (working-features
      "specification document (formdb.scm)"
      "repository structure"
      "self-normalizing database spec (spec/self-normalizing.adoc)"
      "block storage format spec (spec/blocks.adoc)"
      "journal format spec (spec/journal.adoc)"
      "blob encoding spec (spec/encoding.adoc)"
      "FQL grammar + 10 examples (spec/fql.adoc)"))

  (route-to-mvp
    (milestone (id "M1") (name "Specification Complete")
      (status "complete")
      (items
        (item "Define block header format" (status "complete") (decision "D-BLOCK-HEADER-001"))
        (item "Define journal entry schema" (status "complete") (decision "D-JOURNAL-ENTRY-001"))
        (item "Choose ABI blob encoding" (status "complete") (decision "D-ABI-BLOBS-001"))
        (item "Define FQL PoC grammar" (status "complete") (decision "D-FQL-POC-001"))))
    (milestone (id "M2") (name "Form.Blocks PoC")
      (status "in-progress")
      (items
        (item "Implement fixed-size blocks" (status "pending"))
        (item "Implement append-only journal" (status "pending"))
        (item "Implement crash recovery" (status "pending"))
        (item "Create golden test vectors" (status "pending"))))
    (milestone (id "M3") (name "Form.Model PoC")
      (status "pending")
      (items
        (item "Document collections" (status "pending"))
        (item "Edge collections" (status "pending"))
        (item "Schema metadata" (status "pending"))
        (item "Migration artefacts" (status "pending"))))
    (milestone (id "M4") (name "Form.Bridge ABI")
      (status "pending")
      (items
        (item "Define C ABI surface" (status "pending"))
        (item "Implement Zig wrapper" (status "pending"))
        (item "Create bindings documentation" (status "pending"))))
    (milestone (id "M5") (name "Form.Runtime PoC")
      (status "pending")
      (items
        (item "FQL parser" (status "pending"))
        (item "Query planner" (status "pending"))
        (item "EXPLAIN functionality" (status "pending"))
        (item "Provenance surfaces" (status "pending"))))
    (milestone (id "M6") (name "Form.Normalizer")
      (status "specification")
      (items
        (item "FD discovery algorithm selection" (status "open") (question "Q-NORM-001"))
        (item "Approximate FD policy" (status "open") (question "Q-NORM-002"))
        (item "Denormalization support" (status "open") (question "Q-NORM-003"))
        (item "FQL-dt integration" (status "open") (question "Q-NORM-004"))
        (item "Query rewriting strategy" (status "open") (question "Q-NORM-005"))
        (item "Implement DFD algorithm" (status "pending"))
        (item "DISCOVER DEPENDENCIES command" (status "pending"))
        (item "Type encoding in Lean 4" (status "pending"))
        (item "Normal form predicates" (status "pending"))
        (item "Proposal generation" (status "pending"))
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
        "Project ready for Form.Blocks implementation (M2)"))))
