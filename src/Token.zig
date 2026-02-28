const Self = @This();
const Position = @import("Position.zig");

kind: Kind,
lexeme: []const u8,
position: Position,

pub const Kind = enum {
    string, pattern, identifier, name, number,
    equal, plus, dash, comma, lcurly, rcurly,
    kw_any, kw_digit, kw_wordchar, kw_whitespace, kw_boundary, kw_not,
    kw_of, kw_from, kw_except, kw_chars, kw_range,
    kw_either, kw_or,
    kw_capture,
    kw_optional,
    kw_let,
    kw_start, kw_end,
    illegal,
};

pub fn len(self: Self) usize {
    return self.lexeme.len;
}

pub fn stringValue(self: Self) []const u8 {
    return self.lexeme[1..self.lexeme.len-1];
}