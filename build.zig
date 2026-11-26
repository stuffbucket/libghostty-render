const std = @import("std");
const builtin = @import("builtin");

/// Minimum required Zig version, the same as libghostty-vt's.
const minimum_zig_version = @import("build.zig.zon").minimum_zig_version;

/// The oldest libghostty-vt release this library builds against. Only
/// releases with the same major version are accepted.
const minimum_vt_version: std.SemanticVersion = .{ .major = 1, .minor = 0, .patch = 1 };

comptime {
    const current = builtin.zig_version;
    const required = std.SemanticVersion.parse(minimum_zig_version) catch unreachable;
    if (current.major != required.major or
        current.minor != required.minor or
        current.patch < required.patch)
    {
        @compileError(std.fmt.comptimePrint(
            "Your Zig version v{f} does not meet the required build version of v{f}",
            .{ current, required },
        ));
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ghostty = b.lazyDependency("ghostty", .{
        .target = target,
        .optimize = optimize,
    }) orelse return;
    _ = try vtVersion(ghostty);

    const vt_shared = ghostty.artifact("ghostty-vt");
    const vt_static = ghostty.artifact("ghostty-vt-static");

    // The render library is unusable without libghostty-vt, so install
    // libghostty-vt's libraries and headers next to ours.
    b.installArtifact(vt_shared);
    b.installArtifact(vt_static);
}

/// Reads the libghostty-vt release from the dependency's version.h and
/// fails the build if this library doesn't support it.
fn vtVersion(ghostty: *std.Build.Dependency) !std.SemanticVersion {
    const b = ghostty.builder;
    const path = try b.root.join(b.allocator, "include/ghostty/vt/version.h");
    const header = try path.root_dir.handle.readFileAlloc(
        b.graph.io,
        path.subPathOrDot(),
        b.allocator,
        .limited(64 * 1024),
    );

    const version: std.SemanticVersion = .{
        .major = try headerDefine(header, "GHOSTTY_VT_VERSION_MAJOR"),
        .minor = try headerDefine(header, "GHOSTTY_VT_VERSION_MINOR"),
        .patch = try headerDefine(header, "GHOSTTY_VT_VERSION_PATCH"),
    };

    if (version.major != minimum_vt_version.major or
        version.order(minimum_vt_version) == .lt)
    {
        std.debug.panic(
            "libghostty-render needs libghostty-vt {d}.x at {f} or newer, " ++
                "but the ghostty dependency is libghostty-vt {f}",
            .{ minimum_vt_version.major, minimum_vt_version, version },
        );
    }

    return version;
}

/// Returns the integer value of `#define name value` in a header.
fn headerDefine(header: []const u8, name: []const u8) !usize {
    var it = std.mem.splitScalar(u8, header, '\n');
    while (it.next()) |line| {
        var tokens = std.mem.tokenizeAny(u8, line, " \t\r");
        const directive = tokens.next() orelse continue;
        if (!std.mem.eql(u8, directive, "#define")) continue;
        const key = tokens.next() orelse continue;
        if (!std.mem.eql(u8, key, name)) continue;
        return try std.fmt.parseInt(usize, tokens.next() orelse return error.MissingValue, 10);
    }
    return error.MissingDefine;
}
