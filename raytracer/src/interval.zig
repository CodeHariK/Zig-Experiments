const std = @import("std");

// Interval represents a range [min, max] of real numbers
pub const Interval = struct {
    min: f64,
    max: f64,

    const Self = @This();

    // Default interval is empty (min > max means no valid values)
    pub fn init() Self {
        return Self{
            .min = std.math.inf(f64),
            .max = -std.math.inf(f64),
        };
    }

    // Create interval with specific bounds
    pub fn initWithBounds(min: f64, max: f64) Self {
        return Self{
            .min = min,
            .max = max,
        };
    }

    // Returns the size of the interval
    pub fn size(self: Self) f64 {
        return self.max - self.min;
    }

    // Returns true if x is in [min, max] (inclusive)
    pub fn contains(self: Self, x: f64) bool {
        return x >= self.min and x <= self.max;
    }

    // Returns true if x is in (min, max) (exclusive)
    pub fn surrounds(self: Self, x: f64) bool {
        return x > self.min and x < self.max;
    }

    pub fn clamp(self: Self, x: f64) f64 {
        if (x < self.min) return self.min;
        if (x > self.max) return self.max;
        return x;
    }
};

// Static constants
pub const empty = Interval.init();
pub const universe = Interval.initWithBounds(-std.math.inf(f64), std.math.inf(f64));
