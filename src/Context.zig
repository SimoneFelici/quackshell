const std = @import("std");

const known_folders = @import("known_folders");
const z2d = @import("z2d");

const Config = @import("Config.zig");

const Context = @This();

io: std.Io,
gpa: std.mem.Allocator,
arena: std.mem.Allocator,
config: Config,
font: *z2d.font.Font,

pub fn init(process: std.process.Init) !Context {
    const arena = process.arena.allocator();
    const config = try loadConfig(process.io, process.gpa, arena, process.environ_map);

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
    };
}

/// ~/.config/quackshell/config.zon
fn loadConfig(io: std.Io, gpa: std.mem.Allocator, arena: std.mem.Allocator, environ: *const std.process.Environ.Map) !Config {
    const dir = try known_folders.getPath(io, arena, environ, .local_configuration) orelse return .{};
    const path = try std.Io.Dir.path.join(arena, &.{ dir, "quackshell", "config.zon" });

    const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, arena, .unlimited) catch |err| switch (err) {
        error.FileNotFound => return .{},
        else => return err,
    };

    var diag: std.zon.parse.Diagnostics = undefined;
    return std.zon.parse.fromSlice(Config, .{
        .gpa = gpa,
        .arena = arena,
        .source = try arena.dupeSentinel(u8, bytes, 0),
        .diagnostics = &diag,
    }) catch |err| switch (err) {
        error.ParseZon => diag.fatal(path),
        else => return err,
    };
}
