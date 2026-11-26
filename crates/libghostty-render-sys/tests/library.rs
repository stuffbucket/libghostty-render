// Derived from herdr-app src/vt.rs tests (https://github.com/herdrdev/herdr-app, commit a2e8e3f, Apache-2.0). Modified by the libghostty-render authors: rewritten against the raw vt-1.0.1 C API; inputs and expectations of the key, mouse, search, selection and style tests come from herdr's, the version, mode, codepoint-buffer, image-iterator and macro tests are new.

//! Checks the linked library and the hand-written parts of the bindings
//! (macros and `static inline` helpers bindgen cannot emit) against
//! libghostty-vt's behaviour, and exercises the vt-1.0.1 API changes that
//! callers ported from older Ghostty pins trip over.

use libghostty_render_sys::*;
use std::ffi::{CStr, c_void};
use std::ptr::{null, null_mut};

struct Term(GhosttyTerminal);

impl Term {
    fn new(cols: u16, rows: u16) -> Term {
        let mut t = null_mut();
        assert_eq!(
            unsafe { ghostty_terminal_new(null(), &mut t, cols, rows) },
            GHOSTTY_SUCCESS
        );
        Term(t)
    }

    fn write(&self, bytes: &[u8]) {
        unsafe { ghostty_terminal_vt_write(self.0, bytes.as_ptr(), bytes.len()) };
    }

    fn grid_ref(&self, x: u16, y: u32) -> GhosttyGridRef {
        let mut p = GhosttyPoint {
            tag: GHOSTTY_POINT_TAG_ACTIVE,
            ..Default::default()
        };
        p.value.coordinate = GhosttyPointCoordinate { x, y };
        let mut r = GhosttyGridRef::default();
        assert_eq!(
            unsafe { ghostty_terminal_grid_ref(self.0, p, &mut r) },
            GHOSTTY_SUCCESS
        );
        r
    }

    fn style(&self, x: u16, y: u32) -> GhosttyStyle {
        let mut s = GhosttyStyle::default();
        assert_eq!(
            unsafe { ghostty_grid_ref_style(&self.grid_ref(x, y), &mut s) },
            GHOSTTY_SUCCESS
        );
        s
    }

    fn mode(&self, mode: GhosttyMode) -> bool {
        let mut cfg = GhosttyTerminalModeConfig { mode, value: false };
        let r = unsafe {
            ghostty_terminal_get(
                self.0,
                GHOSTTY_TERMINAL_DATA_MODE,
                &mut cfg as *mut _ as *mut c_void,
            )
        };
        assert_eq!(r, GHOSTTY_SUCCESS, "mode {mode:#x}");
        cfg.value
    }
}

impl Drop for Term {
    fn drop(&mut self) {
        unsafe { ghostty_terminal_free(self.0) };
    }
}

#[test]
fn linked_library_is_vt_1_0_1() {
    let version = unsafe { CStr::from_ptr(ghostty_version()) }
        .to_str()
        .unwrap();
    assert_eq!(version, "1.0.1");
    assert_eq!(GHOSTTY_VT_VERSION, b"1.0.1\0");
    let mut string = GhosttyString::default();
    let r = unsafe {
        ghostty_build_info(
            GHOSTTY_BUILD_INFO_VERSION_STRING,
            &mut string as *mut _ as *mut c_void,
        )
    };
    assert_eq!(r, GHOSTTY_SUCCESS);
    assert_eq!(
        unsafe { std::slice::from_raw_parts(string.ptr, string.len) },
        b"1.0.1"
    );
    for (key, want) in [
        (GHOSTTY_BUILD_INFO_VERSION_MAJOR, GHOSTTY_VT_VERSION_MAJOR),
        (GHOSTTY_BUILD_INFO_VERSION_MINOR, GHOSTTY_VT_VERSION_MINOR),
        (GHOSTTY_BUILD_INFO_VERSION_PATCH, GHOSTTY_VT_VERSION_PATCH),
    ] {
        let mut n = 0usize;
        assert_eq!(
            unsafe { ghostty_build_info(key, &mut n as *mut _ as *mut c_void) },
            GHOSTTY_SUCCESS
        );
        assert_eq!(n, want as usize);
    }
    let flag = |key| {
        let mut v = false;
        assert_eq!(
            unsafe { ghostty_build_info(key, &mut v as *mut _ as *mut c_void) },
            GHOSTTY_SUCCESS
        );
        v
    };
    assert!(
        flag(GHOSTTY_BUILD_INFO_SIMD),
        "built with SIMD (highway + simdutf linked)"
    );
    assert!(
        flag(GHOSTTY_BUILD_INFO_KITTY_GRAPHICS),
        "built with Kitty graphics (wuffs linked)"
    );
    let mut optimize: GhosttyOptimizeMode = GHOSTTY_OPTIMIZE_DEBUG;
    unsafe {
        ghostty_build_info(
            GHOSTTY_BUILD_INFO_OPTIMIZE,
            &mut optimize as *mut _ as *mut c_void,
        )
    };
    assert_eq!(optimize, GHOSTTY_OPTIMIZE_RELEASE_FAST);
}

#[test]
fn style_flags_and_underline_match_the_library() {
    let t = Term::new(40, 3);
    // One cell per attribute, then every underline spelling.
    t.write(b"\x1b[1mB\x1b[0m\x1b[3mI\x1b[0m\x1b[2mF\x1b[0m\x1b[5mK\x1b[0m\x1b[7mR\x1b[0m\x1b[8mH\x1b[0m\x1b[9mS\x1b[0m\x1b[53mO\x1b[0m");
    let flags = [
        GHOSTTY_STYLE_FLAG_BOLD,
        GHOSTTY_STYLE_FLAG_ITALIC,
        GHOSTTY_STYLE_FLAG_FAINT,
        GHOSTTY_STYLE_FLAG_BLINK,
        GHOSTTY_STYLE_FLAG_INVERSE,
        GHOSTTY_STYLE_FLAG_INVISIBLE,
        GHOSTTY_STYLE_FLAG_STRIKETHROUGH,
        GHOSTTY_STYLE_FLAG_OVERLINE,
    ];
    for (x, flag) in flags.into_iter().enumerate() {
        let s = t.style(x as u16, 0);
        assert_eq!(s.flags, flag, "cell {x}");
        assert_eq!(ghostty_style_underline(&s), GHOSTTY_SGR_UNDERLINE_NONE);
    }
    t.write(b"\r\n\x1b[4ma\x1b[21mb\x1b[4:3mc\x1b[4:4md\x1b[4:5me\x1b[1;4:3mf\x1b[0mg");
    let want = [
        GHOSTTY_SGR_UNDERLINE_SINGLE,
        GHOSTTY_SGR_UNDERLINE_DOUBLE,
        GHOSTTY_SGR_UNDERLINE_CURLY,
        GHOSTTY_SGR_UNDERLINE_DOTTED,
        GHOSTTY_SGR_UNDERLINE_DASHED,
        GHOSTTY_SGR_UNDERLINE_CURLY,
        GHOSTTY_SGR_UNDERLINE_NONE,
    ];
    for (x, underline) in want.into_iter().enumerate() {
        assert_eq!(
            ghostty_style_underline(&t.style(x as u16, 1)),
            underline,
            "cell {x}"
        );
    }
    // Bold and an underline share the flags word without clobbering each other.
    let s = t.style(5, 1);
    assert_eq!(
        s.flags & !GHOSTTY_STYLE_UNDERLINE_MASK,
        GHOSTTY_STYLE_FLAG_BOLD
    );
    // The style color tag is a u8 in vt-1.0.1.
    t.write(b"\r\n\x1b[38;5;9mp\x1b[38;2;1;2;3mq");
    assert_eq!(
        t.style(0, 2).fg_color.tag,
        GHOSTTY_STYLE_COLOR_PALETTE as u8
    );
    let q = t.style(1, 2).fg_color;
    assert_eq!(q.tag, GHOSTTY_STYLE_COLOR_RGB as u8);
    let rgb = unsafe { q.value.rgb };
    assert_eq!((rgb.r, rgb.g, rgb.b), (1, 2, 3));
}

#[test]
fn modes_pack_the_ansi_flag() {
    assert_eq!(GHOSTTY_MODE_BRACKETED_PASTE, 2004);
    assert_eq!(GHOSTTY_MODE_INSERT, 4 | 0x8000);
    assert!(ghostty_mode_ansi(GHOSTTY_MODE_INSERT) && !ghostty_mode_ansi(GHOSTTY_MODE_SLOW_SCROLL));
    assert_eq!(
        ghostty_mode_value(GHOSTTY_MODE_INSERT),
        ghostty_mode_value(GHOSTTY_MODE_SLOW_SCROLL)
    );
    let t = Term::new(10, 2);
    assert!(!t.mode(GHOSTTY_MODE_BRACKETED_PASTE));
    t.write(b"\x1b[?2004h");
    assert!(t.mode(GHOSTTY_MODE_BRACKETED_PASTE));
    // ANSI mode 4 (insert) and DEC mode 4 (slow scroll) are different modes.
    t.write(b"\x1b[4h");
    assert!(t.mode(GHOSTTY_MODE_INSERT));
    assert!(!t.mode(GHOSTTY_MODE_SLOW_SCROLL));
    // The mode report encoder agrees with the packing.
    let mut buf = [0u8; 16];
    let mut n = 0;
    let r = unsafe {
        ghostty_mode_report_encode(
            GHOSTTY_MODE_INSERT,
            GHOSTTY_MODE_REPORT_SET,
            buf.as_mut_ptr(),
            buf.len(),
            &mut n,
        )
    };
    assert_eq!(r, GHOSTTY_SUCCESS);
    assert_eq!(&buf[..n], b"\x1b[4;1$y");
    let r = unsafe {
        ghostty_mode_report_encode(
            GHOSTTY_MODE_BRACKETED_PASTE,
            GHOSTTY_MODE_REPORT_RESET,
            buf.as_mut_ptr(),
            buf.len(),
            &mut n,
        )
    };
    assert_eq!(r, GHOSTTY_SUCCESS);
    assert_eq!(&buf[..n], b"\x1b[?2004;2$y");
}

/// GRAPHEMES_BUF takes a `GhosttyCodepointBuffer` in vt-1.0.1; older pins
/// took a bare `uint32_t*`, which now silently writes through `ptr`/`cap`.
#[test]
fn render_state_graphemes_use_the_codepoint_buffer() {
    let t = Term::new(10, 2);
    // Grapheme clustering (mode 2027) is off by default in libghostty-vt;
    // without it the ZWJ family below splits after its first person.
    let cluster = GhosttyTerminalModeConfig {
        mode: GHOSTTY_MODE_GRAPHEME_CLUSTER,
        value: true,
    };
    let r = unsafe {
        ghostty_terminal_set(
            t.0,
            GHOSTTY_TERMINAL_OPT_MODE_DEFAULT,
            &cluster as *const _ as *const c_void,
        )
    };
    assert_eq!(r, GHOSTTY_SUCCESS);
    assert!(t.mode(GHOSTTY_MODE_GRAPHEME_CLUSTER));
    // e + combining acute, then a ZWJ family (one cluster, wide).
    t.write("e\u{301}\u{1f468}\u{200d}\u{1f469}\u{200d}\u{1f467}!".as_bytes());
    unsafe {
        let mut state = null_mut();
        assert_eq!(
            ghostty_render_state_new(null(), &mut state),
            GHOSTTY_SUCCESS
        );
        let mut rows = null_mut();
        assert_eq!(
            ghostty_render_state_row_iterator_new(null(), &mut rows),
            GHOSTTY_SUCCESS
        );
        let mut cells = null_mut();
        assert_eq!(
            ghostty_render_state_row_cells_new(null(), &mut cells),
            GHOSTTY_SUCCESS
        );
        assert_eq!(ghostty_render_state_update(state, t.0), GHOSTTY_SUCCESS);
        ghostty_render_state_get(
            state,
            GHOSTTY_RENDER_STATE_DATA_ROW_ITERATOR,
            &mut rows as *mut _ as *mut c_void,
        );
        assert!(ghostty_render_state_row_iterator_next(rows));
        ghostty_render_state_row_get(
            rows,
            GHOSTTY_RENDER_STATE_ROW_DATA_CELLS,
            &mut cells as *mut _ as *mut c_void,
        );
        let mut texts = Vec::new();
        while ghostty_render_state_row_cells_next(cells) {
            let mut len = 0u32;
            ghostty_render_state_row_cells_get(
                cells,
                GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_GRAPHEMES_LEN,
                &mut len as *mut _ as *mut c_void,
            );
            // Too small on purpose: OUT_OF_SPACE, with len the full count.
            let mut small = [0u32; 1];
            let mut buf = GhosttyCodepointBuffer {
                ptr: small.as_mut_ptr(),
                cap: small.len(),
                len: 0,
            };
            let r = ghostty_render_state_row_cells_get(
                cells,
                GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_GRAPHEMES_BUF,
                &mut buf as *mut _ as *mut c_void,
            );
            assert_eq!(buf.len, len as usize);
            assert_eq!(
                r,
                if len > 1 {
                    GHOSTTY_OUT_OF_SPACE
                } else {
                    GHOSTTY_SUCCESS
                }
            );
            let mut cps = vec![0u32; len as usize];
            let mut buf = GhosttyCodepointBuffer {
                ptr: cps.as_mut_ptr(),
                cap: cps.len(),
                len: 0,
            };
            let r = ghostty_render_state_row_cells_get(
                cells,
                GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_GRAPHEMES_BUF,
                &mut buf as *mut _ as *mut c_void,
            );
            assert_eq!(r, GHOSTTY_SUCCESS);
            let from_cps: String = cps.iter().filter_map(|c| char::from_u32(*c)).collect();
            // The UTF-8 form agrees.
            let mut bytes = [0u8; 64];
            let mut utf8 = GhosttyBuffer {
                ptr: bytes.as_mut_ptr(),
                cap: bytes.len(),
                len: 0,
            };
            let r = ghostty_render_state_row_cells_get(
                cells,
                GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_GRAPHEMES_UTF8,
                &mut utf8 as *mut _ as *mut c_void,
            );
            assert_eq!(r, GHOSTTY_SUCCESS);
            assert_eq!(std::str::from_utf8(&bytes[..utf8.len]).unwrap(), from_cps);
            texts.push(from_cps);
        }
        assert_eq!(texts[0], "e\u{301}");
        assert_eq!(texts[1], "\u{1f468}\u{200d}\u{1f469}\u{200d}\u{1f467}");
        assert_eq!(texts[2], "", "the wide cluster's spacer tail");
        assert_eq!(texts[3], "!");
        let mut cursor = ghostty_init_sized!(GhosttyRenderStateCursor);
        assert_eq!(
            ghostty_render_state_get(
                state,
                GHOSTTY_RENDER_STATE_DATA_CURSOR,
                &mut cursor as *mut _ as *mut c_void
            ),
            GHOSTTY_SUCCESS
        );
        assert_eq!((cursor.viewport_x, cursor.viewport_y), (4, 0));
        assert_eq!(
            cursor.visual_style, GHOSTTY_CURSOR_STYLE_BLOCK,
            "the default style; a zeroed value would read as BAR"
        );
        ghostty_render_state_row_cells_free(cells);
        ghostty_render_state_row_iterator_free(rows);
        ghostty_render_state_free(state);
    }
}

/// Kitty images come from the render state's image iterator in vt-1.0.1,
/// and an image's pixels are one `GhosttyString` (`..._IMAGE_DATA_PIXELS`).
#[test]
fn kitty_images_reach_the_render_state() {
    let t = Term::new(20, 5);
    unsafe {
        assert_eq!(ghostty_terminal_resize(t.0, 20, 5, 8, 16), GHOSTTY_SUCCESS);
        let limit: u64 = 16 << 20;
        ghostty_terminal_set(
            t.0,
            GHOSTTY_TERMINAL_OPT_KITTY_IMAGE_STORAGE_LIMIT,
            &limit as *const _ as *const c_void,
        );
    }
    // A 2x1 RGBA image (red, then half-transparent green) at row 1, column 2.
    t.write(b"\x1b[2;3H\x1b_Ga=T,f=32,s=2,v=1,i=7,q=2;/wAA/wD/AIA=\x1b\\");
    unsafe {
        let mut state = null_mut();
        assert_eq!(
            ghostty_render_state_new(null(), &mut state),
            GHOSTTY_SUCCESS
        );
        let mut images = null_mut();
        assert_eq!(
            ghostty_render_state_image_iterator_new(null(), &mut images),
            GHOSTTY_SUCCESS
        );
        assert_eq!(ghostty_render_state_update(state, t.0), GHOSTTY_SUCCESS);
        let mut generation = 0u64;
        ghostty_render_state_get(
            state,
            GHOSTTY_RENDER_STATE_DATA_IMAGE_PLACEMENTS_GENERATION,
            &mut generation as *mut _ as *mut c_void,
        );
        assert_ne!(generation, 0);
        assert_eq!(
            ghostty_render_state_get(
                state,
                GHOSTTY_RENDER_STATE_DATA_IMAGE_ITERATOR,
                &mut images as *mut _ as *mut c_void
            ),
            GHOSTTY_SUCCESS
        );
        assert!(ghostty_render_state_image_iterator_next(images));
        let (mut protocol, mut id, mut layer, mut col, mut row) = (
            GHOSTTY_IMAGE_PROTOCOL_MAX_VALUE,
            0u32,
            GHOSTTY_IMAGE_LAYER_MAX_VALUE,
            0i32,
            0i32,
        );
        let (mut w, mut h, mut sw, mut sh) = (0u32, 0u32, 0u32, 0u32);
        let keys = [
            GHOSTTY_RENDER_STATE_IMAGE_DATA_PROTOCOL,
            GHOSTTY_RENDER_STATE_IMAGE_DATA_IMAGE_ID,
            GHOSTTY_RENDER_STATE_IMAGE_DATA_LAYER,
            GHOSTTY_RENDER_STATE_IMAGE_DATA_VIEWPORT_COL,
            GHOSTTY_RENDER_STATE_IMAGE_DATA_VIEWPORT_ROW,
            GHOSTTY_RENDER_STATE_IMAGE_DATA_PIXEL_WIDTH,
            GHOSTTY_RENDER_STATE_IMAGE_DATA_PIXEL_HEIGHT,
            GHOSTTY_RENDER_STATE_IMAGE_DATA_SOURCE_WIDTH,
            GHOSTTY_RENDER_STATE_IMAGE_DATA_SOURCE_HEIGHT,
        ];
        let mut values: [*mut c_void; 9] = [
            &mut protocol as *mut _ as _,
            &mut id as *mut _ as _,
            &mut layer as *mut _ as _,
            &mut col as *mut _ as _,
            &mut row as *mut _ as _,
            &mut w as *mut _ as _,
            &mut h as *mut _ as _,
            &mut sw as *mut _ as _,
            &mut sh as *mut _ as _,
        ];
        assert_eq!(
            ghostty_render_state_image_get_multi(
                images,
                keys.len(),
                keys.as_ptr(),
                values.as_mut_ptr(),
                null_mut()
            ),
            GHOSTTY_SUCCESS
        );
        assert_eq!(
            (protocol, id, layer),
            (
                GHOSTTY_IMAGE_PROTOCOL_KITTY,
                7,
                GHOSTTY_IMAGE_LAYER_ABOVE_TEXT
            )
        );
        assert_eq!((col, row, w, h, sw, sh), (2, 1, 2, 1, 2, 1));
        assert!(!ghostty_render_state_image_iterator_next(images));

        let mut graphics: GhosttyKittyGraphics = null_mut();
        assert_eq!(
            ghostty_terminal_get(
                t.0,
                GHOSTTY_TERMINAL_DATA_KITTY_GRAPHICS,
                &mut graphics as *mut _ as *mut c_void
            ),
            GHOSTTY_SUCCESS
        );
        let image = ghostty_kitty_graphics_image(graphics, id);
        assert!(!image.is_null());
        let mut format = GHOSTTY_KITTY_IMAGE_FORMAT_PNG;
        ghostty_kitty_graphics_image_get(
            image,
            GHOSTTY_KITTY_GRAPHICS_IMAGE_DATA_FORMAT,
            &mut format as *mut _ as *mut c_void,
        );
        assert_eq!(format, GHOSTTY_KITTY_IMAGE_FORMAT_RGBA);
        let mut pixels = GhosttyString::default();
        assert_eq!(
            ghostty_kitty_graphics_image_get(
                image,
                GHOSTTY_KITTY_GRAPHICS_IMAGE_DATA_PIXELS,
                &mut pixels as *mut _ as *mut c_void
            ),
            GHOSTTY_SUCCESS
        );
        assert_eq!(
            std::slice::from_raw_parts(pixels.ptr, pixels.len),
            [255, 0, 0, 255, 0, 255, 0, 128]
        );

        // The layer masks bindgen can't emit filter the storage iterator.
        let mut it = null_mut();
        assert_eq!(
            ghostty_kitty_graphics_placement_iterator_new(null(), &mut it),
            GHOSTTY_SUCCESS
        );
        let count = |mask: u32| {
            let r = ghostty_kitty_graphics_placement_iterator_set(
                it,
                GHOSTTY_KITTY_GRAPHICS_PLACEMENT_ITERATOR_OPT_LAYER,
                &mask as *const _ as *const c_void,
            );
            assert_eq!(r, GHOSTTY_SUCCESS, "mask {mask:#b}");
            let mut it2 = it;
            ghostty_kitty_graphics_get(
                graphics,
                GHOSTTY_KITTY_GRAPHICS_DATA_PLACEMENT_ITERATOR,
                &mut it2 as *mut _ as *mut c_void,
            );
            let mut n = 0;
            while ghostty_kitty_graphics_placement_next(it2) {
                n += 1;
            }
            n
        };
        assert_eq!(count(GHOSTTY_IMAGE_LAYER_MASK_ABOVE_TEXT), 1);
        assert_eq!(
            count(GHOSTTY_IMAGE_LAYER_MASK_BELOW_TEXT | GHOSTTY_IMAGE_LAYER_MASK_BELOW_BACKGROUND),
            0
        );
        let bad = 1u32 << 3;
        let r = ghostty_kitty_graphics_placement_iterator_set(
            it,
            GHOSTTY_KITTY_GRAPHICS_PLACEMENT_ITERATOR_OPT_LAYER,
            &bad as *const _ as *const c_void,
        );
        assert_eq!(r, GHOSTTY_INVALID_VALUE, "a bit past the last layer");
        ghostty_kitty_graphics_placement_iterator_free(it);
        ghostty_render_state_image_iterator_free(images);
        ghostty_render_state_free(state);
    }
}

/// vt-1.0.1 drops `ghostty_terminal_selection_format_alloc`; the formatter
/// formats the selection it is given (and the whole screen without one).
#[test]
fn selection_text_comes_from_the_formatter() {
    let t = Term::new(12, 3);
    t.write("hello 日本語\r\nsecond".as_bytes());
    unsafe {
        let mut sel = GhosttySelection::default();
        assert_eq!(
            ghostty_terminal_get(
                t.0,
                GHOSTTY_TERMINAL_DATA_SELECTION,
                &mut sel as *mut _ as *mut c_void
            ),
            GHOSTTY_NO_VALUE
        );
        let mut word = ghostty_init_sized!(GhosttyTerminalSelectWordOptions);
        word.ref_ = t.grid_ref(7, 0);
        assert_eq!(
            ghostty_terminal_select_word(t.0, &word, &mut sel),
            GHOSTTY_SUCCESS
        );
        assert_eq!(
            ghostty_terminal_set(
                t.0,
                GHOSTTY_TERMINAL_OPT_SELECTION,
                &sel as *const _ as *const c_void
            ),
            GHOSTTY_SUCCESS
        );

        let mut f = null_mut();
        assert_eq!(
            ghostty_formatter_terminal_new(null(), &mut f, t.0),
            GHOSTTY_SUCCESS
        );
        let format = |f: GhosttyFormatter| {
            let (mut ptr, mut len) = (null_mut(), 0usize);
            assert_eq!(
                ghostty_formatter_format_alloc(f, null(), &mut ptr, &mut len),
                GHOSTTY_SUCCESS
            );
            let text = String::from_utf8_lossy(std::slice::from_raw_parts(ptr, len)).into_owned();
            ghostty_free(null(), ptr, len);
            text
        };
        assert_eq!(
            format(f),
            "hello 日本語\nsecond",
            "no selection: the whole screen"
        );
        let mut current = GhosttySelection::default();
        assert_eq!(
            ghostty_terminal_get(
                t.0,
                GHOSTTY_TERMINAL_DATA_SELECTION,
                &mut current as *mut _ as *mut c_void
            ),
            GHOSTTY_SUCCESS
        );
        let (yes, emit) = (true, GHOSTTY_FORMATTER_FORMAT_PLAIN);
        ghostty_formatter_set(
            f,
            GHOSTTY_FORMATTER_OPT_EMIT,
            &emit as *const _ as *const c_void,
        );
        ghostty_formatter_set(
            f,
            GHOSTTY_FORMATTER_OPT_UNWRAP,
            &yes as *const _ as *const c_void,
        );
        ghostty_formatter_set(
            f,
            GHOSTTY_FORMATTER_OPT_TRIM,
            &yes as *const _ as *const c_void,
        );
        assert_eq!(
            ghostty_formatter_set(
                f,
                GHOSTTY_FORMATTER_OPT_SELECTION,
                &current as *const _ as *const c_void
            ),
            GHOSTTY_SUCCESS
        );
        assert_eq!(format(f), "日本語");
        let mut all = GhosttySelection::default();
        assert_eq!(ghostty_terminal_select_all(t.0, &mut all), GHOSTTY_SUCCESS);
        ghostty_formatter_set(
            f,
            GHOSTTY_FORMATTER_OPT_SELECTION,
            &all as *const _ as *const c_void,
        );
        assert_eq!(format(f), "hello 日本語\nsecond");
        ghostty_formatter_free(f);
    }
}

/// The renamed `_set`/`_set_from_terminal` encoder functions, and
/// `ghostty_key_event_set_utf8` taking a `GhosttyString`.
#[test]
fn keys_and_mouse_encode_with_the_renamed_setters() {
    let t = Term::new(80, 2);
    unsafe {
        let mut enc = null_mut();
        assert_eq!(ghostty_key_encoder_new(null(), &mut enc), GHOSTTY_SUCCESS);
        let mut ev = null_mut();
        assert_eq!(ghostty_key_event_new(null(), &mut ev), GHOSTTY_SUCCESS);
        let encode = |key: GhosttyKey, mods: GhosttyMods, text: &str| {
            assert_eq!(
                ghostty_key_encoder_set_from_terminal(enc, t.0),
                GHOSTTY_SUCCESS
            );
            ghostty_key_event_set_action(ev, GHOSTTY_KEY_ACTION_PRESS);
            ghostty_key_event_set_key(ev, key);
            ghostty_key_event_set_mods(ev, mods);
            ghostty_key_event_set_utf8(
                ev,
                GhosttyString {
                    ptr: text.as_ptr(),
                    len: text.len(),
                },
            );
            let mut buf = [0u8; 32];
            let mut n = 0;
            assert_eq!(
                ghostty_key_encoder_encode(enc, ev, buf.as_mut_ptr() as *mut _, buf.len(), &mut n),
                GHOSTTY_SUCCESS
            );
            buf[..n].to_vec()
        };
        assert_eq!(encode(GHOSTTY_KEY_A, 0, "a"), b"a");
        assert_eq!(
            encode(GHOSTTY_KEY_C, GHOSTTY_MODS_CTRL as GhosttyMods, ""),
            b"\x03"
        );
        assert_eq!(encode(GHOSTTY_KEY_ARROW_UP, 0, ""), b"\x1b[A");
        t.write(b"\x1b[?1h");
        assert_eq!(encode(GHOSTTY_KEY_ARROW_UP, 0, ""), b"\x1bOA");
        let option = GHOSTTY_OPTION_AS_ALT_TRUE;
        assert_eq!(
            ghostty_key_encoder_set(
                enc,
                GHOSTTY_KEY_ENCODER_OPT_MACOS_OPTION_AS_ALT,
                &option as *const _ as *const c_void
            ),
            GHOSTTY_SUCCESS
        );
        ghostty_key_event_free(ev);
        ghostty_key_encoder_free(enc);

        t.write(b"\x1b[?1000h\x1b[?1006h");
        let mut menc = null_mut();
        assert_eq!(
            ghostty_mouse_encoder_new(null(), &mut menc),
            GHOSTTY_SUCCESS
        );
        assert_eq!(
            ghostty_mouse_encoder_set_from_terminal(menc, t.0),
            GHOSTTY_SUCCESS
        );
        let size = GhosttyMouseEncoderSize {
            screen_width: 800,
            screen_height: 40,
            cell_width: 10,
            cell_height: 20,
            ..ghostty_init_sized!(GhosttyMouseEncoderSize)
        };
        assert_eq!(
            ghostty_mouse_encoder_set(
                menc,
                GHOSTTY_MOUSE_ENCODER_OPT_SIZE,
                &size as *const _ as *const c_void
            ),
            GHOSTTY_SUCCESS
        );
        let mut mev = null_mut();
        assert_eq!(ghostty_mouse_event_new(null(), &mut mev), GHOSTTY_SUCCESS);
        ghostty_mouse_event_set_action(mev, GHOSTTY_MOUSE_ACTION_PRESS);
        ghostty_mouse_event_set_button(mev, GHOSTTY_MOUSE_BUTTON_LEFT);
        ghostty_mouse_event_set_position(mev, GhosttyMousePosition { x: 395.0, y: 10.0 });
        let mut buf = [0u8; 32];
        let mut n = 0;
        assert_eq!(
            ghostty_mouse_encoder_encode(menc, mev, buf.as_mut_ptr() as *mut _, buf.len(), &mut n),
            GHOSTTY_SUCCESS
        );
        assert_eq!(&buf[..n], b"\x1b[<0;40;1M");
        ghostty_mouse_event_free(mev);
        ghostty_mouse_encoder_free(menc);
    }
}

/// Search navigation is `ghostty_search_select_next/prev` in vt-1.0.1.
#[test]
fn search_selects_matches_with_the_new_functions() {
    let t = Term::new(32, 4);
    t.write(b"Needle here\r\nnot this\r\nneedle again");
    unsafe {
        let mut s = null_mut();
        assert_eq!(ghostty_search_new(null(), &mut s, t.0), GHOSTTY_SUCCESS);
        let needle = "needle";
        let value = GhosttyString {
            ptr: needle.as_ptr(),
            len: needle.len(),
        };
        assert_eq!(
            ghostty_search_set(
                s,
                GHOSTTY_SEARCH_OPT_NEEDLE,
                &value as *const _ as *const c_void
            ),
            GHOSTTY_SUCCESS
        );
        assert_eq!(ghostty_search_run(s), GHOSTTY_SUCCESS);
        let mut total = 0usize;
        ghostty_search_get(
            s,
            GHOSTTY_SEARCH_DATA_TOTAL_MATCHES,
            &mut total as *mut _ as *mut c_void,
        );
        assert_eq!(total, 2, "case-insensitive");
        let selected = || {
            let mut i = 0usize;
            (ghostty_search_get(
                s,
                GHOSTTY_SEARCH_DATA_SELECTED_INDEX,
                &mut i as *mut _ as *mut c_void,
            ) == GHOSTTY_SUCCESS)
                .then_some(i)
        };
        assert_eq!(selected(), None);
        assert_eq!(ghostty_search_select_next(s), GHOSTTY_SUCCESS);
        assert_eq!(selected(), Some(0));
        assert_eq!(ghostty_search_select_next(s), GHOSTTY_SUCCESS);
        assert_eq!(selected(), Some(1));
        assert_eq!(ghostty_search_select_next(s), GHOSTTY_SUCCESS);
        assert_eq!(selected(), Some(0), "wraps");
        assert_eq!(ghostty_search_select_prev(s), GHOSTTY_SUCCESS);
        assert_eq!(selected(), Some(1));
        ghostty_search_free(s);
    }
}

#[test]
fn palette_masks_match_the_header_macros() {
    let mut mask = GhosttyColorPaletteMask::default();
    for i in [0u8, 63, 64, 200, 255] {
        assert!(!ghostty_color_palette_mask_is_set(&mask, i));
        ghostty_color_palette_mask_set(&mut mask, i);
        assert!(ghostty_color_palette_mask_is_set(&mask, i));
    }
    assert_eq!(mask.bits, [1 | 1 << 63, 1, 0, 1 << (200 - 192) | 1 << 63]);
    ghostty_color_palette_mask_unset(&mut mask, 64);
    assert_eq!(mask.bits[1], 0);
}
