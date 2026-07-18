#!/usr/bin/env bash
# Upload flattened release installers to Supabase Storage bucket `releases`,
# then keep only the newest KEEP versions (default 3).
#
# Usage:
#   SUPABASE_URL=… SUPABASE_SERVICE_ROLE_KEY=… \
#     ./scripts/upload_release_to_supabase.sh <version> <asset-dir>
#
# Optional: RELEASE_STORAGE_KEEP=3 (versions retained after upload)
#
# Objects: releases/v{version}/{filename}
# Public URL: {SUPABASE_URL}/storage/v1/object/public/releases/v{version}/{filename}
set -euo pipefail

version="${1:-}"
asset_dir="${2:-}"
KEEP="${RELEASE_STORAGE_KEEP:-3}"

if [[ -z "$version" || -z "$asset_dir" ]]; then
  echo "Usage: $0 <version> <asset-dir>" >&2
  exit 1
fi

version="${version#v}"

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "::error::SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required." >&2
  exit 1
fi

if [[ ! -d "$asset_dir" ]]; then
  echo "::error::Asset directory not found: $asset_dir" >&2
  exit 1
fi

base_url="${SUPABASE_URL%/}"
prefix="v${version}"
uploaded=0

shopt -s nullglob
files=(
  "$asset_dir"/*.dmg
  "$asset_dir"/*.exe
  "$asset_dir"/*.AppImage
  "$asset_dir"/*.apk
)
shopt -u nullglob

if [[ "${#files[@]}" -eq 0 ]]; then
  echo "::error::No .dmg / .exe / .AppImage / .apk files in $asset_dir" >&2
  exit 1
fi

for file in "${files[@]}"; do
  name="$(basename "$file")"
  object_path="${prefix}/${name}"
  encoded_path="$(
    python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe="/"))' \
      "$object_path"
  )"
  url="${base_url}/storage/v1/object/releases/${encoded_path}"

  echo "Uploading ${name} → releases/${object_path}"
  http_code="$(
    curl -sS -o /tmp/forja-storage-upload.json -w '%{http_code}' \
      -X POST "$url" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "x-upsert: true" \
      -H "Content-Type: application/octet-stream" \
      --data-binary @"$file"
  )"

  if [[ "$http_code" != "200" && "$http_code" != "201" ]]; then
    echo "::error::Upload failed for ${name} (HTTP ${http_code})" >&2
    cat /tmp/forja-storage-upload.json >&2 || true
    exit 1
  fi

  public_url="${base_url}/storage/v1/object/public/releases/${object_path}"
  echo "  public: ${public_url}"
  uploaded=$((uploaded + 1))
done

echo "Uploaded ${uploaded} release asset(s) to Supabase Storage (releases/${prefix}/)."

echo "Pruning Storage to newest ${KEEP} version(s)…"
python3 - "$base_url" "$SUPABASE_SERVICE_ROLE_KEY" "$KEEP" <<'PY'
import json
import sys
import urllib.error
import urllib.request

base_url, service_key, keep_s = sys.argv[1], sys.argv[2], sys.argv[3]
keep = max(1, int(keep_s))
bucket = "releases"
headers = {
    "Authorization": "Bearer %s" % service_key,
    "apikey": service_key,
    "Content-Type": "application/json",
}


def api(method, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        "%s/storage/v1/%s" % (base_url, path),
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        raise SystemExit(
            "Storage API %s %s failed HTTP %s: %s" % (method, path, e.code, err)
        )


def list_prefix(prefix):
    items = []
    offset = 0
    while True:
        _status, page = api(
            "POST",
            "object/list/%s" % bucket,
            {"prefix": prefix, "limit": 100, "offset": offset},
        )
        if not page:
            break
        items.extend(page)
        if len(page) < 100:
            break
        offset += 100
    return items


def semver_key(tag):
    ver = tag[1:] if tag.startswith("v") else tag
    parts = ver.split(".")
    nums = []
    for i in range(3):
        try:
            nums.append(int(parts[i]) if i < len(parts) else 0)
        except ValueError:
            nums.append(0)
    return tuple(nums)


roots = list_prefix("")
versions = sorted(
    {
        item["name"].rstrip("/")
        for item in roots
        if item.get("name")
        and item["name"].startswith("v")
        and ("/" not in item["name"].rstrip("/"))
    },
    key=semver_key,
    reverse=True,
)

if not versions:
    print("No version folders found; nothing to prune.")
    raise SystemExit(0)

keep_set = set(versions[:keep])
drop = [v for v in versions if v not in keep_set]
print("Keeping: %s" % (", ".join(versions[:keep]) or "(none)"))
if not drop:
    print("Nothing older than retention window.")
    raise SystemExit(0)

print("Deleting: %s" % ", ".join(drop))
to_remove = []
for ver in drop:
    for item in list_prefix("%s/" % ver):
        name = item.get("name")
        if not name or name.endswith("/"):
            continue
        path = name if name.startswith("%s/" % ver) else "%s/%s" % (ver, name)
        to_remove.append(path)

if not to_remove:
    print("No objects under %s; done." % ", ".join(drop))
    raise SystemExit(0)

batch = 100
for i in range(0, len(to_remove), batch):
    chunk = to_remove[i : i + batch]
    api("DELETE", "object/%s" % bucket, chunk)
    for p in chunk:
        print("  removed %s" % p)

print(
    "Pruned %d object(s) from %d old version(s)."
    % (len(to_remove), len(drop))
)
PY
