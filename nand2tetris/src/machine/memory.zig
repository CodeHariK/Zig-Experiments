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
const logic = @import("logic").Logic;

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
        const inf = self.info(address);

        const ram_sk_dmux = logic.DMUX(load, inf.addr_14);
        const ramload: u1 = ram_sk_dmux[0]; // When addr_14=0 (RAM) - 'a' gets input
        const skload: u1 = ram_sk_dmux[1]; // When addr_14=1 (Screen/Keyboard) - 'b' gets input

        const screen_kbd_dmux = logic.DMUX(skload, inf.addr_13);
        const sload: u1 = screen_kbd_dmux[0]; // When addr_13=0 (Screen) - 'a' gets input
        const ramout = self.ram.tick(input, inf.addr_0_13, ramload);
        const screenout = self.screen.tick(input, inf.addr_0_12, sload);

        // When address[13]=0, select screenout; when address[13]=1, select kbdout
        const outsk = logic.MUX16(screenout, inf.kbd, inf.addr_13);

        // When address[14]=0, select ramout; when address[14]=1, select outsk
        const out = logic.MUX16(ramout, outsk, inf.addr_14);

        return out;
    }

    /// Get the current value at the specified address without advancing time.
    pub fn peek(self: *const Self, address: [15]u1) [16]u1 {
        const inf = self.info(address);

        // Read from RAM16K
        const ramout = self.ram.peek(inf.addr_0_13);

        // Read from Screen
        const screenout = self.screen.peek(inf.addr_0_12);

        // Mux16(a=screenout, b=kbdout, sel=address[13], out=outsk)
        // When address[13]=0, select screenout; when address[13]=1, select kbdout
        const outsk = logic.MUX16(screenout, inf.kbd, inf.addr_13);

        // Mux16(a=ramout, b=outsk, sel=address[14], out=out)
        // When address[14]=0, select ramout; when address[14]=1, select outsk
        const out = logic.MUX16(ramout, outsk, inf.addr_14);

        return out;
    }

    /// Get address information and device selection for a given address.
    pub fn info(self: *const Self, address: [15]u1) struct {
        device: []const u8,
        addr_14: u1,
        addr_13: u1,
        addr_0_13: [14]u1,
        addr_0_12: [13]u1,
        notkbd: u1,
        kbd: [16]u1,
    } {
        // With LSB-first: address[0] is LSB (bit 0), address[14] is MSB (bit 14)
        const addr_14: u1 = address[14]; // MSB - selects RAM (0) or Screen/Keyboard (1)
        const addr_13: u1 = address[13]; // Selects Screen (0) or Keyboard (1) when addr_14=1
        const addr_0_13: [14]u1 = address[0..14].*; // address[0..13] - RAM16K address
        const addr_0_12: [13]u1 = address[0..13].*; // address[0..12] - Screen address

        // Handle Keyboard (same logic as tick)
        // Or8Way(in=address[0..7], out=notkbd1)
        const addr_0_7: [8]u1 = address[0..8].*;
        const notkbd1 = logic.OR8WAY(addr_0_7);
        // Or8Way(in[0..4]=address[8..12], in[5..7]=false, out=notkbd2)
        const addr_8_12: [5]u1 = address[8..13].*;
        var addr_8_12_padded: [8]u1 = undefined;
        addr_8_12_padded[0..5].* = addr_8_12;
        addr_8_12_padded[5..8].* = [3]u1{ 0, 0, 0 };
        const notkbd2 = logic.OR8WAY(addr_8_12_padded);
        const notkbd = logic.OR(notkbd1, notkbd2);

        const kbd = self.keyboard.read();
        // Mux16(a=kbd, b=false, sel=notkbd, out=kbdout)
        const kbdout = logic.MUX16(kbd, b16(0), notkbd);

        const device = if (addr_14 == 0) "RAM" else if (notkbd == 0) "Kbd" else "Screen";

        return .{
            .device = device,
            .addr_14 = addr_14,
            .addr_13 = addr_13,
            .addr_0_13 = addr_0_13,
            .addr_0_12 = addr_0_12,
            .notkbd = notkbd,
            .kbd = kbdout,
        };
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

// =============================================================================
// Tests
// =============================================================================

test "Memory: comprehensive test vectors" {
    const TestCase = struct {
        in: i32,
        load: u1,
        address_str: u15,
        expected: i32,
    };

    const test_cases = [_]TestCase{
        .{ .in = 12345, .load = 1, .address_str = 0b010000000000000, .expected = 0 },
        .{ .in = 12345, .load = 1, .address_str = 0b010000000000000, .expected = 12345 },
        .{ .in = 12345, .load = 1, .address_str = 0b100000000000000, .expected = 0 },
        .{ .in = 12345, .load = 1, .address_str = 0b100000000000000, .expected = 12345 },
        .{ .in = -1, .load = 1, .address_str = 0b000000000000000, .expected = 0 },
        .{ .in = -1, .load = 1, .address_str = 0b000000000000000, .expected = -1 },
        .{ .in = 9999, .load = 0, .address_str = 0b000000000000000, .expected = -1 },
        .{ .in = 9999, .load = 0, .address_str = 0b000000000000000, .expected = -1 },
        .{ .in = 9999, .load = 0, .address_str = 0b010000000000000, .expected = 12345 },
        .{ .in = 9999, .load = 0, .address_str = 0b100000000000000, .expected = 12345 },
        .{ .in = 12345, .load = 1, .address_str = 0b000000000000000, .expected = -1 },
        .{ .in = 12345, .load = 1, .address_str = 0b000000000000000, .expected = 12345 },
        .{ .in = 12345, .load = 1, .address_str = 0b100000000000000, .expected = 12345 },
        .{ .in = 12345, .load = 1, .address_str = 0b100000000000000, .expected = 12345 },
        .{ .in = 2222, .load = 1, .address_str = 0b010000000000000, .expected = 12345 },
        .{ .in = 2222, .load = 1, .address_str = 0b010000000000000, .expected = 2222 },
        .{ .in = 9999, .load = 0, .address_str = 0b010000000000000, .expected = 2222 },
        .{ .in = 9999, .load = 0, .address_str = 0b010000000000000, .expected = 2222 },
        .{ .in = 9999, .load = 0, .address_str = 0b000000000000000, .expected = 12345 },
        .{ .in = 9999, .load = 0, .address_str = 0b100000000000000, .expected = 12345 },
        .{ .in = 9999, .load = 0, .address_str = 0b000000000000001, .expected = 0 },
        .{ .in = 9999, .load = 0, .address_str = 0b000000000000010, .expected = 0 },
        .{ .in = 9999, .load = 0, .address_str = 0b000000000000100, .expected = 0 },
        .{ .in = 9999, .load = 0, .address_str = 0b000000000001000, .expected = 0 },
        .{ .in = 9999, .load = 0, .address_str = 0b000000000010000, .expected = 0 },
        .{ .in = 9999, .load = 0, .address_str = 0b000000000100000, .expected = 0 },
        .{ .in = 9999, .load = 0, .address_str = 0b000000001000000, .expected = 0 },
        .{ .in = 9999, .load = 0, .address_str = 0b000000010000000, .expected = 0 },
        .{ .in = 9999, .load = 0, .address_str = 0b000000100000000, .expected = 0 },
        .{ .in = 9999, .load = 0, .address_str = 0b000001000000000, .expected = 0 },
        .{ .in = 9999, .load = 0, .address_str = 0b000010000000000, .expected = 0 },
        .{ .in = 9999, .load = 0, .address_str = 0b000100000000000, .expected = 0 },
        .{ .in = 9999, .load = 0, .address_str = 0b001000000000000, .expected = 0 },
        .{ .in = 9999, .load = 0, .address_str = 0b010000000000000, .expected = 2222 },
        .{ .in = 1234, .load = 1, .address_str = 0b001001000110100, .expected = 0 },
        .{ .in = 1234, .load = 1, .address_str = 0b001001000110100, .expected = 1234 },
        .{ .in = 1234, .load = 0, .address_str = 0b010001000110100, .expected = 0 },
        .{ .in = 1234, .load = 0, .address_str = 0b110001000110100, .expected = 0 },
        .{ .in = 2345, .load = 1, .address_str = 0b010001101000101, .expected = 0 },
        .{ .in = 2345, .load = 1, .address_str = 0b010001101000101, .expected = 2345 },
        .{ .in = 2345, .load = 0, .address_str = 0b000001101000101, .expected = 0 },
        .{ .in = 2345, .load = 0, .address_str = 0b100001101000101, .expected = 0 },
        .{ .in = 0, .load = 1, .address_str = 0b100000000000000, .expected = 12345 },
        .{ .in = 0, .load = 1, .address_str = 0b100000000000000, .expected = 0 },
        .{ .in = 0, .load = 1, .address_str = 0b110000000000000, .expected = 75 },
        .{ .in = 12345, .load = 1, .address_str = 0b000111111001111, .expected = 0 },
        .{ .in = 12345, .load = 1, .address_str = 0b000111111001111, .expected = 12345 },
        .{ .in = 12345, .load = 1, .address_str = 0b010111111001111, .expected = 0 },
        .{ .in = 12345, .load = 1, .address_str = 0b010111111001111, .expected = 12345 },
        .{ .in = -1, .load = 1, .address_str = 0b100111111001111, .expected = 0 },
        .{ .in = -1, .load = 1, .address_str = 0b100111111001111, .expected = -1 },
        .{ .in = -1, .load = 1, .address_str = 0b101000001001111, .expected = 0 },
        .{ .in = -1, .load = 1, .address_str = 0b101000001001111, .expected = -1 },
        .{ .in = -1, .load = 1, .address_str = 0b000111111001111, .expected = 12345 },
        .{ .in = -1, .load = 1, .address_str = 0b010111111001111, .expected = 12345 },
        .{ .in = -1, .load = 0, .address_str = 0b100111111001110, .expected = 0 },
        .{ .in = -1, .load = 0, .address_str = 0b100111111001101, .expected = 0 },
        .{ .in = -1, .load = 0, .address_str = 0b100111111001011, .expected = 0 },
        .{ .in = -1, .load = 0, .address_str = 0b100111111000111, .expected = 0 },
        .{ .in = -1, .load = 0, .address_str = 0b100111111011111, .expected = 0 },
        .{ .in = -1, .load = 0, .address_str = 0b100111111101111, .expected = 0 },
        .{ .in = -1, .load = 0, .address_str = 0b100111110001111, .expected = 0 },
        .{ .in = -1, .load = 0, .address_str = 0b100111101001111, .expected = 0 },
        .{ .in = -1, .load = 0, .address_str = 0b100111011001111, .expected = 0 },
        .{ .in = -1, .load = 0, .address_str = 0b100110111001111, .expected = 0 },
        .{ .in = -1, .load = 0, .address_str = 0b100101111001111, .expected = 0 },
        .{ .in = -1, .load = 0, .address_str = 0b100011111001111, .expected = 0 },
        .{ .in = -1, .load = 0, .address_str = 0b101111111001111, .expected = 0 },
        .{ .in = -1, .load = 0, .address_str = 0b110000000000000, .expected = 89 },
    };

    var mem = Memory{};
    mem.reset();
    // Set keyboard to return 75 initially (for test case at index 33)
    mem.setKeyboardKey(75);

    std.debug.print("\n|   in   |load |     address     |  out   | expected | device | peek |\n", .{});

    for (test_cases, 0..) |tc, i| {
        // Update keyboard to 89 before the last test case (which expects 89)
        if (i == test_cases.len - 1) {
            mem.setKeyboardKey(89);
        }

        const address = b15(tc.address_str);
        const input_u16: u16 = @bitCast(@as(i16, @intCast(tc.in)));
        const input = b16(input_u16);

        const output = mem.tick(input, address, tc.load);
        const output_value = @as(i16, @bitCast(fb16(output)));
        const expected_value = tc.expected;

        const inf = mem.info(address);
        const peek_bits = mem.peek(address);
        const peek_value = @as(i16, @bitCast(fb16(peek_bits)));

        const passed = output_value == expected_value;
        const status = if (passed) "✓" else "✗";

        std.debug.print("| {d:6} |  {d}  | {b:0>15} | {d:6} | {d:8} | {s:6} | {d:5}  {s}\n", .{
            tc.in,
            tc.load,
            fromBits(15, address),
            output_value,
            expected_value,
            inf.device,
            peek_value,
            status,
        });

        if (!passed) {
            std.debug.print("  FAILED: expected {d}, got {d}\n", .{ expected_value, output_value });
        }

        try testing.expectEqual(expected_value, output_value);
    }
}
