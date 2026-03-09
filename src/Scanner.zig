const std = @import("std");
const Self = @This();
const Token = @import("Token.zig");

source: []const u8,
start: usize,
current: usize,
line_start: u32,
line: u32,
cache: ?Token,
consumed: ?Token,

const keywords = std.StaticStringMap(Token.Kind).initComptime(.{
    .{ "any", .kw_any },
    .{ "digit", .kw_digit },
    .{ "wordchar", .kw_wordchar },
    .{ "whitespace", .kw_whitespace },
    .{ "boundary", .kw_boundary} ,
    .{ "not", .kw_not },
    .{ "of", .kw_of },
    .{ "from", .kw_from },
    .{ "except", .kw_except },
    .{ "chars", .kw_chars },
    .{ "range", .kw_range },
    .{ "either", .kw_either },
    .{ "or", .kw_or },
    .{ "capture", .kw_capture },
    .{ "optional", .kw_optional },
    .{ "start", .kw_start },
    .{ "end", .kw_end },
    .{ "let", .kw_let },
});

pub fn init(source: []const u8) Self {
    return .{
        .source = source,
        .start = 0,
        .current = 0,
        .line = 1,
        .line_start = 0,
        .cache = null,
        .consumed = null,
    };
}

pub fn next(self: *Self) ?Token {
    if (self.cache) |cached| {
        self.cache = null;
        self.consumed = cached;
        return cached;
    }

    const result = self.scanNext();
    self.consumed = result;
    return result;
}

pub fn peek(self: *Self) ?Token {
    if (self.cache) |cached| {
        return cached;
    }

    self.cache = self.scanNext();
    return self.cache;
}


fn scanNext(self: *Self) ?Token {
    self.start = self.current;

    while (self.advance()) |c| {

        switch (c) {

            '\n', '\r', '\t', ' ' => {
                self.start += 1;
            },

            '=' => return self.makeToken(.equal),
            '+' => return self.makeToken(.plus),
            '-' => return self.makeToken(.dash),
            ',' => return self.makeToken(.comma),
            '{' => return self.makeToken(.lcurly),
            '}' => return self.makeToken(.rcurly),

            '0'...'9' => return self.makeNumber(),
            'a'...'z', 
            'A'...'Z', '_' => return self.makeIdentifier(),

            '"' => return self.makeStringLiteral('"', .string),
            '<' => return self.makeStringLiteral('>', .name),
            '/' => return self.makeStringLiteral('/', .pattern),
            '[' => return self.makeStringLiteral(']', .charset),
            else => std.debug.panic("Unhandled token character: {c}", .{c}),
        }

    } else return null;
}

fn makeNumber(self: *Self) Token {
    while (self.advance()) |c| {
        if (!std.ascii.isDigit(c)) {
            self.current -= 1;
            break;
        }
    }

    return self.makeToken(.number);
}

fn makeIdentifier(self: *Self) Token {
    while (self.advance()) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') {
            self.current -= 1;
            break;
        }
    }

    const word = self.source[self.start..self.current];

    if (keywords.get(word)) |kw| {
        return self.makeToken(kw);
    }
    
    return self.makeToken(.identifier);
}

fn makeStringLiteral(self: *Self, comptime end: u8, kind: Token.Kind) Token {

    // This is done here to have the error point at the beginning
    const error_token = self.makeErrorToken("Unfinished literal, expected '" ++ .{ end } ++ "'.");

    while (self.advance()) |c| {

        if (c == end) {
            break;
        }

        if (c == '\n') {
            return error_token;
        }

    } else {
        return error_token; // reached eof
    }

    return self.makeToken(kind);
}

fn makeToken(self: *Self, kind: Token.Kind) Token {
    const col = @as(u32, @intCast(self.start + 1)) - self.line_start;
    return Token {
        .kind = kind,
        .lexeme = self.source[self.start..self.current],
        .position = .{ .line = self.line, .col = col, },
    };
}

fn makeErrorToken(self: Self, comptime msg: []const u8) Token {
    const col = @as(u32, @intCast(self.start + 1)) - self.line_start;
    return Token {
        .kind = .illegal,
        .lexeme = msg,
        .position = .{ .line = self.line, .col = col, }
    };
}


fn advance(self: *Self) ?u8 {
    if (self.source.len <= self.current) {
        return null;
    }

    if (self.source[self.current] == '\n') {
        self.line_start = @intCast(self.current+1);
        self.line += 1;
    }

    self.current += 1;
    return self.source[self.current-1];
}