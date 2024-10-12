const rl = @import("raylib");
const rg = @import("raygui");
const box2d = @import("box2d");

const std = @import("std");
const assert = std.debug.assert;

const Game = struct {
    screen_width: i32,
    screen_height: i32,

    camera: rl.Camera2D,
    zoomMode: i32,
    showMessageBox: bool,

    paused: bool,

    pub fn init() Game {
        return Game{
            .screen_width = 800,
            .screen_height = 450,
            .camera = rl.Camera2D{
                .target = .{ .x = 0, .y = 0 },
                .offset = .{ .x = 0, .y = 0 },
                .zoom = 1.0,
                .rotation = 0,
            },
            .zoomMode = 0,
            .showMessageBox = false,
            .paused = false,
        };
    }
};

var ball_position = rl.Vector2.init(100, 100);
var ball_speed = rl.Vector2.init(5, 4);
const ball_radius: f32 = 20;

pub export fn run() void {
    var game = Game.init();

    rl.initWindow(
        game.screen_width,
        game.screen_height,
        "Space Mission",
    );
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setWindowState(rl.ConfigFlags{
        .window_resizable = true,
        .window_transparent = true,
    });

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        if (rl.isWindowState(rl.ConfigFlags{ .window_transparent = true })) {
            rl.clearBackground(rl.Color.blank);
        } else rl.clearBackground(rl.Color.ray_white);

        if (rl.isKeyPressed(.key_r)) {
            game = Game.init();
            std.debug.print("Hello", .{});
        }

        if (!game.paused) {
            updateGame(&game);
        }

        ui(&game);
    }
}

fn updateGame(game: *Game) void {
    game.camera.begin();
    defer game.camera.end();

    {
        if (rl.isMouseButtonDown(.mouse_button_right)) {
            var delta = rl.getMouseDelta();
            delta = rl.math.vector2Scale(delta, -1.0 / game.camera.zoom);
            game.camera.target = rl.math.vector2Add(game.camera.target, delta);
        }

        const wheel = rl.getMouseWheelMove();
        if (wheel != 0) {
            // Get the world point that is under the mouse
            const mouseWorldPos = rl.getScreenToWorld2D(rl.getMousePosition(), game.camera);

            // Set the offset to where the mouse is
            game.camera.offset = rl.getMousePosition();

            // Set the target to match, so that the camera maps the world space point
            // under the cursor to the screen space point under the cursor at any zoom
            game.camera.target = mouseWorldPos;

            // Zoom increment
            var scaleFactor = 1.0 + (0.25 * @abs(wheel));
            if (wheel < 0) {
                scaleFactor = 1.0 / scaleFactor;
            }
            game.camera.zoom = rl.math.clamp(game.camera.zoom * scaleFactor, 0.125, 64.0);
        }
    }

    rl.gl.rlPushMatrix();
    rl.gl.rlTranslatef(0, 25 * 50, 0);
    rl.gl.rlRotatef(90, 1, 0, 0);
    rl.drawGrid(100, 50);
    rl.gl.rlPopMatrix();

    rl.drawFPS(10, 10);

    rl.drawRectangleLinesEx(
        rl.Rectangle.init(0, 0, @floatFromInt(rl.getScreenWidth()), @floatFromInt(rl.getScreenHeight())),
        4,
        rl.Color.red,
    );

    const mousePos = rl.getMousePosition();
    rl.drawCircleV(mousePos, 10, rl.Color.dark_blue);
    rl.drawText(
        rl.textFormat("MousePos: %d,%d", .{
            @as(i32, @intFromFloat(mousePos.x)),
            @as(i32, @intFromFloat(mousePos.y)),
        }),
        10,
        30,
        16,
        rl.Color.lime,
    );

    play(game.*);
}

fn ui(game: *Game) void {
    if (rg.guiButton(rl.Rectangle.init(24, 24, 120, 30), "#191#Show Message") > 0) {
        game.showMessageBox = true;
        game.paused = true;
    }

    if (game.showMessageBox) {
        const res = rg.guiMessageBox(rl.Rectangle.init(85, 70, 250, 100), "#191#Message Box", "Hi! This is a message!", "Nice;Cool");
        if (res >= 0) {
            std.debug.print("{}!\n", .{res});
            game.showMessageBox = false;
            game.paused = false;
        }
    }
}
fn play(game: Game) void {
    ball();

    rl.drawCircle(@divTrunc(game.screen_width, @as(i32, 2)), @divTrunc(game.screen_height, @as(i32, 2)), 50, rl.Color.maroon);
}

fn ball() void {
    ball_position = ball_position.add(ball_speed);

    if (ball_position.x >= (@as(f32, @floatFromInt(rl.getScreenWidth())) - ball_radius) or ball_position.x <= ball_radius) {
        ball_speed.x *= -1;
    }
    if (ball_position.y >= (@as(f32, @floatFromInt(rl.getScreenHeight())) - ball_radius) or ball_position.y <= ball_radius) {
        ball_speed.y *= -1;
    }

    rl.drawCircleV(ball_position, ball_radius, rl.Color.maroon);
}
