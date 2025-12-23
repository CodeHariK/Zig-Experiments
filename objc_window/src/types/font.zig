const TrueType = @import("TrueType");
const std = @import("std");

pub fn load(ttf_data: []const u8) !void {
    const gpa = std.heap.page_allocator;

    const ttf = try TrueType.load(ttf_data);

    std.debug.print("index_map: {d}\n", .{ttf.index_map});
    std.debug.print("glyphs_len: {d}\n", .{ttf.glyphs_len});
    std.debug.print("loca: {d}\n", .{ttf.table_offsets[@intFromEnum(TrueType.TableId.loca)]});
    std.debug.print("head: {d}\n", .{ttf.table_offsets[@intFromEnum(TrueType.TableId.head)]});
    std.debug.print("glyf: {d}\n", .{ttf.table_offsets[@intFromEnum(TrueType.TableId.glyf)]});
    std.debug.print("hhea: {d}\n", .{ttf.table_offsets[@intFromEnum(TrueType.TableId.hhea)]});
    std.debug.print("hmtx: {d}\n", .{ttf.table_offsets[@intFromEnum(TrueType.TableId.hmtx)]});
    std.debug.print("kern: {d}\n", .{ttf.table_offsets[@intFromEnum(TrueType.TableId.kern)]});
    std.debug.print("GPOS: {d}\n", .{ttf.table_offsets[@intFromEnum(TrueType.TableId.GPOS)]});

    const example_string = "こんにちは!";
    const scale = ttf.scaleForPixelHeight(20);

    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(gpa);

    var it = std.unicode.Utf8View.initComptime(example_string).iterator();

    while (it.nextCodepoint()) |codepoint| {
        if (ttf.codepointGlyphIndex(codepoint)) |glyph| {
            buffer.clearRetainingCapacity();

            std.log.debug("0x{d}: {d}", .{ codepoint, glyph });

            const dims = ttf.glyphBitmap(gpa, &buffer, glyph, scale, scale) catch |err| switch (err) {
                error.GlyphNotFound => continue,
                error.OutOfMemory => return error.OutOfMemory,
                error.Charstring => return error.Charstring,
            };

            std.debug.print("{d}x{d}\n", .{ dims.width, dims.height });

            // const pixels = buffer.items;
            // for (0..dims.height) |j| {
            //     for (0..dims.width) |i| {
            //         const char = " .:ioVM@"[pixels[j * dims.width + i] >> 5];
            //         std.debug.print("{c}", .{char});
            //     }
            //     std.debug.print("\n", .{});
            // }
        } else {
            std.log.debug("0x{d}: none", .{codepoint});
        }
    }
}

pub fn testBitmapRendering(ttf_data: []const u8) !void {
    const gpa = std.heap.page_allocator;

    const ttf = try TrueType.load(ttf_data);

    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(gpa);

    const scale = ttf.scaleForPixelHeight(32);

    for (0..ttf.glyphs_len) |glyph_index| {
        buffer.clearRetainingCapacity();

        std.debug.print("glyph_index={d}/{d}\n", .{ glyph_index, ttf.glyphs_len });

        const dims = ttf.glyphBitmap(gpa, &buffer, @enumFromInt(glyph_index), scale, scale) catch |err| switch (err) {
            error.GlyphNotFound => continue,
            error.OutOfMemory => return error.OutOfMemory,
            error.Charstring => return error.Charstring,
        };

        std.debug.print("{d}x{d}\n", .{ dims.width, dims.height });
        std.debug.print("{d}x{d}\n", .{ dims.off_x, dims.off_y });
        std.debug.print("{d}\n", .{dims.width * dims.height});
        std.debug.print("{d}\n", .{buffer.items.len});
    }
}
