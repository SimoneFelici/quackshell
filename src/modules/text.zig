const z2d = @import("z2d");

const Context = @import("../Context.zig");

/// Return width of the text
pub fn width(ctx: Context) !f64 {
    var shaped = try z2d.text.shape(ctx.gpa, ctx.font, ctx.config.text.content, 0, 0, .{
        .mode = .extents_only,
        .size = ctx.config.font_size,
    });
    defer shaped.deinit(ctx.gpa);
    return shaped.extents().advance;
}

pub fn draw(ctx: Context, ztx: *z2d.Context, x: f64, y: f64) !f64 {
    var shaped = try z2d.text.shape(ctx.gpa, ctx.font, ctx.config.text.content, x, y, .{
        .size = ctx.config.font_size,
    });
    defer shaped.deinit(ctx.gpa);
    try z2d.painter.fill(ctx.gpa, ztx.surface, &ztx.pattern, shaped.path().nodes.items, .default);
    return shaped.extents().advance;
}
