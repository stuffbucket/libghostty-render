/**
 * @file version.h
 *
 * Version - the version of the libghostty-render headers.
 */

#ifndef GTR_RENDER_VERSION_H
#define GTR_RENDER_VERSION_H

/** @addtogroup gtr_version
 *
 * libghostty-render has two versions you may care about: the version of the
 * headers your program compiled against, and the version of the library it
 * loads when it runs.
 *
 * The macros here describe the headers. gtr_version() and gtr_build_info()
 * report the library. These are usually the same. They can differ when a
 * program compiled against one release runs on a system with another
 * release installed. A library with the same major version works as long as
 * it is at least as new as the headers. While the major version is 0, the
 * minor version must match as well.
 *
 * @{
 */

/** The major version of the libghostty-render headers. */
#define GTR_RENDER_VERSION_MAJOR 0

/** The minor version of the libghostty-render headers. */
#define GTR_RENDER_VERSION_MINOR 1

/** The patch version of the libghostty-render headers. */
#define GTR_RENDER_VERSION_PATCH 0

/**
 * The version of the libghostty-render headers as a string, such as "0.1.0".
 *
 * This is always three numbers separated by dots. It never has a
 * pre-release or build suffix such as "-dev". Use gtr_version() for the
 * full version of the library.
 *
 * Builds made between releases use the number of the release they are
 * working towards. For example, a development build before 0.2.0 sets
 * GTR_RENDER_VERSION to "0.2.0", while gtr_version() returns the full
 * version, such as "0.2.0-dev+abc1234".
 *
 * This header contains only macros and includes no other files, so a build
 * system can also read it directly.
 */
#define GTR_RENDER_VERSION "0.1.0"

/**
 * True if the headers are version maj.min.pat or newer.
 *
 * This works in `#if` directives as well as in regular code:
 *
 * @code
 * #if GTR_RENDER_VERSION_AT_LEAST(0, 2, 0)
 *   // Code that uses functions added in 0.2.0.
 * #endif
 * @endcode
 *
 * @param maj The major version to compare against
 * @param min The minor version to compare against
 * @param pat The patch version to compare against
 */
#define GTR_RENDER_VERSION_AT_LEAST(maj, min, pat)                   \
  (GTR_RENDER_VERSION_MAJOR > (maj) ||                               \
   (GTR_RENDER_VERSION_MAJOR == (maj) &&                             \
    (GTR_RENDER_VERSION_MINOR > (min) ||                             \
     (GTR_RENDER_VERSION_MINOR == (min) &&                           \
      GTR_RENDER_VERSION_PATCH >= (pat)))))

/** @} */

#endif /* GTR_RENDER_VERSION_H */
