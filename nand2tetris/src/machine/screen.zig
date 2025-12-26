// =============================================================================
// Screen (Memory-Mapped I/O)
// =============================================================================
//
// The Screen is a memory-mapped I/O device that provides a 512×256 pixel
// black-and-white display. It is accessed as RAM addresses 16384-24575.
//
// -----------------------------------------------------------------------------
// Screen Overview
// -----------------------------------------------------------------------------
//
// The Screen is a display device that:
//   - Provides a 512×256 pixel display
//   - Each pixel is either black (0) or white (1)
//   - Total pixels: 512 × 256 = 131,072 pixels
//   - Memory-mapped: Accessed via RAM addresses 16384-24575
//
// Key characteristics:
//   - Memory-mapped I/O: Appears as regular RAM to the CPU
//   - Write-only: Can write pixels, cannot read back
//   - Bit-mapped: Each bit represents one pixel
//   - Row-major order: Pixels stored row by row
//
// -----------------------------------------------------------------------------
// Screen Memory Map
// -----------------------------------------------------------------------------
//
// Memory addresses:
//   - Base address: 16384 (0x4000)
//   - End address: 24575 (0x5FFF)
//   - Size: 8,192 words (8K)
//
// Address calculation:
//   - Screen address = 16384 + (row × 32) + (col / 16)
//   - row: 0-255 (256 rows)
//   - col: 0-511 (512 columns)
//   - Each word represents 16 pixels horizontally
//
// -----------------------------------------------------------------------------
// Pixel Layout
// -----------------------------------------------------------------------------
//
// Display dimensions:
//   - Width: 512 pixels
//   - Height: 256 pixels
//   - Total: 131,072 pixels
//
// Memory organization:
//   - Each 16-bit word represents 16 horizontal pixels
//   - Words are stored row by row (row-major order)
//   - Row 0: addresses 16384-16415 (32 words)
//   - Row 1: addresses 16416-16447 (32 words)
//   - ... and so on
//
// Pixel to address mapping:
//   - word_address = 16384 + (row × 32) + (col / 16)
//   - bit_position = 15 - (col % 16)
//   - pixel_value = (word >> bit_position) & 1
//
// -----------------------------------------------------------------------------
// Bit Ordering
// -----------------------------------------------------------------------------
//
// Important: Nand2Tetris uses LSB-first encoding, but this project uses MSB-first.
//
// In this project (MSB-first):
//   - Bit 15 (MSB) = leftmost pixel in the word
//   - Bit 0 (LSB) = rightmost pixel in the word
//   - Word 0x8000 = pixel on left, rest off
//   - Word 0x0001 = pixel on right, rest off
//
// Pixel layout in a word (MSB-first):
//   [15][14][13][12][11][10][9][8][7][6][5][4][3][2][1][0]
//    ←─── 16 pixels, left to right ───→
//
// -----------------------------------------------------------------------------
// Screen Interface
// -----------------------------------------------------------------------------
//
// Inputs:
//   in[16]      - 16-bit value to write
//   load         - Write enable (1 = write, 0 = no change)
//   address[13]  - 13-bit address (0-8191, relative to base 16384)
//
// Outputs:
//   out[16]     - Current value at address (for reading, if needed)
//
// Note: The CPU accesses Screen via RAM, so the interface is:
//   - CPU writes to RAM[address] where address is 16384-24575
//   - RAM routes writes to Screen when address is in range
//
// -----------------------------------------------------------------------------
// Screen Operations
// -----------------------------------------------------------------------------
//
// Writing pixels:
//   1. CPU sets A register to screen address (16384-24575)
//   2. CPU executes C-instruction: M=value
//   3. RAM routes write to Screen
//   4. Screen updates pixel data
//
// Reading pixels (if needed):
//   - Screen can provide current word value
//   - Typically not needed (write-only device)
//
// -----------------------------------------------------------------------------
// Coordinate System
// -----------------------------------------------------------------------------
//
// Screen coordinates:
//   - Origin (0,0) at top-left corner
//   - X increases to the right (0-511)
//   - Y increases downward (0-255)
//
// Memory mapping:
//   - Row 0 (top): addresses 16384-16415
//   - Row 255 (bottom): addresses 24544-24575
//
// -----------------------------------------------------------------------------
// Pixel Values
// -----------------------------------------------------------------------------
//
// Pixel representation:
//   - 0 = black pixel
//   - 1 = white pixel
//
// Word representation:
//   - Each 16-bit word = 16 horizontal pixels
//   - Bit 15 = leftmost pixel
//   - Bit 0 = rightmost pixel
//
// -----------------------------------------------------------------------------
// Screen Update
// -----------------------------------------------------------------------------
//
// When writing to Screen:
//   1. Address is validated (must be 16384-24575)
//   2. Relative address is calculated (address - 16384)
//   3. Row and column are extracted from relative address
//   4. Pixel data is updated in internal buffer
//   5. Display is refreshed (in real hardware or emulation)
//
// -----------------------------------------------------------------------------
// Implementation Structure
// -----------------------------------------------------------------------------
//
// This module will be organized as:
//
//   screen.zig (this file):
//     - Screen struct
//     - Pixel buffer (512×256 bits)
//     - Address decoding
//     - Pixel read/write operations
//
// -----------------------------------------------------------------------------
// Screen Implementation
// -----------------------------------------------------------------------------
//
// Implementation options:
//
//   1. Bit array:
//      - Use array[256][512]u1 for pixels
//      - Simple and direct
//      - Easy to understand
//
//   2. Packed bits:
//      - Use array[256][32]u16 (words per row)
//      - More memory efficient
//      - Matches memory layout
//
//   3. Flat array:
//      - Use array[8192]u16 (all words)
//      - Direct memory mapping
//      - Fast access
//
// Recommended: Packed bits (array[256][32]u16) for efficiency and clarity.
//
// -----------------------------------------------------------------------------
// Address Decoding
// -----------------------------------------------------------------------------
//
// Convert RAM address to screen coordinates:
//
//   1. Check if address is in screen range (16384-24575)
//   2. Calculate relative address: rel_addr = address - 16384
//   3. Extract row: row = rel_addr / 32
//   4. Extract word in row: word_idx = rel_addr % 32
//   5. Calculate column range: col_start = word_idx × 16
//
// -----------------------------------------------------------------------------
// Pixel Access
// -----------------------------------------------------------------------------
//
// Setting a pixel at (x, y):
//   1. Calculate word address: addr = 16384 + (y × 32) + (x / 16)
//   2. Calculate bit position: bit = 15 - (x % 16)
//   3. Set bit in word: word |= (1 << bit)
//
// Clearing a pixel at (x, y):
//   1. Calculate word address and bit position
//   2. Clear bit in word: word &= ~(1 << bit)
//
// Reading a pixel at (x, y):
//   1. Calculate word address and bit position
//   2. Read bit: pixel = (word >> bit) & 1
//
// -----------------------------------------------------------------------------
// Screen Clearing
// -----------------------------------------------------------------------------
//
// Clear entire screen (all black):
//   - Set all words to 0
//   - All pixels become black
//
// Fill entire screen (all white):
//   - Set all words to 0xFFFF
//   - All pixels become white
//
// -----------------------------------------------------------------------------
// TODO: Implementation
// -----------------------------------------------------------------------------
//
// To implement Screen:
//
//   1. Create Screen struct:
//      pub const Screen = struct {
//          pixels: [256][32]u16, // 256 rows, 32 words per row
//          // ... other fields
//      };
//
//   2. Implement initialization:
//      pub fn init() Screen { ... }
//      pub fn clear(self: *Screen) void { ... }
//
//   3. Implement address validation:
//      pub fn isScreenAddress(address: u16) bool {
//          return address >= 16384 and address <= 24575;
//      }
//
//   4. Implement address decoding:
//      pub fn decodeAddress(address: u16) struct { row: u8, word: u5 } { ... }
//
//   5. Implement word write:
//      pub fn writeWord(self: *Screen, address: u16, value: u16) void { ... }
//
//   6. Implement pixel operations:
//      pub fn setPixel(self: *Screen, x: u16, y: u8) void { ... }
//      pub fn clearPixel(self: *Screen, x: u16, y: u8) void { ... }
//      pub fn getPixel(self: *const Screen, x: u16, y: u8) u1 { ... }
//
//   7. Add rendering support (for emulation):
//      - Convert pixel buffer to display format
//      - Render to screen/window
//
// -----------------------------------------------------------------------------
// Testing Strategy
// -----------------------------------------------------------------------------
//
// Test Screen with:
//
//   1. Address validation:
//      - Valid addresses (16384-24575)
//      - Invalid addresses (below 16384, above 24575)
//
//   2. Address decoding:
//      - Test address to row/word conversion
//      - Test edge cases (first/last addresses)
//
//   3. Word writing:
//      - Write to various addresses
//      - Verify correct word is updated
//
//   4. Pixel operations:
//      - Set individual pixels
//      - Clear individual pixels
//      - Read pixel values
//      - Test pixel boundaries
//
//   5. Screen clearing:
//      - Clear entire screen
//      - Verify all pixels are black
//
//   6. Integration tests:
//      - Write patterns to screen
//      - Verify correct display
//
// -----------------------------------------------------------------------------

const std = @import("std");
const testing = std.testing;

const types = @import("types");
const b13 = types.b13;
const b16 = types.b16;
const fb16 = types.fb16;

const memory = @import("memory").Memory;
const RAM_R_T = @import("memory").Memory_I.RAM_R_T;
const logic = @import("gates").Logic;

// =============================================================================
// Screen - 512×256 Pixel Display
// =============================================================================

/// Screen - 512×256 pixel black-and-white display.
///
/// Built from 1 RAM8K chip (8192 words).
///
/// Memory-mapped I/O device accessed at addresses 16384-24575 (8K words).
/// Each word represents 16 horizontal pixels, stored row-major order.
///
/// Interface:
///   - tick(input, address, load): Write word to screen
///   - peek(address): Read word from screen
///   - setPixel(x, y): Set individual pixel
///   - getPixel(x, y): Get individual pixel
///   - clear(): Clear entire screen (all black)
pub const Screen = struct {
    /// Built from 1 RAM8K chip (8192 words)
    ram8k: memory.Ram8K = .{},

    const Self = @This();

    /// Update Screen with new input, address, and load signal.
    /// Returns the current value at the specified address.
    ///
    /// Address is 13 bits (0-8191), relative to base address 16384.
    /// If load=1, writes input to the addressed word.
    pub fn tick(self: *Self, input: [16]u1, address: [13]u1, load: u1) [16]u1 {
        return self.ram8k.tick(input, address, load);
    }

    /// Get the current value at the specified address without advancing time.
    pub fn peek(self: *const Self, address: [13]u1) [16]u1 {
        return self.ram8k.peek(address);
    }

    pub inline fn getWord(self: *const Self, row: u16, col: u16) struct {
        bool: bool,
        addr: [13]u1,
        value: u16,
        bitpos: u4,
    } {
        if (row >= 256 or col >= 512) return .{ .bool = false, .addr = b13(0), .value = 0, .bitpos = 0 }; // Out of bounds

        // Calculate address: addr = (row × 32) + (col / 16)
        const addr: u13 = @intCast(row * 32 + (col / 16));
        const addr_bits = b13(addr);

        // Read word
        const value = self.ram8k.peek(addr_bits);

        const bitpos: u4 = @truncate(15 - (col % 16));

        return .{ .bool = true, .addr = addr_bits, .value = fb16(value), .bitpos = bitpos };
    }

    /// Set a pixel at coordinates (row, col) to white.
    /// row: 0-255 (row), col: 0-511 (column)
    pub fn setPixel(self: *Self, row: u16, col: u16) bool {
        const current = self.getWord(row, col);
        if (!current.bool) return false;

        // Set the bit
        const new_value = current.value | (@as(u16, 1) << current.bitpos);

        // Write back
        _ = self.ram8k.tick(b16(new_value), current.addr, 1);

        return true;
    }

    /// Clear a pixel at coordinates (row, col) to black.
    pub fn clearPixel(self: *Self, row: u16, col: u16) bool {
        const current = self.getWord(row, col);
        if (!current.bool) return false;

        const new_value = current.value & ~(@as(u16, 1) << current.bitpos);

        // Write back
        _ = self.ram8k.tick(b16(new_value), current.addr, 1);
        return true;
    }

    /// Get pixel value at coordinates (row, col).
    /// Returns 1 for white, 0 for black.
    pub fn getPixel(self: *const Self, row: u16, col: u16) u1 {
        const current = self.getWord(row, col);
        if (!current.bool) return 0;

        return @truncate((current.value >> current.bitpos) & 1);
    }

    /// Clear entire screen (set all pixels to black).
    pub fn clear(self: *Self) void {
        self.ram8k.reset();
    }

    /// Fill entire screen (set all pixels to white).
    pub fn fill(self: *Self) void {
        const white_bits = b16(0xFFFF);

        // Write 0xFFFF to all addresses in RAM8K
        for (0..8192) |i| {
            const addr_bits = b13(@intCast(i));
            _ = self.ram8k.tick(white_bits, addr_bits, 1);
        }
    }

    /// Get pixel data for rendering (reads from RAM8K).
    /// Returns pixel data as a flat array of 8192 words.
    pub fn getPixelBuffer(self: *const Self) [8192]u16 {
        var buffer: [8192]u16 = undefined;

        // Read from RAM8K
        for (0..8192) |i| {
            const addr_bits = b13(@intCast(i));
            buffer[i] = fb16(self.ram8k.peek(addr_bits));
        }

        return buffer;
    }
};

// =============================================================================
// Screen_I - Integer Version (Direct Array Storage)
// =============================================================================

/// Screen_I - 512×256 pixel black-and-white display (integer version).
///
/// Integer version using RAM_R_T(16, 8192) for direct array storage.
/// Uses RAM_R_T for address truncation and memory management.
///
/// Interface:
///   - tick(input, address, load): Write word to screen
///   - peek(address): Read word from screen
///   - setPixel(row, col): Set individual pixel
///   - getPixel(row, col): Get individual pixel
///   - clear(): Clear entire screen (all black)
///   - fill(): Fill entire screen (all white) - optimized for speed
pub const Screen_I = struct {
    /// RAM_R_T(16, 8192): 8192 registers of 16 bits each
    const RAM8192 = RAM_R_T(16, 8192);

    /// Internal RAM storage
    ram: RAM8192 = .{},

    const Self = @This();

    /// Update Screen_I with new input, address, and load signal.
    /// Returns the current value at the specified address.
    ///
    /// Address is 13 bits (0-8191), relative to base address 16384.
    /// If load=1, writes input to the addressed word.
    /// Address truncation is handled by RAM_R_T (wraps around like hardware).
    pub fn tick(self: *Self, input: u16, address: u16, load: u1) u16 {
        return self.ram.tick(input, address, load);
    }

    /// Get the current value at the specified address without advancing time.
    /// Address truncation is handled by RAM_R_T (wraps around like hardware).
    pub fn peek(self: *const Self, address: u16) u16 {
        return self.ram.peek(address);
    }

    /// Get word information for a pixel at coordinates (row, col).
    pub inline fn getWord(self: *const Self, row: u16, col: u16) struct {
        bool: bool,
        addr: u13,
        value: u16,
        bitpos: u4,
    } {
        if (row >= 256 or col >= 512) return .{ .bool = false, .addr = 0, .value = 0, .bitpos = 0 }; // Out of bounds

        // Calculate address: addr = (row × 32) + (col / 16)
        const addr: u13 = @intCast(row * 32 + (col / 16));

        // Read word using RAM_R_T (handles address truncation)
        const value = self.ram.peek(addr);

        const bitpos: u4 = @truncate(15 - (col % 16));

        return .{ .bool = true, .addr = addr, .value = value, .bitpos = bitpos };
    }

    /// Set a pixel at coordinates (row, col) to white.
    /// row: 0-255 (row), col: 0-511 (column)
    pub fn setPixel(self: *Self, row: u16, col: u16) bool {
        const current = self.getWord(row, col);
        if (!current.bool) return false;

        // Set the bit
        const new_value = current.value | (@as(u16, 1) << current.bitpos);

        // Write back using RAM_R_T
        _ = self.ram.tick(new_value, current.addr, 1);

        return true;
    }

    /// Clear a pixel at coordinates (row, col) to black.
    pub fn clearPixel(self: *Self, row: u16, col: u16) bool {
        const current = self.getWord(row, col);
        if (!current.bool) return false;

        const new_value = current.value & ~(@as(u16, 1) << current.bitpos);

        // Write back using RAM_R_T
        _ = self.ram.tick(new_value, current.addr, 1);
        return true;
    }

    /// Get pixel value at coordinates (row, col).
    /// Returns 1 for white, 0 for black.
    pub fn getPixel(self: *const Self, row: u16, col: u16) u1 {
        const current = self.getWord(row, col);
        if (!current.bool) return 0;

        return @truncate((current.value >> current.bitpos) & 1);
    }

    /// Clear entire screen (set all pixels to black).
    pub fn clear(self: *Self) void {
        self.ram.reset();
    }

    /// Fill entire screen (set all pixels to white).
    /// Optimized for speed using direct memory operations.
    pub fn fill(self: *Self) void {
        const memory_ptr = self.ram.getMemory();
        @memset(memory_ptr, 0xFFFF);
    }

    /// Get pixel data for rendering.
    /// Returns a reference to the internal memory array.
    pub fn getPixelBuffer(self: *const Self) *const [8192]u16 {
        return self.ram.getMemory();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "Screen: Screen and Screen_I produce identical results" {
    var screen = Screen{};
    var screen_i = Screen_I{};

    // Test multiple word writes
    const test_values = [_]struct { addr: u13, value: u16 }{
        .{ .addr = 0, .value = 0x1234 },
        .{ .addr = 32, .value = 0x5678 },
        .{ .addr = 100, .value = 0xABCD },
        .{ .addr = 8191, .value = 0xFFFF },
    };

    for (test_values) |tv| {
        const addr_bits = b13(tv.addr);
        const value_bits = b16(tv.value);

        _ = screen.tick(value_bits, addr_bits, 1);
        _ = screen_i.tick(tv.value, tv.addr, 1);

        const screen_result = screen.peek(addr_bits);
        const screen_i_result = screen_i.peek(tv.addr);

        try testing.expectEqual(fb16(screen_result), screen_i_result);
    }

    // Test pixel operations
    const test_pixels = [_]struct { row: u16, col: u16 }{
        .{ .row = 0, .col = 0 },
        .{ .row = 0, .col = 15 },
        .{ .row = 0, .col = 16 },
        .{ .row = 100, .col = 200 },
        .{ .row = 255, .col = 511 },
    };

    for (test_pixels) |tp| {
        // Clear both
        screen.clear();
        screen_i.clear();

        // Set pixel
        try testing.expectEqual(screen.setPixel(tp.row, tp.col), screen_i.setPixel(tp.row, tp.col));
        try testing.expectEqual(screen.getPixel(tp.row, tp.col), screen_i.getPixel(tp.row, tp.col));

        // Clear pixel
        try testing.expectEqual(screen.clearPixel(tp.row, tp.col), screen_i.clearPixel(tp.row, tp.col));
        try testing.expectEqual(screen.getPixel(tp.row, tp.col), screen_i.getPixel(tp.row, tp.col));
    }

    const test_both = false;

    // Test fill - verify all words are 0xFFFF
    if (test_both) {
        screen.fill();
    }
    screen_i.fill();

    for (0..8192) |i| {
        const screen_i_word = screen_i.peek(@intCast(i));
        try testing.expectEqual(@as(u16, 0xFFFF), screen_i_word);

        if (test_both) {
            const addr_bits = b13(@intCast(i));
            const screen_word = fb16(screen.peek(addr_bits));
            try testing.expectEqual(@as(u16, 0xFFFF), screen_word);
            try testing.expectEqual(screen_word, screen_i_word);
        }
    }

    // Test clear - verify all words are 0
    screen.clear();
    screen_i.clear();

    for (0..8192) |i| {
        const screen_i_word = screen_i.peek(@intCast(i));
        try testing.expectEqual(@as(u16, 0), screen_i_word);

        if (test_both) {
            const addr_bits = b13(@intCast(i));
            const screen_word = fb16(screen.peek(addr_bits));
            try testing.expectEqual(@as(u16, 0), screen_word);
            try testing.expectEqual(screen_word, screen_i_word);
        }
    }
}
