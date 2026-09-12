#!/usr/bin/env python3
"""Generate runtime-loadable bindings from a `zig translate-c` bindings file.

Cozmic must not hard-link HarfBuzz/FreeType (the target set is
Linux + Windows + macOS, and the host may not have development packages).
The checked-in bindings declare every C entry point as `pub extern fn`, which
forces a link-time dependency. This script rewrites such a file into a
drop-in module that declares **every** entry point as a function-pointer
variable:

    pub var hb_shape: *const fn (...) callconv(.c) ... = undefined;

Call sites keep working unchanged (`c.hb_shape(...)`), because Zig calls a
function pointer variable with the same syntax as an `extern fn`. A small
hand-written `dyn.zig` per library opens the shared object with
`std.DynLib`/`LoadLibraryA` and calls the generated `loadDynamic`, which
resolves the symbols the port actually uses; a missing symbol is a clear
`error.MissingSymbol` instead of a link failure or a crash.

Usage:
    python3 tools/gen_dyn_bindings.py \
        --bindings src/harfbuzz/c_bindings.zig \
        --scan src benches tests \
        --out src/harfbuzz/c_bindings_dyn.zig
    python3 tools/gen_dyn_bindings.py ... --check   # fail if out of date

Symbols that are used but optional at runtime stay declared and manually
resolvable (see `dyn.lookupSymbol`) while being kept out of the required set:

    --exclude NAME            # exact declaration name, repeatable
    --exclude-prefix PREFIX   # e.g. `hb_ft_`, repeatable

HarfBuzz's `hb-ft` bridge is the motivating case: only the test bridge uses
`hb_ft_*`, and a HarfBuzz built without FreeType must still shape text, so
those three entry points are excluded from `required_symbols`.

The generated file is deterministic for a given input, scan set and exclusion
set.

Symbol scanning is namespace-aware: a translated bindings file may declare
unrelated C entry points (libc's `index`, `getenv`, or FreeType's `FT_*` via
`hb-ft.h`), so a bare `c.X` regex would pick up false positives from local
variables named `c` and from the other library. Only uses routed through an
alias of *this* library's binding namespace count:

    c.X                  # const c = @import("c.zig").c; (own directory)
    hb.c.X               # const hb = @import("harfbuzz");
    ft.c.X               # const ft = @import("freetype");
    ftc.X                # const ftc = freetype.c;
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

EXTERN_RE = re.compile(r"^\s*pub extern fn (?P<name>[A-Za-z_][A-Za-z0-9_]*)\((?P<args>.*)\) (?P<ret>.+);$")
ALIAS_RE = re.compile(r"^\s*pub const (?P<alias>[A-Za-z_][A-Za-z0-9_]*) = (?:__root\.)?(?P<target>[A-Za-z_][A-Za-z0-9_]*);$")

# `const hb = @import("harfbuzz");` / `pub const ft = @import("freetype");`
MODULE_IMPORT_RE = re.compile(
    r"^\s*(?:pub\s+)?const\s+(?P<alias>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*@import\(\"(?P<module>harfbuzz|freetype)\"\)\s*;",
    re.M,
)
# `const c = @import("c.zig").c;` (the binding namespace of the library whose
# source directory contains the file).
C_IMPORT_RE = re.compile(
    r"^\s*(?:pub\s+)?const\s+(?P<alias>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*@import\(\"c\.zig\"\)\.c\s*;",
    re.M,
)
# `const ftc = freetype.c;` / `const c = ft.c;` / `const c2 = c;`
PLAIN_ALIAS_RE = re.compile(
    r"^\s*(?:pub\s+)?const\s+(?P<alias>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?P<target>[A-Za-z_][A-Za-z0-9_.]*)\s*;",
    re.M,
)
# `<namespace-chain>.<name>`; the chain excludes the final member (e.g. `hb.c`).
USE_RE = re.compile(r"(?<![\w.])(?P<chain>[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\.(?P<name>[A-Za-z_][A-Za-z0-9_]*)")


def parse_bindings(text: str):
    """Return (externs: name -> (args, ret), alias: name -> target)."""
    externs: dict[str, tuple[str, str]] = {}
    aliases: dict[str, str] = {}
    for line in text.splitlines():
        m = EXTERN_RE.match(line)
        if m:
            externs[m.group("name")] = (m.group("args"), m.group("ret"))
            continue
        m = ALIAS_RE.match(line)
        if m:
            aliases[m.group("alias")] = m.group("target")
    return externs, aliases


def namespace_for(prefix: str, module_aliases: dict[str, str], ns_aliases: dict[str, str]) -> str | None:
    """Library name a `.NAME` receiver prefix refers to, if it is a binding alias."""
    if prefix in ns_aliases:
        return ns_aliases[prefix]
    # `hb.c.NAME` / `ft.c.NAME`: receiver is a module alias and `.c` is its
    # binding namespace.
    if prefix.endswith(".c"):
        receiver = prefix[:-2]
        if receiver in module_aliases:
            return module_aliases[receiver]
    return None


def file_aliases(text: str, own_library: str | None):
    """Return (module_aliases, ns_aliases) for one scanned file.

    `own_library` is the library whose `c_bindings.zig` is being generated when
    `path` lives in that library's source directory (so `@import("c.zig").c`
    names *its* binding); otherwise `None`.
    """
    module_aliases = {m.group("alias"): m.group("module") for m in MODULE_IMPORT_RE.finditer(text)}
    ns_aliases: dict[str, str] = {}
    if own_library is not None:
        for m in C_IMPORT_RE.finditer(text):
            ns_aliases[m.group("alias")] = own_library
    # `const ftc = freetype.c;` and simple re-aliases (`const c2 = c;`).
    # Iterate to a fixpoint: aliases may refer to aliases.
    changed = True
    while changed:
        changed = False
        for m in PLAIN_ALIAS_RE.finditer(text):
            alias = m.group("alias")
            if alias in ns_aliases:
                continue
            library = namespace_for(m.group("target"), module_aliases, ns_aliases)
            if library is not None:
                ns_aliases[alias] = library
                changed = True
    return module_aliases, ns_aliases


def resolve_used(
    scan_files: list[pathlib.Path],
    externs: dict[str, tuple[str, str]],
    aliases: dict[str, str],
    library: str,
    bindings_dir: pathlib.Path,
) -> set[str]:
    """Symbols referenced as `c.X` (or `hb.c.X` / `ft.c.X` / aliases) for
    `library`, with binding aliases chased."""
    used: set[str] = set()
    bindings_dir = bindings_dir.resolve()
    for path in scan_files:
        text = path.read_text()
        own_library = library if path.resolve().is_relative_to(bindings_dir) else None
        module_aliases, ns_aliases = file_aliases(text, own_library)
        if not ns_aliases and not module_aliases:
            continue
        for m in USE_RE.finditer(text):
            if namespace_for(m.group("chain"), module_aliases, ns_aliases) != library:
                continue
            name = m.group("name")
            seen: set[str] = set()
            while name in aliases and name not in seen:
                seen.add(name)
                name = aliases[name]
            if name in externs:
                used.add(name)
    return used


def generate(text: str, externs: dict[str, tuple[str, str]], required: set[str]) -> str:
    out: list[str] = []
    for line in text.splitlines():
        m = EXTERN_RE.match(line)
        if not m:
            out.append(line)
            continue
        name = m.group("name")
        args = m.group("args")
        ret = m.group("ret")
        out.append(f"pub var {name}: *const fn ({args}) callconv(.c) {ret} = undefined;")
    names = sorted(required)
    out.append("")
    out.append("// Generated by tools/gen_dyn_bindings.py - do not edit by hand.")
    out.append("/// Symbols this port references and cannot run without; `loadDynamic`")
    out.append("/// resolves exactly these and fails with `error.MissingSymbol` when the")
    out.append("/// runtime library is older. Optional symbols are resolved by their")
    out.append("/// callers through `dyn.lookupSymbol` instead.")
    out.append("pub const required_symbols = [_][]const u8{")
    for name in names:
        out.append(f'    "{name}",')
    out.append("};")
    out.append("")
    out.append("/// Resolve exactly `names` from `lib`. `loadDynamic` passes")
    out.append("/// `required_symbols`; tests pass explicit lists to exercise a partial")
    out.append("/// bind (a missing symbol after some were already assigned).")
    out.append('pub fn loadDynamicSymbols(lib: *@import("dynload").Library, comptime names: []const []const u8) !void {')
    out.append("    inline for (names) |name| {")
    out.append("        const raw = lib.lookupSymbol(name) orelse return error.MissingSymbol;")
    out.append("        // Function pointers are 4-aligned on some targets (aarch64);")
    out.append("        // @alignCast is a no-op where they are byte-aligned.")
    out.append("        @field(@This(), name) = @ptrCast(@alignCast(raw));")
    out.append("    }")
    out.append("}")
    out.append("")
    out.append("/// Resolve every required symbol from `lib`. Declarations outside")
    out.append("/// `required_symbols` (optional entry points) stay undefined here.")
    out.append('pub fn loadDynamic(lib: *@import("dynload").Library) !void {')
    out.append("    try loadDynamicSymbols(lib, &required_symbols);")
    out.append("}")
    out.append("")
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bindings", required=True, type=pathlib.Path)
    ap.add_argument("--scan", required=True, nargs="+", type=pathlib.Path)
    ap.add_argument("--out", required=True, type=pathlib.Path)
    ap.add_argument("--check", action="store_true")
    ap.add_argument(
        "--exclude",
        action="append",
        default=[],
        metavar="NAME",
        help="declaration to keep out of required_symbols (repeatable)",
    )
    ap.add_argument(
        "--exclude-prefix",
        action="append",
        default=[],
        metavar="PREFIX",
        help="exclude every declaration starting with PREFIX (repeatable)",
    )
    args = ap.parse_args()

    text = args.bindings.read_text()
    externs, aliases = parse_bindings(text)

    # A typo'd exclusion must fail loudly: a silently ignored `--exclude` would
    # leave the symbol in `required_symbols` with no indication.
    for name in args.exclude:
        if name not in externs:
            print(f"error: --exclude {name!r} is not declared in {args.bindings}", file=sys.stderr)
            return 1
    for prefix in args.exclude_prefix:
        if not any(decl.startswith(prefix) for decl in externs):
            print(
                f"error: --exclude-prefix {prefix!r} matches no declaration in {args.bindings}",
                file=sys.stderr,
            )
            return 1

    if not externs:
        print(f"error: no `pub extern fn` declarations in {args.bindings}", file=sys.stderr)
        return 1
    # Safety net: every declaration must be rewritten. A multi-line or
    # otherwise unusual signature would otherwise survive as a real `extern
    # fn` and silently reintroduce the link-time dependency.
    decl_count = len(re.findall(r"\bpub extern fn\b", text))
    if decl_count != len(externs):
        print(
            f"error: parsed {len(externs)} of {decl_count} `pub extern fn` declarations "
            f"in {args.bindings}; unsupported multi-line signature?",
            file=sys.stderr,
        )
        return 1

    library = args.bindings.parent.name
    scan_files: list[pathlib.Path] = []
    for root in args.scan:
        if root.is_dir():
            scan_files.extend(sorted(root.rglob("*.zig")))
        elif root.exists():
            scan_files.append(root)
        else:
            # `benches`/`tests` are optional in some checkouts.
            print(f"note: scan path {root} does not exist; skipping", file=sys.stderr)
    used = resolve_used(scan_files, externs, aliases, library, args.bindings.parent)
    if not used:
        print("error: no used C symbols found in the scan set", file=sys.stderr)
        return 1

    excluded = {
        name
        for name in used
        if name in args.exclude or any(name.startswith(prefix) for prefix in args.exclude_prefix)
    }
    required = used - excluded
    if not required:
        print("error: no required C symbols left after exclusions", file=sys.stderr)
        return 1

    result = generate(text, externs, required)
    suffix = f", {len(excluded)} optional/excluded" if excluded else ""
    if args.check:
        current = args.out.read_text() if args.out.exists() else ""
        if current != result:
            print(f"error: {args.out} is out of date; regenerate with tools/gen_dyn_bindings.py", file=sys.stderr)
            return 1
        print(f"{args.out}: up to date ({len(required)} required symbols, {len(externs)} declarations{suffix})")
        return 0

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(result)
    print(f"wrote {args.out}: {len(externs)} declarations, {len(required)} required symbols{suffix}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
