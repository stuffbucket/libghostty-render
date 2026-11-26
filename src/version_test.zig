//! Checks that the files that repeat the library version agree with the
//! version the library is built with (`.version` in build.zig.zon, a
//! `render-` tag, or `-Dversion-string`). Those files are
//! include/gtr/render/version.h and src/c/gtr-render.map.
//!
//! This is the root of its own test binary, not part of the library.
//! build.zig copies those files next to this one so they can be embedded,
//! and passes the library version as `lib_version`.
//!
//! The header is read as text, the same way build systems such as CMake
//! read it, so this also keeps each define on its own simple line.

const std = @import("std");
const lib_version: std.SemanticVersion = @import("lib_version").lib_version;

const header = @embedFile("version.h");
const map = @embedFile("gtr-render.map");

/// Returns the value of `#define name value` in the header.
fn define(name: []const u8) ![]const u8 {
    var it = std.mem.splitScalar(u8, header, '\n');
    while (it.next()) |line| {
        var tokens = std.mem.tokenizeAny(u8, line, " \t\r");
        const directive = tokens.next() orelse continue;
        if (!std.mem.eql(u8, directive, "#define")) continue;
        const key = tokens.next() orelse continue;
        if (!std.mem.eql(u8, key, name)) continue;
        const value = tokens.next() orelse return error.MissingValue;
        if (tokens.next() != null) return error.TrailingTokens;
        return value;
    }

    return error.MissingDefine;
}

fn defineInt(name: []const u8) !usize {
    return try std.fmt.parseInt(usize, try define(name), 10);
}

test "version.h matches lib_version" {
    const testing = std.testing;

    try testing.expectEqual(lib_version.major, try defineInt("GTR_RENDER_VERSION_MAJOR"));
    try testing.expectEqual(lib_version.minor, try defineInt("GTR_RENDER_VERSION_MINOR"));
    try testing.expectEqual(lib_version.patch, try defineInt("GTR_RENDER_VERSION_PATCH"));

    // The header string is only the release number. A development
    // build's pre-release and build metadata (0.1.0-dev+abc1234) differ
    // per build, and a tagged build of the same commit drops them.
    var expected_buf: [128]u8 = undefined;
    const expected = try std.fmt.bufPrint(
        &expected_buf,
        "\"{d}.{d}.{d}\"",
        .{ lib_version.major, lib_version.minor, lib_version.patch },
    );
    try testing.expectEqualStrings(expected, try define("GTR_RENDER_VERSION"));
}

test "gtr-render.map has a node for lib_version and each earlier minor" {
    // Before 1.0 the first node is 0.1; there is no 0.0 release.
    var minor: usize = if (lib_version.major == 0) 1 else 0;
    while (minor <= lib_version.minor) : (minor += 1) {
        var name_buf: [64]u8 = undefined;
        const name = try std.fmt.bufPrint(
            &name_buf,
            "GTR_RENDER_{d}.{d}",
            .{ lib_version.major, minor },
        );

        // A node starts in the first column. This skips the worked example
        // in the map's comment, which would otherwise count as a node, and
        // the "} GTR_RENDER_0.1;" that chains one node to the previous one.
        var found = false;
        var lines = std.mem.splitScalar(u8, map, '\n');
        while (lines.next()) |line| {
            if (!std.mem.startsWith(u8, line, "GTR_RENDER_")) continue;
            var tokens = std.mem.tokenizeAny(u8, line, " \t\r");
            if (!std.mem.eql(u8, tokens.next().?, name)) continue;
            const brace = tokens.next() orelse continue;
            if (std.mem.eql(u8, brace, "{")) found = true;
        }

        if (!found) {
            std.debug.print("gtr-render.map has no node {s}\n", .{name});
            return error.MissingNode;
        }
    }
}

test "gtr-render.map has no node newer than lib_version" {
    var lines = std.mem.splitScalar(u8, map, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "GTR_RENDER_")) continue;
        var tokens = std.mem.tokenizeAny(u8, line, " \t\r");
        const node = tokens.next().?["GTR_RENDER_".len..];
        var parts = std.mem.splitScalar(u8, node, '.');
        const major = try std.fmt.parseInt(usize, parts.next().?, 10);
        const minor = try std.fmt.parseInt(usize, parts.next() orelse return error.BadNode, 10);
        if (major > lib_version.major or
            (major == lib_version.major and minor > lib_version.minor))
        {
            std.debug.print("gtr-render.map has node {s}, newer than the library\n", .{node});
            return error.NodeTooNew;
        }
    }
}
