# SPDX-License-Identifier: MPL-2.0
# justfile - Just recipes for Lithoglyph
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

# `default` comes from the root Justfile (`just --list --unsorted`).

# ============================================================
# BUILD
# ============================================================

# Build Zig libraries (static + shared)
build-zig:
    cd core-zig && zig build

# Build shared library for FFI consumers
build-ffi:
    cd core-zig && zig build-lib src/bridge.zig -dynamic -lc -O ReleaseFast

# Build C FFI integration test binary
build-ffi-tests:
    # -I../generated/abi: bridge.h is generated to generated/abi/ at the repo
    # root, not into core-zig. See the note in .github/workflows/test-suite.yml.
    cd core-zig && gcc -I../generated/abi -o test-ffi-integration test-ffi-integration.c -L zig-out/lib -llith_bridge
    cd core-zig && gcc -o test-version-only test-version-only.c -L zig-out/lib -llith_bridge
    cd core-zig && gcc -o test-db-open test-db-open.c -L zig-out/lib -llith_bridge

# Build everything
build: build-zig

# ============================================================
# TESTS
# ============================================================

# Run Zig unit tests (bridge + blocks)
test-zig:
    @echo "=== Zig Unit Tests ==="
    cd core-zig && zig build test
    @echo "Zig tests passed"

# Run Zig tests directly (faster, no build system)
test-zig-fast:
    @echo "=== Zig Direct Tests ==="
    cd core-zig && zig test src/bridge.zig
    cd core-zig && zig test src/blocks.zig

# Run Forth block layer tests
test-forth:
    @echo "=== Forth Block Tests ==="
    cd core-forth/test && gforth test-blocks.fs -e bye

# Run C FFI integration tests (requires build-zig first)
test-ffi: build-zig
    @echo "=== C FFI Integration Tests ==="
    cd core-zig && LD_LIBRARY_PATH=zig-out/lib ./test-ffi-integration

# Run C FFI quick smoke tests
test-ffi-smoke: build-zig
    @echo "=== C FFI Smoke Tests ==="
    cd core-zig && LD_LIBRARY_PATH=zig-out/lib ./test-version-only
    cd core-zig && LD_LIBRARY_PATH=zig-out/lib ./test-db-open

# Run Factor ABI seam tests (Factor <-> Form.Bridge)
#
# Previously ran core-factor/gql/seam-tests.factor. That file tests the GQL
# pipeline (Parser -> Planner -> Executor -> Normalizer) and `USING: gql`, so
# it belongs to the language and moved to hyperpolymath/gnpl. Keeping it here
# would have made gnpl a build dependency of lithoglyph — the wrong direction.
#
# The seam lithoglyph actually owns is Factor <-> Form.Bridge, and these two
# files are what test it: test-ffi.factor drives the storage-backend vocab,
# minimal-ffi-test.factor dlopens libbridge directly.
test-factor: build-zig
    @echo "=== Factor ABI Seam Tests ==="
    cd core-factor && factor minimal-ffi-test.factor
    cd core-factor && factor test-ffi.factor

# ── Scripting-layer tests: EMPTY, pending the AffineScript port ───────────────
#
# These four recipes each ran `deno task …` against a directory that contains no
# tests. Measured, not assumed — `deno test` in tests/property, tests/fuzz,
# tests/integration and tests/e2e all report "No test modules found", and no
# file under tests/ calls Deno.test.
#
# They now exit 1 and say so. They previously appeared to work: `deno task test`
# surfaced the empty-suite error, but the CI job wrapped it in
# `|| echo "... skipping for now"`, so the hole was invisible.
#
# ReScript is not the intended language for this layer — AffineScript is.
# See docs/lithoglyph/AFFINESCRIPT-PORT.adoc.

# Property tests — NOT IMPLEMENTED (no test modules exist)
test-property:
    @echo "=== Property Tests: NOT IMPLEMENTED ==="
    @echo "    tests/property has no test modules. Pending the AffineScript"
    @echo "    port — see docs/lithoglyph/AFFINESCRIPT-PORT.adoc"
    @exit 1

# Fuzz tests (quick) — NOT IMPLEMENTED (no test modules exist)
test-fuzz-quick:
    @echo "=== Fuzz Tests (Quick): NOT IMPLEMENTED ==="
    @echo "    tests/fuzz has no test modules. See AFFINESCRIPT-PORT.adoc"
    @exit 1

# Fuzz tests (standard) — NOT IMPLEMENTED (no test modules exist)
test-fuzz:
    @echo "=== Fuzz Tests: NOT IMPLEMENTED ==="
    @echo "    tests/fuzz has no test modules. See AFFINESCRIPT-PORT.adoc"
    @exit 1

# Integration tests — NOT IMPLEMENTED (no test modules exist)
test-integration:
    @echo "=== Integration Tests: NOT IMPLEMENTED ==="
    @echo "    tests/integration has no test modules. See AFFINESCRIPT-PORT.adoc"
    @exit 1

# E2E tests — NOT IMPLEMENTED (no test modules exist)
test-e2e:
    @echo "=== E2E Tests: NOT IMPLEMENTED ==="
    @echo "    tests/e2e has no test modules. See AFFINESCRIPT-PORT.adoc"
    @exit 1

# Run all core tests (no server required). These are the suites that are real.
test: test-zig test-forth test-ffi

# `test-all` used to chain test-property and test-fuzz-quick, which made it look
# broader than `test` while adding nothing but two empty suites. Until the
# AffineScript port lands there is no larger set to run, so it is `test`.
test-all: test

# ============================================================
# BENCHMARKS
# ============================================================

# Factor GQL benchmarks — MOVED, and this repo has no replacement yet.
#
# core-factor/gql/benchmarks.factor benchmarked the GQL parser/planner/executor.
# It is language work, so it moved to hyperpolymath/gnpl (runtime/) along with
# gql.factor itself. Nothing in lithoglyph benchmarks the core today.
#
# This exits non-zero on purpose. RSR doctrine: a check that cannot fail is not
# a check, and a `bench` target that silently succeeds with nothing to run reads
# as "benchmarked and fine". The hole is real; it is named rather than hidden.
bench-factor:
    @echo "=== Factor GQL Benchmarks: MOVED to hyperpolymath/gnpl (runtime/) ==="
    @echo "    lithoglyph has no core benchmarks yet. Add them here, or run"
    @echo "    the language benchmarks in the gnpl repo."
    @exit 1

# Run all benchmarks
bench: bench-factor

# ============================================================
# CHECKS & VALIDATION
# ============================================================

# Check that Forth code loads without errors
check-forth:
    @echo "Checking Forth code loads..."
    cd core-forth/src && gforth lithoglyph-blocks.fs -e 'bye'
    cd core-forth/src && gforth lithoglyph-journal.fs -e 'bye'
    cd core-forth/src && gforth lithoglyph-model.fs -e 'bye'
    @echo "All Forth files load successfully"

# Check that Lean code compiles
check-lean:
    @echo "Checking Lean code compiles..."
    cd normalizer/lean && lake build
    @echo "Lean code compiles"

# Verify Zig ABI exports match expectations
check-abi: build-zig
    @echo "=== ABI Export Verification ==="
    nm -D core-zig/zig-out/lib/liblith_bridge.so | grep ' T lith_' | sort
    @echo "Expected: lith_version, lith_db_open, lith_db_close, lith_txn_begin, lith_txn_commit, lith_txn_abort, lith_apply, lith_introspect_schema, lith_render_block, lith_render_journal, lith_blob_free"

# Run all checks
check: check-forth check-lean check-abi

# Format Zig code
fmt:
    cd core-zig && zig fmt src/

# ============================================================
# CLEAN
# ============================================================

# Clean build artifacts
clean:
    @echo "Cleaning build artifacts..."
    rm -rf core-zig/zig-out core-zig/.zig-cache
    rm -f core-zig/test-*.lgh
    @echo "Clean complete"

# ============================================================
# DEV TOOLS
# ============================================================

# Show development environment status
env-status:
    @echo "Development Environment Status:"
    @echo "================================"
    @which zig 2>/dev/null && echo "Zig: $(zig version)" || echo "Zig: NOT INSTALLED"
    @which gforth 2>/dev/null && echo "Forth: $(gforth --version 2>&1 | head -1)" || echo "gforth: NOT INSTALLED"
    @which factor 2>/dev/null && echo "Factor: installed" || echo "Factor: NOT INSTALLED"
    @which lean 2>/dev/null && echo "Lean: $(lean --version 2>&1 | head -1)" || echo "Lean: NOT INSTALLED"
    @which deno 2>/dev/null && echo "Deno: $(deno --version 2>&1 | head -1)" || echo "Deno: NOT INSTALLED"

# Start demo server for E2E testing
serve:
    @echo "Starting Lithoglyph demo server on :8080..."
    cd core-zig && zig run ../demo-server.zig -- -lc
