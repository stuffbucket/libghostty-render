//! The public C types of libghostty-render, and the registry that describes
//! them.
//!
//! The first part of this file defines the libghostty-vt types that
//! libghostty-render's API uses, such as GhosttyResult. libghostty-render's
//! headers include the libghostty-vt headers for these instead of
//! redefining them, so the values here must match those headers exactly.
//!
//! `type_decls` lists every C type in the API, the libghostty-vt ones it
//! uses and its own. Two things are built from it:
//!
//!   - The header parity test in `abi_test.zig`, which checks every entry
//!     against the C headers translated by translate-c.
//!   - The type manifest, a JSON description of every type's layout that
//!     `gtr_type_json` returns. Its goldens in `abi/` catch ABI changes.
//!
//! This is a smaller version of libghostty-vt's `src/terminal/c/types.zig`
//! and produces the same manifest format.

const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
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

/// The type manifest, built at compile time and embedded in the library.
pub const json: [:0]const u8 = json: {
    @setEvalBranchQuota(1_000_000);
    var counter: std.Io.Writer.Discarding = .init(&.{});
    Json.writeAll(&counter.writer) catch unreachable;

    var buf: [counter.count:0]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buf);
    Json.writeAll(&writer) catch unreachable;
    const final = buf;
    break :json final[0..writer.end :0];
};

/// C: gtr_type_json
pub fn get_json() callconv(calling_conv) [*:0]const u8 {
    return json.ptr;
}

/// Writes the manifest. The format is libghostty-vt's (see
/// `ghostty_type_json` in <ghostty/vt/types.h>), with a leading `library`
/// field. The WebAssembly module contains libghostty-vt's manifest as
/// well, and the ABI check tells the two apart by that field.
const Json = struct {
    fn writeAll(writer: *std.Io.Writer) std.Io.Writer.Error!void {
        var jws: std.json.Stringify = .{ .writer = writer };
        try jws.beginObject();
        try jws.objectField("library");
        try jws.write("libghostty-render");
        try jws.objectField("schema");
        try jws.write(1);

        try jws.objectField("abi");
        try jws.beginObject();
        try jws.objectField("target");
        try jws.write(@tagName(builtin.target.cpu.arch));
        try jws.objectField("os");
        try jws.write(@tagName(builtin.target.os.tag));
        try jws.objectField("environment");
        try jws.write(@tagName(builtin.target.abi));
        try jws.objectField("pointer_size");
        try jws.write(@sizeOf(*anyopaque));
        try jws.objectField("usize_size");
        try jws.write(@sizeOf(usize));
        try jws.objectField("endian");
        try jws.write(@tagName(builtin.target.cpu.arch.endian()));
        try jws.endObject();

        try jws.objectField("library_version");
        try jws.write(build_options.version_string);
        try jws.objectField("commit");
        if (build_options.version_build) |commit| try jws.write(commit) else try jws.write(null);

        try jws.objectField("types");
        try jws.beginObject();
        inline for (type_decls) |decl| {
            try jws.objectField(decl.name);
            try writeType(decl, &jws);
        }
        try jws.endObject();
        try jws.endObject();
    }

    fn writeType(comptime decl: TypeDecl, jws: *std.json.Stringify) std.Io.Writer.Error!void {
        try jws.beginObject();
        try jws.objectField("kind");
        try jws.write(@tagName(decl.kind));

        switch (decl.kind) {
            .@"struct", .@"union" => {
                try writeSizeAlign(decl.T, jws);
                try jws.objectField("fields");
                try jws.beginObject();
                inline for (comptime decl.fields()) |field| {
                    try jws.objectField(field.name);
                    try jws.beginObject();
                    try jws.objectField("offset");
                    try jws.write(field.offset);
                    try jws.objectField("size");
                    try jws.write(@sizeOf(field.T));
                    try writeValueType(decl.name ++ "." ++ field.name, field.T, jws);
                    try jws.endObject();
                }
                try jws.endObject();
            },
            .@"enum" => {
                try writeSizeAlign(c_int, jws);
                try jws.objectField("underlying");
                try jws.write("i32");
                try jws.objectField("prefix");
                try jws.write(decl.prefix);
                try jws.objectField("values");
                try jws.beginObject();
                const info = @typeInfo(decl.T).@"enum";
                inline for (info.field_names, info.field_values) |field, value| {
                    try jws.objectField(comptime TypeDecl.enumValueName(field));
                    try jws.write(value);
                }
                try jws.objectField(decl.sentinel_suffix);
                try jws.write(std.math.maxInt(c_int));
                try jws.endObject();
                try writeKeys(decl, jws);
            },
            .alias => {
                try writeSizeAlign(decl.T, jws);
                try jws.objectField("type");
                try jws.write(decl.alias_type);
            },
            .@"opaque" => try writeSizeAlign(*anyopaque, jws),
            .callback => try writeCallback(decl, jws),
        }
        try jws.endObject();
    }

    fn writeSizeAlign(comptime T: type, jws: *std.json.Stringify) std.Io.Writer.Error!void {
        try jws.objectField("size");
        try jws.write(@sizeOf(T));
        try jws.objectField("align");
        try jws.write(@alignOf(T));
    }

    /// Writes the `keys` object of a key enum, the enum a `_get` or `_set`
    /// function takes to pick a value, such as GtrBuildInfo. Each key gets
    /// its direction and the type its `void *` value points at. Key enums
    /// declare `OutType` (read by `_get`) or `InType` (written by `_set`).
    fn writeKeys(comptime decl: TypeDecl, jws: *std.json.Stringify) std.Io.Writer.Error!void {
        const in = @hasDecl(decl.T, "InType");
        const out = @hasDecl(decl.T, "OutType");
        if (in and out) @compileError(decl.name ++ " declares both InType and OutType");
        if (!in and !out) return;

        try jws.objectField("keys");
        try jws.beginObject();
        const info = @typeInfo(decl.T).@"enum";
        inline for (info.field_names) |field| {
            if (comptime std.mem.eql(u8, field, "invalid")) continue;
            const key = @field(decl.T, field);
            const T = if (in) key.InType() else key.OutType();
            const key_name = comptime TypeDecl.enumValueName(field);
            if (T == void) @compileError(decl.prefix ++ key_name ++ ": a key's value type cannot be void");

            try jws.objectField(key_name);
            try jws.beginObject();
            try jws.objectField("direction");
            try jws.write(if (in) "in" else "out");
            try writeValueType(decl.prefix ++ key_name, T, jws);
            try jws.endObject();
        }
        try jws.endObject();
    }

    /// Writes a callback descriptor: its parameter types and return type.
    fn writeCallback(comptime decl: TypeDecl, jws: *std.json.Stringify) std.Io.Writer.Error!void {
        const info = @typeInfo(@typeInfo(decl.T).pointer.child).@"fn";
        try writeSizeAlign(decl.T, jws);
        try jws.objectField("params");
        try jws.beginArray();
        inline for (info.param_types, 0..) |param, i| {
            const context = std.fmt.comptimePrint("{s} parameter {d}", .{ decl.name, i });
            try jws.beginObject();
            try writeValueType(context, param orelse @compileError(context ++ " is generic"), jws);
            try jws.endObject();
        }
        try jws.endArray();
        try jws.objectField("return");
        try jws.beginObject();
        const R = info.return_type.?;
        if (R == void) {
            try jws.objectField("type");
            try jws.write("void");
        } else try writeValueType(decl.name ++ " return", R, jws);
        try jws.endObject();
    }

    /// Writes the type of a field, key value or callback parameter. A type
    /// the registry can't name is a compile error rather than a vague
    /// "struct" or "opaque".
    fn writeValueType(
        comptime context: []const u8,
        comptime T: type,
        jws: *std.json.Stringify,
    ) std.Io.Writer.Error!void {
        if (comptime registeredName(T)) |name| {
            try jws.objectField("type");
            try jws.write(name);
            return;
        }

        switch (@typeInfo(T)) {
            .array => |info| {
                try jws.objectField("type");
                try jws.write("array");
                try jws.objectField("elem");
                try jws.write(comptime valueName(context, info.child));
                try jws.objectField("count");
                try jws.write(info.len);
            },
            .optional => |info| try writePointer(context, info.child, true, jws),
            .pointer => try writePointer(context, T, false, jws),
            else => {
                try jws.objectField("type");
                try jws.write(comptime valueName(context, T));
            },
        }
    }

    fn writePointer(
        comptime context: []const u8,
        comptime P: type,
        comptime nullable: bool,
        jws: *std.json.Stringify,
    ) std.Io.Writer.Error!void {
        const info = switch (@typeInfo(P)) {
            .pointer => |info| info,
            else => @compileError(context ++ ": an optional must hold a pointer, not " ++ @typeName(P)),
        };
        if (info.size == .slice) @compileError(context ++ ": slices have no C type");
        try jws.objectField("type");
        try jws.write("pointer");
        try jws.objectField("elem");
        try jws.write(comptime valueName(context, info.child));
        try jws.objectField("const");
        try jws.write(info.attrs.@"const");
        if (nullable) {
            try jws.objectField("nullable");
            try jws.write(true);
        }
    }

    /// The manifest name of a scalar or registered type.
    fn valueName(comptime context: []const u8, comptime T: type) []const u8 {
        if (registeredName(T)) |name| return name;
        return switch (@typeInfo(T)) {
            .bool => "bool",
            .float => |info| switch (info.bits) {
                32 => "f32",
                64 => "f64",
                else => @compileError(context ++ ": no C type for " ++ @typeName(T)),
            },
            .int => |info| std.fmt.comptimePrint("{c}{d}", .{
                @as(u8, if (info.signedness == .signed) 'i' else 'u'),
                info.bits,
            }),
            .@"opaque" => if (T == anyopaque)
                "opaque"
            else
                @compileError(context ++ ": the type registry cannot name " ++ @typeName(T)),
            else => @compileError(context ++ ": the type registry cannot name " ++ @typeName(T)),
        };
    }

    fn registeredName(comptime T: type) ?[]const u8 {
        for (type_decls) |decl| {
            if (isTypeLookupKind(decl) and decl.T == T) return decl.name;
        }
        return null;
    }
};

test "manifest parses and describes the library" {
    const testing = std.testing;
    const parsed = try std.json.parseFromSlice(std.json.Value, testing.allocator, json, .{});
    defer parsed.deinit();
    const root = parsed.value.object;

    // The ABI check finds the manifest in the library by this prefix.
    try testing.expect(std.mem.startsWith(u8, json, "{\"library\":\"libghostty-render\",\"schema\":"));
    try testing.expectEqual(@as(i64, 1), root.get("schema").?.integer);
    try testing.expectEqualStrings(build_options.version_string, root.get("library_version").?.string);

    const types = root.get("types").?.object;
    try testing.expectEqual(type_decls.len, types.count());
}

test "manifest describes enums and their keys" {
    const testing = std.testing;
    const parsed = try std.json.parseFromSlice(std.json.Value, testing.allocator, json, .{});
    defer parsed.deinit();
    const info = parsed.value.object.get("types").?.object.get("GtrBuildInfo").?.object;

    try testing.expectEqualStrings("enum", info.get("kind").?.string);
    try testing.expectEqualStrings("GTR_BUILD_INFO_", info.get("prefix").?.string);
    const values = info.get("values").?.object;
    try testing.expectEqual(@as(i64, 0), values.get("INVALID").?.integer);
    try testing.expectEqual(@as(i64, 3), values.get("VERSION_MAJOR").?.integer);
    try testing.expectEqual(@as(i64, std.math.maxInt(c_int)), values.get("MAX_VALUE").?.integer);

    const keys = info.get("keys").?.object;
    try testing.expect(keys.get("INVALID") == null);
    const optimize = keys.get("OPTIMIZE").?.object;
    try testing.expectEqualStrings("out", optimize.get("direction").?.string);
    try testing.expectEqualStrings("GhosttyOptimizeMode", optimize.get("type").?.string);
    try testing.expectEqualStrings(
        "GhosttyString",
        keys.get("VERSION_STRING").?.object.get("type").?.string,
    );
}

test "manifest describes struct fields" {
    const testing = std.testing;
    const parsed = try std.json.parseFromSlice(std.json.Value, testing.allocator, json, .{});
    defer parsed.deinit();
    const string = parsed.value.object.get("types").?.object.get("GhosttyString").?.object;

    try testing.expectEqual(@as(i64, @sizeOf(String)), string.get("size").?.integer);
    const ptr = string.get("fields").?.object.get("ptr").?.object;
    try testing.expectEqual(@as(i64, 0), ptr.get("offset").?.integer);
    try testing.expectEqualStrings("pointer", ptr.get("type").?.string);
    try testing.expectEqualStrings("u8", ptr.get("elem").?.string);
    try testing.expect(ptr.get("const").?.bool);
    const len = string.get("fields").?.object.get("len").?.object;
    try testing.expectEqual(@as(i64, @sizeOf(usize)), len.get("offset").?.integer);
}
