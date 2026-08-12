const std = @import("std");
const mem = std.mem;

const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;

pub const Globals = struct {
    shm: ?*wl.Shm = null,
    compositor: ?*wl.Compositor = null,
    layer_shell: ?*zwlr.LayerShellV1 = null,
};

pub fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, globals: *Globals) void {
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
