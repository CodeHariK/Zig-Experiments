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
const ERR = @import("types").Error;

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

const DestMap = std.StaticStringMap(Destination).initComptime(.{
    .{ "", .null },
    .{ "M", .M },
    .{ "D", .D },
    .{ "MD", .MD },
    .{ "A", .A },
    .{ "AM", .AM },
    .{ "AD", .AD },
    .{ "AMD", .AMD },
});

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

const JumpMap = std.StaticStringMap(Jump).initComptime(.{
    .{ "", .null },
    .{ "JGT", .JGT },
    .{ "JEQ", .JEQ },
    .{ "JGE", .JGE },
    .{ "JLT", .JLT },
    .{ "JNE", .JNE },
    .{ "JLE", .JLE },
    .{ "JMP", .JMP },
});

/// Computation entry structure for lookup tables
const CompEntry = struct {
    a: u1, // ALU input selector: 0=A, 1=M
    comp: u6, // ALU computation bits
};

/// Static string map for computation assembly parsing
/// Maps assembly strings to CompEntry (a, comp) pairs
const comp_assembly_map = std.StaticStringMap(CompEntry).initComptime(.{
    .{ "0", CompEntry{ .a = 0, .comp = 0b101010 } },
    .{ "1", CompEntry{ .a = 0, .comp = 0b111111 } },
    .{ "-1", CompEntry{ .a = 0, .comp = 0b111010 } },
    .{ "D", CompEntry{ .a = 0, .comp = 0b001100 } },
    .{ "A", CompEntry{ .a = 0, .comp = 0b110000 } },
    .{ "M", CompEntry{ .a = 1, .comp = 0b110000 } },
    .{ "!D", CompEntry{ .a = 0, .comp = 0b001101 } },
    .{ "!A", CompEntry{ .a = 0, .comp = 0b110001 } },
    .{ "!M", CompEntry{ .a = 1, .comp = 0b110001 } },
    .{ "-D", CompEntry{ .a = 0, .comp = 0b001111 } },
    .{ "-A", CompEntry{ .a = 0, .comp = 0b110011 } },
    .{ "-M", CompEntry{ .a = 1, .comp = 0b110011 } },
    .{ "D+1", CompEntry{ .a = 0, .comp = 0b011111 } },
    .{ "A+1", CompEntry{ .a = 0, .comp = 0b110111 } },
    .{ "M+1", CompEntry{ .a = 1, .comp = 0b110111 } },
    .{ "D-1", CompEntry{ .a = 0, .comp = 0b001110 } },
    .{ "A-1", CompEntry{ .a = 0, .comp = 0b110010 } },
    .{ "M-1", CompEntry{ .a = 1, .comp = 0b110010 } },
    .{ "D+A", CompEntry{ .a = 0, .comp = 0b000010 } },
    .{ "D+M", CompEntry{ .a = 1, .comp = 0b000010 } },
    .{ "D-A", CompEntry{ .a = 0, .comp = 0b010011 } },
    .{ "D-M", CompEntry{ .a = 1, .comp = 0b010011 } },
    .{ "A-D", CompEntry{ .a = 0, .comp = 0b000111 } },
    .{ "M-D", CompEntry{ .a = 1, .comp = 0b000111 } },
    .{ "D&A", CompEntry{ .a = 0, .comp = 0b000000 } },
    .{ "D&M", CompEntry{ .a = 1, .comp = 0b000000 } },
    .{ "D|A", CompEntry{ .a = 0, .comp = 0b010101 } },
    .{ "D|M", CompEntry{ .a = 1, .comp = 0b010101 } },
});

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

    /// Parse computation from assembly string
    /// Returns error if computation string is invalid
    pub fn fromAssembly(comp_str: []const u8) ERR!Self {
        if (comp_assembly_map.get(comp_str)) |entry| {
            return Self{ .a = entry.a, .comp = entry.comp };
        }
        return ERR.InvalidAssembly;
    }

    /// Convert computation to assembly string
    /// Uses reverse lookup through the static map
    pub fn toAssembly(self: Self, buffer: []u8) ERR![]const u8 {
        // Reverse lookup: iterate through map to find matching (a, comp) pair
        const keys = comp_assembly_map.keys();
        const values = comp_assembly_map.values();

        for (keys, values) |key, entry| {
            if (entry.a == self.a and entry.comp == self.comp) {
                if (key.len > buffer.len) {
                    return ERR.InvalidAssembly;
                }
                @memcpy(buffer[0..key.len], key);
                return buffer[0..key.len];
            }
        }
        return ERR.InvalidAssembly;
    }
};

/// C-instruction structure
pub const CInstruction = struct {
    comp: Computation,
    dest: Destination,
    jump: Jump,
    value: u16,

    const Self = @This();

    /// Create a C-instruction
    /// Format: 111accccccdddjjj
    pub fn create(comp: Computation, dest: Destination, jump: Jump) Self {
        return Self{
            .comp = comp,
            .dest = dest,
            .jump = jump,
            .value = Self.encode(comp, dest, jump),
        };
    }

    /// Encode C-instruction to 16-bit binary
    pub fn encode(comp: Computation, dest: Destination, jump: Jump) u16 {
        const prefix: u16 = 0b111 << 13; // Bits 15-13 = 111
        const a_comp: u16 = @as(u16, comp.getField()) << 6; // Bits 6-12
        const dest_bits: u16 = @as(u16, @intFromEnum(dest)) << 3; // Bits 3-5
        const jump_bits: u16 = @intFromEnum(jump); // Bits 0-2

        return prefix | a_comp | dest_bits | jump_bits;
    }

    /// Decode 16-bit binary to C-instruction
    /// Returns null if not a valid C-instruction (bits 15-13 must be 111)
    pub fn decode(binary: u16) ERR!Self {
        // Check if bits 15-13 are 111
        const prefix = (binary >> 13) & 0b111;
        if (prefix != 0b111) {
            return ERR.NotCInstruction; // Not a C-instruction
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
            .value = binary,
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

    /// Parse C-instruction from assembly syntax
    /// Format: dest=comp;jump (dest and jump are optional)
    /// Examples: "D=M", "M=D+1", "D;JGT", "0;JMP"
    pub fn fromAssembly(assembly: []const u8) ERR!Self {
        var trimmed = assembly;
        // Remove leading/trailing whitespace
        while (trimmed.len > 0 and (trimmed[0] == ' ' or trimmed[0] == '\t')) {
            trimmed = trimmed[1..];
        }
        var end = trimmed.len;
        while (end > 0 and (trimmed[end - 1] == ' ' or trimmed[end - 1] == '\t' or trimmed[end - 1] == '\n' or trimmed[end - 1] == '\r')) {
            end -= 1;
        }
        trimmed = trimmed[0..end];

        // Remove comments (everything after //)
        if (std.mem.indexOf(u8, trimmed, "//")) |comment_start| {
            trimmed = trimmed[0..comment_start];
            // Trim whitespace again after removing comment
            end = trimmed.len;
            while (end > 0 and (trimmed[end - 1] == ' ' or trimmed[end - 1] == '\t')) {
                end -= 1;
            }
            trimmed = trimmed[0..end];
        }

        if (trimmed.len == 0) {
            return ERR.InvalidAssembly;
        }

        // Parse format: [dest=]comp[;jump]
        var dest: Destination = .null;
        var comp_str: []const u8 = undefined;
        var jump: Jump = .null;

        // Check for destination (has '=')
        if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
            const dest_str = trimmed[0..eq_pos];
            // If '=' is present, destination must not be empty
            if (dest_str.len == 0) {
                return ERR.InvalidAssembly;
            }
            dest = parseDestination(dest_str) catch return ERR.InvalidAssembly;
            comp_str = trimmed[eq_pos + 1 ..];
        } else {
            comp_str = trimmed;
        }

        // Check for jump (has ';')
        if (std.mem.indexOf(u8, comp_str, ";")) |semi_pos| {
            const jump_str = comp_str[semi_pos + 1 ..];
            // If ';' is present, computation must not be empty
            if (semi_pos == 0) {
                return ERR.InvalidAssembly;
            }
            jump = parseJump(jump_str) catch return ERR.InvalidAssembly;
            comp_str = comp_str[0..semi_pos];
        }

        // Computation is required and must not be empty
        if (comp_str.len == 0) {
            return ERR.InvalidAssembly;
        }

        // Parse computation
        const comp = Computation.fromAssembly(comp_str) catch return ERR.InvalidAssembly;

        return Self{
            .comp = comp,
            .dest = dest,
            .jump = jump,
            .value = Self.encode(comp, dest, jump),
        };
    }

    /// Convert C-instruction to assembly syntax
    /// Format: dest=comp;jump (omits dest and jump if null)
    pub fn toAssembly(self: Self, buffer: []u8) ERR![]const u8 {
        var pos: usize = 0;

        // Add destination if not null
        if (self.dest != .null) {
            const dest_str = destinationToString(self.dest);
            if (pos + dest_str.len + 1 > buffer.len) return ERR.InvalidAssembly;
            @memcpy(buffer[pos..][0..dest_str.len], dest_str);
            pos += dest_str.len;
            buffer[pos] = '=';
            pos += 1;
        }

        // Add computation
        const comp_str = try self.comp.toAssembly(buffer[pos..]);
        pos += comp_str.len;

        // Add jump if not null
        if (self.jump != .null) {
            if (pos + 1 > buffer.len) return ERR.InvalidAssembly;
            buffer[pos] = ';';
            pos += 1;
            const jump_str = jumpToString(self.jump);
            if (pos + jump_str.len > buffer.len) return ERR.InvalidAssembly;
            @memcpy(buffer[pos..][0..jump_str.len], jump_str);
            pos += jump_str.len;
        }

        return buffer[0..pos];
    }
};

// Helper functions for parsing and formatting

fn parseDestination(dest_str: []const u8) ERR!Destination {
    return DestMap.get(dest_str) orelse ERR.InvalidAssembly;
}

fn destinationToString(dest: Destination) []const u8 {
    return if (dest == .null) "" else @tagName(dest);
}

fn parseJump(jump_str: []const u8) ERR!Jump {
    return JumpMap.get(jump_str) orelse ERR.InvalidAssembly;
}

fn jumpToString(jump: Jump) []const u8 {
    return if (jump == .null) "" else @tagName(jump);
}

// =============================================================================
// Tests
// =============================================================================

const TestCase = struct {
    c_asm: []const u8,
    a: u1,
    comp: u6,
    dest: Destination,
    jump: Jump,
    exp_bin: ?u16, // null if should error
};

test "C-instruction: comprehensive tests" {
    std.debug.print("\n=== C-Instruction Comprehensive Tests ===\n\n", .{});

    const test_cases = [_]TestCase{
        // Basic computations with different destinations
        .{ .c_asm = "D=M", .a = 1, .comp = 0b110000, .dest = .D, .jump = .null, .exp_bin = 0b1111110000010000 },
        .{ .c_asm = "M=D", .a = 0, .comp = 0b001100, .dest = .M, .jump = .null, .exp_bin = 0b1110001100001000 },
        .{ .c_asm = "A=0", .a = 0, .comp = 0b101010, .dest = .A, .jump = .null, .exp_bin = 0b1110101010100000 },
        .{ .c_asm = "D=1", .a = 0, .comp = 0b111111, .dest = .D, .jump = .null, .exp_bin = 0b1110111111010000 },
        .{ .c_asm = "M=-1", .a = 0, .comp = 0b111010, .dest = .M, .jump = .null, .exp_bin = 0b1110111010001000 },

        // Computations with jumps
        .{ .c_asm = "D;JGT", .a = 0, .comp = 0b001100, .dest = .null, .jump = .JGT, .exp_bin = 0b1110001100000001 },
        .{ .c_asm = "D;JEQ", .a = 0, .comp = 0b001100, .dest = .null, .jump = .JEQ, .exp_bin = 0b1110001100000010 },
        .{ .c_asm = "0;JMP", .a = 0, .comp = 0b101010, .dest = .null, .jump = .JMP, .exp_bin = 0b1110101010000111 },
        .{ .c_asm = "D;JLE", .a = 0, .comp = 0b001100, .dest = .null, .jump = .JLE, .exp_bin = 0b1110001100000110 },

        // Combined dest and jump
        .{ .c_asm = "MD=D+1;JGT", .a = 0, .comp = 0b011111, .dest = .MD, .jump = .JGT, .exp_bin = 0b1110011111011001 },
        .{ .c_asm = "AMD=M-1;JMP", .a = 1, .comp = 0b110010, .dest = .AMD, .jump = .JMP, .exp_bin = 0b1111110010111111 },

        // All destinations
        .{ .c_asm = "M=0", .a = 0, .comp = 0b101010, .dest = .M, .jump = .null, .exp_bin = 0b1110101010001000 },
        .{ .c_asm = "D=0", .a = 0, .comp = 0b101010, .dest = .D, .jump = .null, .exp_bin = 0b1110101010010000 },
        .{ .c_asm = "MD=0", .a = 0, .comp = 0b101010, .dest = .MD, .jump = .null, .exp_bin = 0b1110101010011000 },
        .{ .c_asm = "A=0", .a = 0, .comp = 0b101010, .dest = .A, .jump = .null, .exp_bin = 0b1110101010100000 },
        .{ .c_asm = "AM=0", .a = 0, .comp = 0b101010, .dest = .AM, .jump = .null, .exp_bin = 0b1110101010101000 },
        .{ .c_asm = "AD=0", .a = 0, .comp = 0b101010, .dest = .AD, .jump = .null, .exp_bin = 0b1110101010110000 },
        .{ .c_asm = "AMD=0", .a = 0, .comp = 0b101010, .dest = .AMD, .jump = .null, .exp_bin = 0b1110101010111000 },

        // All jump conditions
        .{ .c_asm = "D;JGT", .a = 0, .comp = 0b001100, .dest = .null, .jump = .JGT, .exp_bin = 0b1110001100000001 },
        .{ .c_asm = "D;JEQ", .a = 0, .comp = 0b001100, .dest = .null, .jump = .JEQ, .exp_bin = 0b1110001100000010 },
        .{ .c_asm = "D;JGE", .a = 0, .comp = 0b001100, .dest = .null, .jump = .JGE, .exp_bin = 0b1110001100000011 },
        .{ .c_asm = "D;JLT", .a = 0, .comp = 0b001100, .dest = .null, .jump = .JLT, .exp_bin = 0b1110001100000100 },
        .{ .c_asm = "D;JNE", .a = 0, .comp = 0b001100, .dest = .null, .jump = .JNE, .exp_bin = 0b1110001100000101 },
        .{ .c_asm = "D;JLE", .a = 0, .comp = 0b001100, .dest = .null, .jump = .JLE, .exp_bin = 0b1110001100000110 },
        .{ .c_asm = "D;JMP", .a = 0, .comp = 0b001100, .dest = .null, .jump = .JMP, .exp_bin = 0b1110001100000111 },

        // Various computations
        .{ .c_asm = "D=A", .a = 0, .comp = 0b110000, .dest = .D, .jump = .null, .exp_bin = 0b1110110000010000 },
        .{ .c_asm = "D=M", .a = 1, .comp = 0b110000, .dest = .D, .jump = .null, .exp_bin = 0b1111110000010000 },
        .{ .c_asm = "D=D+1", .a = 0, .comp = 0b011111, .dest = .D, .jump = .null, .exp_bin = 0b1110011111010000 },
        .{ .c_asm = "D=D-1", .a = 0, .comp = 0b001110, .dest = .D, .jump = .null, .exp_bin = 0b1110001110010000 },
        .{ .c_asm = "D=D+A", .a = 0, .comp = 0b000010, .dest = .D, .jump = .null, .exp_bin = 0b1110000010010000 },
        .{ .c_asm = "D=D+M", .a = 1, .comp = 0b000010, .dest = .D, .jump = .null, .exp_bin = 0b1111000010010000 },
        .{ .c_asm = "D=D-A", .a = 0, .comp = 0b010011, .dest = .D, .jump = .null, .exp_bin = 0b1110010011010000 },
        .{ .c_asm = "D=D-A", .a = 0, .comp = 0b010011, .dest = .D, .jump = .null, .exp_bin = 0b1110010011010000 },
        .{ .c_asm = "D=D&M", .a = 1, .comp = 0b000000, .dest = .D, .jump = .null, .exp_bin = 0b1111000000010000 },
        .{ .c_asm = "D=D|A", .a = 0, .comp = 0b010101, .dest = .D, .jump = .null, .exp_bin = 0b1110010101010000 },

        // Whitespace handling
        .{ .c_asm = "  D=M", .a = 1, .comp = 0b110000, .dest = .D, .jump = .null, .exp_bin = 0b1111110000010000 },
        .{ .c_asm = "D=M  ", .a = 1, .comp = 0b110000, .dest = .D, .jump = .null, .exp_bin = 0b1111110000010000 },
        .{ .c_asm = "  D=M  ", .a = 1, .comp = 0b110000, .dest = .D, .jump = .null, .exp_bin = 0b1111110000010000 },
        .{ .c_asm = "\tD=M\t", .a = 1, .comp = 0b110000, .dest = .D, .jump = .null, .exp_bin = 0b1111110000010000 },
        .{ .c_asm = "D=M\n", .a = 1, .comp = 0b110000, .dest = .D, .jump = .null, .exp_bin = 0b1111110000010000 },
        .{ .c_asm = "  D;JGT  ", .a = 0, .comp = 0b001100, .dest = .null, .jump = .JGT, .exp_bin = 0b1110001100000001 },

        // Comments
        .{ .c_asm = "D=M // comment", .a = 1, .comp = 0b110000, .dest = .D, .jump = .null, .exp_bin = 0b1111110000010000 },
        .{ .c_asm = "D=M//comment", .a = 1, .comp = 0b110000, .dest = .D, .jump = .null, .exp_bin = 0b1111110000010000 },
        .{ .c_asm = "  D=M  // comment with spaces", .a = 1, .comp = 0b110000, .dest = .D, .jump = .null, .exp_bin = 0b1111110000010000 },
        .{ .c_asm = "D;JGT // jump if greater", .a = 0, .comp = 0b001100, .dest = .null, .jump = .JGT, .exp_bin = 0b1110001100000001 },
        .{ .c_asm = "MD=D+1;JGT // combined instruction", .a = 0, .comp = 0b011111, .dest = .MD, .jump = .JGT, .exp_bin = 0b1110011111011001 },
        .{ .c_asm = "D=M // load from memory", .a = 1, .comp = 0b110000, .dest = .D, .jump = .null, .exp_bin = 0b1111110000010000 },
    };

    var passed: u32 = 0;
    var failed: u32 = 0;

    for (test_cases, 0..) |tc, i| {
        std.debug.print("[{d}/{d}] {s}\n", .{ i + 1, test_cases.len, tc.c_asm });
        std.debug.print("  Comp: a={d}, comp=0b{b:0>6}, Dest={s}, Jump={s}\n", .{
            tc.a,
            tc.comp,
            @tagName(tc.dest),
            @tagName(tc.jump),
        });

        const comp = Computation.fromBits(tc.a, tc.comp);
        const inst = CInstruction.create(comp, tc.dest, tc.jump);
        const inst_enc = inst.value;

        if (tc.exp_bin) |expected| {
            if (inst_enc != expected) {
                std.debug.print("  ✗ FAILED: encode() = 0b{b:0>16} , expected 0b{b:0>16} \n", .{ inst_enc, expected });
                failed += 1;
                continue;
            }
            std.debug.print("  ✓ encode() = 0b{b:0>16}\n", .{inst_enc});
        }

        // Test decode
        const cinc = CInstruction.decode(inst_enc) catch |err| {
            std.debug.print("  ✗ FAILED: decode() returned error: {}\n", .{err});
            failed += 1;
            continue;
        };

        // Verify fields match
        if (cinc.comp.a != tc.a or cinc.comp.comp != tc.comp or cinc.dest != tc.dest or cinc.jump != tc.jump) {
            std.debug.print("  ✗ FAILED: CInstruction mismatch\n", .{});
            failed += 1;
            continue;
        }

        // Test round-trip
        const round_trip_binary = cinc.value;
        if (round_trip_binary != inst_enc) {
            std.debug.print("  ✗ FAILED: Round-trip binary mismatch\n", .{});
            failed += 1;
            continue;
        }

        // Test assembly encoding (toAssembly)
        var asm_buffer: [256]u8 = undefined;
        const asm_result = inst.toAssembly(&asm_buffer) catch |err| {
            std.debug.print("  ✗ FAILED: toAssembly() returned error: {}\n", .{err});
            failed += 1;
            continue;
        };

        // Verify toAssembly() result parses to the same instruction
        const asm_parsed = CInstruction.fromAssembly(asm_result) catch |err| {
            std.debug.print("  ✗ FAILED: toAssembly() result \"{s}\" failed to parse: {}\n", .{ asm_result, err });
            failed += 1;
            continue;
        };
        if (asm_parsed.comp.a != tc.a or asm_parsed.comp.comp != tc.comp or
            asm_parsed.dest != tc.dest or asm_parsed.jump != tc.jump)
        {
            std.debug.print("  ✗ FAILED: toAssembly() result \"{s}\" doesn't match expected fields\n", .{asm_result});
            failed += 1;
            continue;
        }
        std.debug.print("  ✓ toAssembly() = \"{s}\"\n", .{asm_result});

        // Test assembly decoding (fromAssembly)
        const parsed_inst = CInstruction.fromAssembly(tc.c_asm) catch |err| {
            std.debug.print("  ✗ FAILED: fromAssembly(\"{s}\") returned error: {}\n", .{ tc.c_asm, err });
            failed += 1;
            continue;
        };

        // Verify parsed instruction matches
        if (parsed_inst.comp.a != tc.a or parsed_inst.comp.comp != tc.comp or
            parsed_inst.dest != tc.dest or parsed_inst.jump != tc.jump)
        {
            std.debug.print("  ✗ FAILED: fromAssembly(\"{s}\") field mismatch\n", .{tc.c_asm});
            failed += 1;
            continue;
        }

        // Test round-trip: assembly -> instruction -> assembly
        var round_trip_buffer: [256]u8 = undefined;
        const round_trip_asm = parsed_inst.toAssembly(&round_trip_buffer) catch |err| {
            std.debug.print("  ✗ FAILED: Round-trip toAssembly() error: {}\n", .{err});
            failed += 1;
            continue;
        };

        // Verify round-trip assembly parses to the same instruction (not exact string match)
        const round_trip_parsed = CInstruction.fromAssembly(round_trip_asm) catch |err| {
            std.debug.print("  ✗ FAILED: Round-trip assembly \"{s}\" failed to parse: {}\n", .{ round_trip_asm, err });
            failed += 1;
            continue;
        };
        if (round_trip_parsed.comp.a != tc.a or round_trip_parsed.comp.comp != tc.comp or
            round_trip_parsed.dest != tc.dest or round_trip_parsed.jump != tc.jump)
        {
            std.debug.print("  ✗ FAILED: Round-trip assembly \"{s}\" doesn't match expected fields\n", .{round_trip_asm});
            failed += 1;
            continue;
        }

        passed += 1;
    }

    std.debug.print("\n=== Test Summary ===\n", .{});
    std.debug.print("Total: {d}\n", .{test_cases.len});
    std.debug.print("Passed: {d}\n", .{passed});
    std.debug.print("Failed: {d}\n", .{failed});

    if (failed > 0) {
        std.debug.print("\n✗ Some tests failed!\n", .{});
        return ERR.TestFailed;
    }

    std.debug.print("✓ All tests passed!\n\n", .{});
}

const InvalidAssemblyTestCase = struct {
    name: []const u8,
    assembly: []const u8,
};

test "C-instruction: invalid assembly rejection" {
    std.debug.print("\n=== C-Instruction Invalid Assembly Tests ===\n\n", .{});

    const test_cases = [_]InvalidAssemblyTestCase{
        .{ .name = "reject empty string", .assembly = "" },
        .{ .name = "reject invalid computation", .assembly = "D=X" },
        .{ .name = "reject invalid destination", .assembly = "X=D" },
        .{ .name = "reject invalid jump", .assembly = "D;XXX" },
        .{ .name = "reject malformed dest=comp", .assembly = "=D" },
        .{ .name = "reject malformed comp;jump", .assembly = ";JMP" },
        .{ .name = "reject invalid computation in dest=comp", .assembly = "D=INVALID" },
        .{ .name = "reject invalid computation in comp;jump", .assembly = "INVALID;JMP" },
    };

    var passed: u32 = 0;
    var failed: u32 = 0;

    for (test_cases, 0..) |tc, i| {
        std.debug.print("[{d}/{d}] {s}\n", .{ i + 1, test_cases.len, tc.name });
        std.debug.print("  Assembly: \"{s}\"\n", .{tc.assembly});

        const inst = CInstruction.fromAssembly(tc.assembly) catch |err| {
            std.debug.print("  ✓ Correctly rejected with error: {}\n", .{err});
            passed += 1;
            continue;
        };

        std.debug.print("  ✗ FAILED: Expected error but got success: ", .{});
        var buffer: [256]u8 = undefined;
        if (inst.toAssembly(&buffer)) |asm_result| {
            std.debug.print("\"{s}\"\n", .{asm_result});
        } else |_| {
            std.debug.print("(could not convert to assembly)\n", .{});
        }
        failed += 1;
    }

    std.debug.print("\n=== Invalid Assembly Test Summary ===\n", .{});
    std.debug.print("Total: {d}\n", .{test_cases.len});
    std.debug.print("Passed: {d}\n", .{passed});
    std.debug.print("Failed: {d}\n", .{failed});

    if (failed > 0) {
        std.debug.print("\n✗ Some tests failed!\n", .{});
        return ERR.TestFailed;
    }

    std.debug.print("✓ All invalid assembly tests passed!\n\n", .{});
}
