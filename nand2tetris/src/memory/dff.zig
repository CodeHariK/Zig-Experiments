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

