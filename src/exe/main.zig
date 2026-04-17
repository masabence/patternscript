const std = @import("std");
const patternscript = @import("patternscript");
const terminal = @import("terminal.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var stdin_buffer: [64]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(io, &stdin_buffer);
    const stdin = &stdin_reader.interface;

    var stdout_buffer: [64]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;


    if (args.len == 1) {
        try runRepl(arena, stdin, stdout);
    }

    if (args.len == 2) {
        try runFile(io, arena, args[1], stdout);
    }
}

fn runFile(io: std.Io, gpa: std.mem.Allocator, file_name: []const u8, stdout: *std.Io.Writer) !void {
    const file = try std.Io.Dir.cwd().openFile(io, file_name, .{ .mode = .read_only });
    defer file.close(io);

    var file_buffer: [512]u8 = undefined;
    var reader = file.reader(io, &file_buffer);

    var file_content: std.Io.Writer.Allocating = .init(gpa);
    defer file_content.deinit();

    _ = try reader.interface.streamRemaining(&file_content.writer);

    try patternscript.compile(gpa, file_content.written(), stdout);
    try stdout.writeByte('\n');

    try stdout.flush();
}


fn runRepl(arena: std.mem.Allocator, stdin: *std.Io.Reader, stdout: *std.Io.Writer) !void {

    var builder: patternscript.Builder = .init(arena);

    while (true) {
        try stdout.writeAll(">>> ");
        try stdout.flush();

        const input = try stdin.takeDelimiterInclusive('\n');
        const line = std.mem.trim(u8, input, "\r\n");

        if (line.len == 0) {
            try terminal.eraseCurrentLine(stdout);
            try stdout.flush();
            break;
        }

        try builder.add(line);
    }

    try builder.compile(stdout);
    try stdout.flush();
}