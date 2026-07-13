const std = @import("std");
const patternscript = @import("patternscript");
const highlight = @import("highlight.zig");
const Theme = @import("Theme.zig");

const mibu = @import("mibu");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var stdin_buffer: [512]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(io, &stdin_buffer);
    const stdin = &stdin_reader.interface;

    var stdout_buffer: [128]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var stderr_buffer: [128]u8 = undefined;
    var stderr_writer = std.Io.File.stderr().writer(io, &stderr_buffer);
    const stderr = &stderr_writer.interface;

    if (args.len == 1) {
        try runReplRaw(gpa, stdin, stdout, stderr);
    }

    if (args.len == 2) {
        try runFile(io, gpa, args[1], stdout, stderr);
    }
}

fn runFile(
    io: std.Io,
    gpa: std.mem.Allocator,
    file_name: []const u8,
    stdout: *std.Io.Writer,
    stderr: *std.Io.Writer,
) !void {
    const file = try std.Io.Dir.cwd().openFile(io, file_name, .{ .mode = .read_only });
    defer file.close(io);

    var file_buffer: [512]u8 = undefined;
    var reader = file.reader(io, &file_buffer);

    var file_content: std.Io.Writer.Allocating = .init(gpa);
    defer file_content.deinit();

    _ = try reader.interface.streamRemaining(&file_content.writer);

    try patternscript.compile(gpa, file_content.written(), stdout, stderr);
    try stdout.writeByte('\n');

    try stdout.flush();
}

fn runRepl(
    gpa: std.mem.Allocator,
    stdin: *std.Io.Reader,
    stdout: *std.Io.Writer,
    stderr: *std.Io.Writer,
) !void {
    var builder: patternscript.Builder = .init(gpa);
    defer builder.deinit();

    while (true) {
        try stderr.writeAll(">>> ");
        try stderr.flush();

        const line = try stdin.takeDelimiterInclusive('\n');

        if (std.mem.trim(u8, line, "\r\n").len == 0) {
            try mibu.clear.entireLine(stderr);
            try stderr.flush();
            break;
        }

        try builder.add(line, stderr, .{});
        try stderr.flush();
    }

    try builder.compile(stdout);
    try stdout.flush();
}

fn runReplRaw(
    arena: std.mem.Allocator,
    stdin: *std.Io.Reader,
    stdout: *std.Io.Writer,
    stderr: *std.Io.Writer,
) !void {

    var raw_term = mibu.term.enableRawMode(std.Io.File.stdin().handle)
        catch @panic("Unsupported platform");
    defer raw_term.disableRawMode()
        catch @panic("Unsupported platform");

    var builder: patternscript.Builder = .init(arena);
    defer builder.deinit();

    while (true) {
        try stderr.writeAll(">>> ");
        try stderr.flush();

        var buf: [512]u8 = undefined;

        const line = try highlight.getLine(&buf, stdin, stderr);
        try stderr.writeAll("\r\n");

        if (std.mem.trim(u8, line, "\r\n").len == 0) {
            try mibu.clear.entireLine(stderr);
            try stderr.writeAll("\r");
            try mibu.cursor.goUp(stderr, 1);
            try stderr.flush();
            break;
        }

        try builder.add(line, stderr, .{});
        try stderr.flush();
    }

    try builder.compile(stdout);
    try stdout.flush();
}