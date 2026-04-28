const std = @import("std");
const patternscript = @import("patternscript");
const terminal = @import("terminal.zig");
const color_codes = @import("color_codes.zig");
const highlight = @import("highlight.zig");

const Theme = @import("Theme.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

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
        try runReplRaw(arena, stdin, stdout, stderr);
    }

    if (args.len == 2) {
        try runFile(io, arena, args[1], stdout, stderr);
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
    arena: std.mem.Allocator,
    stdin: *std.Io.Reader,
    stdout: *std.Io.Writer,
    stderr: *std.Io.Writer,
) !void {
    var builder: patternscript.Builder = .init(arena);

    while (true) {
        try stderr.writeAll(">>> ");
        try stderr.flush();

        const line = try stdin.takeDelimiterInclusive('\n');

        if (std.mem.trim(u8, line, "\r\n").len == 0) {
            try terminal.eraseLine(stderr);
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

    const original = terminal.setStdinRawMode();
    defer terminal.resetStdinMode(&original);

    var builder: patternscript.Builder = .init(arena);

    while (true) {
        try stderr.writeAll(">>> ");
        try stderr.flush();

        var buf: [512]u8 = undefined;

        const line = try getLine(arena, &buf, stdin, stderr);
        try stderr.writeByte('\n');

        if (std.mem.trim(u8, line, "\r\n").len == 0) {
            try terminal.eraseLine(stderr);
            try stderr.flush();
            break;
        }

        try builder.add(line, stderr, .{});
        try stderr.flush();
    }

    try builder.compile(stdout);
    try stdout.flush();
}

const global_theme = Theme {
    .keyword = color_codes.blue,
    .number = color_codes.ansi_code(193),
    .string = color_codes.yellow,
};

fn getLine(arena: std.mem.Allocator, buf: []u8, in: *std.Io.Reader, out: *std.Io.Writer) ![]const u8 {
    var cursor: usize = 0;
    while (true) {
        const c = try in.takeByte();

        const delete = 0x7F;
        const backspace = 0x08;

        switch (c) {
            '\r', '\n' => {
                buf[cursor] = '\n';
                cursor += 1;
                break;
            },
            delete, backspace => {
                cursor -|= 1;
            },
            else => {
                buf[cursor] = c;
                cursor += 1;
            }
        }

        try terminal.eraseLineForRedraw(out);
        try out.writeAll(">>> ");
        try highlight.drawLineWithColor(arena, out, buf[0..cursor], global_theme);
        try out.flush();
    }

    return buf[0..cursor];
}