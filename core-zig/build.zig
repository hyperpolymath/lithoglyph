// SPDX-License-Identifier: PMPL-1.0-or-later
// Form.Bridge - Build Configuration

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main library
    const lib = b.addStaticLibrary(.{
        .name = "formdb_bridge",
        .root_source_file = b.path("src/bridge.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Also build shared library for FFI
    const shared_lib = b.addSharedLibrary(.{
        .name = "formdb_bridge",
        .root_source_file = b.path("src/bridge.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Export C ABI
    lib.root_module.addCMacro("FDB_EXPORT", "");
    shared_lib.root_module.addCMacro("FDB_EXPORT", "");

    // Install artifacts
    b.installArtifact(lib);
    b.installArtifact(shared_lib);

    // Unit tests for bridge
    const bridge_tests = b.addTest(.{
        .root_source_file = b.path("src/bridge.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_bridge_tests = b.addRunArtifact(bridge_tests);

    // Unit tests for blocks
    const blocks_tests = b.addTest(.{
        .root_source_file = b.path("src/blocks.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_blocks_tests = b.addRunArtifact(blocks_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_bridge_tests.step);
    test_step.dependOn(&run_blocks_tests.step);
}
