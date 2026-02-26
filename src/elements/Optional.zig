const std = @import("std");
const Writer = std.Io.Writer;
const Element = @import("../element.zig");

const Self = @This();

content: *Element,


pub fn compile(self: Self, writer: *Writer) Writer.Error!void {

    try self.content.value.compile(writer, true);
    try writer.writeByte('?');

}