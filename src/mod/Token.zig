const std = @import("std");
const Position = @import("Position.zig");

const Self = @This();

kind: Kind,
lexeme: []const u8,
position: Position,

pub const Kind = enum {
    string,
    pattern,
    charset,
    identifier,
    name,
    number,
    equal,
    plus,
    dash,
    comma,
    lcurly,
    rcurly,
    kw_any,
    kw_digit,
    kw_wordchar,
    kw_whitespace,
    kw_boundary,
    kw_not,
    kw_of,
    kw_from,
    kw_except,
    kw_or,
    kw_capture,
    kw_optional,
    kw_let,
    kw_start,
    kw_end,
    illegal,

    pub fn format(self: Kind, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        const str = switch (self) {
            .string => "string literal",
            .pattern => "pattern literal",
            .charset => "character set literal",
            .identifier => "identifier",
            .name => "name literal",
            .number => "number literal",
            .equal => "'='",
            .plus => "'+'",
            .dash => "'-'",
            .comma => "','",
            .lcurly => "'{'",
            .rcurly => "'}'",
            .kw_any => "'any'",
            .kw_digit => "'digit'",
            .kw_wordchar => "'wordchar'",
            .kw_whitespace => "'whitespace'",
            .kw_boundary => "'boundary'",
            .kw_not => "'not'",
            .kw_of => "'of'",
            .kw_from => "'from'",
            .kw_except => "'except'",
            .kw_or => "'or'",
            .kw_capture => "'capture'",
            .kw_optional => "'optional'",
            .kw_let => "'let'",
            .kw_start => "'start'",
            .kw_end => "'end'",
            .illegal => "illegal",
        };

        try writer.writeAll(str);
    }
};

pub fn len(self: Self) usize {
    return self.lexeme.len;
}

pub fn stringValue(self: Self) []const u8 {
    return self.lexeme[1 .. self.lexeme.len - 1];
}
