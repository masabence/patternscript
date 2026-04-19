const std = @import("std");
const Self = @This();

const Position = @import("Position.zig");

position: Position,
message: []const u8,

pub fn print(self: Self, out: *std.Io.Writer, with_location: bool) !void {
    if (with_location) {
        try out.print("[{f}] Error: {s}\n", .{ self.position, self.message });
    } else {
        try out.print("Error: {s}\n", .{self.message});
    }
}
