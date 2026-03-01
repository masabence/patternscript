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

fn parseElement(self: *Self) Error!?Element {
    var branches_list: std.ArrayList(Element) = .empty;

    const lhs = try self.parseSimpleElement() orelse return null;
    try branches_list.append(self.alloc(), lhs);

    while (self.match(.kw_or)) |_| {
        const branch = try self.parseSimpleOrError("Expected another branch after 'or'");
        try branches_list.append(self.alloc(), branch);
    }

    if (branches_list.items.len == 1) {
        return branches_list.items[0];
    }

    const branches = try branches_list.toOwnedSlice(self.alloc());

    return Element {
        .value = .initEitherOr(branches),
        .start = lhs.start,
        .end = branches[branches.len-1].end,
    };
}

fn parseSimpleElement(self: *Self) Error!?Element {
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
        .kw_optional => try self.parseOptional(),

        .lcurly => try self.parseBlock(),

        .kw_capture => try self.parseCapture(),
        .kw_not => try self.parseNot(),

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

    const closing = try self.matchOrError(.rcurly);

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

    try self.limit(&.{.kw_of, .plus, .dash});

    if (self.match(.kw_of)) |_| {
        const content = try self.parseOrError("Missing content of quantifier");
        return Element {
            .value = .initNOf(n.lexeme, try self.dupe(content), false),
            .start = n.position,
            .end = content.end,
        };
    }

    if (self.match(.plus)) |_| {
        _ = try self.matchOrError(.kw_of);
        const content = try self.parseOrError("Missing content of quantifier");
        return Element {
            .value = .initNOf(n.lexeme, try self.dupe(content), true),
            .start = n.position,
            .end = content.end,
        };
    }

    if (self.match(.dash)) |_| {

        const m = try self.matchOrError(.number);
        _ = try self.matchOrError(.kw_of);
        const content = try self.parseOrError("Missing content of quantifier");

        return Element {
            .value = .initNToMOf(n.lexeme, m.lexeme, try self.dupe(content)),
            .start = n.position,
            .end = content.end,
        };
    }

    unreachable;
}

fn parseOptional(self: *Self) Error!Element {
    const head = self.getCheckedToken();
    const content = try self.parseOrError("Expected body for 'optional'");

    return Element {
        .value = .initOptional(try self.dupe(content)),
        .start = head.position,
        .end = content.end,
    };
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

fn parseNot(self: *Self) Error!Element {
    const head = self.getCheckedToken();

    try self.limit(&.{.kw_digit, .kw_wordchar, .kw_whitespace, .kw_boundary});
    const content = self.parseElement() catch unreachable orelse unreachable;

    return Element {
        .value = .initNot(try self.dupe(content)),
        .start = head.position,
        .end = content.end,
    };

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

fn parseSimpleOrError(self: *Self, msg: []const u8) Error!Element {
    return try self.parseSimpleElement() orelse {
        try self.reportError(msg, self.scanner.consumed.?, .end);
        return Error.ParseError;
    };
}

fn matchOrError(self: *Self, kind: Token.Kind) Error!Token {
    if (self.match(kind)) |matched| {
        return matched;
    }

    const msg: []const u8 = if (self.scanner.peek()) |peeked|
        try self.format("Expected {f}, found {f}", .{ kind, peeked.kind })
    else
        try self.format("Expected {f}", .{kind});


    if (self.scanner.peek()) |peeked| {
        try self.reportError(msg, peeked, .start);
    }
    else {
        try self.reportError(msg, self.scanner.consumed.?, .end);
    }

    return Error.ParseError;

}

fn limit(self: *Self, allowed: []const Token.Kind) Error!void {
    if (self.scanner.peek()) |peeked| {
        if (!std.mem.containsAtLeast(Token.Kind, allowed, 1, &.{peeked.kind})) {
            const msg = try self.buildExpectedMsg(allowed, peeked.kind);
            try self.reportError(msg, self.scanner.peek().?, .start);
            return Error.ParseError;
        }
    }
    else {
        const msg = try self.buildExpectedMsg(allowed, null);
        try self.reportError(msg, self.scanner.consumed.?, .end);
        return Error.ParseError;
    }
}

fn buildExpectedMsg(self: *Self, allowed: []const Token.Kind, found: ?Token.Kind) Allocator.Error![]const u8 {
    var msg_writer: std.Io.Writer.Allocating = .init(self.alloc());

    msg_writer.writer.writeAll("Expected ") catch return Error.OutOfMemory;
    for (allowed[0..allowed.len-1]) |kind| {
        msg_writer.writer.print("{f}, ", .{kind}) catch return Error.OutOfMemory;
    }
    msg_writer.writer.print("or {f}", .{allowed[allowed.len-1]}) catch return Error.OutOfMemory;

    if (found) |f| {
        msg_writer.writer.print(", found {f}", .{f}) catch return Error.OutOfMemory;
    }

    return msg_writer.toOwnedSlice();
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