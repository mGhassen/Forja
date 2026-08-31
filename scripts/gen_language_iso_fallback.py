#!/usr/bin/env python3
"""Regenerate apps/forja/lib/shared/utils/language_iso_fallback.dart

Pulls ISO 639-2 / 639-3 Ref_Names + OpenSubtitles IdSubLanguage names so
subtitle pickers never fall back to title-cased bare codes (Chr, Ckb, …).
"""

from __future__ import annotations

import json
import pathlib
import re
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "apps/forja/lib/shared/utils/language_iso_fallback.dart"

ISO639_2_URL = (
    "https://raw.githubusercontent.com/haliaeetus/iso-639/master/data/iso_639-2.json"
)
ISO639_3_URL = (
    "https://iso639-3.sil.org/sites/iso639-3/files/downloads/iso-639-3.tab"
)
OPENSUBTITLES_URL = (
    "https://raw.githubusercontent.com/Diaoul/babelfish/master/"
    "babelfish/data/opensubtitles_languages.txt"
)

# Provider / OpenSubtitles tags that are not pure ISO.
EXTRAS = {
    "zt": "Chinese (traditional)",
    "ze": "Chinese bilingual",
    "pb": "Portuguese (BR)",
    "pob": "Portuguese (BR)",
    "me": "Montenegrin",
    "cn": "Chinese",
    "at": "Asturian",
    "ext": "Extremaduran",
    "ex": "Extremaduran",
    "pr": "Dari",
    "ma": "Manipuri",
    "sy": "Syriac",
    "sx": "Santali",
    "sp": "Spanish (EU)",
    "ea": "Spanish (LA)",
    "pm": "Portuguese (MZ)",
    "tp": "Toki Pona",
    "ckb": "Central Kurdish",
    "crs": "Seselwa Creole French",
}

SKIP = {"und", "zxx", "mul", "mis", "qaa"}
CODE_RE = re.compile(r"^[a-z]{2,3}(-[a-z0-9]+)?$")


def fetch(url: str) -> bytes:
    with urllib.request.urlopen(url) as resp:
        return resp.read()


def main() -> None:
    names: dict[str, str] = {}

    for line in fetch(ISO639_3_URL).decode("utf-8").splitlines()[1:]:
        parts = line.split("\t")
        if len(parts) < 7:
            continue
        id_, p2b, p2t, p1, _scope, _ltype, ref = parts[:7]
        if not ref:
            continue
        codes = {id_}
        if p2b:
            codes.add(p2b)
        if p2t:
            codes.add(p2t)
        if p1:
            codes.add(p1)
        for c in codes:
            names.setdefault(c.lower(), ref)

    for key, val in json.loads(fetch(ISO639_2_URL)).items():
        en = (val.get("en") or [None])[0]
        if not en:
            continue
        names.setdefault(key.lower(), en)
        p1 = val.get("639-1")
        if p1:
            names.setdefault(p1.lower(), en)

    for line in fetch(OPENSUBTITLES_URL).decode("utf-8").splitlines()[1:]:
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        code, iso, name = parts[0].strip(), parts[1].strip(), parts[2].strip()
        if not code or not name or name == "LanguageName":
            continue
        names.setdefault(code.lower(), name)
        if iso:
            names.setdefault(iso.lower(), name)

    names.update({k: v for k, v in EXTRAS.items()})
    names = {
        k: v
        for k, v in names.items()
        if k not in SKIP and CODE_RE.fullmatch(k)
    }

    lines = [
        "// GENERATED — do not edit by hand.",
        "// ISO 639 / OpenSubtitles English names for subtitle/audio pickers.",
        "// Prefer native endonyms in language_display.dart; this is the fallback.",
        "// Regenerate: python3 scripts/gen_language_iso_fallback.py",
        "",
        "const Map<String, String> kIsoLanguageEnglishNames = {",
    ]
    for key in sorted(names.keys(), key=lambda x: (len(x), x)):
        safe = names[key].replace("\\", "\\\\").replace("'", "\\'")
        lines.append(f"  '{key}': '{safe}',")
    lines.append("};")
    lines.append("")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {OUT} ({len(names)} entries, {OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
