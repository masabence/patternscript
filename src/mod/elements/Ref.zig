const std = @import("std");
const Writer = std.Io.Writer;

const Self = @This();

identifier: []const u8,
mode: Mode,

pub fn compile(self: Self, writer: *Writer) Writer.Error!void {
    try writer.writeByte('\\');

    if (self.mode == .name) {
        try writer.writeAll("k<");
    }

    try writer.writeAll(self.identifier);

    if (self.mode == .name) {
        try writer.writeByte('>');
    }
}

pub const Mode = enum {
    name,
    id,
};