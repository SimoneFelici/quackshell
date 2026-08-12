const std = @import("std");
const Config = @import("config.zig");

const Context = @This();

gpa: std.mem.Allocator,
io: std.Io,
config: Config,

pub fn init(process_init: std.process.Init) !Context {
    return .{
        .gpa = process_init.gpa,
        .io = process_init.io,
        .config = try Config.load(process_init.gpa),
    };
}
