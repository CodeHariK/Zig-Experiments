// =============================================================================
// CPU (Central Processing Unit)
// =============================================================================
//
// The CPU is the heart of the Hack computer. It executes instructions by
// fetching them from ROM, decoding them, and executing the operations.
//
// -----------------------------------------------------------------------------
// CPU Architecture Overview
// -----------------------------------------------------------------------------
//
// The Hack CPU consists of:
//
//   1. A Register (A-register): 16-bit register that holds:
//      - Data values (for A-instructions)
//      - Memory addresses (for addressing RAM)
//
//   2. D Register (D-register): 16-bit register that holds:
//      - Data values for computations
//      - Intermediate results from ALU operations
//
//   3. Program Counter (PC): 16-bit register that holds:
//      - Address of the next instruction to execute
//
//   4. ALU (Arithmetic Logic Unit): Performs computations
//      - Takes inputs: A register, D register, M (RAM[A])
//      - Produces output: result, zero flag (zr), negative flag (ng)
//
//   5. Instruction Decoder: Decodes 16-bit instructions
//      - Determines if instruction is A-instruction or C-instruction
//      - Extracts control signals for ALU, destinations, and jumps
//
// -----------------------------------------------------------------------------
// CPU Interface
// -----------------------------------------------------------------------------
//
// Inputs:
//   inM[16]      - Value from RAM (M = RAM[A])
//   instruction[16] - Current instruction from ROM
//   reset         - Reset signal (1 = restart from address 0)
//
// Outputs:
//   outM[16]     - Value to write to RAM (when writeM=1)
//   writeM       - Write enable signal for RAM
//   addressM[15] - Address for RAM access (15 bits, 0-32767)
//   pc[15]       - Address of next instruction (15 bits, 0-32767)
//
// -----------------------------------------------------------------------------
// Instruction Execution Flow
// -----------------------------------------------------------------------------
//
// The CPU follows a fetch-execute cycle:
//
//   1. FETCH: Read instruction from ROM[PC]
//
//   2. DECODE: Determine instruction type
//      - If bit 15 == 0: A-instruction
//      - If bits 15-13 == 111: C-instruction
//
//   3. EXECUTE A-Instruction:
//      - Load 15-bit value into A register
//      - PC = PC + 1
//
//   4. EXECUTE C-Instruction:
//      - Decode computation (comp), destination (dest), jump (jump)
//      - Select ALU inputs: A, D, or M based on 'a' bit
//      - Perform ALU operation
//      - Write results to destinations (A, D, M)
//      - Update PC based on jump condition
//
// -----------------------------------------------------------------------------
// A-Instruction Execution
// -----------------------------------------------------------------------------
//
// Format: 0vvvvvvvvvvvvvvv (16 bits)
//
// Execution:
//   1. Load 15-bit value (bits 0-14) into A register
//   2. PC = PC + 1
//
// The A register now holds either:
//   - A constant value (for immediate operations)
//   - A memory address (for accessing RAM)
//
// -----------------------------------------------------------------------------
// C-Instruction Execution
// -----------------------------------------------------------------------------
//
// Format: 111accccccdddjjj (16 bits)
//
// Components:
//   - a (bit 12): ALU input selector
//     * 0: ALU input = A register
//     * 1: ALU input = M (RAM[A])
//   - cccccc (bits 6-11): ALU computation control bits
//   - ddd (bits 3-5): Destination bits
//     * d1 (bit 3): Write to A register
//     * d2 (bit 4): Write to D register
//     * d3 (bit 5): Write to M (RAM[A])
//   - jjj (bits 0-2): Jump condition bits
//     * j1 (bit 0): Jump if out < 0 (JLT)
//     * j2 (bit 1): Jump if out == 0 (JEQ)
//     * j3 (bit 2): Jump if out > 0 (JGT)
//
// Execution Steps:
//   1. Decode instruction to extract comp, dest, jump
//   2. Select ALU inputs:
//      - x = D register (always)
//      - y = A register (if a=0) or M (if a=1)
//   3. Compute ALU control bits from comp field
//   4. Execute ALU operation
//   5. Write results to destinations:
//      - If d1=1: A = ALU output
//      - If d2=1: D = ALU output
//      - If d3=1: M = ALU output (set writeM=1, outM=ALU output)
//   6. Determine next PC:
//      - Compute jump condition from ALU flags (zr, ng) and jump bits
//      - If jump condition true: PC = A register
//      - If jump condition false: PC = PC + 1
//
// -----------------------------------------------------------------------------
// ALU Input Selection
// -----------------------------------------------------------------------------
//
// The 'a' bit in C-instructions determines the second ALU input:
//
//   a = 0: y = A register
//   a = 1: y = M (RAM[A])
//
// The first ALU input is always the D register.
//
// Examples:
//   - "D=A" uses A register (a=0)
//   - "D=M" uses M (a=1)
//   - "D=A+M" uses A and M (a=1, comp="A+M")
//
// -----------------------------------------------------------------------------
// Destination Decoding
// -----------------------------------------------------------------------------
//
// The destination field (ddd) is a 3-bit field:
//
//   Bit 3 (d1): Write to A register
//   Bit 4 (d2): Write to D register
//   Bit 5 (d3): Write to M (RAM[A])
//
// Combinations:
//   000: No destination (null)
//   001: M only
//   010: D only
//   011: MD (M and D)
//   100: A only
//   101: AM (A and M)
//   110: AD (A and D)
//   111: AMD (A, M, and D)
//
// -----------------------------------------------------------------------------
// Jump Condition Decoding
// -----------------------------------------------------------------------------
//
// The jump field (jjj) is a 3-bit field:
//
//   Bit 0 (j1): Jump if out < 0 (negative flag ng)
//   Bit 1 (j2): Jump if out == 0 (zero flag zr)
//   Bit 2 (j3): Jump if out > 0 (not negative and not zero)
//
// Jump conditions:
//   000: No jump (null)
//   001: JLT (Jump if Less Than: ng == 1)
//   010: JEQ (Jump if EQual: zr == 1)
//   011: JLE (Jump if Less or Equal: ng == 1 OR zr == 1)
//   100: JGT (Jump if Greater Than: ng == 0 AND zr == 0)
//   101: JNE (Jump if Not Equal: zr == 0)
//   110: JGE (Jump if Greater or Equal: ng == 0)
//   111: JMP (Unconditional jump: always true)
//
// Jump logic:
//   should_jump = (j1 AND ng) OR (j2 AND zr) OR (j3 AND (NOT ng AND NOT zr))
//
// -----------------------------------------------------------------------------
// Memory Access
// -----------------------------------------------------------------------------
//
// The CPU accesses memory through the A register:
//
//   1. A-instruction sets A to a memory address
//   2. Subsequent C-instruction can read/write RAM[A]
//
// Reading M:
//   - When a=1 in C-instruction, M = RAM[A] is used as ALU input
//   - inM input provides the value of RAM[A]
//
// Writing M:
//   - When d3=1 in C-instruction, ALU output is written to RAM[A]
//   - writeM = 1 signals RAM to write
//   - outM = ALU output is the value to write
//   - addressM = A register (15 bits) specifies the address
//
// -----------------------------------------------------------------------------
// Implementation Structure
// -----------------------------------------------------------------------------
//
// This module will be organized as:
//
//   cpu.zig (this file):
//     - CPU struct and main execution logic
//     - Instruction decoding
//     - Control signal generation
//
//   Components used:
//     - A Register: 16-bit register
//     - D Register: 16-bit register
//     - PC: Program Counter (from memory module)
//     - ALU: Arithmetic Logic Unit (from gates module)
//     - Instruction decoder: Logic to decode A/C instructions
//
// -----------------------------------------------------------------------------
// CPU State
// -----------------------------------------------------------------------------
//
// The CPU maintains internal state:
//
//   - A register: Current value (data or address)
//   - D register: Current data value
//   - PC: Current program counter value
//
// All state is updated synchronously on each clock tick.
//
// -----------------------------------------------------------------------------
// Reset Behavior
// -----------------------------------------------------------------------------
//
// When reset=1:
//   - PC is set to 0 (restart program)
//   - A and D registers may be reset to 0 (implementation dependent)
//   - All outputs are set to safe values
//
// -----------------------------------------------------------------------------
// Timing and Clocking
// -----------------------------------------------------------------------------
//
// The CPU operates on a clock signal:
//
//   - On each clock tick:
//     1. Fetch instruction from ROM[PC]
//     2. Decode instruction
//     3. Execute operation
//     4. Update registers and PC
//     5. Output new values
//
//   - All state changes happen synchronously
//   - Outputs are valid after the clock tick completes
//
// -----------------------------------------------------------------------------
// TODO: Implementation
// -----------------------------------------------------------------------------
//
// To implement the CPU:
//
//   1. Create CPU struct with:
//      - A register (Register16)
//      - D register (Register16)
//      - PC (PC_I from memory module)
//
//   2. Implement instruction decoder:
//      - Detect A-instruction (bit 15 == 0)
//      - Detect C-instruction (bits 15-13 == 111)
//      - Extract fields: a, comp, dest, jump
//
//   3. Implement ALU control signal generation:
//      - Map comp field to ALU control bits (zx, nx, zy, ny, f, no)
//      - Use lookup table or logic based on comp encoding
//
//   4. Implement destination decoding:
//      - Extract d1, d2, d3 bits
//      - Generate load signals for A, D registers
//      - Generate writeM signal for RAM
//
//   5. Implement jump condition logic:
//      - Extract j1, j2, j3 bits
//      - Compute jump condition from ALU flags (zr, ng)
//      - Generate PC load signal
//
//   6. Implement main tick() function:
//      - Fetch instruction
//      - Decode instruction
//      - Execute A-instruction or C-instruction
//      - Update registers and PC
//      - Output results
//
//   7. Handle reset signal:
//      - Reset PC to 0
//      - Optionally reset A and D registers
//
// -----------------------------------------------------------------------------
// Testing Strategy
// -----------------------------------------------------------------------------
//
// Test the CPU with:
//
//   1. A-instruction tests:
//      - Load various values into A register
//      - Verify A register and PC update correctly
//
//   2. C-instruction tests:
//      - Test all ALU operations
//      - Test all destination combinations
//      - Test all jump conditions
//      - Test combinations of dest and jump
//
//   3. Memory access tests:
//      - Test reading from RAM (M as input)
//      - Test writing to RAM (M as destination)
//      - Test address calculation
//
//   4. Control flow tests:
//      - Test conditional jumps
//      - Test unconditional jumps
//      - Test sequential execution
//
//   5. Integration tests:
//      - Run complete programs
//      - Verify correct execution
//      - Check final state matches expectations
//
// -----------------------------------------------------------------------------

// TODO: Add imports when implementing
// const std = @import("std");
// const testing = std.testing;
// const types = @import("types");
// const gates = @import("gates");
// const memory = @import("memory");
// const machine_language = @import("machine_language");

// TODO: Implement CPU struct and functions

