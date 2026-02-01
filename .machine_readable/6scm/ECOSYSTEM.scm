;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - FormDB Position in Ecosystem
;; Media-Type: application/vnd.ecosystem+scm

(ecosystem
  (version "1.0")
  (name "FormDB")
  (type "database")
  (purpose "Narrative-first, reversible, audit-grade database core")

  (position-in-ecosystem
    (category "data-storage")
    (subcategory "audit-grade-databases")
    (unique-value
      "Database internals as readable narrative artefacts"
      "Full reversibility guarantee"
      "Explainable constraint rejections"))

  (related-projects
    (sibling-standard
      (project "valence-shell")
      (relationship "sibling-standard")
      (description "Reversible shell with undo semantics")
      (synergy "Both prioritize reversibility; FormDB stores, Valence executes"))

    (sibling-standard
      (project "anamnesis")
      (relationship "sibling-standard")
      (description "Conversation knowledge extraction")
      (synergy "FormDB could be the persistent store for anamnesis memories"))

    (potential-consumer
      (project "git-hud")
      (relationship "potential-consumer")
      (description "Git repository governance")
      (synergy "FormDB for storing governance audit trails"))

    (potential-consumer
      (project "bofig")
      (relationship "potential-consumer")
      (description "Boundary objects and epistemological scoring")
      (synergy "FormDB for storing scored claims with provenance"))

    (potential-consumer
      (project "claim-forge")
      (relationship "potential-consumer")
      (description "IP registration and timestamping")
      (synergy "FormDB for immutable claim storage with audit trails"))

    (inspiration
      (project "datomic")
      (relationship "inspiration")
      (description "Immutable database with time-based queries")
      (differentiation "FormDB adds narrative rendering and reversibility guarantees"))

    (inspiration
      (project "event-sourcing")
      (relationship "inspiration")
      (description "Pattern of storing events, not state")
      (differentiation "FormDB makes events human/agent readable, not just machine processable")))

  (what-this-is
    "A database where storage internals are designed to be read"
    "An audit trail that explains itself"
    "A foundation for systems that need to prove their history"
    "A multi-model store with document and graph capabilities"
    "A teaching tool for understanding database internals")

  (what-this-is-not
    "A drop-in replacement for PostgreSQL or MySQL"
    "A high-performance OLAP solution"
    "A distributed database (in PoC phase)"
    "A general-purpose NoSQL database"
    "A time-series optimized store"))
