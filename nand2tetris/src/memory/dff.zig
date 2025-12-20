// =============================================================================
// Data Flip-Flop (DFF)
// =============================================================================
//
// The DFF is the fundamental building block of sequential logic.
// Unlike combinational logic (gates), sequential logic has STATE - it remembers.
//
// -----------------------------------------------------------------------------
// CONCEPT: Time in Digital Circuits
// -----------------------------------------------------------------------------
//
// - Combinational circuits: output depends ONLY on current inputs
//   Example: AND(a, b) = a AND b (instantly)
//
// - Sequential circuits: output depends on current inputs AND previous state
//   Example: DFF remembers what happened in the previous clock cycle
//
// -----------------------------------------------------------------------------
// What is a Clock?
// -----------------------------------------------------------------------------
//
//     ┌───┐   ┌───┐   ┌───┐   ┌───┐
//     │   │   │   │   │   │   │   │
// ────┘   └───┘   └───┘   └───┘   └───
//     t0  t1  t2  t3  t4  t5  t6  t7
//
// - The clock is a periodic signal oscillating between 0 and 1
// - Each cycle (low→high→low) represents one discrete time unit
// - All sequential chips update their state at the clock edge (usually rising)
//
// -----------------------------------------------------------------------------
// DFF Behavior
// -----------------------------------------------------------------------------
//
// Interface:
//   Input:  in (1 bit)
//   Output: out (1 bit)
//
// Behavior:
//   out(t) = in(t-1)
//
// The output at time t equals the input at time t-1.
// In other words: the DFF outputs whatever was fed into it in the PREVIOUS cycle.
//
// Time:    t0   t1   t2   t3   t4   t5
// in:       1    0    1    1    0    1
// out:      ?    1    0    1    1    0
//           ↑
//           (undefined or 0 at start)
//
// -----------------------------------------------------------------------------
// Why DFF is Primitive
// -----------------------------------------------------------------------------
//
// In Nand2Tetris, DFF is treated as a PRIMITIVE (given, not built).
//
// In reality, DFFs are built from NAND gates in a clever feedback loop.
// Common implementations:
// - Master-Slave D Flip-Flop (two latches)
// - Edge-triggered D Flip-Flop
//
// The feedback creates a stable memory cell:
//
//     ┌─────────────────┐
//     │   ┌───┐  ┌───┐  │
// in ─┼──►│   ├──►│   ├─┼─► out
//     │   │ L │  │ L │  │
// clk─┼──►│   │  │   │◄─┘
//     │   └───┘  └───┘
//     │   Master  Slave
//     └─────────────────────
//
// We accept DFF as given because:
// 1. Its implementation requires understanding analog timing issues
// 2. The course focuses on digital abstraction
// 3. Every computer uses some form of flip-flop as the base memory element
//
// -----------------------------------------------------------------------------
// DFF as the Atom of Memory
// -----------------------------------------------------------------------------
//
// Everything sequential in a computer is built from DFFs:
//
// DFF → Bit → Register → RAM → CPU registers, caches, memory
//
// One DFF stores exactly ONE bit of information across clock cycles.
//

const std = @import("std");
const testing = std.testing;

/// Data Flip-Flop - the fundamental sequential logic primitive.
///
/// Behavior: out(t) = in(t-1)
/// The output at time t equals the input at time t-1.
///
/// The clock is implicit - each call to `tick()` represents one clock cycle.
pub const DFF = struct {
    /// Internal state: stores the input from the previous cycle
    state: u1 = 0,

    /// Update the DFF with a new input value.
    /// Returns the output (which is the previous input).
    ///
    /// This function represents one clock cycle:
    /// - Outputs the value stored from the previous cycle
    /// - Stores the new input for the next cycle
    pub fn tick(self: *DFF, input: u1) u1 {
        const output = self.state; // out(t) = in(t-1)
        self.state = input; // Store input for next cycle
        return output;
    }

    /// Get the current output without advancing time.
    /// Useful for reading the state without ticking.
    pub fn peek(self: *const DFF) u1 {
        return self.state;
    }

    /// Reset the DFF to initial state (outputs 0).
    pub fn reset(self: *DFF) void {
        self.state = 0;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "DFF: basic behavior - out(t) = in(t-1)" {
    var dff = DFF{};

    // First tick: output is undefined/0 initially, stores input=1
    try testing.expectEqual(0, dff.tick(1));

    // Second tick: outputs previous input (1), stores new input (0)
    try testing.expectEqual(1, dff.tick(0));

    // Third tick: outputs previous input (0), stores new input (1)
    try testing.expectEqual(0, dff.tick(1));

    // Fourth tick: outputs previous input (1), stores new input (1)
    try testing.expectEqual(1, dff.tick(1));

    // Fifth tick: outputs previous input (1), stores new input (0)
    try testing.expectEqual(1, dff.tick(0));
}

test "DFF: reset clears state" {
    var dff = DFF{};

    _ = dff.tick(1);
    _ = dff.tick(1);
    try testing.expectEqual(1, dff.peek());

    dff.reset();
    try testing.expectEqual(0, dff.peek());
    try testing.expectEqual(0, dff.tick(0));
}

test "DFF: debug print - demonstrates out(t) = in(t-1)" {
    var dff = DFF{};

    // Note: To see these print statements, run the test executable directly:
    //   zig build install && ./zig-out/bin/test
    // NOT: zig build test (which suppresses all output)

    std.debug.print("\n=== DFF Debug Test: out(t) = in(t-1) ===\n", .{});
    std.debug.print("Time | Input | Output (previous input) | State\n", .{});
    std.debug.print("-----|-------|------------------------|-------\n", .{});

    const inputs = [_]u1{ 1, 0, 1, 1, 0, 1 };
    var time: u32 = 0;

    for (inputs) |input| {
        const output = dff.tick(input);
        std.debug.print("  t{d} |   {d}   |          {d}              |   {d}\n", .{ time, input, output, dff.peek() });
        time += 1;
    }

    std.debug.print("\nKey insight: Output at time t equals input at time t-1\n", .{});
    std.debug.print("Example: At t1, input=0 but output=1 (from t0's input)\n\n", .{});
}

test "memory module: include all memory tests" {
    // Import other memory files to ensure their tests are included in the memory module
    _ = @import("bit.zig");
    // Add other memory files here as they're implemented
    // _ = @import("register.zig");
    // _ = @import("ram.zig");
    // _ = @import("pc.zig");
}
