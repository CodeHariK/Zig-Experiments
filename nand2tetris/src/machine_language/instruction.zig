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

    /// Encode instruction to 16-bit binary
    pub fn toBinary(self: Self) u16 {
        return switch (self) {
            .a => self.a.value,
            .c => self.c.value,
        };
    }

    /// Convert instruction to assembly string
    /// Uses the provided buffer and symbol table for reverse lookup
    ///
    /// Parameters:
    ///   emit_symbols - If true, emit symbolic names (e.g., "@sum", "@LOOP")
    ///                  If false, emit numeric addresses (e.g., "@16", "@4")
    pub fn toAssembly(self: Self, buffer: []u8, symbol_table: *const SymbolTable, emit_symbols: bool) ![]const u8 {
        return switch (self) {
            .a => self.a.toAssembly(buffer, symbol_table, emit_symbols),
            .c => self.c.toAssembly(buffer),
        };
    }

    /// Decode 16-bit binary to instruction
    /// Automatically determines if it's an A or C instruction
    pub fn decodeBinary(binary: u16) !Self {
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

    /// Decode an assembly string into an Instruction
    /// Automatically determines if it's an A-instruction or C-instruction
    ///
    /// Parameters:
    ///   - assembly: Assembly string (e.g., "@5", "D=A", "M=D+1", "D;JGT")
    ///   - symbol_table: Symbol table for resolving symbols in A-instructions (mutable to allow auto-adding variables)
    ///
    /// Returns:
    ///   - Instruction (either A or C)
    ///
    /// Notes:
    ///   - A-instructions start with '@'
    ///   - C-instructions are everything else
    ///   - Trims whitespace and handles comments
    ///   - Automatically adds variables to symbol table when first encountered
    pub fn decodeAssembly(assembly: []const u8, symbol_table: *SymbolTable) !Self {
        // Trim leading/trailing whitespace
        var trimmed = assembly;
        while (trimmed.len > 0 and (trimmed[0] == ' ' or trimmed[0] == '\t')) {
            trimmed = trimmed[1..];
        }
        var end = trimmed.len;
        while (end > 0 and (trimmed[end - 1] == ' ' or trimmed[end - 1] == '\t' or trimmed[end - 1] == '\n' or trimmed[end - 1] == '\r')) {
            end -= 1;
        }
        trimmed = trimmed[0..end];

        // Skip empty lines
        if (trimmed.len == 0) {
            return ERR.InvalidAssembly;
        }

        // Skip label definitions (lines starting with '(')
        if (trimmed[0] == '(') {
            return ERR.InvalidAssembly; // Labels are not instructions
        }

        // Remove comments (everything after //)
        if (std.mem.indexOf(u8, trimmed, "//")) |comment_start| {
            trimmed = trimmed[0..comment_start];
            // Trim whitespace again after removing comment
            end = trimmed.len;
            while (end > 0 and (trimmed[end - 1] == ' ' or trimmed[end - 1] == '\t')) {
                end -= 1;
            }
            trimmed = trimmed[0..end];
            // Skip if line is now empty
            if (trimmed.len == 0) {
                return ERR.InvalidAssembly;
            }
        }

        // Parse as A-instruction if it starts with '@'
        if (trimmed[0] == '@') {
            const a_inst = try AInstruction.fromAssembly(trimmed, symbol_table);
            return Self{ .a = a_inst };
        } else {
            // Must be a C-instruction
            const c_inst = try CInstruction.fromAssembly(trimmed);
            return Self{ .c = c_inst };
        }
    }
};

// =============================================================================
// Program Structure
// =============================================================================

/// A program is a collection of instructions
pub const Program = struct {
    instructions: std.ArrayList(Instruction),
    symbol_table: SymbolTable,

    const Self = @This();

    /// Initialize an empty program with a symbol table
    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .instructions = std.ArrayList(Instruction).empty,
            .symbol_table = try SymbolTable.init(allocator),
        };
    }

    /// Deinitialize the program and free all memory
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.instructions.deinit(allocator);
        self.symbol_table.deinit();
    }

    /// Create a program from an array of assembly strings
    /// First pass: collect labels
    /// Second pass: assemble instructions
    pub fn fromAssemblyArray(
        self: *Self,
        allocator: std.mem.Allocator,
        assembly_lines: []const []const u8,
    ) !void {
        // Clear existing instructions
        self.instructions.clearRetainingCapacity();

        // First pass: collect labels and their addresses
        var instruction_count: u16 = 0;
        for (assembly_lines) |line| {
            var trimmed = line;
            while (trimmed.len > 0 and (trimmed[0] == ' ' or trimmed[0] == '\t')) {
                trimmed = trimmed[1..];
            }
            var end = trimmed.len;
            while (end > 0 and (trimmed[end - 1] == ' ' or trimmed[end - 1] == '\t' or trimmed[end - 1] == '\n' or trimmed[end - 1] == '\r')) {
                end -= 1;
            }
            trimmed = trimmed[0..end];

            // Remove comments
            if (std.mem.indexOf(u8, trimmed, "//")) |comment_start| {
                trimmed = trimmed[0..comment_start];
                end = trimmed.len;
                while (end > 0 and (trimmed[end - 1] == ' ' or trimmed[end - 1] == '\t')) {
                    end -= 1;
                }
                trimmed = trimmed[0..end];
            }

            // Skip empty lines
            if (trimmed.len == 0) {
                continue;
            }

            // Check if it's a label definition (starts with '(' and ends with ')')
            if (trimmed[0] == '(') {
                if (trimmed.len > 2 and trimmed[trimmed.len - 1] == ')') {
                    const label_name = trimmed[1 .. trimmed.len - 1];
                    // Add label to symbol table with current instruction count as address
                    self.symbol_table.addLabel(label_name, instruction_count) catch |err| {
                        // Ignore if label already exists (might be duplicate)
                        if (err != ERR.SymbolAlreadyExists) {
                            return err;
                        }
                    };
                }
            } else {
                // It's an instruction, increment counter
                instruction_count += 1;
            }
        }

        // Second pass: assemble instructions
        // Pre-allocate capacity with upper bound (assembly_lines.len)
        // Some lines may be skipped (empty, labels, comments), but this avoids
        // reallocations in the common case where most lines are valid instructions
        try self.instructions.ensureTotalCapacity(allocator, assembly_lines.len);

        for (assembly_lines) |line| {
            // Use decodeAssembly to parse the line
            // It handles trimming, comments, empty lines, and label definitions
            // Pass mutable reference so variables can be automatically added
            const inst = Instruction.decodeAssembly(line, &self.symbol_table) catch |err| {
                // Skip invalid assembly (empty lines, labels, etc.)
                if (err == ERR.InvalidAssembly) {
                    continue;
                }
                return err;
            };
            try self.instructions.append(allocator, inst);
        }
    }

    /// Convert the program to an array of assembly strings
    /// Includes label definitions before instructions at label addresses
    ///
    /// Parameters:
    ///   emit_symbols - If true, emit symbolic names for labels and variables (e.g., "@sum", "(LOOP)")
    ///                  If false, emit numeric addresses (e.g., "@16", labels are omitted or shown as addresses)
    pub fn toAssemblyArray(
        self: *const Self,
        allocator: std.mem.Allocator,
        buffer: []u8,
        emit_symbols: bool,
    ) !std.ArrayList([]const u8) {
        var assembly_lines = std.ArrayList([]const u8).empty;

        // Build reverse map: address -> label name
        // Labels are instruction addresses (ROM addresses 0 to instruction_count-1)
        // Variables are RAM addresses (>= 16)
        // Predefined symbols are registers (R0-R15 = 0-15) and I/O addresses
        var label_map = std.AutoHashMap(u16, []const u8).init(allocator);
        defer label_map.deinit();

        const instruction_count = @as(u16, @intCast(self.instructions.items.len));
        // Iterate over label_names to find labels (they're tracked separately)
        var label_name_iterator = self.symbol_table.label_names.iterator();
        while (label_name_iterator.next()) |entry| {
            const name = entry.key_ptr.*;
            // Get the address for this label
            if (self.symbol_table.map.get(name)) |addr| {
                // A label is an instruction address (ROM) that's:
                // 1. Less than the number of instructions (valid instruction address)
                // 2. Not a predefined symbol
                if (addr < instruction_count) {
                    // Check if it's a predefined register (R0-R15 = 0-15)
                    const is_register = (name.len == 2 or name.len == 3) and
                        name[0] == 'R' and
                        (name.len == 2 or (name[1] >= '0' and name[1] <= '9'));
                    // Check if it's a predefined I/O symbol
                    const is_io = std.mem.eql(u8, name, "SCREEN") or std.mem.eql(u8, name, "KBD");
                    // Check if it's a virtual register
                    const is_virtual = std.mem.eql(u8, name, "SP") or
                        std.mem.eql(u8, name, "LCL") or
                        std.mem.eql(u8, name, "ARG") or
                        std.mem.eql(u8, name, "THIS") or
                        std.mem.eql(u8, name, "THAT");

                    if (!is_register and !is_io and !is_virtual) {
                        // It's a label (tracked in label_names, not a predefined symbol)
                        try label_map.put(addr, name);
                    }
                }
            }
        }

        // Pre-allocate capacity (might need extra for labels)
        try assembly_lines.ensureTotalCapacity(allocator, self.instructions.items.len + label_map.count());

        // Output instructions with labels
        for (self.instructions.items, 0..) |inst, addr| {
            // Check if there's a label at this address
            if (label_map.get(@as(u16, @intCast(addr)))) |label_name| {
                if (emit_symbols) {
                    // Output label definition with symbolic name
                    const label_str = try std.fmt.bufPrint(buffer, "({s})", .{label_name});
                    const label_copy = try allocator.dupe(u8, label_str);
                    try assembly_lines.append(allocator, label_copy);
                }
                // If emit_symbols is false, we skip label definitions (they're just metadata)
            }

            // Output instruction
            const asm_str = try inst.toAssembly(buffer, &self.symbol_table, emit_symbols);
            const asm_copy = try allocator.dupe(u8, asm_str);
            try assembly_lines.append(allocator, asm_copy);
        }

        return assembly_lines;
    }

    /// Create a program from an array of binary machine code
    pub fn fromBinaryArray(
        self: *Self,
        allocator: std.mem.Allocator,
        binary_codes: []const u16,
    ) !void {
        // Clear existing instructions
        self.instructions.clearRetainingCapacity();

        // Pre-allocate capacity since we know the exact size
        // This avoids reallocations during append
        try self.instructions.ensureTotalCapacity(allocator, binary_codes.len);

        for (binary_codes) |binary| {
            const inst = try Instruction.decodeBinary(binary);
            try self.instructions.append(allocator, inst);
        }
    }

    /// Convert the program to an array of binary machine code
    pub fn toBinaryArray(
        self: Self,
        allocator: std.mem.Allocator,
    ) !std.ArrayList(u16) {
        var binary_codes = std.ArrayList(u16).empty;

        // Pre-allocate capacity since we know the exact size
        // This avoids reallocations during append
        try binary_codes.ensureTotalCapacity(allocator, self.instructions.items.len);

        for (self.instructions.items) |inst| {
            const binary = inst.toBinary();
            try binary_codes.append(allocator, binary);
        }

        return binary_codes;
    }
};

// =============================================================================
// Array Conversion Functions (Legacy - use Program methods instead)
// =============================================================================

// =============================================================================
// Tests
// =============================================================================

const memory_map = @import("memory_map.zig");
const SymbolTable = memory_map.SymbolTable;

const TestProgram = struct {
    name: []const u8,
    assembly_lines: []const []const u8,
    expected_binary: []const u16,
};

const test_programs = [_]TestProgram{.{
    .name = "multiplication",
    .assembly_lines = &.{
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
    },
    .expected_binary = &.{
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
    },
}};

fn run_test_program(index: usize) !void {
    std.debug.print("\n=== {s} Program Test ===\n\n", .{test_programs[index].name});

    const test_program = test_programs[index];
    const assembly_lines = test_program.assembly_lines;
    const expected_binary = test_program.expected_binary;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse assembly and build instructions using Program
    // Labels and variables are automatically collected/added during assembly
    var program = try Program.init(allocator);
    defer program.deinit(allocator);
    try program.fromAssemblyArray(allocator, assembly_lines);

    // Verify binary output
    std.debug.print("Generated binary:\n", .{});
    var all_match = true;
    for (program.instructions.items, 0..) |inst, i| {
        const binary = inst.toBinary();
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

    std.debug.print("✓ All binary instructions match expected output!\n", .{});

    var buffer: [256]u8 = undefined;
    var asm_lines = try program.toAssemblyArray(allocator, &buffer, true);
    defer {
        // Free individual strings before deinitializing ArrayList
        for (asm_lines.items) |line| {
            allocator.free(line);
        }
        asm_lines.deinit(allocator);
    }

    std.debug.print("Converted back to assembly (with symbols):\n", .{});
    for (asm_lines.items) |line| {
        std.debug.print("{s}\n", .{line});
    }

    // Also print with numeric addresses
    var buffer2: [256]u8 = undefined;
    var asm_lines_numeric = try program.toAssemblyArray(allocator, &buffer2, false);
    defer {
        // Free individual strings before deinitializing ArrayList
        for (asm_lines_numeric.items) |line| {
            allocator.free(line);
        }
        asm_lines_numeric.deinit(allocator);
    }

    std.debug.print("\nConverted back to assembly (numeric addresses):\n", .{});
    for (asm_lines_numeric.items) |line| {
        std.debug.print("{s}\n", .{line});
    }

    // Verify round-trip: convert back to instructions and check binary matches
    var program2 = try Program.init(allocator);
    defer program2.deinit(allocator);
    try program2.fromAssemblyArray(allocator, asm_lines.items);

    var round_trip_match = true;
    for (program.instructions.items, program2.instructions.items, 0..) |inst1, inst2, i| {
        const binary1 = inst1.toBinary();
        const binary2 = inst2.toBinary();
        if (binary1 != binary2) {
            round_trip_match = false;
            std.debug.print("  ✗ Round-trip mismatch at index {d}: {b:0>16} != {b:0>16}\n", .{ i, binary1, binary2 });
        }
    }

    if (!round_trip_match) {
        std.debug.print("\n✗ Round-trip conversion failed!\n", .{});
        return ERR.TestFailed;
    }

    std.debug.print("✓ Round-trip conversion successful!\n", .{});

    // Test binary array conversion: binary -> instructions -> binary
    var binaryInstructions = try program.toBinaryArray(allocator);
    defer binaryInstructions.deinit(allocator);

    // Verify binary array matches expected
    var binary_match = true;
    for (binaryInstructions.items, 0..) |binary, i| {
        if (binary != expected_binary[i]) {
            binary_match = false;
            break;
        }
    }
    if (!binary_match) {
        std.debug.print("\n✗ Binary array conversion failed!\n", .{});
        return ERR.TestFailed;
    }
    std.debug.print("✓ Binary array conversion successful!\n", .{});

    // Test round-trip: binary -> instructions -> binary
    var program3 = try Program.init(allocator);
    defer program3.deinit(allocator);
    try program3.fromBinaryArray(allocator, binaryInstructions.items);

    var binary_round_trip_match = true;
    for (program.instructions.items, program3.instructions.items, 0..) |inst1, inst3, i| {
        const binary1 = inst1.toBinary();
        const binary3 = inst3.toBinary();
        if (binary1 != binary3) {
            binary_round_trip_match = false;
            std.debug.print("  ✗ Binary round-trip mismatch at index {d}: {b:0>16} != {b:0>16}\n", .{ i, binary1, binary3 });
        }
    }

    if (!binary_round_trip_match) {
        std.debug.print("\n✗ Binary round-trip conversion failed!\n", .{});
        return ERR.TestFailed;
    }
    std.debug.print("✓ Binary round-trip conversion successful!\n", .{});

    // Test full round-trip: assembly -> instructions -> binary -> instructions
    // Compare binary code (not assembly) since symbol names are lost in binary conversion
    var binary_array2 = try program.toBinaryArray(allocator);
    defer binary_array2.deinit(allocator);
    var program4 = try Program.init(allocator);
    defer program4.deinit(allocator);
    try program4.fromBinaryArray(allocator, binary_array2.items);

    // Compare binary instructions (the actual program code)
    var full_round_trip_match = true;
    for (program.instructions.items, program4.instructions.items, 0..) |inst1, inst4, i| {
        const binary1 = inst1.toBinary();
        const binary4 = inst4.toBinary();
        if (binary1 != binary4) {
            full_round_trip_match = false;
            std.debug.print("  ✗ Full round-trip mismatch at index {d}: {b:0>16} != {b:0>16}\n", .{ i, binary1, binary4 });
        }
    }

    if (!full_round_trip_match) {
        std.debug.print("\n✗ Full round-trip conversion failed!\n", .{});
        return ERR.TestFailed;
    }
    std.debug.print("✓ Full round-trip conversion successful!\n", .{});
}

test "multiplication program" {
    try run_test_program(0);
}
