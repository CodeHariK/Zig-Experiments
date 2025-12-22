// =============================================================================
// C-Instruction (Compute Instruction)
// =============================================================================
//
// The C-instruction performs computation and optionally stores the result
// and/or conditionally jumps based on the computation result.
//
// -----------------------------------------------------------------------------
// Format
// -----------------------------------------------------------------------------
//
// Binary: 111accccccdddjjj (16 bits)
//   - Bits 15-13 = 111 (identifies C-instruction)
//   - Bit 12 = a (ALU input selector: 0=A, 1=M)
//   - Bits 6-11 = cccccc (ALU computation bits)
//   - Bits 3-5 = ddd (destination bits)
//   - Bits 0-2 = jjj (jump condition bits)
//
// Assembly: dest=comp;jump
//   - dest: Where to store result (optional)
//   - comp: Computation to perform (required)
//   - jump: Jump condition (optional)
//
// -----------------------------------------------------------------------------
// Components
// -----------------------------------------------------------------------------
//
// 1. Computation (comp): What operation to perform
//    - ALU operations: add, subtract, AND, OR, NOT, etc.
//    - Can operate on A, D, M (memory at address A), or combinations
//
// 2. Destination (dest): Where to store the result
//    - null: Don't store
//    - M: Store in RAM[A]
//    - D: Store in D register
//    - A: Store in A register
//    - Combinations: MD, AM, AD, AMD
//
// 3. Jump (jump): Conditional jump based on ALU output
//    - null: No jump
//    - JGT: Jump if output > 0
//    - JEQ: Jump if output = 0
//    - JGE: Jump if output ≥ 0
//    - JLT: Jump if output < 0
//    - JNE: Jump if output ≠ 0
//    - JLE: Jump if output ≤ 0
//    - JMP: Unconditional jump
//
// -----------------------------------------------------------------------------
// Implementation
// -----------------------------------------------------------------------------

const std = @import("std");
const testing = std.testing;

/// Destination field for C-instruction
pub const Destination = enum(u3) {
    null = 0b000, // Don't store
    M = 0b001, // Store in RAM[A]
    D = 0b010, // Store in D register
    MD = 0b011, // Store in M and D
    A = 0b100, // Store in A register
    AM = 0b101, // Store in A and M
    AD = 0b110, // Store in A and D
    AMD = 0b111, // Store in A, M, and D
};

/// Jump condition field for C-instruction
pub const Jump = enum(u3) {
    null = 0b000, // No jump
    JGT = 0b001, // Jump if greater than 0
    JEQ = 0b010, // Jump if equal to 0
    JGE = 0b011, // Jump if greater or equal
    JLT = 0b100, // Jump if less than 0
    JNE = 0b101, // Jump if not equal to 0
    JLE = 0b110, // Jump if less or equal
    JMP = 0b111, // Unconditional jump
};

/// Computation field for C-instruction
/// This represents the ALU computation bits (6 bits) and the 'a' bit
pub const Computation = struct {
    a: u1, // ALU input selector: 0=A, 1=M
    comp: u6, // ALU computation bits

    const Self = @This();

    /// Create computation from a and comp bits
    pub fn fromBits(a: u1, comp: u6) Self {
        return Self{ .a = a, .comp = comp };
    }

    /// Get the full 7-bit computation field (a + comp)
    pub fn getField(self: Self) u7 {
        return (@as(u7, self.a) << 6) | @as(u7, self.comp);
    }
};

/// C-instruction structure
pub const CInstruction = struct {
    comp: Computation,
    dest: Destination,
    jump: Jump,

    const Self = @This();

    /// Create a C-instruction
    pub fn create(comp: Computation, dest: Destination, jump: Jump) Self {
        return Self{
            .comp = comp,
            .dest = dest,
            .jump = jump,
        };
    }

    /// Encode C-instruction to 16-bit binary
    /// Format: 111accccccdddjjj
    pub fn encode(self: Self) u16 {
        const prefix: u16 = 0b111 << 13; // Bits 15-13 = 111
        const a_comp: u16 = @as(u16, self.comp.getField()) << 6; // Bits 6-12
        const dest_bits: u16 = @as(u16, @intFromEnum(self.dest)) << 3; // Bits 3-5
        const jump_bits: u16 = @intFromEnum(self.jump); // Bits 0-2

        return prefix | a_comp | dest_bits | jump_bits;
    }

    /// Decode 16-bit binary to C-instruction
    /// Returns null if not a valid C-instruction (bits 15-13 must be 111)
    pub fn decode(binary: u16) ?Self {
        // Check if bits 15-13 are 111
        const prefix = (binary >> 13) & 0b111;
        if (prefix != 0b111) {
            return null; // Not a C-instruction
        }

        // Extract fields
        const a = @as(u1, @truncate((binary >> 12) & 1));
        const comp_bits = @as(u6, @truncate((binary >> 6) & 0b111111));
        const comp = Computation.fromBits(a, comp_bits);

        const dest = @as(Destination, @enumFromInt((binary >> 3) & 0b111));
        const jump = @as(Jump, @enumFromInt(binary & 0b111));

        return Self{
            .comp = comp,
            .dest = dest,
            .jump = jump,
        };
    }

    /// Get computation field
    pub fn getComputation(self: Self) Computation {
        return self.comp;
    }

    /// Get destination field
    pub fn getDestination(self: Self) Destination {
        return self.dest;
    }

    /// Get jump field
    pub fn getJump(self: Self) Jump {
        return self.jump;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "C-instruction: create and encode" {
    const comp = Computation.fromBits(0, 0b101010); // 0
    const inst = CInstruction.create(comp, .D, .null);
    const binary = inst.encode();

    // Check prefix (bits 15-13 = 111)
    try testing.expectEqual(@as(u16, 0b111), @as(u16, (binary >> 13) & 0b111));
}

test "C-instruction: decode valid binary" {
    // Example: D=M (load from memory)
    // 111 1 110000 010 000
    const binary: u16 = 0b1111110000010000;
    const inst = CInstruction.decode(binary);
    try testing.expect(inst != null);
    try testing.expectEqual(Destination.D, inst.?.getDestination());
}

test "C-instruction: decode rejects A-instruction" {
    // A-instruction has bit 15 = 0
    const binary: u16 = 5;
    const inst = CInstruction.decode(binary);
    try testing.expect(inst == null);
}

test "C-instruction: round-trip encoding" {
    const comp = Computation.fromBits(1, 0b110000); // M
    const inst = CInstruction.create(comp, .MD, .JGT);
    const binary = inst.encode();
    const decoded = CInstruction.decode(binary);
    try testing.expect(decoded != null);
    try testing.expectEqual(Destination.MD, decoded.?.getDestination());
    try testing.expectEqual(Jump.JGT, decoded.?.getJump());
}

test "C-instruction: all destinations" {
    const comp = Computation.fromBits(0, 0b101010);
    const destinations = [_]Destination{ .null, .M, .D, .MD, .A, .AM, .AD, .AMD };

    for (destinations) |dest| {
        const inst = CInstruction.create(comp, dest, .null);
        const binary = inst.encode();
        const decoded = CInstruction.decode(binary);
        try testing.expect(decoded != null);
        try testing.expectEqual(dest, decoded.?.getDestination());
    }
}

test "C-instruction: all jump conditions" {
    const comp = Computation.fromBits(0, 0b101010);
    const jumps = [_]Jump{ .null, .JGT, .JEQ, .JGE, .JLT, .JNE, .JLE, .JMP };

    for (jumps) |jump| {
        const inst = CInstruction.create(comp, .null, jump);
        const binary = inst.encode();
        const decoded = CInstruction.decode(binary);
        try testing.expect(decoded != null);
        try testing.expectEqual(jump, decoded.?.getJump());
    }
}

