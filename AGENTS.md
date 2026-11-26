# Agent Development Guide

A file for [guiding coding agents](https://agents.md/). Read
[`docs/DESIGN.md`](docs/DESIGN.md) and [`docs/PLAN.md`](docs/PLAN.md) first;
they are the source of truth for what this library is and the order work
lands in.

## Commands

Zig and Rust come from `mise.toml`. There is no global default, so run
them through mise:

- **Build:** `mise x zig@0.17.1 -- zig build`
- **Test (Zig and C):** `mise x zig@0.17.1 -- zig build test`
- **Test filter:** `mise x zig@0.17.1 -- zig build test -Dtest-filter=<test name>`
- **Formatting (Zig):** `mise x zig@0.17.1 -- zig fmt .`
- **Rust:** `mise x rust@1.99.0 zig@0.17.1 -- cargo test --workspace`

The first build fetches Ghostty and its dependencies into `zig-pkg/`, and
building libghostty-vt takes a few minutes.

## Directory Structure

- C headers: `include/gtr/render.h` and `include/gtr/render/<area>.h`
- Zig core: `src/`, with the C API in `src/c/`
- Library root and export list: `src/lib_render.zig`
- ELF symbol versions: `src/c/gtr-render.map`
- C tests: `test/c/`
- Rust binding: `crates/` (moves to `bindings/rust/`)

## C API

The C API follows libghostty-vt's conventions exactly. Ghostty's
`src/terminal/c/AGENTS.md` and `dist/doxygen/pages/conventions.md` at tag
`vt-1.0.1` are the reference.

- Names use the `gtr` root: `gtr_<area>_<verb>`, `Gtr<Type>`,
  `GTR_<AREA>_<NAME>`, headers under `<gtr/render/...>` with guards
  `GTR_RENDER_<AREA>_H`. Never export a `ghostty_` symbol.
- Reuse libghostty-vt's shared types (`GhosttyResult`, `GhosttyAllocator`,
  `GhosttyString`, `GHOSTTY_ENUM_TYPED`, `GHOSTTY_INIT_SIZED`, ...) by
  including its headers. Never redefine them.
- Use only libghostty-vt's public C API. Never import its Zig module.
- Every function must be wired all the way through:
  1. Define it in `src/c/<area>.zig` with `callconv(types.calling_conv)`.
  2. Re-export it via a `pub const` in `src/c/main.zig`.
  3. Add an `@export` call in `src/lib_render.zig` with the `gtr_` name.
  4. Declare it with `GTR_API` in `include/gtr/render/<area>.h`.
- All C enums must end in `_MAX_VALUE = GHOSTTY_ENUM_MAX_VALUE`. Get/set
  keys start at `_INVALID = 0`, and unknown keys return
  `GHOSTTY_UNSUPPORTED`.
- Nothing panics across the ABI.

## Versioning

The version lives in `build.zig.zon`. `include/gtr/render/version.h` and
`src/c/gtr-render.map` repeat it, and `zig build test` fails when they
disagree. A minor release adds a node to the map for the functions it adds.

## Code Style

- `zig fmt`. No per-file licence headers in the Zig core, as in Ghostty.
- Files derived from herdr-app (Rust only) carry the Apache-2.0 §4(b)
  notice of what changed.

## Commits and PRs

- Commit subjects are `area: lowercase summary`, with no trailing period
  and at most 72 characters. Areas are listed in DESIGN.md § Process.
- Every PR body ends with an `**AI usage:**` line.
- Never commit, push, tag, create a GitHub repository, or publish to a
  package registry unless the owner asks.
