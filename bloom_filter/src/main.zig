const std = @import("std");
const bloom = @import("bloom_filter.zig");

pub fn main() !void {
    var allocator = std.heap.page_allocator;

    var filter = try bloom.BloomFilter.init(&allocator, 1024, 5);
    defer filter.deinit(&allocator);

    const item = "hello";
    const item2 = "world";

    filter.add(item);
    std.debug.print("Does filter contain 'hello'? {}\n", .{filter.contains(item)});
    std.debug.print("Does filter contain 'world'? {}\n", .{filter.contains(item2)});
}
