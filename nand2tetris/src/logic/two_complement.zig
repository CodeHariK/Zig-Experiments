//! Two's Complement Negation
//!
//! Two's complement is the standard way to represent signed integers in binary.
//! To negate a number: invert all bits, then add 1.
//!
//! ## Formula
//!
//! ```
//! -n = ~n + 1 = (2^N - 1 - n) + 1 = 2^N - n
//! ```
//!
//! Where N is the bit width and `~` is bitwise NOT.
//!
//! ## 4-bit Example
//!
//! | Binary | Unsigned | Signed |
//! |--------|----------|--------|
//! | 0000   | 0        | 0      |
//! | 0001   | 1        | 1      |
//! | 0010   | 2        | 2      |
//! | 0011   | 3        | 3      |
//! | 0100   | 4        | 4      |
//! | 0101   | 5        | 5      |
//! | 0110   | 6        | 6      |
//! | 0111   | 7        | 7      |
//! | 1000   | 8        | -8     |
//! | 1001   | 9        | -7     |
//! | 1010   | 10       | -6     |
//! | 1011   | 11       | -5     |
//! | 1100   | 12       | -4     |
//! | 1101   | 13       | -3     |
//! | 1110   | 14       | -2     |
//! | 1111   | 15       | -1     |
//!
//! ## Key Properties
//!
//! - MSB indicates sign: 0 = positive, 1 = negative
//! - Range for N bits: -2^(N-1) to 2^(N-1)-1
//! - Addition works the same for signed and unsigned (modular arithmetic)
//! - `~n = -n - 1` (bitwise NOT equals -(n+1))
//!
//! ## Example: Negating 5 (4-bit)
//!
//! ```
//! 5    = 0101
//! ~5   = 1010
//! ~5+1 = 1011 = -5
//!
//! Verify: 5 + (-5) = 0101 + 1011 = 10000 = 0000 (mod 16)
//! ```

const std = @import("std");
const testing = std.testing;

const adder = @import("adder.zig");

const types = @import("types");
const UIntN = types.UIntN;
const b4 = types.b4;
const b16 = types.b16;

// Two's complement is a way to represent negative numbers in binary.
// Modular arithmetic

// Inv(n) = N - 1 - n = !n
// !n = -n - 1 = -(n + 1)
// !(n - 1) = -n
// -n = !(n - 1) = !(n + -1)

// 0 = !(0 + -1) = !(1111) = 0
// -1 = !(1 + -1) = !(0 + 0) = !0 = 1111
// -2 = !(2 + -1) = !(1 + 0) = !1 = 1110
// !0 = -1
// !-1 = 0
// !1 = -2

// Inv16(n) = 1111 - n

// TwoComplement(n) = Inv(n) + 1 = N - n = -n (modulo N)
// TwoComplement(n) + n = N = 0 (modulo N)

// INDEX(n) = N - INDEX(-n)
// INDEX(-n) = N - INDEX(n)

// ONE'S             TWO'S
//                    +1

// 0000  ->   0  ->  0001  ->   1 = Inv(1111) + 1 = 1 = Inv(15) + 1 = 16 - 15 = 0001
// 0001  ->   1  ->  0010  ->   2 = Inv(1110) + 1 = 2 = Inv(14) + 1 = 16 - 14 = 0010
// 0010  ->   2  ->  0011  ->   3 = Inv(1101) + 1 = 3 = Inv(13) + 1 = 16 - 13 = 0011
// 0011  ->   3  ->  0100  ->   4 = Inv(1100) + 1 = 4 = Inv(12) + 1 = 16 - 12 = 0100
// 0100  ->   4  ->  0101  ->   5 = Inv(1011) + 1 = 5 = Inv(11) + 1 = 16 - 11 = 0101
// 0101  ->   5  ->  0110  ->   6 = Inv(1010) + 1 = 6 = Inv(10) + 1 = 16 - 10 = 0110
// 0110  ->   6  ->  0111  ->   7 = Inv(1001) + 1 = 7 = Inv(9)  + 1 = 16 - 9  = 0111
// 0111  ->   7  ->  1000  ->  -8 = Inv(1000) + 1 = 1 = Inv(8)  + 1 = 16 - 8  = 1000

// 1000  ->  -7  ->  1001  ->  -7 = Inv(0111) + 1 = 8 = Inv(7)  + 1 = 16 - 7  = 1001
// 1001  ->  -6  ->  1010  ->  -6 = Inv(0110) + 1 = 7 = Inv(6)  + 1 = 16 - 6  = 1010
// 1010  ->  -5  ->  1011  ->  -5 = Inv(0101) + 1 = 6 = Inv(5)  + 1 = 16 - 5  = 1011
// 1011  ->  -4  ->  1100  ->  -4 = Inv(0100) + 1 = 5 = Inv(4)  + 1 = 16 - 4  = 1100
// 1100  ->  -3  ->  1101  ->  -3 = Inv(0011) + 1 = 4 = Inv(3)  + 1 = 16 - 3  = 1101
// 1101  ->  -2  ->  1110  ->  -2 = Inv(0010) + 1 = 3 = Inv(2)  + 1 = 16 - 2  = 1110
// 1110  ->  -1  ->  1111  ->  -1 = Inv(0001) + 1 = 2 = Inv(1)  + 1 = 16 - 1  = 1111
// 1111  ->  -0  ->  0000  ->   0 = Inv(0000) + 1 = 1 = Inv(0)  + 1 = 16 - 0  = 0000

//  0 (0000)  ->   0 (0000)
//  1 (0001)  ->   1 (0001)
//  2 (0010)  ->   2 (0010)
//  3 (0011)  ->   3 (0011)
//  4 (0100)  ->   4 (0100)
//  5 (0101)  ->   5 (0101)
//  6 (0110)  ->   6 (0110)
//  7 (0111)  ->   7 (0111)
// --------------------------
//  8 (1000)  ->  -8 (1000)
//  9 (1001)  ->  -7 (1001)
// 10 (1010)  ->  -6 (1010)
// 11 (1011)  ->  -5 (1011)
// 12 (1100)  ->  -4 (1100)
// 13 (1101)  ->  -3 (1101)
// 14 (1110)  ->  -2 (1110)
// 15 (1111)  ->  -1 (1111)

// -n = Inv(n) + 1 = N - n

// -n = 16 - n
// 0  1  2  3  4  5  6  7   8   9  10  11  12  13  14  15
// 0  1  2  3  4  5  6  7  -8  -7  -6  -5  -4  -3  -2  -1

// 5 = 0101
// -5 = 1011
// -5 = Inv(5) + 1 = 16 - 5 = 1101 = 16 - INDEX(5)
// 5 = Inv(-5) + 1 = 16 - 1101 = 0101 = 16 - INDEX(-5)
// 5 + (-5) = 0101 + 1011 = 10000 = 0 (modulo 16)
// 5 + -7 = 0101 + 1001 = 1110 = -2 (modulo 16)
// -5 + -2 = 1011 + 1110 = 11001 = -7 (modulo 16)

// ------------------------------------------------------------

//  -    +    +    +
// -8    4    2    1

//  0    0    0    0   ->   0
//  0    0    0    1   ->   1
//  0    0    1    0   ->   2
//  0    0    1    1   ->   3
//  0    1    0    0   ->   4
//  0    1    0    1   ->   5
//  0    1    1    0   ->   6
//  0    1    1    1   ->   7

//  1    0    0    0   ->  -8
//  1    0    0    1   ->  -7
//  1    0    1    0   ->  -6
//  1    0    1    1   ->  -5
//  1    1    0    0   ->  -4
//  1    1    0    1   ->  -3
//  1    1    1    0   ->  -2
//  1    1    1    1   ->  -1

// - a * 2^3
// + b * 2^2
// + c * 2^1
// + d * 2^0

//-----------------------------------------------------------

// ============================================================================
// Two's Complement Negation (Bit-Array Version)
// ============================================================================

pub inline fn TWO_COMPLEMENT(comptime N: u8, in: [N]u1) [N]u1 {
    // Step 1: Invert all bits
    var inverted: [N]u1 = undefined;
    inline for (0..N) |i| {
        inverted[i] = ~in[i];
    }
    // Step 2: Add 1
    return adder.INCN(N, inverted).sum;
}

/// 4-bit two's complement negation.
pub inline fn TWO_COMPLEMENT_4(in: [4]u1) [4]u1 {
    return TWO_COMPLEMENT(4, in);
}

/// 16-bit two's complement negation.
pub inline fn TWO_COMPLEMENT_16(in: [16]u1) [16]u1 {
    return TWO_COMPLEMENT(16, in);
}

// ============================================================================
// Two's Complement Negation (Integer Version) - Suffix _I
// ============================================================================

/// Computes two's complement negation (integer version).
pub inline fn TWO_COMPLEMENT_I(comptime N: u8, in: UIntN(N)) UIntN(N) {
    return ~in +% 1; // Wrapping add for overflow
}

/// 4-bit two's complement negation (integer version).
pub inline fn TWO_COMPLEMENT_4_I(in: u4) u4 {
    return TWO_COMPLEMENT_I(4, in);
}

/// 16-bit two's complement negation (integer version).
pub inline fn TWO_COMPLEMENT_16_I(in: u16) u16 {
    return TWO_COMPLEMENT_I(16, in);
}

// ============================================================================
// Tests
// ============================================================================

test "TWO_COMPLEMENT_4" {
    std.debug.print("\nTWO_COMPLEMENT_4------------------\n", .{});
    for (0..16) |i| {
        const in: u4 = @intCast(i);
        const expected: u4 = -%in; // Zig's wrapping negation

        const result = TWO_COMPLEMENT_4(b4(in));
        try testing.expectEqual(b4(expected), result);

        const result_i = TWO_COMPLEMENT_4_I(in);
        try testing.expectEqual(expected, result_i);

        std.debug.print("-{} = {} (binary: {b:0>4})\n", .{ in, result_i, result_i });
    }

    std.debug.print("\nTWO_COMPLEMENT_16------------------\n", .{});
    const TestCase = struct { in: u16, out: u16 };
    const cases = [_]TestCase{
        .{ .in = 0, .out = 0 },
        .{ .in = 1, .out = 65535 }, // -1 = 0xFFFF
        .{ .in = 2, .out = 65534 }, // -2 = 0xFFFE
        .{ .in = 100, .out = 65436 }, // -100
        .{ .in = 1000, .out = 64536 }, // -1000
        .{ .in = 32767, .out = 32769 }, // -(2^15 - 1) = 2^15 + 1
        .{ .in = 32768, .out = 32768 }, // -(-32768) = -32768 (special case, MIN_INT)
        .{ .in = 65535, .out = 1 }, // -(-1) = 1
        .{ .in = 65534, .out = 2 }, // -(-2) = 2
        .{ .in = 0x1234, .out = 0xEDCC }, // arbitrary value
    };

    for (cases) |tc| {
        const result = TWO_COMPLEMENT_16(b16(tc.in));
        try testing.expectEqual(b16(tc.out), result);

        const result_i = TWO_COMPLEMENT_16_I(tc.in);
        try testing.expectEqual(tc.out, result_i);

        std.debug.print("-{} = {} (hex: 0x{X:0>4})\n", .{ tc.in, result_i, result_i });
    }

    std.debug.print("\nDOUBLE NEGATION------------------\n", .{});
    const values = [_]u16{ 0, 1, 2, 100, 1000, 32767, 0xFFFF, 0xFFFE };
    for (values) |val| {
        const neg = TWO_COMPLEMENT_16_I(val);
        const double_neg = TWO_COMPLEMENT_16_I(neg);
        try testing.expectEqual(val, double_neg);
        std.debug.print("-(-{}) = {}\n", .{ val, double_neg });
    }
}
