const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const types = @import("types.zig");
const Result = types.Result;
const String = types.String;
const OptimizeMode = types.OptimizeMode;

/// C: GtrBuildInfo
pub const BuildInfo = enum(c_int) {
    invalid = 0,
    optimize = 1,
    version_string = 2,
    version_major = 3,
    version_minor = 4,
    version_patch = 5,
    version_pre = 6,
    version_build = 7,
    vt_version_string = 8,
    vt_version_major = 9,
    vt_version_minor = 10,
    vt_version_patch = 11,

    _,

    /// Output type expected for querying the data of the given kind.
    pub fn OutType(comptime self: BuildInfo) type {
        return switch (self) {
            .invalid => void,
            .optimize => OptimizeMode,
            .version_string,
            .version_pre,
            .version_build,
            .vt_version_string,
            => String,
            .version_major,
            .version_minor,
            .version_patch,
            .vt_version_major,
            .vt_version_minor,
            .vt_version_patch,
            => usize,
            _ => void,
        };
    }
};

/// The library version as a null-terminated string, for gtr_version. It
/// has the same text as the version_string build info.
const version_z: [:0]const u8 = std.fmt.comptimePrint(
    "{s}",
    .{build_options.version_string},
);

/// The libghostty-vt header version as "major.minor.patch".
const vt_version_string: []const u8 = std.fmt.comptimePrint(
    "{d}.{d}.{d}",
    .{
        build_options.vt_version_major,
        build_options.vt_version_minor,
        build_options.vt_version_patch,
    },
);

/// C: gtr_version
pub fn version() callconv(types.calling_conv) [*:0]const u8 {
    return version_z.ptr;
}

/// C: gtr_build_info
pub fn get(
    data: BuildInfo,
    out: ?*anyopaque,
) callconv(types.calling_conv) Result {
    return switch (data) {
        _ => .unsupported,
        .invalid => .invalid_value,
        inline else => |comptime_data| getTyped(
            comptime_data,
            @ptrCast(@alignCast(out orelse return .invalid_value)),
        ),
    };
}

fn getTyped(
    comptime data: BuildInfo,
    out: *data.OutType(),
) Result {
    switch (data) {
        .invalid => return .invalid_value,
        .optimize => out.* = switch (builtin.mode) {
            .debug => .debug,
            .safe => .release_safe,
            .small => .release_small,
            .fast => .release_fast,
        },
        .version_string => out.* = .init(build_options.version_string),
        .version_major => out.* = build_options.version_major,
        .version_minor => out.* = build_options.version_minor,
        .version_patch => out.* = build_options.version_patch,
        .version_pre => out.* = .init(build_options.version_pre orelse ""),
        .version_build => out.* = .init(build_options.version_build orelse ""),
        .vt_version_string => out.* = .init(vt_version_string),
        .vt_version_major => out.* = build_options.vt_version_major,
        .vt_version_minor => out.* = build_options.vt_version_minor,
        .vt_version_patch => out.* = build_options.vt_version_patch,
        _ => comptime unreachable,
    }

    return .success;
}

test "get optimize" {
    const testing = std.testing;
    var value: OptimizeMode = undefined;
    try testing.expectEqual(Result.success, get(.optimize, @ptrCast(&value)));
    try testing.expectEqual(switch (builtin.mode) {
        .debug => OptimizeMode.debug,
        .safe => .release_safe,
        .small => .release_small,
        .fast => .release_fast,
    }, value);
}

test "get version numbers" {
    const testing = std.testing;
    inline for (.{
        .{ BuildInfo.version_major, build_options.version_major },
        .{ BuildInfo.version_minor, build_options.version_minor },
        .{ BuildInfo.version_patch, build_options.version_patch },
        .{ BuildInfo.vt_version_major, build_options.vt_version_major },
        .{ BuildInfo.vt_version_minor, build_options.vt_version_minor },
        .{ BuildInfo.vt_version_patch, build_options.vt_version_patch },
    }) |case| {
        var value: usize = undefined;
        try testing.expectEqual(Result.success, get(case[0], @ptrCast(&value)));
        try testing.expectEqual(case[1], value);
    }
}

test "get version strings" {
    const testing = std.testing;
    var value: String = undefined;

    try testing.expectEqual(Result.success, get(.version_string, @ptrCast(&value)));
    try testing.expectEqualStrings(build_options.version_string, value.slice());

    try testing.expectEqual(Result.success, get(.version_pre, @ptrCast(&value)));
    try testing.expectEqualStrings(build_options.version_pre orelse "", value.slice());

    try testing.expectEqual(Result.success, get(.version_build, @ptrCast(&value)));
    try testing.expectEqualStrings(build_options.version_build orelse "", value.slice());
}

test "version string agrees with the version numbers" {
    const testing = std.testing;
    const v = try std.SemanticVersion.parse(build_options.version_string);
    try testing.expectEqual(build_options.version_major, v.major);
    try testing.expectEqual(build_options.version_minor, v.minor);
    try testing.expectEqual(build_options.version_patch, v.patch);
}

test "get vt_version_string" {
    const testing = std.testing;
    var value: String = undefined;
    try testing.expectEqual(Result.success, get(.vt_version_string, @ptrCast(&value)));
    const v = try std.SemanticVersion.parse(value.slice());
    try testing.expectEqual(build_options.vt_version_major, v.major);
    try testing.expectEqual(build_options.vt_version_minor, v.minor);
    try testing.expectEqual(build_options.vt_version_patch, v.patch);
}

test "version" {
    const testing = std.testing;
    const value = std.mem.span(version());
    try testing.expectEqualStrings(build_options.version_string, value);

    var string: String = undefined;
    try testing.expectEqual(Result.success, get(.version_string, @ptrCast(&string)));
    try testing.expectEqualStrings(string.slice(), value);
}

test "get invalid" {
    try std.testing.expectEqual(Result.invalid_value, get(.invalid, null));
}

test "get null out" {
    try std.testing.expectEqual(Result.invalid_value, get(.version_major, null));
}

test "get unknown key" {
    var value: usize = 0;
    try std.testing.expectEqual(
        Result.unsupported,
        get(@fromBackingInt(@intCast(9999)), @ptrCast(&value)),
    );
}
