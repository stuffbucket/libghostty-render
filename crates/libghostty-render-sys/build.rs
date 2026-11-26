// Derived from herdr-app crates/ghostty-sys/build.rs (https://github.com/herdrdev/herdr-app, commit a2e8e3f, Apache-2.0). Modified by the libghostty-render authors: GHOSTTY_SOURCE_DIR override, Zig 0.17 requirement for vt-1.0.1, -DGHOSTTY_STATIC, C23 enums for bindgen, Windows system libraries, macros bindgen cannot evaluate are blocklisted (hand-defined in src/lib.rs), the release version is passed for the pinned submodule.

//! Builds libghostty-vt (Ghostty tag vt-1.0.1) from source with Zig and
//! generates bindings to `ghostty/vt.h` with bindgen.
//!
//! The source is the `vendor/ghostty` git submodule unless
//! `GHOSTTY_SOURCE_DIR` points elsewhere. `ZIG` names the Zig binary
//! (default `zig`); Zig 0.17.0 or newer is required.

use std::path::{Path, PathBuf};
use std::process::Command;

// Zig builds for the machine it runs on unless told otherwise: its CPU's
// newest instructions, which crash older CPUs, and never another target's.
fn zig_target(target: &str) -> &'static str {
    match target {
        "x86_64-unknown-linux-gnu" => "x86_64-linux-gnu",
        "aarch64-unknown-linux-gnu" => "aarch64-linux-gnu",
        "x86_64-apple-darwin" => "x86_64-macos",
        "aarch64-apple-darwin" => "aarch64-macos",
        "x86_64-pc-windows-msvc" => "x86_64-windows-msvc",
        "aarch64-pc-windows-msvc" => "aarch64-windows-msvc",
        other => panic!("libghostty-render-sys: no Zig target for {other}"),
    }
}

/// The release in `include/ghostty/vt/version.h`, such as "1.0.1".
fn header_version(src: &Path) -> String {
    let header = std::fs::read_to_string(src.join("include/ghostty/vt/version.h"))
        .expect("read ghostty/vt/version.h");
    header
        .lines()
        .find_map(|line| {
            let mut tokens = line.split_whitespace();
            (tokens.next() == Some("#define") && tokens.next() == Some("GHOSTTY_VT_VERSION"))
                .then(|| tokens.next())
                .flatten()
                .map(|v| v.trim_matches('"').to_owned())
        })
        .expect("GHOSTTY_VT_VERSION in ghostty/vt/version.h")
}

fn source_dir(manifest: &Path) -> PathBuf {
    let (src, hint) = match std::env::var_os("GHOSTTY_SOURCE_DIR") {
        Some(dir) => (
            PathBuf::from(dir),
            "GHOSTTY_SOURCE_DIR does not name a Ghostty checkout",
        ),
        None => (
            manifest.join("../../vendor/ghostty"),
            "vendor/ghostty is empty: run `git submodule update --init --depth 1`, or set GHOSTTY_SOURCE_DIR",
        ),
    };
    if !src.join("build.zig").is_file() || !src.join("include/ghostty/vt.h").is_file() {
        panic!("libghostty-render-sys: {hint} ({})", src.display());
    }
    let src = src.canonicalize().expect("canonicalize Ghostty source dir");
    // Windows' canonical form is `\\?\C:\...`, which clang can't resolve includes against.
    PathBuf::from(src.to_string_lossy().trim_start_matches(r"\\?\").to_owned())
}

fn main() {
    let manifest = PathBuf::from(std::env::var("CARGO_MANIFEST_DIR").unwrap());
    let src = source_dir(&manifest);
    let out = PathBuf::from(std::env::var("OUT_DIR").unwrap());
    for path in ["src", "pkg", "build.zig", "build.zig.zon", "include"] {
        println!("cargo:rerun-if-changed={}", src.join(path).display());
    }
    println!("cargo:rerun-if-env-changed=ZIG");
    println!("cargo:rerun-if-env-changed=GHOSTTY_SOURCE_DIR");

    let target = std::env::var("TARGET").unwrap();
    let zig = std::env::var("ZIG").unwrap_or_else(|_| "zig".into());
    let mut zig_build = Command::new(&zig);
    zig_build.arg("build");
    // Ghostty names an untagged checkout "1.0.1-dev+<hash>". The submodule
    // is pinned to the vt-1.0.1 commit, but a shallow clone (as CI and the
    // README's `--depth 1` make) has no tags, so pass the release version.
    // Another source dir keeps Ghostty's own version.
    if std::env::var_os("GHOSTTY_SOURCE_DIR").is_none() {
        zig_build.arg(format!("-Dlib-version-string={}", header_version(&src)));
    }
    let status = zig_build
        .current_dir(&src)
        // Only the static library is linked. Ghostty can also build an
        // xcframework, which needs a full Xcode; it is off by default with
        // -Demit-lib-vt in vt-1.0.1 but stays off explicitly here.
        .args([
            "-Demit-lib-vt",
            "-Demit-xcframework=false",
            "-Doptimize=ReleaseFast",
        ])
        .arg(format!("-Dtarget={}", zig_target(&target)))
        .arg("--prefix")
        .arg(out.join("zig-out"))
        .arg("--cache-dir")
        .arg(out.join("zig-cache"))
        .status()
        .unwrap_or_else(|e| panic!("cannot run {zig:?} (Zig >= 0.17.0 required; set ZIG): {e}"));
    assert!(
        status.success(),
        "zig build of libghostty-vt failed: {status}"
    );

    // Only the static archive in the search path, so the linker can't pick the shared one.
    let lib = out.join("lib");
    std::fs::create_dir_all(&lib).unwrap();
    let msvc = std::env::var("CARGO_CFG_TARGET_ENV").as_deref() == Ok("msvc");
    if msvc {
        std::fs::copy(
            out.join("zig-out/lib/ghostty-vt-static.lib"),
            lib.join("ghostty-vt.lib"),
        )
        .unwrap();
    } else {
        std::fs::copy(
            out.join("zig-out/lib/libghostty-vt.a"),
            lib.join("libghostty-vt.a"),
        )
        .unwrap();
    }
    println!("cargo:rustc-link-search=native={}", lib.display());
    println!("cargo:rustc-link-lib=static=ghostty-vt");
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        // GhosttyLibVt.zig links these into its static library's module; an
        // archive can't carry them, so the final link must.
        println!("cargo:rustc-link-lib=ntdll");
        println!("cargo:rustc-link-lib=kernel32");
    }
    // Downstream build scripts can find the headers via DEP_GHOSTTY_VT_INCLUDE.
    println!("cargo:include={}", src.join("include").display());

    // libclang without a full clang install lacks its builtin headers; Zig ships the same ones.
    let zig_env = Command::new(&zig).arg("env").output().expect("zig env");
    let zig_env = String::from_utf8_lossy(&zig_env.stdout);
    let zig_lib = zig_env
        .lines()
        .find_map(|l| l.trim().strip_prefix(".lib_dir = \""))
        .and_then(|l| l.strip_suffix("\","))
        .expect("zig env has no lib_dir");

    let include = src.join("include");
    let mut builder = bindgen::Builder::default()
        .header(include.join("ghostty/vt.h").to_string_lossy())
        .clang_arg(format!("-I{}", include.display()))
        // The static library has no dllimport/visibility decorations.
        .clang_arg("-DGHOSTTY_STATIC")
        // Under C23 the headers' GHOSTTY_ENUM_TYPED gives every enum an `int`
        // underlying type, so the generated enum types are i32 on every
        // target (pre-C23 they are u32 on Unix and i32 on MSVC).
        .clang_arg("-std=c2x");
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {
        // Apple's libclang has its builtin headers but needs the SDK for the C
        // library (Zig's builtin headers clash with it there).
        if let Ok(sdk) = Command::new("xcrun").args(["--show-sdk-path"]).output() {
            builder = builder.clang_arg(format!(
                "-isysroot{}",
                String::from_utf8_lossy(&sdk.stdout).trim()
            ));
        }
    } else if Command::new("clang").arg("--version").output().is_err() {
        // With a clang installed, bindgen asks it for its own builtin headers,
        // which match its libclang; Zig's newer ones break older ones.
        builder = builder.clang_arg(format!("-isystem{zig_lib}/include"));
    }
    builder
        .allowlist_function("ghostty_.*")
        .allowlist_type("Ghostty.*")
        .allowlist_var("GHOSTTY_.*")
        // Casts and enum references bindgen can't evaluate; src/lib.rs defines these.
        .blocklist_item("GHOSTTY_STYLE_FLAG_.*")
        .blocklist_item("GHOSTTY_STYLE_UNDERLINE_.*")
        .blocklist_item("GHOSTTY_IMAGE_LAYER_MASK_.*")
        .blocklist_item("GHOSTTY_ENUM_MAX_VALUE")
        .prepend_enum_name(false)
        .derive_default(true)
        .layout_tests(false)
        .generate()
        .expect("bindgen failed on ghostty/vt.h")
        .write_to_file(out.join("bindings.rs"))
        .unwrap();
}
