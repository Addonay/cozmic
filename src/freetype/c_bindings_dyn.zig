const __root = @This();
pub const __builtin = @import("std").zig.c_translation.builtins;
pub const __helpers = @import("std").zig.c_translation.helpers;
pub const ptrdiff_t = c_long;
pub const wchar_t = c_int;
pub const max_align_t = extern struct {
    __aro_max_align_ll: c_longlong = 0,
    __aro_max_align_ld: c_longdouble = 0,
};
pub var memcpy: *const fn (noalias __dest: ?*anyopaque, noalias __src: ?*const anyopaque, __n: usize) callconv(.c) ?*anyopaque = undefined;
pub var memmove: *const fn (__dest: ?*anyopaque, __src: ?*const anyopaque, __n: usize) callconv(.c) ?*anyopaque = undefined;
pub var memccpy: *const fn (noalias __dest: ?*anyopaque, noalias __src: ?*const anyopaque, __c: c_int, __n: usize) callconv(.c) ?*anyopaque = undefined;
pub var memset: *const fn (__s: ?*anyopaque, __c: c_int, __n: usize) callconv(.c) ?*anyopaque = undefined;
pub var memset_explicit: *const fn (__s: ?*anyopaque, __c: c_int, __n: usize) callconv(.c) ?*anyopaque = undefined;
pub var memcmp: *const fn (__s1: ?*const anyopaque, __s2: ?*const anyopaque, __n: usize) callconv(.c) c_int = undefined;
pub var __memcmpeq: *const fn (__s1: ?*const anyopaque, __s2: ?*const anyopaque, __n: usize) callconv(.c) c_int = undefined;
pub var memchr: *const fn (__s: ?*const anyopaque, __c: c_int, __n: usize) callconv(.c) ?*anyopaque = undefined;
pub var strcpy: *const fn (noalias __dest: [*c]u8, noalias __src: [*c]const u8) callconv(.c) [*c]u8 = undefined;
pub var strncpy: *const fn (noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) callconv(.c) [*c]u8 = undefined;
pub var strcat: *const fn (noalias __dest: [*c]u8, noalias __src: [*c]const u8) callconv(.c) [*c]u8 = undefined;
pub var strncat: *const fn (noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) callconv(.c) [*c]u8 = undefined;
pub var strcmp: *const fn (__s1: [*c]const u8, __s2: [*c]const u8) callconv(.c) c_int = undefined;
pub var strncmp: *const fn (__s1: [*c]const u8, __s2: [*c]const u8, __n: usize) callconv(.c) c_int = undefined;
pub var strcoll: *const fn (__s1: [*c]const u8, __s2: [*c]const u8) callconv(.c) c_int = undefined;
pub var strxfrm: *const fn (noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) callconv(.c) usize = undefined;
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
pub var strcoll_l: *const fn (__s1: [*c]const u8, __s2: [*c]const u8, __l: locale_t) callconv(.c) c_int = undefined;
pub var strxfrm_l: *const fn (__dest: [*c]u8, __src: [*c]const u8, __n: usize, __l: locale_t) callconv(.c) usize = undefined;
pub var strdup: *const fn (__s: [*c]const u8) callconv(.c) [*c]u8 = undefined;
pub var strndup: *const fn (__string: [*c]const u8, __n: usize) callconv(.c) [*c]u8 = undefined;
pub var strchr: *const fn (__s: [*c]const u8, __c: c_int) callconv(.c) [*c]u8 = undefined;
pub var strrchr: *const fn (__s: [*c]const u8, __c: c_int) callconv(.c) [*c]u8 = undefined;
pub var strchrnul: *const fn (__s: [*c]const u8, __c: c_int) callconv(.c) [*c]u8 = undefined;
pub var strcspn: *const fn (__s: [*c]const u8, __reject: [*c]const u8) callconv(.c) usize = undefined;
pub var strspn: *const fn (__s: [*c]const u8, __accept: [*c]const u8) callconv(.c) usize = undefined;
pub var strpbrk: *const fn (__s: [*c]const u8, __accept: [*c]const u8) callconv(.c) [*c]u8 = undefined;
pub var strstr: *const fn (__haystack: [*c]const u8, __needle: [*c]const u8) callconv(.c) [*c]u8 = undefined;
pub var strtok: *const fn (noalias __s: [*c]u8, noalias __delim: [*c]const u8) callconv(.c) [*c]u8 = undefined;
pub var __strtok_r: *const fn (noalias __s: [*c]u8, noalias __delim: [*c]const u8, noalias __save_ptr: [*c][*c]u8) callconv(.c) [*c]u8 = undefined;
pub var strtok_r: *const fn (noalias __s: [*c]u8, noalias __delim: [*c]const u8, noalias __save_ptr: [*c][*c]u8) callconv(.c) [*c]u8 = undefined;
pub var strcasestr: *const fn (__haystack: [*c]const u8, __needle: [*c]const u8) callconv(.c) [*c]u8 = undefined;
pub var memmem: *const fn (__haystack: ?*const anyopaque, __haystacklen: usize, __needle: ?*const anyopaque, __needlelen: usize) callconv(.c) ?*anyopaque = undefined;
pub var __mempcpy: *const fn (noalias __dest: ?*anyopaque, noalias __src: ?*const anyopaque, __n: usize) callconv(.c) ?*anyopaque = undefined;
pub var mempcpy: *const fn (noalias __dest: ?*anyopaque, noalias __src: ?*const anyopaque, __n: usize) callconv(.c) ?*anyopaque = undefined;
pub var strlen: *const fn (__s: [*c]const u8) callconv(.c) usize = undefined;
pub var strnlen: *const fn (__string: [*c]const u8, __maxlen: usize) callconv(.c) usize = undefined;
pub var strerror: *const fn (__errnum: c_int) callconv(.c) [*c]u8 = undefined;
pub var strerror_r: *const fn (__errnum: c_int, __buf: [*c]u8, __buflen: usize) callconv(.c) c_int = undefined;
pub var strerror_l: *const fn (__errnum: c_int, __l: locale_t) callconv(.c) [*c]u8 = undefined;
pub var bcmp: *const fn (__s1: ?*const anyopaque, __s2: ?*const anyopaque, __n: usize) callconv(.c) c_int = undefined;
pub var bcopy: *const fn (__src: ?*const anyopaque, __dest: ?*anyopaque, __n: usize) callconv(.c) void = undefined;
pub var bzero: *const fn (__s: ?*anyopaque, __n: usize) callconv(.c) void = undefined;
pub var index: *const fn (__s: [*c]const u8, __c: c_int) callconv(.c) [*c]u8 = undefined;
pub var rindex: *const fn (__s: [*c]const u8, __c: c_int) callconv(.c) [*c]u8 = undefined;
pub var ffs: *const fn (__i: c_int) callconv(.c) c_int = undefined;
pub var ffsl: *const fn (__l: c_long) callconv(.c) c_int = undefined;
pub var ffsll: *const fn (__ll: c_longlong) callconv(.c) c_int = undefined;
pub var strcasecmp: *const fn (__s1: [*c]const u8, __s2: [*c]const u8) callconv(.c) c_int = undefined;
pub var strncasecmp: *const fn (__s1: [*c]const u8, __s2: [*c]const u8, __n: usize) callconv(.c) c_int = undefined;
pub var strcasecmp_l: *const fn (__s1: [*c]const u8, __s2: [*c]const u8, __loc: locale_t) callconv(.c) c_int = undefined;
pub var strncasecmp_l: *const fn (__s1: [*c]const u8, __s2: [*c]const u8, __n: usize, __loc: locale_t) callconv(.c) c_int = undefined;
pub var explicit_bzero: *const fn (__s: ?*anyopaque, __n: usize) callconv(.c) void = undefined;
pub var strsep: *const fn (noalias __stringp: [*c][*c]u8, noalias __delim: [*c]const u8) callconv(.c) [*c]u8 = undefined;
pub var strsignal: *const fn (__sig: c_int) callconv(.c) [*c]u8 = undefined;
pub var __stpcpy: *const fn (noalias __dest: [*c]u8, noalias __src: [*c]const u8) callconv(.c) [*c]u8 = undefined;
pub var stpcpy: *const fn (noalias __dest: [*c]u8, noalias __src: [*c]const u8) callconv(.c) [*c]u8 = undefined;
pub var __stpncpy: *const fn (noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) callconv(.c) [*c]u8 = undefined;
pub var stpncpy: *const fn (noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) callconv(.c) [*c]u8 = undefined;
pub var strlcpy: *const fn (noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) callconv(.c) usize = undefined;
pub var strlcat: *const fn (noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) callconv(.c) usize = undefined;
pub const struct___va_list_tag_2 = extern struct {
    unnamed_0: c_uint = 0,
    unnamed_1: c_uint = 0,
    unnamed_2: ?*anyopaque = null,
    unnamed_3: ?*anyopaque = null,
};
pub const __builtin_va_list = [1]struct___va_list_tag_2;
pub const va_list = __builtin_va_list;
pub const __gnuc_va_list = __builtin_va_list;
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
pub var remove: *const fn (__filename: [*c]const u8) callconv(.c) c_int = undefined;
pub var rename: *const fn (__old: [*c]const u8, __new: [*c]const u8) callconv(.c) c_int = undefined;
pub var renameat: *const fn (__oldfd: c_int, __old: [*c]const u8, __newfd: c_int, __new: [*c]const u8) callconv(.c) c_int = undefined;
pub var fclose: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var tmpfile: *const fn () callconv(.c) ?*FILE = undefined;
pub var tmpnam: *const fn ([*c]u8) callconv(.c) [*c]u8 = undefined;
pub var tmpnam_r: *const fn (__s: [*c]u8) callconv(.c) [*c]u8 = undefined;
pub var tempnam: *const fn (__dir: [*c]const u8, __pfx: [*c]const u8) callconv(.c) [*c]u8 = undefined;
pub var fflush: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var fflush_unlocked: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var fopen: *const fn (noalias __filename: [*c]const u8, noalias __modes: [*c]const u8) callconv(.c) ?*FILE = undefined;
pub var freopen: *const fn (noalias __filename: [*c]const u8, noalias __modes: [*c]const u8, noalias __stream: ?*FILE) callconv(.c) ?*FILE = undefined;
pub var fdopen: *const fn (__fd: c_int, __modes: [*c]const u8) callconv(.c) ?*FILE = undefined;
pub var fopencookie: *const fn (noalias __magic_cookie: ?*anyopaque, noalias __modes: [*c]const u8, __io_funcs: cookie_io_functions_t) callconv(.c) ?*FILE = undefined;
pub var fmemopen: *const fn (__s: ?*anyopaque, __len: usize, __modes: [*c]const u8) callconv(.c) ?*FILE = undefined;
pub var open_memstream: *const fn (__bufloc: [*c][*c]u8, __sizeloc: [*c]usize) callconv(.c) ?*FILE = undefined;
pub var setbuf: *const fn (noalias __stream: ?*FILE, noalias __buf: [*c]u8) callconv(.c) void = undefined;
pub var setvbuf: *const fn (noalias __stream: ?*FILE, noalias __buf: [*c]u8, __modes: c_int, __n: usize) callconv(.c) c_int = undefined;
pub var setbuffer: *const fn (noalias __stream: ?*FILE, noalias __buf: [*c]u8, __size: usize) callconv(.c) void = undefined;
pub var setlinebuf: *const fn (__stream: ?*FILE) callconv(.c) void = undefined;
pub var fprintf: *const fn (noalias __stream: ?*FILE, noalias __format: [*c]const u8, ...) callconv(.c) c_int = undefined;
pub var printf: *const fn (noalias __format: [*c]const u8, ...) callconv(.c) c_int = undefined;
pub var sprintf: *const fn (noalias __s: [*c]u8, noalias __format: [*c]const u8, ...) callconv(.c) c_int = undefined;
pub var vfprintf: *const fn (noalias __s: ?*FILE, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) callconv(.c) c_int = undefined;
pub var vprintf: *const fn (noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) callconv(.c) c_int = undefined;
pub var vsprintf: *const fn (noalias __s: [*c]u8, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) callconv(.c) c_int = undefined;
pub var snprintf: *const fn (noalias __s: [*c]u8, __maxlen: usize, noalias __format: [*c]const u8, ...) callconv(.c) c_int = undefined;
pub var vsnprintf: *const fn (noalias __s: [*c]u8, __maxlen: usize, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) callconv(.c) c_int = undefined;
pub var vasprintf: *const fn (noalias __ptr: [*c][*c]u8, noalias __f: [*c]const u8, __arg: [*c]struct___va_list_tag_2) callconv(.c) c_int = undefined;
pub var __asprintf: *const fn (noalias __ptr: [*c][*c]u8, noalias __fmt: [*c]const u8, ...) callconv(.c) c_int = undefined;
pub var asprintf: *const fn (noalias __ptr: [*c][*c]u8, noalias __fmt: [*c]const u8, ...) callconv(.c) c_int = undefined;
pub var vdprintf: *const fn (__fd: c_int, noalias __fmt: [*c]const u8, __arg: [*c]struct___va_list_tag_2) callconv(.c) c_int = undefined;
pub var dprintf: *const fn (__fd: c_int, noalias __fmt: [*c]const u8, ...) callconv(.c) c_int = undefined;
pub var fscanf: *const fn (noalias __stream: ?*FILE, noalias __format: [*c]const u8, ...) callconv(.c) c_int = undefined;
pub var scanf: *const fn (noalias __format: [*c]const u8, ...) callconv(.c) c_int = undefined;
pub var sscanf: *const fn (noalias __s: [*c]const u8, noalias __format: [*c]const u8, ...) callconv(.c) c_int = undefined;
pub var vfscanf: *const fn (noalias __s: ?*FILE, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) callconv(.c) c_int = undefined;
pub var vscanf: *const fn (noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) callconv(.c) c_int = undefined;
pub var vsscanf: *const fn (noalias __s: [*c]const u8, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_2) callconv(.c) c_int = undefined;
pub var fgetc: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var getc: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var getchar: *const fn () callconv(.c) c_int = undefined;
pub var getc_unlocked: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var getchar_unlocked: *const fn () callconv(.c) c_int = undefined;
pub var fgetc_unlocked: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var fputc: *const fn (__c: c_int, __stream: ?*FILE) callconv(.c) c_int = undefined;
pub var putc: *const fn (__c: c_int, __stream: ?*FILE) callconv(.c) c_int = undefined;
pub var putchar: *const fn (__c: c_int) callconv(.c) c_int = undefined;
pub var fputc_unlocked: *const fn (__c: c_int, __stream: ?*FILE) callconv(.c) c_int = undefined;
pub var putc_unlocked: *const fn (__c: c_int, __stream: ?*FILE) callconv(.c) c_int = undefined;
pub var putchar_unlocked: *const fn (__c: c_int) callconv(.c) c_int = undefined;
pub var getw: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var putw: *const fn (__w: c_int, __stream: ?*FILE) callconv(.c) c_int = undefined;
pub var fgets: *const fn (noalias __s: [*c]u8, __n: c_int, noalias __stream: ?*FILE) callconv(.c) [*c]u8 = undefined;
pub var __getdelim: *const fn (noalias __lineptr: [*c][*c]u8, noalias __n: [*c]usize, __delimiter: c_int, noalias __stream: ?*FILE) callconv(.c) __ssize_t = undefined;
pub var getdelim: *const fn (noalias __lineptr: [*c][*c]u8, noalias __n: [*c]usize, __delimiter: c_int, noalias __stream: ?*FILE) callconv(.c) __ssize_t = undefined;
pub var getline: *const fn (noalias __lineptr: [*c][*c]u8, noalias __n: [*c]usize, noalias __stream: ?*FILE) callconv(.c) __ssize_t = undefined;
pub var fputs: *const fn (noalias __s: [*c]const u8, noalias __stream: ?*FILE) callconv(.c) c_int = undefined;
pub var puts: *const fn (__s: [*c]const u8) callconv(.c) c_int = undefined;
pub var ungetc: *const fn (__c: c_int, __stream: ?*FILE) callconv(.c) c_int = undefined;
pub var fread: *const fn (noalias __ptr: ?*anyopaque, __size: usize, __n: usize, noalias __stream: ?*FILE) callconv(.c) usize = undefined;
pub var fwrite: *const fn (noalias __ptr: ?*const anyopaque, __size: usize, __n: usize, noalias __s: ?*FILE) callconv(.c) usize = undefined;
pub var fread_unlocked: *const fn (noalias __ptr: ?*anyopaque, __size: usize, __n: usize, noalias __stream: ?*FILE) callconv(.c) usize = undefined;
pub var fwrite_unlocked: *const fn (noalias __ptr: ?*const anyopaque, __size: usize, __n: usize, noalias __stream: ?*FILE) callconv(.c) usize = undefined;
pub var fseek: *const fn (__stream: ?*FILE, __off: c_long, __whence: c_int) callconv(.c) c_int = undefined;
pub var ftell: *const fn (__stream: ?*FILE) callconv(.c) c_long = undefined;
pub var rewind: *const fn (__stream: ?*FILE) callconv(.c) void = undefined;
pub var fseeko: *const fn (__stream: ?*FILE, __off: __off_t, __whence: c_int) callconv(.c) c_int = undefined;
pub var ftello: *const fn (__stream: ?*FILE) callconv(.c) __off_t = undefined;
pub var fgetpos: *const fn (noalias __stream: ?*FILE, noalias __pos: [*c]fpos_t) callconv(.c) c_int = undefined;
pub var fsetpos: *const fn (__stream: ?*FILE, __pos: [*c]const fpos_t) callconv(.c) c_int = undefined;
pub var clearerr: *const fn (__stream: ?*FILE) callconv(.c) void = undefined;
pub var feof: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var ferror: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var clearerr_unlocked: *const fn (__stream: ?*FILE) callconv(.c) void = undefined;
pub var feof_unlocked: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var ferror_unlocked: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var perror: *const fn (__s: [*c]const u8) callconv(.c) void = undefined;
pub var fileno: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var fileno_unlocked: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var pclose: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var popen: *const fn (__command: [*c]const u8, __modes: [*c]const u8) callconv(.c) ?*FILE = undefined;
pub var ctermid: *const fn (__s: [*c]u8) callconv(.c) [*c]u8 = undefined;
pub var flockfile: *const fn (__stream: ?*FILE) callconv(.c) void = undefined;
pub var ftrylockfile: *const fn (__stream: ?*FILE) callconv(.c) c_int = undefined;
pub var funlockfile: *const fn (__stream: ?*FILE) callconv(.c) void = undefined;
pub var __uflow: *const fn (?*FILE) callconv(.c) c_int = undefined;
pub var __overflow: *const fn (?*FILE, c_int) callconv(.c) c_int = undefined;
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
pub var __ctype_get_mb_cur_max: *const fn () callconv(.c) usize = undefined;
pub var atof: *const fn (__nptr: [*c]const u8) callconv(.c) f64 = undefined;
pub var atoi: *const fn (__nptr: [*c]const u8) callconv(.c) c_int = undefined;
pub var atol: *const fn (__nptr: [*c]const u8) callconv(.c) c_long = undefined;
pub var atoll: *const fn (__nptr: [*c]const u8) callconv(.c) c_longlong = undefined;
pub var strtod: *const fn (noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) callconv(.c) f64 = undefined;
pub var strtof: *const fn (noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) callconv(.c) f32 = undefined;
pub var strtold: *const fn (noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) callconv(.c) c_longdouble = undefined;
pub var strtol: *const fn (noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) callconv(.c) c_long = undefined;
pub var strtoul: *const fn (noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) callconv(.c) c_ulong = undefined;
pub var strtoq: *const fn (noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) callconv(.c) c_longlong = undefined;
pub var strtouq: *const fn (noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) callconv(.c) c_ulonglong = undefined;
pub var strtoll: *const fn (noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) callconv(.c) c_longlong = undefined;
pub var strtoull: *const fn (noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) callconv(.c) c_ulonglong = undefined;
pub var l64a: *const fn (__n: c_long) callconv(.c) [*c]u8 = undefined;
pub var a64l: *const fn (__s: [*c]const u8) callconv(.c) c_long = undefined;
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
pub var select: *const fn (__nfds: c_int, noalias __readfds: [*c]fd_set, noalias __writefds: [*c]fd_set, noalias __exceptfds: [*c]fd_set, noalias __timeout: [*c]struct_timeval) callconv(.c) c_int = undefined;
pub var pselect: *const fn (__nfds: c_int, noalias __readfds: [*c]fd_set, noalias __writefds: [*c]fd_set, noalias __exceptfds: [*c]fd_set, noalias __timeout: [*c]const struct_timespec, noalias __sigmask: [*c]const __sigset_t) callconv(.c) c_int = undefined;
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
pub var random: *const fn () callconv(.c) c_long = undefined;
pub var srandom: *const fn (__seed: c_uint) callconv(.c) void = undefined;
pub var initstate: *const fn (__seed: c_uint, __statebuf: [*c]u8, __statelen: usize) callconv(.c) [*c]u8 = undefined;
pub var setstate: *const fn (__statebuf: [*c]u8) callconv(.c) [*c]u8 = undefined;
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
pub var random_r: *const fn (noalias __buf: [*c]struct_random_data, noalias __result: [*c]i32) callconv(.c) c_int = undefined;
pub var srandom_r: *const fn (__seed: c_uint, __buf: [*c]struct_random_data) callconv(.c) c_int = undefined;
pub var initstate_r: *const fn (__seed: c_uint, noalias __statebuf: [*c]u8, __statelen: usize, noalias __buf: [*c]struct_random_data) callconv(.c) c_int = undefined;
pub var setstate_r: *const fn (noalias __statebuf: [*c]u8, noalias __buf: [*c]struct_random_data) callconv(.c) c_int = undefined;
pub var rand: *const fn () callconv(.c) c_int = undefined;
pub var srand: *const fn (__seed: c_uint) callconv(.c) void = undefined;
pub var rand_r: *const fn (__seed: [*c]c_uint) callconv(.c) c_int = undefined;
pub var drand48: *const fn () callconv(.c) f64 = undefined;
pub var erand48: *const fn (__xsubi: [*c]c_ushort) callconv(.c) f64 = undefined;
pub var lrand48: *const fn () callconv(.c) c_long = undefined;
pub var nrand48: *const fn (__xsubi: [*c]c_ushort) callconv(.c) c_long = undefined;
pub var mrand48: *const fn () callconv(.c) c_long = undefined;
pub var jrand48: *const fn (__xsubi: [*c]c_ushort) callconv(.c) c_long = undefined;
pub var srand48: *const fn (__seedval: c_long) callconv(.c) void = undefined;
pub var seed48: *const fn (__seed16v: [*c]c_ushort) callconv(.c) [*c]c_ushort = undefined;
pub var lcong48: *const fn (__param: [*c]c_ushort) callconv(.c) void = undefined;
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
pub var drand48_r: *const fn (noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]f64) callconv(.c) c_int = undefined;
pub var erand48_r: *const fn (__xsubi: [*c]c_ushort, noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]f64) callconv(.c) c_int = undefined;
pub var lrand48_r: *const fn (noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) callconv(.c) c_int = undefined;
pub var nrand48_r: *const fn (__xsubi: [*c]c_ushort, noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) callconv(.c) c_int = undefined;
pub var mrand48_r: *const fn (noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) callconv(.c) c_int = undefined;
pub var jrand48_r: *const fn (__xsubi: [*c]c_ushort, noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) callconv(.c) c_int = undefined;
pub var srand48_r: *const fn (__seedval: c_long, __buffer: [*c]struct_drand48_data) callconv(.c) c_int = undefined;
pub var seed48_r: *const fn (__seed16v: [*c]c_ushort, __buffer: [*c]struct_drand48_data) callconv(.c) c_int = undefined;
pub var lcong48_r: *const fn (__param: [*c]c_ushort, __buffer: [*c]struct_drand48_data) callconv(.c) c_int = undefined;
pub var arc4random: *const fn () callconv(.c) __uint32_t = undefined;
pub var arc4random_buf: *const fn (__buf: ?*anyopaque, __size: usize) callconv(.c) void = undefined;
pub var arc4random_uniform: *const fn (__upper_bound: __uint32_t) callconv(.c) __uint32_t = undefined;
pub var malloc: *const fn (__size: usize) callconv(.c) ?*anyopaque = undefined;
pub var calloc: *const fn (__nmemb: usize, __size: usize) callconv(.c) ?*anyopaque = undefined;
pub var realloc: *const fn (__ptr: ?*anyopaque, __size: usize) callconv(.c) ?*anyopaque = undefined;
pub var free: *const fn (__ptr: ?*anyopaque) callconv(.c) void = undefined;
pub var reallocarray: *const fn (__ptr: ?*anyopaque, __nmemb: usize, __size: usize) callconv(.c) ?*anyopaque = undefined;
pub var alloca: *const fn (__size: usize) callconv(.c) ?*anyopaque = undefined;
pub var valloc: *const fn (__size: usize) callconv(.c) ?*anyopaque = undefined;
pub var posix_memalign: *const fn (__memptr: [*c]?*anyopaque, __alignment: usize, __size: usize) callconv(.c) c_int = undefined;
pub var aligned_alloc: *const fn (__alignment: usize, __size: usize) callconv(.c) ?*anyopaque = undefined;
pub var abort: *const fn () callconv(.c) noreturn = undefined;
pub var atexit: *const fn (__func: ?*const fn () callconv(.c) void) callconv(.c) c_int = undefined;
pub var at_quick_exit: *const fn (__func: ?*const fn () callconv(.c) void) callconv(.c) c_int = undefined;
pub var on_exit: *const fn (__func: ?*const fn (__status: c_int, __arg: ?*anyopaque) callconv(.c) void, __arg: ?*anyopaque) callconv(.c) c_int = undefined;
pub var exit: *const fn (__status: c_int) callconv(.c) noreturn = undefined;
pub var quick_exit: *const fn (__status: c_int) callconv(.c) noreturn = undefined;
pub var _Exit: *const fn (__status: c_int) callconv(.c) noreturn = undefined;
pub var getenv: *const fn (__name: [*c]const u8) callconv(.c) [*c]u8 = undefined;
pub var putenv: *const fn (__string: [*c]u8) callconv(.c) c_int = undefined;
pub var setenv: *const fn (__name: [*c]const u8, __value: [*c]const u8, __replace: c_int) callconv(.c) c_int = undefined;
pub var unsetenv: *const fn (__name: [*c]const u8) callconv(.c) c_int = undefined;
pub var clearenv: *const fn () callconv(.c) c_int = undefined;
pub var mktemp: *const fn (__template: [*c]u8) callconv(.c) [*c]u8 = undefined;
pub var mkstemp: *const fn (__template: [*c]u8) callconv(.c) c_int = undefined;
pub var mkstemps: *const fn (__template: [*c]u8, __suffixlen: c_int) callconv(.c) c_int = undefined;
pub var mkdtemp: *const fn (__template: [*c]u8) callconv(.c) [*c]u8 = undefined;
pub var system: *const fn (__command: [*c]const u8) callconv(.c) c_int = undefined;
pub var realpath: *const fn (noalias __name: [*c]const u8, noalias __resolved: [*c]u8) callconv(.c) [*c]u8 = undefined;
pub const __compar_fn_t = ?*const fn (?*const anyopaque, ?*const anyopaque) callconv(.c) c_int;
pub var bsearch: *const fn (__key: ?*const anyopaque, __base: ?*const anyopaque, __nmemb: usize, __size: usize, __compar: __compar_fn_t) callconv(.c) ?*anyopaque = undefined;
pub var qsort: *const fn (__base: ?*anyopaque, __nmemb: usize, __size: usize, __compar: __compar_fn_t) callconv(.c) void = undefined;
pub var abs: *const fn (__x: c_int) callconv(.c) c_int = undefined;
pub var labs: *const fn (__x: c_long) callconv(.c) c_long = undefined;
pub var llabs: *const fn (__x: c_longlong) callconv(.c) c_longlong = undefined;
pub var div: *const fn (__numer: c_int, __denom: c_int) callconv(.c) div_t = undefined;
pub var ldiv: *const fn (__numer: c_long, __denom: c_long) callconv(.c) ldiv_t = undefined;
pub var lldiv: *const fn (__numer: c_longlong, __denom: c_longlong) callconv(.c) lldiv_t = undefined;
pub var ecvt: *const fn (__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) callconv(.c) [*c]u8 = undefined;
pub var fcvt: *const fn (__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) callconv(.c) [*c]u8 = undefined;
pub var gcvt: *const fn (__value: f64, __ndigit: c_int, __buf: [*c]u8) callconv(.c) [*c]u8 = undefined;
pub var qecvt: *const fn (__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) callconv(.c) [*c]u8 = undefined;
pub var qfcvt: *const fn (__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) callconv(.c) [*c]u8 = undefined;
pub var qgcvt: *const fn (__value: c_longdouble, __ndigit: c_int, __buf: [*c]u8) callconv(.c) [*c]u8 = undefined;
pub var ecvt_r: *const fn (__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) callconv(.c) c_int = undefined;
pub var fcvt_r: *const fn (__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) callconv(.c) c_int = undefined;
pub var qecvt_r: *const fn (__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) callconv(.c) c_int = undefined;
pub var qfcvt_r: *const fn (__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) callconv(.c) c_int = undefined;
pub var mblen: *const fn (__s: [*c]const u8, __n: usize) callconv(.c) c_int = undefined;
pub var mbtowc: *const fn (noalias __pwc: [*c]wchar_t, noalias __s: [*c]const u8, __n: usize) callconv(.c) c_int = undefined;
pub var wctomb: *const fn (__s: [*c]u8, __wchar: wchar_t) callconv(.c) c_int = undefined;
pub var mbstowcs: *const fn (noalias __pwcs: [*c]wchar_t, noalias __s: [*c]const u8, __n: usize) callconv(.c) usize = undefined;
pub var wcstombs: *const fn (noalias __s: [*c]u8, noalias __pwcs: [*c]const wchar_t, __n: usize) callconv(.c) usize = undefined;
pub var rpmatch: *const fn (__response: [*c]const u8) callconv(.c) c_int = undefined;
pub var getsubopt: *const fn (noalias __optionp: [*c][*c]u8, noalias __tokens: [*c]const [*c]u8, noalias __valuep: [*c][*c]u8) callconv(.c) c_int = undefined;
pub var getloadavg: *const fn (__loadavg: [*c]f64, __nelem: c_int) callconv(.c) c_int = undefined;
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
pub var setjmp: *const fn (__env: [*c]struct___jmp_buf_tag) callconv(.c) c_int = undefined;
pub var __sigsetjmp: *const fn (__env: [*c]struct___jmp_buf_tag, __savemask: c_int) callconv(.c) c_int = undefined;
pub var _setjmp: *const fn (__env: [*c]struct___jmp_buf_tag) callconv(.c) c_int = undefined;
pub var longjmp: *const fn (__env: [*c]struct___jmp_buf_tag, __val: c_int) callconv(.c) noreturn = undefined;
pub var _longjmp: *const fn (__env: [*c]struct___jmp_buf_tag, __val: c_int) callconv(.c) noreturn = undefined;
pub const sigjmp_buf = [1]struct___jmp_buf_tag;
pub var siglongjmp: *const fn (__env: [*c]struct___jmp_buf_tag, __val: c_int) callconv(.c) noreturn = undefined;
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
    pub const FT_Outline_New_Internal = __root.FT_Outline_New_Internal;
    pub const FT_Outline_Done_Internal = __root.FT_Outline_Done_Internal;
    pub const Internal = __root.FT_Outline_New_Internal;
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
    pub const FT_Outline_Decompose = __root.FT_Outline_Decompose;
    pub const FT_Outline_Check = __root.FT_Outline_Check;
    pub const FT_Outline_Get_CBox = __root.FT_Outline_Get_CBox;
    pub const FT_Outline_Translate = __root.FT_Outline_Translate;
    pub const FT_Outline_Copy = __root.FT_Outline_Copy;
    pub const FT_Outline_Transform = __root.FT_Outline_Transform;
    pub const FT_Outline_Embolden = __root.FT_Outline_Embolden;
    pub const FT_Outline_EmboldenXY = __root.FT_Outline_EmboldenXY;
    pub const FT_Outline_Reverse = __root.FT_Outline_Reverse;
    pub const FT_Outline_Get_Orientation = __root.FT_Outline_Get_Orientation;
    pub const Decompose = __root.FT_Outline_Decompose;
    pub const Check = __root.FT_Outline_Check;
    pub const CBox = __root.FT_Outline_Get_CBox;
    pub const Translate = __root.FT_Outline_Translate;
    pub const Copy = __root.FT_Outline_Copy;
    pub const Transform = __root.FT_Outline_Transform;
    pub const Embolden = __root.FT_Outline_Embolden;
    pub const EmboldenXY = __root.FT_Outline_EmboldenXY;
    pub const Reverse = __root.FT_Outline_Reverse;
    pub const Orientation = __root.FT_Outline_Get_Orientation;
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
pub var FT_Error_String: *const fn (error_code: FT_Error) callconv(.c) [*c]const u8 = undefined;
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
    pub const FT_Done_MM_Var = __root.FT_Done_MM_Var;
    pub const FT_Outline_New = __root.FT_Outline_New;
    pub const FT_Outline_Done = __root.FT_Outline_Done;
    pub const FT_Outline_Get_Bitmap = __root.FT_Outline_Get_Bitmap;
    pub const FT_Outline_Render = __root.FT_Outline_Render;
    pub const FreeType = __root.FT_Done_FreeType;
    pub const Face = __root.FT_New_Face;
    pub const Version = __root.FT_Library_Version;
    pub const Var = __root.FT_Done_MM_Var;
    pub const New = __root.FT_Outline_New;
    pub const Done = __root.FT_Outline_Done;
    pub const Bitmap = __root.FT_Outline_Get_Bitmap;
    pub const Render = __root.FT_Outline_Render;
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
    pub const FT_Get_CMap_Language_ID = __root.FT_Get_CMap_Language_ID;
    pub const FT_Get_CMap_Format = __root.FT_Get_CMap_Format;
    pub const Index = __root.FT_Get_Charmap_Index;
    pub const ID = __root.FT_Get_CMap_Language_ID;
    pub const Format = __root.FT_Get_CMap_Format;
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
    pub const FT_Get_Sfnt_Table = __root.FT_Get_Sfnt_Table;
    pub const FT_Load_Sfnt_Table = __root.FT_Load_Sfnt_Table;
    pub const FT_Sfnt_Table_Info = __root.FT_Sfnt_Table_Info;
    pub const FT_Get_Multi_Master = __root.FT_Get_Multi_Master;
    pub const FT_Get_MM_Var = __root.FT_Get_MM_Var;
    pub const FT_Set_MM_Design_Coordinates = __root.FT_Set_MM_Design_Coordinates;
    pub const FT_Set_Var_Design_Coordinates = __root.FT_Set_Var_Design_Coordinates;
    pub const FT_Get_Var_Design_Coordinates = __root.FT_Get_Var_Design_Coordinates;
    pub const FT_Set_MM_Blend_Coordinates = __root.FT_Set_MM_Blend_Coordinates;
    pub const FT_Get_MM_Blend_Coordinates = __root.FT_Get_MM_Blend_Coordinates;
    pub const FT_Set_Var_Blend_Coordinates = __root.FT_Set_Var_Blend_Coordinates;
    pub const FT_Get_Var_Blend_Coordinates = __root.FT_Get_Var_Blend_Coordinates;
    pub const FT_Set_MM_WeightVector = __root.FT_Set_MM_WeightVector;
    pub const FT_Get_MM_WeightVector = __root.FT_Get_MM_WeightVector;
    pub const FT_Set_Named_Instance = __root.FT_Set_Named_Instance;
    pub const FT_Get_Default_Named_Instance = __root.FT_Get_Default_Named_Instance;
    pub const FT_Get_Sfnt_Name_Count = __root.FT_Get_Sfnt_Name_Count;
    pub const FT_Get_Sfnt_Name = __root.FT_Get_Sfnt_Name;
    pub const FT_Get_Sfnt_LangTag = __root.FT_Get_Sfnt_LangTag;
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
    pub const Table = __root.FT_Get_Sfnt_Table;
    pub const Info = __root.FT_Sfnt_Table_Info;
    pub const Master = __root.FT_Get_Multi_Master;
    pub const Var = __root.FT_Get_MM_Var;
    pub const Coordinates = __root.FT_Set_MM_Design_Coordinates;
    pub const WeightVector = __root.FT_Set_MM_WeightVector;
    pub const Instance = __root.FT_Set_Named_Instance;
    pub const Count = __root.FT_Get_Sfnt_Name_Count;
    pub const LangTag = __root.FT_Get_Sfnt_LangTag;
};
pub const FT_CharMapRec = struct_FT_CharMapRec_;
pub const FT_FaceRec = struct_FT_FaceRec_;
pub const FT_SizeRec = struct_FT_SizeRec_;
pub const FT_GlyphSlotRec = struct_FT_GlyphSlotRec_;
pub var FT_Init_FreeType: *const fn (alibrary: [*c]FT_Library) callconv(.c) FT_Error = undefined;
pub var FT_Done_FreeType: *const fn (library: FT_Library) callconv(.c) FT_Error = undefined;
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
pub var FT_New_Face: *const fn (library: FT_Library, filepathname: [*c]const u8, face_index: FT_Long, aface: [*c]FT_Face) callconv(.c) FT_Error = undefined;
pub var FT_New_Memory_Face: *const fn (library: FT_Library, file_base: [*c]const FT_Byte, file_size: FT_Long, face_index: FT_Long, aface: [*c]FT_Face) callconv(.c) FT_Error = undefined;
pub var FT_Open_Face: *const fn (library: FT_Library, args: [*c]const FT_Open_Args, face_index: FT_Long, aface: [*c]FT_Face) callconv(.c) FT_Error = undefined;
pub var FT_Attach_File: *const fn (face: FT_Face, filepathname: [*c]const u8) callconv(.c) FT_Error = undefined;
pub var FT_Attach_Stream: *const fn (face: FT_Face, parameters: [*c]const FT_Open_Args) callconv(.c) FT_Error = undefined;
pub var FT_Reference_Face: *const fn (face: FT_Face) callconv(.c) FT_Error = undefined;
pub var FT_Done_Face: *const fn (face: FT_Face) callconv(.c) FT_Error = undefined;
pub var FT_Select_Size: *const fn (face: FT_Face, strike_index: FT_Int) callconv(.c) FT_Error = undefined;
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
pub var FT_Request_Size: *const fn (face: FT_Face, req: FT_Size_Request) callconv(.c) FT_Error = undefined;
pub var FT_Set_Char_Size: *const fn (face: FT_Face, char_width: FT_F26Dot6, char_height: FT_F26Dot6, horz_resolution: FT_UInt, vert_resolution: FT_UInt) callconv(.c) FT_Error = undefined;
pub var FT_Set_Pixel_Sizes: *const fn (face: FT_Face, pixel_width: FT_UInt, pixel_height: FT_UInt) callconv(.c) FT_Error = undefined;
pub var FT_Load_Glyph: *const fn (face: FT_Face, glyph_index: FT_UInt, load_flags: FT_Int32) callconv(.c) FT_Error = undefined;
pub var FT_Load_Char: *const fn (face: FT_Face, char_code: FT_ULong, load_flags: FT_Int32) callconv(.c) FT_Error = undefined;
pub var FT_Set_Transform: *const fn (face: FT_Face, matrix: [*c]FT_Matrix, delta: [*c]FT_Vector) callconv(.c) void = undefined;
pub var FT_Get_Transform: *const fn (face: FT_Face, matrix: [*c]FT_Matrix, delta: [*c]FT_Vector) callconv(.c) void = undefined;
pub const FT_RENDER_MODE_NORMAL: c_int = 0;
pub const FT_RENDER_MODE_LIGHT: c_int = 1;
pub const FT_RENDER_MODE_MONO: c_int = 2;
pub const FT_RENDER_MODE_LCD: c_int = 3;
pub const FT_RENDER_MODE_LCD_V: c_int = 4;
pub const FT_RENDER_MODE_SDF: c_int = 5;
pub const FT_RENDER_MODE_MAX: c_int = 6;
pub const enum_FT_Render_Mode_ = c_uint;
pub const FT_Render_Mode = enum_FT_Render_Mode_;
pub var FT_Render_Glyph: *const fn (slot: FT_GlyphSlot, render_mode: FT_Render_Mode) callconv(.c) FT_Error = undefined;
pub const FT_KERNING_DEFAULT: c_int = 0;
pub const FT_KERNING_UNFITTED: c_int = 1;
pub const FT_KERNING_UNSCALED: c_int = 2;
pub const enum_FT_Kerning_Mode_ = c_uint;
pub const FT_Kerning_Mode = enum_FT_Kerning_Mode_;
pub var FT_Get_Kerning: *const fn (face: FT_Face, left_glyph: FT_UInt, right_glyph: FT_UInt, kern_mode: FT_UInt, akerning: [*c]FT_Vector) callconv(.c) FT_Error = undefined;
pub var FT_Get_Track_Kerning: *const fn (face: FT_Face, point_size: FT_Fixed, degree: FT_Int, akerning: [*c]FT_Fixed) callconv(.c) FT_Error = undefined;
pub var FT_Select_Charmap: *const fn (face: FT_Face, encoding: FT_Encoding) callconv(.c) FT_Error = undefined;
pub var FT_Set_Charmap: *const fn (face: FT_Face, charmap: FT_CharMap) callconv(.c) FT_Error = undefined;
pub var FT_Get_Charmap_Index: *const fn (charmap: FT_CharMap) callconv(.c) FT_Int = undefined;
pub var FT_Get_Char_Index: *const fn (face: FT_Face, charcode: FT_ULong) callconv(.c) FT_UInt = undefined;
pub var FT_Get_First_Char: *const fn (face: FT_Face, agindex: [*c]FT_UInt) callconv(.c) FT_ULong = undefined;
pub var FT_Get_Next_Char: *const fn (face: FT_Face, char_code: FT_ULong, agindex: [*c]FT_UInt) callconv(.c) FT_ULong = undefined;
pub var FT_Face_Properties: *const fn (face: FT_Face, num_properties: FT_UInt, properties: [*c]FT_Parameter) callconv(.c) FT_Error = undefined;
pub var FT_Get_Name_Index: *const fn (face: FT_Face, glyph_name: [*c]const FT_String) callconv(.c) FT_UInt = undefined;
pub var FT_Get_Glyph_Name: *const fn (face: FT_Face, glyph_index: FT_UInt, buffer: FT_Pointer, buffer_max: FT_UInt) callconv(.c) FT_Error = undefined;
pub var FT_Get_Postscript_Name: *const fn (face: FT_Face) callconv(.c) [*c]const u8 = undefined;
pub var FT_Get_SubGlyph_Info: *const fn (glyph: FT_GlyphSlot, sub_index: FT_UInt, p_index: [*c]FT_Int, p_flags: [*c]FT_UInt, p_arg1: [*c]FT_Int, p_arg2: [*c]FT_Int, p_transform: [*c]FT_Matrix) callconv(.c) FT_Error = undefined;
pub var FT_Get_FSType_Flags: *const fn (face: FT_Face) callconv(.c) FT_UShort = undefined;
pub var FT_Face_GetCharVariantIndex: *const fn (face: FT_Face, charcode: FT_ULong, variantSelector: FT_ULong) callconv(.c) FT_UInt = undefined;
pub var FT_Face_GetCharVariantIsDefault: *const fn (face: FT_Face, charcode: FT_ULong, variantSelector: FT_ULong) callconv(.c) FT_Int = undefined;
pub var FT_Face_GetVariantSelectors: *const fn (face: FT_Face) callconv(.c) [*c]FT_UInt32 = undefined;
pub var FT_Face_GetVariantsOfChar: *const fn (face: FT_Face, charcode: FT_ULong) callconv(.c) [*c]FT_UInt32 = undefined;
pub var FT_Face_GetCharsOfVariant: *const fn (face: FT_Face, variantSelector: FT_ULong) callconv(.c) [*c]FT_UInt32 = undefined;
pub var FT_MulDiv: *const fn (a: FT_Long, b: FT_Long, c: FT_Long) callconv(.c) FT_Long = undefined;
pub var FT_MulFix: *const fn (a: FT_Long, b: FT_Long) callconv(.c) FT_Long = undefined;
pub var FT_DivFix: *const fn (a: FT_Long, b: FT_Long) callconv(.c) FT_Long = undefined;
pub var FT_RoundFix: *const fn (a: FT_Fixed) callconv(.c) FT_Fixed = undefined;
pub var FT_CeilFix: *const fn (a: FT_Fixed) callconv(.c) FT_Fixed = undefined;
pub var FT_FloorFix: *const fn (a: FT_Fixed) callconv(.c) FT_Fixed = undefined;
pub var FT_Vector_Transform: *const fn (vector: [*c]FT_Vector, matrix: [*c]const FT_Matrix) callconv(.c) void = undefined;
pub var FT_Library_Version: *const fn (library: FT_Library, amajor: [*c]FT_Int, aminor: [*c]FT_Int, apatch: [*c]FT_Int) callconv(.c) void = undefined;
pub var FT_Face_CheckTrueTypePatents: *const fn (face: FT_Face) callconv(.c) FT_Bool = undefined;
pub var FT_Face_SetUnpatentedHinting: *const fn (face: FT_Face, value: FT_Bool) callconv(.c) FT_Bool = undefined;
pub const struct_TT_Header_ = extern struct {
    Table_Version: FT_Fixed = 0,
    Font_Revision: FT_Fixed = 0,
    CheckSum_Adjust: FT_Long = 0,
    Magic_Number: FT_Long = 0,
    Flags: FT_UShort = 0,
    Units_Per_EM: FT_UShort = 0,
    Created: [2]FT_ULong = @import("std").mem.zeroes([2]FT_ULong),
    Modified: [2]FT_ULong = @import("std").mem.zeroes([2]FT_ULong),
    xMin: FT_Short = 0,
    yMin: FT_Short = 0,
    xMax: FT_Short = 0,
    yMax: FT_Short = 0,
    Mac_Style: FT_UShort = 0,
    Lowest_Rec_PPEM: FT_UShort = 0,
    Font_Direction: FT_Short = 0,
    Index_To_Loc_Format: FT_Short = 0,
    Glyph_Data_Format: FT_Short = 0,
};
pub const TT_Header = struct_TT_Header_;
pub const struct_TT_HoriHeader_ = extern struct {
    Version: FT_Fixed = 0,
    Ascender: FT_Short = 0,
    Descender: FT_Short = 0,
    Line_Gap: FT_Short = 0,
    advance_Width_Max: FT_UShort = 0,
    min_Left_Side_Bearing: FT_Short = 0,
    min_Right_Side_Bearing: FT_Short = 0,
    xMax_Extent: FT_Short = 0,
    caret_Slope_Rise: FT_Short = 0,
    caret_Slope_Run: FT_Short = 0,
    caret_Offset: FT_Short = 0,
    Reserved: [4]FT_Short = @import("std").mem.zeroes([4]FT_Short),
    metric_Data_Format: FT_Short = 0,
    number_Of_HMetrics: FT_UShort = 0,
    long_metrics: ?*anyopaque = null,
    short_metrics: ?*anyopaque = null,
};
pub const TT_HoriHeader = struct_TT_HoriHeader_;
pub const struct_TT_VertHeader_ = extern struct {
    Version: FT_Fixed = 0,
    Ascender: FT_Short = 0,
    Descender: FT_Short = 0,
    Line_Gap: FT_Short = 0,
    advance_Height_Max: FT_UShort = 0,
    min_Top_Side_Bearing: FT_Short = 0,
    min_Bottom_Side_Bearing: FT_Short = 0,
    yMax_Extent: FT_Short = 0,
    caret_Slope_Rise: FT_Short = 0,
    caret_Slope_Run: FT_Short = 0,
    caret_Offset: FT_Short = 0,
    Reserved: [4]FT_Short = @import("std").mem.zeroes([4]FT_Short),
    metric_Data_Format: FT_Short = 0,
    number_Of_VMetrics: FT_UShort = 0,
    long_metrics: ?*anyopaque = null,
    short_metrics: ?*anyopaque = null,
};
pub const TT_VertHeader = struct_TT_VertHeader_;
pub const struct_TT_OS2_ = extern struct {
    version: FT_UShort = 0,
    xAvgCharWidth: FT_Short = 0,
    usWeightClass: FT_UShort = 0,
    usWidthClass: FT_UShort = 0,
    fsType: FT_UShort = 0,
    ySubscriptXSize: FT_Short = 0,
    ySubscriptYSize: FT_Short = 0,
    ySubscriptXOffset: FT_Short = 0,
    ySubscriptYOffset: FT_Short = 0,
    ySuperscriptXSize: FT_Short = 0,
    ySuperscriptYSize: FT_Short = 0,
    ySuperscriptXOffset: FT_Short = 0,
    ySuperscriptYOffset: FT_Short = 0,
    yStrikeoutSize: FT_Short = 0,
    yStrikeoutPosition: FT_Short = 0,
    sFamilyClass: FT_Short = 0,
    panose: [10]FT_Byte = @import("std").mem.zeroes([10]FT_Byte),
    ulUnicodeRange1: FT_ULong = 0,
    ulUnicodeRange2: FT_ULong = 0,
    ulUnicodeRange3: FT_ULong = 0,
    ulUnicodeRange4: FT_ULong = 0,
    achVendID: [4]FT_Char = @import("std").mem.zeroes([4]FT_Char),
    fsSelection: FT_UShort = 0,
    usFirstCharIndex: FT_UShort = 0,
    usLastCharIndex: FT_UShort = 0,
    sTypoAscender: FT_Short = 0,
    sTypoDescender: FT_Short = 0,
    sTypoLineGap: FT_Short = 0,
    usWinAscent: FT_UShort = 0,
    usWinDescent: FT_UShort = 0,
    ulCodePageRange1: FT_ULong = 0,
    ulCodePageRange2: FT_ULong = 0,
    sxHeight: FT_Short = 0,
    sCapHeight: FT_Short = 0,
    usDefaultChar: FT_UShort = 0,
    usBreakChar: FT_UShort = 0,
    usMaxContext: FT_UShort = 0,
    usLowerOpticalPointSize: FT_UShort = 0,
    usUpperOpticalPointSize: FT_UShort = 0,
};
pub const TT_OS2 = struct_TT_OS2_;
pub const struct_TT_Postscript_ = extern struct {
    FormatType: FT_Fixed = 0,
    italicAngle: FT_Fixed = 0,
    underlinePosition: FT_Short = 0,
    underlineThickness: FT_Short = 0,
    isFixedPitch: FT_ULong = 0,
    minMemType42: FT_ULong = 0,
    maxMemType42: FT_ULong = 0,
    minMemType1: FT_ULong = 0,
    maxMemType1: FT_ULong = 0,
};
pub const TT_Postscript = struct_TT_Postscript_;
pub const struct_TT_PCLT_ = extern struct {
    Version: FT_Fixed = 0,
    FontNumber: FT_ULong = 0,
    Pitch: FT_UShort = 0,
    xHeight: FT_UShort = 0,
    Style: FT_UShort = 0,
    TypeFamily: FT_UShort = 0,
    CapHeight: FT_UShort = 0,
    SymbolSet: FT_UShort = 0,
    TypeFace: [16]FT_Char = @import("std").mem.zeroes([16]FT_Char),
    CharacterComplement: [8]FT_Char = @import("std").mem.zeroes([8]FT_Char),
    FileName: [6]FT_Char = @import("std").mem.zeroes([6]FT_Char),
    StrokeWeight: FT_Char = 0,
    WidthType: FT_Char = 0,
    SerifStyle: FT_Byte = 0,
    Reserved: FT_Byte = 0,
};
pub const TT_PCLT = struct_TT_PCLT_;
pub const struct_TT_MaxProfile_ = extern struct {
    version: FT_Fixed = 0,
    numGlyphs: FT_UShort = 0,
    maxPoints: FT_UShort = 0,
    maxContours: FT_UShort = 0,
    maxCompositePoints: FT_UShort = 0,
    maxCompositeContours: FT_UShort = 0,
    maxZones: FT_UShort = 0,
    maxTwilightPoints: FT_UShort = 0,
    maxStorage: FT_UShort = 0,
    maxFunctionDefs: FT_UShort = 0,
    maxInstructionDefs: FT_UShort = 0,
    maxStackElements: FT_UShort = 0,
    maxSizeOfInstructions: FT_UShort = 0,
    maxComponentElements: FT_UShort = 0,
    maxComponentDepth: FT_UShort = 0,
};
pub const TT_MaxProfile = struct_TT_MaxProfile_;
pub const FT_SFNT_HEAD: c_int = 0;
pub const FT_SFNT_MAXP: c_int = 1;
pub const FT_SFNT_OS2: c_int = 2;
pub const FT_SFNT_HHEA: c_int = 3;
pub const FT_SFNT_VHEA: c_int = 4;
pub const FT_SFNT_POST: c_int = 5;
pub const FT_SFNT_PCLT: c_int = 6;
pub const FT_SFNT_MAX: c_int = 7;
pub const enum_FT_Sfnt_Tag_ = c_uint;
pub const FT_Sfnt_Tag = enum_FT_Sfnt_Tag_;
pub var FT_Get_Sfnt_Table: *const fn (face: FT_Face, tag: FT_Sfnt_Tag) callconv(.c) ?*anyopaque = undefined;
pub var FT_Load_Sfnt_Table: *const fn (face: FT_Face, tag: FT_ULong, offset: FT_Long, buffer: [*c]FT_Byte, length: [*c]FT_ULong) callconv(.c) FT_Error = undefined;
pub var FT_Sfnt_Table_Info: *const fn (face: FT_Face, table_index: FT_UInt, tag: [*c]FT_ULong, length: [*c]FT_ULong) callconv(.c) FT_Error = undefined;
pub var FT_Get_CMap_Language_ID: *const fn (charmap: FT_CharMap) callconv(.c) FT_ULong = undefined;
pub var FT_Get_CMap_Format: *const fn (charmap: FT_CharMap) callconv(.c) FT_Long = undefined;
pub const struct_FT_MM_Axis_ = extern struct {
    name: [*c]FT_String = null,
    minimum: FT_Long = 0,
    maximum: FT_Long = 0,
};
pub const FT_MM_Axis = struct_FT_MM_Axis_;
pub const struct_FT_Multi_Master_ = extern struct {
    num_axis: FT_UInt = 0,
    num_designs: FT_UInt = 0,
    axis: [4]FT_MM_Axis = @import("std").mem.zeroes([4]FT_MM_Axis),
};
pub const FT_Multi_Master = struct_FT_Multi_Master_;
pub const struct_FT_Var_Axis_ = extern struct {
    name: [*c]FT_String = null,
    minimum: FT_Fixed = 0,
    def: FT_Fixed = 0,
    maximum: FT_Fixed = 0,
    tag: FT_ULong = 0,
    strid: FT_UInt = 0,
};
pub const FT_Var_Axis = struct_FT_Var_Axis_;
pub const struct_FT_Var_Named_Style_ = extern struct {
    coords: [*c]FT_Fixed = null,
    strid: FT_UInt = 0,
    psid: FT_UInt = 0,
};
pub const FT_Var_Named_Style = struct_FT_Var_Named_Style_;
pub const struct_FT_MM_Var_ = extern struct {
    num_axis: FT_UInt = 0,
    num_designs: FT_UInt = 0,
    num_namedstyles: FT_UInt = 0,
    axis: [*c]FT_Var_Axis = null,
    namedstyle: [*c]FT_Var_Named_Style = null,
    pub const FT_Get_Var_Axis_Flags = __root.FT_Get_Var_Axis_Flags;
    pub const Flags = __root.FT_Get_Var_Axis_Flags;
};
pub const FT_MM_Var = struct_FT_MM_Var_;
pub var FT_Get_Multi_Master: *const fn (face: FT_Face, amaster: [*c]FT_Multi_Master) callconv(.c) FT_Error = undefined;
pub var FT_Get_MM_Var: *const fn (face: FT_Face, amaster: [*c][*c]FT_MM_Var) callconv(.c) FT_Error = undefined;
pub var FT_Done_MM_Var: *const fn (library: FT_Library, amaster: [*c]FT_MM_Var) callconv(.c) FT_Error = undefined;
pub var FT_Set_MM_Design_Coordinates: *const fn (face: FT_Face, num_coords: FT_UInt, coords: [*c]FT_Long) callconv(.c) FT_Error = undefined;
pub var FT_Set_Var_Design_Coordinates: *const fn (face: FT_Face, num_coords: FT_UInt, coords: [*c]FT_Fixed) callconv(.c) FT_Error = undefined;
pub var FT_Get_Var_Design_Coordinates: *const fn (face: FT_Face, num_coords: FT_UInt, coords: [*c]FT_Fixed) callconv(.c) FT_Error = undefined;
pub var FT_Set_MM_Blend_Coordinates: *const fn (face: FT_Face, num_coords: FT_UInt, coords: [*c]FT_Fixed) callconv(.c) FT_Error = undefined;
pub var FT_Get_MM_Blend_Coordinates: *const fn (face: FT_Face, num_coords: FT_UInt, coords: [*c]FT_Fixed) callconv(.c) FT_Error = undefined;
pub var FT_Set_Var_Blend_Coordinates: *const fn (face: FT_Face, num_coords: FT_UInt, coords: [*c]FT_Fixed) callconv(.c) FT_Error = undefined;
pub var FT_Get_Var_Blend_Coordinates: *const fn (face: FT_Face, num_coords: FT_UInt, coords: [*c]FT_Fixed) callconv(.c) FT_Error = undefined;
pub var FT_Set_MM_WeightVector: *const fn (face: FT_Face, len: FT_UInt, weightvector: [*c]FT_Fixed) callconv(.c) FT_Error = undefined;
pub var FT_Get_MM_WeightVector: *const fn (face: FT_Face, len: [*c]FT_UInt, weightvector: [*c]FT_Fixed) callconv(.c) FT_Error = undefined;
pub var FT_Get_Var_Axis_Flags: *const fn (master: [*c]FT_MM_Var, axis_index: FT_UInt, flags: [*c]FT_UInt) callconv(.c) FT_Error = undefined;
pub var FT_Set_Named_Instance: *const fn (face: FT_Face, instance_index: FT_UInt) callconv(.c) FT_Error = undefined;
pub var FT_Get_Default_Named_Instance: *const fn (face: FT_Face, instance_index: [*c]FT_UInt) callconv(.c) FT_Error = undefined;
pub var FT_Outline_Decompose: *const fn (outline: [*c]FT_Outline, func_interface: [*c]const FT_Outline_Funcs, user: ?*anyopaque) callconv(.c) FT_Error = undefined;
pub var FT_Outline_New: *const fn (library: FT_Library, numPoints: FT_UInt, numContours: FT_Int, anoutline: [*c]FT_Outline) callconv(.c) FT_Error = undefined;
pub var FT_Outline_New_Internal: *const fn (memory: FT_Memory, numPoints: FT_UInt, numContours: FT_Int, anoutline: [*c]FT_Outline) callconv(.c) FT_Error = undefined;
pub var FT_Outline_Done: *const fn (library: FT_Library, outline: [*c]FT_Outline) callconv(.c) FT_Error = undefined;
pub var FT_Outline_Done_Internal: *const fn (memory: FT_Memory, outline: [*c]FT_Outline) callconv(.c) FT_Error = undefined;
pub var FT_Outline_Check: *const fn (outline: [*c]FT_Outline) callconv(.c) FT_Error = undefined;
pub var FT_Outline_Get_CBox: *const fn (outline: [*c]const FT_Outline, acbox: [*c]FT_BBox) callconv(.c) void = undefined;
pub var FT_Outline_Translate: *const fn (outline: [*c]const FT_Outline, xOffset: FT_Pos, yOffset: FT_Pos) callconv(.c) void = undefined;
pub var FT_Outline_Copy: *const fn (source: [*c]const FT_Outline, target: [*c]FT_Outline) callconv(.c) FT_Error = undefined;
pub var FT_Outline_Transform: *const fn (outline: [*c]const FT_Outline, matrix: [*c]const FT_Matrix) callconv(.c) void = undefined;
pub var FT_Outline_Embolden: *const fn (outline: [*c]FT_Outline, strength: FT_Pos) callconv(.c) FT_Error = undefined;
pub var FT_Outline_EmboldenXY: *const fn (outline: [*c]FT_Outline, xstrength: FT_Pos, ystrength: FT_Pos) callconv(.c) FT_Error = undefined;
pub var FT_Outline_Reverse: *const fn (outline: [*c]FT_Outline) callconv(.c) void = undefined;
pub var FT_Outline_Get_Bitmap: *const fn (library: FT_Library, outline: [*c]FT_Outline, abitmap: [*c]const FT_Bitmap) callconv(.c) FT_Error = undefined;
pub var FT_Outline_Render: *const fn (library: FT_Library, outline: [*c]FT_Outline, params: [*c]FT_Raster_Params) callconv(.c) FT_Error = undefined;
pub const FT_ORIENTATION_TRUETYPE: c_int = 0;
pub const FT_ORIENTATION_POSTSCRIPT: c_int = 1;
pub const FT_ORIENTATION_FILL_RIGHT: c_int = 0;
pub const FT_ORIENTATION_FILL_LEFT: c_int = 1;
pub const FT_ORIENTATION_NONE: c_int = 2;
pub const enum_FT_Orientation_ = c_uint;
pub const FT_Orientation = enum_FT_Orientation_;
pub var FT_Outline_Get_Orientation: *const fn (outline: [*c]FT_Outline) callconv(.c) FT_Orientation = undefined;
pub const struct_FT_SfntName_ = extern struct {
    platform_id: FT_UShort = 0,
    encoding_id: FT_UShort = 0,
    language_id: FT_UShort = 0,
    name_id: FT_UShort = 0,
    string: [*c]FT_Byte = null,
    string_len: FT_UInt = 0,
};
pub const FT_SfntName = struct_FT_SfntName_;
pub var FT_Get_Sfnt_Name_Count: *const fn (face: FT_Face) callconv(.c) FT_UInt = undefined;
pub var FT_Get_Sfnt_Name: *const fn (face: FT_Face, idx: FT_UInt, aname: [*c]FT_SfntName) callconv(.c) FT_Error = undefined;
pub const struct_FT_SfntLangTag_ = extern struct {
    string: [*c]FT_Byte = null,
    string_len: FT_UInt = 0,
};
pub const FT_SfntLangTag = struct_FT_SfntLangTag_;
pub var FT_Get_Sfnt_LangTag: *const fn (face: FT_Face, langID: FT_UInt, alangTag: [*c]FT_SfntLangTag) callconv(.c) FT_Error = undefined;

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
pub const __INT64_C = __helpers.L_SUFFIX;
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
pub const __UINT64_C = __helpers.UL_SUFFIX;
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
pub const __WORDSIZE = @as(c_int, 64);
pub const __WORDSIZE_TIME64_COMPAT32 = @as(c_int, 1);
pub const __SYSCALL_WORDSIZE = @as(c_int, 64);
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
pub const __STDC_VERSION_STDDEF_H__ = @as(c_long, 202311);
pub const NULL = __helpers.cast(?*anyopaque, @as(c_int, 0));
pub const offsetof = @compileError("unable to translate macro: undefined identifier `__builtin_offsetof`"); // /home/addo/.zvm/master/lib/compiler/aro/include/stddef.h:18:9
pub const ft_ptrdiff_t = ptrdiff_t;
pub const _LIBC_LIMITS_H_ = @as(c_int, 1);
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
pub const _BITS_STDINT_INTN_H = @as(c_int, 1);
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
pub const TTTABLES_H_ = "";
pub const ft_sfnt_head = FT_SFNT_HEAD;
pub const ft_sfnt_maxp = FT_SFNT_MAXP;
pub const ft_sfnt_os2 = FT_SFNT_OS2;
pub const ft_sfnt_hhea = FT_SFNT_HHEA;
pub const ft_sfnt_vhea = FT_SFNT_VHEA;
pub const ft_sfnt_post = FT_SFNT_POST;
pub const ft_sfnt_pclt = FT_SFNT_PCLT;
pub const FTMM_H_ = "";
pub const T1_MAX_MM_AXIS = @as(c_int, 4);
pub const T1_MAX_MM_DESIGNS = @as(c_int, 16);
pub const T1_MAX_MM_MAP_POINTS = @as(c_int, 20);
pub const FT_VAR_AXIS_FLAG_HIDDEN = @as(c_int, 1);
pub const FTOUTLN_H_ = "";
pub const FTSNAMES_H_ = "";
pub const FTPARAMS_H_ = "";
pub const FT_PARAM_TAG_IGNORE_TYPOGRAPHIC_FAMILY = FT_MAKE_TAG('i', 'g', 'p', 'f');
pub const FT_PARAM_TAG_IGNORE_PREFERRED_FAMILY = FT_PARAM_TAG_IGNORE_TYPOGRAPHIC_FAMILY;
pub const FT_PARAM_TAG_IGNORE_TYPOGRAPHIC_SUBFAMILY = FT_MAKE_TAG('i', 'g', 'p', 's');
pub const FT_PARAM_TAG_IGNORE_PREFERRED_SUBFAMILY = FT_PARAM_TAG_IGNORE_TYPOGRAPHIC_SUBFAMILY;
pub const FT_PARAM_TAG_INCREMENTAL = FT_MAKE_TAG('i', 'n', 'c', 'r');
pub const FT_PARAM_TAG_IGNORE_SBIX = FT_MAKE_TAG('i', 's', 'b', 'x');
pub const FT_PARAM_TAG_LCD_FILTER_WEIGHTS = FT_MAKE_TAG('l', 'c', 'd', 'f');
pub const FT_PARAM_TAG_RANDOM_SEED = FT_MAKE_TAG('s', 'e', 'e', 'd');
pub const FT_PARAM_TAG_STEM_DARKENING = FT_MAKE_TAG('d', 'a', 'r', 'k');
pub const FT_PARAM_TAG_UNPATENTED_HINTING = FT_MAKE_TAG('u', 'n', 'p', 'a');
pub const TTNAMEID_H_ = "";
pub const TT_PLATFORM_APPLE_UNICODE = @as(c_int, 0);
pub const TT_PLATFORM_MACINTOSH = @as(c_int, 1);
pub const TT_PLATFORM_ISO = @as(c_int, 2);
pub const TT_PLATFORM_MICROSOFT = @as(c_int, 3);
pub const TT_PLATFORM_CUSTOM = @as(c_int, 4);
pub const TT_PLATFORM_ADOBE = @as(c_int, 7);
pub const TT_APPLE_ID_DEFAULT = @as(c_int, 0);
pub const TT_APPLE_ID_UNICODE_1_1 = @as(c_int, 1);
pub const TT_APPLE_ID_ISO_10646 = @as(c_int, 2);
pub const TT_APPLE_ID_UNICODE_2_0 = @as(c_int, 3);
pub const TT_APPLE_ID_UNICODE_32 = @as(c_int, 4);
pub const TT_APPLE_ID_VARIANT_SELECTOR = @as(c_int, 5);
pub const TT_APPLE_ID_FULL_UNICODE = @as(c_int, 6);
pub const TT_MAC_ID_ROMAN = @as(c_int, 0);
pub const TT_MAC_ID_JAPANESE = @as(c_int, 1);
pub const TT_MAC_ID_TRADITIONAL_CHINESE = @as(c_int, 2);
pub const TT_MAC_ID_KOREAN = @as(c_int, 3);
pub const TT_MAC_ID_ARABIC = @as(c_int, 4);
pub const TT_MAC_ID_HEBREW = @as(c_int, 5);
pub const TT_MAC_ID_GREEK = @as(c_int, 6);
pub const TT_MAC_ID_RUSSIAN = @as(c_int, 7);
pub const TT_MAC_ID_RSYMBOL = @as(c_int, 8);
pub const TT_MAC_ID_DEVANAGARI = @as(c_int, 9);
pub const TT_MAC_ID_GURMUKHI = @as(c_int, 10);
pub const TT_MAC_ID_GUJARATI = @as(c_int, 11);
pub const TT_MAC_ID_ORIYA = @as(c_int, 12);
pub const TT_MAC_ID_BENGALI = @as(c_int, 13);
pub const TT_MAC_ID_TAMIL = @as(c_int, 14);
pub const TT_MAC_ID_TELUGU = @as(c_int, 15);
pub const TT_MAC_ID_KANNADA = @as(c_int, 16);
pub const TT_MAC_ID_MALAYALAM = @as(c_int, 17);
pub const TT_MAC_ID_SINHALESE = @as(c_int, 18);
pub const TT_MAC_ID_BURMESE = @as(c_int, 19);
pub const TT_MAC_ID_KHMER = @as(c_int, 20);
pub const TT_MAC_ID_THAI = @as(c_int, 21);
pub const TT_MAC_ID_LAOTIAN = @as(c_int, 22);
pub const TT_MAC_ID_GEORGIAN = @as(c_int, 23);
pub const TT_MAC_ID_ARMENIAN = @as(c_int, 24);
pub const TT_MAC_ID_MALDIVIAN = @as(c_int, 25);
pub const TT_MAC_ID_SIMPLIFIED_CHINESE = @as(c_int, 25);
pub const TT_MAC_ID_TIBETAN = @as(c_int, 26);
pub const TT_MAC_ID_MONGOLIAN = @as(c_int, 27);
pub const TT_MAC_ID_GEEZ = @as(c_int, 28);
pub const TT_MAC_ID_SLAVIC = @as(c_int, 29);
pub const TT_MAC_ID_VIETNAMESE = @as(c_int, 30);
pub const TT_MAC_ID_SINDHI = @as(c_int, 31);
pub const TT_MAC_ID_UNINTERP = @as(c_int, 32);
pub const TT_ISO_ID_7BIT_ASCII = @as(c_int, 0);
pub const TT_ISO_ID_10646 = @as(c_int, 1);
pub const TT_ISO_ID_8859_1 = @as(c_int, 2);
pub const TT_MS_ID_SYMBOL_CS = @as(c_int, 0);
pub const TT_MS_ID_UNICODE_CS = @as(c_int, 1);
pub const TT_MS_ID_SJIS = @as(c_int, 2);
pub const TT_MS_ID_PRC = @as(c_int, 3);
pub const TT_MS_ID_BIG_5 = @as(c_int, 4);
pub const TT_MS_ID_WANSUNG = @as(c_int, 5);
pub const TT_MS_ID_JOHAB = @as(c_int, 6);
pub const TT_MS_ID_UCS_4 = @as(c_int, 10);
pub const TT_MS_ID_GB2312 = TT_MS_ID_PRC;
pub const TT_ADOBE_ID_STANDARD = @as(c_int, 0);
pub const TT_ADOBE_ID_EXPERT = @as(c_int, 1);
pub const TT_ADOBE_ID_CUSTOM = @as(c_int, 2);
pub const TT_ADOBE_ID_LATIN_1 = @as(c_int, 3);
pub const TT_MAC_LANGID_ENGLISH = @as(c_int, 0);
pub const TT_MAC_LANGID_FRENCH = @as(c_int, 1);
pub const TT_MAC_LANGID_GERMAN = @as(c_int, 2);
pub const TT_MAC_LANGID_ITALIAN = @as(c_int, 3);
pub const TT_MAC_LANGID_DUTCH = @as(c_int, 4);
pub const TT_MAC_LANGID_SWEDISH = @as(c_int, 5);
pub const TT_MAC_LANGID_SPANISH = @as(c_int, 6);
pub const TT_MAC_LANGID_DANISH = @as(c_int, 7);
pub const TT_MAC_LANGID_PORTUGUESE = @as(c_int, 8);
pub const TT_MAC_LANGID_NORWEGIAN = @as(c_int, 9);
pub const TT_MAC_LANGID_HEBREW = @as(c_int, 10);
pub const TT_MAC_LANGID_JAPANESE = @as(c_int, 11);
pub const TT_MAC_LANGID_ARABIC = @as(c_int, 12);
pub const TT_MAC_LANGID_FINNISH = @as(c_int, 13);
pub const TT_MAC_LANGID_GREEK = @as(c_int, 14);
pub const TT_MAC_LANGID_ICELANDIC = @as(c_int, 15);
pub const TT_MAC_LANGID_MALTESE = @as(c_int, 16);
pub const TT_MAC_LANGID_TURKISH = @as(c_int, 17);
pub const TT_MAC_LANGID_CROATIAN = @as(c_int, 18);
pub const TT_MAC_LANGID_CHINESE_TRADITIONAL = @as(c_int, 19);
pub const TT_MAC_LANGID_URDU = @as(c_int, 20);
pub const TT_MAC_LANGID_HINDI = @as(c_int, 21);
pub const TT_MAC_LANGID_THAI = @as(c_int, 22);
pub const TT_MAC_LANGID_KOREAN = @as(c_int, 23);
pub const TT_MAC_LANGID_LITHUANIAN = @as(c_int, 24);
pub const TT_MAC_LANGID_POLISH = @as(c_int, 25);
pub const TT_MAC_LANGID_HUNGARIAN = @as(c_int, 26);
pub const TT_MAC_LANGID_ESTONIAN = @as(c_int, 27);
pub const TT_MAC_LANGID_LETTISH = @as(c_int, 28);
pub const TT_MAC_LANGID_SAAMISK = @as(c_int, 29);
pub const TT_MAC_LANGID_FAEROESE = @as(c_int, 30);
pub const TT_MAC_LANGID_FARSI = @as(c_int, 31);
pub const TT_MAC_LANGID_RUSSIAN = @as(c_int, 32);
pub const TT_MAC_LANGID_CHINESE_SIMPLIFIED = @as(c_int, 33);
pub const TT_MAC_LANGID_FLEMISH = @as(c_int, 34);
pub const TT_MAC_LANGID_IRISH = @as(c_int, 35);
pub const TT_MAC_LANGID_ALBANIAN = @as(c_int, 36);
pub const TT_MAC_LANGID_ROMANIAN = @as(c_int, 37);
pub const TT_MAC_LANGID_CZECH = @as(c_int, 38);
pub const TT_MAC_LANGID_SLOVAK = @as(c_int, 39);
pub const TT_MAC_LANGID_SLOVENIAN = @as(c_int, 40);
pub const TT_MAC_LANGID_YIDDISH = @as(c_int, 41);
pub const TT_MAC_LANGID_SERBIAN = @as(c_int, 42);
pub const TT_MAC_LANGID_MACEDONIAN = @as(c_int, 43);
pub const TT_MAC_LANGID_BULGARIAN = @as(c_int, 44);
pub const TT_MAC_LANGID_UKRAINIAN = @as(c_int, 45);
pub const TT_MAC_LANGID_BYELORUSSIAN = @as(c_int, 46);
pub const TT_MAC_LANGID_UZBEK = @as(c_int, 47);
pub const TT_MAC_LANGID_KAZAKH = @as(c_int, 48);
pub const TT_MAC_LANGID_AZERBAIJANI = @as(c_int, 49);
pub const TT_MAC_LANGID_AZERBAIJANI_CYRILLIC_SCRIPT = @as(c_int, 49);
pub const TT_MAC_LANGID_AZERBAIJANI_ARABIC_SCRIPT = @as(c_int, 50);
pub const TT_MAC_LANGID_ARMENIAN = @as(c_int, 51);
pub const TT_MAC_LANGID_GEORGIAN = @as(c_int, 52);
pub const TT_MAC_LANGID_MOLDAVIAN = @as(c_int, 53);
pub const TT_MAC_LANGID_KIRGHIZ = @as(c_int, 54);
pub const TT_MAC_LANGID_TAJIKI = @as(c_int, 55);
pub const TT_MAC_LANGID_TURKMEN = @as(c_int, 56);
pub const TT_MAC_LANGID_MONGOLIAN = @as(c_int, 57);
pub const TT_MAC_LANGID_MONGOLIAN_MONGOLIAN_SCRIPT = @as(c_int, 57);
pub const TT_MAC_LANGID_MONGOLIAN_CYRILLIC_SCRIPT = @as(c_int, 58);
pub const TT_MAC_LANGID_PASHTO = @as(c_int, 59);
pub const TT_MAC_LANGID_KURDISH = @as(c_int, 60);
pub const TT_MAC_LANGID_KASHMIRI = @as(c_int, 61);
pub const TT_MAC_LANGID_SINDHI = @as(c_int, 62);
pub const TT_MAC_LANGID_TIBETAN = @as(c_int, 63);
pub const TT_MAC_LANGID_NEPALI = @as(c_int, 64);
pub const TT_MAC_LANGID_SANSKRIT = @as(c_int, 65);
pub const TT_MAC_LANGID_MARATHI = @as(c_int, 66);
pub const TT_MAC_LANGID_BENGALI = @as(c_int, 67);
pub const TT_MAC_LANGID_ASSAMESE = @as(c_int, 68);
pub const TT_MAC_LANGID_GUJARATI = @as(c_int, 69);
pub const TT_MAC_LANGID_PUNJABI = @as(c_int, 70);
pub const TT_MAC_LANGID_ORIYA = @as(c_int, 71);
pub const TT_MAC_LANGID_MALAYALAM = @as(c_int, 72);
pub const TT_MAC_LANGID_KANNADA = @as(c_int, 73);
pub const TT_MAC_LANGID_TAMIL = @as(c_int, 74);
pub const TT_MAC_LANGID_TELUGU = @as(c_int, 75);
pub const TT_MAC_LANGID_SINHALESE = @as(c_int, 76);
pub const TT_MAC_LANGID_BURMESE = @as(c_int, 77);
pub const TT_MAC_LANGID_KHMER = @as(c_int, 78);
pub const TT_MAC_LANGID_LAO = @as(c_int, 79);
pub const TT_MAC_LANGID_VIETNAMESE = @as(c_int, 80);
pub const TT_MAC_LANGID_INDONESIAN = @as(c_int, 81);
pub const TT_MAC_LANGID_TAGALOG = @as(c_int, 82);
pub const TT_MAC_LANGID_MALAY_ROMAN_SCRIPT = @as(c_int, 83);
pub const TT_MAC_LANGID_MALAY_ARABIC_SCRIPT = @as(c_int, 84);
pub const TT_MAC_LANGID_AMHARIC = @as(c_int, 85);
pub const TT_MAC_LANGID_TIGRINYA = @as(c_int, 86);
pub const TT_MAC_LANGID_GALLA = @as(c_int, 87);
pub const TT_MAC_LANGID_SOMALI = @as(c_int, 88);
pub const TT_MAC_LANGID_SWAHILI = @as(c_int, 89);
pub const TT_MAC_LANGID_RUANDA = @as(c_int, 90);
pub const TT_MAC_LANGID_RUNDI = @as(c_int, 91);
pub const TT_MAC_LANGID_CHEWA = @as(c_int, 92);
pub const TT_MAC_LANGID_MALAGASY = @as(c_int, 93);
pub const TT_MAC_LANGID_ESPERANTO = @as(c_int, 94);
pub const TT_MAC_LANGID_WELSH = @as(c_int, 128);
pub const TT_MAC_LANGID_BASQUE = @as(c_int, 129);
pub const TT_MAC_LANGID_CATALAN = @as(c_int, 130);
pub const TT_MAC_LANGID_LATIN = @as(c_int, 131);
pub const TT_MAC_LANGID_QUECHUA = @as(c_int, 132);
pub const TT_MAC_LANGID_GUARANI = @as(c_int, 133);
pub const TT_MAC_LANGID_AYMARA = @as(c_int, 134);
pub const TT_MAC_LANGID_TATAR = @as(c_int, 135);
pub const TT_MAC_LANGID_UIGHUR = @as(c_int, 136);
pub const TT_MAC_LANGID_DZONGKHA = @as(c_int, 137);
pub const TT_MAC_LANGID_JAVANESE = @as(c_int, 138);
pub const TT_MAC_LANGID_SUNDANESE = @as(c_int, 139);
pub const TT_MAC_LANGID_GALICIAN = @as(c_int, 140);
pub const TT_MAC_LANGID_AFRIKAANS = @as(c_int, 141);
pub const TT_MAC_LANGID_BRETON = @as(c_int, 142);
pub const TT_MAC_LANGID_INUKTITUT = @as(c_int, 143);
pub const TT_MAC_LANGID_SCOTTISH_GAELIC = @as(c_int, 144);
pub const TT_MAC_LANGID_MANX_GAELIC = @as(c_int, 145);
pub const TT_MAC_LANGID_IRISH_GAELIC = @as(c_int, 146);
pub const TT_MAC_LANGID_TONGAN = @as(c_int, 147);
pub const TT_MAC_LANGID_GREEK_POLYTONIC = @as(c_int, 148);
pub const TT_MAC_LANGID_GREELANDIC = @as(c_int, 149);
pub const TT_MAC_LANGID_AZERBAIJANI_ROMAN_SCRIPT = @as(c_int, 150);
pub const TT_MS_LANGID_ARABIC_SAUDI_ARABIA = @as(c_int, 0x0401);
pub const TT_MS_LANGID_ARABIC_IRAQ = @as(c_int, 0x0801);
pub const TT_MS_LANGID_ARABIC_EGYPT = @as(c_int, 0x0C01);
pub const TT_MS_LANGID_ARABIC_LIBYA = @as(c_int, 0x1001);
pub const TT_MS_LANGID_ARABIC_ALGERIA = @as(c_int, 0x1401);
pub const TT_MS_LANGID_ARABIC_MOROCCO = @as(c_int, 0x1801);
pub const TT_MS_LANGID_ARABIC_TUNISIA = @as(c_int, 0x1C01);
pub const TT_MS_LANGID_ARABIC_OMAN = @as(c_int, 0x2001);
pub const TT_MS_LANGID_ARABIC_YEMEN = @as(c_int, 0x2401);
pub const TT_MS_LANGID_ARABIC_SYRIA = @as(c_int, 0x2801);
pub const TT_MS_LANGID_ARABIC_JORDAN = @as(c_int, 0x2C01);
pub const TT_MS_LANGID_ARABIC_LEBANON = @as(c_int, 0x3001);
pub const TT_MS_LANGID_ARABIC_KUWAIT = @as(c_int, 0x3401);
pub const TT_MS_LANGID_ARABIC_UAE = @as(c_int, 0x3801);
pub const TT_MS_LANGID_ARABIC_BAHRAIN = @as(c_int, 0x3C01);
pub const TT_MS_LANGID_ARABIC_QATAR = @as(c_int, 0x4001);
pub const TT_MS_LANGID_BULGARIAN_BULGARIA = @as(c_int, 0x0402);
pub const TT_MS_LANGID_CATALAN_CATALAN = @as(c_int, 0x0403);
pub const TT_MS_LANGID_CHINESE_TAIWAN = @as(c_int, 0x0404);
pub const TT_MS_LANGID_CHINESE_PRC = @as(c_int, 0x0804);
pub const TT_MS_LANGID_CHINESE_HONG_KONG = @as(c_int, 0x0C04);
pub const TT_MS_LANGID_CHINESE_SINGAPORE = @as(c_int, 0x1004);
pub const TT_MS_LANGID_CHINESE_MACAO = @as(c_int, 0x1404);
pub const TT_MS_LANGID_CZECH_CZECH_REPUBLIC = @as(c_int, 0x0405);
pub const TT_MS_LANGID_DANISH_DENMARK = @as(c_int, 0x0406);
pub const TT_MS_LANGID_GERMAN_GERMANY = @as(c_int, 0x0407);
pub const TT_MS_LANGID_GERMAN_SWITZERLAND = @as(c_int, 0x0807);
pub const TT_MS_LANGID_GERMAN_AUSTRIA = @as(c_int, 0x0C07);
pub const TT_MS_LANGID_GERMAN_LUXEMBOURG = @as(c_int, 0x1007);
pub const TT_MS_LANGID_GERMAN_LIECHTENSTEIN = @as(c_int, 0x1407);
pub const TT_MS_LANGID_GREEK_GREECE = @as(c_int, 0x0408);
pub const TT_MS_LANGID_ENGLISH_UNITED_STATES = @as(c_int, 0x0409);
pub const TT_MS_LANGID_ENGLISH_UNITED_KINGDOM = @as(c_int, 0x0809);
pub const TT_MS_LANGID_ENGLISH_AUSTRALIA = @as(c_int, 0x0C09);
pub const TT_MS_LANGID_ENGLISH_CANADA = @as(c_int, 0x1009);
pub const TT_MS_LANGID_ENGLISH_NEW_ZEALAND = @as(c_int, 0x1409);
pub const TT_MS_LANGID_ENGLISH_IRELAND = @as(c_int, 0x1809);
pub const TT_MS_LANGID_ENGLISH_SOUTH_AFRICA = @as(c_int, 0x1C09);
pub const TT_MS_LANGID_ENGLISH_JAMAICA = @as(c_int, 0x2009);
pub const TT_MS_LANGID_ENGLISH_CARIBBEAN = @as(c_int, 0x2409);
pub const TT_MS_LANGID_ENGLISH_BELIZE = @as(c_int, 0x2809);
pub const TT_MS_LANGID_ENGLISH_TRINIDAD = @as(c_int, 0x2C09);
pub const TT_MS_LANGID_ENGLISH_ZIMBABWE = @as(c_int, 0x3009);
pub const TT_MS_LANGID_ENGLISH_PHILIPPINES = @as(c_int, 0x3409);
pub const TT_MS_LANGID_ENGLISH_INDIA = @as(c_int, 0x4009);
pub const TT_MS_LANGID_ENGLISH_MALAYSIA = @as(c_int, 0x4409);
pub const TT_MS_LANGID_ENGLISH_SINGAPORE = @as(c_int, 0x4809);
pub const TT_MS_LANGID_SPANISH_SPAIN_TRADITIONAL_SORT = @as(c_int, 0x040A);
pub const TT_MS_LANGID_SPANISH_MEXICO = @as(c_int, 0x080A);
pub const TT_MS_LANGID_SPANISH_SPAIN_MODERN_SORT = @as(c_int, 0x0C0A);
pub const TT_MS_LANGID_SPANISH_GUATEMALA = @as(c_int, 0x100A);
pub const TT_MS_LANGID_SPANISH_COSTA_RICA = @as(c_int, 0x140A);
pub const TT_MS_LANGID_SPANISH_PANAMA = @as(c_int, 0x180A);
pub const TT_MS_LANGID_SPANISH_DOMINICAN_REPUBLIC = @as(c_int, 0x1C0A);
pub const TT_MS_LANGID_SPANISH_VENEZUELA = @as(c_int, 0x200A);
pub const TT_MS_LANGID_SPANISH_COLOMBIA = @as(c_int, 0x240A);
pub const TT_MS_LANGID_SPANISH_PERU = @as(c_int, 0x280A);
pub const TT_MS_LANGID_SPANISH_ARGENTINA = @as(c_int, 0x2C0A);
pub const TT_MS_LANGID_SPANISH_ECUADOR = @as(c_int, 0x300A);
pub const TT_MS_LANGID_SPANISH_CHILE = @as(c_int, 0x340A);
pub const TT_MS_LANGID_SPANISH_URUGUAY = @as(c_int, 0x380A);
pub const TT_MS_LANGID_SPANISH_PARAGUAY = @as(c_int, 0x3C0A);
pub const TT_MS_LANGID_SPANISH_BOLIVIA = @as(c_int, 0x400A);
pub const TT_MS_LANGID_SPANISH_EL_SALVADOR = @as(c_int, 0x440A);
pub const TT_MS_LANGID_SPANISH_HONDURAS = @as(c_int, 0x480A);
pub const TT_MS_LANGID_SPANISH_NICARAGUA = @as(c_int, 0x4C0A);
pub const TT_MS_LANGID_SPANISH_PUERTO_RICO = @as(c_int, 0x500A);
pub const TT_MS_LANGID_SPANISH_UNITED_STATES = @as(c_int, 0x540A);
pub const TT_MS_LANGID_FINNISH_FINLAND = @as(c_int, 0x040B);
pub const TT_MS_LANGID_FRENCH_FRANCE = @as(c_int, 0x040C);
pub const TT_MS_LANGID_FRENCH_BELGIUM = @as(c_int, 0x080C);
pub const TT_MS_LANGID_FRENCH_CANADA = @as(c_int, 0x0C0C);
pub const TT_MS_LANGID_FRENCH_SWITZERLAND = @as(c_int, 0x100C);
pub const TT_MS_LANGID_FRENCH_LUXEMBOURG = @as(c_int, 0x140C);
pub const TT_MS_LANGID_FRENCH_MONACO = @as(c_int, 0x180C);
pub const TT_MS_LANGID_HEBREW_ISRAEL = @as(c_int, 0x040D);
pub const TT_MS_LANGID_HUNGARIAN_HUNGARY = @as(c_int, 0x040E);
pub const TT_MS_LANGID_ICELANDIC_ICELAND = @as(c_int, 0x040F);
pub const TT_MS_LANGID_ITALIAN_ITALY = @as(c_int, 0x0410);
pub const TT_MS_LANGID_ITALIAN_SWITZERLAND = @as(c_int, 0x0810);
pub const TT_MS_LANGID_JAPANESE_JAPAN = @as(c_int, 0x0411);
pub const TT_MS_LANGID_KOREAN_KOREA = @as(c_int, 0x0412);
pub const TT_MS_LANGID_DUTCH_NETHERLANDS = @as(c_int, 0x0413);
pub const TT_MS_LANGID_DUTCH_BELGIUM = @as(c_int, 0x0813);
pub const TT_MS_LANGID_NORWEGIAN_NORWAY_BOKMAL = @as(c_int, 0x0414);
pub const TT_MS_LANGID_NORWEGIAN_NORWAY_NYNORSK = @as(c_int, 0x0814);
pub const TT_MS_LANGID_POLISH_POLAND = @as(c_int, 0x0415);
pub const TT_MS_LANGID_PORTUGUESE_BRAZIL = @as(c_int, 0x0416);
pub const TT_MS_LANGID_PORTUGUESE_PORTUGAL = @as(c_int, 0x0816);
pub const TT_MS_LANGID_ROMANSH_SWITZERLAND = @as(c_int, 0x0417);
pub const TT_MS_LANGID_ROMANIAN_ROMANIA = @as(c_int, 0x0418);
pub const TT_MS_LANGID_RUSSIAN_RUSSIA = @as(c_int, 0x0419);
pub const TT_MS_LANGID_CROATIAN_CROATIA = @as(c_int, 0x041A);
pub const TT_MS_LANGID_SERBIAN_SERBIA_LATIN = @as(c_int, 0x081A);
pub const TT_MS_LANGID_SERBIAN_SERBIA_CYRILLIC = @as(c_int, 0x0C1A);
pub const TT_MS_LANGID_CROATIAN_BOSNIA_HERZEGOVINA = @as(c_int, 0x101A);
pub const TT_MS_LANGID_BOSNIAN_BOSNIA_HERZEGOVINA = @as(c_int, 0x141A);
pub const TT_MS_LANGID_SERBIAN_BOSNIA_HERZ_LATIN = @as(c_int, 0x181A);
pub const TT_MS_LANGID_SERBIAN_BOSNIA_HERZ_CYRILLIC = @as(c_int, 0x1C1A);
pub const TT_MS_LANGID_BOSNIAN_BOSNIA_HERZ_CYRILLIC = @as(c_int, 0x201A);
pub const TT_MS_LANGID_SLOVAK_SLOVAKIA = @as(c_int, 0x041B);
pub const TT_MS_LANGID_ALBANIAN_ALBANIA = @as(c_int, 0x041C);
pub const TT_MS_LANGID_SWEDISH_SWEDEN = @as(c_int, 0x041D);
pub const TT_MS_LANGID_SWEDISH_FINLAND = @as(c_int, 0x081D);
pub const TT_MS_LANGID_THAI_THAILAND = @as(c_int, 0x041E);
pub const TT_MS_LANGID_TURKISH_TURKEY = @as(c_int, 0x041F);
pub const TT_MS_LANGID_URDU_PAKISTAN = @as(c_int, 0x0420);
pub const TT_MS_LANGID_INDONESIAN_INDONESIA = @as(c_int, 0x0421);
pub const TT_MS_LANGID_UKRAINIAN_UKRAINE = @as(c_int, 0x0422);
pub const TT_MS_LANGID_BELARUSIAN_BELARUS = @as(c_int, 0x0423);
pub const TT_MS_LANGID_SLOVENIAN_SLOVENIA = @as(c_int, 0x0424);
pub const TT_MS_LANGID_ESTONIAN_ESTONIA = @as(c_int, 0x0425);
pub const TT_MS_LANGID_LATVIAN_LATVIA = @as(c_int, 0x0426);
pub const TT_MS_LANGID_LITHUANIAN_LITHUANIA = @as(c_int, 0x0427);
pub const TT_MS_LANGID_TAJIK_TAJIKISTAN = @as(c_int, 0x0428);
pub const TT_MS_LANGID_VIETNAMESE_VIET_NAM = @as(c_int, 0x042A);
pub const TT_MS_LANGID_ARMENIAN_ARMENIA = @as(c_int, 0x042B);
pub const TT_MS_LANGID_AZERI_AZERBAIJAN_LATIN = @as(c_int, 0x042C);
pub const TT_MS_LANGID_AZERI_AZERBAIJAN_CYRILLIC = @as(c_int, 0x082C);
pub const TT_MS_LANGID_BASQUE_BASQUE = @as(c_int, 0x042D);
pub const TT_MS_LANGID_UPPER_SORBIAN_GERMANY = @as(c_int, 0x042E);
pub const TT_MS_LANGID_LOWER_SORBIAN_GERMANY = @as(c_int, 0x082E);
pub const TT_MS_LANGID_MACEDONIAN_MACEDONIA = @as(c_int, 0x042F);
pub const TT_MS_LANGID_SETSWANA_SOUTH_AFRICA = @as(c_int, 0x0432);
pub const TT_MS_LANGID_ISIXHOSA_SOUTH_AFRICA = @as(c_int, 0x0434);
pub const TT_MS_LANGID_ISIZULU_SOUTH_AFRICA = @as(c_int, 0x0435);
pub const TT_MS_LANGID_AFRIKAANS_SOUTH_AFRICA = @as(c_int, 0x0436);
pub const TT_MS_LANGID_GEORGIAN_GEORGIA = @as(c_int, 0x0437);
pub const TT_MS_LANGID_FAEROESE_FAEROE_ISLANDS = @as(c_int, 0x0438);
pub const TT_MS_LANGID_HINDI_INDIA = @as(c_int, 0x0439);
pub const TT_MS_LANGID_MALTESE_MALTA = @as(c_int, 0x043A);
pub const TT_MS_LANGID_SAMI_NORTHERN_NORWAY = @as(c_int, 0x043B);
pub const TT_MS_LANGID_SAMI_NORTHERN_SWEDEN = @as(c_int, 0x083B);
pub const TT_MS_LANGID_SAMI_NORTHERN_FINLAND = @as(c_int, 0x0C3B);
pub const TT_MS_LANGID_SAMI_LULE_NORWAY = @as(c_int, 0x103B);
pub const TT_MS_LANGID_SAMI_LULE_SWEDEN = @as(c_int, 0x143B);
pub const TT_MS_LANGID_SAMI_SOUTHERN_NORWAY = @as(c_int, 0x183B);
pub const TT_MS_LANGID_SAMI_SOUTHERN_SWEDEN = @as(c_int, 0x1C3B);
pub const TT_MS_LANGID_SAMI_SKOLT_FINLAND = @as(c_int, 0x203B);
pub const TT_MS_LANGID_SAMI_INARI_FINLAND = @as(c_int, 0x243B);
pub const TT_MS_LANGID_IRISH_IRELAND = @as(c_int, 0x083C);
pub const TT_MS_LANGID_MALAY_MALAYSIA = @as(c_int, 0x043E);
pub const TT_MS_LANGID_MALAY_BRUNEI_DARUSSALAM = @as(c_int, 0x083E);
pub const TT_MS_LANGID_KAZAKH_KAZAKHSTAN = @as(c_int, 0x043F);
pub const TT_MS_LANGID_KYRGYZ_KYRGYZSTAN = @as(c_int, 0x0440);
pub const TT_MS_LANGID_KISWAHILI_KENYA = @as(c_int, 0x0441);
pub const TT_MS_LANGID_TURKMEN_TURKMENISTAN = @as(c_int, 0x0442);
pub const TT_MS_LANGID_UZBEK_UZBEKISTAN_LATIN = @as(c_int, 0x0443);
pub const TT_MS_LANGID_UZBEK_UZBEKISTAN_CYRILLIC = @as(c_int, 0x0843);
pub const TT_MS_LANGID_TATAR_RUSSIA = @as(c_int, 0x0444);
pub const TT_MS_LANGID_BENGALI_INDIA = @as(c_int, 0x0445);
pub const TT_MS_LANGID_BENGALI_BANGLADESH = @as(c_int, 0x0845);
pub const TT_MS_LANGID_PUNJABI_INDIA = @as(c_int, 0x0446);
pub const TT_MS_LANGID_GUJARATI_INDIA = @as(c_int, 0x0447);
pub const TT_MS_LANGID_ODIA_INDIA = @as(c_int, 0x0448);
pub const TT_MS_LANGID_TAMIL_INDIA = @as(c_int, 0x0449);
pub const TT_MS_LANGID_TELUGU_INDIA = @as(c_int, 0x044A);
pub const TT_MS_LANGID_KANNADA_INDIA = @as(c_int, 0x044B);
pub const TT_MS_LANGID_MALAYALAM_INDIA = @as(c_int, 0x044C);
pub const TT_MS_LANGID_ASSAMESE_INDIA = @as(c_int, 0x044D);
pub const TT_MS_LANGID_MARATHI_INDIA = @as(c_int, 0x044E);
pub const TT_MS_LANGID_SANSKRIT_INDIA = @as(c_int, 0x044F);
pub const TT_MS_LANGID_MONGOLIAN_MONGOLIA = @as(c_int, 0x0450);
pub const TT_MS_LANGID_MONGOLIAN_PRC = @as(c_int, 0x0850);
pub const TT_MS_LANGID_TIBETAN_PRC = @as(c_int, 0x0451);
pub const TT_MS_LANGID_WELSH_UNITED_KINGDOM = @as(c_int, 0x0452);
pub const TT_MS_LANGID_KHMER_CAMBODIA = @as(c_int, 0x0453);
pub const TT_MS_LANGID_LAO_LAOS = @as(c_int, 0x0454);
pub const TT_MS_LANGID_GALICIAN_GALICIAN = @as(c_int, 0x0456);
pub const TT_MS_LANGID_KONKANI_INDIA = @as(c_int, 0x0457);
pub const TT_MS_LANGID_SYRIAC_SYRIA = @as(c_int, 0x045A);
pub const TT_MS_LANGID_SINHALA_SRI_LANKA = @as(c_int, 0x045B);
pub const TT_MS_LANGID_INUKTITUT_CANADA = @as(c_int, 0x045D);
pub const TT_MS_LANGID_INUKTITUT_CANADA_LATIN = @as(c_int, 0x085D);
pub const TT_MS_LANGID_AMHARIC_ETHIOPIA = @as(c_int, 0x045E);
pub const TT_MS_LANGID_TAMAZIGHT_ALGERIA = @as(c_int, 0x085F);
pub const TT_MS_LANGID_NEPALI_NEPAL = @as(c_int, 0x0461);
pub const TT_MS_LANGID_FRISIAN_NETHERLANDS = @as(c_int, 0x0462);
pub const TT_MS_LANGID_PASHTO_AFGHANISTAN = @as(c_int, 0x0463);
pub const TT_MS_LANGID_FILIPINO_PHILIPPINES = @as(c_int, 0x0464);
pub const TT_MS_LANGID_DHIVEHI_MALDIVES = @as(c_int, 0x0465);
pub const TT_MS_LANGID_HAUSA_NIGERIA = @as(c_int, 0x0468);
pub const TT_MS_LANGID_YORUBA_NIGERIA = @as(c_int, 0x046A);
pub const TT_MS_LANGID_QUECHUA_BOLIVIA = @as(c_int, 0x046B);
pub const TT_MS_LANGID_QUECHUA_ECUADOR = @as(c_int, 0x086B);
pub const TT_MS_LANGID_QUECHUA_PERU = @as(c_int, 0x0C6B);
pub const TT_MS_LANGID_SESOTHO_SA_LEBOA_SOUTH_AFRICA = @as(c_int, 0x046C);
pub const TT_MS_LANGID_BASHKIR_RUSSIA = @as(c_int, 0x046D);
pub const TT_MS_LANGID_LUXEMBOURGISH_LUXEMBOURG = @as(c_int, 0x046E);
pub const TT_MS_LANGID_GREENLANDIC_GREENLAND = @as(c_int, 0x046F);
pub const TT_MS_LANGID_IGBO_NIGERIA = @as(c_int, 0x0470);
pub const TT_MS_LANGID_YI_PRC = @as(c_int, 0x0478);
pub const TT_MS_LANGID_MAPUDUNGUN_CHILE = @as(c_int, 0x047A);
pub const TT_MS_LANGID_MOHAWK_MOHAWK = @as(c_int, 0x047C);
pub const TT_MS_LANGID_BRETON_FRANCE = @as(c_int, 0x047E);
pub const TT_MS_LANGID_UIGHUR_PRC = @as(c_int, 0x0480);
pub const TT_MS_LANGID_MAORI_NEW_ZEALAND = @as(c_int, 0x0481);
pub const TT_MS_LANGID_OCCITAN_FRANCE = @as(c_int, 0x0482);
pub const TT_MS_LANGID_CORSICAN_FRANCE = @as(c_int, 0x0483);
pub const TT_MS_LANGID_ALSATIAN_FRANCE = @as(c_int, 0x0484);
pub const TT_MS_LANGID_YAKUT_RUSSIA = @as(c_int, 0x0485);
pub const TT_MS_LANGID_KICHE_GUATEMALA = @as(c_int, 0x0486);
pub const TT_MS_LANGID_KINYARWANDA_RWANDA = @as(c_int, 0x0487);
pub const TT_MS_LANGID_WOLOF_SENEGAL = @as(c_int, 0x0488);
pub const TT_MS_LANGID_DARI_AFGHANISTAN = @as(c_int, 0x048C);
pub const TT_MS_LANGID_ARABIC_GENERAL = @as(c_int, 0x0001);
pub const TT_MS_LANGID_CATALAN_SPAIN = TT_MS_LANGID_CATALAN_CATALAN;
pub const TT_MS_LANGID_CHINESE_GENERAL = @as(c_int, 0x0004);
pub const TT_MS_LANGID_CHINESE_MACAU = TT_MS_LANGID_CHINESE_MACAO;
pub const TT_MS_LANGID_GERMAN_LIECHTENSTEI = TT_MS_LANGID_GERMAN_LIECHTENSTEIN;
pub const TT_MS_LANGID_ENGLISH_GENERAL = @as(c_int, 0x0009);
pub const TT_MS_LANGID_ENGLISH_INDONESIA = @as(c_int, 0x3809);
pub const TT_MS_LANGID_ENGLISH_HONG_KONG = @as(c_int, 0x3C09);
pub const TT_MS_LANGID_SPANISH_SPAIN_INTERNATIONAL_SORT = TT_MS_LANGID_SPANISH_SPAIN_MODERN_SORT;
pub const TT_MS_LANGID_SPANISH_LATIN_AMERICA = @as(c_uint, 0xE40A);
pub const TT_MS_LANGID_FRENCH_WEST_INDIES = @as(c_int, 0x1C0C);
pub const TT_MS_LANGID_FRENCH_REUNION = @as(c_int, 0x200C);
pub const TT_MS_LANGID_FRENCH_CONGO = @as(c_int, 0x240C);
pub const TT_MS_LANGID_FRENCH_ZAIRE = TT_MS_LANGID_FRENCH_CONGO;
pub const TT_MS_LANGID_FRENCH_SENEGAL = @as(c_int, 0x280C);
pub const TT_MS_LANGID_FRENCH_CAMEROON = @as(c_int, 0x2C0C);
pub const TT_MS_LANGID_FRENCH_COTE_D_IVOIRE = @as(c_int, 0x300C);
pub const TT_MS_LANGID_FRENCH_MALI = @as(c_int, 0x340C);
pub const TT_MS_LANGID_FRENCH_MOROCCO = @as(c_int, 0x380C);
pub const TT_MS_LANGID_FRENCH_HAITI = @as(c_int, 0x3C0C);
pub const TT_MS_LANGID_FRENCH_NORTH_AFRICA = @as(c_uint, 0xE40C);
pub const TT_MS_LANGID_KOREAN_EXTENDED_WANSUNG_KOREA = TT_MS_LANGID_KOREAN_KOREA;
pub const TT_MS_LANGID_KOREAN_JOHAB_KOREA = @as(c_int, 0x0812);
pub const TT_MS_LANGID_RHAETO_ROMANIC_SWITZERLAND = TT_MS_LANGID_ROMANSH_SWITZERLAND;
pub const TT_MS_LANGID_MOLDAVIAN_MOLDAVIA = @as(c_int, 0x0818);
pub const TT_MS_LANGID_RUSSIAN_MOLDAVIA = @as(c_int, 0x0819);
pub const TT_MS_LANGID_URDU_INDIA = @as(c_int, 0x0820);
pub const TT_MS_LANGID_CLASSIC_LITHUANIAN_LITHUANIA = @as(c_int, 0x0827);
pub const TT_MS_LANGID_SLOVENE_SLOVENIA = TT_MS_LANGID_SLOVENIAN_SLOVENIA;
pub const TT_MS_LANGID_FARSI_IRAN = @as(c_int, 0x0429);
pub const TT_MS_LANGID_BASQUE_SPAIN = TT_MS_LANGID_BASQUE_BASQUE;
pub const TT_MS_LANGID_SORBIAN_GERMANY = TT_MS_LANGID_UPPER_SORBIAN_GERMANY;
pub const TT_MS_LANGID_SUTU_SOUTH_AFRICA = @as(c_int, 0x0430);
pub const TT_MS_LANGID_TSONGA_SOUTH_AFRICA = @as(c_int, 0x0431);
pub const TT_MS_LANGID_TSWANA_SOUTH_AFRICA = TT_MS_LANGID_SETSWANA_SOUTH_AFRICA;
pub const TT_MS_LANGID_VENDA_SOUTH_AFRICA = @as(c_int, 0x0433);
pub const TT_MS_LANGID_XHOSA_SOUTH_AFRICA = TT_MS_LANGID_ISIXHOSA_SOUTH_AFRICA;
pub const TT_MS_LANGID_ZULU_SOUTH_AFRICA = TT_MS_LANGID_ISIZULU_SOUTH_AFRICA;
pub const TT_MS_LANGID_SAAMI_LAPONIA = @as(c_int, 0x043B);
pub const TT_MS_LANGID_IRISH_GAELIC_IRELAND = @as(c_int, 0x043C);
pub const TT_MS_LANGID_SCOTTISH_GAELIC_UNITED_KINGDOM = @as(c_int, 0x083C);
pub const TT_MS_LANGID_YIDDISH_GERMANY = @as(c_int, 0x043D);
pub const TT_MS_LANGID_KAZAK_KAZAKSTAN = TT_MS_LANGID_KAZAKH_KAZAKHSTAN;
pub const TT_MS_LANGID_KIRGHIZ_KIRGHIZ_REPUBLIC = TT_MS_LANGID_KYRGYZ_KYRGYZSTAN;
pub const TT_MS_LANGID_KIRGHIZ_KIRGHIZSTAN = TT_MS_LANGID_KYRGYZ_KYRGYZSTAN;
pub const TT_MS_LANGID_SWAHILI_KENYA = TT_MS_LANGID_KISWAHILI_KENYA;
pub const TT_MS_LANGID_TATAR_TATARSTAN = TT_MS_LANGID_TATAR_RUSSIA;
pub const TT_MS_LANGID_PUNJABI_ARABIC_PAKISTAN = @as(c_int, 0x0846);
pub const TT_MS_LANGID_ORIYA_INDIA = TT_MS_LANGID_ODIA_INDIA;
pub const TT_MS_LANGID_MONGOLIAN_MONGOLIA_MONGOLIAN = TT_MS_LANGID_MONGOLIAN_PRC;
pub const TT_MS_LANGID_TIBETAN_CHINA = TT_MS_LANGID_TIBETAN_PRC;
pub const TT_MS_LANGID_DZONGHKA_BHUTAN = @as(c_int, 0x0851);
pub const TT_MS_LANGID_TIBETAN_BHUTAN = TT_MS_LANGID_DZONGHKA_BHUTAN;
pub const TT_MS_LANGID_WELSH_WALES = TT_MS_LANGID_WELSH_UNITED_KINGDOM;
pub const TT_MS_LANGID_BURMESE_MYANMAR = @as(c_int, 0x0455);
pub const TT_MS_LANGID_GALICIAN_SPAIN = TT_MS_LANGID_GALICIAN_GALICIAN;
pub const TT_MS_LANGID_MANIPURI_INDIA = @as(c_int, 0x0458);
pub const TT_MS_LANGID_SINDHI_INDIA = @as(c_int, 0x0459);
pub const TT_MS_LANGID_SINDHI_PAKISTAN = @as(c_int, 0x0859);
pub const TT_MS_LANGID_SINHALESE_SRI_LANKA = TT_MS_LANGID_SINHALA_SRI_LANKA;
pub const TT_MS_LANGID_CHEROKEE_UNITED_STATES = @as(c_int, 0x045C);
pub const TT_MS_LANGID_TAMAZIGHT_MOROCCO = @as(c_int, 0x045F);
pub const TT_MS_LANGID_TAMAZIGHT_MOROCCO_LATIN = TT_MS_LANGID_TAMAZIGHT_ALGERIA;
pub const TT_MS_LANGID_KASHMIRI_PAKISTAN = @as(c_int, 0x0460);
pub const TT_MS_LANGID_KASHMIRI_SASIA = @as(c_int, 0x0860);
pub const TT_MS_LANGID_KASHMIRI_INDIA = TT_MS_LANGID_KASHMIRI_SASIA;
pub const TT_MS_LANGID_NEPALI_INDIA = @as(c_int, 0x0861);
pub const TT_MS_LANGID_DIVEHI_MALDIVES = TT_MS_LANGID_DHIVEHI_MALDIVES;
pub const TT_MS_LANGID_EDO_NIGERIA = @as(c_int, 0x0466);
pub const TT_MS_LANGID_FULFULDE_NIGERIA = @as(c_int, 0x0467);
pub const TT_MS_LANGID_IBIBIO_NIGERIA = @as(c_int, 0x0469);
pub const TT_MS_LANGID_SEPEDI_SOUTH_AFRICA = TT_MS_LANGID_SESOTHO_SA_LEBOA_SOUTH_AFRICA;
pub const TT_MS_LANGID_SOTHO_SOUTHERN_SOUTH_AFRICA = TT_MS_LANGID_SESOTHO_SA_LEBOA_SOUTH_AFRICA;
pub const TT_MS_LANGID_KANURI_NIGERIA = @as(c_int, 0x0471);
pub const TT_MS_LANGID_OROMO_ETHIOPIA = @as(c_int, 0x0472);
pub const TT_MS_LANGID_TIGRIGNA_ETHIOPIA = @as(c_int, 0x0473);
pub const TT_MS_LANGID_TIGRIGNA_ERYTHREA = @as(c_int, 0x0873);
pub const TT_MS_LANGID_TIGRIGNA_ERYTREA = TT_MS_LANGID_TIGRIGNA_ERYTHREA;
pub const TT_MS_LANGID_GUARANI_PARAGUAY = @as(c_int, 0x0474);
pub const TT_MS_LANGID_HAWAIIAN_UNITED_STATES = @as(c_int, 0x0475);
pub const TT_MS_LANGID_LATIN = @as(c_int, 0x0476);
pub const TT_MS_LANGID_SOMALI_SOMALIA = @as(c_int, 0x0477);
pub const TT_MS_LANGID_YI_CHINA = TT_MS_LANGID_YI_PRC;
pub const TT_MS_LANGID_PAPIAMENTU_NETHERLANDS_ANTILLES = @as(c_int, 0x0479);
pub const TT_MS_LANGID_UIGHUR_CHINA = TT_MS_LANGID_UIGHUR_PRC;
pub const TT_NAME_ID_COPYRIGHT = @as(c_int, 0);
pub const TT_NAME_ID_FONT_FAMILY = @as(c_int, 1);
pub const TT_NAME_ID_FONT_SUBFAMILY = @as(c_int, 2);
pub const TT_NAME_ID_UNIQUE_ID = @as(c_int, 3);
pub const TT_NAME_ID_FULL_NAME = @as(c_int, 4);
pub const TT_NAME_ID_VERSION_STRING = @as(c_int, 5);
pub const TT_NAME_ID_PS_NAME = @as(c_int, 6);
pub const TT_NAME_ID_TRADEMARK = @as(c_int, 7);
pub const TT_NAME_ID_MANUFACTURER = @as(c_int, 8);
pub const TT_NAME_ID_DESIGNER = @as(c_int, 9);
pub const TT_NAME_ID_DESCRIPTION = @as(c_int, 10);
pub const TT_NAME_ID_VENDOR_URL = @as(c_int, 11);
pub const TT_NAME_ID_DESIGNER_URL = @as(c_int, 12);
pub const TT_NAME_ID_LICENSE = @as(c_int, 13);
pub const TT_NAME_ID_LICENSE_URL = @as(c_int, 14);
pub const TT_NAME_ID_TYPOGRAPHIC_FAMILY = @as(c_int, 16);
pub const TT_NAME_ID_TYPOGRAPHIC_SUBFAMILY = @as(c_int, 17);
pub const TT_NAME_ID_MAC_FULL_NAME = @as(c_int, 18);
pub const TT_NAME_ID_SAMPLE_TEXT = @as(c_int, 19);
pub const TT_NAME_ID_CID_FINDFONT_NAME = @as(c_int, 20);
pub const TT_NAME_ID_WWS_FAMILY = @as(c_int, 21);
pub const TT_NAME_ID_WWS_SUBFAMILY = @as(c_int, 22);
pub const TT_NAME_ID_LIGHT_BACKGROUND = @as(c_int, 23);
pub const TT_NAME_ID_DARK_BACKGROUND = @as(c_int, 24);
pub const TT_NAME_ID_VARIATIONS_PREFIX = @as(c_int, 25);
pub const TT_NAME_ID_PREFERRED_FAMILY = TT_NAME_ID_TYPOGRAPHIC_FAMILY;
pub const TT_NAME_ID_PREFERRED_SUBFAMILY = TT_NAME_ID_TYPOGRAPHIC_SUBFAMILY;
pub const TT_UCR_BASIC_LATIN = @as(c_ulong, 1) << @as(c_int, 0);
pub const TT_UCR_LATIN1_SUPPLEMENT = @as(c_ulong, 1) << @as(c_int, 1);
pub const TT_UCR_LATIN_EXTENDED_A = @as(c_ulong, 1) << @as(c_int, 2);
pub const TT_UCR_LATIN_EXTENDED_B = @as(c_ulong, 1) << @as(c_int, 3);
pub const TT_UCR_IPA_EXTENSIONS = @as(c_ulong, 1) << @as(c_int, 4);
pub const TT_UCR_SPACING_MODIFIER = @as(c_ulong, 1) << @as(c_int, 5);
pub const TT_UCR_COMBINING_DIACRITICAL_MARKS = @as(c_ulong, 1) << @as(c_int, 6);
pub const TT_UCR_GREEK = @as(c_ulong, 1) << @as(c_int, 7);
pub const TT_UCR_COPTIC = @as(c_ulong, 1) << @as(c_int, 8);
pub const TT_UCR_CYRILLIC = @as(c_ulong, 1) << @as(c_int, 9);
pub const TT_UCR_ARMENIAN = @as(c_ulong, 1) << @as(c_int, 10);
pub const TT_UCR_HEBREW = @as(c_ulong, 1) << @as(c_int, 11);
pub const TT_UCR_VAI = @as(c_ulong, 1) << @as(c_int, 12);
pub const TT_UCR_ARABIC = @as(c_ulong, 1) << @as(c_int, 13);
pub const TT_UCR_NKO = @as(c_ulong, 1) << @as(c_int, 14);
pub const TT_UCR_DEVANAGARI = @as(c_ulong, 1) << @as(c_int, 15);
pub const TT_UCR_BENGALI = @as(c_ulong, 1) << @as(c_int, 16);
pub const TT_UCR_GURMUKHI = @as(c_ulong, 1) << @as(c_int, 17);
pub const TT_UCR_GUJARATI = @as(c_ulong, 1) << @as(c_int, 18);
pub const TT_UCR_ORIYA = @as(c_ulong, 1) << @as(c_int, 19);
pub const TT_UCR_TAMIL = @as(c_ulong, 1) << @as(c_int, 20);
pub const TT_UCR_TELUGU = @as(c_ulong, 1) << @as(c_int, 21);
pub const TT_UCR_KANNADA = @as(c_ulong, 1) << @as(c_int, 22);
pub const TT_UCR_MALAYALAM = @as(c_ulong, 1) << @as(c_int, 23);
pub const TT_UCR_THAI = @as(c_ulong, 1) << @as(c_int, 24);
pub const TT_UCR_LAO = @as(c_ulong, 1) << @as(c_int, 25);
pub const TT_UCR_GEORGIAN = @as(c_ulong, 1) << @as(c_int, 26);
pub const TT_UCR_BALINESE = @as(c_ulong, 1) << @as(c_int, 27);
pub const TT_UCR_HANGUL_JAMO = @as(c_ulong, 1) << @as(c_int, 28);
pub const TT_UCR_LATIN_EXTENDED_ADDITIONAL = @as(c_ulong, 1) << @as(c_int, 29);
pub const TT_UCR_GREEK_EXTENDED = @as(c_ulong, 1) << @as(c_int, 30);
pub const TT_UCR_GENERAL_PUNCTUATION = @as(c_ulong, 1) << @as(c_int, 31);
pub const TT_UCR_SUPERSCRIPTS_SUBSCRIPTS = @as(c_ulong, 1) << @as(c_int, 0);
pub const TT_UCR_CURRENCY_SYMBOLS = @as(c_ulong, 1) << @as(c_int, 1);
pub const TT_UCR_COMBINING_DIACRITICAL_MARKS_SYMB = @as(c_ulong, 1) << @as(c_int, 2);
pub const TT_UCR_LETTERLIKE_SYMBOLS = @as(c_ulong, 1) << @as(c_int, 3);
pub const TT_UCR_NUMBER_FORMS = @as(c_ulong, 1) << @as(c_int, 4);
pub const TT_UCR_ARROWS = @as(c_ulong, 1) << @as(c_int, 5);
pub const TT_UCR_MATHEMATICAL_OPERATORS = @as(c_ulong, 1) << @as(c_int, 6);
pub const TT_UCR_MISCELLANEOUS_TECHNICAL = @as(c_ulong, 1) << @as(c_int, 7);
pub const TT_UCR_CONTROL_PICTURES = @as(c_ulong, 1) << @as(c_int, 8);
pub const TT_UCR_OCR = @as(c_ulong, 1) << @as(c_int, 9);
pub const TT_UCR_ENCLOSED_ALPHANUMERICS = @as(c_ulong, 1) << @as(c_int, 10);
pub const TT_UCR_BOX_DRAWING = @as(c_ulong, 1) << @as(c_int, 11);
pub const TT_UCR_BLOCK_ELEMENTS = @as(c_ulong, 1) << @as(c_int, 12);
pub const TT_UCR_GEOMETRIC_SHAPES = @as(c_ulong, 1) << @as(c_int, 13);
pub const TT_UCR_MISCELLANEOUS_SYMBOLS = @as(c_ulong, 1) << @as(c_int, 14);
pub const TT_UCR_DINGBATS = @as(c_ulong, 1) << @as(c_int, 15);
pub const TT_UCR_CJK_SYMBOLS = @as(c_ulong, 1) << @as(c_int, 16);
pub const TT_UCR_HIRAGANA = @as(c_ulong, 1) << @as(c_int, 17);
pub const TT_UCR_KATAKANA = @as(c_ulong, 1) << @as(c_int, 18);
pub const TT_UCR_BOPOMOFO = @as(c_ulong, 1) << @as(c_int, 19);
pub const TT_UCR_HANGUL_COMPATIBILITY_JAMO = @as(c_ulong, 1) << @as(c_int, 20);
pub const TT_UCR_PHAGSPA = @as(c_ulong, 1) << @as(c_int, 21);
pub const TT_UCR_KANBUN = TT_UCR_PHAGSPA;
pub const TT_UCR_CJK_MISC = TT_UCR_PHAGSPA;
pub const TT_UCR_ENCLOSED_CJK_LETTERS_MONTHS = @as(c_ulong, 1) << @as(c_int, 22);
pub const TT_UCR_CJK_COMPATIBILITY = @as(c_ulong, 1) << @as(c_int, 23);
pub const TT_UCR_HANGUL = @as(c_ulong, 1) << @as(c_int, 24);
pub const TT_UCR_SURROGATES = @as(c_ulong, 1) << @as(c_int, 25);
pub const TT_UCR_NON_PLANE_0 = TT_UCR_SURROGATES;
pub const TT_UCR_PHOENICIAN = @as(c_ulong, 1) << @as(c_int, 26);
pub const TT_UCR_CJK_UNIFIED_IDEOGRAPHS = @as(c_ulong, 1) << @as(c_int, 27);
pub const TT_UCR_PRIVATE_USE = @as(c_ulong, 1) << @as(c_int, 28);
pub const TT_UCR_CJK_COMPATIBILITY_IDEOGRAPHS = @as(c_ulong, 1) << @as(c_int, 29);
pub const TT_UCR_ALPHABETIC_PRESENTATION_FORMS = @as(c_ulong, 1) << @as(c_int, 30);
pub const TT_UCR_ARABIC_PRESENTATION_FORMS_A = @as(c_ulong, 1) << @as(c_int, 31);
pub const TT_UCR_COMBINING_HALF_MARKS = @as(c_ulong, 1) << @as(c_int, 0);
pub const TT_UCR_CJK_COMPATIBILITY_FORMS = @as(c_ulong, 1) << @as(c_int, 1);
pub const TT_UCR_SMALL_FORM_VARIANTS = @as(c_ulong, 1) << @as(c_int, 2);
pub const TT_UCR_ARABIC_PRESENTATION_FORMS_B = @as(c_ulong, 1) << @as(c_int, 3);
pub const TT_UCR_HALFWIDTH_FULLWIDTH_FORMS = @as(c_ulong, 1) << @as(c_int, 4);
pub const TT_UCR_SPECIALS = @as(c_ulong, 1) << @as(c_int, 5);
pub const TT_UCR_TIBETAN = @as(c_ulong, 1) << @as(c_int, 6);
pub const TT_UCR_SYRIAC = @as(c_ulong, 1) << @as(c_int, 7);
pub const TT_UCR_THAANA = @as(c_ulong, 1) << @as(c_int, 8);
pub const TT_UCR_SINHALA = @as(c_ulong, 1) << @as(c_int, 9);
pub const TT_UCR_MYANMAR = @as(c_ulong, 1) << @as(c_int, 10);
pub const TT_UCR_ETHIOPIC = @as(c_ulong, 1) << @as(c_int, 11);
pub const TT_UCR_CHEROKEE = @as(c_ulong, 1) << @as(c_int, 12);
pub const TT_UCR_CANADIAN_ABORIGINAL_SYLLABICS = @as(c_ulong, 1) << @as(c_int, 13);
pub const TT_UCR_OGHAM = @as(c_ulong, 1) << @as(c_int, 14);
pub const TT_UCR_RUNIC = @as(c_ulong, 1) << @as(c_int, 15);
pub const TT_UCR_KHMER = @as(c_ulong, 1) << @as(c_int, 16);
pub const TT_UCR_MONGOLIAN = @as(c_ulong, 1) << @as(c_int, 17);
pub const TT_UCR_BRAILLE = @as(c_ulong, 1) << @as(c_int, 18);
pub const TT_UCR_YI = @as(c_ulong, 1) << @as(c_int, 19);
pub const TT_UCR_PHILIPPINE = @as(c_ulong, 1) << @as(c_int, 20);
pub const TT_UCR_OLD_ITALIC = @as(c_ulong, 1) << @as(c_int, 21);
pub const TT_UCR_GOTHIC = @as(c_ulong, 1) << @as(c_int, 22);
pub const TT_UCR_DESERET = @as(c_ulong, 1) << @as(c_int, 23);
pub const TT_UCR_MUSICAL_SYMBOLS = @as(c_ulong, 1) << @as(c_int, 24);
pub const TT_UCR_MATH_ALPHANUMERIC_SYMBOLS = @as(c_ulong, 1) << @as(c_int, 25);
pub const TT_UCR_PRIVATE_USE_SUPPLEMENTARY = @as(c_ulong, 1) << @as(c_int, 26);
pub const TT_UCR_VARIATION_SELECTORS = @as(c_ulong, 1) << @as(c_int, 27);
pub const TT_UCR_TAGS = @as(c_ulong, 1) << @as(c_int, 28);
pub const TT_UCR_LIMBU = @as(c_ulong, 1) << @as(c_int, 29);
pub const TT_UCR_TAI_LE = @as(c_ulong, 1) << @as(c_int, 30);
pub const TT_UCR_NEW_TAI_LUE = @as(c_ulong, 1) << @as(c_int, 31);
pub const TT_UCR_BUGINESE = @as(c_ulong, 1) << @as(c_int, 0);
pub const TT_UCR_GLAGOLITIC = @as(c_ulong, 1) << @as(c_int, 1);
pub const TT_UCR_TIFINAGH = @as(c_ulong, 1) << @as(c_int, 2);
pub const TT_UCR_YIJING = @as(c_ulong, 1) << @as(c_int, 3);
pub const TT_UCR_SYLOTI_NAGRI = @as(c_ulong, 1) << @as(c_int, 4);
pub const TT_UCR_LINEAR_B = @as(c_ulong, 1) << @as(c_int, 5);
pub const TT_UCR_ANCIENT_GREEK_NUMBERS = @as(c_ulong, 1) << @as(c_int, 6);
pub const TT_UCR_UGARITIC = @as(c_ulong, 1) << @as(c_int, 7);
pub const TT_UCR_OLD_PERSIAN = @as(c_ulong, 1) << @as(c_int, 8);
pub const TT_UCR_SHAVIAN = @as(c_ulong, 1) << @as(c_int, 9);
pub const TT_UCR_OSMANYA = @as(c_ulong, 1) << @as(c_int, 10);
pub const TT_UCR_CYPRIOT_SYLLABARY = @as(c_ulong, 1) << @as(c_int, 11);
pub const TT_UCR_KHAROSHTHI = @as(c_ulong, 1) << @as(c_int, 12);
pub const TT_UCR_TAI_XUAN_JING = @as(c_ulong, 1) << @as(c_int, 13);
pub const TT_UCR_CUNEIFORM = @as(c_ulong, 1) << @as(c_int, 14);
pub const TT_UCR_COUNTING_ROD_NUMERALS = @as(c_ulong, 1) << @as(c_int, 15);
pub const TT_UCR_SUNDANESE = @as(c_ulong, 1) << @as(c_int, 16);
pub const TT_UCR_LEPCHA = @as(c_ulong, 1) << @as(c_int, 17);
pub const TT_UCR_OL_CHIKI = @as(c_ulong, 1) << @as(c_int, 18);
pub const TT_UCR_SAURASHTRA = @as(c_ulong, 1) << @as(c_int, 19);
pub const TT_UCR_KAYAH_LI = @as(c_ulong, 1) << @as(c_int, 20);
pub const TT_UCR_REJANG = @as(c_ulong, 1) << @as(c_int, 21);
pub const TT_UCR_CHAM = @as(c_ulong, 1) << @as(c_int, 22);
pub const TT_UCR_ANCIENT_SYMBOLS = @as(c_ulong, 1) << @as(c_int, 23);
pub const TT_UCR_PHAISTOS_DISC = @as(c_ulong, 1) << @as(c_int, 24);
pub const TT_UCR_OLD_ANATOLIAN = @as(c_ulong, 1) << @as(c_int, 25);
pub const TT_UCR_GAME_TILES = @as(c_ulong, 1) << @as(c_int, 26);
pub const TT_UCR_ARABIC_PRESENTATION_A = TT_UCR_ARABIC_PRESENTATION_FORMS_A;
pub const TT_UCR_ARABIC_PRESENTATION_B = TT_UCR_ARABIC_PRESENTATION_FORMS_B;
pub const TT_UCR_COMBINING_DIACRITICS = TT_UCR_COMBINING_DIACRITICAL_MARKS;
pub const TT_UCR_COMBINING_DIACRITICS_SYMB = TT_UCR_COMBINING_DIACRITICAL_MARKS_SYMB;
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
pub const TT_Header_ = struct_TT_Header_;
pub const TT_HoriHeader_ = struct_TT_HoriHeader_;
pub const TT_VertHeader_ = struct_TT_VertHeader_;
pub const TT_OS2_ = struct_TT_OS2_;
pub const TT_Postscript_ = struct_TT_Postscript_;
pub const TT_PCLT_ = struct_TT_PCLT_;
pub const TT_MaxProfile_ = struct_TT_MaxProfile_;
pub const FT_Sfnt_Tag_ = enum_FT_Sfnt_Tag_;
pub const FT_MM_Axis_ = struct_FT_MM_Axis_;
pub const FT_Multi_Master_ = struct_FT_Multi_Master_;
pub const FT_Var_Axis_ = struct_FT_Var_Axis_;
pub const FT_Var_Named_Style_ = struct_FT_Var_Named_Style_;
pub const FT_MM_Var_ = struct_FT_MM_Var_;
pub const FT_Orientation_ = enum_FT_Orientation_;
pub const FT_SfntName_ = struct_FT_SfntName_;
pub const FT_SfntLangTag_ = struct_FT_SfntLangTag_;

// Generated by tools/gen_dyn_bindings.py - do not edit by hand.
/// Symbols this port references and cannot run without; `loadDynamic`
/// resolves exactly these and fails with `error.MissingSymbol` when the
/// runtime library is older. Optional symbols are resolved by their
/// callers through `dyn.lookupSymbol` instead.
pub const required_symbols = [_][]const u8{
    "FT_Done_Face",
    "FT_Done_FreeType",
    "FT_Done_MM_Var",
    "FT_Get_Char_Index",
    "FT_Get_Kerning",
    "FT_Get_MM_Var",
    "FT_Get_Sfnt_Name",
    "FT_Get_Sfnt_Name_Count",
    "FT_Get_Sfnt_Table",
    "FT_Get_Var_Design_Coordinates",
    "FT_Init_FreeType",
    "FT_Library_Version",
    "FT_Load_Glyph",
    "FT_Load_Sfnt_Table",
    "FT_MulFix",
    "FT_New_Face",
    "FT_New_Memory_Face",
    "FT_Outline_Decompose",
    "FT_Reference_Face",
    "FT_Render_Glyph",
    "FT_Select_Charmap",
    "FT_Select_Size",
    "FT_Set_Char_Size",
    "FT_Set_Pixel_Sizes",
    "FT_Set_Transform",
    "FT_Set_Var_Design_Coordinates",
};

/// Resolve exactly `names` from `lib`. `loadDynamic` passes
/// `required_symbols`; tests pass explicit lists to exercise a partial
/// bind (a missing symbol after some were already assigned).
pub fn loadDynamicSymbols(lib: *@import("dynload").Library, comptime names: []const []const u8) !void {
    inline for (names) |name| {
        const raw = lib.lookupSymbol(name) orelse return error.MissingSymbol;
        // Function pointers are 4-aligned on some targets (aarch64);
        // @alignCast is a no-op where they are byte-aligned.
        @field(@This(), name) = @ptrCast(@alignCast(raw));
    }
}

/// Resolve every required symbol from `lib`. Declarations outside
/// `required_symbols` (optional entry points) stay undefined here.
pub fn loadDynamic(lib: *@import("dynload").Library) !void {
    try loadDynamicSymbols(lib, &required_symbols);
}
