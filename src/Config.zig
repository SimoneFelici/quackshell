const std = @import("std");

const Config = @This();

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 90,
};

scale: f32 = 1.0,
bar_height: u32 = 32,
bg: Color = .{ .r = 0, .g = 0, .b = 255 },

pub fn load(gpa: std.mem.Allocator) !Config {
    _ = gpa;
    return .{};
}
