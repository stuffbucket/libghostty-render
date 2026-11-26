# libghostty-render-sys

Raw Rust bindings to [libghostty-vt](https://github.com/ghostty-org/ghostty),
Ghostty's terminal emulation library, pinned to Ghostty tag `vt-1.0.1`
(commit `108cacb17ed8990840cd14abfce43d8ed8503ca1`).

The build script compiles libghostty-vt from source with Zig and links the
static archive; bindgen generates the bindings from `ghostty/vt.h`, doc
comments included. Macros and `static inline` helpers that bindgen can't
emit (style flags, `GHOSTTY_STYLE_UNDERLINE`, `GHOSTTY_MODE_*`,
`ghostty_mode_new`, image layer masks, palette masks, `GHOSTTY_INIT_SIZED`)
are written out by hand in `src/lib.rs` and tested against the library.

## Building

- Zig 0.17.0 or newer on `PATH`, or named by `ZIG`.
- libclang for bindgen (Xcode Command Line Tools on macOS, `libclang-dev` on
  Linux, LLVM on Windows).
- The Ghostty source: the repository's `vendor/ghostty` submodule
  (`git submodule update --init --depth 1`), or any vt-1.0.1 checkout named
  by `GHOSTTY_SOURCE_DIR`.

Zig fetches libghostty-vt's own dependencies (highway, wuffs, uucode,
translate-c) on the first build, into `zig-pkg/` inside the Ghostty source.

Supported targets: `{x86_64,aarch64}-apple-darwin`,
`{x86_64,aarch64}-unknown-linux-gnu`, `{x86_64,aarch64}-pc-windows-msvc`.

## Licence

Apache-2.0. libghostty-vt is MIT, and the archive it builds statically
includes code under other licences; see `NOTICE` and `licenses/README.md`.
The build script is derived from herdr-app's `ghostty-sys`; see
`docs/PROVENANCE.md` in the repository.
