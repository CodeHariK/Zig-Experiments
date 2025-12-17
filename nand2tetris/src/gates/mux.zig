const std = @import("std");
const t = std.testing;

const utils = @import("utils.zig");
const bb2 = utils.bb2;
const bb3 = utils.bb3;
const bb4 = utils.bb4;
const bb8 = utils.bb8;

pub inline fn MUX(in0: u1, in1: u1, sel: u1) u1 {
    return if (sel == 1) in1 else in0;
    // return OR(
    //     AND(a, NOT(sel)),
    //     AND(b, sel),
    // );
}

pub inline fn MUX16(in0: u16, in1: u16, sel: u1) u16 {
    return if (sel == 1) in1 else in0;
}

pub inline fn MUX4WAY16(in0: u16, in1: u16, in2: u16, in3: u16, sel: [2]u1) u16 {
    const left = MUX16(in0, in1, sel[1]);
    const right = MUX16(in2, in3, sel[1]);
    return MUX16(left, right, sel[0]);
}

pub inline fn MUX8WAY16(in0: u16, in1: u16, in2: u16, in3: u16, in4: u16, in5: u16, in6: u16, in7: u16, sel: [3]u1) u16 {
    const left = MUX4WAY16(in0, in1, in2, in3, [2]u1{ sel[1], sel[2] });
    const right = MUX4WAY16(in4, in5, in6, in7, [2]u1{ sel[1], sel[2] });
    return MUX16(left, right, sel[0]);
}

pub inline fn DMUX(in: u1, sel: u1) [2]u1 {
    return [2]u1{ in & ~sel, in & sel };
    // return [2]u1{
    //     AND(in, NOT(sel)),
    //     AND(in, sel),
    // };
}

pub inline fn DMUX4WAY(input: u1, sel: [2]u1) [4]u1 {
    const top = DMUX(input, sel[0]); // split by sel[0] (high bit)
    const lower = DMUX(top[0], sel[1]);
    const upper = DMUX(top[1], sel[1]);
    return [4]u1{ lower[0], lower[1], upper[0], upper[1] };
}

pub inline fn DMUX8WAY(input: u1, sel: [3]u1) [8]u1 {
    const top = DMUX(input, sel[0]); // split by high bit
    const lower = DMUX4WAY(top[0], [2]u1{ sel[1], sel[2] });
    const upper = DMUX4WAY(top[1], [2]u1{ sel[1], sel[2] });
    return [8]u1{
        lower[0], lower[1], lower[2], lower[3],
        upper[0], upper[1], upper[2], upper[3],
    };

    // return [8]u1{
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

test "mux" {
    try t.expect(MUX16(0, 1, 0) == 0);
    try t.expect(MUX16(0, 1, 1) == 1);

    std.debug.print("\nMUX4WAY16------------------\n", .{});
    for (0..4) |i| {
        try t.expect(MUX4WAY16(0, 0, 0, 0, bb2(i)) == 0);
        const ans = @as(u16, 1) << (3 - @as(u2, @intCast(i)));
        const mux4way16 = MUX4WAY16(8, 4, 2, 1, bb2(i));
        try t.expect(mux4way16 == ans);
        std.debug.print("8, 4, 2, 1  {b:0>2}:{d} -> {d}\n", .{ i, i, mux4way16 });
    }

    std.debug.print("\nDMUX4WAY------------------\n", .{});
    for (0..4) |i| {
        try t.expectEqual(DMUX4WAY(0, bb2(i)), bb4(0));
        const ans = @as(u16, 1) << (3 - @as(u2, @intCast(i)));
        const dmux4way = DMUX4WAY(1, bb2(i));
        try t.expectEqual(dmux4way, bb4(ans));
        std.debug.print("{b:0>2}:{d} -> {any}\n", .{ i, i, dmux4way });
    }

    std.debug.print("\nMUX8WAY16------------------\n", .{});
    for (0..8) |i| {
        try t.expect(MUX8WAY16(0, 0, 0, 0, 0, 0, 0, 0, bb3(i)) == 0);
        const ans = @as(u16, 1) << (7 - @as(u3, @intCast(i)));
        const mux8way16 = MUX8WAY16(128, 64, 32, 16, 8, 4, 2, 1, bb3(i));
        try t.expect(mux8way16 == ans);
        std.debug.print("128, 64, 32, 8, 4, 2, 1   {b:0>3}:{d} -> {d}\n", .{ i, i, mux8way16 });
    }

    std.debug.print("\nDMUX8WAY------------------\n", .{});
    for (0..8) |i| {
        try t.expectEqual(DMUX8WAY(0, bb3(i)), bb8(0));
        const ans = @as(u16, 1) << (7 - @as(u3, @intCast(i)));
        const dmux8way = DMUX8WAY(1, bb3(i));
        try t.expectEqual(dmux8way, bb8(ans));
        std.debug.print("{b:0>3}:{d} ->  {any}\n", .{ i, i, dmux8way });
    }
}
