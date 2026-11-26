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
- **ABI goldens:** `mise x zig@0.17.1 -- zig build test-abi` (add `-Dtarget=` for
  `x86_64-linux-gnu` or `wasm32-freestanding`)
- **Formatting (Zig):** `mise x zig@0.17.1 -- zig fmt .`
- **Rust:** `mise x rust@1.99.0 zig@0.17.1 -- cargo test --workspace`
- **WebAssembly:** `zig build -Dtarget=wasm32-freestanding -Doptimize=ReleaseSmall`,
  then `node test/wasm/smoke.mjs zig-out/bin/ghostty-render.wasm`
- **Linters:** CI runs `zig fmt --check .`, `prettier --check .`,
  `alejandra --check .`, `typos`, `shellcheck` and `pinact run --check`
  from `nix develop`, at the versions `flake.lock` pins. Without Nix,
  `npx prettier@3.9.6 --check .` and `uvx typos@1.50.2` match them.

The first build fetches Ghostty and its dependencies into `zig-pkg/`, and
building libghostty-vt takes a few minutes.

## Directory Structure

- C headers: `include/gtr/render.h` and `include/gtr/render/<area>.h`
- Zig core: `src/`, with the C API in `src/c/`
- Library root and export list: `src/lib_render.zig`
- WebAssembly root: `src/lib_render_wasm.zig`
- ELF symbol versions: `src/c/gtr-render.map`
- C tests: `test/c/`; wasm smoke test: `test/wasm/`
- ABI: `src/c/types.zig` (type registry and manifest),
  `src/c/abi_test.zig` (header parity), `src/c/abi/` (goldens and their
  checker), `test/abi/` (libabigail)
- CI: `.github/workflows/test.yml`; Nix shell: `flake.nix`, `nix/`
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
  `GHOSTTY_UNSUPPORTED`. A key enum declares `OutType` (or `InType`) so
  the type manifest can describe each key's value.
- Nothing panics across the ABI.
- Every public C struct, union, enum, opaque handle and callback, and every
  libghostty-vt type the API uses, must be registered in `type_decls` in
  `src/c/types.zig`. The parity test in `src/c/abi_test.zig` fails if a
  `Gtr` header type isn't registered or doesn't match its Zig type. Run it
  with `zig build test -Dtest-filter="C header"`.

## ABI Goldens

`src/c/abi/` holds goldens, which are committed records of the ABI: one
type manifest per target, and `symbols.txt`, the sorted list of public
functions. `zig build test-abi` compares the library to them and fails on
anything that could break a program built against an earlier version.
The rules are at the top of `src/c/abi/check.zig`.

- Allowed: a new function, a new type, a new enum value with a new name and
  number, a key type for that new value, and a new field after the end of a
  sized struct.
- Everything else fails, such as removing something or changing a size,
  alignment, offset, field type, enum value or prefix.
- Never update the goldens to get past a failure. A change that isn't an
  addition needs a new minor version before 1.0, and a new major after.

After an intentional addition, update the goldens of every target. All
three can be written from any machine, because the check never runs the
library:

```
zig build update-abi -Dtarget=x86_64-linux-gnu
zig build update-abi -Dtarget=aarch64-macos
zig build update-abi -Dtarget=wasm32-freestanding
```

CI also compares the Linux library with a libabigail baseline; see
`test/abi/README.md`.

## Versioning

The version lives in `build.zig.zon`. `include/gtr/render/version.h` and
`src/c/gtr-render.map` repeat it, and `zig build test` fails when they
disagree. A minor release adds a node to the map for the functions it adds.

## Code Style

- `zig fmt`. No per-file licence headers in the Zig core, as in Ghostty.
- Files derived from herdr-app (Rust only) carry the Apache-2.0 §4(b)
  notice of what changed.

## CI

Every job feeds the `Required Checks: Test` job, the only check a branch
needs to require. When adding a job, add it to that job's `needs`. Pin
every action by commit SHA with its version in a comment; `pinact` fails
otherwise.

## Commits and PRs

- Commit subjects are `area: lowercase summary`, with no trailing period
  and at most 72 characters. Areas are listed in DESIGN.md § Process.
- Every PR body ends with an `**AI usage:**` line.
- Never commit, push, tag, create a GitHub repository, or publish to a
  package registry unless the owner asks.
