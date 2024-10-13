const rl = @import("raylib");
const rg = @import("raygui");
const box2d = @import("box2d");

const std = @import("std");

const assert = std.debug.assert;

const rand = std.crypto.random;

const Circle = struct {
    radius: f32,
};
const Rect = struct {
    x: f32,
    y: f32,
};

const Shape = union(enum) {
    Circle: Circle,
    Rect: Rect,
};

const Entity = struct {
    bodyId: box2d.BodyId,
    // texture: rl.Texture,

    shape: Shape,
};

const Game = struct {
    screen_width: i32,
    screen_height: i32,

    camera: rl.Camera2D,
    zoomMode: i32,
    showMessageBox: bool,

    paused: bool,

    worldId: box2d.WorldId,

    entities: std.ArrayList(Entity),

    fn init(allocator: std.mem.Allocator) Game {
        // 128 pixels per meter is appropriate for this scene. The boxes are 128 pixels wide.
        const lengthUnitsPerMeter: f32 = 128.0;
        box2d.setLengthUnitsPerMeter(lengthUnitsPerMeter);

        // Create the world definition
        var worldDef = box2d.WorldDef.default();
        // Realistic gravity is achieved by multiplying gravity by the length unit.
        worldDef.gravity.y = 5 * lengthUnitsPerMeter;

        // Create the Box2D world
        const worldId = box2d.WorldId.create(worldDef);

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

            .worldId = worldId,
            .entities = std.ArrayList(Entity).init(allocator),
        };
    }

    fn clear(self: *Game, allocator: std.mem.Allocator) Game {
        self.entities.deinit();
        // box2d.WorldId.destroy(self.worldId);
        return init(allocator);
    }

    fn appendEntity(self: *Game, entity: Entity) void {
        // Append the entity, handling OutOfMemory error
        self.entities.append(entity) catch |err| {
            if (err == error.OutOfMemory) {
                std.debug.print("Out of memory error!\n", .{});
            }
            std.debug.print("--> {}", .{err});
        };
        std.debug.print("entity bodyId: {}\n", .{entity.bodyId});
    }
};

var ball_position = rl.Vector2.init(100, 100);
var ball_speed = rl.Vector2.init(5, 4);
const ball_radius: f32 = 20;

pub export fn run() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var game = Game.init(gpa.allocator());
    defer game.entities.deinit();

    std.debug.print("{}", .{game});

    rl.initWindow(
        game.screen_width,
        game.screen_height,
        "Space Mission",
    );
    defer rl.closeWindow(); // Close window and OpenGL context

    defer box2d.WorldId.destroy(game.worldId);

    rl.setWindowState(rl.ConfigFlags{
        .window_resizable = true,
        .window_transparent = true,
    });

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    groundInit(&game);
    // ballInit(&game);
    boxInit(&game);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        if (rl.isWindowState(rl.ConfigFlags{ .window_transparent = true })) {
            rl.clearBackground(rl.Color.blank);
        } else rl.clearBackground(rl.Color.ray_white);

        if (rl.isKeyPressed(.key_r)) {
            box2d.WorldId.destroy(game.worldId);
            game = game.clear(gpa.allocator());
            std.debug.print("Init", .{});
        }
        if (rl.isKeyPressed(.key_p)) {
            game.paused = !game.paused;
            std.debug.print("pause", .{});
        }

        if (!game.paused) {
            const deltaTime = rl.getFrameTime();
            box2d.WorldId.step(game.worldId, deltaTime, 4);

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
    if (rg.guiButton(rl.Rectangle.init(24, 74, 120, 30), "#191#Show Message") > 0) {
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

    rl.drawCircle(@divTrunc(game.screen_width, @as(i32, 3)), @divTrunc(game.screen_height, @as(i32, 3)), 50, rl.Color.maroon);

    for (game.entities.items) |entity| {
        const p: box2d.Vec2 = box2d.BodyId.getWorldPoint(entity.bodyId, box2d.Vec2{
            .x = 0,
            .y = 0,
        });

        std.debug.print("CirclePlay : {} {} \n", .{ p.x, p.y });

        if (entity.shape == Shape.Circle) {

            // const rotation: box2d.Rot = box2d.BodyId.getRotation(bodyId);
            // const radians: f32 = rotation.toRadians();

            // const ps = rl.Vector2{ .x = p.x, .y = p.y };

            // rl.drawTextureEx(entity.texture, ps, radians * std.math.deg_per_rad, // Convert radians to degrees
            //     1.0, // Scale
            //     rl.Color.white // Color (assuming WHITE is defined in raylib)
            // );

            rl.drawRectangleLines(@as(i32, @intFromFloat(p.x)), @as(i32, @intFromFloat(p.y)), @as(i32, @intFromFloat(2 * entity.shape.Circle.radius)), @as(i32, @intFromFloat(2 * entity.shape.Circle.radius)), rl.Color.green);

            rl.drawCircleLines(@as(i32, @intFromFloat(p.x + entity.shape.Circle.radius)), @as(i32, @intFromFloat(p.y + entity.shape.Circle.radius)), entity.shape.Circle.radius, rl.Color.green);
        }
        if (entity.shape == Shape.Rect) {

            // const rotation: box2d.Rot = box2d.BodyId.getRotation(bodyId);
            // const radians: f32 = rotation.toRadians();

            // const ps = rl.Vector2{ .x = p.x, .y = p.y };

            // rl.drawTextureEx(entity.texture, ps, radians * std.math.deg_per_rad, // Convert radians to degrees
            //     1.0, // Scale
            //     rl.Color.white // Color (assuming WHITE is defined in raylib)
            // );

            rl.drawRectangleLines(@as(i32, @intFromFloat(p.x)), @as(i32, @intFromFloat(p.y)), @as(i32, @intFromFloat(entity.shape.Rect.x)), @as(i32, @intFromFloat(entity.shape.Rect.y)), rl.Color.blue);
        }

        const aabb = box2d.BodyId.computeAABB(entity.bodyId);

        rl.drawRectangleLines(@as(i32, @intFromFloat(aabb.center().x)), @as(i32, @intFromFloat(aabb.center().y)), @as(i32, @intFromFloat(aabb.extents().x)), @as(i32, @intFromFloat(aabb.extents().y)), rl.Color.red);
    }
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

fn groundInit(game: *Game) void {
    const rect = Rect{
        .x = 50.0,
        .y = 50.0,
    };

    const groundPolygon = box2d.Polygon.makeBox(rect.x, rect.y);

    for (0..1) |i| {
        var bodyDef = box2d.BodyDef.default();
        bodyDef.position = box2d.Vec2{
            .x = 50 + 200.0 * @as(f32, @floatFromInt(i)),
            .y = 400,
            // .y = @as(f32, @floatFromInt(game.screen_height)) - rect.y - 100,
        };

        std.debug.print("Ground : {}", .{bodyDef.position});

        const bodyId = box2d.BodyId.create(game.worldId, bodyDef);
        // bodyDef.type = box2d.BodyType.dynamic;

        game.appendEntity(Entity{
            .bodyId = bodyId,
            .shape = Shape{ .Rect = rect },
        });

        var shapeDef = box2d.ShapeDef.default();
        shapeDef.density = 0.1;
        shapeDef.restitution = 1;
        shapeDef.friction = 0.1;
        _ = box2d.ShapeId.createPolygonShape(bodyId, shapeDef, groundPolygon);
    }
}

fn boxInit(game: *Game) void {
    const rect = Rect{
        .x = 50.0,
        .y = 50.0,
    };

    const groundPolygon = box2d.Polygon.makeBox(rect.x, rect.y);

    for (0..1) |i| {
        var bodyDef = box2d.BodyDef.default();
        bodyDef.position = box2d.Vec2{
            .x = 50 + 200.0 * @as(f32, @floatFromInt(i)),
            .y = 100,
            // .y = @as(f32, @floatFromInt(game.screen_height)) - rect.y - 100,
        };

        std.debug.print("Ground : {}", .{bodyDef.position});

        const bodyId = box2d.BodyId.create(game.worldId, bodyDef);
        bodyDef.type = box2d.BodyType.dynamic;

        game.appendEntity(Entity{
            .bodyId = bodyId,
            .shape = Shape{ .Rect = rect },
        });

        var shapeDef = box2d.ShapeDef.default();
        shapeDef.density = 0.1;
        shapeDef.restitution = 1;
        shapeDef.friction = 0.1;
        _ = box2d.ShapeId.createPolygonShape(bodyId, shapeDef, groundPolygon);
    }
}

fn ballInit(game: *Game) void {
    const circle = Circle{
        .radius = 25.0,
    };

    for (0..1) |i| {
        const circlePolygon = box2d.Circle{
            .center = box2d.Vec2{
                // .x = 2.0 * @as(f32, @floatFromInt(i)) * circle.radius + circle.radius,
                // .y = @as(f32, @floatFromInt(game.screen_height)) - 400,
                // .x = 50 + 200.0 * @as(f32, @floatFromInt(i)),
                // .y = 100.0,
                .x = 0,
                .y = 0,
            },
            .radius = circle.radius,
        };

        var bodyDef = box2d.BodyDef.default();
        // bodyDef.position = circlePolygon.center;
        bodyDef.position = box2d.Vec2{
            .x = 50 + 200.0 * @as(f32, @floatFromInt(i)),
            .y = 100,
            // .y = @as(f32, @floatFromInt(game.screen_height)) - rect.y - 100,
        };
        bodyDef.type = box2d.BodyType.dynamic;

        std.debug.print("Circle : {}", .{bodyDef.position});

        const bodyId = box2d.BodyId.create(game.worldId, bodyDef);

        game.appendEntity(Entity{
            .bodyId = bodyId,
            .shape = Shape{ .Circle = circle },
        });

        var shapeDef = box2d.ShapeDef.default();
        shapeDef.density = 0.1;
        shapeDef.restitution = 1;
        shapeDef.friction = 0.1;

        _ = box2d.ShapeId.createCircleShape(bodyId, shapeDef, circlePolygon);
    }
}
