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
    piece_arr: [64]chess.Piece,
    side: chess.Side,
    castle_white_king: bool,
    castle_white_queen: bool,
    castle_black_king: bool,
    castle_black_queen: bool,
    en_passant: ?chess.PosInd,
    fifty_move: u8,
    full_move: u8,

    pub fn initFromFen(fen: []const u8) ?Board {
        const FenStage = enum {
            Pieces,
            Side,
            Castling,
            EnPassant,
            Halfmove,
            Fullmove,
        };

        var piece_arr: [64]chess.Piece = [_]chess.Piece{chess.Piece.none()} ** 64;
        var side: chess.Side = undefined;
        var castle_white_king = false;
        var castle_white_queen = false;
        var castle_black_king = false;
        var castle_black_queen = false;
        var en_passant_rank: u3 = 0;
        var en_passant_file: u3 = 0;
        var en_passant: ?chess.PosInd = null;
        var fifty_move_chars: [2]u8 = [2]u8{ 33, 33 };
        var fifty_move_char_num: u8 = 0;
        var fifty_move: u8 = 0;
        var full_move_chars: [3]u8 = [3]u8{ 33, 33, 33 };
        var full_move_char_num: u8 = 0;
        var full_move: u8 = 0;

        var pos: chess.PosRankFile = chess.PosRankFile.init(7, 0);
        var stage: FenStage = .Pieces;
        for (fen) |fenchar| {
            switch (stage) {
                .Pieces => { // '/' skips to the next rank
                    if (fenchar == '/') {
                        pos.rank -= 1;
                        pos.file = 0;
                        continue;
                    } else if (fenchar == ' ') {
                        stage = .Side;
                        continue;
                    }
                    // Number n => skip n spaces
                    if (fenchar > 47 and fenchar < 57) {
                        pos.file +%= @truncate(fenchar - 48);
                        continue;
                    }

                    // White if uppercase, Black if lowercase
                    const char_side: chess.Side = if (fenchar < 91) .White else .Black;
                    // converts all letters to uppercase
                    const piece_char = if (fenchar > 96) fenchar - 32 else fenchar;
                    const piece_type: chess.PieceType = switch (piece_char) {
                        'K' => .King,
                        'Q' => .Queen,
                        'R' => .Rook,
                        'N' => .Knight,
                        'B' => .Bishop,
                        'P' => .Pawn,
                        else => unreachable,
                    };
                    piece_arr[pos.toInd().ind] = chess.Piece.init(piece_type, char_side);
                    pos.file +%= 1;
                },
                .Side => {
                    switch (fenchar) {
                        'w' => side = .White,
                        'b' => side = .Black,
                        ' ' => stage = .Castling,
                        else => unreachable,
                    }
                },
                .Castling => {
                    switch (fenchar) {
                        '-' => {},
                        'K' => castle_white_king = true,
                        'Q' => castle_white_queen = true,
                        'k' => castle_black_king = true,
                        'q' => castle_black_queen = true,
                        ' ' => stage = .EnPassant,
                        else => unreachable,
                    }
                },
                .EnPassant => {
                    switch (fenchar) {
                        'a'...'h' => {
                            en_passant_file = @intCast(fenchar - 97);
                        },
                        '1'...'8' => {
                            en_passant_file = @intCast(fenchar - 48);
                        },
                        '-' => {
                            en_passant = null;
                        },
                        ' ' => {
                            if (en_passant_rank != 0) {
                                en_passant = chess.PosRankFile.init(en_passant_rank, en_passant_file).toInd();
                            }
                            stage = .Halfmove;
                        },
                        else => unreachable,
                    }
                },
                .Halfmove => {
                    switch (fenchar) {
                        '0'...'9' => {
                            if (fifty_move_chars[0] == '!') {
                                fifty_move_chars[0] = fenchar;
                                fifty_move_char_num = 1;
                            } else {
                                fifty_move_chars[1] = fenchar;
                                fifty_move_char_num = 2;
                            }
                        },
                        ' ' => {
                            const fifty_move_chars_const: []const u8 = fifty_move_chars[0..fifty_move_char_num];
                            fifty_move = std.fmt.parseUnsigned(u8, fifty_move_chars_const, 10) catch unreachable;
                            stage = .Fullmove;
                        },
                        else => unreachable,
                    }
                },
                .Fullmove => {
                    switch (fenchar) {
                        '0'...'9' => {
                            if (full_move_chars[0] == '!') {
                                full_move_chars[0] = fenchar;
                                full_move_char_num = 1;
                            } else if (full_move_chars[1] == '!') {
                                full_move_chars[1] = fenchar;
                                full_move_char_num = 2;
                            } else {
                                full_move_chars[2] = fenchar;
                                full_move_char_num = 3;
                            }
                        },
                        else => unreachable,
                    }
                },
            }
        }
        const full_move_chars_const: []const u8 = full_move_chars[0..full_move_char_num];
        full_move = std.fmt.parseUnsigned(u8, full_move_chars_const, 10) catch unreachable;

        return Board{
            .piece_arr = piece_arr,
            .side = side,
            .castle_white_king = castle_white_king,
            .castle_white_queen = castle_white_queen,
            .castle_black_king = castle_black_king,
            .castle_black_queen = castle_black_queen,
            .en_passant = en_passant,
            .fifty_move = fifty_move,
            .full_move = full_move,
        };
    }

    /// Returns a board from the given FEN notation string
    /// null if the string is an invalid FEN string
    fn fenFromBoard(_: Board) []const u8 {}

    // Move a piece from one square to another
    // Unchecked - does not make sure the move is valid
    pub fn makeMove(self: *Self, move: chess.Move) void {
        const from = move.pos_from;
        const to = move.pos_to;
        self.piece_arr[to.ind] = self.piece_arr[from.ind];
        self.piece_arr[from.ind] = chess.Piece.none();
        self.side = switch (self.side) {
            .White => .Black,
            .Black => .White,
        };
        self.full_move += 1;
    }

    // Get all possible moves for a piece at a given index
    // Currently only used GUI-clientside so doesn't have to be all that optimized
    pub fn getMovesAtInd(self: *const Self, alloc: Allocator, ind: u8) !?std.ArrayList(chess.Move) {
        const getPieceSide = chess.Piece.getPieceSide;
        const getPieceType = chess.Piece.getPieceType;

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
                    if (ind / 8 == first_rank and getPieceType(self.piece_arr[skip_rank]) == .None) {
                        try move_list.append(chess.moveFromPosInds(ind, skip_rank));
                    }
                }
                // Attacking diagonals
                if (ind % 8 < 7) {
                    var atk_diag_right = if (piece_side == .White) ind + 9 else ind - 7;
                    if (ind % 8 < 7 and getPieceType(self.piece_arr[atk_diag_right]) != .None and getPieceSide(self.piece_arr[atk_diag_right]) != piece_side) {
                        try move_list.append(chess.moveFromPosInds(ind, atk_diag_right));
                    }
                }
                if (ind % 8  > 0) {
                    var atk_diag_left = if (piece_side == .White) ind + 7 else ind - 9;
                    if (getPieceType(self.piece_arr[atk_diag_left]) != .None and getPieceSide(self.piece_arr[atk_diag_left]) != piece_side)
                        try move_list.append(chess.moveFromPosInds(ind, atk_diag_left));
                }
            },
            .Knight => {
                if (ind / 8  > 1) {
                    if (ind % 8  > 0 and (getPieceType(self.piece_arr[ind - 17]) == .None or getPieceSide(self.piece_arr[ind - 17]) != piece_side)) {
                        // 2 down 1 left
                        try move_list.append(chess.moveFromPosInds(ind, ind - 17));
                    }
                    if (ind % 8 < 7 and (getPieceType(self.piece_arr[ind - 15]) == .None or getPieceSide(self.piece_arr[ind - 15]) != piece_side)) {
                        // 2 down 1 right
                        try move_list.append(chess.moveFromPosInds(ind, ind - 15));
                    }
                }
                if (ind / 8 < 6) {
                    if (ind % 8 > 0 and (getPieceType(self.piece_arr[ind + 15]) == .None or getPieceSide(self.piece_arr[ind + 15]) != piece_side)) {
                        // 2 up 1 left
                        try move_list.append(chess.moveFromPosInds(ind, ind + 15));
                    }
                    if (ind % 8 < 7 and (getPieceType(self.piece_arr[ind + 17]) == .None or getPieceSide(self.piece_arr[ind + 17]) != piece_side)) {
                        // 2 up 1 left
                        try move_list.append(chess.moveFromPosInds(ind, ind + 17));
                    }
                }
                if (ind / 8 > 0) {
                    if (ind % 8 > 1 and (getPieceType(self.piece_arr[ind - 10]) == .None or getPieceSide(self.piece_arr[ind - 10]) != piece_side)) {
                        // 2 left 1 down
                        try move_list.append(chess.moveFromPosInds(ind, ind - 10));
                    }
                    if (ind % 8 < 6 and (getPieceType(self.piece_arr[ind - 6]) == .None or getPieceSide(self.piece_arr[ind - 6]) != piece_side)) {
                        // 2 right 1 down
                        try move_list.append(chess.moveFromPosInds(ind, ind - 6));
                    }
                }
                if (ind / 8 < 7) {
                    if (ind % 8 > 1 and (getPieceType(self.piece_arr[ind + 6]) == .None or getPieceSide(self.piece_arr[ind + 6]) != piece_side)) {
                        // 2 left 1 up
                        try move_list.append(chess.moveFromPosInds(ind, ind + 6));
                    }
                    if (ind % 8 < 6 and (getPieceType(self.piece_arr[ind + 10]) == .None or getPieceSide(self.piece_arr[ind + 10]) != piece_side)) {
                        // 2 right 1 up
                        try move_list.append(chess.moveFromPosInds(ind, ind + 10));
                    }
                }
            },
            .King => {
                const down = ind / 8 > 0;
                const up = ind / 8 < 7;
                const left = ind % 8 > 0;
                const right = ind % 8 < 7;
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
                const from_file = ind % 8;
                if (piece_type != .Rook) {
                    var trace_ind: u8 = ind + 7;
                    while (trace_ind < 64 and trace_ind % 8 < from_file) : (trace_ind += 7) {
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
                    while (trace_ind < 64 and trace_ind % 8 > from_file) : (trace_ind += 9) {
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
                    while (trace_ind < 64 and trace_ind % 8 > from_file) : (trace_ind -%= 7) {
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
                    while (trace_ind < 64 and trace_ind % 8 < from_file) : (trace_ind -%= 9) {
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
                    while (trace_ind % 8 > from_file) : (trace_ind += 1) {
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
                    while (trace_ind % 8 < from_file) : (trace_ind -%= 1) {
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

    pub fn getMoveAtPos(self: *const Self, alloc: Allocator, pos: u8) !?std.ArrayList(chess.Move) {
        const getPieceSide = piece.PieceSide.getPieceSide;
        const getPIeceType = piece.PieceType.getPieceType;

        const sel_piece = self.piece_arr[pos];
        const piece_side = getPieceSide(sel_piece);
        _ = piece_side;
        const piece_type = getPIeceType(sel_piece);
        _ = piece_type;
        var move_list = std.ArrayList(chess.Move).init(alloc);
        _ = move_list;
    }
};
