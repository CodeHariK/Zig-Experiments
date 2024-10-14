const rl = @import("raylib");
const box2d = @import("box2d");

const std = @import("std");
const assert = std.debug.assert;

const GROUND_COUNT = 14;
const BOX_COUNT = 10;

const Entity = struct {
    bodyId: box2d.BodyId,
    extent: box2d.Vec2,
    texture: rl.Texture,
};

fn DrawEntity(entity: *const Entity) void {
    // The boxes were created centered on the bodies, but raylib draws textures starting at the top left corner.
    // b2Body_GetWorldPoint gets the top left corner of the box accounting for rotation.
    const p: box2d.Vec2 = box2d.BodyId.getWorldPoint(entity.bodyId, box2d.Vec2{
        .x = -entity.extent.x,
        .y = -entity.extent.y,
    });

    const rotation: box2d.Rot = box2d.BodyId.getRotation(entity.bodyId);
    const radians: f32 = rotation.toRadians();

    const ps = rl.Vector2{ .x = p.x, .y = p.y };

    // Use raylib's DrawTextureEx to draw the entity's texture
    rl.drawTextureEx(entity.texture, ps, radians * std.math.deg_per_rad, // Convert radians to degrees
        1.0, // Scale
        rl.Color.white // Color (assuming WHITE is defined in raylib)
    );
    rl.drawRectangle(@as(i32, @intFromFloat(p.x / 2)), @as(i32, @intFromFloat(p.y / 2)), 50, 50, rl.Color.blue);

    // rl.drawCircle(@as(i32, @intFromFloat(p.x / 2)), @as(i32, @intFromFloat(p.y / 2)), 50, rl.Color.maroon);

    const aabb = box2d.BodyId.computeAABB(entity.bodyId);

    std.debug.print("Play : {}\nLower : {}\nCenter : {}\nExtents : {}\n\n", .{ p, aabb.lowerBound, aabb.center(), aabb.extents() });

    rl.drawRectangleLines(@as(i32, @intFromFloat(aabb.lowerBound.x)), @as(i32, @intFromFloat(aabb.lowerBound.y)), @as(i32, @intFromFloat(2 * aabb.extents().x)), @as(i32, @intFromFloat(2 * aabb.extents().y)), rl.Color.red);
}

pub export fn run() void {
    const width: i32 = 960;
    const height: i32 = 540;

    // Initialize the window
    rl.initWindow(width, height, "box2d-raylib");
    rl.setTargetFPS(60);

    // 128 pixels per meter is appropriate for this scene. The boxes are 128 pixels wide.
    const lengthUnitsPerMeter: f32 = 128.0;
    box2d.setLengthUnitsPerMeter(lengthUnitsPerMeter);

    // Create the world definition
    var worldDef = box2d.WorldDef.default();
    // Realistic gravity is achieved by multiplying gravity by the length unit.
    worldDef.gravity.y = 9.8 * lengthUnitsPerMeter;

    // Create the Box2D world
    const worldId = box2d.WorldId.create(worldDef);

    // Load textures
    const groundTexture = rl.loadTexture("ground.png");
    const boxTexture = rl.loadTexture("box.png");

    // Set extents for ground and box
    const groundExtent = box2d.Vec2{
        .x = 0.5 * @as(f32, @floatFromInt(groundTexture.width)),
        .y = 0.5 * @as(f32, @floatFromInt(groundTexture.height)),
    };

    const boxExtent = box2d.Vec2{
        .x = 0.5 * @as(f32, @floatFromInt(boxTexture.width)),
        .y = 0.5 * @as(f32, @floatFromInt(boxTexture.height)),
    };

    // Create polygons
    const groundPolygon = box2d.Polygon.makeBox(groundExtent.x, groundExtent.y);
    const boxPolygon = box2d.Polygon.makeBox(boxExtent.x, boxExtent.y);
    const circlePolygon = box2d.Circle{
        .center = boxExtent, // Assuming boxExtent represents the center of the circle
        .radius = 50.0, // Replace with the appropriate radius value
    };

    // Create array of ground entities
    var groundEntities: [GROUND_COUNT]Entity = undefined;

    for (0..GROUND_COUNT) |i| {
        var entity = groundEntities[i];

        var bodyDef = box2d.BodyDef.default();
        bodyDef.position = box2d.Vec2{
            .x = (2.0 * @as(f32, @floatFromInt(i)) + 2.0) * groundExtent.x,
            .y = height - groundExtent.y - 100.0,
        };

        // Uncomment for rotation if needed
        // bodyDef.rotation = box2d.Rot.fromRadians(0.25 * std.math.pi * @as(f32, @floatFromInt(i)));

        entity.bodyId = box2d.BodyId.create(worldId, bodyDef);
        entity.extent = groundExtent;
        entity.texture = groundTexture;

        const shapeDef = box2d.ShapeDef.default();
        _ = box2d.ShapeId.createPolygonShape(entity.bodyId, shapeDef, groundPolygon);

        groundEntities[i] = entity; // Store the entity back in the array
    }

    // Create box entities array
    var boxEntities: [BOX_COUNT]Entity = undefined;
    var boxIndex: usize = 0;

    for (0..4) |i| {
        const y: f32 = height - groundExtent.y - 100.0 - (2.5 * @as(f32, @floatFromInt(i)) + 2.0) * boxExtent.y - 20.0;

        for (i..4) |j| {
            const x: f32 = 0.5 * @as(f32, @floatFromInt(width)) + (3.0 * @as(f32, @floatFromInt(j)) - @as(f32, @floatFromInt(i)) - 3.0) * boxExtent.x;

            // Ensure boxIndex is within bounds
            assert(boxIndex < BOX_COUNT);

            var entity = &boxEntities[boxIndex]; // Pointer to the current entity
            var bodyDef = box2d.BodyDef.default(); // Create body definition
            bodyDef.type = box2d.BodyType.dynamic; // Set the body type
            bodyDef.position.x = x; // Set position
            bodyDef.position.y = y; // Set position

            // Create body and assign to the entity
            entity.bodyId = box2d.BodyId.create(worldId, bodyDef);
            entity.texture = boxTexture; // Ensure boxTexture is defined
            entity.extent = boxExtent; // Assign extent to the entity

            const shapeDef = box2d.ShapeDef.default(); // Create shape definition
            _ = box2d.ShapeId.createPolygonShape(entity.bodyId, shapeDef, boxPolygon); // Create shape for the entity
            _ = box2d.ShapeId.createCircleShape(entity.bodyId, shapeDef, circlePolygon); // Create shape for the entity

            boxIndex += 1; // Increment the box index
        }
    }

    // Game loop
    var pause: bool = false;

    while (!rl.windowShouldClose()) {
        if (rl.isKeyPressed(rl.KeyboardKey.key_p)) {
            pause = !pause;
        }

        if (!pause) {
            const deltaTime = rl.getFrameTime();
            box2d.WorldId.step(worldId, deltaTime, 4);
        }

        rl.beginDrawing();
        rl.clearBackground(rl.Color.dark_gray);

        for (0..GROUND_COUNT) |i| {
            DrawEntity(&groundEntities[i]);
        }

        for (0..BOX_COUNT) |i| {
            DrawEntity(&boxEntities[i]);
        }

        rl.endDrawing();
    }

    rl.unloadTexture(groundTexture);
    rl.unloadTexture(boxTexture);
    rl.closeWindow();
}
