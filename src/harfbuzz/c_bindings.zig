const __root = @This();
pub const __builtin = @import("std").zig.c_translation.builtins;
pub const __helpers = @import("std").zig.c_translation.helpers;
pub const __u_char = u8;
pub const __u_short = c_ushort;
pub const __u_int = c_uint;
pub const __u_long = c_ulong;
pub const __int8_t = i8;
pub const __uint8_t = u8;
pub const __int16_t = c_short;
pub const __uint16_t = c_ushort;
pub const __int32_t = c_int;
pub const __uint32_t = c_uint;
pub const __int64_t = c_long;
pub const __uint64_t = c_ulong;
pub const __int_least8_t = __int8_t;
pub const __uint_least8_t = __uint8_t;
pub const __int_least16_t = __int16_t;
pub const __uint_least16_t = __uint16_t;
pub const __int_least32_t = __int32_t;
pub const __uint_least32_t = __uint32_t;
pub const __int_least64_t = __int64_t;
pub const __uint_least64_t = __uint64_t;
pub const __quad_t = c_long;
pub const __u_quad_t = c_ulong;
pub const __intmax_t = c_long;
pub const __uintmax_t = c_ulong;
pub const __dev_t = c_ulong;
pub const __uid_t = c_uint;
pub const __gid_t = c_uint;
pub const __ino_t = c_ulong;
pub const __ino64_t = c_ulong;
pub const __mode_t = c_uint;
pub const __nlink_t = c_ulong;
pub const __off_t = c_long;
pub const __off64_t = c_long;
pub const __pid_t = c_int;
pub const __fsid_t = extern struct {
    __val: [2]c_int = @import("std").mem.zeroes([2]c_int),
};
pub const __clock_t = c_long;
pub const __rlim_t = c_ulong;
pub const __rlim64_t = c_ulong;
pub const __id_t = c_uint;
pub const __time_t = c_long;
pub const __useconds_t = c_uint;
pub const __suseconds_t = c_long;
pub const __suseconds64_t = c_long;
pub const __daddr_t = c_int;
pub const __key_t = c_int;
pub const __clockid_t = c_int;
pub const __timer_t = ?*anyopaque;
pub const __blksize_t = c_long;
pub const __blkcnt_t = c_long;
pub const __blkcnt64_t = c_long;
pub const __fsblkcnt_t = c_ulong;
pub const __fsblkcnt64_t = c_ulong;
pub const __fsfilcnt_t = c_ulong;
pub const __fsfilcnt64_t = c_ulong;
pub const __fsword_t = c_long;
pub const __ssize_t = c_long;
pub const __syscall_slong_t = c_long;
pub const __syscall_ulong_t = c_ulong;
pub const __loff_t = __off64_t;
pub const __caddr_t = [*c]u8;
pub const __intptr_t = c_long;
pub const __socklen_t = c_uint;
pub const __sig_atomic_t = c_int;
pub const int_least8_t = __int_least8_t;
pub const int_least16_t = __int_least16_t;
pub const int_least32_t = __int_least32_t;
pub const int_least64_t = __int_least64_t;
pub const uint_least8_t = __uint_least8_t;
pub const uint_least16_t = __uint_least16_t;
pub const uint_least32_t = __uint_least32_t;
pub const uint_least64_t = __uint_least64_t;
pub const int_fast8_t = i8;
pub const int_fast16_t = c_long;
pub const int_fast32_t = c_long;
pub const int_fast64_t = c_long;
pub const uint_fast8_t = u8;
pub const uint_fast16_t = c_ulong;
pub const uint_fast32_t = c_ulong;
pub const uint_fast64_t = c_ulong;
pub const intmax_t = __intmax_t;
pub const uintmax_t = __uintmax_t;
pub const __gwchar_t = c_int;
pub const imaxdiv_t = extern struct {
    quot: c_long = 0,
    rem: c_long = 0,
};
pub extern fn imaxabs(__n: intmax_t) intmax_t;
pub extern fn imaxdiv(__numer: intmax_t, __denom: intmax_t) imaxdiv_t;
pub extern fn strtoimax(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) intmax_t;
pub extern fn strtoumax(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) uintmax_t;
pub extern fn wcstoimax(noalias __nptr: [*c]const __gwchar_t, noalias __endptr: [*c][*c]__gwchar_t, __base: c_int) intmax_t;
pub extern fn wcstoumax(noalias __nptr: [*c]const __gwchar_t, noalias __endptr: [*c][*c]__gwchar_t, __base: c_int) uintmax_t;
pub const ptrdiff_t = c_long;
pub const wchar_t = c_int;
pub const max_align_t = extern struct {
    __aro_max_align_ll: c_longlong = 0,
    __aro_max_align_ld: c_longdouble = 0,
};
pub const hb_bool_t = c_int;
pub const hb_codepoint_t = u32;
pub const hb_position_t = i32;
pub const hb_mask_t = u32;
pub const union__hb_var_int_t = extern union {
    u32: u32,
    i32: i32,
    u16: [2]u16,
    i16: [2]i16,
    u8: [4]u8,
    i8: [4]i8,
};
pub const hb_var_int_t = union__hb_var_int_t;
pub const union__hb_var_num_t = extern union {
    f: f32,
    u32: u32,
    i32: i32,
    u16: [2]u16,
    i16: [2]i16,
    u8: [4]u8,
    i8: [4]i8,
};
pub const hb_var_num_t = union__hb_var_num_t;
pub const hb_tag_t = u32;
pub extern fn hb_tag_from_string(str: [*c]const u8, len: c_int) hb_tag_t;
pub extern fn hb_tag_to_string(tag: hb_tag_t, buf: [*c]u8) void;
pub const HB_DIRECTION_INVALID: c_int = 0;
pub const HB_DIRECTION_LTR: c_int = 4;
pub const HB_DIRECTION_RTL: c_int = 5;
pub const HB_DIRECTION_TTB: c_int = 6;
pub const HB_DIRECTION_BTT: c_int = 7;
pub const hb_direction_t = c_uint;
pub extern fn hb_direction_from_string(str: [*c]const u8, len: c_int) hb_direction_t;
pub extern fn hb_direction_to_string(direction: hb_direction_t) [*c]const u8;
pub const struct_hb_language_impl_t = opaque {
    pub const hb_language_to_string = __root.hb_language_to_string;
    pub const hb_language_matches = __root.hb_language_matches;
    pub const string = __root.hb_language_to_string;
    pub const matches = __root.hb_language_matches;
};
pub const hb_language_t = ?*const struct_hb_language_impl_t;
pub extern fn hb_language_from_string(str: [*c]const u8, len: c_int) hb_language_t;
pub extern fn hb_language_to_string(language: hb_language_t) [*c]const u8;
pub extern fn hb_language_get_default() hb_language_t;
pub extern fn hb_language_matches(language: hb_language_t, specific: hb_language_t) hb_bool_t;
pub const HB_SCRIPT_COMMON: c_int = 1517910393;
pub const HB_SCRIPT_INHERITED: c_int = 1516858984;
pub const HB_SCRIPT_UNKNOWN: c_int = 1517976186;
pub const HB_SCRIPT_ARABIC: c_int = 1098015074;
pub const HB_SCRIPT_ARMENIAN: c_int = 1098018158;
pub const HB_SCRIPT_BENGALI: c_int = 1113943655;
pub const HB_SCRIPT_CYRILLIC: c_int = 1132032620;
pub const HB_SCRIPT_DEVANAGARI: c_int = 1147500129;
pub const HB_SCRIPT_GEORGIAN: c_int = 1197830002;
pub const HB_SCRIPT_GREEK: c_int = 1198679403;
pub const HB_SCRIPT_GUJARATI: c_int = 1198877298;
pub const HB_SCRIPT_GURMUKHI: c_int = 1198879349;
pub const HB_SCRIPT_HANGUL: c_int = 1214344807;
pub const HB_SCRIPT_HAN: c_int = 1214344809;
pub const HB_SCRIPT_HEBREW: c_int = 1214603890;
pub const HB_SCRIPT_HIRAGANA: c_int = 1214870113;
pub const HB_SCRIPT_KANNADA: c_int = 1265525857;
pub const HB_SCRIPT_KATAKANA: c_int = 1264676449;
pub const HB_SCRIPT_LAO: c_int = 1281453935;
pub const HB_SCRIPT_LATIN: c_int = 1281455214;
pub const HB_SCRIPT_MALAYALAM: c_int = 1298954605;
pub const HB_SCRIPT_ORIYA: c_int = 1332902241;
pub const HB_SCRIPT_TAMIL: c_int = 1415671148;
pub const HB_SCRIPT_TELUGU: c_int = 1415933045;
pub const HB_SCRIPT_THAI: c_int = 1416126825;
pub const HB_SCRIPT_TIBETAN: c_int = 1416192628;
pub const HB_SCRIPT_BOPOMOFO: c_int = 1114599535;
pub const HB_SCRIPT_BRAILLE: c_int = 1114792297;
pub const HB_SCRIPT_CANADIAN_SYLLABICS: c_int = 1130458739;
pub const HB_SCRIPT_CHEROKEE: c_int = 1130915186;
pub const HB_SCRIPT_ETHIOPIC: c_int = 1165256809;
pub const HB_SCRIPT_KHMER: c_int = 1265134962;
pub const HB_SCRIPT_MONGOLIAN: c_int = 1299148391;
pub const HB_SCRIPT_MYANMAR: c_int = 1299803506;
pub const HB_SCRIPT_OGHAM: c_int = 1332175213;
pub const HB_SCRIPT_RUNIC: c_int = 1383427698;
pub const HB_SCRIPT_SINHALA: c_int = 1399418472;
pub const HB_SCRIPT_SYRIAC: c_int = 1400468067;
pub const HB_SCRIPT_THAANA: c_int = 1416126817;
pub const HB_SCRIPT_YI: c_int = 1500080489;
pub const HB_SCRIPT_DESERET: c_int = 1148416628;
pub const HB_SCRIPT_GOTHIC: c_int = 1198486632;
pub const HB_SCRIPT_OLD_ITALIC: c_int = 1232363884;
pub const HB_SCRIPT_BUHID: c_int = 1114990692;
pub const HB_SCRIPT_HANUNOO: c_int = 1214344815;
pub const HB_SCRIPT_TAGALOG: c_int = 1416064103;
pub const HB_SCRIPT_TAGBANWA: c_int = 1415669602;
pub const HB_SCRIPT_CYPRIOT: c_int = 1131442804;
pub const HB_SCRIPT_LIMBU: c_int = 1281977698;
pub const HB_SCRIPT_LINEAR_B: c_int = 1281977954;
pub const HB_SCRIPT_OSMANYA: c_int = 1332964705;
pub const HB_SCRIPT_SHAVIAN: c_int = 1399349623;
pub const HB_SCRIPT_TAI_LE: c_int = 1415670885;
pub const HB_SCRIPT_UGARITIC: c_int = 1432838514;
pub const HB_SCRIPT_BUGINESE: c_int = 1114990441;
pub const HB_SCRIPT_COPTIC: c_int = 1131376756;
pub const HB_SCRIPT_GLAGOLITIC: c_int = 1198285159;
pub const HB_SCRIPT_KHAROSHTHI: c_int = 1265131890;
pub const HB_SCRIPT_NEW_TAI_LUE: c_int = 1415670901;
pub const HB_SCRIPT_OLD_PERSIAN: c_int = 1483761007;
pub const HB_SCRIPT_SYLOTI_NAGRI: c_int = 1400466543;
pub const HB_SCRIPT_TIFINAGH: c_int = 1415999079;
pub const HB_SCRIPT_BALINESE: c_int = 1113681001;
pub const HB_SCRIPT_CUNEIFORM: c_int = 1483961720;
pub const HB_SCRIPT_NKO: c_int = 1315663727;
pub const HB_SCRIPT_PHAGS_PA: c_int = 1349017959;
pub const HB_SCRIPT_PHOENICIAN: c_int = 1349021304;
pub const HB_SCRIPT_CARIAN: c_int = 1130459753;
pub const HB_SCRIPT_CHAM: c_int = 1130914157;
pub const HB_SCRIPT_KAYAH_LI: c_int = 1264675945;
pub const HB_SCRIPT_LEPCHA: c_int = 1281716323;
pub const HB_SCRIPT_LYCIAN: c_int = 1283023721;
pub const HB_SCRIPT_LYDIAN: c_int = 1283023977;
pub const HB_SCRIPT_OL_CHIKI: c_int = 1332503403;
pub const HB_SCRIPT_REJANG: c_int = 1382706791;
pub const HB_SCRIPT_SAURASHTRA: c_int = 1398895986;
pub const HB_SCRIPT_SUNDANESE: c_int = 1400204900;
pub const HB_SCRIPT_VAI: c_int = 1449224553;
pub const HB_SCRIPT_AVESTAN: c_int = 1098281844;
pub const HB_SCRIPT_BAMUM: c_int = 1113681269;
pub const HB_SCRIPT_EGYPTIAN_HIEROGLYPHS: c_int = 1164409200;
pub const HB_SCRIPT_IMPERIAL_ARAMAIC: c_int = 1098018153;
pub const HB_SCRIPT_INSCRIPTIONAL_PAHLAVI: c_int = 1349020777;
pub const HB_SCRIPT_INSCRIPTIONAL_PARTHIAN: c_int = 1349678185;
pub const HB_SCRIPT_JAVANESE: c_int = 1247901281;
pub const HB_SCRIPT_KAITHI: c_int = 1265920105;
pub const HB_SCRIPT_LISU: c_int = 1281979253;
pub const HB_SCRIPT_MEETEI_MAYEK: c_int = 1299473769;
pub const HB_SCRIPT_OLD_SOUTH_ARABIAN: c_int = 1398895202;
pub const HB_SCRIPT_OLD_TURKIC: c_int = 1332898664;
pub const HB_SCRIPT_SAMARITAN: c_int = 1398893938;
pub const HB_SCRIPT_TAI_THAM: c_int = 1281453665;
pub const HB_SCRIPT_TAI_VIET: c_int = 1415673460;
pub const HB_SCRIPT_BATAK: c_int = 1113683051;
pub const HB_SCRIPT_BRAHMI: c_int = 1114792296;
pub const HB_SCRIPT_MANDAIC: c_int = 1298230884;
pub const HB_SCRIPT_CHAKMA: c_int = 1130457965;
pub const HB_SCRIPT_MEROITIC_CURSIVE: c_int = 1298494051;
pub const HB_SCRIPT_MEROITIC_HIEROGLYPHS: c_int = 1298494063;
pub const HB_SCRIPT_MIAO: c_int = 1349284452;
pub const HB_SCRIPT_SHARADA: c_int = 1399353956;
pub const HB_SCRIPT_SORA_SOMPENG: c_int = 1399812705;
pub const HB_SCRIPT_TAKRI: c_int = 1415670642;
pub const HB_SCRIPT_BASSA_VAH: c_int = 1113682803;
pub const HB_SCRIPT_CAUCASIAN_ALBANIAN: c_int = 1097295970;
pub const HB_SCRIPT_DUPLOYAN: c_int = 1148547180;
pub const HB_SCRIPT_ELBASAN: c_int = 1164730977;
pub const HB_SCRIPT_GRANTHA: c_int = 1198678382;
pub const HB_SCRIPT_KHOJKI: c_int = 1265135466;
pub const HB_SCRIPT_KHUDAWADI: c_int = 1399418468;
pub const HB_SCRIPT_LINEAR_A: c_int = 1281977953;
pub const HB_SCRIPT_MAHAJANI: c_int = 1298229354;
pub const HB_SCRIPT_MANICHAEAN: c_int = 1298230889;
pub const HB_SCRIPT_MENDE_KIKAKUI: c_int = 1298493028;
pub const HB_SCRIPT_MODI: c_int = 1299145833;
pub const HB_SCRIPT_MRO: c_int = 1299345263;
pub const HB_SCRIPT_NABATAEAN: c_int = 1315070324;
pub const HB_SCRIPT_OLD_NORTH_ARABIAN: c_int = 1315009122;
pub const HB_SCRIPT_OLD_PERMIC: c_int = 1348825709;
pub const HB_SCRIPT_PAHAWH_HMONG: c_int = 1215131239;
pub const HB_SCRIPT_PALMYRENE: c_int = 1348562029;
pub const HB_SCRIPT_PAU_CIN_HAU: c_int = 1348564323;
pub const HB_SCRIPT_PSALTER_PAHLAVI: c_int = 1349020784;
pub const HB_SCRIPT_SIDDHAM: c_int = 1399415908;
pub const HB_SCRIPT_TIRHUTA: c_int = 1416196712;
pub const HB_SCRIPT_WARANG_CITI: c_int = 1466004065;
pub const HB_SCRIPT_AHOM: c_int = 1097363309;
pub const HB_SCRIPT_ANATOLIAN_HIEROGLYPHS: c_int = 1215067511;
pub const HB_SCRIPT_HATRAN: c_int = 1214346354;
pub const HB_SCRIPT_MULTANI: c_int = 1299541108;
pub const HB_SCRIPT_OLD_HUNGARIAN: c_int = 1215655527;
pub const HB_SCRIPT_SIGNWRITING: c_int = 1399287415;
pub const HB_SCRIPT_ADLAM: c_int = 1097100397;
pub const HB_SCRIPT_BHAIKSUKI: c_int = 1114139507;
pub const HB_SCRIPT_MARCHEN: c_int = 1298231907;
pub const HB_SCRIPT_OSAGE: c_int = 1332963173;
pub const HB_SCRIPT_TANGUT: c_int = 1415671399;
pub const HB_SCRIPT_NEWA: c_int = 1315272545;
pub const HB_SCRIPT_MASARAM_GONDI: c_int = 1198485101;
pub const HB_SCRIPT_NUSHU: c_int = 1316186229;
pub const HB_SCRIPT_SOYOMBO: c_int = 1399814511;
pub const HB_SCRIPT_ZANABAZAR_SQUARE: c_int = 1516334690;
pub const HB_SCRIPT_DOGRA: c_int = 1148151666;
pub const HB_SCRIPT_GUNJALA_GONDI: c_int = 1198485095;
pub const HB_SCRIPT_HANIFI_ROHINGYA: c_int = 1383032935;
pub const HB_SCRIPT_MAKASAR: c_int = 1298230113;
pub const HB_SCRIPT_MEDEFAIDRIN: c_int = 1298490470;
pub const HB_SCRIPT_OLD_SOGDIAN: c_int = 1399809903;
pub const HB_SCRIPT_SOGDIAN: c_int = 1399809892;
pub const HB_SCRIPT_ELYMAIC: c_int = 1164736877;
pub const HB_SCRIPT_NANDINAGARI: c_int = 1315008100;
pub const HB_SCRIPT_NYIAKENG_PUACHUE_HMONG: c_int = 1215131248;
pub const HB_SCRIPT_WANCHO: c_int = 1466132591;
pub const HB_SCRIPT_CHORASMIAN: c_int = 1130918515;
pub const HB_SCRIPT_DIVES_AKURU: c_int = 1147756907;
pub const HB_SCRIPT_KHITAN_SMALL_SCRIPT: c_int = 1265202291;
pub const HB_SCRIPT_YEZIDI: c_int = 1499822697;
pub const HB_SCRIPT_CYPRO_MINOAN: c_int = 1131441518;
pub const HB_SCRIPT_OLD_UYGHUR: c_int = 1333094258;
pub const HB_SCRIPT_TANGSA: c_int = 1416524641;
pub const HB_SCRIPT_TOTO: c_int = 1416590447;
pub const HB_SCRIPT_VITHKUQI: c_int = 1449751656;
pub const HB_SCRIPT_MATH: c_int = 1517122664;
pub const HB_SCRIPT_KAWI: c_int = 1264678761;
pub const HB_SCRIPT_NAG_MUNDARI: c_int = 1315006317;
pub const HB_SCRIPT_GARAY: c_int = 1197568609;
pub const HB_SCRIPT_GURUNG_KHEMA: c_int = 1198877544;
pub const HB_SCRIPT_KIRAT_RAI: c_int = 1265787241;
pub const HB_SCRIPT_OL_ONAL: c_int = 1332633967;
pub const HB_SCRIPT_SUNUWAR: c_int = 1400204917;
pub const HB_SCRIPT_TODHRI: c_int = 1416586354;
pub const HB_SCRIPT_TULU_TIGALARI: c_int = 1416983655;
pub const HB_SCRIPT_BERIA_ERFE: c_int = 1113944678;
pub const HB_SCRIPT_SIDETIC: c_int = 1399415924;
pub const HB_SCRIPT_TAI_YO: c_int = 1415674223;
pub const HB_SCRIPT_TOLONG_SIKI: c_int = 1416588403;
pub const HB_SCRIPT_INVALID: c_int = 0;
pub const _HB_SCRIPT_MAX_VALUE: c_int = 2147483647;
pub const _HB_SCRIPT_MAX_VALUE_SIGNED: c_int = 2147483647;
pub const hb_script_t = c_uint;
pub extern fn hb_script_from_iso15924_tag(tag: hb_tag_t) hb_script_t;
pub extern fn hb_script_from_string(str: [*c]const u8, len: c_int) hb_script_t;
pub extern fn hb_script_to_iso15924_tag(script: hb_script_t) hb_tag_t;
pub extern fn hb_script_get_horizontal_direction(script: hb_script_t) hb_direction_t;
pub const struct_hb_user_data_key_t = extern struct {
    unused: u8 = 0,
};
pub const hb_user_data_key_t = struct_hb_user_data_key_t;
pub const hb_destroy_func_t = ?*const fn (user_data: ?*anyopaque) callconv(.c) void;
pub const struct_hb_feature_t = extern struct {
    tag: hb_tag_t = 0,
    value: u32 = 0,
    start: c_uint = 0,
    end: c_uint = 0,
    pub const hb_feature_to_string = __root.hb_feature_to_string;
    pub const string = __root.hb_feature_to_string;
};
pub const hb_feature_t = struct_hb_feature_t;
pub extern fn hb_feature_from_string(str: [*c]const u8, len: c_int, feature: [*c]hb_feature_t) hb_bool_t;
pub extern fn hb_feature_to_string(feature: [*c]hb_feature_t, buf: [*c]u8, size: c_uint) void;
pub const struct_hb_variation_t = extern struct {
    tag: hb_tag_t = 0,
    value: f32 = 0,
    pub const hb_variation_to_string = __root.hb_variation_to_string;
    pub const string = __root.hb_variation_to_string;
};
pub const hb_variation_t = struct_hb_variation_t;
pub extern fn hb_variation_from_string(str: [*c]const u8, len: c_int, variation: [*c]hb_variation_t) hb_bool_t;
pub extern fn hb_variation_to_string(variation: [*c]hb_variation_t, buf: [*c]u8, size: c_uint) void;
pub const hb_color_t = u32;
pub extern fn hb_color_get_alpha(color: hb_color_t) u8;
pub extern fn hb_color_get_red(color: hb_color_t) u8;
pub extern fn hb_color_get_green(color: hb_color_t) u8;
pub extern fn hb_color_get_blue(color: hb_color_t) u8;
pub const struct_hb_glyph_extents_t = extern struct {
    x_bearing: hb_position_t = 0,
    y_bearing: hb_position_t = 0,
    width: hb_position_t = 0,
    height: hb_position_t = 0,
};
pub const hb_glyph_extents_t = struct_hb_glyph_extents_t;
pub const struct_hb_font_t = opaque {
    pub const hb_font_get_h_extents = __root.hb_font_get_h_extents;
    pub const hb_font_get_v_extents = __root.hb_font_get_v_extents;
    pub const hb_font_get_nominal_glyph = __root.hb_font_get_nominal_glyph;
    pub const hb_font_get_variation_glyph = __root.hb_font_get_variation_glyph;
    pub const hb_font_get_nominal_glyphs = __root.hb_font_get_nominal_glyphs;
    pub const hb_font_get_glyph_h_advance = __root.hb_font_get_glyph_h_advance;
    pub const hb_font_get_glyph_v_advance = __root.hb_font_get_glyph_v_advance;
    pub const hb_font_get_glyph_h_advances = __root.hb_font_get_glyph_h_advances;
    pub const hb_font_get_glyph_v_advances = __root.hb_font_get_glyph_v_advances;
    pub const hb_font_get_glyph_h_origin = __root.hb_font_get_glyph_h_origin;
    pub const hb_font_get_glyph_v_origin = __root.hb_font_get_glyph_v_origin;
    pub const hb_font_get_glyph_h_origins = __root.hb_font_get_glyph_h_origins;
    pub const hb_font_get_glyph_v_origins = __root.hb_font_get_glyph_v_origins;
    pub const hb_font_get_glyph_h_kerning = __root.hb_font_get_glyph_h_kerning;
    pub const hb_font_get_glyph_extents = __root.hb_font_get_glyph_extents;
    pub const hb_font_get_glyph_contour_point = __root.hb_font_get_glyph_contour_point;
    pub const hb_font_get_glyph_name = __root.hb_font_get_glyph_name;
    pub const hb_font_get_glyph_from_name = __root.hb_font_get_glyph_from_name;
    pub const hb_font_draw_glyph_or_fail = __root.hb_font_draw_glyph_or_fail;
    pub const hb_font_paint_glyph_or_fail = __root.hb_font_paint_glyph_or_fail;
    pub const hb_font_get_glyph = __root.hb_font_get_glyph;
    pub const hb_font_get_extents_for_direction = __root.hb_font_get_extents_for_direction;
    pub const hb_font_get_glyph_advance_for_direction = __root.hb_font_get_glyph_advance_for_direction;
    pub const hb_font_get_glyph_advances_for_direction = __root.hb_font_get_glyph_advances_for_direction;
    pub const hb_font_get_glyph_origin_for_direction = __root.hb_font_get_glyph_origin_for_direction;
    pub const hb_font_add_glyph_origin_for_direction = __root.hb_font_add_glyph_origin_for_direction;
    pub const hb_font_subtract_glyph_origin_for_direction = __root.hb_font_subtract_glyph_origin_for_direction;
    pub const hb_font_get_glyph_kerning_for_direction = __root.hb_font_get_glyph_kerning_for_direction;
    pub const hb_font_get_glyph_extents_for_origin = __root.hb_font_get_glyph_extents_for_origin;
    pub const hb_font_get_glyph_contour_point_for_origin = __root.hb_font_get_glyph_contour_point_for_origin;
    pub const hb_font_glyph_to_string = __root.hb_font_glyph_to_string;
    pub const hb_font_glyph_from_string = __root.hb_font_glyph_from_string;
    pub const hb_font_draw_glyph = __root.hb_font_draw_glyph;
    pub const hb_font_paint_glyph = __root.hb_font_paint_glyph;
    pub const hb_font_create_sub_font = __root.hb_font_create_sub_font;
    pub const hb_font_reference = __root.hb_font_reference;
    pub const hb_font_destroy = __root.hb_font_destroy;
    pub const hb_font_set_user_data = __root.hb_font_set_user_data;
    pub const hb_font_get_user_data = __root.hb_font_get_user_data;
    pub const hb_font_make_immutable = __root.hb_font_make_immutable;
    pub const hb_font_is_immutable = __root.hb_font_is_immutable;
    pub const hb_font_get_serial = __root.hb_font_get_serial;
    pub const hb_font_changed = __root.hb_font_changed;
    pub const hb_font_set_parent = __root.hb_font_set_parent;
    pub const hb_font_get_parent = __root.hb_font_get_parent;
    pub const hb_font_set_face = __root.hb_font_set_face;
    pub const hb_font_get_face = __root.hb_font_get_face;
    pub const hb_font_set_funcs = __root.hb_font_set_funcs;
    pub const hb_font_set_funcs_data = __root.hb_font_set_funcs_data;
    pub const hb_ot_font_set_funcs = __root.hb_ot_font_set_funcs;
    pub const hb_font_set_scale = __root.hb_font_set_scale;
    pub const hb_font_get_scale = __root.hb_font_get_scale;
    pub const hb_font_set_ppem = __root.hb_font_set_ppem;
    pub const hb_font_get_ppem = __root.hb_font_get_ppem;
    pub const hb_font_set_ptem = __root.hb_font_set_ptem;
    pub const hb_font_get_ptem = __root.hb_font_get_ptem;
    pub const hb_font_is_synthetic = __root.hb_font_is_synthetic;
    pub const hb_font_set_synthetic_bold = __root.hb_font_set_synthetic_bold;
    pub const hb_font_get_synthetic_bold = __root.hb_font_get_synthetic_bold;
    pub const hb_font_set_synthetic_slant = __root.hb_font_set_synthetic_slant;
    pub const hb_font_get_synthetic_slant = __root.hb_font_get_synthetic_slant;
    pub const hb_font_set_variations = __root.hb_font_set_variations;
    pub const hb_font_set_variation = __root.hb_font_set_variation;
    pub const hb_font_set_var_coords_design = __root.hb_font_set_var_coords_design;
    pub const hb_font_get_var_coords_design = __root.hb_font_get_var_coords_design;
    pub const hb_font_set_var_coords_normalized = __root.hb_font_set_var_coords_normalized;
    pub const hb_font_get_var_coords_normalized = __root.hb_font_get_var_coords_normalized;
    pub const hb_font_set_var_named_instance = __root.hb_font_set_var_named_instance;
    pub const hb_font_get_var_named_instance = __root.hb_font_get_var_named_instance;
    pub const hb_font_get_glyph_v_kerning = __root.hb_font_get_glyph_v_kerning;
    pub const hb_font_get_glyph_shape = __root.hb_font_get_glyph_shape;
    pub const hb_shape = __root.hb_shape;
    pub const hb_shape_full = __root.hb_shape_full;
    pub const hb_style_get_value = __root.hb_style_get_value;
    pub const hb_ft_font_get_ft_face = __root.hb_ft_font_get_ft_face;
    pub const hb_ft_font_lock_face = __root.hb_ft_font_lock_face;
    pub const hb_ft_font_unlock_face = __root.hb_ft_font_unlock_face;
    pub const hb_ft_font_set_load_flags = __root.hb_ft_font_set_load_flags;
    pub const hb_ft_font_get_load_flags = __root.hb_ft_font_get_load_flags;
    pub const hb_ft_font_changed = __root.hb_ft_font_changed;
    pub const hb_ft_hb_font_changed = __root.hb_ft_hb_font_changed;
    pub const hb_ft_font_set_funcs = __root.hb_ft_font_set_funcs;
    pub const hb_ft_font_get_face = __root.hb_ft_font_get_face;
    pub const extents = __root.hb_font_get_h_extents;
    pub const glyph = __root.hb_font_get_nominal_glyph;
    pub const glyphs = __root.hb_font_get_nominal_glyphs;
    pub const advance = __root.hb_font_get_glyph_h_advance;
    pub const advances = __root.hb_font_get_glyph_h_advances;
    pub const origin = __root.hb_font_get_glyph_h_origin;
    pub const origins = __root.hb_font_get_glyph_h_origins;
    pub const kerning = __root.hb_font_get_glyph_h_kerning;
    pub const point = __root.hb_font_get_glyph_contour_point;
    pub const name = __root.hb_font_get_glyph_name;
    pub const fail = __root.hb_font_draw_glyph_or_fail;
    pub const direction = __root.hb_font_get_extents_for_direction;
    pub const string = __root.hb_font_glyph_to_string;
    pub const font = __root.hb_font_create_sub_font;
    pub const reference = __root.hb_font_reference;
    pub const destroy = __root.hb_font_destroy;
    pub const data = __root.hb_font_set_user_data;
    pub const immutable = __root.hb_font_make_immutable;
    pub const serial = __root.hb_font_get_serial;
    pub const changed = __root.hb_font_changed;
    pub const parent = __root.hb_font_set_parent;
    pub const face = __root.hb_font_set_face;
    pub const funcs = __root.hb_font_set_funcs;
    pub const ot_funcs = __root.hb_ot_font_set_funcs;
    pub const scale = __root.hb_font_set_scale;
    pub const ppem = __root.hb_font_set_ppem;
    pub const ptem = __root.hb_font_set_ptem;
    pub const synthetic = __root.hb_font_is_synthetic;
    pub const bold = __root.hb_font_set_synthetic_bold;
    pub const slant = __root.hb_font_set_synthetic_slant;
    pub const variations = __root.hb_font_set_variations;
    pub const variation = __root.hb_font_set_variation;
    pub const design = __root.hb_font_set_var_coords_design;
    pub const normalized = __root.hb_font_set_var_coords_normalized;
    pub const instance = __root.hb_font_set_var_named_instance;
    pub const shape = __root.hb_font_get_glyph_shape;
    pub const full = __root.hb_shape_full;
    pub const value = __root.hb_style_get_value;
    pub const flags = __root.hb_ft_font_set_load_flags;
};
pub const hb_font_t = struct_hb_font_t;
pub extern fn hb_malloc(size: usize) ?*anyopaque;
pub extern fn hb_calloc(nmemb: usize, size: usize) ?*anyopaque;
pub extern fn hb_realloc(ptr: ?*anyopaque, size: usize) ?*anyopaque;
pub extern fn hb_free(ptr: ?*anyopaque) void;
pub const HB_MEMORY_MODE_DUPLICATE: c_int = 0;
pub const HB_MEMORY_MODE_READONLY: c_int = 1;
pub const HB_MEMORY_MODE_WRITABLE: c_int = 2;
pub const HB_MEMORY_MODE_READONLY_MAY_MAKE_WRITABLE: c_int = 3;
pub const hb_memory_mode_t = c_uint;
pub const struct_hb_blob_t = opaque {
    pub const hb_blob_create_sub_blob = __root.hb_blob_create_sub_blob;
    pub const hb_blob_copy_writable_or_fail = __root.hb_blob_copy_writable_or_fail;
    pub const hb_blob_reference = __root.hb_blob_reference;
    pub const hb_blob_destroy = __root.hb_blob_destroy;
    pub const hb_blob_set_user_data = __root.hb_blob_set_user_data;
    pub const hb_blob_get_user_data = __root.hb_blob_get_user_data;
    pub const hb_blob_make_immutable = __root.hb_blob_make_immutable;
    pub const hb_blob_is_immutable = __root.hb_blob_is_immutable;
    pub const hb_blob_get_length = __root.hb_blob_get_length;
    pub const hb_blob_get_data = __root.hb_blob_get_data;
    pub const hb_blob_get_data_writable = __root.hb_blob_get_data_writable;
    pub const hb_face_count = __root.hb_face_count;
    pub const hb_face_create = __root.hb_face_create;
    pub const hb_face_create_or_fail = __root.hb_face_create_or_fail;
    pub const hb_face_create_or_fail_using = __root.hb_face_create_or_fail_using;
    pub const hb_ft_face_create_from_blob_or_fail = __root.hb_ft_face_create_from_blob_or_fail;
    pub const blob = __root.hb_blob_create_sub_blob;
    pub const fail = __root.hb_blob_copy_writable_or_fail;
    pub const reference = __root.hb_blob_reference;
    pub const destroy = __root.hb_blob_destroy;
    pub const data = __root.hb_blob_set_user_data;
    pub const immutable = __root.hb_blob_make_immutable;
    pub const length = __root.hb_blob_get_length;
    pub const writable = __root.hb_blob_get_data_writable;
    pub const count = __root.hb_face_count;
    pub const create = __root.hb_face_create;
    pub const using = __root.hb_face_create_or_fail_using;
};
pub const hb_blob_t = struct_hb_blob_t;
pub extern fn hb_blob_create(data: [*c]const u8, length: c_uint, mode: hb_memory_mode_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) ?*hb_blob_t;
pub extern fn hb_blob_create_or_fail(data: [*c]const u8, length: c_uint, mode: hb_memory_mode_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) ?*hb_blob_t;
pub extern fn hb_blob_create_from_file(file_name: [*c]const u8) ?*hb_blob_t;
pub extern fn hb_blob_create_from_file_or_fail(file_name: [*c]const u8) ?*hb_blob_t;
pub extern fn hb_blob_create_sub_blob(parent: ?*hb_blob_t, offset: c_uint, length: c_uint) ?*hb_blob_t;
pub extern fn hb_blob_copy_writable_or_fail(blob: ?*hb_blob_t) ?*hb_blob_t;
pub extern fn hb_blob_get_empty() ?*hb_blob_t;
pub extern fn hb_blob_reference(blob: ?*hb_blob_t) ?*hb_blob_t;
pub extern fn hb_blob_destroy(blob: ?*hb_blob_t) void;
pub extern fn hb_blob_set_user_data(blob: ?*hb_blob_t, key: [*c]hb_user_data_key_t, data: ?*anyopaque, destroy: hb_destroy_func_t, replace: hb_bool_t) hb_bool_t;
pub extern fn hb_blob_get_user_data(blob: ?*const hb_blob_t, key: [*c]hb_user_data_key_t) ?*anyopaque;
pub extern fn hb_blob_make_immutable(blob: ?*hb_blob_t) void;
pub extern fn hb_blob_is_immutable(blob: ?*hb_blob_t) hb_bool_t;
pub extern fn hb_blob_get_length(blob: ?*hb_blob_t) c_uint;
pub extern fn hb_blob_get_data(blob: ?*hb_blob_t, length: [*c]c_uint) [*c]const u8;
pub extern fn hb_blob_get_data_writable(blob: ?*hb_blob_t, length: [*c]c_uint) [*c]u8;
pub const HB_UNICODE_GENERAL_CATEGORY_CONTROL: c_int = 0;
pub const HB_UNICODE_GENERAL_CATEGORY_FORMAT: c_int = 1;
pub const HB_UNICODE_GENERAL_CATEGORY_UNASSIGNED: c_int = 2;
pub const HB_UNICODE_GENERAL_CATEGORY_PRIVATE_USE: c_int = 3;
pub const HB_UNICODE_GENERAL_CATEGORY_SURROGATE: c_int = 4;
pub const HB_UNICODE_GENERAL_CATEGORY_LOWERCASE_LETTER: c_int = 5;
pub const HB_UNICODE_GENERAL_CATEGORY_MODIFIER_LETTER: c_int = 6;
pub const HB_UNICODE_GENERAL_CATEGORY_OTHER_LETTER: c_int = 7;
pub const HB_UNICODE_GENERAL_CATEGORY_TITLECASE_LETTER: c_int = 8;
pub const HB_UNICODE_GENERAL_CATEGORY_UPPERCASE_LETTER: c_int = 9;
pub const HB_UNICODE_GENERAL_CATEGORY_SPACING_MARK: c_int = 10;
pub const HB_UNICODE_GENERAL_CATEGORY_ENCLOSING_MARK: c_int = 11;
pub const HB_UNICODE_GENERAL_CATEGORY_NON_SPACING_MARK: c_int = 12;
pub const HB_UNICODE_GENERAL_CATEGORY_DECIMAL_NUMBER: c_int = 13;
pub const HB_UNICODE_GENERAL_CATEGORY_LETTER_NUMBER: c_int = 14;
pub const HB_UNICODE_GENERAL_CATEGORY_OTHER_NUMBER: c_int = 15;
pub const HB_UNICODE_GENERAL_CATEGORY_CONNECT_PUNCTUATION: c_int = 16;
pub const HB_UNICODE_GENERAL_CATEGORY_DASH_PUNCTUATION: c_int = 17;
pub const HB_UNICODE_GENERAL_CATEGORY_CLOSE_PUNCTUATION: c_int = 18;
pub const HB_UNICODE_GENERAL_CATEGORY_FINAL_PUNCTUATION: c_int = 19;
pub const HB_UNICODE_GENERAL_CATEGORY_INITIAL_PUNCTUATION: c_int = 20;
pub const HB_UNICODE_GENERAL_CATEGORY_OTHER_PUNCTUATION: c_int = 21;
pub const HB_UNICODE_GENERAL_CATEGORY_OPEN_PUNCTUATION: c_int = 22;
pub const HB_UNICODE_GENERAL_CATEGORY_CURRENCY_SYMBOL: c_int = 23;
pub const HB_UNICODE_GENERAL_CATEGORY_MODIFIER_SYMBOL: c_int = 24;
pub const HB_UNICODE_GENERAL_CATEGORY_MATH_SYMBOL: c_int = 25;
pub const HB_UNICODE_GENERAL_CATEGORY_OTHER_SYMBOL: c_int = 26;
pub const HB_UNICODE_GENERAL_CATEGORY_LINE_SEPARATOR: c_int = 27;
pub const HB_UNICODE_GENERAL_CATEGORY_PARAGRAPH_SEPARATOR: c_int = 28;
pub const HB_UNICODE_GENERAL_CATEGORY_SPACE_SEPARATOR: c_int = 29;
pub const hb_unicode_general_category_t = c_uint;
pub const HB_UNICODE_COMBINING_CLASS_NOT_REORDERED: c_int = 0;
pub const HB_UNICODE_COMBINING_CLASS_OVERLAY: c_int = 1;
pub const HB_UNICODE_COMBINING_CLASS_NUKTA: c_int = 7;
pub const HB_UNICODE_COMBINING_CLASS_KANA_VOICING: c_int = 8;
pub const HB_UNICODE_COMBINING_CLASS_VIRAMA: c_int = 9;
pub const HB_UNICODE_COMBINING_CLASS_CCC10: c_int = 10;
pub const HB_UNICODE_COMBINING_CLASS_CCC11: c_int = 11;
pub const HB_UNICODE_COMBINING_CLASS_CCC12: c_int = 12;
pub const HB_UNICODE_COMBINING_CLASS_CCC13: c_int = 13;
pub const HB_UNICODE_COMBINING_CLASS_CCC14: c_int = 14;
pub const HB_UNICODE_COMBINING_CLASS_CCC15: c_int = 15;
pub const HB_UNICODE_COMBINING_CLASS_CCC16: c_int = 16;
pub const HB_UNICODE_COMBINING_CLASS_CCC17: c_int = 17;
pub const HB_UNICODE_COMBINING_CLASS_CCC18: c_int = 18;
pub const HB_UNICODE_COMBINING_CLASS_CCC19: c_int = 19;
pub const HB_UNICODE_COMBINING_CLASS_CCC20: c_int = 20;
pub const HB_UNICODE_COMBINING_CLASS_CCC21: c_int = 21;
pub const HB_UNICODE_COMBINING_CLASS_CCC22: c_int = 22;
pub const HB_UNICODE_COMBINING_CLASS_CCC23: c_int = 23;
pub const HB_UNICODE_COMBINING_CLASS_CCC24: c_int = 24;
pub const HB_UNICODE_COMBINING_CLASS_CCC25: c_int = 25;
pub const HB_UNICODE_COMBINING_CLASS_CCC26: c_int = 26;
pub const HB_UNICODE_COMBINING_CLASS_CCC27: c_int = 27;
pub const HB_UNICODE_COMBINING_CLASS_CCC28: c_int = 28;
pub const HB_UNICODE_COMBINING_CLASS_CCC29: c_int = 29;
pub const HB_UNICODE_COMBINING_CLASS_CCC30: c_int = 30;
pub const HB_UNICODE_COMBINING_CLASS_CCC31: c_int = 31;
pub const HB_UNICODE_COMBINING_CLASS_CCC32: c_int = 32;
pub const HB_UNICODE_COMBINING_CLASS_CCC33: c_int = 33;
pub const HB_UNICODE_COMBINING_CLASS_CCC34: c_int = 34;
pub const HB_UNICODE_COMBINING_CLASS_CCC35: c_int = 35;
pub const HB_UNICODE_COMBINING_CLASS_CCC36: c_int = 36;
pub const HB_UNICODE_COMBINING_CLASS_CCC84: c_int = 84;
pub const HB_UNICODE_COMBINING_CLASS_CCC91: c_int = 91;
pub const HB_UNICODE_COMBINING_CLASS_CCC103: c_int = 103;
pub const HB_UNICODE_COMBINING_CLASS_CCC107: c_int = 107;
pub const HB_UNICODE_COMBINING_CLASS_CCC118: c_int = 118;
pub const HB_UNICODE_COMBINING_CLASS_CCC122: c_int = 122;
pub const HB_UNICODE_COMBINING_CLASS_CCC129: c_int = 129;
pub const HB_UNICODE_COMBINING_CLASS_CCC130: c_int = 130;
pub const HB_UNICODE_COMBINING_CLASS_CCC132: c_int = 132;
pub const HB_UNICODE_COMBINING_CLASS_ATTACHED_BELOW_LEFT: c_int = 200;
pub const HB_UNICODE_COMBINING_CLASS_ATTACHED_BELOW: c_int = 202;
pub const HB_UNICODE_COMBINING_CLASS_ATTACHED_ABOVE: c_int = 214;
pub const HB_UNICODE_COMBINING_CLASS_ATTACHED_ABOVE_RIGHT: c_int = 216;
pub const HB_UNICODE_COMBINING_CLASS_BELOW_LEFT: c_int = 218;
pub const HB_UNICODE_COMBINING_CLASS_BELOW: c_int = 220;
pub const HB_UNICODE_COMBINING_CLASS_BELOW_RIGHT: c_int = 222;
pub const HB_UNICODE_COMBINING_CLASS_LEFT: c_int = 224;
pub const HB_UNICODE_COMBINING_CLASS_RIGHT: c_int = 226;
pub const HB_UNICODE_COMBINING_CLASS_ABOVE_LEFT: c_int = 228;
pub const HB_UNICODE_COMBINING_CLASS_ABOVE: c_int = 230;
pub const HB_UNICODE_COMBINING_CLASS_ABOVE_RIGHT: c_int = 232;
pub const HB_UNICODE_COMBINING_CLASS_DOUBLE_BELOW: c_int = 233;
pub const HB_UNICODE_COMBINING_CLASS_DOUBLE_ABOVE: c_int = 234;
pub const HB_UNICODE_COMBINING_CLASS_IOTA_SUBSCRIPT: c_int = 240;
pub const HB_UNICODE_COMBINING_CLASS_INVALID: c_int = 255;
pub const hb_unicode_combining_class_t = c_uint;
pub const struct_hb_unicode_funcs_t = opaque {
    pub const hb_unicode_funcs_create = __root.hb_unicode_funcs_create;
    pub const hb_unicode_funcs_reference = __root.hb_unicode_funcs_reference;
    pub const hb_unicode_funcs_destroy = __root.hb_unicode_funcs_destroy;
    pub const hb_unicode_funcs_set_user_data = __root.hb_unicode_funcs_set_user_data;
    pub const hb_unicode_funcs_get_user_data = __root.hb_unicode_funcs_get_user_data;
    pub const hb_unicode_funcs_make_immutable = __root.hb_unicode_funcs_make_immutable;
    pub const hb_unicode_funcs_is_immutable = __root.hb_unicode_funcs_is_immutable;
    pub const hb_unicode_funcs_get_parent = __root.hb_unicode_funcs_get_parent;
    pub const hb_unicode_funcs_set_combining_class_func = __root.hb_unicode_funcs_set_combining_class_func;
    pub const hb_unicode_funcs_set_general_category_func = __root.hb_unicode_funcs_set_general_category_func;
    pub const hb_unicode_funcs_set_mirroring_func = __root.hb_unicode_funcs_set_mirroring_func;
    pub const hb_unicode_funcs_set_script_func = __root.hb_unicode_funcs_set_script_func;
    pub const hb_unicode_funcs_set_compose_func = __root.hb_unicode_funcs_set_compose_func;
    pub const hb_unicode_funcs_set_decompose_func = __root.hb_unicode_funcs_set_decompose_func;
    pub const hb_unicode_combining_class = __root.hb_unicode_combining_class;
    pub const hb_unicode_general_category = __root.hb_unicode_general_category;
    pub const hb_unicode_mirroring = __root.hb_unicode_mirroring;
    pub const hb_unicode_script = __root.hb_unicode_script;
    pub const hb_unicode_compose = __root.hb_unicode_compose;
    pub const hb_unicode_decompose = __root.hb_unicode_decompose;
    pub const hb_unicode_funcs_set_eastasian_width_func = __root.hb_unicode_funcs_set_eastasian_width_func;
    pub const hb_unicode_eastasian_width = __root.hb_unicode_eastasian_width;
    pub const hb_unicode_funcs_set_decompose_compatibility_func = __root.hb_unicode_funcs_set_decompose_compatibility_func;
    pub const hb_unicode_decompose_compatibility = __root.hb_unicode_decompose_compatibility;
    pub const create = __root.hb_unicode_funcs_create;
    pub const reference = __root.hb_unicode_funcs_reference;
    pub const destroy = __root.hb_unicode_funcs_destroy;
    pub const data = __root.hb_unicode_funcs_set_user_data;
    pub const immutable = __root.hb_unicode_funcs_make_immutable;
    pub const parent = __root.hb_unicode_funcs_get_parent;
    pub const func = __root.hb_unicode_funcs_set_combining_class_func;
    pub const class = __root.hb_unicode_combining_class;
    pub const category = __root.hb_unicode_general_category;
    pub const mirroring = __root.hb_unicode_mirroring;
    pub const script = __root.hb_unicode_script;
    pub const compose = __root.hb_unicode_compose;
    pub const decompose = __root.hb_unicode_decompose;
    pub const width = __root.hb_unicode_eastasian_width;
    pub const compatibility = __root.hb_unicode_decompose_compatibility;
};
pub const hb_unicode_funcs_t = struct_hb_unicode_funcs_t;
pub extern fn hb_unicode_funcs_get_default() ?*hb_unicode_funcs_t;
pub extern fn hb_unicode_funcs_create(parent: ?*hb_unicode_funcs_t) ?*hb_unicode_funcs_t;
pub extern fn hb_unicode_funcs_get_empty() ?*hb_unicode_funcs_t;
pub extern fn hb_unicode_funcs_reference(ufuncs: ?*hb_unicode_funcs_t) ?*hb_unicode_funcs_t;
pub extern fn hb_unicode_funcs_destroy(ufuncs: ?*hb_unicode_funcs_t) void;
pub extern fn hb_unicode_funcs_set_user_data(ufuncs: ?*hb_unicode_funcs_t, key: [*c]hb_user_data_key_t, data: ?*anyopaque, destroy: hb_destroy_func_t, replace: hb_bool_t) hb_bool_t;
pub extern fn hb_unicode_funcs_get_user_data(ufuncs: ?*const hb_unicode_funcs_t, key: [*c]hb_user_data_key_t) ?*anyopaque;
pub extern fn hb_unicode_funcs_make_immutable(ufuncs: ?*hb_unicode_funcs_t) void;
pub extern fn hb_unicode_funcs_is_immutable(ufuncs: ?*hb_unicode_funcs_t) hb_bool_t;
pub extern fn hb_unicode_funcs_get_parent(ufuncs: ?*hb_unicode_funcs_t) ?*hb_unicode_funcs_t;
pub const hb_unicode_combining_class_func_t = ?*const fn (ufuncs: ?*hb_unicode_funcs_t, unicode: hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) hb_unicode_combining_class_t;
pub const hb_unicode_general_category_func_t = ?*const fn (ufuncs: ?*hb_unicode_funcs_t, unicode: hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) hb_unicode_general_category_t;
pub const hb_unicode_mirroring_func_t = ?*const fn (ufuncs: ?*hb_unicode_funcs_t, unicode: hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) hb_codepoint_t;
pub const hb_unicode_script_func_t = ?*const fn (ufuncs: ?*hb_unicode_funcs_t, unicode: hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) hb_script_t;
pub const hb_unicode_compose_func_t = ?*const fn (ufuncs: ?*hb_unicode_funcs_t, a: hb_codepoint_t, b: hb_codepoint_t, ab: [*c]hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub const hb_unicode_decompose_func_t = ?*const fn (ufuncs: ?*hb_unicode_funcs_t, ab: hb_codepoint_t, a: [*c]hb_codepoint_t, b: [*c]hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub extern fn hb_unicode_funcs_set_combining_class_func(ufuncs: ?*hb_unicode_funcs_t, func: hb_unicode_combining_class_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_unicode_funcs_set_general_category_func(ufuncs: ?*hb_unicode_funcs_t, func: hb_unicode_general_category_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_unicode_funcs_set_mirroring_func(ufuncs: ?*hb_unicode_funcs_t, func: hb_unicode_mirroring_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_unicode_funcs_set_script_func(ufuncs: ?*hb_unicode_funcs_t, func: hb_unicode_script_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_unicode_funcs_set_compose_func(ufuncs: ?*hb_unicode_funcs_t, func: hb_unicode_compose_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_unicode_funcs_set_decompose_func(ufuncs: ?*hb_unicode_funcs_t, func: hb_unicode_decompose_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_unicode_combining_class(ufuncs: ?*hb_unicode_funcs_t, unicode: hb_codepoint_t) hb_unicode_combining_class_t;
pub extern fn hb_unicode_general_category(ufuncs: ?*hb_unicode_funcs_t, unicode: hb_codepoint_t) hb_unicode_general_category_t;
pub extern fn hb_unicode_mirroring(ufuncs: ?*hb_unicode_funcs_t, unicode: hb_codepoint_t) hb_codepoint_t;
pub extern fn hb_unicode_script(ufuncs: ?*hb_unicode_funcs_t, unicode: hb_codepoint_t) hb_script_t;
pub extern fn hb_unicode_compose(ufuncs: ?*hb_unicode_funcs_t, a: hb_codepoint_t, b: hb_codepoint_t, ab: [*c]hb_codepoint_t) hb_bool_t;
pub extern fn hb_unicode_decompose(ufuncs: ?*hb_unicode_funcs_t, ab: hb_codepoint_t, a: [*c]hb_codepoint_t, b: [*c]hb_codepoint_t) hb_bool_t;
pub const struct_hb_set_t = opaque {
    pub const hb_set_reference = __root.hb_set_reference;
    pub const hb_set_destroy = __root.hb_set_destroy;
    pub const hb_set_set_user_data = __root.hb_set_set_user_data;
    pub const hb_set_get_user_data = __root.hb_set_get_user_data;
    pub const hb_set_allocation_successful = __root.hb_set_allocation_successful;
    pub const hb_set_copy = __root.hb_set_copy;
    pub const hb_set_clear = __root.hb_set_clear;
    pub const hb_set_is_empty = __root.hb_set_is_empty;
    pub const hb_set_invert = __root.hb_set_invert;
    pub const hb_set_is_inverted = __root.hb_set_is_inverted;
    pub const hb_set_has = __root.hb_set_has;
    pub const hb_set_add = __root.hb_set_add;
    pub const hb_set_add_range = __root.hb_set_add_range;
    pub const hb_set_add_sorted_array = __root.hb_set_add_sorted_array;
    pub const hb_set_del = __root.hb_set_del;
    pub const hb_set_del_range = __root.hb_set_del_range;
    pub const hb_set_is_equal = __root.hb_set_is_equal;
    pub const hb_set_hash = __root.hb_set_hash;
    pub const hb_set_is_subset = __root.hb_set_is_subset;
    pub const hb_set_set = __root.hb_set_set;
    pub const hb_set_union = __root.hb_set_union;
    pub const hb_set_intersect = __root.hb_set_intersect;
    pub const hb_set_subtract = __root.hb_set_subtract;
    pub const hb_set_symmetric_difference = __root.hb_set_symmetric_difference;
    pub const hb_set_get_population = __root.hb_set_get_population;
    pub const hb_set_get_min = __root.hb_set_get_min;
    pub const hb_set_get_max = __root.hb_set_get_max;
    pub const hb_set_next = __root.hb_set_next;
    pub const hb_set_previous = __root.hb_set_previous;
    pub const hb_set_next_range = __root.hb_set_next_range;
    pub const hb_set_previous_range = __root.hb_set_previous_range;
    pub const hb_set_next_many = __root.hb_set_next_many;
    pub const reference = __root.hb_set_reference;
    pub const destroy = __root.hb_set_destroy;
    pub const data = __root.hb_set_set_user_data;
    pub const successful = __root.hb_set_allocation_successful;
    pub const copy = __root.hb_set_copy;
    pub const clear = __root.hb_set_clear;
    pub const empty = __root.hb_set_is_empty;
    pub const invert = __root.hb_set_invert;
    pub const inverted = __root.hb_set_is_inverted;
    pub const has = __root.hb_set_has;
    pub const add = __root.hb_set_add;
    pub const range = __root.hb_set_add_range;
    pub const array = __root.hb_set_add_sorted_array;
    pub const del = __root.hb_set_del;
    pub const equal = __root.hb_set_is_equal;
    pub const hash = __root.hb_set_hash;
    pub const subset = __root.hb_set_is_subset;
    pub const set = __root.hb_set_set;
    pub const @"union" = __root.hb_set_union;
    pub const intersect = __root.hb_set_intersect;
    pub const subtract = __root.hb_set_subtract;
    pub const difference = __root.hb_set_symmetric_difference;
    pub const population = __root.hb_set_get_population;
    pub const min = __root.hb_set_get_min;
    pub const max = __root.hb_set_get_max;
    pub const next = __root.hb_set_next;
    pub const previous = __root.hb_set_previous;
    pub const many = __root.hb_set_next_many;
};
pub const hb_set_t = struct_hb_set_t;
pub extern fn hb_set_create() ?*hb_set_t;
pub extern fn hb_set_get_empty() ?*hb_set_t;
pub extern fn hb_set_reference(set: ?*hb_set_t) ?*hb_set_t;
pub extern fn hb_set_destroy(set: ?*hb_set_t) void;
pub extern fn hb_set_set_user_data(set: ?*hb_set_t, key: [*c]hb_user_data_key_t, data: ?*anyopaque, destroy: hb_destroy_func_t, replace: hb_bool_t) hb_bool_t;
pub extern fn hb_set_get_user_data(set: ?*const hb_set_t, key: [*c]hb_user_data_key_t) ?*anyopaque;
pub extern fn hb_set_allocation_successful(set: ?*const hb_set_t) hb_bool_t;
pub extern fn hb_set_copy(set: ?*const hb_set_t) ?*hb_set_t;
pub extern fn hb_set_clear(set: ?*hb_set_t) void;
pub extern fn hb_set_is_empty(set: ?*const hb_set_t) hb_bool_t;
pub extern fn hb_set_invert(set: ?*hb_set_t) void;
pub extern fn hb_set_is_inverted(set: ?*const hb_set_t) hb_bool_t;
pub extern fn hb_set_has(set: ?*const hb_set_t, codepoint: hb_codepoint_t) hb_bool_t;
pub extern fn hb_set_add(set: ?*hb_set_t, codepoint: hb_codepoint_t) void;
pub extern fn hb_set_add_range(set: ?*hb_set_t, first: hb_codepoint_t, last: hb_codepoint_t) void;
pub extern fn hb_set_add_sorted_array(set: ?*hb_set_t, sorted_codepoints: [*c]const hb_codepoint_t, num_codepoints: c_uint) void;
pub extern fn hb_set_del(set: ?*hb_set_t, codepoint: hb_codepoint_t) void;
pub extern fn hb_set_del_range(set: ?*hb_set_t, first: hb_codepoint_t, last: hb_codepoint_t) void;
pub extern fn hb_set_is_equal(set: ?*const hb_set_t, other: ?*const hb_set_t) hb_bool_t;
pub extern fn hb_set_hash(set: ?*const hb_set_t) c_uint;
pub extern fn hb_set_is_subset(set: ?*const hb_set_t, larger_set: ?*const hb_set_t) hb_bool_t;
pub extern fn hb_set_set(set: ?*hb_set_t, other: ?*const hb_set_t) void;
pub extern fn hb_set_union(set: ?*hb_set_t, other: ?*const hb_set_t) void;
pub extern fn hb_set_intersect(set: ?*hb_set_t, other: ?*const hb_set_t) void;
pub extern fn hb_set_subtract(set: ?*hb_set_t, other: ?*const hb_set_t) void;
pub extern fn hb_set_symmetric_difference(set: ?*hb_set_t, other: ?*const hb_set_t) void;
pub extern fn hb_set_get_population(set: ?*const hb_set_t) c_uint;
pub extern fn hb_set_get_min(set: ?*const hb_set_t) hb_codepoint_t;
pub extern fn hb_set_get_max(set: ?*const hb_set_t) hb_codepoint_t;
pub extern fn hb_set_next(set: ?*const hb_set_t, codepoint: [*c]hb_codepoint_t) hb_bool_t;
pub extern fn hb_set_previous(set: ?*const hb_set_t, codepoint: [*c]hb_codepoint_t) hb_bool_t;
pub extern fn hb_set_next_range(set: ?*const hb_set_t, first: [*c]hb_codepoint_t, last: [*c]hb_codepoint_t) hb_bool_t;
pub extern fn hb_set_previous_range(set: ?*const hb_set_t, first: [*c]hb_codepoint_t, last: [*c]hb_codepoint_t) hb_bool_t;
pub extern fn hb_set_next_many(set: ?*const hb_set_t, codepoint: hb_codepoint_t, out: [*c]hb_codepoint_t, size: c_uint) c_uint;
pub const struct_hb_map_t = opaque {
    pub const hb_map_reference = __root.hb_map_reference;
    pub const hb_map_destroy = __root.hb_map_destroy;
    pub const hb_map_set_user_data = __root.hb_map_set_user_data;
    pub const hb_map_get_user_data = __root.hb_map_get_user_data;
    pub const hb_map_allocation_successful = __root.hb_map_allocation_successful;
    pub const hb_map_copy = __root.hb_map_copy;
    pub const hb_map_clear = __root.hb_map_clear;
    pub const hb_map_is_empty = __root.hb_map_is_empty;
    pub const hb_map_get_population = __root.hb_map_get_population;
    pub const hb_map_is_equal = __root.hb_map_is_equal;
    pub const hb_map_hash = __root.hb_map_hash;
    pub const hb_map_set = __root.hb_map_set;
    pub const hb_map_get = __root.hb_map_get;
    pub const hb_map_del = __root.hb_map_del;
    pub const hb_map_has = __root.hb_map_has;
    pub const hb_map_update = __root.hb_map_update;
    pub const hb_map_next = __root.hb_map_next;
    pub const hb_map_keys = __root.hb_map_keys;
    pub const hb_map_values = __root.hb_map_values;
    pub const reference = __root.hb_map_reference;
    pub const destroy = __root.hb_map_destroy;
    pub const data = __root.hb_map_set_user_data;
    pub const successful = __root.hb_map_allocation_successful;
    pub const copy = __root.hb_map_copy;
    pub const clear = __root.hb_map_clear;
    pub const empty = __root.hb_map_is_empty;
    pub const population = __root.hb_map_get_population;
    pub const equal = __root.hb_map_is_equal;
    pub const hash = __root.hb_map_hash;
    pub const set = __root.hb_map_set;
    pub const get = __root.hb_map_get;
    pub const del = __root.hb_map_del;
    pub const has = __root.hb_map_has;
    pub const update = __root.hb_map_update;
    pub const next = __root.hb_map_next;
    pub const keys = __root.hb_map_keys;
    pub const values = __root.hb_map_values;
};
pub const hb_map_t = struct_hb_map_t;
pub extern fn hb_map_create() ?*hb_map_t;
pub extern fn hb_map_get_empty() ?*hb_map_t;
pub extern fn hb_map_reference(map: ?*hb_map_t) ?*hb_map_t;
pub extern fn hb_map_destroy(map: ?*hb_map_t) void;
pub extern fn hb_map_set_user_data(map: ?*hb_map_t, key: [*c]hb_user_data_key_t, data: ?*anyopaque, destroy: hb_destroy_func_t, replace: hb_bool_t) hb_bool_t;
pub extern fn hb_map_get_user_data(map: ?*const hb_map_t, key: [*c]hb_user_data_key_t) ?*anyopaque;
pub extern fn hb_map_allocation_successful(map: ?*const hb_map_t) hb_bool_t;
pub extern fn hb_map_copy(map: ?*const hb_map_t) ?*hb_map_t;
pub extern fn hb_map_clear(map: ?*hb_map_t) void;
pub extern fn hb_map_is_empty(map: ?*const hb_map_t) hb_bool_t;
pub extern fn hb_map_get_population(map: ?*const hb_map_t) c_uint;
pub extern fn hb_map_is_equal(map: ?*const hb_map_t, other: ?*const hb_map_t) hb_bool_t;
pub extern fn hb_map_hash(map: ?*const hb_map_t) c_uint;
pub extern fn hb_map_set(map: ?*hb_map_t, key: hb_codepoint_t, value: hb_codepoint_t) void;
pub extern fn hb_map_get(map: ?*const hb_map_t, key: hb_codepoint_t) hb_codepoint_t;
pub extern fn hb_map_del(map: ?*hb_map_t, key: hb_codepoint_t) void;
pub extern fn hb_map_has(map: ?*const hb_map_t, key: hb_codepoint_t) hb_bool_t;
pub extern fn hb_map_update(map: ?*hb_map_t, other: ?*const hb_map_t) void;
pub extern fn hb_map_next(map: ?*const hb_map_t, idx: [*c]c_int, key: [*c]hb_codepoint_t, value: [*c]hb_codepoint_t) hb_bool_t;
pub extern fn hb_map_keys(map: ?*const hb_map_t, keys: ?*hb_set_t) void;
pub extern fn hb_map_values(map: ?*const hb_map_t, values: ?*hb_set_t) void;
pub extern fn hb_face_count(blob: ?*hb_blob_t) c_uint;
pub const struct_hb_face_t = opaque {
    pub const hb_face_reference = __root.hb_face_reference;
    pub const hb_face_destroy = __root.hb_face_destroy;
    pub const hb_face_set_user_data = __root.hb_face_set_user_data;
    pub const hb_face_get_user_data = __root.hb_face_get_user_data;
    pub const hb_face_make_immutable = __root.hb_face_make_immutable;
    pub const hb_face_is_immutable = __root.hb_face_is_immutable;
    pub const hb_face_reference_table = __root.hb_face_reference_table;
    pub const hb_face_reference_blob = __root.hb_face_reference_blob;
    pub const hb_face_set_index = __root.hb_face_set_index;
    pub const hb_face_get_index = __root.hb_face_get_index;
    pub const hb_face_set_upem = __root.hb_face_set_upem;
    pub const hb_face_get_upem = __root.hb_face_get_upem;
    pub const hb_face_set_glyph_count = __root.hb_face_set_glyph_count;
    pub const hb_face_get_glyph_count = __root.hb_face_get_glyph_count;
    pub const hb_face_set_get_table_tags_func = __root.hb_face_set_get_table_tags_func;
    pub const hb_face_get_table_tags = __root.hb_face_get_table_tags;
    pub const hb_face_collect_unicodes = __root.hb_face_collect_unicodes;
    pub const hb_face_collect_nominal_glyph_mapping = __root.hb_face_collect_nominal_glyph_mapping;
    pub const hb_face_collect_variation_selectors = __root.hb_face_collect_variation_selectors;
    pub const hb_face_collect_variation_unicodes = __root.hb_face_collect_variation_unicodes;
    pub const hb_face_builder_add_table = __root.hb_face_builder_add_table;
    pub const hb_face_builder_sort_tables = __root.hb_face_builder_sort_tables;
    pub const hb_font_create = __root.hb_font_create;
    pub const hb_shape_plan_create = __root.hb_shape_plan_create;
    pub const hb_shape_plan_create_cached = __root.hb_shape_plan_create_cached;
    pub const hb_shape_plan_create2 = __root.hb_shape_plan_create2;
    pub const hb_shape_plan_create_cached2 = __root.hb_shape_plan_create_cached2;
    pub const reference = __root.hb_face_reference;
    pub const destroy = __root.hb_face_destroy;
    pub const data = __root.hb_face_set_user_data;
    pub const immutable = __root.hb_face_make_immutable;
    pub const table = __root.hb_face_reference_table;
    pub const blob = __root.hb_face_reference_blob;
    pub const upem = __root.hb_face_set_upem;
    pub const count = __root.hb_face_set_glyph_count;
    pub const func = __root.hb_face_set_get_table_tags_func;
    pub const tags = __root.hb_face_get_table_tags;
    pub const unicodes = __root.hb_face_collect_unicodes;
    pub const mapping = __root.hb_face_collect_nominal_glyph_mapping;
    pub const selectors = __root.hb_face_collect_variation_selectors;
    pub const tables = __root.hb_face_builder_sort_tables;
    pub const create = __root.hb_font_create;
    pub const cached = __root.hb_shape_plan_create_cached;
    pub const create2 = __root.hb_shape_plan_create2;
    pub const cached2 = __root.hb_shape_plan_create_cached2;
};
pub const hb_face_t = struct_hb_face_t;
pub extern fn hb_face_create(blob: ?*hb_blob_t, index: c_uint) ?*hb_face_t;
pub extern fn hb_face_create_or_fail(blob: ?*hb_blob_t, index: c_uint) ?*hb_face_t;
pub extern fn hb_face_create_or_fail_using(blob: ?*hb_blob_t, index: c_uint, loader_name: [*c]const u8) ?*hb_face_t;
pub extern fn hb_face_create_from_file_or_fail(file_name: [*c]const u8, index: c_uint) ?*hb_face_t;
pub extern fn hb_face_create_from_file_or_fail_using(file_name: [*c]const u8, index: c_uint, loader_name: [*c]const u8) ?*hb_face_t;
pub extern fn hb_face_list_loaders() [*c][*c]const u8;
pub const hb_reference_table_func_t = ?*const fn (face: ?*hb_face_t, tag: hb_tag_t, user_data: ?*anyopaque) callconv(.c) ?*hb_blob_t;
pub extern fn hb_face_create_for_tables(reference_table_func: hb_reference_table_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) ?*hb_face_t;
pub extern fn hb_face_get_empty() ?*hb_face_t;
pub extern fn hb_face_reference(face: ?*hb_face_t) ?*hb_face_t;
pub extern fn hb_face_destroy(face: ?*hb_face_t) void;
pub extern fn hb_face_set_user_data(face: ?*hb_face_t, key: [*c]hb_user_data_key_t, data: ?*anyopaque, destroy: hb_destroy_func_t, replace: hb_bool_t) hb_bool_t;
pub extern fn hb_face_get_user_data(face: ?*const hb_face_t, key: [*c]hb_user_data_key_t) ?*anyopaque;
pub extern fn hb_face_make_immutable(face: ?*hb_face_t) void;
pub extern fn hb_face_is_immutable(face: ?*hb_face_t) hb_bool_t;
pub extern fn hb_face_reference_table(face: ?*const hb_face_t, tag: hb_tag_t) ?*hb_blob_t;
pub extern fn hb_face_reference_blob(face: ?*hb_face_t) ?*hb_blob_t;
pub extern fn hb_face_set_index(face: ?*hb_face_t, index: c_uint) void;
pub extern fn hb_face_get_index(face: ?*const hb_face_t) c_uint;
pub extern fn hb_face_set_upem(face: ?*hb_face_t, upem: c_uint) void;
pub extern fn hb_face_get_upem(face: ?*const hb_face_t) c_uint;
pub extern fn hb_face_set_glyph_count(face: ?*hb_face_t, glyph_count: c_uint) void;
pub extern fn hb_face_get_glyph_count(face: ?*const hb_face_t) c_uint;
pub const hb_get_table_tags_func_t = ?*const fn (face: ?*const hb_face_t, start_offset: c_uint, table_count: [*c]c_uint, table_tags: [*c]hb_tag_t, user_data: ?*anyopaque) callconv(.c) c_uint;
pub extern fn hb_face_set_get_table_tags_func(face: ?*hb_face_t, func: hb_get_table_tags_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_face_get_table_tags(face: ?*const hb_face_t, start_offset: c_uint, table_count: [*c]c_uint, table_tags: [*c]hb_tag_t) c_uint;
pub extern fn hb_face_collect_unicodes(face: ?*hb_face_t, out: ?*hb_set_t) void;
pub extern fn hb_face_collect_nominal_glyph_mapping(face: ?*hb_face_t, mapping: ?*hb_map_t, unicodes: ?*hb_set_t) void;
pub extern fn hb_face_collect_variation_selectors(face: ?*hb_face_t, out: ?*hb_set_t) void;
pub extern fn hb_face_collect_variation_unicodes(face: ?*hb_face_t, variation_selector: hb_codepoint_t, out: ?*hb_set_t) void;
pub extern fn hb_face_builder_create() ?*hb_face_t;
pub extern fn hb_face_builder_add_table(face: ?*hb_face_t, tag: hb_tag_t, blob: ?*hb_blob_t) hb_bool_t;
pub extern fn hb_face_builder_sort_tables(face: ?*hb_face_t, tags: [*c]const hb_tag_t) void;
pub const struct_hb_draw_state_t = extern struct {
    path_open: hb_bool_t = 0,
    path_start_x: f32 = 0,
    path_start_y: f32 = 0,
    current_x: f32 = 0,
    current_y: f32 = 0,
    reserved1: hb_var_num_t = @import("std").mem.zeroes(hb_var_num_t),
    reserved2: hb_var_num_t = @import("std").mem.zeroes(hb_var_num_t),
    reserved3: hb_var_num_t = @import("std").mem.zeroes(hb_var_num_t),
    reserved4: hb_var_num_t = @import("std").mem.zeroes(hb_var_num_t),
    reserved5: hb_var_num_t = @import("std").mem.zeroes(hb_var_num_t),
    reserved6: hb_var_num_t = @import("std").mem.zeroes(hb_var_num_t),
    reserved7: hb_var_num_t = @import("std").mem.zeroes(hb_var_num_t),
};
pub const hb_draw_state_t = struct_hb_draw_state_t;
pub const struct_hb_draw_funcs_t = opaque {
    pub const hb_draw_funcs_set_move_to_func = __root.hb_draw_funcs_set_move_to_func;
    pub const hb_draw_funcs_set_line_to_func = __root.hb_draw_funcs_set_line_to_func;
    pub const hb_draw_funcs_set_quadratic_to_func = __root.hb_draw_funcs_set_quadratic_to_func;
    pub const hb_draw_funcs_set_cubic_to_func = __root.hb_draw_funcs_set_cubic_to_func;
    pub const hb_draw_funcs_set_close_path_func = __root.hb_draw_funcs_set_close_path_func;
    pub const hb_draw_funcs_reference = __root.hb_draw_funcs_reference;
    pub const hb_draw_funcs_destroy = __root.hb_draw_funcs_destroy;
    pub const hb_draw_funcs_set_user_data = __root.hb_draw_funcs_set_user_data;
    pub const hb_draw_funcs_get_user_data = __root.hb_draw_funcs_get_user_data;
    pub const hb_draw_funcs_make_immutable = __root.hb_draw_funcs_make_immutable;
    pub const hb_draw_funcs_is_immutable = __root.hb_draw_funcs_is_immutable;
    pub const hb_draw_move_to = __root.hb_draw_move_to;
    pub const hb_draw_line_to = __root.hb_draw_line_to;
    pub const hb_draw_quadratic_to = __root.hb_draw_quadratic_to;
    pub const hb_draw_cubic_to = __root.hb_draw_cubic_to;
    pub const hb_draw_close_path = __root.hb_draw_close_path;
    pub const func = __root.hb_draw_funcs_set_move_to_func;
    pub const reference = __root.hb_draw_funcs_reference;
    pub const destroy = __root.hb_draw_funcs_destroy;
    pub const data = __root.hb_draw_funcs_set_user_data;
    pub const immutable = __root.hb_draw_funcs_make_immutable;
    pub const to = __root.hb_draw_move_to;
    pub const path = __root.hb_draw_close_path;
};
pub const hb_draw_funcs_t = struct_hb_draw_funcs_t;
pub const hb_draw_move_to_func_t = ?*const fn (dfuncs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque, st: [*c]hb_draw_state_t, to_x: f32, to_y: f32, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_draw_line_to_func_t = ?*const fn (dfuncs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque, st: [*c]hb_draw_state_t, to_x: f32, to_y: f32, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_draw_quadratic_to_func_t = ?*const fn (dfuncs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque, st: [*c]hb_draw_state_t, control_x: f32, control_y: f32, to_x: f32, to_y: f32, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_draw_cubic_to_func_t = ?*const fn (dfuncs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque, st: [*c]hb_draw_state_t, control1_x: f32, control1_y: f32, control2_x: f32, control2_y: f32, to_x: f32, to_y: f32, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_draw_close_path_func_t = ?*const fn (dfuncs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque, st: [*c]hb_draw_state_t, user_data: ?*anyopaque) callconv(.c) void;
pub extern fn hb_draw_funcs_set_move_to_func(dfuncs: ?*hb_draw_funcs_t, func: hb_draw_move_to_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_draw_funcs_set_line_to_func(dfuncs: ?*hb_draw_funcs_t, func: hb_draw_line_to_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_draw_funcs_set_quadratic_to_func(dfuncs: ?*hb_draw_funcs_t, func: hb_draw_quadratic_to_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_draw_funcs_set_cubic_to_func(dfuncs: ?*hb_draw_funcs_t, func: hb_draw_cubic_to_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_draw_funcs_set_close_path_func(dfuncs: ?*hb_draw_funcs_t, func: hb_draw_close_path_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_draw_funcs_create() ?*hb_draw_funcs_t;
pub extern fn hb_draw_funcs_get_empty() ?*hb_draw_funcs_t;
pub extern fn hb_draw_funcs_reference(dfuncs: ?*hb_draw_funcs_t) ?*hb_draw_funcs_t;
pub extern fn hb_draw_funcs_destroy(dfuncs: ?*hb_draw_funcs_t) void;
pub extern fn hb_draw_funcs_set_user_data(dfuncs: ?*hb_draw_funcs_t, key: [*c]hb_user_data_key_t, data: ?*anyopaque, destroy: hb_destroy_func_t, replace: hb_bool_t) hb_bool_t;
pub extern fn hb_draw_funcs_get_user_data(dfuncs: ?*const hb_draw_funcs_t, key: [*c]hb_user_data_key_t) ?*anyopaque;
pub extern fn hb_draw_funcs_make_immutable(dfuncs: ?*hb_draw_funcs_t) void;
pub extern fn hb_draw_funcs_is_immutable(dfuncs: ?*hb_draw_funcs_t) hb_bool_t;
pub extern fn hb_draw_move_to(dfuncs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque, st: [*c]hb_draw_state_t, to_x: f32, to_y: f32) void;
pub extern fn hb_draw_line_to(dfuncs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque, st: [*c]hb_draw_state_t, to_x: f32, to_y: f32) void;
pub extern fn hb_draw_quadratic_to(dfuncs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque, st: [*c]hb_draw_state_t, control_x: f32, control_y: f32, to_x: f32, to_y: f32) void;
pub extern fn hb_draw_cubic_to(dfuncs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque, st: [*c]hb_draw_state_t, control1_x: f32, control1_y: f32, control2_x: f32, control2_y: f32, to_x: f32, to_y: f32) void;
pub extern fn hb_draw_close_path(dfuncs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque, st: [*c]hb_draw_state_t) void;
pub const struct_hb_paint_funcs_t = opaque {
    pub const hb_paint_funcs_reference = __root.hb_paint_funcs_reference;
    pub const hb_paint_funcs_destroy = __root.hb_paint_funcs_destroy;
    pub const hb_paint_funcs_set_user_data = __root.hb_paint_funcs_set_user_data;
    pub const hb_paint_funcs_get_user_data = __root.hb_paint_funcs_get_user_data;
    pub const hb_paint_funcs_make_immutable = __root.hb_paint_funcs_make_immutable;
    pub const hb_paint_funcs_is_immutable = __root.hb_paint_funcs_is_immutable;
    pub const hb_paint_funcs_set_push_transform_func = __root.hb_paint_funcs_set_push_transform_func;
    pub const hb_paint_funcs_set_pop_transform_func = __root.hb_paint_funcs_set_pop_transform_func;
    pub const hb_paint_funcs_set_color_glyph_func = __root.hb_paint_funcs_set_color_glyph_func;
    pub const hb_paint_funcs_set_push_clip_glyph_func = __root.hb_paint_funcs_set_push_clip_glyph_func;
    pub const hb_paint_funcs_set_push_clip_rectangle_func = __root.hb_paint_funcs_set_push_clip_rectangle_func;
    pub const hb_paint_funcs_set_pop_clip_func = __root.hb_paint_funcs_set_pop_clip_func;
    pub const hb_paint_funcs_set_color_func = __root.hb_paint_funcs_set_color_func;
    pub const hb_paint_funcs_set_image_func = __root.hb_paint_funcs_set_image_func;
    pub const hb_paint_funcs_set_linear_gradient_func = __root.hb_paint_funcs_set_linear_gradient_func;
    pub const hb_paint_funcs_set_radial_gradient_func = __root.hb_paint_funcs_set_radial_gradient_func;
    pub const hb_paint_funcs_set_sweep_gradient_func = __root.hb_paint_funcs_set_sweep_gradient_func;
    pub const hb_paint_funcs_set_push_group_func = __root.hb_paint_funcs_set_push_group_func;
    pub const hb_paint_funcs_set_pop_group_func = __root.hb_paint_funcs_set_pop_group_func;
    pub const hb_paint_funcs_set_custom_palette_color_func = __root.hb_paint_funcs_set_custom_palette_color_func;
    pub const hb_paint_push_transform = __root.hb_paint_push_transform;
    pub const hb_paint_push_font_transform = __root.hb_paint_push_font_transform;
    pub const hb_paint_push_inverse_font_transform = __root.hb_paint_push_inverse_font_transform;
    pub const hb_paint_pop_transform = __root.hb_paint_pop_transform;
    pub const hb_paint_color_glyph = __root.hb_paint_color_glyph;
    pub const hb_paint_push_clip_glyph = __root.hb_paint_push_clip_glyph;
    pub const hb_paint_push_clip_rectangle = __root.hb_paint_push_clip_rectangle;
    pub const hb_paint_pop_clip = __root.hb_paint_pop_clip;
    pub const hb_paint_color = __root.hb_paint_color;
    pub const hb_paint_image = __root.hb_paint_image;
    pub const hb_paint_linear_gradient = __root.hb_paint_linear_gradient;
    pub const hb_paint_radial_gradient = __root.hb_paint_radial_gradient;
    pub const hb_paint_sweep_gradient = __root.hb_paint_sweep_gradient;
    pub const hb_paint_push_group = __root.hb_paint_push_group;
    pub const hb_paint_pop_group = __root.hb_paint_pop_group;
    pub const hb_paint_custom_palette_color = __root.hb_paint_custom_palette_color;
    pub const reference = __root.hb_paint_funcs_reference;
    pub const destroy = __root.hb_paint_funcs_destroy;
    pub const data = __root.hb_paint_funcs_set_user_data;
    pub const immutable = __root.hb_paint_funcs_make_immutable;
    pub const func = __root.hb_paint_funcs_set_push_transform_func;
    pub const transform = __root.hb_paint_push_transform;
    pub const glyph = __root.hb_paint_color_glyph;
    pub const rectangle = __root.hb_paint_push_clip_rectangle;
    pub const clip = __root.hb_paint_pop_clip;
    pub const color = __root.hb_paint_color;
    pub const image = __root.hb_paint_image;
    pub const gradient = __root.hb_paint_linear_gradient;
    pub const group = __root.hb_paint_push_group;
};
pub const hb_paint_funcs_t = struct_hb_paint_funcs_t;
pub extern fn hb_paint_funcs_create() ?*hb_paint_funcs_t;
pub extern fn hb_paint_funcs_get_empty() ?*hb_paint_funcs_t;
pub extern fn hb_paint_funcs_reference(funcs: ?*hb_paint_funcs_t) ?*hb_paint_funcs_t;
pub extern fn hb_paint_funcs_destroy(funcs: ?*hb_paint_funcs_t) void;
pub extern fn hb_paint_funcs_set_user_data(funcs: ?*hb_paint_funcs_t, key: [*c]hb_user_data_key_t, data: ?*anyopaque, destroy: hb_destroy_func_t, replace: hb_bool_t) hb_bool_t;
pub extern fn hb_paint_funcs_get_user_data(funcs: ?*const hb_paint_funcs_t, key: [*c]hb_user_data_key_t) ?*anyopaque;
pub extern fn hb_paint_funcs_make_immutable(funcs: ?*hb_paint_funcs_t) void;
pub extern fn hb_paint_funcs_is_immutable(funcs: ?*hb_paint_funcs_t) hb_bool_t;
pub const hb_paint_push_transform_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, xx: f32, yx: f32, xy: f32, yy: f32, dx: f32, dy: f32, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_paint_pop_transform_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_paint_color_glyph_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, glyph: hb_codepoint_t, font: ?*hb_font_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub const hb_paint_push_clip_glyph_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, glyph: hb_codepoint_t, font: ?*hb_font_t, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_paint_push_clip_rectangle_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, xmin: f32, ymin: f32, xmax: f32, ymax: f32, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_paint_pop_clip_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_paint_color_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, is_foreground: hb_bool_t, color: hb_color_t, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_paint_image_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, image: ?*hb_blob_t, width: c_uint, height: c_uint, format: hb_tag_t, slant: f32, extents: [*c]hb_glyph_extents_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub const hb_color_stop_t = extern struct {
    offset: f32 = 0,
    is_foreground: hb_bool_t = 0,
    color: hb_color_t = 0,
};
pub const HB_PAINT_EXTEND_PAD: c_int = 0;
pub const HB_PAINT_EXTEND_REPEAT: c_int = 1;
pub const HB_PAINT_EXTEND_REFLECT: c_int = 2;
pub const hb_paint_extend_t = c_uint;
pub const hb_color_line_t = struct_hb_color_line_t;
pub const hb_color_line_get_color_stops_func_t = ?*const fn (color_line: [*c]hb_color_line_t, color_line_data: ?*anyopaque, start: c_uint, count: [*c]c_uint, color_stops: [*c]hb_color_stop_t, user_data: ?*anyopaque) callconv(.c) c_uint;
pub const hb_color_line_get_extend_func_t = ?*const fn (color_line: [*c]hb_color_line_t, color_line_data: ?*anyopaque, user_data: ?*anyopaque) callconv(.c) hb_paint_extend_t;
pub const struct_hb_color_line_t = extern struct {
    data: ?*anyopaque = null,
    get_color_stops: hb_color_line_get_color_stops_func_t = null,
    get_color_stops_user_data: ?*anyopaque = null,
    get_extend: hb_color_line_get_extend_func_t = null,
    get_extend_user_data: ?*anyopaque = null,
    reserved0: ?*anyopaque = null,
    reserved1: ?*anyopaque = null,
    reserved2: ?*anyopaque = null,
    reserved3: ?*anyopaque = null,
    reserved5: ?*anyopaque = null,
    reserved6: ?*anyopaque = null,
    reserved7: ?*anyopaque = null,
    reserved8: ?*anyopaque = null,
    pub const hb_color_line_get_color_stops = __root.hb_color_line_get_color_stops;
    pub const hb_color_line_get_extend = __root.hb_color_line_get_extend;
    pub const stops = __root.hb_color_line_get_color_stops;
    pub const extend = __root.hb_color_line_get_extend;
};
pub extern fn hb_color_line_get_color_stops(color_line: [*c]hb_color_line_t, start: c_uint, count: [*c]c_uint, color_stops: [*c]hb_color_stop_t) c_uint;
pub extern fn hb_color_line_get_extend(color_line: [*c]hb_color_line_t) hb_paint_extend_t;
pub const hb_paint_linear_gradient_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, color_line: [*c]hb_color_line_t, x0: f32, y0: f32, x1: f32, y1: f32, x2: f32, y2: f32, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_paint_radial_gradient_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, color_line: [*c]hb_color_line_t, x0: f32, y0: f32, r0: f32, x1: f32, y1: f32, r1: f32, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_paint_sweep_gradient_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, color_line: [*c]hb_color_line_t, x0: f32, y0: f32, start_angle: f32, end_angle: f32, user_data: ?*anyopaque) callconv(.c) void;
pub const HB_PAINT_COMPOSITE_MODE_CLEAR: c_int = 0;
pub const HB_PAINT_COMPOSITE_MODE_SRC: c_int = 1;
pub const HB_PAINT_COMPOSITE_MODE_DEST: c_int = 2;
pub const HB_PAINT_COMPOSITE_MODE_SRC_OVER: c_int = 3;
pub const HB_PAINT_COMPOSITE_MODE_DEST_OVER: c_int = 4;
pub const HB_PAINT_COMPOSITE_MODE_SRC_IN: c_int = 5;
pub const HB_PAINT_COMPOSITE_MODE_DEST_IN: c_int = 6;
pub const HB_PAINT_COMPOSITE_MODE_SRC_OUT: c_int = 7;
pub const HB_PAINT_COMPOSITE_MODE_DEST_OUT: c_int = 8;
pub const HB_PAINT_COMPOSITE_MODE_SRC_ATOP: c_int = 9;
pub const HB_PAINT_COMPOSITE_MODE_DEST_ATOP: c_int = 10;
pub const HB_PAINT_COMPOSITE_MODE_XOR: c_int = 11;
pub const HB_PAINT_COMPOSITE_MODE_PLUS: c_int = 12;
pub const HB_PAINT_COMPOSITE_MODE_SCREEN: c_int = 13;
pub const HB_PAINT_COMPOSITE_MODE_OVERLAY: c_int = 14;
pub const HB_PAINT_COMPOSITE_MODE_DARKEN: c_int = 15;
pub const HB_PAINT_COMPOSITE_MODE_LIGHTEN: c_int = 16;
pub const HB_PAINT_COMPOSITE_MODE_COLOR_DODGE: c_int = 17;
pub const HB_PAINT_COMPOSITE_MODE_COLOR_BURN: c_int = 18;
pub const HB_PAINT_COMPOSITE_MODE_HARD_LIGHT: c_int = 19;
pub const HB_PAINT_COMPOSITE_MODE_SOFT_LIGHT: c_int = 20;
pub const HB_PAINT_COMPOSITE_MODE_DIFFERENCE: c_int = 21;
pub const HB_PAINT_COMPOSITE_MODE_EXCLUSION: c_int = 22;
pub const HB_PAINT_COMPOSITE_MODE_MULTIPLY: c_int = 23;
pub const HB_PAINT_COMPOSITE_MODE_HSL_HUE: c_int = 24;
pub const HB_PAINT_COMPOSITE_MODE_HSL_SATURATION: c_int = 25;
pub const HB_PAINT_COMPOSITE_MODE_HSL_COLOR: c_int = 26;
pub const HB_PAINT_COMPOSITE_MODE_HSL_LUMINOSITY: c_int = 27;
pub const hb_paint_composite_mode_t = c_uint;
pub const hb_paint_push_group_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_paint_pop_group_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, mode: hb_paint_composite_mode_t, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_paint_custom_palette_color_func_t = ?*const fn (funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, color_index: c_uint, color: [*c]hb_color_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub extern fn hb_paint_funcs_set_push_transform_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_push_transform_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_funcs_set_pop_transform_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_pop_transform_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_funcs_set_color_glyph_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_color_glyph_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_funcs_set_push_clip_glyph_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_push_clip_glyph_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_funcs_set_push_clip_rectangle_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_push_clip_rectangle_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_funcs_set_pop_clip_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_pop_clip_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_funcs_set_color_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_color_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_funcs_set_image_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_image_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_funcs_set_linear_gradient_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_linear_gradient_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_funcs_set_radial_gradient_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_radial_gradient_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_funcs_set_sweep_gradient_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_sweep_gradient_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_funcs_set_push_group_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_push_group_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_funcs_set_pop_group_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_pop_group_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_funcs_set_custom_palette_color_func(funcs: ?*hb_paint_funcs_t, func: hb_paint_custom_palette_color_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_paint_push_transform(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, xx: f32, yx: f32, xy: f32, yy: f32, dx: f32, dy: f32) void;
pub extern fn hb_paint_push_font_transform(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, font: ?*const hb_font_t) void;
pub extern fn hb_paint_push_inverse_font_transform(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, font: ?*const hb_font_t) void;
pub extern fn hb_paint_pop_transform(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque) void;
pub extern fn hb_paint_color_glyph(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, glyph: hb_codepoint_t, font: ?*hb_font_t) hb_bool_t;
pub extern fn hb_paint_push_clip_glyph(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, glyph: hb_codepoint_t, font: ?*hb_font_t) void;
pub extern fn hb_paint_push_clip_rectangle(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, xmin: f32, ymin: f32, xmax: f32, ymax: f32) void;
pub extern fn hb_paint_pop_clip(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque) void;
pub extern fn hb_paint_color(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, is_foreground: hb_bool_t, color: hb_color_t) void;
pub extern fn hb_paint_image(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, image: ?*hb_blob_t, width: c_uint, height: c_uint, format: hb_tag_t, slant: f32, extents: [*c]hb_glyph_extents_t) void;
pub extern fn hb_paint_linear_gradient(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, color_line: [*c]hb_color_line_t, x0: f32, y0: f32, x1: f32, y1: f32, x2: f32, y2: f32) void;
pub extern fn hb_paint_radial_gradient(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, color_line: [*c]hb_color_line_t, x0: f32, y0: f32, r0: f32, x1: f32, y1: f32, r1: f32) void;
pub extern fn hb_paint_sweep_gradient(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, color_line: [*c]hb_color_line_t, x0: f32, y0: f32, start_angle: f32, end_angle: f32) void;
pub extern fn hb_paint_push_group(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque) void;
pub extern fn hb_paint_pop_group(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, mode: hb_paint_composite_mode_t) void;
pub extern fn hb_paint_custom_palette_color(funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, color_index: c_uint, color: [*c]hb_color_t) hb_bool_t;
pub const struct_hb_font_funcs_t = opaque {
    pub const hb_font_funcs_reference = __root.hb_font_funcs_reference;
    pub const hb_font_funcs_destroy = __root.hb_font_funcs_destroy;
    pub const hb_font_funcs_set_user_data = __root.hb_font_funcs_set_user_data;
    pub const hb_font_funcs_get_user_data = __root.hb_font_funcs_get_user_data;
    pub const hb_font_funcs_make_immutable = __root.hb_font_funcs_make_immutable;
    pub const hb_font_funcs_is_immutable = __root.hb_font_funcs_is_immutable;
    pub const hb_font_funcs_set_font_h_extents_func = __root.hb_font_funcs_set_font_h_extents_func;
    pub const hb_font_funcs_set_font_v_extents_func = __root.hb_font_funcs_set_font_v_extents_func;
    pub const hb_font_funcs_set_nominal_glyph_func = __root.hb_font_funcs_set_nominal_glyph_func;
    pub const hb_font_funcs_set_nominal_glyphs_func = __root.hb_font_funcs_set_nominal_glyphs_func;
    pub const hb_font_funcs_set_variation_glyph_func = __root.hb_font_funcs_set_variation_glyph_func;
    pub const hb_font_funcs_set_glyph_h_advance_func = __root.hb_font_funcs_set_glyph_h_advance_func;
    pub const hb_font_funcs_set_glyph_v_advance_func = __root.hb_font_funcs_set_glyph_v_advance_func;
    pub const hb_font_funcs_set_glyph_h_advances_func = __root.hb_font_funcs_set_glyph_h_advances_func;
    pub const hb_font_funcs_set_glyph_v_advances_func = __root.hb_font_funcs_set_glyph_v_advances_func;
    pub const hb_font_funcs_set_glyph_h_origin_func = __root.hb_font_funcs_set_glyph_h_origin_func;
    pub const hb_font_funcs_set_glyph_v_origin_func = __root.hb_font_funcs_set_glyph_v_origin_func;
    pub const hb_font_funcs_set_glyph_h_origins_func = __root.hb_font_funcs_set_glyph_h_origins_func;
    pub const hb_font_funcs_set_glyph_v_origins_func = __root.hb_font_funcs_set_glyph_v_origins_func;
    pub const hb_font_funcs_set_glyph_h_kerning_func = __root.hb_font_funcs_set_glyph_h_kerning_func;
    pub const hb_font_funcs_set_glyph_extents_func = __root.hb_font_funcs_set_glyph_extents_func;
    pub const hb_font_funcs_set_glyph_contour_point_func = __root.hb_font_funcs_set_glyph_contour_point_func;
    pub const hb_font_funcs_set_glyph_name_func = __root.hb_font_funcs_set_glyph_name_func;
    pub const hb_font_funcs_set_glyph_from_name_func = __root.hb_font_funcs_set_glyph_from_name_func;
    pub const hb_font_funcs_set_draw_glyph_or_fail_func = __root.hb_font_funcs_set_draw_glyph_or_fail_func;
    pub const hb_font_funcs_set_paint_glyph_or_fail_func = __root.hb_font_funcs_set_paint_glyph_or_fail_func;
    pub const hb_font_funcs_set_glyph_func = __root.hb_font_funcs_set_glyph_func;
    pub const hb_font_funcs_set_glyph_v_kerning_func = __root.hb_font_funcs_set_glyph_v_kerning_func;
    pub const hb_font_funcs_set_glyph_shape_func = __root.hb_font_funcs_set_glyph_shape_func;
    pub const hb_font_funcs_set_draw_glyph_func = __root.hb_font_funcs_set_draw_glyph_func;
    pub const hb_font_funcs_set_paint_glyph_func = __root.hb_font_funcs_set_paint_glyph_func;
    pub const reference = __root.hb_font_funcs_reference;
    pub const destroy = __root.hb_font_funcs_destroy;
    pub const data = __root.hb_font_funcs_set_user_data;
    pub const immutable = __root.hb_font_funcs_make_immutable;
    pub const func = __root.hb_font_funcs_set_font_h_extents_func;
};
pub const hb_font_funcs_t = struct_hb_font_funcs_t;
pub extern fn hb_font_funcs_create() ?*hb_font_funcs_t;
pub extern fn hb_font_funcs_get_empty() ?*hb_font_funcs_t;
pub extern fn hb_font_funcs_reference(ffuncs: ?*hb_font_funcs_t) ?*hb_font_funcs_t;
pub extern fn hb_font_funcs_destroy(ffuncs: ?*hb_font_funcs_t) void;
pub extern fn hb_font_funcs_set_user_data(ffuncs: ?*hb_font_funcs_t, key: [*c]hb_user_data_key_t, data: ?*anyopaque, destroy: hb_destroy_func_t, replace: hb_bool_t) hb_bool_t;
pub extern fn hb_font_funcs_get_user_data(ffuncs: ?*const hb_font_funcs_t, key: [*c]hb_user_data_key_t) ?*anyopaque;
pub extern fn hb_font_funcs_make_immutable(ffuncs: ?*hb_font_funcs_t) void;
pub extern fn hb_font_funcs_is_immutable(ffuncs: ?*hb_font_funcs_t) hb_bool_t;
pub const struct_hb_font_extents_t = extern struct {
    ascender: hb_position_t = 0,
    descender: hb_position_t = 0,
    line_gap: hb_position_t = 0,
    reserved9: hb_position_t = 0,
    reserved8: hb_position_t = 0,
    reserved7: hb_position_t = 0,
    reserved6: hb_position_t = 0,
    reserved5: hb_position_t = 0,
    reserved4: hb_position_t = 0,
    reserved3: hb_position_t = 0,
    reserved2: hb_position_t = 0,
    reserved1: hb_position_t = 0,
};
pub const hb_font_extents_t = struct_hb_font_extents_t;
pub const hb_font_get_font_extents_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, extents: [*c]hb_font_extents_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub const hb_font_get_font_h_extents_func_t = hb_font_get_font_extents_func_t;
pub const hb_font_get_font_v_extents_func_t = hb_font_get_font_extents_func_t;
pub const hb_font_get_nominal_glyph_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, unicode: hb_codepoint_t, glyph: [*c]hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub const hb_font_get_variation_glyph_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, unicode: hb_codepoint_t, variation_selector: hb_codepoint_t, glyph: [*c]hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub const hb_font_get_nominal_glyphs_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, count: c_uint, first_unicode: [*c]const hb_codepoint_t, unicode_stride: c_uint, first_glyph: [*c]hb_codepoint_t, glyph_stride: c_uint, user_data: ?*anyopaque) callconv(.c) c_uint;
pub const hb_font_get_glyph_advance_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, glyph: hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) hb_position_t;
pub const hb_font_get_glyph_h_advance_func_t = hb_font_get_glyph_advance_func_t;
pub const hb_font_get_glyph_v_advance_func_t = hb_font_get_glyph_advance_func_t;
pub const hb_font_get_glyph_advances_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, count: c_uint, first_glyph: [*c]const hb_codepoint_t, glyph_stride: c_uint, first_advance: [*c]hb_position_t, advance_stride: c_uint, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_font_get_glyph_h_advances_func_t = hb_font_get_glyph_advances_func_t;
pub const hb_font_get_glyph_v_advances_func_t = hb_font_get_glyph_advances_func_t;
pub const hb_font_get_glyph_origin_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, glyph: hb_codepoint_t, x: [*c]hb_position_t, y: [*c]hb_position_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub const hb_font_get_glyph_h_origin_func_t = hb_font_get_glyph_origin_func_t;
pub const hb_font_get_glyph_v_origin_func_t = hb_font_get_glyph_origin_func_t;
pub const hb_font_get_glyph_origins_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, count: c_uint, first_glyph: [*c]const hb_codepoint_t, glyph_stride: c_uint, first_x: [*c]hb_position_t, x_stride: c_uint, first_y: [*c]hb_position_t, y_stride: c_uint, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub const hb_font_get_glyph_h_origins_func_t = hb_font_get_glyph_origins_func_t;
pub const hb_font_get_glyph_v_origins_func_t = hb_font_get_glyph_origins_func_t;
pub const hb_font_get_glyph_kerning_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, first_glyph: hb_codepoint_t, second_glyph: hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) hb_position_t;
pub const hb_font_get_glyph_h_kerning_func_t = hb_font_get_glyph_kerning_func_t;
pub const hb_font_get_glyph_extents_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, glyph: hb_codepoint_t, extents: [*c]hb_glyph_extents_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub const hb_font_get_glyph_contour_point_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, glyph: hb_codepoint_t, point_index: c_uint, x: [*c]hb_position_t, y: [*c]hb_position_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub const hb_font_get_glyph_name_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, glyph: hb_codepoint_t, name: [*c]u8, size: c_uint, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub const hb_font_get_glyph_from_name_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, name: [*c]const u8, len: c_int, glyph: [*c]hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub const hb_font_draw_glyph_or_fail_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, glyph: hb_codepoint_t, draw_funcs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub const hb_font_paint_glyph_or_fail_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, glyph: hb_codepoint_t, paint_funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, palette_index: c_uint, foreground: hb_color_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub extern fn hb_font_funcs_set_font_h_extents_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_font_h_extents_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_font_v_extents_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_font_v_extents_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_nominal_glyph_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_nominal_glyph_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_nominal_glyphs_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_nominal_glyphs_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_variation_glyph_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_variation_glyph_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_glyph_h_advance_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_h_advance_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_glyph_v_advance_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_v_advance_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_glyph_h_advances_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_h_advances_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_glyph_v_advances_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_v_advances_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_glyph_h_origin_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_h_origin_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_glyph_v_origin_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_v_origin_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_glyph_h_origins_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_h_origins_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_glyph_v_origins_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_v_origins_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_glyph_h_kerning_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_h_kerning_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_glyph_extents_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_extents_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_glyph_contour_point_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_contour_point_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_glyph_name_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_name_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_glyph_from_name_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_from_name_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_draw_glyph_or_fail_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_draw_glyph_or_fail_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_paint_glyph_or_fail_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_paint_glyph_or_fail_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_get_h_extents(font: ?*hb_font_t, extents: [*c]hb_font_extents_t) hb_bool_t;
pub extern fn hb_font_get_v_extents(font: ?*hb_font_t, extents: [*c]hb_font_extents_t) hb_bool_t;
pub extern fn hb_font_get_nominal_glyph(font: ?*hb_font_t, unicode: hb_codepoint_t, glyph: [*c]hb_codepoint_t) hb_bool_t;
pub extern fn hb_font_get_variation_glyph(font: ?*hb_font_t, unicode: hb_codepoint_t, variation_selector: hb_codepoint_t, glyph: [*c]hb_codepoint_t) hb_bool_t;
pub extern fn hb_font_get_nominal_glyphs(font: ?*hb_font_t, count: c_uint, first_unicode: [*c]const hb_codepoint_t, unicode_stride: c_uint, first_glyph: [*c]hb_codepoint_t, glyph_stride: c_uint) c_uint;
pub extern fn hb_font_get_glyph_h_advance(font: ?*hb_font_t, glyph: hb_codepoint_t) hb_position_t;
pub extern fn hb_font_get_glyph_v_advance(font: ?*hb_font_t, glyph: hb_codepoint_t) hb_position_t;
pub extern fn hb_font_get_glyph_h_advances(font: ?*hb_font_t, count: c_uint, first_glyph: [*c]const hb_codepoint_t, glyph_stride: c_uint, first_advance: [*c]hb_position_t, advance_stride: c_uint) void;
pub extern fn hb_font_get_glyph_v_advances(font: ?*hb_font_t, count: c_uint, first_glyph: [*c]const hb_codepoint_t, glyph_stride: c_uint, first_advance: [*c]hb_position_t, advance_stride: c_uint) void;
pub extern fn hb_font_get_glyph_h_origin(font: ?*hb_font_t, glyph: hb_codepoint_t, x: [*c]hb_position_t, y: [*c]hb_position_t) hb_bool_t;
pub extern fn hb_font_get_glyph_v_origin(font: ?*hb_font_t, glyph: hb_codepoint_t, x: [*c]hb_position_t, y: [*c]hb_position_t) hb_bool_t;
pub extern fn hb_font_get_glyph_h_origins(font: ?*hb_font_t, count: c_uint, first_glyph: [*c]const hb_codepoint_t, glyph_stride: c_uint, first_x: [*c]hb_position_t, x_stride: c_uint, first_y: [*c]hb_position_t, y_stride: c_uint) hb_bool_t;
pub extern fn hb_font_get_glyph_v_origins(font: ?*hb_font_t, count: c_uint, first_glyph: [*c]const hb_codepoint_t, glyph_stride: c_uint, first_x: [*c]hb_position_t, x_stride: c_uint, first_y: [*c]hb_position_t, y_stride: c_uint) hb_bool_t;
pub extern fn hb_font_get_glyph_h_kerning(font: ?*hb_font_t, left_glyph: hb_codepoint_t, right_glyph: hb_codepoint_t) hb_position_t;
pub extern fn hb_font_get_glyph_extents(font: ?*hb_font_t, glyph: hb_codepoint_t, extents: [*c]hb_glyph_extents_t) hb_bool_t;
pub extern fn hb_font_get_glyph_contour_point(font: ?*hb_font_t, glyph: hb_codepoint_t, point_index: c_uint, x: [*c]hb_position_t, y: [*c]hb_position_t) hb_bool_t;
pub extern fn hb_font_get_glyph_name(font: ?*hb_font_t, glyph: hb_codepoint_t, name: [*c]u8, size: c_uint) hb_bool_t;
pub extern fn hb_font_get_glyph_from_name(font: ?*hb_font_t, name: [*c]const u8, len: c_int, glyph: [*c]hb_codepoint_t) hb_bool_t;
pub extern fn hb_font_draw_glyph_or_fail(font: ?*hb_font_t, glyph: hb_codepoint_t, dfuncs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque) hb_bool_t;
pub extern fn hb_font_paint_glyph_or_fail(font: ?*hb_font_t, glyph: hb_codepoint_t, pfuncs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, palette_index: c_uint, foreground: hb_color_t) hb_bool_t;
pub extern fn hb_font_get_glyph(font: ?*hb_font_t, unicode: hb_codepoint_t, variation_selector: hb_codepoint_t, glyph: [*c]hb_codepoint_t) hb_bool_t;
pub extern fn hb_font_get_extents_for_direction(font: ?*hb_font_t, direction: hb_direction_t, extents: [*c]hb_font_extents_t) void;
pub extern fn hb_font_get_glyph_advance_for_direction(font: ?*hb_font_t, glyph: hb_codepoint_t, direction: hb_direction_t, x: [*c]hb_position_t, y: [*c]hb_position_t) void;
pub extern fn hb_font_get_glyph_advances_for_direction(font: ?*hb_font_t, direction: hb_direction_t, count: c_uint, first_glyph: [*c]const hb_codepoint_t, glyph_stride: c_uint, first_advance: [*c]hb_position_t, advance_stride: c_uint) void;
pub extern fn hb_font_get_glyph_origin_for_direction(font: ?*hb_font_t, glyph: hb_codepoint_t, direction: hb_direction_t, x: [*c]hb_position_t, y: [*c]hb_position_t) void;
pub extern fn hb_font_add_glyph_origin_for_direction(font: ?*hb_font_t, glyph: hb_codepoint_t, direction: hb_direction_t, x: [*c]hb_position_t, y: [*c]hb_position_t) void;
pub extern fn hb_font_subtract_glyph_origin_for_direction(font: ?*hb_font_t, glyph: hb_codepoint_t, direction: hb_direction_t, x: [*c]hb_position_t, y: [*c]hb_position_t) void;
pub extern fn hb_font_get_glyph_kerning_for_direction(font: ?*hb_font_t, first_glyph: hb_codepoint_t, second_glyph: hb_codepoint_t, direction: hb_direction_t, x: [*c]hb_position_t, y: [*c]hb_position_t) void;
pub extern fn hb_font_get_glyph_extents_for_origin(font: ?*hb_font_t, glyph: hb_codepoint_t, direction: hb_direction_t, extents: [*c]hb_glyph_extents_t) hb_bool_t;
pub extern fn hb_font_get_glyph_contour_point_for_origin(font: ?*hb_font_t, glyph: hb_codepoint_t, point_index: c_uint, direction: hb_direction_t, x: [*c]hb_position_t, y: [*c]hb_position_t) hb_bool_t;
pub extern fn hb_font_glyph_to_string(font: ?*hb_font_t, glyph: hb_codepoint_t, s: [*c]u8, size: c_uint) void;
pub extern fn hb_font_glyph_from_string(font: ?*hb_font_t, s: [*c]const u8, len: c_int, glyph: [*c]hb_codepoint_t) hb_bool_t;
pub extern fn hb_font_draw_glyph(font: ?*hb_font_t, glyph: hb_codepoint_t, dfuncs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque) void;
pub extern fn hb_font_paint_glyph(font: ?*hb_font_t, glyph: hb_codepoint_t, pfuncs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, palette_index: c_uint, foreground: hb_color_t) void;
pub extern fn hb_font_create(face: ?*hb_face_t) ?*hb_font_t;
pub extern fn hb_font_create_sub_font(parent: ?*hb_font_t) ?*hb_font_t;
pub extern fn hb_font_get_empty() ?*hb_font_t;
pub extern fn hb_font_reference(font: ?*hb_font_t) ?*hb_font_t;
pub extern fn hb_font_destroy(font: ?*hb_font_t) void;
pub extern fn hb_font_set_user_data(font: ?*hb_font_t, key: [*c]hb_user_data_key_t, data: ?*anyopaque, destroy: hb_destroy_func_t, replace: hb_bool_t) hb_bool_t;
pub extern fn hb_font_get_user_data(font: ?*const hb_font_t, key: [*c]hb_user_data_key_t) ?*anyopaque;
pub extern fn hb_font_make_immutable(font: ?*hb_font_t) void;
pub extern fn hb_font_is_immutable(font: ?*hb_font_t) hb_bool_t;
pub extern fn hb_font_get_serial(font: ?*hb_font_t) c_uint;
pub extern fn hb_font_changed(font: ?*hb_font_t) void;
pub extern fn hb_font_set_parent(font: ?*hb_font_t, parent: ?*hb_font_t) void;
pub extern fn hb_font_get_parent(font: ?*hb_font_t) ?*hb_font_t;
pub extern fn hb_font_set_face(font: ?*hb_font_t, face: ?*hb_face_t) void;
pub extern fn hb_font_get_face(font: ?*hb_font_t) ?*hb_face_t;
pub extern fn hb_font_set_funcs(font: ?*hb_font_t, klass: ?*hb_font_funcs_t, font_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_set_funcs_data(font: ?*hb_font_t, font_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
// Local addition: `hb-ot-font.h` is not part of the translated header set.
// Older system HarfBuzz (e.g. 8.x) has no name-based `hb_font_set_funcs_using`;
// `hb_ot_font_set_funcs` is the stable API that installs the OpenType font
// functions on a face-backed `hb_font_t`.
pub extern fn hb_ot_font_set_funcs(font: ?*hb_font_t) void;
pub extern fn hb_font_set_scale(font: ?*hb_font_t, x_scale: c_int, y_scale: c_int) void;
pub extern fn hb_font_get_scale(font: ?*hb_font_t, x_scale: [*c]c_int, y_scale: [*c]c_int) void;
pub extern fn hb_font_set_ppem(font: ?*hb_font_t, x_ppem: c_uint, y_ppem: c_uint) void;
pub extern fn hb_font_get_ppem(font: ?*hb_font_t, x_ppem: [*c]c_uint, y_ppem: [*c]c_uint) void;
pub extern fn hb_font_set_ptem(font: ?*hb_font_t, ptem: f32) void;
pub extern fn hb_font_get_ptem(font: ?*hb_font_t) f32;
pub extern fn hb_font_is_synthetic(font: ?*hb_font_t) hb_bool_t;
pub extern fn hb_font_set_synthetic_bold(font: ?*hb_font_t, x_embolden: f32, y_embolden: f32, in_place: hb_bool_t) void;
pub extern fn hb_font_get_synthetic_bold(font: ?*hb_font_t, x_embolden: [*c]f32, y_embolden: [*c]f32, in_place: [*c]hb_bool_t) void;
pub extern fn hb_font_set_synthetic_slant(font: ?*hb_font_t, slant: f32) void;
pub extern fn hb_font_get_synthetic_slant(font: ?*hb_font_t) f32;
pub extern fn hb_font_set_variations(font: ?*hb_font_t, variations: [*c]const hb_variation_t, variations_length: c_uint) void;
pub extern fn hb_font_set_variation(font: ?*hb_font_t, tag: hb_tag_t, value: f32) void;
pub extern fn hb_font_set_var_coords_design(font: ?*hb_font_t, coords: [*c]const f32, coords_length: c_uint) void;
pub extern fn hb_font_get_var_coords_design(font: ?*hb_font_t, length: [*c]c_uint) [*c]const f32;
pub extern fn hb_font_set_var_coords_normalized(font: ?*hb_font_t, coords: [*c]const c_int, coords_length: c_uint) void;
pub extern fn hb_font_get_var_coords_normalized(font: ?*hb_font_t, length: [*c]c_uint) [*c]const c_int;
pub extern fn hb_font_set_var_named_instance(font: ?*hb_font_t, instance_index: c_uint) void;
pub extern fn hb_font_get_var_named_instance(font: ?*hb_font_t) c_uint;
pub const struct_hb_glyph_info_t = extern struct {
    codepoint: hb_codepoint_t = 0,
    mask: hb_mask_t = 0,
    cluster: u32 = 0,
    var1: hb_var_int_t = @import("std").mem.zeroes(hb_var_int_t),
    var2: hb_var_int_t = @import("std").mem.zeroes(hb_var_int_t),
    pub const hb_glyph_info_get_glyph_flags = __root.hb_glyph_info_get_glyph_flags;
    pub const flags = __root.hb_glyph_info_get_glyph_flags;
};
pub const hb_glyph_info_t = struct_hb_glyph_info_t;
pub const HB_GLYPH_FLAG_UNSAFE_TO_BREAK: c_int = 1;
pub const HB_GLYPH_FLAG_UNSAFE_TO_CONCAT: c_int = 2;
pub const HB_GLYPH_FLAG_SAFE_TO_INSERT_TATWEEL: c_int = 4;
pub const HB_GLYPH_FLAG_DEFINED: c_int = 7;
pub const hb_glyph_flags_t = c_uint;
pub extern fn hb_glyph_info_get_glyph_flags(info: [*c]const hb_glyph_info_t) hb_glyph_flags_t;
pub const struct_hb_glyph_position_t = extern struct {
    x_advance: hb_position_t = 0,
    y_advance: hb_position_t = 0,
    x_offset: hb_position_t = 0,
    y_offset: hb_position_t = 0,
    @"var": hb_var_int_t = @import("std").mem.zeroes(hb_var_int_t),
};
pub const hb_glyph_position_t = struct_hb_glyph_position_t;
pub const struct_hb_segment_properties_t = extern struct {
    direction: hb_direction_t = @import("std").mem.zeroes(hb_direction_t),
    script: hb_script_t = @import("std").mem.zeroes(hb_script_t),
    language: hb_language_t = null,
    reserved1: ?*anyopaque = null,
    reserved2: ?*anyopaque = null,
    pub const hb_segment_properties_equal = __root.hb_segment_properties_equal;
    pub const hb_segment_properties_hash = __root.hb_segment_properties_hash;
    pub const hb_segment_properties_overlay = __root.hb_segment_properties_overlay;
    pub const equal = __root.hb_segment_properties_equal;
    pub const hash = __root.hb_segment_properties_hash;
    pub const overlay = __root.hb_segment_properties_overlay;
};
pub const hb_segment_properties_t = struct_hb_segment_properties_t;
pub extern fn hb_segment_properties_equal(a: [*c]const hb_segment_properties_t, b: [*c]const hb_segment_properties_t) hb_bool_t;
pub extern fn hb_segment_properties_hash(p: [*c]const hb_segment_properties_t) c_uint;
pub extern fn hb_segment_properties_overlay(p: [*c]hb_segment_properties_t, src: [*c]const hb_segment_properties_t) void;
pub const struct_hb_buffer_t = opaque {
    pub const hb_buffer_create_similar = __root.hb_buffer_create_similar;
    pub const hb_buffer_reset = __root.hb_buffer_reset;
    pub const hb_buffer_reference = __root.hb_buffer_reference;
    pub const hb_buffer_destroy = __root.hb_buffer_destroy;
    pub const hb_buffer_set_user_data = __root.hb_buffer_set_user_data;
    pub const hb_buffer_get_user_data = __root.hb_buffer_get_user_data;
    pub const hb_buffer_set_content_type = __root.hb_buffer_set_content_type;
    pub const hb_buffer_get_content_type = __root.hb_buffer_get_content_type;
    pub const hb_buffer_set_unicode_funcs = __root.hb_buffer_set_unicode_funcs;
    pub const hb_buffer_get_unicode_funcs = __root.hb_buffer_get_unicode_funcs;
    pub const hb_buffer_set_direction = __root.hb_buffer_set_direction;
    pub const hb_buffer_get_direction = __root.hb_buffer_get_direction;
    pub const hb_buffer_set_script = __root.hb_buffer_set_script;
    pub const hb_buffer_get_script = __root.hb_buffer_get_script;
    pub const hb_buffer_set_language = __root.hb_buffer_set_language;
    pub const hb_buffer_get_language = __root.hb_buffer_get_language;
    pub const hb_buffer_set_segment_properties = __root.hb_buffer_set_segment_properties;
    pub const hb_buffer_get_segment_properties = __root.hb_buffer_get_segment_properties;
    pub const hb_buffer_guess_segment_properties = __root.hb_buffer_guess_segment_properties;
    pub const hb_buffer_set_flags = __root.hb_buffer_set_flags;
    pub const hb_buffer_get_flags = __root.hb_buffer_get_flags;
    pub const hb_buffer_set_cluster_level = __root.hb_buffer_set_cluster_level;
    pub const hb_buffer_get_cluster_level = __root.hb_buffer_get_cluster_level;
    pub const hb_buffer_set_replacement_codepoint = __root.hb_buffer_set_replacement_codepoint;
    pub const hb_buffer_get_replacement_codepoint = __root.hb_buffer_get_replacement_codepoint;
    pub const hb_buffer_set_invisible_glyph = __root.hb_buffer_set_invisible_glyph;
    pub const hb_buffer_get_invisible_glyph = __root.hb_buffer_get_invisible_glyph;
    pub const hb_buffer_set_not_found_glyph = __root.hb_buffer_set_not_found_glyph;
    pub const hb_buffer_get_not_found_glyph = __root.hb_buffer_get_not_found_glyph;
    pub const hb_buffer_set_not_found_variation_selector_glyph = __root.hb_buffer_set_not_found_variation_selector_glyph;
    pub const hb_buffer_get_not_found_variation_selector_glyph = __root.hb_buffer_get_not_found_variation_selector_glyph;
    pub const hb_buffer_set_random_state = __root.hb_buffer_set_random_state;
    pub const hb_buffer_get_random_state = __root.hb_buffer_get_random_state;
    pub const hb_buffer_clear_contents = __root.hb_buffer_clear_contents;
    pub const hb_buffer_pre_allocate = __root.hb_buffer_pre_allocate;
    pub const hb_buffer_allocation_successful = __root.hb_buffer_allocation_successful;
    pub const hb_buffer_reverse = __root.hb_buffer_reverse;
    pub const hb_buffer_reverse_range = __root.hb_buffer_reverse_range;
    pub const hb_buffer_reverse_clusters = __root.hb_buffer_reverse_clusters;
    pub const hb_buffer_add = __root.hb_buffer_add;
    pub const hb_buffer_add_utf8 = __root.hb_buffer_add_utf8;
    pub const hb_buffer_add_utf16 = __root.hb_buffer_add_utf16;
    pub const hb_buffer_add_utf32 = __root.hb_buffer_add_utf32;
    pub const hb_buffer_add_latin1 = __root.hb_buffer_add_latin1;
    pub const hb_buffer_add_codepoints = __root.hb_buffer_add_codepoints;
    pub const hb_buffer_append = __root.hb_buffer_append;
    pub const hb_buffer_set_length = __root.hb_buffer_set_length;
    pub const hb_buffer_get_length = __root.hb_buffer_get_length;
    pub const hb_buffer_get_glyph_infos = __root.hb_buffer_get_glyph_infos;
    pub const hb_buffer_get_glyph_positions = __root.hb_buffer_get_glyph_positions;
    pub const hb_buffer_has_positions = __root.hb_buffer_has_positions;
    pub const hb_buffer_normalize_glyphs = __root.hb_buffer_normalize_glyphs;
    pub const hb_buffer_serialize_glyphs = __root.hb_buffer_serialize_glyphs;
    pub const hb_buffer_serialize_unicode = __root.hb_buffer_serialize_unicode;
    pub const hb_buffer_serialize = __root.hb_buffer_serialize;
    pub const hb_buffer_deserialize_glyphs = __root.hb_buffer_deserialize_glyphs;
    pub const hb_buffer_deserialize_unicode = __root.hb_buffer_deserialize_unicode;
    pub const hb_buffer_diff = __root.hb_buffer_diff;
    pub const hb_buffer_set_message_func = __root.hb_buffer_set_message_func;
    pub const hb_buffer_changed = __root.hb_buffer_changed;
    pub const similar = __root.hb_buffer_create_similar;
    pub const reset = __root.hb_buffer_reset;
    pub const reference = __root.hb_buffer_reference;
    pub const destroy = __root.hb_buffer_destroy;
    pub const data = __root.hb_buffer_set_user_data;
    pub const @"type" = __root.hb_buffer_set_content_type;
    pub const funcs = __root.hb_buffer_set_unicode_funcs;
    pub const direction = __root.hb_buffer_set_direction;
    pub const script = __root.hb_buffer_set_script;
    pub const language = __root.hb_buffer_set_language;
    pub const properties = __root.hb_buffer_set_segment_properties;
    pub const flags = __root.hb_buffer_set_flags;
    pub const level = __root.hb_buffer_set_cluster_level;
    pub const codepoint = __root.hb_buffer_set_replacement_codepoint;
    pub const glyph = __root.hb_buffer_set_invisible_glyph;
    pub const state = __root.hb_buffer_set_random_state;
    pub const contents = __root.hb_buffer_clear_contents;
    pub const allocate = __root.hb_buffer_pre_allocate;
    pub const successful = __root.hb_buffer_allocation_successful;
    pub const reverse = __root.hb_buffer_reverse;
    pub const range = __root.hb_buffer_reverse_range;
    pub const clusters = __root.hb_buffer_reverse_clusters;
    pub const add = __root.hb_buffer_add;
    pub const utf8 = __root.hb_buffer_add_utf8;
    pub const utf16 = __root.hb_buffer_add_utf16;
    pub const utf32 = __root.hb_buffer_add_utf32;
    pub const latin1 = __root.hb_buffer_add_latin1;
    pub const codepoints = __root.hb_buffer_add_codepoints;
    pub const append = __root.hb_buffer_append;
    pub const length = __root.hb_buffer_set_length;
    pub const infos = __root.hb_buffer_get_glyph_infos;
    pub const positions = __root.hb_buffer_get_glyph_positions;
    pub const glyphs = __root.hb_buffer_normalize_glyphs;
    pub const unicode = __root.hb_buffer_serialize_unicode;
    pub const serialize = __root.hb_buffer_serialize;
    pub const diff = __root.hb_buffer_diff;
    pub const func = __root.hb_buffer_set_message_func;
    pub const changed = __root.hb_buffer_changed;
};
pub const hb_buffer_t = struct_hb_buffer_t;
pub extern fn hb_buffer_create() ?*hb_buffer_t;
pub extern fn hb_buffer_create_similar(src: ?*const hb_buffer_t) ?*hb_buffer_t;
pub extern fn hb_buffer_reset(buffer: ?*hb_buffer_t) void;
pub extern fn hb_buffer_get_empty() ?*hb_buffer_t;
pub extern fn hb_buffer_reference(buffer: ?*hb_buffer_t) ?*hb_buffer_t;
pub extern fn hb_buffer_destroy(buffer: ?*hb_buffer_t) void;
pub extern fn hb_buffer_set_user_data(buffer: ?*hb_buffer_t, key: [*c]hb_user_data_key_t, data: ?*anyopaque, destroy: hb_destroy_func_t, replace: hb_bool_t) hb_bool_t;
pub extern fn hb_buffer_get_user_data(buffer: ?*const hb_buffer_t, key: [*c]hb_user_data_key_t) ?*anyopaque;
pub const HB_BUFFER_CONTENT_TYPE_INVALID: c_int = 0;
pub const HB_BUFFER_CONTENT_TYPE_UNICODE: c_int = 1;
pub const HB_BUFFER_CONTENT_TYPE_GLYPHS: c_int = 2;
pub const hb_buffer_content_type_t = c_uint;
pub extern fn hb_buffer_set_content_type(buffer: ?*hb_buffer_t, content_type: hb_buffer_content_type_t) void;
pub extern fn hb_buffer_get_content_type(buffer: ?*const hb_buffer_t) hb_buffer_content_type_t;
pub extern fn hb_buffer_set_unicode_funcs(buffer: ?*hb_buffer_t, unicode_funcs: ?*hb_unicode_funcs_t) void;
pub extern fn hb_buffer_get_unicode_funcs(buffer: ?*const hb_buffer_t) ?*hb_unicode_funcs_t;
pub extern fn hb_buffer_set_direction(buffer: ?*hb_buffer_t, direction: hb_direction_t) void;
pub extern fn hb_buffer_get_direction(buffer: ?*const hb_buffer_t) hb_direction_t;
pub extern fn hb_buffer_set_script(buffer: ?*hb_buffer_t, script: hb_script_t) void;
pub extern fn hb_buffer_get_script(buffer: ?*const hb_buffer_t) hb_script_t;
pub extern fn hb_buffer_set_language(buffer: ?*hb_buffer_t, language: hb_language_t) void;
pub extern fn hb_buffer_get_language(buffer: ?*const hb_buffer_t) hb_language_t;
pub extern fn hb_buffer_set_segment_properties(buffer: ?*hb_buffer_t, props: [*c]const hb_segment_properties_t) void;
pub extern fn hb_buffer_get_segment_properties(buffer: ?*const hb_buffer_t, props: [*c]hb_segment_properties_t) void;
pub extern fn hb_buffer_guess_segment_properties(buffer: ?*hb_buffer_t) void;
pub const HB_BUFFER_FLAG_DEFAULT: c_int = 0;
pub const HB_BUFFER_FLAG_BOT: c_int = 1;
pub const HB_BUFFER_FLAG_EOT: c_int = 2;
pub const HB_BUFFER_FLAG_PRESERVE_DEFAULT_IGNORABLES: c_int = 4;
pub const HB_BUFFER_FLAG_REMOVE_DEFAULT_IGNORABLES: c_int = 8;
pub const HB_BUFFER_FLAG_DO_NOT_INSERT_DOTTED_CIRCLE: c_int = 16;
pub const HB_BUFFER_FLAG_VERIFY: c_int = 32;
pub const HB_BUFFER_FLAG_PRODUCE_UNSAFE_TO_CONCAT: c_int = 64;
pub const HB_BUFFER_FLAG_PRODUCE_SAFE_TO_INSERT_TATWEEL: c_int = 128;
pub const HB_BUFFER_FLAG_DEFINED: c_int = 255;
pub const hb_buffer_flags_t = c_uint;
pub extern fn hb_buffer_set_flags(buffer: ?*hb_buffer_t, flags: hb_buffer_flags_t) void;
pub extern fn hb_buffer_get_flags(buffer: ?*const hb_buffer_t) hb_buffer_flags_t;
pub const HB_BUFFER_CLUSTER_LEVEL_MONOTONE_GRAPHEMES: c_int = 0;
pub const HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS: c_int = 1;
pub const HB_BUFFER_CLUSTER_LEVEL_CHARACTERS: c_int = 2;
pub const HB_BUFFER_CLUSTER_LEVEL_GRAPHEMES: c_int = 3;
pub const HB_BUFFER_CLUSTER_LEVEL_DEFAULT: c_int = 0;
pub const hb_buffer_cluster_level_t = c_uint;
pub extern fn hb_buffer_set_cluster_level(buffer: ?*hb_buffer_t, cluster_level: hb_buffer_cluster_level_t) void;
pub extern fn hb_buffer_get_cluster_level(buffer: ?*const hb_buffer_t) hb_buffer_cluster_level_t;
pub extern fn hb_buffer_set_replacement_codepoint(buffer: ?*hb_buffer_t, replacement: hb_codepoint_t) void;
pub extern fn hb_buffer_get_replacement_codepoint(buffer: ?*const hb_buffer_t) hb_codepoint_t;
pub extern fn hb_buffer_set_invisible_glyph(buffer: ?*hb_buffer_t, invisible: hb_codepoint_t) void;
pub extern fn hb_buffer_get_invisible_glyph(buffer: ?*const hb_buffer_t) hb_codepoint_t;
pub extern fn hb_buffer_set_not_found_glyph(buffer: ?*hb_buffer_t, not_found: hb_codepoint_t) void;
pub extern fn hb_buffer_get_not_found_glyph(buffer: ?*const hb_buffer_t) hb_codepoint_t;
pub extern fn hb_buffer_set_not_found_variation_selector_glyph(buffer: ?*hb_buffer_t, not_found_variation_selector: hb_codepoint_t) void;
pub extern fn hb_buffer_get_not_found_variation_selector_glyph(buffer: ?*const hb_buffer_t) hb_codepoint_t;
pub extern fn hb_buffer_set_random_state(buffer: ?*hb_buffer_t, state: c_uint) void;
pub extern fn hb_buffer_get_random_state(buffer: ?*const hb_buffer_t) c_uint;
pub extern fn hb_buffer_clear_contents(buffer: ?*hb_buffer_t) void;
pub extern fn hb_buffer_pre_allocate(buffer: ?*hb_buffer_t, size: c_uint) hb_bool_t;
pub extern fn hb_buffer_allocation_successful(buffer: ?*hb_buffer_t) hb_bool_t;
pub extern fn hb_buffer_reverse(buffer: ?*hb_buffer_t) void;
pub extern fn hb_buffer_reverse_range(buffer: ?*hb_buffer_t, start: c_uint, end: c_uint) void;
pub extern fn hb_buffer_reverse_clusters(buffer: ?*hb_buffer_t) void;
pub extern fn hb_buffer_add(buffer: ?*hb_buffer_t, codepoint: hb_codepoint_t, cluster: c_uint) void;
pub extern fn hb_buffer_add_utf8(buffer: ?*hb_buffer_t, text: [*c]const u8, text_length: c_int, item_offset: c_uint, item_length: c_int) void;
pub extern fn hb_buffer_add_utf16(buffer: ?*hb_buffer_t, text: [*c]const u16, text_length: c_int, item_offset: c_uint, item_length: c_int) void;
pub extern fn hb_buffer_add_utf32(buffer: ?*hb_buffer_t, text: [*c]const u32, text_length: c_int, item_offset: c_uint, item_length: c_int) void;
pub extern fn hb_buffer_add_latin1(buffer: ?*hb_buffer_t, text: [*c]const u8, text_length: c_int, item_offset: c_uint, item_length: c_int) void;
pub extern fn hb_buffer_add_codepoints(buffer: ?*hb_buffer_t, text: [*c]const hb_codepoint_t, text_length: c_int, item_offset: c_uint, item_length: c_int) void;
pub extern fn hb_buffer_append(buffer: ?*hb_buffer_t, source: ?*const hb_buffer_t, start: c_uint, end: c_uint) void;
pub extern fn hb_buffer_set_length(buffer: ?*hb_buffer_t, length: c_uint) hb_bool_t;
pub extern fn hb_buffer_get_length(buffer: ?*const hb_buffer_t) c_uint;
pub extern fn hb_buffer_get_glyph_infos(buffer: ?*hb_buffer_t, length: [*c]c_uint) [*c]hb_glyph_info_t;
pub extern fn hb_buffer_get_glyph_positions(buffer: ?*hb_buffer_t, length: [*c]c_uint) [*c]hb_glyph_position_t;
pub extern fn hb_buffer_has_positions(buffer: ?*hb_buffer_t) hb_bool_t;
pub extern fn hb_buffer_normalize_glyphs(buffer: ?*hb_buffer_t) void;
pub const HB_BUFFER_SERIALIZE_FLAG_DEFAULT: c_int = 0;
pub const HB_BUFFER_SERIALIZE_FLAG_NO_CLUSTERS: c_int = 1;
pub const HB_BUFFER_SERIALIZE_FLAG_NO_POSITIONS: c_int = 2;
pub const HB_BUFFER_SERIALIZE_FLAG_NO_GLYPH_NAMES: c_int = 4;
pub const HB_BUFFER_SERIALIZE_FLAG_GLYPH_EXTENTS: c_int = 8;
pub const HB_BUFFER_SERIALIZE_FLAG_GLYPH_FLAGS: c_int = 16;
pub const HB_BUFFER_SERIALIZE_FLAG_NO_ADVANCES: c_int = 32;
pub const HB_BUFFER_SERIALIZE_FLAG_DEFINED: c_int = 63;
pub const hb_buffer_serialize_flags_t = c_uint;
pub const HB_BUFFER_SERIALIZE_FORMAT_TEXT: c_int = 1413830740;
pub const HB_BUFFER_SERIALIZE_FORMAT_JSON: c_int = 1246973774;
pub const HB_BUFFER_SERIALIZE_FORMAT_INVALID: c_int = 0;
pub const hb_buffer_serialize_format_t = c_uint;
pub extern fn hb_buffer_serialize_format_from_string(str: [*c]const u8, len: c_int) hb_buffer_serialize_format_t;
pub extern fn hb_buffer_serialize_format_to_string(format: hb_buffer_serialize_format_t) [*c]const u8;
pub extern fn hb_buffer_serialize_list_formats() [*c][*c]const u8;
pub extern fn hb_buffer_serialize_glyphs(buffer: ?*hb_buffer_t, start: c_uint, end: c_uint, buf: [*c]u8, buf_size: c_uint, buf_consumed: [*c]c_uint, font: ?*hb_font_t, format: hb_buffer_serialize_format_t, flags: hb_buffer_serialize_flags_t) c_uint;
pub extern fn hb_buffer_serialize_unicode(buffer: ?*hb_buffer_t, start: c_uint, end: c_uint, buf: [*c]u8, buf_size: c_uint, buf_consumed: [*c]c_uint, format: hb_buffer_serialize_format_t, flags: hb_buffer_serialize_flags_t) c_uint;
pub extern fn hb_buffer_serialize(buffer: ?*hb_buffer_t, start: c_uint, end: c_uint, buf: [*c]u8, buf_size: c_uint, buf_consumed: [*c]c_uint, font: ?*hb_font_t, format: hb_buffer_serialize_format_t, flags: hb_buffer_serialize_flags_t) c_uint;
pub extern fn hb_buffer_deserialize_glyphs(buffer: ?*hb_buffer_t, buf: [*c]const u8, buf_len: c_int, end_ptr: [*c][*c]const u8, font: ?*hb_font_t, format: hb_buffer_serialize_format_t) hb_bool_t;
pub extern fn hb_buffer_deserialize_unicode(buffer: ?*hb_buffer_t, buf: [*c]const u8, buf_len: c_int, end_ptr: [*c][*c]const u8, format: hb_buffer_serialize_format_t) hb_bool_t;
pub const HB_BUFFER_DIFF_FLAG_EQUAL: c_int = 0;
pub const HB_BUFFER_DIFF_FLAG_CONTENT_TYPE_MISMATCH: c_int = 1;
pub const HB_BUFFER_DIFF_FLAG_LENGTH_MISMATCH: c_int = 2;
pub const HB_BUFFER_DIFF_FLAG_NOTDEF_PRESENT: c_int = 4;
pub const HB_BUFFER_DIFF_FLAG_DOTTED_CIRCLE_PRESENT: c_int = 8;
pub const HB_BUFFER_DIFF_FLAG_CODEPOINT_MISMATCH: c_int = 16;
pub const HB_BUFFER_DIFF_FLAG_CLUSTER_MISMATCH: c_int = 32;
pub const HB_BUFFER_DIFF_FLAG_GLYPH_FLAGS_MISMATCH: c_int = 64;
pub const HB_BUFFER_DIFF_FLAG_POSITION_MISMATCH: c_int = 128;
pub const hb_buffer_diff_flags_t = c_uint;
pub extern fn hb_buffer_diff(buffer: ?*hb_buffer_t, reference: ?*hb_buffer_t, dottedcircle_glyph: hb_codepoint_t, position_fuzz: c_uint) hb_buffer_diff_flags_t;
pub const hb_buffer_message_func_t = ?*const fn (buffer: ?*hb_buffer_t, font: ?*hb_font_t, message: [*c]const u8, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub extern fn hb_buffer_set_message_func(buffer: ?*hb_buffer_t, func: hb_buffer_message_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_buffer_changed(buffer: ?*hb_buffer_t) void;
pub const hb_font_get_glyph_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, unicode: hb_codepoint_t, variation_selector: hb_codepoint_t, glyph: [*c]hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub extern fn hb_font_funcs_set_glyph_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub const hb_unicode_eastasian_width_func_t = ?*const fn (ufuncs: ?*hb_unicode_funcs_t, unicode: hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) c_uint;
pub extern fn hb_unicode_funcs_set_eastasian_width_func(ufuncs: ?*hb_unicode_funcs_t, func: hb_unicode_eastasian_width_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_unicode_eastasian_width(ufuncs: ?*hb_unicode_funcs_t, unicode: hb_codepoint_t) c_uint;
pub const hb_unicode_decompose_compatibility_func_t = ?*const fn (ufuncs: ?*hb_unicode_funcs_t, u: hb_codepoint_t, decomposed: [*c]hb_codepoint_t, user_data: ?*anyopaque) callconv(.c) c_uint;
pub extern fn hb_unicode_funcs_set_decompose_compatibility_func(ufuncs: ?*hb_unicode_funcs_t, func: hb_unicode_decompose_compatibility_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_unicode_decompose_compatibility(ufuncs: ?*hb_unicode_funcs_t, u: hb_codepoint_t, decomposed: [*c]hb_codepoint_t) c_uint;
pub const hb_font_get_glyph_v_kerning_func_t = hb_font_get_glyph_kerning_func_t;
pub extern fn hb_font_funcs_set_glyph_v_kerning_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_v_kerning_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_get_glyph_v_kerning(font: ?*hb_font_t, top_glyph: hb_codepoint_t, bottom_glyph: hb_codepoint_t) hb_position_t;
pub const hb_font_get_glyph_shape_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, glyph: hb_codepoint_t, draw_funcs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_font_draw_glyph_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, glyph: hb_codepoint_t, draw_funcs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque, user_data: ?*anyopaque) callconv(.c) void;
pub const hb_font_paint_glyph_func_t = ?*const fn (font: ?*hb_font_t, font_data: ?*anyopaque, glyph: hb_codepoint_t, paint_funcs: ?*hb_paint_funcs_t, paint_data: ?*anyopaque, palette_index: c_uint, foreground: hb_color_t, user_data: ?*anyopaque) callconv(.c) hb_bool_t;
pub extern fn hb_font_funcs_set_glyph_shape_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_get_glyph_shape_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_draw_glyph_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_draw_glyph_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_funcs_set_paint_glyph_func(ffuncs: ?*hb_font_funcs_t, func: hb_font_paint_glyph_func_t, user_data: ?*anyopaque, destroy: hb_destroy_func_t) void;
pub extern fn hb_font_get_glyph_shape(font: ?*hb_font_t, glyph: hb_codepoint_t, dfuncs: ?*hb_draw_funcs_t, draw_data: ?*anyopaque) void;
pub extern fn hb_shape(font: ?*hb_font_t, buffer: ?*hb_buffer_t, features: [*c]const hb_feature_t, num_features: c_uint) void;
pub extern fn hb_shape_full(font: ?*hb_font_t, buffer: ?*hb_buffer_t, features: [*c]const hb_feature_t, num_features: c_uint, shaper_list: [*c]const [*c]const u8) hb_bool_t;
pub extern fn hb_shape_list_shapers() [*c][*c]const u8;
pub const struct_hb_shape_plan_t = opaque {
    pub const hb_shape_plan_reference = __root.hb_shape_plan_reference;
    pub const hb_shape_plan_destroy = __root.hb_shape_plan_destroy;
    pub const hb_shape_plan_set_user_data = __root.hb_shape_plan_set_user_data;
    pub const hb_shape_plan_get_user_data = __root.hb_shape_plan_get_user_data;
    pub const hb_shape_plan_execute = __root.hb_shape_plan_execute;
    pub const hb_shape_plan_get_shaper = __root.hb_shape_plan_get_shaper;
    pub const reference = __root.hb_shape_plan_reference;
    pub const destroy = __root.hb_shape_plan_destroy;
    pub const data = __root.hb_shape_plan_set_user_data;
    pub const execute = __root.hb_shape_plan_execute;
    pub const shaper = __root.hb_shape_plan_get_shaper;
};
pub const hb_shape_plan_t = struct_hb_shape_plan_t;
pub extern fn hb_shape_plan_create(face: ?*hb_face_t, props: [*c]const hb_segment_properties_t, user_features: [*c]const hb_feature_t, num_user_features: c_uint, shaper_list: [*c]const [*c]const u8) ?*hb_shape_plan_t;
pub extern fn hb_shape_plan_create_cached(face: ?*hb_face_t, props: [*c]const hb_segment_properties_t, user_features: [*c]const hb_feature_t, num_user_features: c_uint, shaper_list: [*c]const [*c]const u8) ?*hb_shape_plan_t;
pub extern fn hb_shape_plan_create2(face: ?*hb_face_t, props: [*c]const hb_segment_properties_t, user_features: [*c]const hb_feature_t, num_user_features: c_uint, coords: [*c]const c_int, num_coords: c_uint, shaper_list: [*c]const [*c]const u8) ?*hb_shape_plan_t;
pub extern fn hb_shape_plan_create_cached2(face: ?*hb_face_t, props: [*c]const hb_segment_properties_t, user_features: [*c]const hb_feature_t, num_user_features: c_uint, coords: [*c]const c_int, num_coords: c_uint, shaper_list: [*c]const [*c]const u8) ?*hb_shape_plan_t;
pub extern fn hb_shape_plan_get_empty() ?*hb_shape_plan_t;
pub extern fn hb_shape_plan_reference(shape_plan: ?*hb_shape_plan_t) ?*hb_shape_plan_t;
pub extern fn hb_shape_plan_destroy(shape_plan: ?*hb_shape_plan_t) void;
pub extern fn hb_shape_plan_set_user_data(shape_plan: ?*hb_shape_plan_t, key: [*c]hb_user_data_key_t, data: ?*anyopaque, destroy: hb_destroy_func_t, replace: hb_bool_t) hb_bool_t;
pub extern fn hb_shape_plan_get_user_data(shape_plan: ?*const hb_shape_plan_t, key: [*c]hb_user_data_key_t) ?*anyopaque;
pub extern fn hb_shape_plan_execute(shape_plan: ?*hb_shape_plan_t, font: ?*hb_font_t, buffer: ?*hb_buffer_t, features: [*c]const hb_feature_t, num_features: c_uint) hb_bool_t;
pub extern fn hb_shape_plan_get_shaper(shape_plan: ?*hb_shape_plan_t) [*c]const u8;
pub const HB_STYLE_TAG_ITALIC: c_int = 1769234796;
pub const HB_STYLE_TAG_OPTICAL_SIZE: c_int = 1869640570;
pub const HB_STYLE_TAG_SLANT_ANGLE: c_int = 1936486004;
pub const HB_STYLE_TAG_SLANT_RATIO: c_int = 1399615092;
pub const HB_STYLE_TAG_WIDTH: c_int = 2003072104;
pub const HB_STYLE_TAG_WEIGHT: c_int = 2003265652;
pub const _HB_STYLE_TAG_MAX_VALUE: c_int = 2147483647;
pub const hb_style_tag_t = c_uint;
pub extern fn hb_style_get_value(font: ?*hb_font_t, style_tag: hb_style_tag_t) f32;
pub extern fn hb_version(major: [*c]c_uint, minor: [*c]c_uint, micro: [*c]c_uint) void;
pub extern fn hb_version_string() [*c]const u8;
pub extern fn hb_version_atleast(major: c_uint, minor: c_uint, micro: c_uint) hb_bool_t;
pub extern fn memcpy(noalias __dest: ?*anyopaque, noalias __src: ?*const anyopaque, __n: usize) ?*anyopaque;
pub extern fn memmove(__dest: ?*anyopaque, __src: ?*const anyopaque, __n: usize) ?*anyopaque;
pub extern fn memccpy(noalias __dest: ?*anyopaque, noalias __src: ?*const anyopaque, __c: c_int, __n: usize) ?*anyopaque;
pub extern fn memset(__s: ?*anyopaque, __c: c_int, __n: usize) ?*anyopaque;
pub extern fn memset_explicit(__s: ?*anyopaque, __c: c_int, __n: usize) ?*anyopaque;
pub extern fn memcmp(__s1: ?*const anyopaque, __s2: ?*const anyopaque, __n: usize) c_int;
pub extern fn __memcmpeq(__s1: ?*const anyopaque, __s2: ?*const anyopaque, __n: usize) c_int;
pub extern fn memchr(__s: ?*const anyopaque, __c: c_int, __n: usize) ?*anyopaque;
pub extern fn strcpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8) [*c]u8;
pub extern fn strncpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) [*c]u8;
pub extern fn strcat(noalias __dest: [*c]u8, noalias __src: [*c]const u8) [*c]u8;
pub extern fn strncat(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) [*c]u8;
pub extern fn strcmp(__s1: [*c]const u8, __s2: [*c]const u8) c_int;
pub extern fn strncmp(__s1: [*c]const u8, __s2: [*c]const u8, __n: usize) c_int;
pub extern fn strcoll(__s1: [*c]const u8, __s2: [*c]const u8) c_int;
pub extern fn strxfrm(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) usize;
pub const struct___locale_data_1 = opaque {};
pub const struct___locale_struct = extern struct {
    __locales: [13]?*struct___locale_data_1 = @import("std").mem.zeroes([13]?*struct___locale_data_1),
    __ctype_b: [*c]const c_ushort = null,
    __ctype_tolower: [*c]const c_int = null,
    __ctype_toupper: [*c]const c_int = null,
    __names: [13][*c]const u8 = @import("std").mem.zeroes([13][*c]const u8),
};
pub const __locale_t = [*c]struct___locale_struct;
pub const locale_t = __locale_t;
pub extern fn strcoll_l(__s1: [*c]const u8, __s2: [*c]const u8, __l: locale_t) c_int;
pub extern fn strxfrm_l(__dest: [*c]u8, __src: [*c]const u8, __n: usize, __l: locale_t) usize;
pub extern fn strdup(__s: [*c]const u8) [*c]u8;
pub extern fn strndup(__string: [*c]const u8, __n: usize) [*c]u8;
pub extern fn strchr(__s: [*c]const u8, __c: c_int) [*c]u8;
pub extern fn strrchr(__s: [*c]const u8, __c: c_int) [*c]u8;
pub extern fn strchrnul(__s: [*c]const u8, __c: c_int) [*c]u8;
pub extern fn strcspn(__s: [*c]const u8, __reject: [*c]const u8) usize;
pub extern fn strspn(__s: [*c]const u8, __accept: [*c]const u8) usize;
pub extern fn strpbrk(__s: [*c]const u8, __accept: [*c]const u8) [*c]u8;
pub extern fn strstr(__haystack: [*c]const u8, __needle: [*c]const u8) [*c]u8;
pub extern fn strtok(noalias __s: [*c]u8, noalias __delim: [*c]const u8) [*c]u8;
pub extern fn __strtok_r(noalias __s: [*c]u8, noalias __delim: [*c]const u8, noalias __save_ptr: [*c][*c]u8) [*c]u8;
pub extern fn strtok_r(noalias __s: [*c]u8, noalias __delim: [*c]const u8, noalias __save_ptr: [*c][*c]u8) [*c]u8;
pub extern fn strcasestr(__haystack: [*c]const u8, __needle: [*c]const u8) [*c]u8;
pub extern fn memmem(__haystack: ?*const anyopaque, __haystacklen: usize, __needle: ?*const anyopaque, __needlelen: usize) ?*anyopaque;
pub extern fn __mempcpy(noalias __dest: ?*anyopaque, noalias __src: ?*const anyopaque, __n: usize) ?*anyopaque;
pub extern fn mempcpy(noalias __dest: ?*anyopaque, noalias __src: ?*const anyopaque, __n: usize) ?*anyopaque;
pub extern fn strlen(__s: [*c]const u8) usize;
pub extern fn strnlen(__string: [*c]const u8, __maxlen: usize) usize;
pub extern fn strerror(__errnum: c_int) [*c]u8;
pub extern fn strerror_r(__errnum: c_int, __buf: [*c]u8, __buflen: usize) c_int;
pub extern fn strerror_l(__errnum: c_int, __l: locale_t) [*c]u8;
pub extern fn bcmp(__s1: ?*const anyopaque, __s2: ?*const anyopaque, __n: usize) c_int;
pub extern fn bcopy(__src: ?*const anyopaque, __dest: ?*anyopaque, __n: usize) void;
pub extern fn bzero(__s: ?*anyopaque, __n: usize) void;
pub extern fn index(__s: [*c]const u8, __c: c_int) [*c]u8;
pub extern fn rindex(__s: [*c]const u8, __c: c_int) [*c]u8;
pub extern fn ffs(__i: c_int) c_int;
pub extern fn ffsl(__l: c_long) c_int;
pub extern fn ffsll(__ll: c_longlong) c_int;
pub extern fn strcasecmp(__s1: [*c]const u8, __s2: [*c]const u8) c_int;
pub extern fn strncasecmp(__s1: [*c]const u8, __s2: [*c]const u8, __n: usize) c_int;
pub extern fn strcasecmp_l(__s1: [*c]const u8, __s2: [*c]const u8, __loc: locale_t) c_int;
pub extern fn strncasecmp_l(__s1: [*c]const u8, __s2: [*c]const u8, __n: usize, __loc: locale_t) c_int;
pub extern fn explicit_bzero(__s: ?*anyopaque, __n: usize) void;
pub extern fn strsep(noalias __stringp: [*c][*c]u8, noalias __delim: [*c]const u8) [*c]u8;
pub extern fn strsignal(__sig: c_int) [*c]u8;
pub extern fn __stpcpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8) [*c]u8;
pub extern fn stpcpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8) [*c]u8;
pub extern fn __stpncpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) [*c]u8;
pub extern fn stpncpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) [*c]u8;
pub extern fn strlcpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) usize;
pub extern fn strlcat(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) usize;
pub const struct___va_list_tag_2 = extern struct {
    unnamed_0: c_uint = 0,
    unnamed_1: c_uint = 0,
    unnamed_2: ?*anyopaque = null,
    unnamed_3: ?*anyopaque = null,
};
pub const __builtin_va_list = [1]struct___va_list_tag_2;
pub const va_list = __builtin_va_list;
pub const __gnuc_va_list = __builtin_va_list;
const union_unnamed_3 = extern union {
    __wch: c_uint,
    __wchb: [4]u8,
};
pub const __mbstate_t = extern struct {
    __count: c_int = 0,
    __value: union_unnamed_3 = @import("std").mem.zeroes(union_unnamed_3),
};
pub const struct__G_fpos_t = extern struct {
    __pos: __off_t = 0,
    __state: __mbstate_t = @import("std").mem.zeroes(__mbstate_t),
};
pub const __fpos_t = struct__G_fpos_t;
pub const struct__G_fpos64_t = extern struct {
    __pos: __off64_t = 0,
    __state: __mbstate_t = @import("std").mem.zeroes(__mbstate_t),
};
pub const __fpos64_t = struct__G_fpos64_t;
pub const struct__IO_marker = opaque {}; // /usr/include/bits/types/struct_FILE.h:75:7: warning: struct demoted to opaque type - has bitfield
pub const struct__IO_FILE = opaque {
    pub const fclose = __root.fclose;
    pub const fflush = __root.fflush;
    pub const fflush_unlocked = __root.fflush_unlocked;
    pub const setbuf = __root.setbuf;
    pub const setvbuf = __root.setvbuf;
    pub const setbuffer = __root.setbuffer;
    pub const setlinebuf = __root.setlinebuf;
    pub const fprintf = __root.fprintf;
    pub const vfprintf = __root.vfprintf;
    pub const fscanf = __root.fscanf;
    pub const vfscanf = __root.vfscanf;
    pub const fgetc = __root.fgetc;
    pub const getc = __root.getc;
    pub const getc_unlocked = __root.getc_unlocked;
    pub const fgetc_unlocked = __root.fgetc_unlocked;
    pub const getw = __root.getw;
    pub const fseek = __root.fseek;
    pub const ftell = __root.ftell;
    pub const rewind = __root.rewind;
    pub const fseeko = __root.fseeko;
    pub const ftello = __root.ftello;
    pub const fgetpos = __root.fgetpos;
    pub const fsetpos = __root.fsetpos;
    pub const clearerr = __root.clearerr;
    pub const feof = __root.feof;
    pub const ferror = __root.ferror;
    pub const clearerr_unlocked = __root.clearerr_unlocked;
    pub const feof_unlocked = __root.feof_unlocked;
    pub const ferror_unlocked = __root.ferror_unlocked;
    pub const fileno = __root.fileno;
    pub const fileno_unlocked = __root.fileno_unlocked;
    pub const pclose = __root.pclose;
    pub const flockfile = __root.flockfile;
    pub const ftrylockfile = __root.ftrylockfile;
    pub const funlockfile = __root.funlockfile;
    pub const __uflow = __root.__uflow;
    pub const __overflow = __root.__overflow;
    pub const unlocked = __root.fflush_unlocked;
    pub const uflow = __root.__uflow;
    pub const overflow = __root.__overflow;
};
pub const __FILE = struct__IO_FILE;
pub const FILE = struct__IO_FILE;
pub const struct__IO_codecvt = opaque {};
pub const struct__IO_wide_data = opaque {};
pub const _IO_lock_t = anyopaque;
pub const cookie_read_function_t = fn (__cookie: ?*anyopaque, __buf: [*c]u8, __nbytes: usize) callconv(.c) __ssize_t;
pub const cookie_write_function_t = fn (__cookie: ?*anyopaque, __buf: [*c]const u8, __nbytes: usize) callconv(.c) __ssize_t;
pub const cookie_seek_function_t = fn (__cookie: ?*anyopaque, __pos: [*c]__off64_t, __w: c_int) callconv(.c) c_int;
pub const cookie_close_function_t = fn (__cookie: ?*anyopaque) callconv(.c) c_int;
pub const struct__IO_cookie_io_functions_t = extern struct {
    read: ?*const cookie_read_function_t = null,
    write: ?*const cookie_write_function_t = null,
    seek: ?*const cookie_seek_function_t = null,
    close: ?*const cookie_close_function_t = null,
};
pub const cookie_io_functions_t = struct__IO_cookie_io_functions_t;
pub const off_t = __off_t;
pub const fpos_t = __fpos_t;
pub extern var stdin: ?*FILE;
pub extern var stdout: ?*FILE;
pub extern var stderr: ?*FILE;
pub extern fn remove(__filename: [*c]const u8) c_int;
pub extern fn rename(__old: [*c]const u8, __new: [*c]const u8) c_int;
pub extern fn renameat(__oldfd: c_int, __old: [*c]const u8, __newfd: c_int, __new: [*c]const u8) c_int;
pub extern fn fclose(__stream: ?*FILE) c_int;
pub extern fn tmpfile() ?*FILE;
pub extern fn tmpnam([*c]u8) [*c]u8;
pub extern fn tmpnam_r(__s: [*c]u8) [*c]u8;
pub extern fn tempnam(__dir: [*c]const u8, __pfx: [*c]const u8) [*c]u8;
pub extern fn fflush(__stream: ?*FILE) c_int;
pub extern fn fflush_unlocked(__stream: ?*FILE) c_int;
pub extern fn fopen(noalias __filename: [*c]const u8, noalias __modes: [*c]const u8) ?*FILE;
pub extern fn freopen(noalias __filename: [*c]const u8, noalias __modes: [*c]const u8, noalias __stream: ?*FILE) ?*FILE;
pub extern fn fdopen(__fd: c_int, __modes: [*c]const u8) ?*FILE;
pub extern fn fopencookie(noalias __magic_cookie: ?*anyopaque, noalias __modes: [*c]const u8, __io_funcs: cookie_io_functions_t) ?*FILE;
pub extern fn fmemopen(__s: ?*anyopaque, __len: usize, __modes: [*c]const u8) ?*FILE;
pub extern fn open_memstream(__bufloc: [*c][*c]u8, __sizeloc: [*c]usize) ?*FILE;
pub extern fn setbuf(noalias __stream: ?*FILE, noalias __buf: [*c]u8) void;
pub extern fn setvbuf(noalias __stream: ?*FILE, noalias __buf: [*c]u8, __modes: c_int, __n: usize) c_int;
pub extern fn setbuffer(noalias __stream: ?*FILE, noalias __buf: [*c]u8, __size: usize) void;
pub extern fn setlinebuf(__stream: ?*FILE) void;
pub extern fn fprintf(noalias __stream: ?*FILE, noalias __format: [*c]const u8, ...) c_int;
pub extern fn printf(noalias __format: [*c]const u8, ...) c_int;
pub extern fn sprintf(noalias __s: [*c]u8, noalias __format: [*c]const u8, ...) c_int;
pub extern fn vfprintf(noalias __s: ?*FILE, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) c_int;
pub extern fn vprintf(noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) c_int;
pub extern fn vsprintf(noalias __s: [*c]u8, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) c_int;
pub extern fn snprintf(noalias __s: [*c]u8, __maxlen: usize, noalias __format: [*c]const u8, ...) c_int;
pub extern fn vsnprintf(noalias __s: [*c]u8, __maxlen: usize, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) c_int;
pub extern fn vasprintf(noalias __ptr: [*c][*c]u8, noalias __f: [*c]const u8, __arg: [*c]struct___va_list_tag_2) c_int;
pub extern fn __asprintf(noalias __ptr: [*c][*c]u8, noalias __fmt: [*c]const u8, ...) c_int;
pub extern fn asprintf(noalias __ptr: [*c][*c]u8, noalias __fmt: [*c]const u8, ...) c_int;
pub extern fn vdprintf(__fd: c_int, noalias __fmt: [*c]const u8, __arg: [*c]struct___va_list_tag_2) c_int;
pub extern fn dprintf(__fd: c_int, noalias __fmt: [*c]const u8, ...) c_int;
pub extern fn fscanf(noalias __stream: ?*FILE, noalias __format: [*c]const u8, ...) c_int;
pub extern fn scanf(noalias __format: [*c]const u8, ...) c_int;
pub extern fn sscanf(noalias __s: [*c]const u8, noalias __format: [*c]const u8, ...) c_int;
pub extern fn vfscanf(noalias __s: ?*FILE, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) c_int;
pub extern fn vscanf(noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) c_int;
pub extern fn vsscanf(noalias __s: [*c]const u8, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) c_int;
pub extern fn fgetc(__stream: ?*FILE) c_int;
pub extern fn getc(__stream: ?*FILE) c_int;
pub extern fn getchar() c_int;
pub extern fn getc_unlocked(__stream: ?*FILE) c_int;
pub extern fn getchar_unlocked() c_int;
pub extern fn fgetc_unlocked(__stream: ?*FILE) c_int;
pub extern fn fputc(__c: c_int, __stream: ?*FILE) c_int;
pub extern fn putc(__c: c_int, __stream: ?*FILE) c_int;
pub extern fn putchar(__c: c_int) c_int;
pub extern fn fputc_unlocked(__c: c_int, __stream: ?*FILE) c_int;
pub extern fn putc_unlocked(__c: c_int, __stream: ?*FILE) c_int;
pub extern fn putchar_unlocked(__c: c_int) c_int;
pub extern fn getw(__stream: ?*FILE) c_int;
pub extern fn putw(__w: c_int, __stream: ?*FILE) c_int;
pub extern fn fgets(noalias __s: [*c]u8, __n: c_int, noalias __stream: ?*FILE) [*c]u8;
pub extern fn __getdelim(noalias __lineptr: [*c][*c]u8, noalias __n: [*c]usize, __delimiter: c_int, noalias __stream: ?*FILE) __ssize_t;
pub extern fn getdelim(noalias __lineptr: [*c][*c]u8, noalias __n: [*c]usize, __delimiter: c_int, noalias __stream: ?*FILE) __ssize_t;
pub extern fn getline(noalias __lineptr: [*c][*c]u8, noalias __n: [*c]usize, noalias __stream: ?*FILE) __ssize_t;
pub extern fn fputs(noalias __s: [*c]const u8, noalias __stream: ?*FILE) c_int;
pub extern fn puts(__s: [*c]const u8) c_int;
pub extern fn ungetc(__c: c_int, __stream: ?*FILE) c_int;
pub extern fn fread(noalias __ptr: ?*anyopaque, __size: usize, __n: usize, noalias __stream: ?*FILE) usize;
pub extern fn fwrite(noalias __ptr: ?*const anyopaque, __size: usize, __n: usize, noalias __s: ?*FILE) usize;
pub extern fn fread_unlocked(noalias __ptr: ?*anyopaque, __size: usize, __n: usize, noalias __stream: ?*FILE) usize;
pub extern fn fwrite_unlocked(noalias __ptr: ?*const anyopaque, __size: usize, __n: usize, noalias __stream: ?*FILE) usize;
pub extern fn fseek(__stream: ?*FILE, __off: c_long, __whence: c_int) c_int;
pub extern fn ftell(__stream: ?*FILE) c_long;
pub extern fn rewind(__stream: ?*FILE) void;
pub extern fn fseeko(__stream: ?*FILE, __off: __off_t, __whence: c_int) c_int;
pub extern fn ftello(__stream: ?*FILE) __off_t;
pub extern fn fgetpos(noalias __stream: ?*FILE, noalias __pos: [*c]fpos_t) c_int;
pub extern fn fsetpos(__stream: ?*FILE, __pos: [*c]const fpos_t) c_int;
pub extern fn clearerr(__stream: ?*FILE) void;
pub extern fn feof(__stream: ?*FILE) c_int;
pub extern fn ferror(__stream: ?*FILE) c_int;
pub extern fn clearerr_unlocked(__stream: ?*FILE) void;
pub extern fn feof_unlocked(__stream: ?*FILE) c_int;
pub extern fn ferror_unlocked(__stream: ?*FILE) c_int;
pub extern fn perror(__s: [*c]const u8) void;
pub extern fn fileno(__stream: ?*FILE) c_int;
pub extern fn fileno_unlocked(__stream: ?*FILE) c_int;
pub extern fn pclose(__stream: ?*FILE) c_int;
pub extern fn popen(__command: [*c]const u8, __modes: [*c]const u8) ?*FILE;
pub extern fn ctermid(__s: [*c]u8) [*c]u8;
pub extern fn flockfile(__stream: ?*FILE) void;
pub extern fn ftrylockfile(__stream: ?*FILE) c_int;
pub extern fn funlockfile(__stream: ?*FILE) void;
pub extern fn __uflow(?*FILE) c_int;
pub extern fn __overflow(?*FILE, c_int) c_int;
pub const div_t = extern struct {
    quot: c_int = 0,
    rem: c_int = 0,
};
pub const ldiv_t = extern struct {
    quot: c_long = 0,
    rem: c_long = 0,
};
pub const lldiv_t = extern struct {
    quot: c_longlong = 0,
    rem: c_longlong = 0,
};
pub extern fn __ctype_get_mb_cur_max() usize;
pub extern fn atof(__nptr: [*c]const u8) f64;
pub extern fn atoi(__nptr: [*c]const u8) c_int;
pub extern fn atol(__nptr: [*c]const u8) c_long;
pub extern fn atoll(__nptr: [*c]const u8) c_longlong;
pub extern fn strtod(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) f64;
pub extern fn strtof(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) f32;
pub extern fn strtold(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) c_longdouble;
pub extern fn strtol(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_long;
pub extern fn strtoul(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_ulong;
pub extern fn strtoq(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_longlong;
pub extern fn strtouq(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_ulonglong;
pub extern fn strtoll(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_longlong;
pub extern fn strtoull(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_ulonglong;
pub extern fn l64a(__n: c_long) [*c]u8;
pub extern fn a64l(__s: [*c]const u8) c_long;
pub const u_char = __u_char;
pub const u_short = __u_short;
pub const u_int = __u_int;
pub const u_long = __u_long;
pub const quad_t = __quad_t;
pub const u_quad_t = __u_quad_t;
pub const fsid_t = __fsid_t;
pub const loff_t = __loff_t;
pub const ino_t = __ino_t;
pub const dev_t = __dev_t;
pub const gid_t = __gid_t;
pub const mode_t = __mode_t;
pub const nlink_t = __nlink_t;
pub const uid_t = __uid_t;
pub const pid_t = __pid_t;
pub const id_t = __id_t;
pub const daddr_t = __daddr_t;
pub const caddr_t = __caddr_t;
pub const key_t = __key_t;
pub const clock_t = __clock_t;
pub const clockid_t = __clockid_t;
pub const time_t = __time_t;
pub const timer_t = __timer_t;
pub const ulong = c_ulong;
pub const ushort = c_ushort;
pub const uint = c_uint;
pub const u_int8_t = __uint8_t;
pub const u_int16_t = __uint16_t;
pub const u_int32_t = __uint32_t;
pub const u_int64_t = __uint64_t;
pub const register_t = c_int;
pub fn __bswap_16(arg___bsx: __uint16_t) callconv(.c) __uint16_t {
    var __bsx = arg___bsx;
    _ = &__bsx;
    return @byteSwap(@as(__uint16_t, __bsx));
}
pub fn __bswap_32(arg___bsx: __uint32_t) callconv(.c) __uint32_t {
    var __bsx = arg___bsx;
    _ = &__bsx;
    return @bitCast(@as(c_int, @byteSwap(@as(c_int, @bitCast(@as(c_uint, @truncate(__bsx)))))));
}
pub fn __bswap_64(arg___bsx: __uint64_t) callconv(.c) __uint64_t {
    var __bsx = arg___bsx;
    _ = &__bsx;
    return @bitCast(@as(c_long, @byteSwap(@as(c_long, @bitCast(@as(c_ulong, @truncate(__bsx)))))));
}
pub fn __uint16_identity(arg___x: __uint16_t) callconv(.c) __uint16_t {
    var __x = arg___x;
    _ = &__x;
    return __x;
}
pub fn __uint32_identity(arg___x: __uint32_t) callconv(.c) __uint32_t {
    var __x = arg___x;
    _ = &__x;
    return __x;
}
pub fn __uint64_identity(arg___x: __uint64_t) callconv(.c) __uint64_t {
    var __x = arg___x;
    _ = &__x;
    return __x;
}
pub const __sigset_t = extern struct {
    __val: [16]c_ulong = @import("std").mem.zeroes([16]c_ulong),
};
pub const sigset_t = __sigset_t;
pub const struct_timeval = extern struct {
    tv_sec: __time_t = 0,
    tv_usec: __suseconds_t = 0,
};
pub const struct_timespec = extern struct {
    tv_sec: __time_t = 0,
    tv_nsec: __syscall_slong_t = 0,
};
pub const suseconds_t = __suseconds_t;
pub const __fd_mask = c_long;
pub const fd_set = extern struct {
    __fds_bits: [16]__fd_mask = @import("std").mem.zeroes([16]__fd_mask),
};
pub const fd_mask = __fd_mask;
pub extern fn select(__nfds: c_int, noalias __readfds: [*c]fd_set, noalias __writefds: [*c]fd_set, noalias __exceptfds: [*c]fd_set, noalias __timeout: [*c]struct_timeval) c_int;
pub extern fn pselect(__nfds: c_int, noalias __readfds: [*c]fd_set, noalias __writefds: [*c]fd_set, noalias __exceptfds: [*c]fd_set, noalias __timeout: [*c]const struct_timespec, noalias __sigmask: [*c]const __sigset_t) c_int;
pub const blksize_t = __blksize_t;
pub const blkcnt_t = __blkcnt_t;
pub const fsblkcnt_t = __fsblkcnt_t;
pub const fsfilcnt_t = __fsfilcnt_t;
const struct_unnamed_4 = extern struct {
    __low: c_uint = 0,
    __high: c_uint = 0,
};
pub const __atomic_wide_counter = extern union {
    __value64: c_ulonglong,
    __value32: struct_unnamed_4,
};
pub const struct___pthread_internal_list = extern struct {
    __prev: [*c]struct___pthread_internal_list = null,
    __next: [*c]struct___pthread_internal_list = null,
};
pub const __pthread_list_t = struct___pthread_internal_list;
pub const struct___pthread_internal_slist = extern struct {
    __next: [*c]struct___pthread_internal_slist = null,
};
pub const __pthread_slist_t = struct___pthread_internal_slist;
pub const struct___pthread_mutex_s = extern struct {
    __lock: c_int = 0,
    __count: c_uint = 0,
    __owner: c_int = 0,
    __nusers: c_uint = 0,
    __kind: c_int = 0,
    __spins: c_short = 0,
    __glibc_reserved: c_short = 0,
    __list: __pthread_list_t = @import("std").mem.zeroes(__pthread_list_t),
};
pub const struct___pthread_rwlock_arch_t = extern struct {
    __readers: c_uint = 0,
    __writers: c_uint = 0,
    __wrphase_futex: c_uint = 0,
    __writers_futex: c_uint = 0,
    __pad3: c_uint = 0,
    __pad4: c_uint = 0,
    __cur_writer: c_int = 0,
    __shared: c_int = 0,
    __pad1: c_ulong = 0,
    __pad2: c_ulong = 0,
    __flags: c_uint = 0,
};
pub const struct___pthread_cond_s = extern struct {
    __wseq: __atomic_wide_counter = @import("std").mem.zeroes(__atomic_wide_counter),
    __g1_start: __atomic_wide_counter = @import("std").mem.zeroes(__atomic_wide_counter),
    __g_size: [2]c_uint = @import("std").mem.zeroes([2]c_uint),
    __g1_orig_size: c_uint = 0,
    __wrefs: c_uint = 0,
    __g_signals: [2]c_uint = @import("std").mem.zeroes([2]c_uint),
    __unused_initialized_1: c_uint = 0,
    __unused_initialized_2: c_uint = 0,
};
pub const __tss_t = c_uint;
pub const __thrd_t = c_ulong;
pub const __once_flag = extern struct {
    __data: c_int = 0,
};
pub const pthread_t = c_ulong;
pub const pthread_mutexattr_t = extern union {
    __size: [4]u8,
    __align: c_int,
};
pub const pthread_condattr_t = extern union {
    __size: [4]u8,
    __align: c_int,
};
pub const pthread_key_t = c_uint;
pub const pthread_once_t = c_int;
pub const union_pthread_attr_t = extern union {
    __size: [56]u8,
    __align: c_long,
};
pub const pthread_attr_t = union_pthread_attr_t;
pub const pthread_mutex_t = extern union {
    __data: struct___pthread_mutex_s,
    __size: [40]u8,
    __align: c_long,
};
pub const pthread_cond_t = extern union {
    __data: struct___pthread_cond_s,
    __size: [48]u8,
    __align: c_longlong,
};
pub const pthread_rwlock_t = extern union {
    __data: struct___pthread_rwlock_arch_t,
    __size: [56]u8,
    __align: c_long,
};
pub const pthread_rwlockattr_t = extern union {
    __size: [8]u8,
    __align: c_long,
};
pub const pthread_spinlock_t = c_int;
pub const pthread_barrier_t = extern union {
    __size: [32]u8,
    __align: c_long,
};
pub const pthread_barrierattr_t = extern union {
    __size: [4]u8,
    __align: c_int,
};
pub extern fn random() c_long;
pub extern fn srandom(__seed: c_uint) void;
pub extern fn initstate(__seed: c_uint, __statebuf: [*c]u8, __statelen: usize) [*c]u8;
pub extern fn setstate(__statebuf: [*c]u8) [*c]u8;
pub const struct_random_data = extern struct {
    fptr: [*c]i32 = null,
    rptr: [*c]i32 = null,
    state: [*c]i32 = null,
    rand_type: c_int = 0,
    rand_deg: c_int = 0,
    rand_sep: c_int = 0,
    end_ptr: [*c]i32 = null,
    pub const random_r = __root.random_r;
    pub const r = __root.random_r;
};
pub extern fn random_r(noalias __buf: [*c]struct_random_data, noalias __result: [*c]i32) c_int;
pub extern fn srandom_r(__seed: c_uint, __buf: [*c]struct_random_data) c_int;
pub extern fn initstate_r(__seed: c_uint, noalias __statebuf: [*c]u8, __statelen: usize, noalias __buf: [*c]struct_random_data) c_int;
pub extern fn setstate_r(noalias __statebuf: [*c]u8, noalias __buf: [*c]struct_random_data) c_int;
pub extern fn rand() c_int;
pub extern fn srand(__seed: c_uint) void;
pub extern fn rand_r(__seed: [*c]c_uint) c_int;
pub extern fn drand48() f64;
pub extern fn erand48(__xsubi: [*c]c_ushort) f64;
pub extern fn lrand48() c_long;
pub extern fn nrand48(__xsubi: [*c]c_ushort) c_long;
pub extern fn mrand48() c_long;
pub extern fn jrand48(__xsubi: [*c]c_ushort) c_long;
pub extern fn srand48(__seedval: c_long) void;
pub extern fn seed48(__seed16v: [*c]c_ushort) [*c]c_ushort;
pub extern fn lcong48(__param: [*c]c_ushort) void;
pub const struct_drand48_data = extern struct {
    __x: [3]c_ushort = @import("std").mem.zeroes([3]c_ushort),
    __old_x: [3]c_ushort = @import("std").mem.zeroes([3]c_ushort),
    __c: c_ushort = 0,
    __init: c_ushort = 0,
    __a: c_ulonglong = 0,
    pub const drand48_r = __root.drand48_r;
    pub const lrand48_r = __root.lrand48_r;
    pub const mrand48_r = __root.mrand48_r;
    pub const r = __root.drand48_r;
};
pub extern fn drand48_r(noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]f64) c_int;
pub extern fn erand48_r(__xsubi: [*c]c_ushort, noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]f64) c_int;
pub extern fn lrand48_r(noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) c_int;
pub extern fn nrand48_r(__xsubi: [*c]c_ushort, noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) c_int;
pub extern fn mrand48_r(noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) c_int;
pub extern fn jrand48_r(__xsubi: [*c]c_ushort, noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) c_int;
pub extern fn srand48_r(__seedval: c_long, __buffer: [*c]struct_drand48_data) c_int;
pub extern fn seed48_r(__seed16v: [*c]c_ushort, __buffer: [*c]struct_drand48_data) c_int;
pub extern fn lcong48_r(__param: [*c]c_ushort, __buffer: [*c]struct_drand48_data) c_int;
pub extern fn arc4random() __uint32_t;
pub extern fn arc4random_buf(__buf: ?*anyopaque, __size: usize) void;
pub extern fn arc4random_uniform(__upper_bound: __uint32_t) __uint32_t;
pub extern fn malloc(__size: usize) ?*anyopaque;
pub extern fn calloc(__nmemb: usize, __size: usize) ?*anyopaque;
pub extern fn realloc(__ptr: ?*anyopaque, __size: usize) ?*anyopaque;
pub extern fn free(__ptr: ?*anyopaque) void;
pub extern fn reallocarray(__ptr: ?*anyopaque, __nmemb: usize, __size: usize) ?*anyopaque;
pub extern fn alloca(__size: usize) ?*anyopaque;
pub extern fn valloc(__size: usize) ?*anyopaque;
pub extern fn posix_memalign(__memptr: [*c]?*anyopaque, __alignment: usize, __size: usize) c_int;
pub extern fn aligned_alloc(__alignment: usize, __size: usize) ?*anyopaque;
pub extern fn abort() noreturn;
pub extern fn atexit(__func: ?*const fn () callconv(.c) void) c_int;
pub extern fn at_quick_exit(__func: ?*const fn () callconv(.c) void) c_int;
pub extern fn on_exit(__func: ?*const fn (__status: c_int, __arg: ?*anyopaque) callconv(.c) void, __arg: ?*anyopaque) c_int;
pub extern fn exit(__status: c_int) noreturn;
pub extern fn quick_exit(__status: c_int) noreturn;
pub extern fn _Exit(__status: c_int) noreturn;
pub extern fn getenv(__name: [*c]const u8) [*c]u8;
pub extern fn putenv(__string: [*c]u8) c_int;
pub extern fn setenv(__name: [*c]const u8, __value: [*c]const u8, __replace: c_int) c_int;
pub extern fn unsetenv(__name: [*c]const u8) c_int;
pub extern fn clearenv() c_int;
pub extern fn mktemp(__template: [*c]u8) [*c]u8;
pub extern fn mkstemp(__template: [*c]u8) c_int;
pub extern fn mkstemps(__template: [*c]u8, __suffixlen: c_int) c_int;
pub extern fn mkdtemp(__template: [*c]u8) [*c]u8;
pub extern fn system(__command: [*c]const u8) c_int;
pub extern fn realpath(noalias __name: [*c]const u8, noalias __resolved: [*c]u8) [*c]u8;
pub const __compar_fn_t = ?*const fn (?*const anyopaque, ?*const anyopaque) callconv(.c) c_int;
pub extern fn bsearch(__key: ?*const anyopaque, __base: ?*const anyopaque, __nmemb: usize, __size: usize, __compar: __compar_fn_t) ?*anyopaque;
pub extern fn qsort(__base: ?*anyopaque, __nmemb: usize, __size: usize, __compar: __compar_fn_t) void;
pub extern fn abs(__x: c_int) c_int;
pub extern fn labs(__x: c_long) c_long;
pub extern fn llabs(__x: c_longlong) c_longlong;
pub extern fn div(__numer: c_int, __denom: c_int) div_t;
pub extern fn ldiv(__numer: c_long, __denom: c_long) ldiv_t;
pub extern fn lldiv(__numer: c_longlong, __denom: c_longlong) lldiv_t;
pub extern fn ecvt(__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) [*c]u8;
pub extern fn fcvt(__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) [*c]u8;
pub extern fn gcvt(__value: f64, __ndigit: c_int, __buf: [*c]u8) [*c]u8;
pub extern fn qecvt(__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) [*c]u8;
pub extern fn qfcvt(__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) [*c]u8;
pub extern fn qgcvt(__value: c_longdouble, __ndigit: c_int, __buf: [*c]u8) [*c]u8;
pub extern fn ecvt_r(__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) c_int;
pub extern fn fcvt_r(__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) c_int;
pub extern fn qecvt_r(__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) c_int;
pub extern fn qfcvt_r(__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) c_int;
pub extern fn mblen(__s: [*c]const u8, __n: usize) c_int;
pub extern fn mbtowc(noalias __pwc: [*c]wchar_t, noalias __s: [*c]const u8, __n: usize) c_int;
pub extern fn wctomb(__s: [*c]u8, __wchar: wchar_t) c_int;
pub extern fn mbstowcs(noalias __pwcs: [*c]wchar_t, noalias __s: [*c]const u8, __n: usize) usize;
pub extern fn wcstombs(noalias __s: [*c]u8, noalias __pwcs: [*c]const wchar_t, __n: usize) usize;
pub extern fn rpmatch(__response: [*c]const u8) c_int;
pub extern fn getsubopt(noalias __optionp: [*c][*c]u8, noalias __tokens: [*c]const [*c]u8, noalias __valuep: [*c][*c]u8) c_int;
pub extern fn getloadavg(__loadavg: [*c]f64, __nelem: c_int) c_int;
pub const __jmp_buf = [8]c_long;
pub const struct___jmp_buf_tag = extern struct {
    __jmpbuf: __jmp_buf = @import("std").mem.zeroes(__jmp_buf),
    __mask_was_saved: c_int = 0,
    __saved_mask: __sigset_t = @import("std").mem.zeroes(__sigset_t),
    pub const setjmp = __root.setjmp;
    pub const __sigsetjmp = __root.__sigsetjmp;
    pub const _setjmp = __root._setjmp;
    pub const longjmp = __root.longjmp;
    pub const _longjmp = __root._longjmp;
    pub const siglongjmp = __root.siglongjmp;
};
pub const jmp_buf = [1]struct___jmp_buf_tag;
pub extern fn setjmp(__env: [*c]struct___jmp_buf_tag) c_int;
pub extern fn __sigsetjmp(__env: [*c]struct___jmp_buf_tag, __savemask: c_int) c_int;
pub extern fn _setjmp(__env: [*c]struct___jmp_buf_tag) c_int;
pub extern fn longjmp(__env: [*c]struct___jmp_buf_tag, __val: c_int) noreturn;
pub extern fn _longjmp(__env: [*c]struct___jmp_buf_tag, __val: c_int) noreturn;
pub const sigjmp_buf = [1]struct___jmp_buf_tag;
pub extern fn siglongjmp(__env: [*c]struct___jmp_buf_tag, __val: c_int) noreturn;
pub const FT_Int16 = c_short;
pub const FT_UInt16 = c_ushort;
pub const FT_Int32 = c_int;
pub const FT_UInt32 = c_uint;
pub const FT_Fast = c_int;
pub const FT_UFast = c_uint;
pub const FT_Int64 = c_long;
pub const FT_UInt64 = c_ulong;
pub const FT_Memory = [*c]struct_FT_MemoryRec_;
pub const FT_Alloc_Func = ?*const fn (memory: FT_Memory, size: c_long) callconv(.c) ?*anyopaque;
pub const FT_Free_Func = ?*const fn (memory: FT_Memory, block: ?*anyopaque) callconv(.c) void;
pub const FT_Realloc_Func = ?*const fn (memory: FT_Memory, cur_size: c_long, new_size: c_long, block: ?*anyopaque) callconv(.c) ?*anyopaque;
pub const struct_FT_MemoryRec_ = extern struct {
    user: ?*anyopaque = null,
    alloc: FT_Alloc_Func = null,
    free: FT_Free_Func = null,
    realloc: FT_Realloc_Func = null,
};
pub const union_FT_StreamDesc_ = extern union {
    value: c_long,
    pointer: ?*anyopaque,
};
pub const FT_StreamDesc = union_FT_StreamDesc_;
pub const FT_Stream = [*c]struct_FT_StreamRec_;
pub const FT_Stream_IoFunc = ?*const fn (stream: FT_Stream, offset: c_ulong, buffer: [*c]u8, count: c_ulong) callconv(.c) c_ulong;
pub const FT_Stream_CloseFunc = ?*const fn (stream: FT_Stream) callconv(.c) void;
pub const struct_FT_StreamRec_ = extern struct {
    base: [*c]u8 = null,
    size: c_ulong = 0,
    pos: c_ulong = 0,
    descriptor: FT_StreamDesc = @import("std").mem.zeroes(FT_StreamDesc),
    pathname: FT_StreamDesc = @import("std").mem.zeroes(FT_StreamDesc),
    read: FT_Stream_IoFunc = null,
    close: FT_Stream_CloseFunc = null,
    memory: FT_Memory = null,
    cursor: [*c]u8 = null,
    limit: [*c]u8 = null,
};
pub const FT_StreamRec = struct_FT_StreamRec_;
pub const FT_Pos = c_long;
pub const struct_FT_Vector_ = extern struct {
    x: FT_Pos = 0,
    y: FT_Pos = 0,
    pub const FT_Vector_Transform = __root.FT_Vector_Transform;
    pub const Transform = __root.FT_Vector_Transform;
};
pub const FT_Vector = struct_FT_Vector_;
pub const struct_FT_BBox_ = extern struct {
    xMin: FT_Pos = 0,
    yMin: FT_Pos = 0,
    xMax: FT_Pos = 0,
    yMax: FT_Pos = 0,
};
pub const FT_BBox = struct_FT_BBox_;
pub const FT_PIXEL_MODE_NONE: c_int = 0;
pub const FT_PIXEL_MODE_MONO: c_int = 1;
pub const FT_PIXEL_MODE_GRAY: c_int = 2;
pub const FT_PIXEL_MODE_GRAY2: c_int = 3;
pub const FT_PIXEL_MODE_GRAY4: c_int = 4;
pub const FT_PIXEL_MODE_LCD: c_int = 5;
pub const FT_PIXEL_MODE_LCD_V: c_int = 6;
pub const FT_PIXEL_MODE_BGRA: c_int = 7;
pub const FT_PIXEL_MODE_MAX: c_int = 8;
pub const enum_FT_Pixel_Mode_ = c_uint;
pub const FT_Pixel_Mode = enum_FT_Pixel_Mode_;
pub const struct_FT_Bitmap_ = extern struct {
    rows: c_uint = 0,
    width: c_uint = 0,
    pitch: c_int = 0,
    buffer: [*c]u8 = null,
    num_grays: c_ushort = 0,
    pixel_mode: u8 = 0,
    palette_mode: u8 = 0,
    palette: ?*anyopaque = null,
};
pub const FT_Bitmap = struct_FT_Bitmap_;
pub const struct_FT_Outline_ = extern struct {
    n_contours: c_ushort = 0,
    n_points: c_ushort = 0,
    points: [*c]FT_Vector = null,
    tags: [*c]u8 = null,
    contours: [*c]c_ushort = null,
    flags: c_int = 0,
};
pub const FT_Outline = struct_FT_Outline_;
pub const FT_Outline_MoveToFunc = ?*const fn (to: [*c]const FT_Vector, user: ?*anyopaque) callconv(.c) c_int;
pub const FT_Outline_LineToFunc = ?*const fn (to: [*c]const FT_Vector, user: ?*anyopaque) callconv(.c) c_int;
pub const FT_Outline_ConicToFunc = ?*const fn (control: [*c]const FT_Vector, to: [*c]const FT_Vector, user: ?*anyopaque) callconv(.c) c_int;
pub const FT_Outline_CubicToFunc = ?*const fn (control1: [*c]const FT_Vector, control2: [*c]const FT_Vector, to: [*c]const FT_Vector, user: ?*anyopaque) callconv(.c) c_int;
pub const struct_FT_Outline_Funcs_ = extern struct {
    move_to: FT_Outline_MoveToFunc = null,
    line_to: FT_Outline_LineToFunc = null,
    conic_to: FT_Outline_ConicToFunc = null,
    cubic_to: FT_Outline_CubicToFunc = null,
    shift: c_int = 0,
    delta: FT_Pos = 0,
};
pub const FT_Outline_Funcs = struct_FT_Outline_Funcs_;
pub const FT_GLYPH_FORMAT_NONE: c_int = 0;
pub const FT_GLYPH_FORMAT_COMPOSITE: c_int = 1668246896;
pub const FT_GLYPH_FORMAT_BITMAP: c_int = 1651078259;
pub const FT_GLYPH_FORMAT_OUTLINE: c_int = 1869968492;
pub const FT_GLYPH_FORMAT_PLOTTER: c_int = 1886154612;
pub const FT_GLYPH_FORMAT_SVG: c_int = 1398163232;
pub const enum_FT_Glyph_Format_ = c_uint;
pub const FT_Glyph_Format = enum_FT_Glyph_Format_;
pub const struct_FT_Span_ = extern struct {
    x: c_ushort = 0,
    len: c_ushort = 0,
    coverage: u8 = 0,
};
pub const FT_Span = struct_FT_Span_;
pub const FT_SpanFunc = ?*const fn (y: c_int, count: c_int, spans: [*c]const FT_Span, user: ?*anyopaque) callconv(.c) void;
pub const FT_Raster_BitTest_Func = ?*const fn (y: c_int, x: c_int, user: ?*anyopaque) callconv(.c) c_int;
pub const FT_Raster_BitSet_Func = ?*const fn (y: c_int, x: c_int, user: ?*anyopaque) callconv(.c) void;
pub const struct_FT_Raster_Params_ = extern struct {
    target: [*c]const FT_Bitmap = null,
    source: ?*const anyopaque = null,
    flags: c_int = 0,
    gray_spans: FT_SpanFunc = null,
    black_spans: FT_SpanFunc = null,
    bit_test: FT_Raster_BitTest_Func = null,
    bit_set: FT_Raster_BitSet_Func = null,
    user: ?*anyopaque = null,
    clip_box: FT_BBox = @import("std").mem.zeroes(FT_BBox),
};
pub const FT_Raster_Params = struct_FT_Raster_Params_;
pub const struct_FT_RasterRec_ = opaque {};
pub const FT_Raster = ?*struct_FT_RasterRec_;
pub const FT_Raster_NewFunc = ?*const fn (memory: ?*anyopaque, raster: [*c]FT_Raster) callconv(.c) c_int;
pub const FT_Raster_DoneFunc = ?*const fn (raster: FT_Raster) callconv(.c) void;
pub const FT_Raster_ResetFunc = ?*const fn (raster: FT_Raster, pool_base: [*c]u8, pool_size: c_ulong) callconv(.c) void;
pub const FT_Raster_SetModeFunc = ?*const fn (raster: FT_Raster, mode: c_ulong, args: ?*anyopaque) callconv(.c) c_int;
pub const FT_Raster_RenderFunc = ?*const fn (raster: FT_Raster, params: [*c]const FT_Raster_Params) callconv(.c) c_int;
pub const struct_FT_Raster_Funcs_ = extern struct {
    glyph_format: FT_Glyph_Format = @import("std").mem.zeroes(FT_Glyph_Format),
    raster_new: FT_Raster_NewFunc = null,
    raster_reset: FT_Raster_ResetFunc = null,
    raster_set_mode: FT_Raster_SetModeFunc = null,
    raster_render: FT_Raster_RenderFunc = null,
    raster_done: FT_Raster_DoneFunc = null,
};
pub const FT_Raster_Funcs = struct_FT_Raster_Funcs_;
pub const FT_Bool = u8;
pub const FT_FWord = c_short;
pub const FT_UFWord = c_ushort;
pub const FT_Char = i8;
pub const FT_Byte = u8;
pub const FT_Bytes = [*c]const FT_Byte;
pub const FT_Tag = FT_UInt32;
pub const FT_String = u8;
pub const FT_Short = c_short;
pub const FT_UShort = c_ushort;
pub const FT_Int = c_int;
pub const FT_UInt = c_uint;
pub const FT_Long = c_long;
pub const FT_ULong = c_ulong;
pub const FT_F2Dot14 = c_short;
pub const FT_F26Dot6 = c_long;
pub const FT_Fixed = c_long;
pub const FT_Error = c_int;
pub const FT_Pointer = ?*anyopaque;
pub const FT_Offset = usize;
pub const FT_PtrDist = ptrdiff_t;
pub const struct_FT_UnitVector_ = extern struct {
    x: FT_F2Dot14 = 0,
    y: FT_F2Dot14 = 0,
};
pub const FT_UnitVector = struct_FT_UnitVector_;
pub const struct_FT_Matrix_ = extern struct {
    xx: FT_Fixed = 0,
    xy: FT_Fixed = 0,
    yx: FT_Fixed = 0,
    yy: FT_Fixed = 0,
};
pub const FT_Matrix = struct_FT_Matrix_;
pub const struct_FT_Data_ = extern struct {
    pointer: [*c]const FT_Byte = null,
    length: FT_UInt = 0,
};
pub const FT_Data = struct_FT_Data_;
pub const FT_Generic_Finalizer = ?*const fn (object: ?*anyopaque) callconv(.c) void;
pub const struct_FT_Generic_ = extern struct {
    data: ?*anyopaque = null,
    finalizer: FT_Generic_Finalizer = null,
};
pub const FT_Generic = struct_FT_Generic_;
pub const FT_ListNode = [*c]struct_FT_ListNodeRec_;
pub const struct_FT_ListNodeRec_ = extern struct {
    prev: FT_ListNode = null,
    next: FT_ListNode = null,
    data: ?*anyopaque = null,
};
pub const struct_FT_ListRec_ = extern struct {
    head: FT_ListNode = null,
    tail: FT_ListNode = null,
};
pub const FT_List = [*c]struct_FT_ListRec_;
pub const FT_ListNodeRec = struct_FT_ListNodeRec_;
pub const FT_ListRec = struct_FT_ListRec_;
pub const FT_Mod_Err_Base: c_int = 0;
pub const FT_Mod_Err_Autofit: c_int = 0;
pub const FT_Mod_Err_BDF: c_int = 0;
pub const FT_Mod_Err_Bzip2: c_int = 0;
pub const FT_Mod_Err_Cache: c_int = 0;
pub const FT_Mod_Err_CFF: c_int = 0;
pub const FT_Mod_Err_CID: c_int = 0;
pub const FT_Mod_Err_Gzip: c_int = 0;
pub const FT_Mod_Err_LZW: c_int = 0;
pub const FT_Mod_Err_OTvalid: c_int = 0;
pub const FT_Mod_Err_PCF: c_int = 0;
pub const FT_Mod_Err_PFR: c_int = 0;
pub const FT_Mod_Err_PSaux: c_int = 0;
pub const FT_Mod_Err_PShinter: c_int = 0;
pub const FT_Mod_Err_PSnames: c_int = 0;
pub const FT_Mod_Err_Raster: c_int = 0;
pub const FT_Mod_Err_SFNT: c_int = 0;
pub const FT_Mod_Err_Smooth: c_int = 0;
pub const FT_Mod_Err_TrueType: c_int = 0;
pub const FT_Mod_Err_Type1: c_int = 0;
pub const FT_Mod_Err_Type42: c_int = 0;
pub const FT_Mod_Err_Winfonts: c_int = 0;
pub const FT_Mod_Err_GXvalid: c_int = 0;
pub const FT_Mod_Err_Sdf: c_int = 0;
pub const FT_Mod_Err_Max: c_int = 1;
const enum_unnamed_5 = c_uint;
pub const FT_Err_Ok: c_int = 0;
pub const FT_Err_Cannot_Open_Resource: c_int = 1;
pub const FT_Err_Unknown_File_Format: c_int = 2;
pub const FT_Err_Invalid_File_Format: c_int = 3;
pub const FT_Err_Invalid_Version: c_int = 4;
pub const FT_Err_Lower_Module_Version: c_int = 5;
pub const FT_Err_Invalid_Argument: c_int = 6;
pub const FT_Err_Unimplemented_Feature: c_int = 7;
pub const FT_Err_Invalid_Table: c_int = 8;
pub const FT_Err_Invalid_Offset: c_int = 9;
pub const FT_Err_Array_Too_Large: c_int = 10;
pub const FT_Err_Missing_Module: c_int = 11;
pub const FT_Err_Missing_Property: c_int = 12;
pub const FT_Err_Invalid_Glyph_Index: c_int = 16;
pub const FT_Err_Invalid_Character_Code: c_int = 17;
pub const FT_Err_Invalid_Glyph_Format: c_int = 18;
pub const FT_Err_Cannot_Render_Glyph: c_int = 19;
pub const FT_Err_Invalid_Outline: c_int = 20;
pub const FT_Err_Invalid_Composite: c_int = 21;
pub const FT_Err_Too_Many_Hints: c_int = 22;
pub const FT_Err_Invalid_Pixel_Size: c_int = 23;
pub const FT_Err_Invalid_SVG_Document: c_int = 24;
pub const FT_Err_Invalid_Handle: c_int = 32;
pub const FT_Err_Invalid_Library_Handle: c_int = 33;
pub const FT_Err_Invalid_Driver_Handle: c_int = 34;
pub const FT_Err_Invalid_Face_Handle: c_int = 35;
pub const FT_Err_Invalid_Size_Handle: c_int = 36;
pub const FT_Err_Invalid_Slot_Handle: c_int = 37;
pub const FT_Err_Invalid_CharMap_Handle: c_int = 38;
pub const FT_Err_Invalid_Cache_Handle: c_int = 39;
pub const FT_Err_Invalid_Stream_Handle: c_int = 40;
pub const FT_Err_Too_Many_Drivers: c_int = 48;
pub const FT_Err_Too_Many_Extensions: c_int = 49;
pub const FT_Err_Out_Of_Memory: c_int = 64;
pub const FT_Err_Unlisted_Object: c_int = 65;
pub const FT_Err_Cannot_Open_Stream: c_int = 81;
pub const FT_Err_Invalid_Stream_Seek: c_int = 82;
pub const FT_Err_Invalid_Stream_Skip: c_int = 83;
pub const FT_Err_Invalid_Stream_Read: c_int = 84;
pub const FT_Err_Invalid_Stream_Operation: c_int = 85;
pub const FT_Err_Invalid_Frame_Operation: c_int = 86;
pub const FT_Err_Nested_Frame_Access: c_int = 87;
pub const FT_Err_Invalid_Frame_Read: c_int = 88;
pub const FT_Err_Raster_Uninitialized: c_int = 96;
pub const FT_Err_Raster_Corrupted: c_int = 97;
pub const FT_Err_Raster_Overflow: c_int = 98;
pub const FT_Err_Raster_Negative_Height: c_int = 99;
pub const FT_Err_Too_Many_Caches: c_int = 112;
pub const FT_Err_Invalid_Opcode: c_int = 128;
pub const FT_Err_Too_Few_Arguments: c_int = 129;
pub const FT_Err_Stack_Overflow: c_int = 130;
pub const FT_Err_Code_Overflow: c_int = 131;
pub const FT_Err_Bad_Argument: c_int = 132;
pub const FT_Err_Divide_By_Zero: c_int = 133;
pub const FT_Err_Invalid_Reference: c_int = 134;
pub const FT_Err_Debug_OpCode: c_int = 135;
pub const FT_Err_ENDF_In_Exec_Stream: c_int = 136;
pub const FT_Err_Nested_DEFS: c_int = 137;
pub const FT_Err_Invalid_CodeRange: c_int = 138;
pub const FT_Err_Execution_Too_Long: c_int = 139;
pub const FT_Err_Too_Many_Function_Defs: c_int = 140;
pub const FT_Err_Too_Many_Instruction_Defs: c_int = 141;
pub const FT_Err_Table_Missing: c_int = 142;
pub const FT_Err_Horiz_Header_Missing: c_int = 143;
pub const FT_Err_Locations_Missing: c_int = 144;
pub const FT_Err_Name_Table_Missing: c_int = 145;
pub const FT_Err_CMap_Table_Missing: c_int = 146;
pub const FT_Err_Hmtx_Table_Missing: c_int = 147;
pub const FT_Err_Post_Table_Missing: c_int = 148;
pub const FT_Err_Invalid_Horiz_Metrics: c_int = 149;
pub const FT_Err_Invalid_CharMap_Format: c_int = 150;
pub const FT_Err_Invalid_PPem: c_int = 151;
pub const FT_Err_Invalid_Vert_Metrics: c_int = 152;
pub const FT_Err_Could_Not_Find_Context: c_int = 153;
pub const FT_Err_Invalid_Post_Table_Format: c_int = 154;
pub const FT_Err_Invalid_Post_Table: c_int = 155;
pub const FT_Err_DEF_In_Glyf_Bytecode: c_int = 156;
pub const FT_Err_Missing_Bitmap: c_int = 157;
pub const FT_Err_Missing_SVG_Hooks: c_int = 158;
pub const FT_Err_Syntax_Error: c_int = 160;
pub const FT_Err_Stack_Underflow: c_int = 161;
pub const FT_Err_Ignore: c_int = 162;
pub const FT_Err_No_Unicode_Glyph_Name: c_int = 163;
pub const FT_Err_Glyph_Too_Big: c_int = 164;
pub const FT_Err_Missing_Startfont_Field: c_int = 176;
pub const FT_Err_Missing_Font_Field: c_int = 177;
pub const FT_Err_Missing_Size_Field: c_int = 178;
pub const FT_Err_Missing_Fontboundingbox_Field: c_int = 179;
pub const FT_Err_Missing_Chars_Field: c_int = 180;
pub const FT_Err_Missing_Startchar_Field: c_int = 181;
pub const FT_Err_Missing_Encoding_Field: c_int = 182;
pub const FT_Err_Missing_Bbx_Field: c_int = 183;
pub const FT_Err_Bbx_Too_Big: c_int = 184;
pub const FT_Err_Corrupted_Font_Header: c_int = 185;
pub const FT_Err_Corrupted_Font_Glyphs: c_int = 186;
pub const FT_Err_Max: c_int = 187;
const enum_unnamed_6 = c_uint;
pub extern fn FT_Error_String(error_code: FT_Error) [*c]const u8;
pub const struct_FT_Glyph_Metrics_ = extern struct {
    width: FT_Pos = 0,
    height: FT_Pos = 0,
    horiBearingX: FT_Pos = 0,
    horiBearingY: FT_Pos = 0,
    horiAdvance: FT_Pos = 0,
    vertBearingX: FT_Pos = 0,
    vertBearingY: FT_Pos = 0,
    vertAdvance: FT_Pos = 0,
};
pub const FT_Glyph_Metrics = struct_FT_Glyph_Metrics_;
pub const struct_FT_Bitmap_Size_ = extern struct {
    height: FT_Short = 0,
    width: FT_Short = 0,
    size: FT_Pos = 0,
    x_ppem: FT_Pos = 0,
    y_ppem: FT_Pos = 0,
};
pub const FT_Bitmap_Size = struct_FT_Bitmap_Size_;
pub const struct_FT_LibraryRec_ = opaque {
    pub const FT_Done_FreeType = __root.FT_Done_FreeType;
    pub const FT_New_Face = __root.FT_New_Face;
    pub const FT_New_Memory_Face = __root.FT_New_Memory_Face;
    pub const FT_Open_Face = __root.FT_Open_Face;
    pub const FT_Library_Version = __root.FT_Library_Version;
    pub const FreeType = __root.FT_Done_FreeType;
    pub const Face = __root.FT_New_Face;
    pub const Version = __root.FT_Library_Version;
};
pub const FT_Library = ?*struct_FT_LibraryRec_;
pub const struct_FT_ModuleRec_ = opaque {};
pub const FT_Module = ?*struct_FT_ModuleRec_;
pub const struct_FT_DriverRec_ = opaque {};
pub const FT_Driver = ?*struct_FT_DriverRec_;
pub const struct_FT_RendererRec_ = opaque {};
pub const FT_Renderer = ?*struct_FT_RendererRec_;
pub const FT_Face = [*c]struct_FT_FaceRec_;
pub const FT_ENCODING_NONE: c_int = 0;
pub const FT_ENCODING_MS_SYMBOL: c_int = 1937337698;
pub const FT_ENCODING_UNICODE: c_int = 1970170211;
pub const FT_ENCODING_SJIS: c_int = 1936353651;
pub const FT_ENCODING_PRC: c_int = 1734484000;
pub const FT_ENCODING_BIG5: c_int = 1651074869;
pub const FT_ENCODING_WANSUNG: c_int = 2002873971;
pub const FT_ENCODING_JOHAB: c_int = 1785686113;
pub const FT_ENCODING_GB2312: c_int = 1734484000;
pub const FT_ENCODING_MS_SJIS: c_int = 1936353651;
pub const FT_ENCODING_MS_GB2312: c_int = 1734484000;
pub const FT_ENCODING_MS_BIG5: c_int = 1651074869;
pub const FT_ENCODING_MS_WANSUNG: c_int = 2002873971;
pub const FT_ENCODING_MS_JOHAB: c_int = 1785686113;
pub const FT_ENCODING_ADOBE_STANDARD: c_int = 1094995778;
pub const FT_ENCODING_ADOBE_EXPERT: c_int = 1094992453;
pub const FT_ENCODING_ADOBE_CUSTOM: c_int = 1094992451;
pub const FT_ENCODING_ADOBE_LATIN_1: c_int = 1818326065;
pub const FT_ENCODING_OLD_LATIN_2: c_int = 1818326066;
pub const FT_ENCODING_APPLE_ROMAN: c_int = 1634889070;
pub const enum_FT_Encoding_ = c_uint;
pub const FT_Encoding = enum_FT_Encoding_;
pub const struct_FT_CharMapRec_ = extern struct {
    face: FT_Face = null,
    encoding: FT_Encoding = @import("std").mem.zeroes(FT_Encoding),
    platform_id: FT_UShort = 0,
    encoding_id: FT_UShort = 0,
    pub const FT_Get_Charmap_Index = __root.FT_Get_Charmap_Index;
    pub const Index = __root.FT_Get_Charmap_Index;
};
pub const FT_CharMap = [*c]struct_FT_CharMapRec_;
pub const struct_FT_SubGlyphRec_ = opaque {};
pub const FT_SubGlyph = ?*struct_FT_SubGlyphRec_;
pub const struct_FT_Slot_InternalRec_ = opaque {};
pub const FT_Slot_Internal = ?*struct_FT_Slot_InternalRec_;
pub const struct_FT_GlyphSlotRec_ = extern struct {
    library: FT_Library = null,
    face: FT_Face = null,
    next: FT_GlyphSlot = null,
    glyph_index: FT_UInt = 0,
    generic: FT_Generic = @import("std").mem.zeroes(FT_Generic),
    metrics: FT_Glyph_Metrics = @import("std").mem.zeroes(FT_Glyph_Metrics),
    linearHoriAdvance: FT_Fixed = 0,
    linearVertAdvance: FT_Fixed = 0,
    advance: FT_Vector = @import("std").mem.zeroes(FT_Vector),
    format: FT_Glyph_Format = @import("std").mem.zeroes(FT_Glyph_Format),
    bitmap: FT_Bitmap = @import("std").mem.zeroes(FT_Bitmap),
    bitmap_left: FT_Int = 0,
    bitmap_top: FT_Int = 0,
    outline: FT_Outline = @import("std").mem.zeroes(FT_Outline),
    num_subglyphs: FT_UInt = 0,
    subglyphs: FT_SubGlyph = null,
    control_data: ?*anyopaque = null,
    control_len: c_long = 0,
    lsb_delta: FT_Pos = 0,
    rsb_delta: FT_Pos = 0,
    other: ?*anyopaque = null,
    internal: FT_Slot_Internal = null,
    pub const FT_Render_Glyph = __root.FT_Render_Glyph;
    pub const FT_Get_SubGlyph_Info = __root.FT_Get_SubGlyph_Info;
    pub const Glyph = __root.FT_Render_Glyph;
    pub const Info = __root.FT_Get_SubGlyph_Info;
};
pub const FT_GlyphSlot = [*c]struct_FT_GlyphSlotRec_;
pub const struct_FT_Size_Metrics_ = extern struct {
    x_ppem: FT_UShort = 0,
    y_ppem: FT_UShort = 0,
    x_scale: FT_Fixed = 0,
    y_scale: FT_Fixed = 0,
    ascender: FT_Pos = 0,
    descender: FT_Pos = 0,
    height: FT_Pos = 0,
    max_advance: FT_Pos = 0,
};
pub const FT_Size_Metrics = struct_FT_Size_Metrics_;
pub const struct_FT_Size_InternalRec_ = opaque {};
pub const FT_Size_Internal = ?*struct_FT_Size_InternalRec_;
pub const struct_FT_SizeRec_ = extern struct {
    face: FT_Face = null,
    generic: FT_Generic = @import("std").mem.zeroes(FT_Generic),
    metrics: FT_Size_Metrics = @import("std").mem.zeroes(FT_Size_Metrics),
    internal: FT_Size_Internal = null,
};
pub const FT_Size = [*c]struct_FT_SizeRec_;
pub const struct_FT_Face_InternalRec_ = opaque {};
pub const FT_Face_Internal = ?*struct_FT_Face_InternalRec_;
pub const struct_FT_FaceRec_ = extern struct {
    num_faces: FT_Long = 0,
    face_index: FT_Long = 0,
    face_flags: FT_Long = 0,
    style_flags: FT_Long = 0,
    num_glyphs: FT_Long = 0,
    family_name: [*c]FT_String = null,
    style_name: [*c]FT_String = null,
    num_fixed_sizes: FT_Int = 0,
    available_sizes: [*c]FT_Bitmap_Size = null,
    num_charmaps: FT_Int = 0,
    charmaps: [*c]FT_CharMap = null,
    generic: FT_Generic = @import("std").mem.zeroes(FT_Generic),
    bbox: FT_BBox = @import("std").mem.zeroes(FT_BBox),
    units_per_EM: FT_UShort = 0,
    ascender: FT_Short = 0,
    descender: FT_Short = 0,
    height: FT_Short = 0,
    max_advance_width: FT_Short = 0,
    max_advance_height: FT_Short = 0,
    underline_position: FT_Short = 0,
    underline_thickness: FT_Short = 0,
    glyph: FT_GlyphSlot = null,
    size: FT_Size = null,
    charmap: FT_CharMap = null,
    driver: FT_Driver = null,
    memory: FT_Memory = null,
    stream: FT_Stream = null,
    sizes_list: FT_ListRec = @import("std").mem.zeroes(FT_ListRec),
    autohint: FT_Generic = @import("std").mem.zeroes(FT_Generic),
    extensions: ?*anyopaque = null,
    internal: FT_Face_Internal = null,
    pub const FT_Attach_File = __root.FT_Attach_File;
    pub const FT_Attach_Stream = __root.FT_Attach_Stream;
    pub const FT_Reference_Face = __root.FT_Reference_Face;
    pub const FT_Done_Face = __root.FT_Done_Face;
    pub const FT_Select_Size = __root.FT_Select_Size;
    pub const FT_Request_Size = __root.FT_Request_Size;
    pub const FT_Set_Char_Size = __root.FT_Set_Char_Size;
    pub const FT_Set_Pixel_Sizes = __root.FT_Set_Pixel_Sizes;
    pub const FT_Load_Glyph = __root.FT_Load_Glyph;
    pub const FT_Load_Char = __root.FT_Load_Char;
    pub const FT_Set_Transform = __root.FT_Set_Transform;
    pub const FT_Get_Transform = __root.FT_Get_Transform;
    pub const FT_Get_Kerning = __root.FT_Get_Kerning;
    pub const FT_Get_Track_Kerning = __root.FT_Get_Track_Kerning;
    pub const FT_Select_Charmap = __root.FT_Select_Charmap;
    pub const FT_Set_Charmap = __root.FT_Set_Charmap;
    pub const FT_Get_Char_Index = __root.FT_Get_Char_Index;
    pub const FT_Get_First_Char = __root.FT_Get_First_Char;
    pub const FT_Get_Next_Char = __root.FT_Get_Next_Char;
    pub const FT_Face_Properties = __root.FT_Face_Properties;
    pub const FT_Get_Name_Index = __root.FT_Get_Name_Index;
    pub const FT_Get_Glyph_Name = __root.FT_Get_Glyph_Name;
    pub const FT_Get_Postscript_Name = __root.FT_Get_Postscript_Name;
    pub const FT_Get_FSType_Flags = __root.FT_Get_FSType_Flags;
    pub const FT_Face_GetCharVariantIndex = __root.FT_Face_GetCharVariantIndex;
    pub const FT_Face_GetCharVariantIsDefault = __root.FT_Face_GetCharVariantIsDefault;
    pub const FT_Face_GetVariantSelectors = __root.FT_Face_GetVariantSelectors;
    pub const FT_Face_GetVariantsOfChar = __root.FT_Face_GetVariantsOfChar;
    pub const FT_Face_GetCharsOfVariant = __root.FT_Face_GetCharsOfVariant;
    pub const FT_Face_CheckTrueTypePatents = __root.FT_Face_CheckTrueTypePatents;
    pub const FT_Face_SetUnpatentedHinting = __root.FT_Face_SetUnpatentedHinting;
    pub const hb_ft_face_create = __root.hb_ft_face_create;
    pub const hb_ft_face_create_cached = __root.hb_ft_face_create_cached;
    pub const hb_ft_face_create_referenced = __root.hb_ft_face_create_referenced;
    pub const hb_ft_font_create = __root.hb_ft_font_create;
    pub const hb_ft_font_create_referenced = __root.hb_ft_font_create_referenced;
    pub const File = __root.FT_Attach_File;
    pub const Stream = __root.FT_Attach_Stream;
    pub const Face = __root.FT_Reference_Face;
    pub const Size = __root.FT_Select_Size;
    pub const Sizes = __root.FT_Set_Pixel_Sizes;
    pub const Glyph = __root.FT_Load_Glyph;
    pub const Char = __root.FT_Load_Char;
    pub const Transform = __root.FT_Set_Transform;
    pub const Kerning = __root.FT_Get_Kerning;
    pub const Charmap = __root.FT_Select_Charmap;
    pub const Index = __root.FT_Get_Char_Index;
    pub const Properties = __root.FT_Face_Properties;
    pub const Name = __root.FT_Get_Glyph_Name;
    pub const Flags = __root.FT_Get_FSType_Flags;
    pub const GetCharVariantIndex = __root.FT_Face_GetCharVariantIndex;
    pub const GetCharVariantIsDefault = __root.FT_Face_GetCharVariantIsDefault;
    pub const GetVariantSelectors = __root.FT_Face_GetVariantSelectors;
    pub const GetVariantsOfChar = __root.FT_Face_GetVariantsOfChar;
    pub const GetCharsOfVariant = __root.FT_Face_GetCharsOfVariant;
    pub const CheckTrueTypePatents = __root.FT_Face_CheckTrueTypePatents;
    pub const SetUnpatentedHinting = __root.FT_Face_SetUnpatentedHinting;
    pub const create = __root.hb_ft_face_create;
    pub const cached = __root.hb_ft_face_create_cached;
    pub const referenced = __root.hb_ft_face_create_referenced;
};
pub const FT_CharMapRec = struct_FT_CharMapRec_;
pub const FT_FaceRec = struct_FT_FaceRec_;
pub const FT_SizeRec = struct_FT_SizeRec_;
pub const FT_GlyphSlotRec = struct_FT_GlyphSlotRec_;
pub extern fn FT_Init_FreeType(alibrary: [*c]FT_Library) FT_Error;
pub extern fn FT_Done_FreeType(library: FT_Library) FT_Error;
pub const struct_FT_Parameter_ = extern struct {
    tag: FT_ULong = 0,
    data: FT_Pointer = null,
};
pub const FT_Parameter = struct_FT_Parameter_;
pub const struct_FT_Open_Args_ = extern struct {
    flags: FT_UInt = 0,
    memory_base: [*c]const FT_Byte = null,
    memory_size: FT_Long = 0,
    pathname: [*c]FT_String = null,
    stream: FT_Stream = null,
    driver: FT_Module = null,
    num_params: FT_Int = 0,
    params: [*c]FT_Parameter = null,
};
pub const FT_Open_Args = struct_FT_Open_Args_;
pub extern fn FT_New_Face(library: FT_Library, filepathname: [*c]const u8, face_index: FT_Long, aface: [*c]FT_Face) FT_Error;
pub extern fn FT_New_Memory_Face(library: FT_Library, file_base: [*c]const FT_Byte, file_size: FT_Long, face_index: FT_Long, aface: [*c]FT_Face) FT_Error;
pub extern fn FT_Open_Face(library: FT_Library, args: [*c]const FT_Open_Args, face_index: FT_Long, aface: [*c]FT_Face) FT_Error;
pub extern fn FT_Attach_File(face: FT_Face, filepathname: [*c]const u8) FT_Error;
pub extern fn FT_Attach_Stream(face: FT_Face, parameters: [*c]const FT_Open_Args) FT_Error;
pub extern fn FT_Reference_Face(face: FT_Face) FT_Error;
pub extern fn FT_Done_Face(face: FT_Face) FT_Error;
pub extern fn FT_Select_Size(face: FT_Face, strike_index: FT_Int) FT_Error;
pub const FT_SIZE_REQUEST_TYPE_NOMINAL: c_int = 0;
pub const FT_SIZE_REQUEST_TYPE_REAL_DIM: c_int = 1;
pub const FT_SIZE_REQUEST_TYPE_BBOX: c_int = 2;
pub const FT_SIZE_REQUEST_TYPE_CELL: c_int = 3;
pub const FT_SIZE_REQUEST_TYPE_SCALES: c_int = 4;
pub const FT_SIZE_REQUEST_TYPE_MAX: c_int = 5;
pub const enum_FT_Size_Request_Type_ = c_uint;
pub const FT_Size_Request_Type = enum_FT_Size_Request_Type_;
pub const struct_FT_Size_RequestRec_ = extern struct {
    type: FT_Size_Request_Type = @import("std").mem.zeroes(FT_Size_Request_Type),
    width: FT_Long = 0,
    height: FT_Long = 0,
    horiResolution: FT_UInt = 0,
    vertResolution: FT_UInt = 0,
};
pub const FT_Size_RequestRec = struct_FT_Size_RequestRec_;
pub const FT_Size_Request = [*c]struct_FT_Size_RequestRec_;
pub extern fn FT_Request_Size(face: FT_Face, req: FT_Size_Request) FT_Error;
pub extern fn FT_Set_Char_Size(face: FT_Face, char_width: FT_F26Dot6, char_height: FT_F26Dot6, horz_resolution: FT_UInt, vert_resolution: FT_UInt) FT_Error;
pub extern fn FT_Set_Pixel_Sizes(face: FT_Face, pixel_width: FT_UInt, pixel_height: FT_UInt) FT_Error;
pub extern fn FT_Load_Glyph(face: FT_Face, glyph_index: FT_UInt, load_flags: FT_Int32) FT_Error;
pub extern fn FT_Load_Char(face: FT_Face, char_code: FT_ULong, load_flags: FT_Int32) FT_Error;
pub extern fn FT_Set_Transform(face: FT_Face, matrix: [*c]FT_Matrix, delta: [*c]FT_Vector) void;
pub extern fn FT_Get_Transform(face: FT_Face, matrix: [*c]FT_Matrix, delta: [*c]FT_Vector) void;
pub const FT_RENDER_MODE_NORMAL: c_int = 0;
pub const FT_RENDER_MODE_LIGHT: c_int = 1;
pub const FT_RENDER_MODE_MONO: c_int = 2;
pub const FT_RENDER_MODE_LCD: c_int = 3;
pub const FT_RENDER_MODE_LCD_V: c_int = 4;
pub const FT_RENDER_MODE_SDF: c_int = 5;
pub const FT_RENDER_MODE_MAX: c_int = 6;
pub const enum_FT_Render_Mode_ = c_uint;
pub const FT_Render_Mode = enum_FT_Render_Mode_;
pub extern fn FT_Render_Glyph(slot: FT_GlyphSlot, render_mode: FT_Render_Mode) FT_Error;
pub const FT_KERNING_DEFAULT: c_int = 0;
pub const FT_KERNING_UNFITTED: c_int = 1;
pub const FT_KERNING_UNSCALED: c_int = 2;
pub const enum_FT_Kerning_Mode_ = c_uint;
pub const FT_Kerning_Mode = enum_FT_Kerning_Mode_;
pub extern fn FT_Get_Kerning(face: FT_Face, left_glyph: FT_UInt, right_glyph: FT_UInt, kern_mode: FT_UInt, akerning: [*c]FT_Vector) FT_Error;
pub extern fn FT_Get_Track_Kerning(face: FT_Face, point_size: FT_Fixed, degree: FT_Int, akerning: [*c]FT_Fixed) FT_Error;
pub extern fn FT_Select_Charmap(face: FT_Face, encoding: FT_Encoding) FT_Error;
pub extern fn FT_Set_Charmap(face: FT_Face, charmap: FT_CharMap) FT_Error;
pub extern fn FT_Get_Charmap_Index(charmap: FT_CharMap) FT_Int;
pub extern fn FT_Get_Char_Index(face: FT_Face, charcode: FT_ULong) FT_UInt;
pub extern fn FT_Get_First_Char(face: FT_Face, agindex: [*c]FT_UInt) FT_ULong;
pub extern fn FT_Get_Next_Char(face: FT_Face, char_code: FT_ULong, agindex: [*c]FT_UInt) FT_ULong;
pub extern fn FT_Face_Properties(face: FT_Face, num_properties: FT_UInt, properties: [*c]FT_Parameter) FT_Error;
pub extern fn FT_Get_Name_Index(face: FT_Face, glyph_name: [*c]const FT_String) FT_UInt;
pub extern fn FT_Get_Glyph_Name(face: FT_Face, glyph_index: FT_UInt, buffer: FT_Pointer, buffer_max: FT_UInt) FT_Error;
pub extern fn FT_Get_Postscript_Name(face: FT_Face) [*c]const u8;
pub extern fn FT_Get_SubGlyph_Info(glyph: FT_GlyphSlot, sub_index: FT_UInt, p_index: [*c]FT_Int, p_flags: [*c]FT_UInt, p_arg1: [*c]FT_Int, p_arg2: [*c]FT_Int, p_transform: [*c]FT_Matrix) FT_Error;
pub extern fn FT_Get_FSType_Flags(face: FT_Face) FT_UShort;
pub extern fn FT_Face_GetCharVariantIndex(face: FT_Face, charcode: FT_ULong, variantSelector: FT_ULong) FT_UInt;
pub extern fn FT_Face_GetCharVariantIsDefault(face: FT_Face, charcode: FT_ULong, variantSelector: FT_ULong) FT_Int;
pub extern fn FT_Face_GetVariantSelectors(face: FT_Face) [*c]FT_UInt32;
pub extern fn FT_Face_GetVariantsOfChar(face: FT_Face, charcode: FT_ULong) [*c]FT_UInt32;
pub extern fn FT_Face_GetCharsOfVariant(face: FT_Face, variantSelector: FT_ULong) [*c]FT_UInt32;
pub extern fn FT_MulDiv(a: FT_Long, b: FT_Long, c: FT_Long) FT_Long;
pub extern fn FT_MulFix(a: FT_Long, b: FT_Long) FT_Long;
pub extern fn FT_DivFix(a: FT_Long, b: FT_Long) FT_Long;
pub extern fn FT_RoundFix(a: FT_Fixed) FT_Fixed;
pub extern fn FT_CeilFix(a: FT_Fixed) FT_Fixed;
pub extern fn FT_FloorFix(a: FT_Fixed) FT_Fixed;
pub extern fn FT_Vector_Transform(vector: [*c]FT_Vector, matrix: [*c]const FT_Matrix) void;
pub extern fn FT_Library_Version(library: FT_Library, amajor: [*c]FT_Int, aminor: [*c]FT_Int, apatch: [*c]FT_Int) void;
pub extern fn FT_Face_CheckTrueTypePatents(face: FT_Face) FT_Bool;
pub extern fn FT_Face_SetUnpatentedHinting(face: FT_Face, value: FT_Bool) FT_Bool;
pub extern fn hb_ft_face_create(ft_face: FT_Face, destroy: hb_destroy_func_t) ?*hb_face_t;
pub extern fn hb_ft_face_create_cached(ft_face: FT_Face) ?*hb_face_t;
pub extern fn hb_ft_face_create_referenced(ft_face: FT_Face) ?*hb_face_t;
pub extern fn hb_ft_face_create_from_file_or_fail(file_name: [*c]const u8, index: c_uint) ?*hb_face_t;
pub extern fn hb_ft_face_create_from_blob_or_fail(blob: ?*hb_blob_t, index: c_uint) ?*hb_face_t;
pub extern fn hb_ft_font_create(ft_face: FT_Face, destroy: hb_destroy_func_t) ?*hb_font_t;
pub extern fn hb_ft_font_create_referenced(ft_face: FT_Face) ?*hb_font_t;
pub extern fn hb_ft_font_get_ft_face(font: ?*hb_font_t) FT_Face;
pub extern fn hb_ft_font_lock_face(font: ?*hb_font_t) FT_Face;
pub extern fn hb_ft_font_unlock_face(font: ?*hb_font_t) void;
pub extern fn hb_ft_font_set_load_flags(font: ?*hb_font_t, load_flags: c_int) void;
pub extern fn hb_ft_font_get_load_flags(font: ?*hb_font_t) c_int;
pub extern fn hb_ft_font_changed(font: ?*hb_font_t) void;
pub extern fn hb_ft_hb_font_changed(font: ?*hb_font_t) hb_bool_t;
pub extern fn hb_ft_font_set_funcs(font: ?*hb_font_t) void;
pub extern fn hb_ft_font_get_face(font: ?*hb_font_t) FT_Face;

pub const __VERSION__ = "Aro aro-zig";
pub const __Aro__ = "";
pub const __STDC__ = @as(c_int, 1);
pub const __STDC_HOSTED__ = @as(c_int, 1);
pub const __STDC_UTF_16__ = @as(c_int, 1);
pub const __STDC_UTF_32__ = @as(c_int, 1);
pub const __STDC_EMBED_NOT_FOUND__ = @as(c_int, 0);
pub const __STDC_EMBED_FOUND__ = @as(c_int, 1);
pub const __STDC_EMBED_EMPTY__ = @as(c_int, 2);
pub const __STDC_VERSION__ = @as(c_long, 201710);
pub const __GNUC__ = @as(c_int, 7);
pub const __GNUC_MINOR__ = @as(c_int, 1);
pub const __GNUC_PATCHLEVEL__ = @as(c_int, 0);
pub const __ARO_EMULATE_NO__ = @as(c_int, 0);
pub const __ARO_EMULATE_CLANG__ = @as(c_int, 1);
pub const __ARO_EMULATE_GCC__ = @as(c_int, 2);
pub const __ARO_EMULATE_MSVC__ = @as(c_int, 3);
pub const __ARO_EMULATE__ = __ARO_EMULATE_GCC__;
pub inline fn __building_module(x: anytype) @TypeOf(@as(c_int, 0)) {
    _ = &x;
    return @as(c_int, 0);
}
pub const linux = @as(c_int, 1);
pub const __linux = @as(c_int, 1);
pub const __linux__ = @as(c_int, 1);
pub const unix = @as(c_int, 1);
pub const __unix = @as(c_int, 1);
pub const __unix__ = @as(c_int, 1);
pub const __code_model_small__ = @as(c_int, 1);
pub const __amd64__ = @as(c_int, 1);
pub const __amd64 = @as(c_int, 1);
pub const __x86_64__ = @as(c_int, 1);
pub const __x86_64 = @as(c_int, 1);
pub const __SEG_GS = @as(c_int, 1);
pub const __SEG_FS = @as(c_int, 1);
pub const __seg_gs = @compileError("unable to translate macro: undefined identifier `address_space`"); // <builtin>:33:9
pub const __seg_fs = @compileError("unable to translate macro: undefined identifier `address_space`"); // <builtin>:34:9
pub const __LAHF_SAHF__ = @as(c_int, 1);
pub const __AES__ = @as(c_int, 1);
pub const __VAES__ = @as(c_int, 1);
pub const __PCLMUL__ = @as(c_int, 1);
pub const __VPCLMULQDQ__ = @as(c_int, 1);
pub const __LZCNT__ = @as(c_int, 1);
pub const __RDRND__ = @as(c_int, 1);
pub const __FSGSBASE__ = @as(c_int, 1);
pub const __BMI__ = @as(c_int, 1);
pub const __BMI2__ = @as(c_int, 1);
pub const __POPCNT__ = @as(c_int, 1);
pub const __PRFCHW__ = @as(c_int, 1);
pub const __RDSEED__ = @as(c_int, 1);
pub const __ADX__ = @as(c_int, 1);
pub const __MWAITX__ = @as(c_int, 1);
pub const __MOVBE__ = @as(c_int, 1);
pub const __SSE4A__ = @as(c_int, 1);
pub const __FMA__ = @as(c_int, 1);
pub const __F16C__ = @as(c_int, 1);
pub const __SHA__ = @as(c_int, 1);
pub const __FXSR__ = @as(c_int, 1);
pub const __XSAVE__ = @as(c_int, 1);
pub const __XSAVEOPT__ = @as(c_int, 1);
pub const __XSAVEC__ = @as(c_int, 1);
pub const __XSAVES__ = @as(c_int, 1);
pub const __PKU__ = @as(c_int, 1);
pub const __CLFLUSHOPT__ = @as(c_int, 1);
pub const __CLWB__ = @as(c_int, 1);
pub const __WBNOINVD__ = @as(c_int, 1);
pub const __SHSTK__ = @as(c_int, 1);
pub const __CLZERO__ = @as(c_int, 1);
pub const __RDPID__ = @as(c_int, 1);
pub const __RDPRU__ = @as(c_int, 1);
pub const __INVPCID__ = @as(c_int, 1);
pub const __CRC32__ = @as(c_int, 1);
pub const __AVX2__ = @as(c_int, 1);
pub const __AVX__ = @as(c_int, 1);
pub const __SSE4_2__ = @as(c_int, 1);
pub const __SSE4_1__ = @as(c_int, 1);
pub const __SSSE3__ = @as(c_int, 1);
pub const __SSE3__ = @as(c_int, 1);
pub const __SSE2__ = @as(c_int, 1);
pub const __SSE__ = @as(c_int, 1);
pub const __SSE_MATH__ = @as(c_int, 1);
pub const __MMX__ = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_8 = @as(c_int, 1);
pub const __SIZEOF_FLOAT128__ = @as(c_int, 16);
pub const _LP64 = @as(c_int, 1);
pub const __LP64__ = @as(c_int, 1);
pub const __FLOAT128__ = @as(c_int, 1);
pub const __ORDER_LITTLE_ENDIAN__ = @as(c_int, 1234);
pub const __ORDER_BIG_ENDIAN__ = @as(c_int, 4321);
pub const __ORDER_PDP_ENDIAN__ = @as(c_int, 3412);
pub const __BYTE_ORDER__ = __ORDER_LITTLE_ENDIAN__;
pub const __LITTLE_ENDIAN__ = @as(c_int, 1);
pub const __ELF__ = @as(c_int, 1);
pub const __ATOMIC_RELAXED = @as(c_int, 0);
pub const __ATOMIC_CONSUME = @as(c_int, 1);
pub const __ATOMIC_ACQUIRE = @as(c_int, 2);
pub const __ATOMIC_RELEASE = @as(c_int, 3);
pub const __ATOMIC_ACQ_REL = @as(c_int, 4);
pub const __ATOMIC_SEQ_CST = @as(c_int, 5);
pub const __ATOMIC_BOOL_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_WINT_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_SHORT_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_INT_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_LONG_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_LLONG_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_POINTER_LOCK_FREE = @as(c_int, 1);
pub const __WINT_UNSIGNED__ = @as(c_int, 1);
pub const __CHAR_BIT__ = @as(c_int, 8);
pub const __BOOL_WIDTH__ = @as(c_int, 8);
pub const __SCHAR_MAX__ = @as(c_int, 127);
pub const __SCHAR_WIDTH__ = @as(c_int, 8);
pub const __SHRT_MAX__ = @as(c_int, 32767);
pub const __SHRT_WIDTH__ = @as(c_int, 16);
pub const __INT_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_WIDTH__ = @as(c_int, 32);
pub const __LONG_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __LONG_WIDTH__ = @as(c_int, 64);
pub const __LONG_LONG_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __LONG_LONG_WIDTH__ = @as(c_int, 64);
pub const __WCHAR_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __WCHAR_WIDTH__ = @as(c_int, 32);
pub const __WINT_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __WINT_WIDTH__ = @as(c_int, 32);
pub const __INTMAX_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTMAX_WIDTH__ = @as(c_int, 64);
pub const __SIZE_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __SIZE_WIDTH__ = @as(c_int, 64);
pub const __UINTMAX_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTMAX_WIDTH__ = @as(c_int, 64);
pub const __PTRDIFF_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __PTRDIFF_WIDTH__ = @as(c_int, 64);
pub const __INTPTR_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTPTR_WIDTH__ = @as(c_int, 64);
pub const __UINTPTR_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTPTR_WIDTH__ = @as(c_int, 64);
pub const __SIG_ATOMIC_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __SIG_ATOMIC_WIDTH__ = @as(c_int, 32);
pub const __BITINT_MAXWIDTH__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const __SIZEOF_FLOAT__ = @as(c_int, 4);
pub const __SIZEOF_DOUBLE__ = @as(c_int, 8);
pub const __SIZEOF_LONG_DOUBLE__ = @as(c_int, 10);
pub const __SIZEOF_SHORT__ = @as(c_int, 2);
pub const __SIZEOF_INT__ = @as(c_int, 4);
pub const __SIZEOF_LONG__ = @as(c_int, 8);
pub const __SIZEOF_LONG_LONG__ = @as(c_int, 8);
pub const __SIZEOF_POINTER__ = @as(c_int, 8);
pub const __SIZEOF_PTRDIFF_T__ = @as(c_int, 8);
pub const __SIZEOF_SIZE_T__ = @as(c_int, 8);
pub const __SIZEOF_WCHAR_T__ = @as(c_int, 4);
pub const __SIZEOF_WINT_T__ = @as(c_int, 4);
pub const __SIZEOF_INT128__ = @as(c_int, 16);
pub const __INTPTR_TYPE__ = c_long;
pub const __UINTPTR_TYPE__ = c_ulong;
pub const __INTMAX_TYPE__ = c_long;
pub const __INTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`"); // <builtin>:157:9
pub const __INTMAX_C = __helpers.L_SUFFIX;
pub const __UINTMAX_TYPE__ = c_ulong;
pub const __UINTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`"); // <builtin>:160:9
pub const __UINTMAX_C = __helpers.UL_SUFFIX;
pub const __PTRDIFF_TYPE__ = c_long;
pub const __SIZE_TYPE__ = c_ulong;
pub const __WCHAR_TYPE__ = c_int;
pub const __WINT_TYPE__ = c_uint;
pub const __CHAR16_TYPE__ = c_ushort;
pub const __CHAR32_TYPE__ = c_uint;
pub const __INT8_TYPE__ = i8;
pub const __INT8_FMTd__ = "hhd";
pub const __INT8_FMTi__ = "hhi";
pub const __INT8_C_SUFFIX__ = "";
pub inline fn __INT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT16_TYPE__ = c_short;
pub const __INT16_FMTd__ = "hd";
pub const __INT16_FMTi__ = "hi";
pub const __INT16_C_SUFFIX__ = "";
pub inline fn __INT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT32_TYPE__ = c_int;
pub const __INT32_FMTd__ = "d";
pub const __INT32_FMTi__ = "i";
pub const __INT32_C_SUFFIX__ = "";
pub inline fn __INT32_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT64_TYPE__ = c_long;
pub const __INT64_FMTd__ = "ld";
pub const __INT64_FMTi__ = "li";
pub const __INT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`"); // <builtin>:186:9
pub const __UINT8_TYPE__ = u8;
pub const __UINT8_FMTo__ = "hho";
pub const __UINT8_FMTu__ = "hhu";
pub const __UINT8_FMTx__ = "hhx";
pub const __UINT8_FMTX__ = "hhX";
pub const __UINT8_C_SUFFIX__ = "";
pub inline fn __UINT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __UINT8_MAX__ = @as(c_int, 255);
pub const __INT8_MAX__ = @as(c_int, 127);
pub const __UINT16_TYPE__ = c_ushort;
pub const __UINT16_FMTo__ = "ho";
pub const __UINT16_FMTu__ = "hu";
pub const __UINT16_FMTx__ = "hx";
pub const __UINT16_FMTX__ = "hX";
pub const __UINT16_C_SUFFIX__ = "";
pub inline fn __UINT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __UINT16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const __INT16_MAX__ = @as(c_int, 32767);
pub const __UINT32_TYPE__ = c_uint;
pub const __UINT32_FMTo__ = "o";
pub const __UINT32_FMTu__ = "u";
pub const __UINT32_FMTx__ = "x";
pub const __UINT32_FMTX__ = "X";
pub const __UINT32_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `U`"); // <builtin>:211:9
pub const __UINT32_C = __helpers.U_SUFFIX;
pub const __UINT32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __INT32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __UINT64_TYPE__ = c_ulong;
pub const __UINT64_FMTo__ = "lo";
pub const __UINT64_FMTu__ = "lu";
pub const __UINT64_FMTx__ = "lx";
pub const __UINT64_FMTX__ = "lX";
pub const __UINT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`"); // <builtin>:220:9
pub const __UINT64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __INT64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST8_TYPE__ = i8;
pub const __INT_LEAST8_MAX__ = @as(c_int, 127);
pub const __INT_LEAST8_WIDTH__ = @as(c_int, 8);
pub const INT_LEAST8_FMTd__ = "hhd";
pub const INT_LEAST8_FMTi__ = "hhi";
pub const __UINT_LEAST8_TYPE__ = u8;
pub const __UINT_LEAST8_MAX__ = @as(c_int, 255);
pub const UINT_LEAST8_FMTo__ = "hho";
pub const UINT_LEAST8_FMTu__ = "hhu";
pub const UINT_LEAST8_FMTx__ = "hhx";
pub const UINT_LEAST8_FMTX__ = "hhX";
pub const __INT_FAST8_TYPE__ = i8;
pub const __INT_FAST8_MAX__ = @as(c_int, 127);
pub const __INT_FAST8_WIDTH__ = @as(c_int, 8);
pub const INT_FAST8_FMTd__ = "hhd";
pub const INT_FAST8_FMTi__ = "hhi";
pub const __UINT_FAST8_TYPE__ = u8;
pub const __UINT_FAST8_MAX__ = @as(c_int, 255);
pub const UINT_FAST8_FMTo__ = "hho";
pub const UINT_FAST8_FMTu__ = "hhu";
pub const UINT_FAST8_FMTx__ = "hhx";
pub const UINT_FAST8_FMTX__ = "hhX";
pub const __INT_LEAST16_TYPE__ = c_short;
pub const __INT_LEAST16_MAX__ = @as(c_int, 32767);
pub const __INT_LEAST16_WIDTH__ = @as(c_int, 16);
pub const INT_LEAST16_FMTd__ = "hd";
pub const INT_LEAST16_FMTi__ = "hi";
pub const __UINT_LEAST16_TYPE__ = c_ushort;
pub const __UINT_LEAST16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_LEAST16_FMTo__ = "ho";
pub const UINT_LEAST16_FMTu__ = "hu";
pub const UINT_LEAST16_FMTx__ = "hx";
pub const UINT_LEAST16_FMTX__ = "hX";
pub const __INT_FAST16_TYPE__ = c_short;
pub const __INT_FAST16_MAX__ = @as(c_int, 32767);
pub const __INT_FAST16_WIDTH__ = @as(c_int, 16);
pub const INT_FAST16_FMTd__ = "hd";
pub const INT_FAST16_FMTi__ = "hi";
pub const __UINT_FAST16_TYPE__ = c_ushort;
pub const __UINT_FAST16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_FAST16_FMTo__ = "ho";
pub const UINT_FAST16_FMTu__ = "hu";
pub const UINT_FAST16_FMTx__ = "hx";
pub const UINT_FAST16_FMTX__ = "hX";
pub const __INT_LEAST32_TYPE__ = c_int;
pub const __INT_LEAST32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_LEAST32_WIDTH__ = @as(c_int, 32);
pub const INT_LEAST32_FMTd__ = "d";
pub const INT_LEAST32_FMTi__ = "i";
pub const __UINT_LEAST32_TYPE__ = c_uint;
pub const __UINT_LEAST32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_LEAST32_FMTo__ = "o";
pub const UINT_LEAST32_FMTu__ = "u";
pub const UINT_LEAST32_FMTx__ = "x";
pub const UINT_LEAST32_FMTX__ = "X";
pub const __INT_FAST32_TYPE__ = c_int;
pub const __INT_FAST32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_FAST32_WIDTH__ = @as(c_int, 32);
pub const INT_FAST32_FMTd__ = "d";
pub const INT_FAST32_FMTi__ = "i";
pub const __UINT_FAST32_TYPE__ = c_uint;
pub const __UINT_FAST32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_FAST32_FMTo__ = "o";
pub const UINT_FAST32_FMTu__ = "u";
pub const UINT_FAST32_FMTx__ = "x";
pub const UINT_FAST32_FMTX__ = "X";
pub const __INT_LEAST64_TYPE__ = c_long;
pub const __INT_LEAST64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST64_WIDTH__ = @as(c_int, 64);
pub const INT_LEAST64_FMTd__ = "ld";
pub const INT_LEAST64_FMTi__ = "li";
pub const __UINT_LEAST64_TYPE__ = c_ulong;
pub const __UINT_LEAST64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_LEAST64_FMTo__ = "lo";
pub const UINT_LEAST64_FMTu__ = "lu";
pub const UINT_LEAST64_FMTx__ = "lx";
pub const UINT_LEAST64_FMTX__ = "lX";
pub const __INT_FAST64_TYPE__ = c_long;
pub const __INT_FAST64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_FAST64_WIDTH__ = @as(c_int, 64);
pub const INT_FAST64_FMTd__ = "ld";
pub const INT_FAST64_FMTi__ = "li";
pub const __UINT_FAST64_TYPE__ = c_ulong;
pub const __UINT_FAST64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST64_FMTo__ = "lo";
pub const UINT_FAST64_FMTu__ = "lu";
pub const UINT_FAST64_FMTx__ = "lx";
pub const UINT_FAST64_FMTX__ = "lX";
pub const __FLT16_DENORM_MIN__ = @as(f16, 5.9604644775390625e-8);
pub const __FLT16_HAS_DENORM__ = "";
pub const __FLT16_DIG__ = @as(c_int, 3);
pub const __FLT16_DECIMAL_DIG__ = @as(c_int, 5);
pub const __FLT16_EPSILON__ = @as(f16, 9.765625e-4);
pub const __FLT16_HAS_INFINITY__ = "";
pub const __FLT16_HAS_QUIET_NAN__ = "";
pub const __FLT16_MANT_DIG__ = @as(c_int, 11);
pub const __FLT16_MAX_10_EXP__ = @as(c_int, 4);
pub const __FLT16_MAX_EXP__ = @as(c_int, 16);
pub const __FLT16_MAX__ = @as(f16, 6.5504e+4);
pub const __FLT16_MIN_10_EXP__ = -@as(c_int, 4);
pub const __FLT16_MIN_EXP__ = -@as(c_int, 13);
pub const __FLT16_MIN__ = @as(f16, 6.103515625e-5);
pub const __FLT_DENORM_MIN__ = @as(f32, 1.40129846e-45);
pub const __FLT_HAS_DENORM__ = "";
pub const __FLT_DIG__ = @as(c_int, 6);
pub const __FLT_DECIMAL_DIG__ = @as(c_int, 9);
pub const __FLT_EPSILON__ = @as(f32, 1.19209290e-7);
pub const __FLT_HAS_INFINITY__ = "";
pub const __FLT_HAS_QUIET_NAN__ = "";
pub const __FLT_MANT_DIG__ = @as(c_int, 24);
pub const __FLT_MAX_10_EXP__ = @as(c_int, 38);
pub const __FLT_MAX_EXP__ = @as(c_int, 128);
pub const __FLT_MAX__ = @as(f32, 3.40282347e+38);
pub const __FLT_MIN_10_EXP__ = -@as(c_int, 37);
pub const __FLT_MIN_EXP__ = -@as(c_int, 125);
pub const __FLT_MIN__ = @as(f32, 1.17549435e-38);
pub const __DBL_DENORM_MIN__ = @as(f64, 4.9406564584124654e-324);
pub const __DBL_HAS_DENORM__ = "";
pub const __DBL_DIG__ = @as(c_int, 15);
pub const __DBL_DECIMAL_DIG__ = @as(c_int, 17);
pub const __DBL_EPSILON__ = @as(f64, 2.2204460492503131e-16);
pub const __DBL_HAS_INFINITY__ = "";
pub const __DBL_HAS_QUIET_NAN__ = "";
pub const __DBL_MANT_DIG__ = @as(c_int, 53);
pub const __DBL_MAX_10_EXP__ = @as(c_int, 308);
pub const __DBL_MAX_EXP__ = @as(c_int, 1024);
pub const __DBL_MAX__ = @as(f64, 1.7976931348623157e+308);
pub const __DBL_MIN_10_EXP__ = -@as(c_int, 307);
pub const __DBL_MIN_EXP__ = -@as(c_int, 1021);
pub const __DBL_MIN__ = @as(f64, 2.2250738585072014e-308);
pub const __LDBL_DENORM_MIN__ = @as(c_longdouble, 3.64519953188247460253e-4951);
pub const __LDBL_HAS_DENORM__ = "";
pub const __LDBL_DIG__ = @as(c_int, 18);
pub const __LDBL_DECIMAL_DIG__ = @as(c_int, 21);
pub const __LDBL_EPSILON__ = @as(c_longdouble, 1.08420217248550443401e-19);
pub const __LDBL_HAS_INFINITY__ = "";
pub const __LDBL_HAS_QUIET_NAN__ = "";
pub const __LDBL_MANT_DIG__ = @as(c_int, 64);
pub const __LDBL_MAX_10_EXP__ = @as(c_int, 4932);
pub const __LDBL_MAX_EXP__ = @as(c_int, 16384);
pub const __LDBL_MAX__ = @as(c_longdouble, 1.18973149535723176502e+4932);
pub const __LDBL_MIN_10_EXP__ = -@as(c_int, 4931);
pub const __LDBL_MIN_EXP__ = -@as(c_int, 16381);
pub const __LDBL_MIN__ = @as(c_longdouble, 3.36210314311209350626e-4932);
pub const __FLT_EVAL_METHOD__ = @as(c_int, 0);
pub const __FLT_RADIX__ = @as(c_int, 2);
pub const __DECIMAL_DIG__ = __LDBL_DECIMAL_DIG__;
pub const HB_H = "";
pub const HB_BLOB_H = "";
pub const HB_COMMON_H = "";
pub const HB_EXTERN = @compileError("unable to translate C expr: unexpected token 'extern'"); // /usr/include/harfbuzz/hb-common.h:37:9
pub const HB_BEGIN_DECLS = "";
pub const HB_END_DECLS = "";
pub const _INTTYPES_H = @as(c_int, 1);
pub const _FEATURES_H = @as(c_int, 1);
pub const __KERNEL_STRICT_NAMES = "";
pub inline fn __GNUC_PREREQ(maj: anytype, min: anytype) @TypeOf(((__GNUC__ << @as(c_int, 16)) + __GNUC_MINOR__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__GNUC__ << @as(c_int, 16)) + __GNUC_MINOR__) >= ((maj << @as(c_int, 16)) + min);
}
pub inline fn __glibc_clang_prereq(maj: anytype, min: anytype) @TypeOf(@as(c_int, 0)) {
    _ = &maj;
    _ = &min;
    return @as(c_int, 0);
}
pub const __GLIBC_USE = @compileError("unable to translate macro: undefined identifier `__GLIBC_USE_`"); // /usr/include/features.h:197:9
pub const _DEFAULT_SOURCE = @as(c_int, 1);
pub const __GLIBC_USE_ISOC2Y = @as(c_int, 0);
pub const __GLIBC_USE_ISOC23 = @as(c_int, 0);
pub const __USE_ISOC11 = @as(c_int, 1);
pub const __USE_POSIX_IMPLICITLY = @as(c_int, 1);
pub const _POSIX_SOURCE = @as(c_int, 1);
pub const _POSIX_C_SOURCE = @as(c_long, 202405);
pub const __USE_POSIX = @as(c_int, 1);
pub const __USE_POSIX2 = @as(c_int, 1);
pub const __USE_POSIX199309 = @as(c_int, 1);
pub const __USE_POSIX199506 = @as(c_int, 1);
pub const __USE_XOPEN2K = @as(c_int, 1);
pub const __USE_ISOC95 = @as(c_int, 1);
pub const __USE_ISOC99 = @as(c_int, 1);
pub const __USE_XOPEN2K8 = @as(c_int, 1);
pub const _ATFILE_SOURCE = @as(c_int, 1);
pub const __USE_XOPEN2K24 = @as(c_int, 1);
pub const __WORDSIZE = @as(c_int, 64);
pub const __WORDSIZE_TIME64_COMPAT32 = @as(c_int, 1);
pub const __SYSCALL_WORDSIZE = @as(c_int, 64);
pub const __TIMESIZE = __WORDSIZE;
pub const __USE_TIME_BITS64 = @as(c_int, 1);
pub const __USE_MISC = @as(c_int, 1);
pub const __USE_ATFILE = @as(c_int, 1);
pub const __USE_FORTIFY_LEVEL = @as(c_int, 0);
pub const __GLIBC_USE_DEPRECATED_GETS = @as(c_int, 0);
pub const __GLIBC_USE_DEPRECATED_SCANF = @as(c_int, 0);
pub const __GLIBC_USE_C23_STRTOL = @as(c_int, 0);
pub const _STDC_PREDEF_H = @as(c_int, 1);
pub const __STDC_IEC_559__ = @as(c_int, 1);
pub const __STDC_IEC_60559_BFP__ = @as(c_long, 201404);
pub const __STDC_IEC_559_COMPLEX__ = @as(c_int, 1);
pub const __STDC_IEC_60559_COMPLEX__ = @as(c_long, 201404);
pub const __STDC_ISO_10646__ = @as(c_long, 201706);
pub const __GNU_LIBRARY__ = @as(c_int, 6);
pub const __GLIBC__ = @as(c_int, 2);
pub const __GLIBC_MINOR__ = @as(c_int, 43);
pub inline fn __GLIBC_PREREQ(maj: anytype, min: anytype) @TypeOf(((__GLIBC__ << @as(c_int, 16)) + __GLIBC_MINOR__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__GLIBC__ << @as(c_int, 16)) + __GLIBC_MINOR__) >= ((maj << @as(c_int, 16)) + min);
}
pub const _SYS_CDEFS_H = @as(c_int, 1);
pub const __glibc_has_attribute = @compileError("unable to translate macro: undefined identifier `__has_attribute`"); // /usr/include/sys/cdefs.h:45:10
pub inline fn __glibc_has_builtin(name: anytype) @TypeOf(__builtin.has_builtin(name)) {
    _ = &name;
    return __builtin.has_builtin(name);
}
pub const __glibc_has_extension = @compileError("unable to translate macro: undefined identifier `__has_extension`"); // /usr/include/sys/cdefs.h:55:10
pub const __LEAF = @compileError("unable to translate macro: undefined identifier `__leaf__`"); // /usr/include/sys/cdefs.h:65:11
pub const __LEAF_ATTR = @compileError("unable to translate macro: undefined identifier `__leaf__`"); // /usr/include/sys/cdefs.h:66:11
pub const __THROW = @compileError("unable to translate macro: undefined identifier `__nothrow__`"); // /usr/include/sys/cdefs.h:79:11
pub const __THROWNL = @compileError("unable to translate macro: undefined identifier `__nothrow__`"); // /usr/include/sys/cdefs.h:80:11
pub const __NTH = @compileError("unable to translate macro: undefined identifier `__nothrow__`"); // /usr/include/sys/cdefs.h:81:11
pub const __NTHNL = @compileError("unable to translate macro: undefined identifier `__nothrow__`"); // /usr/include/sys/cdefs.h:82:11
pub const __COLD = @compileError("unable to translate macro: undefined identifier `__cold__`"); // /usr/include/sys/cdefs.h:102:11
pub inline fn __P(args: anytype) @TypeOf(args) {
    _ = &args;
    return args;
}
pub inline fn __PMT(args: anytype) @TypeOf(args) {
    _ = &args;
    return args;
}
pub const __CONCAT = @compileError("unable to translate C expr: unexpected token '##'"); // /usr/include/sys/cdefs.h:131:9
pub const __STRING = @compileError("unable to translate C expr: unexpected token ''"); // /usr/include/sys/cdefs.h:132:9
pub const __ptr_t = ?*anyopaque;
pub const __BEGIN_DECLS = "";
pub const __END_DECLS = "";
pub const __attribute_overloadable__ = "";
pub inline fn __bos(ptr: anytype) @TypeOf(__builtin.object_size(ptr, __USE_FORTIFY_LEVEL > @as(c_int, 1))) {
    _ = &ptr;
    return __builtin.object_size(ptr, __USE_FORTIFY_LEVEL > @as(c_int, 1));
}
pub inline fn __bos0(ptr: anytype) @TypeOf(__builtin.object_size(ptr, @as(c_int, 0))) {
    _ = &ptr;
    return __builtin.object_size(ptr, @as(c_int, 0));
}
pub inline fn __glibc_objsize0(__o: anytype) @TypeOf(__bos0(__o)) {
    _ = &__o;
    return __bos0(__o);
}
pub inline fn __glibc_objsize(__o: anytype) @TypeOf(__bos(__o)) {
    _ = &__o;
    return __bos(__o);
}
pub const __warnattr = @compileError("unable to translate macro: undefined identifier `__warning__`"); // /usr/include/sys/cdefs.h:366:10
pub const __errordecl = @compileError("unable to translate macro: undefined identifier `__error__`"); // /usr/include/sys/cdefs.h:367:10
pub const __flexarr = @compileError("unable to translate C expr: unexpected token '['"); // /usr/include/sys/cdefs.h:379:10
pub const __glibc_c99_flexarr_available = @as(c_int, 1);
pub const __REDIRECT = @compileError("unable to translate C expr: unexpected token '__asm__'"); // /usr/include/sys/cdefs.h:410:10
pub const __REDIRECT_NTH = @compileError("unable to translate C expr: unexpected token '__asm__'"); // /usr/include/sys/cdefs.h:417:11
pub const __REDIRECT_NTHNL = @compileError("unable to translate C expr: unexpected token '__asm__'"); // /usr/include/sys/cdefs.h:419:11
pub const __ASMNAME = @compileError("unable to translate macro: undefined identifier `__USER_LABEL_PREFIX__`"); // /usr/include/sys/cdefs.h:422:10
pub inline fn __ASMNAME2(prefix: anytype, cname: anytype) @TypeOf(__STRING(prefix) ++ cname) {
    _ = &prefix;
    _ = &cname;
    return __STRING(prefix) ++ cname;
}
pub const __REDIRECT_FORTIFY = __REDIRECT;
pub const __REDIRECT_FORTIFY_NTH = __REDIRECT_NTH;
pub const __attribute_malloc__ = @compileError("unable to translate macro: undefined identifier `__malloc__`"); // /usr/include/sys/cdefs.h:452:10
pub const __attribute_alloc_size__ = @compileError("unable to translate macro: undefined identifier `__alloc_size__`"); // /usr/include/sys/cdefs.h:460:10
pub const __attribute_alloc_align__ = @compileError("unable to translate macro: undefined identifier `__alloc_align__`"); // /usr/include/sys/cdefs.h:469:10
pub const __attribute_pure__ = @compileError("unable to translate macro: undefined identifier `__pure__`"); // /usr/include/sys/cdefs.h:479:10
pub const __attribute_const__ = @compileError("unable to translate C expr: unexpected token '__attribute__'"); // /usr/include/sys/cdefs.h:486:10
pub const __attribute_maybe_unused__ = @compileError("unable to translate macro: undefined identifier `__unused__`"); // /usr/include/sys/cdefs.h:492:10
pub const __attribute_used__ = @compileError("unable to translate macro: undefined identifier `__used__`"); // /usr/include/sys/cdefs.h:501:10
pub const __attribute_noinline__ = @compileError("unable to translate macro: undefined identifier `__noinline__`"); // /usr/include/sys/cdefs.h:502:10
pub const __attribute_deprecated__ = @compileError("unable to translate macro: undefined identifier `__deprecated__`"); // /usr/include/sys/cdefs.h:510:10
pub const __attribute_deprecated_msg__ = @compileError("unable to translate macro: undefined identifier `__deprecated__`"); // /usr/include/sys/cdefs.h:520:10
pub const __attribute_format_arg__ = @compileError("unable to translate macro: undefined identifier `__format_arg__`"); // /usr/include/sys/cdefs.h:533:10
pub const __attribute_format_strfmon__ = @compileError("unable to translate macro: undefined identifier `__format__`"); // /usr/include/sys/cdefs.h:543:10
pub const __attribute_nonnull__ = @compileError("unable to translate macro: undefined identifier `__nonnull__`"); // /usr/include/sys/cdefs.h:555:11
pub inline fn __nonnull(params: anytype) @TypeOf(__attribute_nonnull__(params)) {
    _ = &params;
    return __attribute_nonnull__(params);
}
pub const __returns_nonnull = @compileError("unable to translate macro: undefined identifier `__returns_nonnull__`"); // /usr/include/sys/cdefs.h:568:10
pub const __attribute_warn_unused_result__ = @compileError("unable to translate macro: undefined identifier `__warn_unused_result__`"); // /usr/include/sys/cdefs.h:577:10
pub const __wur = "";
pub const __always_inline = @compileError("unable to translate macro: undefined identifier `__always_inline__`"); // /usr/include/sys/cdefs.h:595:10
pub const __attribute_artificial__ = @compileError("unable to translate macro: undefined identifier `__artificial__`"); // /usr/include/sys/cdefs.h:604:10
pub const __extern_inline = @compileError("unable to translate C expr: unexpected token 'extern'"); // /usr/include/sys/cdefs.h:626:11
pub const __extern_always_inline = @compileError("unable to translate C expr: unexpected token 'extern'"); // /usr/include/sys/cdefs.h:627:11
pub const __fortify_function = __extern_always_inline ++ __attribute_artificial__;
pub const __va_arg_pack = @compileError("unable to translate macro: undefined identifier `__builtin_va_arg_pack`"); // /usr/include/sys/cdefs.h:638:10
pub const __va_arg_pack_len = @compileError("unable to translate macro: undefined identifier `__builtin_va_arg_pack_len`"); // /usr/include/sys/cdefs.h:639:10
pub const __restrict_arr = @compileError("unable to translate C expr: unexpected token '__restrict'"); // /usr/include/sys/cdefs.h:666:10
pub inline fn __glibc_unlikely(cond: anytype) @TypeOf(__builtin.expect(cond, @as(c_int, 0))) {
    _ = &cond;
    return __builtin.expect(cond, @as(c_int, 0));
}
pub inline fn __glibc_likely(cond: anytype) @TypeOf(__builtin.expect(cond, @as(c_int, 1))) {
    _ = &cond;
    return __builtin.expect(cond, @as(c_int, 1));
}
pub const __attribute_nonstring__ = "";
pub inline fn __attribute_copy__(arg: anytype) void {
    _ = &arg;
    return;
}
pub const __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI = @as(c_int, 0);
pub inline fn __LDBL_REDIR1(name: anytype, proto: anytype, alias: anytype) @TypeOf(name ++ proto) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return name ++ proto;
}
pub inline fn __LDBL_REDIR(name: anytype, proto: anytype) @TypeOf(name ++ proto) {
    _ = &name;
    _ = &proto;
    return name ++ proto;
}
pub inline fn __LDBL_REDIR1_NTH(name: anytype, proto: anytype, alias: anytype) @TypeOf(name ++ proto ++ __THROW) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return name ++ proto ++ __THROW;
}
pub inline fn __LDBL_REDIR_NTH(name: anytype, proto: anytype) @TypeOf(name ++ proto ++ __THROW) {
    _ = &name;
    _ = &proto;
    return name ++ proto ++ __THROW;
}
pub inline fn __LDBL_REDIR2_DECL(name: anytype) void {
    _ = &name;
    return;
}
pub inline fn __LDBL_REDIR_DECL(name: anytype) void {
    _ = &name;
    return;
}
pub inline fn __REDIRECT_LDBL(name: anytype, proto: anytype, alias: anytype) @TypeOf(__REDIRECT(name, proto, alias)) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return __REDIRECT(name, proto, alias);
}
pub inline fn __REDIRECT_NTH_LDBL(name: anytype, proto: anytype, alias: anytype) @TypeOf(__REDIRECT_NTH(name, proto, alias)) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return __REDIRECT_NTH(name, proto, alias);
}
pub const __glibc_macro_warning1 = @compileError("unable to translate macro: undefined identifier `_Pragma`"); // /usr/include/sys/cdefs.h:807:10
pub const __glibc_macro_warning = @compileError("unable to translate macro: undefined identifier `GCC`"); // /usr/include/sys/cdefs.h:808:10
pub const __HAVE_GENERIC_SELECTION = @as(c_int, 1);
pub const __glibc_const_generic = @compileError("unable to translate C expr: expected type instead got 'const'"); // /usr/include/sys/cdefs.h:837:10
pub inline fn __fortified_attr_access(a: anytype, o: anytype, s: anytype) void {
    _ = &a;
    _ = &o;
    _ = &s;
    return;
}
pub inline fn __attr_access(x: anytype) void {
    _ = &x;
    return;
}
pub inline fn __attr_access_none(argno: anytype) void {
    _ = &argno;
    return;
}
pub inline fn __attr_dealloc(dealloc: anytype, argno: anytype) void {
    _ = &dealloc;
    _ = &argno;
    return;
}
pub const __attr_dealloc_free = "";
pub const __attribute_returns_twice__ = @compileError("unable to translate macro: undefined identifier `__returns_twice__`"); // /usr/include/sys/cdefs.h:884:10
pub const __attribute_struct_may_alias__ = @compileError("unable to translate macro: undefined identifier `__may_alias__`"); // /usr/include/sys/cdefs.h:893:10
pub const __stub___compat_bdflush = "";
pub const __stub_chflags = "";
pub const __stub_fchflags = "";
pub const __stub_gtty = "";
pub const __stub_revoke = "";
pub const __stub_setlogin = "";
pub const __stub_sigreturn = "";
pub const __stub_stty = "";
pub const _STDINT_H = @as(c_int, 1);
pub const _BITS_TYPES_H = @as(c_int, 1);
pub const __S16_TYPE = c_short;
pub const __U16_TYPE = c_ushort;
pub const __S32_TYPE = c_int;
pub const __U32_TYPE = c_uint;
pub const __SLONGWORD_TYPE = c_long;
pub const __ULONGWORD_TYPE = c_ulong;
pub const __SQUAD_TYPE = c_long;
pub const __UQUAD_TYPE = c_ulong;
pub const __SWORD_TYPE = c_long;
pub const __UWORD_TYPE = c_ulong;
pub const __SLONG32_TYPE = c_int;
pub const __ULONG32_TYPE = c_uint;
pub const __S64_TYPE = c_long;
pub const __U64_TYPE = c_ulong;
pub const _BITS_TYPESIZES_H = @as(c_int, 1);
pub const __SYSCALL_SLONG_TYPE = __SLONGWORD_TYPE;
pub const __SYSCALL_ULONG_TYPE = __ULONGWORD_TYPE;
pub const __DEV_T_TYPE = __UQUAD_TYPE;
pub const __UID_T_TYPE = __U32_TYPE;
pub const __GID_T_TYPE = __U32_TYPE;
pub const __INO_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __INO64_T_TYPE = __UQUAD_TYPE;
pub const __MODE_T_TYPE = __U32_TYPE;
pub const __NLINK_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSWORD_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __OFF_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __OFF64_T_TYPE = __SQUAD_TYPE;
pub const __PID_T_TYPE = __S32_TYPE;
pub const __RLIM_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __RLIM64_T_TYPE = __UQUAD_TYPE;
pub const __BLKCNT_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __BLKCNT64_T_TYPE = __SQUAD_TYPE;
pub const __FSBLKCNT_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSBLKCNT64_T_TYPE = __UQUAD_TYPE;
pub const __FSFILCNT_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSFILCNT64_T_TYPE = __UQUAD_TYPE;
pub const __ID_T_TYPE = __U32_TYPE;
pub const __CLOCK_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __TIME_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __USECONDS_T_TYPE = __U32_TYPE;
pub const __SUSECONDS_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __SUSECONDS64_T_TYPE = __SQUAD_TYPE;
pub const __DADDR_T_TYPE = __S32_TYPE;
pub const __KEY_T_TYPE = __S32_TYPE;
pub const __CLOCKID_T_TYPE = __S32_TYPE;
pub const __TIMER_T_TYPE = ?*anyopaque;
pub const __BLKSIZE_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __FSID_T_TYPE = @compileError("unable to translate macro: undefined identifier `__val`"); // /usr/include/bits/typesizes.h:73:9
pub const __SSIZE_T_TYPE = __SWORD_TYPE;
pub const __CPU_MASK_TYPE = __SYSCALL_ULONG_TYPE;
pub const __OFF_T_MATCHES_OFF64_T = @as(c_int, 1);
pub const __INO_T_MATCHES_INO64_T = @as(c_int, 1);
pub const __RLIM_T_MATCHES_RLIM64_T = @as(c_int, 1);
pub const __STATFS_MATCHES_STATFS64 = @as(c_int, 1);
pub const __KERNEL_OLD_TIMEVAL_MATCHES_TIMEVAL64 = @as(c_int, 1);
pub const __FD_SETSIZE = @as(c_int, 1024);
pub const _BITS_TIME64_H = @as(c_int, 1);
pub const __TIME64_T_TYPE = __TIME_T_TYPE;
pub const _BITS_WCHAR_H = @as(c_int, 1);
pub const __WCHAR_MAX = __WCHAR_MAX__;
pub const __WCHAR_MIN = -__WCHAR_MAX - @as(c_int, 1);
pub const _BITS_STDINT_INTN_H = @as(c_int, 1);
pub const _BITS_STDINT_UINTN_H = @as(c_int, 1);
pub const _BITS_STDINT_LEAST_H = @as(c_int, 1);
pub const __intptr_t_defined = "";
pub const __INT64_C = __helpers.L_SUFFIX;
pub const __UINT64_C = __helpers.UL_SUFFIX;
pub const INT8_MIN = -@as(c_int, 128);
pub const INT16_MIN = -@as(c_int, 32767) - @as(c_int, 1);
pub const INT32_MIN = -__helpers.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const INT64_MIN = -__INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT8_MAX = @as(c_int, 127);
pub const INT16_MAX = @as(c_int, 32767);
pub const INT32_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const INT64_MAX = __INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT8_MAX = @as(c_int, 255);
pub const UINT16_MAX = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT32_MAX = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT64_MAX = __UINT64_C(__helpers.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INT_LEAST8_MIN = -@as(c_int, 128);
pub const INT_LEAST16_MIN = -@as(c_int, 32767) - @as(c_int, 1);
pub const INT_LEAST32_MIN = -__helpers.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const INT_LEAST64_MIN = -__INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT_LEAST8_MAX = @as(c_int, 127);
pub const INT_LEAST16_MAX = @as(c_int, 32767);
pub const INT_LEAST32_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const INT_LEAST64_MAX = __INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT_LEAST8_MAX = @as(c_int, 255);
pub const UINT_LEAST16_MAX = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_LEAST32_MAX = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_LEAST64_MAX = __UINT64_C(__helpers.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INT_FAST8_MIN = -@as(c_int, 128);
pub const INT_FAST16_MIN = -__helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INT_FAST32_MIN = -__helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INT_FAST64_MIN = -__INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT_FAST8_MAX = @as(c_int, 127);
pub const INT_FAST16_MAX = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const INT_FAST32_MAX = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const INT_FAST64_MAX = __INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT_FAST8_MAX = @as(c_int, 255);
pub const UINT_FAST16_MAX = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST32_MAX = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST64_MAX = __UINT64_C(__helpers.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INTPTR_MIN = -__helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INTPTR_MAX = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const UINTPTR_MAX = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const INTMAX_MIN = -__INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INTMAX_MAX = __INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINTMAX_MAX = __UINT64_C(__helpers.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const PTRDIFF_MIN = -__helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const PTRDIFF_MAX = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const SIG_ATOMIC_MIN = -__helpers.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const SIG_ATOMIC_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const SIZE_MAX = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const WCHAR_MIN = __WCHAR_MIN;
pub const WCHAR_MAX = __WCHAR_MAX;
pub const WINT_MIN = @as(c_uint, 0);
pub const WINT_MAX = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub inline fn INT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn INT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn INT32_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const INT64_C = __helpers.L_SUFFIX;
pub inline fn UINT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn UINT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const UINT32_C = __helpers.U_SUFFIX;
pub const UINT64_C = __helpers.UL_SUFFIX;
pub const INTMAX_C = __helpers.L_SUFFIX;
pub const UINTMAX_C = __helpers.UL_SUFFIX;
pub const ____gwchar_t_defined = @as(c_int, 1);
pub const __PRI64_PREFIX = "l";
pub const __PRIPTR_PREFIX = "l";
pub const PRId8 = "hhd";
pub const PRId16 = "hd";
pub const PRId32 = "d";
pub const PRId64 = __PRI64_PREFIX ++ "d";
pub const PRIdLEAST8 = "hhd";
pub const PRIdLEAST16 = "hd";
pub const PRIdLEAST32 = "d";
pub const PRIdLEAST64 = __PRI64_PREFIX ++ "d";
pub const PRIdFAST8 = "hhd";
pub const PRIdFAST16 = __PRIPTR_PREFIX ++ "d";
pub const PRIdFAST32 = __PRIPTR_PREFIX ++ "d";
pub const PRIdFAST64 = __PRI64_PREFIX ++ "d";
pub const PRIi8 = "hhi";
pub const PRIi16 = "hi";
pub const PRIi32 = "i";
pub const PRIi64 = __PRI64_PREFIX ++ "i";
pub const PRIiLEAST8 = "hhi";
pub const PRIiLEAST16 = "hi";
pub const PRIiLEAST32 = "i";
pub const PRIiLEAST64 = __PRI64_PREFIX ++ "i";
pub const PRIiFAST8 = "hhi";
pub const PRIiFAST16 = __PRIPTR_PREFIX ++ "i";
pub const PRIiFAST32 = __PRIPTR_PREFIX ++ "i";
pub const PRIiFAST64 = __PRI64_PREFIX ++ "i";
pub const PRIo8 = "hho";
pub const PRIo16 = "ho";
pub const PRIo32 = "o";
pub const PRIo64 = __PRI64_PREFIX ++ "o";
pub const PRIoLEAST8 = "hho";
pub const PRIoLEAST16 = "ho";
pub const PRIoLEAST32 = "o";
pub const PRIoLEAST64 = __PRI64_PREFIX ++ "o";
pub const PRIoFAST8 = "hho";
pub const PRIoFAST16 = __PRIPTR_PREFIX ++ "o";
pub const PRIoFAST32 = __PRIPTR_PREFIX ++ "o";
pub const PRIoFAST64 = __PRI64_PREFIX ++ "o";
pub const PRIu8 = "hhu";
pub const PRIu16 = "hu";
pub const PRIu32 = "u";
pub const PRIu64 = __PRI64_PREFIX ++ "u";
pub const PRIuLEAST8 = "hhu";
pub const PRIuLEAST16 = "hu";
pub const PRIuLEAST32 = "u";
pub const PRIuLEAST64 = __PRI64_PREFIX ++ "u";
pub const PRIuFAST8 = "hhu";
pub const PRIuFAST16 = __PRIPTR_PREFIX ++ "u";
pub const PRIuFAST32 = __PRIPTR_PREFIX ++ "u";
pub const PRIuFAST64 = __PRI64_PREFIX ++ "u";
pub const PRIx8 = "hhx";
pub const PRIx16 = "hx";
pub const PRIx32 = "x";
pub const PRIx64 = __PRI64_PREFIX ++ "x";
pub const PRIxLEAST8 = "hhx";
pub const PRIxLEAST16 = "hx";
pub const PRIxLEAST32 = "x";
pub const PRIxLEAST64 = __PRI64_PREFIX ++ "x";
pub const PRIxFAST8 = "hhx";
pub const PRIxFAST16 = __PRIPTR_PREFIX ++ "x";
pub const PRIxFAST32 = __PRIPTR_PREFIX ++ "x";
pub const PRIxFAST64 = __PRI64_PREFIX ++ "x";
pub const PRIX8 = "hhX";
pub const PRIX16 = "hX";
pub const PRIX32 = "X";
pub const PRIX64 = __PRI64_PREFIX ++ "X";
pub const PRIXLEAST8 = "hhX";
pub const PRIXLEAST16 = "hX";
pub const PRIXLEAST32 = "X";
pub const PRIXLEAST64 = __PRI64_PREFIX ++ "X";
pub const PRIXFAST8 = "hhX";
pub const PRIXFAST16 = __PRIPTR_PREFIX ++ "X";
pub const PRIXFAST32 = __PRIPTR_PREFIX ++ "X";
pub const PRIXFAST64 = __PRI64_PREFIX ++ "X";
pub const PRIdMAX = __PRI64_PREFIX ++ "d";
pub const PRIiMAX = __PRI64_PREFIX ++ "i";
pub const PRIoMAX = __PRI64_PREFIX ++ "o";
pub const PRIuMAX = __PRI64_PREFIX ++ "u";
pub const PRIxMAX = __PRI64_PREFIX ++ "x";
pub const PRIXMAX = __PRI64_PREFIX ++ "X";
pub const PRIdPTR = __PRIPTR_PREFIX ++ "d";
pub const PRIiPTR = __PRIPTR_PREFIX ++ "i";
pub const PRIoPTR = __PRIPTR_PREFIX ++ "o";
pub const PRIuPTR = __PRIPTR_PREFIX ++ "u";
pub const PRIxPTR = __PRIPTR_PREFIX ++ "x";
pub const PRIXPTR = __PRIPTR_PREFIX ++ "X";
pub const SCNd8 = "hhd";
pub const SCNd16 = "hd";
pub const SCNd32 = "d";
pub const SCNd64 = __PRI64_PREFIX ++ "d";
pub const SCNdLEAST8 = "hhd";
pub const SCNdLEAST16 = "hd";
pub const SCNdLEAST32 = "d";
pub const SCNdLEAST64 = __PRI64_PREFIX ++ "d";
pub const SCNdFAST8 = "hhd";
pub const SCNdFAST16 = __PRIPTR_PREFIX ++ "d";
pub const SCNdFAST32 = __PRIPTR_PREFIX ++ "d";
pub const SCNdFAST64 = __PRI64_PREFIX ++ "d";
pub const SCNi8 = "hhi";
pub const SCNi16 = "hi";
pub const SCNi32 = "i";
pub const SCNi64 = __PRI64_PREFIX ++ "i";
pub const SCNiLEAST8 = "hhi";
pub const SCNiLEAST16 = "hi";
pub const SCNiLEAST32 = "i";
pub const SCNiLEAST64 = __PRI64_PREFIX ++ "i";
pub const SCNiFAST8 = "hhi";
pub const SCNiFAST16 = __PRIPTR_PREFIX ++ "i";
pub const SCNiFAST32 = __PRIPTR_PREFIX ++ "i";
pub const SCNiFAST64 = __PRI64_PREFIX ++ "i";
pub const SCNu8 = "hhu";
pub const SCNu16 = "hu";
pub const SCNu32 = "u";
pub const SCNu64 = __PRI64_PREFIX ++ "u";
pub const SCNuLEAST8 = "hhu";
pub const SCNuLEAST16 = "hu";
pub const SCNuLEAST32 = "u";
pub const SCNuLEAST64 = __PRI64_PREFIX ++ "u";
pub const SCNuFAST8 = "hhu";
pub const SCNuFAST16 = __PRIPTR_PREFIX ++ "u";
pub const SCNuFAST32 = __PRIPTR_PREFIX ++ "u";
pub const SCNuFAST64 = __PRI64_PREFIX ++ "u";
pub const SCNo8 = "hho";
pub const SCNo16 = "ho";
pub const SCNo32 = "o";
pub const SCNo64 = __PRI64_PREFIX ++ "o";
pub const SCNoLEAST8 = "hho";
pub const SCNoLEAST16 = "ho";
pub const SCNoLEAST32 = "o";
pub const SCNoLEAST64 = __PRI64_PREFIX ++ "o";
pub const SCNoFAST8 = "hho";
pub const SCNoFAST16 = __PRIPTR_PREFIX ++ "o";
pub const SCNoFAST32 = __PRIPTR_PREFIX ++ "o";
pub const SCNoFAST64 = __PRI64_PREFIX ++ "o";
pub const SCNx8 = "hhx";
pub const SCNx16 = "hx";
pub const SCNx32 = "x";
pub const SCNx64 = __PRI64_PREFIX ++ "x";
pub const SCNxLEAST8 = "hhx";
pub const SCNxLEAST16 = "hx";
pub const SCNxLEAST32 = "x";
pub const SCNxLEAST64 = __PRI64_PREFIX ++ "x";
pub const SCNxFAST8 = "hhx";
pub const SCNxFAST16 = __PRIPTR_PREFIX ++ "x";
pub const SCNxFAST32 = __PRIPTR_PREFIX ++ "x";
pub const SCNxFAST64 = __PRI64_PREFIX ++ "x";
pub const SCNdMAX = __PRI64_PREFIX ++ "d";
pub const SCNiMAX = __PRI64_PREFIX ++ "i";
pub const SCNoMAX = __PRI64_PREFIX ++ "o";
pub const SCNuMAX = __PRI64_PREFIX ++ "u";
pub const SCNxMAX = __PRI64_PREFIX ++ "x";
pub const SCNdPTR = __PRIPTR_PREFIX ++ "d";
pub const SCNiPTR = __PRIPTR_PREFIX ++ "i";
pub const SCNoPTR = __PRIPTR_PREFIX ++ "o";
pub const SCNuPTR = __PRIPTR_PREFIX ++ "u";
pub const SCNxPTR = __PRIPTR_PREFIX ++ "x";
pub const __STDC_VERSION_STDDEF_H__ = @as(c_long, 202311);
pub const NULL = __helpers.cast(?*anyopaque, @as(c_int, 0));
pub const offsetof = @compileError("unable to translate macro: undefined identifier `__builtin_offsetof`"); // /home/addo/.zvm/master/lib/compiler/aro/include/stddef.h:18:9
pub const HB_DEPRECATED = @compileError("unable to translate macro: undefined identifier `__deprecated__`"); // /usr/include/harfbuzz/hb-common.h:71:9
pub const HB_DEPRECATED_FOR = @compileError("unable to translate macro: undefined identifier `__deprecated__`"); // /usr/include/harfbuzz/hb-common.h:79:9
pub const HB_CODEPOINT_INVALID = __helpers.cast(hb_codepoint_t, -@as(c_int, 1));
pub inline fn HB_TAG(c1: anytype, c2: anytype, c3: anytype, c4: anytype) hb_tag_t {
    _ = &c1;
    _ = &c2;
    _ = &c3;
    _ = &c4;
    return __helpers.cast(hb_tag_t, ((((__helpers.cast(u32, c1) & @as(c_int, 0xFF)) << @as(c_int, 24)) | ((__helpers.cast(u32, c2) & @as(c_int, 0xFF)) << @as(c_int, 16))) | ((__helpers.cast(u32, c3) & @as(c_int, 0xFF)) << @as(c_int, 8))) | (__helpers.cast(u32, c4) & @as(c_int, 0xFF)));
}
pub inline fn HB_UNTAG(tag: anytype) u8 {
    _ = &tag;
    return blk: {
        _ = __helpers.cast(u8, (tag >> @as(c_int, 24)) & @as(c_int, 0xFF));
        _ = __helpers.cast(u8, (tag >> @as(c_int, 16)) & @as(c_int, 0xFF));
        _ = __helpers.cast(u8, (tag >> @as(c_int, 8)) & @as(c_int, 0xFF));
        break :blk __helpers.cast(u8, tag & @as(c_int, 0xFF));
    };
}
pub const HB_TAG_NONE = HB_TAG(@as(c_int, 0), @as(c_int, 0), @as(c_int, 0), @as(c_int, 0));
pub const HB_TAG_MAX = HB_TAG(@as(c_int, 0xff), @as(c_int, 0xff), @as(c_int, 0xff), @as(c_int, 0xff));
pub const HB_TAG_MAX_SIGNED = HB_TAG(@as(c_int, 0x7f), @as(c_int, 0xff), @as(c_int, 0xff), @as(c_int, 0xff));
pub inline fn HB_DIRECTION_IS_VALID(dir: anytype) @TypeOf((__helpers.cast(c_uint, dir) & ~@as(c_uint, 3)) == @as(c_int, 4)) {
    _ = &dir;
    return (__helpers.cast(c_uint, dir) & ~@as(c_uint, 3)) == @as(c_int, 4);
}
pub inline fn HB_DIRECTION_IS_HORIZONTAL(dir: anytype) @TypeOf((__helpers.cast(c_uint, dir) & ~@as(c_uint, 1)) == @as(c_int, 4)) {
    _ = &dir;
    return (__helpers.cast(c_uint, dir) & ~@as(c_uint, 1)) == @as(c_int, 4);
}
pub inline fn HB_DIRECTION_IS_VERTICAL(dir: anytype) @TypeOf((__helpers.cast(c_uint, dir) & ~@as(c_uint, 1)) == @as(c_int, 6)) {
    _ = &dir;
    return (__helpers.cast(c_uint, dir) & ~@as(c_uint, 1)) == @as(c_int, 6);
}
pub inline fn HB_DIRECTION_IS_FORWARD(dir: anytype) @TypeOf((__helpers.cast(c_uint, dir) & ~@as(c_uint, 2)) == @as(c_int, 4)) {
    _ = &dir;
    return (__helpers.cast(c_uint, dir) & ~@as(c_uint, 2)) == @as(c_int, 4);
}
pub inline fn HB_DIRECTION_IS_BACKWARD(dir: anytype) @TypeOf((__helpers.cast(c_uint, dir) & ~@as(c_uint, 2)) == @as(c_int, 5)) {
    _ = &dir;
    return (__helpers.cast(c_uint, dir) & ~@as(c_uint, 2)) == @as(c_int, 5);
}
pub inline fn HB_DIRECTION_REVERSE(dir: anytype) hb_direction_t {
    _ = &dir;
    return __helpers.cast(hb_direction_t, __helpers.cast(c_uint, dir) ^ @as(c_int, 1));
}
pub const HB_LANGUAGE_INVALID = __helpers.cast(hb_language_t, @as(c_int, 0));
pub const HB_SCRIPT_LIST_H = "";
pub const HB_FEATURE_GLOBAL_START = @as(c_int, 0);
pub const HB_FEATURE_GLOBAL_END = __helpers.cast(c_uint, -@as(c_int, 1));
pub inline fn HB_COLOR(b: anytype, g: anytype, r: anytype, a: anytype) hb_color_t {
    _ = &b;
    _ = &g;
    _ = &r;
    _ = &a;
    return __helpers.cast(hb_color_t, HB_TAG(b, g, r, a));
}
pub const HB_BUFFER_H = "";
pub const HB_UNICODE_H = "";
pub const HB_UNICODE_MAX = __helpers.promoteIntLiteral(c_uint, 0x10FFFF, .hex);
pub const HB_FONT_H = "";
pub const HB_FACE_H = "";
pub const HB_MAP_H = "";
pub const HB_SET_H = "";
pub const HB_SET_VALUE_INVALID = HB_CODEPOINT_INVALID;
pub const HB_MAP_VALUE_INVALID = HB_CODEPOINT_INVALID;
pub const HB_DRAW_H = "";
pub const HB_DRAW_STATE_DEFAULT = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/harfbuzz/hb-draw.h:73:9
pub const HB_PAINT_H = "";
pub const HB_PAINT_IMAGE_FORMAT_PNG = HB_TAG('p', 'n', 'g', ' ');
pub const HB_PAINT_IMAGE_FORMAT_SVG = HB_TAG('s', 'v', 'g', ' ');
pub const HB_PAINT_IMAGE_FORMAT_BGRA = HB_TAG('B', 'G', 'R', 'A');
pub const HB_FONT_NO_VAR_NAMED_INSTANCE = __helpers.promoteIntLiteral(c_int, 0xFFFFFFFF, .hex);
pub const HB_SEGMENT_PROPERTIES_DEFAULT = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/harfbuzz/hb-buffer.h:225:9
pub const HB_BUFFER_CLUSTER_LEVEL_IS_MONOTONE = @compileError("unable to translate macro: undefined identifier `bool`"); // /usr/include/harfbuzz/hb-buffer.h:478:9
pub const HB_BUFFER_CLUSTER_LEVEL_IS_GRAPHEMES = @compileError("unable to translate macro: undefined identifier `bool`"); // /usr/include/harfbuzz/hb-buffer.h:492:9
pub const HB_BUFFER_CLUSTER_LEVEL_IS_CHARACTERS = @compileError("unable to translate macro: undefined identifier `bool`"); // /usr/include/harfbuzz/hb-buffer.h:506:9
pub const HB_BUFFER_REPLACEMENT_CODEPOINT_DEFAULT = @as(c_uint, 0xFFFD);
pub const HB_DEPRECATED_H = "";
pub const HB_SCRIPT_CANADIAN_ABORIGINAL = HB_SCRIPT_CANADIAN_SYLLABICS;
pub const HB_BUFFER_FLAGS_DEFAULT = HB_BUFFER_FLAG_DEFAULT;
pub const HB_BUFFER_SERIALIZE_FLAGS_DEFAULT = HB_BUFFER_SERIALIZE_FLAG_DEFAULT;
pub const HB_UNICODE_COMBINING_CLASS_CCC133 = @as(c_int, 133);
pub const HB_UNICODE_MAX_DECOMPOSITION_LEN = @as(c_int, 18) + @as(c_int, 1);
pub const HB_AAT_LAYOUT_FEATURE_TYPE_CURISVE_CONNECTION = @compileError("unable to translate macro: undefined identifier `HB_AAT_LAYOUT_FEATURE_TYPE_CURSIVE_CONNECTION`"); // /usr/include/harfbuzz/hb-deprecated.h:389:9
pub const HB_SHAPE_H = "";
pub const HB_SHAPE_PLAN_H = "";
pub const HB_STYLE_H = "";
pub const HB_VERSION_H = "";
pub const HB_VERSION_MAJOR = @as(c_int, 14);
pub const HB_VERSION_MINOR = @as(c_int, 1);
pub const HB_VERSION_MICRO = @as(c_int, 0);
pub const HB_VERSION_STRING = "14.1.0";
pub inline fn HB_VERSION_ATLEAST(major: anytype, minor: anytype, micro: anytype) @TypeOf((((major * @as(c_int, 10000)) + (minor * @as(c_int, 100))) + micro) <= (((HB_VERSION_MAJOR * @as(c_int, 10000)) + (HB_VERSION_MINOR * @as(c_int, 100))) + HB_VERSION_MICRO)) {
    _ = &major;
    _ = &minor;
    _ = &micro;
    return (((major * @as(c_int, 10000)) + (minor * @as(c_int, 100))) + micro) <= (((HB_VERSION_MAJOR * @as(c_int, 10000)) + (HB_VERSION_MINOR * @as(c_int, 100))) + HB_VERSION_MICRO);
}
pub const HB_FT_H = "";
pub const FT2BUILD_H_ = "";
pub const FTHEADER_H_ = "";
pub const FT_BEGIN_HEADER = "";
pub const FT_END_HEADER = "";
pub const FT_CONFIG_CONFIG_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:117:9
pub const FT_CONFIG_STANDARD_LIBRARY_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:132:9
pub const FT_CONFIG_OPTIONS_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:147:9
pub const FT_CONFIG_MODULES_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:163:9
pub const FT_FREETYPE_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:180:9
pub const FT_ERRORS_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:195:9
pub const FT_MODULE_ERRORS_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:208:9
pub const FT_SYSTEM_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:224:9
pub const FT_IMAGE_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:240:9
pub const FT_TYPES_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:255:9
pub const FT_LIST_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:270:9
pub const FT_OUTLINE_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:283:9
pub const FT_SIZES_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:296:9
pub const FT_MODULE_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:309:9
pub const FT_RENDER_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:322:9
pub const FT_DRIVER_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:335:9
pub const FT_AUTOHINTER_H = FT_DRIVER_H;
pub const FT_CFF_DRIVER_H = FT_DRIVER_H;
pub const FT_TRUETYPE_DRIVER_H = FT_DRIVER_H;
pub const FT_PCF_DRIVER_H = FT_DRIVER_H;
pub const FT_TYPE1_TABLES_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:408:9
pub const FT_TRUETYPE_IDS_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:423:9
pub const FT_TRUETYPE_TABLES_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:436:9
pub const FT_TRUETYPE_TAGS_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:450:9
pub const FT_BDF_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:463:9
pub const FT_CID_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:476:9
pub const FT_GZIP_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:489:9
pub const FT_LZW_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:502:9
pub const FT_BZIP2_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:515:9
pub const FT_WINFONTS_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:528:9
pub const FT_GLYPH_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:541:9
pub const FT_BITMAP_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:554:9
pub const FT_BBOX_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:567:9
pub const FT_CACHE_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:580:9
pub const FT_MAC_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:597:9
pub const FT_MULTIPLE_MASTERS_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:610:9
pub const FT_SFNT_NAMES_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:624:9
pub const FT_OPENTYPE_VALIDATE_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:638:9
pub const FT_GX_VALIDATE_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:652:9
pub const FT_PFR_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:665:9
pub const FT_STROKER_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:677:9
pub const FT_SYNTHESIS_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:689:9
pub const FT_FONT_FORMATS_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:701:9
pub const FT_XFREE86_H = FT_FONT_FORMATS_H;
pub const FT_TRIGONOMETRY_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:717:9
pub const FT_LCD_FILTER_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:729:9
pub const FT_INCREMENTAL_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:741:9
pub const FT_GASP_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:753:9
pub const FT_ADVANCES_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:765:9
pub const FT_COLOR_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:777:9
pub const FT_OTSVG_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:789:9
pub const FT_ERROR_DEFINITIONS_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:795:9
pub const FT_PARAMETER_TAGS_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:796:9
pub const FT_UNPATENTED_HINTING_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:799:9
pub const FT_TRUETYPE_UNPATENTED_H = @compileError("unable to translate macro: undefined identifier `freetype`"); // /usr/include/freetype2/freetype/config/ftheader.h:800:9
pub const FT_CACHE_IMAGE_H = FT_CACHE_H;
pub const FT_CACHE_SMALL_BITMAPS_H = FT_CACHE_H;
pub const FT_CACHE_CHARMAP_H = FT_CACHE_H;
pub const FT_CACHE_MANAGER_H = FT_CACHE_H;
pub const FT_CACHE_INTERNAL_MRU_H = FT_CACHE_H;
pub const FT_CACHE_INTERNAL_MANAGER_H = FT_CACHE_H;
pub const FT_CACHE_INTERNAL_CACHE_H = FT_CACHE_H;
pub const FT_CACHE_INTERNAL_GLYPH_H = FT_CACHE_H;
pub const FT_CACHE_INTERNAL_IMAGE_H = FT_CACHE_H;
pub const FT_CACHE_INTERNAL_SBITS_H = FT_CACHE_H;
pub const FREETYPE_H_ = "";
pub const __FTCONFIG_H__MULTILIB = "";
pub const FTCONFIG_H_ = "";
pub const FTOPTION_H_ = "";
pub const FT_CONFIG_OPTION_ENVIRONMENT_PROPERTIES = "";
pub const FT_CONFIG_OPTION_SUBPIXEL_RENDERING = "";
pub const FT_CONFIG_OPTION_INLINE_MULFIX = "";
pub const FT_CONFIG_OPTION_USE_LZW = "";
pub const FT_CONFIG_OPTION_USE_ZLIB = "";
pub const FT_CONFIG_OPTION_SYSTEM_ZLIB = "";
pub const FT_CONFIG_OPTION_USE_BZIP2 = "";
pub const FT_CONFIG_OPTION_USE_PNG = "";
pub const FT_CONFIG_OPTION_USE_HARFBUZZ = "";
pub const FT_CONFIG_OPTION_USE_BROTLI = "";
pub const FT_CONFIG_OPTION_POSTSCRIPT_NAMES = "";
pub const FT_CONFIG_OPTION_ADOBE_GLYPH_LIST = "";
pub const FT_CONFIG_OPTION_MAC_FONTS = "";
pub const FT_CONFIG_OPTION_GUESSING_EMBEDDED_RFORK = "";
pub const FT_CONFIG_OPTION_INCREMENTAL = "";
pub const FT_RENDER_POOL_SIZE = @as(c_long, 16384);
pub const FT_MAX_MODULES = @as(c_int, 32);
pub const FT_CONFIG_OPTION_SVG = "";
pub const TT_CONFIG_OPTION_EMBEDDED_BITMAPS = "";
pub const TT_CONFIG_OPTION_COLOR_LAYERS = "";
pub const TT_CONFIG_OPTION_POSTSCRIPT_NAMES = "";
pub const TT_CONFIG_OPTION_SFNT_NAMES = "";
pub const TT_CONFIG_CMAP_FORMAT_0 = "";
pub const TT_CONFIG_CMAP_FORMAT_2 = "";
pub const TT_CONFIG_CMAP_FORMAT_4 = "";
pub const TT_CONFIG_CMAP_FORMAT_6 = "";
pub const TT_CONFIG_CMAP_FORMAT_8 = "";
pub const TT_CONFIG_CMAP_FORMAT_10 = "";
pub const TT_CONFIG_CMAP_FORMAT_12 = "";
pub const TT_CONFIG_CMAP_FORMAT_13 = "";
pub const TT_CONFIG_CMAP_FORMAT_14 = "";
pub const TT_CONFIG_OPTION_BYTECODE_INTERPRETER = "";
pub const TT_CONFIG_OPTION_SUBPIXEL_HINTING = "";
pub const TT_CONFIG_OPTION_GX_VAR_SUPPORT = "";
pub const TT_CONFIG_OPTION_BDF = "";
pub const TT_CONFIG_OPTION_MAX_RUNNABLE_OPCODES = @as(c_long, 1000000);
pub const T1_MAX_DICT_DEPTH = @as(c_int, 5);
pub const T1_MAX_SUBRS_CALLS = @as(c_int, 16);
pub const T1_MAX_CHARSTRINGS_OPERANDS = @as(c_int, 256);
pub const CFF_CONFIG_OPTION_DARKENING_PARAMETER_X1 = @as(c_int, 500);
pub const CFF_CONFIG_OPTION_DARKENING_PARAMETER_Y1 = @as(c_int, 400);
pub const CFF_CONFIG_OPTION_DARKENING_PARAMETER_X2 = @as(c_int, 1000);
pub const CFF_CONFIG_OPTION_DARKENING_PARAMETER_Y2 = @as(c_int, 275);
pub const CFF_CONFIG_OPTION_DARKENING_PARAMETER_X3 = @as(c_int, 1667);
pub const CFF_CONFIG_OPTION_DARKENING_PARAMETER_Y3 = @as(c_int, 275);
pub const CFF_CONFIG_OPTION_DARKENING_PARAMETER_X4 = @as(c_int, 2333);
pub const CFF_CONFIG_OPTION_DARKENING_PARAMETER_Y4 = @as(c_int, 0);
pub const AF_CONFIG_OPTION_CJK = "";
pub const AF_CONFIG_OPTION_INDIC = "";
pub const TT_USE_BYTECODE_INTERPRETER = "";
pub const TT_SUPPORT_SUBPIXEL_HINTING_MINIMAL = "";
pub const TT_SUPPORT_COLRV1 = "";
pub const FTSTDLIB_H_ = "";
pub const ft_ptrdiff_t = ptrdiff_t;
pub const _LIBC_LIMITS_H_ = @as(c_int, 1);
pub const MB_LEN_MAX = @as(c_int, 16);
pub const _GCC_LIMITS_H_ = "";
pub const __CLANG_LIMITS_H = "";
pub const SCHAR_MAX = __SCHAR_MAX__;
pub const SHRT_MAX = __SHRT_MAX__;
pub const INT_MAX = __INT_MAX__;
pub const LONG_MAX = __LONG_MAX__;
pub const SCHAR_MIN = -__SCHAR_MAX__ - @as(c_int, 1);
pub const SHRT_MIN = -__SHRT_MAX__ - @as(c_int, 1);
pub const INT_MIN = -__INT_MAX__ - @as(c_int, 1);
pub const LONG_MIN = -__LONG_MAX__ - @as(c_long, 1);
pub const UCHAR_MAX = (__SCHAR_MAX__ * @as(c_int, 2)) + @as(c_int, 1);
pub const USHRT_MAX = (__SHRT_MAX__ * @as(c_int, 2)) + @as(c_int, 1);
pub const UINT_MAX = (__INT_MAX__ * @as(c_uint, 2)) + @as(c_uint, 1);
pub const ULONG_MAX = (__LONG_MAX__ * @as(c_ulong, 2)) + @as(c_ulong, 1);
pub const CHAR_BIT = __CHAR_BIT__;
pub const CHAR_MIN = SCHAR_MIN;
pub const CHAR_MAX = __SCHAR_MAX__;
pub const LLONG_MIN = -__LONG_LONG_MAX__ - @as(c_longlong, 1);
pub const LLONG_MAX = __LONG_LONG_MAX__;
pub const ULLONG_MAX = (__LONG_LONG_MAX__ * @as(c_ulonglong, 2)) + @as(c_ulonglong, 1);
pub const _BITS_POSIX1_LIM_H = @as(c_int, 1);
pub const _POSIX_AIO_LISTIO_MAX = @as(c_int, 2);
pub const _POSIX_AIO_MAX = @as(c_int, 1);
pub const _POSIX_ARG_MAX = @as(c_int, 4096);
pub const _POSIX_CHILD_MAX = @as(c_int, 25);
pub const _POSIX_DELAYTIMER_MAX = @as(c_int, 32);
pub const _POSIX_HOST_NAME_MAX = @as(c_int, 255);
pub const _POSIX_LINK_MAX = @as(c_int, 8);
pub const _POSIX_LOGIN_NAME_MAX = @as(c_int, 9);
pub const _POSIX_MAX_CANON = @as(c_int, 255);
pub const _POSIX_MAX_INPUT = @as(c_int, 255);
pub const _POSIX_MQ_OPEN_MAX = @as(c_int, 8);
pub const _POSIX_MQ_PRIO_MAX = @as(c_int, 32);
pub const _POSIX_NAME_MAX = @as(c_int, 14);
pub const _POSIX_NGROUPS_MAX = @as(c_int, 8);
pub const _POSIX_OPEN_MAX = @as(c_int, 20);
pub const _POSIX_PATH_MAX = @as(c_int, 256);
pub const _POSIX_PIPE_BUF = @as(c_int, 512);
pub const _POSIX_RE_DUP_MAX = @as(c_int, 255);
pub const _POSIX_RTSIG_MAX = @as(c_int, 8);
pub const _POSIX_SEM_NSEMS_MAX = @as(c_int, 256);
pub const _POSIX_SEM_VALUE_MAX = @as(c_int, 32767);
pub const _POSIX_SIGQUEUE_MAX = @as(c_int, 32);
pub const _POSIX_SSIZE_MAX = @as(c_int, 32767);
pub const _POSIX_STREAM_MAX = @as(c_int, 8);
pub const _POSIX_SYMLINK_MAX = @as(c_int, 255);
pub const _POSIX_SYMLOOP_MAX = @as(c_int, 8);
pub const _POSIX_TIMER_MAX = @as(c_int, 32);
pub const _POSIX_TTY_NAME_MAX = @as(c_int, 9);
pub const _POSIX_TZNAME_MAX = @as(c_int, 6);
pub const _POSIX_CLOCKRES_MIN = __helpers.promoteIntLiteral(c_int, 20000000, .decimal);
pub const _LINUX_LIMITS_H = "";
pub const NGROUPS_MAX = __helpers.promoteIntLiteral(c_int, 65536, .decimal);
pub const MAX_CANON = @as(c_int, 255);
pub const MAX_INPUT = @as(c_int, 255);
pub const NAME_MAX = @as(c_int, 255);
pub const PATH_MAX = @as(c_int, 4096);
pub const PIPE_BUF = @as(c_int, 4096);
pub const XATTR_NAME_MAX = @as(c_int, 255);
pub const XATTR_SIZE_MAX = __helpers.promoteIntLiteral(c_int, 65536, .decimal);
pub const XATTR_LIST_MAX = __helpers.promoteIntLiteral(c_int, 65536, .decimal);
pub const RTSIG_MAX = @as(c_int, 32);
pub const _POSIX_THREAD_KEYS_MAX = @as(c_int, 128);
pub const PTHREAD_KEYS_MAX = @as(c_int, 1024);
pub const _POSIX_THREAD_DESTRUCTOR_ITERATIONS = @as(c_int, 4);
pub const PTHREAD_DESTRUCTOR_ITERATIONS = _POSIX_THREAD_DESTRUCTOR_ITERATIONS;
pub const _POSIX_THREAD_THREADS_MAX = @as(c_int, 64);
pub const AIO_PRIO_DELTA_MAX = @as(c_int, 20);
pub const PTHREAD_STACK_MIN = @as(c_int, 16384);
pub const DELAYTIMER_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const TTY_NAME_MAX = @as(c_int, 32);
pub const LOGIN_NAME_MAX = @as(c_int, 256);
pub const HOST_NAME_MAX = @as(c_int, 64);
pub const MQ_PRIO_MAX = __helpers.promoteIntLiteral(c_int, 32768, .decimal);
pub const SEM_VALUE_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const SSIZE_MAX = LONG_MAX;
pub const _BITS_POSIX2_LIM_H = @as(c_int, 1);
pub const _POSIX2_BC_BASE_MAX = @as(c_int, 99);
pub const _POSIX2_BC_DIM_MAX = @as(c_int, 2048);
pub const _POSIX2_BC_SCALE_MAX = @as(c_int, 99);
pub const _POSIX2_BC_STRING_MAX = @as(c_int, 1000);
pub const _POSIX2_COLL_WEIGHTS_MAX = @as(c_int, 2);
pub const _POSIX2_EXPR_NEST_MAX = @as(c_int, 32);
pub const _POSIX2_LINE_MAX = @as(c_int, 2048);
pub const _POSIX2_RE_DUP_MAX = @as(c_int, 255);
pub const _POSIX2_CHARCLASS_NAME_MAX = @as(c_int, 14);
pub const BC_BASE_MAX = _POSIX2_BC_BASE_MAX;
pub const BC_DIM_MAX = _POSIX2_BC_DIM_MAX;
pub const BC_SCALE_MAX = _POSIX2_BC_SCALE_MAX;
pub const BC_STRING_MAX = _POSIX2_BC_STRING_MAX;
pub const COLL_WEIGHTS_MAX = @as(c_int, 255);
pub const EXPR_NEST_MAX = _POSIX2_EXPR_NEST_MAX;
pub const LINE_MAX = _POSIX2_LINE_MAX;
pub const CHARCLASS_NAME_MAX = @as(c_int, 2048);
pub const RE_DUP_MAX = @as(c_int, 0x7fff);
pub const FT_CHAR_BIT = CHAR_BIT;
pub const FT_USHORT_MAX = USHRT_MAX;
pub const FT_INT_MAX = INT_MAX;
pub const FT_INT_MIN = INT_MIN;
pub const FT_UINT_MAX = UINT_MAX;
pub const FT_LONG_MIN = LONG_MIN;
pub const FT_LONG_MAX = LONG_MAX;
pub const FT_ULONG_MAX = ULONG_MAX;
pub const FT_LLONG_MAX = LLONG_MAX;
pub const FT_LLONG_MIN = LLONG_MIN;
pub const FT_ULLONG_MAX = ULLONG_MAX;
pub const _STRING_H = @as(c_int, 1);
pub const __need_size_t = "";
pub const __need_NULL = "";
pub const _BITS_TYPES_LOCALE_T_H = @as(c_int, 1);
pub const _BITS_TYPES___LOCALE_T_H = @as(c_int, 1);
pub const _STRINGS_H = @as(c_int, 1);
pub const ft_memchr = memchr;
pub const ft_memcmp = memcmp;
pub const ft_memcpy = memcpy;
pub const ft_memmove = memmove;
pub const ft_memset = memset;
pub const ft_strcat = strcat;
pub const ft_strcmp = strcmp;
pub const ft_strcpy = strcpy;
pub const ft_strlen = strlen;
pub const ft_strncmp = strncmp;
pub const ft_strncpy = strncpy;
pub const ft_strrchr = strrchr;
pub const ft_strstr = strstr;
pub const _STDIO_H = @as(c_int, 1);
pub const __need___va_list = "";
pub const __STDC_VERSION_STDARG_H__ = @as(c_int, 0);
pub const va_start = @compileError("unable to translate macro: undefined identifier `__builtin_va_start`"); // /home/addo/.zvm/master/lib/compiler/aro/include/stdarg.h:12:9
pub const va_end = @compileError("unable to translate macro: undefined identifier `__builtin_va_end`"); // /home/addo/.zvm/master/lib/compiler/aro/include/stdarg.h:14:9
pub const va_arg = @compileError("unable to translate macro: undefined identifier `__builtin_va_arg`"); // /home/addo/.zvm/master/lib/compiler/aro/include/stdarg.h:15:9
pub const __va_copy = @compileError("unable to translate macro: undefined identifier `__builtin_va_copy`"); // /home/addo/.zvm/master/lib/compiler/aro/include/stdarg.h:18:9
pub const va_copy = @compileError("unable to translate macro: undefined identifier `__builtin_va_copy`"); // /home/addo/.zvm/master/lib/compiler/aro/include/stdarg.h:22:9
pub const __GNUC_VA_LIST = @as(c_int, 1);
pub const _____fpos_t_defined = @as(c_int, 1);
pub const ____mbstate_t_defined = @as(c_int, 1);
pub const _____fpos64_t_defined = @as(c_int, 1);
pub const ____FILE_defined = @as(c_int, 1);
pub const __FILE_defined = @as(c_int, 1);
pub const __struct_FILE_defined = @as(c_int, 1);
pub const __getc_unlocked_body = @compileError("TODO postfix inc/dec expr"); // /usr/include/bits/types/struct_FILE.h:113:9
pub const __putc_unlocked_body = @compileError("TODO postfix inc/dec expr"); // /usr/include/bits/types/struct_FILE.h:117:9
pub const _IO_EOF_SEEN = @as(c_int, 0x0010);
pub inline fn __feof_unlocked_body(_fp: anytype) @TypeOf((_fp.*._flags & _IO_EOF_SEEN) != @as(c_int, 0)) {
    _ = &_fp;
    return (_fp.*._flags & _IO_EOF_SEEN) != @as(c_int, 0);
}
pub const _IO_ERR_SEEN = @as(c_int, 0x0020);
pub inline fn __ferror_unlocked_body(_fp: anytype) @TypeOf((_fp.*._flags & _IO_ERR_SEEN) != @as(c_int, 0)) {
    _ = &_fp;
    return (_fp.*._flags & _IO_ERR_SEEN) != @as(c_int, 0);
}
pub const _IO_USER_LOCK = __helpers.promoteIntLiteral(c_int, 0x8000, .hex);
pub const __cookie_io_functions_t_defined = @as(c_int, 1);
pub const _VA_LIST_DEFINED = "";
pub const __off_t_defined = "";
pub const __ssize_t_defined = "";
pub const _IOFBF = @as(c_int, 0);
pub const _IOLBF = @as(c_int, 1);
pub const _IONBF = @as(c_int, 2);
pub const BUFSIZ = @as(c_int, 8192);
pub const EOF = -@as(c_int, 1);
pub const SEEK_SET = @as(c_int, 0);
pub const SEEK_CUR = @as(c_int, 1);
pub const SEEK_END = @as(c_int, 2);
pub const P_tmpdir = "/tmp";
pub const L_tmpnam = @as(c_int, 20);
pub const TMP_MAX = __helpers.promoteIntLiteral(c_int, 238328, .decimal);
pub const _BITS_STDIO_LIM_H = @as(c_int, 1);
pub const FILENAME_MAX = @as(c_int, 4096);
pub const L_ctermid = @as(c_int, 9);
pub const FOPEN_MAX = @as(c_int, 16);
pub const __attr_dealloc_fclose = __attr_dealloc(fclose, @as(c_int, 1));
pub const _BITS_FLOATN_H = "";
pub const __HAVE_FLOAT128 = @as(c_int, 1);
pub const __HAVE_DISTINCT_FLOAT128 = @as(c_int, 1);
pub const __HAVE_FLOAT64X = @as(c_int, 1);
pub const __HAVE_FLOAT64X_LONG_DOUBLE = @as(c_int, 1);
pub const __f128 = @compileError("unable to translate macro: undefined identifier `f128`"); // /usr/include/bits/floatn.h:72:12
pub const __CFLOAT128 = @compileError("unable to translate: invalid numeric type"); // /usr/include/bits/floatn.h:86:12
pub const _BITS_FLOATN_COMMON_H = "";
pub const __HAVE_FLOAT16 = @as(c_int, 0);
pub const __HAVE_FLOAT32 = @as(c_int, 1);
pub const __HAVE_FLOAT64 = @as(c_int, 1);
pub const __HAVE_FLOAT32X = @as(c_int, 1);
pub const __HAVE_FLOAT128X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT16 = __HAVE_FLOAT16;
pub const __HAVE_DISTINCT_FLOAT32 = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT64 = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT32X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT64X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT128X = __HAVE_FLOAT128X;
pub const __HAVE_FLOAT128_UNLIKE_LDBL = (__HAVE_DISTINCT_FLOAT128 != 0) and (__LDBL_MANT_DIG__ != @as(c_int, 113));
pub const __HAVE_FLOATN_NOT_TYPEDEF = @as(c_int, 1);
pub const __f32 = @compileError("unable to translate macro: undefined identifier `f32`"); // /usr/include/bits/floatn-common.h:93:12
pub const __f64 = @compileError("unable to translate macro: undefined identifier `f64`"); // /usr/include/bits/floatn-common.h:105:12
pub const __f32x = @compileError("unable to translate macro: undefined identifier `f32x`"); // /usr/include/bits/floatn-common.h:113:12
pub const __f64x = @compileError("unable to translate macro: undefined identifier `f64x`"); // /usr/include/bits/floatn-common.h:125:12
pub const __CFLOAT32 = @compileError("unable to translate: invalid numeric type"); // /usr/include/bits/floatn-common.h:151:12
pub const __CFLOAT64 = @compileError("unable to translate: invalid numeric type"); // /usr/include/bits/floatn-common.h:163:12
pub const __CFLOAT32X = @compileError("unable to translate: invalid numeric type"); // /usr/include/bits/floatn-common.h:171:12
pub const __CFLOAT64X = @compileError("unable to translate: invalid numeric type"); // /usr/include/bits/floatn-common.h:183:12
pub const FT_FILE = FILE;
pub const ft_fclose = fclose;
pub const ft_fopen = fopen;
pub const ft_fread = fread;
pub const ft_fseek = fseek;
pub const ft_ftell = ftell;
pub const ft_snprintf = snprintf;
pub const __GLIBC_USE_LIB_EXT2 = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_BFP_EXT = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_BFP_EXT_C23 = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_EXT = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_FUNCS_EXT = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_FUNCS_EXT_C23 = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_TYPES_EXT = @as(c_int, 0);
pub const __need_wchar_t = "";
pub const _STDLIB_H = @as(c_int, 1);
pub const WNOHANG = @as(c_int, 1);
pub const WUNTRACED = @as(c_int, 2);
pub const WSTOPPED = @as(c_int, 2);
pub const WEXITED = @as(c_int, 4);
pub const WCONTINUED = @as(c_int, 8);
pub const WNOWAIT = __helpers.promoteIntLiteral(c_int, 0x01000000, .hex);
pub const __WNOTHREAD = __helpers.promoteIntLiteral(c_int, 0x20000000, .hex);
pub const __WALL = __helpers.promoteIntLiteral(c_int, 0x40000000, .hex);
pub const __WCLONE = __helpers.promoteIntLiteral(c_int, 0x80000000, .hex);
pub inline fn __WEXITSTATUS(status: anytype) @TypeOf((status & __helpers.promoteIntLiteral(c_int, 0xff00, .hex)) >> @as(c_int, 8)) {
    _ = &status;
    return (status & __helpers.promoteIntLiteral(c_int, 0xff00, .hex)) >> @as(c_int, 8);
}
pub inline fn __WTERMSIG(status: anytype) @TypeOf(status & @as(c_int, 0x7f)) {
    _ = &status;
    return status & @as(c_int, 0x7f);
}
pub inline fn __WSTOPSIG(status: anytype) @TypeOf(__WEXITSTATUS(status)) {
    _ = &status;
    return __WEXITSTATUS(status);
}
pub inline fn __WIFEXITED(status: anytype) @TypeOf(__WTERMSIG(status) == @as(c_int, 0)) {
    _ = &status;
    return __WTERMSIG(status) == @as(c_int, 0);
}
pub inline fn __WIFSIGNALED(status: anytype) @TypeOf((__helpers.cast(i8, (status & @as(c_int, 0x7f)) + @as(c_int, 1)) >> @as(c_int, 1)) > @as(c_int, 0)) {
    _ = &status;
    return (__helpers.cast(i8, (status & @as(c_int, 0x7f)) + @as(c_int, 1)) >> @as(c_int, 1)) > @as(c_int, 0);
}
pub inline fn __WIFSTOPPED(status: anytype) @TypeOf((status & @as(c_int, 0xff)) == @as(c_int, 0x7f)) {
    _ = &status;
    return (status & @as(c_int, 0xff)) == @as(c_int, 0x7f);
}
pub inline fn __WIFCONTINUED(status: anytype) @TypeOf(status == __W_CONTINUED) {
    _ = &status;
    return status == __W_CONTINUED;
}
pub inline fn __WCOREDUMP(status: anytype) @TypeOf(status & __WCOREFLAG) {
    _ = &status;
    return status & __WCOREFLAG;
}
pub inline fn __W_EXITCODE(ret: anytype, sig: anytype) @TypeOf((ret << @as(c_int, 8)) | sig) {
    _ = &ret;
    _ = &sig;
    return (ret << @as(c_int, 8)) | sig;
}
pub inline fn __W_STOPCODE(sig: anytype) @TypeOf((sig << @as(c_int, 8)) | @as(c_int, 0x7f)) {
    _ = &sig;
    return (sig << @as(c_int, 8)) | @as(c_int, 0x7f);
}
pub const __W_CONTINUED = __helpers.promoteIntLiteral(c_int, 0xffff, .hex);
pub const __WCOREFLAG = @as(c_int, 0x80);
pub inline fn WEXITSTATUS(status: anytype) @TypeOf(__WEXITSTATUS(status)) {
    _ = &status;
    return __WEXITSTATUS(status);
}
pub inline fn WTERMSIG(status: anytype) @TypeOf(__WTERMSIG(status)) {
    _ = &status;
    return __WTERMSIG(status);
}
pub inline fn WSTOPSIG(status: anytype) @TypeOf(__WSTOPSIG(status)) {
    _ = &status;
    return __WSTOPSIG(status);
}
pub inline fn WIFEXITED(status: anytype) @TypeOf(__WIFEXITED(status)) {
    _ = &status;
    return __WIFEXITED(status);
}
pub inline fn WIFSIGNALED(status: anytype) @TypeOf(__WIFSIGNALED(status)) {
    _ = &status;
    return __WIFSIGNALED(status);
}
pub inline fn WIFSTOPPED(status: anytype) @TypeOf(__WIFSTOPPED(status)) {
    _ = &status;
    return __WIFSTOPPED(status);
}
pub inline fn WIFCONTINUED(status: anytype) @TypeOf(__WIFCONTINUED(status)) {
    _ = &status;
    return __WIFCONTINUED(status);
}
pub const __ldiv_t_defined = @as(c_int, 1);
pub const __lldiv_t_defined = @as(c_int, 1);
pub const RAND_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const EXIT_FAILURE = @as(c_int, 1);
pub const EXIT_SUCCESS = @as(c_int, 0);
pub const MB_CUR_MAX = __ctype_get_mb_cur_max();
pub const _SYS_TYPES_H = @as(c_int, 1);
pub const __u_char_defined = "";
pub const __ino_t_defined = "";
pub const __dev_t_defined = "";
pub const __gid_t_defined = "";
pub const __mode_t_defined = "";
pub const __nlink_t_defined = "";
pub const __uid_t_defined = "";
pub const __pid_t_defined = "";
pub const __id_t_defined = "";
pub const __daddr_t_defined = "";
pub const __key_t_defined = "";
pub const __clock_t_defined = @as(c_int, 1);
pub const __clockid_t_defined = @as(c_int, 1);
pub const __time_t_defined = @as(c_int, 1);
pub const __timer_t_defined = @as(c_int, 1);
pub const __BIT_TYPES_DEFINED__ = @as(c_int, 1);
pub const _ENDIAN_H = @as(c_int, 1);
pub const _BITS_ENDIAN_H = @as(c_int, 1);
pub const __LITTLE_ENDIAN = @as(c_int, 1234);
pub const __BIG_ENDIAN = @as(c_int, 4321);
pub const __PDP_ENDIAN = @as(c_int, 3412);
pub const _BITS_ENDIANNESS_H = @as(c_int, 1);
pub const __BYTE_ORDER = __LITTLE_ENDIAN;
pub const __FLOAT_WORD_ORDER = __BYTE_ORDER;
pub inline fn __LONG_LONG_PAIR(HI: anytype, LO: anytype) @TypeOf(HI) {
    _ = &HI;
    _ = &LO;
    return blk: {
        _ = &LO;
        break :blk HI;
    };
}
pub const LITTLE_ENDIAN = __LITTLE_ENDIAN;
pub const BIG_ENDIAN = __BIG_ENDIAN;
pub const PDP_ENDIAN = __PDP_ENDIAN;
pub const BYTE_ORDER = __BYTE_ORDER;
pub const _BITS_BYTESWAP_H = @as(c_int, 1);
pub inline fn __bswap_constant_16(x: anytype) __uint16_t {
    _ = &x;
    return __helpers.cast(__uint16_t, ((x >> @as(c_int, 8)) & @as(c_int, 0xff)) | ((x & @as(c_int, 0xff)) << @as(c_int, 8)));
}
pub inline fn __bswap_constant_32(x: anytype) @TypeOf(((((x & __helpers.promoteIntLiteral(c_uint, 0xff000000, .hex)) >> @as(c_int, 24)) | ((x & __helpers.promoteIntLiteral(c_uint, 0x00ff0000, .hex)) >> @as(c_int, 8))) | ((x & @as(c_uint, 0x0000ff00)) << @as(c_int, 8))) | ((x & @as(c_uint, 0x000000ff)) << @as(c_int, 24))) {
    _ = &x;
    return ((((x & __helpers.promoteIntLiteral(c_uint, 0xff000000, .hex)) >> @as(c_int, 24)) | ((x & __helpers.promoteIntLiteral(c_uint, 0x00ff0000, .hex)) >> @as(c_int, 8))) | ((x & @as(c_uint, 0x0000ff00)) << @as(c_int, 8))) | ((x & @as(c_uint, 0x000000ff)) << @as(c_int, 24));
}
pub inline fn __bswap_constant_64(x: anytype) @TypeOf(((((((((x & @as(c_ulonglong, 0xff00000000000000)) >> @as(c_int, 56)) | ((x & @as(c_ulonglong, 0x00ff000000000000)) >> @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x0000ff0000000000)) >> @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000ff00000000)) >> @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x00000000ff000000)) << @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x0000000000ff0000)) << @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000000000ff00)) << @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x00000000000000ff)) << @as(c_int, 56))) {
    _ = &x;
    return ((((((((x & @as(c_ulonglong, 0xff00000000000000)) >> @as(c_int, 56)) | ((x & @as(c_ulonglong, 0x00ff000000000000)) >> @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x0000ff0000000000)) >> @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000ff00000000)) >> @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x00000000ff000000)) << @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x0000000000ff0000)) << @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000000000ff00)) << @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x00000000000000ff)) << @as(c_int, 56));
}
pub const _BITS_UINTN_IDENTITY_H = @as(c_int, 1);
pub inline fn htobe16(x: anytype) @TypeOf(__bswap_16(x)) {
    _ = &x;
    return __bswap_16(x);
}
pub inline fn htole16(x: anytype) @TypeOf(__uint16_identity(x)) {
    _ = &x;
    return __uint16_identity(x);
}
pub inline fn be16toh(x: anytype) @TypeOf(__bswap_16(x)) {
    _ = &x;
    return __bswap_16(x);
}
pub inline fn le16toh(x: anytype) @TypeOf(__uint16_identity(x)) {
    _ = &x;
    return __uint16_identity(x);
}
pub inline fn htobe32(x: anytype) @TypeOf(__bswap_32(x)) {
    _ = &x;
    return __bswap_32(x);
}
pub inline fn htole32(x: anytype) @TypeOf(__uint32_identity(x)) {
    _ = &x;
    return __uint32_identity(x);
}
pub inline fn be32toh(x: anytype) @TypeOf(__bswap_32(x)) {
    _ = &x;
    return __bswap_32(x);
}
pub inline fn le32toh(x: anytype) @TypeOf(__uint32_identity(x)) {
    _ = &x;
    return __uint32_identity(x);
}
pub inline fn htobe64(x: anytype) @TypeOf(__bswap_64(x)) {
    _ = &x;
    return __bswap_64(x);
}
pub inline fn htole64(x: anytype) @TypeOf(__uint64_identity(x)) {
    _ = &x;
    return __uint64_identity(x);
}
pub inline fn be64toh(x: anytype) @TypeOf(__bswap_64(x)) {
    _ = &x;
    return __bswap_64(x);
}
pub inline fn le64toh(x: anytype) @TypeOf(__uint64_identity(x)) {
    _ = &x;
    return __uint64_identity(x);
}
pub const _SYS_SELECT_H = @as(c_int, 1);
pub const __FD_ZERO = @compileError("unable to translate macro: undefined identifier `__i`"); // /usr/include/bits/select.h:25:9
pub const __FD_SET = @compileError("unable to translate C expr: expected ')' instead got '|='"); // /usr/include/bits/select.h:32:9
pub const __FD_CLR = @compileError("unable to translate C expr: expected ')' instead got '&='"); // /usr/include/bits/select.h:34:9
pub inline fn __FD_ISSET(d: anytype, s: anytype) @TypeOf((__FDS_BITS(s)[@as(usize, @intCast(__FD_ELT(d)))] & __FD_MASK(d)) != @as(c_int, 0)) {
    _ = &d;
    _ = &s;
    return (__FDS_BITS(s)[@as(usize, @intCast(__FD_ELT(d)))] & __FD_MASK(d)) != @as(c_int, 0);
}
pub const __sigset_t_defined = @as(c_int, 1);
pub const ____sigset_t_defined = "";
pub const _SIGSET_NWORDS = __helpers.div(@as(c_int, 1024), @as(c_int, 8) * __helpers.sizeof(c_ulong));
pub const __timeval_defined = @as(c_int, 1);
pub const _STRUCT_TIMESPEC = @as(c_int, 1);
pub const __suseconds_t_defined = "";
pub const __NFDBITS = @as(c_int, 8) * __helpers.cast(c_int, __helpers.sizeof(__fd_mask));
pub inline fn __FD_ELT(d: anytype) @TypeOf(__helpers.div(d, __NFDBITS)) {
    _ = &d;
    return __helpers.div(d, __NFDBITS);
}
pub inline fn __FD_MASK(d: anytype) __fd_mask {
    _ = &d;
    return __helpers.cast(__fd_mask, @as(c_ulong, 1) << __helpers.rem(d, __NFDBITS));
}
pub inline fn __FDS_BITS(set: anytype) @TypeOf(set.*.__fds_bits) {
    _ = &set;
    return set.*.__fds_bits;
}
pub const FD_SETSIZE = __FD_SETSIZE;
pub const NFDBITS = __NFDBITS;
pub inline fn FD_SET(fd: anytype, fdsetp: anytype) @TypeOf(__FD_SET(fd, fdsetp)) {
    _ = &fd;
    _ = &fdsetp;
    return __FD_SET(fd, fdsetp);
}
pub inline fn FD_CLR(fd: anytype, fdsetp: anytype) @TypeOf(__FD_CLR(fd, fdsetp)) {
    _ = &fd;
    _ = &fdsetp;
    return __FD_CLR(fd, fdsetp);
}
pub inline fn FD_ISSET(fd: anytype, fdsetp: anytype) @TypeOf(__FD_ISSET(fd, fdsetp)) {
    _ = &fd;
    _ = &fdsetp;
    return __FD_ISSET(fd, fdsetp);
}
pub inline fn FD_ZERO(fdsetp: anytype) @TypeOf(__FD_ZERO(fdsetp)) {
    _ = &fdsetp;
    return __FD_ZERO(fdsetp);
}
pub const __blksize_t_defined = "";
pub const __blkcnt_t_defined = "";
pub const __fsblkcnt_t_defined = "";
pub const __fsfilcnt_t_defined = "";
pub const _BITS_PTHREADTYPES_COMMON_H = @as(c_int, 1);
pub const _THREAD_SHARED_TYPES_H = @as(c_int, 1);
pub const _BITS_PTHREADTYPES_ARCH_H = @as(c_int, 1);
pub const __SIZEOF_PTHREAD_MUTEX_T = @as(c_int, 40);
pub const __SIZEOF_PTHREAD_ATTR_T = @as(c_int, 56);
pub const __SIZEOF_PTHREAD_RWLOCK_T = @as(c_int, 56);
pub const __SIZEOF_PTHREAD_BARRIER_T = @as(c_int, 32);
pub const __SIZEOF_PTHREAD_MUTEXATTR_T = @as(c_int, 4);
pub const __SIZEOF_PTHREAD_COND_T = @as(c_int, 48);
pub const __SIZEOF_PTHREAD_CONDATTR_T = @as(c_int, 4);
pub const __SIZEOF_PTHREAD_RWLOCKATTR_T = @as(c_int, 8);
pub const __SIZEOF_PTHREAD_BARRIERATTR_T = @as(c_int, 4);
pub const __LOCK_ALIGNMENT = "";
pub const __ONCE_ALIGNMENT = "";
pub const _BITS_ATOMIC_WIDE_COUNTER_H = "";
pub const _THREAD_MUTEX_INTERNAL_H = @as(c_int, 1);
pub const __PTHREAD_MUTEX_HAVE_PREV = @as(c_int, 1);
pub const __PTHREAD_MUTEX_INITIALIZER = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/bits/struct_mutex.h:55:10
pub const _RWLOCK_INTERNAL_H = "";
pub inline fn __PTHREAD_RWLOCK_INITIALIZER(__flags: anytype) @TypeOf(__flags) {
    _ = &__flags;
    return blk: {
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        break :blk __flags;
    };
}
pub const __ONCE_FLAG_INIT = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/bits/thread-shared-types.h:114:9
pub const __have_pthread_attr_t = @as(c_int, 1);
pub const _ALLOCA_H = @as(c_int, 1);
pub const __COMPAR_FN_T = "";
pub const ft_qsort = qsort;
pub const ft_scalloc = calloc;
pub const ft_sfree = free;
pub const ft_smalloc = malloc;
pub const ft_srealloc = realloc;
pub const ft_strtol = strtol;
pub const ft_getenv = getenv;
pub const _SETJMP_H = @as(c_int, 1);
pub const _BITS_SETJMP_H = @as(c_int, 1);
pub const __jmp_buf_tag_defined = @as(c_int, 1);
pub inline fn sigsetjmp(env: anytype, savemask: anytype) @TypeOf(__sigsetjmp(env, savemask)) {
    _ = &env;
    _ = &savemask;
    return __sigsetjmp(env, savemask);
}
pub const ft_jmp_buf = jmp_buf;
pub const ft_longjmp = longjmp;
pub inline fn ft_setjmp(b: anytype) @TypeOf(setjmp([*c]ft_jmp_buf.* & b)) {
    _ = &b;
    return setjmp([*c]ft_jmp_buf.* & b);
}
pub const HAVE_UNISTD_H = @as(c_int, 1);
pub const HAVE_FCNTL_H = @as(c_int, 1);
pub const FREETYPE_CONFIG_INTEGER_TYPES_H_ = "";
pub const FT_SIZEOF_INT = __helpers.div(@as(c_int, 32), FT_CHAR_BIT);
pub const FT_SIZEOF_LONG = __helpers.div(@as(c_int, 64), FT_CHAR_BIT);
pub const FT_SIZEOF_LONG_LONG = __helpers.div(@as(c_int, 64), FT_CHAR_BIT);
pub const FT_INT64 = c_long;
pub const FT_UINT64 = c_ulong;
pub const FT_INT64_ZERO = @as(c_int, 0);
pub const FREETYPE_CONFIG_PUBLIC_MACROS_H_ = "";
pub const FT_PUBLIC_FUNCTION_ATTRIBUTE = @compileError("unable to translate macro: undefined identifier `visibility`"); // /usr/include/freetype2/freetype/config/public-macros.h:76:9
pub const FT_EXPORT = @compileError("unable to translate C expr: unexpected token 'extern'"); // /usr/include/freetype2/freetype/config/public-macros.h:104:9
pub const FT_UNUSED = @compileError("unable to translate C expr: expected ')' instead got '='"); // /usr/include/freetype2/freetype/config/public-macros.h:115:9
pub const FT_STATIC_CAST = __helpers.CAST_OR_CALL;
pub const FT_REINTERPRET_CAST = __helpers.CAST_OR_CALL;
pub inline fn FT_STATIC_BYTE_CAST(@"type": anytype, @"var": anytype) @TypeOf(@"type"(u8)(@"var")) {
    _ = &@"type";
    _ = &@"var";
    return @"type"(u8)(@"var");
}
pub const FREETYPE_CONFIG_MAC_SUPPORT_H_ = "";
pub const FTTYPES_H_ = "";
pub const FTSYSTEM_H_ = "";
pub const FTIMAGE_H_ = "";
pub const ft_pixel_mode_none = FT_PIXEL_MODE_NONE;
pub const ft_pixel_mode_mono = FT_PIXEL_MODE_MONO;
pub const ft_pixel_mode_grays = FT_PIXEL_MODE_GRAY;
pub const ft_pixel_mode_pal2 = FT_PIXEL_MODE_GRAY2;
pub const ft_pixel_mode_pal4 = FT_PIXEL_MODE_GRAY4;
pub const FT_OUTLINE_CONTOURS_MAX = USHRT_MAX;
pub const FT_OUTLINE_POINTS_MAX = USHRT_MAX;
pub const FT_OUTLINE_NONE = @as(c_int, 0x0);
pub const FT_OUTLINE_OWNER = @as(c_int, 0x1);
pub const FT_OUTLINE_EVEN_ODD_FILL = @as(c_int, 0x2);
pub const FT_OUTLINE_REVERSE_FILL = @as(c_int, 0x4);
pub const FT_OUTLINE_IGNORE_DROPOUTS = @as(c_int, 0x8);
pub const FT_OUTLINE_SMART_DROPOUTS = @as(c_int, 0x10);
pub const FT_OUTLINE_INCLUDE_STUBS = @as(c_int, 0x20);
pub const FT_OUTLINE_OVERLAP = @as(c_int, 0x40);
pub const FT_OUTLINE_HIGH_PRECISION = @as(c_int, 0x100);
pub const FT_OUTLINE_SINGLE_PASS = @as(c_int, 0x200);
pub const ft_outline_none = FT_OUTLINE_NONE;
pub const ft_outline_owner = FT_OUTLINE_OWNER;
pub const ft_outline_even_odd_fill = FT_OUTLINE_EVEN_ODD_FILL;
pub const ft_outline_reverse_fill = FT_OUTLINE_REVERSE_FILL;
pub const ft_outline_ignore_dropouts = FT_OUTLINE_IGNORE_DROPOUTS;
pub const ft_outline_high_precision = FT_OUTLINE_HIGH_PRECISION;
pub const ft_outline_single_pass = FT_OUTLINE_SINGLE_PASS;
pub inline fn FT_CURVE_TAG(flag: anytype) @TypeOf(flag & @as(c_int, 0x03)) {
    _ = &flag;
    return flag & @as(c_int, 0x03);
}
pub const FT_CURVE_TAG_ON = @as(c_int, 0x01);
pub const FT_CURVE_TAG_CONIC = @as(c_int, 0x00);
pub const FT_CURVE_TAG_CUBIC = @as(c_int, 0x02);
pub const FT_CURVE_TAG_HAS_SCANMODE = @as(c_int, 0x04);
pub const FT_CURVE_TAG_TOUCH_X = @as(c_int, 0x08);
pub const FT_CURVE_TAG_TOUCH_Y = @as(c_int, 0x10);
pub const FT_CURVE_TAG_TOUCH_BOTH = FT_CURVE_TAG_TOUCH_X | FT_CURVE_TAG_TOUCH_Y;
pub const FT_Curve_Tag_On = FT_CURVE_TAG_ON;
pub const FT_Curve_Tag_Conic = FT_CURVE_TAG_CONIC;
pub const FT_Curve_Tag_Cubic = FT_CURVE_TAG_CUBIC;
pub const FT_Curve_Tag_Touch_X = FT_CURVE_TAG_TOUCH_X;
pub const FT_Curve_Tag_Touch_Y = FT_CURVE_TAG_TOUCH_Y;
pub const FT_Outline_MoveTo_Func = FT_Outline_MoveToFunc;
pub const FT_Outline_LineTo_Func = FT_Outline_LineToFunc;
pub const FT_Outline_ConicTo_Func = FT_Outline_ConicToFunc;
pub const FT_Outline_CubicTo_Func = FT_Outline_CubicToFunc;
pub const FT_IMAGE_TAG = @compileError("unable to translate C expr: unexpected token '='"); // /usr/include/freetype2/freetype/ftimage.h:714:9
pub const ft_glyph_format_none = FT_GLYPH_FORMAT_NONE;
pub const ft_glyph_format_composite = FT_GLYPH_FORMAT_COMPOSITE;
pub const ft_glyph_format_bitmap = FT_GLYPH_FORMAT_BITMAP;
pub const ft_glyph_format_outline = FT_GLYPH_FORMAT_OUTLINE;
pub const ft_glyph_format_plotter = FT_GLYPH_FORMAT_PLOTTER;
pub const FT_Raster_Span_Func = FT_SpanFunc;
pub const FT_RASTER_FLAG_DEFAULT = @as(c_int, 0x0);
pub const FT_RASTER_FLAG_AA = @as(c_int, 0x1);
pub const FT_RASTER_FLAG_DIRECT = @as(c_int, 0x2);
pub const FT_RASTER_FLAG_CLIP = @as(c_int, 0x4);
pub const FT_RASTER_FLAG_SDF = @as(c_int, 0x8);
pub const ft_raster_flag_default = FT_RASTER_FLAG_DEFAULT;
pub const ft_raster_flag_aa = FT_RASTER_FLAG_AA;
pub const ft_raster_flag_direct = FT_RASTER_FLAG_DIRECT;
pub const ft_raster_flag_clip = FT_RASTER_FLAG_CLIP;
pub const FT_Raster_New_Func = FT_Raster_NewFunc;
pub const FT_Raster_Done_Func = FT_Raster_DoneFunc;
pub const FT_Raster_Reset_Func = FT_Raster_ResetFunc;
pub const FT_Raster_Set_Mode_Func = FT_Raster_SetModeFunc;
pub const FT_Raster_Render_Func = FT_Raster_RenderFunc;
pub inline fn FT_MAKE_TAG(_x1: anytype, _x2: anytype, _x3: anytype, _x4: anytype) @TypeOf((((FT_STATIC_BYTE_CAST(FT_Tag, _x1) << @as(c_int, 24)) | (FT_STATIC_BYTE_CAST(FT_Tag, _x2) << @as(c_int, 16))) | (FT_STATIC_BYTE_CAST(FT_Tag, _x3) << @as(c_int, 8))) | FT_STATIC_BYTE_CAST(FT_Tag, _x4)) {
    _ = &_x1;
    _ = &_x2;
    _ = &_x3;
    _ = &_x4;
    return (((FT_STATIC_BYTE_CAST(FT_Tag, _x1) << @as(c_int, 24)) | (FT_STATIC_BYTE_CAST(FT_Tag, _x2) << @as(c_int, 16))) | (FT_STATIC_BYTE_CAST(FT_Tag, _x3) << @as(c_int, 8))) | FT_STATIC_BYTE_CAST(FT_Tag, _x4);
}
pub inline fn FT_IS_EMPTY(list: anytype) @TypeOf(list.head == @as(c_int, 0)) {
    _ = &list;
    return list.head == @as(c_int, 0);
}
pub inline fn FT_BOOL(x: anytype) @TypeOf(FT_STATIC_CAST(FT_Bool, x != @as(c_int, 0))) {
    _ = &x;
    return FT_STATIC_CAST(FT_Bool, x != @as(c_int, 0));
}
pub const FT_ERR_XCAT = @compileError("unable to translate C expr: unexpected token '##'"); // /usr/include/freetype2/freetype/fttypes.h:596:9
pub inline fn FT_ERR_CAT(x: anytype, y: anytype) @TypeOf(FT_ERR_XCAT(x, y)) {
    _ = &x;
    _ = &y;
    return FT_ERR_XCAT(x, y);
}
pub const FT_ERR = @compileError("unable to translate macro: undefined identifier `FT_ERR_PREFIX`"); // /usr/include/freetype2/freetype/fttypes.h:601:9
pub inline fn FT_ERROR_BASE(x: anytype) @TypeOf(x & @as(c_int, 0xFF)) {
    _ = &x;
    return x & @as(c_int, 0xFF);
}
pub inline fn FT_ERROR_MODULE(x: anytype) @TypeOf(x & @as(c_uint, 0xFF00)) {
    _ = &x;
    return x & @as(c_uint, 0xFF00);
}
pub inline fn FT_ERR_EQ(x: anytype, e: anytype) @TypeOf(FT_ERROR_BASE(x) == FT_ERROR_BASE(FT_ERR(e))) {
    _ = &x;
    _ = &e;
    return FT_ERROR_BASE(x) == FT_ERROR_BASE(FT_ERR(e));
}
pub inline fn FT_ERR_NEQ(x: anytype, e: anytype) @TypeOf(FT_ERROR_BASE(x) != FT_ERROR_BASE(FT_ERR(e))) {
    _ = &x;
    _ = &e;
    return FT_ERROR_BASE(x) != FT_ERROR_BASE(FT_ERR(e));
}
pub const FTERRORS_H_ = "";
pub const __FTERRORS_H__ = "";
pub const FTMODERR_H_ = "";
pub const FT_ERR_PROTOS_DEFINED = "";
pub const FT_ENC_TAG = @compileError("unable to translate C expr: unexpected token '='"); // /usr/include/freetype2/freetype/freetype.h:772:9
pub const ft_encoding_none = FT_ENCODING_NONE;
pub const ft_encoding_unicode = FT_ENCODING_UNICODE;
pub const ft_encoding_symbol = FT_ENCODING_MS_SYMBOL;
pub const ft_encoding_latin_1 = FT_ENCODING_ADOBE_LATIN_1;
pub const ft_encoding_latin_2 = FT_ENCODING_OLD_LATIN_2;
pub const ft_encoding_sjis = FT_ENCODING_SJIS;
pub const ft_encoding_gb2312 = FT_ENCODING_PRC;
pub const ft_encoding_big5 = FT_ENCODING_BIG5;
pub const ft_encoding_wansung = FT_ENCODING_WANSUNG;
pub const ft_encoding_johab = FT_ENCODING_JOHAB;
pub const ft_encoding_adobe_standard = FT_ENCODING_ADOBE_STANDARD;
pub const ft_encoding_adobe_expert = FT_ENCODING_ADOBE_EXPERT;
pub const ft_encoding_adobe_custom = FT_ENCODING_ADOBE_CUSTOM;
pub const ft_encoding_apple_roman = FT_ENCODING_APPLE_ROMAN;
pub const FT_FACE_FLAG_SCALABLE = @as(c_long, 1) << @as(c_int, 0);
pub const FT_FACE_FLAG_FIXED_SIZES = @as(c_long, 1) << @as(c_int, 1);
pub const FT_FACE_FLAG_FIXED_WIDTH = @as(c_long, 1) << @as(c_int, 2);
pub const FT_FACE_FLAG_SFNT = @as(c_long, 1) << @as(c_int, 3);
pub const FT_FACE_FLAG_HORIZONTAL = @as(c_long, 1) << @as(c_int, 4);
pub const FT_FACE_FLAG_VERTICAL = @as(c_long, 1) << @as(c_int, 5);
pub const FT_FACE_FLAG_KERNING = @as(c_long, 1) << @as(c_int, 6);
pub const FT_FACE_FLAG_FAST_GLYPHS = @as(c_long, 1) << @as(c_int, 7);
pub const FT_FACE_FLAG_MULTIPLE_MASTERS = @as(c_long, 1) << @as(c_int, 8);
pub const FT_FACE_FLAG_GLYPH_NAMES = @as(c_long, 1) << @as(c_int, 9);
pub const FT_FACE_FLAG_EXTERNAL_STREAM = @as(c_long, 1) << @as(c_int, 10);
pub const FT_FACE_FLAG_HINTER = @as(c_long, 1) << @as(c_int, 11);
pub const FT_FACE_FLAG_CID_KEYED = @as(c_long, 1) << @as(c_int, 12);
pub const FT_FACE_FLAG_TRICKY = @as(c_long, 1) << @as(c_int, 13);
pub const FT_FACE_FLAG_COLOR = @as(c_long, 1) << @as(c_int, 14);
pub const FT_FACE_FLAG_VARIATION = @as(c_long, 1) << @as(c_int, 15);
pub const FT_FACE_FLAG_SVG = @as(c_long, 1) << @as(c_int, 16);
pub const FT_FACE_FLAG_SBIX = @as(c_long, 1) << @as(c_int, 17);
pub const FT_FACE_FLAG_SBIX_OVERLAY = @as(c_long, 1) << @as(c_int, 18);
pub inline fn FT_HAS_HORIZONTAL(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_HORIZONTAL) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_HORIZONTAL) != 0);
}
pub inline fn FT_HAS_VERTICAL(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_VERTICAL) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_VERTICAL) != 0);
}
pub inline fn FT_HAS_KERNING(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_KERNING) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_KERNING) != 0);
}
pub inline fn FT_IS_SCALABLE(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_SCALABLE) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_SCALABLE) != 0);
}
pub inline fn FT_IS_SFNT(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_SFNT) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_SFNT) != 0);
}
pub inline fn FT_IS_FIXED_WIDTH(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_FIXED_WIDTH) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_FIXED_WIDTH) != 0);
}
pub inline fn FT_HAS_FIXED_SIZES(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_FIXED_SIZES) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_FIXED_SIZES) != 0);
}
pub inline fn FT_HAS_FAST_GLYPHS(face: anytype) @TypeOf(@as(c_int, 0)) {
    _ = &face;
    return @as(c_int, 0);
}
pub inline fn FT_HAS_GLYPH_NAMES(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_GLYPH_NAMES) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_GLYPH_NAMES) != 0);
}
pub inline fn FT_HAS_MULTIPLE_MASTERS(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_MULTIPLE_MASTERS) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_MULTIPLE_MASTERS) != 0);
}
pub inline fn FT_IS_NAMED_INSTANCE(face: anytype) @TypeOf(!!((face.*.face_index & @as(c_long, 0x7FFF0000)) != 0)) {
    _ = &face;
    return !!((face.*.face_index & @as(c_long, 0x7FFF0000)) != 0);
}
pub inline fn FT_IS_VARIATION(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_VARIATION) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_VARIATION) != 0);
}
pub inline fn FT_IS_CID_KEYED(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_CID_KEYED) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_CID_KEYED) != 0);
}
pub inline fn FT_IS_TRICKY(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_TRICKY) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_TRICKY) != 0);
}
pub inline fn FT_HAS_COLOR(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_COLOR) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_COLOR) != 0);
}
pub inline fn FT_HAS_SVG(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_SVG) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_SVG) != 0);
}
pub inline fn FT_HAS_SBIX(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_SBIX) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_SBIX) != 0);
}
pub inline fn FT_HAS_SBIX_OVERLAY(face: anytype) @TypeOf(!!((face.*.face_flags & FT_FACE_FLAG_SBIX_OVERLAY) != 0)) {
    _ = &face;
    return !!((face.*.face_flags & FT_FACE_FLAG_SBIX_OVERLAY) != 0);
}
pub const FT_STYLE_FLAG_ITALIC = @as(c_int, 1) << @as(c_int, 0);
pub const FT_STYLE_FLAG_BOLD = @as(c_int, 1) << @as(c_int, 1);
pub const FT_OPEN_MEMORY = @as(c_int, 0x1);
pub const FT_OPEN_STREAM = @as(c_int, 0x2);
pub const FT_OPEN_PATHNAME = @as(c_int, 0x4);
pub const FT_OPEN_DRIVER = @as(c_int, 0x8);
pub const FT_OPEN_PARAMS = @as(c_int, 0x10);
pub const ft_open_memory = FT_OPEN_MEMORY;
pub const ft_open_stream = FT_OPEN_STREAM;
pub const ft_open_pathname = FT_OPEN_PATHNAME;
pub const ft_open_driver = FT_OPEN_DRIVER;
pub const ft_open_params = FT_OPEN_PARAMS;
pub const FT_LOAD_DEFAULT = @as(c_int, 0x0);
pub const FT_LOAD_NO_SCALE = @as(c_long, 1) << @as(c_int, 0);
pub const FT_LOAD_NO_HINTING = @as(c_long, 1) << @as(c_int, 1);
pub const FT_LOAD_RENDER = @as(c_long, 1) << @as(c_int, 2);
pub const FT_LOAD_NO_BITMAP = @as(c_long, 1) << @as(c_int, 3);
pub const FT_LOAD_VERTICAL_LAYOUT = @as(c_long, 1) << @as(c_int, 4);
pub const FT_LOAD_FORCE_AUTOHINT = @as(c_long, 1) << @as(c_int, 5);
pub const FT_LOAD_CROP_BITMAP = @as(c_long, 1) << @as(c_int, 6);
pub const FT_LOAD_PEDANTIC = @as(c_long, 1) << @as(c_int, 7);
pub const FT_LOAD_IGNORE_GLOBAL_ADVANCE_WIDTH = @as(c_long, 1) << @as(c_int, 9);
pub const FT_LOAD_NO_RECURSE = @as(c_long, 1) << @as(c_int, 10);
pub const FT_LOAD_IGNORE_TRANSFORM = @as(c_long, 1) << @as(c_int, 11);
pub const FT_LOAD_MONOCHROME = @as(c_long, 1) << @as(c_int, 12);
pub const FT_LOAD_LINEAR_DESIGN = @as(c_long, 1) << @as(c_int, 13);
pub const FT_LOAD_SBITS_ONLY = @as(c_long, 1) << @as(c_int, 14);
pub const FT_LOAD_NO_AUTOHINT = @as(c_long, 1) << @as(c_int, 15);
pub const FT_LOAD_COLOR = @as(c_long, 1) << @as(c_int, 20);
pub const FT_LOAD_COMPUTE_METRICS = @as(c_long, 1) << @as(c_int, 21);
pub const FT_LOAD_BITMAP_METRICS_ONLY = @as(c_long, 1) << @as(c_int, 22);
pub const FT_LOAD_NO_SVG = @as(c_long, 1) << @as(c_int, 24);
pub const FT_LOAD_ADVANCE_ONLY = @as(c_long, 1) << @as(c_int, 8);
pub const FT_LOAD_SVG_ONLY = @as(c_long, 1) << @as(c_int, 23);
pub inline fn FT_LOAD_TARGET_(x: anytype) @TypeOf(FT_STATIC_CAST(FT_Int32, x & @as(c_int, 15)) << @as(c_int, 16)) {
    _ = &x;
    return FT_STATIC_CAST(FT_Int32, x & @as(c_int, 15)) << @as(c_int, 16);
}
pub const FT_LOAD_TARGET_NORMAL = FT_LOAD_TARGET_(FT_RENDER_MODE_NORMAL);
pub const FT_LOAD_TARGET_LIGHT = FT_LOAD_TARGET_(FT_RENDER_MODE_LIGHT);
pub const FT_LOAD_TARGET_MONO = FT_LOAD_TARGET_(FT_RENDER_MODE_MONO);
pub const FT_LOAD_TARGET_LCD = FT_LOAD_TARGET_(FT_RENDER_MODE_LCD);
pub const FT_LOAD_TARGET_LCD_V = FT_LOAD_TARGET_(FT_RENDER_MODE_LCD_V);
pub inline fn FT_LOAD_TARGET_MODE(x: anytype) @TypeOf(FT_STATIC_CAST(FT_Render_Mode, (x >> @as(c_int, 16)) & @as(c_int, 15))) {
    _ = &x;
    return FT_STATIC_CAST(FT_Render_Mode, (x >> @as(c_int, 16)) & @as(c_int, 15));
}
pub const ft_render_mode_normal = FT_RENDER_MODE_NORMAL;
pub const ft_render_mode_mono = FT_RENDER_MODE_MONO;
pub const ft_kerning_default = FT_KERNING_DEFAULT;
pub const ft_kerning_unfitted = FT_KERNING_UNFITTED;
pub const ft_kerning_unscaled = FT_KERNING_UNSCALED;
pub const FT_SUBGLYPH_FLAG_ARGS_ARE_WORDS = @as(c_int, 1);
pub const FT_SUBGLYPH_FLAG_ARGS_ARE_XY_VALUES = @as(c_int, 2);
pub const FT_SUBGLYPH_FLAG_ROUND_XY_TO_GRID = @as(c_int, 4);
pub const FT_SUBGLYPH_FLAG_SCALE = @as(c_int, 8);
pub const FT_SUBGLYPH_FLAG_XY_SCALE = @as(c_int, 0x40);
pub const FT_SUBGLYPH_FLAG_2X2 = @as(c_int, 0x80);
pub const FT_SUBGLYPH_FLAG_USE_MY_METRICS = @as(c_int, 0x200);
pub const FT_FSTYPE_INSTALLABLE_EMBEDDING = @as(c_int, 0x0000);
pub const FT_FSTYPE_RESTRICTED_LICENSE_EMBEDDING = @as(c_int, 0x0002);
pub const FT_FSTYPE_PREVIEW_AND_PRINT_EMBEDDING = @as(c_int, 0x0004);
pub const FT_FSTYPE_EDITABLE_EMBEDDING = @as(c_int, 0x0008);
pub const FT_FSTYPE_NO_SUBSETTING = @as(c_int, 0x0100);
pub const FT_FSTYPE_BITMAP_EMBEDDING_ONLY = @as(c_int, 0x0200);
pub const FREETYPE_MAJOR = @as(c_int, 2);
pub const FREETYPE_MINOR = @as(c_int, 14);
pub const FREETYPE_PATCH = @as(c_int, 3);
pub const _hb_var_int_t = union__hb_var_int_t;
pub const _hb_var_num_t = union__hb_var_num_t;
pub const hb_language_impl_t = struct_hb_language_impl_t;
pub const __locale_struct = struct___locale_struct;
pub const _G_fpos_t = struct__G_fpos_t;
pub const _G_fpos64_t = struct__G_fpos64_t;
pub const _IO_marker = struct__IO_marker;
pub const _IO_FILE = struct__IO_FILE;
pub const _IO_codecvt = struct__IO_codecvt;
pub const _IO_wide_data = struct__IO_wide_data;
pub const _IO_cookie_io_functions_t = struct__IO_cookie_io_functions_t;
pub const timeval = struct_timeval;
pub const timespec = struct_timespec;
pub const __pthread_internal_list = struct___pthread_internal_list;
pub const __pthread_internal_slist = struct___pthread_internal_slist;
pub const __pthread_mutex_s = struct___pthread_mutex_s;
pub const __pthread_rwlock_arch_t = struct___pthread_rwlock_arch_t;
pub const __pthread_cond_s = struct___pthread_cond_s;
pub const random_data = struct_random_data;
pub const drand48_data = struct_drand48_data;
pub const __jmp_buf_tag = struct___jmp_buf_tag;
pub const FT_MemoryRec_ = struct_FT_MemoryRec_;
pub const FT_StreamDesc_ = union_FT_StreamDesc_;
pub const FT_StreamRec_ = struct_FT_StreamRec_;
pub const FT_Vector_ = struct_FT_Vector_;
pub const FT_BBox_ = struct_FT_BBox_;
pub const FT_Pixel_Mode_ = enum_FT_Pixel_Mode_;
pub const FT_Bitmap_ = struct_FT_Bitmap_;
pub const FT_Outline_ = struct_FT_Outline_;
pub const FT_Outline_Funcs_ = struct_FT_Outline_Funcs_;
pub const FT_Glyph_Format_ = enum_FT_Glyph_Format_;
pub const FT_Span_ = struct_FT_Span_;
pub const FT_Raster_Params_ = struct_FT_Raster_Params_;
pub const FT_RasterRec_ = struct_FT_RasterRec_;
pub const FT_Raster_Funcs_ = struct_FT_Raster_Funcs_;
pub const FT_UnitVector_ = struct_FT_UnitVector_;
pub const FT_Matrix_ = struct_FT_Matrix_;
pub const FT_Data_ = struct_FT_Data_;
pub const FT_Generic_ = struct_FT_Generic_;
pub const FT_ListNodeRec_ = struct_FT_ListNodeRec_;
pub const FT_ListRec_ = struct_FT_ListRec_;
pub const FT_Glyph_Metrics_ = struct_FT_Glyph_Metrics_;
pub const FT_Bitmap_Size_ = struct_FT_Bitmap_Size_;
pub const FT_LibraryRec_ = struct_FT_LibraryRec_;
pub const FT_ModuleRec_ = struct_FT_ModuleRec_;
pub const FT_DriverRec_ = struct_FT_DriverRec_;
pub const FT_RendererRec_ = struct_FT_RendererRec_;
pub const FT_Encoding_ = enum_FT_Encoding_;
pub const FT_CharMapRec_ = struct_FT_CharMapRec_;
pub const FT_SubGlyphRec_ = struct_FT_SubGlyphRec_;
pub const FT_Slot_InternalRec_ = struct_FT_Slot_InternalRec_;
pub const FT_GlyphSlotRec_ = struct_FT_GlyphSlotRec_;
pub const FT_Size_Metrics_ = struct_FT_Size_Metrics_;
pub const FT_Size_InternalRec_ = struct_FT_Size_InternalRec_;
pub const FT_SizeRec_ = struct_FT_SizeRec_;
pub const FT_Face_InternalRec_ = struct_FT_Face_InternalRec_;
pub const FT_FaceRec_ = struct_FT_FaceRec_;
pub const FT_Parameter_ = struct_FT_Parameter_;
pub const FT_Open_Args_ = struct_FT_Open_Args_;
pub const FT_Size_Request_Type_ = enum_FT_Size_Request_Type_;
pub const FT_Size_RequestRec_ = struct_FT_Size_RequestRec_;
pub const FT_Render_Mode_ = enum_FT_Render_Mode_;
pub const FT_Kerning_Mode_ = enum_FT_Kerning_Mode_;
