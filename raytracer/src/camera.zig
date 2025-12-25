const std = @import("std");
const rl = @import("raylib");
const math = @import("math.zig");

const ray = @import("ray.zig");
const hittable = @import("hittable.zig");
const interval = @import("interval.zig");
const color_mod = @import("color.zig");
const material = @import("material.zig");

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
    vfov: f64 = 90.0, // Vertical field of view in degrees
    lookfrom: Point3 = Point3.init(.{ 0.0, 0.0, 0.0 }), // Point camera is looking from
    lookat: Point3 = Point3.init(.{ 0.0, 0.0, -1.0 }), // Point camera is looking at
    vup: Vec3 = Vec3.init(.{ 0.0, 1.0, 0.0 }), // Camera-relative "up" direction
    defocus_angle: f64 = 0.0, // Variation angle of rays through each pixel
    focus_dist: f64 = 10.0, // Distance from camera lookfrom point to plane of perfect focus

    // Private camera variables (computed during initialization)
    camera_center: Point3 = undefined,

    viewport_height: f64 = undefined,
    viewport_width: f64 = undefined,
    viewport_u: Vec3 = undefined,
    viewport_v: Vec3 = undefined,
    u: Vec3 = undefined, // Camera frame basis vectors
    v: Vec3 = undefined,
    w: Vec3 = undefined,
    defocus_disk_u: Vec3 = undefined, // Defocus disk horizontal radius
    defocus_disk_v: Vec3 = undefined, // Defocus disk vertical radius

    pixel_delta_u: Vec3 = undefined,
    pixel_delta_v: Vec3 = undefined,
    pixel00_loc: Point3 = undefined,

    samples_per_pixel: u8 = 8, // Number of samples per pixel for antialiasing
    pixel_samples_scale: f64 = undefined, // Color scale factor for a sum of pixel samples
    max_depth: u8 = 8, // Maximum ray bounce depth to prevent infinite recursion

    pub var rand: math.Rand = undefined;

    const Self = @This();

    // Initialize camera parameters
    pub fn init(args: struct {
        aspect_ratio: ?f64,
        image_width: ?f64,
        samples_per_pixel: ?u8,
        max_depth: ?u8,
        vfov: ?f64,
        lookfrom: ?Point3,
        lookat: ?Point3,
        vup: ?Vec3,
        defocus_angle: ?f64,
        focus_dist: ?f64,
    }) Self {
        var self = Self{
            .aspect_ratio = args.aspect_ratio orelse 16.0 / 9.0,
            .image_width = args.image_width orelse 800.0,
            .samples_per_pixel = args.samples_per_pixel orelse 8,
            .max_depth = args.max_depth orelse 8,
            .vfov = args.vfov orelse 90.0,
            .lookfrom = args.lookfrom orelse Point3.init(.{ 0.0, 0.0, 0.0 }),
            .lookat = args.lookat orelse Point3.init(.{ 0.0, 0.0, -1.0 }),
            .vup = args.vup orelse Vec3.init(.{ 0.0, 1.0, 0.0 }),
            .defocus_angle = args.defocus_angle orelse 0.0,
            .focus_dist = args.focus_dist orelse 10.0,
        };

        Self.rand = math.Rand.init(@bitCast(std.time.timestamp()));

        // Camera center is where we're looking from
        self.camera_center = self.lookfrom;

        // Compute viewport height from vertical field of view
        const theta = std.math.degreesToRadians(self.vfov);
        const h = @tan(theta / 2.0);
        self.viewport_height = 2.0 * h * self.focus_dist;

        // Compute derived values
        self.image_height = self.image_width / self.aspect_ratio;
        self.viewport_width = self.viewport_height * self.aspect_ratio;

        // Calculate the u,v,w unit basis vectors for the camera coordinate frame
        // w is the direction the camera is looking (from lookat to lookfrom, normalized)
        self.w = self.lookfrom.sub(self.lookat).unit();
        // u is perpendicular to both vup and w (right vector)
        self.u = self.vup.cross(self.w).unit();
        // v is perpendicular to both w and u (up vector)
        self.v = self.w.cross(self.u);

        // Viewport vectors: U goes right, V goes down (negative v)
        self.viewport_u = self.u.mulScalar(self.viewport_width);
        self.viewport_v = self.v.neg().mulScalar(self.viewport_height);

        // Pixel spacing: how much to move for each pixel
        self.pixel_delta_u = self.viewport_u.divScalar(self.image_width);
        self.pixel_delta_v = self.viewport_v.divScalar(self.image_height);

        // Calculate the location of the upper left pixel
        // Start at camera center, move back by focus_dist along w, then offset by half viewport
        const viewport_upper_left = self.camera_center
            .sub(self.w.mulScalar(self.focus_dist))
            .sub(self.viewport_u.divScalar(2.0))
            .sub(self.viewport_v.divScalar(2.0));

        // Pixel00 is the center of the first pixel (upper-left pixel)
        // We offset by half a pixel in both U and V directions to get the pixel center
        self.pixel00_loc = viewport_upper_left
            .add(self.pixel_delta_u.add(self.pixel_delta_v).mulScalar(0.5));

        // Calculate defocus disk radius from defocus angle
        // The disk radius is: focus_dist * tan(defocus_angle / 2)
        const defocus_radius = self.focus_dist * @tan(std.math.degreesToRadians(self.defocus_angle / 2.0));
        self.defocus_disk_u = self.u.mulScalar(defocus_radius);
        self.defocus_disk_v = self.v.mulScalar(defocus_radius);

        // Compute pixel samples scale
        self.pixel_samples_scale = 1.0 / @as(f64, @floatFromInt(self.samples_per_pixel));

        return self;
    }

    // Returns a random point in the camera defocus disk
    fn defocusDiskSample(self: *Self) Point3 {
        const p = Self.rand.vec3RandomInUnitDisk();
        return self.camera_center
            .add(self.defocus_disk_u.mulScalar(p.x()))
            .add(self.defocus_disk_v.mulScalar(p.y()));
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

        // Get a random point in the defocus disk for depth of field
        const ray_origin = if (self.defocus_angle <= 0.0)
            self.camera_center
        else
            self.defocusDiskSample();

        // Calculate the point on the focus plane that the ray should pass through
        // Since the viewport is at focus_dist, pixel_sample is already on the focus plane
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
            // return self.scatterLambertian(&rec, world, depth);
            // return self.scatterBounceColor(&rec, world, depth);
            // return self.normalColor(&rec);

            // Use material system to scatter the ray
            if (rec.material) |mat| {
                const scatter_result = mat.scatter(r, &rec, &Self.rand);
                if (scatter_result.did_scatter) {
                    // Recursively trace the scattered ray with material attenuation
                    return self.rayColor(scatter_result.scattered, world, depth - 1)
                        .mul(scatter_result.attenuation);
                }
            }
            // If material doesn't scatter, return black (absorbed)
            return Color.zero();
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

    inline fn scatterBounceColor(self: *const Self, rec: *const HitRecord, world: *const HittableList, depth: u32) Color {
        const direction = Self.rand.vec3RandomOnHemisphere(rec.normal);
        return self.rayColor(Ray.init(rec.p, direction), world, depth - 1).mulScalar(REFLECTANCE);
    }
    inline fn scatterLambertian(self: *const Self, rec: *const HitRecord, world: *const HittableList, depth: u32) Color {
        const random_unit = Self.rand.vec3RandomUnitVector();
        const direction = rec.normal.add(random_unit);
        return self.rayColor(Ray.init(rec.p, direction), world, depth - 1).mulScalar(REFLECTANCE);
    }
    inline fn normalColor(self: *const Self, rec: *const HitRecord) Color {
        _ = self;
        return rec.normal.add(WHITE).mulScalar(REFLECTANCE);
    }
};

const WHITE = Color.init(.{ 1.0, 1.0, 1.0 });
const SKY = Color.init(.{ 0.5, 0.7, 1.0 });
const REFLECTANCE = 0.5;
