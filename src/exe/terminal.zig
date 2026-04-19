const std = @import("std");

pub fn eraseCurrentLine(stdout: *std.Io.Writer) !void {
    try stdout.writeAll("\x1b[2K\r\x1b[1A");
}
