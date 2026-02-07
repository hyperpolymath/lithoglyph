;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025 hyperpolymath
;;
;; STATE.scm - Project state tracking for FormBD
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.0.6")
    (schema-version "1.0.0")
    (created "2026-02-01")
    (updated "2026-02-01")
    (project "FormBD")
    (repo "https://github.com/hyperpolymath/lithoglyph"))

  (project-context
    (name "FormBD: Narrative-First, Reversible, Audit-Grade Database")
    (tagline "The database where the database is part of the story")
    (naming-note "Temporary name - Google owns 'FormDB' trademark. Rename before v1.0.0")
    (tech-stack
      (storage-layer "Forth" "Form.Blocks + Form.Model")
      (bridge-layer "Zig" "Form.Bridge - Zig-only ABI, no C dependency")
      (runtime-layer "Factor" "Form.Runtime - FQL parser/planner/executor")
      (normalizer-layer "Factor + Lean 4" "Form.Normalizer - FD discovery with proofs")
      (control-plane "Elixir/OTP" "Form.ControlPlane - clustering, supervision")
      (query-language "FBQLdt" "github.com/hyperpolymath/fbql-dt - dependently-typed")
      (config "Nickel")
      (containers "Podman/Nerdctl")))

  (current-position
    (phase "http-api-integration")
    (overall-completion 85)
    (components
      (form-blocks
        (status complete)
        (completion 100)
        (version "v0.0.2")
        (files
          "core-forth/src/lithoglyph-blocks.fs"
          "core-forth/test/test-blocks.fs"
          "spec/blocks.adoc"))
      (form-journal
        (status complete)
        (completion 100)
        (version "v0.0.2")
        (files
          "core-forth/src/lithoglyph-journal.fs"
          "spec/journal.adoc"))
      (form-model
        (status complete)
        (completion 100)
        (version "v0.0.2")
        (files
          "core-forth/src/lithoglyph-model.fs"
          "spec/encoding.adoc"))
      (form-blocks-zig
        (status complete)
        (completion 100)
        (version "v0.0.7-phase1")
        (description "Industrial-grade Zig block I/O layer - Phase 1")
        (files
          "core-zig/src/blocks.zig"
          "core-zig/test_install_blocks.sh"
          "core-zig/test-execution.sh")
        (features
          "4 KiB block storage with 64-byte headers"
          "CRC32C checksums (Castagnoli polynomial)"
          "Block types: document, edge, journal, schema, superblock"
          "Superblock management and persistence"
          "Journal append with linkage"
          "9/9 tests passing"))
      (form-bridge
        (status complete)
        (completion 100)
        (version "v0.0.7-phase2")
        (description "C ABI bridge wired to persistent BlockStorage - Phase 2")
        (files
          "core-zig/src/bridge.zig"
          "core-zig/test-install.sh")
        (features
          "Persistent block storage (no more in-memory stubs)"
          "JSON introspection (CBOR removed)"
          "Zig 0.15.2 compatible"
          "12/12 tests passing"
          "End-to-end execution test verified"))
      (factor-ffi-bindings
        (status complete)
        (completion 100)
        (version "v0.0.7-phase3")
        (description "Factor FFI bindings to Zig bridge - Phase 3 COMPLETE")
        (files
          "core-factor/gql/storage-backend.factor"
          "core-factor/test-ffi.factor"
          "core-factor/minimal-ffi-test.factor"
          "core-zig/test-version-only.c"
          "core-zig/test-db-open.c"
          "core-zig/test-ffi-integration.c")
        (features
          "FFI library loading (cross-platform)"
          "All 14 bridge functions declared"
          "Helper functions (blob>string, check-fdb-status, with-fdb-error)"
          "Database open/close via FFI - TESTED ✅"
          "Transaction management (begin/commit/abort)"
          "Insert operations with fdb_apply"
          "Schema introspection"
          "Built libbridge.so (2.6MB)")
        (testing-results
          "fdb_version() returns 100 ✅"
          "fdb_db_open() creates BlockStorage ✅"
          "Database handle valid (0x7fa8bffe0000) ✅"
          "fdb_db_close() works without error ✅"
          "Status codes correct (0 = OK) ✅"
          "Error handling works (LgBlob ptr/len) ✅"
          "C integration tests pass ✅"))
      (form-runtime
        (status complete)
        (completion 100)
        (version "v0.0.4")
        (files
          "core-factor/fbql/fbql.factor"
          "core-factor/fbql/storage-backend.factor"
          "core-factor/fbql/benchmarks.factor"
          "core-factor/fbql/seam-tests.factor"
          "spec/fbql.adoc"
          "spec/fbql-philosophy.adoc"))
      (form-normalizer
        (status complete)
        (completion 100)
        (version "v0.0.4")
        (files
          "spec/self-normalizing.adoc"))
      (api-server
        (status complete)
        (completion 100)
        (version "v0.0.5")
        (files
          "api/README.adoc"))
      (language-bindings
        (status in-progress)
        (completion 40)
        (version "v0.0.6")
        (rescript-bindings
          (status in-progress)
          (completion 60)
          (files "clients/rescript/README.md"))
        (php-bindings
          (status in-progress)
          (completion 20)
          (files "clients/php/README.md")))
      (cms-integrations
        (status not-started)
        (completion 0)
        (planned-integrations
          "WordPress/Strapi/Directus/Ghost/Payload"
          "See: integrations/"))
      (control-plane
        (status not-started)
        (completion 0)
        (planned-version "v0.1.0")
        (files "control-plane/README.adoc")))
    (working-features
      "Fixed-size block storage (4 KiB blocks)"
      "Persistent block I/O with CRC32C checksums"
      "Append-only journal with sequence numbering and linkage"
      "Multi-model layer (documents + edges + schemas)"
      "Zig FFI bridge with persistent BlockStorage backend"
      "C-compatible ABI (callconv .c)"
      "FQL parser and executor in Factor"
      "Self-normalizing database with FD discovery"
      "Multi-protocol API server"
      "End-to-end block allocation, write, read, journal tested"))

  (route-to-mvp
    (target-version "1.0.0")
    (definition "Production-ready narrative database with clustering and full ecosystem")

    (milestones
      (milestone-1
        (name "Core Specifications")
        (status complete)
        (completed-date "2025")
        (version "v0.0.2")
        (items
          (item "lithoglyph.scm unified specification" status: complete)
          (item "spec/blocks.adoc" status: complete)
          (item "spec/journal.adoc" status: complete)
          (item "spec/fbql.adoc" status: complete)
          (item "spec/fbql-dependent-types.md" status: complete)
          (item "spec/self-normalizing.adoc" status: complete)
          (item "spec/cloud-storage.adoc" status: complete)
          (item "spec/fbql-philosophy.adoc" status: complete)))

      (milestone-2-5
        (name "Forth PoC Implementation")
        (status complete)
        (completed-date "2025")
        (version "v0.0.2")
        (items
          (item "Form.Blocks - Fixed-size blocks with headers" status: complete)
          (item "Form.Journal - Append-only with crash recovery" status: complete)
          (item "Form.Model - Multi-model layer" status: complete)
          (item "Form.Bridge - Zig-only ABI" status: complete)))

      (milestone-6
        (name "Machine-Readable Artefacts")
        (status complete)
        (completed-date "2025")
        (version "v0.0.2"))

      (milestone-7
        (name "Complete Documentation Suite")
        (status complete)
        (completed-date "2025")
        (version "v0.0.3"))

      (milestone-8
        (name "Form.Runtime (FQL Engine)")
        (status complete)
        (completed-date "2025")
        (version "v0.0.4")
        (items
          (item "FQL parser in Factor" status: complete)
          (item "Query planner" status: complete)
          (item "Executor with introspection" status: complete)
          (item "Storage backend integration" status: complete)))

      (milestone-9
        (name "Form.Normalizer")
        (status complete)
        (completed-date "2025")
        (version "v0.0.4")
        (items
          (item "FD discovery algorithms (DFD/TANE)" status: complete)
          (item "Self-normalizing database spec" status: complete)))

      (milestone-10
        (name "Production Hardening")
        (status complete)
        (completed-date "2025")
        (version "v0.0.4"))

      (milestone-11
        (name "Multi-Protocol API Server")
        (status complete)
        (completed-date "2025")
        (version "v0.0.5"))

      (milestone-12
        (name "Language Bindings")
        (status in-progress)
        (version "v0.0.6")
        (items
          (item "ReScript bindings" status: in-progress completion: 60)
          (item "PHP bindings" status: in-progress completion: 20)
          (item "SDK generator tooling" status: planned)
          (item "Deno/JavaScript bindings" status: planned)
          (item "Julia bindings" status: planned)))

      (milestone-13
        (name "CMS Integration")
        (status not-started)
        (version "v0.0.7")
        (items
          (item "WordPress plugin/integration" status: planned)
          (item "Strapi integration" status: planned)
          (item "Directus integration" status: planned)
          (item "Ghost integration" status: planned)
          (item "Payload integration" status: planned)))

      (milestone-14
        (name "Form.ControlPlane (Clustering)")
        (status not-started)
        (version "v0.1.0")
        (items
          (item "Elixir/OTP control plane" status: planned)
          (item "Session management" status: planned)
          (item "Cluster coordination" status: planned)
          (item "Port communication with core" status: planned)))

      (milestone-14.5
        (name "Final Branding and Naming")
        (status not-started)
        (version "v0.9.0")
        (description "Choose final production name to replace 'FormBD' (Google owns 'FormDB' trademark)")
        (items
          (item "Trademark search" status: planned)
          (item "Community feedback on name options" status: planned)
          (item "Update all documentation and code" status: planned)
          (item "Update domain names and branding" status: planned)))

      (milestone-15
        (name "1.0.0 Release Candidate")
        (status not-started)
        (version "v1.0.0-rc")
        (items
          (item "Production deployment guide" status: planned)
          (item "Performance benchmarks" status: planned)
          (item "Security audit" status: planned)
          (item "Full test coverage" status: planned)
          (item "Documentation complete" status: planned)))))

  (blockers-and-issues
    (critical
      (issue
        (id "NAMING-001")
        (title "FormBD is temporary name")
        (description "Google owns 'FormDB' trademark. Need final production name before v1.0.0")
        (milestone "M14.5 - Final Branding and Naming")
        (target-version "v0.9.0")))
    (high
      (issue
        (id "INTEGRATION-001")
        (title "FBQLdt integration")
        (description "FormBD needs to integrate with fbql-dt for dependently-typed queries")
        (dependency "github.com/hyperpolymath/fbql-dt M7 (Idris2 ABI) + M8 (Zig FFI)")
        (notes "Wait for fbql-dt to complete Idris2 ABI and Zig FFI layers")))
    (medium
      (issue
        (id "BINDINGS-001")
        (title "Language bindings incomplete")
        (description "ReScript bindings 60% done, PHP bindings 20% done")
        (milestone "M12"))
      (issue
        (id "ABI-FFI-001")
        (title "Verify ABI/FFI Universal Standard compliance")
        (description "Ensure FormBD follows hyperpolymath standard: Idris2 ABI + Zig FFI")
        (status "needs-assessment")
        (notes "Current: Zig bridge exists, but Idris2 ABI layer may be missing")))
    (low ()))

  (lithoglyph-ecosystem
    (reference "ECOSYSTEM.scm")
    (core-repos
      "formbd - Database core (this repo)"
      "fbql-dt - Dependently-typed query language"
      "formbase - Airtable alternative UI"
      "lithoglyph-studio - Admin GUI"
      "lithoglyph-debugger - Proof-carrying recovery tool"
      "lithoglyph-analytics - Analytics layer"
      "lithoglyph-beam - BEAM/Elixir ecosystem integration"
      "lithoglyph-geo - Geospatial extensions"
      "zotero-formbd - Reference manager integration")
    (integration-status
      (fbql-dt "Spec-aligned, implementation pending M7+M8")
      (formbase "Depends on FormBD, needs API bindings")
      (lithoglyph-studio "Planned for M13+")
      (lithoglyph-debugger "Planned for production hardening")))

  (critical-next-actions
    (immediate
      (action "Complete ReScript bindings (M12)")
      (action "Complete PHP bindings (M12)"))
    (this-week
      (action "Create ECOSYSTEM.scm with full ecosystem relationships")
      (action "Assess ABI/FFI Universal Standard compliance")
      (action "Document integration plan with fbql-dt"))
    (this-month
      (action "Start M13 CMS Integration planning")
      (action "Design M14 ControlPlane architecture")
      (action "Brainstorm name options for M14.5")))

  (session-history
    (snapshot
      (date "2026-02-01")
      (session-id "documentation-organization")
      (accomplishments
        "Created STATE.scm for FormBD repo"
        "Added M14.5 milestone for final naming/branding before v1.0.0"
        "Assessed current state: M1-M11 complete, M12 in progress (40%)"
        "Identified critical blocker: FBQLdt integration needs M7+M8 from fbql-dt"
        "Identified medium priority: ABI/FFI standard compliance needs assessment")
      (next-steps
        "Create ECOSYSTEM.scm"
        "Organize documentation per user's plan"
        "Verify ABI/FFI Universal Standard compliance"
        "Update ROADMAP.adoc with M14.5 milestone"))))

;; Helper functions for state queries
(define (get-completion-percentage state)
  (state 'current-position 'overall-completion))

(define (get-blockers state priority)
  (state 'blockers-and-issues priority))

(define (get-milestone state n)
  (state 'route-to-mvp 'milestones (string->symbol (format "milestone-~a" n))))
