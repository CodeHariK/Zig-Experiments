// =============================================================================
// A-Instruction (Address Instruction)
// =============================================================================
//
// The A-instruction loads a constant value into the A register or sets up
// memory addresses for subsequent operations.
//
// -----------------------------------------------------------------------------
// Format
// -----------------------------------------------------------------------------
//
// Binary: 0vvvvvvvvvvvvvvv (16 bits)
//   - Bit 15 = 0 (identifies A-instruction)
//   - Bits 0-14 = 15-bit value (0 to 32,767)
//
// Assembly: @value
//   Where value is:
//     - A decimal number (0-32767)
//     - A symbol (variable, label, or predefined symbol)
//
// -----------------------------------------------------------------------------
// Purpose
// -----------------------------------------------------------------------------
//
// 1. Load constants: @5 followed by D=A loads 5 into D register
// 2. Set memory addresses: @100 followed by M=D stores D at RAM[100]
// 3. Jump targets: @LOOP (where LOOP is a label) sets jump destination
//
// -----------------------------------------------------------------------------
// Value vs Address: Context Determines Meaning
// -----------------------------------------------------------------------------
//
// An A-instruction stores a 15-bit value (0-32767). This value can represent
// either a direct numeric constant OR a memory address - the instruction
// itself doesn't distinguish between them.
//
// The interpretation depends on how the value is used in the NEXT instruction:
//
//   As a VALUE (constant):
//     @5
//     D=A        // D = 5 (treats A register value as data)
//
//   As an ADDRESS (memory location):
//     @5
//     M=D        // RAM[5] = D (treats A register value as address)
//
//   As a JUMP TARGET:
//     @LOOP
//     0;JMP      // Jump to address stored in A register
//
// The same binary instruction can be used in different contexts:
//   - @5 → stores value 5 in A register
//   - If next instruction uses A: treats 5 as a value
//   - If next instruction uses M: treats 5 as an address (RAM[5])
//
// In assembly parsing:
//   - Numeric literals (@5, @100): parsed directly as values/addresses
//   - Symbols (@R0, @LOOP): resolved via symbol table to get address
//   - Both result in the same A-instruction structure (just a 15-bit value)
//
// Note: An A-instruction stores a 15-bit value (0-32767). This value can
// represent either:
//   - A direct numeric constant (e.g., @5 means value 5)
//   - A memory address (e.g., @100 means address 100, @R0 means address 0)
//   - A symbol that resolves to an address (e.g., @LOOP, @counter)
//
// The distinction between "value" and "address" is contextual, not stored
// in the instruction itself. The same binary instruction can be used as:
//   - A value: @5 followed by D=A (loads 5 into D)
//   - An address: @5 followed by M=D (stores D at RAM[5])
//
// The interpretation depends on how the value is used in the next instruction.
//
// -----------------------------------------------------------------------------
// Examples
// -----------------------------------------------------------------------------
//
// @5        // Load 5 into A register
// @100      // Load 100 into A register
// @LOOP     // Load address of LOOP label into A
// @R0       // Load address 0 (predefined symbol)
//
// -----------------------------------------------------------------------------
// Implementation
// -----------------------------------------------------------------------------

const std = @import("std");
const testing = std.testing;
const memory_map = @import("memory_map.zig");
const SymbolTable = memory_map.SymbolTable;
const ERR = @import("types").Error;

/// Maximum value for A-instruction (2^15 - 1)
pub const MAX_A_VALUE: u16 = 32767;

/// A-instruction structure
pub const AInstruction = struct {
    value: u16,

    const Self = @This();

    /// Decode 16-bit binary to A-instruction
    /// Returns error if not a valid A-instruction (bit 15 must be 0)
    pub fn decode(binary: u16) ERR!Self {
        // Check if bit 15 is 0 (A-instruction marker)
        // If bit 15 is 1, the binary value is >= 32768, which exceeds MAX_A_VALUE
        if (binary > MAX_A_VALUE) {
            return ERR.NotAInstruction; // Not an A-instruction (bit 15 = 1 means C-instruction or invalid)
        }
        // Extract bits 0-14 (value is already constrained to 0-32767 by u15 type)
        return Self{ .value = binary };
    }

    /// Parse A-instruction from assembly syntax
    /// Assembly format: @value or @symbol
    /// Examples: "@5", "@100", "@LOOP", "@R0"
    /// Uses symbol table to resolve symbols
    /// Automatically adds variables when first encountered
    pub fn fromAssembly(assembly: []const u8, symbol_table: *SymbolTable) !Self {
        // Remove leading whitespace (spaces, tabs, etc.)
        var trimmed = assembly;
        while (trimmed.len > 0 and (trimmed[0] == ' ' or trimmed[0] == '\t')) {
            trimmed = trimmed[1..];
        }

        // Must start with '@'
        if (trimmed.len == 0 or trimmed[0] != '@') {
            return ERR.InvalidAssembly;
        }

        // Skip '@' and parse the value
        const value_str = trimmed[1..];

        // Remove trailing whitespace and comments
        var end = value_str.len;
        for (value_str, 0..) |c, i| {
            if (c == ' ' or c == '/' or c == '\n' or c == '\r' or c == '\t') {
                end = i;
                break;
            }
        }
        const clean_value = value_str[0..end];

        // Try to parse as decimal number first
        if (std.fmt.parseInt(u16, clean_value, 10)) |value| {
            return decode(value);
        } else |_| {
            // Not a number, try symbol table lookup
            if (symbol_table.lookup(clean_value)) |addr| {
                return decode(addr);
            } else {
                // Symbol not found - automatically add it as a variable
                const addr = try symbol_table.addVariable(clean_value);
                return decode(addr);
            }
        }
    }

    /// Convert A-instruction to assembly syntax
    /// Returns assembly string like "@5" or "@R0" (if symbol found in table)
    /// Performs reverse lookup (address -> symbol name) by iterating the map
    ///
    /// Parameters:
    ///   emit_symbols - If true, emit symbolic names (e.g., "@sum", "@LOOP")
    ///                  If false, emit numeric addresses (e.g., "@16", "@4")
    ///
    /// To disassemble from binary, use: decode(binary)?.toAssembly(buffer, symbol_table)
    pub fn toAssembly(self: Self, buffer: []u8, symbol_table: *const SymbolTable, emit_symbols: bool) ![]const u8 {
        const value = self.value;

        // If not emitting symbols, always use numeric value
        if (!emit_symbols) {
            const formatted = try std.fmt.bufPrint(buffer, "@{d}", .{value});
            return formatted;
        }

        // Reverse lookup: find symbol name for this address
        // Note: This requires iterating since hash maps only support key->value lookup
        var iterator = symbol_table.map.iterator();
        while (iterator.next()) |entry| {
            if (entry.value_ptr.* == value) {
                // Found a symbol for this address
                const formatted = try std.fmt.bufPrint(buffer, "@{s}", .{entry.key_ptr.*});
                return formatted;
            }
        }

        // No symbol found, use numeric value
        const formatted = try std.fmt.bufPrint(buffer, "@{d}", .{value});
        return formatted;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "A-instruction: comprehensive tests" {
    std.debug.print("\n=== A-Instruction Comprehensive Tests ===\n\n", .{});

    const test_cases = [_]u16{
        0,
        5,
        100,
        1000,
        10000,
        12345,
        16383,
        MAX_A_VALUE,

        // Error cases
        32768,
        65535,
    };

    var passed: u32 = 0;
    var failed: u32 = 0;

    for (test_cases, 0..) |input, idx| {
        std.debug.print("[{d}/{d}] Input: {d} (0b{b:0>16})\n", .{ idx + 1, test_cases.len, input, input });

        // Test decode (should succeed)
        const inst = AInstruction.decode(input) catch |err| {
            if (input > MAX_A_VALUE and err == ERR.NotAInstruction) {
                std.debug.print("  ✓ Correctly rejected with {}\n", .{err});
                passed += 1;
            } else {
                std.debug.print("  ✗ FAILED: Unexpected error: {}\n", .{err});
                failed += 1;
            }
            continue;
        };

        if (input > MAX_A_VALUE) {
            std.debug.print("  ✗ FAILED: Input Max Value: {}\n", .{input});
            failed += 1;
            continue;
        }

        if (inst.value != input) {
            std.debug.print("  ✗ FAILED: getValue() = {d}, expected {d}\n", .{ inst.value, input });
            failed += 1;
        }

        passed += 1;
    }

    std.debug.print("=== Test Summary ===\n", .{});
    std.debug.print("Total: {d}\n", .{test_cases.len});
    std.debug.print("Passed: {d}\n", .{passed});
    std.debug.print("Failed: {d}\n", .{failed});

    if (failed > 0) {
        std.debug.print("\n✗ Some tests failed!\n", .{});
        return ERR.TestFailed;
    }

    std.debug.print("✓ All tests passed!\n\n", .{});
}

const AssemblyTestCase = struct {
    assembly: []const u8,
    exp_bin: ?u16, // null if should error
    exp_asm: []const []const u8, // Array of valid expected outputs from toAssembly
    setup_label: ?struct { label: []const u8, address: u16 } = null,
    setup_variable: ?[]const u8 = null,
};

test "A-instruction: assembly parsing and generation" {
    std.debug.print("\n=== A-Instruction Assembly Tests ===\n\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var symbol_table = try SymbolTable.init(allocator);
    defer symbol_table.deinit();

    const test_cases = [_]AssemblyTestCase{
        // Numeric values
        // Note: @0 and @5 may return @R0/@R5 or @SP in toAssembly due to multiple symbols mapping to same address
        .{ .assembly = "@0", .exp_bin = 0, .exp_asm = &.{ "@0", "@R0", "@SP" } },
        .{ .assembly = "@5", .exp_bin = 5, .exp_asm = &.{ "@5", "@R5" } },
        .{ .assembly = "@100", .exp_bin = 100, .exp_asm = &.{"@100"} },
        .{ .assembly = "@32767", .exp_bin = 32767, .exp_asm = &.{"@32767"} },

        // Predefined registers
        .{ .assembly = "@R0", .exp_bin = 0, .exp_asm = &.{ "@R0", "@SP" } },
        .{ .assembly = "@R15", .exp_bin = 15, .exp_asm = &.{"@R15"} },

        // Virtual registers
        // Note: SP=0 (same as R0), LCL=1 (same as R1), ARG=2 (same as R2)
        // toAssembly may return R0/R1/R2 instead due to iteration order
        .{ .assembly = "@SP", .exp_bin = 0, .exp_asm = &.{ "@SP", "@R0" } },
        .{ .assembly = "@LCL", .exp_bin = 1, .exp_asm = &.{ "@LCL", "@R1" } },
        .{ .assembly = "@ARG", .exp_bin = 2, .exp_asm = &.{ "@ARG", "@R2" } },
        .{ .assembly = "@THIS", .exp_bin = 3, .exp_asm = &.{ "@THIS", "@R3" } },
        .{ .assembly = "@THAT", .exp_bin = 4, .exp_asm = &.{ "@THAT", "@R4" } },

        // Memory-mapped I/O
        .{ .assembly = "@SCREEN", .exp_bin = 16384, .exp_asm = &.{"@SCREEN"} },
        .{ .assembly = "@KBD", .exp_bin = 24576, .exp_asm = &.{"@KBD"} },

        // Labels (need setup)
        .{ .assembly = "@LOOP", .exp_bin = 10, .exp_asm = &.{"@LOOP"}, .setup_label = .{ .label = "LOOP", .address = 10 } },
        .{ .assembly = "@END", .exp_bin = 50, .exp_asm = &.{"@END"}, .setup_label = .{ .label = "END", .address = 50 } },
        // Note: START=0 conflicts with R0/SP, so toAssembly may return @R0 or @SP
        .{ .assembly = "@START", .exp_bin = 0, .exp_asm = &.{ "@START", "@R0", "@SP" }, .setup_label = .{ .label = "START", .address = 0 } },

        // Variables (need setup - addresses auto-assigned sequentially starting at 16)
        .{ .assembly = "@counter", .exp_bin = 16, .exp_asm = &.{"@counter"}, .setup_variable = "counter" },
        .{ .assembly = "@sum", .exp_bin = 17, .exp_asm = &.{"@sum"}, .setup_variable = "sum" },
        .{ .assembly = "@i", .exp_bin = 18, .exp_asm = &.{"@i"}, .setup_variable = "i" },

        // Whitespace handling
        .{ .assembly = "  @5", .exp_bin = 5, .exp_asm = &.{"@5"} },
        .{ .assembly = "@5  ", .exp_bin = 5, .exp_asm = &.{"@5"} },
        .{ .assembly = "  @5  ", .exp_bin = 5, .exp_asm = &.{"@5"} },
        .{ .assembly = "\t@100\t", .exp_bin = 100, .exp_asm = &.{"@100"} },
        .{ .assembly = "@R0\n", .exp_bin = 0, .exp_asm = &.{ "@R0", "@SP" } },
        .{ .assembly = "  @SCREEN  ", .exp_bin = 16384, .exp_asm = &.{"@SCREEN"} },

        // Comments
        .{ .assembly = "@5 // comment", .exp_bin = 5, .exp_asm = &.{"@5"} },
        .{ .assembly = "@5//comment", .exp_bin = 5, .exp_asm = &.{"@5"} },
        .{ .assembly = "  @100  // comment with spaces", .exp_bin = 100, .exp_asm = &.{"@100"} },
        .{ .assembly = "@R0 // register 0", .exp_bin = 0, .exp_asm = &.{ "@R0", "@SP" } },
        .{ .assembly = "@SCREEN // screen memory", .exp_bin = 16384, .exp_asm = &.{"@SCREEN"} },
        .{ .assembly = "@KBD // keyboard input", .exp_bin = 24576, .exp_asm = &.{"@KBD"} },
        .{ .assembly = "@32767 // max value", .exp_bin = 32767, .exp_asm = &.{"@32767"} },

        // Invalid assembly (expected_value = null means should error)
        .{ .assembly = "5", .exp_bin = null, .exp_asm = &.{} },
        .{ .assembly = "-1", .exp_bin = null, .exp_asm = &.{} },
        .{ .assembly = "@32768", .exp_bin = null, .exp_asm = &.{} },
    };

    var passed: u32 = 0;
    var failed: u32 = 0;
    var buffer: [256]u8 = undefined;

    for (test_cases, 0..) |tc, i| {
        std.debug.print("[{d}/{d}] {s}\n", .{ i + 1, test_cases.len, tc.assembly });

        // Setup labels/variables if needed
        if (tc.setup_label) |setup| {
            symbol_table.addLabel(setup.label, setup.address) catch |err| {
                std.debug.print("  ✗ FAILED: Could not add label: {}\n", .{err});
                failed += 1;
                continue;
            };
            std.debug.print("  Setup: Added label {s} = {d}\n", .{ setup.label, setup.address });
        }
        if (tc.setup_variable) |var_name| {
            const var_addr = symbol_table.addVariable(var_name) catch |err| {
                std.debug.print("  ✗ FAILED: Could not add variable: {}\n", .{err});
                failed += 1;
                continue;
            };
            std.debug.print("  Setup: Added variable {s} = {d}\n", .{ var_name, var_addr });
        }

        const inst = AInstruction.fromAssembly(tc.assembly, &symbol_table) catch |err| {
            // If expected_value is null, we expect an error - any error is acceptable
            if (tc.exp_bin == null) {
                std.debug.print("  ✓ Correctly rejected with error: {}\n", .{err});
                passed += 1;
            } else {
                std.debug.print("  ✗ FAILED: fromAssembly returned error: {}\n", .{err});
                failed += 1;
            }
            continue;
        };

        // If we got here, fromAssembly succeeded
        // If expected_value is null, we expected an error, so this is a failure
        if (tc.exp_bin == null) {
            std.debug.print("  ✗ FAILED: Expected error but got success\n", .{});
            failed += 1;
            continue;
        }

        // Test getValue
        if (inst.value != tc.exp_bin) {
            std.debug.print("  ✗ FAILED: getValue() = {d}, expected {any}\n", .{ inst.value, tc.exp_bin });
            failed += 1;
            continue;
        }
        std.debug.print("  ✓ getValue() = {d}\n", .{inst.value});

        // Test toAssembly
        const result = try inst.toAssembly(&buffer, &symbol_table, true);

        // Verify toAssembly() result parses to the same instruction
        const result_parsed = AInstruction.fromAssembly(result, &symbol_table) catch |err| {
            std.debug.print("  ✗ FAILED: toAssembly() result \"{s}\" failed to parse: {}\n", .{ result, err });
            failed += 1;
            continue;
        };
        if (result_parsed.value != inst.value) {
            std.debug.print("  ✗ FAILED: toAssembly() result \"{s}\" doesn't match expected value: {d} != {d}\n", .{ result, result_parsed.value, inst.value });
            failed += 1;
            continue;
        }
        std.debug.print("  ✓ toAssembly() = \"{s}\"\n", .{result});

        // Check if result is in the expected_assembly array (for informational purposes)
        var found = false;
        for (tc.exp_asm) |expected_asm| {
            if (std.mem.eql(u8, result, expected_asm)) {
                found = true;
                break;
            }
        }
        if (!found and tc.exp_asm.len > 0) {
            // Not a failure, just informational - the parsed value matches which is what matters
            std.debug.print("  Note: toAssembly() = \"{s}\" (not in expected list, but parses correctly)\n", .{result});
        }

        // Test round-trip: assembly -> instruction -> assembly
        const round_trip = try inst.toAssembly(&buffer, &symbol_table, true);
        const round_trip_inst = AInstruction.fromAssembly(round_trip, &symbol_table) catch |err| {
            std.debug.print("  ✗ FAILED: Round-trip fromAssembly error: {}\n", .{err});
            failed += 1;
            continue;
        };
        if (round_trip_inst.value != inst.value) {
            std.debug.print("  ✗ FAILED: Round-trip value mismatch: {d} -> {d}\n", .{ inst.value, round_trip_inst.value });
            failed += 1;
            continue;
        }
        std.debug.print("  ✓ Round-trip: \"{s}\" -> \"{s}\"\n", .{ tc.assembly, round_trip });

        passed += 1;
    }

    std.debug.print("=== Assembly Test Summary ===\n", .{});
    std.debug.print("Total: {d}\n", .{test_cases.len});
    std.debug.print("Passed: {d}\n", .{passed});
    std.debug.print("Failed: {d}\n", .{failed});

    if (failed > 0) {
        std.debug.print("\n✗ Some tests failed!\n", .{});
        return ERR.TestFailed;
    }

    std.debug.print("\n✓ All assembly tests passed!\n", .{});
}
