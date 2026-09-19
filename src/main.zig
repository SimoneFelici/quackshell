const std = @import("std");
const Context = @import("Context.zig");
const Client = @import("Client.zig");
const Bar = @import("Bar.zig");

pub fn main(init: std.process.Init) anyerror!void {
    const ctx = try Context.init(init);

    var client: Client = undefined;
    try client.init();
    defer client.deinit();

    const shm = client.globals.shm orelse return error.NoWlShm;
    defer shm.destroy();

    const compositor = client.globals.compositor orelse return error.NoWlCompositor;
    defer compositor.destroy();

    const layer_shell = client.globals.layer_shell orelse return error.NoLayerShell;
    defer layer_shell.destroy();

    var bar: Bar = undefined;
    try bar.init(ctx, client.display, compositor, layer_shell, shm);
    defer bar.deinit();

    // Main loop
    while (bar.running) {
        if (client.display.dispatch() != .SUCCESS) return error.DispatchFailed;
    }
}
