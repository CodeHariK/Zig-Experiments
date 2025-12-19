//! Bit Conversion Utilities
//!
//! Provides functions for converting between integer types and bit arrays.
//! All bit arrays use MSB-first ordering to match the project convention.

const std = @import("std");
const testing = std.testing;

/// Returns an unsigned integer type with exactly N bits.
/// Example: `UIntN(4)` returns `u4`
pub fn UIntN(comptime N: u8) type {
    return std.meta.Int(.unsigned, N);
}

/// Converts an unsigned integer to an array of u1 bits (MSB first).
/// Example: `toBits(4, 5)` returns `[4]u1{ 0, 1, 0, 1 }`
pub fn toBits(comptime N: u8, value: UIntN(N)) [N]u1 {
    var bits: [N]u1 = undefined;
    inline for (0..N) |i| {
        bits[i] = @truncate(value >> (N - 1 - i));
    }
    return bits;
}

/// Converts an array of u1 bits (MSB first) back to an unsigned integer.
/// Example: `fromBits(4, [4]u1{ 0, 1, 0, 1 })` returns `5`
pub fn fromBits(comptime N: u8, bits: [N]u1) UIntN(N) {
    var value: UIntN(N) = 0;
    inline for (0..N) |i| {
        value |= @as(UIntN(N), bits[i]) << (N - 1 - i);
    }
    return value;
}

// ============================================================================
// Convenience Functions - Integer to Bit Array
// ============================================================================

/// Converts to 2-bit array
pub fn b2(value: usize) [2]u1 {
    return toBits(2, @truncate(value));
}

/// Converts to 3-bit array
pub fn b3(value: usize) [3]u1 {
    return toBits(3, @truncate(value));
}

/// Converts to 4-bit array
pub fn b4(value: usize) [4]u1 {
    return toBits(4, @truncate(value));
}

/// Converts to 8-bit array
pub fn b8(value: usize) [8]u1 {
    return toBits(8, @truncate(value));
}

/// Converts to 16-bit array
pub fn b16(value: usize) [16]u1 {
    return toBits(16, @truncate(value));
}

// ============================================================================
// Convenience Functions - Bit Array to Integer
// ============================================================================

/// Converts from 2-bit array
pub fn fb2(bits: [2]u1) u2 {
    return fromBits(2, bits);
}

/// Converts from 3-bit array
pub fn fb3(bits: [3]u1) u3 {
    return fromBits(3, bits);
}

/// Converts from 4-bit array
pub fn fb4(bits: [4]u1) u4 {
    return fromBits(4, bits);
}

/// Converts from 8-bit array
pub fn fb8(bits: [8]u1) u8 {
    return fromBits(8, bits);
}

/// Converts from 16-bit array
pub fn fb16(bits: [16]u1) u16 {
    return fromBits(16, bits);
}

// ============================================================================
// Tests
// ============================================================================

test "toBits converts integers to MSB-first bit arrays" {
    try testing.expectEqual([2]u1{ 0, 1 }, b2(1));
    try testing.expectEqual([3]u1{ 0, 1, 0 }, b3(2));
    try testing.expectEqual([4]u1{ 0, 1, 0, 1 }, b4(5));
    try testing.expectEqual([8]u1{ 0, 0, 0, 0, 0, 1, 1, 1 }, b8(7));
    try testing.expectEqual([16]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0 }, b16(8));
}

test "fromBits converts MSB-first bit arrays to integers" {
    try testing.expectEqual(@as(u2, 1), fb2([2]u1{ 0, 1 }));
    try testing.expectEqual(@as(u3, 2), fb3([3]u1{ 0, 1, 0 }));
    try testing.expectEqual(@as(u4, 5), fb4([4]u1{ 0, 1, 0, 1 }));
    try testing.expectEqual(@as(u8, 7), fb8([8]u1{ 0, 0, 0, 0, 0, 1, 1, 1 }));
    try testing.expectEqual(@as(u16, 8), fb16([16]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0 }));
}

test "roundtrip: toBits and fromBits are inverses" {
    inline for ([_]u16{ 0, 1, 255, 1000, 0xFFFF, 0xABCD }) |val| {
        try testing.expectEqual(val, fb16(b16(val)));
    }
}
