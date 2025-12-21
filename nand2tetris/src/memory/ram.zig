// =============================================================================
// RAM (Random Access Memory)
// =============================================================================
//
// RAM is an array of registers that can be accessed by address.
// "Random Access" means we can read/write ANY location in constant time.
//
// -----------------------------------------------------------------------------
// RAM Hierarchy in Nand2Tetris
// -----------------------------------------------------------------------------
//
// RAM8    =   8 registers  (3-bit address)
// RAM64   =  64 registers  (6-bit address)
// RAM512  = 512 registers  (9-bit address)
// RAM4K   = 4096 registers (12-bit address)
// RAM16K  = 16384 registers (14-bit address)
//
// Each level is built by combining 8 units of the previous level.
//
// -----------------------------------------------------------------------------
// RAM Interface (using RAM8 as example)
// -----------------------------------------------------------------------------
//
// Inputs:
//   in[16]    - 16-bit value to potentially store
//   address[3] - which of the 8 registers to access (0-7)
//   load      - 1 = write to selected register, 0 = just read
//
// Output:
//   out[16]   - value currently stored in the selected register
//
// -----------------------------------------------------------------------------
// RAM Behavior
// -----------------------------------------------------------------------------
//
// Read (always happening):
//   out = Register[address]
//
// Write (only when load=1):
//   Register[address] = in
//   (takes effect next cycle)
//
// Key insight: We're always reading from the addressed location.
// The load signal only controls whether we ALSO write.
//
// -----------------------------------------------------------------------------
// RAM8 Implementation Strategy
// -----------------------------------------------------------------------------
//
// Two main tasks:
// 1. DEMUX the load signal to the correct register
// 2. MUX the outputs to select the right register's value
//
//                  ┌─────────────────────────────────────────┐
//                  │               RAM8                       │
//                  │                                          │
//   in[16] ───────►├─────────► Reg0 ───────┐                  │
//                  ├─────────► Reg1 ───────┤                  │
//                  ├─────────► Reg2 ───────┤                  │
//                  ├─────────► Reg3 ───────┼────► Mux8Way16 ──┼──► out[16]
//                  ├─────────► Reg4 ───────┤                  │
//                  ├─────────► Reg5 ───────┤                  │
//                  ├─────────► Reg6 ───────┤                  │
//                  ├─────────► Reg7 ───────┘                  │
//                  │             ▲                  ▲          │
//                  │             │                  │          │
//   load ─────────►├──► DMux8Way─┘                  │          │
//                  │        ▲                       │          │
//   address[3] ───►├────────┴───────────────────────┘          │
//                  └───────────────────────────────────────────┘
//
// Step 1: DMux8Way takes load and address
//   - Routes load=1 to exactly one register based on address
//   - Other 7 registers receive load=0 (hold their values)
//
// Step 2: All 8 registers receive the same 'in' value
//   - Only the one with load=1 will actually store it
//
// Step 3: Mux8Way16 selects output based on address
//   - Picks the output from the addressed register
//
// -----------------------------------------------------------------------------
// Building Larger RAMs (Recursive Structure)
// -----------------------------------------------------------------------------
//
// RAM64 = 8 × RAM8
//
//   address[6] = [aaa][bbb]
//                 ↓    ↓
//              high  low
//              (which RAM8)  (which register in that RAM8)
//
//   - Use high 3 bits to select which RAM8 unit
//   - Pass low 3 bits to that RAM8 as its internal address
//
//                  ┌─────────────────────────────────────────┐
//                  │               RAM64                      │
//                  │                                          │
//   in[16] ───────►├─────────► RAM8_0 ─────┐                  │
//                  ├─────────► RAM8_1 ─────┤                  │
//                  ├─────────► RAM8_2 ─────┤                  │
//                  ├─────────► RAM8_3 ─────┼────► Mux8Way16 ──┼──► out
//                  ├─────────► RAM8_4 ─────┤                  │
//                  ├─────────► RAM8_5 ─────┤                  │
//                  ├─────────► RAM8_6 ─────┤                  │
//                  ├─────────► RAM8_7 ─────┘                  │
//                  │             ▲                  ▲          │
//   load ─────────►├──► DMux8Way─┘                  │          │
//                  │        ▲                       │          │
//   address[6] ───►├────────┴───────────────────────┘          │
//                  │   high 3 bits      all 6 bits             │
//                  │                                           │
//                  │   low 3 bits → each RAM8's address        │
//                  └───────────────────────────────────────────┘
//
// This pattern repeats:
//   RAM512  = 8 × RAM64
//   RAM4K   = 8 × RAM512
//   RAM16K  = 4 × RAM4K  (only 4 because 14 bits, not 15)
//
// -----------------------------------------------------------------------------
// Address Bit Calculation
// -----------------------------------------------------------------------------
//
// For N registers, we need log₂(N) address bits:
//
//   RAM8:    8 = 2³   →  3 address bits
//   RAM64:  64 = 2⁶   →  6 address bits
//   RAM512: 512 = 2⁹  →  9 address bits
//   RAM4K:  4096 = 2¹² → 12 address bits
//   RAM16K: 16384 = 2¹⁴ → 14 address bits
//
// -----------------------------------------------------------------------------
// Why "Random Access"?
// -----------------------------------------------------------------------------
//
// Historical contrast with sequential access (like tape drives):
// - Tape: to read position 1000, must wind through positions 0-999
// - RAM: to read position 1000, just provide address 1000 directly
//
// Access time is CONSTANT regardless of which address we access.
// This is O(1) access - critical for efficient computing.
//
// The MUX/DEMUX structure provides this: address bits flow through
// gates in parallel, not sequentially through memory cells.
//

const std = @import("std");
const testing = std.testing;

const register = @import("register.zig");
const logic = @import("gates").Logic;

const types = @import("types");
const b16 = types.b16;
const b3 = types.b3;
const b6 = types.b6;
const b9 = types.b9;
const b12 = types.b12;
const b14 = types.b14;
const fb3 = types.fb3;
const fb8 = types.fb8;
const fb16 = types.fb16;
const toBits = types.toBits;

// =============================================================================
// RAM8 - 8 Registers (3-bit address)
// =============================================================================

/// RAM8 - 8 16-bit registers addressable by 3-bit address.
///
/// Built from 8 Register16 chips:
/// - DMUX8WAY routes load signal to the correct register
/// - MUX8WAY16 selects output from the correct register
///
/// Behavior:
///   - Always reads from Register[address]
///   - Writes to Register[address] when load=1
pub const RAM8 = struct {
    registers: [8]register.Register16 = [_]register.Register16{.{}} ** 8,

    const Self = @This();

    /// Update RAM8 with new input, address, and load signal.
    /// Returns the current output from the addressed register.
    ///
    /// This function represents one clock cycle:
    /// - Always reads from Register[address]
    /// - If load=1: writes input to Register[address]
    pub fn tick(self: *Self, input: [16]u1, address: [3]u1, load: u1) [16]u1 {
        // Step 1: DMUX8WAY routes load signal to the correct register
        const load_signals = logic.DMUX8WAY(load, address);

        // Step 2: All registers receive the same input, but only one gets load=1
        var outputs: [8][16]u1 = undefined;
        inline for (0..8) |i| {
            outputs[i] = self.registers[i].tick(input, load_signals[i]);
        }

        // Step 3: MUX8WAY16 selects output from the addressed register
        const output = logic.MUX8WAY16(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            address,
        );

        // std.debug.print("{s}: {any}, input: {any}, output: {any}, load_signals: {any}\n", .{
        //     if (load == 1) "Load" else "Read",
        //     fb3(address),
        //     fb16(input),
        //     fb16(output),
        //     load_signals,
        // });

        return output;
    }

    /// Get the current output from the addressed register without advancing time.
    pub fn peek(self: *const Self, address: [3]u1) [16]u1 {
        return logic.MUX8WAY16(
            self.registers[0].peek(),
            self.registers[1].peek(),
            self.registers[2].peek(),
            self.registers[3].peek(),
            self.registers[4].peek(),
            self.registers[5].peek(),
            self.registers[6].peek(),
            self.registers[7].peek(),
            address,
        );
    }

    /// Reset all registers to initial state (all bits set to 0).
    pub fn reset(self: *Self) void {
        inline for (0..8) |i| {
            self.registers[i].reset();
        }
    }

    pub fn randomize(self: *Self) void {
        inline for (0..8) |i| {
            _ = self.registers[i].tick(toBits(16, i), 1);
        }
    }

    pub fn print(self: *const Self) void {
        std.debug.print("RAM8 State:\n", .{});
        std.debug.print("┌─────────┬─────────┐\n", .{});
        std.debug.print("│ Address │  Value  │\n", .{});
        std.debug.print("├─────────┼─────────┤\n", .{});

        inline for (0..8) |i| {
            const j = 7 - i;
            const value = self.registers[j].peek();
            std.debug.print("│  {d:3}    │  {d:3}    │\n", .{ i, fb16(value) });
        }

        std.debug.print("└─────────┴─────────┘\n", .{});
    }
};

// =============================================================================
// RAM8_I - 8 Registers (Integer Version)
// =============================================================================

/// RAM8_I - 8 16-bit registers addressable by 3-bit address (integer version).
///
/// Integer version using u16 for values and u3 for addresses.
/// More efficient than bit-array version for performance-critical code.
pub const RAM8_I = struct {
    registers: [8]register.Register16_I = [_]register.Register16_I{.{}} ** 8,

    const Self = @This();

    /// Update RAM8_I with new input, address, and load signal.
    /// Returns the current output from the addressed register.
    ///
    /// This function represents one clock cycle:
    /// - Always reads from Register[address]
    /// - If load=1: writes input to Register[address]
    pub fn tick(self: *Self, input: u16, address: u3, load: u1) u16 {
        // Step 1: DMUX8WAY_I routes load signal to the correct register
        // Returns u8 with bit set at position 'address'
        const load_signals = logic.DMUX8WAY_I(load, address);

        // Step 2: All registers receive the same input, but only one gets load=1
        var outputs: [8]u16 = undefined;
        inline for (0..8) |i| {
            const j = 7 - i;
            // Check if the load signal bit is set for this register
            const load_signal: u1 = @truncate((load_signals >> j) & 1);
            // Always tick the register to get its output (it will only load if load_signal == 1)
            outputs[i] = self.registers[i].tick(input, load_signal);
        }

        // Step 3: MUX8WAY16_I selects output from the addressed register
        // MUX8WAY16_I expects in7, in6, ..., in0 where in0 is for address 0
        // So outputs[0] (address 0) maps to in0 (last param), outputs[7] (address 7) maps to in7 (first param)
        const output = logic.MUX8WAY16_I(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            address,
        );

        return output;
    }

    /// Get the current output from the addressed register without advancing time.
    pub fn peek(self: *const Self, address: u3) u16 {
        return logic.MUX8WAY16_I(
            self.registers[0].peek(),
            self.registers[1].peek(),
            self.registers[2].peek(),
            self.registers[3].peek(),
            self.registers[4].peek(),
            self.registers[5].peek(),
            self.registers[6].peek(),
            self.registers[7].peek(),
            address,
        );
    }

    /// Reset all registers to initial state (all values set to 0).
    pub fn reset(self: *Self) void {
        inline for (0..8) |i| {
            self.registers[i].reset();
        }
    }

    pub fn print(self: *const Self) void {
        std.debug.print("RAM8_I State:\n", .{});
        std.debug.print("┌─────────┬─────────┐\n", .{});
        std.debug.print("│ Address │  Value  │\n", .{});
        std.debug.print("├─────────┼─────────┤\n", .{});

        inline for (0..8) |i| {
            const j = 7 - i;
            const value = self.registers[j].peek();
            std.debug.print("│  {d:3}    │  {d:5}  │\n", .{ i, value });
        }

        std.debug.print("└─────────┴─────────┘\n", .{});
    }
};

// =============================================================================
// RAM64 - 64 Registers (6-bit address)
// =============================================================================

/// RAM64 - 64 16-bit registers addressable by 6-bit address.
///
/// Built from 8 RAM8 chips:
/// - High 3 bits select which RAM8 unit
/// - Low 3 bits address within that RAM8
///
/// Behavior:
///   - Always reads from RAM8[high_bits][low_bits]
///   - Writes to RAM8[high_bits][low_bits] when load=1
pub const RAM64 = struct {
    ram8s: [8]RAM8 = [_]RAM8{.{}} ** 8,

    const Self = @This();

    /// Update RAM64 with new input, address, and load signal.
    /// Returns the current output from the addressed register.
    pub fn tick(self: *Self, input: [16]u1, address: [6]u1, load: u1) [16]u1 {
        // Split address: high 3 bits select RAM8, low 3 bits address within RAM8
        // Reverse high bits because MUX/DMUX expect LSB-first selector
        const high_bits_raw: [3]u1 = address[0..3].*;
        const high_bits: [3]u1 = [3]u1{ high_bits_raw[2], high_bits_raw[1], high_bits_raw[0] };
        const low_bits: [3]u1 = address[3..6].*;

        // Step 1: DMUX8WAY routes load signal to the correct RAM8
        const load_signals = logic.DMUX8WAY(load, high_bits);

        // Step 2: All RAM8s receive the same input and low address, but only one gets load=1
        var outputs: [8][16]u1 = undefined;
        inline for (0..8) |i| {
            outputs[i] = self.ram8s[i].tick(input, low_bits, load_signals[i]);
        }

        // Step 3: MUX8WAY16 selects output from the addressed RAM8
        return logic.MUX8WAY16(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            high_bits,
        );
    }

    /// Get the current output from the addressed register without advancing time.
    pub fn peek(self: *const Self, address: [6]u1) [16]u1 {
        // Reverse high bits because MUX expects LSB-first selector
        const high_bits_raw: [3]u1 = address[0..3].*;
        const high_bits: [3]u1 = [3]u1{ high_bits_raw[2], high_bits_raw[1], high_bits_raw[0] };
        const low_bits: [3]u1 = address[3..6].*;

        var outputs: [8][16]u1 = undefined;
        inline for (0..8) |i| {
            outputs[i] = self.ram8s[i].peek(low_bits);
        }
        return logic.MUX8WAY16(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            high_bits,
        );
    }

    /// Reset all RAM8s to initial state.
    pub fn reset(self: *Self) void {
        inline for (0..8) |i| {
            self.ram8s[i].reset();
        }
    }
};

// =============================================================================
// RAM64_I - 64 Registers (Integer Version)
// =============================================================================

/// RAM64_I - 64 16-bit registers addressable by 6-bit address (integer version).
///
/// Integer version using u16 for values and u6 for addresses.
/// Built from 8 RAM8_I chips:
/// - High 3 bits select which RAM8_I unit
/// - Low 3 bits address within that RAM8_I
pub const RAM64_I = struct {
    ram8s: [8]RAM8_I = [_]RAM8_I{.{}} ** 8,

    const Self = @This();

    /// Update RAM64_I with new input, address, and load signal.
    /// Returns the current output from the addressed register.
    pub fn tick(self: *Self, input: u16, address: u6, load: u1) u16 {
        // Split address: high 3 bits select RAM8_I, low 3 bits address within RAM8_I
        const high_bits: u3 = @truncate(address >> 3);
        const low_bits: u3 = @truncate(address);

        // Step 1: DMUX8WAY_I routes load signal to the correct RAM8_I
        const load_signals = logic.DMUX8WAY_I(load, high_bits);

        // Step 2: All RAM8_Is receive the same input and low address, but only one gets load=1
        var outputs: [8]u16 = undefined;
        inline for (0..8) |i| {
            const j = 7 - i;
            // Check if the load signal bit is set for this RAM8_I
            const load_signal: u1 = @truncate((load_signals >> j) & 1);
            // Always tick the RAM8_I to get its output (it will only load if load_signal == 1)
            outputs[i] = self.ram8s[i].tick(input, low_bits, load_signal);
        }

        // Step 3: MUX8WAY16_I selects output from the addressed RAM8_I
        const output = logic.MUX8WAY16_I(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            high_bits,
        );

        return output;
    }

    /// Get the current output from the addressed register without advancing time.
    pub fn peek(self: *const Self, address: u6) u16 {
        const high_bits: u3 = @truncate(address >> 3);
        const low_bits: u3 = @truncate(address);

        var outputs: [8]u16 = undefined;
        inline for (0..8) |i| {
            outputs[i] = self.ram8s[i].peek(low_bits);
        }
        return logic.MUX8WAY16_I(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            high_bits,
        );
    }

    /// Reset all RAM8_Is to initial state.
    pub fn reset(self: *Self) void {
        inline for (0..8) |i| {
            self.ram8s[i].reset();
        }
    }
};

// =============================================================================
// RAM512 - 512 Registers (9-bit address)
// =============================================================================

/// RAM512 - 512 16-bit registers addressable by 9-bit address.
///
/// Built from 8 RAM64 chips:
/// - High 3 bits select which RAM64 unit
/// - Low 6 bits address within that RAM64
pub const RAM512 = struct {
    ram64s: [8]RAM64 = [_]RAM64{.{}} ** 8,

    const Self = @This();

    /// Update RAM512 with new input, address, and load signal.
    pub fn tick(self: *Self, input: [16]u1, address: [9]u1, load: u1) [16]u1 {
        // Reverse high bits because MUX/DMUX expect LSB-first selector
        const high_bits_raw: [3]u1 = address[0..3].*;
        const high_bits: [3]u1 = [3]u1{ high_bits_raw[2], high_bits_raw[1], high_bits_raw[0] };
        const low_bits: [6]u1 = address[3..9].*;

        const load_signals = logic.DMUX8WAY(load, high_bits);

        var outputs: [8][16]u1 = undefined;
        inline for (0..8) |i| {
            outputs[i] = self.ram64s[i].tick(input, low_bits, load_signals[i]);
        }

        return logic.MUX8WAY16(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            high_bits,
        );
    }

    /// Get the current output from the addressed register without advancing time.
    pub fn peek(self: *const Self, address: [9]u1) [16]u1 {
        // Reverse high bits because MUX expects LSB-first selector
        const high_bits_raw: [3]u1 = address[0..3].*;
        const high_bits: [3]u1 = [3]u1{ high_bits_raw[2], high_bits_raw[1], high_bits_raw[0] };
        const low_bits: [6]u1 = address[3..9].*;

        var outputs: [8][16]u1 = undefined;
        inline for (0..8) |i| {
            outputs[i] = self.ram64s[i].peek(low_bits);
        }
        return logic.MUX8WAY16(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            high_bits,
        );
    }

    /// Reset all RAM64s to initial state.
    pub fn reset(self: *Self) void {
        inline for (0..8) |i| {
            self.ram64s[i].reset();
        }
    }
};

// =============================================================================
// RAM512_I - 512 Registers (Integer Version)
// =============================================================================

/// RAM512_I - 512 16-bit registers addressable by 9-bit address (integer version).
///
/// Integer version using u16 for values and u9 for addresses.
/// Built from 8 RAM64_I chips:
/// - High 3 bits select which RAM64_I unit
/// - Low 6 bits address within that RAM64_I
pub const RAM512_I = struct {
    ram64s: [8]RAM64_I = [_]RAM64_I{.{}} ** 8,

    const Self = @This();

    /// Update RAM512_I with new input, address, and load signal.
    /// Returns the current output from the addressed register.
    pub fn tick(self: *Self, input: u16, address: u9, load: u1) u16 {
        // Split address: high 3 bits select RAM64_I, low 6 bits address within that RAM64_I
        const high_bits: u3 = @truncate(address >> 6);
        const low_bits: u6 = @truncate(address);

        // Step 1: DMUX8WAY_I routes load signal to the correct RAM64_I
        const load_signals = logic.DMUX8WAY_I(load, high_bits);

        // Step 2: All RAM64_Is receive the same input and low address, but only one gets load=1
        var outputs: [8]u16 = undefined;
        inline for (0..8) |i| {
            const j = 7 - i;
            // Check if the load signal bit is set for this RAM64_I
            const load_signal: u1 = @truncate((load_signals >> j) & 1);
            // Always tick the RAM64_I to get its output (it will only load if load_signal == 1)
            outputs[i] = self.ram64s[i].tick(input, low_bits, load_signal);
        }

        // Step 3: MUX8WAY16_I selects output from the addressed RAM64_I
        const output = logic.MUX8WAY16_I(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            high_bits,
        );

        return output;
    }

    /// Get the current output from the addressed register without advancing time.
    pub fn peek(self: *const Self, address: u9) u16 {
        const high_bits: u3 = @truncate(address >> 6);
        const low_bits: u6 = @truncate(address);

        var outputs: [8]u16 = undefined;
        inline for (0..8) |i| {
            outputs[i] = self.ram64s[i].peek(low_bits);
        }
        return logic.MUX8WAY16_I(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            high_bits,
        );
    }

    /// Reset all RAM64_Is to initial state.
    pub fn reset(self: *Self) void {
        inline for (0..8) |i| {
            self.ram64s[i].reset();
        }
    }
};

// =============================================================================
// RAM4K - 4096 Registers (12-bit address)
// =============================================================================

/// RAM4K - 4096 16-bit registers addressable by 12-bit address.
///
/// Built from 8 RAM512 chips:
/// - High 3 bits select which RAM512 unit
/// - Low 9 bits address within that RAM512
pub const RAM4K = struct {
    ram512s: [8]RAM512 = [_]RAM512{.{}} ** 8,

    const Self = @This();

    /// Update RAM4K with new input, address, and load signal.
    pub fn tick(self: *Self, input: [16]u1, address: [12]u1, load: u1) [16]u1 {
        // Reverse high bits because MUX/DMUX expect LSB-first selector
        const high_bits_raw: [3]u1 = address[0..3].*;
        const high_bits: [3]u1 = [3]u1{ high_bits_raw[2], high_bits_raw[1], high_bits_raw[0] };
        const low_bits: [9]u1 = address[3..12].*;

        const load_signals = logic.DMUX8WAY(load, high_bits);

        var outputs: [8][16]u1 = undefined;
        inline for (0..8) |i| {
            outputs[i] = self.ram512s[i].tick(input, low_bits, load_signals[i]);
        }

        return logic.MUX8WAY16(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            high_bits,
        );
    }

    /// Get the current output from the addressed register without advancing time.
    pub fn peek(self: *const Self, address: [12]u1) [16]u1 {
        // Reverse high bits because MUX expects LSB-first selector
        const high_bits_raw: [3]u1 = address[0..3].*;
        const high_bits: [3]u1 = [3]u1{ high_bits_raw[2], high_bits_raw[1], high_bits_raw[0] };
        const low_bits: [9]u1 = address[3..12].*;

        var outputs: [8][16]u1 = undefined;
        inline for (0..8) |i| {
            outputs[i] = self.ram512s[i].peek(low_bits);
        }
        return logic.MUX8WAY16(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            high_bits,
        );
    }

    /// Reset all RAM512s to initial state.
    pub fn reset(self: *Self) void {
        inline for (0..8) |i| {
            self.ram512s[i].reset();
        }
    }
};

// =============================================================================
// RAM4K_I - 4096 Registers (Integer Version)
// =============================================================================

/// RAM4K_I - 4096 16-bit registers addressable by 12-bit address (integer version).
///
/// Integer version using u16 for values and u12 for addresses.
/// Built from 8 RAM512_I chips:
/// - High 3 bits select which RAM512_I unit
/// - Low 9 bits address within that RAM512_I
pub const RAM4K_I = struct {
    ram512s: [8]RAM512_I = [_]RAM512_I{.{}} ** 8,

    const Self = @This();

    /// Update RAM4K_I with new input, address, and load signal.
    /// Returns the current output from the addressed register.
    pub fn tick(self: *Self, input: u16, address: u12, load: u1) u16 {
        // Split address: high 3 bits select RAM512_I, low 9 bits address within that RAM512_I
        const high_bits: u3 = @truncate(address >> 9);
        const low_bits: u9 = @truncate(address);

        // Step 1: DMUX8WAY_I routes load signal to the correct RAM512_I
        const load_signals = logic.DMUX8WAY_I(load, high_bits);

        // Step 2: All RAM512_Is receive the same input and low address, but only one gets load=1
        var outputs: [8]u16 = undefined;
        inline for (0..8) |i| {
            const j = 7 - i;
            // Check if the load signal bit is set for this RAM512_I
            const load_signal: u1 = @truncate((load_signals >> j) & 1);
            // Always tick the RAM512_I to get its output (it will only load if load_signal == 1)
            outputs[i] = self.ram512s[i].tick(input, low_bits, load_signal);
        }

        // Step 3: MUX8WAY16_I selects output from the addressed RAM512_I
        const output = logic.MUX8WAY16_I(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            high_bits,
        );

        return output;
    }

    /// Get the current output from the addressed register without advancing time.
    pub fn peek(self: *const Self, address: u12) u16 {
        const high_bits: u3 = @truncate(address >> 9);
        const low_bits: u9 = @truncate(address);

        var outputs: [8]u16 = undefined;
        inline for (0..8) |i| {
            outputs[i] = self.ram512s[i].peek(low_bits);
        }
        return logic.MUX8WAY16_I(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            outputs[4],
            outputs[5],
            outputs[6],
            outputs[7],
            high_bits,
        );
    }

    /// Reset all RAM512_Is to initial state.
    pub fn reset(self: *Self) void {
        inline for (0..8) |i| {
            self.ram512s[i].reset();
        }
    }
};

// =============================================================================
// RAM16K - 16384 Registers (14-bit address)
// =============================================================================

/// RAM16K - 16384 16-bit registers addressable by 14-bit address.
///
/// Built from 4 RAM4K chips (not 8, because 14 bits = 2^14 = 16384):
/// - High 2 bits select which RAM4K unit
/// - Low 12 bits address within that RAM4K
pub const RAM16K = struct {
    ram4ks: [4]RAM4K = [_]RAM4K{.{}} ** 4,

    const Self = @This();

    /// Update RAM16K with new input, address, and load signal.
    pub fn tick(self: *Self, input: [16]u1, address: [14]u1, load: u1) [16]u1 {
        // Reverse high bits because MUX/DMUX expect LSB-first selector
        const high_bits_raw: [2]u1 = address[0..2].*;
        const high_bits: [2]u1 = [2]u1{ high_bits_raw[1], high_bits_raw[0] };
        const low_bits: [12]u1 = address[2..14].*;

        // Use DMUX4WAY for 4-way selection
        const load_signals = logic.DMUX4WAY(load, high_bits);

        var outputs: [4][16]u1 = undefined;
        inline for (0..4) |i| {
            outputs[i] = self.ram4ks[i].tick(input, low_bits, load_signals[i]);
        }

        // Use MUX4WAY16 for 4-way output selection
        return logic.MUX4WAY16(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            high_bits,
        );
    }

    /// Get the current output from the addressed register without advancing time.
    pub fn peek(self: *const Self, address: [14]u1) [16]u1 {
        // Reverse high bits because MUX expects LSB-first selector
        const high_bits_raw: [2]u1 = address[0..2].*;
        const high_bits: [2]u1 = [2]u1{ high_bits_raw[1], high_bits_raw[0] };
        const low_bits: [12]u1 = address[2..14].*;

        var outputs: [4][16]u1 = undefined;
        inline for (0..4) |i| {
            outputs[i] = self.ram4ks[i].peek(low_bits);
        }
        return logic.MUX4WAY16(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            high_bits,
        );
    }

    /// Reset all RAM4Ks to initial state.
    pub fn reset(self: *Self) void {
        inline for (0..4) |i| {
            self.ram4ks[i].reset();
        }
    }
};

// =============================================================================
// RAM16K_I - 16384 Registers (Integer Version)
// =============================================================================

/// RAM16K_I - 16384 16-bit registers addressable by 14-bit address (integer version).
///
/// Integer version using u16 for values and u16 for addresses (14 bits used).
/// Built from 4 RAM4K_I chips (not 8, because 14 bits = 2^14 = 16384):
/// - High 2 bits select which RAM4K_I unit
/// - Low 12 bits address within that RAM4K_I
pub const RAM16K_I = struct {
    ram4ks: [4]RAM4K_I = [_]RAM4K_I{.{}} ** 4,

    const Self = @This();

    /// Update RAM16K_I with new input, address, and load signal.
    /// Returns the current output from the addressed register.
    pub fn tick(self: *Self, input: u16, address: u16, load: u1) u16 {
        // Split address: high 2 bits select RAM4K_I, low 12 bits address within that RAM4K_I
        // Address is 14 bits, stored in u16: bits 12-13 are high, bits 0-11 are low
        const high_bits: u2 = @truncate(address >> 12);
        const low_bits: u12 = @truncate(address);

        // Step 1: DMUX4WAY_I routes load signal to the correct RAM4K_I
        const load_signals = logic.DMUX4WAY_I(load, high_bits);

        // Step 2: All RAM4K_Is receive the same input and low address, but only one gets load=1
        var outputs: [4]u16 = undefined;
        inline for (0..4) |i| {
            const j = 3 - i;
            // Check if the load signal bit is set for this RAM4K_I
            const load_signal: u1 = @truncate((load_signals >> j) & 1);
            // Always tick the RAM4K_I to get its output (it will only load if load_signal == 1)
            outputs[i] = self.ram4ks[i].tick(input, low_bits, load_signal);
        }

        // Step 3: MUX4WAY16_I selects output from the addressed RAM4K_I
        const output = logic.MUX4WAY16_I(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            high_bits,
        );

        return output;
    }

    /// Get the current output from the addressed register without advancing time.
    pub fn peek(self: *const Self, address: u16) u16 {
        const high_bits: u2 = @truncate(address >> 12);
        const low_bits: u12 = @truncate(address);

        var outputs: [4]u16 = undefined;
        inline for (0..4) |i| {
            outputs[i] = self.ram4ks[i].peek(low_bits);
        }
        return logic.MUX4WAY16_I(
            outputs[0],
            outputs[1],
            outputs[2],
            outputs[3],
            high_bits,
        );
    }

    /// Reset all RAM4K_Is to initial state.
    pub fn reset(self: *Self) void {
        inline for (0..4) |i| {
            self.ram4ks[i].reset();
        }
    }
};

// =============================================================================
// Tests
// =============================================================================

/// Helper function to verify and print test results
fn verifyAndPrint(time: u32, input: i32, load: u1, address: anytype, expected: i16, output: i16, output_i: i16, peek: i16) !void {
    try testing.expectEqual(expected, output);
    try testing.expectEqual(expected, output_i);

    std.debug.print("| {d:3}  | {d:6} |  {d:2}  |   {d:5}   | {d:7}  | {d:6}  | {d:6}  | {d:6}  |\n", .{
        time,
        input,
        load,
        address,
        expected,
        output,
        output_i,
        peek,
    });
}

test "RAM8: comprehensive test" {
    const testCases = [_]struct { input: i32, load: u1, address: u8, expected: i16, print_ram: bool = false }{
        .{ .input = 0, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 1, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 1, .address = 0, .expected = 0 },
        .{ .input = 11111, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 11111, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 11111, .load = 1, .address = 1, .expected = 0 },
        .{ .input = 11111, .load = 1, .address = 1, .expected = 11111, .print_ram = false },
        .{ .input = 11111, .load = 0, .address = 0, .expected = 0, .print_ram = false },
        .{ .input = 11111, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 3333, .load = 0, .address = 3, .expected = 0 },
        .{ .input = 3333, .load = 0, .address = 3, .expected = 0 },
        .{ .input = 3333, .load = 1, .address = 3, .expected = 0 },
        .{ .input = 3333, .load = 1, .address = 3, .expected = 3333 },
        .{ .input = 3333, .load = 0, .address = 3, .expected = 3333 },
        .{ .input = 3333, .load = 0, .address = 3, .expected = 3333 },
        .{ .input = 3333, .load = 0, .address = 1, .expected = 11111 },
        .{ .input = 7777, .load = 0, .address = 1, .expected = 11111 },
        .{ .input = 7777, .load = 0, .address = 1, .expected = 11111 },
        .{ .input = 7777, .load = 1, .address = 7, .expected = 0 },
        .{ .input = 7777, .load = 1, .address = 7, .expected = 7777 },
        .{ .input = 7777, .load = 0, .address = 7, .expected = 7777 },
        .{ .input = 7777, .load = 0, .address = 7, .expected = 7777 },
        .{ .input = 7777, .load = 0, .address = 3, .expected = 3333 },
        .{ .input = 7777, .load = 0, .address = 7, .expected = 7777 },
        .{ .input = 7777, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 7777, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 7777, .load = 0, .address = 1, .expected = 11111 },
        .{ .input = 7777, .load = 0, .address = 2, .expected = 0 },
        .{ .input = 7777, .load = 0, .address = 3, .expected = 3333 },
        .{ .input = 7777, .load = 0, .address = 4, .expected = 0 },
        .{ .input = 7777, .load = 0, .address = 5, .expected = 0 },
        .{ .input = 7777, .load = 0, .address = 6, .expected = 0 },
        .{ .input = 7777, .load = 0, .address = 7, .expected = 7777 },
        .{ .input = 21845, .load = 1, .address = 0, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 0, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 1, .expected = 11111 },
        .{ .input = 21845, .load = 1, .address = 1, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 2, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 3, .expected = 3333 },
        .{ .input = 21845, .load = 1, .address = 3, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 4, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 4, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 5, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 5, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 6, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 6, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 7, .expected = 7777 },
        .{ .input = 21845, .load = 1, .address = 7, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 1, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 3, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 4, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 6, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 7, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 0, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 1, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 4, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 6, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 0, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 1, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 1, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 4, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 6, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 1, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 1, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 3, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 4, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 6, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 2, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 3, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 3, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 4, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 6, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 3, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 3, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 4, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 4, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 4, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 6, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 4, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 4, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 5, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 4, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 6, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 5, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 6, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 6, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 4, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 6, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 7, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 6, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 6, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 7, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 7, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 4, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 6, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 7, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 7, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 0, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 1, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 3, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 4, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 6, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 7, .expected = 21845 },
    };

    var ram = RAM8{};
    var ram_i = RAM8_I{};
    var time: u32 = 0;

    std.debug.print("\n| time |   in   | load |  address  | expected |    out  |  out_i  |   peek  |\n", .{});

    for (testCases) |tc| {

        // Convert i32 to u16 (treating as 16-bit signed/unsigned)
        const input_u16: u16 = @bitCast(@as(i16, @intCast(tc.input)));

        const output = @as(i16, @bitCast(fb16(ram.tick(b16(input_u16), b3(tc.address), tc.load))));

        const output_i = @as(i16, @bitCast(ram_i.tick(input_u16, @as(u3, @intCast(tc.address)), tc.load)));

        const peek = @as(i16, @bitCast(fb16(ram.peek(b3(tc.address)))));

        try verifyAndPrint(time, tc.input, tc.load, tc.address, tc.expected, output, output_i, peek);
        if (tc.print_ram) {
            ram.print();
        }
        time += 1;
    }
}

test "RAM64: comprehensive test" {
    const testCases = [_]struct { input: i32, load: u1, address: u8, expected: i16, print_ram: bool = false }{
        .{ .input = 0, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 1, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 1, .address = 0, .expected = 0 },
        .{ .input = 1313, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 1313, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 1313, .load = 1, .address = 13, .expected = 0 },
        .{ .input = 1313, .load = 1, .address = 13, .expected = 1313 },
        .{ .input = 1313, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 1313, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 4747, .load = 0, .address = 47, .expected = 0 },
        .{ .input = 4747, .load = 0, .address = 47, .expected = 0 },
        .{ .input = 4747, .load = 1, .address = 47, .expected = 0 },
        .{ .input = 4747, .load = 1, .address = 47, .expected = 4747 },
        .{ .input = 4747, .load = 0, .address = 47, .expected = 4747 },
        .{ .input = 4747, .load = 0, .address = 47, .expected = 4747 },
        .{ .input = 4747, .load = 0, .address = 13, .expected = 1313 },
        .{ .input = 6363, .load = 0, .address = 13, .expected = 1313 },
        .{ .input = 6363, .load = 0, .address = 13, .expected = 1313 },
        .{ .input = 6363, .load = 1, .address = 63, .expected = 0 },
        .{ .input = 6363, .load = 1, .address = 63, .expected = 6363 },
        .{ .input = 6363, .load = 0, .address = 63, .expected = 6363 },
        .{ .input = 6363, .load = 0, .address = 63, .expected = 6363 },
        .{ .input = 6363, .load = 0, .address = 47, .expected = 4747 },
        .{ .input = 6363, .load = 0, .address = 63, .expected = 6363 },
        .{ .input = 6363, .load = 0, .address = 40, .expected = 0 },
        .{ .input = 6363, .load = 0, .address = 40, .expected = 0 },
        .{ .input = 6363, .load = 0, .address = 41, .expected = 0 },
        .{ .input = 6363, .load = 0, .address = 42, .expected = 0 },
        .{ .input = 6363, .load = 0, .address = 43, .expected = 0 },
        .{ .input = 6363, .load = 0, .address = 44, .expected = 0 },
        .{ .input = 6363, .load = 0, .address = 45, .expected = 0 },
        .{ .input = 6363, .load = 0, .address = 46, .expected = 0 },
        .{ .input = 6363, .load = 0, .address = 47, .expected = 4747 },
        .{ .input = 21845, .load = 1, .address = 40, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 40, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 41, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 41, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 42, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 42, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 43, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 43, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 44, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 44, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 45, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 45, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 46, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 46, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 47, .expected = 4747 },
        .{ .input = 21845, .load = 1, .address = 47, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 41, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 43, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 44, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 46, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 47, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 40, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 41, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 43, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 44, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 46, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 47, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 40, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 41, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 41, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 41, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 43, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 44, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 46, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 47, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 41, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 41, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 42, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 41, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 43, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 44, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 46, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 47, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 42, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 43, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 43, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 41, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 43, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 44, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 46, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 47, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 43, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 43, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 44, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 44, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 41, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 43, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 44, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 46, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 47, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 44, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 44, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 45, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 41, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 43, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 44, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 46, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 47, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 45, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 46, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 46, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 41, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 43, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 44, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 46, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 47, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 46, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 46, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 47, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 47, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 41, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 43, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 44, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 46, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 47, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 47, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 47, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 40, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 41, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 43, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 44, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 46, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 47, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 5, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 5, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 13, .expected = 1313 },
        .{ .input = 21845, .load = 0, .address = 21, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 29, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 37, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 53, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 61, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 5, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 5, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 13, .expected = 1313 },
        .{ .input = 21845, .load = 1, .address = 13, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 21, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 21, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 29, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 29, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 37, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 37, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 45, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 45, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 53, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 53, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 61, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 61, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 13, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 21, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 29, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 37, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 53, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 61, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 5, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 13, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 21, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 29, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 37, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 53, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 61, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 5, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 13, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 13, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 21, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 29, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 37, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 53, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 61, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 13, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 13, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 21, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 21, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 21, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 29, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 37, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 53, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 61, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 21, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 21, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 29, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 29, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 21, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 29, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 37, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 53, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 61, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 29, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 29, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 37, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 37, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 21, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 29, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 37, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 53, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 61, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 37, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 37, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 45, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 21, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 29, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 37, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 53, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 61, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 45, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 53, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 53, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 21, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 29, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 37, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 53, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 61, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 53, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 53, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 61, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 61, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 21, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 29, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 37, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 53, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 61, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 61, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 61, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 5, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 13, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 21, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 29, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 37, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 45, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 53, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 61, .expected = 21845 },
    };

    var ram = RAM64{};
    var ram_i = RAM64_I{};
    var time: u32 = 0;

    std.debug.print("\n| time |   in   | load |  address  | expected |    out  |  out_i  |   peek  |\n", .{});

    for (testCases) |tc| {
        // Convert i32 to u16 (treating as 16-bit signed/unsigned)
        const input_u16: u16 = @bitCast(@as(i16, @intCast(tc.input)));

        const output = @as(i16, @bitCast(fb16(ram.tick(b16(input_u16), b6(tc.address), tc.load))));

        const output_i = @as(i16, @bitCast(ram_i.tick(input_u16, @as(u6, @intCast(tc.address)), tc.load)));

        const peek = @as(i16, @bitCast(fb16(ram.peek(b6(tc.address)))));

        try verifyAndPrint(time, tc.input, tc.load, tc.address, tc.expected, output, output_i, peek);
        if (tc.print_ram) {
            // self.ram.print();
        }
        time += 1;
    }
}

test "RAM512: comprehensive test" {
    const testCases = [_]struct { input: i32, load: u1, address: u16, expected: i16, print_ram: bool = false }{
        .{ .input = 0, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 1, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 1, .address = 0, .expected = 0 },
        .{ .input = 13099, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 13099, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 13099, .load = 1, .address = 130, .expected = 0 },
        .{ .input = 13099, .load = 1, .address = 130, .expected = 13099 },
        .{ .input = 13099, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 13099, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 4729, .load = 0, .address = 472, .expected = 0 },
        .{ .input = 4729, .load = 0, .address = 472, .expected = 0 },
        .{ .input = 4729, .load = 1, .address = 472, .expected = 0 },
        .{ .input = 4729, .load = 1, .address = 472, .expected = 4729 },
        .{ .input = 4729, .load = 0, .address = 472, .expected = 4729 },
        .{ .input = 4729, .load = 0, .address = 472, .expected = 4729 },
        .{ .input = 4729, .load = 0, .address = 130, .expected = 13099 },
        .{ .input = 5119, .load = 0, .address = 130, .expected = 13099 },
        .{ .input = 5119, .load = 0, .address = 130, .expected = 13099 },
        .{ .input = 5119, .load = 1, .address = 511, .expected = 0 },
        .{ .input = 5119, .load = 1, .address = 511, .expected = 5119 },
        .{ .input = 5119, .load = 0, .address = 511, .expected = 5119 },
        .{ .input = 5119, .load = 0, .address = 511, .expected = 5119 },
        .{ .input = 5119, .load = 0, .address = 472, .expected = 4729 },
        .{ .input = 5119, .load = 0, .address = 511, .expected = 5119 },
        .{ .input = 5119, .load = 0, .address = 168, .expected = 0 },
        .{ .input = 5119, .load = 0, .address = 168, .expected = 0 },
        .{ .input = 5119, .load = 0, .address = 169, .expected = 0 },
        .{ .input = 5119, .load = 0, .address = 170, .expected = 0 },
        .{ .input = 5119, .load = 0, .address = 171, .expected = 0 },
        .{ .input = 5119, .load = 0, .address = 172, .expected = 0 },
        .{ .input = 5119, .load = 0, .address = 173, .expected = 0 },
        .{ .input = 5119, .load = 0, .address = 174, .expected = 0 },
        .{ .input = 5119, .load = 0, .address = 175, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 168, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 168, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 169, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 169, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 170, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 170, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 171, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 171, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 172, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 172, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 173, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 173, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 174, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 174, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 175, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 175, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 169, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 171, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 172, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 173, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 174, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 175, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 168, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 169, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 171, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 172, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 173, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 174, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 175, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 168, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 169, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 169, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 169, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 171, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 172, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 173, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 174, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 175, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 169, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 169, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 170, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 169, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 171, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 172, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 173, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 174, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 175, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 170, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 171, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 171, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 169, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 171, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 172, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 173, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 174, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 175, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 171, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 171, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 172, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 172, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 169, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 171, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 172, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 173, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 174, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 175, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 172, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 172, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 173, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 173, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 169, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 171, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 172, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 173, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 174, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 175, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 173, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 173, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 174, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 174, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 169, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 171, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 172, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 173, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 174, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 175, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 174, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 174, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 175, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 175, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 169, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 171, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 172, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 173, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 174, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 175, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 175, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 175, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 168, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 169, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 171, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 172, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 173, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 174, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 175, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 42, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 42, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 106, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 234, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 298, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 362, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 426, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 490, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 42, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 42, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 106, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 106, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 170, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 170, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 234, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 234, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 298, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 298, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 362, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 362, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 426, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 426, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 490, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 490, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 106, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 234, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 298, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 362, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 426, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 490, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 42, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 106, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 234, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 298, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 362, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 426, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 490, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 42, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 106, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 106, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 106, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 234, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 298, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 362, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 426, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 490, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 106, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 106, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 170, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 106, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 234, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 298, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 362, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 426, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 490, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 170, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 234, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 234, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 106, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 234, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 298, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 362, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 426, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 490, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 234, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 234, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 298, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 298, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 106, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 234, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 298, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 362, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 426, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 490, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 298, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 298, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 362, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 362, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 106, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 234, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 298, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 362, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 426, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 490, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 362, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 362, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 426, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 426, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 106, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 234, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 298, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 362, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 426, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 490, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 426, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 426, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 490, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 490, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 106, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 234, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 298, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 362, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 426, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 490, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 490, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 490, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 42, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 106, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 170, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 234, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 298, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 362, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 426, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 490, .expected = 21845 },
    };

    var ram = RAM512{};
    var ram_i = RAM512_I{};
    var time: u32 = 0;

    std.debug.print("\n| time |   in   | load |  address  | expected |    out  |  out_i  |   peek  |\n", .{});

    for (testCases) |tc| {
        // Convert i32 to u16 (treating as 16-bit signed/unsigned)
        const input_u16: u16 = @bitCast(@as(i16, @intCast(tc.input)));

        const output = @as(i16, @bitCast(fb16(ram.tick(b16(input_u16), b9(tc.address), tc.load))));

        const output_i = @as(i16, @bitCast(ram_i.tick(input_u16, @as(u9, @intCast(tc.address)), tc.load)));

        const peek = @as(i16, @bitCast(fb16(ram.peek(b9(tc.address)))));

        try verifyAndPrint(time, tc.input, tc.load, tc.address, tc.expected, output, output_i, peek);

        if (tc.print_ram) {
            // self.ram.print();
        }
        time += 1;
    }
}

test "RAM4K: comprehensive test" {
    const testCases = [_]struct { input: i32, load: u1, address: u16, expected: i16, print_ram: bool = false }{
        .{ .input = 0, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 1, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 1, .address = 0, .expected = 0 },
        .{ .input = 1111, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 1111, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 1111, .load = 1, .address = 1111, .expected = 0 },
        .{ .input = 1111, .load = 1, .address = 1111, .expected = 1111 },
        .{ .input = 1111, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 1111, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 3513, .load = 0, .address = 3513, .expected = 0 },
        .{ .input = 3513, .load = 0, .address = 3513, .expected = 0 },
        .{ .input = 3513, .load = 1, .address = 3513, .expected = 0 },
        .{ .input = 3513, .load = 1, .address = 3513, .expected = 3513 },
        .{ .input = 3513, .load = 0, .address = 3513, .expected = 3513 },
        .{ .input = 3513, .load = 0, .address = 3513, .expected = 3513 },
        .{ .input = 3513, .load = 0, .address = 1111, .expected = 1111 },
        .{ .input = 4095, .load = 0, .address = 1111, .expected = 1111 },
        .{ .input = 4095, .load = 0, .address = 1111, .expected = 1111 },
        .{ .input = 4095, .load = 1, .address = 4095, .expected = 0 },
        .{ .input = 4095, .load = 1, .address = 4095, .expected = 4095 },
        .{ .input = 4095, .load = 0, .address = 4095, .expected = 4095 },
        .{ .input = 4095, .load = 0, .address = 4095, .expected = 4095 },
        .{ .input = 4095, .load = 0, .address = 3513, .expected = 3513 },
        .{ .input = 4095, .load = 0, .address = 4095, .expected = 4095 },
        .{ .input = 4095, .load = 0, .address = 2728, .expected = 0 },
        .{ .input = 4095, .load = 0, .address = 2728, .expected = 0 },
        .{ .input = 4095, .load = 0, .address = 2729, .expected = 0 },
        .{ .input = 4095, .load = 0, .address = 2730, .expected = 0 },
        .{ .input = 4095, .load = 0, .address = 2731, .expected = 0 },
        .{ .input = 4095, .load = 0, .address = 2732, .expected = 0 },
        .{ .input = 4095, .load = 0, .address = 2733, .expected = 0 },
        .{ .input = 4095, .load = 0, .address = 2734, .expected = 0 },
        .{ .input = 4095, .load = 0, .address = 2735, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 2728, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 2728, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2729, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 2729, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2730, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 2730, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2731, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 2731, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2732, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 2732, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2733, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 2733, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2734, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 2734, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2735, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 2735, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2729, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2730, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2731, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2732, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2733, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2734, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2735, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2728, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2729, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2730, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2731, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2732, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2733, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2734, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2735, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2728, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2729, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2729, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2729, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2730, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2731, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2732, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2733, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2734, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2735, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2729, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 2729, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2730, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2730, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2729, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2730, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2731, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2732, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2733, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2734, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2735, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2730, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 2730, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2731, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2731, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2729, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2730, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2731, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2732, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2733, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2734, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2735, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2731, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 2731, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2732, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2732, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2729, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2730, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2731, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2732, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2733, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2734, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2735, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2732, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 2732, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2733, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2733, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2729, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2730, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2731, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2732, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2733, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2734, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2735, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2733, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 2733, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2734, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2734, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2729, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2730, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2731, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2732, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2733, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2734, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2735, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2734, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 2734, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2735, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2735, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2729, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2730, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2731, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2732, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2733, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2734, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2735, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 2735, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 2735, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2728, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2729, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2730, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2731, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2732, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2733, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2734, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2735, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 341, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 341, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 853, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 1365, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 1877, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 2389, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 2901, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 3413, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 3925, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 341, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 341, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 853, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 853, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 1365, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 1365, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 1877, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 1877, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2389, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 2389, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2901, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 2901, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 3413, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 3413, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 3925, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 3925, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 853, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 1877, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2389, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2901, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 3925, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 341, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 853, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1877, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2389, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2901, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3925, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 341, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 853, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 853, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 853, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1877, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2389, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2901, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3925, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 853, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 853, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 1365, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 853, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 1877, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2389, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2901, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3925, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 1365, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 1877, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 1877, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 853, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1877, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2389, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2901, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3925, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 1877, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 1877, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2389, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2389, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 853, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1877, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2389, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 2901, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3925, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2389, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 2389, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2901, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 2901, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 853, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1877, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2389, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2901, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3925, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 2901, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 2901, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 3413, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 853, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1877, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2389, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2901, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 3925, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 3413, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 3925, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 3925, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 853, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1877, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2389, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 2901, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3925, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 3925, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 3925, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 341, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 853, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 1877, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2389, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 2901, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 3925, .expected = 21845 },
    };

    var ram = RAM4K{};
    var ram_i = RAM4K_I{};
    var time: u32 = 0;

    std.debug.print("\n| time |   in   | load |  address  | expected |    out  |  out_i  |   peek  |\n", .{});

    for (testCases) |tc| {
        // Convert i32 to u16 (treating as 16-bit signed/unsigned)
        const input_u16: u16 = @bitCast(@as(i16, @intCast(tc.input)));

        const output = @as(i16, @bitCast(fb16(ram.tick(b16(input_u16), b12(tc.address), tc.load))));

        const output_i = @as(i16, @bitCast(ram_i.tick(input_u16, @as(u12, @intCast(tc.address)), tc.load)));

        const peek = @as(i16, @bitCast(fb16(ram.peek(b12(tc.address)))));

        try verifyAndPrint(time, tc.input, tc.load, tc.address, tc.expected, output, output_i, peek);

        if (tc.print_ram) {
            // ram.print();
        }
        time += 1;
    }
}

test "RAM16K: comprehensive test" {
    const testCases = [_]struct { input: i32, load: u1, address: u16, expected: i16, print_ram: bool = false }{
        .{ .input = 0, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 1, .address = 0, .expected = 0 },
        .{ .input = 0, .load = 1, .address = 0, .expected = 0 },
        .{ .input = 4321, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 4321, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 4321, .load = 1, .address = 4321, .expected = 0 },
        .{ .input = 4321, .load = 1, .address = 4321, .expected = 4321 },
        .{ .input = 4321, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 4321, .load = 0, .address = 0, .expected = 0 },
        .{ .input = 12345, .load = 0, .address = 12345, .expected = 0 },
        .{ .input = 12345, .load = 0, .address = 12345, .expected = 0 },
        .{ .input = 12345, .load = 1, .address = 12345, .expected = 0 },
        .{ .input = 12345, .load = 1, .address = 12345, .expected = 12345 },
        .{ .input = 12345, .load = 0, .address = 12345, .expected = 12345 },
        .{ .input = 12345, .load = 0, .address = 12345, .expected = 12345 },
        .{ .input = 12345, .load = 0, .address = 4321, .expected = 4321 },
        .{ .input = 16383, .load = 0, .address = 4321, .expected = 4321 },
        .{ .input = 16383, .load = 0, .address = 4321, .expected = 4321 },
        .{ .input = 16383, .load = 1, .address = 16383, .expected = 0 },
        .{ .input = 16383, .load = 1, .address = 16383, .expected = 16383 },
        .{ .input = 16383, .load = 0, .address = 16383, .expected = 16383 },
        .{ .input = 16383, .load = 0, .address = 16383, .expected = 16383 },
        .{ .input = 16383, .load = 0, .address = 12345, .expected = 12345 },
        .{ .input = 16383, .load = 0, .address = 16383, .expected = 16383 },
        .{ .input = 16383, .load = 0, .address = 10920, .expected = 0 },
        .{ .input = 16383, .load = 0, .address = 10920, .expected = 0 },
        .{ .input = 16383, .load = 0, .address = 10921, .expected = 0 },
        .{ .input = 16383, .load = 0, .address = 10922, .expected = 0 },
        .{ .input = 16383, .load = 0, .address = 10923, .expected = 0 },
        .{ .input = 16383, .load = 0, .address = 10924, .expected = 0 },
        .{ .input = 16383, .load = 0, .address = 10925, .expected = 0 },
        .{ .input = 16383, .load = 0, .address = 10926, .expected = 0 },
        .{ .input = 16383, .load = 0, .address = 10927, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 10920, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 10920, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10921, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 10921, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10922, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 10922, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10923, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 10923, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10924, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 10924, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10925, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 10925, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10926, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 10926, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10927, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 10927, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10921, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10922, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10923, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10924, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10925, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10926, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10927, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10920, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10921, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10922, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10923, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10924, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10925, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10926, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10927, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10920, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10921, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10921, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10921, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10922, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10923, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10924, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10925, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10926, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10927, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10921, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 10921, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10922, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10922, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10921, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10922, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10923, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10924, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10925, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10926, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10927, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10922, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 10922, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10923, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10923, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10921, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10922, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10923, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10924, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10925, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10926, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10927, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10923, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 10923, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10924, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10924, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10921, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10922, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10923, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10924, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10925, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10926, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10927, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10924, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 10924, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10925, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10925, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10921, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10922, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10923, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10924, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10925, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10926, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10927, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10925, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 10925, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10926, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10926, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10921, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10922, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10923, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10924, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10925, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10926, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10927, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 10926, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 10926, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10927, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 10927, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10921, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10922, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10923, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10924, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10925, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10926, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 10927, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 10927, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 10927, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10920, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10921, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10922, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10923, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10924, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10925, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10926, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 10927, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 1365, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 1365, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 3413, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 5461, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 7509, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 9557, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 11605, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 13653, .expected = 0 },
        .{ .input = 21845, .load = 0, .address = 15701, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 1365, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 1365, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 3413, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 3413, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 5461, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 5461, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 7509, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 7509, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 9557, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 9557, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 11605, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 11605, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 13653, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 13653, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 15701, .expected = 0 },
        .{ .input = 21845, .load = 1, .address = 15701, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 5461, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 7509, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 9557, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 11605, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 13653, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 15701, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 1365, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5461, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7509, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 9557, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 11605, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13653, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 15701, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 1365, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 3413, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 5461, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7509, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 9557, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 11605, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13653, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 15701, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 3413, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 5461, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 5461, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5461, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 7509, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 9557, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 11605, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13653, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 15701, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 5461, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 5461, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 7509, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 7509, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5461, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7509, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 9557, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 11605, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13653, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 15701, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 7509, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 7509, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 9557, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 9557, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5461, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7509, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 9557, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 11605, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13653, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 15701, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 9557, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 9557, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 11605, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 11605, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5461, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7509, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 9557, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 11605, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 13653, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 15701, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 11605, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 11605, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 13653, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 13653, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5461, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7509, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 9557, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 11605, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13653, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 15701, .expected = 21845 },
        .{ .input = 21845, .load = 1, .address = 13653, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 13653, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 15701, .expected = 21845 },
        .{ .input = -21846, .load = 1, .address = 15701, .expected = -21846 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 5461, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 7509, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 9557, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 11605, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 13653, .expected = 21845 },
        .{ .input = -21846, .load = 0, .address = 15701, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 15701, .expected = -21846 },
        .{ .input = 21845, .load = 1, .address = 15701, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 1365, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 3413, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 5461, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 7509, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 9557, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 11605, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 13653, .expected = 21845 },
        .{ .input = 21845, .load = 0, .address = 15701, .expected = 21845 },
    };

    var ram = RAM16K{};
    var ram_i = RAM16K_I{};
    var time: u32 = 0;

    std.debug.print("\n| time |   in   | load |  address  | expected |    out  |  out_i  |   peek  |\n", .{});

    for (testCases) |tc| {
        // Convert i32 to u16 (treating as 16-bit signed/unsigned)
        const input_u16: u16 = @bitCast(@as(i16, @intCast(tc.input)));

        const output = @as(i16, @bitCast(fb16(ram.tick(b16(input_u16), b14(tc.address), tc.load))));

        const output_i = @as(i16, @bitCast(ram_i.tick(input_u16, @as(u14, @intCast(tc.address)), tc.load)));

        const peek = @as(i16, @bitCast(fb16(ram.peek(b14(tc.address)))));

        try verifyAndPrint(time, tc.input, tc.load, tc.address, tc.expected, output, output_i, peek);

        if (tc.print_ram) {
            // ram.print();
        }
        time += 1;
    }
}
