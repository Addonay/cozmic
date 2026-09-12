//! Canonical integration contract for cozmic.
//!
//! The port began as independently-testable subsystem files, each carrying
//! local stand-in types. That made the modules compile standalone but meant
//! `buffer.Attrs != attrs.Attrs`, and the public `Buffer` never reached the
//! real shaper. This file is the single source of truth for WHICH module owns
//! which type. All modules must import these paths; no new local copies.
//!
//! Type ownership map (mirrors cosmic-text lib.rs re-exports):
//!
//!   attrs.zig       Color, Family, FamilyOwned, Stretch, Style, Weight,
//!                   Attrs, AttrsOwned, AttrsList, FontMatchAttrs, Metrics,
//!                   CacheMetrics, FeatureTag, Feature, FontFeatures,
//!                   LetterSpacing, UnderlineStyle, TextDecoration,
//!                   DecorationMetrics, GlyphDecorationData
//!   cursor.zig      Affinity, Cursor, LayoutCursor, Motion, Scroll
//!   line_ending.zig LineEnding, LineIter
//!   layout.zig      LayoutGlyph, LayoutLine, PhysicalGlyph, DecorationSpan,
//!                   GlyphRange, Wrap, Align, Ellipsize, EllipsizeHeightLimit,
//!                   Hinting
//!   glyph_cache.zig SubpixelBin, CacheKey, CacheKeyFlags
//!   font.zig        Font, FontId (u32)
//!   font_system.zig FontSystem, FontDb, FaceInfo, FontMatchKey,
//!                   FontCacheEntry, fallback iteration
//!   shape.zig       Shaping, Direction, ShapeGlyph, ShapeWord, ShapeSpan,
//!                   ShapeLine, ShapeBuffer, layoutToBuffer
//!   buffer_line.zig BufferLine
//!   buffer.zig      Buffer, DirtyFlags, LayoutRun, LayoutRunIter,
//!                   BufferWithFontSystem
//!   edit.zig        Editor, Selection, Change, ChangeItem, Action, BufferRef
//!   unicode.zig     UAX helpers: grapheme/word/line/bidi/script/whitespace
//!   render.zig      Renderer, renderDecoration
//!   swash_cache.zig SwashCache, withPixels
//!
//! Rules:
//! 1. No module defines a local copy of a type owned by another module.
//! 2. Low-level modules must not import high-level modules:
//!    attrs < glyph_cache < layout < unicode < cursor/line_ending < font <
//!    font_system < shape < buffer_line < buffer < edit.
//! 3. The public root (`root.zig`) re-exports the canonical owner, not a
//!    buffer.zig stand-in.
//! 4. "Compiles standalone with `zig test src/<file>.zig`" is retired as a
//!    constraint; files may and should import their dependencies.

const std = @import("std");

// Re-export the canonical owners for convenient `@import("types.zig")` use.
pub const attrs = @import("attrs.zig");
pub const cursor = @import("cursor.zig");
pub const line_ending = @import("line_ending.zig");
pub const layout = @import("layout.zig");
pub const glyph_cache = @import("glyph_cache.zig");
pub const unicode = @import("unicode.zig");

pub const Attrs = attrs.Attrs;
pub const AttrsOwned = attrs.AttrsOwned;
pub const AttrsList = attrs.AttrsList;
pub const Metrics = attrs.Metrics;
pub const Color = attrs.Color;
pub const Weight = attrs.Weight;
pub const Stretch = attrs.Stretch;
pub const Style = attrs.Style;
pub const Family = attrs.Family;
pub const FamilyOwned = attrs.FamilyOwned;
pub const FontMatchAttrs = attrs.FontMatchAttrs;
pub const UnderlineStyle = attrs.UnderlineStyle;
pub const TextDecoration = attrs.TextDecoration;
pub const DecorationMetrics = attrs.DecorationMetrics;
pub const GlyphDecorationData = attrs.GlyphDecorationData;

pub const Affinity = cursor.Affinity;
pub const Cursor = cursor.Cursor;
pub const LayoutCursor = cursor.LayoutCursor;
pub const Motion = cursor.Motion;
pub const Scroll = cursor.Scroll;

pub const LineEnding = line_ending.LineEnding;
pub const LineIter = line_ending.LineIter;

pub const Wrap = layout.Wrap;
pub const Align = layout.Align;
pub const Ellipsize = layout.Ellipsize;
pub const EllipsizeHeightLimit = layout.EllipsizeHeightLimit;
pub const Hinting = layout.Hinting;
pub const LayoutGlyph = layout.LayoutGlyph;
pub const LayoutLine = layout.LayoutLine;
pub const PhysicalGlyph = layout.PhysicalGlyph;
pub const DecorationSpan = layout.DecorationSpan;
pub const Level = u8;

pub const SubpixelBin = glyph_cache.SubpixelBin;
pub const CacheKey = glyph_cache.CacheKey;
pub const CacheKeyFlags = glyph_cache.CacheKeyFlags;

test "canonical owners resolve" {
    try std.testing.expect(@sizeOf(Metrics) > 0);
    try std.testing.expect(@sizeOf(Attrs) > 0);
    try std.testing.expect(@sizeOf(Cursor) > 0);
    try std.testing.expect(@sizeOf(LayoutLine) > 0);
}
