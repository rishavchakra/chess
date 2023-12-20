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
    const hv_iter = [_]BB{hv_sliders} ** 4;
    // NE, SE, SW, NW
    const diag_iter = [_]BB{diag_sliders} ** 4;
    for (0..8) |i| {
        _ = i;
        hv_iter[0] = bitboard.shiftNorth(hv_iter[0], 1) & movable_mask;
        hv_iter[1] = bitboard.shiftSouth(hv_iter[1], 1) & movable_mask;
        hv_iter[2] = bitboard.shiftEast(hv_iter[2], 1) & movable_mask;
        hv_iter[3] = bitboard.shiftWest(hv_iter[3], 1) & movable_mask;

        diag_iter[0] = bitboard.shiftNE(diag_iter[0], 1) & movable_mask;
        diag_iter[1] = bitboard.shiftSE(diag_iter[1], 1) & movable_mask;
        diag_iter[2] = bitboard.shiftSW(diag_iter[2], 1) & movable_mask;
        diag_iter[3] = bitboard.shiftNW(diag_iter[3], 1) & movable_mask;
    }
}

fn kingMoves(king: bitboard.Placebit) BB {
    const king_ind = bitboard.indFromPlacebit(king);
    return move_gen_lookup.kingMoveLookup[king_ind];
}
