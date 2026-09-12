#!/usr/bin/env bash
# Restore the pinned upstream source trees used while porting COSMIC Text.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=pin.env
source "$ROOT/tools/pin.env"

fetch_reference() {
    local name="$1" repo="$2" rev="$3" destination="$4" actual
    if [[ -d "$destination/.git" ]]; then
        actual="$(git -C "$destination" rev-parse HEAD)"
        [[ "$actual" == "$rev" ]] || {
            echo "error: $name is at $actual, expected $rev: $destination" >&2
            return 1
        }
        echo "ok: $name at $rev"
        return 0
    fi
    [[ ! -e "$destination" ]] || {
        echo "error: reference destination exists but is not a Git checkout: $destination" >&2
        return 1
    }
    mkdir -p "$(dirname "$destination")"
    echo "cloning $name at $rev ..."
    git clone --filter=blob:none --no-checkout "$repo" "$destination"
    git -C "$destination" checkout --detach --quiet "$rev"
    actual="$(git -C "$destination" rev-parse HEAD)"
    [[ "$actual" == "$rev" ]] || {
        echo "error: $name resolved to $actual, expected $rev" >&2
        return 1
    }
    echo "ok: $name at $rev"
}

fetch_reference cosmic-text "$COSMIC_TEXT_REPO" "$COSMIC_TEXT_REV" "$ROOT/.reference/cosmic-text"
fetch_reference ezi-code "$EZI_CODE_REPO" "$EZI_CODE_REV" "$ROOT/.reference/ezi-code"
fetch_reference harfbuzz "$HARFBUZZ_REPO" "$HARFBUZZ_REV" "$ROOT/.reference/harfbuzz-ref"
fetch_reference freetype "$FREETYPE_REPO" "$FREETYPE_REV" "$ROOT/.reference/freetype-ref"

# Keep the benchmark oracle fair: Cozmic and COSMIC Text load the same fonts.
# The inserted helper and replacements are idempotent, so this preserves the
# local benchmark adjustment when a reference tree is freshly reconstructed.
COSMIC_TEXT="$ROOT/.reference/cosmic-text"
if grep -q -F "cozmic bench-fairness patch (2026-09-11)" "$COSMIC_TEXT/benches/"*.rs; then
    echo "ok: cosmic-text benchmark fairness patch already applied"
else
    python3 - "$COSMIC_TEXT/benches/layout.rs" "$COSMIC_TEXT/benches/text_shaping_benchmarks.rs" <<'PY'
import sys
from pathlib import Path

layout_helper = """/// cozmic bench-fairness patch (2026-09-11): build the font system from the
/// same vendored fonts the cozmic benches load, so ratios compare engines
/// rather than font sets. `new_with_fonts` still scans system fonts; the host
/// has no Inter/FiraMono installed, so the generic-family overrides below
/// resolve to these exact vendored faces.
fn cozmic_font_system() -> ct::FontSystem {
    use std::sync::Arc;
    let sources = [
        include_bytes!("../../../tests/fonts/Inter-Regular.ttf").as_slice(),
        include_bytes!("../../../tests/fonts/NotoSansArabic.ttf").as_slice(),
        include_bytes!("../../../tests/fonts/NotoSansHebrew.ttf").as_slice(),
        include_bytes!("../../../tests/fonts/FiraMono-Medium.ttf").as_slice(),
    ]
    .into_iter()
    .map(|bytes| ct::fontdb::Source::Binary(Arc::new(bytes.to_vec())));
    let mut fs = ct::FontSystem::new_with_fonts(sources);
    fs.db_mut().set_sans_serif_family("Inter");
    fs.db_mut().set_monospace_family("FiraMono");
    fs
}
"""
shaping_helper = layout_helper.replace(
    "`new_with_fonts` still scans system fonts; the host\n/// has no Inter/FiraMono installed, so the generic-family overrides below\n",
    "The host has no Inter/FiraMono installed, so the\n/// generic-family overrides below\n",
)
for filename, helper in zip(sys.argv[1:], (layout_helper, shaping_helper)):
    path = Path(filename)
    text = path.read_text()
    marker = "use criterion::{black_box, criterion_group, criterion_main, Criterion};\n"
    if marker not in text or "let mut fs = ct::FontSystem::new();" not in text:
        raise SystemExit(f"unexpected upstream benchmark layout: {path}")
    text = text.replace(marker, marker + "\n" + helper + "\n", 1)
    text = text.replace("let mut fs = ct::FontSystem::new();", "let mut fs = cozmic_font_system();")
    path.write_text(text)
PY
    echo "applied: cosmic-text benchmark fairness patch"
fi
