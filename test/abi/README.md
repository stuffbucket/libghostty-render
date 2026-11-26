# libghostty-render ABI Checks

This directory contains the tooling that checks the ABI of
libghostty-render in CI, ported from libghostty-vt's `test/abi`. For every
change, we compare the ABI of the Linux x86_64 shared library against a
baseline committed here, using
[libabigail](https://sourceware.org/libabigail/). The check runs as the
`abi-check` job in `.github/workflows/test.yml`. A second check,
`zig build test-abi`, covers what this one can't, such as macOS and
WebAssembly. It compares the library to the manifest goldens and symbol
list in `src/c/abi/`.

The goal is that a change never breaks the ABI by accident. If a change
would break programs already built against libghostty-render, CI fails and
shows what changed. If the break is intentional, the same change updates
the baseline, so the break is visible in review.

| File                      | Purpose                                                       |
| ------------------------- | ------------------------------------------------------------- |
| `check.sh`                | Dumps the ABI of a build, or compares a build to a baseline.  |
| `libghostty-render.suppr` | Suppressions for changes we know are compatible. Empty today. |
| `baseline.abi`            | The baseline ABI.                                             |
| `baseline.txt`            | The commit and version the baseline was dumped from.          |

## What Fails the Check

The baseline is the ABI as of the last release or the last intentional
break. Any change from the baseline that could break an existing program
fails the check. For example:

- Removing a function, or changing its parameters or return type.
- Adding, removing, resizing or reordering a struct member.
- Changing the value of an enum constant.

Additions pass, because no existing program uses them yet:

- A new function.
- A new type.
- A new enum constant.
- A new member at the end of a sized struct, one whose first member is
  `size_t size` (see `GHOSTTY_INIT_SIZED` in `<ghostty/vt/types.h>`).

The ABI includes the libghostty-vt types that libghostty-render's API
uses, such as `GhosttyResult` and `GhosttyString`, so a libghostty-vt
update that changes them fails here too.

The check also reads the library itself, because libabigail can't see
these two things. It fails if:

- The SONAME isn't `libghostty-render.so.<major>`, with the major version
  in `build.zig.zon`.
- The symbol version nodes the library defines aren't exactly the nodes
  `src/c/gtr-render.map` declares.

## Breaking the ABI on Purpose

Before 1.0, a minor release may break the ABI; from 1.0, only a major
release may (see `docs/DESIGN.md`). A pull request that breaks the ABI on
purpose must update `baseline.abi` and `baseline.txt` in the same pull
request. The diff of the baseline is how reviewers see the break.

## Updating the Baseline

Every run of the `abi-check` job uploads an artifact named
`libghostty-render-abi`. It contains a `baseline.abi` and `baseline.txt`
for the commit the job ran on. Artifacts expire after a week. To update
the baseline:

1. Find the `abi-check` job for the commit you want as the baseline. For
   a release, this is the Test run of the `render-X.Y.Z` tag. For an
   intentional break, this is the latest commit of the pull request.
2. Download its `libghostty-render-abi` artifact.
3. Copy `baseline.abi` and `baseline.txt` into this directory. For a
   release, add a `tag: render-X.Y.Z` line to `baseline.txt`.
4. Commit them.

Please use the artifact rather than a dump from your own machine. A dump
made with a different compiler or C library can differ from CI's in ways
that don't matter, and those differences make the baseline diff hard to
review.

## Running the Check Locally

libabigail only reads ELF files, so the check only runs on Linux. From
the root of the repository, build with the same options CI uses, then
compare the build to the baseline:

```sh
nix develop -c zig build -Doptimize=ReleaseFast -Dcpu=baseline
nix develop -c test/abi/check.sh diff test/abi/baseline.abi zig-out/lib/libghostty-render.so
```

`diff` exits with 0 if the ABI matches the baseline or only grew and the
SONAME and version nodes are right, and with 1 if not or if something
went wrong. To write the ABI of a build to a file instead, use `dump`:

```sh
nix develop -c test/abi/check.sh dump zig-out/lib/libghostty-render.so /tmp/libghostty-render.abi
```

`check.sh` reads two optional environment variables:

- `CC`: the C compiler that builds the probe library described below.
  Defaults to `cc`.
- `GTR_ABI_INCLUDE`: the directory with the public headers, ours and
  libghostty-vt's. Defaults to `zig-out/include`, where `zig build`
  installs both.

## How It Works

libabigail normally reads the ABI of a library from its debug info. That
doesn't work for a Zig library, because Zig writes the debug info of
exported functions under their Zig names and doesn't mark them as
external, so libabigail treats every one of them as private.

Instead, `check.sh` builds a small "probe" library from the public
headers. For each function that the library exports and the headers
declare with `GTR_API`, the probe holds one pointer with the type the
header gives it:

```c
#include <gtr/render.h>

__typeof__(gtr_build_info) *const abi_gtr_build_info = &gtr_build_info;
__typeof__(gtr_version) *const abi_gtr_version = &gtr_version;
// ...and so on for every function.
```

The probe is compiled with debug info for every type in the headers,
links against the library and takes the library's SONAME. The ABI of the
probe is the ABI that programs compile against, and that is what we dump
and compare. This is why libabigail reports show functions as `abi_*`
variables.

The dump also makes sure that no function slips past the check. It fails
if the library exports a `gtr_*` function that the headers don't
declare, or if a function is missing from the dump.
