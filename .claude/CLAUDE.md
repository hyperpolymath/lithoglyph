# CLAUDE.md - AI Assistant Instructions for Lithoglyph

## Project Overview

Lithoglyph is a narrative-first, reversible, audit-grade database.
Stack: Forth (storage) → Zig (bridge/ABI) → Factor (FQL runtime) → Idris2 (proofs) → Lean 4 (normalizer proofs).
Satellites: BEAM NIFs (Zig + Rust), ReScript client, Tauri studio.

## Critical Invariants

1. **IP Rename PENDING**: Code uses `FormBD`/`FormDB` internally. Rename to `Lith`/`Litho` before public release.
2. **Zero `believe_me`** in Idris2 ABI (`src/FormBD/`). This is a hard invariant.
3. **`core-zig/`** is the working bridge. `ffi/zig/` delegates to it.
4. **Proven library** lives at `/var/mnt/eclipse/repos/proven/` — never bundle a copy.
5. All Zig `@ptrCast`/`@alignCast` must have `// SAFETY:` comments.

## Machine-Readable Artefacts

`.machine_readable/`: STATE.scm, ECOSYSTEM.scm, META.scm, AGENTIC.scm, NEUROSYM.scm, PLAYBOOK.scm

## Build Commands

```bash
# Zig bridge (the core)
cd core-zig && zig build test

# Forth kernel (17 tests)
cd core-forth && gforth test/lithoglyph-tests.fs

# Lean 4 proofs (52 tests)
cd core-lean && lake build

# Idris2 ABI type-check
idris2 --source-dir src --check src/FormBD/FormBridge.idr

# BEAM NIF (Rust, 0 warnings)
cd beam/native_rust && cargo build

# BEAM NIF (Zig)
cd beam/native && zig build
```

## Known Issues

- **API layer** (`api/src/rest.zig`): 83 call sites need Zig 0.15.2 HTTP migration
- **Studio**: 11 Tauri commands return mock data
- **Idris2 Nat reduction**: Proof type signatures must use concrete literals, not function-defined constants (Idris2 0.8 limitation)
