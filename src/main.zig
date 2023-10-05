const std = @import("std");
const gl = @cImport({
    // Disables GLFW's inclusion of GL libraries
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
    @cInclude("glad/glad.h");
});
const render = @import("rendering/render.zig");
const board = @import("board.zig");
const game = @import("game.zig");
const client = @import("player_client.zig");
const clients = @import("clients.zig");
const chess = @import("chess.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    var gpa = general_purpose_allocator.allocator();
    _ = gpa;

    var game_state = game.Game.init();
    const window = try render.WindowState.init();
    defer window.deinit();
    const render_state = try render.RenderState.init();

    var client_white = clients.GuiClient.init(&render_state, &window, .White);
    var client_black = clients.GuiClient.init(&render_state, &window, .Black);

    game_state.addClientWhite(&client_white);
    game_state.addClientBlack(&client_black);

    render_state.updatePiecePositions(game_state.chessboard);

    client_white.requestMove();

    while (window.isRunning()) {
        client_white.tickUpdate();
        client_black.tickUpdate();

        render_state.render();
        window.draw();
    }
}

pub fn main_old() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    var gpa = general_purpose_allocator.allocator();

    const window = try render.WindowState.init();
    defer window.deinit();

    const render_state = try render.RenderState.init();
    var client_white = client.PlayerClient.initWhite(gpa);
    var client_black = client.PlayerClient.initBlack(gpa);
    var game_state = game.Game.init();
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
