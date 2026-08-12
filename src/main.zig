const std = @import("std");
const mem = std.mem;
const posix = std.posix;
const z2d = @import("z2d");
const Context = @import("context.zig");
const Wayland = @import("wayland.zig");

const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;

const State = struct {
    configured: bool = false,
    running: bool = true,
    width: u32 = 0,
    height: u32 = 0,
};

pub fn main(init: std.process.Init) anyerror!void {
    const ctx = try Context.init(init);
    // Connect to compositor
    // null = "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    const display = try wl.Display.connect(null);
    defer display.disconnect();

    const registry = try display.getRegistry();
    defer registry.destroy();

    var globals = Wayland.Globals{};
    registry.setListener(*Wayland.Globals, Wayland.registryListener, &globals);
    if (display.roundtrip() != .SUCCESS) return error.RoundtripFailed;

    const shm = globals.shm orelse return error.NoWlShm;
    defer shm.destroy();
    const compositor = globals.compositor orelse return error.NoWlCompositor;
    defer compositor.destroy();
    const layer_shell = globals.layer_shell orelse return error.NoLayerShell;
    defer layer_shell.destroy();
    const surface = try compositor.createSurface();
    defer surface.destroy();
    const layer_surface = try layer_shell.getLayerSurface(surface, null, .top, "quackshell");
    defer layer_surface.destroy();

    layer_surface.setSize(0, ctx.config.bar_height);
    // layer_surface.setSize(BAR_HEIGHT, 0);
    layer_surface.setAnchor(.{ .top = true, .left = true, .right = true });
    // layer_surface.setAnchor(.{ .bottom = true, .left = true, .right = true });
    // layer_surface.setAnchor(.{ .left = true, .top = true, .bottom = true });
    layer_surface.setExclusiveZone(@intCast(ctx.config.bar_height));

    var state = State{};
    layer_surface.setListener(*State, layerSurfaceListener, &state);

    // Empty request to be seen by the compositor
    // Then we get info from the listener
    surface.commit();
    while (!state.configured) {
        if (display.dispatch() != .SUCCESS) return error.DispatchFailed;
    }

    const buffer = blk: {
        const stride = state.width * 4;
        const size = stride * state.height;

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

        var sfc = z2d.Surface.initBuffer(.image_surface_argb, null, pixels, @intCast(state.width), @intCast(state.height));
        var ztx = z2d.Context.init(ctx.io, ctx.gpa, &sfc);
        defer ztx.deinit();
        ztx.setSourceToPixel(.{ .argb = .{ .r = 0x00, .g = 0x00, .b = 0xff, .a = 0xff } });

        try ztx.moveTo(0, 0);
        try ztx.lineTo(@floatFromInt(state.width), 0);
        try ztx.lineTo(@floatFromInt(state.width), @floatFromInt(state.height));
        try ztx.lineTo(0, @floatFromInt(state.height));
        try ztx.closePath();
        try ztx.fill();

        const pool = try shm.createPool(fd, @intCast(size));
        defer pool.destroy();

        break :blk try pool.createBuffer(
            0,
            @intCast(state.width),
            @intCast(state.height),
            @intCast(stride),
            wl.Shm.Format.argb8888,
        );
    };
    defer buffer.destroy();

    // Print buffer to monitor
    surface.attach(buffer, 0, 0);
    surface.commit();

    // Main loop
    while (state.running) {
        if (display.dispatch() != .SUCCESS) return error.DispatchFailed;
    }
}

fn layerSurfaceListener(ls: *zwlr.LayerSurfaceV1, event: zwlr.LayerSurfaceV1.Event, state: *State) void {
    switch (event) {
        .configure => |configure| {
            ls.ackConfigure(configure.serial);
            state.width = configure.width;
            state.height = configure.height;
            state.configured = true;
        },
        .closed => state.running = false,
    }
}
