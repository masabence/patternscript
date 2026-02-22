const std = @import("std");
const Writer = std.Io.Writer;
const Element = @import("../element.zig").Element;

const Self = @This();

content: *Element,


pub fn compile(self: Self, writer: *Writer) Writer.Error!void {

    const buf_size = 2;

    var buffer = [buf_size]u8 {0, 0};
    var buffer_writer = std.Io.Writer.fixed(&buffer);
    self.content.compile(&buffer_writer, false) catch {
        std.debug.panic("Atom overfilled {} byte buffer", .{buf_size});
    };

    inline for (buffer) |c| {
        if (c == 0) {
            return;
        }

        try writer.writeByte(std.ascii.toUpper(c));
    }

}