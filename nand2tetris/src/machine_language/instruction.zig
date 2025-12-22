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
        const binary: u16 = value;
        const a_inst = try AInstruction.decode(binary);
        return Self{ .a = a_inst };
    }

    /// Create a C-instruction
    pub fn cInstruction(comp: CInstruction.Computation, dest: CInstruction.Destination, jump: CInstruction.Jump) Self {
        const c_inst = CInstruction.create(comp, dest, jump);
        return Self{ .c = c_inst };
    }

    /// Encode instruction to 16-bit binary
    pub fn encode(self: Self) u16 {
        return switch (self) {
            .a => |a| a.encode(),
            .c => |c| c.encode(),
        };
    }

    /// Decode 16-bit binary to instruction
    /// Automatically determines if it's an A or C instruction
    pub fn decode(binary: u16) !Self {
        // Check if it's a C-instruction (bit 15 = 1)
        if ((binary >> 15) & 1 == 1) {
            if (CInstruction.decode(binary)) |c_inst| {
                return Self{ .c = c_inst };
            }
            return ERR.Error.InvalidInstruction;
        } else {
            // Must be an A-instruction (bit 15 = 0)
            const a_inst = AInstruction.decode(binary) catch |err| {
                return err;
            };
            return Self{ .a = a_inst };
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

    /// Get A-instruction value (only valid if isA() returns true)
    pub fn getAValue(self: Self) ?u15 {
        return switch (self) {
            .a => |a| a.getValue(),
            .c => null,
        };
    }

    /// Get C-instruction (only valid if isC() returns true)
    pub fn getCInstruction(self: Self) ?CInstruction {
        return switch (self) {
            .a => null,
            .c => |c| c,
        };
    }
};

// =============================================================================
// Tests
// =============================================================================

test "Instruction: create A-instruction" {
    const inst = try Instruction.aInstruction(123);
    try testing.expect(inst.isA());
    try testing.expect(!inst.isC());
    try testing.expectEqual(@as(?u15, 123), inst.getAValue());
}

test "Instruction: create C-instruction" {
    const comp = CInstruction.Computation.fromBits(0, 0b101010);
    const inst = Instruction.cInstruction(comp, .D, .null);
    try testing.expect(!inst.isA());
    try testing.expect(inst.isC());
    try testing.expect(inst.getCInstruction() != null);
}

test "Instruction: encode A-instruction" {
    const inst = try Instruction.aInstruction(456);
    const binary = inst.encode();
    try testing.expectEqual(@as(u16, 456), binary);
    try testing.expectEqual(@as(u16, 0), (binary >> 15) & 1); // Bit 15 = 0
}

test "Instruction: encode C-instruction" {
    const comp = CInstruction.Computation.fromBits(1, 0b110000);
    const inst = Instruction.cInstruction(comp, .M, .JGT);
    const binary = inst.encode();
    try testing.expectEqual(@as(u16, 0b111), (binary >> 13) & 0b111); // Prefix = 111
}

test "Instruction: decode A-instruction" {
    const binary: u16 = 789;
    const inst = try Instruction.decode(binary);
    try testing.expect(inst.isA());
    try testing.expectEqual(@as(?u15, 789), inst.getAValue());
}

test "Instruction: decode C-instruction" {
    const binary: u16 = 0b1111110000010000; // D=M
    const inst = try Instruction.decode(binary);
    try testing.expect(inst.isC());
    try testing.expect(inst.getCInstruction() != null);
}

test "Instruction: round-trip A-instruction" {
    const original = try Instruction.aInstruction(9999);
    const binary = original.encode();
    const decoded = try Instruction.decode(binary);
    try testing.expect(decoded.isA());
    try testing.expectEqual(@as(?u15, 9999), decoded.getAValue());
}

test "Instruction: round-trip C-instruction" {
    const comp = CInstruction.Computation.fromBits(0, 0b001100); // D
    const original = Instruction.cInstruction(comp, .AMD, .JMP);
    const binary = original.encode();
    const decoded = try Instruction.decode(binary);
    try testing.expect(decoded.isC());
    const decoded_c = decoded.getCInstruction();
    try testing.expect(decoded_c != null);
    try testing.expectEqual(CInstruction.Destination.AMD, decoded_c.?.getDestination());
    try testing.expectEqual(CInstruction.Jump.JMP, decoded_c.?.getJump());
}
