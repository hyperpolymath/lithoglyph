;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Current project state

(define state
  '((metadata
     (version "1.0")
     (schema-version "1.0")
     (created "2026-02-04")
     (updated "2026-02-05")
     (project "lithoglyph")
     (repo "hyperpolymath/lithoglyph")
     (formerly "formbd"))

    (project-context
     (name "Lithoglyph")
     (tagline "Stone-carved data for the ages: narrative-first, reversible, audit-grade database")
     (tech-stack
      (storage "Forth")
      (bridge "Zig")
      (runtime "Factor")
      (normalizer "Factor + Lean 4")
      (control-plane "Elixir (optional)")))

    (current-position
     (phase "production-hardening")
     (overall-completion 75)
     (components
      ((name "Form.Blocks")
       (completion 100)
       (status "complete")
       (files "core-forth/src/formbd-blocks.fs")
       (notes "348 lines, fixed-size blocks, CRC32C checksums"))

      ((name "Form.Journal")
       (completion 100)
       (status "complete")
       (files "core-forth/src/formbd-journal.fs")
       (notes "370 lines, append-only, sequence numbers, crash recovery"))

      ((name "Form.Model")
       (completion 100)
       (status "complete")
       (files "core-forth/src/formbd-model.fs")
       (notes "297 lines, documents, edges, schemas, constraints"))

      ((name "Form.Bridge")
       (completion 100)
       (status "complete")
       (files "core-zig/src/bridge.zig")
       (notes "Zig-only ABI, C-compatible, opaque handles"))

      ((name "Form.Runtime")
       (completion 100)
       (status "complete")
       (files "core-factor/fbql/fbql.factor")
       (notes "FQL parser/planner/executor, EXPLAIN, provenance"))

      ((name "Form.Normalizer")
       (completion 100)
       (status "complete")
       (files "normalizer/factor/fd-discovery.factor" "normalizer/lean/FunDep.lean")
       (notes "FD discovery, Lean 4 proofs, 1NF-BCNF"))

      ((name "Multi-Protocol API")
       (completion 100)
       (status "complete")
       (files "api/src/main.zig")
       (notes "HTTP API server with multiple protocol support"))

      ((name "Documentation Suite")
       (completion 100)
       (status "complete")
       (notes "QUICKSTART, VERSIONING, DEPLOYMENT, SECURITY, API-REFERENCE, MIGRATION, OBSERVABILITY, INTEGRATION"))

      ((name "Language Bindings")
       (completion 20)
       (status "in-progress")
       (notes "ReScript and PHP client libraries - NEXT PRIORITY")))

     (working-features
      ("Fixed-size block storage (4 KiB blocks)"
       "Append-only journal with reversibility"
       "Multi-model logical layer (documents, edges, schemas)"
       "FQL query language with EXPLAIN and provenance"
       "Automatic functional dependency discovery"
       "Lean 4 formal proofs for normalization"
       "Multi-protocol API server"
       "Comprehensive documentation suite"
       "Crash recovery and integrity checks"
       "CRC32C checksums"
       "Schema and constraint metadata"
       "Type-encoded normal forms (1NF-BCNF)")))

    (route-to-mvp
     (milestones
      ((milestone-id "m1")
       (name "Core Specifications")
       (status "complete")
       (completion 100)
       (items "formbd.scm" "specs/" "Repository structure"))

      ((milestone-id "m2-m5")
       (name "Forth PoC Implementation")
       (status "complete")
       (completion 100)
       (items "Form.Blocks" "Form.Journal" "Form.Model"))

      ((milestone-id "m6")
       (name "Machine-Readable Artefacts")
       (status "complete")
       (completion 100))

      ((milestone-id "m7")
       (name "Complete Documentation Suite")
       (status "complete")
       (completion 100))

      ((milestone-id "m8")
       (name "Form.Runtime (FQL Engine)")
       (status "complete")
       (completion 100))

      ((milestone-id "m9")
       (name "Form.Normalizer")
       (status "complete")
       (completion 100))

      ((milestone-id "m10")
       (name "Production Hardening")
       (status "complete")
       (completion 100))

      ((milestone-id "m11")
       (name "Multi-Protocol API Server")
       (status "complete")
       (completion 100))

      ((milestone-id "m12")
       (name "Language Bindings")
       (status "in-progress")
       (completion 20)
       (items "ReScript client" "PHP client"))))

    (blockers-and-issues
     (critical ())
     (high ())
     (medium
      ("Language bindings need completion (ReScript, PHP)"))
     (low
      ("CMS integration (WordPress) future phase"
       "Form.ControlPlane (clustering) future phase")))

    (critical-next-actions
     (immediate
      ("Complete ReScript client library"
       "Complete PHP client library"
       "Update all references formbd → lithoglyph"))
     (this-week
      ("Test language bindings with API server"
       "Update related repos (formbase, analytics, geo, etc.)"))
     (this-month
      ("Begin CMS integration (WordPress) planning"
       "Plan Form.ControlPlane clustering architecture")))))
