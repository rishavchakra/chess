const chess = @import("chess.zig");
const bitboard = @import("bitboard.zig");
const move_gen = @import("move_gen.zig");

pub const start_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
pub const test_fen = "rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2";

pub const Board = struct {
    const Self = @This();
    const Bitboard = bitboard.Bitboard;

    white: Bitboard,
    black: Bitboard,
    pawn: Bitboard,
    bishop: Bitboard,
    knight: Bitboard,
    rook: Bitboard,
    queen: Bitboard,
    king: Bitboard,
    side: chess.Side,

    pub fn initFromFen(fen_str: []const u8) Self {
        var pos: chess.PosRankFile = chess.PosRankFile.init(7, 0);

        var white: Bitboard = 0;
        var black: Bitboard = 0;
        var pawn: Bitboard = 0;
        var bishop: Bitboard = 0;
        var knight: Bitboard = 0;
        var rook: Bitboard = 0;
        var queen: Bitboard = 0;
        var king: Bitboard = 0;

        for (fen_str) |fen_char| {
            if (fen_char == '/') {
                pos.rank -= 1;
                pos.file = 0;
                continue;
            } else if (fen_char == ' ') {
                break;
            }
            if (fen_char > 47 and fen_char < 57) {
                pos.file +%= @truncate(fen_char - 0x30);
                continue;
            }
            // const char_side: chess.Side = if (fen_char < 0x60) .White else .Black;
            // const piece_char = if (fen_char > 0x60) fen_char - 0x20 else fen_char;
            const piece_bit: Bitboard = @as(u64, 1) << pos.toInd().ind;
            switch (fen_char) {
                0x41...0x5A => white |= piece_bit,
                0x61...0x7A => black |= piece_bit,
                else => unreachable,
            }
            switch (fen_char) {
                'K', 'k' => king |= piece_bit,
                'Q', 'q' => queen |= piece_bit,
                'R', 'r' => rook |= piece_bit,
                'N', 'n' => knight |= piece_bit,
                'B', 'b' => bishop |= piece_bit,
                'P', 'p' => pawn |= piece_bit,
                else => unreachable,
            }
            pos.file +%= 1;
        }

        return Self{
            .white = white,
            .black = black,
            .pawn = pawn,
            .bishop = bishop,
            .knight = knight,
            .rook = rook,
            .queen = queen,
            .king = king,
            .side = chess.Side.White,
        };
    }

    pub fn makeMove(self: *Self, move: chess.Move) void {
        _ = move;
        _ = self;
    }

    pub fn initBoardWithMove(self: *const Self, move: chess.Move) void {
        _ = move;
        _ = self;
    }

    // TODO: Replace with type of move list
    fn getMoves(self: *const Self, side: chess.Side) void {
        const w_pawn = self.white & self.pawn;
        const b_pawn = self.black & self.pawn;
        const w_bishop = self.white & self.bishop;
        _ = w_bishop;
        const b_bishop = self.black & self.bishop;
        _ = b_bishop;
        const w_knight = self.white & self.knight;
        _ = w_knight;
        const b_knight = self.black & self.knight;
        _ = b_knight;
        const w_rook = self.white & self.rook;
        _ = w_rook;
        const b_rook = self.black & self.rook;
        _ = b_rook;
        const w_queen = self.white & self.queen;
        _ = w_queen;
        const b_queen = self.black & self.queen;
        _ = b_queen;
        const w_king = self.white & self.king;
        _ = w_king;
        const b_king = self.black & self.king;
        _ = b_king;
        const empty = ~(self.white & self.black);

        const pawn_pushes = empty & (if (side == .White) bitboard.shiftNorth(w_pawn, 1) else bitboard.shiftSouth(b_pawn, 1));
        _ = pawn_pushes;
        const double_pawn_pushes = empty & (if (side == .White) 0x00000000ff000000 else 0x000000ff00000000) & 1;
        _ = double_pawn_pushes;
    }

    fn getWhiteMoves(self: *const Self) void {
        const w_pawn = self.white & self.pawn;
        const b_pawn = self.black & self.pawn;
        _ = b_pawn;
        const w_bishop = self.white & self.bishop;
        const b_bishop = self.black & self.bishop;
        _ = b_bishop;
        const w_knight = self.white & self.knight;
        const b_knight = self.black & self.knight;
        _ = b_knight;
        const w_rook = self.white & self.rook;
        const b_rook = self.black & self.rook;
        _ = b_rook;
        const w_queen = self.white & self.queen;
        const b_queen = self.black & self.queen;
        _ = b_queen;
        const w_king = self.white & self.king;
        const b_king = self.black & self.king;
        _ = b_king;
        const empty = ~(self.white & self.black);
        const diag_sliders = w_bishop | w_queen;
        _ = diag_sliders;
        const vh_sliders = w_rook | w_queen;
        _ = vh_sliders;

        const pawn_pushes = empty & bitboard.shiftNorth(w_pawn, 1);
        const double_pawn_pushes = empty & pawn_pushes & 0x00000000ff000000;

        const knight_moves = move_gen.getKnightAttacks(w_knight);

        const king_ind = @ctz(w_king);
        const king_moves = move_gen.kingMoveLookup[king_ind];

        return pawn_pushes | double_pawn_pushes | knight_moves | king_moves;
    }
};
