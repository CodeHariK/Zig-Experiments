// =============================================================================
// Machine Language Errors
// =============================================================================
//
// Centralized error definitions for the machine language module.
// This provides a single source of truth for all error types used across
// A-instructions, C-instructions, symbol tables, and assembly operations.
//
// -----------------------------------------------------------------------------
// Error Categories
// -----------------------------------------------------------------------------
//
// 1. Instruction Errors: Related to instruction parsing/decoding
// 2. Assembly Errors: Related to assembly syntax and parsing
// 3. Symbol Table Errors: Related to symbol resolution and management
// 4. Test Errors: For test framework (not part of public API)
//
// -----------------------------------------------------------------------------
// Usage
// -----------------------------------------------------------------------------
//
// Import this module and use the Error type:
//   const errors = @import("errors.zig");
//   return errors.Error.NotAInstruction;
//
// Or use the specific error set for your module:
//   pub const MyError = errors.Error;
//   pub fn myFunction() MyError!ReturnType { ... }
//

/// Comprehensive error set for machine language operations
pub const Error = error{
    // =========================================================================
    // Instruction Errors
    // =========================================================================

    /// Binary does not represent an A-instruction (bit 15 = 1)
    NotAInstruction,

    /// Binary does not represent a C-instruction (bits 15-13 != 111)
    NotCInstruction,

    /// Binary does not represent a valid instruction
    InvalidInstruction,

    // =========================================================================
    // Assembly Errors
    // =========================================================================

    /// Assembly syntax is invalid (missing @, malformed, etc.)
    InvalidAssembly,

    // =========================================================================
    // Symbol Table Errors
    // =========================================================================

    /// Symbol not found in symbol table
    SymbolNotFound,

    /// Symbol already exists in symbol table (duplicate label/variable)
    SymbolAlreadyExists,

    /// No more variable space available (exceeded RAM_END)
    OutOfVariableSpace,

    // =========================================================================
    // Test Errors (internal use only)
    // =========================================================================

    /// Test case failed (for test framework)
    TestFailed,
};
