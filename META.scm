;; SPDX-License-Identifier: PMPL-1.0-or-later
;; META.scm - Meta-level project information

(define meta
  '((architecture-decisions
     ((adr-001
       (status "accepted")
       (date "2026-02-04")
       (context "Initial project setup")
       (decision "Use standard hyperpolymath structure")
       (consequences "Consistent with other hyperpolymath projects"))

      (adr-002
       (status "accepted")
       (date "2026-02-05")
       (context "Project naming: formbd conflicts with Google trademark")
       (decision "Rename project from formbd to Lithoglyph")
       (consequences
        "Lithoglyph = litho (stone) + glyph (carved symbol)"
        "Meaning: Stone-carved data, permanent records"
        "Captures: Forth sculpting data, narrative-first, audit-grade permanence"
        "No trademark conflicts (defunct Lithoglyph Inc. made Mac software 2007-2012)"
        "Package names available: lithoglyph on NPM/PyPI"
        "Domains available: lithoglyph.io, lithoglyph.dev"
        "Avoids 'graph' confusion (glyph ≠ graph database)"
        "Related to: petroglyph (rock carving), stelae (carved stone pillars)"))

      (adr-003
       (status "accepted")
       (date "2025-01")
       (context "Storage layer implementation language choice")
       (decision "Use Forth for Form.Blocks and Form.Model")
       (consequences
        "Forth provides: minimal footprint, direct hardware access, deterministic execution"
        "Perfect for: block-level operations, journaling, crash recovery"
        "Trade-offs: Less familiar to mainstream developers, but ideal for foundational layer"
        "Files: core-forth/src/*.fs (1015 lines total)"))

      (adr-004
       (status "accepted")
       (date "2025-01")
       (context "FFI layer implementation")
       (decision "Use Zig-only ABI (eliminate C dependency)")
       (consequences
        "Zig provides: C-compatible ABI without C toolchain requirement"
        "Benefits: Memory safety, cross-compilation, callconv(.C) for FFI"
        "Simpler build: No C headers, direct Forth ↔ Zig ↔ Factor integration"
        "Location: core-zig/src/bridge.zig"))

      (adr-005
       (status "accepted")
       (date "2025-01")
       (context "Query language and runtime implementation")
       (decision "Use Factor for FQL parser/planner/executor")
       (consequences
        "Factor provides: Stack-based (like Forth), powerful metaprogramming"
        "Enables: PEG parsing, cost-based planning, provenance tracking"
        "EXPLAIN functionality: readable plans, VERBOSE mode, step types"
        "Location: core-factor/fbql/fbql.factor"))

      (adr-006
       (status "accepted")
       (date "2025-01")
       (context "Formal verification for normalization")
       (decision "Use Lean 4 for type-encoded normal form proofs")
       (consequences
        "Lean 4 provides: Dependent types, proof verification, modern tooling"
        "Enables: Provable correctness of FD discovery, normal form predicates"
        "Integration: Factor discovers FDs, Lean verifies they satisfy normal forms"
        "Location: normalizer/lean/*.lean"))

      (adr-007
       (status "accepted")
       (date "2025-01")
       (context "Multi-language architecture rationale")
       (decision "Polyglot by design: right tool for each layer")
       (consequences
        "Forth: Blocks/storage (deterministic, minimal)"
        "Zig: FFI bridge (C-compatible, safe)"
        "Factor: Runtime/FQL (stack-based, metaprogramming)"
        "Lean 4: Formal proofs (dependent types)"
        "Elixir: Control plane optional (BEAM fault tolerance)"
        "Each language chosen for its strengths, not dogma"))))

    (development-practices
     (code-style
      "Forth: Stack comments, word definitions, minimal comments"
      "Zig: comptime, callconv(.C) for FFI, explicit error handling"
      "Factor: Stack effect declarations, vocabularies, parsing words"
      "Lean: Dependent types, proof tactics, structured proofs")

     (security
      "SPDX headers on all files"
      "OpenSSF Scorecard compliance"
      "CRC32C checksums for data integrity"
      "Crash recovery and repair guidance"
      "Audit-grade journal with reversibility")

     (testing
      "Forth: test-blocks.fs for block operations"
      "Factor: seam-tests.factor for FQL integration"
      "Integration: End-to-end tests across layers"
      "Required for critical functionality")

     (versioning "Semantic versioning, stability policy in VERSIONING.adoc")

     (documentation
      "README.adoc: Project overview"
      "STATE.scm: Current project state (75% complete)"
      "META.scm: Architectural decisions (this file)"
      "ECOSYSTEM.scm: Ecosystem position"
      "ROADMAP.adoc: Development phases M1-M15"
      "QUICKSTART.adoc: 15-minute tutorial"
      "VERSIONING.adoc: Stability policy"
      "ARCHITECTURE.adoc: Layer-by-layer design"
      "docs/: Deployment, security, API reference, migrations, observability, integration patterns")

     (branching "main branch, feature branches, PRs required"))

    (design-rationale
     ((why-narrative-first
       "Schemas, constraints, migrations, blocks, journals are narrative artefacts"
       "Database is part of the story, not opaque substrate"
       "Target domains: investigative journalism, governance, cultural archives"
       "Agent understanding required for agentic ecosystems")

      (why-reversibility
       "Every operation has an inverse, logged in journal"
       "Enables: Audit trails, undo/redo, time-travel queries"
       "Critical for: Compliance, debugging, data governance")

      (why-multi-model
       "Documents, edges, schemas in one unified store"
       "No impedance mismatch between models"
       "Enables: Richer data relationships, flexible schemas")

      (why-self-normalizing
       "Automatic functional dependency discovery"
       "Type-encoded normal forms with Lean 4 proofs"
       "Reduces: Manual schema design errors, denormalization bugs")

      (why-forth
       "Minimal, deterministic, direct hardware access"
       "Perfect for: Storage layer, journaling, crash recovery"
       "Forth 'sculpts' data onto disk - the original metaphor")

      (why-stone-metaphor
       "Lithoglyph = carved stone symbols = permanent data records"
       "Ancient: Petroglyph (rock art), Stelae (stone pillars), Lithography (stone writing)"
       "Modern: Audit-grade database, immutable journal, carved-in-stone correctness")))))
