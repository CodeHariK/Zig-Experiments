pub inline fn cast(comptime T: type, value: anytype) T {
    return switch (@typeInfo(T)) {
        .int => @as(T, @intCast(value)),
        .float => @as(T, @floatCast(value)),
        .pointer => @as(T, @ptrCast(value)),
        .comptime_int => @as(T, value),
        .comptime_float => @as(T, value),
        else => @as(T, value),
    };
}
