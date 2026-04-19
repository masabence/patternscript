const std = @import("std");
const Writer = std.Io.Writer;
const Element = @import("../Element.zig");

const Self = @This();

content: *const Element,
negated: bool,

pub fn compile(self: Self, writer: *Writer) Writer.Error!void {
    try writer.writeByte('[');
    if (self.negated) {
        try writer.writeByte('^');
    }
    try self.content.value.compile(writer, false);
    try writer.writeByte(']');
}
