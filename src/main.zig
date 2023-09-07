const std = @import("std");

const gl = @cImport({
    // Disables GLFW's inclusion of GL libraries
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
    // @cInclude("GL/glew.h");
    @cInclude("glad/glad.h");
});

const RenderError = error{
    WindowInitError,
    WindowCreationError,
    GLInitError,
};

pub fn main() !void {
    const glfw_init_res = gl.glfwInit();
    if (glfw_init_res == 0) {
        return RenderError.WindowInitError;
    }
    defer gl.glfwTerminate();

    const window = gl.glfwCreateWindow(512, 512, "Chess", null, null);
    if (window == null) {
        return RenderError.WindowCreationError;
    }
    defer gl.glfwDestroyWindow(window);

    gl.glfwMakeContextCurrent(window);

    while (gl.glfwWindowShouldClose(window) == 0) {
        gl.glfwSwapBuffers(window);
        gl.glfwPollEvents();
    }
}
