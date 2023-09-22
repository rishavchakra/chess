const std = @import("std");
const gl = @cImport({
    // Disables GLFW's inclusion of GL libraries
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
    @cInclude("glad/glad.h");
});
const render = @import("rendering/render.zig");
const board = @import("board.zig");
const chess = @import("chess.zig");
const client = @import("client.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    var gpa = general_purpose_allocator.allocator();

    const window = try render.WindowState.init();
    defer window.deinit();

    const render_state = try render.RenderState.init();
    var client_white = client.ClientState.initWhite(gpa);
    var client_black = client.ClientState.initBlack(gpa);
    var game_state = chess.ChessGame.init();
    game_state.addClients(&client_white, &client_black);
    client_white.addToGame(&game_state);
    client_white.addRenderer(&render_state);
    client_black.addToGame(&game_state);
    client_black.addRenderer(&render_state);

    while (window.isRunning()) {
        render_state.updatePiecePositions(game_state.chessboard);
        render_state.render();

        // Not going to work! This runs for every tick the mouse button is down
        // Could write monopulsing code but...
        // Just use the callback!
        // const glfwMouseCB = gl.glfwSetMouseButtonCallback(window.window_handle, mouseCallback);
        // Never mind! The callback sucks!
        try client_white.getMouseInput(&window);
        try client_black.getMouseInput(&window);
        // const click_state: c_int = gl.glfwGetMouseButton(window.window_handle, gl.GLFW_MOUSE_BUTTON_LEFT);
        // if (click_state == gl.GLFW_PRESS) {
        //     var mousex: f64 = undefined;
        //     var mousey: f64 = undefined;
        //     gl.glfwGetCursorPos(window.window_handle, &mousex, &mousey);
        //     // std.debug.print("Click: ({}, {})\n", .{mousex, mousey});
        // }

        window.draw();
    }
}
