const std = @import("std");
const rl = @import("raylib");
const math = @import("utils/math.zig");
const GameSimulation = @import("GameSimulation.zig");

pub fn main() anyerror!void {

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Our game state
    var gameState = GameSimulation.GameState{};

    gameState.Init();

    // Initialize our game object
    gameState.physicsComponents[0].position = .{ .x = 400, .y = 200 };

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key

        if (rl.isWindowFocused()) {
            if (rl.isGamepadButtonDown(0, rl.GamepadButton.gamepad_button_left_face_up) or rl.isKeyDown(rl.KeyboardKey.key_up)) {
                gameState.inputComponents[0].inputCommand.Up = true;
            }

            if (rl.isGamepadButtonDown(0, rl.GamepadButton.gamepad_button_left_face_down) or rl.isKeyDown(rl.KeyboardKey.key_down)) {
                gameState.inputComponents[0].inputCommand.Down = true;
            }

            if (rl.isGamepadButtonDown(0, rl.GamepadButton.gamepad_button_left_face_left) or rl.isKeyDown(rl.KeyboardKey.key_left)) {
                gameState.inputComponents[0].inputCommand.Left = true;
            }

            if (rl.isGamepadButtonDown(0, rl.GamepadButton.gamepad_button_left_face_right) or rl.isKeyDown(rl.KeyboardKey.key_right)) {
                gameState.inputComponents[0].inputCommand.Right = true;
            }
        }

        // Game Simulation
        {
            GameSimulation.UpdateGame(&gameState);
        }

        // Draw
        rl.beginDrawing();

        rl.clearBackground(rl.Color.white);

        // Reflect the position of our game object on screen.
        rl.drawCircle(
            gameState.physicsComponents[0].position.x,
            gameState.physicsComponents[0].position.y,
            50,
            rl.Color.maroon,
        );

        rl.endDrawing();
        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.closeWindow(); // Close window and OpenGL context
    //--------------------------------------------------------------------------------------
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
