const std = @import("std");
const Writer = std.Io.Writer;
const Element = @import("../element.zig").Element;

const Self = @This();

content: *Element,
negated: bool,


pub fn compile(self: Self, writer: *Writer) Writer.Error!void {

    try writer.writeByte('[');
    if (self.negated) {
        try writer.writeByte('^');
    }
    try self.content.compile(writer, false);
    try writer.writeByte(']');
}