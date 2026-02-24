const std = @import("std");
const Scanner = @import("Scanner.zig");
const Element = @import("element.zig").Element;
const Token = @import("Token.zig");
const ErrorMessage = @import("ErrorMessage.zig");
const Allocator = std.mem.Allocator;

const Self = @This();


scanner: *Scanner,
arena: std.heap.ArenaAllocator,
errors: std.ArrayList(ErrorMessage),
bindings: std.StringHashMapUnmanaged(Element),

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
pub fn parse(self: *Self) Allocator.Error![]Element {

    var elements: std.ArrayList(Element) = .empty;

    while (self.scanner.next()) |token| {

        const element = self.parseToken(token) catch |e| switch (e) {
            Error.InvalidConstruct => continue, 
            Error.OutOfMemory => return Allocator.Error.OutOfMemory,
        };

        try elements.append(self.alloc(), element);
    }

    return elements.toOwnedSlice(self.alloc());
}

fn parseToken(self: *Self, token: Token) Error!Element {

    switch (token.kind) {
        .kw_any => return self.parseAny(),
        .kw_digit => return .initAtom("\\d"),
        .kw_wordchar => return .initAtom("\\w"),
        .kw_boundary => return .initAtom("\\b"),
        .kw_whitespace => return .initAtom("\\s"),
        .kw_start => return .initAtom("^"),
        .kw_end => return .initAtom("$"),

        .kw_not => return self.parseNot(token),
        .kw_optional => return self.parseOptional(token),
        .kw_capture => return self.parseCapture(token),
        .kw_either => return self.parseEitherOr(token),

        .kw_let => return self.parseLetBinding(token),

        .lcurly => return self.parseBlock(token),

        .pattern => return .initPattern(token.stringValue()),
        .string => return .initString(token.stringValue()),


        .identifier => {
            if (isNumber(token.lexeme)) {
                return self.parseNOf(token);
            }

            return self.parseIdentifier(token);
        },

        .illegal => {
            try self.reportError(token.lexeme, token);
            return Error.InvalidConstruct;
        },

        else => {
            try self.reportError("Invalid token", token);
            return Error.InvalidConstruct;
        },
    }
}

fn parseNext(self: *Self) Error!?Element {
    const next = self.scanner.next() orelse return null;
    return try self.parseToken(next); 
}

fn parseLetBinding(self: *Self, token: Token) Error!Element {

    if (self.match(.identifier)) |name_token| {
        const name = name_token.lexeme;

        if (self.bindings.contains(name)) {
            try self.reportError("Identifier already in use", name_token);
            return Error.InvalidConstruct;
        }

        if (self.match(.equal) == null) {
            try self.reportError("Expected '=' in let binding", name_token);
            return Error.InvalidConstruct;
        }

        const content = try self.parseNext() orelse {
            try self.reportError("Expected element definition", name_token);
            return Error.InvalidConstruct;
        };

        try self.bindings.put(self.alloc(), name, content);

        return Element.initAtom(""); // returning an element while not printing anything

    } else {
        try self.reportError("Expected identifier after 'let'", token);
        return Error.InvalidConstruct;
    }




}

fn parseIdentifier(self: *Self, token: Token) Error!Element {
    if (self.bindings.get(token.lexeme)) |name| {
        return name;
    }

    try self.reportError("Unknown identifier", token);
    return Error.InvalidConstruct;
}

fn parseAny(self: *Self) Error!Element {

    var content: Element = undefined;

    if (self.match(.kw_from)) |from_token| {
        content = try self.parseNext() orelse {
            try self.reportError("Expected token after 'from' token", from_token);
            return Error.InvalidConstruct;
        };

        return Element.initCharset(try self.dupe(content), false);
    }

    if (self.match(.kw_except)) |except_token| {
        content = try self.parseNext() orelse {
            try self.reportError("Expected token after 'from' token", except_token);
            return Error.InvalidConstruct;
        };

        return Element.initCharset(try self.dupe(content), true);
    }

    return .initAtom(".");
}


fn parseBlock(self: *Self, opening: Token) Error!Element {
    var contents: std.ArrayList(Element) = .empty;
    var last_token = opening;

    while (self.scanner.next()) |next| {
        last_token = next;
        if (next.kind == .rcurly) {
            
            return Element.initBlock(try contents.toOwnedSlice(self.alloc()));
        }

        const element = try self.parseToken(next);
        try contents.append(self.alloc(), element);

    }

    try self.reportError("Unterminated block", last_token);
    return Error.InvalidConstruct;

}

fn parseNot(self: *Self, token: Token) Error!Element {

    const content = try self.parseNext() orelse {
        try self.reportError("Expected token after 'not'", token);
        return Error.InvalidConstruct;
    };

    switch (content) {
        .atom => |atom| {
            if (atom.len != 1) {
                return Element.initNot(try self.dupe(content));
            }
        },
        else => {},
    }

    try self.reportError("Invalid token after 'not'", token);
    return Error.InvalidConstruct;
}

fn parseOptional(self: *Self, token: Token) Error!Element {
    const content = try self.parseNext() orelse {
        try self.reportError("Expexted token after 'optional'", token);
        return Error.InvalidConstruct;
    };

    return Element.initOptional(try self.dupe(content));
}

fn parseCapture(self: *Self, token: Token) Error!Element {
    const content = try self.parseNext() orelse {
        try self.reportError("Expexted token after 'optional'", token);
        return Error.InvalidConstruct;
    };

    return Element.initCapture(try self.dupe(content));
}

fn parseNOf(self: *Self, num: Token) Error!Element {

    var mode: enum {normal, plus, range} = .normal;
    var second_num: ?[]const u8 = null;

    while (true) {

        // # of { ... } , base case
        if (self.match(.kw_of)) |of_token| {
            const content = try self.parseNext() orelse {
                try self.reportError("Ended unexpectedly", of_token);
                return Error.InvalidConstruct;
            };

            return switch (mode) {
                .normal => Element.initNOf(num.lexeme, try self.dupe(content), false),
                .plus => Element.initNOf(num.lexeme, try self.dupe(content), true),
                .range => Element.initNToMOf(num.lexeme, second_num.?, try self.dupe(content)),
            };
        }

        // #+ of { ... }
        if (self.match(.plus)) |_| {

            if (mode != .normal) {
                continue;
            }

            mode = .plus;
            continue;
        }

        // #-# of { ... }
        if (self.match(.dash)) |dash_token| {

            if (mode != .normal) {
                continue;
            }

            if (self.match(.identifier)) |second_num_token| {

                if (!isNumber(second_num_token.lexeme)) {
                    try self.reportError("Range quantifier must be a number", second_num_token);
                    return Error.InvalidConstruct;
                }

                second_num = second_num_token.lexeme;
                mode = .range;
                continue;
                
            }

            try self.reportError("Range must have an upper bound", dash_token);
            return Error.InvalidConstruct;

        }

        try self.reportError("Missing 'of' after quantifier", num);
        return Error.InvalidConstruct;

    }
}

fn parseEitherOr(self: *Self, token: Token) Error!Element {
    var branches: std.ArrayList(Element) = .empty;
    
    const first_content = try self.parseNext() orelse {
        try self.reportError("Expected token after 'either'", token);
        return Error.InvalidConstruct;
    };

    if (first_content == .either_or) {
        try self.reportError("Cannot have 'either' inside another 'either' element", token); // Janky, should be content token
        return Error.InvalidConstruct;
    }

    try branches.append(self.alloc(), first_content);

    while (self.match(.kw_or)) |or_token| {
        const content = try self.parseNext() orelse {
            try self.reportError("Expected token after 'or'", or_token);
            return Error.InvalidConstruct;
        };

        try branches.append(self.alloc(), content);
    }

    if (branches.items.len == 1) {
        try self.reportError("Expected at least two branches of 'either' element", token);
        return Error.InvalidConstruct;
    }

    return Element.initEitherOr(try branches.toOwnedSlice(self.alloc()));
}

fn match(self: Self, kind: Token.Kind) ?Token {
    
    if (self.scanner.peek()) |token| {
        if (token.kind == kind) {
            return self.scanner.next();
        }
    }

    return null;
}

fn reportError(self: *Self, msg: []const u8, token: Token) Allocator.Error!void {
    try self.errors.append(self.alloc(), .{
        .line = token.line,
        .col = token.col,
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

fn dupe(self: *Self, e: Element) Allocator.Error!*Element {
    const ptr = try self.alloc().create(Element);
    ptr.* = e;

    return ptr;
}

fn alloc(self: *Self) std.mem.Allocator {
    return self.arena.allocator();
}




pub const Error = error{InvalidConstruct} || Allocator.Error;