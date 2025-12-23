// Geometry types (Cocoa-compatible)

pub const CGFloat = f64;

pub const CGPoint = extern struct {
    x: CGFloat,
    y: CGFloat,
};

pub const CGSize = extern struct {
    width: CGFloat,
    height: CGFloat,
};

pub const CGRect = extern struct {
    origin: CGPoint,
    size: CGSize,

    pub fn init(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) CGRect {
        return .{
            .origin = .{ .x = x, .y = y },
            .size = .{ .width = w, .height = h },
        };
    }
};
