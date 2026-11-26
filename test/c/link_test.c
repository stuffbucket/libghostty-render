/*
 * Links a C program against libghostty-render and libghostty-vt through
 * the installed headers, and checks that the library and the headers agree
 * on the version. build.zig builds this once against the shared libraries
 * and once against the static ones (with GTR_STATIC and GHOSTTY_STATIC).
 */

#include <stdio.h>
#include <string.h>

#include <ghostty/vt.h>
#include <gtr/render.h>

#define CHECK(cond)                                                     \
  do {                                                                  \
    if (!(cond)) {                                                      \
      fprintf(stderr, "%s:%d: check failed: %s\n", __FILE__, __LINE__, \
              #cond);                                                   \
      return 1;                                                         \
    }                                                                   \
  } while (0)

static int check_size(GtrBuildInfo key, size_t expected) {
  size_t value = (size_t)-1;
  if (gtr_build_info(key, &value) != GHOSTTY_SUCCESS) return 0;
  return value == expected;
}

int main(void) {
  /* The library is the release the headers describe. */
  CHECK(check_size(GTR_BUILD_INFO_VERSION_MAJOR, GTR_RENDER_VERSION_MAJOR));
  CHECK(check_size(GTR_BUILD_INFO_VERSION_MINOR, GTR_RENDER_VERSION_MINOR));
  CHECK(check_size(GTR_BUILD_INFO_VERSION_PATCH, GTR_RENDER_VERSION_PATCH));

  const char* version = gtr_version();
  CHECK(version != NULL);
  CHECK(strncmp(version, GTR_RENDER_VERSION, strlen(GTR_RENDER_VERSION)) == 0);

  GhosttyString string = {0};
  CHECK(gtr_build_info(GTR_BUILD_INFO_VERSION_STRING, &string) ==
        GHOSTTY_SUCCESS);
  CHECK(string.len == strlen(version));
  CHECK(memcmp(string.ptr, version, string.len) == 0);

  /* It was built against the libghostty-vt headers this program sees. */
  CHECK(check_size(GTR_BUILD_INFO_VT_VERSION_MAJOR, GHOSTTY_VT_VERSION_MAJOR));
  CHECK(check_size(GTR_BUILD_INFO_VT_VERSION_MINOR, GHOSTTY_VT_VERSION_MINOR));
  CHECK(check_size(GTR_BUILD_INFO_VT_VERSION_PATCH, GHOSTTY_VT_VERSION_PATCH));
  CHECK(gtr_build_info(GTR_BUILD_INFO_VT_VERSION_STRING, &string) ==
        GHOSTTY_SUCCESS);
  CHECK(string.len == strlen(GHOSTTY_VT_VERSION));
  CHECK(memcmp(string.ptr, GHOSTTY_VT_VERSION, string.len) == 0);

  GhosttyOptimizeMode mode = GHOSTTY_OPTIMIZE_MODE_MAX_VALUE;
  CHECK(gtr_build_info(GTR_BUILD_INFO_OPTIMIZE, &mode) == GHOSTTY_SUCCESS);
  CHECK(mode >= GHOSTTY_OPTIMIZE_DEBUG && mode <= GHOSTTY_OPTIMIZE_RELEASE_FAST);

  /* Errors follow libghostty-vt's rules. */
  CHECK(gtr_build_info(GTR_BUILD_INFO_INVALID, &string) ==
        GHOSTTY_INVALID_VALUE);
  CHECK(gtr_build_info(GTR_BUILD_INFO_VERSION_MAJOR, NULL) ==
        GHOSTTY_INVALID_VALUE);
  CHECK(gtr_build_info((GtrBuildInfo)9999, &string) == GHOSTTY_UNSUPPORTED);

  /* And libghostty-vt itself is linked and callable. */
  size_t vt_major = 0;
  CHECK(ghostty_build_info(GHOSTTY_BUILD_INFO_VERSION_MAJOR, &vt_major) ==
        GHOSTTY_SUCCESS);
  CHECK(vt_major == GHOSTTY_VT_VERSION_MAJOR);

  printf("libghostty-render %s on libghostty-vt %s\n", version,
         ghostty_version());
  return 0;
}
