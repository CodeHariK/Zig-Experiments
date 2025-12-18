const std = @import("std");
const t = std.testing;

const mux = @import("mux.zig");
const adder = @import("adder.zig");

const u = @import("utils.zig");
const b8 = u.b8;
const b16 = u.b16;

pub const Logic = struct {
    pub inline fn NAND(in1: u1, in0: u1) u1 {
        return ~(in1 & in0);
    }

    pub inline fn NOT(in: u1) u1 {
        return ~in;
        // return Logic.NAND(in, in);
    }

    pub inline fn AND(in1: u1, in0: u1) u1 {
        return in1 & in0;
        // return Logic.NOT(Logic.NAND(in1, in0));
    }

    pub inline fn OR(in1: u1, in0: u1) u1 {
        return in1 | in0;
        // return Logic.NAND(Logic.NOT(in1), Logic.NOT(in0));
    }

    pub inline fn XOR(in1: u1, in0: u1) u1 {
        return in1 ^ in0;

        // return Logic.OR(
        //     Logic.AND(in1, Logic.NOT(in0)),
        //     Logic.AND(Logic.NOT(in1), in0),
        // );

        // const d = Logic.NAND(in1, in0);
        // return Logic.NAND(Logic.NAND(in1, d), Logic.NAND(in0, d));
    }

    pub inline fn NOR(in1: u1, in0: u1) u1 {
        return ~(in1 | in0);
        // return Logic.NOT(Logic.OR(in1, in0));
    }

    pub inline fn XNOR(in1: u1, in0: u1) u1 {
        return ~(in1 ^ in0);
        // return Logic.NOT(Logic.XOR(in1, in0));
    }

    pub inline fn CLOCK(tick: u32) bool {
        return (tick & 1) == 0;
    }

    // ========== Bit-array versions ==========

    pub inline fn NOT16(in: [16]u1) [16]u1 {
        var out: [16]u1 = undefined;
        inline for (0..16) |i| out[i] = ~in[i];
        return out;
    }

    pub inline fn AND16(in1: [16]u1, in0: [16]u1) [16]u1 {
        var out: [16]u1 = undefined;
        inline for (0..16) |i| out[i] = in1[i] & in0[i];
        return out;
    }

    pub inline fn OR16(in1: [16]u1, in0: [16]u1) [16]u1 {
        var out: [16]u1 = undefined;
        inline for (0..16) |i| out[i] = in1[i] | in0[i];
        return out;
    }

    pub inline fn OR8WAY(in: [8]u1) u1 {
        var out: u1 = 0;
        inline for (0..8) |i| {
            out |= in[i];
        }
        return out;
    }

    // Bit-array versions (sel/inputs are [N]u1)
    pub const MUX = mux.MUX;
    pub const MUX16 = mux.MUX16;
    pub const MUX4WAY16 = mux.MUX4WAY16;
    pub const MUX8WAY16 = mux.MUX8WAY16;
    pub const DMUX = mux.DMUX;
    pub const DMUX4WAY = mux.DMUX4WAY;
    pub const DMUX8WAY = mux.DMUX8WAY;

    // Adder (single-bit)
    pub const HALF_ADDER = adder.HALF_ADDER;
    pub const FULL_ADDER = adder.FULL_ADDER;

    // Bit-array versions
    pub const RIPPLE_ADDER = adder.RIPPLE_ADDER;
    pub const RIPPLE_ADDER_16 = adder.RIPPLE_ADDER_16;

    // ========== Integer versions (_I) ==========

    pub inline fn NOT16_I(in: u16) u16 {
        return ~in;
    }

    pub inline fn AND16_I(in1: u16, in0: u16) u16 {
        return in1 & in0;
    }

    pub inline fn OR16_I(in1: u16, in0: u16) u16 {
        return in1 | in0;
    }

    pub inline fn OR8WAY_I(in: u8) u1 {
        return if (in != 0) 1 else 0;
    }

    // Integer versions (sel is u2, u3, etc.)
    pub const MUX_I = mux.MUX_I;
    pub const MUX16_I = mux.MUX16_I;
    pub const MUX4WAY16_I = mux.MUX4WAY16_I;
    pub const MUX8WAY16_I = mux.MUX8WAY16_I;
    pub const DMUX_I = mux.DMUX_I;
    pub const DMUX4WAY_I = mux.DMUX4WAY_I;
    pub const DMUX8WAY_I = mux.DMUX8WAY_I;

    // Integer versions
    pub const RIPPLE_ADDER_I = adder.RIPPLE_ADDER_I;
    pub const RIPPLE_ADDER_16_I = adder.RIPPLE_ADDER_16_I;
};

test "LOGIC TEST" {
    _ = @import("mux.zig");
    _ = @import("adder.zig");

    const NOT_OUT = [2]u1{ 1, 0 };
    const AND_OUT = [4]u1{ 0, 0, 0, 1 };
    const OR_OUT = [4]u1{ 0, 1, 1, 1 };
    const XOR_OUT = [4]u1{ 0, 1, 1, 0 };
    const NAND_OUT = [4]u1{ 1, 1, 1, 0 };
    const NOR_OUT = [4]u1{ 1, 0, 0, 0 };
    const XNOR_OUT = [4]u1{ 1, 0, 0, 1 };

    try t.expectEqual(Logic.NOT16(b16(0xffff)), b16(0));
    try t.expectEqual(Logic.OR16(b16(0xffff), b16(0)), b16(0xffff));
    try t.expectEqual(Logic.AND16(b16(0xffff), b16(0)), b16(0));
    try t.expectEqual(Logic.OR8WAY(b8(0b10101010)), 1);
    try t.expectEqual(Logic.OR8WAY(b8(0)), 0);

    // Test integer versions
    try t.expect(Logic.NOT16_I(0xffff) == 0);
    try t.expect(Logic.OR16_I(0xffff, 0) == 0xffff);
    try t.expect(Logic.AND16_I(0xffff, 0) == 0);
    try t.expect(Logic.OR8WAY_I(0b10101010) == 1);
    try t.expect(Logic.OR8WAY_I(0) == 0);

    std.debug.print("\nTEST------------------\n", .{});
    std.debug.print("S  In1  In0  AND  OR  XOR  NAND  NOR  XNOR\n", .{});

    var isel: u8 = 0;
    while (isel < 2) : (isel += 1) {
        const S: u1 = @intCast(isel);

        var idx1: u8 = 0;
        while (idx1 < 2) : (idx1 += 1) {
            var idx0: u8 = 0;
            while (idx0 < 2) : (idx0 += 1) {
                const IN1: u1 = @intCast(idx1);
                const IN0: u1 = @intCast(idx0);

                const A_NOT = Logic.NOT(IN1);
                const A_AND_B = Logic.AND(IN1, IN0);
                const A_OR_B = Logic.OR(IN1, IN0);
                const A_XOR_B = Logic.XOR(IN1, IN0);
                const A_NAND_B = Logic.NAND(IN1, IN0);
                const A_NOR_B = Logic.NOR(IN1, IN0);
                const A_XNOR_B = Logic.XNOR(IN1, IN0);

                try t.expect(A_NOT == NOT_OUT[idx1]);
                try t.expect(A_AND_B == AND_OUT[idx1 * 2 + idx0]);
                try t.expect(A_OR_B == OR_OUT[idx1 * 2 + idx0]);
                try t.expect(A_XOR_B == XOR_OUT[idx1 * 2 + idx0]);
                try t.expect(A_NAND_B == NAND_OUT[idx1 * 2 + idx0]);
                try t.expect(A_NOR_B == NOR_OUT[idx1 * 2 + idx0]);
                try t.expect(A_XNOR_B == XNOR_OUT[idx1 * 2 + idx0]);

                std.debug.print("{d}   {d}    {d}    {d}   {d}    {d}    {d}     {d}    {d}\n", .{
                    S,
                    IN1,
                    IN0,
                    A_AND_B,
                    A_OR_B,
                    A_XOR_B,
                    A_NAND_B,
                    A_NOR_B,
                    A_XNOR_B,
                });
            }
        }
    }
}
