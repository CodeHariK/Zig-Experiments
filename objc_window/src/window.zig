// Window creation and management for macOS using zig-objc

const std = @import("std");
const objc = @import("objc");
const types = @import("types/mod.zig");

// Re-export types for convenience
pub const CGFloat = types.CGFloat;
pub const CGPoint = types.CGPoint;
pub const CGSize = types.CGSize;
pub const CGRect = types.CGRect;
pub const StyleMask = types.StyleMask;
pub const Color = types.Color;
pub const Input = types.Input;
pub const MouseButton = types.MouseButton;
pub const Key = types.Key;

// Event types and callbacks
pub const MouseEvent = types.MouseEvent;
pub const KeyEvent = types.KeyEvent;
pub const ScrollEvent = types.ScrollEvent;
pub const MouseCallback = types.MouseCallback;
pub const KeyCallback = types.KeyCallback;
pub const ScrollCallback = types.ScrollCallback;
pub const MoveCallback = types.MoveCallback;
pub const EventHandlers = types.EventHandlers;

const NSEventType = types.NSEventType;
const Object = objc.Object;
const c = objc.c;

pub const WindowError = error{
    ClassNotFound,
    SuperclassNotFound,
    FailedToCreateClass,
};

// Global state
var should_terminate: bool = false;

/// Window close callback
fn windowShouldClose(_: c.id, _: c.SEL, _: c.id) callconv(.c) bool {
    should_terminate = true;
    return true;
}

/// Creates an Objective-C delegate class with a method
fn createDelegate(
    class_name: [:0]const u8,
    method_name: [:0]const u8,
    method_impl: anytype,
) WindowError!Object {
    const NSObject = objc.getClass("NSObject") orelse return error.SuperclassNotFound;
    var delegate_class = objc.allocateClassPair(NSObject, class_name) orelse
        return error.FailedToCreateClass;

    _ = delegate_class.addMethod(method_name, method_impl);

    objc.registerClassPair(delegate_class);

    return delegate_class.msgSend(Object, "alloc", .{}).msgSend(
        Object,
        "init",
        .{},
    );
}

pub const Window = struct {
    window: Object,
    app: Object,
    input: Input,
    handlers: EventHandlers,

    pub const Config = struct {
        title: [:0]const u8 = "Boom Window",
        width: u32 = 800,
        height: u32 = 600,
        x: u32 = 200,
        y: u32 = 200,
        style: u64 = StyleMask.default,
        background: Color = Color.dark,
    };

    /// Create a new window
    pub fn init(config: Config) WindowError!Window {
        const NSApplication = objc.getClass("NSApplication") orelse return error.ClassNotFound;
        const app = NSApplication.msgSend(Object, "sharedApplication", .{});
        app.msgSend(void, "setActivationPolicy:", .{@as(i64, 0)});

        const frame = CGRect{
            .origin = .{ .x = @floatFromInt(config.x), .y = @floatFromInt(config.y) },
            .size = .{ .width = @floatFromInt(config.width), .height = @floatFromInt(config.height) },
        };

        const NSWindow = objc.getClass("NSWindow") orelse return error.ClassNotFound;
        var window = NSWindow.msgSend(Object, "alloc", .{});
        window = window.msgSend(
            Object,
            "initWithContentRect:styleMask:backing:defer:",
            .{
                frame,
                config.style,
                @as(u64, 2),
                false,
            },
        );

        window.msgSend(void, "setAcceptsMouseMovedEvents:", .{true});

        const delegate = try createDelegate(
            "BoomWindowDelegate",
            "windowShouldClose:",
            windowShouldClose,
        );
        window.msgSend(void, "setDelegate:", .{delegate});

        const NSString = objc.getClass("NSString") orelse return error.ClassNotFound;
        const title = NSString.msgSend(
            Object,
            "stringWithUTF8String:",
            .{config.title},
        );
        window.msgSend(void, "setTitle:", .{title});

        const NSColor = objc.getClass("NSColor") orelse return error.ClassNotFound;
        const bg = NSColor.msgSend(
            Object,
            "colorWithRed:green:blue:alpha:",
            .{
                config.background.r,
                config.background.g,
                config.background.b,
                config.background.a,
            },
        );
        window.msgSend(void, "setBackgroundColor:", .{bg});

        return .{
            .window = window,
            .app = app,
            .input = .{},
            .handlers = .{},
        };
    }

    /// Show the window
    pub fn show(self: *Window) void {
        self.window.msgSend(void, "makeKeyAndOrderFront:", .{@as(?Object, null)});
        self.app.msgSend(void, "activate", .{});
    }

    // =========================================================================
    // Event handler setters (JS-style)
    // =========================================================================

    pub fn onMouseDown(self: *Window, cb: MouseCallback) *Window {
        self.handlers.onMouseDown = cb;
        return self;
    }

    pub fn onMouseUp(self: *Window, cb: MouseCallback) *Window {
        self.handlers.onMouseUp = cb;
        return self;
    }

    pub fn onMouseMove(self: *Window, cb: MoveCallback) *Window {
        self.handlers.onMouseMove = cb;
        return self;
    }

    pub fn onClick(self: *Window, cb: MouseCallback) *Window {
        self.handlers.onClick = cb;
        return self;
    }

    pub fn onKeyDown(self: *Window, cb: KeyCallback) *Window {
        self.handlers.onKeyDown = cb;
        return self;
    }

    pub fn onKeyUp(self: *Window, cb: KeyCallback) *Window {
        self.handlers.onKeyUp = cb;
        return self;
    }

    pub fn onScroll(self: *Window, cb: ScrollCallback) *Window {
        self.handlers.onScroll = cb;
        return self;
    }

    /// Process events and update input state (non-blocking)
    pub fn pollEvents(self: *Window) void {
        const NSDate = objc.getClass("NSDate") orelse return;
        const NSString = objc.getClass("NSString") orelse return;
        const run_loop_mode = NSString.msgSend(
            Object,
            "stringWithUTF8String:",
            .{"kCFRunLoopDefaultMode"},
        );

        const pool = objc.AutoreleasePool.init();
        defer pool.deinit();

        // Reset per-frame edge flags
        self.input.mouse_pressed = false;
        self.input.mouse_released = false;
        self.input.key_pressed = false;
        self.input.key_released = false;
        self.input.scroll_delta = 0;
        self.input.key_char = null;

        // Process all pending events
        while (true) {
            const distant_past = NSDate.msgSend(
                Object,
                "distantPast",
                .{},
            );
            const event_id = self.app.msgSend(
                c.id,
                "nextEventMatchingMask:untilDate:inMode:dequeue:",
                .{
                    @as(u64, 0xFFFFFFFFFFFFFFFF),
                    distant_past,
                    run_loop_mode,
                    true,
                },
            );

            if (event_id == null) break;

            const event: Object = .{ .value = event_id };
            self.processEvent(event);
            self.app.msgSend(void, "sendEvent:", .{event});
        }

        _ = self.app.msgSend(Object, "updateWindows", .{});
    }

    fn processEvent(self: *Window, event: Object) void {
        const event_type = event.msgSend(u64, "type", .{});

        const flags = event.msgSend(u64, "modifierFlags", .{});
        self.input.shift = (flags & (1 << 17)) != 0;
        self.input.ctrl = (flags & (1 << 18)) != 0;
        self.input.alt = (flags & (1 << 19)) != 0;
        self.input.cmd = (flags & (1 << 20)) != 0;

        switch (event_type) {
            NSEventType.leftMouseDown, NSEventType.rightMouseDown => {
                const button: MouseButton = if (event_type == NSEventType.leftMouseDown) .left else .right;
                self.input.mouse_button = button;
                self.input.mouse_down = true;
                self.input.mouse_pressed = true;
                self.updateMousePosition(event);

                const mouse_event = MouseEvent{
                    .x = self.input.mouse_x,
                    .y = self.input.mouse_y,
                    .button = button,
                };
                if (self.handlers.onMouseDown) |cb| cb(mouse_event);
                if (self.handlers.onClick) |cb| cb(mouse_event);
            },
            NSEventType.leftMouseUp, NSEventType.rightMouseUp => {
                self.updateMousePosition(event);
                self.input.mouse_down = false;
                self.input.mouse_released = true;

                const mouse_event = MouseEvent{
                    .x = self.input.mouse_x,
                    .y = self.input.mouse_y,
                    .button = self.input.mouse_button,
                };
                if (self.handlers.onMouseUp) |cb| cb(mouse_event);

                self.input.mouse_button = .none;
            },
            NSEventType.mouseMoved, NSEventType.leftMouseDragged, NSEventType.rightMouseDragged => {
                self.updateMousePosition(event);
                if (self.handlers.onMouseMove) |cb| cb(self.input.mouse_x, self.input.mouse_y);
            },
            NSEventType.scrollWheel => {
                self.input.scroll_delta = event.msgSend(CGFloat, "scrollingDeltaY", .{});
                if (self.handlers.onScroll) |cb| {
                    cb(.{
                        .x = self.input.mouse_x,
                        .y = self.input.mouse_y,
                        .delta = self.input.scroll_delta,
                    });
                }
            },
            NSEventType.keyDown => {
                self.input.key_code = event.msgSend(u16, "keyCode", .{});
                self.input.key_down = true;
                self.input.key_pressed = true;
                const chars = event.msgSend(Object, "characters", .{});
                if (chars.msgSend(u64, "length", .{}) > 0) {
                    self.input.key_char = @truncate(chars.msgSend(u16, "characterAtIndex:", .{@as(u64, 0)}));
                }

                if (self.handlers.onKeyDown) |cb| {
                    cb(.{
                        .code = self.input.key_code,
                        .char = self.input.key_char,
                        .shift = self.input.shift,
                        .ctrl = self.input.ctrl,
                        .alt = self.input.alt,
                        .cmd = self.input.cmd,
                    });
                }
            },
            NSEventType.keyUp => {
                self.input.key_code = event.msgSend(u16, "keyCode", .{});
                self.input.key_down = false;
                self.input.key_released = true;

                if (self.handlers.onKeyUp) |cb| {
                    cb(.{
                        .code = self.input.key_code,
                        .char = self.input.key_char,
                        .shift = self.input.shift,
                        .ctrl = self.input.ctrl,
                        .alt = self.input.alt,
                        .cmd = self.input.cmd,
                    });
                }
            },
            else => {},
        }
    }

    fn updateMousePosition(self: *Window, event: Object) void {
        const loc = event.msgSend(CGPoint, "locationInWindow", .{});
        self.input.mouse_x = loc.x;
        self.input.mouse_y = loc.y;
    }

    pub fn shouldClose(_: *Window) bool {
        return should_terminate;
    }

    pub fn getInput(self: *Window) Input {
        return self.input;
    }
};
