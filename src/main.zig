const std = @import("std");
const posix = std.posix;

const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;

const z2d = @import("z2d");

const Context = @import("Context.zig");
const draw = @import("draw.zig");
const listeners = @import("listeners.zig");

pub fn main(init: std.process.Init) !void {
    const ctx = Context.init(init, .{});

    // Connect to compositor
    // null = "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    const display = try wl.Display.connect(null);
    defer display.disconnect();

    const registry = try display.getRegistry();
    var globals: listeners.Globals = .{ .arena = ctx.arena };
    registry.setListener(*listeners.Globals, listeners.registryListener, &globals);
    if (display.roundtrip() != .SUCCESS) return error.RoundtripFailed;

    const compositor = globals.compositor orelse return error.NoWlCompositor;
    const shm = globals.shm orelse return error.NoWlShm;
    const layer_shell = globals.layer_shell orelse return error.NoLayerShell;

    for (globals.outputs.items) |output| {
        try createBar(ctx, display, compositor, layer_shell, shm, output);
    }

    while (display.dispatch() == .SUCCESS) {}
}

/// Create bar
fn createBar(
    ctx: Context,
    display: *wl.Display,
    compositor: *wl.Compositor,
    layer_shell: *zwlr.LayerShellV1,
    shm: *wl.Shm,
    output: *wl.Output,
) !void {
    const surface = try compositor.createSurface();
    const layer_surface = try layer_shell.getLayerSurface(surface, output, .top, "quackshell");
    layer_surface.setSize(0, ctx.config.height);
    layer_surface.setAnchor(switch (ctx.config.position) {
        .top => .{ .top = true, .left = true, .right = true },
        .bottom => .{ .bottom = true, .left = true, .right = true },
    });
    layer_surface.setExclusiveZone(@intCast(ctx.config.height));

    const state = try ctx.arena.create(listeners.State);
    state.* = .{};
    layer_surface.setListener(*listeners.State, listeners.layerSurfaceListener, state);

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
}

/// Wayland buffer
fn createBuffer(ctx: Context, shm: *wl.Shm, width: u32, height: u32) !*wl.Buffer {
    const stride = width * 4;
    const len = stride * height;

    const fd = try posix.memfd_create("quackshell", 0);
    if (posix.errno(posix.system.ftruncate(fd, len)) != .SUCCESS) return error.FtruncateFailed;
    const data = try posix.mmap(null, len, .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, fd, 0);

    const pixels = std.mem.bytesAsSlice(z2d.pixel.ARGB, data);
    try draw.bar(ctx, pixels, width, height);

    const pool = try shm.createPool(fd, @intCast(len));
    defer pool.destroy();
    return try pool.createBuffer(0, @intCast(width), @intCast(height), @intCast(stride), .argb8888);
}
