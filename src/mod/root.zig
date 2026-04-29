const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Scanner = @import("Scanner.zig");
pub const Parser = @import("Parser.zig");
pub const ErrorMessage = @import("ErrorMessage.zig");
pub const Element = @import("Element.zig");
pub const Builder = @import("Builder.zig");

pub fn compile(
    gpa: Allocator,
    source: []const u8,
    out: *std.Io.Writer,
    err: *std.Io.Writer,
) !void {
    var builder: Builder = .init(gpa);
    defer builder.deinit();
    try builder.add(source, err, .{ .print_location = true });
    try builder.compile(out);
}
