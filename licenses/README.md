# Third-party licences

`libghostty-render-sys` builds libghostty-vt (Ghostty tag `vt-1.0.1`,
commit `108cacb17ed8990840cd14abfce43d8ed8503ca1`) from source and links its
static archive into every program that uses it. That archive contains
Ghostty's code and the third-party code listed below. Each text here was
copied from the pinned source named in the table, not from another
project's copy.

## Statically linked into `libghostty-vt.a`

| Component | Version / commit | Licence | Where the text came from | Files here |
| --- | --- | --- | --- | --- |
| Ghostty (libghostty-vt), including its `src/simd/*.cpp` and the highway/wuffs wrappers in `pkg/` | vt-1.0.1, `108cacb17ed8990840cd14abfce43d8ed8503ca1` | MIT | `vendor/ghostty/LICENSE` | `ghostty-LICENSE-MIT` |
| [Highway](https://github.com/google/highway) (SIMD dispatch; Ghostty also vendors `hwy/targets.cc`, `per_target.cc`, `abort.cc` into `pkg/highway/src/cpp`) | 1.2.0, `66486a10623fa0d72fe91260f96c892e41aceb06` (Zig package `N-V-__8AAGmZhABbsPJLfbqrh6JTHsXhY6qCaLAQyx25e0XE`) | Apache-2.0 OR BSD-3-Clause | `LICENSE`, `LICENSE-BSD3` of the fetched package | `highway-LICENSE-APACHE`, `highway-LICENSE-BSD3` |
| [simdutf](https://github.com/simdutf/simdutf) (amalgamated, vendored in Ghostty's `pkg/simdutf/vendor`) | 9.0.0 (`SIMDUTF_VERSION` in `simdutf.h`) | Apache-2.0 OR MIT | `pkg/simdutf/vendor/LICENSE-APACHE`, `LICENSE-MIT` | `simdutf-LICENSE-APACHE`, `simdutf-LICENSE-MIT` |
| simdutf's CPU detection, derived from PyTorch's TH library | as above | BSD-3-Clause | the notice embedded in `pkg/simdutf/vendor/simdutf.h` (lines 967–1010) | `simdutf-NOTICE-TH` |
| [Wuffs](https://github.com/google/wuffs) (`release/c/wuffs-v0.4.c`: pixel format conversion for Kitty graphics) | 0.4.0-alpha.10, `7411f488fe2e2c205c3d3b3d28638b7356522930` (Zig package `N-V-__8AAP5JWgCGP_AD0teWpa4krRvE9VPZzvviGdbmN4jI`) | Apache-2.0 OR MIT | `LICENSE`, `LICENSE-APACHE`, `LICENSE-MIT` of the fetched package | `wuffs-LICENSE`, `wuffs-LICENSE-APACHE`, `wuffs-LICENSE-MIT` |
| [uucode](https://github.com/jacobsandlund/uucode) (Unicode tables for grapheme breaking and widths, generated from the Unicode Character Database 18.0.0; Björn Höhrmann's UTF-8 decoder) | 0.2.0, `1fb73433bba5d93366c57f23ff2e9d7939746500` (Zig package `uucode-0.2.0-ZZjBPm6FVgBcY-79AHV8ckQj86z0JwOyVyj89VeZrEiv`) | MIT AND Unicode-3.0 (decoder: MIT-style) | `LICENSE.md` of the fetched package; its `licenses/LICENSE_Bjoern_Hoehrmann` and `licenses/LICENSE_unicode` are missing from the tarball Ghostty fetches, so they were taken from the upstream repository at the same commit (`raw.githubusercontent.com/jacobsandlund/uucode/1fb73433…/licenses/`) | `uucode-LICENSE.md`, `uucode-LICENSE_Bjoern_Hoehrmann`, `uucode-LICENSE_unicode` |
| [translate-c](https://github.com/ziglang/translate-c) helpers (`lib/c_builtins.zig`, `lib/helpers.zig`, reachable from every translated C header) | 2.0.0, `02ff0c523fb92a38939b04d0145c4a9602a74d56` | MIT | `LICENSE` of the fetched package | `translate_c-LICENSE-MIT` |
| [Zig](https://ziglang.org) standard library and compiler runtime (`compiler_rt.o` is bundled into the archive) | 0.17.1 | MIT | `LICENSE` of the Zig 0.17.1 distribution | `zig-LICENSE-MIT` |
| musl-derived routines in Zig's compiler runtime (math functions such as `sin`, `cos`, `log2`, `round`) | as shipped with Zig 0.17.1 | MIT | `lib/libc/musl/COPYRIGHT` of the Zig 0.17.1 distribution | `musl-COPYRIGHT` |

Zig's compiler runtime also contains code ported from LLVM's compiler-rt
(Apache-2.0 WITH LLVM-exception). The LLVM exception waives the notice
requirements for code embedded in compiled output, so no separate text is
needed.

Not linked: the `pixels` test images in Ghostty's `pkg/wuffs` (never fetched
for this build), libpng/zlib/oniguruma/freetype/harfbuzz and the other
`pkg/` libraries of Ghostty's desktop app, Zig's ubsan runtime (not bundled
in ReleaseFast builds; Ghostty also disables it on Windows), and any libc:
macOS links libSystem and Linux links glibc dynamically; Windows uses the
MSVC runtime.

## Evidence

1. **Ghostty's own report.** vt-1.0.1 has a `lib-vt-packages` build step
   (`src/build/LibVtPackages.zig`) that walks libghostty-vt's module graph
   and lists, per package, the files compiled into the library. Run for all
   six supported targets:

   ```sh
   cd vendor/ghostty
   for t in aarch64-macos x86_64-macos x86_64-linux-gnu aarch64-linux-gnu \
            x86_64-windows-msvc aarch64-windows-msvc; do
     zig build lib-vt-packages -Demit-lib-vt -Demit-xcframework=false \
       -Doptimize=ReleaseFast -Dtarget=$t --prefix /tmp/report-$t
   done
   ```

   Every target reported the same packages with linked files: Ghostty
   itself (`src/lib_vt.zig`, `src/simd/{base64,codepoint_width,index_of,vt}.cpp`),
   highway (upstream package and `pkg/highway`), `pkg/simdutf`
   (`vendor/simdutf.cpp`), wuffs (`release/c/wuffs-v0.4.c`) and `pkg/wuffs`,
   translate_c (`lib/c_builtins.zig`, `lib/helpers.zig`) and uucode
   (`src/root.zig`, `types.zig`, `config.zig`, `storage.zig`). Ghostty
   publishes the same list in `deps/libghostty-vt-third-party.json`.

2. **The archive.** `ar t libghostty-vt.a` (aarch64-macos, ReleaseFast)
   lists `ghostty-vt-static_zcu.o` (Zig code: Ghostty, uucode, translate-c
   helpers, Zig std), `compiler_rt.o`, `highway_zcu.o`, `targets.o`,
   `per_target.o`, `abort.o` (highway), `simdutf.o`, `wuffs-v0.4.o`, and
   `base64.o`, `codepoint_width.o`, `index_of.o`, `vt.o` (Ghostty's SIMD
   C++).

3. **The build scripts.** `src/build/GhosttyLibVt.zig` sets
   `bundle_compiler_rt = true` for the static library (and
   `bundle_ubsan_rt`, turned off on Windows) and combines the SIMD archives
   into it; `src/build/GhosttyZig.zig` imports `uucode`, imports `wuffs`
   when Kitty graphics are enabled, and adds highway and simdutf when SIMD
   is enabled. Vendored C++ is built with `HWY_NO_LIBCXX`/`SIMDUTF_NO_LIBCXX`,
   so no C++ standard library is linked. `ghostty_build_info` in the linked
   library reports SIMD and Kitty graphics as enabled (checked by
   `tests/library.rs`).

## This project's own dependencies

| Component | Licence | Files here |
| --- | --- | --- |
| [herdr-app](https://github.com/herdrdev/herdr-app) at `a2e8e3f` (build script approach and test cases; see `docs/PROVENANCE.md`) | Apache-2.0 | `herdr-app-LICENSE-APACHE` |
| [GPUI](https://github.com/zed-industries/zed) (for the planned GPUI binding; not used by the current code) | Apache-2.0 | `gpui-LICENSE-APACHE` |

Build-time only, not linked: bindgen and its dependencies (BSD-3-Clause,
MIT, Apache-2.0), and the Zig compiler itself.
