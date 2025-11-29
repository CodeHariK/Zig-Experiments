const basicwindow = @import("examples/core/basic_window.zig");
const windowflags = @import("examples/core/window_flags.zig");

const logoraylib = @import("examples/shapes/logo_raylib.zig");

const camera2d = @import("examples/core/2d_camera_mouse_zoom.zig");

const texture_outline = @import("examples/shaders/texture_outline.zig");

const sprite_anim = @import("examples/textures/sprite_anim.zig");
const textures_background_scrolling = @import("examples/textures/textures_background_scrolling.zig");

const boxraylibsimple = @import("boxraylib/simple.zig");
const boxraylibsimple2 = @import("boxraylib/simple2.zig");

pub fn main() anyerror!void {
    // basicwindow.main();
    // logoraylib.main();
    // camera2d.main();
    // texture_outline.main();
    // windowflags.main();
    // sprite_anim.main();
    // textures_background_scrolling.main();

    // boxraylibsimple.run();
    boxraylibsimple2.run();
}
