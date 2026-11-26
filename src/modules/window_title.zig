const std = @import("std");

const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;

const Context = @import("../Context.zig");

const State = struct {
    gpa: std.mem.Allocator = undefined,
    active: ?*Toplevel = null,
    changed: bool = false,
};

const Toplevel = struct {
    title: []u8 = &.{},
    activated: bool = false,
    pending_activated: bool = false,
};

var state: State = .{};

pub fn content(_: Context) ![]const u8 {
    return if (state.active) |toplevel| toplevel.title else "";
}

pub fn changed() bool {
    defer state.changed = false;
    return state.changed;
}

pub fn init(ctx: Context) !void {
    state.gpa = ctx.gpa;
}

pub fn bind(_: Context, registry: *wl.Registry, name: u32, interface: [*:0]const u8, version: u32) void {
    if (std.mem.orderZ(u8, interface, zwlr.ForeignToplevelManagerV1.interface.name) != .eq) return;
    const manager = registry.bind(name, zwlr.ForeignToplevelManagerV1, @min(version, 3)) catch return;
    manager.setListener(*State, managerListener, &state);
}

fn managerListener(_: *zwlr.ForeignToplevelManagerV1, event: zwlr.ForeignToplevelManagerV1.Event, s: *State) void {
    switch (event) {
        .toplevel => |ev| {
            const toplevel = s.gpa.create(Toplevel) catch return ev.toplevel.destroy();
            toplevel.* = .{};
            ev.toplevel.setListener(*Toplevel, handleListener, toplevel);
        },
        .finished => {},
    }
}

fn handleListener(handle: *zwlr.ForeignToplevelHandleV1, event: zwlr.ForeignToplevelHandleV1.Event, toplevel: *Toplevel) void {
    switch (event) {
        .title => |ev| {
            const title = state.gpa.dupe(u8, std.mem.span(ev.title)) catch return;
            state.gpa.free(toplevel.title);
            toplevel.title = title;
        },
        .state => |ev| {
            const activated = @backingInt(zwlr.ForeignToplevelHandleV1.State.activated);
            toplevel.pending_activated = std.mem.indexOfScalar(u32, ev.state.slice(u32), activated) != null;
        },
        .done => {
            const previous = state.active;
            if (toplevel.pending_activated and !toplevel.activated) {
                state.active = toplevel;
            } else if (!toplevel.pending_activated and state.active == toplevel) {
                state.active = null;
            }
            toplevel.activated = toplevel.pending_activated;
            if (state.active != previous or state.active == toplevel) state.changed = true;
        },
        .closed => {
            if (state.active == toplevel) {
                state.active = null;
                state.changed = true;
            }
            state.gpa.free(toplevel.title);
            state.gpa.destroy(toplevel);
            handle.destroy();
        },
        else => {},
    }
}
