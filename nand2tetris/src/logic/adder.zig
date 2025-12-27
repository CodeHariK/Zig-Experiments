//! Adder Circuits
//!
//! Building blocks for binary addition:
//! - Half Adder: adds two bits
//! - Full Adder: adds two bits plus carry-in
//! - Ripple Carry Adder: chains full adders for N-bit addition
//!
//! These form the foundation of the ALU's arithmetic operations.

const std = @import("std");
const testing = std.testing;

const types = @import("types");
const UIntN = types.UIntN;
const b4 = types.b4;
const b16 = types.b16;
const toBits = types.toBits;

/// Result of a single-bit addition.
pub const AdderResult = struct {
    sum: u1,
    carry: u1,
};

// ============================================================================
// Single-Bit Adders
// ============================================================================

/// Half Adder: adds two bits, produces sum and carry.
///
/// Truth table:
///   a  b | sum carry
///   0  0 |  0    0
///   0  1 |  1    0
///   1  0 |  1    0
///   1  1 |  0    1
pub inline fn HALF_ADDER(a: u1, b: u1) AdderResult {
    return .{
        .sum = a ^ b,
        .carry = a & b,
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

pub inline fn FULL_ADDER(in1: u1, in0: u1, carry: u1) AdderResult {
    const sum1 = HALF_ADDER(in1, in0);
    const sum2 = HALF_ADDER(sum1.sum, carry);
    return .{
        .sum = sum2.sum,
        .carry = sum1.carry | sum2.carry,
    };
}

// ============================================================================
// Multi-Bit Adders (Bit-Array Version)
// ============================================================================

/// Result of an N-bit addition.
pub fn RippleAdderResult(comptime N: u8) type {
    return struct {
        sum: [N]u1,
        carry: u1,
    };
}

/// N-bit ripple carry adder.
/// Adds two N-bit numbers represented as bit arrays (LSB first).
/// Chains N full adders, propagating carry from LSB (index 0) to MSB (index N-1).
pub inline fn RIPPLE_ADDER(comptime N: u8, a: [N]u1, b: [N]u1) RippleAdderResult(N) {
    var carry: u1 = 0;
    var sum: [N]u1 = undefined;

    // Process from LSB (index 0) to MSB (index N-1)
    inline for (0..N) |i| {
        const result = FULL_ADDER(a[i], b[i], carry);
        sum[i] = result.sum;
        carry = result.carry;
    }

    return .{ .sum = sum, .carry = carry };
}

/// 16-bit ripple carry adder.
pub inline fn RIPPLE_ADDER_16(a: [16]u1, b: [16]u1) RippleAdderResult(16) {
    return RIPPLE_ADDER(16, a, b);
}

/// N-bit incrementer: adds 1 to the input.
pub inline fn INCN(comptime N: u8, in: [N]u1) RippleAdderResult(N) {
    return RIPPLE_ADDER(N, in, toBits(N, 1));
}

/// 16-bit incrementer.
pub inline fn INC16(in: [16]u1) RippleAdderResult(16) {
    return INCN(16, in);
}

// ============================================================================
// Multi-Bit Adders (Integer Version) - Suffix _I
// ============================================================================

/// Result of an N-bit integer addition.
pub fn RippleAdderResult_I(comptime N: u8) type {
    return struct {
        sum: UIntN(N),
        carry: u1,
    };
}

/// N-bit ripple carry adder (integer version).
/// Uses Zig's built-in overflow detection for efficiency.
pub inline fn RIPPLE_ADDER_I(comptime N: u8, a: UIntN(N), b: UIntN(N)) RippleAdderResult_I(N) {
    const result = @addWithOverflow(a, b);
    return .{ .sum = result[0], .carry = result[1] };
}

/// 16-bit ripple carry adder (integer version).
pub inline fn RIPPLE_ADDER_16_I(a: u16, b: u16) RippleAdderResult_I(16) {
    return RIPPLE_ADDER_I(16, a, b);
}

/// N-bit incrementer (integer version).
pub inline fn INCN_I(comptime N: u8, in: UIntN(N)) RippleAdderResult_I(N) {
    return RIPPLE_ADDER_I(N, in, 1);
}

/// 16-bit incrementer (integer version).
pub inline fn INC16_I(in: u16) RippleAdderResult_I(16) {
    return INCN_I(16, in);
}

// ============================================================================
// Tests
// ============================================================================

test "ADDER" {
    std.debug.print("\nHALF_ADDER------------------\n", .{});
    std.debug.print("a b -> carry sum\n", .{});
    for (0..2) |i| {
        const a: u1 = @intCast(i);
        for (0..2) |j| {
            const b: u1 = @intCast(j);
            const result = HALF_ADDER(a, b);
            try testing.expectEqual(a ^ b, result.sum);
            try testing.expectEqual(a & b, result.carry);
            std.debug.print("{b} {b} ->   {b}    {b}\n", .{ a, b, result.carry, result.sum });
        }
    }

    std.debug.print("\nFULL_ADDER------------------\n", .{});
    std.debug.print("a b cin -> cout sum\n", .{});
    for (0..2) |i| {
        const a: u1 = @intCast(i);
        for (0..2) |j| {
            const b: u1 = @intCast(j);
            for (0..2) |k| {
                const cin: u1 = @intCast(k);
                const result = FULL_ADDER(a, b, cin);
                try testing.expectEqual(a ^ b ^ cin, result.sum);
                try testing.expectEqual((a & b) | (b & cin) | (cin & a), result.carry);
                std.debug.print("{b} {b}  {b}  ->  {b}   {b}\n", .{ a, b, cin, result.carry, result.sum });
            }
        }
    }

    std.debug.print("\nRIPPLE_ADDER u4------------------\n", .{});
    const TestCase = struct { a: u4, b: u4, sum: u4, carry: u1 };
    const cases = [_]TestCase{
        .{ .a = 5, .b = 3, .sum = 8, .carry = 0 },
        .{ .a = 10, .b = 5, .sum = 15, .carry = 0 },
        .{ .a = 15, .b = 1, .sum = 0, .carry = 1 },
        .{ .a = 9, .b = 9, .sum = 2, .carry = 1 },
    };

    for (cases) |tc| {
        const r = RIPPLE_ADDER(4, b4(tc.a), b4(tc.b));
        try testing.expectEqual(b4(tc.sum), r.sum);
        try testing.expectEqual(tc.carry, r.carry);

        const r_i = RIPPLE_ADDER_I(4, tc.a, tc.b);
        try testing.expectEqual(tc.sum, r_i.sum);
        try testing.expectEqual(tc.carry, r_i.carry);

        std.debug.print("{} + {} = {} (carry={})\n", .{ tc.a, tc.b, r_i.sum, r_i.carry });
    }

    std.debug.print("\nRIPPLE_ADDER u16------------------\n", .{});
    const TestCase16 = struct { a: u16, b: u16, sum: u16, carry: u1 };
    const casesTestCase16 = [_]TestCase16{
        .{ .a = 1000, .b = 2000, .sum = 3000, .carry = 0 },
        .{ .a = 0xFFFF, .b = 1, .sum = 0, .carry = 1 },
        .{ .a = 0x8000, .b = 0x8000, .sum = 0, .carry = 1 },
        .{ .a = 12345, .b = 54321, .sum = 1130, .carry = 1 },
        .{ .a = 0b0001001000110100, .b = 0b1001100001110110, .sum = 0b1010101010101010, .carry = 0 },
    };

    for (casesTestCase16) |tc| {
        const r = RIPPLE_ADDER_16(b16(tc.a), b16(tc.b));
        try testing.expectEqual(b16(tc.sum), r.sum);
        try testing.expectEqual(tc.carry, r.carry);

        const r_i = RIPPLE_ADDER_16_I(tc.a, tc.b);
        try testing.expectEqual(tc.sum, r_i.sum);
        try testing.expectEqual(tc.carry, r_i.carry);

        std.debug.print("{} + {} = {} (carry={})\n", .{ tc.a, tc.b, r_i.sum, r_i.carry });
    }

    std.debug.print("\nINC16------------------\n", .{});
    const TestCaseInc16 = struct { in: u16, out: u16, carry: u1 };
    const casesTestCaseInc16 = [_]TestCaseInc16{
        .{ .in = 0, .out = 1, .carry = 0 },
        .{ .in = 1, .out = 2, .carry = 0 },
        .{ .in = 0b1111111111111011, .out = 0b1111111111111100, .carry = 0 },
        .{ .in = 65535, .out = 0, .carry = 1 },
    };

    for (casesTestCaseInc16) |tc| {
        const r = INC16(b16(tc.in));
        try testing.expectEqual(b16(tc.out), r.sum);
        try testing.expectEqual(tc.carry, r.carry);

        const r_i = INC16_I(tc.in);
        try testing.expectEqual(tc.out, r_i.sum);
        try testing.expectEqual(tc.carry, r_i.carry);

        std.debug.print("{} + 1 = {} (carry={})\n", .{ tc.in, r_i.sum, r_i.carry });
    }
}
