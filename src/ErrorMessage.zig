const std = @import("std");
const Self = @This();

line: u32,
message: []const u8,

pub fn debug(self: Self) void {
    std.debug.print("[{}]: {s}\n", .{self.line, self.message});
}