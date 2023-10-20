// MSB      ...     LSB
// North    ...     South
// Black    ...     White
pub const Bitboard = u64;

pub fn shiftNorth(board: Bitboard, comptime n: u8) Bitboard {
    return board << (8 * n);
}

pub fn shiftSouth(board: Bitboard, comptime n: u8) Bitboard {
    return board >> (8 * n);
}

pub fn shiftEast(board: Bitboard, comptime n: u8) Bitboard {
    return board >> n;
}

pub fn shiftWest(board: Bitboard, comptime n: u8) Bitboard {
    return board << n;
}
