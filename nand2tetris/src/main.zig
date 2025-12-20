const std = @import("std");

const l = @import("gates").Logic;

// Import memory module to include tests
const memory = @import("memory");

// Reference them to avoid unused import warnings
comptime {
    _ = memory;
    // Gates files are included through the gates module, no need to import directly
}

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
