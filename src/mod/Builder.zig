const std = @import("std");
const Element = @import("Element.zig");
const Parser = @import("Parser.zig");
const Scanner = @import("Scanner.zig");
const ErrorMessage = @import("ErrorMessage.zig");


const Builder = @This();

bindings: std.StringHashMap(Element),
parsed: std.ArrayList(Element),

pub fn init(arena: std.mem.Allocator) Builder {
    return .{
        .bindings = .init(arena),
        .parsed = .empty,
    };
}


pub fn add(self: *Builder, line: []const u8) !void {
    const duped_line = try self.bindings.allocator.dupe(u8, line);
    var scanner: Scanner = .init(duped_line);

    var errors: std.ArrayList(ErrorMessage) = .empty;

    var parser: Parser = .init(self.bindings.allocator, &scanner, &errors, &self.bindings);
    const result = parser.parse() catch |e| switch (e) {
        error.ParseError => {
            for (parser.errors.items) |message| {
                message.debug();
            }
            return;
        },
        else => return e,
    };



    try self.parsed.appendSlice(self.bindings.allocator, result);

}

pub fn compile(self: *Builder, writer: *std.Io.Writer) !void {
    for (self.parsed.items) |element| {
        try element.value.compile(writer, false);
    }
} 