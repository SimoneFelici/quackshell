const std = @import("std");

const zeit = @import("zeit");

const Context = @import("../Context.zig");

pub fn format(ctx: Context, buf: []u8) ![]const u8 {
    const now = zeit.instant(.{ .now = ctx.io }, &ctx.timezone);
    var writer = std.Io.Writer.fixed(buf);
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
