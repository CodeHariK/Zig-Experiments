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
const logic = @import("logic").Logic;

const types = @import("types");
const b16 = types.b16;
const b3 = types.b3;
const b6 = types.b6;
const b9 = types.b9;
const b12 = types.b12;
const b13 = types.b13;
const b14 = types.b14;
const b15 = types.b15;
const fb3 = types.fb3;
const fb8 = types.fb8;
const fb13 = types.fb13;
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

/// RAM8K - 8192 16-bit registers addressable by 13-bit address.
///
/// Built from 2 RAM4K chips (2 × 4096 = 8192):
/// - High bit (bit 12) selects which RAM4K unit
/// - Low 12 bits address within that RAM4K
pub const RAM8K = struct {
    ram4ks: [2]RAM4K = [_]RAM4K{.{}} ** 2,

    const Self = @This();

    /// Update RAM8K with new input, address, and load signal.
    pub fn tick(self: *Self, input: [16]u1, address: [13]u1, load: u1) [16]u1 {
        // Split address: high bit (bit 12) selects RAM4K, low 12 bits address within that RAM4K
        // Address is MSB-first: address[0] is MSB (bit 12)
        const high_bit: u1 = address[0]; // MSB (bit 12)
        const low_bits: [12]u1 = address[1..13].*;

        // Route load signal to the correct RAM4K
        // DMux(in, sel) returns [out_sel1, out_sel0]
        // When sel=0: out[0]=0, out[1]=in (first RAM4K)
        // When sel=1: out[0]=in, out[1]=0 (second RAM4K)
        const load_signals = logic.DMUX(load, high_bit);

        var outputs: [2][16]u1 = undefined;
        inline for (0..2) |i| {
            outputs[i] = self.ram4ks[i].tick(input, low_bits, load_signals[i]);
        }

        // MUX16 selects output from the addressed RAM4K
        // MUX16(in1, in0, sel): sel=0 → in0, sel=1 → in1
        return logic.MUX16(
            outputs[0],
            outputs[1],
            high_bit,
        );
    }

    /// Get the current output from the addressed register without advancing time.
    pub fn peek(self: *const Self, address: [13]u1) [16]u1 {
        // Split address: high bit (bit 12) selects RAM4K, low 12 bits address within that RAM4K
        const high_bit: u1 = address[0]; // MSB (bit 12)
        const low_bits: [12]u1 = address[1..13].*;

        var outputs: [2][16]u1 = undefined;
        inline for (0..2) |i| {
            outputs[i] = self.ram4ks[i].peek(low_bits);
        }

        // MUX16 selects output from the addressed RAM4K
        return logic.MUX16(
            outputs[0],
            outputs[1],
            high_bit,
        );
    }

    /// Reset all RAM4Ks to initial state.
    pub fn reset(self: *Self) void {
        inline for (0..2) |i| {
            self.ram4ks[i].reset();
        }
    }
};

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

/// RAM32K - 32768 16-bit registers addressable by 15-bit address.
///
/// Built from 8 RAM4K chips (8 × 4096 = 32768):
/// - High 3 bits (bits 12-14) select which RAM4K unit
/// - Low 12 bits (bits 0-11) address within that RAM4K
pub const RAM32K = struct {
    ram4ks: [8]RAM4K = [_]RAM4K{.{}} ** 8,

    const Self = @This();

    /// Update RAM32K with new input, address, and load signal.
    pub fn tick(self: *Self, input: [16]u1, address: [15]u1, load: u1) [16]u1 {
        // Split address: high 3 bits (bits 12-14) select RAM4K, low 12 bits address within that RAM4K
        // Address is MSB-first: address[0] is MSB (bit 14)
        // 15 bits total: 3 bits for selection (8 RAM4Ks) + 12 bits for address = 15 bits
        const high_bits_raw: [3]u1 = address[0..3].*;
        // Reverse high bits because MUX/DMUX expect LSB-first selector
        const high_bits: [3]u1 = [3]u1{ high_bits_raw[2], high_bits_raw[1], high_bits_raw[0] };
        const low_bits: [12]u1 = address[3..15].*;

        // Use DMUX8WAY for 8-way selection
        const load_signals = logic.DMUX8WAY(load, high_bits);

        var outputs: [8][16]u1 = undefined;
        inline for (0..8) |i| {
            outputs[i] = self.ram4ks[i].tick(input, low_bits, load_signals[i]);
        }

        // Use MUX8WAY16 for 8-way output selection
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
    pub fn peek(self: *const Self, address: [15]u1) [16]u1 {
        // Split address: high 3 bits (bits 12-14) select RAM4K, low 12 bits address within that RAM4K
        const high_bits_raw: [3]u1 = address[0..3].*;
        // Reverse high bits because MUX expects LSB-first selector
        const high_bits: [3]u1 = [3]u1{ high_bits_raw[2], high_bits_raw[1], high_bits_raw[0] };
        const low_bits: [12]u1 = address[3..15].*;

        var outputs: [8][16]u1 = undefined;
        inline for (0..8) |i| {
            outputs[i] = self.ram4ks[i].peek(low_bits);
        }

        // Use MUX8WAY16 for 8-way output selection
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

    /// Reset all RAM4Ks to initial state.
    pub fn reset(self: *Self) void {
        inline for (0..8) |i| {
            self.ram4ks[i].reset();
        }
    }
};

// =============================================================================
// RAM_R_T - Generic RAM with Direct Array Storage
// =============================================================================

///
/// Integer version using direct array access for performance-critical code.
///
/// Parameters:
///   - R: Register size in bits (e.g., 16 for 16-bit words)
///   - T: Number of registers (e.g., 8192 for RAM8K)
///
/// Example usage:
/// ```zig
/// const RAM8 = RAM_R_T(16, 8);      // 8 registers of 16 bits each
/// const RAM64 = RAM_R_T(16, 64);    // 64 registers of 16 bits each
/// const RAM8K = RAM_R_T(16, 8192);  // 8192 registers of 16 bits each
/// ```
pub fn RAM_R_T(comptime R: comptime_int, comptime T: comptime_int) type {
    // Calculate the integer type for register values
    const RegisterType = std.meta.Int(.unsigned, R);

    // Calculate address width from T (number of registers)
    // Find the smallest integer type that can hold addresses 0..T-1
    comptime var address_bits: comptime_int = 0;
    comptime var temp: comptime_int = T;
    while (temp > 1) {
        address_bits += 1;
        temp >>= 1;
    }
    // If T is not a power of 2, we need one more bit
    if ((@as(comptime_int, 1) << address_bits) < T) {
        address_bits += 1;
    }

    // Use u16 as the address type (can handle up to 65535 addresses)
    // For sizes > 65535, we'd need u32, but Nand2Tetris max is 16384
    const AddressType = if (address_bits <= 16) u16 else u32;

    return struct {
        /// Direct array storage: T registers of R bits each
        memory: [T]RegisterType = [_]RegisterType{0} ** T,

        const Self = @This();
        const AddrType = AddressType;
        const RegType = RegisterType;

        /// Update RAM_R_T with new input, address, and load signal.
        /// Returns the current value at the specified address.
        ///
        /// If load=1, writes input to the addressed register.
        /// Address is truncated to fit within the memory size (wraps around like hardware).
        pub fn tick(self: *Self, input: RegisterType, address: AddressType, load: u1) RegisterType {
            // Truncate address to fit within T (like hardware does with address bits)
            const addr = @as(usize, @intCast(address)) % T;
            const current = self.memory[addr];
            if (load == 1) {
                self.memory[addr] = input;
            }
            return current;
        }

        /// Get the current value at the specified address without advancing time.
        /// Address is truncated to fit within the memory size (wraps around like hardware).
        pub fn peek(self: *const Self, address: AddressType) RegisterType {
            // Truncate address to fit within T (like hardware does with address bits)
            const addr = @as(usize, @intCast(address)) % T;
            return self.memory[addr];
        }

        /// Reset all memory to initial state (all values set to 0).
        pub fn reset(self: *Self) void {
            @memset(&self.memory, 0);
        }

        /// Get a reference to the internal memory array.
        pub fn getMemory(self: *Self) *[T]RegisterType {
            return &self.memory;
        }
    };
}

pub const RAM8_I = RAM_R_T(16, 8);
pub const RAM64_I = RAM_R_T(16, 64);
pub const RAM512_I = RAM_R_T(16, 512);
pub const RAM4K_I = RAM_R_T(16, 4096);
pub const RAM8K_I = RAM_R_T(16, 8192);
pub const RAM16K_I = RAM_R_T(16, 16384);
pub const RAM32K_I = RAM_R_T(16, 32768);

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

test "RAM8K: comprehensive test" {
    const RAM_SIZE = 8192;
    const NUM_TEST_CASES = 50;
    const FUZZ_SEED: u64 = 0x123456789ABCDEF0;
    const edge_addresses = [_]u16{ 0, 4095, 4096, 8191 };

    var test_cases_buffer: [NUM_TEST_CASES]FuzzTestCase = undefined;
    const testCases = generateFuzzTestCases(RAM_SIZE, NUM_TEST_CASES, FUZZ_SEED, &edge_addresses, &test_cases_buffer);

    var ram = RAM8K{};
    var ram_i = RAM8K_I{};
    var time: u32 = 0;

    std.debug.print("\n| time |   in   | load |  address  | expected |    out  |  out_i  |   peek  |\n", .{});

    for (testCases) |tc| {
        // Convert i32 to u16 (treating as 16-bit signed/unsigned)
        const input_u16: u16 = @bitCast(@as(i16, @intCast(tc.input)));

        const output = @as(i16, @bitCast(fb16(ram.tick(b16(input_u16), b13(tc.address), tc.load))));
        const output_i = @as(i16, @bitCast(ram_i.tick(input_u16, tc.address, tc.load)));
        const peek = @as(i16, @bitCast(fb16(ram.peek(b13(tc.address)))));

        try verifyAndPrint(time, tc.input, tc.load, tc.address, tc.expected, output, output_i, peek);

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

test "RAM32K: comprehensive test" {
    const RAM_SIZE = 32768;
    const NUM_TEST_CASES = 50;
    const FUZZ_SEED: u64 = 0x123456789ABCDEF0;
    const edge_addresses = [_]u16{ 0, 4095, 4096, 8191 };

    var test_cases_buffer: [NUM_TEST_CASES]FuzzTestCase = undefined;
    const testCases = generateFuzzTestCases(RAM_SIZE, NUM_TEST_CASES, FUZZ_SEED, &edge_addresses, &test_cases_buffer);

    var ram = RAM32K{};
    var ram_i = RAM32K_I{};
    var time: u32 = 0;

    std.debug.print("\n| time |   in   | load |  address  | expected |    out  |  out_i  |   peek  |\n", .{});

    for (testCases) |tc| {
        // Convert i32 to u16 (treating as 16-bit signed/unsigned)
        const input_u16: u16 = @bitCast(@as(i16, @intCast(tc.input)));

        const output = @as(i16, @bitCast(fb16(ram.tick(b16(input_u16), b15(tc.address), tc.load))));
        const output_i = @as(i16, @bitCast(ram_i.tick(input_u16, tc.address, tc.load)));
        const peek = @as(i16, @bitCast(fb16(ram.peek(b15(tc.address)))));

        try verifyAndPrint(time, tc.input, tc.load, tc.address, tc.expected, output, output_i, peek);

        time += 1;
    }
}

// =============================================================================
// Fuzz Test Generator
// =============================================================================

/// Test case generated by the fuzz generator
const FuzzTestCase = struct {
    input: i32,
    load: u1,
    address: u16,
    expected: i16,
};

/// Deterministic fuzz generator for RAM tests.
/// Generates predictable test cases using a fixed seed PRNG.
fn generateFuzzTestCases(
    comptime ram_size: comptime_int,
    num_cases: usize,
    seed: u64,
    edge_addresses: ?[]const u16,
    test_cases: []FuzzTestCase,
) []FuzzTestCase {
    // Simple LCG PRNG for deterministic generation
    var rng_state: u64 = seed;
    const nextRand = struct {
        fn call(state: *u64) u64 {
            state.* = state.* *% 1103515245 +% 12345; // LCG parameters
            return state.*;
        }
    }.call;

    // Track RAM state to compute expected outputs
    var ram_state: [ram_size]u16 = [_]u16{0} ** ram_size;

    // Track current address to reuse it for multiple cycles
    var current_address: ?u16 = null;
    var address_reuse_count: u32 = 0;
    const max_reuse = 5; // Reuse same address for up to 3 cycles

    for (0..num_cases) |i| {
        // Generate input value (signed 16-bit range)
        const input_i32: i32 = @as(i32, @intCast(nextRand(&rng_state) % 0x10000)) - 0x8000;
        const input_u16: u16 = @bitCast(@as(i16, @intCast(input_i32)));

        // Generate address (reuse same address for a few cycles, then pick new one)
        var address: u16 = undefined;
        if (current_address) |addr| {
            // Continue using current address if we haven't reached max reuse
            if (address_reuse_count < max_reuse) {
                address_reuse_count += 1;
                address = addr;
            } else {
                // Reset and pick new address
                current_address = null;
                address_reuse_count = 0;
                // Fall through to pick new address
            }
        }

        // Pick new address if we don't have one
        if (current_address == null) {
            const rand_val = nextRand(&rng_state);
            address = if (edge_addresses) |edges| blk: {
                // 10% chance of selecting an edge case
                if (rand_val % 10 == 0) {
                    const edge_idx = (rand_val / 10) % edges.len;
                    break :blk edges[edge_idx] % ram_size;
                } else {
                    break :blk @truncate(rand_val % ram_size);
                }
            } else @truncate(rand_val % ram_size);
            current_address = address;
            address_reuse_count = 1;
        }

        // Generate load signal (totally random: XOR multiple bits to break up patterns)
        const rand_val = nextRand(&rng_state);
        // XOR bits from different positions to get better randomness
        const load: u1 = @truncate(((rand_val >> 0) ^ (rand_val >> 7) ^ (rand_val >> 15) ^ (rand_val >> 23)) & 1);

        // Compute expected output (current value at address before write)
        const addr_truncated = address % ram_size;
        const expected_i16: i16 = @bitCast(ram_state[addr_truncated]);

        // Update RAM state if load=1
        if (load == 1) {
            ram_state[addr_truncated] = input_u16;
        }

        test_cases[i] = .{
            .input = input_i32,
            .load = load,
            .address = address,
            .expected = expected_i16,
        };
    }

    return test_cases[0..num_cases];
}
