; SPDX-License-Identifier: PMPL-1.0-or-later
; FormBD Debugger - Meta Information

(meta
  (version "1.1")
  (name "formbd-debugger")
  (media-type "application/meta+scheme")

  (architecture-decisions
    (adr-001
      (status accepted)
      (date "2025-01-11")
      (title "Use Lean 4 for core proof library")
      (context "Need a theorem prover with good performance and tactics")
      (decision "Use Lean 4 for all core proofs and constraint verification")
      (consequences
        ("Proofs can use powerful tactics like omega and simp")
        ("Native compilation for performance")
        ("Mathlib available for mathematical foundations")
        ("Learning curve for contributors unfamiliar with Lean")))

    (adr-002
      (status accepted)
      (date "2025-01-11")
      (title "Use Idris 2 for interactive shell")
      (context "Need interactive exploration with dependent types")
      (decision "Use Idris 2 for REPL and interactive debugging")
      (consequences
        ("First-class types enable runtime type computation")
        ("REPL provides interactive exploration")
        ("Quantitative types for resource tracking")
        ("Requires users to have Idris 2 installed")))

    (adr-003
      (status accepted)
      (date "2025-01-11")
      (title "Rust for database adapters")
      (context "Need efficient, safe database communication")
      (decision "Use Rust for all database adapter code")
      (consequences
        ("Excellent database driver ecosystem")
        ("Memory safety without garbage collection")
        ("Easy FFI with Lean 4 and Idris 2")
        ("Rust knowledge required for adapter development")))

    (adr-004
      (status accepted)
      (date "2026-01-11")
      (title "Scaffold-first development approach")
      (context "Complex multi-language project needs clear structure before implementation")
      (decision "Create complete scaffolding across all 4 ecosystems before filling in implementations")
      (consequences
        ("Clear module boundaries from the start")
        ("Parallel development possible across Lean/Idris/Rust/TUI")
        ("Type signatures serve as contracts between components")
        ("Some stubs marked 'sorry' or 'believe_me' until proven"))))

  (development-practices
    (code-style
      (lean4 "Follow Lean 4 naming conventions, explicit universe levels")
      (idris2 "Follow Idris 2 standard library style, use Total where possible")
      (rust "Follow rustfmt defaults, clippy clean"))

    (security
      (principle "Never execute unproven recovery operations")
      (principle "All database operations must be reversible or explicitly marked destructive")
      (principle "Audit trail for all recovery operations")
      (principle "Proofs must be machine-checked, not just type-checked"))

    (testing
      (unit-tests "Property-based testing for proof correctness")
      (integration "Test against real PostgreSQL, FormBD, and SQLite")
      (formal "Lean 4 proofs as executable tests")
      (repl "Idris 2 REPL tests for interactive scenarios"))

    (versioning "Semantic versioning")

    (documentation
      (format "AsciiDoc for all documentation")
      (api "Type signatures serve as documentation")
      (proofs "Theorem statements document invariants"))

    (branching
      (main "main - stable releases")
      (development "dev - integration branch")
      (features "feat/* - feature branches")
      (proofs "proof/* - theorem development")))

  (design-rationale
    (why-proven-recovery
      "Database recovery is too important to rely on hope. A corrupted database
       can destroy years of work, violate compliance requirements, or cause
       irreversible data loss. By requiring proofs, we shift from 'this should
       work' to 'this will work, and here's the mathematical proof.'")

    (why-lean-and-idris
      "Lean 4 provides industrial-strength theorem proving with excellent
       performance. Idris 2 provides first-class dependent types that make
       the REPL experience type-safe. Together they offer the best of both
       worlds: rigorous proofs and interactive exploration.")

    (why-rust-adapters
      "Database communication requires both performance and safety. Rust's
       ownership system prevents common bugs like use-after-free that could
       corrupt database connections. The ecosystem includes excellent drivers
       for PostgreSQL, SQLite, and other databases.")

    (why-four-ecosystems
      "Each ecosystem serves a distinct purpose: Lean 4 for proofs that must
       be correct, Idris 2 for interactive exploration with types, Rust for
       efficient database I/O, and Ratatui for terminal UI. The complexity
       is justified by the safety requirements.")))
