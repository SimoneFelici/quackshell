const std = @import("std");
const mem = std.mem;
const posix = std.posix;

const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;

const z2d = @import("z2d");

const Context = @import("Context.zig");

const Globals = struct {
    compositor: ?*wl.Compositor = null,
    shm: ?*wl.Shm = null,
    layer_shell: ?*zwlr.LayerShellV1 = null,
};

const State = struct {
    configured: bool = false,
    closed: bool = false,
    width: u32 = 0,
    height: u32 = 0,
};

pub fn main(init: std.process.Init) !void {
    const ctx = Context.init(init, .{});

    const display = try wl.Display.connect(null);
    defer display.disconnect();

    const registry = try display.getRegistry();
    var globals: Globals = .{};
    registry.setListener(*Globals, registryListener, &globals);
    if (display.roundtrip() != .SUCCESS) return error.RoundtripFailed;

    const compositor = globals.compositor orelse return error.NoWlCompositor;
    const shm = globals.shm orelse return error.NoWlShm;
    const layer_shell = globals.layer_shell orelse return error.NoLayerShell;

    const surface = try compositor.createSurface();
    const layer_surface = try layer_shell.getLayerSurface(surface, null, .top, "quackshell");
    layer_surface.setSize(0, ctx.config.height);
    layer_surface.setAnchor(switch (ctx.config.position) {
        .top => .{ .top = true, .left = true, .right = true },
        .bottom => .{ .bottom = true, .left = true, .right = true },
    });
    layer_surface.setExclusiveZone(@intCast(ctx.config.height));

    var state: State = .{};
    layer_surface.setListener(*State, layerSurfaceListener, &state);

    // Empty request to be seen by the compositor
    // Then we get info from the listener
    surface.commit();
    while (!state.configured and !state.closed) {
        if (display.dispatch() != .SUCCESS) return error.DispatchFailed;
    }
    if (state.closed) return;

    const buffer = try createBuffer(ctx, shm, state.width, state.height);
    surface.attach(buffer, 0, 0);
    surface.damageBuffer(0, 0, @intCast(state.width), @intCast(state.height));
    surface.commit();

    while (!state.closed) {
        if (display.dispatch() != .SUCCESS) return error.DispatchFailed;
    }
}

/// Wayland buffer
fn createBuffer(ctx: Context, shm: *wl.Shm, width: u32, height: u32) !*wl.Buffer {
    const stride = width * 4;
    const len = stride * height;

    const fd = try posix.memfd_create("quackshell", 0);
    if (posix.errno(posix.system.ftruncate(fd, len)) != .SUCCESS) return error.FtruncateFailed;
    const data = try posix.mmap(null, len, .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, fd, 0);

    const pixels = mem.bytesAsSlice(z2d.pixel.ARGB, data);
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

    const pool = try shm.createPool(fd, @intCast(len));
    defer pool.destroy();
    return try pool.createBuffer(0, @intCast(width), @intCast(height), @intCast(stride), .argb8888);
}

// Wayland listeners

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, globals: *Globals) void {
    switch (event) {
        .global => |global| {
            if (mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                globals.compositor = registry.bind(global.name, wl.Compositor, @min(global.version, 4)) catch return;
            } else if (mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                globals.shm = registry.bind(global.name, wl.Shm, 1) catch return;
            } else if (mem.orderZ(u8, global.interface, zwlr.LayerShellV1.interface.name) == .eq) {
                globals.layer_shell = registry.bind(global.name, zwlr.LayerShellV1, @min(global.version, 4)) catch return;
            }
        },
        .global_remove => {},
    }
}

fn layerSurfaceListener(layer_surface: *zwlr.LayerSurfaceV1, event: zwlr.LayerSurfaceV1.Event, state: *State) void {
    switch (event) {
        .configure => |ev| {
            layer_surface.ackConfigure(ev.serial);
            state.width = ev.width;
            state.height = ev.height;
            state.configured = true;
        },
        .closed => state.closed = true,
    }
}
