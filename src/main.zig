const std = @import("std");

const wayland = @import("wayland");
const wl = wayland.client.wl;

const Bar = @import("Bar.zig");
const Context = @import("Context.zig");
const listeners = @import("listeners.zig");
const modules = @import("modules.zig");

pub fn main(init: std.process.Init) !void {
    const ctx = try Context.init(init, .{});
    try modules.init(ctx);

    // Connect to compositor
    // null = "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    const display = try wl.Display.connect(null);
    defer display.disconnect();

    const registry = try display.getRegistry();
    var globals: listeners.Globals = .{ .ctx = ctx };
    registry.setListener(*listeners.Globals, listeners.registryListener, &globals);
    if (display.roundtrip() != .SUCCESS) return error.RoundtripFailed;

    const compositor = globals.compositor orelse return error.NoWlCompositor;
    const shm = globals.shm orelse return error.NoWlShm;
    const layer_shell = globals.layer_shell orelse return error.NoLayerShell;

    var bars: std.ArrayList(*Bar) = .empty;
    for (globals.outputs.items) |output| {
        const bar = try Bar.create(ctx, compositor, layer_shell, output);
        try bars.append(ctx.arena, bar);
    }

    var fds = [_]std.posix.pollfd{
        .{ .fd = display.getFd(), .events = std.posix.POLL.IN, .revents = 0 },
    };

    // Main loop
    while (true) {
        for (bars.items) |bar| try bar.update(ctx, shm);

        while (!display.prepareRead()) {
            if (display.dispatchPending() != .SUCCESS) return error.DispatchFailed;
        }
        switch (display.flush()) {
            .SUCCESS, .AGAIN => {},
            else => return error.FlushFailed,
        }

        const ret = std.posix.system.poll(&fds, fds.len, modules.timeout(ctx) orelse -1);
        if (std.posix.errno(ret) != .SUCCESS) {
            display.cancelRead();
            continue;
        }

        if (fds[0].revents & std.posix.POLL.IN != 0) {
            if (display.readEvents() != .SUCCESS) return error.ReadFailed;
        } else {
            display.cancelRead();
        }
        if (display.dispatchPending() != .SUCCESS) return error.DispatchFailed;

        if (ret == 0 or modules.changed()) {
            for (bars.items) |bar| bar.dirty = true;
        }
    }
}
