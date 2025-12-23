// Color type with presets

const geometry = @import("geometry.zig");
const CGFloat = geometry.CGFloat;

pub const Color = struct {
    r: CGFloat,
    g: CGFloat,
    b: CGFloat,
    a: CGFloat = 1.0,

    // Presets
    pub const dark = Color{ .r = 0.15, .g = 0.15, .b = 0.2 };
    pub const white = Color{ .r = 1.0, .g = 1.0, .b = 1.0 };
    pub const black = Color{ .r = 0.0, .g = 0.0, .b = 0.0 };
    pub const red = Color{ .r = 1.0, .g = 0.0, .b = 0.0 };
    pub const green = Color{ .r = 0.0, .g = 1.0, .b = 0.0 };
    pub const blue = Color{ .r = 0.0, .g = 0.0, .b = 1.0 };
    pub const gray = Color{ .r = 0.5, .g = 0.5, .b = 0.5 };
    pub const yellow = Color{ .r = 1.0, .g = 1.0, .b = 0.0 };
    pub const cyan = Color{ .r = 0.0, .g = 1.0, .b = 1.0 };
    pub const magenta = Color{ .r = 1.0, .g = 0.0, .b = 1.0 };

    pub fn rgb(r: CGFloat, g: CGFloat, b: CGFloat) Color {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn rgba(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Create from 0-255 range
    pub fn rgb8(r: u8, g: u8, b: u8) Color {
        return .{
            .r = @as(CGFloat, @floatFromInt(r)) / 255.0,
            .g = @as(CGFloat, @floatFromInt(g)) / 255.0,
            .b = @as(CGFloat, @floatFromInt(b)) / 255.0,
        };
    }

    /// Create from hex (0xRRGGBB)
    pub fn hex(value: u24) Color {
        return .{
            .r = @as(CGFloat, @floatFromInt((value >> 16) & 0xFF)) / 255.0,
            .g = @as(CGFloat, @floatFromInt((value >> 8) & 0xFF)) / 255.0,
            .b = @as(CGFloat, @floatFromInt(value & 0xFF)) / 255.0,
        };
    }
};
