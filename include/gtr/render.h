/**
 * @file render.h
 *
 * libghostty-render - a toolkit-neutral terminal renderer for libghostty-vt.
 *
 * This is the umbrella header. It includes every public header of
 * libghostty-render, and the libghostty-vt headers they build on.
 *
 * libghostty-render turns a libghostty-vt render state into a frame plan:
 * everything an application needs to draw a terminal with its own UI
 * toolkit so that the result looks like Ghostty. The application does
 * fonts, shaping, rasterising and drawing.
 *
 * libghostty-render follows the conventions of libghostty-vt, and reuses
 * its shared types such as GhosttyResult, GhosttyAllocator and
 * GhosttyString rather than defining its own.
 *
 * Define GTR_STATIC before including this header when linking the static
 * library. The libghostty-vt headers it includes need GHOSTTY_STATIC as
 * well when libghostty-vt is linked statically.
 */

#ifndef GTR_RENDER_H
#define GTR_RENDER_H

#include <gtr/render/version.h>
#include <gtr/render/types.h>
#include <gtr/render/build_info.h>

#endif /* GTR_RENDER_H */
