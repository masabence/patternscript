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

    var scanner = Scanner.init(arena, source);

    var state: Parser.State = .init();
    defer state.deinit(arena);

    var parser = Parser.init(arena, &scanner, &state);

    const elements = parser.parse() catch {
        for (parser.state.errors.items) |message| {
            try message.print(err, true);
        }
        return;
    };

    if (parser.state.errors.items.len != 0) {
        return;
    }

    for (elements) |e| {
        try e.value.compile(out, false);
    }
}
