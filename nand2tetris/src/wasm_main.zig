const std = @import("std");
const machine_language = @import("machine_language");

// WASM memory allocator - use fixed buffer for freestanding
var allocator_buffer: [64 * 1024]u8 = undefined; // 64KB buffer
var fba = std.heap.FixedBufferAllocator.init(&allocator_buffer);
var allocator: std.mem.Allocator = fba.allocator();

// Assemble a program from assembly array
// Input: assembly lines in memory (newline-separated or null-separated)
// Output: binary array written to output_ptr
// Returns: number of 16-bit words written (0 on error)
export fn assembleProgram(
    assembly_ptr: [*]const u8,
    assembly_len: usize,
    binary_ptr: [*]u16,
    binary_len: usize,
) usize {
    // Reset allocator for each call
    fba.reset();

    // Parse assembly lines (assume newline-separated)
    var assembly_lines = std.ArrayList([]const u8).empty;
    defer assembly_lines.deinit(allocator);

    var start: usize = 0;
    var i: usize = 0;
    while (i < assembly_len) : (i += 1) {
        if (assembly_ptr[i] == '\n' or assembly_ptr[i] == 0) {
            if (i > start) {
                const line = assembly_ptr[start..i];
                assembly_lines.append(allocator, line) catch return 0;
            }
            start = i + 1;
        }
    }
    // Add last line if no trailing newline
    if (start < assembly_len) {
        const line = assembly_ptr[start..assembly_len];
        assembly_lines.append(allocator, line) catch return 0;
    }

    // Create program and assemble
    var program = machine_language.Program.init(allocator) catch return 0;
    defer program.deinit(allocator);

    program.fromAssemblyArray(allocator, assembly_lines.items) catch return 0;

    // Convert to binary array
    var binary_array = program.toBinaryArray(allocator) catch return 0;
    defer binary_array.deinit(allocator);

    if (binary_array.items.len == 0) return 0; // No instructions assembled
    if (binary_array.items.len > binary_len) return 0;

    // Clear the output area first (set to zeros)
    @memset(binary_ptr[0..binary_len], 0);

    // Copy the binary array to output
    @memcpy(binary_ptr[0..binary_array.items.len], binary_array.items);
    return @intCast(binary_array.items.len);
}

// Disassemble a program from binary array
// Input: binary array (u16 values)
// Output: assembly lines written to output_ptr (newline-separated)
// Returns: number of bytes written (0 on error)
export fn disassembleProgram(
    binary_ptr: [*]const u16,
    binary_len: usize,
    output_ptr: [*]u8,
    output_len: usize,
    emit_symbols: u8, // 0=false, 1=true
) usize {
    // Reset allocator for each call
    fba.reset();

    // Create program from binary
    var program = machine_language.Program.init(allocator) catch return 0;
    defer program.deinit(allocator);

    const binary_slice = binary_ptr[0..binary_len];
    program.fromBinaryArray(allocator, binary_slice) catch return 0;

    // Convert to assembly
    var buffer: [256]u8 = undefined;
    var assembly_lines = program.toAssemblyArray(allocator, &buffer, emit_symbols != 0) catch return 0;
    defer {
        for (assembly_lines.items) |line| {
            allocator.free(line);
        }
        assembly_lines.deinit(allocator);
    }

    // Write assembly lines to output (newline-separated)
    var written: usize = 0;
    for (assembly_lines.items) |line| {
        if (written + line.len + 1 > output_len) break; // +1 for newline
        @memcpy(output_ptr[written .. written + line.len], line);
        written += line.len;
        if (written < output_len) {
            output_ptr[written] = '\n';
            written += 1;
        }
    }

    return written;
}
