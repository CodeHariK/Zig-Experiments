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

