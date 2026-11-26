/**
 * @file types.h
 *
 * Common macros for libghostty-render.
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

#endif /* GTR_RENDER_TYPES_H */
