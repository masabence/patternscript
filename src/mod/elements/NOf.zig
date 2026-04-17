const std = @import("std");
const Writer = std.Io.Writer;
const Element = @import("../Element.zig");

const Self = @This();

n: []const u8,
plus: bool,
content: *const Element,


pub fn compile(self: Self, writer: *Writer, strict: bool) Writer.Error!void {

    if (!self.plus and eql(self.n, "1")) {
        try self.content.value.compile(writer, strict);
        return;
    }

    try self.content.value.compile(writer, true);

    if (self.plus) {
        if (eql(self.n, "1")) {
            try writer.writeByte('+');
            return;
        }

        if (eql(self.n, "0")) {
            try writer.writeByte('*');
            return;
        }
    }


    try writer.writeByte('{');
    try writer.writeAll(self.n);
    if (self.plus) {
        try writer.writeByte(',');
    }
    try writer.writeByte('}');
}

inline fn eql(str1: []const u8, str2: []const u8) bool {
    return std.mem.eql(u8, str1, str2);
}