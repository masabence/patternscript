const std = @import("std");
const Writer = std.Io.Writer;

pub const Not = @import("elements/Not.zig");
pub const String = @import("elements/String.zig");
pub const Pattern = @import("elements/Pattern.zig");
pub const Block = @import("elements/Block.zig");
pub const NOf = @import("elements/NOf.zig");
pub const NToMOf = @import("elements/NToMOf.zig");
pub const Optional = @import("elements/Optional.zig");
pub const Capture = @import("elements/Capture.zig");
pub const EitherOr = @import("elements/EitherOr.zig");
pub const Charset = @import("elements/Charset.zig");


pub const Element = union(enum) {
    atom: []const u8,
    not: Not,
    string: String,
    pattern: Pattern,
    block: Block,
    n_of: NOf,
    n_to_m_of: NToMOf,
    optional: Optional,
    capture: Capture,
    either_or: EitherOr,
    charset: Charset,


    pub fn compile(self: Element, writer: *Writer, strict: bool) Writer.Error!void {
        switch (self) {
            .atom => |str| try writer.writeAll(str),
            .not => |not| try not.compile(writer),
            .string => |string| try string.compile(writer, strict),
            .pattern => |pattern| try pattern.compile(writer, strict),
            .block => |block| try block.compile(writer, strict),
            .n_of => |n_of| try n_of.compile(writer, strict),
            .n_to_m_of => |n_to_m_of| try n_to_m_of.compile(writer),
            .optional => |optional| try optional.compile(writer),
            .capture => |capture| try capture.compile(writer),
            .either_or => |either_or| try either_or.compile(writer),
            .charset => |charset| try charset.compile(writer),
            // else => std.debug.panic("Unimplemented element: {any}", .{@tagName(self)}),
        }
    }

    pub fn initAtom(str: []const u8) Element {
        return .{ .atom = str };
    }

    pub fn initNot(content: *Element) Element {
        return .{ .not = Not { .content = content} };
    }

    pub fn initString(str: []const u8) Element {
        return .{ .string = String { .str = str} };
    }

    pub fn initPattern(str: []const u8) Element {
        return .{ .pattern = Pattern { .str = str} };
    }

    pub fn initBlock(contents: []Element) Element {
        return .{ .block = Block { .contents = contents} };
    }

    pub fn initNOf(n: []const u8, content: *Element, plus: bool) Element {
        return .{ .n_of = NOf { .n = n, .content = content, .plus = plus } };
    }

    pub fn initNToMOf(n: []const u8, m: []const u8, content: *Element) Element {
        return .{ .n_to_m_of = NToMOf { .n = n, .m = m, .content = content } };
    }

    pub fn initOptional(content: *Element) Element {
        return .{ .optional = Optional { .content = content} };
    }

    pub fn initCapture(content: *Element) Element {
        return .{ .capture = Capture { .content = content } };
    }

    pub fn initEitherOr(contents: []Element) Element {
        return .{ .either_or = EitherOr { .contents = contents } };
    }

    pub fn initCharset(content: *Element, negated: bool) Element {
        return .{ .charset = Charset { .content = content, .negated = negated } };
    }
};