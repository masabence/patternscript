const std = @import("std");
const Allocator = std.mem.Allocator;

const Scanner = @import("Scanner.zig");
const Parser = @import("Parser.zig");
const ErrorMessage = @import("ErrorMessage.zig");
const Element = @import("Element.zig");

const ErrorMessageList = std.ArrayList(ErrorMessage);

pub fn compile(gpa: Allocator, source: []const u8, writer: *std.Io.Writer) !void {

    var arena_allocator: std.heap.ArenaAllocator = .init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var errors: ErrorMessageList = .empty;
    defer errors.deinit(arena);

    var scanner = Scanner.init(source);
    
    var parser = Parser.init(arena, &scanner, &errors);

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