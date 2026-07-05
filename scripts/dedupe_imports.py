#!/usr/bin/env python3
"""Dedupe imports and normalize to package:forja paths in apps/forja/lib."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "apps" / "forja" / "lib"

REL_TO_PACKAGE = {
    "details_screen.dart": "package:forja/features/home/details_screen.dart",
    "streaming_details_screen.dart": "package:forja/features/home/streaming_details_screen.dart",
    "home_screen.dart": "package:forja/features/home/home_screen.dart",
    "search_screen.dart": "package:forja/features/search/search_screen.dart",
    "discover_screen.dart": "package:forja/features/discover/discover_screen.dart",
    "lists_screen.dart": "package:forja/features/my_list/lists_screen.dart",
    "player_screen.dart": "package:forja/features/player/player_screen.dart",
    "../player_screen.dart": "package:forja/features/player/player_screen.dart",
    "main_screen.dart": "package:forja/shell/main_screen.dart",
}


def process_file(path: Path) -> bool:
    text = path.read_text()
    lines = text.splitlines(keepends=True)
    seen: set[str] = set()
    out: list[str] = []
    changed = False

    for line in lines:
        m = re.match(r"^import\s+'([^']+)';\s*$", line)
        if m:
            uri = m.group(1)
            if uri in REL_TO_PACKAGE:
                uri = REL_TO_PACKAGE[uri]
                line = f"import '{uri}';\n"
                changed = True
            elif uri.startswith("../") and uri.endswith(".dart"):
                # resolve relative within lib
                resolved = (path.parent / uri).resolve()
                try:
                    rel = resolved.relative_to(ROOT)
                    uri = f"package:forja/{rel.as_posix()}"
                    line = f"import '{uri}';\n"
                    changed = True
                except ValueError:
                    pass
            if uri in seen:
                changed = True
                continue
            seen.add(uri)
        out.append(line)

    new_text = "".join(out)
    if new_text != text:
        path.write_text(new_text)
        return True
    return changed


def main() -> None:
    count = 0
    for dart in ROOT.rglob("*.dart"):
        if process_file(dart):
            count += 1
            print(dart.relative_to(ROOT))
    print(f"Updated {count} files")


if __name__ == "__main__":
    main()
