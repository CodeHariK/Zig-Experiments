// =============================================================================
// RAM (Random Access Memory)
// =============================================================================
//
// RAM is an array of registers that can be accessed by address.
// "Random Access" means we can read/write ANY location in constant time.
//
// -----------------------------------------------------------------------------
// RAM Hierarchy in Nand2Tetris
// -----------------------------------------------------------------------------
//
// RAM8    =   8 registers  (3-bit address)
// RAM64   =  64 registers  (6-bit address)
// RAM512  = 512 registers  (9-bit address)
// RAM4K   = 4096 registers (12-bit address)
// RAM16K  = 16384 registers (14-bit address)
//
// Each level is built by combining 8 units of the previous level.
//
// -----------------------------------------------------------------------------
// RAM Interface (using RAM8 as example)
// -----------------------------------------------------------------------------
//
// Inputs:
//   in[16]    - 16-bit value to potentially store
//   address[3] - which of the 8 registers to access (0-7)
//   load      - 1 = write to selected register, 0 = just read
//
// Output:
//   out[16]   - value currently stored in the selected register
//
// -----------------------------------------------------------------------------
// RAM Behavior
// -----------------------------------------------------------------------------
//
// Read (always happening):
//   out = Register[address]
//
// Write (only when load=1):
//   Register[address] = in
//   (takes effect next cycle)
//
// Key insight: We're always reading from the addressed location.
// The load signal only controls whether we ALSO write.
//
// -----------------------------------------------------------------------------
// RAM8 Implementation Strategy
// -----------------------------------------------------------------------------
//
// Two main tasks:
// 1. DEMUX the load signal to the correct register
// 2. MUX the outputs to select the right register's value
//
//                  ┌─────────────────────────────────────────┐
//                  │               RAM8                       │
//                  │                                          │
//   in[16] ───────►├─────────► Reg0 ───────┐                  │
//                  ├─────────► Reg1 ───────┤                  │
//                  ├─────────► Reg2 ───────┤                  │
//                  ├─────────► Reg3 ───────┼────► Mux8Way16 ──┼──► out[16]
//                  ├─────────► Reg4 ───────┤                  │
//                  ├─────────► Reg5 ───────┤                  │
//                  ├─────────► Reg6 ───────┤                  │
//                  ├─────────► Reg7 ───────┘                  │
//                  │             ▲                  ▲          │
//                  │             │                  │          │
//   load ─────────►├──► DMux8Way─┘                  │          │
//                  │        ▲                       │          │
//   address[3] ───►├────────┴───────────────────────┘          │
//                  └───────────────────────────────────────────┘
//
// Step 1: DMux8Way takes load and address
//   - Routes load=1 to exactly one register based on address
//   - Other 7 registers receive load=0 (hold their values)
//
// Step 2: All 8 registers receive the same 'in' value
//   - Only the one with load=1 will actually store it
//
// Step 3: Mux8Way16 selects output based on address
//   - Picks the output from the addressed register
//
// -----------------------------------------------------------------------------
// Building Larger RAMs (Recursive Structure)
// -----------------------------------------------------------------------------
//
// RAM64 = 8 × RAM8
//
//   address[6] = [aaa][bbb]
//                 ↓    ↓
//              high  low
//              (which RAM8)  (which register in that RAM8)
//
//   - Use high 3 bits to select which RAM8 unit
//   - Pass low 3 bits to that RAM8 as its internal address
//
//                  ┌─────────────────────────────────────────┐
//                  │               RAM64                      │
//                  │                                          │
//   in[16] ───────►├─────────► RAM8_0 ─────┐                  │
//                  ├─────────► RAM8_1 ─────┤                  │
//                  ├─────────► RAM8_2 ─────┤                  │
//                  ├─────────► RAM8_3 ─────┼────► Mux8Way16 ──┼──► out
//                  ├─────────► RAM8_4 ─────┤                  │
//                  ├─────────► RAM8_5 ─────┤                  │
//                  ├─────────► RAM8_6 ─────┤                  │
//                  ├─────────► RAM8_7 ─────┘                  │
//                  │             ▲                  ▲          │
//   load ─────────►├──► DMux8Way─┘                  │          │
//                  │        ▲                       │          │
//   address[6] ───►├────────┴───────────────────────┘          │
//                  │   high 3 bits      all 6 bits             │
//                  │                                           │
//                  │   low 3 bits → each RAM8's address        │
//                  └───────────────────────────────────────────┘
//
// This pattern repeats:
//   RAM512  = 8 × RAM64
//   RAM4K   = 8 × RAM512
//   RAM16K  = 4 × RAM4K  (only 4 because 14 bits, not 15)
//
// -----------------------------------------------------------------------------
// Address Bit Calculation
// -----------------------------------------------------------------------------
//
// For N registers, we need log₂(N) address bits:
//
//   RAM8:    8 = 2³   →  3 address bits
//   RAM64:  64 = 2⁶   →  6 address bits
//   RAM512: 512 = 2⁹  →  9 address bits
//   RAM4K:  4096 = 2¹² → 12 address bits
//   RAM16K: 16384 = 2¹⁴ → 14 address bits
//
// -----------------------------------------------------------------------------
// Why "Random Access"?
// -----------------------------------------------------------------------------
//
// Historical contrast with sequential access (like tape drives):
// - Tape: to read position 1000, must wind through positions 0-999
// - RAM: to read position 1000, just provide address 1000 directly
//
// Access time is CONSTANT regardless of which address we access.
// This is O(1) access - critical for efficient computing.
//
// The MUX/DEMUX structure provides this: address bits flow through
// gates in parallel, not sequentially through memory cells.
//

