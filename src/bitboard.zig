const std = @import("std");

pub const Bitboard = struct {
    const Self = @This();

    bits: u64,

    pub fn empty() Self {
        return Self{ .bits = 0 };
    }

    pub fn initFromNum(num: u64) Self {
        return Self{ .bits = num };
    }

    pub fn getBit(self: Self, ind: u8) u1 {
        return @truncate(self.bits >> @truncate(ind));
    }
};
