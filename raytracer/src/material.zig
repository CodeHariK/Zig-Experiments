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
    dielectric: Dielectric,

    const Self = @This();

    // Scatter a ray off this material
    // Returns ScatterResult with attenuation, scattered ray, and success flag
    pub fn scatter(self: Self, r_in: Ray, rec: *const HitRecord, rand: *math.Rand) ScatterResult {
        return switch (self) {
            .lambertian => |mat| mat.scatter(r_in, rec, rand),
            .metal => |mat| mat.scatter(r_in, rec, rand),
            .dielectric => |mat| mat.scatter(r_in, rec, rand),
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

// Dielectric (glass/transparent) material
// Refracts light based on Snell's law
pub const Dielectric = struct {
    // Refractive index in vacuum or air, or the ratio of the material's refractive index
    // over the refractive index of the enclosing media
    refraction_index: f64,

    const Self = @This();

    pub fn init(refraction_index: f64) Material {
        return Material{ .dielectric = Self{ .refraction_index = refraction_index } };
    }

    pub fn scatter(self: Self, r_in: Ray, rec: *const HitRecord, rand: *math.Rand) ScatterResult {
        // Glass doesn't absorb color - attenuation is always white
        const attenuation = Color.init(.{ 1.0, 1.0, 1.0 });

        // Determine the ratio of refraction indices
        // When entering material (front_face = true): use 1.0 / refraction_index
        // When exiting material (front_face = false): use refraction_index / 1.0
        const ri = if (rec.front_face) (1.0 / self.refraction_index) else self.refraction_index;

        // Normalize the incoming ray direction
        const unit_direction = r_in.dir.unit();

        // Calculate cos(theta) where theta is the angle between -unit_direction and normal
        const cos_theta = @min(unit_direction.neg().dot(rec.normal), 1.0);
        const sin_theta = std.math.sqrt(1.0 - cos_theta * cos_theta);

        // Check for total internal reflection
        // If ri * sin_theta > 1.0, refraction is impossible (Snell's law violation)
        const cannot_refract = ri * sin_theta > 1.0;

        const direction = if (cannot_refract or Self.reflectance(cos_theta, ri) > rand.randomDouble())
            unit_direction.reflect(rec.normal)
        else
            unit_direction.refract(rec.normal, ri);

        const scattered = Ray.init(rec.p, direction);

        // Dielectric always scatters (either refracts or reflects)
        return ScatterResult{
            .attenuation = attenuation,
            .scattered = scattered,
            .did_scatter = true,
        };
    }

    // Use Schlick's approximation for reflectance (Fresnel reflection)
    // This gives the probability of reflection based on the angle of incidence
    pub fn reflectance(cosine: f64, refraction_index: f64) f64 {
        // r0 is the reflectance at normal incidence (0 degrees)
        var r0 = (1.0 - refraction_index) / (1.0 + refraction_index);
        r0 = r0 * r0;
        // Schlick's approximation: R(θ) = r0 + (1 - r0) * (1 - cos(θ))^5
        return r0 + (1.0 - r0) * std.math.pow(f64, 1.0 - cosine, 5);
    }
};
