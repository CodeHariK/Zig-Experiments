const std = @import("std");
const rl = @import("raylib");
const math = @import("utils/math.zig");
const GameSimulation = @import("GameSimulation.zig");

const GameObject = struct {
    x: i32, // variable with the type float 32
    y: i32,
};

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

    // Initialize our game object
    gameState.physicsComponents[0].position = .{ .x = 400, .y = 200 };

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key

        var PressingRight: bool = false;
        var PressingLeft: bool = false;

        if (rl.isWindowFocused()) {
            if (rl.isGamepadButtonDown(0, rl.GamepadButton.gamepad_button_left_face_up) or rl.isKeyDown(rl.KeyboardKey.key_up)) {
                // PolledInput |= static_cast<unsigned int>(InputCommand::Up);
            }

            if (rl.isGamepadButtonDown(0, rl.GamepadButton.gamepad_button_left_face_down) or rl.isKeyDown(rl.KeyboardKey.key_down)) {
                // PolledInput |= static_cast<unsigned int>(InputCommand::Down);
            }

            if (rl.isGamepadButtonDown(0, rl.GamepadButton.gamepad_button_left_face_left) or rl.isKeyDown(rl.KeyboardKey.key_left)) {
                // PolledInput |= static_cast<unsigned int>(InputCommand::Left);
                PressingLeft = true;
            }

            if (rl.isGamepadButtonDown(0, rl.GamepadButton.gamepad_button_left_face_right) or rl.isKeyDown(rl.KeyboardKey.key_right)) {
                // PolledInput |= static_cast<unsigned int>(InputCommand::Right);
                PressingRight = true;
            }
        }

        // Game Simulation
        {

            //  Update position of object base on player input
            {
                const entity = &gameState.physicsComponents[0];
                if (PressingLeft) {
                    entity.velocity.x = -1;
                } else if (PressingRight) {
                    entity.velocity.x = 1;
                } else {
                    entity.velocity.x = 0;
                }
            }

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
