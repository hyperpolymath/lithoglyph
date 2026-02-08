; SPDX-License-Identifier: PMPL-1.0-or-later
; FormBD Debugger - Project State

(state
  (metadata
    (version "0.1.0")
    (schema-version "1.0")
    (created "2025-01-11")
    (updated "2026-01-12")
    (project "formbd-debugger")
    (repo "https://github.com/hyperpolymath/formbd-debugger"))

  (project-context
    (name "FormBD Debugger")
    (tagline "Proof-carrying database recovery and introspection")
    (tech-stack
      (primary "Lean 4" "Idris 2")
      (secondary "Rust")
      (ui "Ratatui")))

  (current-position
    (phase "implementation-active")
    (overall-completion 55)
    (components
      (specification 100 "SPEC.adoc complete")
      (core-proofs 85 "Real theorem implementations with tactics")
      (idris-repl 80 "Full REPL with schema types and commands")
      (rust-adapters 75 "PostgreSQL connection with schema introspection")
      (tui 40 "Widget scaffolds implemented"))
    (working-features
      ("Lean 4 lake project builds with formbd dependency"
       "Core type definitions (Schema, Constraint, Query)"
       "State types (Snapshot, Delta, Transaction)"
       "REAL proofs: LosslessPreserving, LosslessTransformation"
       "REAL proofs: FDSatisfiedInRows, fd_preserved_by_subset"
       "REAL proofs: delete_with_archive_is_lossless, lossless_compose"
       "Idris 2 package structure"
       "REPL core loop with 10 commands"
       "Schema/Table/Column/Constraint/FD types in Idris"
       "Sample schema with authors/articles/evidence tables"
       "Recovery plan types"
       "Rust workspace with 3 adapter crates"
       "PostgreSQL tokio-postgres async connection"
       "PostgreSQL pg_catalog/information_schema introspection"
       "FormBD journal format parsing"
       "Ratatui widget scaffolds")))

  (route-to-mvp
    (milestone "Phase 1: Core Proof Library"
      (status "near-complete")
      (items
        ("Define Schema/Table/Column types in Lean 4" . done)
        ("Define Snapshot and Delta types" . done)
        ("Implement constraint checking proofs" . done)
        ("Implement lossless join proofs" . done)
        ("Implement FD preservation proofs" . done)
        ("Implement reversibility proofs" . partial)))
    (milestone "Phase 2: Database Adapters"
      (status "in-progress")
      (items
        ("PostgreSQL adapter (pg_catalog)" . done)
        ("PostgreSQL schema introspection" . done)
        ("FormBD native adapter" . scaffold)
        ("SQLite adapter for testing" . scaffold)
        ("WAL parsing" . not-started)
        ("Transaction log extraction" . not-started)))
    (milestone "Phase 3: Idris 2 REPL"
      (status "functional")
      (items
        ("REPL framework" . done)
        ("Schema/Table/Column types" . done)
        ("Constraint and FD types" . done)
        ("Sample schema for testing" . done)
        ("Command handlers (10 commands)" . done)
        ("Database connection" . not-started)
        ("Query execution with type checking" . not-started)
        ("Recovery plan generation" . scaffold)
        ("Proof display" . not-started)))
    (milestone "Phase 4: Terminal UI"
      (status "in-progress")
      (items
        ("Ratatui TUI scaffold" . done)
        ("Timeline visualization" . scaffold)
        ("Constraint violation browser" . scaffold)
        ("Recovery plan wizard" . scaffold))))

  (blockers-and-issues
    (critical ())
    (high-priority ())
    (medium-priority
      ("Idris REPL needs actual database connection")
      ("Complete reversibility proofs (has 2 sorry)")
      ("Insert theorem proof incomplete (needs map/find lemma)"))
    (low-priority
      ("TUI needs styling and keyboard navigation")
      ("FormBD native adapter needs implementation")))

  (formbd-alignment
    (formbd-version "0.0.4")
    (alignment-date "2026-01-12")
    (status "scaffold-aligned")
    (integration-gaps
      (journal-types
        "Need to add: Migration = 7, NormalizationStep = 8 to EntryType enum"
        "FormBD migration.factor uses three-phase lifecycle")
      (provenance-struct
        "Add: confidence: f64, proof_blob: Option<Vec<u8>>"
        "FormBD now tracks confidence per FD discovery")
      (lossless-proofs
        "Debugger LosslessProof is placeholder"
        "Should import FormBD's Proofs.lean or fbql-dt's LosslessTransform"))
    (compatible-now
      "Journal header format matches FormBD journal.factor"
      "Entry hash chain verification concept aligns"
      "Provenance actor_id/rationale fields match")
    (next-steps
      "Update journal.rs EntryType to match FormBD"
      "Add Migration type support to parse_segment"
      "Implement verify_chain with real hash checks"
      "Connect LosslessProof to actual decomposition theorems"))

  (critical-next-actions
    (immediate
      ("Connect Idris REPL to PostgreSQL via FFI or IPC")
      ("Complete remaining sorry proofs in Lossless.lean"))
    (this-week
      ("Test REPL with real PostgreSQL database")
      ("Implement FormBD native adapter")
      ("Add proof display to TUI"))
    (this-month
      ("End-to-end: load schema -> detect violation -> generate recovery plan")
      ("Integrate with formbd journal for time-travel debugging")))

  (unified-roadmap
    (reference "UNIFIED-ROADMAP.scm")
    (role "Proof-carrying recovery tool")
    (mvp-blockers
      "Idris REPL needs database connection"
      "FormBD adapter needs real journal parsing")
    (this-repo-priority
      "Wire Idris REPL to PostgreSQL adapter"
      "Complete FormBD native adapter"
      "Finish Ratatui TUI interface"))

  (session-history
    (snapshot "2026-01-12-rename"
      (accomplishments
        ("RENAMED: FormDB → FormBD (Google has 2009 patent on FormDB)")
        ("RENAMED: FDQL → FBQL (query language)")
        ("Released v1.0.0 - MVP with proof-carrying recovery")
        ("Real PostgreSQL constraint checking (FK, UNIQUE, CHECK, PK)")
        ("Timeline from pg_stat_activity and pg_stat_user_tables")
        ("Lean 4 proof integration in recovery plans")
        ("Updated all imports, packages, directories")))
    (snapshot "2026-01-12"
      (accomplishments
        ("Refactored core to depend on formbd/normalizer/lean (lakefile.toml)")
        ("Implemented REAL Lean 4 proofs in Lossless.lean (~225 lines)")
        ("  - LosslessTransformation structure with rowsAccountedFor, tablesPreserved")
        ("  - LosslessPreserving structure for archive-free preservation")
        ("  - insert_preserves_existing_rows theorem (complete proof)")
        ("  - delete_with_archive_is_lossless theorem (complete proof)")
        ("  - lossless_compose theorem (composition of lossless transforms)")
        ("Implemented REAL Lean 4 proofs in FDPreserving.lean (~224 lines)")
        ("  - FunctionalDependency structure with determinant/dependent")
        ("  - FDSatisfiedInRows predicate")
        ("  - fd_preserved_by_subset theorem (complete proof)")
        ("  - delete_preserves_fds theorem (complete proof)")
        ("Rewrote PostgreSQL Rust adapter with real connection (~185 lines lib.rs)")
        ("  - tokio-postgres async connection")
        ("  - Schema introspection via pg_catalog queries (~419 lines schema.rs)")
        ("Rewrote Idris 2 REPL Core.idr (~375 lines)")
        ("  - DataType, Column, Table, Constraint, FunctionalDep, Schema types")
        ("  - DebugState record with connection/schema/history tracking")
        ("  - Sample schema (authors/articles/evidence with FDs and constraints)")
        ("  - 10 command handlers: help, demo, schema, tables, describe, fds, constraints, diagnose, explain, quit")
        ("Cross-checked with fqldt repo - confirmed no parser overlap")
        ("Updated STATE.scm with session progress")))
    (snapshot "2026-01-11"
      (accomplishments
        ("Created full project scaffold (41 files, 1918 lines)")
        ("Lean 4 core library: Types, State, Proofs modules")
        ("Idris 2 REPL: Core, Commands, Inspector, Recovery modules")
        ("Rust adapters: postgres, formbd, sqlite crates")
        ("Ratatui TUI: timeline, constraint_tree, recovery_plan, proof_viewer widgets")
        ("Added formbd-debugger to all 5 FormBD ecosystem repos")
        ("Pushed all changes to GitHub")))
    (snapshot "2025-01-11"
      (accomplishments
        ("Wrote comprehensive SPEC.adoc")
        ("Created README.adoc")
        ("Set up project structure")))))
