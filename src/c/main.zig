//! The C API of libghostty-render. Every public function is re-exported
//! here and listed in `lib_render.zig`, which gives it its C name.

pub const types = @import("types.zig");

test {
    _ = types;
}
