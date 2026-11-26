//! Checks the libghostty-vt that libghostty-render is built and linked
//! against.
//!
//! build.zig reads GHOSTTY_VT_VERSION_* from the libghostty-vt headers of
//! the `ghostty` dependency and refuses to build against an unsupported
//! release. This test links the libghostty-vt library from the same
//! dependency and checks, through its public C API, that the library
//! reports the same release as its headers.

const std = @import("std");
const build_options = @import("build_options");

const GhosttyResult = c_int;
const GHOSTTY_SUCCESS: GhosttyResult = 0;

/// GhosttyBuildInfo values from <ghostty/vt/build_info.h>.
const GHOSTTY_BUILD_INFO_VERSION_MAJOR: c_int = 6;
const GHOSTTY_BUILD_INFO_VERSION_MINOR: c_int = 7;
const GHOSTTY_BUILD_INFO_VERSION_PATCH: c_int = 8;

extern fn ghostty_build_info(data: c_int, out: ?*anyopaque) GhosttyResult;
extern fn ghostty_version() [*:0]const u8;

fn vtInfo(key: c_int) !usize {
    var value: usize = 0;
    if (ghostty_build_info(key, @ptrCast(&value)) != GHOSTTY_SUCCESS)
        return error.BuildInfoFailed;
    return value;
}

test "linked libghostty-vt matches its headers" {
    const testing = std.testing;
    try testing.expectEqual(build_options.vt_version_major, try vtInfo(GHOSTTY_BUILD_INFO_VERSION_MAJOR));
    try testing.expectEqual(build_options.vt_version_minor, try vtInfo(GHOSTTY_BUILD_INFO_VERSION_MINOR));
    try testing.expectEqual(build_options.vt_version_patch, try vtInfo(GHOSTTY_BUILD_INFO_VERSION_PATCH));
}

test "linked libghostty-vt version string starts with its release" {
    var buf: [32]u8 = undefined;
    const release = try std.fmt.bufPrint(&buf, "{d}.{d}.{d}", .{
        build_options.vt_version_major,
        build_options.vt_version_minor,
        build_options.vt_version_patch,
    });
    const full = std.mem.span(ghostty_version());
    try std.testing.expect(std.mem.startsWith(u8, full, release));
}
