const std = @import("std");
const Allocator = std.mem.Allocator;

const Scanner = @import("Scanner.zig");
const Parser = @import("Parser.zig");
const ErrorMessage = @import("ErrorMessage.zig");
const Element = @import("Element.zig");

pub const Builder = @import("Builder.zig");

pub fn compile(
    gpa: Allocator,
    source: []const u8,
    out: *std.Io.Writer,
    err: *std.Io.Writer,
) !void {
    var arena_allocator: std.heap.ArenaAllocator = .init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var errors: std.ArrayList(ErrorMessage) = .empty;
    defer errors.deinit(arena);

    var scanner = Scanner.init(arena, source);

    var bindings: std.StringHashMapUnmanaged(Element) = .empty;
    defer bindings.deinit(arena);

    var parser = Parser.init(arena, &scanner, &errors, &bindings);

    const elements = parser.parse() catch {
        for (parser.errors.items) |message| {
            try message.print(err, true);
        }
        return;
    };

    if (parser.errors.items.len != 0) {
        return;
    }

    for (elements) |e| {
        try e.value.compile(out, false);
    }
}
