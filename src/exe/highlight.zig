const std = @import("std");
const patternscript = @import("patternscript");
const mibu = @import("mibu");
const Theme = @import("Theme.zig");
const Color = mibu.color.Color;

const global_theme = Theme {
    .keyword = Color.blue,
    .operation = Color.plum_3,
    .quantifier = Color.dark_sea_green_2,
    .string = Color.light_salmon_3b,
    .charset = Color.cadet_blue,
    .name = Color.sky_blue_3,
    .identifier = Color.white,
    .symbol = Color.white,
    .illegal = Color.red,
};

pub fn getLine(buf: []u8, in: *std.Io.Reader, out: *std.Io.Writer) ![]const u8 {
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

                if (std.ascii.isControl(c)) {
                    continue;
                }

                buf[cursor] = c;
                cursor += 1;
            }
        }

        try mibu.clear.entireLine(out);
        try out.writeByte('\r');
        try out.writeAll(">>> ");
        try drawLineWithColor(out, buf[0..cursor], global_theme);
        try out.flush();
    }

    return buf[0..cursor];
}

fn drawLineWithColor(out: *std.Io.Writer, raw: []const u8, theme: Theme) !void {
    var scanner: patternscript.Scanner = .init(raw);
    var written_count: usize = 0;

    while (scanner.next()) |token| {
        const token_start_index = token.position.col - 1;
        const before_token = raw[written_count..token_start_index];

        try out.writeAll(before_token);
        written_count += before_token.len;

        const color = switch (token.kind.class()) {
            .keyword => theme.keyword,
            .operation => theme.operation,
            .quantifier => theme.quantifier,
            .string => theme.string,
            .charset => theme.charset,
            .identifier => theme.identifier,
            .name => theme.name,
            .symbol => theme.symbol,
            .illegal => theme.illegal,
        };

        try writeTokenInColor(out, token.lexeme, color);
        written_count += token.lexeme.len;
    }

    try out.writeAll(raw[written_count..]);
}

fn writeTokenInColor(out: *std.Io.Writer, lexeme: []const u8, color: Color) !void {
    try mibu.color.fg256(out, color);
    try out.writeAll(lexeme);
    try mibu.color.resetAll(out);
}