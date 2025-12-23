// =============================================================================
// Chapter 4: Machine Language - Overview
// =============================================================================
//
// This chapter introduces Machine Language - the lowest-level programming
// language that directly communicates with the computer hardware.
//
// -----------------------------------------------------------------------------
// What is Machine Language?
// -----------------------------------------------------------------------------
//
// Machine language is:
// - Binary instructions that the CPU executes directly
// - Hardware-specific - each CPU architecture has its own machine language
// - Low-level - one instruction typically performs one simple operation
// - The foundation for all higher-level languages
//
// -----------------------------------------------------------------------------
// The Hack Machine Language
// -----------------------------------------------------------------------------
//
// The Hack machine language is a simplified 16-bit instruction set designed
// for the Hack computer built in Nand2Tetris.
//
// Key Characteristics:
// - 16-bit instructions: Each instruction is exactly 16 bits
// - Two instruction types: A-instruction and C-instruction
// - Simple architecture: Designed for learning, not production use
// - Complete: Can express any computation (Turing-complete)
//
// -----------------------------------------------------------------------------
// Instruction Formats
// -----------------------------------------------------------------------------
//
// A-Instruction (Address Instruction):
//   Format: 0vvvvvvvvvvvvvvv (16 bits)
//   - Bit 15 = 0 (identifies A-instruction)
//   - Bits 0-14 = 15-bit value (0 to 32,767)
//   Purpose: Load constant or set memory address
//
// C-Instruction (Compute Instruction):
//   Format: 111accccccdddjjj (16 bits)
//   - Bits 15-13 = 111 (identifies C-instruction)
//   - Bit 12 = a (ALU input selector)
//   - Bits 6-11 = cccccc (ALU computation bits)
//   - Bits 3-5 = ddd (destination bits)
//   - Bits 0-2 = jjj (jump condition bits)
//   Purpose: Perform computation and optionally store result and/or jump
//
// -----------------------------------------------------------------------------
// Memory and Registers
// -----------------------------------------------------------------------------
//
// Registers:
//   - A Register: Holds data or memory addresses, used to address memory
//   - D Register: Primary data storage, used for computations
//   - M Register: Represents RAM[A] (memory at address stored in A)
//
// Memory Architecture:
//   - RAM: 16K (16,384) 16-bit words, addresses 0-16383
//   - Screen: Memory-mapped I/O, addresses 16384-24575 (8K words)
//   - Keyboard: Memory-mapped I/O, address 24576
//
// -----------------------------------------------------------------------------
// Program Flow Control
// -----------------------------------------------------------------------------
//
// Control flow is achieved through:
//   - Labels: Named locations in code (e.g., (LOOP), (END))
//   - Variables: Symbolic names for memory locations (e.g., @i, @sum)
//   - Jump instructions: Conditional and unconditional jumps
//
// -----------------------------------------------------------------------------
// Implementation Structure
// -----------------------------------------------------------------------------
//
// This module will be organized as:
//   - a_instruction.zig: A-instruction parsing and encoding
//   - c_instruction.zig: C-instruction parsing and encoding
//   - instruction.zig: Unified instruction handling
//   - assembler.zig: Assembly to machine code translation
//   - examples.zig: Example programs and patterns
//
// TODO: Implement each component incrementally

// Re-export main types
// Note: The @import statements below automatically include tests from those modules
// when testing this module, so no additional imports are needed.
pub const Instruction = @import("instruction.zig").Instruction;
pub const AInstruction = @import("a_instruction.zig").AInstruction;
pub const CInstruction = @import("c_instruction.zig").CInstruction;

test "machine_language module: include all machine language tests" {
    _ = @import("memory_map.zig");
    _ = @import("a_instruction.zig");
    _ = @import("c_instruction.zig");
    // _ = @import("instruction.zig");
}
