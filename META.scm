;; META.scm - FormDB Meta-Level Information
;; Media-Type: application/meta+scheme
;; Spec: spec/META-FORMAT-SPEC.adoc

(meta
  (architecture-decisions
    (adr-001
      (status "accepted")
      (date "2026-01-03")
      (title "Forth for Truth Core")
      (context
        "The truth core (Form.Blocks, Form.Model) needs to be small, auditable,
        and deterministic. We need a language that is stack-based, minimal,
        and has no hidden runtime behavior.")
      (decision
        "Use Forth for Form.Blocks and Form.Model.
        Forth's simplicity, determinism, and lack of hidden state make it
        ideal for the truth core where every operation must be auditable.")
      (consequences
        "Developers must learn Forth"
        "Excellent for formal verification"
        "Small attack surface"
        "Deterministic rendering is natural"))

    (adr-002
      (status "accepted")
      (date "2026-01-03")
      (title "Zig for ABI Bridge")
      (context
        "We need a stable C ABI to connect the Forth truth core with
        higher-level runtimes (Factor, Elixir). The bridge must be safe,
        fast, and produce no hidden allocations.")
      (decision
        "Use Zig for Form.Bridge.
        Zig provides C ABI compatibility, explicit memory management,
        compile-time safety, and no hidden control flow.")
      (consequences
        "Excellent interop with C-compatible runtimes"
        "No garbage collection pauses"
        "Safety governor can be implemented at ABI level"
        "Portable across platforms"))

    (adr-003
      (status "accepted")
      (date "2026-01-03")
      (title "Factor for Runtime")
      (context
        "The runtime needs to parse FQL, plan queries, execute them,
        and provide rich introspection. We need a language that handles
        complex data transformations elegantly.")
      (decision
        "Use Factor for Form.Runtime.
        Factor's concatenative nature, quotations, and vocabularies
        provide excellent metaprogramming for query planning and introspection.")
      (consequences
        "Rich introspection capabilities"
        "Good FFI for calling into Zig bridge"
        "Quotations natural for query representation"
        "Smaller community than mainstream languages"))

    (adr-004
      (status "accepted")
      (date "2026-01-03")
      (title "Journal-First Mutation Semantics")
      (context
        "Auditability and reversibility require that every mutation be recorded
        before it takes effect. We must guarantee no silent state changes.")
      (decision
        "All mutating operations MUST be journaled before being considered committed.
        No layer may bypass the journal. The journal is the source of truth for
        all mutations.")
      (consequences
        "Every mutation is auditable"
        "Reversibility is always possible"
        "Slight latency overhead for write path"
        "Journal becomes critical path for durability"))

    (adr-005
      (status "proposed")
      (date "2026-01-03")
      (title "Elixir/OTP for Control Plane")
      (context
        "Session management, supervision, and cluster coordination need
        fault-tolerant, battle-tested primitives. The control plane should
        not own truth semantics.")
      (decision
        "Use Elixir/OTP for optional Form.ControlPlane.
        OTP supervisors, GenServers, and distribution primitives provide
        robust session and cluster management. Control plane communicates
        with core via ports, never bypassing the bridge.")
      (consequences
        "Fault-tolerant session handling"
        "Cluster coordination via libcluster"
        "Clear separation: control plane != truth owner"
        "Additional language in the stack")))

  (development-practices
    (code-style
      (forth "Standard Forth conventions, one word per line for complex definitions")
      (zig "Follow Zig style guide, explicit error handling")
      (factor "Use vocabularies, document stack effects")
      (elixir "Standard Elixir formatting, dialyzer type specs"))
    (security
      (principle "Defense in depth")
      (audit-log "All mutations journaled")
      (constraint-enforcement "At bridge layer, not just runtime"))
    (testing
      (unit "Each layer has unit tests")
      (integration "Seam checks between layers")
      (golden "Test vectors for storage formats"))
    (versioning "SemVer, but PoC is 0.x")
    (documentation "AsciiDoc for specs, inline for code")
    (branching "main for stable, feature branches for development"))

  (design-rationale
    (why-forth
      "Forth is the simplest possible foundation for deterministic storage.
      Every word's behavior is explicit. There are no hidden allocations,
      no garbage collection, no closures capturing state. This transparency
      is essential for auditability and formal verification.")
    (why-factor-not-forth
      "While Forth is perfect for the truth core, Factor provides better
      ergonomics for complex query planning and introspection. Factor's
      quotations are ideal for representing query fragments, and its
      vocabulary system helps organize the runtime cleanly.")
    (why-not-sql
      "SQL is designed for relational algebra, not narrative audit trails.
      FQL prioritizes explainability, provenance, and reversibility over
      SQL compatibility. We may add SQL compatibility later as a layer.")
    (why-reversibility
      "In investigative journalism and compliance, the ability to answer
      'what was the state at time T' and 'how did we get from state A to
      state B' is essential. Irreversible operations hide history.")))
