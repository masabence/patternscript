const std = @import("std");

pub const black = "\x1b[0;30m";
pub const red = "\x1b[0;31m";
pub const green = "\x1b[0;32m";
pub const yellow = "\x1b[0;33m";
pub const blue = "\x1b[0;34m";
pub const purple = "\x1b[0;35m";
pub const cyan = "\x1b[0;36m";
pub const white = "\x1b[0;37m";

pub const reset = "\x1b[0m";


pub fn rgb(r: comptime_int, g: comptime_int, b: comptime_int) []const u8 {
    comptime std.debug.assert(r > 0 and r < 6);
    comptime std.debug.assert(g > 0 and g < 6);
    comptime std.debug.assert(b > 0 and b < 6);

    const code = (r * 36) + (g * 6) + b + 16;
    return ansi_code(code);
}

pub fn ansi_code(code: comptime_int) []const u8 {
    return std.fmt.comptimePrint("\x1b[38;5;{}m", .{code});
}