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
fn knightMoves(knights: BB) BB {
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

/// Calculates moves of all sliding pieces
/// Useful for finding attacked squares or moves
/// movable_mask determines behaviour
/// enemy or empty: attacked squares
/// empty: movable, non-attacked squares
/// bitboard.all: full ranges of motion (skewers, pins, etc.)
fn sliderMoves(hv_sliders: BB, diag_sliders: BB, movable_mask: BB) BB {
    // North, South, East, West
    var hv_iter = [_]BB{hv_sliders} ** 4;
    // NE, SE, SW, NW
    var diag_iter = [_]BB{diag_sliders} ** 4;
    var move_mask: BB = 0;
    for (0..8) |_| {
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
        try testing.expect(knightMovesIndividual(pos) == knightMoves(pos));
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
    try testing.expectEqual(sliderMoves(a1, 0, bitboard.all), a1_moves);

    const e4 = bitboard.rank4 & bitboard.fileE;
    const e4_moves = (bitboard.rank4 | bitboard.fileE) ^ e4;
    try testing.expectEqual(sliderMoves(e4, 0, bitboard.all), e4_moves);
}
