const z2d = @import("z2d");

const Config = @This();

height: u32 = 30,
background: z2d.pixel.ARGB = .{ .a = 255, .r = 0, .g = 0, .b = 255 },
position: Position = .top,
gaps: i32 = 10,
rounding: u32 = 3,

font: []const u8 = "/usr/share/fonts/TTF/JetBrainsMonoNLNerdFont-Regular.ttf",
font_size: f64 = 16,
foreground: z2d.pixel.ARGB = .{ .a = 255, .r = 255, .g = 255, .b = 255 },
padding: f64 = 10,

left: []const Module = &.{.window_title},
center: []const Module = &.{.time},
right: []const Module = &.{},

time: Time = .{},
window_title: WindowTitle = .{},

pub const Position = enum { top, bottom };
pub const Module = enum { time, window_title };

pub const Time = struct {
    format: []const u8 = "%d %b %Y %H:%M:%S",
};

pub const WindowTitle = struct {
    max_length: usize = 60,
};
