# SPDX-License-Identifier: PMPL-1.0-or-later
# justfile - Just recipes for Lithoglyph
# See: https://github.com/hyperpolymath/mustfile

# Default recipe
default:
    @just --list

# Build the project (placeholder - components use different build systems)
build:
    @echo "Lithoglyph uses multiple languages:"
    @echo "  - Forth (gforth): No build step needed"
    @echo "  - Factor: Vocabulary loads on demand"
    @echo "  - Zig: Use 'zig build' in core-zig/"
    @echo "  - Lean: Use 'lean' or 'lake build'"

# Run Forth block layer tests
test-forth:
    @echo "Running Forth block tests..."
    cd core-forth/test && toolbox run gforth test-blocks.fs

# Check that Forth code loads
check-forth:
    @echo "Checking Forth code loads..."
    cd core-forth/src && toolbox run gforth lithoglyph-blocks.fs -e 'bye'
    cd core-forth/src && toolbox run gforth lithoglyph-journal.fs -e 'bye'
    cd core-forth/src && toolbox run gforth lithoglyph-model.fs -e 'bye'
    @echo "All Forth files load successfully"

# Check that Lean code compiles
check-lean:
    @echo "Checking Lean code compiles..."
    cd normalizer/lean && lean FunDep.lean
    @echo "Lean code compiles (warnings are expected)"

# Run all tests
test: test-forth

# Run all checks
check: check-forth check-lean

# Format code (placeholder - each language has its own formatter)
fmt:
    @echo "Formatting not yet configured"
    @echo "  - Forth: No standard formatter"
    @echo "  - Factor: Use 'lint' vocab in Factor"
    @echo "  - Zig: Use 'zig fmt'"
    @echo "  - Lean: Use 'lean4-mode' in editor"

# Lint code (placeholder)
lint:
    @echo "Linting not yet configured"

# Clean build artifacts
clean:
    @echo "Cleaning build artifacts..."
    rm -rf core-zig/zig-cache core-zig/zig-out
    @echo "Clean complete"

# Show development environment status
env-status:
    @echo "Development Environment Status:"
    @echo "================================"
    @which gforth 2>/dev/null && gforth --version || echo "gforth: NOT INSTALLED (use 'toolbox run gforth')"
    @which factor 2>/dev/null && factor --version 2>/dev/null || echo "Factor: ~/.local/opt/factor/factor (or ~/.local/bin/factor-lang)"
    @which lean 2>/dev/null && lean --version || echo "Lean: NOT INSTALLED"
    @which zig 2>/dev/null && zig version || echo "Zig: NOT INSTALLED"
