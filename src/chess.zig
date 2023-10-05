pub const Side = enum { White, Black };
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
        return PosInd{ .ind = (@as(u6, @intCast(self.rank))) + self.file };
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
pub const Move = struct {
    pos_from: PosInd,
    pos_to: PosInd,
    flags: u4,

    pub fn init(from: PosInd, to: PosInd) Move {
        return Move{
            .pos_from = from,
            .pos_to = to,
            .flags = 0,
        };
    }
};
pub const Piece = struct {
    data: u4,

    pub fn init(pt: PieceType, side: Side) Piece {
        return @intFromEnum(pt) | (@intFromEnum(side) << 3);
    }

    pub fn none() Piece {
        return Piece{ .data = 0 };
    }

    pub fn getPieceType(self: Piece) PieceType {
        switch (self & 0b111) {
            0 => PieceType.None,
            0b001 => PieceType.Pawn,
            0b010 => PieceType.Bishop,
            0b011 => PieceType.Knight,
            0b100 => PieceType.Rook,
            0b101 => PieceType.Queen,
            0b110 => PieceType.King,
            else => unreachable,
        }
    }

    pub fn getPieceSide(self: Piece) Side {
        switch (self.data >> 3) {
            0 => .White,
            1 => .Black,
        }
    }
};
pub const PieceType = enum {
    None,
    Pawn,
    Bishop,
    Knight,
    Rook,
    Queen,
    King,

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
