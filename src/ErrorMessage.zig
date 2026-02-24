const std = @import("std");
const Self = @This();

line: u32,
col: u32,
message: []const u8,

pub fn debug(self: Self) void {
    std.debug.print("[{}, {}] Error: {s}\n", .{self.line, self.col, self.message});
}