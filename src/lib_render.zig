//! The root of the libghostty-render library.
//!
//! The C API lives in `c/`. This file exports it under the `gtr_*` names
//! declared in `include/gtr/render/*.h`. The export list is explicit, so a
//! function is only part of the ABI when it is listed here.

const std = @import("std");

pub const c = @import("c/main.zig");

comptime {}

test {
    std.testing.refAllDecls(@This());
    _ = c;
}
