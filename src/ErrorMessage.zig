const std = @import("std");
const Self = @This();

const Position = @import("Position.zig");

position: Position,
message: []const u8,

pub fn debug(self: Self) void {
    std.debug.print("[{}, {}] Error: {s}\n", .{self.position.line, self.position.col, self.message});
}