// =============================================================================
// Hardware Module
// =============================================================================
//
// This module implements the complete Hack computer hardware, including:
//   - CPU (Central Processing Unit)
//   - ROM (Read-Only Memory)
//   - Screen (Memory-Mapped I/O Display)
//   - Keyboard (Memory-Mapped I/O Input)
//   - Computer (Complete System Integration)
//
// -----------------------------------------------------------------------------
// Module Overview
// -----------------------------------------------------------------------------
//
// The hardware module provides the physical components of the Hack computer:
//
//   1. CPU: Executes instructions, manages registers, performs computations
//   2. ROM: Stores program instructions (32K words)
//   3. Screen: 512×256 pixel display (memory-mapped at 16384-24575)
//   4. Keyboard: Keyboard input (memory-mapped at 24576)
//   5. Computer: Complete system that integrates all components
//
// -----------------------------------------------------------------------------
// Module Structure
// -----------------------------------------------------------------------------
//
// This module is organized as:
//
//   mod.zig (this file):
//     - Module documentation
//     - Public API exports
//
//   cpu.zig:
//     - CPU implementation
//     - Instruction execution
//     - Register management
//
//   rom.zig:
//     - ROM implementation
//     - Program storage
//     - Instruction fetching
//
//   screen.zig:
//     - Screen implementation
//     - Pixel buffer
//     - Display rendering
//
//   keyboard.zig:
//     - Keyboard implementation
//     - Key code handling
//     - Input polling
//
//   computer.zig:
//     - Computer system integration
//     - Component coordination
//     - Memory routing
//     - Execution cycle
//
// -----------------------------------------------------------------------------
// Dependencies
// -----------------------------------------------------------------------------
//
// This module depends on:
//
//   - types: Type definitions and utilities
//   - gates: Logic gates and ALU
//   - memory: RAM, registers, and PC
//   - machine_language: Instruction formats and decoding
//
// -----------------------------------------------------------------------------
// Usage
// -----------------------------------------------------------------------------
//
// Example: Create and run a computer
//
//   const hardware = @import("hardware");
//   const computer = hardware.Computer.init(program);
//   computer.tick(0); // Execute one instruction
//
// Example: Access individual components
//
//   const cpu = hardware.CPU.init();
//   const rom = hardware.ROM.initFromSlice(instructions);
//   const screen = hardware.Screen.init();
//   const keyboard = hardware.Keyboard.init();
//
// -----------------------------------------------------------------------------
// TODO: Implementation Status
// -----------------------------------------------------------------------------
//
// Current status: Documentation only
//
// Components to implement:
//   [ ] CPU (cpu.zig)
//   [ ] ROM (rom.zig)
//   [ ] Screen (screen.zig)
//   [ ] Keyboard (keyboard.zig)
//   [ ] Computer (computer.zig)
//
// -----------------------------------------------------------------------------

// TODO: Uncomment and implement when ready
// pub const CPU = @import("cpu.zig").CPU;
// pub const ROM = @import("rom.zig").ROM;
// pub const Screen = @import("screen.zig").Screen;
// pub const Keyboard = @import("keyboard.zig").Keyboard;
// pub const Computer = @import("computer.zig").Computer;
pub const alu = @import("alu.zig");

// Placeholder exports (remove when implementing)
pub const cpu = struct {};
pub const rom = struct {};
pub const screen = struct {};
pub const keyboard = struct {};
pub const computer = struct {};

// ============================================================================
// Tests
// ============================================================================

const std = @import("std");
const testing = std.testing;

test "gates module: include all gate tests" {
    _ = @import("alu.zig");
    _ = @import("keyboard.zig");
    _ = @import("screen.zig");
    _ = @import("rom.zig");
    // _ = @import("memory.zig");
    // _ = @import("computer.zig");
    // _ = @import("cpu.zig");
}
