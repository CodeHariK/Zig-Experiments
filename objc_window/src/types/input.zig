// Input state types

pub const MouseButton = enum {
    none,
    left,
    right,
    middle,
};

pub const Input = struct {
    // Mouse position
    mouse_x: f64 = 0,
    mouse_y: f64 = 0,

    // Mouse button state
    mouse_button: MouseButton = .none,
    mouse_down: bool = false, // true while held
    mouse_pressed: bool = false, // true only on first frame of click
    mouse_released: bool = false, // true only on frame of release
    scroll_delta: f64 = 0,

    // Keyboard state
    key_code: u16 = 0,
    key_down: bool = false, // true while held
    key_pressed: bool = false, // true only on first frame
    key_released: bool = false, // true only on frame of release
    key_char: ?u8 = null,

    // Modifiers
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    cmd: bool = false,
};
