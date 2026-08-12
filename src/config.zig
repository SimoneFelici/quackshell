const std = @import("std");

const Config = @This();

scale: f32 = 1.0,
bar_height: u32 = 32,

pub fn load(gpa: std.mem.Allocator) !Config {
    _ = gpa;
    return .{};
}
