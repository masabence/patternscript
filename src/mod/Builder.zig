const std = @import("std");
const Element = @import("Element.zig");
const Parser = @import("Parser.zig");
const Scanner = @import("Scanner.zig");
const ErrorMessage = @import("ErrorMessage.zig");

const Builder = @This();

// Fields allocated with gpa
gpa: std.mem.Allocator,
bindings: std.StringHashMapUnmanaged(Element),
lines: std.ArrayList([]const u8),

// Fields allocated with parser_arena
parser_arena: std.heap.ArenaAllocator,
parser_state: Parser.State,
parsed: std.ArrayList(Element),

pub fn init(gpa: std.mem.Allocator) Builder {
    return .{
        .gpa = gpa,
        .bindings = .empty,
        .parsed = .empty,
        .parser_state = .init(),
        .lines = .empty,
        .parser_arena = .init(gpa),
    };
}

pub fn deinit(self: *Builder) void {
    self.bindings.deinit(self.gpa);

    for (self.lines.items) |line| {
        self.gpa.free(line);
    }

    self.lines.deinit(self.gpa);

    self.parser_arena.deinit();
}

pub fn add(self: *Builder, line: []const u8, stderr: *std.Io.Writer, options: AddOptions) !void {
    const duped_line = try self.gpa.dupe(u8, line);
    try self.lines.append(self.gpa, duped_line);

    var scanner: Scanner = .init(duped_line);

    var parser: Parser = .init(self.parser_arena.allocator(), &scanner, &self.parser_state);
    const result = parser.parse() catch |e| switch (e) {
        error.ParseError => {
            for (parser.state.errors.items) |message| {
                try message.print(stderr, options.print_location);
                try stderr.writeByte('\r');
            }
            try stderr.flush();
            self.parser_state.errors.clearRetainingCapacity();
            return;
        },
        else => return e,
    };

    try self.parsed.appendSlice(self.parser_arena.allocator(), result);
}

pub fn compile(self: *Builder, writer: *std.Io.Writer) !void {
    for (self.parsed.items) |element| {
        try element.value.compile(writer, false);
    }
}


pub const AddOptions = struct {
    print_location: bool = false,
};