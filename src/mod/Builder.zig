const std = @import("std");
const Element = @import("Element.zig");
const Parser = @import("Parser.zig");
const Scanner = @import("Scanner.zig");
const ErrorMessage = @import("ErrorMessage.zig");


const Builder = @This();

arena: std.mem.Allocator,
bindings: std.StringHashMapUnmanaged(Element),
parsed: std.ArrayList(Element),

pub fn init(arena: std.mem.Allocator) Builder {
    return .{
        .arena = arena,
        .bindings = .empty,
        .parsed = .empty,
    };
}


pub fn add(self: *Builder, line: []const u8, stderr: *std.Io.Writer) !void {
    var scanner: Scanner = .init(self.arena, line);

    var errors: std.ArrayList(ErrorMessage) = .empty;



    var parser: Parser = .init(self.arena, &scanner, &errors, &self.bindings);
    const result = parser.parse() catch |e| switch (e) {
        error.ParseError => {
            for (parser.errors.items) |message| {
                try message.print(stderr, false);
            }
            return;
        },
        else => return e,
    };



    try self.parsed.appendSlice(self.arena, result);

}

pub fn compile(self: *Builder, writer: *std.Io.Writer) !void {
    for (self.parsed.items) |element| {
        try element.value.compile(writer, false);
    }
} 