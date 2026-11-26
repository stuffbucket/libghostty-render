# libghostty-render: PR series

This is the order the work lands in. Each PR is small enough to review in one sitting, compiles, and passes CI on its own. Each one proves one thing, stated in its "Proves" line. The commits inside a PR are listed as their planned subjects. They follow the house style in [DESIGN.md § Process](DESIGN.md#process) and are kept as written, then merged with a merge commit.

PRs are developed on branches of `github.com/stuffbucket/libghostty-render` and opened for the owner's review.

## Foundation

**1. `build: libghostty-render skeleton on libghostty-vt vt-1.0.1`**
Proves: the library builds against the pinned libghostty-vt and its version is checked.

- `build: add zig build with the ghostty vt-1.0.1 dependency`
- `build: emit static and shared libraries with a versioned symbol map`
- `version: add GTR_RENDER_VERSION macros, gtr_version and gtr_build_info`
- `version: test that header, symbol map and build version agree`
- `build: link a c program against the shared and static libraries`
- `docs: add AGENTS.md and describe the core library`

**2. `ci: lint, test and cross-build on GitHub-hosted runners`**
Proves: every later PR is held to the same gates.

- `build: add nix flake pinned to libghostty-vt's nixpkgs and zig`
- `ci: add zig fmt, prettier, alejandra, typos, shellcheck and pinact`
- `ci: run zig build test on macos, linux and windows`
- `build: rerun configure so the version follows git`
- `build: emit one wasm module with libghostty-vt for wasm32`
- `ci: cross-build the target matrix including wasm32`
- `ci: add the aggregated required job`
- `ci: test the msvc abi natively on windows`
- `docs: describe the linters, the wasm build and ci`

**3. `abi: header and Zig parity, symbol goldens and header compile matrix`**
Proves: the C headers cannot drift from the implementation.

- `abi: register public types and check them against translate-c`
- `abi: check exported symbols against headers and the export list`
- `abi: add per-target type manifest goldens`
- `abi: compile headers as c11, c23 and c++17 with -Werror`
- `ci: add libabigail baseline diff`

**4. `doxygen: docs build with groups, conventions and zero warnings`**
Proves: the docs build is warning-free from day one, and later PRs add docs as they go.

- `doxygen: add Doxyfile, groups.dox and the main page`
- `doxygen: document conventions shared with libghostty-vt`
- `ci: fail the docs job on any doxygen output`

## Core

**5. `metrics: port Ghostty's cell metrics`**
Proves: cell geometry matches Ghostty for the same face metrics.

- `metrics: port font/Metrics.zig from Ghostty vt-1.0.1`
- `metrics: port Ghostty's metrics tests`
- `metrics: add GtrFaceMetrics, GtrMetrics and gtr_metrics_calc`
- `metrics: parse and apply adjust-* modifiers`
- `example: c-metrics`

**6. `sprite: port Ghostty's sprite canvas and box drawing`**
Proves: box-drawing glyphs match Ghostty's reference images pixel for pixel.

- `build: add the z2d 0.13.2 dependency`
- `sprite: port the sprite canvas onto caller-owned A8 buffers`
- `sprite: port box drawing (U+2500–257F)`
- `sprite: compare against Ghostty's testdata goldens`
- `sprite: add gtr_sprite_has and gtr_sprite_render`

**7. `sprite: blocks, braille, powerline, legacy computing and specials`**
Proves: full sprite coverage, including decorations and cursors.

- `sprite: port blocks, braille and geometric shapes`
- `sprite: port powerline and branch drawing`
- `sprite: port legacy computing and octants`
- `sprite: port underline, strikethrough, overline and cursor sprites`
- `example: c-sprite-atlas`

**8. `color: Ghostty's colour resolution and minimum contrast`**
Proves: per-cell colours follow Ghostty's rules, including the edge cases.

- `color: port style fg/bg resolution with bold-color`
- `color: port the minimum-contrast function from the shaders`
- `color: test inverse, invisible, faint and isCovering`

**9. `renderer: renderer object and options named after Ghostty config`**
Proves: the options API follows libghostty-vt's get/set rules and uses Ghostty's defaults.

- `renderer: add GtrRenderer new and free`
- `renderer: add options with Ghostty's names and defaults`
- `renderer: add the glyph coverage callback`

## Frames

**10. `frame: backgrounds and text runs from a render state`**
Proves: a render state becomes background spans and shaping runs exactly as Ghostty splits them.

- `frame: add GtrFrame and its iterators`
- `frame: build merged background spans`
- `frame: port the shaping run iterator`
- `frame: golden frame plans from recorded byte streams`

**11. `frame: decorations, cursor and highlights`**
Proves: underlines, cursor rules and selection, search and link colours match Ghostty.

- `frame: decorations with Ghostty's draw order`
- `frame: cursor style, geometry and colours`
- `frame: selection, search and link highlights`
- `frame: preedit`

**12. `frame: kitty images and padding extension`**
Proves: images come out in Ghostty's layer order, and padding extends as Ghostty does.

- `frame: kitty placements in draw order`
- `frame: padding extension heuristics`
- `example: c-frame-dump`

**13. `fuzz: AFL++ harness from VT bytes to frame plans`**
Proves: arbitrary input cannot break frame invariants or leak memory.

- `fuzz: add the frame harness and corpus`
- `frame: assert frame invariants in debug builds`
- `ci: compile the fuzz harness and run valgrind`

## Distribution

**14. `dist: pkg-config, CMake package and release workflow`**
Proves: downstream projects can consume the library in the standard ways, and releases are reproducible.

- `build: install pkg-config files and the CMake package`
- `build: option to use a system libghostty-vt instead of installing the dependency's`
- `ci: build examples with zig and cmake`
- `ci: tag-driven release with signatures and checksums`
- `doxygen: rendering guide`

## Rust binding

This series reuses the vt-1.0.1 Rust bindings already ported from herdr-app (currently uncommitted under `crates/`; they move to `bindings/rust/`).

**15. `bindings/rust: sys crate for libghostty-vt and libghostty-render`**
Proves: Rust sees exactly the C ABI.

- `bindings/rust: build both libraries and bindgen their headers`
- `bindings/rust: check the bindgen layout against the ABI manifest`

**16. `bindings/rust: safe wrapper`**
Proves: the Rust API is safe and leak-free.

- `bindings/rust: terminal, render state and frame wrappers`
- `bindings/rust: sprites and metrics`

**17. `bindings/rust: GPUI terminal element derived from herdr-app`**
Proves: a GPUI app can show a Ghostty terminal using only the C library's frame plans.

- `bindings/rust: paint frame plans with GPUI`
- `bindings/rust: terminal view with input, IME and selection`
- `bindings/rust: replay and shell examples`
- `bindings/rust: visual golden tests on macos`

## Decisions (2026-11-24)

1. **Naming:** libghostty's scheme with our own root word: `<gtr/render.h>`, `gtr_<area>_<verb>`, `Gtr<Type>`, `GTR_RENDER_VERSION*`, tags `render-X.Y.Z`. See [DESIGN.md § Naming](DESIGN.md#naming).
2. **Licences:** MIT core; Apache-2.0 Rust binding; z2d (MPL-2.0) as an unmodified dependency.
3. **Rust binding location:** this repository, under `bindings/rust/`.

The Rust `-sys` crate ported so far (`crates/libghostty-render-sys`, uncommitted) moves to `bindings/rust/` in PR 15. The core uses a `build.zig.zon` dependency on Ghostty rather than the `vendor/ghostty` submodule, and the binding builds against the installed core.
