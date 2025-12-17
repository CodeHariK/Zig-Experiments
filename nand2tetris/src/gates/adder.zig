const std = @import("std");
const t = std.testing;
const u = @import("utils.zig");

pub const AdderOut = struct {
    sum: u1,
    carry: u1,
};

// a b carry sum
// 0 0   0    0
// 0 1   0    1
// 1 0   0    1
// 1 1   1    0

pub inline fn HALF_ADDER(a: u1, b: u1) AdderOut {
    return .{
        .sum = a ^ b,
        .carry = a & b,
    };
}

// a b c     sum1   sum2      carry   sum

// 0 0 0      0,0    0,0        0      0
// 0 1 0      0,1    0,1        0      1
// 1 0 0      0,1    0,1        0      1
// 1 1 0      1,0    0,0        1      0

// 0 0 1      0,0    0,1        0      1
// 0 1 1      0,1    1,0        1      0
// 1 0 1      0,1    1,0        1      0
// 1 1 1      1,0    1,1        1      1

pub inline fn FULL_ADDER(a: u1, b: u1, carry: u1) AdderOut {
    const sum1 = HALF_ADDER(a, b);
    const sum2 = HALF_ADDER(sum1.sum, carry);
    return .{
        .sum = sum2.sum,
        .carry = sum1.carry | sum2.carry,
    };
}

/// Return type for RIPPLE_ADDER with N-bit sum
pub fn RippleAdderResult(comptime N: u8) type {
    return struct {
        sum: u.UIntN(N),
        carry: u1,
    };
}

/// N-bit ripple carry adder: adds two N-bit numbers represented as arrays of u1 (MSB first)
pub inline fn RIPPLE_ADDER(comptime N: u16, a: [N]u1, b: [N]u1) RippleAdderResult(N) {
    const U = u.UIntN(N);
    var carry: u1 = 0;
    var sum: U = 0;

    // Process from LSB (index N-1) to MSB (index 0)
    inline for (0..N) |i| {
        const bit_idx = N - 1 - i; // LSB first
        const out = FULL_ADDER(a[bit_idx], b[bit_idx], carry);
        sum |= @as(U, out.sum) << i;
        carry = out.carry;
    }

    return .{ .sum = sum, .carry = carry };
}

pub inline fn RIPPLE_ADDER_16(a: u16, b: u16) RippleAdderResult(16) {
    return RIPPLE_ADDER(16, u.toBits(16, a), u.toBits(16, b));
}

test "adder" {
    std.debug.print("\nHALF_ADDER------------------\n", .{});
    for (0..2) |i| {
        const a: u1 = @intCast(i);
        for (0..2) |j| {
            const b: u1 = @intCast(j);
            const out = HALF_ADDER(a, b);
            try t.expectEqual(out, AdderOut{ .sum = a ^ b, .carry = a & b });
            std.debug.print("{b} {b} -> {b} {b}\n", .{ a, b, out.carry, out.sum });
        }
    }

    std.debug.print("\nFULL_ADDER------------------\n", .{});
    for (0..2) |i| {
        const a: u1 = @intCast(i);
        for (0..2) |j| {
            const b: u1 = @intCast(j);
            for (0..2) |k| {
                const c: u1 = @intCast(k);
                const out = FULL_ADDER(a, b, c);
                try t.expectEqual(out, AdderOut{ .sum = a ^ b ^ c, .carry = (a & b) | (b & c) | (c & a) });
                std.debug.print("{b} {b} {b} -> {b} {b}\n", .{ a, b, c, out.carry, out.sum });
            }
        }
    }
}

test "ripple adder u4" {
    std.debug.print("\nRIPPLE_ADDER u4------------------\n", .{});

    // 5 + 3 = 8, no overflow
    var r = RIPPLE_ADDER(4, u.toBits(4, 5), u.toBits(4, 3));
    try t.expectEqual(r.sum, 8);
    try t.expectEqual(r.carry, 0);
    std.debug.print("5 + 3 = {} (carry={})\n", .{ r.sum, r.carry });

    // 10 + 5 = 15, no overflow
    r = RIPPLE_ADDER(4, u.toBits(4, 10), u.toBits(4, 5));
    try t.expectEqual(r.sum, 15);
    try t.expectEqual(r.carry, 0);
    std.debug.print("10 + 5 = {} (carry={})\n", .{ r.sum, r.carry });

    // 15 + 1 = 0 with carry (overflow)
    r = RIPPLE_ADDER(4, u.toBits(4, 15), u.toBits(4, 1));
    try t.expectEqual(r.sum, 0);
    try t.expectEqual(r.carry, 1);
    std.debug.print("15 + 1 = {} (carry={})\n", .{ r.sum, r.carry });

    // 9 + 9 = 2 with carry (overflow)
    r = RIPPLE_ADDER(4, u.toBits(4, 9), u.toBits(4, 9));
    try t.expectEqual(r.sum, 2);
    try t.expectEqual(r.carry, 1);
    std.debug.print("9 + 9 = {} (carry={})\n", .{ r.sum, r.carry });
}

test "ripple adder u16" {
    std.debug.print("\nRIPPLE_ADDER u16------------------\n", .{});

    // 1000 + 2000 = 3000
    var r = RIPPLE_ADDER(16, u.toBits(16, 1000), u.toBits(16, 2000));
    try t.expectEqual(r.sum, 3000);
    try t.expectEqual(r.carry, 0);
    std.debug.print("1000 + 2000 = {} (carry={})\n", .{ r.sum, r.carry });

    // 0xFFFF + 1 = 0 with carry
    r = RIPPLE_ADDER(16, u.toBits(16, 0xFFFF), u.toBits(16, 1));
    try t.expectEqual(r.sum, 0);
    try t.expectEqual(r.carry, 1);
    std.debug.print("0xFFFF + 1 = {} (carry={})\n", .{ r.sum, r.carry });

    // 0x8000 + 0x8000 = 0 with carry
    r = RIPPLE_ADDER(16, u.toBits(16, 0x8000), u.toBits(16, 0x8000));
    try t.expectEqual(r.sum, 0);
    try t.expectEqual(r.carry, 1);
    std.debug.print("0x8000 + 0x8000 = {} (carry={})\n", .{ r.sum, r.carry });

    // 12345 + 54321 = 66666 (no overflow)
    r = RIPPLE_ADDER(16, u.toBits(16, 12345), u.toBits(16, 54321));
    try t.expectEqual(r.sum, 66666 & 0xFFFF); // 1130 after truncation
    try t.expectEqual(r.carry, 1);
    std.debug.print("12345 + 54321 = {} (carry={})\n", .{ r.sum, r.carry });
}
