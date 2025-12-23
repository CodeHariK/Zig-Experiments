const std = @import("std");
const rl = @import("raylib");

const math = @import("math.zig");
const ray = @import("ray.zig");
const hittable = @import("hittable.zig");
const Vec3 = math.Vec3;
const Ray = ray.Ray;
const Point3 = ray.Point3;
const HittableList = hittable.HittableList;
const Hittable = hittable.Hittable;
const Sphere = hittable.Sphere;
const HitRecord = hittable.HitRecord;

const Color = @import("color.zig").Color;

const ASPECT_RATIO = 16.0 / 9.0;
const IMAGE_WIDTH = 800.0;
const IMAGE_HEIGHT = IMAGE_WIDTH / ASPECT_RATIO;

const FOCAL_LENGTH = 1.0;
const VIEWPORT_HEIGHT = 2.0;
const VIEWPORT_WIDTH = VIEWPORT_HEIGHT * ASPECT_RATIO;

// Viewport vectors: U goes right, V goes down (negative Y)
const VIEWPORT_U = Vec3.init(.{ VIEWPORT_WIDTH, 0.0, 0.0 });
const VIEWPORT_V = Vec3.init(.{ 0.0, -VIEWPORT_HEIGHT, 0.0 });

// Pixel spacing: how much to move for each pixel
const PIXEL_DELTA_U = VIEWPORT_U.divScalar(IMAGE_WIDTH);
const PIXEL_DELTA_V = VIEWPORT_V.divScalar(IMAGE_HEIGHT);

const CAMERA_CENTER = Vec3.init(.{ 0.0, 0.0, 0.0 });

// Calculate the location of the upper left pixel.
//
// Explanation:
// 1. Start at camera center
// 2. Move back by focal_length along -Z axis (camera looks down -Z)
// 3. Move left by half the viewport width (viewport_u/2)
// 4. Move up by half the viewport height (viewport_v/2, but V is negative so this moves up)
// This gives us the upper-left corner of the viewport
const VIEWPORT_UPPER_LEFT = CAMERA_CENTER
    .sub(Vec3.init(.{ 0.0, 0.0, FOCAL_LENGTH }))
    .sub(VIEWPORT_U.divScalar(2.0))
    .sub(VIEWPORT_V.divScalar(2.0));

// Pixel00 is the center of the first pixel (upper-left pixel)
// We offset by half a pixel in both U and V directions to get the pixel center
const PIXEL00_LOC = VIEWPORT_UPPER_LEFT
    .add(PIXEL_DELTA_U.mulScalar(0.5))
    .add(PIXEL_DELTA_V.mulScalar(0.5));

pub fn main() !void {
    const image_width_int = @as(i32, @intFromFloat(IMAGE_WIDTH));
    const image_height_int = @as(i32, @intFromFloat(IMAGE_HEIGHT));

    // Initialize raylib window
    rl.initWindow(image_width_int, image_height_int, "Raytracer");
    defer rl.closeWindow();

    // Create world with hittable objects
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var world = HittableList.init(allocator);
    defer world.deinit();

    // Add a sphere to the world
    try world.add(Hittable{ .sphere = Sphere.init(Point3.init(.{ 0.0, 0.0, -1.0 }), 0.5) });
    try world.add(Hittable{ .sphere = Sphere.init(Point3.init(.{ 0.0, -100.5, -1.0 }), 100.0) });

    // Create image buffer to render to
    var image = rl.Image.genColor(image_width_int, image_height_int, .purple);
    defer image.unload();

    // Render the image
    // Note: j goes from top to bottom (0 to image_height-1)
    var j: i32 = 0;
    while (j < image_height_int) : (j += 1) {
        var i: i32 = 0;
        while (i < image_width_int) : (i += 1) {
            // Calculate pixel center position
            const i_f64 = @as(f64, @floatFromInt(i));
            const j_f64 = @as(f64, @floatFromInt(j));
            const pixel_center = PIXEL00_LOC
                .add(PIXEL_DELTA_U.mulScalar(i_f64))
                .add(PIXEL_DELTA_V.mulScalar(j_f64));

            // Calculate ray direction (from camera center to pixel center)
            const ray_direction = pixel_center.sub(CAMERA_CENTER);

            // Create ray from camera center through pixel center
            const r = Ray.init(CAMERA_CENTER, ray_direction);

            // Get color for this ray
            const color = ray_color(r, &world);

            image.drawPixel(i, j, color);
        }
    }

    // Convert image to texture for display
    const texture = try rl.Texture2D.fromImage(image);
    defer texture.unload();

    // Main loop - display the rendered image
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);
        rl.drawTexture(texture, 0, 0, .white);
    }
}

fn ray_color(r: Ray, world: *const HittableList) rl.Color {
    var rec = HitRecord{
        .p = undefined,
        .normal = undefined,
        .t = 0,
        .front_face = false,
    };

    // Check if ray hits anything in the world
    if (world.hit(r, 0, std.math.inf(f64), &rec)) {
        // Color = 0.5 * (normal + white)
        // This adds white (1,1,1) to normal (components in [-1,1]), giving [0,2]
        // Then scales by 0.5 to get [0,1] range
        const color_vec = rec.normal.addScalar(1.0).mulScalar(0.5);
        return Color.fromVec3(color_vec).toRlColor();
    }

    // Otherwise, return sky gradient
    // Get unit direction vector
    const unit_direction = r.dir.unit();

    // Normalize Y component from [-1, 1] to [0, 1]
    // When y = -1 (pointing down), a = 0 (white)
    // When y = 1 (pointing up), a = 1 (light blue)
    const a = 0.5 * (unit_direction.y() + 1.0);

    // Linear interpolation: (1-a)*white + a*light_blue
    const white = Color.init(1.0, 1.0, 1.0);
    const light_blue = Color.init(0.5, 0.7, 1.0);
    const color = white.blend(light_blue, a);

    return color.toRlColor();
}
