const std = @import("std");
const c = @import("termios");

const termios = c.termios;

pub fn setStdinRawMode() termios {
    var original: termios = undefined;
    var raw: termios = undefined;

    _ = c.tcgetattr(c.STDIN_FILENO, &original);
    raw = original;

    raw.c_lflag &= ~@as(c_uint, c.ECHO | c.ICANON);
    _ = c.tcsetattr(c.STDIN_FILENO, c.TCSAFLUSH, &raw);

    return original;
}

pub fn resetStdinMode(settings: *const termios) void {
    _ = c.tcsetattr(c.STDIN_FILENO, c.TCSAFLUSH, settings);
}

pub fn eraseLine(out: *std.Io.Writer) !void {
    try out.writeAll("\x1b[2K\r\x1b[1A");
}

pub fn eraseLineRaw(out: *std.Io.Writer) !void {
    try out.writeAll("\x1b[2K\r");
}
