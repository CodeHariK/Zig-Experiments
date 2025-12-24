const rl = @import("raylib");
const Vec3 = @import("math.zig").Vec3;
const math = @import("std").math;

// Color is just a type alias for Vec3
pub const Color = Vec3;

// Extension functions for Color
pub const ColorExt = struct {

    // Convert linear color component to gamma-corrected value
    // Gamma correction accounts for how displays interpret brightness
    // Most displays have gamma ~2.2, so we apply sqrt (gamma 2.0) as approximation
    // This makes the image appear brighter and more natural
    pub inline fn linearToGamma(linear_component: f64) f64 {
        if (linear_component > 0.0) {
            return math.sqrt(linear_component);
        }
        return 0.0;
    }

    // Convert Color (Vec3) to Raylib Color with gamma correction
    pub fn toRlColor(color: Color) rl.Color {
        // Apply gamma correction to each color component
        const r_gamma = linearToGamma(math.clamp(color.x(), 0.0, 1.0));
        const g_gamma = linearToGamma(math.clamp(color.y(), 0.0, 1.0));
        const b_gamma = linearToGamma(math.clamp(color.z(), 0.0, 1.0));

        return rl.Color{
            .r = @as(u8, @intFromFloat(r_gamma * 255.999)),
            .g = @as(u8, @intFromFloat(g_gamma * 255.999)),
            .b = @as(u8, @intFromFloat(b_gamma * 255.999)),
            .a = 255,
        };
    }

    // Blend two colors with alpha
    pub fn blend(self: Color, other: Color, alpha: f64) Color {
        return self.mulScalar(1.0 - alpha).add(other.mulScalar(alpha));
    }
};
