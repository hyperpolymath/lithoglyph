// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell (@hyperpolymath)
//
// build.zig - FormBD FFI Build Configuration

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build shared library for FFI
    const lib = b.addSharedLibrary(.{
        .name = "formbd",
        .root_source_file = b.path("src/bridge.zig"),
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 0, .minor = 6, .patch = 5 },
    });

    // Link against proven library (Idris2 output)
    // TODO: Add proven library linking once it's built
    // lib.linkSystemLibrary("proven");

    // Link against Forth/Factor runtime
    // TODO: Add Form.Blocks, Form.Model linking
    // lib.linkSystemLibrary("formbd_blocks");

    // Export C symbols for FFI
    lib.linkLibC();

    b.installArtifact(lib);

    // Build tests
    const tests = b.addTest(.{
        .root_source_file = b.path("test/ffi_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    tests.root_module.addImport("formbd", &lib.root_module);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run FFI tests");
    test_step.dependOn(&run_tests.step);

    // Integration tests
    const integration_tests = b.addTest(.{
        .root_source_file = b.path("test/integration_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    integration_tests.root_module.addImport("formbd", &lib.root_module);

    const run_integration = b.addRunArtifact(integration_tests);
    const integration_step = b.step("integration", "Run integration tests");
    integration_step.dependOn(&run_integration.step);

    // Seam tests (test integration points)
    const seam_tests = b.addTest(.{
        .root_source_file = b.path("test/seam_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    seam_tests.root_module.addImport("formbd", &lib.root_module);

    const run_seam = b.addRunArtifact(seam_tests);
    const seam_step = b.step("seam", "Run seam tests (integration boundaries)");
    seam_step.dependOn(&run_seam.step);
}
