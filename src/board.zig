const std = @import("std");
const piece = @import("piece.zig");

pub const Board = struct {
    piece_arr: [64]piece.Piece,
};

fn indFromRankFile(rank: u8, file: u8) usize {
    return (rank * 8) + file;
}

fn rankFromInd(ind: usize) u8 {
    return ind / 8;
}

fn fileFromInd(ind: usize) u8 {
    return ind % 8;
}

pub const start_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
/// Returns a board from the given FEN notation string
/// null if the string is an invalid FEN string
pub fn boardFromFen(fen: []const u8) ?Board {
    var piece_arr: [64]piece.Piece = [_]piece.Piece{piece.pieceInit(piece.PieceType.None, piece.Side.White)} ** 64;

    var rank: u16 = 0;
    var file: u16 = 0;
    for (fen) |fenchar| {
        // std.debug.print("rank: {}\tfile: {}\t", .{rank, file});
        // '/' skips to the next rank
        if (fenchar == '/') {
            file = 0;
            rank += 1;
            // std.debug.print("Skipping to rank {} file {}\n", .{rank, file});
            continue;
        } else if (fenchar == ' ') {
            // std.debug.print("Finishing FEN string\n", .{});
            break;
        }
        if (fenchar > 47 and fenchar < 57) {
            file += fenchar - 48;
            continue;
        }

        const Side = piece.Side;
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
        // std.debug.print("rank: {}\tfile: {}\tpiece: {c}\n", .{rank, file, fenchar});
        piece_arr[file + (rank * 8)] = piece.pieceInit(piece_type, side);
        file += 1;
    }

    return Board{
        .piece_arr = piece_arr,
    };
}

fn fenFromBoard(_: Board) []const u8 {}
