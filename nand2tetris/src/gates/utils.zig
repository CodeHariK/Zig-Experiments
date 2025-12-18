const std = @import("std");
const t = std.testing;

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

pub fn fromBits(comptime N: u8, bits: [N]u1) UIntN(N) {
    var value: UIntN(N) = 0;
    inline for (0..N) |i| {
        value |= @as(UIntN(N), bits[i]) << (N - 1 - i);
    }
    return value;
}

pub fn b2(value: usize) [2]u1 {
    return toBits(2, @truncate(value));
}
pub fn b3(value: usize) [3]u1 {
    return toBits(3, @truncate(value));
}
pub fn b4(value: usize) [4]u1 {
    return toBits(4, @truncate(value));
}
pub fn b8(value: usize) [8]u1 {
    return toBits(8, @truncate(value));
}
pub fn b16(value: usize) [16]u1 {
    return toBits(16, @truncate(value));
}

pub fn fb2(bits: [2]u1) u2 {
    return fromBits(2, bits);
}
pub fn fb3(bits: [3]u1) u3 {
    return fromBits(3, bits);
}
pub fn fb4(bits: [4]u1) u4 {
    return fromBits(4, bits);
}
pub fn fb8(bits: [8]u1) u8 {
    return fromBits(8, bits);
}
pub fn fb16(bits: [16]u1) u16 {
    return fromBits(16, bits);
}

test "utils" {
    try t.expectEqual([2]u1{ 0, 1 }, b2(1));
    try t.expectEqual([3]u1{ 0, 1, 0 }, b3(2));
    try t.expectEqual([4]u1{ 0, 1, 0, 1 }, b4(5));
    try t.expectEqual([8]u1{ 0, 0, 0, 0, 0, 1, 1, 1 }, b8(7));
    try t.expectEqual([16]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0 }, b16(8));

    try t.expectEqual(@as(u2, 1), fb2([2]u1{ 0, 1 }));
    try t.expectEqual(@as(u3, 2), fb3([3]u1{ 0, 1, 0 }));
    try t.expectEqual(@as(u4, 5), fb4([4]u1{ 0, 1, 0, 1 }));
    try t.expectEqual(@as(u8, 7), fb8([8]u1{ 0, 0, 0, 0, 0, 1, 1, 1 }));
    try t.expectEqual(@as(u16, 8), fb16([16]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0 }));
}
