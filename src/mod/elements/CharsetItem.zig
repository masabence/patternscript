const std = @import("std");
const Writer = std.Io.Writer;

const Self = @This();

str: []const u8,

pub fn compile(self: Self, writer: *Writer) Writer.Error!void {
    for (self.str) |c| {
        switch (c) {
            // To revise
            // _ => try writer.writeByte('\\'),
            else => {},
        }

        try writer.writeByte(c);
    }
}
