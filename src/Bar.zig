const std = @import("std");
const mem = std.mem;
const posix = std.posix;
const z2d = @import("z2d");
const Context = @import("Context.zig");

const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;

const Bar = @This();

surface: *wl.Surface,
layer_surface: *zwlr.LayerSurfaceV1,
buffer: *wl.Buffer,

configured: bool = false,
running: bool = true,
width: u32 = 0,
height: u32 = 0,

pub fn init(
    bar: *Bar,
    ctx: Context,
    display: *wl.Display,
    compositor: *wl.Compositor,
    layer_shell: *zwlr.LayerShellV1,
    shm: *wl.Shm,
) !void {
    const surface = try compositor.createSurface();
    errdefer surface.destroy();
    const layer_surface = try layer_shell.getLayerSurface(surface, null, .top, "quackshell");
    errdefer layer_surface.destroy();

    layer_surface.setSize(0, ctx.config.bar_height);
    // layer_surface.setSize(BAR_HEIGHT, 0);
    layer_surface.setAnchor(.{ .top = true, .left = true, .right = true });
    // layer_surface.setAnchor(.{ .bottom = true, .left = true, .right = true });
    // layer_surface.setAnchor(.{ .left = true, .top = true, .bottom = true });
    layer_surface.setExclusiveZone(@intCast(ctx.config.bar_height));

    bar.* = .{
        .surface = surface,
        .layer_surface = layer_surface,
        .buffer = undefined,
    };
    layer_surface.setListener(*Bar, layerSurfaceListener, bar);

    // Empty request to be seen by the compositor
    // Then we get info from the listener
    surface.commit();
    while (!bar.configured) {
        if (display.dispatch() != .SUCCESS) return error.DispatchFailed;
    }

    bar.buffer = try bar.createBuffer(ctx, shm);
    errdefer bar.buffer.destroy();

    // Print buffer to monitor
    bar.surface.attach(bar.buffer, 0, 0);
    bar.surface.commit();
}

pub fn deinit(bar: *Bar) void {
    bar.buffer.destroy();
    bar.layer_surface.destroy();
    bar.surface.destroy();
}

fn createBuffer(bar: *Bar, ctx: Context, shm: *wl.Shm) !*wl.Buffer {
    const stride = bar.width * 4;
    const size = stride * bar.height;

    const fd = try posix.memfd_create("quackshell", 0);
    if (posix.errno(posix.system.ftruncate(fd, size)) != .SUCCESS) return error.FtruncateFailed;
    const data = try posix.mmap(
        null,
        size,
        .{ .READ = true, .WRITE = true },
        .{ .TYPE = .SHARED },
        fd,
        0,
    );
    const pixels = mem.bytesAsSlice(z2d.pixel.ARGB, data);

    var sfc = z2d.Surface.initBuffer(.image_surface_argb, null, pixels, @intCast(bar.width), @intCast(bar.height));
    var ztx = z2d.Context.init(ctx.io, ctx.gpa, &sfc);
    defer ztx.deinit();
    ztx.setSourceToPixel(.{ .argb = .{ .r = 0x00, .g = 0x00, .b = 0xff, .a = 0xff } });

    try ztx.moveTo(0, 0);
    try ztx.lineTo(@floatFromInt(bar.width), 0);
    try ztx.lineTo(@floatFromInt(bar.width), @floatFromInt(bar.height));
    try ztx.lineTo(0, @floatFromInt(bar.height));
    try ztx.closePath();
    try ztx.fill();

    const pool = try shm.createPool(fd, @intCast(size));
    defer pool.destroy();

    return try pool.createBuffer(
        0,
        @intCast(bar.width),
        @intCast(bar.height),
        @intCast(stride),
        wl.Shm.Format.argb8888,
    );
}

fn layerSurfaceListener(ls: *zwlr.LayerSurfaceV1, event: zwlr.LayerSurfaceV1.Event, bar: *Bar) void {
    switch (event) {
        .configure => |configure| {
            ls.ackConfigure(configure.serial);
            bar.width = configure.width;
            bar.height = configure.height;
            bar.configured = true;
        },
        .closed => bar.running = false,
    }
}
