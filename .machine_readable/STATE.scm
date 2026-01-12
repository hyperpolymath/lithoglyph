;; SPDX-License-Identifier: PMPL-1.0
;; STATE.scm - Project state for FormDB
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
    (tagline "Narrative-first, reversible, audit-grade database")
    (tech-stack
      (primary "Forth" "Factor" "Zig")
      (specifications "AsciiDoc" "EBNF" "Lean4")
      (future "Gleam" "Elixir/OTP")))

  (current-position
    (phase "Phase 6: Form.Runtime PoC")
    (overall-completion 65)
    (components
      (spec-fql 100 "FQL language specification complete")
      (spec-blocks 100 "Block format specification complete")
      (spec-journal 100 "Journal format specification complete")
      (spec-self-normalizing 100 "Self-normalizing spec complete")
      (spec-fql-dt 100 "FQLdt dependent types spec complete")
      (form-blocks 100 "Forth block storage layer complete")
      (form-journal 100 "Forth journal layer complete")
      (form-model 100 "Forth model layer complete")
      (form-bridge 100 "Zig ABI design complete")
      (documentation 100 "Full docs suite complete")
      (fdql-parser 80 "Factor PEG parser in progress")
      (fdql-planner 0 "Query planner not started")
      (fdql-executor 0 "Executor not started"))
    (working-features
      "Block read/write with CRC32C"
      "Append-only journal with sequence numbers"
      "Document/edge collection storage"
      "Schema metadata storage"
      "FDQL parser (AST generation)"))

  (route-to-mvp
    (milestones
      (m1 "Core Specifications" 100 "v0.0.2" "2026-01-11")
      (m2-m5 "Forth PoC Implementation" 100 "v0.0.2" "2026-01-11")
      (m6 "Machine-Readable Artefacts" 100 "v0.0.2" "2026-01-11")
      (m7 "Complete Documentation Suite" 100 "v0.0.3" "2026-01-12")
      (m8 "Form.Runtime (FQL Engine)" 25 "in-progress" "")
      (m9 "Form.Normalizer" 0 "planned" "")
      (m10 "Production Hardening" 0 "planned" "")))

  (blockers-and-issues
    (critical)
    (high)
    (medium
      "Factor PEG grammar needs testing with edge cases"
      "Query planner architecture not finalized")
    (low
      "Some docs reference planned features with 🚧 markers"))

  (critical-next-actions
    (immediate
      "Complete FDQL parser testing"
      "Design query planner architecture")
    (this-week
      "Implement basic query executor"
      "Add EXPLAIN functionality")
    (this-month
      "Complete Form.Runtime PoC"
      "Provenance output from queries"
      "Seam checks (Parser↔Planner↔Executor)"))

  (session-history
    (session
      (date "2026-01-12")
      (accomplishments
        "Fleshed out docs/API-REFERENCE.adoc"
        "Fleshed out docs/MIGRATION-FROM-RDBMS.adoc"
        "Fleshed out docs/OBSERVABILITY.adoc"
        "Fleshed out docs/INTEGRATION-PATTERNS.adoc"
        "Updated CHANGELOG for v0.0.3"
        "Tagged and released v0.0.3"
        "Created GitHub release"
        "Updated ROADMAP with milestone status"
        "Committed FDQL parser (fql→fdql rename)"))))
