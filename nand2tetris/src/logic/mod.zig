//! Gates Module
//!
//! This is the root file for the gates module. It exports all gates functionality
//! including logic gates, multiplexers, adders, and ALU.

const logic_mod = @import("logic.zig");
const mux = @import("mux.zig");
const adder = @import("adder.zig");
const two_complement = @import("two_complement.zig");

// Re-export main namespaces
pub const Logic = logic_mod.Logic;
pub const Logic_I = logic_mod.Logic_I;

// ============================================================================
// Tests
// ============================================================================

const std = @import("std");
const testing = std.testing;

test "gates module: include all gate tests" {
    // Import all gate files to ensure their tests are included in the gates module
    _ = @import("logic.zig");
    _ = @import("mux.zig");
    _ = @import("adder.zig");
    _ = @import("two_complement.zig");
}
