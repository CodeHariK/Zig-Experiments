//! Multiplexer (MUX) and Demultiplexer (DMUX) Gates
//!
//! MUX: Selects one of multiple inputs based on selector bits.
//! DMUX: Routes a single input to one of multiple outputs based on selector bits.
//!
//! These are fundamental building blocks for memory addressing and data routing.

const std = @import("std");
const testing = std.testing;

const utils = @import("utils.zig");
const b2 = utils.b2;
const b3 = utils.b3;
const b4 = utils.b4;
const b8 = utils.b8;
const b16 = utils.b16;
const fb2 = utils.fb2;

// ============================================================================
// Multiplexers (Bit-Array Version)
// ============================================================================

/// 2-way multiplexer: selects in0 when sel=0, in1 when sel=1.
/// NAND equivalent: OR(AND(in0, NOT(sel)), AND(in1, sel))
pub inline fn MUX(in1: u1, in0: u1, sel: u1) u1 {
    return if (sel == 0) in0 else in1;
}

/// 16-bit 2-way multiplexer.
pub inline fn MUX16(in1: [16]u1, in0: [16]u1, sel: u1) [16]u1 {
    return if (sel == 0) in0 else in1;
}

/// 16-bit 4-way multiplexer: selects one of 4 inputs based on 2-bit selector.
/// sel=00→in0, sel=01→in1, sel=10→in2, sel=11→in3
pub inline fn MUX4WAY16(in3: [16]u1, in2: [16]u1, in1: [16]u1, in0: [16]u1, sel: [2]u1) [16]u1 {
    const left = MUX16(in3, in2, sel[1]);
    const right = MUX16(in1, in0, sel[1]);
    return MUX16(left, right, sel[0]);
}

/// 16-bit 8-way multiplexer: selects one of 8 inputs based on 3-bit selector.
pub inline fn MUX8WAY16(
    in7: [16]u1,
    in6: [16]u1,
    in5: [16]u1,
    in4: [16]u1,
    in3: [16]u1,
    in2: [16]u1,
    in1: [16]u1,
    in0: [16]u1,
    sel: [3]u1,
) [16]u1 {
    const left = MUX4WAY16(in7, in6, in5, in4, [2]u1{ sel[1], sel[2] });
    const right = MUX4WAY16(in3, in2, in1, in0, [2]u1{ sel[1], sel[2] });
    return MUX16(left, right, sel[0]);
}

// ============================================================================
// Demultiplexers (Bit-Array Version)
// ============================================================================

/// 2-way demultiplexer: routes input to out[1] when sel=1, out[0] when sel=0.
/// Returns [out_sel1, out_sel0]
pub inline fn DMUX(in: u1, sel: u1) [2]u1 {
    return [2]u1{ in & sel, in & ~sel };
    // return [2]u1{
    //     logic.Logic.AND(in, sel),
    //     logic.Logic.AND(in, logic.Logic.NOT(sel)),
    // };
}

/// 4-way demultiplexer: routes input to one of 4 outputs based on 2-bit selector.
pub inline fn DMUX4WAY(in: u1, sel: [2]u1) [4]u1 {
    const top = DMUX(in, sel[0]);
    const lower = DMUX(top[0], sel[1]);
    const upper = DMUX(top[1], sel[1]);
    return [4]u1{ lower[0], lower[1], upper[0], upper[1] };
}

/// 8-way demultiplexer: routes input to one of 8 outputs based on 3-bit selector.
pub inline fn DMUX8WAY(in: u1, sel: [3]u1) [8]u1 {
    const top = DMUX(in, sel[0]);
    const lower = DMUX4WAY(top[0], [2]u1{ sel[1], sel[2] });
    const upper = DMUX4WAY(top[1], [2]u1{ sel[1], sel[2] });
    return [8]u1{
        lower[0], lower[1], lower[2], lower[3],
        upper[0], upper[1], upper[2], upper[3],
    };
}

// ============================================================================
// Multiplexers (Integer Version) - Suffix _I
// ============================================================================

/// 2-way multiplexer (integer version).
pub inline fn MUX_I(in1: u1, in0: u1, sel: u1) u1 {
    return if (sel == 0) in0 else in1;
}

/// 16-bit 2-way multiplexer (integer version).
pub inline fn MUX16_I(in1: u16, in0: u16, sel: u1) u16 {
    return if (sel == 0) in0 else in1;
}

/// 16-bit 4-way multiplexer (integer version).
pub inline fn MUX4WAY16_I(in3: u16, in2: u16, in1: u16, in0: u16, sel: u2) u16 {
    const sel_lo: u1 = @truncate(sel);
    const sel_hi: u1 = @truncate(sel >> 1);
    const left = MUX16_I(in3, in2, sel_lo);
    const right = MUX16_I(in1, in0, sel_lo);
    return MUX16_I(left, right, sel_hi);
}

/// 16-bit 8-way multiplexer (integer version).
pub inline fn MUX8WAY16_I(
    in7: u16,
    in6: u16,
    in5: u16,
    in4: u16,
    in3: u16,
    in2: u16,
    in1: u16,
    in0: u16,
    sel: u3,
) u16 {
    const sel_lo: u2 = @truncate(sel);
    const sel_hi: u1 = @truncate(sel >> 2);
    const left = MUX4WAY16_I(in7, in6, in5, in4, sel_lo);
    const right = MUX4WAY16_I(in3, in2, in1, in0, sel_lo);
    return MUX16_I(left, right, sel_hi);
}

// ============================================================================
// Demultiplexers (Integer Version) - Suffix _I
// ============================================================================

/// 2-way demultiplexer (integer version).
/// Returns a u2 with the bit set at position `sel`.
pub inline fn DMUX_I(in: u1, sel: u1) u2 {
    return @as(u2, in) << sel;
}

/// 4-way demultiplexer (integer version).
pub inline fn DMUX4WAY_I(in: u1, sel: u2) u4 {
    return @as(u4, in) << sel;
}

/// 8-way demultiplexer (integer version).
pub inline fn DMUX8WAY_I(in: u1, sel: u3) u8 {
    return @as(u8, in) << sel;
}

// ============================================================================
// Tests
// ============================================================================

test "MUX/DMUX" {
    std.debug.print("\nMUX TEST------------------\n", .{});
    std.debug.print("sel  in1  in0  MUX   DMUX\n", .{});

    for (0..2) |isel| {
        const sel: u1 = @intCast(isel);
        for (0..2) |idx1| {
            const in1: u1 = @intCast(idx1);
            for (0..2) |idx0| {
                const in0: u1 = @intCast(idx0);

                const mux_out = MUX(in1, in0, sel);
                const dmux_out = DMUX(in1, sel);

                std.debug.print(" {d}    {d}    {d}    {d}    {d},{d}\n", .{
                    sel, in1, in0, mux_out, dmux_out[0], dmux_out[1],
                });
            }
        }
    }

    // MUX truth table: sel=0 → in0, sel=1 → in1
    try testing.expectEqual(@as(u1, 0), MUX(0, 0, 0));
    try testing.expectEqual(@as(u1, 1), MUX(0, 1, 0));
    try testing.expectEqual(@as(u1, 0), MUX(0, 1, 1));
    try testing.expectEqual(@as(u1, 1), MUX(1, 0, 1));

    // DMUX: routes input to position indicated by sel
    try testing.expectEqual([2]u1{ 0, 0 }, DMUX(0, 0));
    try testing.expectEqual([2]u1{ 0, 1 }, DMUX(1, 0));
    try testing.expectEqual([2]u1{ 1, 0 }, DMUX(1, 1));
    try testing.expectEqual([2]u1{ 0, 0 }, DMUX(0, 1));
}

test "MUX16" {
    try testing.expectEqual(b16(1), MUX16(b16(0), b16(1), 0));
    try testing.expectEqual(b16(0), MUX16(b16(0), b16(1), 1));
    try testing.expectEqual(@as(u16, 1), MUX16_I(0, 1, 0));
    try testing.expectEqual(@as(u16, 0), MUX16_I(0, 1, 1));
}

test "MUX4WAY16" {
    std.debug.print("\nMUX4WAY16------------------\n", .{});
    for (0..4) |i| {
        const sel: u2 = @intCast(i);
        const expected: u16 = @as(u16, 1) << sel;

        const result = MUX4WAY16(b16(8), b16(4), b16(2), b16(1), b2(i));
        try testing.expectEqual(b16(expected), result);

        const result_i = MUX4WAY16_I(8, 4, 2, 1, sel);
        try testing.expectEqual(expected, result_i);

        std.debug.print("8, 4, 2, 1  sel={b:0>2}:{d} -> {d}\n", .{ i, i, result_i });
    }
}

test "MUX8WAY16" {
    std.debug.print("\nMUX8WAY16------------------\n", .{});
    for (0..8) |i| {
        const sel: u3 = @intCast(i);
        const expected: u16 = @as(u16, 1) << sel;

        const result = MUX8WAY16(b16(128), b16(64), b16(32), b16(16), b16(8), b16(4), b16(2), b16(1), b3(i));
        try testing.expectEqual(b16(expected), result);

        const result_i = MUX8WAY16_I(128, 64, 32, 16, 8, 4, 2, 1, sel);
        try testing.expectEqual(expected, result_i);

        std.debug.print("128, 64, 32, 16, 8, 4, 2, 1  sel={b:0>3}:{d} -> {d}\n", .{ i, i, result_i });
    }
}

test "DMUX4WAY" {
    std.debug.print("\nDMUX4WAY------------------\n", .{});
    for (0..4) |i| {
        const sel: u2 = @intCast(i);
        const expected: u4 = @as(u4, 1) << sel;

        try testing.expectEqual(b4(0), DMUX4WAY(0, b2(i)));
        const dmux4way = DMUX4WAY(1, b2(i));
        try testing.expectEqual(b4(expected), dmux4way);

        try testing.expectEqual(@as(u4, 0), DMUX4WAY_I(0, sel));
        try testing.expectEqual(expected, DMUX4WAY_I(1, sel));

        std.debug.print("sel={b:0>2}:{d} -> {any}\n", .{ i, i, dmux4way });
    }
}

test "DMUX8WAY" {
    std.debug.print("\nDMUX8WAY------------------\n", .{});
    for (0..8) |i| {
        const sel: u3 = @intCast(i);
        const expected: u8 = @as(u8, 1) << sel;

        try testing.expectEqual(b8(0), DMUX8WAY(0, b3(i)));
        const dmux8way = DMUX8WAY(1, b3(i));
        try testing.expectEqual(b8(expected), dmux8way);

        try testing.expectEqual(@as(u8, 0), DMUX8WAY_I(0, sel));
        try testing.expectEqual(expected, DMUX8WAY_I(1, sel));

        std.debug.print("sel={b:0>3}:{d} -> {any}\n", .{ i, i, dmux8way });
    }
}
