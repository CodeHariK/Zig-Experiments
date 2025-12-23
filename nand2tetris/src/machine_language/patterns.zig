// =============================================================================
// Common Programming Patterns
// =============================================================================
//
// This module documents and provides examples of common programming patterns
// in Hack machine language. These patterns form the building blocks for
// writing programs.
//
// -----------------------------------------------------------------------------
// Load and Store Patterns
// -----------------------------------------------------------------------------
//
// Load Constant:
//   @5
//   D=A        // D = 5
//
// Load from Memory:
//   @100
//   D=M        // D = RAM[100]
//
// Store to Memory:
//   @200
//   M=D        // RAM[200] = D
//
// -----------------------------------------------------------------------------
// Arithmetic Operations
// -----------------------------------------------------------------------------
//
// Addition:
//   @x
//   D=M        // D = RAM[x]
//   @y
//   D=D+M      // D = RAM[x] + RAM[y]
//   @sum
//   M=D        // RAM[sum] = RAM[x] + RAM[y]
//
// Subtraction:
//   @x
//   D=M        // D = RAM[x]
//   @y
//   D=D-M      // D = RAM[x] - RAM[y]
//
// -----------------------------------------------------------------------------
// Control Flow Patterns
// -----------------------------------------------------------------------------
//
// Conditional: (if RAM[x] > 0, jump to POSITIVE)
//   @x
//   D=M
//   @POSITIVE
//   D;JGT      // if RAM[x] > 0, jump to POSITIVE
//   // negative code
//   (POSITIVE)
//   // positive code
//
// Loop: (loop from 0 to 10, incrementing i each time)
//   @i
//   M=0         // i = 0
//   (LOOP)
//     @i
//     D=M
//     @10
//     D=D-A     // D = i - 10
//     @END
//     D;JGE     // if i >= 10, exit
//     // loop body
//     @i
//     M=M+1     // i++
//     @LOOP
//     0;JMP     // continue
//   (END)
//
// -----------------------------------------------------------------------------
// Array Operations
// -----------------------------------------------------------------------------
//
// Array Access:
//   @arr
//   D=A
//   @i
//   A=D+M       // A = arr + RAM[i]
//   D=M         // D = arr[i]
//
// Array Sum:
//   @arr
//   D=A
//   @sum
//   M=0         // sum = 0
//   @i
//   M=0         // i = 0
//   (LOOP)
//     @i
//     D=M
//     @n
//     D=D-M     // D = i - n
//     @END
//     D;JGE     // if i >= n, exit
//     @arr
//     D=A
//     @i
//     A=D+M     // A = arr + RAM[i]
//     D=M       // D = arr[i]
//     @sum
//     M=M+D     // sum += arr[i]
//     @i
//     M=M+1     // i++
//     @LOOP
//     0;JMP
//   (END)
//
// -----------------------------------------------------------------------------
// I/O Patterns
// -----------------------------------------------------------------------------
//
// Clear Screen:
//   @SCREEN
//   D=A
//   @addr
//   M=D         // RAM[addr] = SCREEN
//   @8192
//   D=A
//   @n
//   M=D         // RAM[n] = 8192
//   @i
//   M=0         // RAM[i] = 0
//   (LOOP)
//     @i
//     D=M       // D = RAM[i]
//     @n
//     D=D-M     // D = RAM[i] - RAM[n]
//     @END
//     D;JGE     // if RAM[i] >= RAM[n], exit
//     @addr
//     D=M       // D = RAM[addr] = SCREEN
//     @i
//     A=D+M     // A = SCREEN + RAM[i]
//     M=0       // RAM[SCREEN + RAM[i]] = 0 (clear pixel)
//     @i
//     M=M+1     // RAM[i]++
//     @LOOP
//     0;JMP
//   (END)
//
// Keyboard Input:
//   (WAIT_KEY)
//     @KBD
//     D=M
//     @WAIT_KEY
//     D;JEQ     // Wait until key pressed
//     // Process key in D
//
// -----------------------------------------------------------------------------
// TODO: Implementation
// -----------------------------------------------------------------------------
//
// These patterns can be implemented as helper functions or macros that
// generate the appropriate instruction sequences. For now, they serve as
// documentation and examples.
//
// Future implementations might include:
//   - Pattern generators
//   - Code templates
//   - Optimization helpers
//   - Common algorithm implementations

const std = @import("std");
const Instruction = @import("instruction.zig").Instruction;
const AInstruction = @import("a_instruction.zig").AInstruction;
const CInstruction = @import("c_instruction.zig").CInstruction;

// TODO: Implement pattern generators when needed
// Example function signatures:
//
// pub fn loadConstant(value: u15) Instruction { ... }
// pub fn loadFromMemory(address: u15) []Instruction { ... }
// pub fn storeToMemory(address: u15) []Instruction { ... }
// pub fn addValues() []Instruction { ... }
// pub fn createLoop(init: u15, limit: u15, body: []Instruction) []Instruction { ... }
