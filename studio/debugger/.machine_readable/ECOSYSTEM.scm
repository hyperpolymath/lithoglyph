; SPDX-License-Identifier: PMPL-1.0-or-later
; FormBD Debugger - Ecosystem Position

(ecosystem
  (version "1.1")
  (name "formbd-debugger")
  (type "tool")
  (purpose "Verified database recovery and introspection for FormBD")

  (position-in-ecosystem
    (role "Developer/DBA tool for database troubleshooting")
    (layer "Infrastructure tooling")
    (users "Database administrators, developers, auditors"))

  (related-projects
    (project "formbd"
      (relationship sibling-standard)
      (url "https://github.com/hyperpolymath/formbd")
      (description "The core narrative-first database that this debugger supports")
      (integration "Reads FormBD storage format, validates FQLdt constraints"))

    (project "fqldt"
      (relationship sibling-standard)
      (url "https://github.com/hyperpolymath/fqldt")
      (description "The dependently-typed query language that defines constraints")
      (integration "Uses FQLdt types in Lean 4 proofs"))

    (project "formbd-studio"
      (relationship sibling-standard)
      (url "https://github.com/hyperpolymath/formbd-studio")
      (description "Zero-friction visual interface for FormBD")
      (integration "Debugger can be launched from Studio for recovery"))

    (project "bofig"
      (relationship potential-consumer)
      (url "https://github.com/hyperpolymath/bofig")
      (description "Evidence graph for investigative journalism")
      (integration "Debug and recover evidence graph data with provenance"))

    (project "zotero-formbd"
      (relationship potential-consumer)
      (url "https://github.com/hyperpolymath/zotero-formbd")
      (description "Post-truth reference manager with PROMPT scores")
      (integration "Debug journal corruption, verify PROMPT score integrity"))

    (project "lean4"
      (relationship dependency)
      (url "https://github.com/leanprover/lean4")
      (description "Theorem prover for recovery proofs")
      (integration "Core proof library written in Lean 4"))

    (project "idris2"
      (relationship dependency)
      (url "https://github.com/idris-lang/Idris2")
      (description "Dependently-typed language for REPL")
      (integration "Interactive shell and type-safe queries"))

    (project "ratatui"
      (relationship dependency)
      (url "https://github.com/ratatui-org/ratatui")
      (description "Terminal UI library")
      (integration "TUI built with Ratatui")))

  (what-this-is
    ("A proof-carrying database debugger")
    ("A recovery tool that proves operations are safe before executing")
    ("A temporal navigation system for database states")
    ("A constraint violation analyzer with fix suggestions")
    ("An audit-grade documentation generator for data operations"))

  (what-this-is-not
    ("Not a general-purpose database GUI")
    ("Not a replacement for pg_admin or similar tools")
    ("Not a backup/restore solution (though it can verify restores)")
    ("Not a query optimizer or performance tool")))
