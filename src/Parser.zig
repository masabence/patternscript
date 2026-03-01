const std = @import("std");
const Scanner = @import("Scanner.zig");
const Element = @import("element.zig");
const Token = @import("Token.zig");
const ErrorMessage = @import("ErrorMessage.zig");
const Position = @import("Position.zig");
const Allocator = std.mem.Allocator;

const Self = @This();


scanner: *Scanner,
arena: std.heap.ArenaAllocator,
errors: std.ArrayList(ErrorMessage),
bindings: std.StringHashMapUnmanaged(Element),
depth: u32 = 0,

pub fn init(scanner: *Scanner, gpa: Allocator) Self {
    return .{
        .scanner = scanner,
        .arena = .init(gpa),
        .errors = .empty,
        .bindings = .empty,
    };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

/// Result owned by the parser, freed with `deinit`
pub fn parse(self: *Self) Error![]const Element {
    const elements = try self.parseList();

    if (self.scanner.peek() != null) {
        try self.reportError("Expected comma after element", self.scanner.consumed.?, .end);
        return Error.ParseError;
    }

    return elements;

}

/// Main dispatch for the parser.
/// 
/// Returns:
/// * `Element` on success,
/// * `null` if the token is not an entry point,
/// * `ParseError` on incorrect input.
fn parseElement(self: *Self) Error!?Element {
    const t = self.scanner.peek() orelse return null;

    return switch (t.kind) {
        .kw_digit => self.parseAtom("\\d"),
        .kw_wordchar => self.parseAtom("\\w"),
        .kw_whitespace => self.parseAtom("\\s"),
        .kw_boundary => self.parseAtom("\\b"),
        .kw_start => self.parseAtom("^"),
        .kw_end => self.parseAtom("$"),

        .string => self.parseString(Element.Value.initString),
        .pattern => self.parseString(Element.Value.initPattern),

        .number => try self.parseQuantifier(),

        .lcurly => try self.parseBlock(),
        .kw_capture => try self.parseCapture(),

        else => return null,
    };
}

fn parseList(self: *Self) Error![]const Element {
    var elements: std.ArrayList(Element) = .empty;

    const first = try self.parseElement() orelse return &.{};
    try elements.append(self.alloc(), first);

    while (self.match(.comma)) |_| {
        const element = try self.parseElement() 
            orelse return try elements.toOwnedSlice(self.alloc());

        try elements.append(self.alloc(), element);
    }

    return try elements.toOwnedSlice(self.alloc());
}

fn parseBlock(self: *Self) Error!Element {
    const opening = self.getCheckedToken();
    const contents = try self.parseList();

    const closing = try self.matchOrError(.rcurly, 
        try self.format("Unclosed curly brace (opened on {}:{})", .{opening.position.line, opening.position.col})
    );

    return Element {
        .value = .initBlock(contents),
        .start = opening.position,
        .end = closing.position,
    };

}

fn parseAtom(self: *Self, str: []const u8) Element {
    const token = self.getCheckedToken();
    return Element {
        .value = .{ .atom = str },
        .start = token.position,
        .end = token.position.addToCol(@as(u32, @intCast(token.len())) - 1),
    };
}

fn parseString(self: *Self, factory: fn([]const u8) Element.Value) Element {
    const token = self.getCheckedToken();

    return Element {
        .value = factory(token.stringValue()),
        .start = token.position,
        .end = token.position.addToCol(@as(u32, @intCast(token.len())) - 1),
    };
}

fn parseQuantifier(self: *Self) Error!Element {
    const n = self.getCheckedToken();

    try self.limit(&.{.kw_of, .plus, .dash}, "Expected 'of', '+', or '-'");

    if (self.match(.kw_of)) |_| {
        const content = try self.parseOrError("Missing content of quantifier");
        return Element {
            .value = .initNOf(n.lexeme, try self.dupe(content), false),
            .start = n.position,
            .end = content.end,
        };
    }

    if (self.match(.plus)) |_| {
        _ = try self.matchOrError(.kw_of, "Expected 'of' in quantifier");
        const content = try self.parseOrError("Missing content of quantifier");
        return Element {
            .value = .initNOf(n.lexeme, try self.dupe(content), true),
            .start = n.position,
            .end = content.end,
        };
    }

    if (self.match(.dash)) |_| {

        const m = try self.matchOrError(.number, "Expected number in quantifier");
        _ = try self.matchOrError(.kw_of, "Expected 'of' in quantifier");
        const content = try self.parseOrError("Missing content of quantifier");

        return Element {
            .value = .initNToMOf(n.lexeme, m.lexeme, try self.dupe(content)),
            .start = n.position,
            .end = content.end,
        };
    }

    unreachable;
}

fn parseCapture(self: *Self) Error!Element {
    const head = self.getCheckedToken();
    const name = if (self.match(.name)) |token| token.stringValue() else null;
    const content = try self.parseOrError("Expected body for 'capture'");

    return Element {
        .value = .initCapture(name, try self.dupe(content)),
        .start = head.position,
        .end = content.end,
    };
    
}

fn consume(self: *Self, kind: Token.Kind, msg: []const u8) Allocator.Error!void {
    if (self.match(kind)) |_| {
        return;
    }

    if (self.scanner.peek()) |incorrect_token| {
        try self.reportError(msg, incorrect_token, .start);
    }
    else {
        try self.reportError(msg, self.scanner.consumed.?, .end);
    }

}


fn match(self: Self, kind: Token.Kind) ?Token {    
    if (self.scanner.peek()) |token| {
        if (token.kind == kind) {
            return self.scanner.next();
        }
    }

    return null;
}

fn reportError(self: *Self, msg: []const u8, token: Token, target: enum{start, end}) Allocator.Error!void {
    const offset = if (target == .end) @as(u32, @intCast(token.len())) else 0;
    try self.reportErrorByPosition(msg, token.position.addToCol(offset));
}

fn reportErrorByPosition(self: *Self, msg: []const u8, position: Position) Allocator.Error!void {
    try self.errors.append(self.alloc(), .{
        .position = position,
        .message = msg,
    });
}

fn isNumber(str: []const u8) bool {
    for (str) |c| {
        if (!std.ascii.isDigit(c)) {
            return false;
        }
    }

    return true;
}

fn getCheckedToken(self: *Self) Token {
    return self.scanner.next() orelse unreachable;
}

fn nextOrError(self: *Self, msg: []const u8) error{ParseError}!Token {
    if (self.scanner.next()) |next| {
        return next;
    }

    try self.reportError(msg, self.scanner.consumed.?, .end);
    return error.ParseError;
}

fn parseOrError(self: *Self, msg: []const u8) Error!Element {
    return try self.parseElement() orelse {
        try self.reportError(msg, self.scanner.consumed.?, .end);
        return Error.ParseError;
    };
}

fn matchOrError(self: *Self, kind: Token.Kind, msg: []const u8) Error!Token {
    return self.match(kind) orelse {
        try self.reportError(msg, self.scanner.consumed.?, .start);
        return Error.ParseError;
    };
}

fn limit(self: *Self, allowed: []const Token.Kind, msg: []const u8) Error!void {
    const peeked = self.scanner.peek() orelse {
        try self.reportError(msg, self.scanner.consumed.?, .end);
        return Error.ParseError;
    };

    if (!std.mem.containsAtLeast(Token.Kind, allowed, 1, &.{peeked.kind})) {
        try self.reportError(msg, self.scanner.peek().?, .start);
        return Error.ParseError;
    }
}

fn format(self: *Self, comptime fmt: []const u8, args: anytype) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(self.alloc(), fmt, args);
}

fn dupe(self: *Self, e: Element) Allocator.Error!*const Element {
    const ptr = try self.alloc().create(Element);
    ptr.* = e;

    return ptr;
}

fn alloc(self: *Self) std.mem.Allocator {
    return self.arena.allocator();
}


pub const Error = error{ParseError} || Allocator.Error;