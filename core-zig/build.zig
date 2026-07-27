// SPDX-License-Identifier: MPL-2.0
// Form.Bridge - Build Configuration (Zig 0.15.2+)

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main static library
    const lib = b.addLibrary(.{
        .name = "lith_bridge",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bridge.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });

    // Also build shared library for FFI
    const shared_lib = b.addLibrary(.{
        .name = "lith_bridge",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bridge.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
    });

    // Install artifacts
    b.installArtifact(lib);
    b.installArtifact(shared_lib);

    // Unit tests for bridge
    const bridge_tests = b.addTest(.{
        .name = "bridge-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bridge.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_bridge_tests = b.addRunArtifact(bridge_tests);

    // Unit tests for blocks
    const blocks_tests = b.addTest(.{
        .name = "blocks-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/blocks.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Unit tests for crypto.
    //
    // `.filters` restricts this binary to its own three tests. crypto_test.zig
    // legitimately `@import("blocks.zig")` — it needs Block.init and
    // Block.deriveKey — and Zig compiles every `test` block of an imported file
    // into the importing binary. Without a filter this binary also runs all
    // nine blocks.zig tests, so `zig build test` executes them twice, in two
    // binaries, concurrently, in the same working directory. Several of them
    // open fixed filenames (test_alloc.lgh, test_blocks.lgh, test_journal.lgh),
    // so the two copies race for the same file and the loser sees the winner's
    // data:
    //
    //   error: 'blocks.test.block allocation and write' failed: expected 1, found 2
    //
    // Intermittent by nature — it depends which binary wins — which is why the
    // same commit passed and failed on consecutive runs with no change.
    //
    // This was latent, not new: until the `_crypto_tests` typo was fixed this
    // binary never built, so the blocks tests only ever ran once. Enabling the
    // crypto suite is what made the collision reachable.
    //
    // Filtering is the right fix rather than renaming the fixtures: running the
    // blocks suite twice was never intended and costs time for no coverage.
    // blocks_tests above still runs all nine.
    const crypto_tests = b.addTest(.{
        .name = "crypto-tests",
        .filters = &.{"crypto"},
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/crypto_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_blocks_tests = b.addRunArtifact(blocks_tests);
    const run_crypto_tests = b.addRunArtifact(crypto_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_bridge_tests.step);
    test_step.dependOn(&run_blocks_tests.step);
    test_step.dependOn(&run_crypto_tests.step);
}
