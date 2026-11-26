/**
 * @file types.h
 *
 * Common macros of libghostty-render, and its type manifest.
 *
 * libghostty-render has no common types of its own. It reuses the ones from
 * libghostty-vt, such as GhosttyResult, GhosttyString and the
 * GHOSTTY_ENUM_TYPED and GHOSTTY_INIT_SIZED macros, by including
 * <ghostty/vt/types.h>.
 */

#ifndef GTR_RENDER_TYPES_H
#define GTR_RENDER_TYPES_H

#include <ghostty/vt/types.h>

// Symbol visibility for shared library builds. On Windows, functions
// are exported from the DLL when building and imported when consuming.
// On other platforms with GCC/Clang, functions are marked with default
// visibility so they remain accessible when the library is built with
// -fvisibility=hidden. For static library builds, define GTR_STATIC
// before including this header to make this a no-op.
#ifndef GTR_API
#if defined(GTR_STATIC)
  #define GTR_API
#elif defined(_WIN32) || defined(_WIN64)
  #ifdef GTR_BUILD_SHARED
    #define GTR_API __declspec(dllexport)
  #else
    #define GTR_API __declspec(dllimport)
  #endif
#elif defined(__GNUC__) && __GNUC__ >= 4
  #define GTR_API __attribute__((visibility("default")))
#else
  #define GTR_API
#endif
#endif

/**
 * Mark a function or type as deprecated.
 *
 * A deprecated declaration still works, but it will be removed in a future
 * major release. Code that uses it gets a compiler warning that includes
 * @p msg, so the message should say what to use instead.
 *
 * Put the macro before GTR_API on the declaration:
 *
 * @code
 * GTR_DEPRECATED("use gtr_foo_new() instead")
 * GTR_API GhosttyResult gtr_foo_create(GtrFoo* out);
 * @endcode
 *
 * The macro uses `__attribute__((deprecated))` on GCC and Clang and
 * `__declspec(deprecated)` on MSVC. On other compilers it does nothing.
 * Define GTR_DEPRECATED yourself before including any libghostty-render
 * header to replace it, for example with an empty definition while you
 * migrate.
 */
#ifndef GTR_DEPRECATED
#if defined(__GNUC__) || defined(__clang__)
  #define GTR_DEPRECATED(msg) __attribute__((deprecated(msg)))
#elif defined(_MSC_VER)
  #define GTR_DEPRECATED(msg) __declspec(deprecated(msg))
#else
  #define GTR_DEPRECATED(msg)
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Get a JSON description of every public type of the library.
 *
 * The manifest describes the C types as this build of the library lays
 * them out for its target: the size and alignment of each type, the
 * offset and type of each struct field, the values of each enum, the
 * value type of each key of a `_get` or `_set` key enum, and the
 * parameters of each callback. It covers libghostty-render's own types
 * and the libghostty-vt types its API uses, such as GhosttyResult.
 *
 * The format is libghostty-vt's, described with ghostty_type_json() in
 * <ghostty/vt/types.h>, with one more field: `library`, which is always
 * "libghostty-render". Language bindings that can't use the C headers,
 * such as WebAssembly hosts, should take offsets, sizes and enum values
 * from the manifest rather than hardcoding them, reject unknown `schema`
 * versions, and check the descriptors they need when they start.
 *
 * Example (abbreviated):
 * @code{.json}
 * {
 *   "library": "libghostty-render",
 *   "schema": 1,
 *   "abi": {
 *     "target": "wasm32", "os": "freestanding", "environment": "none",
 *     "pointer_size": 4, "usize_size": 4, "endian": "little"
 *   },
 *   "library_version": "0.1.0", "commit": null,
 *   "types": {
 *     "GtrBuildInfo": {
 *       "kind": "enum", "size": 4, "align": 4,
 *       "underlying": "i32", "prefix": "GTR_BUILD_INFO_",
 *       "values": { "INVALID": 0, "OPTIMIZE": 1, "MAX_VALUE": 2147483647 },
 *       "keys": {
 *         "OPTIMIZE": { "direction": "out", "type": "GhosttyOptimizeMode" }
 *       }
 *     }
 *   }
 * }
 * @endcode
 *
 * @return Pointer to the null-terminated JSON string. It is never NULL,
 *         is owned by the library, and stays valid for as long as the
 *         library is loaded.
 */
GTR_API const char *gtr_type_json(void);

#ifdef __cplusplus
}
#endif

#endif /* GTR_RENDER_TYPES_H */
