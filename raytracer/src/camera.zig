const std = @import("std");
const rl = @import("raylib");
const math = @import("math.zig");

const ray = @import("ray.zig");
const hittable = @import("hittable.zig");
const interval = @import("interval.zig");
const color_mod = @import("color.zig");

const Vec3 = math.Vec3;
const Point3 = ray.Point3;
const Ray = ray.Ray;
const HittableList = hittable.HittableList;
const HitRecord = hittable.HitRecord;
const Interval = interval.Interval;
const Color = color_mod.Color;
const ColorExt = color_mod.ColorExt;

pub const Camera = struct {
    // Public camera parameters
    aspect_ratio: f64 = 16.0 / 9.0,
    image_width: f64 = 800.0,
    image_height: f64 = undefined,

    // Private camera variables (computed during initialization)
    camera_center: Point3 = undefined,

    focal_length: f64 = 1.0,
    viewport_height: f64 = 2.0,
    viewport_width: f64 = undefined,
    viewport_u: Vec3 = undefined,
    viewport_v: Vec3 = undefined,

    pixel_delta_u: Vec3 = undefined,
    pixel_delta_v: Vec3 = undefined,
    pixel00_loc: Point3 = undefined,

    samples_per_pixel: u8 = 8, // Number of samples per pixel for antialiasing
    pixel_samples_scale: f64 = undefined, // Color scale factor for a sum of pixel samples
    max_depth: u8 = 8, // Maximum ray bounce depth to prevent infinite recursion

    pub var rand: math.Rand = undefined;

    const Self = @This();

    // Initialize camera parameters
    pub fn init() Self {
        var self = Self{
            .aspect_ratio = 16.0 / 9.0,
            .image_width = 800.0,
            .focal_length = 1.0,
            .viewport_height = 2.0,
        };

        Self.rand = math.Rand.init(@bitCast(std.time.timestamp()));

        // Compute derived values
        self.image_height = self.image_width / self.aspect_ratio;
        self.viewport_width = self.viewport_height * self.aspect_ratio;

        // Camera center (origin)
        self.camera_center = Point3.init(.{ 0.0, 0.0, 0.0 });

        // Viewport vectors: U goes right, V goes down (negative Y)
        self.viewport_u = Vec3.init(.{ self.viewport_width, 0.0, 0.0 });
        self.viewport_v = Vec3.init(.{ 0.0, -self.viewport_height, 0.0 });

        // Pixel spacing: how much to move for each pixel
        self.pixel_delta_u = self.viewport_u.divScalar(self.image_width);
        self.pixel_delta_v = self.viewport_v.divScalar(self.image_height);

        // Calculate the location of the upper left pixel.
        //
        // Explanation:
        // 1. Start at camera center
        // 2. Move back by focal_length along -Z axis (camera looks down -Z)
        // 3. Move left by half the viewport width (viewport_u/2)
        // 4. Move up by half the viewport height (viewport_v/2, but V is negative so this moves up)
        // This gives us the upper-left corner of the viewport
        const viewport_upper_left = self.camera_center
            .sub(Vec3.init(.{ 0.0, 0.0, self.focal_length }))
            .sub(self.viewport_u.add(self.viewport_v).divScalar(2.0));

        // Pixel00 is the center of the first pixel (upper-left pixel)
        // We offset by half a pixel in both U and V directions to get the pixel center
        self.pixel00_loc = viewport_upper_left
            .add(self.pixel_delta_u.add(self.pixel_delta_v).mulScalar(0.5));

        // Compute pixel samples scale
        self.pixel_samples_scale = 1.0 / @as(f64, @floatFromInt(self.samples_per_pixel));

        return self;
    }

    // Construct a camera ray originating from the origin and directed at randomly sampled
    // point around the pixel location i, j
    fn getRay(self: *Self, i: i32, j: i32) Ray {
        const offset = Self.rand.vec3SampleSquare();
        const i_f64 = @as(f64, @floatFromInt(i));
        const j_f64 = @as(f64, @floatFromInt(j));
        const pixel_sample = self.pixel00_loc
            .add(self.pixel_delta_u.mulScalar(i_f64 + offset.x()))
            .add(self.pixel_delta_v.mulScalar(j_f64 + offset.y()));

        const ray_origin = self.camera_center;
        const ray_direction = pixel_sample.sub(ray_origin);

        return Ray.init(ray_origin, ray_direction);
    }

    // Render the world to an image
    pub fn render(self: *Self, world: *const HittableList) !rl.Image {
        const image_width_int = @as(i32, @intFromFloat(self.image_width));
        const image_height_int = @as(i32, @intFromFloat(self.image_height));

        // Create image buffer to render to
        var image = rl.Image.genColor(image_width_int, image_height_int, .purple);

        // Render the image with anti-aliasing
        // Note: j goes from top to bottom (0 to image_height-1)
        var j: i32 = 0;
        while (j < image_height_int) : (j += 1) {
            var i: i32 = 0;
            while (i < image_width_int) : (i += 1) {
                // Accumulate color from multiple samples
                var pixel_color_accum = Color.zero();
                var sample: u8 = 0;
                while (sample < self.samples_per_pixel) : (sample += 1) {
                    const r = self.getRay(i, j);
                    const sample_color = self.rayColor(r, world, self.max_depth);
                    pixel_color_accum.addAssign(sample_color);
                }

                // Scale by pixel_samples_scale and convert back to Raylib color
                const final_color_vec = pixel_color_accum.mulScalar(self.pixel_samples_scale);
                const final_color = ColorExt.toRlColor(final_color_vec);

                image.drawPixel(i, j, final_color);
            }
        }

        return image;
    }

    /// Calculate the color of a ray
    fn rayColor(self: *const Self, r: Ray, world: *const HittableList, depth: u32) Color {
        // If we've exceeded max depth, no more light is gathered from this path
        if (depth <= 0) {
            return Color.zero();
        }

        var rec = HitRecord{
            .p = undefined,
            .normal = undefined,
            .t = 0,
            .front_face = false,
        };

        // Check if ray hits anything in the world
        const ray_t = Interval.initWithBounds(0.001, std.math.inf(f64));
        if (world.hit(r, ray_t, &rec)) {
            return self.scatterLambertian(&rec, world, depth);
            // return self.scatterBounceColor(&rec, world, depth);
            // return self.normalColor(&rec);
        }

        // Ray missed everything - it hit the sky (our light source)
        // The sky color is a gradient from white (top) to light blue (bottom)
        // This is where light comes from in path tracing
        // HOW SHADOWS FORM:
        // When scattered rays hit other objects before reaching sky (light source):
        //   - They bounce again (recursive call)
        //   - Each bounce multiplies by 0.5 (attenuation)
        //   - Areas where rays hit objects before sky → darker → shadows!
        // Example: scattered ray → hits ground → bounces → sky = 0.5 * light (darker)
        //          scattered ray → hits ground → hits sphere → bounces → sky = 0.25 * light (shadow!)
        const unit_direction = r.dir.unit();
        const a = 0.5 * (unit_direction.y() + 1.0);
        const color = ColorExt.blend(WHITE, SKY, a);
        return color;
    }

    // Hemisphere-based scattering: uniform distribution on hemisphere
    // All directions above surface have equal probability
    // This function recursively traces rays through the scene:
    // - If ray hits a surface: bounce in random direction (diffuse material), attenuate by 0.5
    // - If ray misses everything: return sky gradient color
    // - If max_depth reached: return black (no light contribution from this path)
    // The color accumulates as we unwind the recursion: each bounce multiplies by 0.5
    inline fn scatterBounceColor(self: *const Self, rec: *const HitRecord, world: *const HittableList, depth: u32) Color {
        // Diffuse material: scatter ray in random direction on hemisphere above surface
        // vec3RandomOnHemisphere ensures the scattered ray is above the surface (not going into it)
        // This creates a uniform distribution on the hemisphere
        const direction = Self.rand.vec3RandomOnHemisphere(rec.normal);

        // ATTENUATION: When light bounces off a surface, not all light is reflected.
        // Some light is absorbed by the material. The 0.5 factor represents the material's
        // "albedo" (reflectivity) - in this case, 50% of light is reflected, 50% is absorbed.
        //
        // Example: If a ray with intensity 1.0 hits a surface:
        //   - After 1 bounce: 1.0 * 0.5 = 0.5 (50% reflected)
        //   - After 2 bounces: 0.5 * 0.5 = 0.25 (25% of original)
        //   - After 3 bounces: 0.25 * 0.5 = 0.125 (12.5% of original)
        // This creates realistic light falloff - objects get darker the more bounces away from light.
        //
        // In a real raytracer, different materials would have different albedos:
        //   - White paint: ~0.9 (reflects 90%)
        //   - Gray concrete: ~0.5 (reflects 50%)
        //   - Dark wood: ~0.2 (reflects 20%)
        return self.rayColor(Ray.init(rec.p, direction), world, depth - 1).mulScalar(REFLECTANCE);
    }

    // Lambertian scattering model: direction = normal + random_unit_vector()
    // This creates a cosine-weighted distribution that is physically accurate for matte surfaces.
    //
    // HOW IT WORKS:
    // 1. Generate a random unit vector (point on unit sphere)
    // 2. Add it to the surface normal
    // 3. This creates a new direction vector
    //
    // PHYSICAL ACCURACY:
    // - The distribution favors directions closer to the normal (cosine-weighted)
    // - This matches how real matte surfaces scatter light (Lambert's cosine law)
    // - More physically accurate than uniform hemisphere sampling
    //
    // NOTE: The direction vector is not normalized, but that's correct for this model.
    // The non-normalized length creates the proper probability distribution.
    inline fn scatterLambertian(self: *const Self, rec: *const HitRecord, world: *const HittableList, depth: u32) Color {
        const random_unit = Self.rand.vec3RandomUnitVector();
        const direction = rec.normal.add(random_unit);
        return self.rayColor(Ray.init(rec.p, direction), world, depth - 1).mulScalar(REFLECTANCE);
    }

    inline fn normalColor(self: *const Self, rec: *const HitRecord) Color {
        _ = self;
        // This adds white (1,1,1) to normal (components in [-1,1]), giving [0,2]
        // Then scales by 0.5 to get [0,1] range
        return rec.normal.add(WHITE).mulScalar(REFLECTANCE);
    }
};

const WHITE = Color.init(.{ 1.0, 1.0, 1.0 });
const SKY = Color.init(.{ 0.5, 0.7, 1.0 });
const REFLECTANCE = 0.5;
