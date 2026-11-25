const std = @import("std");

const z2d = @import("z2d");
const zeit = @import("zeit");

const Config = @import("Config.zig");

const Context = @This();

io: std.Io,
gpa: std.mem.Allocator,
arena: std.mem.Allocator,
config: Config,
font: *z2d.font.Font,
timezone: zeit.TimeZone,

pub fn init(process: std.process.Init, config: Config) !Context {
    const arena = process.arena.allocator();

    const bytes = try std.Io.Dir.cwd().readFileAlloc(process.io, config.font, arena, .unlimited);
    const file = try z2d.font.File.loadBuffer(bytes);
    const font = try arena.create(z2d.font.Font);
    font.* = file.loadFontIndex(0) catch |err| {
        std.log.err("unsupported font {s}", .{config.font});
        return err;
    };

    return .{
        .io = process.io,
        .gpa = process.gpa,
        .arena = arena,
        .config = config,
        .font = font,
        .timezone = try zeit.local(arena, process.io, .{}),
    };
}
