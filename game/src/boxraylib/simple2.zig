const rl = @import("raylib");
const rg = @import("raygui");
const box2d = @import("box2d");

const std = @import("std");

const assert = std.debug.assert;

const rand = std.crypto.random;

const Entity = struct {
    bodyId: box2d.BodyId,
    // texture: rl.Texture,

    shape: Shape,
};

const Shape = union(enum) {
    Circle: Circle,
    Rect: Rect,
};

const Circle = struct {
    radius: f32,

    fn init(circle: Circle, game: *Game, ix: f32, iy: f32, dynamic: bool, mass: f32, rotationalInertia: f32) void {
        var bodyDef = box2d.BodyDef.default();
        bodyDef.position = box2d.Vec2{ .x = ix, .y = iy };
        if (dynamic) {
            bodyDef.type = box2d.BodyType.dynamic;
        }
        // bodyDef.linearVelocity = box2d.Vec2{ .x = 3 * 128, .y = 4 * 128 };

        const bodyId = box2d.BodyId.create(game.worldId, bodyDef);
        bodyId.setAutomaticMass(false);
        bodyId.setMassData(box2d.MassData{
            .mass = mass,
            .rotationalInertia = rotationalInertia,
            .center = box2d.Vec2{ .x = 0, .y = 0 },
        });
        std.debug.print("\n\n{}\n\n{}\n\n", .{ bodyId.getMass(), bodyId.getMassData() });

        game.appendEntity(Entity{
            .bodyId = bodyId,
            .shape = Shape{ .Circle = circle },
        });

        var shapeDef = box2d.ShapeDef.default();
        // shapeDef.density = 0.1;
        shapeDef.restitution = 1;
        shapeDef.friction = 0;

        _ = box2d.ShapeId.createCircleShape(
            bodyId,
            shapeDef,
            box2d.Circle{
                .center = box2d.Vec2{ .x = 0, .y = 0 },
                .radius = circle.radius,
            },
        );
    }

    fn move(bodyId: box2d.BodyId) void {
        if (rl.isKeyDown(.key_right)) {
            bodyId.applyForceToCenter(box2d.Vec2{ .x = 1000, .y = 0 }, true);
        }
        if (rl.isKeyDown(.key_left)) {
            bodyId.applyForceToCenter(box2d.Vec2{ .x = -1000, .y = 0 }, true);
        }
    }
};

const Rect = struct {
    hw: f32,
    hh: f32,

    fn init(rect: Rect, game: *Game, ix: f32, iy: f32, dynamic: bool) void {
        var bodyDef = box2d.BodyDef.default();
        bodyDef.position = box2d.Vec2{ .x = ix, .y = iy };
        if (dynamic) {
            bodyDef.type = box2d.BodyType.dynamic;
        }

        const bodyId = box2d.BodyId.create(game.worldId, bodyDef);

        game.appendEntity(Entity{
            .bodyId = bodyId,
            .shape = Shape{ .Rect = rect },
        });

        var shapeDef = box2d.ShapeDef.default();
        shapeDef.density = 0.1;
        shapeDef.restitution = 1;
        shapeDef.friction = 0.1;

        _ = box2d.ShapeId.createPolygonShape(
            bodyId,
            shapeDef,
            box2d.Polygon.makeBox(rect.hw, rect.hh),
        );
    }
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

        var game = Game{
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

        const w1 = Rect{ .hw = 10, .hh = @as(f32, @floatFromInt(game.screen_height)) / 2 };
        w1.init(&game, -10, @as(f32, @floatFromInt(game.screen_height)) / 2, false);
        w1.init(&game, 10 + @as(f32, @floatFromInt(game.screen_width)), @as(f32, @floatFromInt(game.screen_height)) / 2, false);
        const w2 = Rect{ .hw = @as(f32, @floatFromInt(game.screen_width)) / 2, .hh = 10 };
        w2.init(&game, @as(f32, @floatFromInt(game.screen_width)) / 2, -10, false);
        w2.init(&game, @as(f32, @floatFromInt(game.screen_width)) / 2, 10 + @as(f32, @floatFromInt(game.screen_height)), false);

        // const rect = Rect{
        //     .hw = 40.0,
        //     .hh = 25.0,
        // };
        // for (0..7) |i| {
        //     rect.init(
        //         &game,
        //         @as(f32, @floatFromInt(i)) * 100 + 50,
        //         400,
        //         false,
        //     );
        //     rect.init(
        //         &game,
        //         @as(f32, @floatFromInt(i)) * 90 + 50,
        //         200,
        //         true,
        //     );
        // }

        var circle = Circle{
            .radius = 25.0,
        };
        for (0..1) |i| {
            circle.init(
                &game,
                @as(f32, @floatFromInt(i)) * 60 + 50,
                50,
                true,
                3,
                3,
            );
        }

        return game;
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
            std.debug.print("Pause", .{});
        }

        if (!game.paused) {
            const deltaTime = rl.getFrameTime();
            box2d.WorldId.step(game.worldId, deltaTime, 4);

            updateGame(&game);
        }

        game.ui();
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

    render(game.*);
}

fn render(game: Game) void {
    for (game.entities.items) |entity| {
        const p: box2d.Vec2 = box2d.BodyId.getWorldPoint(entity.bodyId, box2d.Vec2{
            .x = 0,
            .y = 0,
        });

        const rotation: box2d.Rot = box2d.BodyId.getRotation(entity.bodyId);
        const radians: f32 = rotation.toRadians() * std.math.deg_per_rad;

        if (entity.shape == Shape.Circle) {
            Circle.move(entity.bodyId);

            // rl.drawTextureEx(entity.texture, ps, radians * std.math.deg_per_rad, // Convert radians to degrees
            //     1.0, // Scale
            //     rl.Color.white // Color (assuming WHITE is defined in raylib)
            // );

            rl.drawRectangleLines(
                @as(i32, @intFromFloat(p.x - entity.shape.Circle.radius)),
                @as(i32, @intFromFloat(p.y - entity.shape.Circle.radius)),
                @as(i32, @intFromFloat(2 * entity.shape.Circle.radius)),
                @as(i32, @intFromFloat(2 * entity.shape.Circle.radius)),
                rl.Color.green,
            );

            rl.drawCircleLines(
                @as(i32, @intFromFloat(p.x)),
                @as(i32, @intFromFloat(p.y)),
                entity.shape.Circle.radius,
                rl.Color.green,
            );
        }
        if (entity.shape == Shape.Rect) {

            // rl.drawTextureEx(entity.texture, ps, radians * std.math.deg_per_rad, // Convert radians to degrees
            //     1.0, // Scale
            //     rl.Color.white // Color (assuming WHITE is defined in raylib)
            // );

            rl.drawRectanglePro(
                rl.Rectangle.init(p.x, p.y, 2 * entity.shape.Rect.hw, 2 * entity.shape.Rect.hh),
                rl.Vector2{ .x = entity.shape.Rect.hw, .y = entity.shape.Rect.hh },
                radians,
                rl.Color.init(200, 200, 200, 50),
            );

            rl.drawRectangleLines(
                @as(i32, @intFromFloat(p.x - entity.shape.Rect.hw)),
                @as(i32, @intFromFloat(p.y - entity.shape.Rect.hh)),
                @as(i32, @intFromFloat(2 * entity.shape.Rect.hw)),
                @as(i32, @intFromFloat(2 * entity.shape.Rect.hh)),
                rl.Color.blue,
            );
        }

        const aabb = box2d.BodyId.computeAABB(entity.bodyId);

        rl.drawRectangleLines(
            @as(i32, @intFromFloat(aabb.lowerBound.x)),
            @as(i32, @intFromFloat(aabb.lowerBound.y)),
            @as(i32, @intFromFloat(2 * aabb.extents().x)),
            @as(i32, @intFromFloat(2 * aabb.extents().y)),
            rl.Color.red,
        );
    }
}
