const std = @import("std");
const vec = @import("../math/vec3.zig");
const cast = @import("../cast.zig").cast;

pub const Image = struct {
    width: usize,
    height: usize,
    pixels: []vec.Vec3,

    pub fn init(allocator: *const std.mem.Allocator, width: usize, height: usize) !Image {
        const pixels = try allocator.alloc(vec.Vec3, width * height);
        for (pixels) |*p| p.* = .{ 0, 0, 0 }; // initialize to black
        return Image{ .width = width, .height = height, .pixels = pixels };
    }

    pub fn deinit(self: *Image, allocator: *const std.mem.Allocator) void {
        allocator.free(self.pixels);
    }

    pub fn setPixel(self: *Image, x: usize, y: usize, color: vec.Vec3) void {
        self.pixels[y * self.width + x] = color;
    }

    pub fn getPixel(self: *Image, x: usize, y: usize) vec.Vec3 {
        return self.pixels[y * self.width + x];
    }

    pub fn writePPM(self: *Image, path: []const u8) !void {
        const buffer_size = 16 * 1024; // 16 KB buffer
        var buffer: [buffer_size]u8 = undefined;

        var file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        var out = file.writer(&buffer);

        // Write PPM header
        try out.interface.print("P3\n{d} {d}\n255\n", .{ self.width, self.height });

        // Write pixels
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                try out.interface.print("{f}", .{vec.Color{ .data = self.getPixel(x, y) }});
            }
        }

        // Flush buffer to file
        try out.interface.flush();
    }

    pub fn drawRect(self: *Image, x_offset: usize, y_offset: usize, x_size: usize, y_size: usize, color: vec.Vec3) void {
        const w_max = x_size;
        const h_max = y_size;

        for (0..h_max) |dy| {
            const y = y_offset + dy;
            if (y >= self.height) break;
            for (0..w_max) |dx| {
                const x = x_offset + dx;
                if (x >= self.width) break;
                self.setPixel(x, y, color);
            }
        }
    }

    pub fn drawCircle(out: *Image, cx: isize, cy: isize, r: usize, color: vec.Vec3) void {
        var x: isize = 0;
        var y: isize = @intCast(r);
        var d: isize = 1 - cast(isize, r);

        while (x <= y) {
            _plotCirclePoints(out, cx, cy, x, y, color);

            if (d < 0) {
                d += 2 * x + 3;
            } else {
                d += 2 * (x - y) + 5;
                y -= 1;
            }
            x += 1;
        }
    }
    inline fn _plotCirclePoints(out: *Image, cx: isize, cy: isize, x: isize, y: isize, color: vec.Vec3) void {
        // Reflect the computed point to 8 octants
        _plotPixel(out, cx + x, cy + y, color);
        _plotPixel(out, cx - x, cy + y, color);
        _plotPixel(out, cx + x, cy - y, color);
        _plotPixel(out, cx - x, cy - y, color);
        _plotPixel(out, cx + y, cy + x, color);
        _plotPixel(out, cx - y, cy + x, color);
        _plotPixel(out, cx + y, cy - x, color);
        _plotPixel(out, cx - y, cy - x, color);
    }
    inline fn _plotPixel(out: *Image, x: isize, y: isize, color: vec.Vec3) void {
        if (x >= 0 and y >= 0 and x < out.width and y < out.height) {
            out.pixels[@as(usize, @intCast(y)) * out.width + @as(usize, @intCast(x))] = color;
        }
    }

    pub fn drawGradient(self: *Image, x_offset: usize, y_offset: usize, x_size: usize, y_size: usize) void {
        if (x_offset + x_size > self.width or y_offset + y_size > self.height) {
            return;
        }

        const w_max = x_size;
        const h_max = y_size;

        for (0..h_max) |dy| {
            const y = y_offset + dy;
            if (y >= self.height) break;
            for (0..w_max) |dx| {
                const x = x_offset + dx;
                if (x >= self.width) break;
                const pixel: vec.Vec3 = .{
                    @as(f32, @floatFromInt(dx)) / @as(f32, @floatFromInt(w_max)),
                    @as(f32, @floatFromInt(dy)) / @as(f32, @floatFromInt(h_max)),
                    0,
                };

                self.setPixel(x, y, pixel);
            }
        }
    }
};

pub fn writePPMImage(
    img_width: usize,
    img_height: usize,
    comptime write_fn: fn (w: *Image, img_width: usize, img_height: usize) anyerror!void,
) !void {
    const allocator = std.heap.page_allocator;
    var img = try Image.init(&allocator, img_width, img_height);
    defer img.deinit(&allocator);

    try write_fn(&img, img_width, img_height);

    try img.writePPM("image.ppm");
}
