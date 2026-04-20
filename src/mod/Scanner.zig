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
arena: std.mem.Allocator,

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
    .{ "optional", .kw_optional },
    .{ "start", .kw_start },
    .{ "end", .kw_end },
    .{ "let", .kw_let },
});

pub fn init(arena: std.mem.Allocator, source: []const u8) Self {
    return .{
        .source = source,
        .start = 0,
        .current = 0,
        .line = 1,
        .line_start = 0,
        .cache = null,
        .consumed = null,
        .arena = arena,
    };
}

pub fn next(self: *Self) !?Token {
    if (self.cache) |cached| {
        self.cache = null;
        self.consumed = cached;
        return cached;
    }

    self.consumed = try self.scanNext();
    return self.consumed;
}

pub fn peek(self: *Self) !?Token {
    if (self.cache) |cached| {
        return cached;
    }

    self.cache = try self.scanNext();
    return self.cache;
}

fn scanNext(self: *Self) !?Token {
    self.start = self.current;

    while (self.consume()) |c| {
        if (std.ascii.isAlphabetic(c) or c == '_') {
            return try self.makeIdentifier();
        }

        if (std.ascii.isDigit(c)) {
            return try self.makeNumber();
        }

        if (c == '\n') {
            self.handleNewline();
        }

        if (std.ascii.isWhitespace(c)) {
            self.start += 1;
            continue;
        }

        switch (c) {
            ',' => return try self.makeToken(.comma),
            '{' => return try self.makeToken(.lcurly),
            '}' => return try self.makeToken(.rcurly),
            '=' => return try self.makeToken(.equal),
            '-' => return try self.makeToken(.dash),
            '+' => return try self.makeToken(.plus),

            '"' => return try self.makeStringLiteral('"', .string),
            '[' => return try self.makeStringLiteral(']', .charset),
            '/' => return try self.makeStringLiteral('/', .pattern),
            '<' => return try self.makeStringLiteral('>', .name),

            else => std.debug.panic("Not implemented character: {c}", .{c}),
        }
    }

    return null;
}

fn makeNumber(self: *Self) !Token {
    while (self.toBeConsumed()) |to_be_consumed| {
        if (!std.ascii.isDigit(to_be_consumed)) {
            break;
        }

        _ = self.consume();
    }

    return try self.makeToken(.number);
}

fn makeIdentifier(self: *Self) !Token {
    while (self.toBeConsumed()) |to_be_consumed| {
        if (!std.ascii.isAlphanumeric(to_be_consumed)) {
            break;
        }
        _ = self.consume();
    }

    if (keywords.get(self.currentLexeme())) |kind| {
        return self.makeToken(kind);
    }

    return try self.makeToken(.identifier);
}

fn makeStringLiteral(self: *Self, comptime end: u8, kind: Token.Kind) !Token {
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

    return try self.makeToken(kind);
}

fn makeToken(self: *Self, kind: Token.Kind) !Token {
    return Token{
        .kind = kind,
        .lexeme = try self.arena.dupe(u8, self.currentLexeme()),
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
