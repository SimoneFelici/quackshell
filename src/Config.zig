const z2d = @import("z2d");

const Config = @This();

height: u32 = 30,
background: z2d.pixel.ARGB = .{ .a = 255, .r = 0, .g = 0, .b = 255 },
position: Position = .top,
gaps: i32 = 10,
rounding: u32 = 3,
font: []const u8 = "",

pub const Position = enum { top, bottom };
