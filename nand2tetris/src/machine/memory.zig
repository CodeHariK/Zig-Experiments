// =============================================================================
// Memory (Complete Address Space)
// =============================================================================
//
// The Memory chip provides the complete address space of the Hack computer,
// including RAM and memory-mapped I/O (Screen and Keyboard).
//
// -----------------------------------------------------------------------------
// Memory Overview
// -----------------------------------------------------------------------------
//
// The Memory chip facilitates read and write operations:
//   Read:  out(t) = Memory[address(t)](t)
//   Write: if load(t-1) then Memory[address(t-1)](t) = in(t-1)
//
// Address space:
//   - 0x0000-0x3FFF (0-16383): RAM16K (16K words)
//   - 0x4000-0x5FFF (16384-24575): Screen (8K words)
//   - 0x6000 (24576): Keyboard (1 word, read-only)
//   - 0x6001-0x7FFF: Invalid (reads 0)
//
// -----------------------------------------------------------------------------
// Memory Interface
// -----------------------------------------------------------------------------
//
// Inputs:
//   in[16]      - 16-bit value to write
//   load        - Write enable (1 = write, 0 = read)
//   address[15] - 15-bit address (0-32767)
//
// Outputs:
//   out[16]     - Value at the specified address
//
// -----------------------------------------------------------------------------
// Address Decoding
// -----------------------------------------------------------------------------
//
// Address bits:
//   address[14] - Selects RAM (0) or Screen/Keyboard (1)
//   address[13] - When address[14]=1, selects Screen (0) or Keyboard (1)
//
// Component addressing:
//   RAM16K:     address[0..13] (14 bits, 0-16383)
//   Screen:     address[0..12] (13 bits, 0-8191, relative to base 16384)
//   Keyboard:   address == 0x6000 (address[14]=1, address[13]=1, address[0..12]=0)
//
// -----------------------------------------------------------------------------
// Implementation
// -----------------------------------------------------------------------------
//
// This implementation follows the HDL specification:
//   1. DMux on address[14] to route load to RAM or Screen/Keyboard
//   2. DMux on address[13] to route Screen/Keyboard load to Screen or nothing
//   3. RAM16K handles addresses 0-16383
//   4. Screen handles addresses 16384-24575
//   5. Keyboard handles address 24576 (read-only)
//   6. Mux16 selects output from RAM or Screen/Keyboard based on address[14]
//   7. Mux16 selects output from Screen or Keyboard based on address[13]
//
// -----------------------------------------------------------------------------

const std = @import("std");
const testing = std.testing;

const memory = @import("memory").Memory;
const logic = @import("gates").Logic;

const types = @import("types");
const b14 = types.b14;
const b15 = types.b15;
const b16 = types.b16;
const fb16 = types.fb16;
const fromBits = types.fromBits;

const screen_mod = @import("screen.zig");
const keyboard_mod = @import("keyboard.zig");

// =============================================================================
// Memory - Complete Address Space
// =============================================================================

/// Memory - Complete address space including RAM, Screen, and Keyboard.
///
/// Implements the complete memory map:
///   - RAM16K: addresses 0-16383
///   - Screen: addresses 16384-24575
///   - Keyboard: address 24576
///
/// Uses bit arrays for addresses and data: [15]u1 for address, [16]u1 for data.
pub const Memory = struct {
    ram: memory.Ram16K = .{},
    screen: screen_mod.Screen = .{},
    keyboard: keyboard_mod.Keyboard = .{},

    const Self = @This();

    /// Update Memory with new input, address, and load signal.
    /// Returns the current value at the specified address.
    ///
    /// Behavior:
    ///   - Always reads from the addressed location
    ///   - If load=1, writes input to the addressed location
    ///   - Write takes effect in the next time step
    pub fn tick(self: *Self, input: [16]u1, address: [15]u1, load: u1) [16]u1 {
        // Map nand2tetris address bits (LSB-first) to our MSB-first system:
        // nand2tetris address[14] (MSB) → our address[0] (MSB)
        // nand2tetris address[13] → our address[1]
        // nand2tetris address[0..13] → our address[1..15] (14 bits for RAM16K)
        // nand2tetris address[0..12] → our address[2..15] (13 bits for Screen)
        // nand2tetris address[0..7] → our address[7..14] (8 bits)
        // nand2tetris address[8..12] → our address[2..6] (5 bits)

        const addr_14: u1 = address[0]; // nand2tetris address[14] - selects RAM (0) or Screen/Keyboard (1)
        const addr_13: u1 = address[1]; // nand2tetris address[13] - selects Screen (0) or Keyboard (1) when addr_14=1
        const addr_0_13: [14]u1 = address[1..15].*; // nand2tetris address[0..13] - RAM16K address
        const addr_0_12: [13]u1 = address[2..15].*; // nand2tetris address[0..12] - Screen address

        // Step 1: DMux on address[14] to route load signal
        // DMux(in, sel) returns [out_sel1, out_sel0]
        // When sel=0: out[0]=0, out[1]=in (RAM selected)
        // When sel=1: out[0]=in, out[1]=0 (Screen/Keyboard selected)
        const ram_sk_dmux = logic.DMUX(load, addr_14);
        const ramload: u1 = ram_sk_dmux[1]; // When addr_14=0 (RAM) - out[1] gets input
        const skload: u1 = ram_sk_dmux[0]; // When addr_14=1 (Screen/Keyboard) - out[0] gets input

        // Step 2: DMux on address[13] to route Screen/Keyboard load signal
        const screen_kbd_dmux = logic.DMUX(skload, addr_13);
        const sload: u1 = screen_kbd_dmux[1]; // When addr_13=0 (Screen) - out[1] gets input
        // nothing = screen_kbd_dmux[0] when addr_13=1 (Keyboard - read-only, so no load)

        // Step 3: Load RAM16K and Screen
        const ramout = self.ram.tick(input, addr_0_13, ramload);
        const screenout = self.screen.tick(input, addr_0_12, sload);

        // Step 4: Handle Keyboard
        // Keyboard is at address 0x6000, which means:
        //   nand2tetris: address[14]=1, address[13]=1, address[0..12]=0
        //   our system: address[0]=1, address[1]=1, address[2..14]=0
        // Check if address[0..12] (nand2tetris) = address[2..14] (our system) are all 0
        // nand2tetris address[0..7] → our address[7..14] (8 bits)
        const addr_0_7: [8]u1 = address[7..15].*; // nand2tetris address[0..7]
        const notkbd1 = logic.OR8WAY(addr_0_7);
        // nand2tetris address[8..12] → our address[2..6] (5 bits)
        const addr_8_12: [5]u1 = address[2..7].*; // nand2tetris address[8..12]
        // Pad to 8 bits for OR8WAY (in[0..4]=address[8..12], in[5..7]=false)
        var addr_8_12_padded: [8]u1 = undefined;
        addr_8_12_padded[0..5].* = addr_8_12;
        addr_8_12_padded[5..8].* = [3]u1{ 0, 0, 0 };
        const notkbd2 = logic.OR8WAY(addr_8_12_padded);
        const notkbd = logic.OR(notkbd1, notkbd2);

        const kbd = self.keyboard.read();
        // Mux16(a=kbd, b=false, sel=notkbd, out=kbdout)
        // If notkbd=1 (any bit set), output false (0), else output kbd
        const kbdout = logic.MUX16(b16(0), kbd, notkbd);

        // Step 5: Determine which is the output
        // Mux16(a=screenout, b=kbdout, sel=address[13], out=outsk)
        // sel=0 → screenout, sel=1 → kbdout
        const outsk = logic.MUX16(kbdout, screenout, addr_13);

        // Mux16(a=ramout, b=outsk, sel=address[14], out=out)
        // sel=0 → ramout, sel=1 → outsk
        const out = logic.MUX16(outsk, ramout, addr_14);

        return out;
    }

    /// Get the current value at the specified address without advancing time.
    pub fn peek(self: *const Self, address: [15]u1) [16]u1 {
        // Map nand2tetris address bits (LSB-first) to our MSB-first system
        const addr_14: u1 = address[0]; // nand2tetris address[14]
        const addr_13: u1 = address[1]; // nand2tetris address[13]
        const addr_0_13: [14]u1 = address[1..15].*; // nand2tetris address[0..13] - RAM16K address
        const addr_0_12: [13]u1 = address[2..15].*; // nand2tetris address[0..12] - Screen address

        // Read from RAM16K
        const ramout = self.ram.peek(addr_0_13);

        // Read from Screen
        const screenout = self.screen.peek(addr_0_12);

        // Handle Keyboard (same logic as tick)
        // nand2tetris address[0..7] → our address[7..14]
        const addr_0_7: [8]u1 = address[7..15].*;
        const notkbd1 = logic.OR8WAY(addr_0_7);
        // nand2tetris address[8..12] → our address[2..6]
        const addr_8_12: [5]u1 = address[2..7].*;
        var addr_8_12_padded: [8]u1 = undefined;
        addr_8_12_padded[0..5].* = addr_8_12;
        addr_8_12_padded[5..8].* = [3]u1{ 0, 0, 0 };
        const notkbd2 = logic.OR8WAY(addr_8_12_padded);
        const notkbd = logic.OR(notkbd1, notkbd2);

        const kbd = self.keyboard.read();
        const kbdout = logic.MUX16(b16(0), kbd, notkbd);

        const outsk = logic.MUX16(kbdout, screenout, addr_13);
        const out = logic.MUX16(outsk, ramout, addr_14);

        return out;
    }

    /// Reset all memory components to initial state.
    pub fn reset(self: *Self) void {
        self.ram.reset();
        self.screen.reset();
        self.keyboard.reset();
    }

    /// Set keyboard key code (convenience method).
    pub fn setKeyboardKey(self: *Self, key_code: u16) void {
        self.keyboard.setKey(key_code);
    }
};
