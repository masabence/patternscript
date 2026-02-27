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
pub fn parse(self: *Self) Error![]Element {
    const elements = try self.parseList();

    if (self.scanner.peek() != null) {
        try self.reportError("Expected comma after element", self.scanner.consumed.?, .end);
        return Error.InvalidConstruct;
    }

    return elements;

}

/// Main dispatch for the parser.
/// 
/// Returns:
/// * `Element` on success.
/// * `null` after the stream ended.
/// * `error.MissingToken` when a token was needed, but not found.
/// * `error.InvalidConstruct`when a wrong token was found.
fn parseElement(self: *Self) Error!?Element {
    const t = self.scanner.peek() orelse return null;

    return switch (t.kind) {
        .kw_digit => self.parseAtom("\\d"),
        .kw_wordchar => self.parseAtom("\\w"),
        .kw_whitespace => self.parseAtom("\\s"),
        .kw_boundary => self.parseAtom("\\b"),
        .kw_start => self.parseAtom("^"),
        .kw_end => self.parseAtom("$"),

        .string => self.parseString(.string),
        .pattern => self.parseString(.pattern),

        else => return null,
    };
}

fn parseList(self: *Self) Error![]Element {
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

fn parseAtom(self: *Self, str: []const u8) Element {
    const token = self.scanner.next() orelse unreachable;
    return Element {
        .value = .{ .atom = str },
        .start = token.position,
        .end = token.position.addToCol(@as(u32, @intCast(token.len())) - 1),
    };
}

fn parseString(self: *Self, comptime tag: std.meta.Tag(Element.Value)) Element {
    const token = self.scanner.next() orelse unreachable;

    return Element {
        .value = @unionInit(Element.Value, @tagName(tag), .{ .str = token.stringValue(), } ),
        .start = token.position,
        .end = token.position.addToCol(@as(u32, @intCast(token.len())) - 1),
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
    try self.errors.append(self.alloc(), .{
        .position = token.position.addToCol(offset),
        .message = msg,
    });
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

fn dupe(self: *Self, e: Element) Allocator.Error!*const Element {
    const ptr = try self.alloc().create(Element);
    ptr.* = e;

    return ptr;
}

fn alloc(self: *Self) std.mem.Allocator {
    return self.arena.allocator();
}




pub const Error = error{InvalidConstruct, MissingToken} || Allocator.Error;