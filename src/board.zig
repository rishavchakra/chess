const std = @import("std");
const piece = @import("piece.zig");
const chess = @import("chess.zig");
const bitboard = @import("bitboard.zig");
const Allocator = std.mem.Allocator;

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
        self.side = switch (self.side) {
            chess.Side.White => chess.Side.Black,
            chess.Side.Black => chess.Side.White,
        };
    }

    // Get all possible moves for a piece at a given index
    // Currently only used GUI-clientside so doesn't have to be all that optimized
    pub fn getMovesAtInd(self: *const Self, alloc: Allocator, ind: u8) !?std.ArrayList(chess.Move) {
        const getPieceSide = piece.PieceSide.getPieceSide;
        const getPieceType = piece.PieceType.getPieceType;

        const sel_piece = self.piece_arr[ind];
        const piece_side = getPieceSide(sel_piece);
        const piece_type = getPieceType(sel_piece);
        var move_list = std.ArrayList(chess.Move).init(alloc);
        switch (piece_type) {
            .None => return null,
            .Pawn => {
                var first_rank: u8 = if (piece_side == .White) 1 else 6;
                var next_rank = if (piece_side == .White) ind + 8 else ind - 8;
                var skip_rank = if (piece_side == .White) ind + 16 else ind - 16;
                // Regular move
                if (getPieceType(self.piece_arr[next_rank]) == .None) {
                    try move_list.append(chess.moveFromPosInds(ind, next_rank));
                    // Double move from first rank
                    if (rankFromInd(ind) == first_rank and getPieceType(self.piece_arr[skip_rank]) == .None) {
                        try move_list.append(chess.moveFromPosInds(ind, skip_rank));
                    }
                }
                // Attacking diagonals
                if (fileFromInd(ind) < 7) {
                    var atk_diag_right = if (piece_side == .White) ind + 9 else ind - 7;
                    if (fileFromInd(ind) < 7 and getPieceType(self.piece_arr[atk_diag_right]) != .None and getPieceSide(self.piece_arr[atk_diag_right]) != piece_side) {
                        try move_list.append(chess.moveFromPosInds(ind, atk_diag_right));
                    }
                }
                if (fileFromInd(ind) > 0) {
                    var atk_diag_left = if (piece_side == .White) ind + 7 else ind - 9;
                    if (getPieceType(self.piece_arr[atk_diag_left]) != .None and getPieceSide(self.piece_arr[atk_diag_left]) != piece_side)
                    try move_list.append(chess.moveFromPosInds(ind, atk_diag_left));
                }
            },
            .Knight => {
                if (rankFromInd(ind) > 1) {
                    if (fileFromInd(ind) > 0 and (getPieceType(self.piece_arr[ind - 17]) == .None or getPieceSide(self.piece_arr[ind - 17]) != piece_side)) {
                        // 2 down 1 left
                        try move_list.append(chess.moveFromPosInds(ind, ind - 17));
                    }
                    if (fileFromInd(ind) < 7 and (getPieceType(self.piece_arr[ind - 15]) == .None or getPieceSide(self.piece_arr[ind - 15]) != piece_side)) {
                        // 2 down 1 right
                        try move_list.append(chess.moveFromPosInds(ind, ind - 15));
                    }
                }
                if (rankFromInd(ind) < 6) {
                    if (fileFromInd(ind) > 0 and (getPieceType(self.piece_arr[ind + 15]) == .None or getPieceSide(self.piece_arr[ind + 15]) != piece_side)) {
                        // 2 up 1 left
                        try move_list.append(chess.moveFromPosInds(ind, ind + 15));
                    }
                    if (fileFromInd(ind) < 7 and (getPieceType(self.piece_arr[ind + 17]) == .None or getPieceSide(self.piece_arr[ind + 17]) != piece_side)) {
                        // 2 up 1 left
                        try move_list.append(chess.moveFromPosInds(ind, ind + 17));
                    }
                }
                if (rankFromInd(ind) > 0) {
                    if (fileFromInd(ind) > 1 and (getPieceType(self.piece_arr[ind - 10]) == .None or getPieceSide(self.piece_arr[ind - 10]) != piece_side)) {
                        // 2 left 1 down
                        try move_list.append(chess.moveFromPosInds(ind, ind - 10));
                    }
                    if (fileFromInd(ind) < 6 and (getPieceType(self.piece_arr[ind - 6]) == .None or getPieceSide(self.piece_arr[ind - 6]) != piece_side)) {
                        // 2 right 1 down
                        try move_list.append(chess.moveFromPosInds(ind, ind - 6));
                    }
                }
                if (rankFromInd(ind) < 7) {
                    if (fileFromInd(ind) > 1 and (getPieceType(self.piece_arr[ind + 6]) == .None or getPieceSide(self.piece_arr[ind + 6]) != piece_side)) {
                        // 2 left 1 up
                        try move_list.append(chess.moveFromPosInds(ind, ind + 6));
                    }
                    if (fileFromInd(ind) < 6 and (getPieceType(self.piece_arr[ind + 10]) == .None or getPieceSide(self.piece_arr[ind + 10]) != piece_side)) {
                        // 2 right 1 up
                        try move_list.append(chess.moveFromPosInds(ind, ind + 10));
                    }
                }
            },
            .King => {
                const down = rankFromInd(ind) > 0;
                const up = rankFromInd(ind) < 7;
                const left = fileFromInd(ind) > 0;
                const right = fileFromInd(ind) < 7;
                if (up and (getPieceType(self.piece_arr[ind + 8]) == .None or getPieceSide(self.piece_arr[ind + 8]) != piece_side)) {
                    try move_list.append(chess.moveFromPosInds(ind, ind + 8));
                }
                if (down and (getPieceType(self.piece_arr[ind - 8]) == .None or getPieceSide(self.piece_arr[ind - 8]) != piece_side)) {
                    try move_list.append(chess.moveFromPosInds(ind, ind - 8));
                }
                if (right and (getPieceType(self.piece_arr[ind + 1]) == .None or getPieceSide(self.piece_arr[ind + 1]) != piece_side)) {
                    try move_list.append(chess.moveFromPosInds(ind, ind + 1));
                }
                if (left and (getPieceType(self.piece_arr[ind - 1]) == .None or getPieceSide(self.piece_arr[ind - 1]) != piece_side)) {
                    try move_list.append(chess.moveFromPosInds(ind, ind - 1));
                }
                if (up and right and (getPieceType(self.piece_arr[ind + 9]) == .None or getPieceSide(self.piece_arr[ind + 9]) != piece_side)) {
                    try move_list.append(chess.moveFromPosInds(ind, ind + 9));
                }
                if (up and left and (getPieceType(self.piece_arr[ind + 7]) == .None or getPieceSide(self.piece_arr[ind + 7]) != piece_side)) {
                    try move_list.append(chess.moveFromPosInds(ind, ind + 7));
                }
                if (down and right and (getPieceType(self.piece_arr[ind - 7]) == .None or getPieceSide(self.piece_arr[ind - 7]) != piece_side)) {
                    try move_list.append(chess.moveFromPosInds(ind, ind - 7));
                }
                if (down and left and (getPieceType(self.piece_arr[ind - 9]) == .None or getPieceSide(self.piece_arr[ind - 9]) != piece_side)) {
                    try move_list.append(chess.moveFromPosInds(ind, ind - 9));
                }
            },
            else => { // Sliding pieces
                const from_file = fileFromInd(ind);
                if (piece_type != .Rook) {
                    var trace_ind: u8 = ind + 7;
                    while (trace_ind < 64 and fileFromInd(trace_ind) < from_file) : (trace_ind += 7) {
                        if (getPieceType(self.piece_arr[trace_ind]) != .None) {
                            if (getPieceSide(self.piece_arr[trace_ind]) != piece_side) {
                                try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                            }
                            break;
                        }
                        try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                    }
                    // Up-right
                    trace_ind = ind + 9;
                    while (trace_ind < 64 and fileFromInd(trace_ind) > from_file) : (trace_ind += 9) {
                        if (getPieceType(self.piece_arr[trace_ind]) != .None) {
                            if (getPieceSide(self.piece_arr[trace_ind]) != piece_side) {
                                try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                            }
                            break;
                        }
                        try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                    }
                    // Downward tracing is checked with u8 overflow/wraparound
                    // if the tracing index is close to the u8 max (above 64) then tracing is finished
                    // Down-right
                    trace_ind = ind -% 7;
                    while (trace_ind < 64 and fileFromInd(trace_ind) > from_file) : (trace_ind -%= 7) {
                        if (getPieceType(self.piece_arr[trace_ind]) != .None) {
                            if (getPieceSide(self.piece_arr[trace_ind]) != piece_side) {
                                try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                            }
                            break;
                        }
                        try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                    }
                    // Down-left
                    trace_ind = ind -% 9;
                    while (trace_ind < 64 and fileFromInd(trace_ind) < from_file) : (trace_ind -%= 9) {
                        if (getPieceType(self.piece_arr[trace_ind]) != .None) {
                            if (getPieceSide(self.piece_arr[trace_ind]) != piece_side) {
                                try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                            }
                            break;
                        }
                        try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                    }
                }

                if (piece_type != .Bishop) { // straights
                    var trace_ind: u8 = ind + 8;
                    // Up
                    while (trace_ind < 64) : (trace_ind += 8) {
                        if (getPieceType(self.piece_arr[trace_ind]) != .None) {
                            if (getPieceSide(self.piece_arr[trace_ind]) != piece_side) {
                                try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                            }
                            break;
                        }
                        try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                    }
                    // Right
                    trace_ind = ind + 1;
                    while (fileFromInd(trace_ind) > from_file) : (trace_ind += 1) {
                        if (getPieceType(self.piece_arr[trace_ind]) != .None) {
                            if (getPieceSide(self.piece_arr[trace_ind]) != piece_side) {
                                try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                            }
                            break;
                        }
                        try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                    }
                    // Downward tracing is checked with u8 overflow/wraparound
                    // if the tracing index is close to the u8 max (above 64) then tracing is finished
                    // Down
                    trace_ind = ind -% 8;
                    while (trace_ind < 64) : (trace_ind -%= 8) {
                        if (getPieceType(self.piece_arr[trace_ind]) != .None) {
                            if (getPieceSide(self.piece_arr[trace_ind]) != piece_side) {
                                try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                            }
                            break;
                        }
                        try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                    }
                    // Left
                    trace_ind = ind -% 1;
                    while (fileFromInd(trace_ind) < from_file) : (trace_ind -%= 1) {
                        if (getPieceType(self.piece_arr[trace_ind]) != .None) {
                            if (getPieceSide(self.piece_arr[trace_ind]) != piece_side) {
                                try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                            }
                            break;
                        }
                        try move_list.append(chess.moveFromPosInds(ind, trace_ind));
                    }

                }
            },
        }
        return move_list;
    }

    // Get all possible moves for all pieces of a given side
    // Must be fast
    pub fn getAllMoves(self: *const Self, alloc: Allocator, side: chess.Side) !?std.ArrayList(chess.Move) {
        _ = side;
        _ = alloc;
        _ = self;
        return null;
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

fn rankFromInd(ind: u8) u8 {
    return ind / 8;
}

fn fileFromInd(ind: u8) u8 {
    return ind % 8;
}
