# Changelog

All notable changes to FormBD Debugger will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-12

### Added

#### PostgreSQL Adapter
- Real database connection via `tokio-postgres`
- Schema introspection from `information_schema` and `pg_catalog`
- Constraint checking for FOREIGN KEY, UNIQUE, CHECK, PRIMARY KEY
- Timeline events from `pg_stat_activity` and `pg_stat_user_tables`
- Connection pooling support

#### Terminal UI (Ratatui)
- Six views: Home, Schema, Timeline, Diagnose, Recover, Help
- Interactive navigation with vim-style keybindings (j/k)
- Real-time constraint violation detection
- Proof-carrying recovery plan generation
- Status bar with connection state and database info

#### Lean 4 Proof Library
- `Lossless.lean` - INSERT/DELETE losslessness theorems
  - `insert_is_lossless`: INSERT preserves all existing rows
  - `insert_is_reversible`: INSERT can be undone via DELETE
  - `delete_with_archive_is_lossless`: DELETE with archive preserves data
  - `lossless_compose`: Composed operations are lossless
- `FDPreserving.lean` - Functional dependency preservation
  - `delete_preserves_fds`: DELETE always preserves FDs
  - `insert_preserves_fds_if_compatible`: INSERT preserves FDs when compatible
  - `delete_snapshot_preserves_fds`: Snapshot-level FD preservation
- `Rollback.lean` - Transaction rollback proofs
  - `RecoveryPlan` structure with correctness, validity, reversibility

#### Proof Integration
- Recovery plans reference applicable Lean theorems
- Proof coverage calculation per recovery step
- Proven properties tracking (Data Preservation, FD Preservation, Reversibility)

### Technical Details

- Rust 2021 edition
- Async runtime: Tokio
- TUI framework: Ratatui 0.29 + Crossterm 0.28
- Proof assistant: Lean 4

[1.0.0]: https://github.com/hyperpolymath/lithoglyph-debugger/releases/tag/v1.0.0
