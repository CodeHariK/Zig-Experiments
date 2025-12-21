//! Memory Module
//!
//! This is the root file for the memory module. It exports all memory components
//! including DFF, Bit, Register, and other sequential logic components.

const dff_mod = @import("dff.zig");
const bit_mod = @import("bit.zig");
const register_mod = @import("register.zig");

// Re-export main types
pub const DFF = dff_mod.DFF;
pub const Bit = bit_mod.Bit;
pub const Register = register_mod.Register;
pub const Register16 = register_mod.Register16;

// ============================================================================
// Tests
// ============================================================================

const std = @import("std");
const testing = std.testing;

test "memory module: include all memory tests" {
    // Import all memory files to ensure their tests are included in the memory module
    _ = @import("dff.zig");
    _ = @import("bit.zig");
    _ = @import("register.zig");
    _ = @import("ram.zig");
    _ = @import("pc.zig");
}
