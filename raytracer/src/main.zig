const std = @import("std");
const rl = @import("raylib");
const rui = @import("raygui");
const ray = @import("ray.zig");
const hittable = @import("hittable.zig");
const camera_mod = @import("camera.zig");
const math = @import("math.zig");

const Point3 = ray.Point3;
const HittableList = hittable.HittableList;
const Hittable = hittable.Hittable;
const Sphere = hittable.Sphere;
const Camera = camera_mod.Camera;

pub fn main() !void {

    // Initialize raylib window
    const image_width: f64 = 800.0;
    const image_height: f64 = image_width / (16.0 / 9.0);
    const image_width_int = @as(i32, @intFromFloat(image_width));
    const image_height_int = @as(i32, @intFromFloat(image_height));

    rl.initWindow(image_width_int, image_height_int, "Raytracer");
    defer rl.closeWindow();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create world with hittable objects
    var world = HittableList.init(allocator);
    defer world.deinit();

    // Add spheres to the world
    try world.add(Hittable{ .sphere = Sphere.init(Point3.init(.{ 0.0, 0.0, -1.0 }), 0.5) });
    try world.add(Hittable{ .sphere = Sphere.init(Point3.init(.{ 0.0, -100.5, -1.0 }), 100.0) });

    // Create and initialize camera
    var cam = Camera.init();

    // Render the world and measure time
    var timer = try std.time.Timer.start();

    var image = try cam.render(&world);
    defer image.unload();

    const render_time_ns = timer.read();
    const render_time_ms = @as(f64, @floatFromInt(render_time_ns)) / 1_000_000.0;
    var render_time_buf: [64]u8 = undefined;
    const render_time_text = try std.fmt.bufPrintZ(&render_time_buf, "Render time: {d:.2} ms", .{render_time_ms});

    // Convert image to texture for display
    const texture = try rl.Texture2D.fromImage(image);
    defer texture.unload();

    // Main loop - display the rendered image
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);
        rl.drawTexture(texture, 0, 0, .white);

        // Display render time
        rl.drawText(render_time_text, 10, 10, 20, .white);
    }
}
