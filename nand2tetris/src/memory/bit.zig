// =============================================================================
// Bit (1-bit Register)
// =============================================================================
//
// A Bit is a single-bit memory cell with a "load" control.
// It's the first useful memory abstraction built on top of DFF.
//
// -----------------------------------------------------------------------------
// The Problem with Raw DFF
// -----------------------------------------------------------------------------
//
// DFF always copies its input to output after one cycle.
// But we want CONTROLLABLE memory:
// - Sometimes: "remember the new value" (write)
// - Sometimes: "keep the old value" (hold)
//
// -----------------------------------------------------------------------------
// Bit Interface
// -----------------------------------------------------------------------------
//
// Inputs:
//   in   (1 bit) - the value to potentially store
//   load (1 bit) - control signal: 1 = store new value, 0 = keep current
//
// Output:
//   out  (1 bit) - the currently stored value
//
// -----------------------------------------------------------------------------
// Bit Behavior
// -----------------------------------------------------------------------------
//
// if load(t-1) == 1:
//     out(t) = in(t-1)    // store the new value
// else:
//     out(t) = out(t-1)   // maintain the current value
//
// Example timeline:
//
// Time:     t0   t1   t2   t3   t4   t5   t6
// in:        1    0    1    1    0    1    0
// load:      1    0    0    1    1    0    0
// out:       ?    1    1    1    1    0    0
//                 ↑              ↑    ↑
//                 loaded 1     loaded 1  loaded 0
//
// When load=0, the Bit ignores 'in' and keeps outputting its stored value.
// When load=1, the Bit captures 'in' and outputs it starting next cycle.
//
// -----------------------------------------------------------------------------
// Implementation Strategy
// -----------------------------------------------------------------------------
//
// The key insight: use a MUX to choose between:
// - The current stored value (feedback from DFF output)
// - The new input value
//
//                   load
//                    │
//                    ▼
//           ┌───────────────┐
//   in ────►│               │
//           │      MUX      ├──────┐
//     ┌────►│               │      │
//     │     └───────────────┘      │
//     │                            ▼
//     │                      ┌───────────┐
//     │                      │           │
//     └──────────────────────┤    DFF    ├────► out
//              feedback      │           │
//                            └───────────┘
//
// Pseudocode:
//   mux_out = Mux(a=dff_out, b=in, sel=load)
//   dff_out = DFF(mux_out)
//   out = dff_out
//
// When load=0: MUX selects dff_out → DFF stores its own output → value preserved
// When load=1: MUX selects in → DFF stores new input → value updated
//
// -----------------------------------------------------------------------------
// Bit as Building Block
// -----------------------------------------------------------------------------
//
// The Bit is crucial because it adds the CONTROL concept to memory.
// We can now decide WHEN to store, not just store every cycle.
//
// 16 Bits → 16-bit Register
// 8 Registers → RAM8
// And so on...
//

const std = @import("std");
const testing = std.testing;

const dff = @import("dff.zig");

const logic = @import("logic").Logic;

/// Bit - a 1-bit register with load control.
///
/// A Bit adds the CONTROL concept to memory - we can decide WHEN to store,
/// not just store every cycle like a raw DFF.
///
/// Behavior:
///   if load(t-1) == 1: out(t) = in(t-1)    // store new value
///   else:              out(t) = out(t-1)   // maintain current value
pub const Bit = struct {
    dff: dff.DFF = .{},

    /// Update the Bit with new input and load signal.
    /// Returns the current output.
    ///
    /// This function represents one clock cycle:
    /// - If load=1: stores the new input value
    /// - If load=0: maintains the current stored value
    pub fn tick(self: *Bit, input: u1, load: u1) u1 {
        const dff_out = self.dff.peek();
        // MUX selects: input when load=1, dff_out when load=0
        const mux_out = logic.MUX(dff_out, input, load);
        return self.dff.tick(mux_out);
    }

    /// Get the current output without advancing time.
    pub fn peek(self: *const Bit) u1 {
        return self.dff.peek();
    }

    /// Reset the Bit to initial state (outputs 0).
    pub fn reset(self: *Bit) void {
        self.dff.reset();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "Bit: comprehensive behavior test" {
    const TestCase = struct {
        input: u1,
        load: u1,
        expected_output: u1,
        expected_peek: u1,
    };

    var bit = Bit{};

    // Initial state: output is 0
    try testing.expectEqual(0, bit.peek());

    // Test cases: load=1 stores new value, load=0 maintains current value
    const tick_cases = [_]TestCase{
        .{ .input = 1, .load = 1, .expected_output = 0, .expected_peek = 1 }, // First tick outputs previous (0), stores 1
        .{ .input = 0, .load = 1, .expected_output = 1, .expected_peek = 0 }, // Outputs previous (1), stores 0
        .{ .input = 1, .load = 1, .expected_output = 0, .expected_peek = 1 }, // Outputs previous (0), stores 1
        .{ .input = 0, .load = 0, .expected_output = 1, .expected_peek = 1 }, // Outputs current (1), maintains 1
        .{ .input = 1, .load = 0, .expected_output = 1, .expected_peek = 1 }, // Outputs current (1), maintains 1
    };

    std.debug.print("\n=== Bit: load=1 stores, load=0 maintains ===\n", .{});
    std.debug.print("Time | Input | Load | Output | Stored\n", .{});
    std.debug.print("-----|-------|------|--------|-------\n", .{});

    var time: u32 = 0;
    for (tick_cases) |tc| {
        const output = bit.tick(tc.input, tc.load);
        try testing.expectEqual(tc.expected_output, output);
        try testing.expectEqual(tc.expected_peek, bit.peek());
        std.debug.print("  t{d} |   {d}   |  {d}   |   {d}    |   {d}\n", .{ time, tc.input, tc.load, output, bit.peek() });
        time += 1;
    }
    std.debug.print("\n", .{});

    // Timeline sequence from documentation
    // Time:     t0   t1   t2   t3   t4   t5   t6
    // in:        1    0    1    1    0    1    0
    // load:      1    0    0    1    1    0    0
    // out:       0    1    1    1    1    0    0
    bit.reset();
    const timeline_cases = [_]TestCase{
        .{ .input = 1, .load = 1, .expected_output = 0, .expected_peek = 1 },
        .{ .input = 0, .load = 0, .expected_output = 1, .expected_peek = 1 },
        .{ .input = 1, .load = 0, .expected_output = 1, .expected_peek = 1 },
        .{ .input = 1, .load = 1, .expected_output = 1, .expected_peek = 1 },
        .{ .input = 0, .load = 1, .expected_output = 1, .expected_peek = 0 },
        .{ .input = 1, .load = 0, .expected_output = 0, .expected_peek = 0 },
        .{ .input = 0, .load = 0, .expected_output = 0, .expected_peek = 0 },
    };

    std.debug.print("=== Bit: Timeline sequence ===\n", .{});
    std.debug.print("Time | Input | Load | Output | Stored\n", .{});
    std.debug.print("-----|-------|------|--------|-------\n", .{});

    time = 0;
    for (timeline_cases) |tc| {
        const output = bit.tick(tc.input, tc.load);
        try testing.expectEqual(tc.expected_output, output);
        try testing.expectEqual(tc.expected_peek, bit.peek());
        std.debug.print("  t{d} |   {d}   |  {d}   |   {d}    |   {d}\n", .{ time, tc.input, tc.load, output, bit.peek() });
        time += 1;
    }
    std.debug.print("\n", .{});

    // Test peek does not advance state
    bit.reset();
    try testing.expectEqual(0, bit.peek());
    _ = bit.tick(1, 1);
    try testing.expectEqual(1, bit.peek());
    _ = bit.tick(0, 1);
    try testing.expectEqual(0, bit.peek());
}
