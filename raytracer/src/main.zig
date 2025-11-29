const std = @import("std");
const vec = @import("vec.zig");

const aspect_ratio = 16.0 / 9.0;
const img_width = 256.0;
const img_height = blk: {
    const h: comptime_int = @intFromFloat(img_width / aspect_ratio);
    break :blk @max(h, 1); // Ensure minimum of 1
};

const focal_length = 1.0;
const viewport_height = 2.0;
const viewport_width = viewport_height * (img_width + 0.0) / (img_height - 0.0);
const camera_center: vec.Vec3 = vec.zero;

pub fn main() !void {
    var buffer: [4096]u8 = undefined;
    var out = (try std.fs.cwd().createFile("image.ppm", .{})).writer(&buffer);
    defer out.file.close();

    try writePPM(&out.interface);

    try out.interface.flush();
}

pub fn writePPM(out: *std.Io.Writer) !void {
    try out.print("P3\n{d} {d}\n255\n", .{ img_width, img_height });

    for (0..img_height) |h| {
        for (0..img_width) |w| {
            const fh: f32 = @floatFromInt(h);
            const fw: f32 = @floatFromInt(w);

            const pixel: vec.Vec3 = .{
                fw / img_width,
                fh / img_height,
                0,
            };

            try out.print("{f}", .{vec.Color{ .data = pixel }});
        }
    }
}
