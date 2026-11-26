# libghostty-render: design

Status: proposal, 2026-11-24. Nothing below is implemented. Decisions that are still open are marked **[open]**.

## What it is

A toolkit-neutral terminal renderer for [libghostty-vt](https://lib.ghostty.org/vt/). It turns a libghostty-vt render state into a deterministic **frame plan**: everything an application needs to draw a terminal with its own UI toolkit (GPUI, Core Graphics/Metal, Qt, Direct2D, a web canvas) so the result looks like Ghostty.

It is meant to hold people over until libghostty ships a renderer of its own, and to be on par with libghostty-vt in API design, stability and testing until then.

### What the library does

Everything that is a terminal decision, not a toolkit decision:

- **Cell metrics:** cell size, baseline, and decoration and cursor geometry from the face metrics, including Ghostty's `adjust-*` modifiers.
- **Colour resolution:** palette, bold colour, inverse, invisible, faint, minimum contrast, selection and search colours.
- **Shaping runs:** how a row is cut into runs to shape (style, cursor, selection and ligature breaks; font-fallback breaks through a host callback).
- **Decorations:** single, double, curly, dotted and dashed underlines, plus strikethrough and overline.
- **Cursor:** style, geometry and colours (block, hollow, bar, underline, lock; focus; blink phase supplied by the caller).
- **Highlights and images:** selection, search and link highlights; Kitty image placements in draw order; padding extension.
- **Sprite glyphs**, rasterised as A8 masks: box drawing, blocks, braille, Powerline, legacy computing, octants and branch drawing.

### What the host does

Font loading and fallback, text shaping, glyph rasterisation and atlases, blending, presenting, image decoding and texture caching, input, IME and UI chrome.

### Where the logic comes from

The logic is ported from Ghostty's own renderer, which is MIT-licensed:

| Ghostty source | Ported into |
|---|---|
| `src/renderer/generic.zig` (`rebuildCells` / `rebuildRow`) | frame building |
| `src/renderer/{cell,row,cursor,image}.zig` | frame building |
| `src/terminal/style.zig` (colour resolution) | frame building |
| `src/font/shaper/run.zig` | run splitting |
| `src/font/Metrics.zig` | metrics |
| `src/font/sprite/` (on z2d) | sprites |
| `shaders.metal` (the minimum-contrast function) | colour resolution |

The ports are rewritten against libghostty-vt's **public** C API, not Ghostty's internal types.

herdr-app ([herdrdev/herdr-app](https://github.com/herdrdev/herdr-app), Apache-2.0) proved the technique: drawing libghostty-vt cells with a toolkit's own text and quad primitives. The Rust/GPUI binding is derived from its code.

## Layers

```text
 libghostty-vt  (Ghostty, MIT)        terminal state, render state, public C ABI
       │  public include/ghostty/vt/*.h only
 libghostty-render core  (Zig → C ABI)    metrics · renderer options · frame plans · sprites
       │  include/<ns>/*.h
 bindings/
   rust/  <ns>-sys (bindgen: vt + render headers) · safe wrapper · GPUI element (from herdr-app)
   (later) swift/, c++/qt, wasm/js …
```

The rules that keep the layers separate:

- **The core links only libghostty-vt and z2d.** It contains no toolkit, font, GPU or I/O code.
- **Bindings depend only on the installed headers and libraries**, never on core internals. Bindings are versioned separately from the core: a binding states which core minor versions it supports.
- **One copy of libghostty-vt.** The core takes libghostty-vt objects, such as render states, from the application, so both must use the same copy. The shared library links the shared libghostty-vt. The static library doesn't bundle libghostty-vt, so the application links it too.
- **The core never calls a clock.** Time-dependent state is an input, such as `focused` and `blink_visible`. The same render state and inputs always produce the same frame plan, byte for byte.

## Naming

Decided 2026-11-24. We copy libghostty's naming scheme exactly and swap only the root word, so the API reads like libghostty's and can never collide with an official library.

No libghostty renderer branch, PR or issue exists to copy (checked 2026-11-24). The only stated intent is a GPU library: "provide us with an OpenGL or Metal surface and we'll take care of the rest" ([libghostty is coming](https://mitchellh.com/writing/libghostty-is-coming)).

libghostty-vt's scheme puts the library name only in headers, version macros, symbol-map nodes and tags, never in function names. libghostty-vt exports `ghostty_terminal_new`, not `ghostty_vt_terminal_new`. Any `ghostty_<area>_*` name we picked could therefore collide with a future official library. `ghostty.h` already uses `ghostty_surface_*` and `ghostty_app_*`.

| | libghostty-vt | libghostty-render |
|---|---|---|
| Library | `libghostty-vt` | `libghostty-render` (`ghostty-render.dll`) |
| Umbrella header | `<ghostty/vt.h>` | `<gtr/render.h>` |
| Area headers | `<ghostty/vt/<area>.h>` | `<gtr/render/<area>.h>` |
| Include guards | `GHOSTTY_VT_<AREA>_H` | `GTR_RENDER_<AREA>_H` |
| Functions | `ghostty_<area>_<verb>` | `gtr_<area>_<verb>` |
| Types | `Ghostty<Type>` | `Gtr<Type>` |
| Constants | `GHOSTTY_<AREA>_<NAME>` | `GTR_<AREA>_<NAME>` |
| Visibility and deprecation | `GHOSTTY_API`, `GHOSTTY_STATIC`, `GHOSTTY_DEPRECATED` | `GTR_API`, `GTR_STATIC`, `GTR_DEPRECATED` |
| Version macros | `GHOSTTY_VT_VERSION*` | `GTR_RENDER_VERSION*` |
| Symbol-map node | `GHOSTTY_VT_1.0` | `GTR_RENDER_0.1` |
| Tags | `vt-X.Y.Z` | `render-X.Y.Z` |
| pkg-config / CMake | `libghostty-vt` / `ghostty-vt` | `libghostty-render` / `ghostty-render` |

Shared types (`GhosttyResult`, `GhosttyAllocator`, `GhosttyString` and so on) keep their `Ghostty` names, because we include libghostty-vt's own headers rather than redefining them.

## API shape

The core follows libghostty-vt's conventions exactly (`dist/doxygen/pages/conventions.md` and `src/terminal/c/AGENTS.md` at `vt-1.0.1`).

**What we reuse from libghostty-vt.** Our headers include `<ghostty/vt/types.h>` and `<ghostty/vt/allocator.h>`. We do not redefine these types or macros:

- `GhosttyResult`
- `GhosttyAllocator`
- `GhosttyString`, `GhosttyBuffer` and `GhosttyCodepoints`
- `GHOSTTY_ENUM_TYPED` / `GHOSTTY_ENUM_MAX_VALUE`
- `GHOSTTY_INIT_SIZED` and `ghostty_sized_init`

The same rules apply:

- Opaque handles have `_new(const GhosttyAllocator*, X* out)` and `_free`, and `_free(NULL)` is a no-op.
- `_get`/`_set`/`_get_multi` take key enums that start at `*_INVALID = 0`. An unknown key returns `GHOSTTY_UNSUPPORTED`, and setting NULL restores the default.
- Sized structs have `size` as the first field, are zero-defaulted, and are read and written only up to `size`. Every other struct is documented as frozen, with its byte size.
- Iterators follow new → filled by `_get` → `bool _next` → per-item `_get` → `_free`.
- Every enum ends in `_MAX_VALUE`, and enums coming from C are validated in every build mode.
- Every function returns a result code. Nothing panics across the ABI. Release builds trap.

### Areas (first release)

| Area | Objects and calls | Ported from |
|---|---|---|
| `version` | `GTR_VERSION_*` macros, `gtr_version()`, `gtr_build_info()` | libghostty-vt pattern |
| `metrics` | `GtrFaceMetrics` (sized, input), `GtrMetrics` (sized, output), `gtr_metrics_calc`, modifier parse/apply | `font/Metrics.zig` |
| `renderer` | `GtrRenderer` new/free/set/get. Options are named after Ghostty config keys: `minimum-contrast`, `bold-color`, `faint-opacity`, `cursor-color`, `cursor-text`, `cursor-opacity`, `selection-foreground/background`, `search-*`, `background-opacity`, `background-opacity-cells`, `window-padding-color`, `font-shaping-break`. Defaults match Ghostty's. Plus a glyph-coverage callback for font-fallback run breaks | `config/Config.zig` defaults; `terminal/style.zig` |
| `frame` | `gtr_frame_build(renderer, GhosttyRenderState, const GtrFrameInputs*, GtrFrame)` | `renderer/generic.zig`, `cell.zig`, `row.zig`, `cursor.zig`, `image.zig`, `font/shaper/run.zig` |
| `sprite` | `gtr_sprite_has(cp)`, `gtr_sprite_render(cp_or_special, const GtrMetrics*, span, GhosttyBuffer*, GtrSpriteInfo*)` → A8 mask with bearings. Covers the decoration and cursor sprites too, so every pixel matches Ghostty | `font/sprite/` |
| `color` | `gtr_color_contrast(fg, bg, ratio)` (WCAG, linear) | `shaders.metal` `contrasted_color` |

`gtr_frame_build` takes per-frame inputs (focus, blink phase, preedit range, search and link highlights) and returns iterators for:

- background spans;
- text runs (codepoints, clusters, cell span, font style, presentation, resolved colours, constraint hints, and a stable hash for host caching);
- decorations;
- the cursor;
- images in draw order;
- padding extension;
- per-row dirty flags.

Frames reuse their storage across builds, just as render states do.

## Proving it correct

We use the compiler and the toolchain the way libghostty-vt does, and add golden comparisons against Ghostty's own output.

1. **Header and code cannot drift.**
   - A `type_decls` registry lists every public type. A translate-c test imports our headers into Zig and checks every size, alignment, field offset, enum value, `_MAX_VALUE` sentinel, handle and callback against the Zig definitions. The reverse check catches header types missing from the registry. Any mismatch fails the build. (Mirrors libghostty-vt's `c/abi_test.zig` and `c/types.zig`.)
   - `symbols.txt` is cross-checked against the explicit `@export` list, the `GTR_API` declarations in the headers, and the symbols actually exported from the built ELF, Mach-O and wasm files.
2. **The ABI cannot break by accident.**
   - Per-target JSON type manifests are checked in as goldens. They may only grow; a golden is never edited to get past a failure.
   - A libabigail baseline diff runs in CI against a probe library built from the headers.
   - A versioned ELF symbol map (`gtr.map`, one node per minor release), SONAME `libghostty-render.so.<major>`, and the macOS compatibility version.
3. **Headers are clean in every language mode.** They compile under C11, C23 and C++17 with `-Wall -Wextra -Wpedantic -Werror`. A version test ties the version header, the symbol map and the build constant together.
4. **It matches Ghostty.**
   - Ghostty's own tests are ported with their code: `Metrics.zig` tests, and the pixel-exact sprite reference PNGs in `font/sprite/testdata`.
   - Frame plans are checked against goldens produced by feeding recorded byte streams through libghostty-vt `vt-1.0.1`.
   - Colours and runs are checked against Ghostty's rules cell by cell, including the cases herdr's renderer gets wrong: bold colour, `isCovering`, invisible decorations, selection swap, and faint at 0.5.
5. **It holds up under arbitrary input.**
   - An AFL++ harness feeds arbitrary bytes → libghostty-vt → render state → frame plan.
   - The library asserts its own invariants: every span stays inside the grid, runs are ordered and don't overlap, every cluster maps to a cell, and colours are opaque where Ghostty's are.
   - Zig's testing allocator catches leaks.
   - A valgrind step runs from C.
6. **Examples are part of the test suite.** Every `example/*/src/main.c` is built in CI with Zig and CMake, and the docs include code from those examples with `@snippet` so the docs can't rot.

## Stability

We use libghostty-vt's rules word for word, as set out in its `stability.md`:

- **Minor releases** may only add functions, types, enum values, and fields at the end of sized structs.
- **Behaviour changes** ship as new functions. The old function is marked `GTR_DEPRECATED` until the next major release.
- **Versioning:** SemVer, starting at 0.x until the API has had real users. 1.0 freezes the ABI under the rules above.
- **Zig version:** the minimum matches libghostty-vt's (`0.17.0`).
- **libghostty-vt pin:** the dependency is pinned by tag and hash in `build.zig.zon`, starting at `vt-1.0.1`. Moving to a newer `vt-1.x` is a patch release of ours when the headers are ABI-identical. `vt-1.0.2` is.

## When libghostty ships its own renderer

We plan for this from the start:

- **Separate namespace.** Our symbols and headers never clash with `ghostty_*`, so both can be linked into one app and an app can migrate one call site at a time.
- **Public inputs only.** We use only the public render state, so we never depend on anything an official renderer couldn't also see.
- **Ghostty's settings.** Option names, units and defaults are Ghostty's config keys, so settings carry over unchanged.
- **Bindings hide the backend.** Each binding exposes a small backend interface ("frame for this render state at this size"). Switching a binding to an official renderer is a change inside the binding. The GPUI element and the apps built on it don't change.
- **The likely outcomes.** Upstream's renderer is most likely Ghostty's GPU pipeline drawing into a surface (Metal and OpenGL), while this library serves toolkit-native drawing.
  - If upstream also covers toolkit-native drawing, we deprecate.
  - If it covers part of what we do, we wrap it and keep the rest.
  - If it covers none of it, we continue.
- **Migration table.** When upstream publishes an API, `docs/MIGRATION.md` maps each `gtr_*` call to its official equivalent.
- **Retirement policy.** After an official renderer is released:
  - we keep our ABI for at least one full release cycle;
  - we mark superseded functions `GTR_DEPRECATED` with the official replacement named in the message;
  - the bindings gain a build option that routes to the official backend.

## Licensing

Decided 2026-11-24.

| Part | Source | Licence |
|---|---|---|
| Core (Zig): root `LICENSE` | Ported from Ghostty (MIT) | **MIT**, the same as libghostty-vt |
| z2d (dependency, unmodified) | [z2d 0.13.2](https://github.com/vancluever/z2d), as pinned by Ghostty | MPL-2.0 (file-level). We link it unmodified, ship its notice and source location, and never patch it in-tree |
| Rust/GPUI binding: `bindings/rust/LICENSE` | Derived from herdr-app (Apache-2.0); links GPUI (Apache-2.0, Zed Industries) | **Apache-2.0**. Files derived from herdr carry a notice of what changed (§4(b)) |
| Bundled into libghostty-vt | Listed in `licenses/README.md` | Their own; texts in `licenses/` |

The libraries bundled into libghostty-vt `vt-1.0.1` on every target are highway, simdutf, wuffs, uucode, translate-c helpers and Zig's `compiler_rt`/std. `licenses/README.md` records the evidence.

Credits are in `NOTICE` and the README: the herdr team (the technique and the GPUI code), the Ghostty and libghostty team (the terminal and the renderer logic we port), Zed Industries (GPUI) and the z2d author. The core files carry no per-file licence headers, as in Ghostty. `docs/PROVENANCE.md` maps each ported file to its upstream source at a fixed commit.

## Process

How this repository is run, following the libghostty-vt team's practice (see `docs/PLAN.md` for the PR series).

- **Commits**
  - The subject is `area: lowercase summary`, with no trailing period and 72 characters or fewer. Areas: `version`, `metrics`, `renderer`, `frame`, `sprite`, `color`, `abi`, `build`, `ci`, `doxygen`, `docs`, `example`, `fuzz`, `bindings/rust`, `treewide`.
  - Commits are small and do one thing, and they stay as written inside the PR.
  - An optional prose body, wrapped at 72 columns, explains the why, the approach and the cost.
- **PRs**
  - The title follows the commit format, because it becomes the merge subject.
  - The body is 1–3 paragraphs on what changed and why. If the C ABI breaks, it opens with a bold banner, followed by "Breaking changes:" and "Additions:" lists. A C snippet, size impact or reproduction goes in when relevant.
  - Every PR ends with an `**AI usage:**` line naming the tool and what it did.
  - PRs are merged with **merge commits only; squash merging is disabled**. Large features land as a run of sequential PRs.
- **Linters**, all pinned through a Nix flake that uses the nixpkgs and zig-overlay revisions from libghostty-vt `vt-1.0.1`:
  - `zig fmt --check .`
  - `prettier --check .`
  - `alejandra --check .`
  - `typos`
  - `shellcheck --check-sourced --severity=warning`
  - `pinact run --check` (every action pinned by SHA)
  - doxygen with empty stderr
- **CI** on GitHub-hosted runners:
  - lint jobs, gated by paths-filter;
  - `zig build test`;
  - the ABI, schema and symbol checks;
  - a header compile matrix;
  - a cross-build matrix (macOS, Linux and FreeBSD on x86_64 and aarch64; Windows; wasm32);
  - native macOS and Windows link tests;
  - example builds with Zig and CMake;
  - valgrind;
  - a fuzz harness compile check;
  - `distcheck`;
  - Rust binding build and test on all three operating systems.
  
  A single aggregated `required` job gates merges.
- **Releases** come from a `render-X.Y.Z` tag, which must match `build.zig`. Each release produces source and dependency tarballs, minisign signatures, SHA256SUMS and docs.
- **Package registries:** nothing is published to crates.io or any other registry until the owner decides to. Rust crates carry their package metadata but inherit `publish = false` from the workspace, so `cargo publish` refuses. No CI job publishes.
- **Local development** uses `mise` for Zig 0.17.x and Rust. Nix is optional locally and required in CI so linter versions match.
