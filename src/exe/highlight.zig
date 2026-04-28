const std = @import("std");
const color_codes = @import("color_codes.zig");
const patternscript = @import("patternscript");

const Theme = @import("Theme.zig");

pub fn drawLineWithColor(arena: std.mem.Allocator, out: *std.Io.Writer, raw: []const u8, theme: Theme) !void {
    var scanner: patternscript.Scanner = .init(arena, raw);
    var written_count: usize = 0;

    while (try scanner.next()) |token| {
        const token_start_index = token.position.col - 1;
        const before_token = raw[written_count..token_start_index];

        try out.writeAll(before_token);
        written_count += before_token.len;

        switch (token.kind) {
            .number => written_count += try writeTokenInColor(out, token.lexeme, theme.number),
            .string => written_count += try writeTokenInColor(out, token.lexeme, theme.string),
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
            => written_count += try writeTokenInColor(out, token.lexeme, theme.keyword),

            else => {},
        }
    }

    try out.writeAll(raw[written_count..]);
}

fn writeTokenInColor(out: *std.Io.Writer, lexeme: []const u8, color: []const u8) !usize {
    try out.writeAll(color);
    try out.writeAll(lexeme);
    try out.writeAll(color_codes.reset);
    return lexeme.len;
}