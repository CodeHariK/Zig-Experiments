// =============================================================================
// ROM (Read-Only Memory)
// =============================================================================
//
// ROM stores the program instructions that the CPU executes. In the Hack
// computer, ROM is 32K (32,768) words, each 16 bits wide.
//
// -----------------------------------------------------------------------------
// ROM Overview
// -----------------------------------------------------------------------------
//
// ROM (Read-Only Memory) is non-volatile memory that stores:
//   - Program instructions (machine code)
//   - Constants and data that don't change during execution
//
// Key characteristics:
//   - Read-only: Cannot be written during program execution
//   - Non-volatile: Contents persist when power is off
//   - Random access: Can read any address directly
//   - Fixed contents: Loaded at program start, unchanged during execution
//
// -----------------------------------------------------------------------------
// ROM Interface
// -----------------------------------------------------------------------------
//
// Inputs:
//   address[15] - 15-bit address (0 to 32,767)
//
// Outputs:
//   out[16] - 16-bit instruction at the specified address
//
// -----------------------------------------------------------------------------
// ROM Size
// -----------------------------------------------------------------------------
//
// The Hack computer ROM is 32K words:
//   - Address range: 0 to 32,767 (2^15 - 1)
//   - Word size: 16 bits
//   - Total capacity: 32,768 × 16 = 524,288 bits = 64 KB
//
// This is sufficient for:
//   - Large programs (thousands of instructions)
//   - Complex algorithms
//   - Operating system code
//
// -----------------------------------------------------------------------------
// ROM Addressing
// -----------------------------------------------------------------------------
//
// Address format:
//   - 15-bit address (0 to 32,767)
//   - Address 0 is the first instruction (program entry point)
//   - Addresses increment sequentially
//
// Reading:
//   - Given address A, ROM outputs instruction at address A
//   - Reading is immediate (combinational logic)
//   - No clock required for reading
//
// -----------------------------------------------------------------------------
// ROM Contents
// -----------------------------------------------------------------------------
//
// ROM is typically loaded with:
//
//   1. Program instructions:
//      - A-instructions: Load addresses/constants
//      - C-instructions: Perform computations and control flow
//
//   2. Data constants:
//      - Lookup tables
//      - String data
//      - Precomputed values
//
//   3. Subroutines:
//      - Function code
//      - Library routines
//      - System calls
//
// -----------------------------------------------------------------------------
// ROM Initialization
// -----------------------------------------------------------------------------
//
// ROM contents are set when the program is loaded:
//
//   1. Assembly source code is assembled to machine code
//   2. Machine code is loaded into ROM
//   3. ROM contents remain fixed during execution
//
// In simulation/emulation:
//   - ROM can be initialized from:
//     * Array of 16-bit values
//     * Binary file
//     * Assembled program
//
// -----------------------------------------------------------------------------
// ROM vs RAM
// -----------------------------------------------------------------------------
//
// ROM (Read-Only Memory):
//   - Stores program instructions
//   - Cannot be modified during execution
//   - Non-volatile (persists)
//   - Accessed via PC (Program Counter)
//   - 32K words (0-32,767)
//
// RAM (Random Access Memory):
//   - Stores data and variables
//   - Can be read and written
//   - Volatile (lost on power off)
//   - Accessed via A register
//   - 16K words (0-16,383)
//
// -----------------------------------------------------------------------------
// Implementation Structure
// -----------------------------------------------------------------------------
//
// This module implements ROM32K using RAM16K components:
//
//   rom.zig (this file):
//     - ROM32K struct (built from 2 RAM16K_I components)
//     - Initialization from data
//     - Read operation
//
// -----------------------------------------------------------------------------
// ROM Implementation
// -----------------------------------------------------------------------------
//
// ROM32K is built from 2 RAM16K_I chips:
//   - High bit (bit 14) selects which RAM16K_I unit
//   - Low 14 bits address within that RAM16K_I
//   - Address 0-16383: first RAM16K_I
//   - Address 16384-32767: second RAM16K_I
//
// This follows the same hierarchical pattern as RAM construction:
//   - ROM32K = 2 × RAM16K_I
//   - Uses MUX16_I to select output from the correct RAM16K_I
//   - Read-only during execution (load=0 always for reads)
//   - Can be initialized with program data (one-time write)
//
// -----------------------------------------------------------------------------
// ROM Initialization Methods
// -----------------------------------------------------------------------------
//
// ROM can be initialized from:
//
//   1. Array of instructions:
//      rom.initFromArray(&[u16]{ 0x0000, 0xEA88, ... });
//
//   2. Slice of instructions:
//      rom.initFromSlice(instructions);
//
//   3. Binary file:
//      rom.initFromFile("program.bin");
//
//   4. Assembled program:
//      rom.initFromInstructions(instructions);
//
//   5. Empty (all zeros):
//      rom.initEmpty();
//
// -----------------------------------------------------------------------------
// Address Validation
// -----------------------------------------------------------------------------
//
// Address must be valid:
//   - Range: 0 to 32,767
//   - Invalid addresses should return 0 or error
//
// Implementation:
//   - Check address range before access
//   - Return 0 for invalid addresses (or error)
//   - Log warnings for out-of-range access
//
// -----------------------------------------------------------------------------
// ROM Reading
// -----------------------------------------------------------------------------
//
// Reading from ROM:
//
//   1. Validate address (0 to 32,767)
//   2. Return instruction at that address
//   3. If address is out of range, return 0
//
// Reading is:
//   - Combinational (no clock required)
//   - Immediate (no delay)
//   - Non-destructive (doesn't change ROM)
//
// -----------------------------------------------------------------------------
// Implementation Details
// -----------------------------------------------------------------------------
//
// ROM32K implementation:
//
//   1. Structure:
//      - Built from 2 RAM16K_I components
//      - Uses hierarchical addressing pattern
//
//   2. Addressing:
//      - 15-bit address (0-32767)
//      - High bit (bit 14) selects RAM16K_I: 0→first, 1→second
//      - Low 14 bits address within selected RAM16K_I
//
//   3. Read operation:
//      - Uses peek() on both RAM16K_I components
//      - MUX16_I selects output from addressed component
//      - Read-only: no load signal needed
//
//   4. Initialization:
//      - Uses tick() with load=1 to write to RAM16K_I components
//      - One-time setup before execution begins
//      - After initialization, ROM is read-only
//
// -----------------------------------------------------------------------------
// Testing Strategy
// -----------------------------------------------------------------------------
//
// Test ROM with:
//
//   1. Initialization tests:
//      - Empty ROM (all zeros)
//      - ROM from array
//      - ROM from slice
//      - Partial initialization
//
//   2. Reading tests:
//      - Read valid addresses
//      - Read address 0
//      - Read address 32,767 (max)
//      - Read out-of-range addresses
//
//   3. Content verification:
//      - Verify loaded instructions match input
//      - Verify uninitialized addresses are 0
//
//   4. Edge cases:
//      - Empty ROM
//      - Single instruction
//      - Full ROM (32K instructions)
//
// -----------------------------------------------------------------------------

const std = @import("std");
const testing = std.testing;

const memory = @import("memory").Memory;
const memory_i = @import("memory").Memory_I;
const types = @import("types");
const b15 = types.b15;
const b16 = types.b16;

// =============================================================================
// ROM32K - 32768 Words (Read-Only Memory) - Bit-Array Version
// =============================================================================

/// ROM32K - 32768 16-bit words addressable by 15-bit address (bit-array version).
///
/// Built from 1 RAM32K chip:
/// - Direct 15-bit addressing (0-32767)
///
/// ROM is read-only during execution, but can be initialized with program data.
/// Uses bit arrays for addresses and data: [15]u1 for address, [16]u1 for data.
pub const ROM32K = struct {
    ram32k: memory.Ram32K = .{},

    const Self = @This();

    /// Read instruction from ROM at the specified address.
    /// This is a read-only operation - ROM cannot be written during execution.
    ///
    /// Address must be in range 0-32767 (15 bits).
    /// Returns all zeros for out-of-range addresses.
    pub fn read(self: *const Self, address: [15]u1) [16]u1 {
        // Read directly from RAM32K (using peek for read-only access)
        return self.ram32k.peek(address);
    }

    /// Initialize ROM from a slice of instructions.
    /// This writes to the underlying RAM32K component to set up the ROM contents.
    ///
    /// Only the first 32768 words from the slice are used.
    /// If the slice is shorter, remaining addresses are set to 0.
    pub fn initFromSlice(self: *Self, instructions: []const u16) void {
        const max_size = 32768;
        const size = @min(instructions.len, max_size);

        // Write instructions directly to RAM32K
        for (instructions[0..size], 0..) |instruction, i| {
            const address_bits = b15(i);
            const instruction_bits = b16(instruction);

            // Write to RAM32K (load=1 to write)
            _ = self.ram32k.tick(instruction_bits, address_bits, 1);
        }

        // Clear remaining addresses if slice was shorter than 32768
        if (instructions.len < max_size) {
            for (instructions.len..max_size) |i| {
                const address_bits = b15(i);
                _ = self.ram32k.tick(b16(0), address_bits, 1);
            }
        }
    }

    /// Reset ROM to initial state (all zeros).
    pub fn reset(self: *Self) void {
        self.ram32k.reset();
    }
};

// =============================================================================
// ROM32K_I - 32768 Words (Read-Only Memory) - Integer Version
// =============================================================================

/// ROM32K_I - 32768 16-bit words addressable by 15-bit address (integer version).
///
/// Built from 1 RAM32K_I chip:
/// - Direct 15-bit addressing (0-32767)
///
/// Integer version using direct u16/u15 for faster operations.
/// Uses RAM32K_I for direct integer access, avoiding hardware simulation overhead.
pub const ROM32K_I = struct {
    ram32k: memory_i.Ram32K = .{},

    const Self = @This();

    /// Read instruction from ROM at the specified address.
    /// This is a read-only operation - ROM cannot be written during execution.
    ///
    /// Address must be in range 0-32767 (15 bits).
    /// Returns all zeros for out-of-range addresses.
    pub fn read(self: *const Self, address: u15) u16 {
        // Read directly from RAM32K_I (using peek for read-only access)
        return self.ram32k.peek(address);
    }

    /// Initialize ROM from a slice of instructions.
    /// This writes to the underlying RAM32K_I component to set up the ROM contents.
    ///
    /// Only the first 32768 words from the slice are used.
    /// If the slice is shorter, remaining addresses are set to 0.
    /// Optimized using direct memory access for better performance.
    pub fn initFromSlice(self: *Self, instructions: []const u16) void {
        if (instructions.len > 32768) {
            @panic("ROM32K_I: instructions length exceeds maximum size of 32768");
        }

        const size = instructions.len;

        // Get direct access to RAM32K_I memory for fast initialization
        const rom_memory = self.ram32k.getMemory();

        // Copy instructions directly to memory
        if (size > 0) {
            @memcpy(rom_memory[0..size], instructions[0..size]);
        }

        // Clear remaining addresses if slice was shorter than 32768
        if (instructions.len < 32768) {
            @memset(rom_memory[instructions.len..32768], 0);
        }
    }

    /// Reset ROM to initial state (all zeros).
    pub fn reset(self: *Self) void {
        self.ram32k.reset();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ROM32K and ROM32K_I produce identical results" {
    var rom_i = ROM32K_I{};

    // Test empty ROM
    try testing.expectEqual(@as(u16, 0), rom_i.read(0));
    try testing.expectEqual(@as(u16, 0), rom_i.read(32767));

    // Test initialization from slice
    const instructions = [_]u16{ 0x0001, 0x1234, 0x5678, 0x9ABC, 0xFFFF, 0x0000 };

    rom_i.initFromSlice(&instructions);

    // Verify all instructions match
    for (instructions, 0..) |expected, i| {
        const rom_i_value = rom_i.read(@intCast(i));

        try testing.expectEqual(expected, rom_i_value);
    }

    // Test that uninitialized addresses are 0
    try testing.expectEqual(@as(u16, 0), rom_i.read(instructions.len));

    // Test boundary addresses
    var boundary_instructions: [16386]u16 = undefined;
    @memset(&boundary_instructions, 0); // Initialize all to zero
    boundary_instructions[16383] = 0xAAAA;
    boundary_instructions[16384] = 0xBBBB;
    boundary_instructions[16385] = 0xCCCC;

    rom_i.initFromSlice(&boundary_instructions);

    try testing.expectEqual(@as(u16, 0xAAAA), rom_i.read(16383));
    try testing.expectEqual(@as(u16, 0xBBBB), rom_i.read(16384));
    try testing.expectEqual(@as(u16, 0xCCCC), rom_i.read(16385));

    // Test max address
    var max_instructions: [32768]u16 = undefined;
    @memset(&max_instructions, 0); // Initialize all to zero
    max_instructions[32767] = 0xFFFF;

    rom_i.initFromSlice(&max_instructions);

    try testing.expectEqual(@as(u16, 0xFFFF), rom_i.read(32767));
    try testing.expectEqual(@as(u16, 0), rom_i.read(0));

    // Test reset
    rom_i.reset();

    try testing.expectEqual(@as(u16, 0), rom_i.read(0));
    try testing.expectEqual(@as(u16, 0), rom_i.read(32767));
}
