const std = @import("std");

const wayland = @import("wayland");
const wl = wayland.client.wl;
const z2d = @import("z2d");
const zeit = @import("zeit");

const Context = @import("../Context.zig");
const text = @import("../draw.zig").text;

var timezone: zeit.TimeZone = undefined;
var buf: [64]u8 = undefined;

pub fn init(ctx: Context) !void {
    timezone = try zeit.local(ctx.arena, ctx.io, .{});
}

pub fn draw(ctx: Context, ztx: ?*z2d.Context, _: *wl.Output, x: f64, y: f64) !f64 {
    return text(ctx, ztx, try format(ctx), x, y);
}

fn format(ctx: Context) ![]const u8 {
    const now = zeit.instant(.{ .now = ctx.io }, &timezone);
    var writer = std.Io.Writer.fixed(&buf);
    try now.time().strftime(&writer, ctx.config.time.format);
    return writer.buffered();
}

/// Time to wait since next refresh
pub fn timeout(ctx: Context) i32 {
    const fmt = ctx.config.time.format;
    const seconds = std.mem.indexOf(u8, fmt, "%S") != null or std.mem.indexOf(u8, fmt, "%T") != null;
    const step: i64 = if (seconds) 1_000 else 60_000;
    const ms = @divFloor(std.Io.Clock.now(.real, ctx.io).nanoseconds, std.time.ns_per_ms);
    return @intCast(step - @mod(ms, step));
}
