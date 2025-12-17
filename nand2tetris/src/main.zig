const std = @import("std");

const l = @import("gates/logic.zig").Logic;

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
