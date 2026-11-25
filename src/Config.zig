const z2d = @import("z2d");

const Config = @This();

height: u32 = 30,
background: z2d.pixel.ARGB = .{ .a = 255, .r = 0, .g = 0, .b = 255 },
position: Position = .top,
gaps: i32 = 10,
rounding: u32 = 3,

font: []const u8 = "/usr/share/fonts/TTF/JetBrainsMonoNLNerdFont-Regular.ttf",
// font: []const u8 = "/usr/share/fonts/noto/NotoColorEmoji.ttf",
font_size: f64 = 14,
foreground: z2d.pixel.ARGB = .{ .a = 255, .r = 255, .g = 255, .b = 255 },
padding: f64 = 10,

left: []const Module = &.{ .text, .text, .text },
center: []const Module = &.{ .text, .text, .text },
right: []const Module = &.{ .text, .text, .text },

text: Text = .{},

pub const Position = enum { top, bottom };
pub const Module = enum { text };

pub const Text = struct {
    content: []const u8 = "󰈸 quackshell 󰈸",
};
