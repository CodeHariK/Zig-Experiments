const std = @import("std");
const vec = @import("../math/vec3.zig");

pub fn writePPMImage(
    img_width: f32,
    img_height: f32,
    comptime write_fn: fn (w: *std.Io.Writer, img_width: f32, img_height: f32) anyerror!void,
) !void {
    var buffer: [4096]u8 = undefined;
    var out = (try std.fs.cwd().createFile("image.ppm", .{})).writer(&buffer);
    defer out.file.close();

    try out.interface.print("P3\n{d} {d}\n255\n", .{ img_width, img_height });

    try write_fn(&out.interface, img_width, img_height);

    try out.interface.flush();
}

pub fn createGradientMap(out: *std.Io.Writer, img_width: f32, img_height: f32, x_offset: f32, y_offset: f32, x_size: f32, y_size: f32) !void {
    if (x_size <= 0 or y_size <= 0 or
        x_offset < 0 or y_offset < 0 or
        x_offset + x_size > img_width or y_offset + y_size > img_height)
    {
        return error.InvalidGradientSize;
    }

    std.debug.print("createGradientMap: {d}x{d} @ ({d}, {d})\n", .{ x_size, y_size, x_offset, y_offset });

    var h: f32 = y_offset;
    while (h < y_offset + y_size) : (h += 1.0) {
        var w: f32 = x_offset;
        while (w < x_offset + x_size) : (w += 1.0) {
            const pixel: vec.Vec3 = .{
                w / img_width,
                h / img_height,
                0,
            };

            try out.print("{f}", .{vec.Color{ .data = pixel }});
        }
    }
}
