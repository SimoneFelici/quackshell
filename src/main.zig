const std = @import("std");
const mem = std.mem;
const posix = std.posix;
const z2d = @import("z2d");

const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;

const BAR_HEIGHT = 32;

const Globals = struct {
    shm: ?*wl.Shm = null,
    compositor: ?*wl.Compositor = null,
    layer_shell: ?*zwlr.LayerShellV1 = null,
};

const State = struct {
    configured: bool = false,
    running: bool = true,
    width: u32 = 0,
    height: u32 = 0,
};

pub fn main(init: std.process.Init) anyerror!void {
    // Connect to compositor
    // nulll = "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    const display = try wl.Display.connect(null);
    defer display.disconnect();

    const registry = try display.getRegistry();
    defer registry.destroy();

    var globals = Globals{};

    registry.setListener(*Globals, registryListener, &globals);
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

    layer_surface.setSize(0, BAR_HEIGHT);
    // layer_surface.setSize(BAR_HEIGHT, 0);
    layer_surface.setAnchor(.{ .top = true, .left = true, .right = true });
    // layer_surface.setAnchor(.{ .bottom = true, .left = true, .right = true });
    // layer_surface.setAnchor(.{ .left = true, .top = true, .bottom = true });
    layer_surface.setExclusiveZone(BAR_HEIGHT);

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
        var ctx = z2d.Context.init(init.io, init.gpa, &sfc);
        defer ctx.deinit();
        ctx.setSourceToPixel(.{ .argb = .{ .r = 0x00, .g = 0x00, .b = 0x99, .a = 0x99 } });

        try ctx.moveTo(0, 0);
        try ctx.lineTo(@floatFromInt(state.width), 0);
        try ctx.lineTo(@floatFromInt(state.width), @floatFromInt(state.height));
        try ctx.lineTo(0, @floatFromInt(state.height));
        try ctx.closePath();
        try ctx.fill();

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

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, globals: *Globals) void {
    switch (event) {
        .global => |global| {
            if (mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                globals.compositor = registry.bind(global.name, wl.Compositor, 1) catch return;
            } else if (mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                globals.shm = registry.bind(global.name, wl.Shm, 1) catch return;
            } else if (mem.orderZ(u8, global.interface, zwlr.LayerShellV1.interface.name) == .eq) {
                globals.layer_shell = registry.bind(global.name, zwlr.LayerShellV1, 1) catch return;
            }
        },
        .global_remove => {},
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
