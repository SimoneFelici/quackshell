const std = @import("std");
const posix = std.posix;

const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;

const z2d = @import("z2d");

const Context = @import("Context.zig");
const draw = @import("draw.zig");

const Bar = @This();

surface: *wl.Surface,
layer_surface: *zwlr.LayerSurfaceV1,
buffer: ?*wl.Buffer = null,
pixels: []z2d.pixel.ARGB = &.{},
width: u32 = 0,
height: u32 = 0,
configured: bool = false,
closed: bool = false,
busy: bool = false,
dirty: bool = true,

pub fn create(
    ctx: Context,
    compositor: *wl.Compositor,
    layer_shell: *zwlr.LayerShellV1,
    output: *wl.Output,
) !*Bar {
    const bar = try ctx.arena.create(Bar);

    const surface = try compositor.createSurface();
    const layer_surface = try layer_shell.getLayerSurface(surface, output, .top, "quackshell");
    layer_surface.setSize(0, ctx.config.height);
    layer_surface.setAnchor(switch (ctx.config.position) {
        .top => .{ .top = true, .left = true, .right = true },
        .bottom => .{ .bottom = true, .left = true, .right = true },
    });
    layer_surface.setMargin(0, ctx.config.gaps, 0, ctx.config.gaps);
    layer_surface.setExclusiveZone(@intCast(ctx.config.height));

    bar.* = .{ .surface = surface, .layer_surface = layer_surface };
    layer_surface.setListener(*Bar, layerSurfaceListener, bar);

    surface.commit();
    return bar;
}

/// If the bar is dirty and not busy draws the bar
pub fn update(bar: *Bar, ctx: Context, shm: *wl.Shm) !void {
    if (bar.closed or !bar.configured or !bar.dirty or bar.busy) return;
    if (bar.buffer == null) try bar.createBuffer(shm);

    @memset(std.mem.sliceAsBytes(bar.pixels), 0);

    var sfc = z2d.Surface.initBuffer(.image_surface_argb, null, bar.pixels, @intCast(bar.width), @intCast(bar.height));
    var ztx = z2d.Context.init(ctx.io, ctx.gpa, &sfc);
    defer ztx.deinit();

    const w: f64 = @floatFromInt(bar.width);
    const h: f64 = @floatFromInt(bar.height);
    try draw.background(ctx, &ztx, w, h);
    try draw.zones(ctx, &ztx, w, h);

    bar.surface.attach(bar.buffer.?, 0, 0);
    bar.surface.damageBuffer(0, 0, @intCast(bar.width), @intCast(bar.height));
    bar.surface.commit();

    bar.busy = true;
    bar.dirty = false;
}

fn createBuffer(bar: *Bar, shm: *wl.Shm) !void {
    const stride = bar.width * 4;
    const len = stride * bar.height;

    const fd = try posix.memfd_create("quackshell", 0);
    defer _ = posix.system.close(fd);
    if (posix.errno(posix.system.ftruncate(fd, len)) != .SUCCESS) return error.FtruncateFailed;
    const data = try posix.mmap(null, len, .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, fd, 0);

    const pool = try shm.createPool(fd, @intCast(len));
    defer pool.destroy();
    const buffer = try pool.createBuffer(0, @intCast(bar.width), @intCast(bar.height), @intCast(stride), .argb8888);
    buffer.setListener(*Bar, bufferListener, bar);

    bar.buffer = buffer;
    bar.pixels = std.mem.bytesAsSlice(z2d.pixel.ARGB, data);
}

fn destroyBuffer(bar: *Bar) void {
    const buffer = bar.buffer orelse return;
    buffer.destroy();
    posix.munmap(@alignCast(std.mem.sliceAsBytes(bar.pixels)));
    bar.buffer = null;
    bar.pixels = &.{};
    bar.busy = false;
}

/// When not in use sets busy to false
fn bufferListener(_: *wl.Buffer, event: wl.Buffer.Event, bar: *Bar) void {
    switch (event) {
        .release => bar.busy = false,
    }
}

fn layerSurfaceListener(layer_surface: *zwlr.LayerSurfaceV1, event: zwlr.LayerSurfaceV1.Event, bar: *Bar) void {
    switch (event) {
        .configure => |ev| {
            layer_surface.ackConfigure(ev.serial);
            if (ev.width != bar.width or ev.height != bar.height) bar.destroyBuffer();
            bar.width = ev.width;
            bar.height = ev.height;
            bar.configured = true;
            bar.dirty = true;
        },
        .closed => bar.closed = true,
    }
}
