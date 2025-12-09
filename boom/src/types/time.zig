// Frame timing utilities

const std = @import("std");

pub const Time = struct {
    target_fps: u32,
    frame_time_ns: i64,
    frame_start: i128,
    last_frame: i128,
    delta_ns: i64,
    frame_count: u64,
    fps: f64,
    fps_update_time: i128,
    fps_frame_count: u64,

    pub fn init(target_fps: u32) Time {
        const now = std.time.nanoTimestamp();
        return .{
            .target_fps = target_fps,
            .frame_time_ns = if (target_fps > 0) @divFloor(std.time.ns_per_s, target_fps) else 0,
            .frame_start = now,
            .last_frame = now,
            .delta_ns = 0,
            .frame_count = 0,
            .fps = 0,
            .fps_update_time = now,
            .fps_frame_count = 0,
        };
    }

    /// Call at the start of each frame. Returns delta time in seconds.
    pub fn tick(self: *Time) f64 {
        const now = std.time.nanoTimestamp();
        self.delta_ns = @intCast(now - self.last_frame);
        self.last_frame = now;
        self.frame_start = now;
        self.frame_count += 1;
        self.fps_frame_count += 1;

        // Update FPS every second
        const fps_elapsed = now - self.fps_update_time;
        if (fps_elapsed >= std.time.ns_per_s) {
            self.fps = @as(f64, @floatFromInt(self.fps_frame_count)) /
                (@as(f64, @floatFromInt(fps_elapsed)) / std.time.ns_per_s);
            self.fps_update_time = now;
            self.fps_frame_count = 0;
        }

        return self.delta();
    }

    /// Sleep to maintain target FPS. Call at end of frame.
    pub fn sleep(self: *Time) void {
        if (self.target_fps == 0) return;

        const now = std.time.nanoTimestamp();
        const elapsed: i64 = @intCast(now - self.frame_start);
        const remaining = self.frame_time_ns - elapsed;

        if (remaining > 0) {
            std.Thread.sleep(@intCast(remaining));
        }
    }

    /// Delta time in seconds
    pub fn delta(self: *Time) f64 {
        return @as(f64, @floatFromInt(self.delta_ns)) / std.time.ns_per_s;
    }

    /// Delta time in milliseconds
    pub fn deltaMs(self: *Time) f64 {
        return @as(f64, @floatFromInt(self.delta_ns)) / std.time.ns_per_ms;
    }

    /// Current FPS
    pub fn getFps(self: *Time) f64 {
        return self.fps;
    }

    /// Total frames since start
    pub fn getFrameCount(self: *Time) u64 {
        return self.frame_count;
    }
};
