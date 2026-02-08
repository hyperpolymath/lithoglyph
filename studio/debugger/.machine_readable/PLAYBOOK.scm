; SPDX-License-Identifier: PMPL-1.0-or-later
; FormDB Debugger - Operational Playbook

(playbook
  (version "1.0")
  (name "formdb-debugger")
  (media-type "application/playbook+scheme")

  (build-commands
    (lean4
      (build "cd core && lake build")
      (test "cd core && lake test")
      (clean "cd core && lake clean")
      (update-deps "cd core && lake update"))

    (idris2
      (build "cd idris && idris2 --build debugger.ipkg")
      (repl "cd idris && idris2 --repl debugger.ipkg")
      (clean "cd idris && rm -rf build/")
      (typecheck "cd idris && idris2 --check debugger.ipkg"))

    (rust
      (build "cd adapters && cargo build")
      (test "cd adapters && cargo test")
      (release "cd adapters && cargo build --release")
      (clippy "cd adapters && cargo clippy")
      (fmt "cd adapters && cargo fmt"))

    (tui
      (build "cd ui && cargo build")
      (run "cd ui && cargo run")
      (release "cd ui && cargo build --release")))

  (development-workflow
    (daily
      ("Pull latest changes")
      ("Run lake build to check Lean 4")
      ("Run cargo test to check Rust")
      ("Update STATE.scm if progress made"))

    (before-commit
      ("lake build - Lean 4 must compile")
      ("idris2 --check - Idris 2 must typecheck")
      ("cargo test - all Rust tests pass")
      ("cargo clippy - no warnings")
      ("Update STATE.scm completion percentages"))

    (release
      ("Tag version in git")
      ("Build release binaries")
      ("Update CHANGELOG")
      ("Push to GitHub")))

  (troubleshooting
    (issue "lake build fails with sorry"
      (cause "Unfinished proof contains sorry placeholder")
      (fix "Complete the proof or mark as known technical debt in STATE.scm"))

    (issue "Idris 2 totality check fails"
      (cause "Function not proven total")
      (fix "Add assert_total or rewrite to be structurally recursive"))

    (issue "Rust adapter connection refused"
      (cause "Database not running or wrong connection string")
      (fix "Check database is running, verify connection parameters"))

    (issue "TUI renders incorrectly"
      (cause "Terminal size too small or missing unicode support")
      (fix "Resize terminal or check TERM environment variable")))

  (recovery-scenarios
    (scenario "Constraint violation detected"
      (steps
        ("1. Use 'explain violation <constraint>' to understand the issue")
        ("2. Review suggested fixes with proof status")
        ("3. Choose fix with complete proof (marked QED)")
        ("4. Confirm execution")
        ("5. Verify constraint now satisfied")))

    (scenario "Corrupted FormDB journal"
      (steps
        ("1. Load journal with 'connect formdb://<path>'")
        ("2. Use 'timeline' to visualize entry history")
        ("3. Identify corruption point with 'verify-chain'")
        ("4. Generate recovery plan with 'recover from <entry>'")
        ("5. Review proof of losslessness")
        ("6. Execute recovery")))

    (scenario "Foreign key orphan records"
      (steps
        ("1. Use 'find orphans <table>' to list violations")
        ("2. For each orphan, review options:")
        ("   - Re-insert parent record")
        ("   - Update to valid parent")
        ("   - Delete orphan (if safe)")
        ("3. Each option shows proof status")
        ("4. Execute chosen fix"))))

  (monitoring
    (health-checks
      ("Lean 4 lake can resolve mathlib")
      ("Idris 2 can load all packages")
      ("Rust can connect to test databases")
      ("TUI renders in standard terminal"))

    (metrics
      ("Proof coverage: % of operations with complete proofs")
      ("Sorry count: number of unfinished proofs")
      ("Test coverage: % of Rust code with tests")
      ("Build time: time for full rebuild"))))
