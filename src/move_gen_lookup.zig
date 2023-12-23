const bitboard = @import("bitboard.zig");

pub const knightMoveLookup: [64]u64 = [_]u64{
    0x0204000402 >> 16, // a1
    0x0508000805 >> 16, // b1
    0x0a1100110a >> 16, // c1
    0x1422002214 >> 16, // d1
    0x2844004428 >> 16, // e1
    0x5088008850 >> 16, // f1
    0xa0100010a0 >> 16, // g1
    0x4020002040 >> 16, // h1
    0x0204000402 >> 8, // a2
    0x0508000805 >> 8, // b2
    0x0a1100110a >> 8, // c2
    0x1422002214 >> 8, // d2
    0x2844004428 >> 8, // e2
    0x5088008850 >> 8, // f2
    0xa0100010a0 >> 8, // g2
    0x4020002040 >> 8, // h2
    0x0204000402, // a3
    0x0508000805, // b3
    0x0a1100110a, // c3
    0x1422002214, // d3
    0x2844004428, // e3
    0x5088008850, // f3
    0xa0100010a0, // g3
    0x4020002040, // h3
    0x0204000402 << 8, // a4
    0x0508000805 << 8, // b4
    0x0a1100110a << 8, // c4
    0x1422002214 << 8, // d4
    0x2844004428 << 8, // e4
    0x5088008850 << 8, // f4
    0xa0100010a0 << 8, // g4
    0x4020002040 << 8, // h4
    0x0204000402 << 16, // a5
    0x0508000805 << 16, // b5
    0x0a1100110a << 16, // c5
    0x1422002214 << 16, // d5
    0x2844004428 << 16, // e5
    0x5088008850 << 16, // f5
    0xa0100010a0 << 16, // g5
    0x4020002040 << 16, // h5
    0x0204000402 << 24, // a6
    0x0508000805 << 24, // b6
    0x0a1100110a << 24, // c6
    0x1422002214 << 24, // d6
    0x2844004428 << 24, // e6
    0x5088008850 << 24, // f6
    0xa0100010a0 << 24, // g6
    0x4020002040 << 24, // h6
    // Rank 7 - bits start getting cut off by bitshift
    @truncate(0x0204000402 << 32), // a7
    @truncate(0x0508000805 << 32), // b7
    @truncate(0x0a1100110a << 32), // c7
    @truncate(0x1422002214 << 32), // d7
    @truncate(0x2844004428 << 32), // e7
    @truncate(0x5088008850 << 32), // f7
    @truncate(0xa0100010a0 << 32), // g7
    @truncate(0x4020002040 << 32), // h7
    @truncate(0x0204000402 << 40), // a8
    @truncate(0x0508000805 << 40), // b8
    @truncate(0x0a1100110a << 40), // c8
    @truncate(0x1422002214 << 40), // d8
    @truncate(0x2844004428 << 40), // e8
    @truncate(0x5088008850 << 40), // f8
    @truncate(0xa0100010a0 << 40), // g8
    @truncate(0x4020002040 << 40), // h8
};

pub const kingMoveLookup: [64]u64 = [_]u64{
    0x0000000000000302, // a1
    0x0000000000000705, // b1
    0x0000000000000E0A, // c1
    0x0000000000001C14, // d1
    0x0000000000003828, // e1
    0x0000000000007050, // f1
    0x000000000000E0A0, // g1
    0x000000000000C040, // h1
    0x0000000000030203, // a2
    0x0000000000070507, // b2
    0x00000000000E0A0E, // c2
    0x00000000001C141C, // d2
    0x0000000000382838, // e2
    0x0000000000705007, // f2
    0x0000000000E0A0E0, // g2
    0x0000000000C040C0, // h2
    0x0000000003020300, // a3
    0x0000000007050700, // b3
    0x000000000E0A0E00, // c3
    0x000000001C141C00, // d3
    0x0000000038283800, // e3
    0x0000000070500700, // f3
    0x00000000E0A0E000, // g3
    0x00000000C040C000, // h3
    0x0000000302030000, // a4
    0x0000000705070000, // b4
    0x0000000E0A0E0000, // c4
    0x0000001C141C0000, // d4
    0x0000003828380000, // e4
    0x0000007050070000, // f4
    0x000000E0A0E00000, // g4
    0x000000C040C00000, // h4
    0x0000030203000000, // a5
    0x0000070507000000, // b5
    0x00000E0A0E000000, // c5
    0x00001C141C000000, // d5
    0x0000382838000000, // e5
    0x0000705007000000, // f5
    0x0000E0A0E0000000, // g5
    0x0000C040C0000000, // h5
    0x0003020300000000, // a6
    0x0007050700000000, // b6
    0x000E0A0E00000000, // c6
    0x001C141C00000000, // d6
    0x0038283800000000, // e6
    0x0070500700000000, // f6
    0x00E0A0E000000000, // g6
    0x00C040C000000000, // h6
    0x0302030000000000, // a7
    0x0705070000000000, // b7
    0x0E0A0E0000000000, // c7
    0x1C141C0000000000, // d7
    0x3828380000000000, // e7
    0x7050070000000000, // f7
    0xE0A0E00000000000, // g7
    0xC040C00000000000, // h7
    0x0203000000000000, // a8
    0x0507000000000000, // b8
    0x0A0E000000000000, // c8
    0x141C000000000000, // d8
    0x2838000000000000, // e8
    0x5007000000000000, // f8
    0xA0E0000000000000, // g8
    0x40C0000000000000, // h8
};

pub const sliderFiles: [64]u64 = [_]u64{
    bitboard.fileA,
    bitboard.fileB,
    bitboard.fileC,
    bitboard.fileD,
    bitboard.fileE,
    bitboard.fileF,
    bitboard.fileG,
    bitboard.fileH,

    bitboard.fileA,
    bitboard.fileB,
    bitboard.fileC,
    bitboard.fileD,
    bitboard.fileE,
    bitboard.fileF,
    bitboard.fileG,
    bitboard.fileH,

    bitboard.fileA,
    bitboard.fileB,
    bitboard.fileC,
    bitboard.fileD,
    bitboard.fileE,
    bitboard.fileF,
    bitboard.fileG,
    bitboard.fileH,

    bitboard.fileA,
    bitboard.fileB,
    bitboard.fileC,
    bitboard.fileD,
    bitboard.fileE,
    bitboard.fileF,
    bitboard.fileG,
    bitboard.fileH,

    bitboard.fileA,
    bitboard.fileB,
    bitboard.fileC,
    bitboard.fileD,
    bitboard.fileE,
    bitboard.fileF,
    bitboard.fileG,
    bitboard.fileH,

    bitboard.fileA,
    bitboard.fileB,
    bitboard.fileC,
    bitboard.fileD,
    bitboard.fileE,
    bitboard.fileF,
    bitboard.fileG,
    bitboard.fileH,

    bitboard.fileA,
    bitboard.fileB,
    bitboard.fileC,
    bitboard.fileD,
    bitboard.fileE,
    bitboard.fileF,
    bitboard.fileG,
    bitboard.fileH,

    bitboard.fileA,
    bitboard.fileB,
    bitboard.fileC,
    bitboard.fileD,
    bitboard.fileE,
    bitboard.fileF,
    bitboard.fileG,
    bitboard.fileH,
};

pub const sliderRanks: [64]u64 = [_]u64{
    bitboard.rank1,
    bitboard.rank1,
    bitboard.rank1,
    bitboard.rank1,
    bitboard.rank1,
    bitboard.rank1,
    bitboard.rank1,
    bitboard.rank1,

    bitboard.rank2,
    bitboard.rank2,
    bitboard.rank2,
    bitboard.rank2,
    bitboard.rank2,
    bitboard.rank2,
    bitboard.rank2,
    bitboard.rank2,

    bitboard.rank3,
    bitboard.rank3,
    bitboard.rank3,
    bitboard.rank3,
    bitboard.rank3,
    bitboard.rank3,
    bitboard.rank3,
    bitboard.rank3,

    bitboard.rank4,
    bitboard.rank4,
    bitboard.rank4,
    bitboard.rank4,
    bitboard.rank4,
    bitboard.rank4,
    bitboard.rank4,
    bitboard.rank4,

    bitboard.rank5,
    bitboard.rank5,
    bitboard.rank5,
    bitboard.rank5,
    bitboard.rank5,
    bitboard.rank5,
    bitboard.rank5,
    bitboard.rank5,

    bitboard.rank6,
    bitboard.rank6,
    bitboard.rank6,
    bitboard.rank6,
    bitboard.rank6,
    bitboard.rank6,
    bitboard.rank6,
    bitboard.rank6,

    bitboard.rank7,
    bitboard.rank7,
    bitboard.rank7,
    bitboard.rank7,
    bitboard.rank7,
    bitboard.rank7,
    bitboard.rank7,
    bitboard.rank7,

    bitboard.rank8,
    bitboard.rank8,
    bitboard.rank8,
    bitboard.rank8,
    bitboard.rank8,
    bitboard.rank8,
    bitboard.rank8,
    bitboard.rank8,
};

pub const sliderDiagonals: [64]u64 = [_]u64{
    bitboard.diag0,
    bitboard.diag15,
    bitboard.diag14,
    bitboard.diag13,
    bitboard.diag12,
    bitboard.diag11,
    bitboard.diag10,
    bitboard.diag9,

    bitboard.diag1,
    bitboard.diag0,
    bitboard.diag15,
    bitboard.diag14,
    bitboard.diag13,
    bitboard.diag12,
    bitboard.diag11,
    bitboard.diag10,

    bitboard.diag2,
    bitboard.diag1,
    bitboard.diag0,
    bitboard.diag15,
    bitboard.diag14,
    bitboard.diag13,
    bitboard.diag12,
    bitboard.diag11,

    bitboard.diag3,
    bitboard.diag2,
    bitboard.diag1,
    bitboard.diag0,
    bitboard.diag15,
    bitboard.diag14,
    bitboard.diag13,
    bitboard.diag12,

    bitboard.diag4,
    bitboard.diag3,
    bitboard.diag2,
    bitboard.diag1,
    bitboard.diag0,
    bitboard.diag15,
    bitboard.diag14,
    bitboard.diag13,

    bitboard.diag5,
    bitboard.diag4,
    bitboard.diag3,
    bitboard.diag2,
    bitboard.diag1,
    bitboard.diag0,
    bitboard.diag15,
    bitboard.diag14,

    bitboard.diag6,
    bitboard.diag5,
    bitboard.diag4,
    bitboard.diag3,
    bitboard.diag2,
    bitboard.diag1,
    bitboard.diag0,
    bitboard.diag15,

    bitboard.diag7,
    bitboard.diag6,
    bitboard.diag5,
    bitboard.diag4,
    bitboard.diag3,
    bitboard.diag2,
    bitboard.diag1,
    bitboard.diag0,
};

pub const sliderAntidiagonals: [64]u64 = [_]u64{
    bitboard.diag7,
    bitboard.diag6,
    bitboard.diag5,
    bitboard.diag4,
    bitboard.diag3,
    bitboard.diag2,
    bitboard.diag1,
    bitboard.diag0,

    bitboard.diag6,
    bitboard.diag5,
    bitboard.diag4,
    bitboard.diag3,
    bitboard.diag2,
    bitboard.diag1,
    bitboard.diag0,
    bitboard.diag15,

    bitboard.diag5,
    bitboard.diag4,
    bitboard.diag3,
    bitboard.diag2,
    bitboard.diag1,
    bitboard.diag0,
    bitboard.diag15,
    bitboard.diag14,

    bitboard.diag4,
    bitboard.diag3,
    bitboard.diag2,
    bitboard.diag1,
    bitboard.diag0,
    bitboard.diag15,
    bitboard.diag14,
    bitboard.diag13,

    bitboard.diag3,
    bitboard.diag2,
    bitboard.diag1,
    bitboard.diag0,
    bitboard.diag15,
    bitboard.diag14,
    bitboard.diag13,
    bitboard.diag12,

    bitboard.diag2,
    bitboard.diag1,
    bitboard.diag0,
    bitboard.diag15,
    bitboard.diag14,
    bitboard.diag13,
    bitboard.diag12,
    bitboard.diag11,

    bitboard.diag1,
    bitboard.diag0,
    bitboard.diag15,
    bitboard.diag14,
    bitboard.diag13,
    bitboard.diag12,
    bitboard.diag11,
    bitboard.diag10,

    bitboard.diag0,
    bitboard.diag15,
    bitboard.diag14,
    bitboard.diag13,
    bitboard.diag12,
    bitboard.diag11,
    bitboard.diag10,
    bitboard.diag9,
};
