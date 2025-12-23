// Event types and callbacks

const input = @import("input.zig");
const MouseButton = input.MouseButton;

// =============================================================================
// Event Structs
// =============================================================================

pub const MouseEvent = struct {
    x: f64,
    y: f64,
    button: MouseButton,
};

pub const KeyEvent = struct {
    code: u16,
    char: ?u8,
    shift: bool,
    ctrl: bool,
    alt: bool,
    cmd: bool,
};

pub const ScrollEvent = struct {
    x: f64,
    y: f64,
    delta: f64,
};

// =============================================================================
// Callback Types
// =============================================================================

pub const MouseCallback = *const fn (MouseEvent) void;
pub const KeyCallback = *const fn (KeyEvent) void;
pub const ScrollCallback = *const fn (ScrollEvent) void;
pub const MoveCallback = *const fn (f64, f64) void;

// =============================================================================
// Event Handlers (JS-style)
// =============================================================================

pub const EventHandlers = struct {
    onMouseDown: ?MouseCallback = null,
    onMouseUp: ?MouseCallback = null,
    onMouseMove: ?MoveCallback = null,
    onClick: ?MouseCallback = null,
    onKeyDown: ?KeyCallback = null,
    onKeyUp: ?KeyCallback = null,
    onScroll: ?ScrollCallback = null,
};

// =============================================================================
// NSEvent Types (internal, macOS-specific)
// =============================================================================

pub const NSEventType = struct {
    pub const leftMouseDown: u64 = 1;
    pub const leftMouseUp: u64 = 2;
    pub const rightMouseDown: u64 = 3;
    pub const rightMouseUp: u64 = 4;
    pub const mouseMoved: u64 = 5;
    pub const leftMouseDragged: u64 = 6;
    pub const rightMouseDragged: u64 = 7;
    pub const keyDown: u64 = 10;
    pub const keyUp: u64 = 11;
    pub const scrollWheel: u64 = 22;
};
