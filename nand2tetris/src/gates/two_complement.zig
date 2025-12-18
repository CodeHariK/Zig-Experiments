const std = @import("std");
const t = std.testing;

const adder = @import("adder.zig");

const u = @import("utils.zig");
const UIntN = u.UIntN;
const b4 = u.b4;
const b16 = u.b16;
const toBits = u.toBits;
const fromBits = u.fromBits;

// Two's complement is a way to represent negative numbers in binary.
// Modular arithmetic

// FLIP(n) = N - 1 - n
// FLIP16(n) = 1111 - n

// TwoComplement(n) = FLIP(n) + 1 = N - n = -n (modulo N)
// TwoComplement(n) + n = N = 0 (modulo N)

// INDEX(n) = N - INDEX(-n)
// INDEX(-n) = N - INDEX(n)

// ONE'S             TWO'S
//                    +1

// 0000  ->   0  ->  0001  ->   1 = FLIP(1111) + 1 = 1 = FLIP(15) + 1 = 16 - 15 = 0001
// 0001  ->   1  ->  0010  ->   2 = FLIP(1110) + 1 = 2 = FLIP(14) + 1 = 16 - 14 = 0010
// 0010  ->   2  ->  0011  ->   3 = FLIP(1101) + 1 = 3 = FLIP(13) + 1 = 16 - 13 = 0011
// 0011  ->   3  ->  0100  ->   4 = FLIP(1100) + 1 = 4 = FLIP(12) + 1 = 16 - 12 = 0100
// 0100  ->   4  ->  0101  ->   5 = FLIP(1011) + 1 = 5 = FLIP(11) + 1 = 16 - 11 = 0101
// 0101  ->   5  ->  0110  ->   6 = FLIP(1010) + 1 = 6 = FLIP(10) + 1 = 16 - 10 = 0110
// 0110  ->   6  ->  0111  ->   7 = FLIP(1001) + 1 = 7 = FLIP(9)  + 1 = 16 - 9  = 0111
// 0111  ->   7  ->  1000  ->  -8 = FLIP(1000) + 1 = 1 = FLIP(8)  + 1 = 16 - 8  = 1000

// 1000  ->  -7  ->  1001  ->  -7 = FLIP(0111) + 1 = 8 = FLIP(7)  + 1 = 16 - 7  = 1001
// 1001  ->  -6  ->  1010  ->  -6 = FLIP(0110) + 1 = 7 = FLIP(6)  + 1 = 16 - 6  = 1010
// 1010  ->  -5  ->  1011  ->  -5 = FLIP(0101) + 1 = 6 = FLIP(5)  + 1 = 16 - 5  = 1011
// 1011  ->  -4  ->  1100  ->  -4 = FLIP(0100) + 1 = 5 = FLIP(4)  + 1 = 16 - 4  = 1100
// 1100  ->  -3  ->  1101  ->  -3 = FLIP(0011) + 1 = 4 = FLIP(3)  + 1 = 16 - 3  = 1101
// 1101  ->  -2  ->  1110  ->  -2 = FLIP(0010) + 1 = 3 = FLIP(2)  + 1 = 16 - 2  = 1110
// 1110  ->  -1  ->  1111  ->  -1 = FLIP(0001) + 1 = 2 = FLIP(1)  + 1 = 16 - 1  = 1111
// 1111  ->  -0  ->  0000  ->   0 = FLIP(0000) + 1 = 1 = FLIP(0)  + 1 = 16 - 0  = 0000

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

// -n = FLIP(n) + 1 = N - n

// -n = 16 - n
// 0  1  2  3  4  5  6  7   8   9  10  11  12  13  14  15
// 0  1  2  3  4  5  6  7  -8  -7  -6  -5  -4  -3  -2  -1

// 5 = 0101
// -5 = 1011
// -5 = FLIP(5) + 1 = 16 - 5 = 1101 = 16 - INDEX(5)
// 5 = FLIP(-5) + 1 = 16 - 1101 = 0101 = 16 - INDEX(-5)
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

pub inline fn TWO_COMPLEMENT(comptime N: u8, in: [N]u1) [N]u1 {
    // Step 1: NOT all bits (flip)
    var flipped: [N]u1 = undefined;
    inline for (0..N) |i| {
        flipped[i] = ~in[i];
    }
    // Step 2: Add 1 using ripple adder
    return adder.INCN(N, flipped).sum;
}

pub inline fn TWO_COMPLEMENT_4(in: [4]u1) [4]u1 {
    return TWO_COMPLEMENT(4, in);
}

pub inline fn TWO_COMPLEMENT_16(in: [16]u1) [16]u1 {
    return TWO_COMPLEMENT(16, in);
}

pub inline fn TWO_COMPLEMENT_I(comptime N: u8, in: UIntN(N)) UIntN(N) {
    // FLIP(n) + 1, wrapping addition for overflow
    return ~in +% 1;
}

pub inline fn TWO_COMPLEMENT_4_I(in: u4) u4 {
    return TWO_COMPLEMENT_I(4, in);
}

pub inline fn TWO_COMPLEMENT_16_I(in: u16) u16 {
    return TWO_COMPLEMENT_I(16, in);
}

test "two_complement_4" {
    std.debug.print("\nTWO_COMPLEMENT_4------------------\n", .{});

    // negate(n) = 16 - n (wrapping)
    for (0..16) |i| {
        const in: u4 = @intCast(i);
        const expected: u4 = -%in; // wrapping negation

        // Test bit-array version
        const r = TWO_COMPLEMENT_4(b4(in));
        try t.expectEqual(b4(expected), r);

        // Test integer version
        const r_i = TWO_COMPLEMENT_4_I(in);
        try t.expectEqual(expected, r_i);

        std.debug.print("{} = {} (binary: {b:0>4})\n", .{ in, r_i, r_i });
    }
}

test "two_complement_16" {
    std.debug.print("\nTWO_COMPLEMENT_16------------------\n", .{});

    const tests16 = [_]struct { in: u16, out: u16 }{
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

    for (tests16) |tc| {
        // Test bit-array version
        const r = TWO_COMPLEMENT_16(b16(tc.in));
        try t.expectEqual(b16(tc.out), r);

        // Test integer version
        const r_i = TWO_COMPLEMENT_16_I(tc.in);
        try t.expectEqual(tc.out, r_i);

        std.debug.print("{} = {} (hex: 0x{X:0>4})\n", .{ tc.in, r_i, r_i });
    }
}
