const std = @import("std");
const t = std.testing;

const logic = @import("logic.zig").Logic;
const adder = @import("adder.zig");

const u = @import("utils.zig");
const b16 = u.b16;

// /**
//  * ALU (Arithmetic Logic Unit):
//  * Computes out = one of the following functions:
//  *                0, 1, -1,
//  *                x, y, !x, !y, -x, -y,
//  *                x + 1, y + 1, x - 1, y - 1,
//  *                x + y, x - y, y - x,
//  *                x & y, x | y
//  * on the 16-bit inputs x, y,
//  * according to the input bits zx, nx, zy, ny, f, no.
//  * In addition, computes the two output bits:
//  * if (out == 0) zr = 1, else zr = 0
//  * if (out < 0)  ng = 1, else ng = 0
//  */
// // Implementation: Manipulates the x and y inputs
// // and operates on the resulting values, as follows:
// // if (zx == 1) sets x = 0        // 16-bit constant
// // if (nx == 1) sets x = !x       // bitwise not
// // if (zy == 1) sets y = 0        // 16-bit constant
// // if (ny == 1) sets y = !y       // bitwise not
// // if (f == 1)  sets out = x + y  // integer 2's complement addition
// // if (f == 0)  sets out = x & y  // bitwise and
// // if (no == 1) sets out = !out   // bitwise not

// CHIP ALU {
//     IN
//         x[16], y[16],  // 16-bit inputs
//         zx, // zero the x input?
//         nx, // negate the x input?
//         zy, // zero the y input?
//         ny, // negate the y input?
//         f,  // compute (out = x + y) or (out = x & y)?
//         no; // negate the out output?
//     OUT
//         out[16], // 16-bit output
//         zr,      // if (out == 0) equals 1, else 0
//         ng;      // if (out < 0)  equals 1, else 0

//     PARTS:
//     // if (zx==1) set x = 0
//     Mux16(a=x,b=false,sel=zx,out=zxout);

//     // if (zy==1) set y = 0
//     Mux16(a=y,b=false,sel=zy,out=zyout);

//     // if (nx==1) set x = ~x
//     // if (ny==1) set y = ~y
//     Not16(in=zxout,out=notx);
//     Not16(in=zyout,out=noty);
//     Mux16(a=zxout,b=notx,sel=nx,out=nxout);
//     Mux16(a=zyout,b=noty,sel=ny,out=nyout);

//     // if (f==1)  set out = x + y
//     // if (f==0)  set out = x & y
//     Add16(a=nxout,b=nyout,out=addout);
//     And16(a=nxout,b=nyout,out=andout);
//     Mux16(a=andout,b=addout,sel=f,out=fout);

//     // if (no==1) set out = ~out
//     // 1 if (out<0),  0 otherwise
//     Not16(in=fout,out=nfout);
//     Mux16(a=fout,b=nfout,sel=no,out=out,out[0..7]=zr1,out[8..15]=zr2,out[15]=ng);

//     // 1 if (out==0), 0 otherwise
//     Or8Way(in=zr1,out=or1);
//     Or8Way(in=zr2,out=or2);
//     Or(a=or1,b=or2,out=or3);
//     Not(in=or3,out=zr);
// }

pub const ALUResult = struct {
    out: [16]u1,
    zr: u1, // 1 if out == 0
    ng: u1, // 1 if out < 0
};

pub const ALUResult_I = struct {
    out: u16,
    zr: u1,
    ng: u1,
};

const ZERO16 = [16]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

/// Bit-array version of ALU
pub inline fn ALU(x: [16]u1, y: [16]u1, zx: u1, nx: u1, zy: u1, ny: u1, f: u1, no: u1) ALUResult {
    // if (zx==1) set x = 0
    // Mux16(a=x,b=false,sel=zx,out=zxout);
    const zxout = logic.MUX16(ZERO16, x, zx);

    // if (zy==1) set y = 0
    // Mux16(a=y,b=false,sel=zy,out=zyout);
    const zyout = logic.MUX16(ZERO16, y, zy);

    // if (nx==1) set x = ~x
    // if (ny==1) set y = ~y
    // Not16(in=zxout,out=notx);
    // Not16(in=zyout,out=noty);
    // Mux16(a=zxout,b=notx,sel=nx,out=nxout);
    // Mux16(a=zyout,b=noty,sel=ny,out=nyout);
    const notx = logic.NOT16(zxout);
    const noty = logic.NOT16(zyout);
    const nxout = logic.MUX16(notx, zxout, nx);
    const nyout = logic.MUX16(noty, zyout, ny);

    // if (f==1)  set out = x + y
    // if (f==0)  set out = x & y
    // Add16(a=nxout,b=nyout,out=addout);
    // And16(a=nxout,b=nyout,out=andout);
    // Mux16(a=andout,b=addout,sel=f,out=fout);
    const addout = adder.RIPPLE_ADDER_16(nxout, nyout).sum;
    const andout = logic.AND16(nxout, nyout);
    const fout = logic.MUX16(addout, andout, f);

    // if (no==1) set out = ~out
    // 1 if (out<0),  0 otherwise
    // Not16(in=fout,out=nfout);
    // Mux16(a=fout,b=nfout,sel=no,out=out,out[0..7]=zr1,out[8..15]=zr2,out[15]=ng);
    const nfout = logic.NOT16(fout);
    const out = logic.MUX16(nfout, fout, no);
    const ng = out[0]; // MSB (bit 15) indicates negative in two's complement

    // 1 if (out==0), 0 otherwise
    // Or8Way(in=zr1,out=or1);
    // Or8Way(in=zr2,out=or2);
    // Or(a=or1,b=or2,out=or3);
    // Not(in=or3,out=zr);
    const zr1: [8]u1 = out[8..16].*; // low 8 bits (indices 8-15)
    const zr2: [8]u1 = out[0..8].*; // high 8 bits (indices 0-7)
    const or1 = logic.OR8WAY(zr1);
    const or2 = logic.OR8WAY(zr2);
    const or3 = logic.OR(or1, or2);
    const zr = logic.NOT(or3);

    return .{ .out = out, .zr = zr, .ng = ng };
}

/// Integer version of ALU
pub inline fn ALU_I(x: u16, y: u16, zx: u1, nx: u1, zy: u1, ny: u1, f: u1, no: u1) ALUResult_I {
    // if (zx==1) set x = 0
    // Mux16(a=x,b=false,sel=zx,out=zxout);
    const zxout = logic.MUX16_I(0, x, zx);

    // if (zy==1) set y = 0
    // Mux16(a=y,b=false,sel=zy,out=zyout);
    const zyout = logic.MUX16_I(0, y, zy);

    // if (nx==1) set x = ~x
    // if (ny==1) set y = ~y
    // Not16(in=zxout,out=notx);
    // Not16(in=zyout,out=noty);
    // Mux16(a=zxout,b=notx,sel=nx,out=nxout);
    // Mux16(a=zyout,b=noty,sel=ny,out=nyout);
    const notx = logic.NOT16_I(zxout);
    const noty = logic.NOT16_I(zyout);
    const nxout = logic.MUX16_I(notx, zxout, nx);
    const nyout = logic.MUX16_I(noty, zyout, ny);

    // if (f==1)  set out = x + y
    // if (f==0)  set out = x & y
    // Add16(a=nxout,b=nyout,out=addout);
    // And16(a=nxout,b=nyout,out=andout);
    // Mux16(a=andout,b=addout,sel=f,out=fout);
    const addout = adder.RIPPLE_ADDER_16_I(nxout, nyout).sum;
    const andout = logic.AND16_I(nxout, nyout);
    const fout = logic.MUX16_I(addout, andout, f);

    // if (no==1) set out = ~out
    // 1 if (out<0),  0 otherwise
    // Not16(in=fout,out=nfout);
    // Mux16(a=fout,b=nfout,sel=no,out=out,out[0..7]=zr1,out[8..15]=zr2,out[15]=ng);
    const nfout = logic.NOT16_I(fout);
    const out = logic.MUX16_I(nfout, fout, no);
    const ng: u1 = @truncate(out >> 15); // MSB indicates negative

    // 1 if (out==0), 0 otherwise
    // Or8Way(in=zr1,out=or1);
    // Or8Way(in=zr2,out=or2);
    // Or(a=or1,b=or2,out=or3);
    // Not(in=or3,out=zr);
    const zr1: u8 = @truncate(out);
    const zr2: u8 = @truncate(out >> 8);
    const or1 = logic.OR8WAY_I(zr1);
    const or2 = logic.OR8WAY_I(zr2);
    const or3 = logic.OR(or1, or2);
    const zr = logic.NOT(or3);

    return .{ .out = out, .zr = zr, .ng = ng };
}

test "ALU" {
    std.debug.print("\nALU TEST------------------\n", .{});

    // Test table from nand2tetris ALU.cmp
    // |   x   |   y   |zx|nx|zy|ny| f|no|  out  |zr|ng|
    const tests = [_]struct { x: u16, y: u16, zx: u1, nx: u1, zy: u1, ny: u1, f: u1, no: u1, out: u16, zr: u1, ng: u1 }{
        // x=0, y=0xFFFF
        .{ .x = 0, .y = 0xFFFF, .zx = 1, .nx = 0, .zy = 1, .ny = 0, .f = 1, .no = 0, .out = 0x0000, .zr = 1, .ng = 0 }, // 0
        .{ .x = 0, .y = 0xFFFF, .zx = 1, .nx = 1, .zy = 1, .ny = 1, .f = 1, .no = 1, .out = 0x0001, .zr = 0, .ng = 0 }, // 1
        .{ .x = 0, .y = 0xFFFF, .zx = 1, .nx = 1, .zy = 1, .ny = 0, .f = 1, .no = 0, .out = 0xFFFF, .zr = 0, .ng = 1 }, // -1
        .{ .x = 0, .y = 0xFFFF, .zx = 0, .nx = 0, .zy = 1, .ny = 1, .f = 0, .no = 0, .out = 0x0000, .zr = 1, .ng = 0 }, // x
        .{ .x = 0, .y = 0xFFFF, .zx = 1, .nx = 1, .zy = 0, .ny = 0, .f = 0, .no = 0, .out = 0xFFFF, .zr = 0, .ng = 1 }, // y
        .{ .x = 0, .y = 0xFFFF, .zx = 0, .nx = 0, .zy = 1, .ny = 1, .f = 0, .no = 1, .out = 0xFFFF, .zr = 0, .ng = 1 }, // !x
        .{ .x = 0, .y = 0xFFFF, .zx = 1, .nx = 1, .zy = 0, .ny = 0, .f = 0, .no = 1, .out = 0x0000, .zr = 1, .ng = 0 }, // !y
        .{ .x = 0, .y = 0xFFFF, .zx = 0, .nx = 0, .zy = 1, .ny = 1, .f = 1, .no = 1, .out = 0x0000, .zr = 1, .ng = 0 }, // -x
        .{ .x = 0, .y = 0xFFFF, .zx = 1, .nx = 1, .zy = 0, .ny = 0, .f = 1, .no = 1, .out = 0x0001, .zr = 0, .ng = 0 }, // -y
        .{ .x = 0, .y = 0xFFFF, .zx = 0, .nx = 1, .zy = 1, .ny = 1, .f = 1, .no = 1, .out = 0x0001, .zr = 0, .ng = 0 }, // x+1
        .{ .x = 0, .y = 0xFFFF, .zx = 1, .nx = 1, .zy = 0, .ny = 1, .f = 1, .no = 1, .out = 0x0000, .zr = 1, .ng = 0 }, // y+1
        .{ .x = 0, .y = 0xFFFF, .zx = 0, .nx = 0, .zy = 1, .ny = 1, .f = 1, .no = 0, .out = 0xFFFF, .zr = 0, .ng = 1 }, // x-1
        .{ .x = 0, .y = 0xFFFF, .zx = 1, .nx = 1, .zy = 0, .ny = 0, .f = 1, .no = 0, .out = 0xFFFE, .zr = 0, .ng = 1 }, // y-1
        .{ .x = 0, .y = 0xFFFF, .zx = 0, .nx = 0, .zy = 0, .ny = 0, .f = 1, .no = 0, .out = 0xFFFF, .zr = 0, .ng = 1 }, // x+y
        .{ .x = 0, .y = 0xFFFF, .zx = 0, .nx = 1, .zy = 0, .ny = 0, .f = 1, .no = 1, .out = 0x0001, .zr = 0, .ng = 0 }, // x-y
        .{ .x = 0, .y = 0xFFFF, .zx = 0, .nx = 0, .zy = 0, .ny = 1, .f = 1, .no = 1, .out = 0xFFFF, .zr = 0, .ng = 1 }, // y-x
        .{ .x = 0, .y = 0xFFFF, .zx = 0, .nx = 0, .zy = 0, .ny = 0, .f = 0, .no = 0, .out = 0x0000, .zr = 1, .ng = 0 }, // x&y
        .{ .x = 0, .y = 0xFFFF, .zx = 0, .nx = 1, .zy = 0, .ny = 1, .f = 0, .no = 1, .out = 0xFFFF, .zr = 0, .ng = 1 }, // x|y
        // x=17, y=3
        .{ .x = 17, .y = 3, .zx = 1, .nx = 0, .zy = 1, .ny = 0, .f = 1, .no = 0, .out = 0x0000, .zr = 1, .ng = 0 }, // 0
        .{ .x = 17, .y = 3, .zx = 1, .nx = 1, .zy = 1, .ny = 1, .f = 1, .no = 1, .out = 0x0001, .zr = 0, .ng = 0 }, // 1
        .{ .x = 17, .y = 3, .zx = 1, .nx = 1, .zy = 1, .ny = 0, .f = 1, .no = 0, .out = 0xFFFF, .zr = 0, .ng = 1 }, // -1
        .{ .x = 17, .y = 3, .zx = 0, .nx = 0, .zy = 1, .ny = 1, .f = 0, .no = 0, .out = 0x0011, .zr = 0, .ng = 0 }, // x
        .{ .x = 17, .y = 3, .zx = 1, .nx = 1, .zy = 0, .ny = 0, .f = 0, .no = 0, .out = 0x0003, .zr = 0, .ng = 0 }, // y
        .{ .x = 17, .y = 3, .zx = 0, .nx = 0, .zy = 1, .ny = 1, .f = 0, .no = 1, .out = 0xFFEE, .zr = 0, .ng = 1 }, // !x
        .{ .x = 17, .y = 3, .zx = 1, .nx = 1, .zy = 0, .ny = 0, .f = 0, .no = 1, .out = 0xFFFC, .zr = 0, .ng = 1 }, // !y
        .{ .x = 17, .y = 3, .zx = 0, .nx = 0, .zy = 1, .ny = 1, .f = 1, .no = 1, .out = 0xFFEF, .zr = 0, .ng = 1 }, // -x
        .{ .x = 17, .y = 3, .zx = 1, .nx = 1, .zy = 0, .ny = 0, .f = 1, .no = 1, .out = 0xFFFD, .zr = 0, .ng = 1 }, // -y
        .{ .x = 17, .y = 3, .zx = 0, .nx = 1, .zy = 1, .ny = 1, .f = 1, .no = 1, .out = 0x0012, .zr = 0, .ng = 0 }, // x+1
        .{ .x = 17, .y = 3, .zx = 1, .nx = 1, .zy = 0, .ny = 1, .f = 1, .no = 1, .out = 0x0004, .zr = 0, .ng = 0 }, // y+1
        .{ .x = 17, .y = 3, .zx = 0, .nx = 0, .zy = 1, .ny = 1, .f = 1, .no = 0, .out = 0x0010, .zr = 0, .ng = 0 }, // x-1
        .{ .x = 17, .y = 3, .zx = 1, .nx = 1, .zy = 0, .ny = 0, .f = 1, .no = 0, .out = 0x0002, .zr = 0, .ng = 0 }, // y-1
        .{ .x = 17, .y = 3, .zx = 0, .nx = 0, .zy = 0, .ny = 0, .f = 1, .no = 0, .out = 0x0014, .zr = 0, .ng = 0 }, // x+y
        .{ .x = 17, .y = 3, .zx = 0, .nx = 1, .zy = 0, .ny = 0, .f = 1, .no = 1, .out = 0x000E, .zr = 0, .ng = 0 }, // x-y
        .{ .x = 17, .y = 3, .zx = 0, .nx = 0, .zy = 0, .ny = 1, .f = 1, .no = 1, .out = 0xFFF2, .zr = 0, .ng = 1 }, // y-x
        .{ .x = 17, .y = 3, .zx = 0, .nx = 0, .zy = 0, .ny = 0, .f = 0, .no = 0, .out = 0x0001, .zr = 0, .ng = 0 }, // x&y
        .{ .x = 17, .y = 3, .zx = 0, .nx = 1, .zy = 0, .ny = 1, .f = 0, .no = 1, .out = 0x0013, .zr = 0, .ng = 0 }, // x|y
    };

    // Print header
    std.debug.print("|        x         |        y         |zx |nx |zy |ny | f |no |       out        |zr |ng |\n", .{});

    for (tests) |tc| {
        // Test bit-array version
        const r = ALU(b16(tc.x), b16(tc.y), tc.zx, tc.nx, tc.zy, tc.ny, tc.f, tc.no);
        try t.expectEqual(b16(tc.out), r.out);
        try t.expectEqual(tc.zr, r.zr);
        try t.expectEqual(tc.ng, r.ng);

        // Test integer version
        const r_i = ALU_I(tc.x, tc.y, tc.zx, tc.nx, tc.zy, tc.ny, tc.f, tc.no);
        try t.expectEqual(tc.out, r_i.out);
        try t.expectEqual(tc.zr, r_i.zr);
        try t.expectEqual(tc.ng, r_i.ng);

        std.debug.print("| {b:0>16} | {b:0>16} | {} | {} | {} | {} | {} | {} | {b:0>16} | {} | {} |\n", .{
            tc.x, tc.y, tc.zx, tc.nx, tc.zy, tc.ny, tc.f, tc.no, r_i.out, r_i.zr, r_i.ng,
        });
    }
}
