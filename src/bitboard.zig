const std = @import("std");
const chess = @import("chess.zig");

pub const Bitboard = struct {
    const Self = @This();

    bits: u64,

    pub fn empty() Self {
        return Self{ .bits = 0 };
    }

    pub fn initFromNum(num: u64) Self {
        return Self{ .bits = num };
    }

    pub fn initFromMoveList(move_list: std.ArrayList(chess.Move)) Self {
        var bits: u64 = 0;
        for (move_list.items) |move| {
            const pos_to = chess.movePosTo(move);
            bits |= (@as(u64, 0b1) << pos_to);
        }
        return Self{ .bits = bits };
    }

    pub fn getBit(self: Self, ind: u8) u1 {
        return @truncate(self.bits >> @truncate(ind));
    }
};
