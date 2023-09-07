const std = @import("std");
const gl = @cImport({
    // Disables GLFW's inclusion of GL libraries
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
    @cInclude("glad/glad.h");
});
const img = @cImport({
    @cInclude("stb_image.h");
});
const render = @import("rendering/render.zig");
const shaders = @import("rendering/shaders.zig");

pub fn main() !void {
    const window = try render.windowInit();
    defer render.windowDeinit(window);

    const vert_shader = try render.createShader(render.ShaderType.Vertex, shaders.vert_shader_src);
    const frag_shader = try render.createShader(render.ShaderType.Fragment, shaders.frag_shader_src);
    const shader_program = try render.createShaderProgram(&[_]c_uint{ vert_shader, frag_shader });
    render.deleteShader(vert_shader);
    render.deleteShader(frag_shader);

    const texture = render.createTexture("assets/cburnett/p_white.png");
    _ = texture;

    const board_bufs = render.chessboard();

    while (render.windowIsRunning(window)) {
        // gl.glClearColor(0.11, 0.11, 0.14, 1.0);
        gl.glClearColor(0.35, 0.35, 0.35, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        gl.glUseProgram(shader_program);
        gl.glBindVertexArray(board_bufs.VAO);
        gl.glDrawElements(gl.GL_TRIANGLES, render.chessboard_inds_len, gl.GL_UNSIGNED_INT, null);

        gl.glfwSwapBuffers(window);
        gl.glfwPollEvents();
    }
}
