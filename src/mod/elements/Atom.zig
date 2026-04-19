const std = @import("std");
const Writer = std.Io.Writer;

const Self = @This();

kind: Kind,

pub fn compile(self: Self, writer: *Writer) Writer.Error!void {
    const str = switch (self.kind) {
        .any => ".",
        .digit => "\\d",
        .wordchar => "\\w",
        .whitespace => "\\s",
        .boundary => "\\b",
        .start => "^",
        .end => "$",
    };

    return writer.writeAll(str);
}

pub const Kind = enum {
    any,
    digit,
    wordchar,
    whitespace,
    boundary,
    start,
    end,
};
