const std = @import("std");
const Allocator = std.mem.Allocator;

const Scanner = @import("Scanner.zig");
const Parser = @import("Parser.zig");

const Element = @import("Element.zig");


pub fn compile(gpa: Allocator, source: []const u8, writer: *std.Io.Writer) !void {

    var scanner = Scanner.init(source);
    
    var parser = Parser.init(&scanner, gpa);
    defer parser.deinit();
    const elements = parser.parse() catch {
        for (parser.errors.items) |err| {
            err.debug();
        }
        return;
    };


    if (parser.errors.items.len != 0) {
        return;
    }

    for (elements) |e| {
        try e.value.compile(writer, false);
    }
}