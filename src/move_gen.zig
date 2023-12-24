const std = @import("std");
const testing = std.testing;
const bitboard = @import("bitboard.zig");
const BB = bitboard.Bitboard;
const board = @import("board.zig");
const chess = @import("chess.zig");
const move_gen_lookup = @import("move_gen_lookup.zig");

//////// Piece moves ////////

/// Calculates single forward pawn moves
fn pawnPushes(pawns: BB, comptime side: chess.Side) BB {
    return switch (side) {
        .White => bitboard.shiftNorth(pawns, 1),
        .Black => bitboard.shiftSouth(pawns, 1),
    };
}

/// Calculates double forward pawn moves
/// pawn_pushes: bitboard of pawns that have already been pushed
fn pawnDoublePushes(pawn_pushes: BB, comptime side: chess.Side) BB {
    return switch (side) {
        .White => bitboard.shiftNorth(pawn_pushes & bitboard.rank3, 1),
        .Black => bitboard.shiftSouth(pawn_pushes & bitboard.rank6, 1),
    };
}

/// Calculates pawn diagonal-attacked squares
fn pawnAttacks(pawns: BB, comptime side: chess.Side) BB {
    return switch (side) {
        .White => bitboard.shiftNE(pawns, 1) | bitboard.shiftNW(pawns, 1),
        .Black => bitboard.shiftSE(pawns, 1) | bitboard.shiftSW(pawns, 1),
    };
}

/// Calculates moves of all knights
/// Useful for getting attacked squares
fn knightMovesParallel(knights: BB) BB {
    const l1 = (knights >> 1) & 0x7f7f7f7f7f7f7f7f;
    const l2 = (knights >> 2) & 0x3f3f3f3f3f3f3f3f;
    const r1 = (knights << 1) & 0xfefefefefefefefe;
    const r2 = (knights << 2) & 0xfcfcfcfcfcfcfcfc;
    const h1 = l1 | r1;
    const h2 = l2 | r2;
    return (h1 << 16) | (h1 >> 16) | (h2 << 8) | (h2 >> 8);
}

/// Calculates moves of a single knight
/// Useful for finding moves
fn knightMovesIndividual(knight: bitboard.Placebit) BB {
    const knight_ind = bitboard.indFromPlacebit(knight);
    return move_gen_lookup.knightMoveLookup[knight_ind.ind];
}

/// Calculates the valid moves of a single orthogonally-sliding piece
/// Treats all occupied squares as attackable, whether ally or enemy
/// bitwise & with enemy mask to get attacked squares
fn hvSliderMovesIndividual(piece: bitboard.Placebit, occupied: BB) BB {
    const piece_ind = bitboard.indFromPlacebit(piece).ind;

    const file = move_gen_lookup.sliderFiles[piece_ind];
    const rank = move_gen_lookup.sliderRanks[piece_ind];

    const file_o = occupied & file;
    const rank_o = occupied & rank;
    const pos_file_ray = (file_o ^ (file_o -% (2 *% piece))) & file;
    const pos_rank_ray = (rank_o ^ (rank_o -% (2 *% piece))) & rank;

    const rev_piece = @bitReverse(piece);
    const rev_file_o = @bitReverse(file_o);
    const rev_rank_o = @bitReverse(rank_o);
    const neg_file_ray = @bitReverse(rev_file_o ^ (rev_file_o -% (2 *% rev_piece))) & file;
    const neg_rank_ray = @bitReverse(rev_rank_o ^ (rev_rank_o -% (2 *% rev_piece))) & rank;

    return pos_file_ray | neg_file_ray | pos_rank_ray | neg_rank_ray;
}

/// Calculates the valid moves of a single diagonally-sliding piece
/// Treats all occupied squares as attackable, whether ally or enemy
/// bitwise & with enemy mask to get attacked squares
fn diagSliderMovesIndividual(piece: bitboard.Placebit, occupied: BB) BB {
    const piece_ind = bitboard.indFromPlacebit(piece);

    const diag = move_gen_lookup.sliderDiagonals[piece_ind];
    const antidiag = move_gen_lookup.sliderAntidiagonals[piece_ind];

    const diag_o = occupied & diag;
    const antidiag_o = occupied & antidiag;
    const pos_diag_ray = (diag_o ^ (diag_o -% (2 *% piece))) & diag;
    const pos_antidiag_ray = (antidiag_o ^ (antidiag_o -% (2 *% piece))) & antidiag;

    const rev_piece = @bitReverse(piece);
    const rev_diag_o = @bitReverse(diag_o);
    const rev_antidiag_o = @bitReverse(antidiag_o);
    const neg_diag_ray = @bitReverse(rev_diag_o ^ (rev_diag_o -% (2 *% rev_piece))) & diag;
    const neg_antidiag_ray = @bitReverse(rev_antidiag_o ^ (rev_antidiag_o -% (2 *% rev_piece))) & antidiag;

    return pos_diag_ray | neg_diag_ray | pos_antidiag_ray | neg_antidiag_ray;
}

/// Calculates moves of all sliding pieces
/// Useful for finding attacked squares or moves
/// movable_mask determines behaviour
/// enemy or empty: attacked squares
/// empty: movable, non-attacked squares
/// bitboard.all: full ranges of motion (skewers, pins, etc.)
fn sliderMovesOld(hv_sliders: BB, diag_sliders: BB, movable_mask: BB) BB {
    // North, South, East, West
    var hv_iter = [_]BB{hv_sliders} ** 4;
    // NE, SE, SW, NW
    var diag_iter = [_]BB{diag_sliders} ** 4;
    var move_mask: BB = 0;
    inline for (0..8) |_| {
        hv_iter[0] = bitboard.shiftNorth(hv_iter[0], 1) & movable_mask;
        hv_iter[1] = bitboard.shiftSouth(hv_iter[1], 1) & movable_mask;
        hv_iter[2] = bitboard.shiftEast(hv_iter[2], 1) & movable_mask;
        hv_iter[3] = bitboard.shiftWest(hv_iter[3], 1) & movable_mask;

        diag_iter[0] = bitboard.shiftNE(diag_iter[0], 1) & movable_mask;
        diag_iter[1] = bitboard.shiftSE(diag_iter[1], 1) & movable_mask;
        diag_iter[2] = bitboard.shiftSW(diag_iter[2], 1) & movable_mask;
        diag_iter[3] = bitboard.shiftNW(diag_iter[3], 1) & movable_mask;

        move_mask |= hv_iter[0] | hv_iter[1] | hv_iter[2] | hv_iter[3] |
            diag_iter[0] | diag_iter[1] | diag_iter[2] | diag_iter[3];
    }

    return move_mask;
}

/// Kogge-Stone algorithm for flood fill
/// Calculates moves of all orthogonally-sliding pieces
/// Useful for finding attacked squares or moves
fn hvSliderMovesParallel(hv_sliders: BB, occupied: BB) BB {
    var empty = (~occupied) & (~bitboard.rank1);
    var hv_north = hv_sliders;
    hv_north |= empty & bitboard.shiftNorth(hv_north, 1);
    empty = empty & bitboard.shiftNorth(empty, 1);
    hv_north |= empty & bitboard.shiftNorth(hv_north, 2);
    empty = empty & bitboard.shiftNorth(empty, 2);
    hv_north |= empty & bitboard.shiftNorth(hv_north, 4);
    hv_north |= bitboard.shiftNorth(hv_north, 1);

    empty = (~occupied) & (~bitboard.rank8);
    var hv_south = hv_sliders;
    hv_south |= empty & bitboard.shiftSouth(hv_south, 1);
    empty = empty & bitboard.shiftSouth(empty, 1);
    hv_south |= empty & bitboard.shiftSouth(hv_south, 2);
    empty = empty & bitboard.shiftSouth(empty, 2);
    hv_south |= empty & bitboard.shiftSouth(hv_south, 4);
    hv_south |= bitboard.shiftSouth(hv_south, 1);

    empty = (~occupied) & (~bitboard.fileA);
    var hv_east = hv_sliders;
    hv_east |= empty & bitboard.shiftEast(hv_east, 1);
    empty = empty & bitboard.shiftEast(empty, 1);
    hv_east |= empty & bitboard.shiftEast(hv_east, 2);
    empty = empty & bitboard.shiftEast(empty, 2);
    hv_east |= empty & bitboard.shiftEast(hv_east, 4);
    hv_east |= bitboard.shiftEast(hv_east, 1);

    empty = (~occupied) & (~bitboard.fileH);
    var hv_west = hv_sliders;
    hv_west |= empty & bitboard.shiftWest(hv_west, 1);
    empty = empty & bitboard.shiftWest(empty, 1);
    hv_west |= empty & bitboard.shiftWest(hv_west, 2);
    empty = empty & bitboard.shiftWest(empty, 2);
    hv_west |= empty & bitboard.shiftWest(hv_west, 4);
    hv_west |= bitboard.shiftWest(hv_west, 1);

    return (hv_north | hv_south | hv_east | hv_west) ^ hv_sliders;
}

/// Kogge-Stone algorithm for flood fill
/// Calculates moves of all diagonally-sliding pieces
/// Useful for finding attacked squares or moves
fn diagSliderMovesParallel(diag_sliders: BB, occupied: BB) BB {
    var empty = (~occupied) & (~bitboard.rank1);
    var diag_ne = diag_sliders;
    diag_ne |= empty & bitboard.shiftNE(diag_ne, 1);
    empty = empty & bitboard.shiftNE(empty, 1);
    diag_ne |= empty & bitboard.shiftNE(diag_ne, 2);
    empty = empty & bitboard.shiftNE(empty, 2);
    diag_ne |= empty & bitboard.shiftNE(diag_ne, 4);
    diag_ne |= bitboard.shiftNE(diag_ne, 1);

    empty = (~occupied) & (~bitboard.rank8);
    var diag_se = diag_sliders;
    diag_se |= empty & bitboard.shiftSE(diag_se, 1);
    empty = empty & bitboard.shiftSE(empty, 1);
    diag_se |= empty & bitboard.shiftSE(diag_se, 2);
    empty = empty & bitboard.shiftSE(empty, 2);
    diag_se |= empty & bitboard.shiftSE(diag_se, 4);
    diag_se |= bitboard.shiftSE(diag_se, 1);

    empty = (~occupied) & (~bitboard.fileA);
    var diag_sw = diag_sliders;
    diag_sw |= empty & bitboard.shiftSW(diag_sw, 1);
    empty = empty & bitboard.shiftSW(empty, 1);
    diag_sw |= empty & bitboard.shiftSW(diag_sw, 2);
    empty = empty & bitboard.shiftSW(empty, 2);
    diag_sw |= empty & bitboard.shiftSW(diag_sw, 4);
    diag_sw |= bitboard.shiftSW(diag_sw, 1);

    empty = (~occupied) & (~bitboard.fileH);
    var diag_nw = diag_sliders;
    diag_nw |= empty & bitboard.shiftNW(diag_nw, 1);
    empty = empty & bitboard.shiftNW(empty, 1);
    diag_nw |= empty & bitboard.shiftNW(diag_nw, 2);
    empty = empty & bitboard.shiftNW(empty, 2);
    diag_nw |= empty & bitboard.shiftNW(diag_nw, 4);
    diag_nw |= bitboard.shiftNW(diag_nw, 1);

    return (diag_ne | diag_se | diag_sw | diag_nw) ^ diag_sliders;
}

fn kingMoves(king: bitboard.Placebit) BB {
    const king_ind = bitboard.indFromPlacebit(king);
    return move_gen_lookup.kingMoveLookup[king_ind];
}

////////////////////////////////
// Testing
////////////////////////////////
test "pawn pushes" {
    try testing.expectEqual(pawnPushes(bitboard.rank2, .White), bitboard.rank3);
    try testing.expectEqual(pawnPushes(bitboard.rank2 & bitboard.fileB, .White), bitboard.rank3 & bitboard.fileB);
    try testing.expectEqual(pawnPushes(bitboard.rank4, .Black), bitboard.rank3);
    try testing.expectEqual(pawnPushes(bitboard.rank7, .Black), bitboard.rank6);
}

test "pawn double pushes" {
    try testing.expectEqual(pawnDoublePushes(bitboard.rank3, .White), bitboard.rank4);
    try testing.expectEqual(pawnDoublePushes(bitboard.rank4, .White), 0);
    try testing.expectEqual(pawnDoublePushes(bitboard.rank3 & bitboard.fileB, .White), bitboard.rank4 & bitboard.fileB);

    try testing.expectEqual(pawnDoublePushes(bitboard.rank6, .Black), bitboard.rank5);
    try testing.expectEqual(pawnDoublePushes(bitboard.rank5, .Black), 0);
    try testing.expectEqual(pawnDoublePushes(bitboard.rank6 & bitboard.fileB, .Black), bitboard.rank5 & bitboard.fileB);
}

test "pawn attacks" {
    // All pawns on rank 2 can attack all of rank 3
    try testing.expectEqual(pawnAttacks(bitboard.rank2, .White), bitboard.rank3);

    // central pawns
    const b2 = bitboard.rank2 & bitboard.fileB;
    const a3c3 = bitboard.rank3 & (bitboard.fileA | bitboard.fileC);
    const a1c1 = bitboard.rank1 & (bitboard.fileA | bitboard.fileC);
    try testing.expectEqual(pawnAttacks(b2, .White), a3c3);
    try testing.expectEqual(pawnAttacks(b2, .Black), a1c1);

    // Edge pawns
    const a2h2 = bitboard.rank2 & (bitboard.fileA | bitboard.fileH);
    const b3g3 = bitboard.rank3 & (bitboard.fileB | bitboard.fileG);
    const b1g1 = bitboard.rank1 & (bitboard.fileB | bitboard.fileG);
    try testing.expectEqual(pawnAttacks(a2h2, .White), b3g3);
    try testing.expectEqual(pawnAttacks(a2h2, .Black), b1g1);
}

test "knight behaviour equality" {
    // There are two different implementations for knight movement for different use cases
    // This tests that they are equivalent in all common uses
    for (0..64) |i| {
        const pos_ind = chess.PosInd{ .ind = @truncate(i) };
        const pos = bitboard.placebitFromInd(pos_ind);
        try testing.expect(knightMovesIndividual(pos) == knightMovesParallel(pos));
    }
}

test "knight moves" {
    // Unobstructed
    const e4 = bitboard.rank4 & bitboard.fileE;
    const e4_moves = (bitboard.rank2 & (bitboard.fileD | bitboard.fileF)) | (bitboard.rank6 & (bitboard.fileD | bitboard.fileF)) | (bitboard.rank3 & (bitboard.fileC | bitboard.fileG)) | (bitboard.rank5 & (bitboard.fileC | bitboard.fileG));
    try testing.expectEqual(knightMovesIndividual(e4), e4_moves);

    // Corners
    const a1 = bitboard.rank1 & bitboard.fileA;
    const a1_moves = (bitboard.rank2 & bitboard.fileC) | (bitboard.rank3 & bitboard.fileB);
    try testing.expectEqual(knightMovesIndividual(a1), a1_moves);

    const a8 = bitboard.rank8 & bitboard.fileA;
    const a8_moves = (bitboard.rank7 & bitboard.fileC) | (bitboard.rank6 & bitboard.fileB);
    try testing.expectEqual(knightMovesIndividual(a8), a8_moves);

    const h1 = bitboard.rank1 & bitboard.fileH;
    const h1_moves = (bitboard.rank2 & bitboard.fileF) | (bitboard.rank3 & bitboard.fileG);
    try testing.expectEqual(knightMovesIndividual(h1), h1_moves);

    const h8 = bitboard.rank8 & bitboard.fileH;
    const h8_moves = (bitboard.rank7 & bitboard.fileF) | (bitboard.rank6 & bitboard.fileG);
    try testing.expectEqual(knightMovesIndividual(h8), h8_moves);
}

test "lateral slider moves" {
    // Unobstructed movement
    const a1 = bitboard.rank1 & bitboard.fileA;
    const a1_moves = (bitboard.rank1 | bitboard.fileA) ^ a1;
    const found_a1_moves = hvSliderMovesIndividual(a1, a1);
    // bitboard.print(found_a1_moves);
    try testing.expectEqual(found_a1_moves, a1_moves);

    const e4 = bitboard.rank4 & bitboard.fileE;
    const e4_moves = (bitboard.rank4 | bitboard.fileE) ^ e4;
    const found_e4_moves = hvSliderMovesIndividual(e4, e4);
    // bitboard.print(found_e4_moves);
    try testing.expectEqual(found_e4_moves, e4_moves);
}
