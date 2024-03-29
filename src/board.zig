const chess = @import("chess.zig");
const bitboard = @import("bitboard.zig");
const move_gen = @import("move_gen.zig");
const std = @import("std");
const testing = std.testing;

pub const start_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
pub const test_fen = "rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2";

pub const BoardFlags = packed struct {
    const Self = @This();

    side: chess.Side = .White,
    has_enpassant: bool = false,
    w_castle_l: bool = true,
    w_castle_r: bool = true,
    b_castle_l: bool = true,
    b_castle_r: bool = true,

    pub fn makeMove(self: Self, move: chess.Move) BoardFlags {
        return switch (move.flags) {
            .KingMove => self.makeMoveKing(),
            .RookMove => {
                switch (move.pos_from.ind) {
                    0, 56 => return self.makeMoveRookQueenside(),
                    7, 63 => return self.makeMoveRookKingside(),
                    else => return self.makeMoveQuiet(),
                }
            },
            .DoublePawnPush => self.makeMoveDoublePawnPush(),
            else => self.makeMoveQuiet(),
        };
    }

    fn makeMoveQuiet(self: BoardFlags) BoardFlags {
        return BoardFlags{
            .side = self.side.oppositeSide(),
            .has_enpassant = false,
            .w_castle_l = self.w_castle_l,
            .w_castle_r = self.w_castle_r,
            .b_castle_l = self.b_castle_l,
            .b_castle_r = self.b_castle_r,
        };
    }

    fn makeMoveKing(self: BoardFlags) BoardFlags {
        return switch (self.side) {
            .White => BoardFlags{
                .side = self.side.oppositeSide(),
                .has_enpassant = false,
                .w_castle_l = false,
                .w_castle_r = false,
                .b_castle_l = self.b_castle_l,
                .b_castle_r = self.b_castle_r,
            },
            .Black => BoardFlags{
                .side = self.side.oppositeSide(),
                .has_enpassant = false,
                .w_castle_l = self.w_castle_l,
                .w_castle_r = self.w_castle_r,
                .b_castle_l = false,
                .b_castle_r = false,
            },
        };
    }

    fn makeMoveRookQueenside(self: BoardFlags) BoardFlags {
        return switch (self.side) {
            .White => BoardFlags{
                .side = self.side.oppositeSide(),
                .has_enpassant = false,
                .w_castle_l = false,
                .w_castle_r = self.w_castle_r,
                .b_castle_l = self.b_castle_l,
                .b_castle_r = self.b_castle_r,
            },
            .Black => BoardFlags{
                .side = self.side.oppositeSide(),
                .has_enpassant = false,
                .w_castle_l = self.w_castle_l,
                .w_castle_r = self.w_castle_r,
                .b_castle_l = false,
                .b_castle_r = self.b_castle_r,
            },
        };
    }

    fn makeMoveRookKingside(self: BoardFlags) BoardFlags {
        return switch (self.side) {
            .White => BoardFlags{
                .side = self.side.oppositeSide(),
                .has_enpassant = false,
                .w_castle_l = self.w_castle_l,
                .w_castle_r = false,
                .b_castle_l = self.b_castle_l,
                .b_castle_r = self.b_castle_r,
            },
            .Black => BoardFlags{
                .side = self.side.oppositeSide(),
                .has_enpassant = false,
                .w_castle_l = self.w_castle_l,
                .w_castle_r = self.w_castle_r,
                .b_castle_l = self.b_castle_l,
                .b_castle_r = false,
            },
        };
    }

    fn makeMoveDoublePawnPush(self: BoardFlags) BoardFlags {
        return BoardFlags{
            .side = self.side.oppositeSide(),
            .has_enpassant = true,
            .w_castle_l = self.w_castle_l,
            .w_castle_r = self.w_castle_r,
            .b_castle_l = self.b_castle_l,
            .b_castle_r = self.b_castle_r,
        };
    }
};

pub const Board = struct {
    const Self = @This();
    const BB = bitboard.Bitboard;

    white: BB,
    black: BB,
    pawn: BB,
    bishop: BB,
    knight: BB,
    rook: BB,
    queen: BB,
    king: BB,
    ep: BB, // The additional square behind a pushed pawn, not the pawn itself

    // non-piece board state
    side: chess.Side,
    has_enpassant: u1,
    w_castle_l: u1,
    w_castle_r: u1,
    b_castle_l: u1,
    b_castle_r: u1,

    pub fn initFromFen(fen_str: []const u8) Self {
        var pos: chess.PosRankFile = chess.PosRankFile.init(7, 0);

        var white: BB = 0;
        var black: BB = 0;
        var pawn: BB = 0;
        var bishop: BB = 0;
        var knight: BB = 0;
        var rook: BB = 0;
        var queen: BB = 0;
        var king: BB = 0;
        var side: chess.Side = undefined;
        var w_castle_l: u1 = 0;
        var w_castle_r: u1 = 0;
        var b_castle_l: u1 = 0;
        var b_castle_r: u1 = 0;
        var ep_pos: chess.PosRankFile = chess.PosRankFile.init(0, 0);
        var has_ep: bool = true;

        const FenStage = enum {
            Pieces,
            Side,
            Castling,
            EnPassant,
            Halfmove,
            Fullmove,
        };
        var stage: FenStage = .Pieces;
        for (fen_str) |fen_char| {
            switch (stage) {
                .Pieces => {
                    if (fen_char == '/') {
                        pos.rank -= 1;
                        pos.file = 0;
                        continue;
                    } else if (fen_char == ' ') {
                        stage = .Side;
                        continue;
                    }
                    if (fen_char > 47 and fen_char < 57) {
                        pos.file +%= @truncate(fen_char - 0x30);
                        continue;
                    }
                    // const char_side: chess.Side = if (fen_char < 0x60) .White else .Black;
                    // const piece_char = if (fen_char > 0x60) fen_char - 0x20 else fen_char;
                    const piece_bit: BB = @as(u64, 1) << pos.toInd().ind;
                    switch (fen_char) {
                        0x41...0x5A => white |= piece_bit,
                        0x61...0x7A => black |= piece_bit,
                        else => unreachable,
                    }
                    switch (fen_char) {
                        'K', 'k' => king |= piece_bit,
                        'Q', 'q' => queen |= piece_bit,
                        'R', 'r' => rook |= piece_bit,
                        'N', 'n' => knight |= piece_bit,
                        'B', 'b' => bishop |= piece_bit,
                        'P', 'p' => pawn |= piece_bit,
                        else => unreachable,
                    }
                    pos.file +%= 1;
                },
                .Side => {
                    switch (fen_char) {
                        'w' => side = .White,
                        'b' => side = .Black,
                        ' ' => stage = .Castling,
                        else => unreachable,
                    }
                },
                .Castling => {
                    switch (fen_char) {
                        '-' => {},
                        ' ' => stage = .EnPassant,
                        'K' => w_castle_r = 1,
                        'Q' => w_castle_l = 1,
                        'k' => b_castle_r = 1,
                        'q' => b_castle_l = 1,
                        else => unreachable,
                    }
                },
                .EnPassant => {
                    switch (fen_char) {
                        '-' => {
                            has_ep = false;
                            stage = .Halfmove;
                        },
                        'a'...'h' => ep_pos.file = @as(u3, @truncate(fen_char - 'a')),
                        // 3 and 6 are only possible en passant ranks
                        '3', '6' => ep_pos.rank = @as(u3, @truncate(fen_char - '1')),
                        ' ' => stage = .Halfmove,
                        else => unreachable,
                    }
                },
                .Halfmove => break,
                else => unreachable,
            }
        }

        const ep = if (has_ep) bitboard.placebitFromInd(chess.PosRankFile.toInd(ep_pos)) else 0;

        return Self{
            .white = white,
            .black = black,
            .pawn = pawn,
            .bishop = bishop,
            .knight = knight,
            .rook = rook,
            .queen = queen,
            .king = king,
            .ep = ep,

            .side = side,
            .has_enpassant = @intFromBool(has_ep),
            .w_castle_l = w_castle_l,
            .w_castle_r = w_castle_r,
            .b_castle_l = b_castle_l,
            .b_castle_r = b_castle_r,
        };
    }

    /// Mutably makes a move on the given board
    /// Assumes that the move is valid
    /// Be careful with castling especially;
    /// if not a valid castle, will spawn a new rook
    pub fn makeMove(self: *Self, flags: BoardFlags, move: chess.Move) void {
        const from_bit = bitboard.placebitFromInd(move.pos_from);
        const to_bit = bitboard.placebitFromInd(move.pos_to);

        // Regardless of piece type, nothing should be in
        // the target square except the new piece
        self.pawn ^= to_bit;
        self.bishop ^= to_bit;
        self.knight ^= to_bit;
        self.rook ^= to_bit;
        self.queen ^= to_bit;
        self.king ^= to_bit;

        if (self.pawn & from_bit > 0) {
            self.pawn ^= from_bit;
            self.pawn |= to_bit;
        } else if (self.bishop & from_bit > 0) {
            self.bishop ^= from_bit;
            self.bishop |= to_bit;
        } else if (self.knight & from_bit > 0) {
            self.knight ^= from_bit;
            self.knight |= to_bit;
        } else if (self.rook & from_bit > 0) {
            self.rook ^= from_bit;
            self.rook |= to_bit;
        } else if (self.queen & from_bit > 0) {
            self.queen ^= from_bit;
            self.queen |= to_bit;
        } else {
            self.king ^= from_bit;
            self.king |= to_bit;
        }
        switch (flags.side) {
            .White => {
                self.white ^= from_bit;
                self.white |= to_bit;
            },
            .Black => {
                self.black ^= from_bit;
                self.black |= to_bit;
            },
        }

        switch (move.flags) {
            .CaptureEP => {
                switch (flags.side) {
                    .White => {
                        const ep_pawn_bit = bitboard.shiftSouth(to_bit, 1);
                        self.black ^= ep_pawn_bit;
                        self.pawn ^= ep_pawn_bit;
                    },
                    .Black => {
                        const ep_pawn_bit = bitboard.shiftNorth(to_bit, 1);
                        self.white ^= ep_pawn_bit;
                        self.pawn ^= ep_pawn_bit;
                    },
                }
            },
            .PromoBishop, .CapturePromoBishop => {
                self.pawn ^= to_bit;
                self.bishop |= to_bit;
            },
            .PromoKnight, .CapturePromoKnight => {
                self.pawn ^= to_bit;
                self.knight |= to_bit;
            },
            .PromoRook, .CapturePromoRook => {
                self.pawn ^= to_bit;
                self.rook |= to_bit;
            },
            .PromoQueen, .CapturePromoQueen => {
                self.pawn ^= to_bit;
                self.queen |= to_bit;
            },
            .CastleKing => {
                switch (flags.side) {
                    .White => {
                        // Only one king, of course
                        self.king = bitboard.rank1 & bitboard.fileG;
                        // Be careful here - if unchecked, this will spawn a new rook
                        self.rook ^= bitboard.rank1 & bitboard.fileH;
                        self.rook |= bitboard.rank1 & bitboard.fileF;
                        self.white ^= 0xf0;
                        self.white |= 0x60;
                    },
                    .Black => {
                        self.king = bitboard.rank8 & bitboard.fileG;
                        self.rook ^= bitboard.rank8 & bitboard.fileH;
                        self.rook |= bitboard.rank8 & bitboard.fileF;
                        self.black ^= 0xf000000000000000;
                        self.black |= 0x6000000000000000;
                    },
                }
            },
            .CastleQueen => {
                switch (flags.side) {
                    .White => {
                        self.king = bitboard.rank1 & bitboard.fileC;
                        self.rook ^= bitboard.rank1 & bitboard.fileA;
                        self.rook |= bitboard.rank1 & bitboard.fileD;
                        self.white ^= 0x1f;
                        self.white |= 0x0c;
                    },
                    .Black => {
                        self.king = bitboard.rank8 & bitboard.fileC;
                        self.rook ^= bitboard.rank8 & bitboard.fileA;
                        self.rook |= bitboard.rank8 & bitboard.fileD;
                        self.black ^= 0x1f00000000000000;
                        self.black |= 0x0c00000000000000;
                    },
                }
            },
            else => {},
        }
    }

    // Queenside castling
    fn canCastleLeft(self: *const Self, occupied: BB, attacked: BB) bool {
        switch (self.side) {
            .White => {
                // TODO: simplify to single statement
                // TODO: make these magic numbers constants in the bitboard file
                // can't castle through occupied spaces or move the king through check
                if (!self.w_castle_l) {
                    return false;
                }
                if (occupied & 0xe > 0 or attacked & 0x1c > 0) {
                    return false;
                }
                if (self.white & self.rooks & 0x1 > 0) {
                    return true;
                }
                return false;
            },
            .Black => {
                if (!self.b_castle_l) {
                    return false;
                }
                if (occupied & (0xe << 56) > 0 or attacked & (0x70 << 56)) {
                    return false;
                }
                if (self.black & self.rooks & (0x1 << 56) > 0) {
                    return true;
                }
                return false;
            },
        }
    }

    // Kingside castling
    fn canCastleRight(self: *const Self, occupied: BB, attacked: BB) bool {
        switch (self.side) {
            .White => {
                // TODO: simplify to single statement
                // TODO: make these magic numbers constants in the bitboard file
                // can't castle through occupied spaces or move the king through check
                if (!self.w_castle_r) {
                    return false;
                }
                if (occupied & 0x60 > 0 or attacked & 0x70 > 0) {
                    return false;
                }
                if (self.white & self.rooks & 0x80 > 0) {
                    return true;
                }
                return false;
            },
            .Black => {
                if (!self.b_castle_r) {
                    return false;
                }
                if (occupied & (0x60 << 56) > 0 or attacked & (0x70 << 56)) {
                    return false;
                }
                if (self.white & self.rooks & (0x80 << 56) > 0) {
                    return true;
                }
                return false;
            },
        }
    }
};

test "FEN en passant" {
    const board = Board.initFromFen("8/8/8/1K1pP1r1/8/8/6k1/8 w - d6 0 1");
    try testing.expectEqual(board.has_enpassant, 1);
    try testing.expectEqual(board.ep, bitboard.rank6 & bitboard.fileD);
}
