// =============================================================================
// VM Command - Command Types and Structures
// =============================================================================
//
// This module defines the data structures for representing VM commands.
// VM commands come in two main types:
//   1. Arithmetic/Logical operations (no operands)
//   2. Memory access operations (push/pop with segment and index)
//
// -----------------------------------------------------------------------------
// Command Types
// -----------------------------------------------------------------------------

const std = @import("std");

/// Arithmetic and logical operations
pub const ArithmeticOp = enum {
    add, // Pop two values, push (y + x)
    sub, // Pop two values, push (y - x)
    neg, // Pop one value, push (-x)
    eq, // Pop two values, push (y == x ? -1 : 0)
    gt, // Pop two values, push (y > x ? -1 : 0)
    lt, // Pop two values, push (y < x ? -1 : 0)
    @"and", // Pop two values, push (y & x)
    @"or", // Pop two values, push (y | x)
    not, // Pop one value, push (~x)

    /// Convert operation name string to ArithmeticOp enum
    pub fn fromString(name: []const u8) ?ArithmeticOp {
        return ArithmeticOpMap.get(name) orelse null;
    }

    /// Convert ArithmeticOp enum to string
    pub fn toString(self: ArithmeticOp) []const u8 {
        return @tagName(self);
    }

    /// Check if operation requires two operands
    pub fn isBinary(self: ArithmeticOp) bool {
        return switch (self) {
            .add, .sub, .eq, .gt, .lt, .@"and", .@"or" => true,
            .neg, .not => false,
        };
    }

    /// Check if operation is a comparison (eq, gt, lt)
    pub fn isComparison(self: ArithmeticOp) bool {
        return switch (self) {
            .eq, .gt, .lt => true,
            else => false,
        };
    }
};

const ArithmeticOpMap = std.StaticStringMap(ArithmeticOp).initComptime(.{
    .{ "add", .add },
    .{ "sub", .sub },
    .{ "neg", .neg },
    .{ "eq", .eq },
    .{ "gt", .gt },
    .{ "lt", .lt },
    .{ "and", .@"and" },
    .{ "or", .@"or" },
    .{ "not", .not },
});

/// Memory segments in the VM
pub const Segment = enum {
    local, // LCL pointer - function local variables
    argument, // ARG pointer - function arguments
    this, // THIS pointer - object instance variables
    that, // THAT pointer - array elements
    constant, // Literal constants (no memory, just values)
    static, // Class-level variables (mapped to RAM[16..255])
    pointer, // THIS/THAT pointers (RAM[3-4])
    temp, // Temporary variables (RAM[5..12])

    /// Convert segment name string to Segment enum
    pub fn fromString(name: []const u8) ?Segment {
        return SegmentMap.get(name) orelse null;
    }

    /// Convert Segment enum to string
    pub fn toString(self: Segment) []const u8 {
        return @tagName(self);
    }
};

const SegmentMap = std.StaticStringMap(Segment).initComptime(.{
    .{ "local", .local },
    .{ "argument", .argument },
    .{ "this", .this },
    .{ "that", .that },
    .{ "constant", .constant },
    .{ "static", .static },
    .{ "pointer", .pointer },
    .{ "temp", .temp },
});

/// Memory access operation type
pub const MemoryOp = enum {
    push, // Push value from segment[index] onto stack
    pop, // Pop value from stack into segment[index]
};

/// Unified VM command type
pub const Command = union(enum) {
    /// Arithmetic or logical operation
    arithmetic: ArithmeticOp,
    /// Memory access operation (push or pop)
    memory: struct {
        op: MemoryOp,
        segment: Segment,
        index: u16,
    },

    const Self = @This();

    /// Create an arithmetic command
    pub fn arithmeticCommand(op: ArithmeticOp) Self {
        return Self{ .arithmetic = op };
    }

    /// Create a push command
    pub fn pushCommand(segment: Segment, index: u16) Self {
        return Self{
            .memory = .{
                .op = .push,
                .segment = segment,
                .index = index,
            },
        };
    }

    /// Create a pop command
    pub fn popCommand(segment: Segment, index: u16) Self {
        return Self{
            .memory = .{
                .op = .pop,
                .segment = segment,
                .index = index,
            },
        };
    }

    /// Check if command is an arithmetic operation
    pub fn isArithmetic(self: Self) bool {
        return switch (self) {
            .arithmetic => true,
            .memory => false,
        };
    }

    /// Check if command is a memory access operation
    pub fn isMemory(self: Self) bool {
        return switch (self) {
            .arithmetic => false,
            .memory => true,
        };
    }

    /// Check if command is a push operation
    pub fn isPush(self: Self) bool {
        return switch (self) {
            .arithmetic => false,
            .memory => |m| m.op == .push,
        };
    }

    /// Check if command is a pop operation
    pub fn isPop(self: Self) bool {
        return switch (self) {
            .arithmetic => false,
            .memory => |m| m.op == .pop,
        };
    }

    /// Convert command to string representation (for debugging)
    pub fn toString(self: Self, buffer: []u8) ![]const u8 {
        return switch (self) {
            .arithmetic => |op| try std.fmt.bufPrint(buffer, "{s}", .{op.toString()}),
            .memory => |m| {
                const op_str = if (m.op == .push) "push" else "pop";
                return try std.fmt.bufPrint(buffer, "{s} {s} {d}", .{ op_str, m.segment.toString(), m.index });
            },
        };
    }
};

// =============================================================================
// Tests
// =============================================================================

test "Segment fromString and toString" {
    const segments = [_]Segment{ .local, .argument, .this, .that, .constant, .static, .pointer, .temp };
    const names = [_][]const u8{ "local", "argument", "this", "that", "constant", "static", "pointer", "temp" };

    for (segments, names) |segment, name| {
        try std.testing.expectEqual(segment, Segment.fromString(name).?);
        try std.testing.expectEqualStrings(name, segment.toString());
    }

    try std.testing.expect(Segment.fromString("invalid") == null);
}

test "ArithmeticOp fromString and toString" {
    const ops = [_]ArithmeticOp{ .add, .sub, .neg, .eq, .gt, .lt, .@"and", .@"or", .not };
    const names = [_][]const u8{ "add", "sub", "neg", "eq", "gt", "lt", "and", "or", "not" };

    for (ops, names) |op, name| {
        try std.testing.expectEqual(op, ArithmeticOp.fromString(name).?);
        try std.testing.expectEqualStrings(name, op.toString());
    }

    try std.testing.expect(ArithmeticOp.fromString("invalid") == null);
}

test "ArithmeticOp isBinary" {
    try std.testing.expect(ArithmeticOp.add.isBinary());
    try std.testing.expect(ArithmeticOp.sub.isBinary());
    try std.testing.expect(ArithmeticOp.eq.isBinary());
    try std.testing.expect(ArithmeticOp.gt.isBinary());
    try std.testing.expect(ArithmeticOp.lt.isBinary());
    try std.testing.expect(ArithmeticOp.@"and".isBinary());
    try std.testing.expect(ArithmeticOp.@"or".isBinary());
    try std.testing.expect(!ArithmeticOp.neg.isBinary());
    try std.testing.expect(!ArithmeticOp.not.isBinary());
}

test "ArithmeticOp isComparison" {
    try std.testing.expect(ArithmeticOp.eq.isComparison());
    try std.testing.expect(ArithmeticOp.gt.isComparison());
    try std.testing.expect(ArithmeticOp.lt.isComparison());
    try std.testing.expect(!ArithmeticOp.add.isComparison());
    try std.testing.expect(!ArithmeticOp.neg.isComparison());
}

test "Command creation and checks" {
    // Arithmetic command
    const add_cmd = Command.arithmeticCommand(.add);
    try std.testing.expect(add_cmd.isArithmetic());
    try std.testing.expect(!add_cmd.isMemory());
    try std.testing.expect(!add_cmd.isPush());
    try std.testing.expect(!add_cmd.isPop());

    // Push command
    const push_cmd = Command.pushCommand(.constant, 5);
    try std.testing.expect(!push_cmd.isArithmetic());
    try std.testing.expect(push_cmd.isMemory());
    try std.testing.expect(push_cmd.isPush());
    try std.testing.expect(!push_cmd.isPop());

    // Pop command
    const pop_cmd = Command.popCommand(.local, 2);
    try std.testing.expect(!pop_cmd.isArithmetic());
    try std.testing.expect(pop_cmd.isMemory());
    try std.testing.expect(!pop_cmd.isPush());
    try std.testing.expect(pop_cmd.isPop());
}

test "Command toString" {
    var buffer: [256]u8 = undefined;

    // Arithmetic
    const add_cmd = Command.arithmeticCommand(.add);
    const add_str = try add_cmd.toString(&buffer);
    try std.testing.expectEqualStrings("add", add_str);

    // Push
    const push_cmd = Command.pushCommand(.constant, 7);
    const push_str = try push_cmd.toString(&buffer);
    try std.testing.expectEqualStrings("push constant 7", push_str);

    // Pop
    const pop_cmd = Command.popCommand(.local, 2);
    const pop_str = try pop_cmd.toString(&buffer);
    try std.testing.expectEqualStrings("pop local 2", pop_str);
}
