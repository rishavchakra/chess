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
// const client = @import("player_client.zig");
const clients = @import("client.zig");
const chess = @import("chess.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    var gpa = general_purpose_allocator.allocator();
    _ = gpa;

    const window = try render.WindowState.init();
    defer window.deinit();
    const render_state = try render.RenderState.init();

    var game_state = game.Game.init(&render_state);

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
