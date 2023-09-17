const std = @import("std");
const piece = @import("piece.zig");
const board = @import("board.zig");
const client = @import("client.zig");

pub const ChessGame = struct {
    const Self = @This();

    chessboard: board.Board,
    client_white: *client.ClientState,
    client_black: *client.ClientState,

    pub fn init() Self {
        return Self{
            .chessboard = board.Board.initFromFen(board.test_fen).?,
            .client_white = undefined,
            .client_black = undefined,
        };
    }

    pub fn addClients(self: *Self, client_white: *client.ClientState, client_black: *client.ClientState) void {
        self.client_white = client_white;
        self.client_black = client_black;
    }

    pub fn makeMove(self: *Self, move: Move) void {
        self.chessboard.makeMove(move);
        switch (self.chessboard.side) {
            Side.White => {
                self.client_white.allowToMove();
            },
            Side.Black => {
                self.client_black.allowToMove();
            },
        }
    }

    pub fn isValidPiece(self: *const Self, ind: u8) bool {
        const piece_selected = self.chessboard.piece_arr[ind];
        if (piece.PieceType.getPieceType(piece_selected) == piece.PieceType.None) {
            return false;
        }
        const piece_side = piece.PieceSide.getPieceSide(piece_selected);
        // std.debug.print("Piece: {b}\tSide: {}\n", .{piece_selected, piece_side});
        return (self.chessboard.side == Side.White and piece_side == piece.PieceSide.White) or (self.chessboard.side == Side.Black and piece_side == piece.PieceSide.Black);
    }
};

// Combine with the Side enum in piece.zig
pub const Side = enum { White, Black };

// 64 possible positions => 6 bits
// MSB, position from, position to, LSB
// 2 + 2 bits for good measure (and alignment)
pub const Move = u16;

pub fn moveFromPosInds(pos_from: u8, pos_to: u8) Move {
    return (@as(u16, @intCast(pos_from)) << 8) + pos_to;
    // return (pos_from << 8) + pos_to;
}

pub fn movePosFrom(move: Move) u8 {
    return @truncate(move >> 8);
}

pub fn movePosTo(move: Move) u8 {
    return @truncate(move);
}
