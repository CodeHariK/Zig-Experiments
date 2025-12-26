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

    // ---- logic module ----
    const logic_mod = b.createModule(.{
        .root_source_file = b.path("src/logic/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    logic_mod.addImport("types", types_mod);

    // ---- memory module ----
    const memory_mod = b.createModule(.{
        .root_source_file = b.path("src/memory/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    memory_mod.addImport("types", types_mod);
    memory_mod.addImport("logic", logic_mod);

    // ---- machine_language module ----
    const machine_language_mod = b.createModule(.{
        .root_source_file = b.path("src/machine_language/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    machine_language_mod.addImport("types", types_mod);

    // ---- machine module ----
    const machine_mod = b.createModule(.{
        .root_source_file = b.path("src/machine/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    machine_mod.addImport("types", types_mod);
    machine_mod.addImport("logic", logic_mod);
    machine_mod.addImport("memory", memory_mod);

    // ---- root module (src/) ----
    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // make `@import("types")`, `@import("logic")`, `@import("memory")`, etc. work
    root_mod.addImport("types", types_mod);
    root_mod.addImport("logic", logic_mod);
    root_mod.addImport("memory", memory_mod);
    root_mod.addImport("machine", machine_mod);

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
    const logic_tests = b.addTest(.{ .root_module = logic_mod, .name = "test-logic" });
    const memory_tests = b.addTest(.{ .root_module = memory_mod, .name = "test-memory" });
    const machine_language_tests = b.addTest(.{ .root_module = machine_language_mod, .name = "test-machine-language" });
    const machine_tests = b.addTest(.{ .root_module = machine_mod, .name = "test-machine" });

    const run_types_tests = b.addRunArtifact(types_tests);
    const run_logic_tests = b.addRunArtifact(logic_tests);
    const run_memory_tests = b.addRunArtifact(memory_tests);
    const run_machine_language_tests = b.addRunArtifact(machine_language_tests);
    const run_machine_tests = b.addRunArtifact(machine_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_types_tests.step);
    test_step.dependOn(&run_logic_tests.step);
    test_step.dependOn(&run_memory_tests.step);
    test_step.dependOn(&run_machine_language_tests.step);
    test_step.dependOn(&run_machine_tests.step);

    b.installArtifact(types_tests);
    b.installArtifact(logic_tests);
    b.installArtifact(memory_tests);
    b.installArtifact(machine_language_tests);
    b.installArtifact(machine_tests);
}
