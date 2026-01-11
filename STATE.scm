;; STATE.scm - FormDB Project State
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.0.2")
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
    (phase "conceptual")
    (overall-completion 5)
    (components
      (Form.Blocks (status "not-started") (completion 0))
      (Form.Model (status "not-started") (completion 0))
      (Form.Bridge (status "not-started") (completion 0))
      (Form.Runtime (status "not-started") (completion 0))
      (Form.ControlPlane (status "deferred") (completion 0)))
    (working-features
      "specification document (formdb.scm)"
      "repository structure"
      "self-normalizing database spec (spec/self-normalizing.adoc)"))

  (route-to-mvp
    (milestone (id "M1") (name "Specification Complete")
      (status "in-progress")
      (items
        (item "Define block header format" (status "open") (question "Q-BLOCK-HEADER-001"))
        (item "Define journal entry schema" (status "open") (question "Q-JOURNAL-ENTRY-001"))
        (item "Choose ABI blob encoding" (status "open") (question "Q-ABI-BLOBS-001"))
        (item "Define FQL PoC grammar" (status "open") (question "Q-FQL-POC-001"))))
    (milestone (id "M2") (name "Form.Blocks PoC")
      (status "pending")
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
    (high
      (issue "Open questions need decisions before implementation can begin"))
    (medium)
    (low))

  (critical-next-actions
    (immediate
      "Decide on block header layout (Q-BLOCK-HEADER-001)"
      "Decide on journal entry schema (Q-JOURNAL-ENTRY-001)")
    (this-week
      "Choose ABI blob encoding (Q-ABI-BLOBS-001)"
      "Draft FQL grammar (Q-FQL-POC-001)")
    (this-month
      "Begin Form.Blocks implementation"
      "Create initial test vectors"))

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
        "Added 5 open questions (Q-NORM-001 through Q-NORM-005)"))))
