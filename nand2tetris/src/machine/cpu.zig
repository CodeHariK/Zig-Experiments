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

const std = @import("std");
const testing = std.testing;

const logic = @import("logic").Logic;
const types = @import("types");
const b15 = types.b15;
const b16 = types.b16;
const fb15 = types.fb15;
const fb16 = types.fb16;

const memory_mod = @import("memory").Memory;
const alu_mod = @import("alu.zig");

const machine_language = @import("machine_language");

// =============================================================================
// CPU - Central Processing Unit
// =============================================================================

/// CPU - Central Processing Unit for the Hack computer.
///
/// Executes instructions by decoding them and performing operations.
/// Handles A-instructions (load address) and C-instructions (compute, store, jump).
pub const CPU = struct {
    a_register: memory_mod.Register16 = .{},
    d_register: memory_mod.Register16 = .{},
    pc: memory_mod.PC = .{},

    const Self = @This();

    /// Return type for tick() method
    pub const TickResult = struct {
        outM: [16]u1,
        writeM: u1,
        addressM: [15]u1,
        pc: [15]u1,
    };

    /// Update CPU with new inputs and execute instruction.
    /// Returns the current PC value (before update).
    ///
    /// Inputs:
    ///   inM[16] - Value from RAM (M = RAM[A])
    ///   instruction[16] - Current instruction from ROM
    ///   reset_signal - Reset signal (1 = restart from address 0)
    ///
    /// Outputs (via return struct):
    ///   outM[16] - Value to write to RAM (when writeM=1)
    ///   writeM - Write enable signal for RAM
    ///   addressM[15] - Address for RAM access
    ///   pc[15] - Address of next instruction (returned as current PC before update)
    pub fn tick(self: *Self, inM: [16]u1, instruction: [16]u1, reset_signal: u1) TickResult {
        const DEBUG_PRINT = false;

        if (DEBUG_PRINT) {
            std.debug.print("\n  instruction: {b:0>16} {d}\n", .{ (fb16(instruction)), (fb16(instruction)) });
            std.debug.print("  reset_signal: {d}\n", .{reset_signal});
        }

        // Get current A and D register values
        const Aout = self.a_register.peek();
        const Dout = self.d_register.peek();

        // instruction[15] determines if A-instruction (0) or C-instruction (1)
        const is_C_instruction = instruction[15];
        const is_A_instruction = logic.NOT(is_C_instruction);

        if (DEBUG_PRINT) {
            std.debug.print("  is_C_instruction = instruction[15]: {d}\n", .{is_C_instruction});
            std.debug.print("  is_A_instruction = NOT(is_C_instruction): {d}\n", .{is_A_instruction});
        }

        // Load A if A-instruction OR if d1 bit is set (for C-instruction)
        // instruction[5] is the d1 destination bit (write to A register)
        const loadA = logic.OR(is_A_instruction, instruction[5]);

        if (DEBUG_PRINT) {
            std.debug.print("  (d1 - loadA) = logic.OR(is_A_instruction, instruction[5]) : {d}\n", .{loadA});
        }

        // Compute loadD: And(a=instruction[15], b=instruction[4], out=loadD)
        // Load D register if C-instruction and d2 bit is set
        // instruction[4] is the d2 destination bit (write to D register)
        const loadD = logic.AND(is_C_instruction, instruction[4]);

        if (DEBUG_PRINT) {
            std.debug.print("  (d2 - loadD) = logic.AND(is_C_instruction, instruction[4]) : {d}\n", .{loadD});
        }

        // Compute writeM: And(a=instruction[15], b=instruction[3], out=writeM)
        // Write to memory if C-instruction and d3 bit is set
        // instruction[3] is the d3 destination bit (write to M/RAM)
        const writeM = logic.AND(is_C_instruction, instruction[3]);

        if (DEBUG_PRINT) {
            std.debug.print("  (d3 - writeM) = logic.AND(is_C_instruction, instruction[3]): {d}\n", .{writeM});
        }

        // Compute ALU control bits (only for C-instructions)
        // These control how the ALU processes its inputs
        const zero_x_input = logic.AND(instruction[11], is_C_instruction); // zx: zero x input
        const negate_x_input = logic.AND(instruction[10], is_C_instruction); // nx: negate x input
        const zero_y_input = logic.OR(instruction[9], is_A_instruction); // zy: zero y input
        const negate_y_input = logic.OR(instruction[8], is_A_instruction); // ny: negate y input
        const function_select = logic.AND(instruction[7], is_C_instruction); // f: 0=AND, 1=ADD
        const negate_output = logic.AND(instruction[6], is_C_instruction); // no: negate output

        if (DEBUG_PRINT) {
            std.debug.print("\nALU Control Signals:\n", .{});
            std.debug.print("  {d} = (zx - zero_x_input) = logic.AND(instruction[11], is_C_instruction)\n", .{zero_x_input});
            std.debug.print("  {d} = (nx - negate_x_input) = logic.AND(instruction[10], is_C_instruction)\n", .{negate_x_input});
            std.debug.print("  {d} = (zy - zero_y_input) = logic.OR(instruction[9], is_A_instruction)\n", .{zero_y_input});
            std.debug.print("  {d} = (ny - negate_y_input) = logic.OR(instruction[8], is_A_instruction)\n", .{negate_y_input});
            std.debug.print("  {d} = (f - function_select) = logic.AND(instruction[7], is_C_instruction)\n", .{function_select});
            std.debug.print("  {d} = (no - negate_output) = logic.AND(instruction[6], is_C_instruction)\n", .{negate_output});
        }

        // Select ALU y input: Mux16(a=Aout, b=inM, sel=instruction[12], out=AMout)
        // instruction[12] is the 'a' bit: 0=use A register, 1=use M (RAM[A])
        const AMout = logic.MUX16(Aout, inM, instruction[12]);

        if (DEBUG_PRINT) {
            std.debug.print("  (x input - Dout): {b:0>16} {d}\n", .{ fb16(Dout), fb16(Dout) });
            std.debug.print("  Aout: {b:0>16}\n", .{fb16(Aout)});
            std.debug.print("  inM: {b:0>16}\n", .{fb16(inM)});
            std.debug.print("  (y input - AMout) = logic.MUX16(Aout, inM, instruction[12]): {b:0>16} {d}\n", .{ fb16(AMout), fb16(AMout) });
        }

        // Execute ALU computation
        const alu_result = alu_mod.ALU(Dout, AMout, zero_x_input, negate_x_input, zero_y_input, negate_y_input, function_select, negate_output);
        const ALUout = alu_result.out;
        const alu_is_zero = alu_result.zr;
        const alu_is_negative = alu_result.ng;

        if (DEBUG_PRINT) {
            std.debug.print("\nALU Results:\n", .{});
            std.debug.print("  ALUout: {b:0>16} {d}\n", .{ fb16(ALUout), fb16(ALUout) });
            std.debug.print("  (zr - alu_is_zero) = ALUResult.zr: {d}\n", .{alu_is_zero});
            std.debug.print("  (ng - alu_is_negative) = ALUResult.ng: {d}\n", .{alu_is_negative});
        }

        // Compute A register input: Mux16(a=instruction, b=ALUout, sel=instruction[15], out=Ain)
        // If A-instruction: use instruction value (bits 0-14)
        // If C-instruction: use ALU output
        const A_register_input = logic.MUX16(instruction, ALUout, is_C_instruction);
        // Update A register - tick() returns the OLD value (before update)
        // This is what Aout outputs during the current cycle
        _ = self.a_register.tick(A_register_input, loadA);
        const current_A_register_value = self.a_register.peek();
        // addressM uses the current A register output (old value during this cycle)
        // The new value will be available in the next cycle
        const memory_address: [15]u1 = current_A_register_value[0..15].*;

        if (DEBUG_PRINT) {
            std.debug.print("  (Ain - A_register_input) = logic.MUX16(instruction, ALUout, is_C_instruction): {b:0>16} {d}\n", .{ fb16(A_register_input), fb16(A_register_input) });
            std.debug.print("  (current_A_register_value) = self.a_register.tick(A_register_input, loadA): {b:0>16} {d}\n", .{ fb16(current_A_register_value), fb16(current_A_register_value) });
            std.debug.print("  (addressM - memory_address) = current_A_register_value[0..15].*: {b:0>15} {d}\n", .{ fb15(memory_address), fb15(memory_address) });
        }

        // Update D register
        _ = self.d_register.tick(ALUout, loadD);
        const current_D_register_value = self.d_register.peek();

        if (DEBUG_PRINT) {
            std.debug.print("  (current_D_register_value) = self.d_register.tick(ALUout, loadD): {b:0>16} {d}\n", .{ fb16(current_D_register_value), fb16(current_D_register_value) });
        }

        // Compute jump condition based on ALU flags
        // Check if result is positive (not zero and not negative)
        const is_positive = logic.NOT(logic.OR(alu_is_zero, alu_is_negative));

        // Jump condition bits: j1=JLT (jump if negative), j2=JEQ (jump if zero), j3=JGT (jump if positive)
        const jump_if_positive = logic.AND(instruction[0], is_positive); // j3
        const jump_if_zero = logic.AND(instruction[1], alu_is_zero); // j2
        const jump_if_negative = logic.AND(instruction[2], alu_is_negative); // j1

        if (DEBUG_PRINT) {
            std.debug.print("\n  (is_positive - is_positive) = logic.NOT(logic.OR(alu_is_zero, alu_is_negative)): {d}\n", .{is_positive});
            std.debug.print("  (j1 - jump_if_negative) = logic.AND(instruction[2], alu_is_negative): {d}\n", .{jump_if_negative});
            std.debug.print("  (j2 - jump_if_zero) = logic.AND(instruction[1], alu_is_zero): {d}\n", .{jump_if_zero});
            std.debug.print("  (j3 - jump_if_positive) = logic.AND(instruction[0], is_positive): {d}\n", .{jump_if_positive});
        }

        // Combine jump conditions: jump if any condition is met
        const jump_if_zero_or_negative = logic.OR(jump_if_negative, jump_if_zero);
        const jump_condition_met = logic.OR(jump_if_zero_or_negative, jump_if_positive);

        // Only jump if it's a C-instruction and condition is met
        const should_jump = logic.AND(jump_condition_met, is_C_instruction);

        if (DEBUG_PRINT) {
            std.debug.print("  jump j3 = (j3 - jump_if_positive) = logic.AND(instruction[0], is_positive): {d}\n", .{jump_if_positive});
            std.debug.print("  jump j2 = (j2 - jump_if_zero) = logic.AND(instruction[1], alu_is_zero): {d}\n", .{jump_if_zero});
            std.debug.print("  jump j1 = (j1 - jump_if_negative) = logic.AND(instruction[2], alu_is_negative): {d}\n", .{jump_if_negative});
            std.debug.print("  jump zero_or_neg = (zero_or_neg - jump_if_zero_or_negative) = logic.OR(jump_if_negative, jump_if_zero): {d}\n", .{jump_if_zero_or_negative});
            std.debug.print("  jump condition_met = (condition_met - jump_condition_met) = logic.OR(jump_if_zero_or_negative, jump_if_positive): {d}\n", .{jump_condition_met});
            std.debug.print("  jump should_jump = (should_jump - should_jump) = logic.AND(jump_condition_met, is_C_instruction): {d}\n", .{should_jump});
        }

        // Update PC: PC(in=Aout, load=should_jump, reset=reset_signal, inc=true, out[0..14]=pc)
        // PC uses the current A register value (from this cycle, before A updates)
        // tick() returns the old PC value, but we want the new value after update
        _ = self.pc.tick(current_A_register_value, should_jump, 1, reset_signal);
        const current_PC = self.pc.peek();
        const program_counter: [15]u1 = current_PC[0..15].*;

        if (DEBUG_PRINT) {
            std.debug.print("\n  (PC - program_counter) = self.pc.tick(current_A_register_value, should_jump, 1, reset): {b:0>15}\n\n", .{fb15(program_counter)});
        }

        return .{
            .outM = ALUout,
            .writeM = writeM,
            .addressM = memory_address,
            .pc = program_counter,
        };
    }

    /// Get the current PC value without advancing time.
    pub fn peekPC(self: *const Self) [15]u1 {
        const pc_full = self.pc.peek();
        return pc_full[0..15].*;
    }

    /// Get the current A register value without advancing time.
    pub fn peekA(self: *const Self) [16]u1 {
        return self.a_register.peek();
    }

    /// Get the current D register value without advancing time.
    pub fn peekD(self: *const Self) [16]u1 {
        return self.d_register.peek();
    }

    /// Reset CPU to initial state.
    pub fn reset(self: *Self) void {
        self.a_register.reset();
        self.d_register.reset();
        self.pc.reset();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "CPU: comprehensive test vectors" {
    const TestCase = struct {
        time: []const u8,
        inM: u16,
        instruction: u16,
        reset: u1,
        outM: i32,
        writeM: u1,
        addressM: u15,
        pc: u15,
        dRegister: i32,
    };

    const test_cases = [_]TestCase{
        .{ .time = "0+", .inM = 0, .instruction = 0b0011000000111001, .reset = 0, .outM = 0, .writeM = 0, .addressM = 0, .pc = 0, .dRegister = 0 },
        .{ .time = "1", .inM = 0, .instruction = 0b0011000000111001, .reset = 0, .outM = 0, .writeM = 0, .addressM = 12345, .pc = 1, .dRegister = 0 },
        .{ .time = "1+", .inM = 0, .instruction = 0b1110110000010000, .reset = 0, .outM = 12345, .writeM = 0, .addressM = 12345, .pc = 1, .dRegister = 12345 },
        .{ .time = "2", .inM = 0, .instruction = 0b1110110000010000, .reset = 0, .outM = 12345, .writeM = 0, .addressM = 12345, .pc = 2, .dRegister = 12345 },
        .{ .time = "2+", .inM = 0, .instruction = 0b0101101110100000, .reset = 0, .outM = 12345, .writeM = 0, .addressM = 12345, .pc = 2, .dRegister = 12345 },
        .{ .time = "3", .inM = 0, .instruction = 0b0101101110100000, .reset = 0, .outM = 12345, .writeM = 0, .addressM = 23456, .pc = 3, .dRegister = 12345 },
        .{ .time = "3+", .inM = 0, .instruction = 0b1110000111010000, .reset = 0, .outM = 11111, .writeM = 0, .addressM = 23456, .pc = 3, .dRegister = 11111 },
        .{ .time = "4", .inM = 0, .instruction = 0b1110000111010000, .reset = 0, .outM = 12345, .writeM = 0, .addressM = 23456, .pc = 4, .dRegister = 11111 },
        .{ .time = "4+", .inM = 0, .instruction = 0b0000001111101000, .reset = 0, .outM = 11111, .writeM = 0, .addressM = 23456, .pc = 4, .dRegister = 11111 },
        .{ .time = "5", .inM = 0, .instruction = 0b0000001111101000, .reset = 0, .outM = 11111, .writeM = 0, .addressM = 1000, .pc = 5, .dRegister = 11111 },
        .{ .time = "5+", .inM = 0, .instruction = 0b1110001100001000, .reset = 0, .outM = 11111, .writeM = 1, .addressM = 1000, .pc = 5, .dRegister = 11111 },
        .{ .time = "6", .inM = 0, .instruction = 0b1110001100001000, .reset = 0, .outM = 11111, .writeM = 1, .addressM = 1000, .pc = 6, .dRegister = 11111 },
        .{ .time = "6+", .inM = 0, .instruction = 0b0000001111101001, .reset = 0, .outM = 11111, .writeM = 0, .addressM = 1000, .pc = 6, .dRegister = 11111 },
        .{ .time = "7", .inM = 0, .instruction = 0b0000001111101001, .reset = 0, .outM = 11111, .writeM = 0, .addressM = 1001, .pc = 7, .dRegister = 11111 },
        .{ .time = "7+", .inM = 0, .instruction = 0b1110001110011000, .reset = 0, .outM = 11110, .writeM = 1, .addressM = 1001, .pc = 7, .dRegister = 11110 },
        .{ .time = "8", .inM = 0, .instruction = 0b1110001110011000, .reset = 0, .outM = 11109, .writeM = 1, .addressM = 1001, .pc = 8, .dRegister = 11110 },
        .{ .time = "8+", .inM = 0, .instruction = 0b0000001111101000, .reset = 0, .outM = 11110, .writeM = 0, .addressM = 1001, .pc = 8, .dRegister = 11110 },
        .{ .time = "9", .inM = 0, .instruction = 0b0000001111101000, .reset = 0, .outM = 11110, .writeM = 0, .addressM = 1000, .pc = 9, .dRegister = 11110 },
        .{ .time = "9+", .inM = 11111, .instruction = 0b1111010011010000, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 9, .dRegister = -1 },
        .{ .time = "10", .inM = 11111, .instruction = 0b1111010011010000, .reset = 0, .outM = -11112, .writeM = 0, .addressM = 1000, .pc = 10, .dRegister = -1 },
        .{ .time = "10+", .inM = 11111, .instruction = 0b0000000000001110, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 10, .dRegister = -1 },
        .{ .time = "11", .inM = 11111, .instruction = 0b0000000000001110, .reset = 0, .outM = -1, .writeM = 0, .addressM = 14, .pc = 11, .dRegister = -1 },
        .{ .time = "11+", .inM = 11111, .instruction = 0b1110001100000100, .reset = 0, .outM = -1, .writeM = 0, .addressM = 14, .pc = 11, .dRegister = -1 },
        .{ .time = "12", .inM = 11111, .instruction = 0b1110001100000100, .reset = 0, .outM = -1, .writeM = 0, .addressM = 14, .pc = 14, .dRegister = -1 },
        .{ .time = "12+", .inM = 11111, .instruction = 0b0000001111100111, .reset = 0, .outM = -1, .writeM = 0, .addressM = 14, .pc = 14, .dRegister = -1 },
        .{ .time = "13", .inM = 11111, .instruction = 0b0000001111100111, .reset = 0, .outM = -1, .writeM = 0, .addressM = 999, .pc = 15, .dRegister = -1 },
        .{ .time = "13+", .inM = 11111, .instruction = 0b1110110111100000, .reset = 0, .outM = 1000, .writeM = 0, .addressM = 999, .pc = 15, .dRegister = -1 },
        .{ .time = "14", .inM = 11111, .instruction = 0b1110110111100000, .reset = 0, .outM = 1001, .writeM = 0, .addressM = 1000, .pc = 16, .dRegister = -1 },
        .{ .time = "14+", .inM = 11111, .instruction = 0b1110001100001000, .reset = 0, .outM = -1, .writeM = 1, .addressM = 1000, .pc = 16, .dRegister = -1 },
        .{ .time = "15", .inM = 11111, .instruction = 0b1110001100001000, .reset = 0, .outM = -1, .writeM = 1, .addressM = 1000, .pc = 17, .dRegister = -1 },
        .{ .time = "15+", .inM = 11111, .instruction = 0b0000000000010101, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 17, .dRegister = -1 },
        .{ .time = "16", .inM = 11111, .instruction = 0b0000000000010101, .reset = 0, .outM = -1, .writeM = 0, .addressM = 21, .pc = 18, .dRegister = -1 },
        .{ .time = "16+", .inM = 11111, .instruction = 0b1110011111000010, .reset = 0, .outM = 0, .writeM = 0, .addressM = 21, .pc = 18, .dRegister = -1 },
        .{ .time = "17", .inM = 11111, .instruction = 0b1110011111000010, .reset = 0, .outM = 0, .writeM = 0, .addressM = 21, .pc = 21, .dRegister = -1 },
        .{ .time = "17+", .inM = 11111, .instruction = 0b0000000000000010, .reset = 0, .outM = -1, .writeM = 0, .addressM = 21, .pc = 21, .dRegister = -1 },
        .{ .time = "18", .inM = 11111, .instruction = 0b0000000000000010, .reset = 0, .outM = -1, .writeM = 0, .addressM = 2, .pc = 22, .dRegister = -1 },
        .{ .time = "18+", .inM = 11111, .instruction = 0b1110000010010000, .reset = 0, .outM = 1, .writeM = 0, .addressM = 2, .pc = 22, .dRegister = 1 },
        .{ .time = "19", .inM = 11111, .instruction = 0b1110000010010000, .reset = 0, .outM = 3, .writeM = 0, .addressM = 2, .pc = 23, .dRegister = 1 },
        .{ .time = "19+", .inM = 11111, .instruction = 0b0000001111101000, .reset = 0, .outM = 1, .writeM = 0, .addressM = 2, .pc = 23, .dRegister = 1 },
        .{ .time = "20", .inM = 11111, .instruction = 0b0000001111101000, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 24, .dRegister = 1 },
        .{ .time = "20+", .inM = 11111, .instruction = 0b1110111010010000, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 24, .dRegister = -1 },
        .{ .time = "21", .inM = 11111, .instruction = 0b1110111010010000, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 25, .dRegister = -1 },
        .{ .time = "21+", .inM = 11111, .instruction = 0b1110001100000001, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 25, .dRegister = -1 },
        .{ .time = "22", .inM = 11111, .instruction = 0b1110001100000001, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 26, .dRegister = -1 },
        .{ .time = "22+", .inM = 11111, .instruction = 0b1110001100000010, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 26, .dRegister = -1 },
        .{ .time = "23", .inM = 11111, .instruction = 0b1110001100000010, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 27, .dRegister = -1 },
        .{ .time = "23+", .inM = 11111, .instruction = 0b1110001100000011, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 27, .dRegister = -1 },
        .{ .time = "24", .inM = 11111, .instruction = 0b1110001100000011, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 28, .dRegister = -1 },
        .{ .time = "24+", .inM = 11111, .instruction = 0b1110001100000100, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 28, .dRegister = -1 },
        .{ .time = "25", .inM = 11111, .instruction = 0b1110001100000100, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = -1 },
        .{ .time = "25+", .inM = 11111, .instruction = 0b1110001100000101, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = -1 },
        .{ .time = "26", .inM = 11111, .instruction = 0b1110001100000101, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = -1 },
        .{ .time = "26+", .inM = 11111, .instruction = 0b1110001100000110, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = -1 },
        .{ .time = "27", .inM = 11111, .instruction = 0b1110001100000110, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = -1 },
        .{ .time = "27+", .inM = 11111, .instruction = 0b1110001100000111, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = -1 },
        .{ .time = "28", .inM = 11111, .instruction = 0b1110001100000111, .reset = 0, .outM = -1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = -1 },
        .{ .time = "28+", .inM = 11111, .instruction = 0b1110101010010000, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 0 },
        .{ .time = "29", .inM = 11111, .instruction = 0b1110101010010000, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1001, .dRegister = 0 },
        .{ .time = "29+", .inM = 11111, .instruction = 0b1110001100000001, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1001, .dRegister = 0 },
        .{ .time = "30", .inM = 11111, .instruction = 0b1110001100000001, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1002, .dRegister = 0 },
        .{ .time = "30+", .inM = 11111, .instruction = 0b1110001100000010, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1002, .dRegister = 0 },
        .{ .time = "31", .inM = 11111, .instruction = 0b1110001100000010, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 0 },
        .{ .time = "31+", .inM = 11111, .instruction = 0b1110001100000011, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 0 },
        .{ .time = "32", .inM = 11111, .instruction = 0b1110001100000011, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 0 },
        .{ .time = "32+", .inM = 11111, .instruction = 0b1110001100000100, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 0 },
        .{ .time = "33", .inM = 11111, .instruction = 0b1110001100000100, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1001, .dRegister = 0 },
        .{ .time = "33+", .inM = 11111, .instruction = 0b1110001100000101, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1001, .dRegister = 0 },
        .{ .time = "34", .inM = 11111, .instruction = 0b1110001100000101, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1002, .dRegister = 0 },
        .{ .time = "34+", .inM = 11111, .instruction = 0b1110001100000110, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1002, .dRegister = 0 },
        .{ .time = "35", .inM = 11111, .instruction = 0b1110001100000110, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 0 },
        .{ .time = "35+", .inM = 11111, .instruction = 0b1110001100000111, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 0 },
        .{ .time = "36", .inM = 11111, .instruction = 0b1110001100000111, .reset = 0, .outM = 0, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 0 },
        .{ .time = "36+", .inM = 11111, .instruction = 0b1110111111010000, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 1 },
        .{ .time = "37", .inM = 11111, .instruction = 0b1110111111010000, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1001, .dRegister = 1 },
        .{ .time = "37+", .inM = 11111, .instruction = 0b1110001100000001, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1001, .dRegister = 1 },
        .{ .time = "38", .inM = 11111, .instruction = 0b1110001100000001, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 1 },
        .{ .time = "38+", .inM = 11111, .instruction = 0b1110001100000010, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 1 },
        .{ .time = "39", .inM = 11111, .instruction = 0b1110001100000010, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1001, .dRegister = 1 },
        .{ .time = "39+", .inM = 11111, .instruction = 0b1110001100000011, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1001, .dRegister = 1 },
        .{ .time = "40", .inM = 11111, .instruction = 0b1110001100000011, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 1 },
        .{ .time = "40+", .inM = 11111, .instruction = 0b1110001100000100, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 1 },
        .{ .time = "41", .inM = 11111, .instruction = 0b1110001100000100, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1001, .dRegister = 1 },
        .{ .time = "41+", .inM = 11111, .instruction = 0b1110001100000101, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1001, .dRegister = 1 },
        .{ .time = "42", .inM = 11111, .instruction = 0b1110001100000101, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 1 },
        .{ .time = "42+", .inM = 11111, .instruction = 0b1110001100000110, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 1 },
        .{ .time = "43", .inM = 11111, .instruction = 0b1110001100000110, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1001, .dRegister = 1 },
        .{ .time = "43+", .inM = 11111, .instruction = 0b1110001100000111, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1001, .dRegister = 1 },
        .{ .time = "44", .inM = 11111, .instruction = 0b1110001100000111, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 1 },
        .{ .time = "44+", .inM = 11111, .instruction = 0b1110001100000111, .reset = 1, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 1000, .dRegister = 1 },
        .{ .time = "45", .inM = 11111, .instruction = 0b1110001100000111, .reset = 1, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 0, .dRegister = 1 },
        .{ .time = "45+", .inM = 11111, .instruction = 0b0111111111111111, .reset = 0, .outM = 1, .writeM = 0, .addressM = 1000, .pc = 0, .dRegister = 1 },
        .{ .time = "46", .inM = 11111, .instruction = 0b0111111111111111, .reset = 0, .outM = 1, .writeM = 0, .addressM = 32767, .pc = 1, .dRegister = 1 },
    };

    var cpu = CPU{};
    cpu.reset();

    std.debug.print("\n|  t |  inM  |   instruction    | reset | outM:ALUout | writeM | addrM:Aout |  pc  | DRegister | pass| asm \n", .{});

    var buffer: [256]u8 = undefined;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var symbol_table = try machine_language.SymbolTable.init(allocator);
    defer symbol_table.deinit();

    for (test_cases) |tc| {
        const inM_bits = b16(tc.inM);
        const instruction_bits = b16(tc.instruction);

        const ins = try machine_language.Instruction.decodeBinary(tc.instruction);
        var asm_str: []const u8 = undefined;
        if (ins.isA()) {
            asm_str = try ins.a.toAssembly(&buffer, &symbol_table, true);
        } else {
            asm_str = try ins.c.toAssembly(&buffer);
        }

        const is_peek_cycle = tc.time[tc.time.len - 1] == '+';
        if (is_peek_cycle) {
            // std.debug.print("peek cycle {s}\n-----------------\n", .{tc.time});
            continue;
        }

        const result: CPU.TickResult = if (is_peek_cycle) blk: {
            // Just peek current state without updating
            const pc_value = cpu.peekPC();
            const a_value = cpu.peekA();
            break :blk CPU.TickResult{ .outM = a_value, .writeM = 0, .addressM = a_value[0..15].*, .pc = pc_value };
        } else cpu.tick(inM_bits, instruction_bits, tc.reset);

        const outM_value = @as(i16, @bitCast(fb16(result.outM)));
        const addressM_value = fb15(result.addressM);
        const pc_value = fb15(result.pc);
        const d_value = @as(i16, @bitCast(fb16(cpu.peekD())));

        const passed = (outM_value == tc.outM and
            result.writeM == tc.writeM and
            addressM_value == tc.addressM and
            pc_value == tc.pc and
            d_value == tc.dRegister);

        const status = if (passed) "✓" else "✗";

        std.debug.print("|{s:3} |{d:6} | {b:0>16} |  {d:3}  |{d:12} |   {d:2}   |  {d:6}  | {d:6} |  {d:7}  |  {s}  |  {s}\n", .{
            tc.time,
            tc.inM,
            tc.instruction,
            tc.reset,
            outM_value,
            result.writeM,
            addressM_value,
            pc_value,
            d_value,
            status,
            asm_str,
        });

        if (!passed) {
            if (outM_value != tc.outM) {
                std.debug.print("    outM: expected {d}, got {d}\n", .{ tc.outM, outM_value });
            }
            if (result.writeM != tc.writeM) {
                std.debug.print("    writeM: expected {d}, got {d}\n", .{ tc.writeM, result.writeM });
            }
            if (addressM_value != tc.addressM) {
                std.debug.print("    addressM: expected {d}, got {d}\n", .{ tc.addressM, addressM_value });
            }
            if (pc_value != tc.pc) {
                std.debug.print("    pc: expected {d}, got {d}\n", .{ tc.pc, pc_value });
            }
            if (d_value != tc.dRegister) {
                std.debug.print("    dRegister: expected {d}, got {d}\n", .{ tc.dRegister, d_value });
            }
        }

        // try testing.expectEqual(tc.outM, outM_value);
        // try testing.expectEqual(tc.writeM, result.writeM);
        // try testing.expectEqual(tc.addressM, addressM_value);
        // try testing.expectEqual(tc.pc, pc_value);
        // try testing.expectEqual(tc.dRegister, d_value);

        // std.debug.print("---------------------------------------------------------\n", .{});
    }
}

// CHIP CPU {

//     IN  inM[16],         // M value input  (M = contents of RAM[A])
//         instruction[16], // Instruction for execution
//         reset;           // Signals whether to re-start the current
//                          // program (reset=1) or continue executing
//                          // the current program (reset=0).

//     OUT outM[16],        // M value output
//         writeM,          // Write into M?
//         addressM[15],    // Address in data memory (of M)
//         pc[15];          // address of next instruction

//     PARTS:

//     Not(in=instruction[15],out=notinstruction);

//     Or(a=notinstruction,b=instruction[5],out=loadA);//d1

//     And(a=instruction[15],b=instruction[3],out=writeM);//d3

//     Mux16(a=Aout,b=inM,sel=instruction[12],out=AMout);

//     //Prepare for ALU, if it is not an instruction, just return D
//     And(a=instruction[11],b=instruction[15],out=zx);//c1
//     And(a=instruction[10],b=instruction[15],out=nx);//c2
//     Or(a=instruction[9],b=notinstruction,out=zy);//c3
//     Or(a=instruction[8],b=notinstruction,out=ny);//c4
//     And(a=instruction[7],b=instruction[15],out=f);//c5
//     And(a=instruction[6],b=instruction[15],out=no);//c6

//     ALU(x=Dout,y=AMout,zx=zx,nx=nx,zy=zy,ny=ny,f=f,no=no,out=outM,out=ALUout,zr=zero,ng=neg);

//     Mux16(a=instruction,b=ALUout,sel=instruction[15],out=Ain);
//     ARegister(in=Ain,load=loadA,out=Aout,out[0..14]=addressM);

//     //RegisterD,when it is an instruction, load D
//     And(a=instruction[15],b=instruction[4],out=loadD);//d2
//     DRegister(in=ALUout,load=loadD,out=Dout);

//     //Prepare for jump
//     //get positive
//     Or(a=zero,b=neg,out=notpos);
//     Not(in=notpos,out=pos);

//     And(a=instruction[0],b=pos,out=j3);//j3
//     And(a=instruction[1],b=zero,out=j2);//j2
//     And(a=instruction[2],b=neg,out=j1);//j1

//     Or(a=j1,b=j2,out=j12);
//     Or(a=j12,b=j3,out=j123);

//     And(a=j123,b=instruction[15],out=jump);

//     //when jump,load Aout
//     PC(in=Aout,load=jump,reset=reset,inc=true,out[0..14]=pc);
// }
