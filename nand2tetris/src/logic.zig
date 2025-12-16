const std = @import("std");
const t = std.testing;

pub const Logic = struct {
    pub inline fn NAND(a: bool, b: bool) bool {
        return !(a & b);
    }

    pub inline fn NOT(a: bool) bool {
        return !a;
        // return Logic.NAND(a, a);
    }

    pub inline fn AND(a: bool, b: bool) bool {
        return a & b;
        // return Logic.NOT(Logic.NAND(a, b));
    }

    pub inline fn OR(a: bool, b: bool) bool {
        return a | b;
        // return Logic.NAND(Logic.NOT(a), Logic.NOT(b));
    }

    pub inline fn XOR(a: bool, b: bool) bool {
        return a ^ b;

        // return Logic.OR(
        //     Logic.AND(a, Logic.NOT(b)),
        //     Logic.AND(Logic.NOT(a), b),
        // );

        // const d = Logic.NAND(a, b);
        // return Logic.NAND(Logic.NAND(a, d), Logic.NAND(b, d));
    }

    pub inline fn NOR(a: bool, b: bool) bool {
        return !(a | b);
        // return Logic.NOT(Logic.OR(a, b));
    }

    pub inline fn XNOR(a: bool, b: bool) bool {
        return !(a ^ b);
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

    pub inline fn MUX(in0: bool, in1: bool, sel: bool) bool {
        return if (sel) in1 else in0;
        // return Logic.OR(
        //     Logic.AND(a, Logic.NOT(sel)),
        //     Logic.AND(b, sel),
        // );
    }

    pub fn MUX16(in0: u16, in1: u16, sel: bool) u16 {
        return if (sel) in1 else in0;
    }

    pub inline fn MUX4WAY16(in0: u16, in1: u16, in2: u16, in3: u16, sel: [2]bool) u16 {
        const left = MUX16(in0, in1, sel[1]);
        const right = MUX16(in2, in3, sel[1]);
        return MUX16(left, right, sel[0]);
    }

    pub fn MUX8WAY16(in0: u16, in1: u16, in2: u16, in3: u16, in4: u16, in5: u16, in6: u16, in7: u16, sel: [3]bool) u16 {
        const left = MUX4WAY16(in0, in1, in2, in3, [2]bool{ sel[1], sel[2] });
        const right = MUX4WAY16(in4, in5, in6, in7, [2]bool{ sel[1], sel[2] });
        return MUX16(left, right, sel[0]);
    }

    pub inline fn DMUX(in: bool, sel: bool) [2]bool {
        return [2]bool{ in and !sel, in and sel };
        // return [2]bool{
        //     Logic.AND(in, Logic.NOT(sel)),
        //     Logic.AND(in, sel),
        // };
    }

    pub fn DMUX4WAY(input: bool, sel: [2]bool) [4]bool {
        const top = DMUX(input, sel[0]); // split by sel[0] (high bit)
        const lower = DMUX(top[0], sel[1]);
        const upper = DMUX(top[1], sel[1]);
        return [4]bool{ lower[0], lower[1], upper[0], upper[1] };
    }

    pub fn DMUX8WAY(input: bool, sel: [3]bool) [8]bool {
        const top = DMUX(input, sel[0]); // split by high bit
        const lower = DMUX4WAY(top[0], [2]bool{ sel[1], sel[2] });
        const upper = DMUX4WAY(top[1], [2]bool{ sel[1], sel[2] });
        return [8]bool{
            lower[0], lower[1], lower[2], lower[3],
            upper[0], upper[1], upper[2], upper[3],
        };

        // return [8]bool{
        //     input and !sel[0] and !sel[1] and !sel[2], // 000
        //     input and !sel[0] and !sel[1] and sel[2], // 001
        //     input and !sel[0] and sel[1] and !sel[2], // 010
        //     input and !sel[0] and sel[1] and sel[2], // 011
        //     input and sel[0] and !sel[1] and !sel[2], // 100
        //     input and sel[0] and !sel[1] and sel[2], // 101
        //     input and sel[0] and sel[1] and !sel[2], // 110
        //     input and sel[0] and sel[1] and sel[2], // 111
        // };
    }

    pub inline fn CLOCK(tick: u32) bool {
        return (tick & 1) == 0;
    }
};

test "logic" {
    const NOT_OUT = [2]bool{ true, false };
    const AND_OUT = [4]bool{ false, false, false, true };
    const OR_OUT = [4]bool{ false, true, true, true };
    const XOR_OUT = [4]bool{ false, true, true, false };
    const NAND_OUT = [4]bool{ true, true, true, false };
    const NOR_OUT = [4]bool{ true, false, false, false };
    const XNOR_OUT = [4]bool{ true, false, false, true };
    const MUX_OUT = [8]bool{ false, false, false, true, true, false, true, true };
    const DMUX_OUT: [4][2]bool = .{ .{ false, false }, .{ false, false }, .{ true, false }, .{ false, true } };

    try t.expect(Logic.NOT16(0xffff) == 0);
    try t.expect(Logic.OR16(0xffff, 0) == 0xffff);
    try t.expect(Logic.AND16(0xffff, 0) == 0);
    try t.expect(Logic.OR8WAY(0b10101010) == true);
    try t.expect(Logic.OR8WAY(0) == false);

    try t.expect(Logic.MUX16(0, 1, false) == 0);
    try t.expect(Logic.MUX16(0, 1, true) == 1);

    std.debug.print("\nMUX4WAY16------------------\n", .{});
    for (0..4) |i| {
        try t.expect(Logic.MUX4WAY16(0, 0, 0, 0, bb2(i)) == 0);
        const ans = @as(u16, 1) << (3 - @as(u2, @intCast(i)));
        const mux4way16 = Logic.MUX4WAY16(8, 4, 2, 1, bb2(i));
        try t.expect(mux4way16 == ans);
        std.debug.print("8, 4, 2, 1  {b:0>2}:{d} -> {d}\n", .{ i, i, mux4way16 });
    }

    std.debug.print("\nDMUX4WAY------------------\n", .{});
    for (0..4) |i| {
        try t.expectEqual(Logic.DMUX4WAY(false, bb2(i)), bb4(0));
        const ans = @as(u16, 1) << (3 - @as(u2, @intCast(i)));
        const dmux4way = Logic.DMUX4WAY(true, bb2(i));
        try t.expectEqual(dmux4way, bb4(ans));
        std.debug.print("{b:0>2}:{d} -> {b:0>4}  {any}\n", .{ i, i, ub4(dmux4way), ub4(dmux4way) });
    }

    std.debug.print("\nMUX8WAY16------------------\n", .{});
    for (0..8) |i| {
        try t.expect(Logic.MUX8WAY16(0, 0, 0, 0, 0, 0, 0, 0, bb3(i)) == 0);
        const ans = @as(u16, 1) << (7 - @as(u3, @intCast(i)));
        const mux8way16 = Logic.MUX8WAY16(128, 64, 32, 16, 8, 4, 2, 1, bb3(i));
        try t.expect(mux8way16 == ans);
        std.debug.print("128, 64, 32, 8, 4, 2, 1   {b:0>3}:{d} -> {d}\n", .{ i, i, mux8way16 });
    }

    std.debug.print("\nDMUX8WAY------------------\n", .{});
    for (0..8) |i| {
        try t.expectEqual(Logic.DMUX8WAY(false, bb3(i)), bb8(0));
        const ans = @as(u16, 1) << (7 - @as(u3, @intCast(i)));
        const dmux8way = Logic.DMUX8WAY(true, bb3(i));
        try t.expectEqual(dmux8way, bb8(ans));
        std.debug.print("{b:0>3}:{d} ->  {b:0>8}  {any}\n", .{ i, i, ub8(dmux8way), ub8(dmux8way) });
    }

    std.debug.print("\nTEST------------------\n", .{});
    std.debug.print("a  b  sel  AND  OR  XOR  NAND  NOR  XNOR  MUX   DMUX\n", .{});

    var ia: u8 = 0;
    while (ia < 2) : (ia += 1) {
        var ib: u8 = 0;
        while (ib < 2) : (ib += 1) {
            const a = ia == 1;
            const b = ib == 1;

            const A_NOT = Logic.NOT(a);
            const A_AND_B = Logic.AND(a, b);
            const A_OR_B = Logic.OR(a, b);
            const A_XOR_B = Logic.XOR(a, b);
            const A_NAND_B = Logic.NAND(a, b);
            const A_NOR_B = Logic.NOR(a, b);
            const A_XNOR_B = Logic.XNOR(a, b);

            try t.expect(A_NOT == NOT_OUT[ia]);
            try t.expect(A_AND_B == AND_OUT[ia * 2 + ib]);
            try t.expect(A_OR_B == OR_OUT[ia * 2 + ib]);
            try t.expect(A_XOR_B == XOR_OUT[ia * 2 + ib]);
            try t.expect(A_NAND_B == NAND_OUT[ia * 2 + ib]);
            try t.expect(A_NOR_B == NOR_OUT[ia * 2 + ib]);
            try t.expect(A_XNOR_B == XNOR_OUT[ia * 2 + ib]);

            var isel: u8 = 0;
            while (isel < 2) : (isel += 1) {
                const sel = isel == 1;

                const A_MUX_B = Logic.MUX(a, b, sel);
                try t.expectEqual(A_MUX_B, MUX_OUT[ia * 4 + ib * 2 + isel]);

                const B_DMUX = Logic.DMUX(b, sel);
                try t.expectEqual(B_DMUX, DMUX_OUT[ib * 2 + isel]);

                std.debug.print("{s}  {s}   {s}    {s}   {s}    {s}    {s}     {s}    {s}     {s}    {s},{s}\n", .{
                    if (a) "1" else "0",
                    if (b) "1" else "0",
                    if (sel) "1" else "0",
                    if (A_AND_B) "1" else "0",
                    if (A_OR_B) "1" else "0",
                    if (A_XOR_B) "1" else "0",
                    if (A_NAND_B) "1" else "0",
                    if (A_NOR_B) "1" else "0",
                    if (A_XNOR_B) "1" else "0",
                    if (A_MUX_B) "1" else "0",
                    if (B_DMUX[0]) "1" else "0",
                    if (B_DMUX[1]) "1" else "0",
                });
            }
        }
    }
}

fn bb2(value: usize) [2]bool {
    return [2]bool{
        value & 0b10 != 0,
        value & 0b01 != 0,
    };
}

fn bb3(value: usize) [3]bool {
    return [3]bool{
        value & 0b100 != 0,
        value & 0b010 != 0,
        value & 0b001 != 0,
    };
}

fn bb4(value: u16) [4]bool {
    return [4]bool{
        value & 0b1000 != 0,
        value & 0b0100 != 0,
        value & 0b0010 != 0,
        value & 0b0001 != 0,
    };
}

fn bb8(value: u16) [8]bool {
    return [8]bool{
        value & 0b10000000 != 0,
        value & 0b01000000 != 0,
        value & 0b00100000 != 0,
        value & 0b00010000 != 0,
        value & 0b00001000 != 0,
        value & 0b00000100 != 0,
        value & 0b00000010 != 0,
        value & 0b00000001 != 0,
    };
}

fn ub4(value: [4]bool) u4 {
    return @as(u4, @intFromBool(value[0])) << 3 | @as(u4, @intFromBool(value[1])) << 2 | @as(u4, @intFromBool(value[2])) << 1 | @as(u4, @intFromBool(value[3]));
}

fn ub8(value: [8]bool) u8 {
    return @as(u8, @intFromBool(value[0])) << 7 |
        @as(u8, @intFromBool(value[1])) << 6 |
        @as(u8, @intFromBool(value[2])) << 5 |
        @as(u8, @intFromBool(value[3])) << 4 |
        @as(u8, @intFromBool(value[4])) << 3 |
        @as(u8, @intFromBool(value[5])) << 2 |
        @as(u8, @intFromBool(value[6])) << 1 |
        @as(u8, @intFromBool(value[7])) << 0;
}
