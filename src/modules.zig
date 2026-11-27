const std = @import("std");

const wayland = @import("wayland");
const wl = wayland.client.wl;
const z2d = @import("z2d");

const Config = @import("Config.zig");
const Context = @import("Context.zig");

// Modules list
const list = struct {
    pub const time = @import("modules/time.zig");
    pub const window_title = @import("modules/window_title.zig");
    pub const workspaces = @import("modules/workspaces.zig");
};

const all = std.enums.values(Config.Module);

// In use modules
var used: std.EnumSet(Config.Module) = .empty;

pub fn init(ctx: Context) !void {
    for ([_][]const Config.Module{ ctx.config.left, ctx.config.center, ctx.config.right }) |zone| {
        for (zone) |module| used.insert(module);
    }

    inline for (all) |m| {
        const module = @field(list, @tagName(m));
        if (@hasDecl(module, "init")) {
            if (used.contains(m)) try module.init(ctx);
        }
    }
}

/// Draw module and return the width
/// if NULL returns the width
pub fn draw(ctx: Context, ztx: ?*z2d.Context, output: *wl.Output, module: Config.Module, x: f64, y: f64) !f64 {
    return switch (module) {
        inline else => |m| @field(list, @tagName(m)).draw(ctx, ztx, output, x, y),
    };
}

pub fn bind(ctx: Context, registry: *wl.Registry, name: u32, interface: [*:0]const u8, version: u32) void {
    inline for (all) |m| {
        const module = @field(list, @tagName(m));
        if (@hasDecl(module, "bind")) {
            if (used.contains(m)) module.bind(ctx, registry, name, interface, version);
        }
    }
}

pub fn changed() bool {
    var any = false;
    inline for (all) |m| {
        const module = @field(list, @tagName(m));
        if (@hasDecl(module, "changed")) {
            if (module.changed()) any = true;
        }
    }
    return any;
}

pub fn timeout(ctx: Context) ?i32 {
    var ms: ?i32 = null;
    inline for (all) |m| {
        const module = @field(list, @tagName(m));
        if (@hasDecl(module, "timeout")) {
            if (used.contains(m)) {
                const t = module.timeout(ctx);
                ms = if (ms) |prev| @min(prev, t) else t;
            }
        }
    }
    return ms;
}
