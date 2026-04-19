const std = @import("std");

const Self = @This();

line: u32,
col: u32,

pub fn addToCol(self: Self, n: u32) Self {
    return .{
        .line = self.line,
        .col = self.col + n,
    };
}

pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.print("{}:{}", .{ self.line, self.col });
}
