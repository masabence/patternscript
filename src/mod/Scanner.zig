const std = @import("std");
const Self = @This();
const Token = @import("Token.zig");

source: []const u8,
start: u32,
current: u32,
line_start: u32,
line: u32,
cache: ?Token,
consumed: ?Token,

const keywords = std.StaticStringMap(Token.Kind).initComptime(.{
    .{ "any", .kw_any },
    .{ "digit", .kw_digit },
    .{ "wordchar", .kw_wordchar },
    .{ "whitespace", .kw_whitespace },
    .{ "boundary", .kw_boundary },
    .{ "not", .kw_not },
    .{ "of", .kw_of },
    .{ "from", .kw_from },
    .{ "except", .kw_except },
    .{ "or", .kw_or },
    .{ "capture", .kw_capture },
    .{ "ref", .kw_ref },
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

    self.consumed = self.scanNext();
    return self.consumed;
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

    while (self.consume()) |c| {
        if (std.ascii.isAlphabetic(c) or c == '_') {
            return self.makeIdentifier();
        }

        if (std.ascii.isDigit(c)) {
            return self.makeNumber();
        }

        if (c == '\n') {
            self.handleNewline();
        }

        if (std.ascii.isWhitespace(c)) {
            self.start += 1;
            continue;
        }

        switch (c) {
            ',' => return self.makeToken(.comma),
            '{' => return self.makeToken(.lcurly),
            '}' => return self.makeToken(.rcurly),
            '=' => return self.makeToken(.equal),
            '-' => return self.makeToken(.dash),
            '+' => return self.makeToken(.plus),

            '"' => return self.makeStringLiteral('"', .string),
            '[' => return self.makeStringLiteral(']', .charset),
            '/' => return self.makeStringLiteral('/', .pattern),
            '<' => return self.makeStringLiteral('>', .name),

            else => std.debug.panic("Not implemented character: {c}", .{c}),
        }
    }

    return null;
}

fn makeNumber(self: *Self) Token {
    while (self.toBeConsumed()) |to_be_consumed| {
        if (!std.ascii.isDigit(to_be_consumed)) {
            break;
        }

        _ = self.consume();
    }

    return self.makeToken(.number);
}

fn makeIdentifier(self: *Self) Token {
    while (self.toBeConsumed()) |to_be_consumed| {
        if (!std.ascii.isAlphanumeric(to_be_consumed)) {
            break;
        }
        _ = self.consume();
    }

    if (keywords.get(self.currentLexeme())) |kind| {
        return self.makeToken(kind);
    }

    return self.makeToken(.identifier);
}

fn makeStringLiteral(self: *Self, comptime end: u8, kind: Token.Kind) Token {
    while (self.consume()) |consumed| {
        if (consumed == end) {
            break;
        }

        if (consumed == '\n') {
            const err = self.makeErrorToken(std.fmt.comptimePrint("Expected closing '{c}'", .{end}));
            self.handleNewline();
            return err;
        }
    }

    return self.makeToken(kind);
}

fn makeToken(self: *Self, kind: Token.Kind) Token {
    return Token{
        .kind = kind,
        .lexeme = self.currentLexeme(),
        .position = .{
            .line = self.line,
            .col = self.start - self.line_start + 1,
        },
    };
}

fn makeErrorToken(self: Self, msg: []const u8) Token {
    return Token{
        .kind = .illegal,
        .lexeme = msg,
        .position = .{
            .line = self.line,
            .col = self.start - self.line_start + 1,
        },
    };
}

fn handleNewline(self: *Self) void {
    self.line += 1;
    self.line_start = self.current;
}

fn currentLexeme(self: *Self) []const u8 {
    return self.source[self.start..self.current];
}

/// Returns the character at the current index, and advances
fn consume(self: *Self) ?u8 {
    const char = self.toBeConsumed() orelse return null;
    self.current += 1;
    return char;
}

/// Returns the character at the current index
fn toBeConsumed(self: Self) ?u8 {
    if (self.current >= self.source.len) {
        return null;
    }

    return self.source[self.current];
}
