//! Type Utilities and Bit Conversion
//!
//! Provides type-level utilities and functions for converting between integer types and bit arrays.
//! All bit arrays use LSB-first ordering to match the project convention.

const std = @import("std");
const testing = std.testing;

/// Returns an unsigned integer type with exactly N bits.
///
/// This is a type-level function that generates the appropriate unsigned integer
/// type for a given bit width at compile time.
///
/// Example:
/// ```zig
/// const U4 = UIntN(4);  // Returns u4
/// const value: U4 = 15;  // Maximum value for 4 bits
/// ```
pub fn UIntN(comptime N: u8) type {
    return std.meta.Int(.unsigned, N);
}

/// Converts an unsigned integer to an array of u1 bits (LSB first).
/// Example: `toBits(4, 5)` returns `[4]u1{ 1, 0, 1, 0 }`
pub fn toBits(comptime N: u8, value: UIntN(N)) [N]u1 {
    var bits: [N]u1 = undefined;
    inline for (0..N) |i| {
        bits[i] = @truncate(value >> i);
    }
    return bits;
}

/// Converts an array of u1 bits (LSB first) back to an unsigned integer.
/// Example: `fromBits(4, [4]u1{ 1, 0, 1, 0 })` returns `5`
pub fn fromBits(comptime N: u8, bits: [N]u1) UIntN(N) {
    var value: UIntN(N) = 0;
    inline for (0..N) |i| {
        value |= @as(UIntN(N), bits[i]) << i;
    }
    return value;
}

// ============================================================================
// Convenience Functions - Integer to Bit Array
// ============================================================================

/// Converts to 2-bit array
pub inline fn b2(value: usize) [2]u1 {
    return toBits(2, @truncate(value));
}

/// Converts to 3-bit array
pub inline fn b3(value: usize) [3]u1 {
    return toBits(3, @truncate(value));
}

/// Converts to 6-bit array
pub inline fn b6(value: usize) [6]u1 {
    return toBits(6, @truncate(value));
}

/// Converts to 4-bit array
pub inline fn b4(value: usize) [4]u1 {
    return toBits(4, @truncate(value));
}

/// Converts to 8-bit array
pub inline fn b8(value: usize) [8]u1 {
    return toBits(8, @truncate(value));
}

/// Converts to 8-bit array
pub inline fn b9(value: usize) [9]u1 {
    return toBits(9, @truncate(value));
}

/// Converts to 12-bit array
pub inline fn b12(value: usize) [12]u1 {
    return toBits(12, @truncate(value));
}

/// Converts to 13-bit array
pub inline fn b13(value: usize) [13]u1 {
    return toBits(13, @truncate(value));
}

/// Converts to 14-bit array
pub inline fn b14(value: usize) [14]u1 {
    return toBits(14, @truncate(value));
}

/// Converts to 15-bit array
pub inline fn b15(value: usize) [15]u1 {
    return toBits(15, @truncate(value));
}

/// Converts to 16-bit array
pub inline fn b16(value: usize) [16]u1 {
    return toBits(16, @truncate(value));
}

// ============================================================================
// Convenience Functions - Bit Array to Integer
// ============================================================================

/// Converts from 2-bit array
pub inline fn fb2(bits: [2]u1) u2 {
    return fromBits(2, bits);
}

/// Converts from 3-bit array
pub inline fn fb3(bits: [3]u1) u3 {
    return fromBits(3, bits);
}

/// Converts from 4-bit array
pub inline fn fb4(bits: [4]u1) u4 {
    return fromBits(4, bits);
}

/// Converts from 6-bit array
pub inline fn fb6(bits: [6]u1) u6 {
    return fromBits(6, bits);
}

/// Converts from 8-bit array
pub inline fn fb8(bits: [8]u1) u8 {
    return fromBits(8, bits);
}

/// Converts from 12-bit array
pub inline fn fb12(bits: [12]u1) u12 {
    return fromBits(12, bits);
}

/// Converts from 13-bit array
pub inline fn fb13(bits: [13]u1) u13 {
    return fromBits(13, bits);
}

/// Converts from 15-bit array
pub inline fn fb15(bits: [15]u1) u15 {
    return fromBits(15, bits);
}

/// Converts from 16-bit array
pub inline fn fb16(bits: [16]u1) u16 {
    return fromBits(16, bits);
}

// ============================================================================
// Tests
// ============================================================================

test "toBits converts integers to LSB-first bit arrays" {
    try testing.expectEqual([2]u1{ 1, 0 }, b2(1));
    try testing.expectEqual([3]u1{ 0, 1, 0 }, b3(2));
    try testing.expectEqual([4]u1{ 1, 0, 1, 0 }, b4(5));
    try testing.expectEqual([8]u1{ 1, 1, 1, 0, 0, 0, 0, 0 }, b8(7));
    try testing.expectEqual([16]u1{ 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, b16(8));

    try testing.expectEqual(@as(u2, 1), fb2([2]u1{ 1, 0 }));
    try testing.expectEqual(@as(u3, 2), fb3([3]u1{ 0, 1, 0 }));
    try testing.expectEqual(@as(u4, 5), fb4([4]u1{ 1, 0, 1, 0 }));
    try testing.expectEqual(@as(u8, 7), fb8([8]u1{ 1, 1, 1, 0, 0, 0, 0, 0 }));
    try testing.expectEqual(@as(u16, 8), fb16([16]u1{ 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }));

    inline for ([_]u16{ 0, 1, 255, 1000, 0xFFFF, 0xABCD }) |val| {
        try testing.expectEqual(val, fb16(b16(val)));
    }
}
