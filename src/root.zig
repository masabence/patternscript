const std = @import("std");
const Allocator = std.mem.Allocator;

const Scanner = @import("Scanner.zig");
const Parser = @import("Parser.zig");

const Element = @import("element.zig").Element;


pub fn compile(source: []const u8, gpa: Allocator, writer: *std.Io.Writer) !void {

    var scanner = Scanner.init(source);
    
    var parser = Parser.init(&scanner, gpa);
    const elements = try parser.parse();
    defer parser.deinit();

    for (parser.errors.items) |err| {
        err.debug();
    }

    if (parser.errors.items.len != 0) {
        return;
    }

    for (elements) |e| {
        try e.compile(writer, false);
    }
}