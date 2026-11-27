const std = @import("std");

const wayland = @import("wayland");
const wl = wayland.client.wl;
const z2d = @import("z2d");

const Config = @import("Config.zig");
const Context = @import("Context.zig");
const modules = @import("modules.zig");

pub fn background(ctx: Context, ztx: *z2d.Context, w: f64, h: f64) !void {
    ztx.setSourceToPixel(.{ .argb = ctx.config.background.multiply() });
    try rect(ztx, 0, 0, w, h, @floatFromInt(ctx.config.rounding));
}

pub fn zones(ctx: Context, ztx: *z2d.Context, output: *wl.Output, w: f64, h: f64) void {
    ztx.setSourceToPixel(.{ .argb = ctx.config.foreground.multiply() });

    const fe = ctx.font.extents(ctx.config.font_size);
    const y = (h - (@abs(fe.ascender) + @abs(fe.descender))) / 2;
    const pad = ctx.config.padding;
    const center = ctx.config.center;
    const right = ctx.config.right;

    _ = zone(ctx, ztx, output, ctx.config.left, pad, y);
    _ = zone(ctx, ztx, output, center, (w - zone(ctx, null, output, center, 0, y)) / 2, y);
    _ = zone(ctx, ztx, output, right, w - pad - zone(ctx, null, output, right, 0, y), y);
}

/// Draw modules of a zone and return the width
/// If NULL returns the width
fn zone(ctx: Context, ztx: ?*z2d.Context, output: *wl.Output, zone_modules: []const Config.Module, start: f64, y: f64) f64 {
    var x = start;
    for (zone_modules, 0..) |module, i| {
        if (i > 0) x += ctx.config.padding;
        x += modules.draw(ctx, ztx, output, module, x, y) catch |err| blk: {
            std.log.err("module {t}: {t}", .{ module, err });
            break :blk 0;
        };
    }
    return x - start;
}

/// Draws text and return the width
/// If NULL returns the width
pub fn text(ctx: Context, ztx: ?*z2d.Context, str: []const u8, x: f64, y: f64) !f64 {
    var shaped = try z2d.text.shape(ctx.gpa, ctx.font, str, x, y, .{
        .mode = if (ztx == null) .extents_only else .all,
        .size = ctx.config.font_size,
    });
    defer shaped.deinit(ctx.gpa);
    if (ztx) |z| try z2d.painter.fill(ctx.gpa, z.surface, &z.pattern, shaped.path().nodes.items, .default);
    return shaped.extents().advance;
}

/// Draw rectangle
pub fn rect(ztx: *z2d.Context, x: f64, y: f64, w: f64, h: f64, radius: f64) !void {
    const r = @min(radius, h / 2, w / 2);
    const pi = std.math.pi;

    ztx.resetPath();
    try ztx.moveTo(x + r, y);
    try ztx.lineTo(x + w - r, y);
    try ztx.arc(x + w - r, y + r, r, -pi / 2.0, 0);
    try ztx.lineTo(x + w, y + h - r);
    try ztx.arc(x + w - r, y + h - r, r, 0, pi / 2.0);
    try ztx.lineTo(x + r, y + h);
    try ztx.arc(x + r, y + h - r, r, pi / 2.0, pi);
    try ztx.lineTo(x, y + r);
    try ztx.arc(x + r, y + r, r, pi, 3.0 * pi / 2.0);
    try ztx.closePath();
    try ztx.fill();
}
