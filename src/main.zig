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
const board = @import("board.zig");

pub fn main() !void {
    const window = try render.windowInit();
    defer render.windowDeinit(window);

    const board_vert_shader = try render.createShader(render.ShaderType.Vertex, shaders.board_vert_shader_src);
    const board_frag_shader = try render.createShader(render.ShaderType.Fragment, shaders.board_frag_shader_src);
    const board_shader_program = try render.createShaderProgram(&[_]c_uint{ board_vert_shader, board_frag_shader });
    render.deleteShader(board_vert_shader);
    render.deleteShader(board_frag_shader);

    const piece_vert_shader = try render.createShader(render.ShaderType.Vertex, shaders.piece_vert_shader_src);
    const piece_frag_shader = try render.createShader(render.ShaderType.Fragment, shaders.piece_frag_shader_src);
    const piece_shader_program = try render.createShaderProgram(&[_]c_uint{ piece_vert_shader, piece_frag_shader });
    render.deleteShader(piece_vert_shader);
    render.deleteShader(piece_frag_shader);
    const texture = render.createTexture("assets/pieces-png/black-king.png");

    const board_bufs = render.createChessboard();
    const piece_bufs = render.createPieceBufs();

    const game_board = board.boardFromFen(board.start_fen).?;
    render.updatePieceBufs(piece_bufs, game_board);
    // std.debug.print("{any}\n", .{game_board.piece_arr});

    gl.glClearColor(0.35, 0.35, 0.35, 1.0);

    while (render.windowIsRunning(window)) {
        // gl.glClearColor(0.11, 0.11, 0.14, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        gl.glUseProgram(board_shader_program);
        gl.glBindVertexArray(board_bufs.VAO);
        gl.glDrawElements(gl.GL_TRIANGLES, render.chessboard_inds_len, gl.GL_UNSIGNED_INT, null);
        // gl.glBindVertexArray(0);

        gl.glUseProgram(piece_shader_program);
        gl.glBindTexture(gl.GL_TEXTURE_2D, texture);
        gl.glBindVertexArray(piece_bufs.VAO);
        // gl.glDrawArrays(gl.GL_TRIANGLES, 0, render.pieces_verts_len);
        gl.glDrawElements(gl.GL_TRIANGLES, render.pieces_inds_len, gl.GL_UNSIGNED_INT, null);
        gl.glBindVertexArray(0);

        gl.glfwSwapBuffers(window);
        gl.glfwPollEvents();
    }
}
