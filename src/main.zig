const std = @import("std");
const patternscript = @import("patternscript");

pub fn main() !void {

    var dba: std.heap.DebugAllocator(.{}) = .init;
    defer _ = dba.deinit();
    const gpa = dba.allocator();

    const file = try std.fs.cwd().openFile("source.txt", .{ .mode = .read_only });
    defer file.close();

    const source = try file.readToEndAlloc(gpa, std.math.maxInt(u32));
    defer gpa.free(source);


    var buffer: [1024]u8 = undefined;
    var stdin = std.fs.File.stdout().writer(&buffer);
    const writer = &stdin.interface;

    try patternscript.compile(source, gpa, writer);
    try writer.writeByte('\n');

    try writer.flush();
}