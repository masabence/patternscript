const std = @import("std");
const Writer = std.Io.Writer;
const Element = @import("../Element.zig");

const Self = @This();

contents: []const Element,


pub fn compile(self: Self, writer: *Writer, strict: bool) Writer.Error!void {

    if (self.contents.len == 1) {
        return self.contents[0].value.compile(writer, strict);
    }

    if (strict) {
        try writer.writeAll("(?:");
    }

    for (self.contents) |content| {
        try content.value.compile(writer, false);
    }

    if (strict) {
        try writer.writeByte(')');
    }

}