const std = @import("std");

pub const BloomFilter = struct {
    bit_array: []u8,
    num_hashes: usize,

    pub fn init(allocator: *std.mem.Allocator, size: usize, num_hashes: usize) !BloomFilter {
        const bit_array = try allocator.alloc(u8, size);
        @memset(bit_array, 0);

        return BloomFilter{
            .bit_array = bit_array,
            .num_hashes = num_hashes,
        };
    }

    fn hash(item: []const u8, seed: u32) u32 {
        return std.hash.Murmur2_32.hashWithSeed(item, seed);
    }

    pub fn add(self: *BloomFilter, item: []const u8) void {
        for (0..self.num_hashes) |i| {
            const hash_val = hash(item, @intCast(i));
            const index = hash_val % self.bit_array.len;
            self.bit_array[index] = 1;
        }
    }

    pub fn contains(self: *const BloomFilter, item: []const u8) bool {
        for (0..self.num_hashes) |i| {
            const hash_val = hash(item, @intCast(i));
            const index = hash_val % self.bit_array.len;
            if (self.bit_array[index] == 0) {
                return false;
            }
        }
        return true;
    }

    pub fn deinit(self: *BloomFilter, allocator: *std.mem.Allocator) void {
        allocator.free(self.bit_array);
    }
};
