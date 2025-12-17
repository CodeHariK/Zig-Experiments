const std = @import("std");
const t = std.testing;

const mux = @import("mux.zig");
const adder = @import("adder.zig");

pub const Logic = struct {
    pub inline fn NAND(a: u1, b: u1) u1 {
        return ~(a & b);
    }

    pub inline fn NOT(a: u1) u1 {
        return ~a;
        // return Logic.NAND(a, a);
    }

    pub inline fn AND(a: u1, b: u1) u1 {
        return a & b;
        // return Logic.NOT(Logic.NAND(a, b));
    }

    pub inline fn OR(a: u1, b: u1) u1 {
        return a | b;
        // return Logic.NAND(Logic.NOT(a), Logic.NOT(b));
    }

    pub inline fn XOR(a: u1, b: u1) u1 {
        return a ^ b;

        // return Logic.OR(
        //     Logic.AND(a, Logic.NOT(b)),
        //     Logic.AND(Logic.NOT(a), b),
        // );

        // const d = Logic.NAND(a, b);
        // return Logic.NAND(Logic.NAND(a, d), Logic.NAND(b, d));
    }

    pub inline fn NOR(a: u1, b: u1) u1 {
        return ~(a | b);
        // return Logic.NOT(Logic.OR(a, b));
    }

    pub inline fn XNOR(a: u1, b: u1) u1 {
        return ~(a ^ b);
        // return Logic.NOT(Logic.XOR(a, b));
    }

    pub inline fn NOT16(in: u16) u16 {
        return ~in;
    }

    pub inline fn AND16(a: u16, b: u16) u16 {
        return a & b;
    }

    pub inline fn OR16(a: u16, b: u16) u16 {
        return a | b;
    }

    pub inline fn OR8WAY(in: u8) bool {
        return in != 0;
    }

    pub const MUX = mux.MUX;
    pub const MUX16 = mux.MUX16;
    pub const MUX4WAY16 = mux.MUX4WAY16;
    pub const MUX8WAY16 = mux.MUX8WAY16;
    pub const DMUX = mux.DMUX;
    pub const DMUX4WAY = mux.DMUX4WAY;
    pub const DMUX8WAY = mux.DMUX8WAY;

    pub const HALF_ADDER = adder.HALF_ADDER;
    pub const FULL_ADDER = adder.FULL_ADDER;

    pub inline fn CLOCK(tick: u32) bool {
        return (tick & 1) == 0;
    }
};

test "logic" {
    _ = @import("mux.zig");
    _ = @import("adder.zig");

    const NOT_OUT = [2]u1{ 1, 0 };
    const AND_OUT = [4]u1{ 0, 0, 0, 1 };
    const OR_OUT = [4]u1{ 0, 1, 1, 1 };
    const XOR_OUT = [4]u1{ 0, 1, 1, 0 };
    const NAND_OUT = [4]u1{ 1, 1, 1, 0 };
    const NOR_OUT = [4]u1{ 1, 0, 0, 0 };
    const XNOR_OUT = [4]u1{ 1, 0, 0, 1 };
    const MUX_OUT = [8]u1{ 0, 0, 0, 1, 1, 0, 1, 1 };
    const DMUX_OUT: [4][2]u1 = .{ .{ 0, 0 }, .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 } };

    try t.expect(Logic.NOT16(0xffff) == 0);
    try t.expect(Logic.OR16(0xffff, 0) == 0xffff);
    try t.expect(Logic.AND16(0xffff, 0) == 0);
    try t.expect(Logic.OR8WAY(0b10101010) == true);
    try t.expect(Logic.OR8WAY(0) == false);

    std.debug.print("\nTEST------------------\n", .{});
    std.debug.print("S  A   B  AND  OR  XOR  NAND  NOR  XNOR  MUX   DMUX\n", .{});

    var isel: u8 = 0;
    while (isel < 2) : (isel += 1) {
        const S: u1 = @intCast(isel);

        var ia: u8 = 0;
        while (ia < 2) : (ia += 1) {
            var ib: u8 = 0;
            while (ib < 2) : (ib += 1) {
                const A: u1 = @intCast(ia);
                const B: u1 = @intCast(ib);

                const A_NOT = Logic.NOT(A);
                const A_AND_B = Logic.AND(A, B);
                const A_OR_B = Logic.OR(A, B);
                const A_XOR_B = Logic.XOR(A, B);
                const A_NAND_B = Logic.NAND(A, B);
                const A_NOR_B = Logic.NOR(A, B);
                const A_XNOR_B = Logic.XNOR(A, B);

                try t.expect(A_NOT == NOT_OUT[ia]);
                try t.expect(A_AND_B == AND_OUT[ia * 2 + ib]);
                try t.expect(A_OR_B == OR_OUT[ia * 2 + ib]);
                try t.expect(A_XOR_B == XOR_OUT[ia * 2 + ib]);
                try t.expect(A_NAND_B == NAND_OUT[ia * 2 + ib]);
                try t.expect(A_NOR_B == NOR_OUT[ia * 2 + ib]);
                try t.expect(A_XNOR_B == XNOR_OUT[ia * 2 + ib]);

                const A_MUX_B = Logic.MUX(A, B, S);
                try t.expectEqual(A_MUX_B, MUX_OUT[ia * 4 + ib * 2 + isel]);

                const B_DMUX = Logic.DMUX(B, S);
                try t.expectEqual(B_DMUX, DMUX_OUT[ib * 2 + isel]);

                std.debug.print("{d}  {d}   {d}   {d}   {d}    {d}    {d}     {d}    {d}     {d}    {d},{d}\n", .{
                    S,
                    A,
                    B,
                    A_AND_B,
                    A_OR_B,
                    A_XOR_B,
                    A_NAND_B,
                    A_NOR_B,
                    A_XNOR_B,
                    A_MUX_B,
                    B_DMUX[0],
                    B_DMUX[1],
                });
            }
        }
    }
}
