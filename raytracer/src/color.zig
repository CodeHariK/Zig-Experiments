const rl = @import("raylib");
const Vec3 = @import("math.zig").Vec3;

pub const Color = struct {
    data: Vec3,

    const Self = @This();

    pub fn init(r: f64, g: f64, b: f64) Self {
        return Self{ .data = Vec3.init(.{ r, g, b }) };
    }

    pub fn fromVec3(v: Vec3) Self {
        return Self{ .data = v };
    }

    pub fn toRlColor(self: Self) rl.Color {
        return rl.Color{
            .r = @as(u8, @intFromFloat(self.data.data[0] * 255.999)),
            .g = @as(u8, @intFromFloat(self.data.data[1] * 255.999)),
            .b = @as(u8, @intFromFloat(self.data.data[2] * 255.999)),
            .a = 255,
        };
    }

    pub fn blend(self: Self, other: Self, alpha: f64) Self {
        return Self{ .data = self.data.mulScalar(1.0 - alpha).add(other.data.mulScalar(alpha)) };
    }
};
