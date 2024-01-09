const std = @import("std");
const testing = std.testing;
const bitboard = @import("bitboard.zig");
const BB = bitboard.Bitboard;
const board = @import("board.zig");
const chess = @import("chess.zig");
const move_gen_lookup = @import("move_gen_lookup.zig");

//////// Legal moves ////////

const MoveLimiter = struct {
    king_block: BB,
    check_mask: BB,
    pin_ortho: BB,
    pin_diag: BB,
};

fn calculateMoveLimiters(chessboard: *const board.Board, comptime flags: board.BoardFlags) MoveLimiter {
    var ret = MoveLimiter{
        .king_block = 0,
        .check_mask = bitboard.all,
        .pin_ortho = 0,
        .pin_diag = 0,
    };

    const ally_mask = switch (flags.side) {
        .White => chessboard.white,
        .Black => chessboard.black,
    };
    const enemy_mask = switch (flags.side) {
        .White => chessboard.black,
        .Black => chessboard.white,
    };
    const ep_pawn_mask = switch (flags.side) {
        .White => bitboard.shiftNorth(chessboard.ep, 1),
        .Black => bitboard.shiftSouth(chessboard.ep, 1),
    };

    const occupied = chessboard.black | chessboard.white;
    const enemy_hv_sliders = enemy_mask & (chessboard.rook | chessboard.queen);
    const enemy_diag_sliders = enemy_mask & (chessboard.bishop | chessboard.queen);
    const enemy_knights = enemy_mask & chessboard.knight;
    const enemy_pawns = enemy_mask & chessboard.pawn;
    const ally_king = ally_mask & chessboard.king;
    const occ_without_king = occupied ^ ally_king;
    const ally_king_ind = bitboard.indFromPlacebit(ally_king).ind;

    // King not included in the slider move calculation
    // If it was, the king could block vision to the square behind it (away from the sliding attacker)
    // and this would be incorrectly registered as a valid move
    const hv_attacks = hvSliderMovesParallel(enemy_hv_sliders, occ_without_king);
    const diag_attacks = diagSliderMovesParallel(enemy_diag_sliders, occ_without_king);
    const knight_attacks = knightMovesParallel(enemy_knights);
    const pawn_attacks = pawnAttacks(enemy_pawns, flags.side.oppositeSide());

    ret.king_block = hv_attacks | diag_attacks | knight_attacks | pawn_attacks;

    const king_ortho = move_gen_lookup.sliderFiles[ally_king_ind] | move_gen_lookup.sliderRanks[ally_king_ind];
    const king_diags = move_gen_lookup.sliderDiagonals[ally_king_ind] | move_gen_lookup.sliderAntidiagonals[ally_king_ind];
    const ortho_poss_checkers = enemy_hv_sliders & king_ortho;
    const diags_poss_checkers = enemy_diag_sliders & king_diags;
    // Enemy ortho-sliding pieces and the squares they see
    // Including the pieces themselves (they will be included in the check mask)
    const ortho_checkable_attacks = hvSliderMovesParallel(ortho_poss_checkers, occupied) | ortho_poss_checkers;
    const diags_checkable_attacks = diagSliderMovesParallel(diags_poss_checkers, occupied) | diags_poss_checkers;
    // Squares seen by ally king
    const ortho_king_seen = hvSliderMovesSingle(ally_king, occupied);
    const diags_king_seen = diagSliderMovesSingle(ally_king, occupied);
    // Intersection of squares seen by king and squares seen by enemy sliders
    // is either empty (>1 piece in between)
    // 1 bit (single pinned piece in between)
    // >1 bit (no pinned piece; direct check)
    // Ignoring non-enemy-sliding pieces in between 
    const possible_ortho_pins = occupied & ~enemy_hv_sliders;
    const possible_diag_pins = occupied & ~enemy_diag_sliders;
    // Possibly better way of doing this: king_seen & enemy_sliders gives checkers, pathBetween gets bitboard
    // Would remove second set of parallel slider checks
    const ortho_checks = (ortho_king_seen & ~possible_ortho_pins) & (ortho_checkable_attacks & ~possible_ortho_pins);
    const diag_checks = (diags_king_seen & possible_diag_pins) & (diags_checkable_attacks & possible_diag_pins);
    const knight_checks = knightMovesSingle(ally_king) & enemy_knights;
    const pawn_checks = pawnAttacks(ally_king, flags.side) & enemy_pawns;

    // Unfortunately, idk any way to turn only 0s to filled bitboards branchlessly.
    // Tried: wraparound subtract 1, non-wraparound add 1
    // subtract with overflow bit, multiply overflow bit with filled bitboard
    // subtract with error check, catch error => filled bitboard
    // All have branches and this approach has the simplest asm
    if (ortho_checks != 0) {
        ret.check_mask = ortho_checks;
    } else if (diag_checks != 0) {
        // else if because impossible to have ortho and diag checks simultaneously
        // eliminates a branch when there is an ortho check
        ret.check_mask = diag_checks;
    } 
    // Double check possible with a pawn and an ortho, but not with any other piece type
    if (pawn_checks != 0) {
        ret.check_mask &= pawn_checks;
    }
    if (knight_checks != 0) {
        ret.check_mask &= knight_checks;
    }

    const ortho_skewers = hvSliderSkewerSingle(ally_king, ortho_king_seen & ally_mask, occupied);
    const diag_skewers = diagSliderSkewerSingle(ally_king, diags_king_seen & ally_mask, occupied);

    // By this calculation, pin masks will include any check masks
    // but that shouldn't matter because pinned pieces cannot move to other parts of the same pin
    if (ortho_skewers & enemy_hv_sliders != 0) {
        ret.pin_ortho = ortho_skewers;
    }
    if (diag_skewers & enemy_diag_sliders != 0) {
        ret.pin_diag = diag_skewers;
    }

    // TODO: This branch is COLD and should not be checked every single move generation
    // maybe: overarching switch statement for board flags
    // @setCold compiler hint currently not applicable to non-function scope branches
    if (flags.has_enpassant) {
        const king_rank = move_gen_lookup.sliderRanks[ally_king_ind];
        const ep_takers_pos = ally_mask & chessboard.pawn & (bitboard.shiftEast(ep_pawn_mask, 1) | bitboard.shiftWest(ep_pawn_mask, 1));
        const occ_without_ep = occupied ^ ep_pawn_mask; // Should mask out single EP pawn
        const ep_king_seen = hvSliderMovesSingle(ally_king, occ_without_ep) & king_rank;
        const ep_king_skewer = hvSliderSkewerSingle(ally_king, ep_king_seen & ep_takers_pos, occ_without_ep);
        // If there's an HV attacker preventing taking EP
        if (ep_king_skewer & enemy_hv_sliders != 0) {
            ret.pin_ortho |= ep_king_skewer;
        }
    }

    return ret;
}

/// Calculates and returns skewering rays of an orthogonally-sliding piece
/// Skewering ray: squares seen by a piece either directly or through one piece
fn hvSliderSkewerSingle(piece: bitboard.Placebit, blockers: BB, occupied: BB) BB {
    const occ_without_attacked = occupied ^ blockers;
    return hvSliderMovesSingle(piece, occ_without_attacked);
}

/// Calculates and returns skewering rays of an diagonally-sliding piece
/// Skewering ray: squares seen by a piece either directly or through one piece
fn diagSliderSkewerSingle(piece: bitboard.Placebit, blockers: BB, occupied: BB) BB {
    const occ_without_attacked = occupied ^ blockers;
    return diagSliderMovesSingle(piece, occ_without_attacked);
}

//////// Pseudolegal piece moves ////////

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
fn knightMovesSingle(knight: bitboard.Placebit) BB {
    const knight_ind = bitboard.indFromPlacebit(knight);
    return move_gen_lookup.knightMoveLookup[knight_ind.ind];
}

/// Calculates the valid moves of a single orthogonally-sliding piece
/// Treats all occupied squares as attackable, whether ally or enemy
/// bitwise & with enemy mask to get attacked squares
fn hvSliderMovesSingle(piece: bitboard.Placebit, occupied: BB) BB {
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
fn diagSliderMovesSingle(piece: bitboard.Placebit, occupied: BB) BB {
    const piece_ind = bitboard.indFromPlacebit(piece).ind;

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
test pawnPushes {
    try testing.expectEqual(pawnPushes(bitboard.rank2, .White), bitboard.rank3);
    try testing.expectEqual(pawnPushes(bitboard.rank2 & bitboard.fileB, .White), bitboard.rank3 & bitboard.fileB);
    try testing.expectEqual(pawnPushes(bitboard.rank4, .Black), bitboard.rank3);
    try testing.expectEqual(pawnPushes(bitboard.rank7, .Black), bitboard.rank6);
}

test pawnDoublePushes {
    try testing.expectEqual(pawnDoublePushes(bitboard.rank3, .White), bitboard.rank4);
    try testing.expectEqual(pawnDoublePushes(bitboard.rank4, .White), 0);
    try testing.expectEqual(pawnDoublePushes(bitboard.rank3 & bitboard.fileB, .White), bitboard.rank4 & bitboard.fileB);

    try testing.expectEqual(pawnDoublePushes(bitboard.rank6, .Black), bitboard.rank5);
    try testing.expectEqual(pawnDoublePushes(bitboard.rank5, .Black), 0);
    try testing.expectEqual(pawnDoublePushes(bitboard.rank6 & bitboard.fileB, .Black), bitboard.rank5 & bitboard.fileB);
}

test pawnAttacks {
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
        try testing.expect(knightMovesSingle(pos) == knightMovesParallel(pos));
    }
}

test "knight moves" {
    // Unobstructed
    const e4 = bitboard.rank4 & bitboard.fileE;
    const e4_moves = (bitboard.rank2 & (bitboard.fileD | bitboard.fileF)) | (bitboard.rank6 & (bitboard.fileD | bitboard.fileF)) | (bitboard.rank3 & (bitboard.fileC | bitboard.fileG)) | (bitboard.rank5 & (bitboard.fileC | bitboard.fileG));
    try testing.expectEqual(knightMovesSingle(e4), e4_moves);

    // Corners
    const a1 = bitboard.rank1 & bitboard.fileA;
    const a1_moves = (bitboard.rank2 & bitboard.fileC) | (bitboard.rank3 & bitboard.fileB);
    try testing.expectEqual(knightMovesSingle(a1), a1_moves);

    const a8 = bitboard.rank8 & bitboard.fileA;
    const a8_moves = (bitboard.rank7 & bitboard.fileC) | (bitboard.rank6 & bitboard.fileB);
    try testing.expectEqual(knightMovesSingle(a8), a8_moves);

    const h1 = bitboard.rank1 & bitboard.fileH;
    const h1_moves = (bitboard.rank2 & bitboard.fileF) | (bitboard.rank3 & bitboard.fileG);
    try testing.expectEqual(knightMovesSingle(h1), h1_moves);

    const h8 = bitboard.rank8 & bitboard.fileH;
    const h8_moves = (bitboard.rank7 & bitboard.fileF) | (bitboard.rank6 & bitboard.fileG);
    try testing.expectEqual(knightMovesSingle(h8), h8_moves);
}

test "lateral slider moves" {
    // Unobstructed movement
    const a1 = bitboard.rank1 & bitboard.fileA;
    const a1_moves = (bitboard.rank1 | bitboard.fileA) ^ a1;
    const found_a1_moves = hvSliderMovesSingle(a1, a1);
    // bitboard.print(found_a1_moves);
    try testing.expectEqual(found_a1_moves, a1_moves);

    const e4 = bitboard.rank4 & bitboard.fileE;
    const e4_moves = (bitboard.rank4 | bitboard.fileE) ^ e4;
    const found_e4_moves = hvSliderMovesSingle(e4, e4);
    // bitboard.print(found_e4_moves);
    try testing.expectEqual(found_e4_moves, e4_moves);
}

test calculateMoveLimiters {
    const board1 = board.Board.initFromFen("7k/8/2r3b1/5R2/2B2b2/5r2/rRK4r/7r w - - 0 1");
    const king1 = board1.king & board1.white;
    const limiters1 = calculateMoveLimiters(&board1, .{ .side = .White });
    const expected_pin_ortho = hvSliderMovesSingle(king1, board1.black);
    const expected_check_mask = 0xf800;
    try testing.expectEqual(limiters1.check_mask, expected_check_mask);
    try testing.expect(limiters1.pin_ortho == expected_pin_ortho);
    // try testing.expectEqual(0x)
}
