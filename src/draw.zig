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
    const left: f64 = @floatFromInt(ctx.config.gaps);
    const right: f64 = @floatFromInt(width - ctx.config.gaps);
    const bottom: f64 = @floatFromInt(height);
    const pi = std.math.pi;

    try ztx.moveTo(left + r, 0);
    try ztx.lineTo(right - r, 0);
    try ztx.arc(right - r, r, r, -pi / 2.0, 0);
    try ztx.lineTo(right, bottom - r);
    try ztx.arc(right - r, bottom - r, r, 0, pi / 2.0);
    try ztx.lineTo(left + r, bottom);
    try ztx.arc(left + r, bottom - r, r, pi / 2.0, pi);
    try ztx.lineTo(left, r);
    try ztx.arc(left + r, r, r, pi, 3.0 * pi / 2.0);
    try ztx.closePath();
    try ztx.fill();
}
