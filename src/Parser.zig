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

    var elements: std.ArrayList(Element) = .empty;

    while (try self.parseElement()) |element| {
        try elements.append(self.alloc(), element);
        try self.consume(.comma, "Expected comma after element");
    }

    return elements.toOwnedSlice(self.alloc());
}

fn parseElement(self: *Self) Error!?Element {
    const t = self.scanner.peek() orelse return null;

    const value = switch (t.kind) {
        .kw_digit => return self.parseAtom("\\d"),
        .kw_wordchar => return self.parseAtom("\\w"),
        .kw_whitespace => return self.parseAtom("\\s"),
        .kw_boundary => return self.parseAtom("\\b"),
        .kw_start => return self.parseAtom("^"),
        .kw_end => return self.parseAtom("$"),

        .string => return self.parseString(.string),
        .pattern => return self.parseString(.pattern),

        .kw_capture => return try self.parseSimpleParent(Element.initCapture, null),

        else => unreachable,
    };

    return Element {
        .value = value,
    };
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


fn parseSimpleParent(
    self: *Self, 
    comptime factory: fn(content: *const Element) Element.Value, 
    comptime allowed_contents: ?[]const Token.Kind
) Error!Element {
    const head = self.scanner.next() orelse unreachable;

    const content = try self.parseElement() orelse return error.MissingToken;

    const allowed = allowed_contents == null or allowed: {
        for (allowed_contents) |option| {
            if (content.value == option) {
                break :allowed true;
            }
        }
        break :allowed false;
    };

    if (!allowed) {
        return error.InvalidConstruct;
    }

    const value = factory(try self.dupe(content));

    return Element {
        .value = value,
        .start = head.position,
        .end = content.end,
    };

}


fn consume(self: *Self, kind: Token.Kind, msg: []const u8) Allocator.Error!void {
    if (self.match(kind)) |_| {
        return;
    }

    try self.reportError(msg, .{ .line = 0, .col = 0 });

}


fn match(self: Self, kind: Token.Kind) ?Token {    
    if (self.scanner.peek()) |token| {
        if (token.kind == kind) {
            return self.scanner.next();
        }
    }

    return null;
}

fn reportErrorByToken(self: *Self, msg: []const u8, token: Token, after_token: bool) Allocator.Error!void {
    const offset = if (after_token) @as(u32, @intCast(token.len())) - 1 else 0;
    try self.errors.append(self.alloc(), .{
        .position = token.position.addToCol(offset),
        .message = msg,
    });
}

fn reportError(self: *Self, msg: []const u8, position: Position) Allocator.Error!void {
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

fn dupe(self: *Self, e: Element) Allocator.Error!*const Element {
    const ptr = try self.alloc().create(Element);
    ptr.* = e;

    return ptr;
}

fn alloc(self: *Self) std.mem.Allocator {
    return self.arena.allocator();
}




pub const Error = error{InvalidConstruct, MissingToken} || Allocator.Error;