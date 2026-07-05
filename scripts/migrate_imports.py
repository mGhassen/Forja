#!/usr/bin/env python3
"""Rewrite relative imports to package imports after monorepo extraction."""

import re
import sys
from pathlib import Path

GLOBAL = [
    (r"import '\.\./models/", "import 'package:forja_core/models/"),
    (r"import '\.\./\.\./models/", "import 'package:forja_core/models/"),
    (r"import '\.\./\.\./\.\./models/", "import 'package:forja_core/models/"),
    (r"import 'models/", "import 'package:forja_core/models/"),
    (r"import '\.\./utils/", "import 'package:forja_core/utils/"),
    (r"import '\.\./\.\./utils/", "import 'package:forja_core/utils/"),
    (r"import '\.\./\.\./\.\./utils/", "import 'package:forja_core/utils/"),
    (r"import 'utils/", "import 'package:forja_core/utils/"),
    (r"import '\.\./scrapers/", "import 'package:forja_scrapers/scrapers/"),
    (r"import '\.\./\.\./scrapers/", "import 'package:forja_scrapers/scrapers/"),
    (r"import 'scrapers/", "import 'package:forja_scrapers/scrapers/"),
    (r"import '\.\./webstreamr/", "import 'package:forja_webstreamr/webstreamr/"),
    (r"import '\.\./\.\./webstreamr/", "import 'package:forja_webstreamr/webstreamr/"),
    (r"import 'webstreamr/", "import 'package:forja_webstreamr/webstreamr/"),
    (r"import '\.\./features/iptv/forja_tv/", "import 'package:forja_iptv/iptv/"),
    (r"import '\.\./\.\./features/iptv/forja_tv/", "import 'package:forja_iptv/iptv/"),
    (r"import '\.\./widgets/", "import 'package:forja_ui/widgets/"),
    (r"import '\.\./\.\./widgets/", "import 'package:forja_ui/widgets/"),
    (r"import 'widgets/", "import 'package:forja_ui/widgets/"),
    (r"import '\.\./screens/player/", "import 'package:forja_player/screens/player/"),
    (r"import '\.\./\.\./screens/player/", "import 'package:forja_player/screens/player/"),
    (r"import '\.\./\.\./\.\./screens/player/", "import 'package:forja_player/screens/player/"),
    (r"import 'screens/player/", "import 'package:forja_player/screens/player/"),
    (r"import '\.\./api/settings_service.dart'", "import 'package:forja_storage/forja_storage.dart'"),
    (r"import '\.\./\.\./api/settings_service.dart'", "import 'package:forja_storage/forja_storage.dart'"),
    (r"import '\.\./services/watch_history_service.dart'", "import 'package:forja_storage/forja_storage.dart'"),
    (r"import '\.\./\.\./services/watch_history_service.dart'", "import 'package:forja_storage/forja_storage.dart'"),
    (r"import '\.\./services/my_list_service.dart'", "import 'package:forja_storage/forja_storage.dart'"),
    (r"import '\.\./\.\./services/my_list_service.dart'", "import 'package:forja_storage/forja_storage.dart'"),
    (r"import '\.\./services/book_progress_service.dart'", "import 'package:forja_storage/forja_storage.dart'"),
    (r"import '\.\./api/local_server_service.dart'", "import 'package:forja_streaming/forja_streaming.dart'"),
    (r"import '\.\./\.\./api/local_server_service.dart'", "import 'package:forja_streaming/forja_streaming.dart'"),
]

OUTSIDE_API = [
    (r"import '\.\./api/", "import 'package:forja_api/api/"),
    (r"import '\.\./\.\./api/", "import 'package:forja_api/api/"),
    (r"import '\.\./\.\./\.\./api/", "import 'package:forja_api/api/"),
    (r"import 'api/", "import 'package:forja_api/api/"),
    (r"import '\.\./services/", "import 'package:forja_api/services/"),
    (r"import '\.\./\.\./services/", "import 'package:forja_api/services/"),
    (r"import '\.\./\.\./\.\./services/", "import 'package:forja_api/services/"),
    (r"import 'services/", "import 'package:forja_api/services/"),
    (r"import '\.\./screens/", "import 'package:forja_ui/screens/"),
    (r"import '\.\./\.\./screens/", "import 'package:forja_ui/screens/"),
    (r"import '\.\./\.\./\.\./screens/", "import 'package:forja_ui/screens/"),
    (r"import 'screens/", "import 'package:forja_ui/screens/"),
]

INSIDE_API = [
    (r"import '\.\./api/", "import 'package:forja_api/api/"),
    (r"import '\.\./\.\./api/", "import 'package:forja_api/api/"),
    (r"import '\.\./services/", "import 'package:forja_api/services/"),
    (r"import '\.\./\.\./services/", "import 'package:forja_api/services/"),
    (r"import '\.\./api/local_server_service.dart'", "import 'package:forja_streaming/forja_streaming.dart'"),
    (r"import '\.\./api/torrent_stream_service.dart'", "import 'package:forja_streaming/forja_streaming.dart'"),
    (r"import '\.\./api/webstreamr_service.dart'", "import 'package:forja_streaming/forja_streaming.dart'"),
    (r"import '\.\./api/nuvio_service.dart'", "import 'package:forja_streaming/forja_streaming.dart'"),
    (r"import '\.\./api/stream_providers.dart'", "import 'package:forja_streaming/forja_streaming.dart'"),
    (r"import '\.\./api/videasy_extractor.dart'", "import 'package:forja_streaming/forja_streaming.dart'"),
    (r"import '\.\./api/vidsrc_extractor.dart'", "import 'package:forja_streaming/forja_streaming.dart'"),
    (r"import '\.\./api/site111477_proxy.dart'", "import 'package:forja_streaming/forja_streaming.dart'"),
    (r"import '\.\./api/nuvio_bootstrap.dart'", "import 'package:forja_streaming/forja_streaming.dart'"),
    (r"import '\.\./api/nuvio_runtime.dart'", "import 'package:forja_streaming/forja_streaming.dart'"),
]


def apply(text: str, rules: list[tuple[str, str]]) -> str:
    for pattern, repl in rules:
        text = re.sub(pattern, repl, text)
    return text


def process(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    original = text
    text = apply(text, GLOBAL)
    if "packages/forja_api/" in str(path):
        text = apply(text, INSIDE_API)
    else:
        text = apply(text, OUTSIDE_API)
    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "packages")
    changed = sum(process(p) for p in root.rglob("*.dart"))
    print(f"Updated {changed} files")


if __name__ == "__main__":
    main()
