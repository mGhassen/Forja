#!/bin/sh
# PasskeysPlugin is @available(macOS 13.5, *). Keep app deploy target at 10.15
# and only register the plugin on OS versions that support it — do not raise
# MACOSX_DEPLOYMENT_TARGET for the whole app.
#
# Flutter regenerates GeneratedPluginRegistrant.swift on assemble; this script
# re-applies the availability gate before Sources compile.
set -e

FILE="${SRCROOT:-$(cd "$(dirname "$0")" && pwd)}/Flutter/GeneratedPluginRegistrant.swift"

if [ ! -f "$FILE" ]; then
  echo "note: $FILE missing — skip passkeys gate"
  exit 0
fi

# Already gated.
if grep -q 'if #available(macOS 13.5, \*)' "$FILE"; then
  exit 0
fi

# Unconditional register from Flutter tooling.
if ! grep -q 'PasskeysPlugin.register(with:' "$FILE"; then
  exit 0
fi

python3 - "$FILE" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
pattern = re.compile(
    r'^(\s*)PasskeysPlugin\.register\(with:\s*registry\.registrar\(forPlugin:\s*"PasskeysPlugin"\)\)\s*$',
    re.M,
)
replacement = (
    r'\1if #available(macOS 13.5, *) {\n'
    r'\1  PasskeysPlugin.register(with: registry.registrar(forPlugin: "PasskeysPlugin"))\n'
    r'\1}'
)
new, n = pattern.subn(replacement, text, count=1)
if n != 1:
    sys.stderr.write(
        f"error: expected exactly one PasskeysPlugin.register line in {path}, found {n}\n"
    )
    sys.exit(1)
path.write_text(new)
print(f"Gated PasskeysPlugin registration behind macOS 13.5 in {path}")
PY
