// =============================================================================
// Memory Map and Predefined Symbols
// =============================================================================
//
// This module documents the Hack computer's memory architecture and
// predefined symbols used in assembly language.
//
// -----------------------------------------------------------------------------
// Memory Architecture
// -----------------------------------------------------------------------------
//
// RAM (Data Memory):
//   - Size: 16K (16,384) 16-bit words
//   - Addresses: 0 to 16,383
//   - General-purpose storage
//   - Access via M in C-instructions (where M = RAM[A])
//
// Screen (Memory-Mapped I/O):
//   - Addresses: 16,384 to 24,575 (8K words)
//   - Maps to 256x512 pixel display
//   - Each word controls 16 pixels (one row segment)
//   - Row-major order: pixels arranged left-to-right, top-to-bottom
//
// Keyboard (Memory-Mapped I/O):
//   - Address: 24,576
//   - Read-only
//   - Returns ASCII code of pressed key
//   - Returns 0 when no key pressed
//
// -----------------------------------------------------------------------------
// Predefined Symbols
// -----------------------------------------------------------------------------
//
// Registers (R0-R15):
//   - R0 through R15: RAM addresses 0-15
//   - General-purpose registers
//   - Commonly used for local variables
//
// Virtual Registers (for high-level language support):
//   - SP: Stack pointer (R0)
//   - LCL: Local variables pointer (R1)
//   - ARG: Arguments pointer (R2)
//   - THIS: This pointer (R3)
//   - THAT: That pointer (R4)
//
// Memory-Mapped I/O:
//   - SCREEN: Address 16,384 (start of screen memory)
//   - KBD: Address 24,576 (keyboard input)
//
// -----------------------------------------------------------------------------
// Implementation
// -----------------------------------------------------------------------------

const std = @import("std");
const testing = std.testing;
const ERR = @import("types").Error;

/// RAM size in words
pub const RAM_SIZE: u16 = 16384;

/// RAM start address
pub const RAM_START: u16 = 0;

/// RAM end address
pub const RAM_END: u16 = RAM_SIZE - 1;

/// Screen start address
pub const SCREEN_START: u16 = 16384;

/// Screen size in words
pub const SCREEN_SIZE: u16 = 8192;

/// Screen end address
pub const SCREEN_END: u16 = SCREEN_START + SCREEN_SIZE - 1;

/// Keyboard address
pub const KBD_ADDRESS: u16 = 24576;

/// Screen dimensions
pub const SCREEN_WIDTH: u16 = 512; // pixels
pub const SCREEN_HEIGHT: u16 = 256; // pixels
pub const PIXELS_PER_WORD: u16 = 16; // pixels per 16-bit word
pub const WORDS_PER_ROW: u16 = SCREEN_WIDTH / PIXELS_PER_WORD; // 32 words per row

/// Register addresses (R0-R15)
pub const R0: u16 = 0;
pub const R1: u16 = 1;
pub const R2: u16 = 2;
pub const R3: u16 = 3;
pub const R4: u16 = 4;
pub const R5: u16 = 5;
pub const R6: u16 = 6;
pub const R7: u16 = 7;
pub const R8: u16 = 8;
pub const R9: u16 = 9;
pub const R10: u16 = 10;
pub const R11: u16 = 11;
pub const R12: u16 = 12;
pub const R13: u16 = 13;
pub const R14: u16 = 14;
pub const R15: u16 = 15;

/// Virtual register addresses
pub const SP: u16 = R0; // Stack pointer
pub const LCL: u16 = R1; // Local variables pointer
pub const ARG: u16 = R2; // Arguments pointer
pub const THIS: u16 = R3; // This pointer
pub const THAT: u16 = R4; // That pointer

/// Check if address is in RAM range
pub fn isRAMAddress(address: u16) bool {
    return address >= RAM_START and address <= RAM_END;
}

/// Check if address is in Screen range
pub fn isScreenAddress(address: u16) bool {
    return address >= SCREEN_START and address <= SCREEN_END;
}

/// Check if address is Keyboard
pub fn isKeyboardAddress(address: u16) bool {
    return address == KBD_ADDRESS;
}

/// Calculate screen address from row and column
/// Returns null if coordinates are out of bounds
pub fn screenAddress(row: u16, col: u16) ?u16 {
    if (row >= SCREEN_HEIGHT or col >= SCREEN_WIDTH) {
        return null;
    }
    const word_col = col / PIXELS_PER_WORD;
    return SCREEN_START + (row * WORDS_PER_ROW) + word_col;
}

/// Get row from screen address
pub fn screenRow(address: u16) ?u16 {
    if (!isScreenAddress(address)) {
        return null;
    }
    const offset = address - SCREEN_START;
    return offset / WORDS_PER_ROW;
}

/// Get column (word index) from screen address
pub fn screenCol(address: u16) ?u16 {
    if (!isScreenAddress(address)) {
        return null;
    }
    const offset = address - SCREEN_START;
    return offset % WORDS_PER_ROW;
}

// =============================================================================
// Symbol Table
// =============================================================================
//
// The symbol table maps symbolic names to memory addresses. It handles three
// types of symbols: predefined symbols, labels, and variables.
//
// -----------------------------------------------------------------------------
// Types of Symbols
// -----------------------------------------------------------------------------
//
// 1. PREDEFINED SYMBOLS
//    - Built-in symbols provided by the Hack architecture
//    - Registers: R0-R15 (RAM addresses 0-15)
//    - Virtual registers: SP, LCL, ARG, THIS, THAT
//    - I/O: SCREEN (16384), KBD (24576)
//    - Initialized automatically when symbol table is created
//
// 2. LABELS
//    - Represent instruction addresses (ROM locations)
//    - Defined with parentheses: (LOOP), (END), (START)
//    - Used as jump targets: @LOOP, @END
//    - Address = ROM address where the instruction is located
//    - Added during first pass of assembly (when label definition is encountered)
//    - Example:
//        (LOOP)
//          @i
//          M=M+1
//          @LOOP    // Jump back to LOOP label
//          0;JMP
//
// 3. VARIABLES
//    - Represent data memory addresses (RAM locations)
//    - Defined implicitly when first used: @counter, @sum, @x
//    - Used to store and access data values
//    - Address = Auto-assigned starting at RAM[16]
//    - Added during second pass of assembly (when undefined symbol is encountered)
//    - Example:
//        @counter   // Variable - auto-assigned to RAM[16]
//        M=0
//        @sum       // Variable - auto-assigned to RAM[17]
//        M=0
//
// -----------------------------------------------------------------------------
// Why Variables Start at RAM[16]
// -----------------------------------------------------------------------------
//
// RAM addresses 0-15 are reserved for predefined registers:
//   - R0 through R15 = addresses 0-15
//   - Variables start at 16 to avoid conflicts
//
// Memory Layout:
//   RAM[0-15]    → R0-R15 (predefined registers)
//   RAM[16+]     → Variables (user-defined, auto-assigned sequentially)
//   RAM[16384+]  → Screen memory (memory-mapped I/O)
//   RAM[24576]   → Keyboard (memory-mapped I/O)
//
// -----------------------------------------------------------------------------
// Variable Characteristics: Global and Eternal
// -----------------------------------------------------------------------------
//
// In Hack assembly language, variables are:
//
// 1. GLOBAL SCOPE
//    - All variables are program-wide
//    - No local scoping (no functions/subroutines in basic Hack)
//    - Once defined, accessible from anywhere in the program
//
// 2. ETERNAL (Permanent)
//    - Once assigned an address during assembly, they remain forever
//    - Cannot be deleted or freed
//    - Symbol table is built at assembly time and is static
//    - Address assignment is permanent for the program's lifetime
//
// 3. CANNOT BE DELETED
//    - The symbol table is built once during assembly (compile time)
//    - It does not change during program execution (runtime)
//    - No garbage collection or memory management
//    - Variables persist for the entire program execution
//
// Why This Design?
//   - Hack is a simple assembly language
//   - No scoping mechanisms (no local variables)
//   - No dynamic memory management
//   - No garbage collection
//   - Symbol resolution happens at assembly time, not runtime
//
// Example:
//   @counter    // First use → assigned RAM[16]
//   M=0
//
//   @sum        // First use → assigned RAM[17]
//   M=0
//
//   // Later in code...
//   @counter    // Still refers to RAM[16] - same variable
//   M=M+1
//
//   // counter and sum exist for the entire program
//   // They can't be "deleted" or "freed"
//
// -----------------------------------------------------------------------------
// Label vs Variable Comparison
// -----------------------------------------------------------------------------
//
// | Aspect          | Label                    | Variable                |
// |-----------------|--------------------------|-------------------------|
// | Memory Type     | ROM (instructions)      | RAM (data)              |
// | Definition      | Explicit: (LABEL)        | Implicit: @variable    |
// | Address Source  | Instruction location     | Auto-assigned (16+)    |
// | Purpose         | Control flow (jumps)     | Data storage            |
// | Assembly Pass   | First pass               | Second pass             |
// | Scope           | Global                   | Global                  |
// | Lifetime        | Eternal                  | Eternal                 |
// | Can Delete?     | No                       | No                      |
//
// -----------------------------------------------------------------------------
// Implementation Notes
// -----------------------------------------------------------------------------
//
// - addLabel(label, address): Manually sets the address (ROM instruction address)
// - addVariable(variable): Auto-assigns next available RAM address starting at 16
// - Both are stored in the same hash map
// - Symbol table is built during assembly and remains static during execution
//

/// Symbol table for mapping symbols to addresses
/// Handles predefined symbols, labels, and variables
pub const SymbolTable = struct {
    const HashMap = std.StringHashMap(u16);
    map: HashMap, // All symbols: predefined, labels, and variables
    label_names: std.StringHashMap(void), // Track which symbols are labels (not variables)
    next_variable_addr: u16 = 16, // Variables start at RAM[16]

    const Self = @This();

    /// Initialize symbol table with predefined symbols
    pub fn init(allocator: std.mem.Allocator) !Self {
        var table = Self{
            .map = HashMap.init(allocator),
            .label_names = std.StringHashMap(void).init(allocator),
            .next_variable_addr = 16,
        };

        // Add predefined registers R0-R15
        try table.map.put("R0", R0);
        try table.map.put("R1", R1);
        try table.map.put("R2", R2);
        try table.map.put("R3", R3);
        try table.map.put("R4", R4);

        try table.map.put("R5", R5);
        try table.map.put("R6", R6);
        try table.map.put("R7", R7);
        try table.map.put("R8", R8);
        try table.map.put("R9", R9);
        try table.map.put("R10", R10);
        try table.map.put("R11", R11);
        try table.map.put("R12", R12);
        try table.map.put("R13", R13);
        try table.map.put("R14", R14);
        try table.map.put("R15", R15);

        // Add virtual registers
        try table.map.put("SP", SP);
        try table.map.put("LCL", LCL);
        try table.map.put("ARG", ARG);
        try table.map.put("THIS", THIS);
        try table.map.put("THAT", THAT);

        // Add memory-mapped I/O
        try table.map.put("SCREEN", SCREEN_START);
        try table.map.put("KBD", KBD_ADDRESS);

        return table;
    }

    /// Deinitialize symbol table
    pub fn deinit(self: *Self) void {
        self.map.deinit();
        self.label_names.deinit();
    }

    /// Look up a symbol and return its address
    /// Returns null if symbol not found
    pub fn lookup(self: *const Self, symbol: []const u8) ?u16 {
        return self.map.get(symbol);
    }

    /// Add a label (instruction address)
    /// Labels are typically added during first pass of assembly
    pub fn addLabel(self: *Self, label: []const u8, address: u16) !void {
        // Check if already exists
        if (self.map.contains(label)) {
            return error.SymbolAlreadyExists;
        }
        try self.map.put(label, address);
        try self.label_names.put(label, {});
    }

    /// Add a variable (auto-assigns next available address starting at 16)
    /// Variables are typically added during second pass of assembly
    pub fn addVariable(self: *Self, variable: []const u8) !u16 {
        // Check if already exists
        if (self.map.get(variable)) |addr| {
            return addr;
        }

        // Check if we've run out of variable space
        if (self.next_variable_addr > RAM_END) {
            return ERR.OutOfVariableSpace;
        }

        const addr = self.next_variable_addr;
        try self.map.put(variable, addr);
        self.next_variable_addr += 1;
        return addr;
    }

    /// Check if a symbol exists
    pub fn contains(self: *const Self, symbol: []const u8) bool {
        return self.map.contains(symbol);
    }

    /// Get the next available variable address (without adding it)
    pub fn getNextVariableAddress(self: *const Self) u16 {
        return self.next_variable_addr;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "Memory map: RAM addresses" {
    try testing.expect(isRAMAddress(0));
    try testing.expect(isRAMAddress(16383));
    try testing.expect(!isRAMAddress(16384));
    try testing.expect(!isRAMAddress(65535));
}

test "Memory map: Screen addresses" {
    try testing.expect(isScreenAddress(16384));
    try testing.expect(isScreenAddress(24575));
    try testing.expect(!isScreenAddress(16383));
    try testing.expect(!isScreenAddress(24576));
}

test "Memory map: Keyboard address" {
    try testing.expect(isKeyboardAddress(24576));
    try testing.expect(!isKeyboardAddress(24575));
    try testing.expect(!isKeyboardAddress(24577));
}

test "Memory map: Screen address calculation" {
    const addr = screenAddress(0, 0);
    try testing.expect(addr != null);
    try testing.expectEqual(SCREEN_START, addr.?);

    const addr2 = screenAddress(100, 200);
    try testing.expect(addr2 != null);
    try testing.expect(addr2.? >= SCREEN_START);
    try testing.expect(addr2.? <= SCREEN_END);
}

test "Memory map: Screen address out of bounds" {
    try testing.expect(screenAddress(256, 0) == null);
    try testing.expect(screenAddress(0, 512) == null);
    try testing.expect(screenAddress(300, 600) == null);
}

test "Memory map: Screen row/col extraction" {
    const addr = screenAddress(10, 32).?;
    const row = screenRow(addr);
    const col = screenCol(addr);
    try testing.expect(row != null);
    try testing.expect(col != null);
    try testing.expectEqual(@as(u16, 10), row.?);
}
