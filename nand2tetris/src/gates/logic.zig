//! Logic Gates
//!
//! Fundamental logic gates built from NAND (the universal gate).
//! All gates can be constructed using only NAND, demonstrating that NAND is
//! functionally complete. The implementations here use Zig's native operators
//! for efficiency, but NAND-based equivalents are documented.
//!
//! Gate naming follows HDL convention (SCREAMING_CASE).

const std = @import("std");
const testing = std.testing;

const mux = @import("mux.zig");
const adder = @import("adder.zig");
const alu = @import("alu.zig");
const two_complement = @import("two_complement.zig");

const types = @import("types");
const b8 = types.b8;
const b16 = types.b16;

/// Logic gates namespace - contains all basic and compound gates.
pub const Logic = struct {

    // ========================================================================
    // Single-Bit Gates
    // ========================================================================

    /// NAND gate - the universal gate from which all others can be built.
    /// Truth table: 00→1, 01→1, 10→1, 11→0
    pub inline fn NAND(a: u1, b: u1) u1 {
        return ~(a & b);
    }

    /// NOT gate (inverter).
    /// NAND equivalent: NAND(a, a)
    pub inline fn NOT(a: u1) u1 {
        return ~a;
    }

    /// AND gate.
    /// NAND equivalent: NOT(NAND(a, b))
    pub inline fn AND(a: u1, b: u1) u1 {
        return a & b;
    }

    /// OR gate.
    /// NAND equivalent: NAND(NOT(a), NOT(b))
    pub inline fn OR(a: u1, b: u1) u1 {
        return a | b;
    }

    /// XOR gate (exclusive or).
    pub inline fn XOR(a: u1, b: u1) u1 {
        return a ^ b;

        // return Logic.OR(
        //     Logic.AND(in1, Logic.NOT(in0)),
        //     Logic.AND(Logic.NOT(in1), in0),
        // );

        // const d = Logic.NAND(in1, in0);
        // return Logic.NAND(Logic.NAND(in1, d), Logic.NAND(in0, d));
    }

    /// NOR gate (not or).
    /// NAND equivalent: NOT(OR(a, b))
    pub inline fn NOR(a: u1, b: u1) u1 {
        return ~(a | b);
    }

    /// XNOR gate (exclusive nor / equivalence).
    /// NAND equivalent: NOT(XOR(a, b))
    pub inline fn XNOR(a: u1, b: u1) u1 {
        return ~(a ^ b);
    }

    /// Simple clock signal generator - returns true on even ticks.
    pub inline fn CLOCK(tick: u32) bool {
        return (tick & 1) == 0;
    }

    // ========================================================================
    // 16-Bit Gates (Bit-Array Version)
    // ========================================================================

    /// 16-bit NOT - inverts each bit.
    pub inline fn NOT16(in: [16]u1) [16]u1 {
        var out: [16]u1 = undefined;
        inline for (0..16) |i| out[i] = ~in[i];
        return out;
    }

    /// 16-bit AND - bitwise AND of two 16-bit values.
    pub inline fn AND16(a: [16]u1, b: [16]u1) [16]u1 {
        var out: [16]u1 = undefined;
        inline for (0..16) |i| out[i] = a[i] & b[i];
        return out;
    }

    /// 16-bit OR - bitwise OR of two 16-bit values.
    pub inline fn OR16(a: [16]u1, b: [16]u1) [16]u1 {
        var out: [16]u1 = undefined;
        inline for (0..16) |i| out[i] = a[i] | b[i];
        return out;
    }

    /// 8-way OR - returns 1 if any input bit is 1.
    pub inline fn OR8WAY(in: [8]u1) u1 {
        var out: u1 = 0;
        inline for (0..8) |i| out |= in[i];
        return out;
    }

    // ========================================================================
    // Re-exported MUX/DMUX (Bit-Array Version)
    // ========================================================================

    pub const MUX = mux.MUX;
    pub const MUX16 = mux.MUX16;
    pub const MUX4WAY16 = mux.MUX4WAY16;
    pub const MUX8WAY16 = mux.MUX8WAY16;
    pub const DMUX = mux.DMUX;
    pub const DMUX4WAY = mux.DMUX4WAY;
    pub const DMUX8WAY = mux.DMUX8WAY;

    // ========================================================================
    // Re-exported Adders (Bit-Array Version)
    // ========================================================================

    pub const HALF_ADDER = adder.HALF_ADDER;
    pub const FULL_ADDER = adder.FULL_ADDER;
    pub const RIPPLE_ADDER = adder.RIPPLE_ADDER;
    pub const RIPPLE_ADDER_16 = adder.RIPPLE_ADDER_16;
    pub const INCN = adder.INCN;
    pub const INC16 = adder.INC16;

    // ========================================================================
    // 16-Bit Gates (Integer Version) - Suffix _I
    // ========================================================================

    /// 16-bit NOT (integer version).
    pub inline fn NOT16_I(in: u16) u16 {
        return ~in;
    }

    /// 16-bit AND (integer version).
    pub inline fn AND16_I(a: u16, b: u16) u16 {
        return a & b;
    }

    /// 16-bit OR (integer version).
    pub inline fn OR16_I(a: u16, b: u16) u16 {
        return a | b;
    }

    /// 8-way OR (integer version) - returns 1 if any bit is set.
    pub inline fn OR8WAY_I(in: u8) u1 {
        return if (in != 0) 1 else 0;
    }

    // ========================================================================
    // Re-exported MUX/DMUX (Integer Version)
    // ========================================================================

    pub const MUX_I = mux.MUX_I;
    pub const MUX16_I = mux.MUX16_I;
    pub const MUX4WAY16_I = mux.MUX4WAY16_I;
    pub const MUX8WAY16_I = mux.MUX8WAY16_I;
    pub const DMUX_I = mux.DMUX_I;
    pub const DMUX4WAY_I = mux.DMUX4WAY_I;
    pub const DMUX8WAY_I = mux.DMUX8WAY_I;

    // ========================================================================
    // Re-exported Adders (Integer Version)
    // ========================================================================

    pub const RIPPLE_ADDER_I = adder.RIPPLE_ADDER_I;
    pub const RIPPLE_ADDER_16_I = adder.RIPPLE_ADDER_16_I;
    pub const INCN_I = adder.INCN_I;
    pub const INC16_I = adder.INC16_I;
};

// ============================================================================
// Tests
// ============================================================================

test "run all gate tests" {
    _ = @import("mux.zig");
    _ = @import("adder.zig");
    _ = @import("two_complement.zig");
    _ = @import("alu.zig");
}

test "single-bit gates follow truth tables" {
    // Expected outputs indexed by [a * 2 + b] for 2-input gates
    const NOT_EXPECTED = [2]u1{ 1, 0 };
    const AND_EXPECTED = [4]u1{ 0, 0, 0, 1 };
    const OR_EXPECTED = [4]u1{ 0, 1, 1, 1 };
    const XOR_EXPECTED = [4]u1{ 0, 1, 1, 0 };
    const NAND_EXPECTED = [4]u1{ 1, 1, 1, 0 };
    const NOR_EXPECTED = [4]u1{ 1, 0, 0, 0 };
    const XNOR_EXPECTED = [4]u1{ 1, 0, 0, 1 };

    std.debug.print("\nLOGIC GATES TEST------------------\n", .{});
    std.debug.print("a  b  | NOT  AND  OR  XOR  NAND  NOR  XNOR\n", .{});

    for (0..2) |i| {
        const a: u1 = @intCast(i);
        try testing.expectEqual(NOT_EXPECTED[i], Logic.NOT(a));

        for (0..2) |j| {
            const b: u1 = @intCast(j);
            const idx = i * 2 + j;

            const and_out = Logic.AND(a, b);
            const or_out = Logic.OR(a, b);
            const xor_out = Logic.XOR(a, b);
            const nand_out = Logic.NAND(a, b);
            const nor_out = Logic.NOR(a, b);
            const xnor_out = Logic.XNOR(a, b);

            try testing.expectEqual(AND_EXPECTED[idx], and_out);
            try testing.expectEqual(OR_EXPECTED[idx], or_out);
            try testing.expectEqual(XOR_EXPECTED[idx], xor_out);
            try testing.expectEqual(NAND_EXPECTED[idx], nand_out);
            try testing.expectEqual(NOR_EXPECTED[idx], nor_out);
            try testing.expectEqual(XNOR_EXPECTED[idx], xnor_out);

            std.debug.print("{d}  {d}  |  {d}    {d}   {d}    {d}    {d}     {d}    {d}\n", .{
                a, b, Logic.NOT(a), and_out, or_out, xor_out, nand_out, nor_out, xnor_out,
            });
        }
    }
}

test "16-bit gates (bit-array version)" {
    try testing.expectEqual(b16(0x0000), Logic.NOT16(b16(0xFFFF)));
    try testing.expectEqual(b16(0xFFFF), Logic.NOT16(b16(0x0000)));
    try testing.expectEqual(b16(0xFFFF), Logic.OR16(b16(0xFFFF), b16(0x0000)));
    try testing.expectEqual(b16(0x0000), Logic.AND16(b16(0xFFFF), b16(0x0000)));
    try testing.expectEqual(b16(0x00FF), Logic.AND16(b16(0xFFFF), b16(0x00FF)));
}

test "16-bit gates (integer version)" {
    try testing.expectEqual(@as(u16, 0x0000), Logic.NOT16_I(0xFFFF));
    try testing.expectEqual(@as(u16, 0xFFFF), Logic.NOT16_I(0x0000));
    try testing.expectEqual(@as(u16, 0xFFFF), Logic.OR16_I(0xFFFF, 0x0000));
    try testing.expectEqual(@as(u16, 0x0000), Logic.AND16_I(0xFFFF, 0x0000));
    try testing.expectEqual(@as(u16, 0x00FF), Logic.AND16_I(0xFFFF, 0x00FF));
}

test "OR8WAY returns 1 if any bit is set" {
    try testing.expectEqual(@as(u1, 1), Logic.OR8WAY(b8(0b10101010)));
    try testing.expectEqual(@as(u1, 1), Logic.OR8WAY(b8(0b00000001)));
    try testing.expectEqual(@as(u1, 0), Logic.OR8WAY(b8(0b00000000)));

    try testing.expectEqual(@as(u1, 1), Logic.OR8WAY_I(0b10101010));
    try testing.expectEqual(@as(u1, 1), Logic.OR8WAY_I(0b00000001));
    try testing.expectEqual(@as(u1, 0), Logic.OR8WAY_I(0b00000000));
}
