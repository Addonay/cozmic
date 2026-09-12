//! Port of cosmic-text `attrs.rs`: text attributes, font matching helpers,
//! decorations, and attributed span lists.
//!
//! Conventions used throughout this module:
//! - Every owning type stores the allocator it was created with. `clone()`
//!   reuses the stored allocator and `deinit()` takes no arguments.
//!   Conversions that move a value into a *different* owner take an explicit
//!   allocator parameter.
//! - Fallible operations return `std.mem.Allocator.Error` on out-of-memory.
//!   Library code never panics on user input; empty ranges are ignored.
//! - Builder setters on `Attrs` take `*Attrs` and return `*Attrs` so calls
//!   chain. They are prefixed with `with_` because Zig does not allow a
//!   method to share a name with a struct field (unlike Rust). This is
//!   intentional and stable: Rust spells them `color()`, `family()`,
//!   `weight()`, etc. (consuming `self`); Zig spells them `with_color()`,
//!   `with_family()`, `with_weight()`, etc. (pointer-chaining). Do not rename
//!   to match Rust; the `with_` prefix is required by the language.
//! - `eql()` provides value equality and `hash()` feeds a stable byte
//!   representation into a `std.hash.Wyhash`, mirroring the Rust
//!   `Eq`/`PartialEq` and `Hash` derives. Equal values always hash equally.
//!   Integer hashing is little-endian (`writeInt(..., .little)`) so hashes are
//!   stable across big/little-endian hosts.

const std = @import("std");

/// Feed one byte tag into a hasher.
fn hash_tag(hasher: *std.hash.Wyhash, tag: u8) void {
    hasher.update(&.{tag});
}

/// Feed a `usize` into a hasher as little-endian bytes (stable across hosts).
fn hash_usize(hasher: *std.hash.Wyhash, value: usize) void {
    var buf: [@sizeOf(usize)]u8 = undefined;
    std.mem.writeInt(usize, &buf, value, .little);
    hasher.update(&buf);
}

/// Feed a `u32` into a hasher as little-endian bytes (stable across hosts).
fn hash_u32(hasher: *std.hash.Wyhash, value: u32) void {
    var buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &buf, value, .little);
    hasher.update(&buf);
}

/// Feed a `u16` into a hasher as little-endian bytes (stable across hosts).
fn hash_u16(hasher: *std.hash.Wyhash, value: u16) void {
    var buf: [2]u8 = undefined;
    std.mem.writeInt(u16, &buf, value, .little);
    hasher.update(&buf);
}

/// Feed an optional hashable value into a hasher: a `0` tag for `null`,
/// otherwise a `1` tag followed by the value.
fn hash_optional(hasher: *std.hash.Wyhash, opt: anytype) void {
    if (opt) |v| {
        hash_tag(hasher, 1);
        v.hash(hasher);
    } else {
        hash_tag(hasher, 0);
    }
}

/// Text color, stored as `0xAARRGGBB`.
pub const Color = struct {
    /// Packed color value in `0xAARRGGBB` order.
    value: u32,

    /// Create a new opaque color with red, green, and blue components.
    pub fn rgb(red: u8, green: u8, blue: u8) Color {
        return rgba(red, green, blue, 0xFF);
    }

    /// Create a new color with red, green, blue, and alpha components.
    pub fn rgba(red: u8, green: u8, blue: u8, alpha: u8) Color {
        return .{
            .value = (@as(u32, alpha) << 24) | (@as(u32, red) << 16) | (@as(u32, green) << 8) | @as(u32, blue),
        };
    }

    /// Get a tuple over all of the components, in `(r, g, b, a)` order.
    pub fn as_rgba_tuple(self: Color) struct { u8, u8, u8, u8 } {
        return .{ self.r(), self.g(), self.b(), self.a() };
    }

    /// Get an array over all of the components, in `[r, g, b, a]` order.
    pub fn as_rgba(self: Color) [4]u8 {
        return .{ self.r(), self.g(), self.b(), self.a() };
    }

    /// Get the red component.
    pub fn r(self: Color) u8 {
        return @intCast((self.value & 0x00_FF_00_00) >> 16);
    }

    /// Get the green component.
    pub fn g(self: Color) u8 {
        return @intCast((self.value & 0x00_00_FF_00) >> 8);
    }

    /// Get the blue component.
    pub fn b(self: Color) u8 {
        return @intCast(self.value & 0x00_00_00_FF);
    }

    /// Get the alpha component.
    pub fn a(self: Color) u8 {
        return @intCast((self.value & 0xFF_00_00_00) >> 24);
    }

    /// Value equality.
    pub fn eql(self: Color, other: Color) bool {
        return self.value == other.value;
    }

    /// Total ordering over the packed value, mirroring the Rust `Ord` derive.
    pub fn order(self: Color, other: Color) std.math.Order {
        return std.math.order(self.value, other.value);
    }

    /// Feed the packed value into `hasher`.
    pub fn hash(self: Color, hasher: *std.hash.Wyhash) void {
        hash_u32(hasher, self.value);
    }
};

/// A font family, borrowing the name slice (mirrors fontdb `Family`).
pub const Family = union(enum) {
    /// A named font family, e.g. `"Inter"`. The slice is borrowed.
    name: []const u8,
    /// Serif fonts represent the formal text style for a script.
    serif,
    /// Low contrast glyphs with plain stroke endings.
    sans_serif,
    /// Informal, handwritten-style glyphs.
    cursive,
    /// Decorative or expressive glyphs.
    fantasy,
    /// Fixed-width glyphs.
    monospace,

    /// Value equality; names compare by contents.
    pub fn eql(self: Family, other: Family) bool {
        switch (self) {
            .name => |n| switch (other) {
                .name => |m| return std.mem.eql(u8, n, m),
                else => return false,
            },
            .serif => return other == .serif,
            .sans_serif => return other == .sans_serif,
            .cursive => return other == .cursive,
            .fantasy => return other == .fantasy,
            .monospace => return other == .monospace,
        }
    }

    /// Feed a stable representation of the family into `hasher`.
    pub fn hash(self: Family, hasher: *std.hash.Wyhash) void {
        switch (self) {
            .name => |n| {
                hash_tag(hasher, 0);
                hasher.update(n);
            },
            .serif => hash_tag(hasher, 1),
            .sans_serif => hash_tag(hasher, 2),
            .cursive => hash_tag(hasher, 3),
            .fantasy => hash_tag(hasher, 4),
            .monospace => hash_tag(hasher, 5),
        }
    }
};

/// An owned version of `Family`; the `name` payload is heap-allocated.
///
/// Stores the allocator it was created with (like `FontFeatures`,
/// `AttrsOwned`, `FontMatchAttrs`); `clone_with(allocator)` rebinds the copy
/// to a new allocator and `deinit()` uses the stored allocator (takes no
/// arguments). This is a breaking change from the earlier union-only shape
/// that required the caller to pass the allocator to `deinit`.
pub const FamilyOwned = struct {
    /// Allocator backing the owned `name` (stored even for non-owning tags so
    /// `deinit()` never needs an argument).
    allocator: std.mem.Allocator,
    /// Owned payload.
    kind: Kind,

    /// Owned family payload.
    pub const Kind = union(enum) {
        /// An owned copy of a font family name.
        name: []u8,
        /// Serif fonts represent the formal text style for a script.
        serif,
        /// Low contrast glyphs with plain stroke endings.
        sans_serif,
        /// Informal, handwritten-style glyphs.
        cursive,
        /// Decorative or expressive glyphs.
        fantasy,
        /// Fixed-width glyphs.
        monospace,
    };

    /// Copy a borrowed `Family`, duplicating the name when present.
    pub fn from_family(allocator: std.mem.Allocator, family: Family) !FamilyOwned {
        const kind: Kind = switch (family) {
            .name => |n| .{ .name = try allocator.dupe(u8, n) },
            .serif => .serif,
            .sans_serif => .sans_serif,
            .cursive => .cursive,
            .fantasy => .fantasy,
            .monospace => .monospace,
        };
        return .{ .allocator = allocator, .kind = kind };
    }

    /// Borrow this owned family as a `Family`.
    ///
    /// The returned name slice aliases memory owned by `self`; the caller
    /// must not use it after `self` is modified or deinitialized.
    pub fn as_family(self: *const FamilyOwned) Family {
        return switch (self.kind) {
            .name => |n| .{ .name = n },
            .serif => .serif,
            .sans_serif => .sans_serif,
            .cursive => .cursive,
            .fantasy => .fantasy,
            .monospace => .monospace,
        };
    }

    /// Deep copy, duplicating the name with `allocator`.
    pub fn clone_with(self: *const FamilyOwned, allocator: std.mem.Allocator) !FamilyOwned {
        return from_family(allocator, self.as_family());
    }

    /// Release the owned name, if any, using the stored allocator.
    pub fn deinit(self: *FamilyOwned) void {
        switch (self.kind) {
            .name => |n| self.allocator.free(n),
            else => {},
        }
    }

    /// Value equality; names compare by contents.
    pub fn eql(self: *const FamilyOwned, other: *const FamilyOwned) bool {
        return self.as_family().eql(other.as_family());
    }

    /// Feed a stable representation of the family into `hasher`.
    pub fn hash(self: *const FamilyOwned, hasher: *std.hash.Wyhash) void {
        self.as_family().hash(hasher);
    }
};

/// True when two allocators are the same instance (same `ptr` and `vtable`).
fn allocatorsEql(a: std.mem.Allocator, b: std.mem.Allocator) bool {
    return a.ptr == b.ptr and a.vtable == b.vtable;
}

/// Font width selection, matching fontdb `Stretch` (TTF OS/2 width class).
///
/// Numeric values match the OS/2 `usWidthClass` numbers 1-9.
pub const Stretch = enum(u8) {
    ultra_condensed = 1,
    extra_condensed = 2,
    condensed = 3,
    semi_condensed = 4,
    normal = 5,
    semi_expanded = 6,
    expanded = 7,
    extra_expanded = 8,
    ultra_expanded = 9,

    /// Convert an OS/2 width class number to a `Stretch`, if valid.
    pub fn from_number(value: u8) ?Stretch {
        return switch (value) {
            1 => .ultra_condensed,
            2 => .extra_condensed,
            3 => .condensed,
            4 => .semi_condensed,
            5 => .normal,
            6 => .semi_expanded,
            7 => .expanded,
            8 => .extra_expanded,
            9 => .ultra_expanded,
            else => null,
        };
    }

    /// Convert this stretch to its OS/2 width class number.
    pub fn to_number(self: Stretch) u8 {
        return @backingInt(self);
    }

    /// Value equality.
    pub fn eql(self: Stretch, other: Stretch) bool {
        return self == other;
    }

    /// Ordering by width class number.
    pub fn order(self: Stretch, other: Stretch) std.math.Order {
        return std.math.order(self.to_number(), other.to_number());
    }

    /// Feed the width class number into `hasher`.
    pub fn hash(self: Stretch, hasher: *std.hash.Wyhash) void {
        hash_tag(hasher, self.to_number());
    }
};

/// Font slant selection, matching fontdb `Style`.
pub const Style = enum(u8) {
    /// A face that is neither italic nor obliqued.
    normal = 0,
    /// A form that is generally cursive in nature.
    italic = 1,
    /// A typically-sloped version of the regular face.
    oblique = 2,

    /// Value equality.
    pub fn eql(self: Style, other: Style) bool {
        return self == other;
    }

    /// Feed the style discriminant into `hasher`.
    pub fn hash(self: Style, hasher: *std.hash.Wyhash) void {
        hash_tag(hasher, @backingInt(self));
    }
};

/// Font weight (degree of blackness), matching fontdb `Weight`.
///
/// Note: fontdb models weight as a struct wrapping a `u16`, not an enum, so
/// this port does the same to preserve arbitrary weight values.
pub const Weight = struct {
    /// Raw weight value, e.g. 400 for normal, 700 for bold.
    value: u16,

    /// Thin weight (100), the thinnest value.
    pub const thin: Weight = .{ .value = 100 };
    /// Extra light weight (200).
    pub const extra_light: Weight = .{ .value = 200 };
    /// Light weight (300).
    pub const light: Weight = .{ .value = 300 };
    /// Normal weight (400).
    pub const normal: Weight = .{ .value = 400 };
    /// Medium weight (500, higher than normal).
    pub const medium: Weight = .{ .value = 500 };
    /// Semibold weight (600).
    pub const semibold: Weight = .{ .value = 600 };
    /// Bold weight (700).
    pub const bold: Weight = .{ .value = 700 };
    /// Extra-bold weight (800).
    pub const extra_bold: Weight = .{ .value = 800 };
    /// Black weight (900), the thickest value.
    pub const black: Weight = .{ .value = 900 };

    /// Value equality.
    pub fn eql(self: Weight, other: Weight) bool {
        return self.value == other.value;
    }

    /// Ordering by raw weight value, mirroring the Rust `Ord` derive.
    pub fn order(self: Weight, other: Weight) std.math.Order {
        return std.math.order(self.value, other.value);
    }

    /// Feed the raw weight value into `hasher` (little-endian).
    pub fn hash(self: Weight, hasher: *std.hash.Wyhash) void {
        hash_u16(hasher, self.value);
    }
};

/// Flags that change glyph rendering, mirroring `CacheKeyFlags`.
pub const CacheKeyFlags = struct {
    /// Raw flag bits.
    bits: u32 = 0,

    /// Skew by 14 degrees to synthesize italic.
    pub const fake_italic: CacheKeyFlags = .{ .bits = 1 };
    /// Disable hinting.
    pub const disable_hinting: CacheKeyFlags = .{ .bits = 2 };
    /// Render as a pixel font.
    pub const pixel_font: CacheKeyFlags = .{ .bits = 4 };

    /// Uppercase aliases (mirroring the previous `glyph_cache` spelling).
    pub const FAKE_ITALIC = fake_italic;
    pub const DISABLE_HINTING = disable_hinting;
    pub const PIXEL_FONT = pixel_font;

    /// No flags set.
    pub fn empty() CacheKeyFlags {
        return .{};
    }

    /// Union of two flag sets (`a | b`), mirroring bitflags `|`.
    pub fn merge(a: CacheKeyFlags, b: CacheKeyFlags) CacheKeyFlags {
        return .{ .bits = a.bits | b.bits };
    }

    /// Ordering by raw bits, mirroring the `Ord` derive on the Rust bitflags.
    pub fn lessThan(a: CacheKeyFlags, b: CacheKeyFlags) bool {
        return a.bits < b.bits;
    }

    /// Build flags from raw bits.
    pub fn from_bits(bits: u32) CacheKeyFlags {
        return .{ .bits = bits };
    }

    /// Check whether all bits in `other` are set in `self`.
    pub fn contains(self: CacheKeyFlags, other: CacheKeyFlags) bool {
        return (self.bits & other.bits) == other.bits;
    }

    /// Set all bits in `other`.
    pub fn insert(self: *CacheKeyFlags, other: CacheKeyFlags) void {
        self.bits |= other.bits;
    }

    /// Clear all bits in `other`.
    pub fn remove(self: *CacheKeyFlags, other: CacheKeyFlags) void {
        self.bits &= ~other.bits;
    }

    /// Value equality.
    pub fn eql(self: CacheKeyFlags, other: CacheKeyFlags) bool {
        return self.bits == other.bits;
    }

    /// Feed the raw bits into `hasher`.
    pub fn hash(self: CacheKeyFlags, hasher: *std.hash.Wyhash) void {
        hash_u32(hasher, self.bits);
    }
};

/// Metrics of text: font size and line height in pixels.
///
/// Mirrors cosmic-text `Metrics`; `PartialEq` only (no hash for floats).
pub const Metrics = struct {
    /// Font size in pixels.
    font_size: f32,
    /// Line height in pixels.
    line_height: f32,

    /// Create metrics with the given font size and line height.
    pub fn new(font_size: f32, line_height: f32) Metrics {
        return .{ .font_size = font_size, .line_height = line_height };
    }

    /// Create metrics with the given font size, scaling line height relatively.
    pub fn relative(font_size: f32, line_height_scale: f32) Metrics {
        return .{ .font_size = font_size, .line_height = font_size * line_height_scale };
    }

    /// Scale font size and line height.
    pub fn scale(self: Metrics, factor: f32) Metrics {
        return .{ .font_size = self.font_size * factor, .line_height = self.line_height * factor };
    }

    /// Value equality.
    pub fn eql(self: Metrics, other: Metrics) bool {
        return self.font_size == other.font_size and self.line_height == other.line_height;
    }
};

/// Metrics, but storing the `u32` bit patterns of the floats so the value
/// implements `eql()` and `hash()`.
pub const CacheMetrics = struct {
    /// Bit pattern of the font size.
    font_size_bits: u32,
    /// Bit pattern of the line height.
    line_height_bits: u32,

    /// Build cache metrics from float metrics.
    pub fn from_metrics(metrics: Metrics) CacheMetrics {
        return .{
            .font_size_bits = @bitCast(metrics.font_size),
            .line_height_bits = @bitCast(metrics.line_height),
        };
    }

    /// Build cache metrics directly from float values.
    pub fn new(font_size: f32, line_height: f32) CacheMetrics {
        return from_metrics(Metrics.new(font_size, line_height));
    }

    /// Convert back to float metrics.
    pub fn to_metrics(self: CacheMetrics) Metrics {
        return .{
            .font_size = @bitCast(self.font_size_bits),
            .line_height = @bitCast(self.line_height_bits),
        };
    }

    /// Value equality over the bit patterns.
    pub fn eql(self: CacheMetrics, other: CacheMetrics) bool {
        return self.font_size_bits == other.font_size_bits and
            self.line_height_bits == other.line_height_bits;
    }

    /// Feed the bit patterns into `hasher`.
    pub fn hash(self: CacheMetrics, hasher: *std.hash.Wyhash) void {
        hash_u32(hasher, self.font_size_bits);
        hash_u32(hasher, self.line_height_bits);
    }
};

/// A 4-byte OpenType feature tag identifier.
pub const FeatureTag = struct {
    /// Raw tag bytes, e.g. `"kern"`.
    bytes: [4]u8,

    /// Build a tag from a 4-byte array.
    pub fn new(tag: *const [4]u8) FeatureTag {
        return .{ .bytes = tag.* };
    }

    /// Kerning adjusts spacing between specific character pairs.
    pub const kerning: FeatureTag = .{ .bytes = "kern".* };
    /// Standard ligatures (fi, fl, etc.)
    pub const standard_ligatures: FeatureTag = .{ .bytes = "liga".* };
    /// Contextual ligatures (context-dependent ligatures).
    pub const contextual_ligatures: FeatureTag = .{ .bytes = "clig".* };
    /// Contextual alternates (glyph substitutions based on context).
    pub const contextual_alternates: FeatureTag = .{ .bytes = "calt".* };
    /// Discretionary ligatures (optional stylistic ligatures).
    pub const discretionary_ligatures: FeatureTag = .{ .bytes = "dlig".* };
    /// Small caps (lowercase to small capitals).
    pub const small_caps: FeatureTag = .{ .bytes = "smcp".* };
    /// All small caps (uppercase and lowercase to small capitals).
    pub const all_small_caps: FeatureTag = .{ .bytes = "c2sc".* };
    /// Stylistic Set 1 (font-specific alternate glyphs).
    pub const stylistic_set_1: FeatureTag = .{ .bytes = "ss01".* };
    /// Stylistic Set 2 (font-specific alternate glyphs).
    pub const stylistic_set_2: FeatureTag = .{ .bytes = "ss02".* };

    /// Borrow the raw tag bytes.
    pub fn as_bytes(self: *const FeatureTag) *const [4]u8 {
        return &self.bytes;
    }

    /// Value equality.
    pub fn eql(self: FeatureTag, other: FeatureTag) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }

    /// Feed the tag bytes into `hasher`.
    pub fn hash(self: FeatureTag, hasher: *std.hash.Wyhash) void {
        hasher.update(&self.bytes);
    }
};

/// A single OpenType feature setting: tag plus value.
pub const Feature = struct {
    /// Which feature to set.
    tag: FeatureTag,
    /// Feature value (1 enables, 0 disables boolean features).
    value: u32,

    /// Value equality.
    pub fn eql(self: Feature, other: Feature) bool {
        return self.tag.eql(other.tag) and self.value == other.value;
    }

    /// Feed the tag and value into `hasher`.
    pub fn hash(self: Feature, hasher: *std.hash.Wyhash) void {
        self.tag.hash(hasher);
        hash_u32(hasher, self.value);
    }
};

/// An ordered list of OpenType feature settings.
///
/// Mirrors the Rust type: `set()` appends (it does not deduplicate), and
/// `enable()`/`disable()` append a value of 1/0 respectively.
pub const FontFeatures = struct {
    /// Allocator backing the feature list.
    allocator: std.mem.Allocator,
    /// Feature settings in insertion order.
    features: std.ArrayList(Feature) = .empty,

    /// Create an empty feature list.
    pub fn init(allocator: std.mem.Allocator) FontFeatures {
        return .{ .allocator = allocator };
    }

    /// Release list storage. Individual features own no memory.
    pub fn deinit(self: *FontFeatures) void {
        self.features.deinit(self.allocator);
    }

    /// Copy the list, rebinding the copy to `allocator`.
    pub fn clone_with(self: *const FontFeatures, allocator: std.mem.Allocator) !FontFeatures {
        var copy = FontFeatures.init(allocator);
        errdefer copy.deinit();
        try copy.features.appendSlice(allocator, self.features.items);
        return copy;
    }

    /// Number of feature settings.
    pub fn count(self: *const FontFeatures) usize {
        return self.features.items.len;
    }

    /// Get the setting at `index`. The caller must ensure it is in bounds.
    pub fn get(self: *const FontFeatures, index: usize) Feature {
        return self.features.items[index];
    }

    /// Append a `(tag, value)` setting. Returns `self` for chaining.
    pub fn set(self: *FontFeatures, tag: FeatureTag, value: u32) !*FontFeatures {
        try self.features.append(self.allocator, .{ .tag = tag, .value = value });
        return self;
    }

    /// Enable a feature (append it with value 1). Returns `self` for chaining.
    pub fn enable(self: *FontFeatures, tag: FeatureTag) !*FontFeatures {
        return self.set(tag, 1);
    }

    /// Disable a feature (append it with value 0). Returns `self` for chaining.
    pub fn disable(self: *FontFeatures, tag: FeatureTag) !*FontFeatures {
        return self.set(tag, 0);
    }

    /// Value equality, order-sensitive like the underlying list.
    pub fn eql(self: *const FontFeatures, other: *const FontFeatures) bool {
        if (self.features.items.len != other.features.items.len) return false;
        for (self.features.items, other.features.items) |a, b| {
            if (!a.eql(b)) return false;
        }
        return true;
    }

    /// Feed the settings in order into `hasher`.
    pub fn hash(self: *const FontFeatures, hasher: *std.hash.Wyhash) void {
        hash_usize(hasher, self.features.items.len);
        for (self.features.items) |feature| feature.hash(hasher);
    }
};

/// Letter spacing (tracking) in EM units.
///
/// Wraps an `f32` so equality and hashing canonicalize NaN and signed zero:
/// all NaN payloads compare and hash equally, and `-0.0` hashes like `+0.0`.
pub const LetterSpacing = struct {
    /// Spacing value in EM units.
    value: f32,

    /// Canonical NaN bit pattern used for equality and hashing.
    pub const canonical_nan_bits: u32 = 0x7fc0_0000;

    /// Bit pattern used for hashing: canonical NaN for NaN inputs,
    /// otherwise the value with `-0.0` canonicalized to `+0.0`.
    pub fn normalized_bits(self: LetterSpacing) u32 {
        if (std.math.isNan(self.value)) {
            return canonical_nan_bits;
        }
        // Adding +0.0 canonicalizes -0.0 to +0.0.
        return @bitCast(self.value + 0.0);
    }

    /// Value equality where any NaN equals any other NaN.
    pub fn eql(self: LetterSpacing, other: LetterSpacing) bool {
        if (std.math.isNan(self.value)) {
            return std.math.isNan(other.value);
        }
        return self.value == other.value;
    }

    /// Feed the canonicalized bits into `hasher`.
    pub fn hash(self: LetterSpacing, hasher: *std.hash.Wyhash) void {
        hash_u32(hasher, self.normalized_bits());
    }
};

/// Underline line style.
pub const UnderlineStyle = enum(u8) {
    /// No underline.
    none = 0,
    /// A single underline.
    single = 1,
    /// A double underline.
    double = 2,

    /// Value equality.
    pub fn eql(self: UnderlineStyle, other: UnderlineStyle) bool {
        return self == other;
    }

    /// Feed the style discriminant into `hasher`.
    pub fn hash(self: UnderlineStyle, hasher: *std.hash.Wyhash) void {
        hash_tag(hasher, @backingInt(self));
    }
};

/// Underline, strikethrough, and overline decoration settings.
pub const TextDecoration = struct {
    /// Underline style.
    underline: UnderlineStyle = .none,
    /// Optional underline color override (text color when `null`).
    underline_color_opt: ?Color = null,
    /// Whether strikethrough is enabled.
    strikethrough: bool = false,
    /// Optional strikethrough color override (text color when `null`).
    strikethrough_color_opt: ?Color = null,
    /// Whether overline is enabled.
    overline: bool = false,
    /// Optional overline color override (text color when `null`).
    overline_color_opt: ?Color = null,

    /// Create decoration settings with no decoration enabled.
    pub fn new() TextDecoration {
        return .{};
    }

    /// Check whether any decoration is enabled.
    pub fn has_decoration(self: TextDecoration) bool {
        return self.underline != .none or self.strikethrough or self.overline;
    }

    /// Value equality.
    pub fn eql(self: TextDecoration, other: TextDecoration) bool {
        return self.underline == other.underline and
            opt_color_eql(self.underline_color_opt, other.underline_color_opt) and
            self.strikethrough == other.strikethrough and
            opt_color_eql(self.strikethrough_color_opt, other.strikethrough_color_opt) and
            self.overline == other.overline and
            opt_color_eql(self.overline_color_opt, other.overline_color_opt);
    }

    /// Feed all settings into `hasher`.
    pub fn hash(self: TextDecoration, hasher: *std.hash.Wyhash) void {
        self.underline.hash(hasher);
        hash_optional(hasher, self.underline_color_opt);
        hash_tag(hasher, @as(u8, @intFromBool(self.strikethrough)));
        hash_optional(hasher, self.strikethrough_color_opt);
        hash_tag(hasher, @as(u8, @intFromBool(self.overline)));
        hash_optional(hasher, self.overline_color_opt);
    }
};

/// Compare two optional colors for equality.
fn opt_color_eql(a: ?Color, b: ?Color) bool {
    if (a) |ac| {
        if (b) |bc| return ac.eql(bc);
        return false;
    }
    return b == null;
}

/// Offset and thickness for a text decoration line, in EM units.
///
/// Holds floats, so only `eql()` is provided (no hash), like the Rust
/// `PartialEq`-only derive.
pub const DecorationMetrics = struct {
    /// Offset from the baseline in EM units.
    offset: f32 = 0,
    /// Line thickness in EM units.
    thickness: f32 = 0,

    /// Value equality.
    pub fn eql(self: DecorationMetrics, other: DecorationMetrics) bool {
        return self.offset == other.offset and self.thickness == other.thickness;
    }
};

/// Decoration configuration paired with font-provided line metrics.
///
/// Holds floats, so only `eql()` is provided (no hash), like the Rust
/// `PartialEq`-only derive.
pub const GlyphDecorationData = struct {
    /// The text decoration configuration from the user.
    text_decoration: TextDecoration,
    /// Underline offset and thickness from the font.
    underline_metrics: DecorationMetrics,
    /// Strikethrough offset and thickness from the font.
    strikethrough_metrics: DecorationMetrics,
    /// Font ascent in EM units (`ascent / upem`), used for overline positioning.
    ascent: f32,

    /// Value equality.
    pub fn eql(self: GlyphDecorationData, other: GlyphDecorationData) bool {
        return self.text_decoration.eql(other.text_decoration) and
            self.underline_metrics.eql(other.underline_metrics) and
            self.strikethrough_metrics.eql(other.strikethrough_metrics) and
            self.ascent == other.ascent;
    }
};

/// Text attributes.
///
/// The borrowed `family` name slice must outlive the `Attrs` value; use
/// `AttrsOwned` for an owned copy. Builder setters take `*Attrs` and return
/// `*Attrs` so calls chain: `_ = attrs.with_color(c).with_weight(.bold);`.
pub const Attrs = struct {
    /// Allocator backing `font_features`.
    allocator: std.mem.Allocator,
    /// Optional text color override.
    color_opt: ?Color = null,
    /// Font family (borrowed).
    family: Family = .sans_serif,
    /// Font width.
    stretch: Stretch = .normal,
    /// Font slant.
    style: Style = .normal,
    /// Font weight.
    weight: Weight = Weight.normal,
    /// Opaque caller metadata.
    metadata: usize = 0,
    /// Glyph cache key flags.
    cache_key_flags: CacheKeyFlags = .{},
    /// Metrics override; buffer metrics apply when `null`.
    metrics_opt: ?CacheMetrics = null,
    /// Letter spacing (tracking) in EM units.
    letter_spacing_opt: ?LetterSpacing = null,
    /// OpenType feature settings.
    font_features: FontFeatures,
    /// Text decorations.
    text_decoration: TextDecoration = TextDecoration.new(),

    /// Create attributes with sane defaults: a regular sans-serif font.
    pub fn init(allocator: std.mem.Allocator) Attrs {
        return .{
            .allocator = allocator,
            .font_features = FontFeatures.init(allocator),
        };
    }

    /// Release feature list storage.
    pub fn deinit(self: *Attrs) void {
        self.font_features.deinit();
    }

    /// Deep copy, rebinding the copy to `allocator`.
    pub fn clone_with(self: *const Attrs, allocator: std.mem.Allocator) !Attrs {
        var copy = Attrs.init(allocator);
        errdefer copy.deinit();
        copy.color_opt = self.color_opt;
        copy.family = self.family;
        copy.stretch = self.stretch;
        copy.style = self.style;
        copy.weight = self.weight;
        copy.metadata = self.metadata;
        copy.cache_key_flags = self.cache_key_flags;
        copy.metrics_opt = self.metrics_opt;
        copy.letter_spacing_opt = self.letter_spacing_opt;
        copy.font_features.deinit();
        copy.font_features = try self.font_features.clone_with(allocator);
        copy.text_decoration = self.text_decoration;
        return copy;
    }

    /// Set `Color`.
    pub fn with_color(self: *Attrs, color: Color) *Attrs {
        self.color_opt = color;
        return self;
    }

    /// Set `Family`.
    pub fn with_family(self: *Attrs, family: Family) *Attrs {
        self.family = family;
        return self;
    }

    /// Set `Stretch`.
    pub fn with_stretch(self: *Attrs, stretch: Stretch) *Attrs {
        self.stretch = stretch;
        return self;
    }

    /// Set `Style`.
    pub fn with_style(self: *Attrs, style: Style) *Attrs {
        self.style = style;
        return self;
    }

    /// Set `Weight`.
    pub fn with_weight(self: *Attrs, weight: Weight) *Attrs {
        self.weight = weight;
        return self;
    }

    /// Set metadata.
    pub fn with_metadata(self: *Attrs, metadata: usize) *Attrs {
        self.metadata = metadata;
        return self;
    }

    /// Set `CacheKeyFlags`.
    pub fn with_cache_key_flags(self: *Attrs, cache_key_flags: CacheKeyFlags) *Attrs {
        self.cache_key_flags = cache_key_flags;
        return self;
    }

    /// Set `Metrics`, overriding values in the buffer.
    pub fn with_metrics(self: *Attrs, metrics: Metrics) *Attrs {
        self.metrics_opt = CacheMetrics.from_metrics(metrics);
        return self;
    }

    /// Set letter spacing (tracking) in EM units.
    pub fn with_letter_spacing(self: *Attrs, letter_spacing: f32) *Attrs {
        self.letter_spacing_opt = .{ .value = letter_spacing };
        return self;
    }

    /// Set `FontFeatures`, taking ownership of `font_features`.
    ///
    /// Previously held features are released. The caller must not use
    /// `font_features` after this call.
    ///
    /// Allocator contract: `font_features` must have been created with the
    /// same allocator as `self` (`self.allocator`). Debug-asserts this; a
    /// mismatched allocator would desync `Attrs.allocator` vs
    /// `font_features.allocator` and free with the wrong allocator on later
    /// `deinit`/`clone_with`. To move features across allocators, rebind
    /// first: `var rebound = try features.clone_with(attrs.allocator);` then
    /// `_ = attrs.with_font_features(rebound);`.
    pub fn with_font_features(self: *Attrs, font_features: FontFeatures) *Attrs {
        std.debug.assert(allocatorsEql(self.allocator, font_features.allocator));
        self.font_features.deinit();
        self.font_features = font_features;
        return self;
    }

    /// Set the underline style.
    pub fn with_underline(self: *Attrs, style: UnderlineStyle) *Attrs {
        self.text_decoration.underline = style;
        return self;
    }

    /// Set the underline color override.
    pub fn with_underline_color(self: *Attrs, color: Color) *Attrs {
        self.text_decoration.underline_color_opt = color;
        return self;
    }

    /// Enable strikethrough.
    pub fn with_strikethrough(self: *Attrs) *Attrs {
        self.text_decoration.strikethrough = true;
        return self;
    }

    /// Set the strikethrough color override.
    pub fn with_strikethrough_color(self: *Attrs, color: Color) *Attrs {
        self.text_decoration.strikethrough_color_opt = color;
        return self;
    }

    /// Enable overline.
    pub fn with_overline(self: *Attrs) *Attrs {
        self.text_decoration.overline = true;
        return self;
    }

    /// Set the overline color override.
    pub fn with_overline_color(self: *Attrs, color: Color) *Attrs {
        self.text_decoration.overline_color_opt = color;
        return self;
    }

    /// Check if this set of attributes can be shaped together with another.
    ///
    /// Only family, stretch, style, and weight matter for shaping.
    pub fn compatible(self: *const Attrs, other: *const Attrs) bool {
        return self.family.eql(other.family) and
            self.stretch.eql(other.stretch) and
            self.style.eql(other.style) and
            self.weight.eql(other.weight);
    }

    /// Value equality over every field, including decorations and features.
    pub fn eql(self: *const Attrs, other: *const Attrs) bool {
        return opt_color_eql(self.color_opt, other.color_opt) and
            self.family.eql(other.family) and
            self.stretch.eql(other.stretch) and
            self.style.eql(other.style) and
            self.weight.eql(other.weight) and
            self.metadata == other.metadata and
            self.cache_key_flags.eql(other.cache_key_flags) and
            opt_cache_metrics_eql(self.metrics_opt, other.metrics_opt) and
            opt_letter_spacing_eql(self.letter_spacing_opt, other.letter_spacing_opt) and
            self.font_features.eql(&other.font_features) and
            self.text_decoration.eql(other.text_decoration);
    }

    /// Feed every field into `hasher`.
    pub fn hash(self: *const Attrs, hasher: *std.hash.Wyhash) void {
        hash_optional(hasher, self.color_opt);
        self.family.hash(hasher);
        self.stretch.hash(hasher);
        self.style.hash(hasher);
        self.weight.hash(hasher);
        hash_usize(hasher, self.metadata);
        self.cache_key_flags.hash(hasher);
        hash_optional(hasher, self.metrics_opt);
        hash_optional(hasher, self.letter_spacing_opt);
        self.font_features.hash(hasher);
        self.text_decoration.hash(hasher);
    }
};

/// Compare two optional cache metrics for equality.
fn opt_cache_metrics_eql(a: ?CacheMetrics, b: ?CacheMetrics) bool {
    if (a) |am| {
        if (b) |bm| return am.eql(bm);
        return false;
    }
    return b == null;
}

/// Compare two optional letter spacings for equality.
fn opt_letter_spacing_eql(a: ?LetterSpacing, b: ?LetterSpacing) bool {
    if (a) |av| {
        if (b) |bv| return av.eql(bv);
        return false;
    }
    return b == null;
}

/// Font-specific part of `Attrs`, used for font matching.
pub const FontMatchAttrs = struct {
    /// Allocator backing the owned family name.
    allocator: std.mem.Allocator,
    /// Owned font family.
    family: FamilyOwned,
    /// Font width.
    stretch: Stretch,
    /// Font slant.
    style: Style,
    /// Font weight.
    weight: Weight,

    /// Extract the font-matching subset of `attrs`, copying the family name.
    pub fn from_attrs(allocator: std.mem.Allocator, attrs: *const Attrs) !FontMatchAttrs {
        return .{
            .allocator = allocator,
            .family = try FamilyOwned.from_family(allocator, attrs.family),
            .stretch = attrs.stretch,
            .style = attrs.style,
            .weight = attrs.weight,
        };
    }

    /// Release the owned family name (uses the stored allocator).
    pub fn deinit(self: *FontMatchAttrs) void {
        std.debug.assert(allocatorsEql(self.allocator, self.family.allocator));
        self.family.deinit();
    }

    /// Deep copy, rebinding the copy to `allocator`.
    pub fn clone_with(self: *const FontMatchAttrs, allocator: std.mem.Allocator) !FontMatchAttrs {
        return .{
            .allocator = allocator,
            .family = try FamilyOwned.from_family(allocator, self.family.as_family()),
            .stretch = self.stretch,
            .style = self.style,
            .weight = self.weight,
        };
    }

    /// Value equality.
    pub fn eql(self: *const FontMatchAttrs, other: *const FontMatchAttrs) bool {
        return self.family.eql(&other.family) and
            self.stretch.eql(other.stretch) and
            self.style.eql(other.style) and
            self.weight.eql(other.weight);
    }

    /// Feed every field into `hasher`.
    pub fn hash(self: *const FontMatchAttrs, hasher: *std.hash.Wyhash) void {
        self.family.hash(hasher);
        self.stretch.hash(hasher);
        self.style.hash(hasher);
        self.weight.hash(hasher);
    }
};

/// An owned version of `Attrs`.
///
/// The family name and feature list are heap-allocated. `to_attrs()` converts
/// back to a borrowed `Attrs`: the family slice aliases this value (and must
/// not outlive it) while the feature list is freshly cloned (and must be
/// released with `deinit()`), mirroring how the Rust `as_attrs()` clones the
/// feature vector.
pub const AttrsOwned = struct {
    /// Allocator backing the family name and feature list.
    allocator: std.mem.Allocator,
    /// Optional text color override.
    color_opt: ?Color = null,
    /// Owned font family (stores its own allocator; must match `allocator`).
    family_owned: FamilyOwned,
    /// Font width.
    stretch: Stretch = .normal,
    /// Font slant.
    style: Style = .normal,
    /// Font weight.
    weight: Weight = Weight.normal,
    /// Opaque caller metadata.
    metadata: usize = 0,
    /// Glyph cache key flags.
    cache_key_flags: CacheKeyFlags = .{},
    /// Metrics override; buffer metrics apply when `null`.
    metrics_opt: ?CacheMetrics = null,
    /// Letter spacing (tracking) in EM units.
    letter_spacing_opt: ?LetterSpacing = null,
    /// OpenType feature settings.
    font_features: FontFeatures,
    /// Text decorations.
    text_decoration: TextDecoration = TextDecoration.new(),

    /// Copy borrowed `attrs` into a fully owned value.
    pub fn from_attrs(allocator: std.mem.Allocator, attrs: *const Attrs) !AttrsOwned {
        var owned = AttrsOwned{
            .allocator = allocator,
            .color_opt = attrs.color_opt,
            .family_owned = undefined,
            .stretch = attrs.stretch,
            .style = attrs.style,
            .weight = attrs.weight,
            .metadata = attrs.metadata,
            .cache_key_flags = attrs.cache_key_flags,
            .metrics_opt = attrs.metrics_opt,
            .letter_spacing_opt = attrs.letter_spacing_opt,
            .font_features = undefined,
            .text_decoration = attrs.text_decoration,
        };
        owned.family_owned = try FamilyOwned.from_family(allocator, attrs.family);
        errdefer owned.family_owned.deinit();
        owned.font_features = try attrs.font_features.clone_with(allocator);
        return owned;
    }

    /// Release the family name and feature list storage.
    pub fn deinit(self: *AttrsOwned) void {
        std.debug.assert(allocatorsEql(self.allocator, self.family_owned.allocator));
        std.debug.assert(allocatorsEql(self.allocator, self.font_features.allocator));
        self.family_owned.deinit();
        self.font_features.deinit();
    }

    /// Deep copy, rebinding the copy to `allocator`.
    pub fn clone_with(self: *const AttrsOwned, allocator: std.mem.Allocator) !AttrsOwned {
        var copy = AttrsOwned{
            .allocator = allocator,
            .color_opt = self.color_opt,
            .family_owned = undefined,
            .stretch = self.stretch,
            .style = self.style,
            .weight = self.weight,
            .metadata = self.metadata,
            .cache_key_flags = self.cache_key_flags,
            .metrics_opt = self.metrics_opt,
            .letter_spacing_opt = self.letter_spacing_opt,
            .font_features = undefined,
            .text_decoration = self.text_decoration,
        };
        copy.family_owned = try FamilyOwned.from_family(allocator, self.family_owned.as_family());
        errdefer copy.family_owned.deinit();
        copy.font_features = try self.font_features.clone_with(allocator);
        return copy;
    }

    /// Convert back to attributes.
    ///
    /// The returned `family` slice borrows from `self` and must not outlive
    /// it. The returned `font_features` is a fresh clone owned by the caller,
    /// which must release it with `deinit()`.
    pub fn to_attrs(self: *const AttrsOwned, allocator: std.mem.Allocator) !Attrs {
        var attrs = Attrs.init(allocator);
        errdefer attrs.deinit();
        attrs.color_opt = self.color_opt;
        attrs.family = self.family_owned.as_family();
        attrs.stretch = self.stretch;
        attrs.style = self.style;
        attrs.weight = self.weight;
        attrs.metadata = self.metadata;
        attrs.cache_key_flags = self.cache_key_flags;
        attrs.metrics_opt = self.metrics_opt;
        attrs.letter_spacing_opt = self.letter_spacing_opt;
        attrs.font_features.deinit();
        attrs.font_features = try self.font_features.clone_with(allocator);
        attrs.text_decoration = self.text_decoration;
        return attrs;
    }

    /// Value equality over every field.
    pub fn eql(self: *const AttrsOwned, other: *const AttrsOwned) bool {
        return opt_color_eql(self.color_opt, other.color_opt) and
            self.family_owned.eql(&other.family_owned) and
            self.stretch.eql(other.stretch) and
            self.style.eql(other.style) and
            self.weight.eql(other.weight) and
            self.metadata == other.metadata and
            self.cache_key_flags.eql(other.cache_key_flags) and
            opt_cache_metrics_eql(self.metrics_opt, other.metrics_opt) and
            opt_letter_spacing_eql(self.letter_spacing_opt, other.letter_spacing_opt) and
            self.font_features.eql(&other.font_features) and
            self.text_decoration.eql(other.text_decoration);
    }

    /// Feed every field into `hasher`.
    pub fn hash(self: *const AttrsOwned, hasher: *std.hash.Wyhash) void {
        hash_optional(hasher, self.color_opt);
        self.family_owned.hash(hasher);
        self.stretch.hash(hasher);
        self.style.hash(hasher);
        self.weight.hash(hasher);
        hash_usize(hasher, self.metadata);
        self.cache_key_flags.hash(hasher);
        hash_optional(hasher, self.metrics_opt);
        hash_optional(hasher, self.letter_spacing_opt);
        self.font_features.hash(hasher);
        self.text_decoration.hash(hasher);
    }
};

/// One attributed range: `[start, end)` carries `attrs`.
///
/// Spans in an `AttrsList` are always sorted, non-overlapping, and non-empty.
pub const Span = struct {
    /// Inclusive range start (byte index into the line).
    start: usize,
    /// Exclusive range end.
    end: usize,
    /// Attributes applied to `[start, end)`.
    attrs: AttrsOwned,

    /// Value equality.
    pub fn eql(self: *const Span, other: *const Span) bool {
        return self.start == other.start and self.end == other.end and
            self.attrs.eql(&other.attrs);
    }
};

/// Iterator over the spans of an `AttrsList`, in ascending order.
pub const SpanIterator = struct {
    /// Remaining spans.
    spans: []const Span,
    /// Next span index.
    index: usize = 0,

    /// Return the next span, or `null` when exhausted.
    pub fn next(self: *SpanIterator) ?*const Span {
        if (self.index >= self.spans.len) return null;
        const span = &self.spans[self.index];
        self.index += 1;
        return span;
    }
};

/// List of text attributes to apply to a line.
///
/// Holds default attributes plus a sorted, non-overlapping set of override
/// spans with rangemap-style insert semantics: `add_span()` overwrites any
/// overlapped portions, and adjacent spans with equal attributes merge.
pub const AttrsList = struct {
    /// Allocator backing defaults and spans.
    allocator: std.mem.Allocator,
    /// Default attributes used where no span applies.
    default_attrs: AttrsOwned,
    /// Sorted, non-overlapping override spans.
    spans: std.ArrayList(Span) = .empty,

    /// Create a list with the given default `Attrs`.
    pub fn init(allocator: std.mem.Allocator, attrs: *const Attrs) !AttrsList {
        return .{
            .allocator = allocator,
            .default_attrs = try AttrsOwned.from_attrs(allocator, attrs),
        };
    }

    /// Create a list from already-owned defaults, taking ownership of them.
    ///
    /// The caller must not use `owned` after this call.
    pub fn init_owned(allocator: std.mem.Allocator, owned: AttrsOwned) AttrsList {
        return .{ .allocator = allocator, .default_attrs = owned };
    }

    /// Release defaults and all spans.
    pub fn deinit(self: *AttrsList) void {
        self.clear_spans();
        self.spans.deinit(self.allocator);
        self.default_attrs.deinit();
    }

    /// Get the default `Attrs`.
    ///
    /// The returned `family` slice borrows from the list and the returned
    /// `font_features` is a fresh clone; the caller must call `deinit()` on
    /// the result.
    pub fn defaults(self: *const AttrsList, allocator: std.mem.Allocator) !Attrs {
        return self.default_attrs.to_attrs(allocator);
    }

    /// Borrow the current spans as a slice, in ascending order.
    pub fn spans_slice(self: *const AttrsList) []const Span {
        return self.spans.items;
    }

    /// Iterate over the current spans, in ascending order.
    pub fn spans_iter(self: *const AttrsList) SpanIterator {
        return .{ .spans = self.spans.items };
    }

    /// Number of override spans.
    pub fn span_count(self: *const AttrsList) usize {
        return self.spans.items.len;
    }

    /// Clear all override spans, keeping the defaults.
    pub fn clear_spans(self: *AttrsList) void {
        for (self.spans.items) |*span| span.attrs.deinit();
        self.spans.clearRetainingCapacity();
    }

    /// Add an attribute span, removing any overlapped portions of old spans.
    ///
    /// Empty ranges (`start >= end`) are ignored. After insertion, adjacent
    /// spans with equal attributes are merged.
    pub fn add_span(self: *AttrsList, start: usize, end: usize, attrs: *const Attrs) !void {
        // Empty or inverted ranges are not supported, even if by accident.
        if (start >= end) return;

        const allocator = self.allocator;

        // Clone the incoming attributes before mutating anything so a
        // failed allocation leaves the list untouched.
        var owned = try AttrsOwned.from_attrs(allocator, attrs);
        errdefer owned.deinit();

        // A span strictly containing [start, end) must contribute both a
        // left and a right fragment sharing its attributes, so pre-clone
        // the attributes for the right fragment. At most one span can
        // strictly contain the new range because spans never overlap.
        var right_clone: ?AttrsOwned = null;
        for (self.spans.items) |*span| {
            if (span.start < start and span.end > end) {
                right_clone = try span.attrs.clone_with(allocator);
                break;
            }
        }
        errdefer if (right_clone) |*rc| rc.deinit();

        // Reserve room for every kept span plus the new span and one extra
        // fragment, so all appends below are infallible.
        var rebuilt: std.ArrayList(Span) = .empty;
        try rebuilt.ensureTotalCapacity(allocator, self.spans.items.len + 2);

        var inserted = false;
        for (self.spans.items) |*span| {
            if (span.end <= start or span.start >= end) {
                // No overlap: lazily insert the new span first when this
                // kept span sorts after it.
                if (!inserted and span.start >= end) {
                    rebuilt.appendAssumeCapacity(.{ .start = start, .end = end, .attrs = owned });
                    inserted = true;
                }
                // Move ownership of the kept span.
                rebuilt.appendAssumeCapacity(span.*);
            } else {
                // Overlap: keep the non-overlapped fragments, if any.
                if (span.start < start) {
                    rebuilt.appendAssumeCapacity(.{
                        .start = span.start,
                        .end = start,
                        .attrs = span.attrs,
                    });
                }
                if (span.end > end) {
                    if (!inserted) {
                        rebuilt.appendAssumeCapacity(.{ .start = start, .end = end, .attrs = owned });
                        inserted = true;
                    }
                    // The strictly-containing case reuses the pre-made
                    // clone; otherwise the right fragment moves the
                    // original attributes.
                    const fragment_attrs = if (span.start < start) right_clone.? else span.attrs;
                    rebuilt.appendAssumeCapacity(.{
                        .start = end,
                        .end = span.end,
                        .attrs = fragment_attrs,
                    });
                } else if (span.start >= start) {
                    // Fully covered: drop and release.
                    span.attrs.deinit();
                }
                // Otherwise only a left fragment was kept (moved above) and
                // there is nothing to release.
            }
        }
        if (!inserted) {
            rebuilt.appendAssumeCapacity(.{ .start = start, .end = end, .attrs = owned });
        }

        // Merge adjacent spans with equal attributes. The absorbed span's
        // attributes are released; survivors keep their (moved) ownership.
        if (rebuilt.items.len > 0) {
            var kept: usize = 0;
            for (1..rebuilt.items.len) |src| {
                if (rebuilt.items[kept].end == rebuilt.items[src].start and
                    rebuilt.items[kept].attrs.eql(&rebuilt.items[src].attrs))
                {
                    rebuilt.items[kept].end = rebuilt.items[src].end;
                    rebuilt.items[src].attrs.deinit();
                } else {
                    kept += 1;
                    if (kept != src) rebuilt.items[kept] = rebuilt.items[src];
                }
            }
            rebuilt.items = rebuilt.items[0 .. kept + 1];
        }

        // Every old span was moved, cloned, or released above; only the
        // backing buffer remains, so free it without touching items.
        var old = self.spans;
        self.spans = rebuilt;
        old.deinit(allocator);
    }

    /// Get the attributes applying at `index`.
    ///
    /// Returns the span containing `index`, or the defaults when no span
    /// contains it. The result borrows from the list; later mutations may
    /// invalidate it.
    pub fn get_span(self: *const AttrsList, index: usize) *const AttrsOwned {
        var lo: usize = 0;
        var hi: usize = self.spans.items.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            const span = &self.spans.items[mid];
            if (index < span.start) {
                hi = mid;
            } else if (index >= span.end) {
                lo = mid + 1;
            } else {
                return &span.attrs;
            }
        }
        return &self.default_attrs;
    }

    /// Get the attributes applying at `index` as an owned `Attrs` value.
    ///
    /// Falls back to the defaults when no span contains `index`. The caller
    /// must call `deinit()` on the result.
    pub fn get_span_attrs(self: *const AttrsList, index: usize, allocator: std.mem.Allocator) !Attrs {
        return self.get_span(index).to_attrs(allocator);
    }

    /// Split the list at `index`, keeping `[0, index)` and returning a new
    /// list holding `[index, ...)` shifted down by `index`.
    ///
    /// A span straddling `index` is divided in both lists.
    pub fn split_off(self: *AttrsList, index: usize) !AttrsList {
        const allocator = self.allocator;

        var new_list = AttrsList.init_owned(allocator, try self.default_attrs.clone_with(allocator));
        errdefer new_list.deinit();

        // At most one span can straddle `index`; pre-clone its attributes
        // for the right-hand fragment before mutating anything.
        var right_clone: ?AttrsOwned = null;
        for (self.spans.items) |*span| {
            if (span.start < index and span.end > index) {
                right_clone = try span.attrs.clone_with(allocator);
                break;
            }
        }
        errdefer if (right_clone) |*rc| rc.deinit();

        // Count both sides so the appends below are infallible.
        var left_count: usize = 0;
        var right_count: usize = 0;
        for (self.spans.items) |*span| {
            if (span.end <= index) {
                left_count += 1;
            } else if (span.start >= index) {
                right_count += 1;
            } else {
                left_count += 1;
                right_count += 1;
            }
        }
        try new_list.spans.ensureTotalCapacity(allocator, right_count);
        var left: std.ArrayList(Span) = .empty;
        try left.ensureTotalCapacity(allocator, left_count);

        for (self.spans.items) |*span| {
            if (span.end <= index) {
                left.appendAssumeCapacity(span.*);
            } else if (span.start >= index) {
                new_list.spans.appendAssumeCapacity(.{
                    .start = span.start - index,
                    .end = span.end - index,
                    .attrs = span.attrs,
                });
            } else {
                left.appendAssumeCapacity(.{
                    .start = span.start,
                    .end = index,
                    .attrs = span.attrs,
                });
                new_list.spans.appendAssumeCapacity(.{
                    .start = 0,
                    .end = span.end - index,
                    .attrs = right_clone.?,
                });
            }
        }

        var old = self.spans;
        self.spans = left;
        old.deinit(allocator);
        return new_list;
    }

    /// Replace the defaults and clear all spans.
    ///
    /// Intentional visibility divergence: Rust declares this `pub(crate)`
    /// (`AttrsList::reset(mut self, ...) -> Self`, consuming). Zig has no
    /// `pub(crate)`, so this port exposes it as `pub` for the same crate-local
    /// reuse (buffer reuse paths) while keeping it out of the public shape
    /// docs. Signature also diverges on purpose: in-place `*AttrsList`
    /// (`!void`, fallible for allocation) instead of consuming `self`, to
    /// avoid moving heap-owned spans through the return value.
    pub fn reset(self: *AttrsList, default: *const Attrs) !void {
        const owned = try AttrsOwned.from_attrs(self.allocator, default);
        self.default_attrs.deinit();
        self.default_attrs = owned;
        self.clear_spans();
    }

    /// Value equality over defaults and spans.
    pub fn eql(self: *const AttrsList, other: *const AttrsList) bool {
        if (!self.default_attrs.eql(&other.default_attrs)) return false;
        if (self.spans.items.len != other.spans.items.len) return false;
        for (self.spans.items, other.spans.items) |*a, *b| {
            if (!a.eql(b)) return false;
        }
        return true;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "color bit packing" {
    const t = std.testing;

    const solid = Color.rgb(0x12, 0x34, 0x56);
    try t.expectEqual(@as(u32, 0xFF12_3456), solid.value);
    try t.expectEqual(@as(u8, 0x12), solid.r());
    try t.expectEqual(@as(u8, 0x34), solid.g());
    try t.expectEqual(@as(u8, 0x56), solid.b());
    try t.expectEqual(@as(u8, 0xFF), solid.a());

    const translucent = Color.rgba(0x12, 0x34, 0x56, 0x80);
    try t.expectEqual(@as(u32, 0x8012_3456), translucent.value);
    try t.expectEqual(@as(u8, 0x80), translucent.a());

    const tuple = solid.as_rgba_tuple();
    try t.expectEqual(@as(u8, 0x12), tuple[0]);
    try t.expectEqual(@as(u8, 0x34), tuple[1]);
    try t.expectEqual(@as(u8, 0x56), tuple[2]);
    try t.expectEqual(@as(u8, 0xFF), tuple[3]);
    try t.expectEqual([4]u8{ 0x12, 0x34, 0x56, 0xFF }, solid.as_rgba());

    try t.expect(solid.eql(Color.rgb(0x12, 0x34, 0x56)));
    try t.expect(!solid.eql(translucent));
    try t.expectEqual(std.math.Order.eq, solid.order(Color.rgb(0x12, 0x34, 0x56)));

    // Equal colors hash equally; different colors (very likely) do not.
    var h1 = std.hash.Wyhash.init(0);
    solid.hash(&h1);
    var h2 = std.hash.Wyhash.init(0);
    Color.rgb(0x12, 0x34, 0x56).hash(&h2);
    try t.expectEqual(h1.final(), h2.final());
    var h3 = std.hash.Wyhash.init(0);
    translucent.hash(&h3);
    try t.expect(h1.final() != h3.final());
}

test "feature enable and disable" {
    const t = std.testing;
    const alloc = t.allocator;

    var features = FontFeatures.init(alloc);
    defer features.deinit();

    _ = try features.enable(FeatureTag.kerning);
    try t.expectEqual(@as(usize, 1), features.count());
    try t.expect(features.get(0).tag.eql(FeatureTag.kerning));
    try t.expectEqual(@as(u32, 1), features.get(0).value);

    // Disabling appends a second setting (mirrors the Rust push semantics).
    _ = try features.disable(FeatureTag.kerning);
    try t.expectEqual(@as(usize, 2), features.count());
    try t.expectEqual(@as(u32, 0), features.get(1).value);

    _ = try features.set(FeatureTag.stylistic_set_1, 2);
    try t.expectEqual(@as(u32, 2), features.get(2).value);

    try t.expect(FeatureTag.kerning.eql(FeatureTag.new("kern")));
    try t.expect(!FeatureTag.kerning.eql(FeatureTag.standard_ligatures));
    try t.expectEqualStrings("liga", FeatureTag.standard_ligatures.as_bytes());

    // Equal lists compare and hash equally.
    var other = FontFeatures.init(alloc);
    defer other.deinit();
    _ = try other.enable(FeatureTag.kerning);
    _ = try other.disable(FeatureTag.kerning);
    _ = try other.set(FeatureTag.stylistic_set_1, 2);
    try t.expect(features.eql(&other));
    var h1 = std.hash.Wyhash.init(0);
    features.hash(&h1);
    var h2 = std.hash.Wyhash.init(0);
    other.hash(&h2);
    try t.expectEqual(h1.final(), h2.final());

    // Order matters.
    var reordered = FontFeatures.init(alloc);
    defer reordered.deinit();
    _ = try reordered.disable(FeatureTag.kerning);
    _ = try reordered.enable(FeatureTag.kerning);
    _ = try reordered.set(FeatureTag.stylistic_set_1, 2);
    try t.expect(!features.eql(&reordered));
}

test "attrs builder and compatible" {
    const t = std.testing;
    const alloc = t.allocator;

    var attrs = Attrs.init(alloc);
    defer attrs.deinit();

    // Defaults mirror Attrs::new: regular sans-serif, no overrides.
    try t.expect(attrs.color_opt == null);
    try t.expect(attrs.family.eql(.sans_serif));
    try t.expect(attrs.stretch.eql(.normal));
    try t.expect(attrs.style.eql(.normal));
    try t.expect(attrs.weight.eql(Weight.normal));
    try t.expectEqual(@as(usize, 0), attrs.metadata);
    try t.expect(attrs.metrics_opt == null);
    try t.expect(attrs.letter_spacing_opt == null);
    try t.expectEqual(@as(usize, 0), attrs.font_features.count());
    try t.expect(!attrs.text_decoration.has_decoration());

    // Builder chaining sets every field.
    _ = attrs.with_color(Color.rgb(1, 2, 3))
        .with_family(.{ .name = "Inter" })
        .with_stretch(.condensed)
        .with_style(.italic)
        .with_weight(Weight.bold)
        .with_metadata(7)
        .with_cache_key_flags(CacheKeyFlags.fake_italic)
        .with_metrics(Metrics.new(16, 20))
        .with_letter_spacing(0.5)
        .with_underline(.single)
        .with_underline_color(Color.rgb(4, 5, 6))
        .with_strikethrough()
        .with_strikethrough_color(Color.rgb(7, 8, 9))
        .with_overline()
        .with_overline_color(Color.rgb(10, 11, 12));

    try t.expect(attrs.color_opt.?.eql(Color.rgb(1, 2, 3)));
    try t.expect(attrs.family.eql(.{ .name = "Inter" }));
    try t.expect(attrs.stretch.eql(.condensed));
    try t.expect(attrs.style.eql(.italic));
    try t.expect(attrs.weight.eql(Weight.bold));
    try t.expectEqual(@as(usize, 7), attrs.metadata);
    try t.expect(attrs.cache_key_flags.contains(CacheKeyFlags.fake_italic));
    try t.expect(attrs.metrics_opt.?.eql(CacheMetrics.new(16, 20)));
    try t.expect(attrs.letter_spacing_opt.?.eql(.{ .value = 0.5 }));
    try t.expect(attrs.text_decoration.has_decoration());
    try t.expect(attrs.text_decoration.underline == .single);
    try t.expect(attrs.text_decoration.underline_color_opt.?.eql(Color.rgb(4, 5, 6)));
    try t.expect(attrs.text_decoration.strikethrough);
    try t.expect(attrs.text_decoration.overline);

    // compatible() only considers family/stretch/style/weight.
    var same_shape = try attrs.clone_with(alloc);
    defer same_shape.deinit();
    _ = same_shape.with_color(Color.rgb(9, 9, 9)).with_metadata(99);
    try t.expect(attrs.compatible(&same_shape));

    var other_weight = try attrs.clone_with(alloc);
    defer other_weight.deinit();
    _ = other_weight.with_weight(Weight.normal);
    try t.expect(!attrs.compatible(&other_weight));

    var other_family = try attrs.clone_with(alloc);
    defer other_family.deinit();
    _ = other_family.with_family(.serif);
    try t.expect(!attrs.compatible(&other_family));

    var other_stretch = try attrs.clone_with(alloc);
    defer other_stretch.deinit();
    _ = other_stretch.with_stretch(.normal);
    try t.expect(!attrs.compatible(&other_stretch));

    var other_style = try attrs.clone_with(alloc);
    defer other_style.deinit();
    _ = other_style.with_style(.normal);
    try t.expect(!attrs.compatible(&other_style));

    // Full equality covers every field; equal values hash equally.
    try t.expect(attrs.eql(&attrs));
    try t.expect(!attrs.eql(&same_shape));
    var h1 = std.hash.Wyhash.init(0);
    attrs.hash(&h1);
    var h2 = std.hash.Wyhash.init(0);
    attrs.hash(&h2);
    try t.expectEqual(h1.final(), h2.final());
}

test "attrs list add get merge" {
    const t = std.testing;
    const alloc = t.allocator;

    var default_attrs = Attrs.init(alloc);
    defer default_attrs.deinit();
    _ = default_attrs.with_color(Color.rgb(255, 0, 0));

    var list = try AttrsList.init(alloc, &default_attrs);
    defer list.deinit();

    // No spans: everything falls back to defaults.
    try t.expectEqual(@as(usize, 0), list.span_count());
    try t.expect(list.get_span(0).color_opt.?.eql(Color.rgb(255, 0, 0)));
    try t.expect(list.get_span(999).color_opt.?.eql(Color.rgb(255, 0, 0)));

    var blue = Attrs.init(alloc);
    defer blue.deinit();
    _ = blue.with_color(Color.rgb(0, 0, 255));

    var green = Attrs.init(alloc);
    defer green.deinit();
    _ = green.with_color(Color.rgb(0, 255, 0));

    try list.add_span(2, 8, &blue);
    try t.expectEqual(@as(usize, 1), list.span_count());
    try t.expect(list.get_span(1).color_opt.?.eql(Color.rgb(255, 0, 0)));
    try t.expect(list.get_span(2).color_opt.?.eql(Color.rgb(0, 0, 255)));
    try t.expect(list.get_span(7).color_opt.?.eql(Color.rgb(0, 0, 255)));
    try t.expect(list.get_span(8).color_opt.?.eql(Color.rgb(255, 0, 0)));

    // Overwriting the middle splits the span in two.
    try list.add_span(4, 6, &green);
    try t.expectEqual(@as(usize, 3), list.span_count());
    const spans = list.spans_slice();
    try t.expectEqual(@as(usize, 2), spans[0].start);
    try t.expectEqual(@as(usize, 4), spans[0].end);
    try t.expectEqual(@as(usize, 4), spans[1].start);
    try t.expectEqual(@as(usize, 6), spans[1].end);
    try t.expectEqual(@as(usize, 6), spans[2].start);
    try t.expectEqual(@as(usize, 8), spans[2].end);
    try t.expect(list.get_span(3).color_opt.?.eql(Color.rgb(0, 0, 255)));
    try t.expect(list.get_span(4).color_opt.?.eql(Color.rgb(0, 255, 0)));
    try t.expect(list.get_span(6).color_opt.?.eql(Color.rgb(0, 0, 255)));

    // Re-applying the original attributes merges everything back.
    try list.add_span(4, 6, &blue);
    try t.expectEqual(@as(usize, 1), list.span_count());
    try t.expectEqual(@as(usize, 2), list.spans_slice()[0].start);
    try t.expectEqual(@as(usize, 8), list.spans_slice()[0].end);

    // Adjacent inserts with equal attributes merge.
    list.clear_spans();
    try list.add_span(0, 2, &blue);
    try list.add_span(2, 4, &blue);
    try t.expectEqual(@as(usize, 1), list.span_count());
    try t.expectEqual(@as(usize, 0), list.spans_slice()[0].start);
    try t.expectEqual(@as(usize, 4), list.spans_slice()[0].end);

    // Adjacent inserts with different attributes stay separate.
    try list.add_span(4, 6, &green);
    try t.expectEqual(@as(usize, 2), list.span_count());

    // Empty and inverted ranges are ignored.
    try list.add_span(3, 3, &green);
    try list.add_span(5, 4, &green);
    try t.expectEqual(@as(usize, 2), list.span_count());

    // A fully covering span absorbs everything overlapped.
    try list.add_span(0, 10, &green);
    try t.expectEqual(@as(usize, 1), list.span_count());
    try t.expectEqual(@as(usize, 0), list.spans_slice()[0].start);
    try t.expectEqual(@as(usize, 10), list.spans_slice()[0].end);
    try t.expect(list.get_span(5).color_opt.?.eql(Color.rgb(0, 255, 0)));

    // Iterator visits spans in order.
    var it = list.spans_iter();
    const first = it.next().?;
    try t.expectEqual(@as(usize, 0), first.start);
    try t.expect(it.next() == null);

    // Owned Attrs view of a span, with defaults fallback.
    var span_attrs = try list.get_span_attrs(5, alloc);
    defer span_attrs.deinit();
    try t.expect(span_attrs.color_opt.?.eql(Color.rgb(0, 255, 0)));
    var fallback_attrs = try list.get_span_attrs(50, alloc);
    defer fallback_attrs.deinit();
    try t.expect(fallback_attrs.color_opt.?.eql(Color.rgb(255, 0, 0)));

    // Clearing restores pure defaults.
    list.clear_spans();
    try t.expectEqual(@as(usize, 0), list.span_count());
    try t.expect(list.get_span(5).color_opt.?.eql(Color.rgb(255, 0, 0)));
}

test "attrs list split off" {
    const t = std.testing;
    const alloc = t.allocator;

    var default_attrs = Attrs.init(alloc);
    defer default_attrs.deinit();

    var blue = Attrs.init(alloc);
    defer blue.deinit();
    _ = blue.with_color(Color.rgb(0, 0, 255));

    var green = Attrs.init(alloc);
    defer green.deinit();
    _ = green.with_color(Color.rgb(0, 255, 0));

    var list = try AttrsList.init(alloc, &default_attrs);
    defer list.deinit();
    try list.add_span(2, 8, &blue);
    try list.add_span(10, 12, &green);

    // Split inside the first span: it straddles in both halves.
    var right = try list.split_off(5);
    defer right.deinit();

    try t.expectEqual(@as(usize, 1), list.span_count());
    try t.expectEqual(@as(usize, 2), list.spans_slice()[0].start);
    try t.expectEqual(@as(usize, 5), list.spans_slice()[0].end);
    try t.expect(list.get_span(4).color_opt.?.eql(Color.rgb(0, 0, 255)));

    try t.expectEqual(@as(usize, 2), right.span_count());
    try t.expectEqual(@as(usize, 0), right.spans_slice()[0].start);
    try t.expectEqual(@as(usize, 3), right.spans_slice()[0].end);
    try t.expect(right.get_span(0).color_opt.?.eql(Color.rgb(0, 0, 255)));
    try t.expectEqual(@as(usize, 5), right.spans_slice()[1].start);
    try t.expectEqual(@as(usize, 7), right.spans_slice()[1].end);
    try t.expect(right.get_span(6).color_opt.?.eql(Color.rgb(0, 255, 0)));
    // Defaults survive the split on both sides.
    try t.expect(right.get_span(4).color_opt == null);

    // Split at zero moves everything to the new list unchanged.
    var everything = try right.split_off(0);
    defer everything.deinit();
    try t.expectEqual(@as(usize, 0), right.span_count());
    try t.expectEqual(@as(usize, 2), everything.span_count());
    try t.expectEqual(@as(usize, 0), everything.spans_slice()[0].start);
    try t.expectEqual(@as(usize, 3), everything.spans_slice()[0].end);

    // Split past the end leaves the list intact and returns an empty list.
    var empty = try everything.split_off(100);
    defer empty.deinit();
    try t.expectEqual(@as(usize, 0), empty.span_count());
    try t.expectEqual(@as(usize, 2), everything.span_count());
    try t.expect(everything.eql(&everything));
    try t.expect(!everything.eql(&empty));
}

test "letter spacing nan handling" {
    const t = std.testing;

    const nan_a: f32 = std.math.nan(f32);
    const nan_b: f32 = @bitCast(@as(u32, 0x7FC0_0001));
    const neg_nan: f32 = @bitCast(@as(u32, 0xFFC0_0000));

    const spacing_nan_a: LetterSpacing = .{ .value = nan_a };
    const spacing_nan_b: LetterSpacing = .{ .value = nan_b };
    const spacing_neg_nan: LetterSpacing = .{ .value = neg_nan };
    const spacing_one: LetterSpacing = .{ .value = 1.0 };

    // Any NaN equals any other NaN, but not a real number.
    try t.expect(spacing_nan_a.eql(spacing_nan_b));
    try t.expect(spacing_nan_a.eql(spacing_neg_nan));
    try t.expect(!spacing_nan_a.eql(spacing_one));
    try t.expect(!spacing_one.eql(spacing_nan_a));
    try t.expect(spacing_one.eql(.{ .value = 1.0 }));

    // NaN payloads canonicalize to the same hash.
    var h1 = std.hash.Wyhash.init(0);
    spacing_nan_a.hash(&h1);
    var h2 = std.hash.Wyhash.init(0);
    spacing_nan_b.hash(&h2);
    try t.expectEqual(h1.final(), h2.final());
    var h3 = std.hash.Wyhash.init(0);
    spacing_neg_nan.hash(&h3);
    try t.expectEqual(h1.final(), h3.final());

    // -0.0 and +0.0 compare and hash equally.
    const neg_zero: LetterSpacing = .{ .value = -0.0 };
    const pos_zero: LetterSpacing = .{ .value = 0.0 };
    try t.expect(neg_zero.eql(pos_zero));
    var h4 = std.hash.Wyhash.init(0);
    neg_zero.hash(&h4);
    var h5 = std.hash.Wyhash.init(0);
    pos_zero.hash(&h5);
    try t.expectEqual(h4.final(), h5.final());

    // Distinct values (very likely) hash distinctly.
    var h6 = std.hash.Wyhash.init(0);
    spacing_one.hash(&h6);
    try t.expect(h4.final() != h6.final());
}

test "family owned roundtrip" {
    const t = std.testing;
    const alloc = t.allocator;

    var named = try FamilyOwned.from_family(alloc, .{ .name = "Inter" });
    // Allocator is stored; `deinit()` takes no arguments.
    try t.expect(allocatorsEql(alloc, named.allocator));
    // `named` owns its copy, so it stays valid on its own.
    try t.expect(named.as_family().eql(.{ .name = "Inter" }));
    try t.expect(named.eql(&named));

    var named_clone = try named.clone_with(alloc);
    defer named_clone.deinit();
    try t.expect(allocatorsEql(alloc, named_clone.allocator));
    try t.expect(named.eql(&named_clone));
    var h1 = std.hash.Wyhash.init(0);
    named.hash(&h1);
    var h2 = std.hash.Wyhash.init(0);
    named_clone.hash(&h2);
    try t.expectEqual(h1.final(), h2.final());
    named.deinit();

    var generic = try FamilyOwned.from_family(alloc, .monospace);
    defer generic.deinit();
    try t.expect(allocatorsEql(alloc, generic.allocator));
    try t.expect(generic.as_family().eql(.monospace));
    try t.expect(!generic.eql(&named_clone));
}

test "family owned allocator rebinding" {
    const t = std.testing;
    const alloc = t.allocator;
    var buf: [256]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const other_alloc = fba.allocator();

    var owned = try FamilyOwned.from_family(other_alloc, .{ .name = "Inter" });
    defer owned.deinit();
    try t.expect(allocatorsEql(other_alloc, owned.allocator));
    try t.expect(!allocatorsEql(alloc, owned.allocator));

    // Rebind to the new allocator via `clone_with`.
    var rebound = try owned.clone_with(alloc);
    defer rebound.deinit();
    try t.expect(allocatorsEql(alloc, rebound.allocator));
    try t.expect(owned.eql(&rebound));
}

test "cache metrics roundtrip" {
    const t = std.testing;

    const metrics = Metrics.relative(16, 1.25);
    try t.expect(metrics.eql(Metrics.new(16, 20)));

    const scaled = Metrics.new(10, 12).scale(2);
    try t.expect(scaled.eql(Metrics.new(20, 24)));

    const cached = CacheMetrics.from_metrics(metrics);
    try t.expectEqual(@as(u32, @bitCast(@as(f32, 16))), cached.font_size_bits);
    try t.expect(cached.to_metrics().eql(metrics));
    try t.expect(cached.eql(CacheMetrics.new(16, 20)));

    var h1 = std.hash.Wyhash.init(0);
    cached.hash(&h1);
    var h2 = std.hash.Wyhash.init(0);
    CacheMetrics.new(16, 20).hash(&h2);
    try t.expectEqual(h1.final(), h2.final());
}

test "owned attrs and match attrs roundtrip" {
    const t = std.testing;
    const alloc = t.allocator;

    var attrs = Attrs.init(alloc);
    defer attrs.deinit();
    _ = attrs.with_color(Color.rgb(1, 2, 3))
        .with_family(.{ .name = "Inter" })
        .with_weight(Weight.bold)
        .with_underline(.double);
    _ = try attrs.font_features.enable(FeatureTag.kerning);

    var owned = try AttrsOwned.from_attrs(alloc, &attrs);
    defer owned.deinit();
    try t.expect(owned.color_opt.?.eql(Color.rgb(1, 2, 3)));
    try t.expect(owned.family_owned.as_family().eql(.{ .name = "Inter" }));
    try t.expectEqual(@as(usize, 1), owned.font_features.count());

    var back = try owned.to_attrs(alloc);
    defer back.deinit();
    try t.expect(back.eql(&attrs));

    var owned_clone = try owned.clone_with(alloc);
    defer owned_clone.deinit();
    try t.expect(owned.eql(&owned_clone));

    var match_attrs = try FontMatchAttrs.from_attrs(alloc, &attrs);
    defer match_attrs.deinit();
    var match_clone = try match_attrs.clone_with(alloc);
    defer match_clone.deinit();
    try t.expect(match_attrs.eql(&match_clone));

    // Same shaping key despite different colors.
    var recolored = try attrs.clone_with(alloc);
    defer recolored.deinit();
    _ = recolored.with_color(Color.rgb(9, 9, 9));
    var match_recolored = try FontMatchAttrs.from_attrs(alloc, &recolored);
    defer match_recolored.deinit();
    try t.expect(match_attrs.eql(&match_recolored));

    var h1 = std.hash.Wyhash.init(0);
    match_attrs.hash(&h1);
    var h2 = std.hash.Wyhash.init(0);
    match_recolored.hash(&h2);
    try t.expectEqual(h1.final(), h2.final());
}

test "attrs list reset and defaults" {
    const t = std.testing;
    const alloc = t.allocator;

    var first = Attrs.init(alloc);
    defer first.deinit();
    _ = first.with_color(Color.rgb(1, 1, 1));

    var second = Attrs.init(alloc);
    defer second.deinit();
    _ = second.with_color(Color.rgb(2, 2, 2));

    var span_attrs = Attrs.init(alloc);
    defer span_attrs.deinit();
    _ = span_attrs.with_color(Color.rgb(3, 3, 3));

    var list = try AttrsList.init(alloc, &first);
    defer list.deinit();
    try list.add_span(0, 4, &span_attrs);
    try t.expectEqual(@as(usize, 1), list.span_count());

    var got_defaults = try list.defaults(alloc);
    defer got_defaults.deinit();
    try t.expect(got_defaults.color_opt.?.eql(Color.rgb(1, 1, 1)));

    try list.reset(&second);
    try t.expectEqual(@as(usize, 0), list.span_count());
    try t.expect(list.get_span(0).color_opt.?.eql(Color.rgb(2, 2, 2)));

    var other = try AttrsList.init(alloc, &second);
    defer other.deinit();
    try t.expect(list.eql(&other));
}

test "with_font_features requires matching allocator" {
    const t = std.testing;
    const alloc = t.allocator;

    var attrs = Attrs.init(alloc);
    defer attrs.deinit();

    // Same-allocator move is allowed and keeps the stored allocator in sync.
    var features = FontFeatures.init(alloc);
    _ = try features.enable(FeatureTag.kerning);
    try t.expect(allocatorsEql(alloc, features.allocator));
    _ = attrs.with_font_features(features);
    try t.expect(allocatorsEql(alloc, attrs.font_features.allocator));
    try t.expectEqual(@as(usize, 1), attrs.font_features.count());
}

test "with_font_features wrong-allocator misuse must rebind via clone_with" {
    const t = std.testing;
    const alloc = t.allocator;
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const other_alloc = fba.allocator();

    var attrs = Attrs.init(alloc);
    defer attrs.deinit();

    var foreign = FontFeatures.init(other_alloc);
    _ = try foreign.enable(FeatureTag.kerning);
    try t.expect(!allocatorsEql(alloc, foreign.allocator));

    // Direct `with_font_features(foreign)` would trip the debug assert
    // (`allocatorsEql` fails) and — in release — desync `Attrs.allocator`
    // from `font_features.allocator`. Do NOT do that. Rebind first:
    const rebound = try foreign.clone_with(alloc);
    // `foreign` is still owned by the caller; release it with its own allocator.
    foreign.deinit();
    // Now the move is safe: allocators match.
    try t.expect(allocatorsEql(alloc, rebound.allocator));
    _ = attrs.with_font_features(rebound);
    try t.expectEqual(@as(usize, 1), attrs.font_features.count());
    try t.expect(attrs.font_features.get(0).tag.eql(FeatureTag.kerning));
}
