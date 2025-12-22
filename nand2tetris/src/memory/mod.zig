// =============================================================================
// Chapter 3: Sequential Logic & Memory - Overview
// =============================================================================
//
// This chapter transitions from COMBINATIONAL logic to SEQUENTIAL logic.
// The fundamental difference: sequential circuits have MEMORY (state).
//
// -----------------------------------------------------------------------------
// Combinational vs Sequential
// -----------------------------------------------------------------------------
//
// COMBINATIONAL (Chapters 1-2):
// - Output depends ONLY on current inputs
// - No memory, no state
// - Examples: AND, OR, MUX, ALU
// - Output = f(inputs)
//
// SEQUENTIAL (Chapter 3):
// - Output depends on current inputs AND history
// - Has memory, maintains state across time
// - Examples: DFF, Register, RAM, PC
// - Output = f(inputs, state)
//
// -----------------------------------------------------------------------------
// The Memory Hierarchy We're Building
// -----------------------------------------------------------------------------
//
//   Primitive
//      │
//      ▼
//    ┌─────┐
//    │ DFF │  ◄── Data Flip-Flop (given as primitive)
//    └──┬──┘       Stores 1 bit, outputs previous input
//       │
//       ▼
//    ┌─────┐
//    │ Bit │  ◄── 1-bit register with load control
//    └──┬──┘       Store OR hold based on load signal
//       │
//       ▼
//  ┌──────────┐
//  │ Register │  ◄── 16-bit register (word)
//  └────┬─────┘       16 Bits in parallel
//       │
//       ▼
//    ┌──────┐
//    │ RAM8 │  ◄── 8 Registers, addressable
//    └──┬───┘       3-bit address
//       │
//       ▼
//   ┌───────┐
//   │ RAM64 │  ◄── 8 RAM8s = 64 Registers
//   └──┬────┘       6-bit address
//       │
//       ▼
//  ┌────────┐
//  │ RAM512 │  ◄── 8 RAM64s = 512 Registers
//  └──┬─────┘       9-bit address
//       │
//       ▼
//   ┌───────┐
//   │ RAM4K │  ◄── 8 RAM512s = 4096 Registers
//   └──┬────┘       12-bit address
//       │
//       ▼
//  ┌────────┐
//  │ RAM16K │  ◄── 4 RAM4Ks = 16384 Registers
//  └────────┘       14-bit address
//
// Plus: PC (Program Counter) - specialized register for instruction flow
//
// -----------------------------------------------------------------------------
// Key Concepts
// -----------------------------------------------------------------------------
//
// 1. CLOCK
//    - Synchronizes all sequential elements
//    - Creates discrete time steps (t, t+1, t+2, ...)
//    - All state changes happen at clock edges
//
// 2. STATE
//    - Information preserved across clock cycles
//    - The "memory" in memory chips
//    - State(t+1) = f(State(t), Inputs(t))
//
// 3. FEEDBACK
//    - Output connected back to input (through DFF)
//    - Creates stable memory loops
//    - DFF breaks infinite loops by adding 1-cycle delay
//
// 4. ADDRESSING
//    - Using binary addresses to select registers
//    - DMux to route writes, Mux to route reads
//    - n address bits → 2^n addressable locations
//
// -----------------------------------------------------------------------------
// Timing Diagram Notation
// -----------------------------------------------------------------------------
//
// Time flows left to right:
//
//     t0   t1   t2   t3   t4
//      │    │    │    │    │
// clk  ┌┐   ┌┐   ┌┐   ┌┐   ┌┐
//      └┘   └┘   └┘   └┘   └┘
//
// Signal values shown at each time:
//
// in:   0    1    1    0    1
// out:  0    0    1    1    0    (assuming out = in from previous cycle)
//
// -----------------------------------------------------------------------------
// The Big Picture
// -----------------------------------------------------------------------------
//
// Why does memory matter?
//
// 1. STORING PROGRAMS
//    - Instructions live in memory (ROM in Hack)
//    - PC points to current instruction
//    - Without memory, we'd need hardwired circuits for every program
//
// 2. STORING DATA
//    - Variables, arrays, objects
//    - Stack frames, heap allocations
//    - Without memory, we could only compute with immediate values
//
// 3. MAINTAINING STATE
//    - Where are we in the program? (PC)
//    - What are the current values? (registers)
//    - What's the program's history? (RAM)
//
// Memory transforms a calculator into a COMPUTER.
// A calculator computes: input → output
// A computer executes PROGRAMS: sequences of operations over time
//
// -----------------------------------------------------------------------------
// Implementation Order
// -----------------------------------------------------------------------------
//
// Build in this order (each uses the previous):
//
// 1. DFF      - given as primitive
// 2. Bit      - uses DFF + Mux
// 3. Register - uses 16 Bits
// 4. RAM8     - uses 8 Registers + DMux8Way + Mux8Way16
// 5. RAM64    - uses 8 RAM8s + DMux8Way + Mux8Way16
// 6. RAM512   - uses 8 RAM64s + DMux8Way + Mux8Way16
// 7. RAM4K    - uses 8 RAM512s + DMux8Way + Mux8Way16
// 8. RAM16K   - uses 4 RAM4Ks + DMux4Way + Mux4Way16
// 9. PC       - uses Register + Inc16 + Muxes
//

const dff_mod = @import("dff.zig");
const bit_mod = @import("bit.zig");
const register_mod = @import("register.zig");
const ram_mod = @import("ram.zig");
const pc_mod = @import("pc.zig");

/// Memory - a collection of memory elements.
pub const Memory = struct {
    dff: dff_mod.DFF,
    bit: bit_mod.Bit,
    register: register_mod.Register,
    register16: register_mod.Register16,
    ram8: ram_mod.RAM8,
    ram64: ram_mod.RAM64,
    ram512: ram_mod.RAM512,
    ram4k: ram_mod.RAM4K,
    ram16k: ram_mod.RAM16K,
    pc: pc_mod.PC,
};

/// Memory_I - a collection of memory elements (integer version).
pub const Memory_I = struct {
    register: register_mod.Register_I,
    register16: register_mod.Register16_I,
    ram8: ram_mod.RAM8_I,
    ram64: ram_mod.RAM64_I,
    ram512: ram_mod.RAM512_I,
    ram4k: ram_mod.RAM4K_I,
    ram16k: ram_mod.RAM16K_I,
    pc: pc_mod.PC_I,
};

// ============================================================================
// Tests
// ============================================================================

const std = @import("std");
const testing = std.testing;

test "memory module: include all memory tests" {
    // Import all memory files to ensure their tests are included in the memory module
    _ = @import("dff.zig");
    _ = @import("bit.zig");
    _ = @import("register.zig");
    _ = @import("ram.zig");
    _ = @import("pc.zig");
}
