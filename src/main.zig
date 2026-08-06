const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.client.wl;

pub fn main() !void {
    const display = try wl.Display.connect(null);
    defer display.disconnect();

    const registry = try display.getRegistry();
    defer registry.destroy();
}
