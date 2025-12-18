const std = @import("std");
const t = std.testing;

const logic = @import("logic.zig");

const u = @import("utils.zig");
const b2 = u.b2;
const b3 = u.b3;
const b4 = u.b4;
const b8 = u.b8;
const b16 = u.b16;
const fb2 = u.fb2;

// ============================================================================
// Bit-array versions (all inputs/outputs are [N]u1)
// ============================================================================

pub inline fn MUX(in1: u1, in0: u1, sel: u1) u1 {
    return if (sel == 0) in0 else in1;
    // return logic.Logic.OR(
    //     logic.Logic.AND(in0, logic.Logic.NOT(sel)),
    //     logic.Logic.AND(in1, sel),
    // );
}

/// 16-bit mux with bit-array inputs/output
pub inline fn MUX16(in1: [16]u1, in0: [16]u1, sel: u1) [16]u1 {
    return if (sel == 0) in0 else in1;
}

pub inline fn MUX4WAY16(in3: [16]u1, in2: [16]u1, in1: [16]u1, in0: [16]u1, sel: [2]u1) [16]u1 {
    const left = MUX16(in3, in2, sel[1]);
    const right = MUX16(in1, in0, sel[1]);
    return MUX16(left, right, sel[0]);
}

pub inline fn MUX8WAY16(in7: [16]u1, in6: [16]u1, in5: [16]u1, in4: [16]u1, in3: [16]u1, in2: [16]u1, in1: [16]u1, in0: [16]u1, sel: [3]u1) [16]u1 {
    const left = MUX4WAY16(in7, in6, in5, in4, [2]u1{ sel[1], sel[2] });
    const right = MUX4WAY16(in3, in2, in1, in0, [2]u1{ sel[1], sel[2] });
    return MUX16(left, right, sel[0]);
}

pub inline fn DMUX(in: u1, sel: u1) [2]u1 {
    return [2]u1{ in & sel, in & ~sel };
    // return [2]u1{
    //     logic.Logic.AND(in, sel),
    //     logic.Logic.AND(in, logic.Logic.NOT(sel)),
    // };
}

pub inline fn DMUX4WAY(in: u1, sel: [2]u1) [4]u1 {
    const top = DMUX(in, sel[0]);
    const lower = DMUX(top[0], sel[1]);
    const upper = DMUX(top[1], sel[1]);
    return [4]u1{ lower[0], lower[1], upper[0], upper[1] };
}

pub inline fn DMUX8WAY(input: u1, sel: [3]u1) [8]u1 {
    const top = DMUX(input, sel[0]);
    const lower = DMUX4WAY(top[0], [2]u1{ sel[1], sel[2] });
    const upper = DMUX4WAY(top[1], [2]u1{ sel[1], sel[2] });
    return [8]u1{
        lower[0], lower[1], lower[2], lower[3],
        upper[0], upper[1], upper[2], upper[3],
    };

    // return [8]u1{
    //     input & sel[0] & sel[1] & sel[2], // 111
    //     input & sel[0] & sel[1] & ~sel[2], // 110
    //     input & sel[0] & ~sel[1] & sel[2], // 101
    //     input & sel[0] & ~sel[1] & ~sel[2], // 100
    //     input & ~sel[0] & sel[1] & sel[2], // 011
    //     input & ~sel[0] & sel[1] & ~sel[2], // 010
    //     input & ~sel[0] & ~sel[1] & sel[2], // 001
    //     input & ~sel[0] & ~sel[1] & ~sel[2], // 000
    // };
}

// ============================================================================
// Integer versions (sel is u2, u3, etc.) - suffix _I
// ============================================================================

pub inline fn MUX_I(in1: u1, in0: u1, sel: u1) u1 {
    return if (sel == 0) in0 else in1;
}

pub inline fn MUX16_I(in1: u16, in0: u16, sel: u1) u16 {
    return if (sel == 0) in0 else in1;
}

pub inline fn MUX4WAY16_I(in3: u16, in2: u16, in1: u16, in0: u16, sel: u2) u16 {
    const sel_lo: u1 = @truncate(sel);
    const sel_hi: u1 = @truncate(sel >> 1);
    const left = MUX16_I(in3, in2, sel_lo);
    const right = MUX16_I(in1, in0, sel_lo);
    return MUX16_I(left, right, sel_hi);
}

pub inline fn MUX8WAY16_I(in7: u16, in6: u16, in5: u16, in4: u16, in3: u16, in2: u16, in1: u16, in0: u16, sel: u3) u16 {
    const sel_lo: u2 = @truncate(sel);
    const sel_hi: u1 = @truncate(sel >> 2);
    const left = MUX4WAY16_I(in7, in6, in5, in4, sel_lo);
    const right = MUX4WAY16_I(in3, in2, in1, in0, sel_lo);
    return MUX16_I(left, right, sel_hi);
}

pub inline fn DMUX_I(in: u1, sel: u1) u2 {
    return @as(u2, in) << sel;
}

pub inline fn DMUX4WAY_I(in: u1, sel: u2) u4 {
    return @as(u4, in) << sel;
}

pub inline fn DMUX8WAY_I(in: u1, sel: u3) u8 {
    return @as(u8, in) << sel;
}

test "MUX/DMUX TEST" {
    const MUX_OUT = [8]u1{ 0, 1, 0, 1, 0, 0, 1, 1 };
    const DMUX_OUT: [4][2]u1 = .{ .{ 0, 0 }, .{ 0, 1 }, .{ 0, 0 }, .{ 1, 0 } };

    std.debug.print("\nMUXTEST------------------\n", .{});
    std.debug.print("S  In1  In0  MUX   DMUX\n", .{});

    var isel: u8 = 0;
    while (isel < 2) : (isel += 1) {
        const S: u1 = @intCast(isel);

        var idx1: u8 = 0;
        while (idx1 < 2) : (idx1 += 1) {
            var idx0: u8 = 0;
            while (idx0 < 2) : (idx0 += 1) {
                const IN1: u1 = @intCast(idx1);
                const IN0: u1 = @intCast(idx0);

                const A_MUX_B = MUX(IN1, IN0, S);
                const A_MUX_B_I = MUX_I(IN1, IN0, S);
                try t.expectEqual(A_MUX_B, MUX_OUT[isel * 4 + idx1 * 2 + idx0]);
                try t.expectEqual(A_MUX_B_I, MUX_OUT[isel * 4 + idx1 * 2 + idx0]);

                const A_DMUX = DMUX(IN1, S);
                const A_DMUX_I = DMUX_I(IN1, S);
                try t.expectEqual(A_DMUX, DMUX_OUT[isel * 2 + idx1]);
                try t.expectEqual(A_DMUX_I, fb2(DMUX_OUT[isel * 2 + idx1]));
                std.debug.print("{d}   {d}    {d}     {d}    {d},{d}\n", .{
                    S,
                    IN1,
                    IN0,
                    A_MUX_B,
                    A_DMUX[0],
                    A_DMUX[1],
                });
            }
        }
    }

    try t.expectEqual(MUX16(b16(0), b16(1), 0), b16(1));
    try t.expectEqual(MUX16(b16(0), b16(1), 1), b16(0));
    try t.expect(MUX16_I(0, 1, 0) == 1);
    try t.expect(MUX16_I(0, 1, 1) == 0);

    std.debug.print("\nMUX4WAY16------------------\n", .{});
    for (0..4) |i| {
        try t.expectEqual(MUX4WAY16(b16(0), b16(0), b16(0), b16(0), b2(i)), b16(0));
        const ans: u16 = @as(u16, 1) << @intCast(i);
        const mux4way16 = MUX4WAY16(b16(8), b16(4), b16(2), b16(1), b2(i));
        try t.expectEqual(mux4way16, b16(ans));
        std.debug.print("8, 4, 2, 1  {b:0>2}:{d} -> {d}\n", .{ i, i, ans });
    }

    std.debug.print("\nMUX4WAY16_I------------------\n", .{});
    for (0..4) |i| {
        const sel: u2 = @intCast(i);
        try t.expect(MUX4WAY16_I(0, 0, 0, 0, sel) == 0);
        const ans = @as(u16, 1) << sel;
        const mux4way16 = MUX4WAY16_I(8, 4, 2, 1, sel);
        try t.expect(mux4way16 == ans);
        std.debug.print("8, 4, 2, 1  sel={d} -> {d}\n", .{ sel, mux4way16 });
    }

    std.debug.print("\nMUX8WAY16------------------\n", .{});
    for (0..8) |i| {
        try t.expectEqual(MUX8WAY16(b16(0), b16(0), b16(0), b16(0), b16(0), b16(0), b16(0), b16(0), b3(i)), b16(0));
        const ans: u16 = @as(u16, 1) << @intCast(i);
        const mux8way16 = MUX8WAY16(b16(128), b16(64), b16(32), b16(16), b16(8), b16(4), b16(2), b16(1), b3(i));
        try t.expectEqual(mux8way16, b16(ans));
        std.debug.print("128, 64, 32, 16, 8, 4, 2, 1   {b:0>3}:{d} -> {d}\n", .{ i, i, ans });
    }

    std.debug.print("\nMUX8WAY16_I------------------\n", .{});
    for (0..8) |i| {
        const sel: u3 = @intCast(i);
        try t.expect(MUX8WAY16_I(0, 0, 0, 0, 0, 0, 0, 0, sel) == 0);
        const ans = @as(u16, 1) << sel;
        const mux8way16 = MUX8WAY16_I(128, 64, 32, 16, 8, 4, 2, 1, sel);
        try t.expect(mux8way16 == ans);
        std.debug.print("128, 64, 32, 16, 8, 4, 2, 1   sel={d} -> {d}\n", .{ sel, mux8way16 });
    }

    std.debug.print("\nDMUX4WAY------------------\n", .{});
    for (0..4) |i| {
        try t.expectEqual(DMUX4WAY(0, b2(i)), b4(0));
        const ans = @as(u16, 1) << @intCast(i);
        const dmux4way = DMUX4WAY(1, b2(i));
        try t.expectEqual(dmux4way, b4(ans));
        std.debug.print("{b:0>2}:{d} -> {any}\n", .{ i, i, dmux4way });
    }

    std.debug.print("\nDMUX4WAY_I------------------\n", .{});
    for (0..4) |i| {
        const sel: u2 = @intCast(i);
        try t.expectEqual(DMUX4WAY_I(0, sel), 0);
        const ans: u4 = @as(u4, 1) << sel;
        const dmux4way = DMUX4WAY_I(1, sel);
        try t.expectEqual(dmux4way, ans);
        std.debug.print("sel={d} -> {b:0>4}\n", .{ sel, dmux4way });
    }

    std.debug.print("\nDMUX8WAY------------------\n", .{});
    for (0..8) |i| {
        try t.expectEqual(DMUX8WAY(0, b3(i)), b8(0));
        const ans = @as(u16, 1) << @intCast(i);
        const dmux8way = DMUX8WAY(1, b3(i));
        try t.expectEqual(dmux8way, b8(ans));
        std.debug.print("{b:0>3}:{d} ->  {any}\n", .{ i, i, dmux8way });
    }

    std.debug.print("\nDMUX8WAY_I------------------\n", .{});
    for (0..8) |i| {
        const sel: u3 = @intCast(i);
        try t.expectEqual(DMUX8WAY_I(0, sel), 0);
        const ans: u8 = @as(u8, 1) << sel;
        const dmux8way = DMUX8WAY_I(1, sel);
        try t.expectEqual(dmux8way, ans);
        std.debug.print("sel={d} -> {b:0>8}\n", .{ sel, dmux8way });
    }
}
