// =============================================================================
// PC (Program Counter)
// =============================================================================
//
// The Program Counter is a special-purpose register that holds the address
// of the next instruction to execute. It's the heart of program flow control.
//
// -----------------------------------------------------------------------------
// Why We Need a Program Counter
// -----------------------------------------------------------------------------
//
// Programs are sequences of instructions stored in memory:
//
//   Address | Instruction
//   --------|------------
//   0       | load A
//   1       | add B
//   2       | store C
//   3       | jump to 10
//   ...     | ...
//
// The CPU needs to know: "Which instruction should I execute NOW?"
// The PC provides this answer. After executing each instruction, the PC
// typically increments to point to the next instruction.
//
// -----------------------------------------------------------------------------
// PC Interface
// -----------------------------------------------------------------------------
//
// Inputs:
//   in[16]  - value to load (for jumps)
//   load    - if 1, load 'in' into PC (jump to address)
//   inc     - if 1, increment PC by 1 (normal sequential execution)
//   reset   - if 1, set PC to 0 (restart program)
//
// Output:
//   out[16] - current PC value (address of next instruction)
//
// -----------------------------------------------------------------------------
// PC Behavior (Priority Order)
// -----------------------------------------------------------------------------
//
// The control signals have priority (evaluated in this order):
//
// if reset(t-1) == 1:
//     out(t) = 0              // restart from beginning
// else if load(t-1) == 1:
//     out(t) = in(t-1)        // jump to specified address
// else if inc(t-1) == 1:
//     out(t) = out(t-1) + 1   // move to next instruction
// else:
//     out(t) = out(t-1)       // stay (pause/halt)
//
// Priority matters! If reset=1, we go to 0 regardless of load or inc.
//
// -----------------------------------------------------------------------------
// Example Timeline
// -----------------------------------------------------------------------------
//
// Time:     t0   t1   t2   t3   t4   t5   t6   t7
// in:       --   --   --  100   --   --   --   --
// reset:     1    0    0    0    0    0    1    0
// load:      0    0    0    1    0    0    0    0
// inc:       0    1    1    0    1    1    0    1
// out:       0    0    1    2  100  101  102    0
//            ↑    ↑    ↑    ↑    ↑    ↑    ↑    ↑
//         reset  inc  inc  load inc  inc reset inc
//
// -----------------------------------------------------------------------------
// Implementation Strategy
// -----------------------------------------------------------------------------
//
// Build up from simpler parts using MUXes for priority selection:
//
//   1. Incrementer: adds 1 to current value
//   2. Chain of MUXes to implement priority:
//
//                                    reset
//                                      │
//                                      ▼
//                    load         ┌─────────┐
//                      │          │  MUX    │
//                      ▼          │         │
//   in[16] ────► ┌─────────┐     │ sel=rst │
//                │  MUX    ├────►│  a=...  ├────► Register ────► out[16]
//   inc_out ───► │ sel=load│     │  b=0    │          │
//                │  a=...  │     └─────────┘          │
//                └─────────┘                          │
//                      ▲                              │
//                      │        inc                   │
//                      │         │                    │
//                      │         ▼                    │
//                      │    ┌─────────┐               │
//   current ───────────┴───►│  MUX    │◄──────────────┘
//   (feedback)              │ sel=inc │
//                           │  b=+1   │
//                           └─────────┘
//                                │
//                                ▼
//                            inc_out
//
// Simplified logic flow:
//   1. inc_val = current + 1
//   2. after_inc = inc ? inc_val : current
//   3. after_load = load ? in : after_inc
//   4. after_reset = reset ? 0 : after_load
//   5. new_value = after_reset → stored in Register
//
// -----------------------------------------------------------------------------
// PC in the Fetch-Execute Cycle
// -----------------------------------------------------------------------------
//
// The PC is central to how CPUs work:
//
//   FETCH:   Read instruction at address PC from ROM
//            Send instruction to decode logic
//
//   EXECUTE: Perform the operation
//            Compute next PC value:
//            - Normal: PC + 1
//            - Jump:   PC = target address
//            - Reset:  PC = 0
//
//   REPEAT:  Go back to FETCH with new PC value
//
// This is the fundamental rhythm of computation!
//
// -----------------------------------------------------------------------------
// Jumps and Branches
// -----------------------------------------------------------------------------
//
// The 'load' input enables jumps:
//
// Unconditional jump (JMP):
//   load = 1, in = target_address
//
// Conditional jump (like JEQ, JGT, JLT in Hack):
//   load = (condition is true ? 1 : 0)
//   in = target_address
//
// The CPU's control logic determines whether to assert 'load' based on
// the instruction and ALU flags (zero, negative, etc.)
//
// -----------------------------------------------------------------------------
// The Incrementer
// -----------------------------------------------------------------------------
//
// The PC needs to add 1 to its current value.
// Options:
// 1. Use the ALU we already built with x=current, y=1, op=add
// 2. Build a dedicated 16-bit incrementer (simpler, might be faster)
//
// A dedicated incrementer is essentially:
//   Inc16(in) = Add16(in, 1)
//
// But optimized: we're always adding exactly 1, so we can use a
// ripple-carry chain of half-adders instead of full adders.
//

const std = @import("std");
const testing = std.testing;

const logic = @import("logic").Logic;

const register = @import("register.zig");
const types = @import("types");
const b16 = types.b16;
const fb16 = types.fb16;

// =============================================================================
// PC - Program Counter (Bit-Array Version)
// =============================================================================

/// Program Counter - holds the address of the next instruction to execute.
///
/// Priority order: reset > load > inc > hold
pub const PC = struct {
    register: register.Register16 = .{},

    const Self = @This();

    /// Update PC with new input and control signals.
    /// Returns the current PC value (before update).
    ///
    /// Priority order:
    ///   1. reset_signal: set to 0
    ///   2. load: set to input value
    ///   3. inc: increment by 1
    ///   4. else: hold current value
    pub fn tick(self: *Self, input: [16]u1, load: u1, inc: u1, reset_signal: u1) [16]u1 {
        // Get current value (output of register)
        const current = self.register.peek();

        // Step 1: Increment current value
        const inc_result = logic.INC16(current);
        const inc_val = inc_result.sum;

        // Step 2: Choose between current and incremented value based on inc
        // MUX16(in1, in0, sel): sel==0 → in0, sel==1 → in1
        // If inc==1, we want inc_val; if inc==0, we want current
        const after_inc = logic.MUX16(inc_val, current, inc);

        // Step 3: Choose between after_inc and input based on load
        // If load==1, we want input; if load==0, we want after_inc
        const after_load = logic.MUX16(input, after_inc, load);

        // Step 4: Choose between after_load and 0 based on reset_signal
        // If reset_signal==1, we want 0; if reset_signal==0, we want after_load
        const new_value = logic.MUX16(b16(0), after_load, reset_signal);

        // Step 5: Store new value in register (always load, since we computed the value)
        // Register.tick() returns the current value (before update) and stores new_value
        _ = self.register.tick(new_value, 1);

        // Return current value (before update) - this is what was in the register before we stored new_value
        return current;
    }

    /// Get the current PC value without advancing time.
    pub fn peek(self: *const Self) [16]u1 {
        return self.register.peek();
    }

    /// Reset PC to 0.
    pub fn reset(self: *Self) void {
        self.register.reset();
    }
};

// =============================================================================
// PC_I - Program Counter (Integer Version)
// =============================================================================

/// Program Counter (Integer Version) - holds the address of the next instruction.
///
/// Priority order: reset > load > inc > hold
pub const PC_I = struct {
    register: register.Register16_I = .{},

    const Self = @This();

    /// Update PC_I with new input and control signals.
    /// Returns the current PC value (before update).
    ///
    /// Priority order:
    ///   1. reset_signal: set to 0
    ///   2. load: set to input value
    ///   3. inc: increment by 1
    ///   4. else: hold current value
    pub fn tick(self: *Self, input: u16, load: u1, inc: u1, reset_signal: u1) u16 {
        // Get current value (output of register)
        const current = self.register.peek();

        // Step 1: Increment current value
        const inc_result = logic.INC16_I(current);
        const inc_val = inc_result.sum;

        // Step 2: Choose between current and incremented value based on inc
        // MUX16_I(in1, in0, sel): sel==0 → in0, sel==1 → in1
        const after_inc = logic.MUX16_I(inc_val, current, inc);

        // Step 3: Choose between after_inc and input based on load
        const after_load = logic.MUX16_I(input, after_inc, load);

        // Step 4: Choose between after_load and 0 based on reset_signal
        // If reset_signal==1, we want 0; if reset_signal==0, we want after_load
        const new_value = logic.MUX16_I(0, after_load, reset_signal);

        // Step 5: Store new value in register (always load, since we computed the value)
        _ = self.register.tick(new_value, 1);

        // Return current value (before update)
        return current;
    }

    /// Get the current PC value without advancing time.
    pub fn peek(self: *const Self) u16 {
        return self.register.peek();
    }

    /// Reset PC to 0.
    pub fn reset(self: *Self) void {
        self.register.reset();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "PC_I comprehensive test with print statements" {
    const TestCase = struct {
        time: []const u8,
        input: i16,
        reset: u1,
        load: u1,
        inc: u1,
        expected_out: i16,
    };

    const test_cases = [_]TestCase{
        .{ .time = "0+", .input = 0, .reset = 0, .load = 0, .inc = 0, .expected_out = 0 },
        .{ .time = "1", .input = 0, .reset = 0, .load = 0, .inc = 0, .expected_out = 0 },
        .{ .time = "1+", .input = 0, .reset = 0, .load = 0, .inc = 1, .expected_out = 0 },
        .{ .time = "2", .input = 0, .reset = 0, .load = 0, .inc = 1, .expected_out = 1 },
        .{ .time = "2+", .input = -32123, .reset = 0, .load = 0, .inc = 1, .expected_out = 1 },
        .{ .time = "3", .input = -32123, .reset = 0, .load = 0, .inc = 1, .expected_out = 2 },
        .{ .time = "3+", .input = -32123, .reset = 0, .load = 1, .inc = 1, .expected_out = 2 },
        .{ .time = "4", .input = -32123, .reset = 0, .load = 1, .inc = 1, .expected_out = -32123 },
        .{ .time = "4+", .input = -32123, .reset = 0, .load = 0, .inc = 1, .expected_out = -32123 },
        .{ .time = "5", .input = -32123, .reset = 0, .load = 0, .inc = 1, .expected_out = -32122 },
        .{ .time = "5+", .input = -32123, .reset = 0, .load = 0, .inc = 1, .expected_out = -32122 },
        .{ .time = "6", .input = -32123, .reset = 0, .load = 0, .inc = 1, .expected_out = -32121 },
        .{ .time = "6+", .input = 12345, .reset = 0, .load = 1, .inc = 0, .expected_out = -32121 },
        .{ .time = "7", .input = 12345, .reset = 0, .load = 1, .inc = 0, .expected_out = 12345 },
        .{ .time = "7+", .input = 12345, .reset = 1, .load = 1, .inc = 0, .expected_out = 12345 },
        .{ .time = "8", .input = 12345, .reset = 1, .load = 1, .inc = 0, .expected_out = 0 },
        .{ .time = "8+", .input = 12345, .reset = 0, .load = 1, .inc = 1, .expected_out = 0 },
        .{ .time = "9", .input = 12345, .reset = 0, .load = 1, .inc = 1, .expected_out = 12345 },
        .{ .time = "9+", .input = 12345, .reset = 1, .load = 1, .inc = 1, .expected_out = 12345 },
        .{ .time = "10", .input = 12345, .reset = 1, .load = 1, .inc = 1, .expected_out = 0 },
        .{ .time = "10+", .input = 12345, .reset = 0, .load = 0, .inc = 1, .expected_out = 0 },
        .{ .time = "11", .input = 12345, .reset = 0, .load = 0, .inc = 1, .expected_out = 1 },
        .{ .time = "11+", .input = 12345, .reset = 1, .load = 0, .inc = 1, .expected_out = 1 },
        .{ .time = "12", .input = 12345, .reset = 1, .load = 0, .inc = 1, .expected_out = 0 },
        .{ .time = "12+", .input = 0, .reset = 0, .load = 1, .inc = 1, .expected_out = 0 },
        .{ .time = "13", .input = 0, .reset = 0, .load = 1, .inc = 1, .expected_out = 0 },
        .{ .time = "13+", .input = 0, .reset = 0, .load = 0, .inc = 1, .expected_out = 0 },
        .{ .time = "14", .input = 0, .reset = 0, .load = 0, .inc = 1, .expected_out = 1 },
        .{ .time = "14+", .input = 22222, .reset = 1, .load = 0, .inc = 0, .expected_out = 1 },
        .{ .time = "15", .input = 22222, .reset = 1, .load = 0, .inc = 0, .expected_out = 0 },
    };

    var pc = PC{};
    var pc_i = PC_I{};

    std.debug.print("\n", .{});
    std.debug.print("| time |   in   |reset|load | inc |  out   |  out_i  |\n", .{});
    std.debug.print("|------|--------|-----|-----|-----|--------|--------|\n", .{});

    for (test_cases) |tc| {
        const is_tick = std.mem.endsWith(u8, tc.time, "+");
        const input_u16: u16 = @bitCast(tc.input);

        if (is_tick) {
            const current_out: i16 = @bitCast(fb16(pc.tick(b16(input_u16), tc.load, tc.inc, tc.reset)));
            const current_out_i: i16 = @bitCast(pc_i.tick(input_u16, tc.load, tc.inc, tc.reset));
            std.debug.print("| {s:4} | {d:6} |  {d}  |  {d}  |  {d}  | {d:6} | {d:6} |\n", .{
                tc.time,
                tc.input,
                tc.reset,
                tc.load,
                tc.inc,
                current_out,
                current_out_i,
            });
        } else {
            const actual_out: i16 = @bitCast(fb16(pc.peek()));
            const actual_out_i: i16 = @bitCast(pc_i.peek());
            std.debug.print("| {s:4} | {d:6} |  {d}  |  {d}  |  {d}  | {d:6} | {d:6} |\n", .{
                tc.time,
                tc.input,
                tc.reset,
                tc.load,
                tc.inc,
                actual_out,
                actual_out_i,
            });

            try testing.expectEqual(tc.expected_out, actual_out_i);
        }
    }
}
