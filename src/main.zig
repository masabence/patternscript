const std = @import("std");
const patternscript = @import("patternscript");

pub fn main(init: std.process.Init) !void {

    const gpa = init.gpa;
    const io = init.io;
    const file = try std.Io.Dir.cwd().openFile(io, "source.txt", .{ .mode = .read_only });
    defer file.close(io);

    var file_buffer: [512]u8 = undefined;
    var reader = file.reader(io, &file_buffer);

    var file_content: std.Io.Writer.Allocating = .init(gpa);
    defer file_content.deinit();

    _ = try reader.interface.streamRemaining(&file_content.writer);


    var stdout_buffer: [64]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try patternscript.compile(gpa, file_content.written(), stdout);
    try stdout.writeByte('\n');

    try stdout.flush();
}