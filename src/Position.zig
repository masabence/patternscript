const Self = @This();

line: u32,
col: u32,

pub fn addToCol(self: Self, n: u32) Self {
    return .{
        .line = self.line,
        .col = self.col + n,
    };
}