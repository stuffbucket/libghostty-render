# libghostty-render

Terminal rendering on top of [libghostty-vt](https://github.com/ghostty-org/ghostty),
Ghostty's terminal emulation library.

The renderer itself is being designed as a language-neutral C-ABI library,
with GPUI as one binding on top; see [`docs/DESIGN.md`](docs/DESIGN.md) and
[`docs/PLAN.md`](docs/PLAN.md). What exists today is its foundation:

- **The core library skeleton** (`build.zig`, `include/gtr/`, `src/`): a Zig
  library with a C ABI, built against libghostty-vt `vt-1.0.1` as a
  `build.zig.zon` dependency. It emits `libghostty-render` as a shared and a
  static library and exports only the version API so far: the
  `GTR_RENDER_VERSION*` macros in `<gtr/render/version.h>`, `gtr_version()` and
  `gtr_build_info()`. Shared builds export only `gtr_*` symbols, versioned
  `GTR_RENDER_0.1` on ELF, and link the shared libghostty-vt. The static
  library leaves libghostty-vt for the application to link, because the
  renderer and the application must share one copy of it.

  ```sh
  mise x zig@0.17.1 -- zig build test   # Zig unit tests, version agreement, C link tests
  mise x zig@0.17.1 -- zig build        # installs libs and headers into zig-out/
  ```

- **`libghostty-render-sys`**: builds libghostty-vt `vt-1.0.1` from source
  with Zig, links it statically, and exposes all of `ghostty/vt.h` to Rust
  through bindgen, plus hand-written equivalents of the macros and inline
  helpers bindgen can't generate.

## Usage

```toml
[dependencies]
libghostty-render-sys = { git = "https://github.com/stuffbucket/libghostty-render" }
```

```rust
use libghostty_render_sys::*;
use std::{ffi::c_void, ptr};

unsafe {
    let mut term = ptr::null_mut();
    assert_eq!(ghostty_terminal_new(ptr::null(), &mut term, 80, 24), GHOSTTY_SUCCESS);
    let bytes = b"\x1b[1;31mred\x1b[0m";
    ghostty_terminal_vt_write(term, bytes.as_ptr(), bytes.len());

    // Read the first cell's style back.
    let mut point = GhosttyPoint { tag: GHOSTTY_POINT_TAG_ACTIVE, ..Default::default() };
    point.value.coordinate = GhosttyPointCoordinate { x: 0, y: 0 };
    let mut cell = GhosttyGridRef::default();
    ghostty_terminal_grid_ref(term, point, &mut cell);
    let mut style = GhosttyStyle::default();
    ghostty_grid_ref_style(&cell, &mut style);
    assert!(style.flags & GHOSTTY_STYLE_FLAG_BOLD != 0);

    // Modes are packed (number + ANSI bit); use the constants.
    let mut mode = GhosttyTerminalModeConfig { mode: GHOSTTY_MODE_BRACKETED_PASTE, value: false };
    ghostty_terminal_get(term, GHOSTTY_TERMINAL_DATA_MODE, &mut mode as *mut _ as *mut c_void);

    ghostty_terminal_free(term);
}
```

## Building

You need Zig 0.17.0 or newer (`ZIG` can name the binary), libclang for
bindgen, and the Ghostty submodule:

```sh
git submodule update --init --depth 1
mise install            # Rust 1.99.0 and Zig 0.17.1, from mise.toml
cargo test --workspace
```

`GHOSTTY_SOURCE_DIR` builds from another Ghostty checkout instead of
`vendor/ghostty`. The first build lets Zig fetch libghostty-vt's
dependencies (highway, wuffs, uucode, translate-c).

## Platforms

macOS (arm64, x86_64), Linux glibc (x86_64, arm64) and Windows MSVC (x86_64,
arm64). CI builds and tests on macOS, Ubuntu and Windows.

## Ghostty pin

`vendor/ghostty` is Ghostty tag **`vt-1.0.1`**
(`108cacb17ed8990840cd14abfce43d8ed8503ca1`), libghostty-vt 1.0.1.
`vt-1.0.2` (tagged 2026-11-24, `573c4a21`) has the same headers apart from
the version macros, so moving to it is a one-line submodule change plus the
version constants. [`docs/PROVENANCE.md`](docs/PROVENANCE.md) lists the API
changes between vt-1.0.1 and the older Ghostty that herdr builds on.

## Licence

The core library is MIT-licensed, the same as libghostty-vt
([`LICENSE`](LICENSE)). The Rust bindings and the GPUI component are
Apache-2.0, because they derive from herdr-app and link GPUI
([`LICENSE-APACHE`](LICENSE-APACHE)). [`NOTICE`](NOTICE) has the credits.
libghostty-vt's static library also contains highway, simdutf, wuffs, uucode,
translate-c and Zig's runtime, whose licences are in
[`licenses/`](licenses/README.md) with the evidence for that list.

## Credits

This library exists because of other people's work, and we are grateful:

- **The herdr team** ([herdr-app](https://github.com/herdrdev/herdr-app)) for
  the technique of driving libghostty-vt from Rust and drawing it in GPUI,
  and for the code we started from: the Zig build and bindgen setup in
  `libghostty-render-sys` and the test cases are theirs (Apache-2.0; see
  [`docs/PROVENANCE.md`](docs/PROVENANCE.md)).
- **The Ghostty and libghostty team** ([Ghostty](https://github.com/ghostty-org/ghostty),
  Mitchell Hashimoto and contributors) for libghostty-vt, and for the renderer
  and font code the core library ports. All terminal emulation here is theirs.
- **Zed Industries** for [GPUI](https://github.com/zed-industries/zed), the
  UI framework the first binding targets.
