// Types module - re-exports all type definitions

// Geometry
pub const geometry = @import("geometry.zig");
pub const CGFloat = geometry.CGFloat;
pub const CGPoint = geometry.CGPoint;
pub const CGSize = geometry.CGSize;
pub const CGRect = geometry.CGRect;

// Color
pub const color = @import("color.zig");
pub const Color = color.Color;

// Style
pub const style = @import("style.zig");
pub const StyleMask = style.StyleMask;

// Input
pub const input = @import("input.zig");
pub const MouseButton = input.MouseButton;
pub const Input = input.Input;

// Key codes
pub const key = @import("key.zig");
pub const Key = key.Key;

// Events
pub const events = @import("events.zig");
pub const MouseEvent = events.MouseEvent;
pub const KeyEvent = events.KeyEvent;
pub const ScrollEvent = events.ScrollEvent;
pub const MouseCallback = events.MouseCallback;
pub const KeyCallback = events.KeyCallback;
pub const ScrollCallback = events.ScrollCallback;
pub const MoveCallback = events.MoveCallback;
pub const EventHandlers = events.EventHandlers;
pub const NSEventType = events.NSEventType;

// Time
pub const time = @import("time.zig");
pub const Time = time.Time;
