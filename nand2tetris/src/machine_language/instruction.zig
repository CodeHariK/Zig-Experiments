// =============================================================================
// Instruction - Unified Instruction Handling
// =============================================================================
//
// This module provides a unified interface for handling both A-instructions
// and C-instructions in the Hack machine language.
//
// -----------------------------------------------------------------------------
// Instruction Types
// -----------------------------------------------------------------------------
//
// Hack has two instruction types:
//   1. A-instruction: Load address/constant (0vvvvvvvvvvvvvvv)
//   2. C-instruction: Compute and control (111accccccdddjjj)
//
// -----------------------------------------------------------------------------
// Instruction Execution Model
// -----------------------------------------------------------------------------
//
// Fetch-Execute Cycle:
//   1. Fetch: Load instruction from ROM[PC]
//   2. Decode: Determine instruction type (A or C)
//   3. Execute: Perform operation
//   4. Update: Store results, update PC
//
// Two-Phase Execution:
//   - A-instruction: Sets A register (immediate)
//   - C-instruction: Uses A register (from previous instruction or current)
//
// -----------------------------------------------------------------------------
// Implementation
// -----------------------------------------------------------------------------

const std = @import("std");
const testing = std.testing;
const ERR = @import("types").Error;

const AInstruction = @import("a_instruction.zig").AInstruction;
const CInstruction = @import("c_instruction.zig").CInstruction;

/// Unified instruction type (either A or C)
pub const Instruction = union(enum) {
    a: AInstruction,
    c: CInstruction,

    const Self = @This();

    /// Create an A-instruction
    pub fn aInstruction(value: u16) !Self {
        // Treat value as binary (bit 15 = 0, bits 0-14 = value)
        const a_inst = try AInstruction.decode(value);
        return Self{ .a = a_inst };
    }

    /// Create a C-instruction
    pub fn cInstruction(comp: CInstruction.Computation, dest: CInstruction.Destination, jump: CInstruction.Jump) Self {
        const c_inst = CInstruction.create(comp, dest, jump);
        return Self{ .c = c_inst };
    }

    /// Encode instruction to 16-bit binary
    pub fn getValue(self: Self) u16 {
        return switch (self) {
            .a => self.a.value,
            .c => self.c.value,
        };
    }

    /// Decode 16-bit binary to instruction
    /// Automatically determines if it's an A or C instruction
    pub fn decode(binary: u16) !Self {
        // Try C-instruction first (bit 15 = 1)
        if (CInstruction.decode(binary)) |c_inst| {
            return Self{ .c = c_inst };
        } else |err| {
            // If it's not a C-instruction, try A-instruction
            if (err == ERR.NotCInstruction) {
                const a_inst = try AInstruction.decode(binary);
                return Self{ .a = a_inst };
            }
            // Some other error occurred
            return err;
        }
    }

    /// Check if instruction is an A-instruction
    pub fn isA(self: Self) bool {
        return switch (self) {
            .a => true,
            .c => false,
        };
    }

    /// Check if instruction is a C-instruction
    pub fn isC(self: Self) bool {
        return switch (self) {
            .a => false,
            .c => true,
        };
    }
};

// =============================================================================
// Tests
// =============================================================================

const memory_map = @import("memory_map.zig");
const SymbolTable = memory_map.SymbolTable;

test "multiplication program" {
    std.debug.print("\n=== Multiplication Program Test ===\n\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var symbol_table = try SymbolTable.init(allocator);
    defer symbol_table.deinit();

    // Setup labels and variables
    // LOOP label at address 4 (after @sum, M=0, @i, M=1)
    try symbol_table.addLabel("LOOP", 4);
    // END label at address 18 (after all loop instructions)
    try symbol_table.addLabel("END", 18);
    // Variables: sum at 16, i at 17
    _ = try symbol_table.addVariable("sum");
    _ = try symbol_table.addVariable("i");

    const assembly_lines = [_][]const u8{
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

    const expected_binary = [_]u16{
        0b0000000000010000, // @sum (16)
        0b1110101010001000, // M=0
        0b0000000000010001, // @i (17)
        0b1110111111001000, // M=1
        // (LOOP) - label, not an instruction
        0b0000000000010001, // @i (17)
        0b1111110000010000, // D=M
        0b0000000000000000, // @R0 (0)
        0b1111010011010000, // D=D-M
        0b0000000000010010, // @END (18)
        0b1110001100000001, // D;JGT
        0b0000000000000001, // @R1 (1)
        0b1111110000010000, // D=M
        0b0000000000010000, // @sum (16)
        0b1111000010001000, // M=D+M
        0b0000000000010001, // @i (17)
        0b1111110111001000, // M=M+1
        0b0000000000000100, // @LOOP (4)
        0b1110101010000111, // 0;JMP
        // (END) - label, not an instruction
        0b0000000000010000, // @sum (16)
        0b1111110000010000, // D=M
        0b0000000000000010, // @R2 (2)
        0b1110001100001000, // M=D
    };

    var instructions = std.ArrayList(Instruction).empty;
    defer instructions.deinit(allocator);

    // Parse assembly and build instructions
    for (assembly_lines) |line| {
        // Skip labels (lines starting with '(')
        if (line.len > 0 and line[0] == '(') {
            continue;
        }

        // Try parsing as A-instruction first
        if (line.len > 0 and line[0] == '@') {
            const a_inst = try AInstruction.fromAssembly(line, &symbol_table);
            try instructions.append(allocator, Instruction{ .a = a_inst });
        } else {
            // Must be a C-instruction
            const c_inst = try CInstruction.fromAssembly(line);
            try instructions.append(allocator, Instruction{ .c = c_inst });
        }
    }

    // Verify binary output
    std.debug.print("Generated binary:\n", .{});
    var all_match = true;
    for (instructions.items, 0..) |inst, i| {
        const binary = inst.getValue();
        const expected = expected_binary[i];
        const match = binary == expected;
        if (!match) all_match = false;
        std.debug.print("{b:0>16}\n", .{binary});
        if (!match) {
            std.debug.print("  ✗ Expected: {b:0>16}\n", .{expected});
        }
    }

    if (!all_match) {
        std.debug.print("\n✗ Binary output doesn't match expected!\n", .{});
        return ERR.TestFailed;
    }

    std.debug.print("\n✓ All binary instructions match expected output!\n", .{});
}
