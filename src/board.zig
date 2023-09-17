const std = @import("std");
const piece = @import("piece.zig");
const chess = @import("chess.zig");

pub const start_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
pub const test_fen = "rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2";

pub const Board = struct {
    const Self = @This();

    // Stored in rank-major order
    piece_arr: [64]piece.Piece,
    side: chess.Side,

    pub fn initFromFen(fen: []const u8) ?Board {
        var piece_arr: [64]piece.Piece = [_]piece.Piece{piece.pieceNone()} ** 64;

        var x: u8 = 0;
        var y: u8 = 0;
        for (fen) |fenchar| {
            // std.debug.print("rank: {}\tfile: {}\t", .{rank, file});
            // '/' skips to the next rank
            if (fenchar == '/') {
                x = 0;
                y += 1;
                // std.debug.print("Skipping to rank {} file {}\n", .{rank, file});
                continue;
            } else if (fenchar == ' ') {
                // std.debug.print("Finishing FEN string\n", .{});
                break;
            }
            if (fenchar > 47 and fenchar < 57) {
                x += fenchar - 48;
                continue;
            }

            const Side = piece.PieceSide;
            const Type = piece.PieceType;
            const side: Side = if (fenchar < 91) Side.White else Side.Black;
            // converts all letters to uppercase
            const piece_char = if (fenchar > 96) fenchar - 32 else fenchar;
            const piece_type: piece.PieceType = switch (piece_char) {
                'K' => Type.King,
                'Q' => Type.Queen,
                'R' => Type.Rook,
                'N' => Type.Knight,
                'B' => Type.Bishop,
                'P' => Type.Pawn,
                else => return null,
            };
            // std.debug.print("x: {}\ty: {}\tpiece: {c}\tind: {}\n", .{x, y, fenchar, indFromXY(x, y)});
            piece_arr[indFromXY(x, y)] = piece.pieceInit(piece_type, side);
            x += 1;
        }

        return Board{
            .piece_arr = piece_arr,
            .side = chess.Side.White,
        };
    }

    /// Returns a board from the given FEN notation string
    /// null if the string is an invalid FEN string
    fn fenFromBoard(_: Board) []const u8 {}

    pub fn makeMove(self: *Self, move: chess.Move) void {
        const from = chess.movePosFrom(move);
        const to = chess.movePosTo(move);
        self.piece_arr[to] = self.piece_arr[from];
        self.piece_arr[from] = piece.pieceNone();
        self.side = switch(self.side) {
            chess.Side.White => chess.Side.Black,
            chess.Side.Black => chess.Side.White,
        };
    }
};

/// Index from Rank, File coordinates
/// Counted from the bottom left
pub fn indFromRankFile(rank: u8, file: u8) u8 {
    return (rank * 8) + file;
}

/// Index from X, Y coordinates
/// Counted from the top left
pub fn indFromXY(x: u8, y: u8) u8 {
    return ((7 - y) * 8) + x;
}

fn rankFromInd(ind: usize) u8 {
    return ind / 8;
}

fn fileFromInd(ind: usize) u8 {
    return ind % 8;
}
