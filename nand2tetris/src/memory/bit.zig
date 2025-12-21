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

const logic = @import("gates").Logic;

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
        // MUX selects: in when load=1, dff_out when load=0
        const mux_out = logic.MUX(input, dff_out, load);
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

test "Bit: load=1 stores new value" {
    var bit = Bit{};

    // First tick: load=1, in=1 → stores 1
    try testing.expectEqual(0, bit.tick(1, 1));

    // Second tick: load=1, in=0 → stores 0, outputs previous (1)
    try testing.expectEqual(1, bit.tick(0, 1));

    // Third tick: load=1, in=1 → stores 1, outputs previous (0)
    try testing.expectEqual(0, bit.tick(1, 1));
}

test "Bit: load=0 maintains current value" {
    var bit = Bit{};

    // Set initial value
    _ = bit.tick(1, 1);
    try testing.expectEqual(1, bit.peek());

    // load=0, in changes but value is maintained
    try testing.expectEqual(1, bit.tick(0, 0));
    try testing.expectEqual(1, bit.tick(1, 0));
    try testing.expectEqual(1, bit.tick(0, 0));
    try testing.expectEqual(1, bit.peek());
}

test "Bit: sequence matches expected timeline" {
    var bit = Bit{};

    // Timeline from documentation:
    // Time:     t0   t1   t2   t3   t4   t5   t6
    // in:        1    0    1    1    0    1    0
    // load:      1    0    0    1    1    0    0
    // out:       ?    1    1    1    1    0    0

    const inputs = [_]u1{ 1, 0, 1, 1, 0, 1, 0 };
    const loads = [_]u1{ 1, 0, 0, 1, 1, 0, 0 };
    const expected_outputs = [_]u1{ 0, 1, 1, 1, 1, 0, 0 };

    for (inputs, loads, expected_outputs) |input, load, expected| {
        const output = bit.tick(input, load);
        try testing.expectEqual(expected, output);
    }
}

test "Bit: alternating load behavior" {
    var bit = Bit{};

    // Store 1
    try testing.expectEqual(0, bit.tick(1, 1));
    try testing.expectEqual(1, bit.peek());

    // Hold (load=0, in=0 doesn't matter)
    try testing.expectEqual(1, bit.tick(0, 0));
    try testing.expectEqual(1, bit.peek());

    // Store 0
    try testing.expectEqual(1, bit.tick(0, 1));
    try testing.expectEqual(0, bit.peek());

    // Hold (load=0, in=1 doesn't matter)
    try testing.expectEqual(0, bit.tick(1, 0));
    try testing.expectEqual(0, bit.peek());
}

test "Bit: peek does not advance state" {
    var bit = Bit{};

    _ = bit.tick(1, 1);
    try testing.expectEqual(1, bit.peek());
    try testing.expectEqual(1, bit.peek()); // Still same value

    _ = bit.tick(0, 1);
    try testing.expectEqual(0, bit.peek());
}

test "Bit: reset clears state" {
    var bit = Bit{};

    _ = bit.tick(1, 1);
    _ = bit.tick(1, 1);
    try testing.expectEqual(1, bit.peek());

    bit.reset();
    try testing.expectEqual(0, bit.peek());
    try testing.expectEqual(0, bit.tick(0, 0));
}
