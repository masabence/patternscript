const std = @import("std");
const Writer = std.Io.Writer;
const Element = @import("../element.zig").Element;

const Self = @This();

contents: []Element,


pub fn compile(self: Self, writer: *Writer) Writer.Error!void {

    try writer.writeAll("(?:");

    for (0..self.contents.len-1) |i| {
        try self.contents[i].compile(writer, false);
        try writer.writeByte('|');
    }

    try self.contents[self.contents.len-1].compile(writer, false);
    try writer.writeByte(')');

}