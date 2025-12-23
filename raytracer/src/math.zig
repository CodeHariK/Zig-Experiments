const std = @import("std");

// Generic vector type using @Vector for SIMD optimization
pub fn Vec(comptime N: comptime_int, comptime T: type) type {
    return struct {
        data: @Vector(N, T),

        const Self = @This();

        const tolerance_vec: @Vector(N, T) = @splat(1e-5);

        pub fn init(components: [N]T) Self {
            return Self{ .data = components };
        }

        pub fn zero() Self {
            const zero_val: T = 0;
            return Self{ .data = @splat(zero_val) };
        }

        pub fn one() Self {
            const one_val: T = 1;
            return Self{ .data = @splat(one_val) };
        }

        pub fn x(self: Self) T {
            return self.data[0];
        }

        pub fn y(self: Self) T {
            if (N < 2) @compileError("Vec.y() requires N >= 2");
            return self.data[1];
        }

        pub fn z(self: Self) T {
            if (N < 3) @compileError("Vec.z() requires N >= 3");
            return self.data[2];
        }

        pub fn neg(self: Self) Self {
            return Self{ .data = -self.data };
        }

        pub fn add(self: Self, other: Self) Self {
            return Self{ .data = self.data + other.data };
        }

        pub fn addScalar(self: Self, t: T) Self {
            const t_vec: @Vector(N, T) = @splat(t);
            return Self{ .data = self.data + t_vec };
        }

        pub fn sub(self: Self, other: Self) Self {
            return Self{ .data = self.data - other.data };
        }

        pub fn mul(self: Self, other: Self) Self {
            return Self{ .data = self.data * other.data };
        }

        pub fn mulScalar(self: Self, t: T) Self {
            const t_vec: @Vector(N, T) = @splat(t);
            return Self{ .data = self.data * t_vec };
        }

        pub fn div(self: Self, other: Self) Self {
            return Self{ .data = self.data / other.data };
        }

        pub fn divScalar(self: Self, t: T) Self {
            const t_vec: @Vector(N, T) = @splat(t);
            return Self{ .data = self.data / t_vec };
        }

        pub fn addAssign(self: *Self, other: Self) void {
            self.data += other.data;
        }

        pub fn mulAssign(self: *Self, t: T) void {
            const t_vec: @Vector(N, T) = @splat(t);
            self.data *= t_vec;
        }

        pub fn divAssign(self: *Self, t: T) void {
            const t_vec: @Vector(N, T) = @splat(t);
            self.data /= t_vec;
        }

        pub fn lengthSquared(self: Self) T {
            return @reduce(.Add, self.data * self.data);
        }

        pub fn length(self: Self) T {
            return @sqrt(self.lengthSquared());
        }

        pub fn dot(self: Self, other: Self) T {
            return @reduce(.Add, self.data * other.data);
        }

        pub fn unit(self: Self) Self {
            return self.divScalar(self.length());
        }

        // cross product only works for 3D vectors
        pub fn cross(self: Self, other: Self) Self {
            if (N != 3) @compileError("cross product only works for 3D vectors");
            return Self{
                .data = .{
                    self.data[1] * other.data[2] - self.data[2] * other.data[1],
                    self.data[2] * other.data[0] - self.data[0] * other.data[2],
                    self.data[0] * other.data[1] - self.data[1] * other.data[0],
                },
            };
        }

        pub fn approxEqAbs(self: Self, other: Self) bool {
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
