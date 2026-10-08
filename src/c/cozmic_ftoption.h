/* FreeType options for cozmic's bundled build.
 *
 * Starts from upstream's defaults and removes what cozmic never uses, so the
 * static library carries only sfnt (TrueType/OpenType/CFF) loading, hinting,
 * variations and anti-aliased rendering. Selected via
 * -DFT_CONFIG_OPTIONS_H="<cozmic_ftoption.h>" in build.zig. */
#include <freetype/config/ftoption.h>

/* Legacy containers and formats cozmic never opens. */
#undef FT_CONFIG_OPTION_USE_LZW
#undef FT_CONFIG_OPTION_MAC_FONTS
#undef FT_CONFIG_OPTION_GUESSING_EMBEDDED_RFORK
#undef FT_CONFIG_OPTION_INCREMENTAL
#undef TT_CONFIG_OPTION_BDF
/* OT-SVG glyphs need an external renderer hook; cozmic has none. */
#undef FT_CONFIG_OPTION_SVG

/* PNG-compressed color bitmaps (CBDT/sbix, e.g. Noto Color Emoji) need
 * libpng + zlib. With -Dcolor-bitmaps=false both are left out, and so is
 * WOFF (zlib) support. */
#if defined(COZMIC_FT_PNG) && COZMIC_FT_PNG
#  define FT_CONFIG_OPTION_USE_PNG
#  define FT_CONFIG_OPTION_SYSTEM_ZLIB
#else
#  undef FT_CONFIG_OPTION_USE_ZLIB
#endif
