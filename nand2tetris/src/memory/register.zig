// =============================================================================
// Register (16-bit Register)
// =============================================================================
//
// A Register stores a 16-bit value (a "word" in Hack computer terminology).
// It's simply 16 Bit chips operating in parallel.
//
// -----------------------------------------------------------------------------
// Register Interface
// -----------------------------------------------------------------------------
//
// Inputs:
//   in[16] - 16-bit value to potentially store
//   load   - control signal: 1 = store, 0 = hold
//
// Output:
//   out[16] - the currently stored 16-bit value
//
// -----------------------------------------------------------------------------
// Register Behavior
// -----------------------------------------------------------------------------
//
// if load(t-1) == 1:
//     out(t) = in(t-1)    // store the new 16-bit value
// else:
//     out(t) = out(t-1)   // maintain current value
//
// Exactly like Bit, but for 16 bits at once.
//
// -----------------------------------------------------------------------------
// Implementation
// -----------------------------------------------------------------------------
//
// Dead simple: 16 Bit chips in parallel, all sharing the same load signal.
//
//   in[0] ──► Bit ──► out[0]
//   in[1] ──► Bit ──► out[1]
//   in[2] ──► Bit ──► out[2]
//     ...     ...     ...
//   in[15]──► Bit ──► out[15]
//              ▲
//              │
//            load (shared by all 16 Bits)
//
// Each Bit handles one position independently.
// The load signal controls ALL bits together - we store the whole word or nothing.
//
// -----------------------------------------------------------------------------
// Why 16 Bits?
// -----------------------------------------------------------------------------
//
// The Hack computer uses 16-bit words throughout:
// - 16-bit data bus
// - 16-bit instructions
// - 16-bit addresses (can address 2^16 = 65,536 memory locations)
//
// This is a design choice. Real computers use various word sizes:
// - Early computers: 8-bit, 12-bit, 18-bit, 36-bit
// - Modern: 32-bit, 64-bit
//
// -----------------------------------------------------------------------------
// Register vs CPU Register
// -----------------------------------------------------------------------------
//
// Don't confuse this memory Register with CPU registers (like A, D in Hack).
//
// - Memory Register: generic storage unit in RAM
// - CPU Register: special-purpose, hardwired into the processor
//
// Both use the same underlying Bit/DFF technology, but CPU registers are
// directly connected to the ALU and have special roles in instruction execution.
//
// In the Hack CPU:
// - A Register: holds address or data
// - D Register: holds data for computation
// - PC: Program Counter (special register, covered separately)
//

const std = @import("std");
const testing = std.testing;

const bit = @import("bit.zig");
const gates = @import("gates");
const logic = gates.Logic;

const types = @import("types");
const b4 = types.b4;
const b8 = types.b8;
const b16 = types.b16;
const fb2 = types.fb2;
const fb3 = types.fb3;
const fb4 = types.fb4;
const fb8 = types.fb8;
const fb16 = types.fb16;

/// Generic N-bit Register - stores an N-bit value with load control.
///
/// Built from N Bit chips operating in parallel, all sharing the same load signal.
///
/// Behavior:
///   if load(t-1) == 1: out(t) = in(t-1)    // store new value
///   else:              out(t) = out(t-1)   // maintain current value
pub fn Register(comptime N: u8) type {
    return struct {
        bits: [N]bit.Bit = [_]bit.Bit{.{}} ** N,

        const Self = @This();

        /// Update the Register with new input and load signal.
        /// Returns the current output.
        ///
        /// This function represents one clock cycle:
        /// - If load=1: stores the new input value
        /// - If load=0: maintains the current stored value
        pub fn tick(self: *Self, input: [N]u1, load: u1) [N]u1 {
            var output: [N]u1 = undefined;
            inline for (0..N) |i| {
                output[i] = self.bits[i].tick(input[i], load);
            }
            return output;
        }

        /// Get the current output without advancing time.
        pub fn peek(self: *const Self) [N]u1 {
            var output: [N]u1 = undefined;
            inline for (0..N) |i| {
                output[i] = self.bits[i].peek();
            }
            return output;
        }

        /// Reset the Register to initial state (all bits set to 0).
        pub fn reset(self: *Self) void {
            inline for (0..N) |i| {
                self.bits[i].reset();
            }
        }
    };
}

/// 16-bit Register - stores a 16-bit word (Hack computer standard).
///
/// This is the standard word size used throughout the Hack computer:
/// - 16-bit data bus
/// - 16-bit instructions
/// - 16-bit addresses (can address 2^16 = 65,536 memory locations)
pub const Register16 = Register(16);

// =============================================================================
// Register_I - Integer Version (using UIntN)
// =============================================================================

/// Generic N-bit Register (Integer Version) - stores an N-bit value with load control.
///
/// Integer version using UIntN(N) instead of bit arrays.
/// More efficient than bit-array version for performance-critical code.
///
/// Behavior:
///   if load(t-1) == 1: out(t) = in(t-1)    // store new value
///   else:              out(t) = out(t-1)   // maintain current value
pub fn Register_I(comptime N: u8) type {
    const UIntType = types.UIntN(N);

    return struct {
        stored_value: UIntType = 0,

        const Self = @This();

        /// Update the Register with new input and load signal.
        /// Returns the current output (stored value).
        ///
        /// This function represents one clock cycle:
        /// - Output is always the current stored value
        /// - If load=1: stores the new input value (will be output on next tick)
        /// - If load=0: maintains the current stored value
        pub fn tick(self: *Self, input: UIntType, load: u1) UIntType {
            // Output is the current stored value
            const output = self.stored_value;

            // Update stored value based on load signal
            if (load == 1) {
                self.stored_value = input;
            }
            // else: stored_value remains unchanged

            return output;
        }

        /// Get the current output without advancing time.
        pub fn peek(self: *const Self) UIntType {
            return self.stored_value;
        }

        /// Reset the Register to initial state (all bits set to 0).
        pub fn reset(self: *Self) void {
            self.stored_value = 0;
        }
    };
}

/// 16-bit Register (Integer Version) - stores a 16-bit word.
///
/// Integer version using u16 instead of [16]u1 bit arrays.
pub const Register16_I = Register_I(16);

// =============================================================================
// Tests
// =============================================================================

test "Register16: comprehensive behavior test" {
    const TestCase = struct {
        input: u16,
        load: u1,
        expected_output: u16,
        expected_peek: u16,
    };

    var reg = Register16{};
    var reg_i = Register16_I{};

    // Test cases covering all behaviors
    const test_cases = [_]TestCase{
        // Basic behavior: load=1 stores new value
        .{ .input = 0x1234, .load = 1, .expected_output = 0, .expected_peek = 0x1234 }, // First tick: initially 0
        .{ .input = 0x5678, .load = 1, .expected_output = 0x1234, .expected_peek = 0x5678 }, // Outputs previous, stores new
        .{ .input = 0x9ABC, .load = 0, .expected_output = 0x5678, .expected_peek = 0x5678 }, // load=0 maintains value
        .{ .input = 0xDEF0, .load = 0, .expected_output = 0x5678, .expected_peek = 0x5678 }, // Still maintains
        .{ .input = 0xABCD, .load = 1, .expected_output = 0x5678, .expected_peek = 0xABCD }, // Store new value
        .{ .input = 0x0000, .load = 0, .expected_output = 0xABCD, .expected_peek = 0xABCD }, // Maintains
        .{ .input = 0xFFFF, .load = 0, .expected_output = 0xABCD, .expected_peek = 0xABCD }, // Still maintains
        // Bit pattern tests: all bits operate independently
        .{ .input = 0xAAAA, .load = 1, .expected_output = 0xABCD, .expected_peek = 0xAAAA }, // Alternating pattern
        .{ .input = 0x5555, .load = 1, .expected_output = 0xAAAA, .expected_peek = 0x5555 }, // Opposite pattern
    };

    std.debug.print("\n=== Register16: load=1 stores, load=0 maintains ===\n", .{});
    std.debug.print("Time | Load | Input    | Output (previous input) | Stored\n", .{});
    std.debug.print("-----|------|----------|------------------------|--------\n", .{});

    var time: u32 = 0;
    for (test_cases) |tc| {
        const input_bits = b16(tc.input);
        const output_bits = reg.tick(input_bits, tc.load);
        const output_i = reg_i.tick(tc.input, tc.load);

        try testing.expectEqual(tc.expected_output, fb16(output_bits));
        try testing.expectEqual(fb16(output_bits), output_i);
        try testing.expectEqual(tc.expected_peek, fb16(reg.peek()));
        try testing.expectEqual(fb16(reg.peek()), reg_i.peek());

        std.debug.print("  t{d} |  {d}   | 0x{X:04}  |        0x{X:04}          | 0x{X:04}\n", .{ time, tc.load, tc.input, fb16(output_bits), fb16(reg.peek()) });
        time += 1;
    }
    std.debug.print("\nKey insight: Output at time t equals input at time t-1 (when load=1)\n", .{});
    std.debug.print("When load=0, the register maintains its current value\n\n", .{});

    // Test peek does not advance state
    try testing.expectEqual(@as(u16, 0x5555), fb16(reg.peek()));
    try testing.expectEqual(fb16(reg.peek()), reg_i.peek());
    try testing.expectEqual(@as(u16, 0x5555), fb16(reg.peek())); // Still same value
    try testing.expectEqual(fb16(reg.peek()), reg_i.peek());

    // Test reset clears all bits
    reg.reset();
    reg_i.reset();
    try testing.expectEqual(@as(u16, 0), fb16(reg.peek()));
    try testing.expectEqual(fb16(reg.peek()), reg_i.peek());
    try testing.expectEqual(@as(u16, 0), fb16(reg.tick(b16(0), 0)));
    try testing.expectEqual(fb16(reg.tick(b16(0), 0)), reg_i.tick(0, 0));
}

test "Register: generic N-bit register works for different sizes" {
    // Test 4-bit register
    const Reg4 = Register(4);
    const Reg4_I = Register_I(4);
    var reg4 = Reg4{};
    var reg4_i = Reg4_I{};

    const input4 = b4(0b1010);
    _ = reg4.tick(input4, 1);
    _ = reg4_i.tick(0b1010, 1);
    try testing.expectEqual(@as(u4, 0b1010), fb4(reg4.peek()));
    try testing.expectEqual(fb4(reg4.peek()), reg4_i.peek());

    // Test 8-bit register
    const Reg8 = Register(8);
    const Reg8_I = Register_I(8);
    var reg8 = Reg8{};
    var reg8_i = Reg8_I{};

    const input8 = b8(0xAB);
    _ = reg8.tick(input8, 1);
    _ = reg8_i.tick(0xAB, 1);
    try testing.expectEqual(@as(u8, 0xAB), fb8(reg8.peek()));
    try testing.expectEqual(fb8(reg8.peek()), reg8_i.peek());
}
