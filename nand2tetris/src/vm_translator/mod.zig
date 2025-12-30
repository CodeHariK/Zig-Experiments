// =============================================================================
// Chapter 7: VM Translator - Overview
// =============================================================================
//
// This chapter marks the transition from HARDWARE to SOFTWARE in Nand2Tetris.
// We're building a Virtual Machine (VM) Translator that converts high-level
// VM code into Hack assembly language.
//
// -----------------------------------------------------------------------------
// What is a Virtual Machine?
// -----------------------------------------------------------------------------
//
// A Virtual Machine is an abstraction layer that sits between high-level
// languages and machine code. It provides:
//
// - Platform independence: Same VM code runs on different hardware
// - Simplified operations: Stack-based operations are easier to reason about
// - Security: VM can enforce safety checks and boundaries
// - Portability: Write once, run anywhere (if VM is available)
//
// The VM we're building is stack-based, similar to the Java Virtual Machine
// or Python's bytecode interpreter.
//
// -----------------------------------------------------------------------------
// The VM Architecture
// -----------------------------------------------------------------------------
//
// Stack-Based Operations:
//   - All operations work with a stack
//   - Push: Add value to top of stack
//   - Pop: Remove value from top of stack
//   - Arithmetic: Operate on top stack elements
//
// Memory Segments:
//   - The VM uses different memory segments for different purposes:
//
//     1. LOCAL: Function local variables (LCL pointer)
//     2. ARGUMENT: Function arguments (ARG pointer)
//     3. THIS: Object instance variables (THIS pointer)
//     4. THAT: Array elements (THAT pointer)
//     5. CONSTANT: Literal constants (no memory, just values)
//     6. STATIC: Class-level variables (mapped to RAM[16..255])
//     7. POINTER: THIS/THAT pointers (RAM[3-4])
//     8. TEMP: Temporary variables (RAM[5..12])
//
// Stack Pointer:
//   - SP (RAM[0]): Points to the next available stack location
//   - Stack grows downward (higher addresses)
//   - SP points to the location AFTER the top element
//
// -----------------------------------------------------------------------------
// VM Command Types
// -----------------------------------------------------------------------------
//
// 1. ARITHMETIC/LOGICAL OPERATIONS (no operands):
//    - add: Pop two values, push (y + x)
//    - sub: Pop two values, push (y - x)
//    - neg: Pop one value, push (-x)
//    - eq:  Pop two values, push (y == x ? -1 : 0)
//    - gt:  Pop two values, push (y > x ? -1 : 0)
//    - lt:  Pop two values, push (y < x ? -1 : 0)
//    - and: Pop two values, push (y & x)
//    - or:  Pop two values, push (y | x)
//    - not: Pop one value, push (~x)
//
// 2. MEMORY ACCESS OPERATIONS (with segment and index):
//    - push segment index: Push value from segment[index] onto stack
//    - pop segment index:  Pop value from stack into segment[index]
//
//    Segments:
//    - push constant 5    → Push literal 5
//    - push local 2       → Push LCL[2]
//    - push argument 1    → Push ARG[1]
//    - push this 0        → Push THIS[0]
//    - push that 3        → Push THAT[3]
//    - push static 0      → Push static variable 0
//    - push pointer 0     → Push THIS pointer
//    - push pointer 1     → Push THAT pointer
//    - push temp 2        → Push RAM[7] (temp 2 = RAM[5+2])
//
// -----------------------------------------------------------------------------
// Translation Strategy
// -----------------------------------------------------------------------------
//
// For each VM command, we generate Hack assembly code:
//
// 1. ARITHMETIC OPERATIONS:
//    - Pop operands from stack (decrement SP, read value)
//    - Perform computation using ALU
//    - Push result onto stack (write value, increment SP)
//
// 2. PUSH OPERATIONS:
//    - Calculate address of source (segment + index)
//    - Load value from source
//    - Push onto stack (write to *SP, increment SP)
//
// 3. POP OPERATIONS:
//    - Calculate address of destination (segment + index)
//    - Pop from stack (decrement SP, read value)
//    - Store value at destination
//
// -----------------------------------------------------------------------------
// Memory Mapping
// -----------------------------------------------------------------------------
//
// Hack RAM layout for VM:
//
//   RAM[0]   → SP (Stack Pointer)
//   RAM[1]   → LCL (Local segment pointer)
//   RAM[2]   → ARG (Argument segment pointer)
//   RAM[3]   → THIS pointer
//   RAM[4]   → THAT pointer
//   RAM[5-12] → TEMP segment (8 words)
//   RAM[13-15] → General purpose (for VM operations)
//   RAM[16-255] → STATIC segment (240 words)
//   RAM[256-2047] → Stack (grows downward)
//
// -----------------------------------------------------------------------------
// Implementation Structure
// -----------------------------------------------------------------------------
//
// This module will be organized as:
//
//   - parser.zig:        Parse VM commands from .vm files
//   - command.zig:       VM command types and structures
//   - arithmetic.zig:    Translate arithmetic/logical operations
//   - memory.zig:        Translate push/pop operations
//   - code_writer.zig:   Generate Hack assembly code
//   - translator.zig:    Main translation logic (orchestrates everything)
//
// -----------------------------------------------------------------------------
// Translation Example
// -----------------------------------------------------------------------------
//
// VM Code:
//   push constant 7
//   push constant 8
//   add
//
// Generated Assembly:
//   @7          // push constant 7
//   D=A
//   @SP
//   A=M
//   M=D
//   @SP
//   M=M+1
//
//   @8          // push constant 8
//   D=A
//   @SP
//   A=M
//   M=D
//   @SP
//   M=M+1
//
//   @SP         // add
//   AM=M-1
//   D=M
//   A=A-1
//   M=M+D
//
// -----------------------------------------------------------------------------
// Implementation Tasks
// -----------------------------------------------------------------------------
//
// Phase 1: Basic Stack Operations
//   [ ] Implement push constant
//   [ ] Implement pop operations for all segments
//   [ ] Implement push operations for all segments
//
// Phase 2: Arithmetic Operations
//   [ ] Implement add, sub, neg
//   [ ] Implement and, or, not
//   [ ] Implement eq, gt, lt (with unique labels)
//
// Phase 3: File Processing
//   [ ] Parse .vm files
//   [ ] Handle comments and whitespace
//   [ ] Generate .asm output files
//
// Phase 4: Testing
//   [ ] Test with provided VM test files
//   [ ] Verify output with CPU emulator
//   [ ] Handle edge cases
//
// TODO: Implement each component incrementally

// Re-export main types
pub const Command = @import("command.zig").Command;
pub const Segment = @import("command.zig").Segment;
pub const ArithmeticOp = @import("command.zig").ArithmeticOp;
// pub const Parser = @import("parser.zig").Parser;
// pub const CodeWriter = @import("code_writer.zig").CodeWriter;
// pub const Translator = @import("translator.zig").Translator;

test "vm_translator module: include all vm_translator tests" {
    // Tests will be added as we implement each component
    _ = @import("command.zig");
    // _ = @import("parser.zig");
    // _ = @import("code_writer.zig");
}
