const std = @import("std");
const Writer = std.Io.Writer;

const Self = @This();

str: []const u8,

pub fn compile(self: Self, writer: *Writer, strict: bool) Writer.Error!void {
    const needs_wrapping = strict and self.str.len != 1;

    if (needs_wrapping) {
        try writer.writeAll("(?:");
    }

    for (self.str) |c| {
        switch (c) {
            '.', '?', '/', '\\', '(', ')', '{', '}', '[', ']' => try writer.writeByte('\\'),
            else => {},
        }

        try writer.writeByte(c);
    }

    if (needs_wrapping) {
        try writer.writeByte(')');
    }
}
