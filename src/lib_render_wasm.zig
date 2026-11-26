//! The root of the libghostty-render WebAssembly module.
//!
//! A wasm module can't link another one at run time, so the wasm build is
//! a single module that contains libghostty-vt's C ABI as well as
//! libghostty-render's. build.zig compiles libghostty-vt's C ABI module as
//! a separate object, where it is the root and exports `ghostty_*`, and
//! links it in. This file adds the `gtr_*` exports. libghostty-render
//! still calls only the public C API.
//!
//! The declarations below only take effect in the root module, so they are
//! re-exported from libghostty-vt's root to keep its logging, panic and
//! debug-Io behaviour on wasm.

const vt = @import("ghostty-vt-c");

pub const std_options = vt.std_options;
pub const panic = vt.panic;
pub const std_options_debug_io = vt.std_options_debug_io;

comptime {
    _ = @import("lib_render.zig");
}
