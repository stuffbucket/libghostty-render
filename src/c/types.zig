//! Zig definitions of the libghostty-vt C types that libghostty-render
//! uses in its own API. libghostty-render's headers include the
//! libghostty-vt headers for these instead of redefining them, so the
//! values here must match those headers exactly.

const std = @import("std");

/// The calling convention of every exported function.
pub const calling_conv: std.lang.CallingConvention = .c;

/// C: GhosttyResult
pub const Result = enum(c_int) {
    success = 0,
    out_of_memory = -1,
    invalid_value = -2,
    out_of_space = -3,
    no_value = -4,
    io_error = -5,
    limit_exceeded = -6,
    rejected = -7,
    unsupported = -8,
};

/// C: GhosttyString
pub const String = extern struct {
    ptr: [*]const u8,
    len: usize,

    pub fn init(s: []const u8) String {
        return .{ .ptr = s.ptr, .len = s.len };
    }

    pub fn slice(self: String) []const u8 {
        return self.ptr[0..self.len];
    }
};

/// C: GhosttyOptimizeMode
pub const OptimizeMode = enum(c_int) {
    debug = 0,
    release_safe = 1,
    release_small = 2,
    release_fast = 3,
};
