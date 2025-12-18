const std = @import("std");
const t = std.testing;

const u = @import("utils.zig");
const UIntN = u.UIntN;
const b4 = u.b4;
const b16 = u.b16;

pub const AdderOut = struct {
    sum: u1,
    carry: u1,
};

// in1 in0 carry sum
//  0   0    0    0
//  0   1    0    1
//  1   0    0    1
//  1   1    1    0

pub inline fn HALF_ADDER(in1: u1, in0: u1) AdderOut {
    return .{
        .sum = in1 ^ in0,
        .carry = in1 & in0,
    };
}

// in1 in0  c    sum1   sum2    carry   sum

//  0   0   0    0,0    0,0       0      0
//  0   1   0    0,1    0,1       0      1
//  1   0   0    0,1    0,1       0      1
//  1   1   0    1,0    0,0       1      0

//  0   0   1    0,0    0,1       0      1
//  0   1   1    0,1    1,0       1      0
//  1   0   1    0,1    1,0       1      0
//  1   1   1    1,0    1,1       1      1

pub inline fn FULL_ADDER(in1: u1, in0: u1, carry: u1) AdderOut {
    const sum1 = HALF_ADDER(in1, in0);
    const sum2 = HALF_ADDER(sum1.sum, carry);
    return .{
        .sum = sum2.sum,
        .carry = sum1.carry | sum2.carry,
    };
}

// ============================================================================
// Bit-array versions (inputs are [N]u1)
// ============================================================================

/// Return type for RIPPLE_ADDER with N-bit sum
pub fn RippleAdderResult(comptime N: u8) type {
    return struct {
        sum: [N]u1,
        carry: u1,
    };
}

/// N-bit ripple carry adder: adds two N-bit numbers represented as arrays of u1 (MSB first)
pub inline fn RIPPLE_ADDER(comptime N: u8, in1: [N]u1, in0: [N]u1) RippleAdderResult(N) {
    var carry: u1 = 0;
    var sum: [N]u1 = undefined;

    // Process from LSB (index N-1) to MSB (index 0)
    inline for (0..N) |i| {
        const bit_idx = N - 1 - i;
        const out = FULL_ADDER(in1[bit_idx], in0[bit_idx], carry);
        sum[bit_idx] = out.sum; // Store at same index as input bits
        carry = out.carry;
    }

    return .{ .sum = sum, .carry = carry };
}

pub inline fn RIPPLE_ADDER_16(in1: [16]u1, in0: [16]u1) RippleAdderResult(16) {
    return RIPPLE_ADDER(16, in1, in0);
}

// ============================================================================
// Integer versions - suffix _I
// ============================================================================

pub fn RippleAdderResult_I(comptime N: u8) type {
    return struct {
        sum: UIntN(N),
        carry: u1,
    };
}

/// N-bit ripple carry adder: adds two N-bit integers
pub inline fn RIPPLE_ADDER_I(comptime N: u8, in1: UIntN(N), in0: UIntN(N)) RippleAdderResult_I(N) {
    const result = @addWithOverflow(in1, in0);
    return .{ .sum = result[0], .carry = result[1] };

    // const U = UIntN(N);
    // var carry: u1 = 0;
    // var sum: U = 0;

    // // Process from LSB to MSB
    // inline for (0..N) |i| {
    //     const a_bit: u1 = @truncate(in1 >> i);
    //     const b_bit: u1 = @truncate(in0 >> i);
    //     const out = FULL_ADDER(a_bit, b_bit, carry);
    //     sum |= @as(U, out.sum) << i;
    //     carry = out.carry;
    // }

    // return .{ .sum = sum, .carry = carry };
}

/// 16-bit ripple adder convenience function (integer version)
pub inline fn RIPPLE_ADDER_16_I(in1: u16, in0: u16) RippleAdderResult_I(16) {
    return RIPPLE_ADDER_I(16, in1, in0);
}

test "ADDER TEST" {
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
    std.debug.print("\nRIPPLE_ADDER u4------------------\n", .{});

    const tests4 = [_]struct { a: u4, b: u4, sum: u4, carry: u1 }{
        .{ .a = 5, .b = 3, .sum = 8, .carry = 0 },
        .{ .a = 10, .b = 5, .sum = 15, .carry = 0 },
        .{ .a = 15, .b = 1, .sum = 0, .carry = 1 },
        .{ .a = 9, .b = 9, .sum = 2, .carry = 1 },
    };

    for (tests4) |tc| {
        // Test bit-array version
        const r = RIPPLE_ADDER(4, b4(tc.a), b4(tc.b));
        try t.expectEqual(r.sum, b4(tc.sum));
        try t.expectEqual(r.carry, tc.carry);

        // Test integer version
        const r_i = RIPPLE_ADDER_I(4, tc.a, tc.b);
        try t.expectEqual(r_i.sum, tc.sum);
        try t.expectEqual(r_i.carry, tc.carry);

        std.debug.print("{} + {} = {} (carry={})\n", .{ tc.a, tc.b, r_i.sum, r_i.carry });
    }

    std.debug.print("\nRIPPLE_ADDER u16------------------\n", .{});

    const tests16 = [_]struct { a: u16, b: u16, sum: u16, carry: u1 }{
        .{ .a = 1000, .b = 2000, .sum = 3000, .carry = 0 },
        .{ .a = 0xFFFF, .b = 1, .sum = 0, .carry = 1 },
        .{ .a = 0x8000, .b = 0x8000, .sum = 0, .carry = 1 },
        .{ .a = 12345, .b = 54321, .sum = 1130, .carry = 1 },
        .{ .a = 0b0001001000110100, .b = 0b1001100001110110, .sum = 0b1010101010101010, .carry = 0 },
    };

    for (tests16) |tc| {
        // Test bit-array version (via convenience function)
        const r = RIPPLE_ADDER_16(b16(tc.a), b16(tc.b));
        try t.expectEqual(r.sum, b16(tc.sum));
        try t.expectEqual(r.carry, tc.carry);

        // Test integer version
        const r_i = RIPPLE_ADDER_16_I(tc.a, tc.b);
        try t.expectEqual(r_i.sum, tc.sum);
        try t.expectEqual(r_i.carry, tc.carry);

        std.debug.print("{} + {} = {} (carry={})\n", .{ tc.a, tc.b, r_i.sum, r_i.carry });
    }
}
