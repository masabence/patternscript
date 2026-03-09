const std = @import("std");
const Writer = std.Io.Writer;

const Position = @import("Position.zig");
const Token = @import("Token.zig");

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
pub const CharsetItem = @import("elements/CharsetItem.zig");
pub const LetBinding = @import("elements/LetBinding.zig");

const Element = @This();

value: Value,
start: Position,
end: Position,

pub const Value = union(enum) {
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
    charset_item: CharsetItem,
    let_binding: LetBinding,

    pub fn compile(self: Value, writer: *Writer, strict: bool) Writer.Error!void {
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
            .charset_item => |charset_item| try charset_item.compile(writer),
            .let_binding => {},
            // else => std.debug.panic("Unimplemented element: {any}", .{@tagName(self)}),
        }
    }

    pub fn initAtom(str: []const u8) Value {
        return .{ .atom = str };
    }

    pub fn initNot(content: *const Element) Value {
        return .{ .not = Not { .content = content} };
    }

    pub fn initString(str: []const u8) Value {
        return .{ .string = String { .str = str } };
    }

    pub fn initPattern(str: []const u8) Value {
        return .{ .pattern = Pattern { .str = str } };
    }

    pub fn initBlock(contents: []const Element) Value {
        return .{ .block = Block { .contents = contents} };
    }

    pub fn initNOf(n: []const u8, content: *const Element, plus: bool) Value {
        return .{ .n_of = NOf { .n = n, .content = content, .plus = plus } };
    }

    pub fn initNToMOf(n: []const u8, m: []const u8, content: *const Element) Value {
        return .{ .n_to_m_of = NToMOf { .n = n, .m = m, .content = content } };
    }

    pub fn initOptional(content: *const Element) Value {
        return .{ .optional = Optional { .content = content} };
    }

    pub fn initCapture(name: ?[]const u8, content: *const Element) Value {
        return .{ .capture = Capture { .name = name, .content = content } };
    }

    pub fn initEitherOr(contents: []const Element) Value {
        return .{ .either_or = EitherOr { .contents = contents } };
    }

    pub fn initCharset(content: *const Element, negated: bool) Value {
        return .{ .charset = Charset { .content = content, .negated = negated } };
    }

    pub fn initCharsetItem(str: []const u8) Value {
        return .{ .charset_item = CharsetItem { .str = str } };
    }

    pub fn initLetBinding(name: []const u8, content: *const Element) Value {
        return .{ .let_binding = LetBinding { .name = name, .content = content } };
    }
};