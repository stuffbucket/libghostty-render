const std = @import("std");
const builtin = @import("builtin");

/// The library version, from build.zig.zon. Between releases it is the
/// release being worked towards with a "-dev" suffix. See `libVersion`
/// for how a build turns it into the version it reports.
const zon_version = @import("build.zig.zon").version;

/// Minimum required Zig version, the same as libghostty-vt's.
const minimum_zig_version = @import("build.zig.zon").minimum_zig_version;

/// The oldest libghostty-vt release this library builds against. Only
/// releases with the same major version are accepted.
const minimum_vt_version: std.SemanticVersion = .{ .major = 1, .minor = 0, .patch = 1 };

/// libghostty-render releases are tagged `render-X.Y.Z`.
const tag_prefix = "render-";

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
    const is_dep = b.dep_prefix.len > 0;

    const test_filters = b.option(
        [][]const u8,
        "test-filter",
        "Filter for test. Only applies to Zig tests.",
    ) orelse &[0][]const u8{};
    const version_string = b.option(
        []const u8,
        "version-string",
        "A specific version string to use for the build. If not specified, " ++
            "git and build.zig.zon are used. This must be a semantic version.",
    );

    const lib_version: std.SemanticVersion = if (version_string) |v|
        try std.SemanticVersion.parse(v)
    else
        try libVersion(b, is_dep);

    const ghostty = b.lazyDependency("ghostty", .{
        .target = target,
        .optimize = optimize,
    }) orelse return;
    const vt_version = try vtVersion(ghostty);

    // Build options visible to the library as @import("build_options").
    const options = b.addOptions();
    {
        var buf: [256]u8 = undefined;
        const full = try std.fmt.bufPrint(&buf, "{f}", .{lib_version});
        options.addOption([]const u8, "version_string", b.dupe(full));
        options.addOption(usize, "version_major", lib_version.major);
        options.addOption(usize, "version_minor", lib_version.minor);
        options.addOption(usize, "version_patch", lib_version.patch);
        options.addOption(?[]const u8, "version_pre", lib_version.pre);
        options.addOption(?[]const u8, "version_build", lib_version.build);
        options.addOption(usize, "vt_version_major", vt_version.major);
        options.addOption(usize, "vt_version_minor", vt_version.minor);
        options.addOption(usize, "vt_version_patch", vt_version.patch);
    }

    const vt_shared = ghostty.artifact("ghostty-vt");
    const vt_static = ghostty.artifact("ghostty-vt-static");

    const shared = addLibrary(b, .dynamic, target, optimize, options, lib_version, vt_shared);
    const static = addLibrary(b, .static, target, optimize, options, lib_version, vt_static);

    // The render library is unusable without libghostty-vt, so install
    // libghostty-vt's libraries and headers next to ours.
    b.installArtifact(shared);
    b.installArtifact(static);
    b.installArtifact(vt_shared);
    b.installArtifact(vt_static);

    // Tests
    const test_step = b.step("test", "Run all tests");

    // Unit tests of the library code.
    {
        const mod = createLibModule(b, target, optimize, options);
        const t = b.addTest(.{
            .name = "ghostty-render-test",
            .root_module = mod,
            .filters = test_filters,
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // The committed version.h and the symbol version nodes in
    // gtr-render.map must match the library version, so a version bump has
    // to update them together. The test embeds these files, so they are
    // copied into one directory.
    {
        const wf = b.addWriteFiles();
        const root = wf.addCopyFile(b.path("src/version_test.zig"), "version_test.zig");
        _ = wf.addCopyFile(b.path("include/gtr/render/version.h"), "version.h");
        _ = wf.addCopyFile(b.path("src/c/gtr-render.map"), "gtr-render.map");
        const opts = b.addOptions();
        opts.addOption(std.SemanticVersion, "lib_version", lib_version);
        const mod = b.createModule(.{
            .root_source_file = root,
            .target = b.graph.host,
            .optimize = .Debug,
        });
        mod.addOptions("lib_version", opts);
        const t = b.addTest(.{
            .name = "ghostty-render-version-test",
            .root_module = mod,
            .filters = test_filters,
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // The libghostty-vt library we link reports the release its headers
    // describe.
    {
        const mod = b.createModule(.{
            .root_source_file = b.path("src/vt_test.zig"),
            .target = target,
            .optimize = optimize,
        });
        mod.addOptions("build_options", options);
        mod.linkLibrary(vt_static);
        const t = b.addTest(.{
            .name = "ghostty-render-vt-test",
            .root_module = mod,
            .filters = test_filters,
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }
}

fn createLibModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.OptimizeMode,
    options: *std.Build.Step.Options,
) *std.Build.Module {
    const mod = b.createModule(.{
        .root_source_file = b.path("src/lib_render.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addOptions("build_options", options);
    return mod;
}

fn addLibrary(
    b: *std.Build,
    linkage: std.lang.LinkMode,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.OptimizeMode,
    options: *std.Build.Step.Options,
    version: std.SemanticVersion,
    vt: *std.Build.Step.Compile,
) *std.Build.Step.Compile {
    const mod = createLibModule(b, target, optimize, options);
    const lib = b.addLibrary(.{
        .name = if (linkage == .static) "ghostty-render-static" else "ghostty-render",
        .linkage = linkage,
        .root_module = mod,
        .version = version,
    });
    lib.installHeadersDirectory(b.path("include/gtr"), "gtr", .{
        .include_extensions = &.{".h"},
    });

    // The render library takes libghostty-vt objects, such as render
    // states, from the application. Both must use the same copy of
    // libghostty-vt, so the shared library links the shared libghostty-vt
    // and the static library leaves libghostty-vt for the application to
    // link.
    switch (linkage) {
        .dynamic => mod.linkLibrary(vt),
        .static => {
            // Only the headers. The archive is linked by the application.
            mod.addIncludePath(vt.getEmittedIncludeTree());

            // Enable PIC so the static library can be linked into PIE
            // executables, the default on most Linux distributions.
            mod.pic = target.result.os.tag != .freestanding;
        },
    }

    if (linkage == .dynamic and target.result.os.tag.isDarwin()) {
        lib.install_name = b.fmt("@rpath/libghostty-render.{d}.dylib", .{version.major});
    }
    if (linkage == .dynamic and target.result.ofmt == .elf) {
        // Export only the gtr_* functions, tagged with a version that the
        // loader checks. The map file explains the versioning.
        lib.version_script = b.path("src/c/gtr-render.map");

        // Zig's own ELF linker silently ignores the version script. LLD
        // applies it, and Zig can only link with LLD when it compiles with
        // LLVM.
        lib.use_llvm = true;
        lib.use_lld = true;
    }
    if (target.result.os.tag.isDarwin()) {
        // Self-hosted x86_64 doesn't work for Darwin.
        lib.use_llvm = true;

        // Required for codesign and dynamic linking to work.
        lib.headerpad_max_install_names = true;
    }
    if (target.result.os.tag == .windows) {
        // Zig's ubsan emits /exclude-symbols linker directives that are
        // incompatible with the MSVC linker (LNK4229).
        lib.bundle_ubsan_rt = false;
    }

    return lib;
}

/// Returns the library version when `-Dversion-string` isn't set.
///
/// The build.zig.zon version is used as is when this is a dependency or
/// git isn't available. Otherwise the version depends on the commit's
/// `render-` tag. With `.version = "0.1.0-dev"`:
///
///   | Commit                 | Version             |
///   | ---------------------- | ------------------- |
///   | Tagged `render-0.1.0`  | 0.1.0               |
///   | Tagged `render-0.2.0`  | panic, tag mismatch |
///   | Untagged, at c7f68a7f4 | 0.1.0-dev+c7f68a7f4 |
fn libVersion(b: *std.Build, is_dep: bool) !std.SemanticVersion {
    const version = try std.SemanticVersion.parse(zon_version);
    if (is_dep) return version;

    var code: u8 = 0;
    const short_hash = hash: {
        const output = b.runAllowFail(
            &.{ "git", "-C", b.root.subPathOrDot(), "-c", "log.showSignature=false", "log", "--pretty=format:%h", "-n", "1" },
            &code,
            .ignore,
        ) catch |err| switch (err) {
            // No git, not a repository, or no commits yet.
            error.FileNotFound, error.ExitCodeFailure => return version,
            else => return err,
        };
        break :hash std.mem.trim(u8, output, &std.ascii.whitespace);
    };

    const tags = b.runAllowFail(
        &.{ "git", "-C", b.root.subPathOrDot(), "tag", "--points-at", "HEAD" },
        &code,
        .ignore,
    ) catch |err| switch (err) {
        error.FileNotFound, error.ExitCodeFailure => return version,
        else => return err,
    };

    var it = std.mem.tokenizeAny(u8, tags, "\r\n ");
    while (it.next()) |tag| {
        if (!std.mem.startsWith(u8, tag, tag_prefix)) continue;

        const expected = b.fmt("{s}{d}.{d}.{d}", .{
            tag_prefix,
            version.major,
            version.minor,
            version.patch,
        });
        if (!std.mem.eql(u8, tag, expected)) std.debug.panic(
            "release tag {s} doesn't match the version \"{s}\" in " ++
                "build.zig.zon. Expected the tag {s}.",
            .{ tag, zon_version, expected },
        );

        return .{
            .major = version.major,
            .minor = version.minor,
            .patch = version.patch,
        };
    }

    return .{
        .major = version.major,
        .minor = version.minor,
        .patch = version.patch,
        .pre = version.pre orelse "dev",
        .build = if (short_hash.len > 0) short_hash else null,
    };
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
