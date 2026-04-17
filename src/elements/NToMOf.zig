const std = @import("std");
const Writer = std.Io.Writer;
const Element = @import("../Element.zig");

const Self = @This();

n: []const u8,
m: []const u8,
content: *const Element,


pub fn compile(self: Self, writer: *Writer) Writer.Error!void {

    try self.content.value.compile(writer, true);

    try writer.writeByte('{');
    try writer.writeAll(self.n);
    try writer.writeByte(',');
    try writer.writeAll(self.m);
    try writer.writeByte('}');
}