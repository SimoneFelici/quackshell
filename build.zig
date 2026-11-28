const std = @import("std");
const Scanner = @import("wayland").Scanner;

pub const Module = enum { time, window_title, workspaces };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const modules = b.option([]const u8, "modules", "Comma separated modules to compile");

    const options = b.addOptions();
    inline for (comptime std.enums.values(Module)) |m| {
        options.addOption(bool, @tagName(m), enabled(modules, m));
    }

    // Wayland
    const wayland_protocols = b.dependency("wayland_protocols", .{});
    const wlr_protocols = b.dependency("wlr_protocols", .{});

    const scanner = Scanner.create(b, .{ .wayland_protocols = wayland_protocols.path("") });
    const wayland = b.createModule(.{ .root_source_file = scanner.result });

    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
    scanner.addCustomProtocol(wlr_protocols.path("unstable/wlr-layer-shell-unstable-v1.xml"));

    scanner.generate("wl_compositor", 7);
    scanner.generate("wl_output", 4);
    scanner.generate("wl_shm", 3);
    scanner.generate("xdg_wm_base", 3);
    scanner.generate("zwlr_layer_shell_v1", 5);

    if (enabled(modules, .window_title)) {
        scanner.addCustomProtocol(wlr_protocols.path("unstable/wlr-foreign-toplevel-management-unstable-v1.xml"));
        scanner.generate("zwlr_foreign_toplevel_manager_v1", 3);
    }
    if (enabled(modules, .workspaces)) {
        scanner.addSystemProtocol("staging/ext-workspace/ext-workspace-v1.xml");
        scanner.generate("ext_workspace_manager_v1", 1);
    }

    const z2d = b.dependency("z2d", .{
        .target = target,
        .optimize = optimize,
    }).module("z2d");

    const known_folders = b.dependency("known_folders", .{
        .target = target,
        .optimize = optimize,
    }).module("known-folders");

    const zeit = if (enabled(modules, .time)) b.lazyDependency("zeit", .{
        .target = target,
        .optimize = optimize,
    }) else null;

    // const goose = b.dependency("goose", .{
    //     .target = target,
    //     .optimize = optimize,
    // }).module("goose");

    const exe = b.addExecutable(.{
        .name = "quackshell",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        // .use_llvm = true,
    });

    exe.root_module.addImport("wayland", wayland);
    exe.root_module.addImport("z2d", z2d);
    exe.root_module.addImport("known_folders", known_folders);
    if (zeit) |dep| exe.root_module.addImport("zeit", dep.module("zeit"));
    // exe.root_module.addImport("goose", goose);

    exe.root_module.addOptions("build_options", options);
    exe.root_module.linkSystemLibrary("wayland-client", .{});
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
}

fn enabled(modules: ?[]const u8, m: Module) bool {
    const list = modules orelse return true;
    var it = std.mem.splitScalar(u8, list, ',');
    while (it.next()) |name| {
        if (std.mem.eql(u8, name, @tagName(m))) return true;
    }
    return false;
}
