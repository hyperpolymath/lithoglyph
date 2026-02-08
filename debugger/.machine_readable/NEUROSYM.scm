; SPDX-License-Identifier: PMPL-1.0-or-later
; FormDB Debugger - Neurosymbolic Integration Configuration

(neurosym
  (version "1.0")
  (name "formdb-debugger")
  (media-type "application/neurosym+scheme")

  (symbolic-layer
    (description "Lean 4 and Idris 2 provide the symbolic reasoning layer")

    (components
      (lean4-proofs
        (purpose "Machine-checked correctness proofs")
        (guarantees
          ("Lossless: no data loss during recovery")
          ("FD-Preserving: functional dependencies maintained")
          ("Reversible: operations can be undone")))

      (idris2-types
        (purpose "Dependent types for runtime safety")
        (guarantees
          ("Type-indexed database schemas")
          ("Constraint-carrying queries")
          ("Provenance-tracked values")))

      (constraint-system
        (purpose "Database constraint representation")
        (types
          ("Primary key constraints")
          ("Foreign key constraints")
          ("Unique constraints")
          ("Check constraints")
          ("Functional dependencies")))))

  (neural-layer
    (description "AI assistance for proof search and recovery planning")

    (capabilities
      (proof-suggestion
        (input "Theorem statement and context")
        (output "Candidate proof tactics")
        (verification "Lean 4 type checker"))

      (recovery-planning
        (input "Constraint violation description")
        (output "Ranked recovery options")
        (verification "Proof obligations for each option"))

      (pattern-recognition
        (input "Database state history")
        (output "Anomaly detection and root cause analysis")
        (verification "Temporal logic assertions"))))

  (integration-points
    (proof-search
      (neural "LLM suggests proof tactics based on goal")
      (symbolic "Lean 4 verifies suggested tactics compile")
      (feedback "Failed tactics inform next suggestions"))

    (recovery-ranking
      (neural "LLM ranks recovery options by likely success")
      (symbolic "Each option requires complete proof before execution")
      (feedback "Successful recoveries train ranking model"))

    (error-explanation
      (neural "LLM generates human-readable error explanations")
      (symbolic "Explanations reference specific constraint violations")
      (feedback "User corrections improve explanations")))

  (trust-boundaries
    (trusted
      ("Lean 4 proof checker")
      ("Idris 2 type checker")
      ("Database adapter read operations"))

    (verified-before-trust
      ("LLM-suggested proof tactics")
      ("LLM-suggested recovery plans")
      ("Any write operation to database"))

    (never-trusted
      ("Unproven recovery operations")
      ("Tactics that use sorry/admit")
      ("External input without validation"))))
