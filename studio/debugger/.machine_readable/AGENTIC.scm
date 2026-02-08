; SPDX-License-Identifier: PMPL-1.0-or-later
; FormDB Debugger - AI Agent Interaction Patterns

(agentic
  (version "1.0")
  (name "formdb-debugger")
  (media-type "application/agentic+scheme")

  (agent-capabilities
    (can-do
      ("Read and analyze Lean 4 proof files")
      ("Read and analyze Idris 2 source files")
      ("Read and modify Rust adapter code")
      ("Read and modify Ratatui TUI code")
      ("Run lake build for Lean 4 compilation")
      ("Run idris2 --build for Idris compilation")
      ("Run cargo build/test for Rust compilation")
      ("Analyze SPEC.adoc for requirements")
      ("Update STATE.scm with progress")
      ("Generate new proof stubs"))

    (should-ask
      ("Before modifying core proof theorems")
      ("Before changing database adapter interfaces")
      ("Before adding new dependencies")
      ("When multiple valid proof strategies exist"))

    (cannot-do
      ("Execute database recovery operations")
      ("Access actual production databases")
      ("Modify proof axioms without review")))

  (interaction-patterns
    (pattern "proof-development"
      (trigger "User asks to implement a proof")
      (steps
        ("Read the theorem statement from Lean 4 file")
        ("Analyze the goal and available hypotheses")
        ("Propose proof strategy")
        ("Implement proof with tactics")
        ("Run lake build to verify")))

    (pattern "adapter-extension"
      (trigger "User asks to support new database")
      (steps
        ("Create new crate in adapters/")
        ("Implement DatabaseAdapter trait")
        ("Add to workspace Cargo.toml")
        ("Write integration tests")
        ("Update ECOSYSTEM.scm with new dependency")))

    (pattern "repl-command"
      (trigger "User asks to add REPL command")
      (steps
        ("Add command to Commands.idr")
        ("Implement handler in appropriate module")
        ("Update help text")
        ("Test in Idris 2 REPL")))

    (pattern "tui-widget"
      (trigger "User asks to add UI element")
      (steps
        ("Create widget in ui/src/widgets/")
        ("Add to widgets.rs module")
        ("Wire up in app.rs")
        ("Test with cargo run"))))

  (file-ownership
    (lean4 "core/**/*.lean" "Core proof library - high caution")
    (idris2 "idris/**/*.idr" "REPL and interactive shell")
    (rust-adapters "adapters/**/*.rs" "Database communication")
    (rust-ui "ui/**/*.rs" "Terminal user interface")
    (spec "SPEC.adoc" "Requirements - read only unless asked")
    (state "STATE.scm" "Update after significant work")
    (meta "META.scm" "Update for architectural decisions"))

  (safety-rules
    (rule "proof-before-execute"
      "Never suggest executing recovery without completed proofs")
    (rule "preserve-sorry"
      "Document all 'sorry' (Lean) and 'believe_me' (Idris) as technical debt")
    (rule "test-before-commit"
      "Always run lake build and cargo test before marking tasks complete")
    (rule "incremental-proofs"
      "Build proofs incrementally, verifying each step compiles")))
