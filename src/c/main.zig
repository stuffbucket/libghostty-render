//! The C API of libghostty-render. Every public function is re-exported
//! here and listed in `lib_render.zig`, which gives it its C name.

const build_info_c = @import("build_info.zig");

pub const types = @import("types.zig");

pub const build_info = build_info_c.get;
pub const version = build_info_c.version;
pub const type_json = types.get_json;

test {
    _ = build_info_c;
    _ = types;
}
