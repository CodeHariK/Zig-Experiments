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

