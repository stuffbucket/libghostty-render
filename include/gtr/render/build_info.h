/**
 * @file build_info.h
 *
 * Build info - query how libghostty-render was built.
 */

#ifndef GTR_RENDER_BUILD_INFO_H
#define GTR_RENDER_BUILD_INFO_H

/** @addtogroup gtr_build_info
 *
 * Build info is what this copy of the library knows about how it was
 * compiled: its version, its optimization mode, and the version of
 * libghostty-vt it was built against.
 *
 * These values are constant for the lifetime of the process, so you only
 * have to read them once.
 *
 * ## Example
 *
 * @code{.c}
 * size_t major = 0;
 * gtr_build_info(GTR_BUILD_INFO_VERSION_MAJOR, &major);
 * @endcode
 *
 * To check the version of the headers rather than the library, see
 * @ref gtr_version "Version".
 *
 * @{
 */

#include <stddef.h>
#include <stdbool.h>

#include <ghostty/vt/types.h>
#include <ghostty/vt/build_info.h>
#include <gtr/render/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Build info data types that can be queried.
 *
 * Each variant documents the expected output pointer type.
 */
typedef enum GHOSTTY_ENUM_TYPED {
  /** Invalid data type. Never results in any data extraction. */
  GTR_BUILD_INFO_INVALID = 0,

  /**
   * The optimization mode the library was built with.
   *
   * Output type: GhosttyOptimizeMode *
   */
  GTR_BUILD_INFO_OPTIMIZE = 1,

  /**
   * The full version string (e.g. "0.1.0" or "0.1.0-dev+abcdef").
   *
   * Output type: GhosttyString *
   */
  GTR_BUILD_INFO_VERSION_STRING = 2,

  /**
   * The major version number.
   *
   * Output type: size_t *
   */
  GTR_BUILD_INFO_VERSION_MAJOR = 3,

  /**
   * The minor version number.
   *
   * Output type: size_t *
   */
  GTR_BUILD_INFO_VERSION_MINOR = 4,

  /**
   * The patch version number.
   *
   * Output type: size_t *
   */
  GTR_BUILD_INFO_VERSION_PATCH = 5,

  /**
   * The pre metadata string (e.g. "dev"). Has zero length if no pre
   * metadata is present.
   *
   * Output type: GhosttyString *
   */
  GTR_BUILD_INFO_VERSION_PRE = 6,

  /**
   * The build metadata string (e.g. commit hash). Has zero length if no
   * build metadata is present.
   *
   * Output type: GhosttyString *
   */
  GTR_BUILD_INFO_VERSION_BUILD = 7,

  /**
   * The release of the libghostty-vt headers the library was built
   * against, as three numbers separated by dots (e.g. "1.0.1"). This is
   * GHOSTTY_VT_VERSION at build time. The libghostty-vt your program loads
   * reports its own version through ghostty_version().
   *
   * Output type: GhosttyString *
   */
  GTR_BUILD_INFO_VT_VERSION_STRING = 8,

  /**
   * The major version of the libghostty-vt headers the library was built
   * against.
   *
   * Output type: size_t *
   */
  GTR_BUILD_INFO_VT_VERSION_MAJOR = 9,

  /**
   * The minor version of the libghostty-vt headers the library was built
   * against.
   *
   * Output type: size_t *
   */
  GTR_BUILD_INFO_VT_VERSION_MINOR = 10,

  /**
   * The patch version of the libghostty-vt headers the library was built
   * against.
   *
   * Output type: size_t *
   */
  GTR_BUILD_INFO_VT_VERSION_PATCH = 11,
  GTR_BUILD_INFO_MAX_VALUE = GHOSTTY_ENUM_MAX_VALUE,
} GtrBuildInfo;

/**
 * Query a compile-time build configuration value.
 *
 * You must pass a pointer to the correct output type for the requested
 * data (see GtrBuildInfo variants for types).
 *
 * @param data The build info field to query
 * @param out Pointer to store the result (type depends on data parameter)
 * @return GHOSTTY_SUCCESS on success, GHOSTTY_INVALID_VALUE if `data` is
 *         GTR_BUILD_INFO_INVALID or `out` is NULL, or GHOSTTY_UNSUPPORTED
 *         if `data` is not known to this version of the library
 *
 * @ingroup gtr_build_info
 */
GTR_API GhosttyResult gtr_build_info(GtrBuildInfo data, void *out);

/**
 * Get the full version of the library as a string.
 *
 * This is the version of the library your program loaded, which can differ
 * from the GTR_RENDER_VERSION of the headers it was compiled against. See
 * @ref gtr_version "Version" for when that matters.
 *
 * A release returns its version, such as "0.1.0". A development build also
 * has a pre-release and build suffix, such as "0.2.0-dev+abc1234".
 *
 * This returns the same text as GTR_BUILD_INFO_VERSION_STRING, but as a
 * null-terminated string.
 *
 * @code
 * printf("Using libghostty-render %s\n", gtr_version());
 * @endcode
 *
 * @return The version string. It is never NULL, is owned by the library,
 *         and stays valid for as long as the library is loaded. Do not
 *         free it.
 *
 * @ingroup gtr_build_info
 */
GTR_API const char *gtr_version(void);

#ifdef __cplusplus
}
#endif

/** @} */

#endif /* GTR_RENDER_BUILD_INFO_H */
