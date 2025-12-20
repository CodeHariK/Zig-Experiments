const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ---- gates module ----
    const gates_mod = b.createModule(.{
        .root_source_file = b.path("src/gates/logic.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ---- memory module ----
    const memory_mod = b.createModule(.{
        .root_source_file = b.path("src/memory/dff.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ---- root module (src/) ----
    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // make `@import("gates")` and `@import("memory")` work
    root_mod.addImport("gates", gates_mod);
    root_mod.addImport("memory", memory_mod);

    // Memory module needs access to gates module
    memory_mod.addImport("gates", gates_mod);

    // ---- executable ----
    const exe = b.addExecutable(.{
        .name = "nand2tetris",
        .root_module = root_mod,
    });

    b.installArtifact(exe);

    // ---- run exe ----
    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // ---- tests ----
    // Test root module (includes memory tests)
    const tests = b.addTest(.{
        .root_module = root_mod,
        .name = "test-root", // Unique name to avoid conflicts
    });

    const run_tests = b.addRunArtifact(tests);

    // Also test gates module directly to ensure all gates tests are included
    const gates_tests = b.addTest(.{
        .root_module = gates_mod,
        .name = "test-gates", // Unique name to avoid conflicts
    });

    const run_gates_tests = b.addRunArtifact(gates_tests);

    // Also test memory module directly to ensure all memory tests are included
    const memory_tests = b.addTest(.{
        .root_module = memory_mod,
        .name = "test-memory", // Unique name to avoid conflicts
    });

    const run_memory_tests = b.addRunArtifact(memory_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_gates_tests.step);
    test_step.dependOn(&run_memory_tests.step);

    // IMPORTANT:
    // install test binaries so you can run them manually
    // and see std.debug.print output
    b.installArtifact(tests);
    b.installArtifact(gates_tests);
    b.installArtifact(memory_tests);
}
