const std = @import("std");

const wayland = @import("wayland");
const wl = wayland.client.wl;
const ext = wayland.client.ext;
const z2d = @import("z2d");

const Context = @import("../Context.zig");
const rect = @import("../draw.zig").rect;
const text = @import("../draw.zig").text;

const State = struct {
    gpa: std.mem.Allocator = undefined,
    workspaces: std.ArrayList(*Workspace) = .empty,
    changed: bool = false,
};

const Group = struct {
    outputs: std.ArrayList(*wl.Output) = .empty,
};

const Workspace = struct {
    group: ?*Group = null,
    name: []u8 = &.{},
    active: bool = false,
    hidden: bool = false,
};

var state: State = .{};

pub fn draw(ctx: Context, ztx: ?*z2d.Context, output: *wl.Output, x: f64, y: f64) !f64 {
    const conf = ctx.config.workspaces;
    const extents = ctx.font.extents(ctx.config.font_size);
    const text_height = @abs(extents.ascender) + @abs(extents.descender);

    var pos = x;
    for (state.workspaces.items) |ws| {
        if (ws.hidden) continue;
        if (conf.scope == .monitor) {
            const group = ws.group orelse continue;
            if (std.mem.indexOfScalar(*wl.Output, group.outputs.items, output) == null) continue;
        }

        const w = try text(ctx, null, ws.name, 0, 0) + 2 * conf.padding;
        if (ztx) |z| {
            if (ws.active) {
                z.setSourceToPixel(.{ .argb = conf.active_background.multiply() });
                try rect(z, pos, conf.margin, w, 2 * y + text_height - 2 * conf.margin, @floatFromInt(ctx.config.rounding));
                z.setSourceToPixel(.{ .argb = conf.active_foreground.multiply() });
            }
            _ = try text(ctx, z, ws.name, pos + conf.padding, y);
            z.setSourceToPixel(.{ .argb = ctx.config.foreground.multiply() });
        }
        pos += w;
    }
    return pos - x;
}

pub fn changed() bool {
    defer state.changed = false;
    return state.changed;
}

pub fn init(ctx: Context) !void {
    state.gpa = ctx.gpa;
}

pub fn bind(_: Context, registry: *wl.Registry, name: u32, interface: [*:0]const u8, version: u32) void {
    if (std.mem.orderZ(u8, interface, ext.WorkspaceManagerV1.interface.name) != .eq) return;
    const manager = registry.bind(name, ext.WorkspaceManagerV1, @min(version, 1)) catch return;
    manager.setListener(*State, managerListener, &state);
}

fn managerListener(_: *ext.WorkspaceManagerV1, event: ext.WorkspaceManagerV1.Event, s: *State) void {
    switch (event) {
        .workspace_group => |ev| {
            const group = s.gpa.create(Group) catch return ev.workspace_group.destroy();
            group.* = .{};
            ev.workspace_group.setListener(*Group, groupListener, group);
        },
        .workspace => |ev| {
            const ws = s.gpa.create(Workspace) catch return ev.workspace.destroy();
            ws.* = .{};
            s.workspaces.append(s.gpa, ws) catch {
                s.gpa.destroy(ws);
                return ev.workspace.destroy();
            };
            ev.workspace.setListener(*Workspace, workspaceListener, ws);
        },
        .done => s.changed = true,
        .finished => {},
    }
}

fn groupListener(handle: *ext.WorkspaceGroupHandleV1, event: ext.WorkspaceGroupHandleV1.Event, group: *Group) void {
    switch (event) {
        .output_enter => |ev| {
            const output = ev.output orelse return;
            group.outputs.append(state.gpa, output) catch {};
        },
        .output_leave => |ev| {
            const output = ev.output orelse return;
            if (std.mem.indexOfScalar(*wl.Output, group.outputs.items, output)) |i| {
                _ = group.outputs.swapRemove(i);
            }
        },
        .workspace_enter => |ev| {
            const ws_handle = ev.workspace orelse return;
            const ws: *Workspace = @ptrCast(@alignCast(ws_handle.getUserData() orelse return));
            ws.group = group;
        },
        .workspace_leave => |ev| {
            const ws_handle = ev.workspace orelse return;
            const ws: *Workspace = @ptrCast(@alignCast(ws_handle.getUserData() orelse return));
            if (ws.group == group) ws.group = null;
        },
        .removed => {
            for (state.workspaces.items) |ws| {
                if (ws.group == group) ws.group = null;
            }
            group.outputs.deinit(state.gpa);
            state.gpa.destroy(group);
            handle.destroy();
        },
        else => {},
    }
}

fn workspaceListener(handle: *ext.WorkspaceHandleV1, event: ext.WorkspaceHandleV1.Event, ws: *Workspace) void {
    switch (event) {
        .name => |ev| {
            const name = state.gpa.dupe(u8, std.mem.span(ev.name)) catch return;
            state.gpa.free(ws.name);
            ws.name = name;
        },
        .state => |ev| {
            ws.active = ev.state.active;
            ws.hidden = ev.state.hidden;
        },
        .removed => {
            if (std.mem.indexOfScalar(*Workspace, state.workspaces.items, ws)) |i| {
                _ = state.workspaces.orderedRemove(i);
            }
            state.gpa.free(ws.name);
            state.gpa.destroy(ws);
            handle.destroy();
        },
        else => {},
    }
}
