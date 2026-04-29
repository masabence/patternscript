const std = @import("std");

const STDIN = 0;
const termios = std.os.linux.termios;

pub fn setStdinRawMode() termios {
    var original: termios = undefined;
    var raw: termios = undefined;

    _ = std.os.linux.tcgetattr(STDIN, &original);
    raw = original;

    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;
    _ = std.os.linux.tcsetattr(STDIN, .FLUSH, &raw);

    return original;
}

pub fn resetStdinMode(settings: *const termios) void {
    _ = std.os.linux.tcsetattr(STDIN, .FLUSH, settings);
}

pub fn eraseLine(out: *std.Io.Writer) !void {
    try out.writeAll("\x1b[2K\r\x1b[1A");
}

pub fn eraseLineForRedraw(out: *std.Io.Writer) !void {
    try out.writeAll("\x1b[2K\r");
}
