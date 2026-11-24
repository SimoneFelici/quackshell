const std = @import("std");

const z2d = @import("z2d");

const Context = @import("Context.zig");

/// Draws the bar
pub fn bar(ctx: Context, pixels: []z2d.pixel.ARGB, width: u32, height: u32) !void {
    var sfc = z2d.Surface.initBuffer(.image_surface_argb, null, pixels, @intCast(width), @intCast(height));
    var ztx = z2d.Context.init(ctx.io, ctx.gpa, &sfc);
    defer ztx.deinit();

    ztx.setSourceToPixel(.{ .argb = ctx.config.background.multiply() });

    const r: f64 = @floatFromInt(ctx.config.rounding);
    const w: f64 = @floatFromInt(width);
    const h: f64 = @floatFromInt(height);
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
