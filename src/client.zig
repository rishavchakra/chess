const std = @import("std");
const gl = @cImport({
    // Disables GLFW's inclusion of GL libraries
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
    @cInclude("glad/glad.h");
});
const render = @import("rendering/render.zig");
const chess = @import("chess.zig");
const board = @import("board.zig");
const bitboard = @import("bitboard.zig");

pub const ClientState = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    mouse_is_down: bool,
    allow_mouse_click: bool,
    move_state: ClientMoveState,
    chess_game: *chess.ChessGame,
    renderer: *const render.RenderState,
    pending_move_from: u8,

    pub fn initWhite(alloc: std.mem.Allocator) Self {
        return Self{
            .allocator = alloc,
            .mouse_is_down = false,
            .allow_mouse_click = false,
            .move_state = ClientMoveState.WaitingMoveFrom,
            .chess_game = undefined,
            .renderer = undefined,
            .pending_move_from = undefined,
        };
    }

    pub fn initBlack(alloc: std.mem.Allocator) Self {
        return Self{
            .allocator = alloc,
            .mouse_is_down = false,
            .allow_mouse_click = false,
            .move_state = ClientMoveState.WaitingOppMove,
            .chess_game = undefined,
            .renderer = undefined,
            .pending_move_from = undefined,
        };
    }

    pub fn addToGame(self: *Self, chess_game: *chess.ChessGame) void {
        self.chess_game = chess_game;
    }

    pub fn addRenderer(self: *Self, renderer: *const render.RenderState) void {
        self.renderer = renderer;
    }

    pub fn getMouseInput(self: *Self, window: *const render.WindowState) !void {
        if (self.move_state == ClientMoveState.WaitingOppMove) {
            return;
        }
        const click_state: c_int = gl.glfwGetMouseButton(window.window_handle, gl.GLFW_MOUSE_BUTTON_LEFT);
        if (!self.mouse_is_down and click_state == gl.GLFW_PRESS) {
            self.mouse_is_down = true;
            var mousex: f64 = undefined;
            var mousey: f64 = undefined;
            gl.glfwGetCursorPos(window.window_handle, &mousex, &mousey);
            // std.debug.print("Click: ({d}, {d})\n", .{ mousex, mousey });

            var window_width: i32 = undefined;
            var window_height: i32 = undefined;
            gl.glfwGetWindowSize(window.window_handle, &window_width, &window_height);

            // For using squares that are actually square
            _ = if (window_width < window_height) window_width else window_height;

            const square_width: u32 = @as(u32, @intCast(window_width)) / 8;
            const square_height: u32 = @as(u32, @intCast(window_height)) / 8;

            const in_square_x: u8 = @truncate(@as(u32, @intFromFloat(mousex)) / square_width);
            const in_square_y: u8 = @truncate(@as(u32, @intFromFloat(mousey)) / square_height);

            const click_board_ind = board.indFromXY(in_square_x, in_square_y);
            // std.debug.print("Square: ({}, {})\tInd: {}\n", .{ in_square_x, in_square_y, click_board_ind });
            switch (self.move_state) {
                ClientMoveState.WaitingMoveFrom => {
                    if (self.chess_game.isValidPiece(click_board_ind)) {
                        self.move_state = ClientMoveState.WaitingMoveTo;
                        self.pending_move_from = click_board_ind;

                        // Find and render move list
                        const move_list = (try self.chess_game.chessboard.getMovesAtInd(self.allocator, click_board_ind)).?;
                        defer move_list.deinit();
                        const moves_bitboard = bitboard.Bitboard.initFromMoveList(move_list);
                        self.renderer.updateBitboardDisplay(moves_bitboard);
                    }
                },
                ClientMoveState.WaitingMoveTo => {
                    const move = chess.moveFromPosInds(self.pending_move_from, click_board_ind);
                    // Attempting to click on your own piece - should select this new piece
                    if (self.chess_game.isValidPiece(click_board_ind)) {
                        self.pending_move_from = click_board_ind;

                        // Find and re-render move list
                        const move_list = (try self.chess_game.chessboard.getMovesAtInd(self.allocator, click_board_ind)).?;
                        defer move_list.deinit();
                        const moves_bitboard = bitboard.Bitboard.initFromMoveList(move_list);
                        self.renderer.updateBitboardDisplay(moves_bitboard);
                    } else {
                        self.move_state = ClientMoveState.WaitingOppMove;
                        self.chess_game.makeMove(move);
                        self.renderer.updateBitboardDisplay(bitboard.Bitboard.empty());
                    }
                },
                ClientMoveState.WaitingOppMove => {},
            }
        } else if (click_state == gl.GLFW_RELEASE) {
            self.mouse_is_down = false;
            self.allow_mouse_click = true;
        }
    }

    pub fn allowToMove(self: *Self) void {
        self.move_state = ClientMoveState.WaitingMoveFrom;
        self.allow_mouse_click = false;
    }
};

const ClientMoveState = enum {
    WaitingMoveFrom,
    WaitingMoveTo,
    WaitingOppMove,
};
