const chess = @import("chess.zig");
const bitboard = @import("bitboard.zig");
const move_gen = @import("move_gen.zig");
const std = @import("std");

pub const start_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
pub const test_fen = "rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2";

pub const Board = struct {
    const Self = @This();
    const Bitboard = bitboard.Bitboard;

    white: Bitboard,
    black: Bitboard,
    pawn: Bitboard,
    bishop: Bitboard,
    knight: Bitboard,
    rook: Bitboard,
    queen: Bitboard,
    king: Bitboard,

    // non-piece board state
    side: chess.Side,
    has_enpassant: u1,
    w_castle_l: u1,
    w_castle_r: u1,
    b_castle_l: u1,
    b_castle_r: u1,

    pub fn initFromFen(fen_str: []const u8) Self {
        var pos: chess.PosRankFile = chess.PosRankFile.init(7, 0);

        var white: Bitboard = 0;
        var black: Bitboard = 0;
        var pawn: Bitboard = 0;
        var bishop: Bitboard = 0;
        var knight: Bitboard = 0;
        var rook: Bitboard = 0;
        var queen: Bitboard = 0;
        var king: Bitboard = 0;
        var side: chess.Side = undefined;
        var w_castle_l: u1 = 0;
        var w_castle_r: u1 = 0;
        var b_castle_l: u1 = 0;
        var b_castle_r: u1 = 0;

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
                        break;
                    }
                    if (fen_char > 47 and fen_char < 57) {
                        pos.file +%= @truncate(fen_char - 0x30);
                        continue;
                    }
                    // const char_side: chess.Side = if (fen_char < 0x60) .White else .Black;
                    // const piece_char = if (fen_char > 0x60) fen_char - 0x20 else fen_char;
                    const piece_bit: Bitboard = @as(u64, 1) << pos.toInd().ind;
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
                        '-', ' ' => stage = .EnPassant,
                        'K' => w_castle_r = 1,
                        'Q' => w_castle_l = 1,
                        'k' => b_castle_r = 1,
                        'q' => b_castle_l = 1,
                        else => unreachable,
                    }
                },
                .EnPassant => break,
                else => unreachable,
            }
        }

        return Self{
            .white = white,
            .black = black,
            .pawn = pawn,
            .bishop = bishop,
            .knight = knight,
            .rook = rook,
            .queen = queen,
            .king = king,

            .side = side,
            .has_enpassant = 0,
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
    pub fn makeMove(self: *Self, move: chess.Move) void {
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
        switch (self.side) {
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
                switch (self.side) {
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
                switch (self.side) {
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
                switch (self.side) {
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

        self.side = self.side.oppositeSide();
    }

    // Queenside castling
    fn canCastleLeft(self: *const Self, occupied: Bitboard, attacked: Bitboard) bool {
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
    fn canCastleRight(self: *const Self, occupied: Bitboard, attacked: Bitboard) bool {
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
