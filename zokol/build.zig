const std = @import("std");
const shdc = @import("shdc");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    // Compile shaders
    const shader_step = try shdc.createSourceFile(b, .{
        .shdc_dep = b.dependency("shdc", .{}),
        .input = "src/shaders/triangle.glsl",
        .output = "src/shaders/triangle.glsl.zig",
        .slang = .{
            .glsl430 = false,
            .glsl410 = false,
            .glsl300es = false,
            .metal_macos = true,
            .hlsl5 = false,
            .wgsl = false,
        },
    });

    const exe = b.addExecutable(.{
        .name = "zokol",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.step.dependOn(shader_step);

    const sokol_dep = b.dependency("sokol_zig", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("sokol", sokol_dep.module("sokol"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_tests.step);
}
