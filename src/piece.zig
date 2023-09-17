pub const Piece = u8;

pub const PieceType = enum(u8) {
    None = 0b0,
    Pawn = 0b1,
    Bishop = 0b10,
    Knight = 0b11,
    Rook = 0b100,
    Queen = 0b101,
    King = 0b110,

    pub fn getPieceType(p: Piece) PieceType {
        return switch (p & 0b111) {
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
};

// Combine with the Side enum in chess.zig
pub const PieceSide = enum(u8) {
    White = 0b0000,
    Black = 0b1000,

    pub fn getPieceSide(p: Piece) PieceSide {
        return switch ((p >> 3) & 0b1) {
            0 => PieceSide.White,
            1 => PieceSide.Black,
            else => unreachable,
        };
    }
};

pub fn pieceInit(pt: PieceType, side: PieceSide) Piece {
    return @intFromEnum(pt) | @intFromEnum(side);
}

pub fn pieceNone() Piece {
    return 0;
}
