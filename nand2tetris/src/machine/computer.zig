// =============================================================================
// Computer (Complete System)
// =============================================================================
//
// The Computer is the complete Hack computer system that integrates all
// components: CPU, ROM, RAM, Screen, and Keyboard.
//
// -----------------------------------------------------------------------------
// Computer Overview
// -----------------------------------------------------------------------------
//
// The Computer is the complete system consisting of:
//
//   1. CPU (Central Processing Unit):
//      - Executes instructions
//      - Manages registers (A, D, PC)
//      - Performs computations via ALU
//
//   2. ROM (Read-Only Memory):
//      - Stores program instructions
//      - 32K words (0-32,767)
//      - Accessed via PC
//
//   3. RAM (Random Access Memory):
//      - Stores data and variables
//      - 16K words (0-16,383)
//      - Accessed via A register
//
//   4. Screen (Memory-Mapped I/O):
//      - 512×256 pixel display
//      - Addresses 16384-24575 (8K words)
//      - Accessed via RAM addresses
//
//   5. Keyboard (Memory-Mapped I/O):
//      - Keyboard input
//      - Address 24576 (1 word)
//      - Accessed via RAM address
//
// -----------------------------------------------------------------------------
// Computer Architecture
// -----------------------------------------------------------------------------
//
// System connections:
//
//   ┌─────────┐
//   │   ROM   │◄─── PC (from CPU)
//   └────┬────┘
//        │ instruction[16]
//        ▼
//   ┌─────────┐
//   │   CPU   │
//   └────┬────┘
//        │
//        ├───► addressM[15] ──┐
//        ├───► outM[16] ──────┤
//        ├───► writeM ────────┤
//        │                     │
//        │◄─── inM[16] ────────┤
//        │                     │
//        │                     ▼
//        │              ┌──────────┐
//        │              │  Memory  │
//        │              │  (16K)   │
//        │              └────┬─────┘
//        │                   │
//        │                   ├───► Screen (16384-24575)
//        │                   └───► Keyboard (24576)
//        │
//        └───► pc[15] ───────► ROM
//
// -----------------------------------------------------------------------------
// Computer Interface
// -----------------------------------------------------------------------------
//
// Inputs:
//   reset - Reset signal (1 = restart computer)
//
// Outputs:
//   (None directly - outputs go to Screen and other devices)
//
// Internal:
//   - All components are connected internally
//   - CPU fetches from ROM
//   - CPU reads/writes RAM
//   - RAM routes to Screen/Keyboard
//
// -----------------------------------------------------------------------------
// Memory Map
// -----------------------------------------------------------------------------
//
// Complete memory map:
//
//   Address Range    | Size  | Device    | Purpose
//   -----------------|-------|-----------|------------------
//   0 - 16,383       | 16K   | RAM       | Data and variables
//   16,384 - 24,575  | 8K    | Screen    | Display (512×256)
//   24,576           | 1     | Keyboard  | Keyboard input
//   0 - 32,767       | 32K   | ROM       | Program instructions
//
// Note: ROM and RAM have separate address spaces.
//       ROM is accessed via PC, RAM is accessed via A register.
//
// -----------------------------------------------------------------------------
// Computer Execution Cycle
// -----------------------------------------------------------------------------
//
// The computer executes programs in a continuous cycle:
//
//   1. RESET (if reset=1):
//      - PC = 0
//      - Registers reset
//      - Memory cleared (optional)
//
//   2. FETCH:
//      - instruction = ROM[PC]
//      - Send instruction to CPU
//
//   3. EXECUTE:
//      - CPU decodes instruction
//      - CPU performs operation
//      - CPU updates registers
//      - CPU accesses RAM if needed
//
//   4. UPDATE:
//      - PC updated (incremented or jumped)
//      - RAM updated if write occurred
//      - Screen updated if RAM write was to screen address
//
//   5. REPEAT:
//      - Go back to step 2
//      - Continue until halted or reset
//
// -----------------------------------------------------------------------------
// Memory Routing
// -----------------------------------------------------------------------------
//
// RAM handles routing to memory-mapped I/O:
//
//   When CPU writes to RAM address A:
//     if A < 16384:
//         Write to RAM[A]
//     else if A < 24576:
//         Write to Screen (address A - 16384)
//     else if A == 24576:
//         Write to Keyboard (typically ignored, keyboard is read-only)
//
//   When CPU reads from RAM address A:
//     if A < 16384:
//         Read from RAM[A]
//     else if A < 24576:
//         Read from Screen (address A - 16384)
//     else if A == 24576:
//         Read from Keyboard
//
// -----------------------------------------------------------------------------
// Computer Initialization
// -----------------------------------------------------------------------------
//
// To initialize the computer:
//
//   1. Load program into ROM:
//      - Assemble program to machine code
//      - Load instructions into ROM
//
//   2. Initialize RAM:
//      - Set initial values (optional)
//      - Clear memory (optional)
//
//   3. Initialize Screen:
//      - Clear display (all black)
//
//   4. Initialize Keyboard:
//      - Set key code to 0 (no key)
//
//   5. Reset CPU:
//      - Set PC to 0
//      - Reset registers
//
// -----------------------------------------------------------------------------
// Computer Execution
// -----------------------------------------------------------------------------
//
// To run the computer:
//
//   1. Set reset = 0 (if was 1)
//   2. For each clock tick:
//      - Call computer.tick()
//      - Computer executes one instruction
//      - Update display if needed
//      - Check for keyboard input
//   3. Continue until program halts or reset
//
// -----------------------------------------------------------------------------
// Implementation Structure
// -----------------------------------------------------------------------------
//
// This module will be organized as:
//
//   computer.zig (this file):
//     - Computer struct
//     - Component integration
//     - Memory routing
//     - Execution cycle
//
//   Components used:
//     - CPU (from cpu.zig)
//     - ROM (from rom.zig)
//     - RAM (from memory module)
//     - Screen (from screen.zig)
//     - Keyboard (from keyboard.zig)
//
// -----------------------------------------------------------------------------
// Computer Implementation
// -----------------------------------------------------------------------------
//
// Implementation structure:
//
//   pub const Computer = struct {
//       cpu: CPU,
//       rom: ROM,
//       ram: RAM, // from memory module
//       screen: Screen,
//       keyboard: Keyboard,
//
//       // Initialize computer with program
//       pub fn init(program: []const u16) Computer { ... }
//
//       // Execute one instruction (one clock tick)
//       pub fn tick(self: *Computer, reset: u1) void { ... }
//
//       // Load program into ROM
//       pub fn loadProgram(self: *Computer, program: []const u16) void { ... }
//
//       // Reset computer
//       pub fn reset(self: *Computer) void { ... }
//   };
//
// -----------------------------------------------------------------------------
// Memory Routing Implementation
// -----------------------------------------------------------------------------
//
// RAM routing logic:
//
//   fn routeMemoryAccess(address: u16) MemoryDevice {
//       if (address < 16384) {
//           return .ram;
//       } else if (address < 24576) {
//           return .screen;
//       } else if (address == 24576) {
//           return .keyboard;
//       } else {
//           return .invalid;
//       }
//   }
//
// When CPU reads/writes:
//   1. Check address range
//   2. Route to appropriate device
//   3. Perform operation
//   4. Return result (for reads)
//
// -----------------------------------------------------------------------------
// TODO: Implementation
// -----------------------------------------------------------------------------
//
// To implement Computer:
//
//   1. Create Computer struct with all components:
//      - cpu: CPU
//      - rom: ROM
//      - ram: RAM (from memory module)
//      - screen: Screen
//      - keyboard: Keyboard
//
//   2. Implement initialization:
//      pub fn init(program: []const u16) Computer { ... }
//
//   3. Implement memory routing:
//      - Route RAM accesses to correct device
//      - Handle Screen addresses (16384-24575)
//      - Handle Keyboard address (24576)
//
//   4. Implement tick() function:
//      pub fn tick(self: *Computer, reset: u1) void {
//          // Fetch instruction from ROM
//          // Execute in CPU
//          // Handle memory access
//          // Update components
//      }
//
//   5. Implement program loading:
//      pub fn loadProgram(self: *Computer, program: []const u16) void { ... }
//
//   6. Implement reset:
//      pub fn reset(self: *Computer) void { ... }
//
//   7. Add helper methods:
//      - Get CPU state
//      - Get memory contents
//      - Get screen buffer
//      - Get keyboard state
//
// -----------------------------------------------------------------------------
// Testing Strategy
// -----------------------------------------------------------------------------
//
// Test Computer with:
//
//   1. Initialization:
//      - Create computer with program
//      - Verify all components initialized
//
//   2. Program execution:
//      - Load simple program
//      - Execute instructions
//      - Verify correct execution
//
//   3. Memory access:
//      - Test RAM access
//      - Test Screen access
//      - Test Keyboard access
//      - Test address routing
//
//   4. Integration tests:
//      - Run complete programs
//      - Verify final state
//      - Test screen output
//      - Test keyboard input
//
//   5. Reset behavior:
//      - Test reset signal
//      - Verify PC resets to 0
//      - Verify state is cleared
//
// -----------------------------------------------------------------------------

const std = @import("std");
const testing = std.testing;

const types = @import("types");
const b15 = types.b15;
const b16 = types.b16;
const fb15 = types.fb15;
const fb16 = types.fb16;

const cpu_mod = @import("cpu.zig");
const rom_mod = @import("rom.zig");
const memory_mod = @import("memory.zig");

const machine_language = @import("machine_language");

// =============================================================================
// Computer - Complete Hack Computer System
// =============================================================================

/// Computer - Complete Hack computer system integrating CPU, ROM, and Memory.
///
/// Implements the complete computer according to the HDL specification:
///   CHIP Computer {
///       IN reset;
///       PARTS:
///       CPU(instruction=instruction, reset=reset, inM=outMemo, outM=CPUoutM, writeM=wM, addressM=adM, pc=PC);
///       Memory(in=CPUoutM, load=wM, address=adM, out=outMemo);
///       ROM32K(address=PC, out=instruction);
///   }
pub const Computer = struct {
    cpu: cpu_mod.CPU = .{},
    rom: rom_mod.ROM32K = .{},
    memory: memory_mod.Memory = .{},

    const Self = @This();

    /// Execute one instruction cycle.
    ///
    /// Execution flow:
    ///   1. Get current PC from CPU
    ///   2. Read instruction from ROM[PC]
    ///   3. Get current A register (addressM) from CPU
    ///   4. Read inM from Memory[addressM]
    ///   5. Execute CPU tick with instruction, reset_signal, inM
    ///   6. Update Memory with CPU outputs (outM, writeM, addressM)
    ///
    /// Inputs:
    ///   reset_signal - Reset signal (1 = restart computer from address 0)
    pub fn tick(self: *Self, reset_signal: u1) void {
        // 1. Get current PC from CPU to fetch instruction
        const current_pc = self.cpu.peekPC();

        // 2. Read instruction from ROM[PC]
        const instruction = self.rom.read(current_pc);

        // 3. Get current A register value (addressM) from CPU
        // This is the address that CPU will use to access Memory
        const current_a = self.cpu.peekA();
        const addressM: [15]u1 = current_a[0..15].*;

        // 4. Read inM from Memory[addressM] (using peek to get current value)
        const inM = self.memory.peek(addressM);

        // 5. Execute CPU tick with instruction, reset_signal, and inM
        const cpu_result = self.cpu.tick(inM, instruction, reset_signal);

        // 6. Update Memory with CPU outputs
        // Memory.tick() handles routing to RAM, Screen, or Keyboard based on addressM
        _ = self.memory.tick(cpu_result.outM, cpu_result.addressM, cpu_result.writeM);
    }

    /// Load program into ROM.
    ///
    /// This initializes the ROM with the program instructions.
    /// The program should be an array of 16-bit machine code instructions.
    ///
    /// Inputs:
    ///   program - Slice of 16-bit instructions to load into ROM
    pub fn loadProgram(self: *Self, allocator: std.mem.Allocator, program: *machine_language.Program) !void {
        var binary = try program.toBinaryArray(allocator);
        defer binary.deinit(allocator);
        self.rom.initFromSlice(binary.items);
    }

    /// Reset computer to initial state.
    ///
    /// Resets CPU, ROM, and Memory to their initial states.
    /// PC is set to 0, registers are cleared, and memory is zeroed.
    pub fn reset(self: *Self) void {
        self.cpu.reset();
        self.rom.reset();
        self.memory.reset();
    }

    /// Get the current PC value.
    pub fn getPC(self: *const Self) [15]u1 {
        return self.cpu.peekPC();
    }

    /// Get the current A register value.
    pub fn getA(self: *const Self) [16]u1 {
        return self.cpu.peekA();
    }

    /// Get the current D register value.
    pub fn getD(self: *const Self) [16]u1 {
        return self.cpu.peekD();
    }

    /// Get a reference to the Memory component for direct access.
    /// This allows reading/writing memory directly if needed.
    pub fn getMemory(self: *Self) *memory_mod.Memory {
        return &self.memory;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "Computer: basic initialization and reset" {
    var computer = Computer{};
    computer.reset();

    // After reset, PC should be 0
    const pc = computer.getPC();
    try testing.expectEqual(@as(u15, 0), fb15(pc));
}

const add_program_assembly = [_][]const u8{
    "@2", // Load 2 into A register
    "D=A", // Copy A (2) to D register
    "@3", // Load 3 into A register
    "D=D+A", // Add A (3) to D (2), result (5) in D
    "@0", // Load 0 into A register (address for result)
    "M=D", // Store D (5) into RAM[0]
};

test "Computer: Add.hack program execution" {
    var computer = Computer{};
    computer.reset();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var add_program = try machine_language.Program.init(allocator);
    defer add_program.deinit(allocator);

    try add_program.fromAssemblyArray(allocator, &add_program_assembly);

    try computer.loadProgram(allocator, &add_program);

    // Print header
    std.debug.print("\n|time |reset|ARegister|DRegister|PC[]|RAM16K[0]|RAM16K[1]|RAM16K[2]|\n", .{});

    // Helper function to print state
    const printState = struct {
        fn print(time_val: u32, reset_val: u1, comp: *Computer) void {
            const a_reg = fb16(comp.getA());
            const d_reg = fb16(comp.getD());
            const pc = fb15(comp.getPC());
            const memory = comp.getMemory();
            const ram0 = fb16(memory.peek(b15(0)));
            const ram1 = fb16(memory.peek(b15(1)));
            const ram2 = fb16(memory.peek(b15(2)));
            std.debug.print("|{d:4} |{d:4} |{d:8} |{d:8} |{d:3}|{d:8} |{d:8} |{d:8} |\n", .{
                time_val, reset_val, a_reg, d_reg, pc, ram0, ram1, ram2,
            });
        }
    }.print;

    // Initial state (time 0)
    printState(0, 0, &computer);

    // First run: execute 6 instructions
    var time: u32 = 1;
    var i: u32 = 0;
    while (i < 6) : (i += 1) {
        computer.tick(0);
        printState(time, 0, &computer);
        time += 1;
    }

    // Reset: clear RAM[0] first, then reset
    const memory = computer.getMemory();
    _ = memory.tick(b16(0), b15(0), 1); // Clear RAM[0]
    computer.tick(1); // Reset with reset=1
    printState(time, 1, &computer);
    time += 1;

    // Second run: execute 6 instructions again
    i = 0;
    while (i < 6) : (i += 1) {
        computer.tick(0);
        printState(time, 0, &computer);
        time += 1;
    }
}

// Mult.asm - Multiplication program: R2 = R0 * R1

const mult_program_assembly = [_][]const u8{
    "@sum",
    "M=0",
    "@i",
    "M=1",
    "(LOOP)",
    "@i",
    "D=M",
    "@R0",
    "D=D-M",
    "@END",
    "D;JGT",
    "@R1",
    "D=M",
    "@sum",
    "M=D+M",
    "@i",
    "M=M+1",
    "@LOOP",
    "0;JMP",
    "(END)",
    "@sum",
    "D=M",
    "@R2",
    "M=D",
};

test "Computer: Mult.hack program execution" {
    var computer = Computer{};
    computer.reset();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var mult_program = try machine_language.Program.init(allocator);
    defer mult_program.deinit(allocator);

    // Labels will be automatically collected during fromAssemblyArray
    // Variables will be automatically added when first encountered
    try mult_program.fromAssemblyArray(allocator, &mult_program_assembly);

    try computer.loadProgram(allocator, &mult_program);

    // Helper to set RAM value
    const setRAM = struct {
        fn set(comp: *Computer, address: u16, value: i16) void {
            const mem = comp.getMemory();
            const addr_bits = types.b15(address);
            const val_bits = types.b16(@as(u16, @bitCast(value)));
            _ = mem.tick(val_bits, addr_bits, 1);
        }
    }.set;

    // Helper function to print state (similar to Add.hack test)
    const printState = struct {
        fn print(time_val: u32, reset_val: u1, comp: *Computer) void {
            const a_reg = types.fb16(comp.getA());
            const d_reg = types.fb16(comp.getD());
            const pc = types.fb15(comp.getPC());
            const memory = comp.getMemory();
            const ram0 = types.fb16(memory.peek(types.b15(0)));
            const ram1 = types.fb16(memory.peek(types.b15(1)));
            const ram2 = types.fb16(memory.peek(types.b15(2)));
            std.debug.print("|{d:4} |{d:4} |{d:8} |{d:8} |{d:3}|{d:8} |{d:8} |{d:8} |\n", .{
                time_val, reset_val, a_reg, d_reg, pc, ram0, ram1, ram2,
            });
        }
    }.print;

    // Print header
    std.debug.print("\n|time |reset|ARegister|DRegister|PC[]|RAM16K[0]|RAM16K[1]|RAM16K[2]|\n", .{});

    // Helper function to run a test case
    const runTestCase = struct {
        var time_counter: u32 = 0;

        fn run(comp: *Computer, r0: i16, r1: i16, ticks: u32, print_intermediate: bool) void {
            // Reset only CPU and memory (not ROM, since program is already loaded)
            comp.cpu.reset();
            comp.memory.reset();

            if (print_intermediate) {
                printState(time_counter, 0, comp);
                time_counter += 1;
            }

            setRAM(comp, 0, r0);
            setRAM(comp, 1, r1);
            setRAM(comp, 2, -1);

            var i: u32 = 0;
            while (i < ticks) : (i += 1) {
                comp.tick(0);
                if (print_intermediate) {
                    printState(time_counter, 0, comp);
                    time_counter += 1;
                }
            }

            // Restore R0 and R1 in case the program changed them
            setRAM(comp, 0, r0);
            setRAM(comp, 1, r1);

            // Always print final state
            printState(time_counter, 0, comp);
            time_counter += 1;
        }
    }.run;

    // Test case 1: 0 * 0
    runTestCase(&computer, 0, 0, 20, false);

    // Test case 2: 1 * 0
    runTestCase(&computer, 1, 0, 50, false);

    // Test case 3: 0 * 2
    runTestCase(&computer, 0, 2, 80, false);

    // Test case 4: 3 * 1
    runTestCase(&computer, 3, 1, 120, false);

    // Test case 5: 2 * 4
    runTestCase(&computer, 2, 4, 150, false);

    // Test case 6: 6 * 7
    runTestCase(&computer, 6, 7, 210, false);
}

// Sum.asm - Adds 1+2+...+100
const sum_program_assembly = [_][]const u8{
    "@i", // @i (16) : A = 16 : i variable
    "M=1", // RAM[i] = 1 : initialize i to 1
    "@sum", // @sum (17) : A = 17 : sum variable
    "M=0", // RAM[sum] = 0 : initialize sum to 0
    "(LOOP)", // Loop label
    "@i", // @i : A = i variable address
    "D=M", // D = RAM[i] : load i into D
    "@100", // @100 : A = 100
    "D=D-A", // D = D - 100 : check if i > 100
    "@END", // @END : A = END label address
    "D;JGT", // if D > 0, jump to END
    "@i", // @i : A = i variable address
    "D=M", // D = RAM[i] : load i into D
    "@sum", // @sum : A = sum variable address
    "M=D+M", // RAM[sum] = RAM[sum] + RAM[i] : add i to sum
    "@i", // @i : A = i variable address
    "M=M+1", // RAM[i] = RAM[i] + 1 : increment i
    "@LOOP", // @LOOP : A = LOOP label address
    "0;JMP", // 0;JMP : jump to LOOP
    "(END)", // (END) : end label
    "@END", // @END : A = END label address
    "0;JMP", // 0;JMP : infinite loop
};

test "Computer: Sum.hack program execution (1+...+100)" {
    var computer = Computer{};
    computer.reset();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var sum_program = try machine_language.Program.init(allocator);
    defer sum_program.deinit(allocator);

    // Labels and variables will be automatically collected/added during fromAssemblyArray
    try sum_program.fromAssemblyArray(allocator, &sum_program_assembly);

    try computer.loadProgram(allocator, &sum_program);

    // Helper function to print state
    const printState = struct {
        fn print(time_val: u32, reset_val: u1, comp: *Computer) void {
            const a_reg = types.fb16(comp.getA());
            const d_reg = types.fb16(comp.getD());
            const pc = types.fb15(comp.getPC());
            const memory = comp.getMemory();
            // Print i (RAM[16]), sum (RAM[17])
            const i_val = types.fb16(memory.peek(types.b15(16)));
            const sum_val = types.fb16(memory.peek(types.b15(17)));
            std.debug.print("|{d:4} |{d:4} |{d:8} |{d:8} |{d:3}|{d:8} |{d:8} |\n", .{
                time_val, reset_val, a_reg, d_reg, pc, i_val, sum_val,
            });
        }
    }.print;

    // Print header
    std.debug.print("\n|time |reset|ARegister|DRegister|PC[]|RAM16K[16](i)|RAM16K[17](sum)|\n", .{});

    // Reset only CPU and memory (not ROM, since program is already loaded)
    computer.cpu.reset();
    computer.memory.reset();

    var time: u32 = 0;
    printState(time, 0, &computer);
    time += 1;

    // Run for 1500 cycles
    var i: u32 = 0;
    while (i < 1500) : (i += 1) {
        computer.tick(0);
        // Print every 100th cycle
        if (time % 100 == 0) {
            printState(time, 0, &computer);
        }
        time += 1;
    }

    // Print final result after 1500 cycles
    printState(time - 1, 0, &computer);
}
