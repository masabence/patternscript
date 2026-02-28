const std = @import("std");
const Writer = std.Io.Writer;
const Element = @import("../element.zig");

const Self = @This();

content: *const Element,
name: ?[]const u8,


pub fn compile(self: Self, writer: *Writer) Writer.Error!void {

    try writer.writeByte('(');

    if (self.name) |name| {
        try writer.print("?<{s}>", .{name});
    }

    try self.content.value.compile(writer, false);
    try writer.writeByte(')');
}