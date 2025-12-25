const std = @import("std");
const rl = @import("raylib");
const ray = @import("ray.zig");
const hittable = @import("hittable.zig");
const camera_mod = @import("camera.zig");
const math = @import("math.zig");
const material_mod = @import("material.zig");

const Point3 = ray.Point3;
const HittableList = hittable.HittableList;
const Hittable = hittable.Hittable;
const Sphere = hittable.Sphere;
const Camera = camera_mod.Camera;

const Material = material_mod.Material;
const Lambertian = material_mod.Lambertian;
const Metal = material_mod.Metal;
const Dielectric = material_mod.Dielectric;

const Color = math.Vec3;
const Vec3 = math.Vec3;

// Helper function to generate a random color in [0, 1)
fn randomColor(rand: *math.Rand) Color {
    return Color.init(.{
        rand.randomDouble(),
        rand.randomDouble(),
        rand.randomDouble(),
    });
}

// Helper function to generate a random color in [min, max)
fn randomColorMinMax(rand: *math.Rand, min: f64, max: f64) Color {
    return Color.init(.{
        rand.randomDoubleMinMax(min, max),
        rand.randomDoubleMinMax(min, max),
        rand.randomDoubleMinMax(min, max),
    });
}

pub fn main() !void {

    // Initialize raylib window
    const aspect_ratio: f64 = 16.0 / 9.0;
    const image_width: f64 = 800.0;
    const image_height: f64 = image_width / aspect_ratio;
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

    // Initialize random number generator
    var rand = math.Rand.init(@bitCast(std.time.timestamp()));

    // Ground sphere
    const ground_material = Lambertian.init(Color.init(.{ 0.5, 0.5, 0.5 }));
    try world.add(Hittable{ .sphere = Sphere.init(Point3.init(.{ 0.0, -1000.0, 0.0 }), 1000.0, ground_material) });

    // Create a grid of random spheres
    const sphere_count = 4;
    var a: i32 = -sphere_count;
    while (a < sphere_count) : (a += 1) {
        var b: i32 = -sphere_count;
        while (b < sphere_count) : (b += 1) {
            const choose_mat = rand.randomDouble();
            const center = Point3.init(.{
                @as(f64, @floatFromInt(a)) + 0.9 * rand.randomDouble(),
                0.2,
                @as(f64, @floatFromInt(b)) + 0.9 * rand.randomDouble(),
            });

            // Skip spheres too close to the large sphere at (4, 0.2, 0)
            const to_large_sphere = center.sub(Point3.init(.{ 4.0, 0.2, 0.0 }));
            if (to_large_sphere.length() > 0.9) {
                if (choose_mat < 0.8) {
                    // Diffuse material
                    const albedo = randomColor(&rand).mul(randomColor(&rand));
                    const sphere_material = Lambertian.init(albedo);
                    try world.add(Hittable{ .sphere = Sphere.init(center, 0.2, sphere_material) });
                } else if (choose_mat < 0.95) {
                    // Metal material
                    const albedo = randomColorMinMax(&rand, 0.5, 1.0);
                    const fuzz = rand.randomDoubleMinMax(0.0, 0.5);
                    const sphere_material = Metal.init(albedo, fuzz);
                    try world.add(Hittable{ .sphere = Sphere.init(center, 0.2, sphere_material) });
                } else {
                    // Glass material
                    const sphere_material = Dielectric.init(1.5);
                    try world.add(Hittable{ .sphere = Sphere.init(center, 0.2, sphere_material) });
                }
            }
        }
    }

    // Three large spheres
    const material1 = Dielectric.init(1.5);
    try world.add(Hittable{ .sphere = Sphere.init(Point3.init(.{ 0.0, 1.0, 0.0 }), 1.0, material1) });

    const material2 = Lambertian.init(Color.init(.{ 0.4, 0.2, 0.1 }));
    try world.add(Hittable{ .sphere = Sphere.init(Point3.init(.{ -4.0, 1.0, 0.0 }), 1.0, material2) });

    const material3 = Metal.init(Color.init(.{ 0.7, 0.6, 0.5 }), 0.0);
    try world.add(Hittable{ .sphere = Sphere.init(Point3.init(.{ 4.0, 1.0, 0.0 }), 1.0, material3) });

    // Create and initialize camera
    var cam = Camera.init(.{
        .aspect_ratio = aspect_ratio,
        .image_width = image_width,
        .samples_per_pixel = 8,
        .max_depth = 8,
        .vfov = 20.0,
        .lookfrom = Point3.init(.{ 13.0, 2.0, 3.0 }),
        .lookat = Point3.init(.{ 0.0, 0.0, 0.0 }),
        .vup = Vec3.init(.{ 0.0, 1.0, 0.0 }),
        .defocus_angle = 0.6,
        .focus_dist = 10.0,
    });

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
