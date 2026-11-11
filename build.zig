const std = @import("std");
const Scanner = @import("wayland").Scanner;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Wayland
    const scanner = Scanner.create(b, .{});
    const wayland = b.createModule(.{ .root_source_file = scanner.result });
    const wlr_protocols = b.dependency("wlr-protocols", .{});

    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
    scanner.addCustomProtocol(wlr_protocols.path("unstable/wlr-layer-shell-unstable-v1.xml"));
    scanner.addCustomProtocol(wlr_protocols.path("unstable/wlr-foreign-toplevel-management-unstable-v1.xml"));

    scanner.generate("wl_compositor", 7);
    scanner.generate("wl_output", 4);
    scanner.generate("wl_shm", 3);
    scanner.generate("xdg_wm_base", 3);
    scanner.generate("zwlr_layer_shell_v1", 5);

    const z2d = b.dependency("z2d", .{
        .target = target,
        .optimize = optimize,
    }).module("z2d");

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
            .imports = &.{
                .{ .name = "wayland", .module = wayland },
                .{ .name = "z2d", .module = z2d },
                // .{ .name = "goose", .module = goose },
            },
        }),
        .use_llvm = true,
    });
    exe.root_module.linkSystemLibrary("wayland-client", .{});

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
}
