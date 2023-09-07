const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "chess",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const Path = std.Build.LazyPath;
    const CSrcFile = std.Build.Step.Compile.CSourceFile;
    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("GLEW");
    exe.addIncludePath(Path{ .path = "libs/glad/include" });
    exe.addCSourceFile(CSrcFile{ .file = Path{ .path = "libs/glad/src/glad.c" }, .flags = &[_][]const u8{"-std=c99"} });
    exe.addIncludePath(Path{ .path = "libs/stb_image"});
    exe.addCSourceFile(CSrcFile{ .file = Path{ .path = "libs/stb_image/stb_image_impl.c" }, .flags = &[_][]const u8{"-std=c99"} });
    exe.linkFramework("Cocoa");
    exe.linkFramework("OpenGL");
    exe.linkFramework("IOKit");
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    {
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}
