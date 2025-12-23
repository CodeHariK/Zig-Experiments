const std = @import("std");
const math = @import("math.zig");

const Vec3 = math.Vec3;

// point3 is just an alias for vec3, but useful for geometric clarity in the code.
pub const Point3 = Vec3;

// Ray struct for ray tracing
pub const Ray = struct {
    orig: Point3,
    dir: Vec3,

    const Self = @This();

    pub fn init(origin: Point3, direction: Vec3) Self {
        return Self{
            .orig = origin,
            .dir = direction,
        };
    }

    pub fn at(self: Self, t: f64) Point3 {
        return self.orig.add(self.dir.mulScalar(t));
    }
};
