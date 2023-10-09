const gl = @cImport({
    // Disables GLFW's inclusion of GL libraries
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
    @cInclude("glad/glad.h");
});
const std = @import("std");
const render = @import("rendering/render.zig");
const game = @import("game.zig");
const chess = @import("chess.zig");

// pub const Client = union(enum) {
//     player: GuiClient,
//     // bot: bot_client.BotClient,
// };

pub const GuiClient = struct {
    const Self = @This();

    const ClientState = enum {
        Idle,
        PieceDragging,
        PieceSelected,
        PieceDestSelected,
        WaitingForOpp,
    };

    client_state: ClientState,
    renderer: *const render.RenderState,
    window_state: *const render.WindowState,
    chess_game: *game.Game,
    side: chess.Side,
    selected_piece_ind: chess.PosInd,

    pub fn init(renderer: *const render.RenderState, window: *const render.WindowState, side: chess.Side) Self {
        return Self{
            .client_state = .WaitingForOpp,
            .renderer = renderer,
            .window_state = window,
            .chess_game = undefined,
            .side = side,
            .selected_piece_ind = undefined,
        };
    }

    pub fn addToGame(self: *Self, chess_game: *game.Game) void {
        self.chess_game = chess_game;
    }

    pub fn requestMove(self: *Self) void {
        self.client_state = .Idle;
    }

    pub fn tickUpdate(self: *Self) void {
        const click_state: c_int = gl.glfwGetMouseButton(self.window_state.window_handle, gl.GLFW_MOUSE_BUTTON_LEFT);

        const mouse_pos = self.getMouseRankFile();
        const mouse_pos_ind = mouse_pos.toInd();

        switch (self.client_state) {
            .Idle => {
                if (click_state == gl.GLFW_PRESS) {
                    //check if the clicked board item is the right side
                    if (true) {
                        self.selected_piece_ind = mouse_pos_ind;
                        self.client_state = .PieceDragging;
                        // std.debug.print("idle->press\n", .{});
                    }
                }
            },
            .PieceDragging => {
                if (click_state == gl.GLFW_RELEASE) {
                    // dropped back on starting square
                    if (self.selected_piece_ind.ind == mouse_pos_ind.ind) {
                        self.client_state = .PieceSelected;
                        // std.debug.print("drag->in place\n", .{});
                    } else {
                        // check if dragged to a valid move
                        const move = chess.Move.init(self.selected_piece_ind, mouse_pos_ind);
                        if (self.chess_game.isValidMove(move)) {
                            // Make the move
                            self.chess_game.makeMove(move);
                            self.client_state = .WaitingForOpp;
                            // std.debug.print("drag->move\n", .{});
                        } // Maybe: cancel move altogether if not a valid move
                    } // mouse position checking
                } // mouse button unpressed
            },
            .PieceSelected => {
                if (click_state == gl.GLFW_PRESS) {
                    self.client_state = .PieceDestSelected;
                }
            },
            .PieceDestSelected => {
                if (click_state == gl.GLFW_RELEASE) {
                    // Make the move
                    const move = chess.Move.init(self.selected_piece_ind, mouse_pos_ind);
                    if (self.chess_game.isValidMove(move)) {
                        self.chess_game.makeMove(move);
                        self.client_state = .WaitingForOpp;
                        // std.debug.print("selected->move\n", .{});
                    } else {
                        self.client_state = .Idle;
                        // std.debug.print("selected->deselected\n", .{});
                    }
                }
            },
            .WaitingForOpp => {}
        }
    }

    fn getMouseRankFile(self: *Self) chess.PosRankFile {
        var mousex: f64 = undefined;
        var mousey: f64 = undefined;
        gl.glfwGetCursorPos(self.window_state.window_handle, &mousex, &mousey);

        // Prevent negative zero errors
        mousex = @max(0.0, mousex);
        mousey = @max(0.0, mousey);

        var window_width: i32 = undefined;
        var window_height: i32 = undefined;
        gl.glfwGetWindowSize(self.window_state.window_handle, &window_width, &window_height);

        const square_width: u32 = @as(u32, @intCast(window_width)) / 8;
        const square_height: u32 = @as(u32, @intCast(window_height)) / 8;

        const in_square_x: u3 = @truncate(@as(u32, @intFromFloat(mousex)) / square_width);
        const in_square_y: u3 = @truncate(@as(u32, @intFromFloat(mousey)) / square_height);

        return chess.PosRankFile.init(7 - in_square_y, in_square_x);
    }
};
