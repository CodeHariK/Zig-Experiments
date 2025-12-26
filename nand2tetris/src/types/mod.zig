//! Types Module
//!
//! Provides type-level utilities and bit conversion functions.
//! This module contains type constructors and utilities for working with
//! integer types and bit arrays.

pub const Error = @import("errors.zig").Error;

pub const uintn = @import("uintn.zig");

// Re-export all public functions from uintn.zig for convenience
pub const UIntN = uintn.UIntN;
pub const toBits = uintn.toBits;
pub const fromBits = uintn.fromBits;

// Re-export convenience functions
pub const b2 = uintn.b2;
pub const b3 = uintn.b3;
pub const b6 = uintn.b6;
pub const b4 = uintn.b4;
pub const b8 = uintn.b8;
pub const b9 = uintn.b9;
pub const b12 = uintn.b12;
pub const b13 = uintn.b13;
pub const b14 = uintn.b14;
pub const b15 = uintn.b15;
pub const b16 = uintn.b16;
pub const fb2 = uintn.fb2;
pub const fb3 = uintn.fb3;
pub const fb4 = uintn.fb4;
pub const fb8 = uintn.fb8;
pub const fb12 = uintn.fb12;
pub const fb13 = uintn.fb13;
pub const fb15 = uintn.fb15;
pub const fb16 = uintn.fb16;
