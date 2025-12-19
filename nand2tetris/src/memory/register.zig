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

