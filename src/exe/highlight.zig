const std = @import("std");
const color_codes = @import("color_codes.zig");
const terminal = @import("terminal.zig");
const patternscript = @import("patternscript");

const Theme = @import("Theme.zig");

const global_theme = Theme {
    .keyword = color_codes.blue,
    .number = color_codes.ansi_code(193),
    .string = color_codes.yellow,
};

pub fn getLine(arena: std.mem.Allocator, buf: []u8, in: *std.Io.Reader, out: *std.Io.Writer) ![]const u8 {
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
        try drawLineWithColor(arena, out, buf[0..cursor], global_theme);
        try out.flush();
    }

    return buf[0..cursor];
}

fn drawLineWithColor(arena: std.mem.Allocator, out: *std.Io.Writer, raw: []const u8, theme: Theme) !void {
    var scanner: patternscript.Scanner = .init(arena, raw);
    var written_count: usize = 0;

    while (try scanner.next()) |token| {
        const token_start_index = token.position.col - 1;
        const before_token = raw[written_count..token_start_index];

        try out.writeAll(before_token);
        written_count += before_token.len;

        switch (token.kind) {
            .number => try writeTokenInColor(out, token.lexeme, theme.number, &written_count),
            .string => try writeTokenInColor(out, token.lexeme, theme.string, &written_count),
            .kw_any,
            .kw_boundary,
            .kw_capture,
            .kw_digit,
            .kw_end,
            .kw_except,
            .kw_from,
            .kw_let,
            .kw_not,
            .kw_of,
            .kw_optional,
            .kw_or,
            .kw_ref,
            .kw_start,
            .kw_whitespace,
            .kw_wordchar,
            => try writeTokenInColor(out, token.lexeme, theme.keyword, &written_count),

            else => {},
        }
    }

    try out.writeAll(raw[written_count..]);
}

fn writeTokenInColor(out: *std.Io.Writer, lexeme: []const u8, color: []const u8, written: *usize) !void {
    try out.writeAll(color);
    try out.writeAll(lexeme);
    try out.writeAll(color_codes.reset);
    written.* += lexeme.len;
}