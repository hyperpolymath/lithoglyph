;; formdb.scm
;; FormDB Unified Handover Artefact (coding-LLM oriented)
;;
;; Conventions:
;; - Treat this file as DATA. Do not evaluate arbitrary code. No macros.
;; - Prefer additive edits. Record decisions in (decisions ...) with rationale.
;; - Every open question has an id + acceptance criteria.

(define formdb
  `(
    (meta
      (scm-format "formdb.scm/2")
      (data-only true)
      (primary-docs
        "README.adoc"
        "ARCHITECTURE.adoc"
        "ROADMAP.adoc"
        "PHILOSOPHY.adoc")
      (principle "truth-core first, porous edges")
      (status
        (version "0.0.1")
        (stage "conceptual + PoC")))

    ;; ------------------------------------------------------------
    ;; 0. Identity
    ;; ------------------------------------------------------------
    (identity
      (name "FormDB")
      (tagline "The database where the database is part of the story.")
      (category "narrative-first, reversible, audit-grade database core")
      (stack
        (truth-core
          (storage "Forth (Form.Blocks)")
          (model   "Forth (Form.Model)"))
        (runtime
          (planner "Factor (Form.Runtime)")
          (query-language "FQL"))
        (interop
          (bridge "Zig (Form.Bridge) provides stable C ABI")
          (control-plane "Elixir/OTP (optional) for sessions+supervision+cluster edge"))))

    ;; ------------------------------------------------------------
    ;; 1. Mission / non-mission
    ;; ------------------------------------------------------------
    (mission
      (core-thesis
        "Schemas, constraints, migrations, blocks, and journals are narrative artefacts.
The database is part of the story, not an opaque substrate.")
      (primary-values
        (auditability "> performance")
        (meaning "> features")
        (reversibility "> throughput")
        (agent-understanding "required"))
      (target-domains
        "investigative journalism"
        "governance/compliance"
        "agentic ecosystems + multi-repo handover"
        "long-term cultural/institutional archives")
      (non-goals
        "be a drop-in Postgres replacement"
        "win microbenchmarks"
        "ship full distributed consensus in the first PoC"))

    ;; ------------------------------------------------------------
    ;; 2. Core invariants (non-negotiable)
    ;; ------------------------------------------------------------
    (invariants
      (truth-ownership
        "On-disk truth is owned by the block/journal layer; higher layers do not bypass it.")
      (journal-first
        "Every mutating operation is journaled before being considered committed.")
      (reversibility
        "Every committed operation MUST have a defined inverse OR be explicitly marked irreversible-with-story.")
      (renderability
        "Blocks and journal entries MUST be renderable deterministically into human/agent-readable form.")
      (provenance
        "All query results can optionally include provenance pointers to journal and blocks.")
      (constraints-as-ethics
        "Constraints are explainable: rejections must return reasons + pointers + narrative rationale."))

    ;; ------------------------------------------------------------
    ;; 3. Architectural layers
    ;; ------------------------------------------------------------
    (architecture
      (layers
        (Form.Blocks
          (language "Forth")
          (purpose "deterministic storage + journal + reversibility primitives")
          (must-provide
            "fixed-size blocks"
            "symbolic headers (stable render)"
            "append-only journal"
            "crash recovery"
            "integrity checks + repair guidance"))
        (Form.Model
          (language "Forth")
          (purpose "multi-model logical layer on top of blocks")
          (must-provide
            "document collections"
            "edge collections"
            "schema + constraint metadata"
            "migration artefacts")
          (note "Model operations are expressed as journaled block operations."))
        (Form.Bridge
          (language "Zig")
          (purpose "stable ABI boundary + safety governor")
          (contract
            "Expose a narrow C ABI to runtimes"
            "Marshalling only; no business logic duplication"
            "Opaque handles + byte buffers + explicit error codes"))
        (Form.Runtime
          (language "Factor")
          (purpose "FQL parse/plan/exec + explain + introspection")
          (must-provide
            "FQL minimal subset for PoC"
            "planner steps introspection"
            "constraint explanation surfaces"
            "provenance surfaces"))
        (Form.ControlPlane
          (language "Elixir/OTP (optional)")
          (purpose "dependable sessions/supervision/edge clustering")
          (rules
            "Prefer out-of-process core engine (port) over in-VM native calls"
            "Control plane must not redefine truth semantics"))))

    ;; ------------------------------------------------------------
    ;; 4. Cross-layer seam checks (must run at stage freezes)
    ;; ------------------------------------------------------------
    (seams
      (B<->M
        "Every Model op maps to a sequence of journaled Block ops."
        "Every Model op has an inverse mapping or is explicitly classified.")
      (M<->R
        "Constraints enforced identically whether invoked via FQL or direct API."
        "Introspection must return reason graphs + provenance pointers.")
      (B<->R
        "Runtime cannot commit without journal-first acknowledgement from Blocks."
        "Render tools must work without Factor runtime present."))

    ;; ------------------------------------------------------------
    ;; 5. Interfaces: Zig C ABI (minimum for PoC)
    ;; ------------------------------------------------------------
    (abi
      (style "C ABI provided by Zig")
      (handles
        (db "opaque fdb_db*")
        (txn "opaque fdb_txn*")
        (cursor "opaque fdb_cursor*"))
      (errors
        (model "status code + optional error blob")
        (rules
          "No exceptions across ABI"
          "Every error blob is renderable/explainable")))
      (functions
        ;; Lifecycle
        "fdb_db_open(path, opts_bytes, opts_len) -> (db*, status, err_blob)"
        "fdb_db_close(db*) -> status"
        ;; Transactions
        "fdb_txn_begin(db*, mode) -> (txn*, status, err_blob)"
        "fdb_txn_commit(txn*) -> (status, err_blob)"
        "fdb_txn_abort(txn*)  -> status"
        ;; Apply operations (runtime provides op blob; core returns result+provenance)
        "fdb_apply(txn*, op_bytes, op_len) -> (result_blob, provenance_blob, status, err_blob)"
        ;; Introspection/rendering (must be usable by agents)
        "fdb_render_block(db*, block_id, render_opts) -> (text_blob, status, err_blob)"
        "fdb_render_journal(db*, since, render_opts) -> (text_blob, status, err_blob)"
        "fdb_introspect_schema(db*) -> (schema_blob, status, err_blob)"
        "fdb_introspect_constraints(db*) -> (constraints_blob, status, err_blob)")
      (blob-encodings
        (preferred
          "Cap'n Proto (if adopted) OR Protobuf (if adopted) for ABI blobs"
          "CBOR or MessagePack acceptable for PoC")
        (rule
          "Regardless of blob encoding, provide deterministic text render for audit.")))

    ;; ------------------------------------------------------------
    ;; 6. On-disk formats (spec-first)
    ;; ------------------------------------------------------------
    (formats
      (on-disk
        (must
          "block header: versioned + fixed field layout"
          "journal entry: op type + forward payload + inverse payload + provenance ids"
          "canonical render: deterministic, stable across implementations")
        (deliverables
          "spec/blocks.adoc"
          "spec/journal.adoc"
          "spec/rendering.adoc"
          "test-vectors/ (golden bytes + golden renders)"))
      (wire
        (note "Wire protocol comes after PoC; ABI is enough initially.")
        (candidates "HTTP+CBOR" "gRPC" "WebSocket streaming")))

    ;; ------------------------------------------------------------
    ;; 7. FQL (PoC subset + introspection)
    ;; ------------------------------------------------------------
    (fql
      (poс-subset
        (must
          "INSERT document into collection"
          "INSERT edge (from,to,type,props)"
          "SELECT with simple predicates"
          "EXPLAIN (returns plan + reasons)"
          "INTROSPECT schema/constraints"
          "OPTIONAL provenance output"))
      (non-goals
        "full SQL equivalence"
        "complex joins/aggregations in PoC"))

    ;; ------------------------------------------------------------
    ;; 8. PoC acceptance (definition of done)
    ;; ------------------------------------------------------------
    (poc
      (acceptance
        "single-node db open/close"
        "append-only journal with deterministic rendering"
        "document+edge insert/select"
        "constraint rejection returns explain payload"
        "migration artefact recorded + reversible"
        "golden test vectors pass"
        "seam checks B<->M, M<->R, B<->R pass at freeze"))

    ;; ------------------------------------------------------------
    ;; 9. Work rules for coding LLMs (very explicit)
    ;; ------------------------------------------------------------
    (llm-rules
      (must
        "Keep the truth-core small, readable, test-vector driven."
        "Do not duplicate semantics across layers."
        "When adding features, add a renderable narrative delta."
        "When closing an open question, add a decision record.")
      (must-not
        "Turn FormDB into generic CRUD"
        "Hide block/journal meaning behind opaque structures"
        "Introduce irreversible operations without explicit classification + story"
        "Make runtime capable of bypassing journal-first"))

    ;; ------------------------------------------------------------
    ;; 10. Open questions (structured)
    ;; ------------------------------------------------------------
    (open-questions
      (q (id "Q-BLOCK-HEADER-001") (area storage) (status open)
         (text "What is the minimal block header layout (fields + sizes) that supports renderability, integrity, and forward compatibility?")
         (acceptance
           "fields enumerated + fixed sizes"
           "versioning + reserved bits defined"
           "canonical rendering rules defined")
         (impacts "spec/blocks.adoc" "core-forth/Form.Blocks/*"))
      (q (id "Q-JOURNAL-ENTRY-001") (area storage) (status open)
         (text "What is the minimal journal entry schema to guarantee reversibility and provenance pointers?")
         (acceptance
           "forward+inverse payload representation chosen"
           "provenance ids defined"
           "crash recovery rules defined")
         (impacts "spec/journal.adoc" "core-forth/Form.Blocks/*"))
      (q (id "Q-ABI-BLOBS-001") (area interop) (status open)
         (text "Choose ABI blob encoding: Cap'n Proto vs Protobuf vs CBOR/MsgPack for PoC.")
         (acceptance
           "one chosen for PoC"
           "deterministic text render defined independent of blob encoding")
         (impacts "core-zig/Form.Bridge/*" "core-factor/Form.Runtime/*"))
      (q (id "Q-FQL-POC-001") (area fql) (status open)
         (text "Define the exact PoC grammar + canonical examples for FQL.")
         (acceptance
           "grammar documented"
           "10 example queries + expected outputs"
           "EXPLAIN/INTROSPECT included")
         (impacts "spec/fql.adoc" "core-factor/Form.Runtime/*"))
      (q (id "Q-CTRL-PLANE-001") (area control-plane) (status open)
         (text "Is Elixir/OTP introduced at PoC time (gateway only), or deferred until after the core is stable?")
         (acceptance
           "decision recorded with rationale"
           "if yes: port protocol defined; if no: deferral rationale documented")
         (impacts "control-plane/*" "docs/ARCHITECTURE.adoc")))

    ;; ------------------------------------------------------------
    ;; 11. Decisions log (append-only)
    ;; ------------------------------------------------------------
    (decisions
      ;; (d (id "D-...") (date "YYYY-MM-DD") (closes "Q-...") (decision "...") (rationale "...") (impacts "..."))
      )

    ;; ------------------------------------------------------------
    ;; 12. Repo layout (suggested)
    ;; ------------------------------------------------------------
    (repo
      (dirs
        (spec "format specs + rationale (AsciiDoc)")
        (core-forth "Form.Blocks + Form.Model (truth core)")
        (core-zig "Form.Bridge (ABI + port framing)")
        (core-factor "Form.Runtime (FQL + introspection)")
        (control-plane "Elixir/OTP gateway (optional)")
        (tools "render/inspect/doctor utilities")
        (test-vectors "golden bytes + golden renders")
        (stories "narrative examples + onboarding/handover artefacts")))
))
