const std = @import("std");
const math = @import("math.zig");
const ray = @import("ray.zig");

const Vec3 = math.Vec3;
const Color = math.Vec3;
const Ray = ray.Ray;
const HitRecord = @import("hittable.zig").HitRecord;

// Result of a scatter operation
pub const ScatterResult = struct {
    attenuation: Color,
    scattered: Ray,
    did_scatter: bool,
};

// Material interface - defines how light interacts with surfaces
pub const Material = union(enum) {
    lambertian: Lambertian,
    metal: Metal,
    // Future materials can be added here:
    // metal: Metal,
    // dielectric: Dielectric,

    const Self = @This();

    // Scatter a ray off this material
    // Returns ScatterResult with attenuation, scattered ray, and success flag
    pub fn scatter(self: Self, r_in: Ray, rec: *const HitRecord, rand: *math.Rand) ScatterResult {
        return switch (self) {
            .lambertian => |mat| mat.scatter(r_in, rec, rand),
            .metal => |mat| mat.scatter(r_in, rec, rand),
            // .dielectric => |mat| mat.scatter(r_in, rec, rand),
        };
    }
};

// Lambertian (matte/diffuse) material
// Scatters light in all directions with equal probability
pub const Lambertian = struct {
    albedo: Color, // Color of the material (reflectivity)

    const Self = @This();

    pub fn init(albedo: Color) Material {
        return Material{ .lambertian = Self{ .albedo = albedo } };
    }

    pub fn scatter(self: Self, r_in: Ray, rec: *const HitRecord, rand: *math.Rand) ScatterResult {
        _ = r_in; // Not used in Lambertian scattering

        // Lambertian scattering: direction = normal + random_unit_vector
        const random_unit = rand.vec3RandomUnitVector();
        const scatter_direction = rec.normal.add(random_unit);

        if (scatter_direction.approxEqAbs(Vec3.zero())) {
            return ScatterResult{
                .attenuation = Color.zero(),
                .scattered = Ray.init(rec.p, rec.normal),
                .did_scatter = false,
            };
        }

        return ScatterResult{
            .attenuation = self.albedo,
            .scattered = Ray.init(rec.p, scatter_direction),
            .did_scatter = true,
        };
    }
};

// Metal (shiny/reflective) material
pub const Metal = struct {
    albedo: Color, // Color of the material (reflectivity)
    fuzz: f64, // Fuzziness of the material (0 = perfect mirror, 1 = very rough)

    const Self = @This();

    pub fn init(albedo: Color, fuzz: f64) Material {
        // Clamp fuzz to [0, 1] - values > 1 would make reflection point into surface
        const clamped_fuzz = if (fuzz < 1.0) fuzz else 1.0;
        return Material{ .metal = Self{ .albedo = albedo, .fuzz = clamped_fuzz } };
    }

    pub fn scatter(self: Self, r_in: Ray, rec: *const HitRecord, rand: *math.Rand) ScatterResult {
        // Reflect the incoming ray direction off the surface normal
        const reflected = r_in.dir.reflect(rec.normal);

        // Normalize the reflected direction, then add fuzz (random offset)
        // This creates a rough/brushed metal appearance
        const scattered_direction = reflected.unit()
            .add(rand.vec3RandomUnitVector().mulScalar(self.fuzz));

        const scattered = Ray.init(rec.p, scattered_direction);

        // Only scatter if the scattered ray points away from the surface
        // If fuzz is too large, the ray might point into the surface
        const did_scatter = scattered_direction.dot(rec.normal) > 0.0;

        return ScatterResult{
            .attenuation = self.albedo,
            .scattered = scattered,
            .did_scatter = did_scatter,
        };
    }
};
