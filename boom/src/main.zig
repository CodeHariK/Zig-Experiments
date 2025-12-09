// Boom - Native macOS window with input handling

const std = @import("std");
const types = @import("types/mod.zig");
const win = @import("window.zig");
const font = @import("types/font.zig");
const image = @import("types/image/ppm.zig");

const Window = win.Window;
const Color = types.Color;
const Key = types.Key;
const Time = types.Time;
const MouseEvent = types.MouseEvent;
const KeyEvent = types.KeyEvent;
const ScrollEvent = types.ScrollEvent;

// =============================================================================
// Event Callbacks (JS-style)
// =============================================================================

fn handleMouseDown(e: MouseEvent) void {
    const btn = switch (e.button) {
        .left => "Left",
        .right => "Right",
        .middle => "Middle",
        .none => "None",
    };
    std.debug.print("🖱️  Mouse {s} down at ({d:.0}, {d:.0})\n", .{ btn, e.x, e.y });
}

fn handleMouseUp(e: MouseEvent) void {
    std.debug.print("🖱️  Mouse up at ({d:.0}, {d:.0})\n", .{ e.x, e.y });
}

fn handleMouseMove(x: f64, y: f64) void {
    _ = x;
    _ = y;
}

fn handleKeyDown(e: KeyEvent) void {
    if (e.char) |ch| {
        std.debug.print("⌨️  Key down: '{c}' (code: {d})", .{ ch, e.code });
    } else {
        std.debug.print("⌨️  Key down: code {d}", .{e.code});
    }

    if (e.shift or e.ctrl or e.alt or e.cmd) {
        std.debug.print(" [", .{});
        if (e.cmd) std.debug.print("⌘", .{});
        if (e.ctrl) std.debug.print("⌃", .{});
        if (e.alt) std.debug.print("⌥", .{});
        if (e.shift) std.debug.print("⇧", .{});
        std.debug.print("]", .{});
    }
    std.debug.print("\n", .{});
}

fn handleKeyUp(e: KeyEvent) void {
    std.debug.print("⌨️  Key up: code {d}\n", .{e.code});
}

fn handleScroll(e: ScrollEvent) void {
    std.debug.print("📜 Scroll: {d:.2} at ({d:.0}, {d:.0})\n", .{ e.delta, e.x, e.y });
}

// =============================================================================
// Main
// =============================================================================

fn tesst(out: *std.Io.Writer, img_width: f32, img_height: f32) anyerror!void {
    try image.createGradientMap(out, img_width, img_height, 0, 0, img_width, img_height);
}

pub fn main() !void {
    try font.load(@embedFile("assets/GoNotoCurrent-Regular.ttf"));
    // try font.testBitmapRendering(@embedFile("assets/GoNotoCurrent-Regular.ttf"));

    try image.writePPMImage(10.0, 10.0, tesst);

    std.debug.print("Starting Boom...\n", .{});
    std.debug.print("Press ESC or Q to quit\n\n", .{});

    var window = try Window.init(.{
        .title = "Boom! - 60 FPS Demo",
        .width = 800,
        .height = 600,
        .background = Color.dark,
    });

    _ = window
        .onMouseDown(handleMouseDown)
        .onMouseUp(handleMouseUp)
        .onMouseMove(handleMouseMove)
        .onKeyDown(handleKeyDown)
        .onKeyUp(handleKeyUp)
        .onScroll(handleScroll);

    window.show();

    // Toggle FPS cap: true = 30fps, false = unlimited
    const cap_fps = true;
    var timer = Time.init(if (cap_fps) 30 else 0);
    var fps_print_timer: f64 = 0;

    while (!window.shouldClose()) {
        const dt = timer.tick(); // Delta time in seconds

        window.pollEvents();

        const input = window.getInput();

        // Quit on ESC or Q
        if (input.key_pressed) {
            if (input.key_code == Key.escape or input.key_code == Key.q) {
                std.debug.print("Quit requested!\n", .{});
                break;
            }
        }

        // Print FPS every second
        fps_print_timer += dt;
        if (fps_print_timer >= 1.0) {
            std.debug.print("FPS: {d:.1} | Frame: {d} | dt: {d:.2}ms\n", .{
                timer.getFps(),
                timer.getFrameCount(),
                timer.deltaMs(),
            });
            fps_print_timer = 0;
        }

        // Sleep to maintain target FPS
        timer.sleep();
    }

    std.debug.print("Goodbye!\n", .{});
}
