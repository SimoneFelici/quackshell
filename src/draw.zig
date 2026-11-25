const std = @import("std");

const z2d = @import("z2d");

const Config = @import("Config.zig");
const Context = @import("Context.zig");
const text = @import("modules/text.zig");

pub fn background(ctx: Context, ztx: *z2d.Context, w: f64, h: f64) !void {
    ztx.setSourceToPixel(.{ .argb = ctx.config.background.multiply() });

    const r: f64 = @min(@as(f64, @floatFromInt(ctx.config.rounding)), h / 2, w / 2);
    const pi = std.math.pi;

    try ztx.moveTo(r, 0);
    try ztx.lineTo(w - r, 0);
    try ztx.arc(w - r, r, r, -pi / 2.0, 0);
    try ztx.lineTo(w, h - r);
    try ztx.arc(w - r, h - r, r, 0, pi / 2.0);
    try ztx.lineTo(r, h);
    try ztx.arc(r, h - r, r, pi / 2.0, pi);
    try ztx.lineTo(0, r);
    try ztx.arc(r, r, r, pi, 3.0 * pi / 2.0);
    try ztx.closePath();
    try ztx.fill();
}

pub fn modules(ctx: Context, ztx: *z2d.Context, w: f64, h: f64) !void {
    ztx.setSourceToPixel(.{ .argb = ctx.config.foreground.multiply() });

    const fe = ctx.font.extents(ctx.config.font_size);
    const y = (h - (@abs(fe.ascender) + @abs(fe.descender))) / 2;
    const pad = ctx.config.padding;

    try zone(ctx, ztx, ctx.config.left, pad, y);
    try zone(ctx, ztx, ctx.config.center, (w - try zoneWidth(ctx, ctx.config.center)) / 2, y);
    try zone(ctx, ztx, ctx.config.right, w - pad - try zoneWidth(ctx, ctx.config.right), y);
}

fn zoneWidth(ctx: Context, zone_modules: []const Config.Module) !f64 {
    var total: f64 = 0;
    for (zone_modules, 0..) |module, i| {
        if (i > 0) total += ctx.config.padding;
        total += switch (module) {
            .text => try text.width(ctx),
        };
    }
    return total;
}

fn zone(ctx: Context, ztx: *z2d.Context, zone_modules: []const Config.Module, start: f64, y: f64) !void {
    var x = start;
    for (zone_modules) |module| {
        x += ctx.config.padding + switch (module) {
            .text => try text.draw(ctx, ztx, x, y),
        };
    }
}
