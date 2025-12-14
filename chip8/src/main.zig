const std = @import("std");
const rl = @import("raylib");
const rui = @import("raygui");
const Chip8 = @import("chip8.zig").Chip8;

pub fn main() !void {
    try chip8main();
}

pub fn chip8main() !void {
    var chip8 = Chip8.init();

    // try chip8.loadROM("roms/HexToDecimal.ch8");
    // try chip8.loadROM("roms/LittleLamb.ch8");
    // try chip8.loadROM("roms/SpaceInvaders.ch8");
    try chip8.loadROM("roms/INVADERS.ch8");
    // try chip8.loadROM("roms/cube.ch8");
    // try chip8.loadROM("roms/syntax.ch8");

    std.debug.print("Chip8 initialized\n", .{});

    // Initialization
    //--------------------------------------------------------------------------------------
    const SCREEN_WIDTH = 640;
    const SCREEN_HEIGHT = 400;

    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.dark_purple);

        // Update keyboard input BEFORE running cycles
        // Reset keys each frame
        chip8.reset_keys();

        // CHIP-8 Keypad mapping to QWERTY keyboard:
        // 1 2 3 C -> 1 2 3 4
        // 4 5 6 D -> Q W E R
        // 7 8 9 E -> A S D F
        // A 0 B F -> Z X C V

        if (rl.isKeyDown(.one)) chip8.set_key(0x1);
        if (rl.isKeyDown(.two)) chip8.set_key(0x2);
        if (rl.isKeyDown(.three)) chip8.set_key(0x3);
        if (rl.isKeyDown(.four)) chip8.set_key(0xC);

        if (rl.isKeyDown(.q)) chip8.set_key(0x4);
        if (rl.isKeyDown(.w)) chip8.set_key(0x5);
        if (rl.isKeyDown(.e)) chip8.set_key(0x6);
        if (rl.isKeyDown(.r)) chip8.set_key(0xD);

        if (rl.isKeyDown(.a)) chip8.set_key(0x7);
        if (rl.isKeyDown(.s)) chip8.set_key(0x8);
        if (rl.isKeyDown(.d)) chip8.set_key(0x9);
        if (rl.isKeyDown(.f)) chip8.set_key(0xE);

        if (rl.isKeyDown(.z)) chip8.set_key(0xA);
        if (rl.isKeyDown(.x)) chip8.set_key(0x0);
        if (rl.isKeyDown(.c)) chip8.set_key(0xB);
        if (rl.isKeyDown(.v)) chip8.set_key(0xF);

        // Run multiple cycles per frame for proper speed
        // CHIP-8 typically runs at ~500-700Hz, so at 60 FPS we need ~7-10 cycles per frame
        // Using 5 for better playability
        for (0..5) |_| {
            chip8.emulateCycle();
        }

        if (chip8.draw_flag) {
            for (0..32) |row| {
                for (0..64) |col| {
                    if (chip8.gfx[row][col]) {
                        rl.drawRectangle(
                            @divTrunc(@as(i32, @intCast(col)) * SCREEN_WIDTH, 64),
                            @divTrunc(@as(i32, @intCast(row)) * SCREEN_HEIGHT, 32),
                            @divTrunc(@as(i32, @intCast(SCREEN_WIDTH)), 64),
                            @divTrunc(@as(i32, @intCast(SCREEN_HEIGHT)), 32),
                            .white,
                        );
                    }
                }
            }
        }

        // if (chip8.sound_timer > 0) {
        //     rl.drawCircle(100, 100, 50, .red);
        // }

        // rl.drawText("Congrats! You created your first window!", 190, 200, 20, .light_gray);

        // if (rui.button(.{ .x = 10, .y = 10, .width = 100, .height = 32 }, "Disassemble")) {}
        //----------------------------------------------------------------------------------

        rl.drawFPS(0, 0);

        if (rl.isKeyDown(.escape)) {
            break;
        }
    }
}
