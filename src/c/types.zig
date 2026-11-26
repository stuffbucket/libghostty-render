//! The public C types of libghostty-render, and the registry that describes
//! them.
//!
//! The first part of this file defines the libghostty-vt types that
//! libghostty-render's API uses, such as GhosttyResult. libghostty-render's
//! headers include the libghostty-vt headers for these instead of
//! redefining them, so the values here must match those headers exactly.
//!
//! `type_decls` lists every C type in the API, the libghostty-vt ones it
//! uses and its own. The header parity test in `abi_test.zig` checks every
//! entry against the C headers translated by translate-c.
//!
//! This is a smaller version of libghostty-vt's `src/terminal/c/types.zig`.

const std = @import("std");
const build_info = @import("build_info.zig");

/// The calling convention of every exported function.
pub const calling_conv: std.lang.CallingConvention = .c;

/// C: GhosttyResult
pub const Result = enum(c_int) {
    success = 0,
    out_of_memory = -1,
    invalid_value = -2,
    out_of_space = -3,
    no_value = -4,
    io_error = -5,
    limit_exceeded = -6,
    rejected = -7,
    unsupported = -8,
};

/// C: GhosttyString
pub const String = extern struct {
    ptr: [*]const u8,
    len: usize,

    pub fn init(s: []const u8) String {
        return .{ .ptr = s.ptr, .len = s.len };
    }

    pub fn slice(self: String) []const u8 {
        return self.ptr[0..self.len];
    }
};

/// C: GhosttyOptimizeMode
pub const OptimizeMode = enum(c_int) {
    debug = 0,
    release_safe = 1,
    release_small = 2,
    release_fast = 3,
};

/// One public C type.
pub const TypeDecl = struct {
    /// The C name, such as `GtrBuildInfo`.
    name: []const u8,

    /// The Zig type with the same layout.
    T: type,

    kind: Kind,

    /// For enums, the prefix of every enumerator, such as
    /// `GTR_BUILD_INFO_`.
    prefix: []const u8 = "",

    /// For enums, the sentinel after the prefix that every C enum ends
    /// with. It is `GHOSTTY_ENUM_MAX_VALUE`, so the enum is an int.
    sentinel_suffix: []const u8 = "MAX_VALUE",

    /// For aliases, the manifest name of the integer, such as `u16`.
    alias_type: []const u8 = "",

    pub const Kind = enum {
        @"struct",
        @"union",
        @"enum",
        alias,
        @"opaque",
        callback,
    };

    fn initStruct(comptime name: []const u8, comptime T: type) TypeDecl {
        return .{ .name = name, .T = T, .kind = .@"struct" };
    }

    fn initUnion(comptime name: []const u8, comptime T: type) TypeDecl {
        return .{ .name = name, .T = T, .kind = .@"union" };
    }

    fn initEnum(
        comptime name: []const u8,
        comptime T: type,
        comptime prefix: []const u8,
    ) TypeDecl {
        return .{ .name = name, .T = T, .kind = .@"enum", .prefix = prefix };
    }

    /// An enum whose sentinel isn't `<prefix>MAX_VALUE`, such as
    /// GhosttyResult, whose values are `GHOSTTY_*` but whose sentinel is
    /// `GHOSTTY_RESULT_MAX_VALUE`.
    fn initEnumSentinel(
        comptime name: []const u8,
        comptime T: type,
        comptime prefix: []const u8,
        comptime sentinel_suffix: []const u8,
    ) TypeDecl {
        return .{
            .name = name,
            .T = T,
            .kind = .@"enum",
            .prefix = prefix,
            .sentinel_suffix = sentinel_suffix,
        };
    }

    /// An integer typedef, such as `typedef uint16_t GtrFoo;`.
    fn initAlias(
        comptime name: []const u8,
        comptime T: type,
        comptime alias_type: []const u8,
    ) TypeDecl {
        return .{ .name = name, .T = T, .kind = .alias, .alias_type = alias_type };
    }

    /// An opaque handle, such as
    /// `typedef struct GtrRendererImpl* GtrRenderer;`. `T` is the Zig
    /// handle type, which must be distinct from every other registered
    /// type so that function parameters of that type can name it.
    fn initHandle(comptime name: []const u8, comptime T: type) TypeDecl {
        return .{ .name = name, .T = T, .kind = .@"opaque" };
    }

    /// A callback typedef. `T` is the Zig function pointer type, such as
    /// `*const fn (?*anyopaque) callconv(.c) void`.
    fn initCallback(comptime name: []const u8, comptime T: type) TypeDecl {
        return .{ .name = name, .T = T, .kind = .callback };
    }

    /// A struct or union field as the C header declares it.
    pub const Field = struct {
        name: []const u8,
        T: type,

        /// The byte offset from the start of the type. Always 0 for unions.
        offset: usize,
    };

    /// The fields of a struct or union, in declaration order.
    pub fn fields(comptime self: TypeDecl) []const Field {
        comptime {
            const info = switch (self.kind) {
                .@"struct" => @typeInfo(self.T).@"struct",
                .@"union" => @typeInfo(self.T).@"union",
                else => unreachable,
            };
            var out: [info.field_names.len]Field = undefined;
            for (&out, info.field_names, info.field_types) |*field, name, ty| field.* = .{
                .name = name,
                .T = ty,
                .offset = if (self.kind == .@"union") 0 else @offsetOf(self.T, name),
            };
            const final = out;
            return &final;
        }
    }

    /// The C name of a Zig enum value without the enum's prefix: the Zig
    /// name in upper case. Add the prefix to get the full C enumerator,
    /// such as `GTR_BUILD_INFO_VERSION_MAJOR`.
    pub fn enumValueName(comptime zig_name: []const u8) []const u8 {
        comptime {
            var buf: [zig_name.len]u8 = undefined;
            for (&buf, zig_name) |*d, c| d.* = std.ascii.toUpper(c);
            const final = buf;
            return &final;
        }
    }
};

/// Every public C type. Names and enum prefixes are explicit because Zig
/// identifiers are not the C API contract. Keep the list sorted by name.
pub const type_decls = [_]TypeDecl{
    .initEnumSentinel("GhosttyOptimizeMode", OptimizeMode, "GHOSTTY_OPTIMIZE_", "MODE_MAX_VALUE"),
    .initEnumSentinel("GhosttyResult", Result, "GHOSTTY_", "RESULT_MAX_VALUE"),
    .initStruct("GhosttyString", String),
    .initEnum("GtrBuildInfo", build_info.BuildInfo, "GTR_BUILD_INFO_"),
};

comptime {
    for (type_decls, 0..) |decl, i| {
        switch (decl.kind) {
            .@"struct", .@"union" => if (@typeInfo(decl.T) != .@"struct" and
                @typeInfo(decl.T) != .@"union")
                @compileError(decl.name ++ ": not a struct or union"),
            .@"enum" => if (@typeInfo(decl.T) != .@"enum")
                @compileError(decl.name ++ ": not an enum"),
            .callback => if (!isCallbackPointer(decl.T))
                @compileError(decl.name ++ ": a callback type must be a function pointer"),
            .alias, .@"opaque" => {},
        }

        // Types are looked up by Zig type to name field and key types, so
        // two names for one Zig type would be ambiguous.
        if (!isTypeLookupKind(decl)) continue;
        for (type_decls[0..i]) |previous| {
            if (!isTypeLookupKind(previous)) continue;
            if (previous.T == decl.T)
                @compileError(decl.name ++ " and " ++ previous.name ++ " have the same Zig type");
        }
    }
}

/// Whether `registeredName` finds this declaration by its Zig type.
/// Integer typedefs and callbacks share their Zig types with unrelated
/// values, so they are never looked up that way.
fn isTypeLookupKind(comptime decl: TypeDecl) bool {
    return switch (decl.kind) {
        .@"struct", .@"union", .@"enum", .@"opaque" => true,
        .alias, .callback => false,
    };
}

fn isCallbackPointer(comptime T: type) bool {
    return @typeInfo(T) == .pointer and @typeInfo(@typeInfo(T).pointer.child) == .@"fn";
}
