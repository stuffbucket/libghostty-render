# Provenance

libghostty-render is a derivative work. This file records what came from
where, so the Apache-2.0 §4(b) notices in each file can be checked.

## Upstream pins

| Upstream | Version | Commit | Licence |
| --- | --- | --- | --- |
| [herdr-app](https://github.com/herdrdev/herdr-app) | — | `a2e8e3ffa84439d4a245a1e6aa8947ef0dd20a1b` | Apache-2.0 |
| [Ghostty / libghostty-vt](https://github.com/ghostty-org/ghostty) | tag `vt-1.0.1` (libghostty-vt 1.0.1) | `108cacb17ed8990840cd14abfce43d8ed8503ca1` | MIT |
| Zig toolchain used to build libghostty-vt | 0.17.1 (vt-1.0.1 requires ≥ 0.17.0) | — | MIT |

Ghostty is the `vendor/ghostty` git submodule, a shallow checkout of the
commit above. `GHOSTTY_SOURCE_DIR` can point the build at another checkout.

`vt-1.0.2` (tagged 2026-11-24, commit `573c4a21e02311ae87844af26b6a7a179f82858e`)
has the same public headers as vt-1.0.1 apart from the version macros. Moving
to it means checking out that commit in the submodule and updating
`GHOSTTY_TAG`/`GHOSTTY_COMMIT` in `crates/libghostty-render-sys/src/lib.rs`
and the version test.

## Files derived from herdr-app

Each file below starts with a one-line notice naming its herdr source and
summarising the changes.

| Our file | herdr-app source | Changes |
| --- | --- | --- |
| `crates/libghostty-render-sys/build.rs` | `crates/ghostty-sys/build.rs` (lines 1–96, all) | Ghostty source from `GHOSTTY_SOURCE_DIR` or `vendor/ghostty` with a clear error when missing; Zig ≥ 0.17.0 for vt-1.0.1; rerun on `pkg/` changes; `-DGHOSTTY_STATIC`; headers parsed as C23 (`-std=c2x`) so every enum is `int`/`i32` on all targets; Windows links `ntdll`/`kernel32`; macros bindgen can't evaluate are blocklisted and hand-defined; `DEP_GHOSTTY_VT_INCLUDE` exported. Target mapping, separate `--prefix`/`--cache-dir` under `OUT_DIR`, static-archive-only search path and the libclang/SDK header handling are herdr's. |
| `crates/libghostty-render-sys/src/lib.rs` | `crates/ghostty-sys/src/lib.rs` (lines 1–3, all) | Crate docs; hand-written equivalents of `GHOSTTY_STYLE_FLAG_*`, `GHOSTTY_STYLE_UNDERLINE_{SHIFT,MASK}`/`GHOSTTY_STYLE_UNDERLINE()`, `ghostty_mode_new/value/ansi` and all `GHOSTTY_MODE_*`, `GHOSTTY_IMAGE_LAYER_MASK_*`, the palette-mask macros and `GHOSTTY_INIT_SIZED` (as `ghostty_init_sized!`); pin constants. |
| `crates/libghostty-render-sys/Cargo.toml` | `crates/ghostty-sys/Cargo.toml` | Renamed; `links = "ghostty-vt"` and the bindgen 0.72 build dependency kept; publishing metadata added. |
| `crates/libghostty-render-sys/tests/library.rs` | `src/vt.rs` tests, lines 2352–2360 (keys), 2408–2418 (mouse), 2117–2148 (search), 2068–2105 and 2532–2542 (selection text), 2643–2681 (underline styles) | Rewritten against the raw C API. Inputs and expected bytes are herdr's; version, mode packing, codepoint buffer, render-state image iterator, layer mask and palette mask tests are new. |

Nothing else in the repository is derived from herdr-app. The GPUI
component, frame model and painting that were planned as further ports
(herdr `src/vt.rs`, `src/terminal.rs`, `src/sprites.rs`) were not written:
the renderer is being re-designed as a C-ABI library (see `DESIGN.md`).

## libghostty-vt API changes since herdr's Ghostty pin

herdr pins Ghostty `291fd050b`, 590 commits before vt-1.0.1. Anyone porting
code written against that pin (as herdr's `src/vt.rs`) to vt-1.0.1 meets the
changes below. Each was checked in the vt-1.0.1 headers; the ones marked ✓
are exercised by `crates/libghostty-render-sys/tests/library.rs`.

| Area | herdr's pin | vt-1.0.1 |
| --- | --- | --- |
| Key encoder options ✓ | `ghostty_key_encoder_setopt[_from_terminal]` | `ghostty_key_encoder_set` / `ghostty_key_encoder_set_from_terminal` (key/encoder.h:197, 219; the latter returns `GhosttyResult`) |
| Mouse encoder options ✓ | `ghostty_mouse_encoder_setopt[_from_terminal]` | `ghostty_mouse_encoder_set` / `_set_from_terminal` (mouse/encoder.h:190, 209) |
| Key event text ✓ | `ghostty_key_event_set_utf8(ev, ptr, len)` | `ghostty_key_event_set_utf8(ev, GhosttyString)` (key/event.h:490) |
| Kitty image data ✓ | `GHOSTTY_KITTY_IMAGE_DATA_*`, `DATA_PTR` + `DATA_LEN` | `GHOSTTY_KITTY_GRAPHICS_IMAGE_DATA_*`; one `..._PIXELS` returning `GhosttyString`, `GHOSTTY_NO_VALUE` until loaded (kitty_graphics.h:296–394) |
| Kitty placements ✓ | Embedder iterates storage placements and decodes U+10EEEE placeholders itself | Render state lists every placement, virtual ones included, already in viewport cells and pixels: `GHOSTTY_RENDER_STATE_DATA_IMAGE_ITERATOR`, `ghostty_render_state_image_iterator_*`, `ghostty_render_state_image_get[_multi]`, `GHOSTTY_RENDER_STATE_DATA_IMAGE_PLACEMENTS_GENERATION`; placements carry a `GhosttyImageLayer` to draw them in |
| Cursor style ✓ | `GHOSTTY_RENDER_STATE_CURSOR_VISUAL_STYLE_*` | `GHOSTTY_CURSOR_STYLE_*` (types.h:357–366); `BAR = 0`, so a zeroed cursor reads as a bar |
| Viewport scrolling | `GHOSTTY_SCROLL_VIEWPORT_*` | `GHOSTTY_TERMINAL_SCROLL_VIEWPORT_*` (terminal.h:101–122) |
| Search navigation ✓ | `ghostty_search_set(s, GHOSTTY_SEARCH_OPT_SELECT_NEXT/PREV, NULL)` | `ghostty_search_select_next/prev(s)` (search.h:356, 374); scrolling to the match is `GHOSTTY_SEARCH_OPT_SELECT_SCROLL` |
| Selection text ✓ | `ghostty_terminal_selection_format_alloc` | Formatter: `ghostty_formatter_terminal_new`, `ghostty_formatter_set` (`EMIT`, `UNWRAP`, `TRIM`, `SELECTION`), `ghostty_formatter_format_alloc`, `ghostty_formatter_free` (formatter.h:234–403), with the selection read from `GHOSTTY_TERMINAL_DATA_SELECTION` |
| Sized structs ✓ | `size` on `GhosttyGridRef`, `GhosttySelection`, `GhosttyStyle`, `GhosttyClipboardWrite` | None of the four has one (grid_ref.h:100, selection.h:118, style.h:226, terminal.h:873) |
| Style ✓ | `bold`, `italic`, … bools and `underline` int | `flags: u16` (`GHOSTTY_STYLE_FLAG_*`, underline in bits 8–10); `GhosttyStyleColor.tag` is `u8` |
| Clipboard locations | `PRIMARY = 1` | `SELECTION = 1`, `PRIMARY = 2` |
| Graphemes ✓ | `GRAPHEMES_BUF` filled a bare `uint32_t*` | `GRAPHEMES_BUF` takes `GhosttyCodepointBuffer{ptr,cap,len}` (render.h:1034); passing a bare array compiles and corrupts memory. `GRAPHEMES_UTF8` (`GhosttyBuffer`) is the alternative |
| Enums | — | Every enum has a `*_MAX_VALUE = INT_MAX` sentinel |

Further differences found while porting, not in the list above:

- **Modes are packed.** `GhosttyMode` is the mode number in bits 0–14 plus
  an ANSI flag in bit 15 (modes.h:115). DEC private modes (2004, 2026,
  2027, …) keep their plain numbers, so herdr's constants still work, but an
  ANSI mode such as insert (4) must be `4 | 0x8000`; plain `4` is DEC slow
  scroll. The `GHOSTTY_MODE_*` constants and `ghostty_mode_new` are macros
  and `static inline` functions, so bindgen emits none of them.
- **Grapheme clustering is off by default.** Without mode 2027 a ZWJ emoji
  sequence splits into several cells. herdr sets it through
  `GHOSTTY_TERMINAL_OPT_MODE_DEFAULT`, which survives a reset.
- **The formatter formats the whole screen when it has no selection.**
  `ghostty_terminal_selection_format_alloc` returned nothing without a
  selection; a port must check `GHOSTTY_TERMINAL_DATA_SELECTION` (which
  returns `GHOSTTY_NO_VALUE`) before formatting.
- **`GhosttyGridRef.x`/`.y` are page-internal.** The header now says they
  are not screen coordinates and are read-only (grid_ref.h:85–100). herdr's
  link scanner walks a row by writing `r.x = x`; that happens to work
  because a row never spans pages horizontally, but a port should take a
  fresh grid ref per cell.
- **`ghostty_grid_ref_graphemes` leaves the buffer untouched on
  `GHOSTTY_OUT_OF_SPACE`.** herdr's link scanner reads the first 16 entries
  of its buffer whatever the result; for a cluster longer than 16 code
  points it reads zeros. Retry with `out_written` entries instead.
- **Enum types differ by platform unless the headers are parsed as C23.**
  `GHOSTTY_ENUM_TYPED` is `: int` only under C23/C++11. Parsed as C17,
  bindgen makes enums `u32` on Unix and `i32` on MSVC (herdr's
  "C enums are int on Linux and unsigned on macOS" workaround). This crate
  passes `-std=c2x`, so they are `i32` everywhere.
- **Kitty image placements default to `GHOSTTY_IMAGE_LAYER_ABOVE_TEXT`.** A
  placement with z-index 0 is drawn above text; virtual placements are
  always below text (z = -1). The image storage limit defaults to 10 MB;
  0 disables the protocol.
- **`ghostty_version()`** returns a C string, and `ghostty_build_info()`
  reports the version numbers as `size_t`.

## Build and static archive

`build.rs` runs `zig build -Demit-lib-vt -Demit-xcframework=false
-Doptimize=ReleaseFast -Dtarget=<target>` in the Ghostty source with
`--prefix`/`--cache-dir` under `OUT_DIR`, and links only the static archive
(`libghostty-vt.a`, or `ghostty-vt-static.lib` on Windows, copied to
`ghostty-vt.lib`). Zig 0.17 stores the dependencies it fetches in `zig-pkg/`
inside the Ghostty source; Ghostty's `.gitignore` covers it.

What the archive contains, and the evidence, is in
[`licenses/README.md`](../licenses/README.md).

## GPUI

The planned GPUI component (a stock `gpui-pre` 0.3.x dependency replacing
herdr's fork-only `ShapedLine::with_cell_positions`, `TextSystem::font_metrics`
/ `font_table` and `option_as_alt`) was not written; see `DESIGN.md`. No GPUI
code is in the repository. `licenses/gpui-LICENSE-APACHE` and the GPUI
section of `NOTICE` remain for that future binding.
