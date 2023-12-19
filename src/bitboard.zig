// MSB      ...     LSB
// North    ...     South
// Black    ...     White
// Bitboards
pub const Bitboard = u64;
// Place bits are u64s with a single bit population.
// They are meant to mark a single piece's position like a bitboard.
pub const Placebit = u64;

pub fn shiftNorth(board: Bitboard, comptime n: u8) Bitboard {
    return board << (8 * n);
}

pub fn shiftSouth(board: Bitboard, comptime n: u8) Bitboard {
    return board >> (8 * n);
}

pub fn shiftEast(board: Bitboard, comptime n: u8) Bitboard {
    return board << n;
}

pub fn shiftWest(board: Bitboard, comptime n: u8) Bitboard {
    return board >> n;
}

pub fn shiftNE(board: Bitboard, comptime n: u8) Bitboard {
    return board << (9 * n);
}

pub fn shiftSE(board: Bitboard, comptime n: u8) Bitboard {
    return board >> (7 * n);
}

pub fn shiftSW(board: Bitboard, comptime n: u8) Bitboard {
    return board >> (9 * n);
}

pub fn shiftNW(board: Bitboard, comptime n: u8) Bitboard {
    return board << (7 * n);
}

