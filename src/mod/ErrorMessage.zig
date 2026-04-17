const std = @import("std");
const Self = @This();

const Position = @import("Position.zig");

position: Position,
message: []const u8,

pub fn debug(self: Self) void {
    std.debug.print("[{f}] Error: {s}\n", .{self.position, self.message});
}