// =============================================================================
// Keyboard (Memory-Mapped I/O)
// -----------------------------------------------------------------------------
//
// The Keyboard is a memory-mapped I/O device that provides keyboard input.
// It is accessed as RAM address 24576 (single word).
//
// -----------------------------------------------------------------------------
// Keyboard Overview
// -----------------------------------------------------------------------------
//
// The Keyboard is an input device that:
//   - Provides keyboard input to the computer
//   - Memory-mapped: Accessed via RAM address 24576
//   - Single word: Only one 16-bit value
//   - Read-only from CPU perspective: CPU reads, doesn't write
//
// Key characteristics:
//   - Memory-mapped I/O: Appears as regular RAM to the CPU
//   - Read-only: CPU reads key code, cannot write
//   - ASCII encoding: Key codes are ASCII character codes
//   - Polling: CPU must poll address 24576 to check for key press
//
// -----------------------------------------------------------------------------
// Keyboard Memory Map
// -----------------------------------------------------------------------------
//
// Memory address:
//   - Address: 24576 (0x6000)
//   - Single word: Only one 16-bit value
//
// Key code format:
//   - 16-bit value representing ASCII character code
//   - 0 = no key pressed
//   - Non-zero = ASCII code of pressed key
//
// -----------------------------------------------------------------------------
// Keyboard Interface
// -----------------------------------------------------------------------------
//
// Inputs (from external system):
//   key_code[16] - ASCII code of currently pressed key (0 = no key)
//
// Outputs (to CPU via RAM):
//   out[16] - Current key code at address 24576
//
// Note: The CPU accesses Keyboard via RAM, so the interface is:
//   - CPU reads RAM[24576] to get current key code
//   - RAM routes reads to Keyboard when address is 24576
//
// -----------------------------------------------------------------------------
// Key Code Values
// -----------------------------------------------------------------------------
//
// Key code encoding:
//   - 0 = No key pressed
//   - 1-127 = ASCII character code
//   - Common keys:
//     * 32 = Space
//     * 13 = Enter (Carriage Return)
//     * 8 = Backspace
//     * 27 = Escape
//     * 48-57 = '0'-'9'
//     * 65-90 = 'A'-'Z'
//     * 97-122 = 'a'-'z'
//
// Special keys:
//   - Arrow keys, function keys, etc. may use extended codes
//   - Implementation dependent
//
// -----------------------------------------------------------------------------
// Keyboard Operations
// -----------------------------------------------------------------------------
//
// Reading key press:
//   1. CPU sets A register to 24576
//   2. CPU executes C-instruction: D=M (read RAM[24576])
//   3. RAM routes read to Keyboard
//   4. Keyboard returns current key code
//   5. CPU checks if key code is non-zero
//
// Polling pattern:
//   @KBD
//   D=M
//   @LOOP
//   D;JEQ    // Loop if no key pressed
//   // Key was pressed, process it
//
// -----------------------------------------------------------------------------
// Key State
// -----------------------------------------------------------------------------
//
// Keyboard state:
//   - Current key code (0 = no key, non-zero = key code)
//   - Updated by external system (user input, emulator, etc.)
//   - CPU can only read, cannot modify
//
// Key press detection:
//   - CPU must poll address 24576
//   - Compare value to 0 to detect key press
//   - Compare to specific ASCII codes to detect specific keys
//
// -----------------------------------------------------------------------------
// Implementation Structure
// -----------------------------------------------------------------------------
//
// This module will be organized as:
//
//   keyboard.zig (this file):
//     - Keyboard struct
//     - Key code storage
//     - Read operation
//     - Key press detection helpers
//
// -----------------------------------------------------------------------------
// Keyboard Implementation
// -----------------------------------------------------------------------------
//
// Implementation options:
//
//   1. Simple value:
//      - Store current key code as u16
//      - Simple and direct
//      - Easy to update
//
//   2. State machine:
//      - Track key press/release events
//      - More complex, but enables event handling
//
// Recommended: Simple value for Hack computer simplicity.
//
// -----------------------------------------------------------------------------
// Address Validation
// -----------------------------------------------------------------------------
//
// Keyboard address:
//   - Must be exactly 24576
//   - Other addresses are not keyboard
//   - RAM handles routing based on address
//
// Implementation:
//   - Check if address == 24576
//   - Return key code if address matches
//   - Return 0 or error if address doesn't match
//
// -----------------------------------------------------------------------------
// Key Code Updates
// -----------------------------------------------------------------------------
//
// Key code is updated by external system:
//   - User presses key → update key code
//   - User releases key → set key code to 0
//   - Emulator/simulator provides key events
//
// In emulation:
//   - Keyboard receives key events from input system
//   - Updates internal key code value
//   - CPU reads current value when accessing address 24576
//
// -----------------------------------------------------------------------------
// TODO: Implementation
// -----------------------------------------------------------------------------
//
// To implement Keyboard:
//
//   1. Create Keyboard struct:
//      pub const Keyboard = struct {
//          key_code: u16 = 0, // Current key code (0 = no key)
//          // ... other fields
//      };
//
//   2. Implement initialization:
//      pub fn init() Keyboard { ... }
//
//   3. Implement address check:
//      pub fn isKeyboardAddress(address: u16) bool {
//          return address == 24576;
//      }
//
//   4. Implement read operation:
//      pub fn read(self: *const Keyboard) u16 {
//          return self.key_code;
//      }
//
//   5. Implement key update (for emulation):
//      pub fn setKey(self: *Keyboard, key_code: u16) void {
//          self.key_code = key_code;
//      }
//
//   6. Implement key press detection helpers:
//      pub fn isKeyPressed(self: *const Keyboard) bool {
//          return self.key_code != 0;
//      }
//
//      pub fn getKeyCode(self: *const Keyboard) u16 {
//          return self.key_code;
//      }
//
//   7. Add key event handling (for emulation):
//      - Handle key press events
//      - Handle key release events
//      - Map physical keys to ASCII codes
//
// -----------------------------------------------------------------------------
// Testing Strategy
// -----------------------------------------------------------------------------
//
// Test Keyboard with:
//
//   1. Initialization:
//      - Verify initial state (key_code = 0)
//
//   2. Key code updates:
//      - Set various key codes
//      - Verify correct values are stored
//
//   3. Read operations:
//      - Read key code
//      - Verify correct value returned
//
//   4. Key press detection:
//      - Test isKeyPressed() with various codes
//      - Test with key code 0 (no key)
//      - Test with non-zero codes (key pressed)
//
//   5. Address validation:
//      - Test isKeyboardAddress() with valid address (24576)
//      - Test with invalid addresses
//
//   6. Integration tests:
//      - Simulate key press/release
//      - Verify CPU can read key codes
//      - Test keyboard polling pattern
//
// -----------------------------------------------------------------------------

const std = @import("std");
const testing = std.testing;

const types = @import("types");
const b16 = types.b16;
const fb16 = types.fb16;

const memory = @import("memory").Memory;
const memory_i = @import("memory").Memory_I;

// =============================================================================
// Keyboard - Memory-Mapped Input Device
// =============================================================================

/// Keyboard - Memory-mapped I/O device for keyboard input.
///
/// Implemented as a 16-bit register that holds the current key code.
/// Accessed at address 24576 (0x6000). Read-only from CPU perspective.
/// Returns ASCII key code (0 = no key pressed, non-zero = key code).
///
/// Interface:
///   - read(): Read current key code
///   - setKey(key_code): Set key code (for emulation)
///   - isKeyPressed(): Check if any key is pressed
pub const Keyboard = struct {
    /// 16-bit register holding the current key code
    register: memory.Register16 = .{},

    const Self = @This();

    /// Read current key code.
    /// Returns the ASCII code of the currently pressed key, or 0 if no key is pressed.
    pub fn read(self: *const Self) [16]u1 {
        return self.register.peek();
    }

    /// Set the current key code (for emulation/simulation).
    /// Typically called by the emulator when a key is pressed or released.
    /// This updates the register by ticking it with load=1.
    pub fn setKey(self: *Self, key_code: u16) void {
        const key_bits = b16(key_code);
        _ = self.register.tick(key_bits, 1);
    }

    /// Unset the current key code (for emulation).
    /// Sets the key code to 0 (no key pressed).
    pub inline fn unsetKey(self: *Self) void {
        self.setKey(0);
    }

    /// Get the current key code as an integer.
    pub fn getKeyCode(self: *const Self) u16 {
        const key_bits = self.register.peek();
        return fb16(key_bits);
    }

    /// Reset keyboard to initial state (no key pressed).
    pub fn reset(self: *Self) void {
        self.register.reset();
    }
};

// =============================================================================
// Keyboard_I - Integer Version
// =============================================================================

/// Keyboard_I - Memory-mapped I/O device for keyboard input (integer version).
///
/// Integer version using direct u16 storage for faster operations.
/// Uses Register16_I for direct integer access, avoiding hardware simulation overhead.
///
/// Interface:
///   - read(): Read current key code
///   - setKey(key_code): Set key code (for emulation)
///   - isKeyPressed(): Check if any key is pressed
pub const Keyboard_I = struct {
    /// 16-bit register holding the current key code (integer version)
    register: memory_i.Register16 = .{},

    const Self = @This();

    /// Read current key code.
    /// Returns the ASCII code of the currently pressed key, or 0 if no key is pressed.
    pub fn read(self: *const Self) u16 {
        return self.register.peek();
    }

    /// Set the current key code (for emulation/simulation).
    /// Typically called by the emulator when a key is pressed or released.
    /// This updates the register by ticking it with load=1.
    pub fn setKey(self: *Self, key_code: u16) void {
        _ = self.register.tick(key_code, 1);
    }

    /// Unset the current key code (for emulation).
    /// Sets the key code to 0 (no key pressed).
    pub inline fn unsetKey(self: *Self) void {
        self.setKey(0);
    }

    /// Get the current key code as an integer.
    pub fn getKeyCode(self: *const Self) u16 {
        return self.register.peek();
    }

    /// Reset keyboard to initial state (no key pressed).
    pub fn reset(self: *Self) void {
        self.register.reset();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "Keyboard and Keyboard_I produce identical results" {
    var kbd = Keyboard{};
    var kbd_i = Keyboard_I{};

    const test_keys = [_]u16{ 0, 65, 32, 13, 97, 255, 0xFFFF, 0 };

    for (test_keys) |key_code| {
        kbd.setKey(key_code);
        kbd_i.setKey(key_code);

        const kbd_value = fb16(kbd.read());
        const kbd_i_value = kbd_i.read();

        try testing.expectEqual(kbd_value, kbd_i_value);
        try testing.expectEqual(kbd.getKeyCode(), kbd_i.getKeyCode());
    }

    // Test reset
    kbd.reset();
    kbd_i.reset();
    try testing.expectEqual(kbd.getKeyCode(), kbd_i.getKeyCode());
}
