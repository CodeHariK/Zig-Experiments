const std = @import("std");

/// Returns an unsigned integer type with N bits
pub fn UIntN(comptime N: u8) type {
    return std.meta.Int(.unsigned, N);
}

/// Convert an unsigned integer to an array of u1 bits (MSB first)
pub fn toBits(comptime N: u8, value: UIntN(N)) [N]u1 {
    var bits: [N]u1 = undefined;
    inline for (0..N) |i| {
        bits[i] = @truncate(value >> (N - 1 - i));
    }
    return bits;
}

pub fn bb2(value: usize) [2]u1 {
    return toBits(2, @truncate(value));
}

pub fn bb3(value: usize) [3]u1 {
    return toBits(3, @truncate(value));
}

pub fn bb4(value: u16) [4]u1 {
    return toBits(4, @truncate(value));
}

pub fn bb8(value: u16) [8]u1 {
    return toBits(8, @truncate(value));
}
