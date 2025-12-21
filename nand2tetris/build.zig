const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ---- types module ----
    const types_mod = b.createModule(.{
        .root_source_file = b.path("src/types/mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ---- gates module ----
    const gates_mod = b.createModule(.{
        .root_source_file = b.path("src/gates/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    gates_mod.addImport("types", types_mod);

    // ---- memory module ----
    const memory_mod = b.createModule(.{
        .root_source_file = b.path("src/memory/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    memory_mod.addImport("types", types_mod);
    memory_mod.addImport("gates", gates_mod);

    // ---- root module (src/) ----
    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // make `@import("types")`, `@import("gates")` and `@import("memory")` work
    root_mod.addImport("types", types_mod);
    root_mod.addImport("gates", gates_mod);
    root_mod.addImport("memory", memory_mod);

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
    const types_tests = b.addTest(.{ .root_module = types_mod, .name = "test-types" });
    const gates_tests = b.addTest(.{ .root_module = gates_mod, .name = "test-gates" });
    const memory_tests = b.addTest(.{ .root_module = memory_mod, .name = "test-memory" });

    const run_types_tests = b.addRunArtifact(types_tests);
    const run_gates_tests = b.addRunArtifact(gates_tests);
    const run_memory_tests = b.addRunArtifact(memory_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_types_tests.step);
    test_step.dependOn(&run_gates_tests.step);
    test_step.dependOn(&run_memory_tests.step);

    b.installArtifact(types_tests);
    b.installArtifact(gates_tests);
    b.installArtifact(memory_tests);
}
