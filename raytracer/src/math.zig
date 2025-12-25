const std = @import("std");
const Random = std.Random;

const epsilon = 1e-10;

// Generic vector type using @Vector for SIMD optimization
pub fn Vec(comptime N: comptime_int, comptime T: type) type {
    return struct {
        data: @Vector(N, T),

        const Self = @This();

        const tolerance_vec: @Vector(N, T) = @splat(epsilon);

        pub inline fn init(components: [N]T) Self {
            return Self{ .data = components };
        }

        pub inline fn zero() Self {
            const zero_val: T = 0;
            return Self{ .data = @splat(zero_val) };
        }

        pub inline fn one() Self {
            const one_val: T = 1;
            return Self{ .data = @splat(one_val) };
        }

        pub inline fn x(self: Self) T {
            return self.data[0];
        }

        pub inline fn y(self: Self) T {
            if (N < 2) @compileError("Vec.y() requires N >= 2");
            return self.data[1];
        }

        pub inline fn z(self: Self) T {
            if (N < 3) @compileError("Vec.z() requires N >= 3");
            return self.data[2];
        }

        pub inline fn neg(self: Self) Self {
            return Self{ .data = -self.data };
        }

        pub inline fn add(self: Self, other: Self) Self {
            return Self{ .data = self.data + other.data };
        }

        pub inline fn addScalar(self: Self, t: T) Self {
            const t_vec: @Vector(N, T) = @splat(t);
            return Self{ .data = self.data + t_vec };
        }

        pub inline fn sub(self: Self, other: Self) Self {
            return Self{ .data = self.data - other.data };
        }

        pub inline fn mul(self: Self, other: Self) Self {
            return Self{ .data = self.data * other.data };
        }

        pub inline fn mulScalar(self: Self, t: T) Self {
            const t_vec: @Vector(N, T) = @splat(t);
            return Self{ .data = self.data * t_vec };
        }

        pub inline fn div(self: Self, other: Self) Self {
            return Self{ .data = self.data / other.data };
        }

        pub inline fn divScalar(self: Self, t: T) Self {
            const t_vec: @Vector(N, T) = @splat(t);
            return Self{ .data = self.data / t_vec };
        }

        pub inline fn addAssign(self: *Self, other: Self) void {
            self.data += other.data;
        }

        pub inline fn mulAssign(self: *Self, t: T) void {
            const t_vec: @Vector(N, T) = @splat(t);
            self.data *= t_vec;
        }

        pub inline fn divAssign(self: *Self, t: T) void {
            const t_vec: @Vector(N, T) = @splat(t);
            self.data /= t_vec;
        }

        pub inline fn lengthSquared(self: Self) T {
            return @reduce(.Add, self.data * self.data);
        }

        pub inline fn length(self: Self) T {
            return @sqrt(self.lengthSquared());
        }

        pub inline fn dot(self: Self, other: Self) T {
            return @reduce(.Add, self.data * other.data);
        }

        pub inline fn unit(self: Self) Self {
            return self.divScalar(self.length());
        }

        pub inline fn reflect(self: Self, normal: Self) Self {
            return self.sub(normal.mulScalar(2.0 * self.dot(normal)));
        }

        pub inline fn refract(self: Self, normal: Self, etai_over_etat: T) Self {
            const cos_theta = @min(self.dot(normal.neg()), 1.0);
            const r_out_perp = self.add(normal.mulScalar(cos_theta)).mulScalar(etai_over_etat);
            const r_out_parallel = normal.mulScalar(-std.math.sqrt(@abs(1.0 - r_out_perp.lengthSquared())));
            return r_out_perp.add(r_out_parallel);
        }

        // cross product only works for 3D vectors
        pub inline fn cross(self: Self, other: Self) Self {
            if (N != 3) @compileError("cross product only works for 3D vectors");
            return Self{
                .data = .{
                    self.data[1] * other.data[2] - self.data[2] * other.data[1],
                    self.data[2] * other.data[0] - self.data[0] * other.data[2],
                    self.data[0] * other.data[1] - self.data[1] * other.data[0],
                },
            };
        }

        pub inline fn approxEqAbs(self: Self, other: Self) bool {
            const diff = self.data - other.data;
            const abs_diff = @abs(diff);
            return @reduce(.And, abs_diff < tolerance_vec);
        }
    };
}

// Convenience type aliases
pub const Vec3 = Vec(3, f64);
pub const Vec2 = Vec(2, f64);
pub const Vec4 = Vec(4, f64);

pub const Rand = struct {
    prng: std.Random.DefaultPrng = undefined,

    const Self = @This();

    pub fn init(seed: u64) Self {
        return Rand{ .prng = std.Random.DefaultPrng.init(seed) };
    }

    // Returns a random real in [0,1)
    pub inline fn randomDouble(self: *Self) f64 {
        return self.prng.random().float(f64);
    }

    // Returns a random real in [min,max)
    pub inline fn randomDoubleMinMax(self: *Self, min: f64, max: f64) f64 {
        return min + (max - min) * self.randomDouble();
    }

    pub fn vec3Random(self: *Self) Vec3 {
        return Vec3.init(.{
            self.randomDouble(),
            self.randomDouble(),
            self.randomDouble(),
        });
    }

    pub fn vec3RandomMinMax(self: *Self, min: f64, max: f64) Vec3 {
        return Vec3.init(.{
            self.randomDoubleMinMax(min, max),
            self.randomDoubleMinMax(min, max),
            self.randomDoubleMinMax(min, max),
        });
    }

    pub fn vec3SampleSquare(self: *Self) Vec3 {
        return Vec3.init(.{
            self.randomDouble() - 0.5,
            self.randomDouble() - 0.5,
            0.0,
        });
    }

    // Generates a random point inside a unit disk (circle with radius 1) in the x-y plane.
    // Uses rejection sampling: generates random points in [-1,1]² and accepts those
    // inside the unit circle (length_squared < 1).
    // This is typically used for depth of field effects in ray tracing.
    pub inline fn vec3RandomInUnitDisk(self: *Self) Vec3 {
        while (true) {
            const p = Vec3.init(.{
                self.randomDoubleMinMax(-1.0, 1.0),
                self.randomDoubleMinMax(-1.0, 1.0),
                0.0,
            });
            if (p.lengthSquared() < 1.0) {
                return p;
            }
        }
    }

    // Generates a random unit vector (vector with length 1) using rejection sampling.
    // This method:
    // 1. Generates random points in the cube [-1, 1]³
    // 2. Rejects points outside the unit sphere (length_squared > 1)
    // 3. Normalizes accepted points to get a unit vector
    // This produces a uniform distribution on the surface of the unit sphere.
    //
    // Note: Simply normalizing a random vector in [-1,1]³ would NOT give uniform
    // distribution - points would cluster near cube corners. Rejection sampling
    // ensures uniform distribution on the sphere surface.
    pub fn vec3RandomUnitVector(self: *Self) Vec3 {
        while (true) {
            const p = self.vec3RandomMinMax(-1.0, 1.0);
            const len_sq = p.lengthSquared();
            if (epsilon <= len_sq and len_sq <= 1.0) {
                return p.divScalar(@sqrt(len_sq));
            }
        }
    }

    // Generates a random unit vector on the hemisphere defined by the given normal.
    // If the generated vector is in the opposite hemisphere, it is negated to
    // ensure it lies in the same hemisphere as the normal.
    pub inline fn vec3RandomOnHemisphere(self: *Self, normal: Vec3) Vec3 {
        const on_unit_sphere = self.vec3RandomUnitVector();
        if (on_unit_sphere.dot(normal) > 0.0) {
            return on_unit_sphere;
        } else {
            return on_unit_sphere.neg();
        }
    }

    pub fn vec3RandomUnitVectorGaussian(self: *Self) Vec3 {
        const rng = self.prng.random();
        const x = rng.floatNorm(f64);
        const y = rng.floatNorm(f64);
        const z = rng.floatNorm(f64);
        const p = Vec3.init(.{ x, y, z });
        return p.unit();
    }

    // More efficient alternative: generates a random unit vector using Gaussian distribution.
    // This gives uniform distribution on the sphere without rejection sampling.
    //
    // WHY GAUSSIAN WORKS:
    // - Gaussian (normal) distribution has rotational symmetry: the probability density
    //   depends only on distance from origin, not direction: P(x,y,z) ∝ exp(-r²/2)
    // - When you normalize a Gaussian vector, all directions are equally likely
    // - This is because the Gaussian PDF is spherically symmetric
    //
    // BOX-MULLER TRANSFORM:
    // Converts two uniform [0,1) random numbers into two independent standard normal
    // (Gaussian) random numbers:
    //   z0 = sqrt(-2*ln(u1)) * cos(2π*u2)
    //   z1 = sqrt(-2*ln(u1)) * sin(2π*u2)
    // where u1, u2 are uniform [0,1)
    //
    // For 3D, we generate 3 independent Gaussians using Box-Muller (need 6 uniform randoms)
    pub fn vec3RandomUnitVectorGaussian2(self: *Self) Vec3 {
        const rng = self.prng.random();

        // Generate 3 independent standard normal random variables using Box-Muller
        // We need 6 uniform random numbers for 3 Gaussians (2 per Gaussian)
        const uniform1 = rng.float(f64);
        const uniform2 = rng.float(f64);
        const uniform3 = rng.float(f64);
        const uniform4 = rng.float(f64);

        // Box-Muller transform: z = sqrt(-2*ln(u1)) * cos(2π*u2)
        // First pair: x and y components
        const sqrt_term1 = @sqrt(-2.0 * std.math.ln(uniform1));
        const x = sqrt_term1 * @cos(2.0 * std.math.pi * uniform2);
        const y = sqrt_term1 * @sin(2.0 * std.math.pi * uniform2);

        // Second pair for z component
        const sqrt_term2 = @sqrt(-2.0 * std.math.ln(uniform3));
        const z = sqrt_term2 * @cos(2.0 * std.math.pi * uniform4);

        const p = Vec3.init(.{ x, y, z });
        return p.unit();
    }
};
