// White = 0
// Black = 1
pub const Side = enum(u1) {
    White,
    Black,

    pub fn oppositeSide(self: Side) Side {
        return @enumFromInt(1 - @intFromEnum(self));
    }
};

pub const PosRankFile = struct {
    rank: u3,
    file: u3,

    pub fn init(rank: u3, file: u3) PosRankFile {
        return PosRankFile{
            .rank = rank,
            .file = file,
        };
    }

    pub fn toInd(self: PosRankFile) PosInd {
        return PosInd{ .ind = (@as(u6, @intCast(self.rank)) * 8) + self.file };
    }
};

pub const PosInd = struct {
    ind: u6,

    pub fn init(ind: u6) PosInd {
        return PosInd{
            .ind = ind,
        };
    }

    pub fn toRankFile(self: PosInd) PosRankFile {
        return PosRankFile{
            .rank = @intCast(self.ind / 8),
            .file = @intCast(self.ind % 8),
        };
    }
};

// 16-bit move data if using 'packed struct'
// 24-bit move data (3 bytes) if just using 'struct'
pub const Move = struct {
    pos_from: PosInd, // 6 bits
    pos_to: PosInd, // 6 bits
    flags: MoveType, // 4 bits

    pub fn init(from: PosInd, to: PosInd, move_type: MoveType) Move {
        return Move{
            .pos_from = from,
            .pos_to = to,
            .flags = move_type,
        };
    }
};

pub const MoveType = enum(u4) {
    Quiet, // no captures, no checks
    DoublePawnPush, // pushing a pawn two spaces
    KingMove, // king moves, no longer able to castle
    RookMove, // rook moves, no longer able to castle on corresponding side
    CastleKing, // castle kingside (right side)
    CastleQueen, // castle queenside (left side)
    Capture, // Move captures a piece
    CaptureEP, // Pawn captures a pawn via En Passant
    PromoBishop, // Pawn promoted to Bishop
    PromoKnight, // Pawn promoted to Knight
    PromoRook, // Pawn promoted to Rook
    PromoQueen, // Pawn promoted to Queen
    CapturePromoBishop, // Pawn moves forward via capture, promoted to Bishop
    CapturePromoKnight, // Pawn moves forward via capture, promoted to Knight
    CapturePromoRook, // Pawn moves forward via capture, promoted to Rook
    CapturePromoQueen, // Pawn moves forward via capture, promoted to Queen
};

pub const Piece = struct {
    data: u4,

    pub fn init(pt: PieceType, side: Side) Piece {
        const type_val: u4 = @intFromEnum(pt);
        const side_val: u4 = @intFromEnum(side);
        return Piece{ .data = type_val | (side_val << 3) };
    }

    pub fn none() Piece {
        return Piece{ .data = 0 };
    }

    pub fn getPieceType(self: Piece) PieceType {
        return switch (self.data & 0b111) {
            0 => PieceType.None,
            0b001 => PieceType.Pawn,
            0b010 => PieceType.Bishop,
            0b011 => PieceType.Knight,
            0b100 => PieceType.Rook,
            0b101 => PieceType.Queen,
            0b110 => PieceType.King,
            else => unreachable,
        };
    }

    pub fn getPieceSide(self: Piece) Side {
        return switch (self.data >> 3) {
            0 => .White,
            1 => .Black,
            else => unreachable,
        };
    }
};

pub const PieceType = enum(u3) {
    None,
    Pawn,
    Bishop,
    Knight,
    Rook,
    Queen,
    King,

    // Each piece's in-game point value
    pub fn value(self: PieceType) u8 {
        switch (self) {
            .None => 0,
            .Pawn => 1,
            .Bishop => 3,
            .Knight => 3,
            .Rook => 5,
            .Queen => 9,
            .King => 10,
        }
    }
};
