const std = @import("std");

const Config = @import("Config.zig");

const Context = @This();

io: std.Io,
gpa: std.mem.Allocator,
arena: std.mem.Allocator,
env: *const std.process.Environ.Map,
config: Config,

pub fn init(process: std.process.Init, config: Config) Context {
    return .{
        .io = process.io,
        .gpa = process.gpa,
        .arena = process.arena.allocator(),
        .env = process.environ_map,
        .config = config,
    };
}
