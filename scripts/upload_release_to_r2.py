#!/usr/bin/env python3
"""Upload flattened release installers to Cloudflare R2 (S3 API).

Usage:
  R2_ACCOUNT_ID=… R2_ACCESS_KEY_ID=… R2_SECRET_ACCESS_KEY=… \\
    ./scripts/upload_release_to_r2.py <version> <asset-dir>

  # Patch AFTVnews codes into manifests after APKs are already on CDN:
  FORJA_DOWNLOADER_CODES=arm64=…,armeabi-v7a=… \\
    ./scripts/upload_release_to_r2.py --patch-downloader-codes <version>

Optional env:
  R2_BUCKET=forja-releases
  R2_ENDPOINT=https://{account}.r2.cloudflarestorage.com
  RELEASE_STORAGE_KEEP=3

Objects:
  v{version}/{filename}
  latest/{filename}
  latest/manifest.json   — per-platform latest (partial releases merge; do not wipe others)
  changelog/{version}.md — frozen release notes (kept forever; never pruned)
  changelog/index.json   — version list for the in-app update dialog

Manifest shape (latest/manifest.json):
  {
    "published_at": "…",
    "platforms": {
      "macos": {
        "version": "1.2.406",
        "published_at": "…",
        "assets": ["…-arm64.dmg", "…-x86_64.dmg"],
        "arches": {
          "arm64": { "version": "1.2.406", "filename": "…-arm64.dmg", "published_at": "…" },
          "x86_64": { "version": "1.2.400", "filename": "…-x86_64.dmg", "published_at": "…" }
        }
      },
      "windows": {
        "version": "1.2.400",
        "published_at": "…",
        "assets": ["…exe"],
        "arches": {
          "default": { "version": "1.2.400", "filename": "…exe", "published_at": "…" }
        }
      },
      "android_tv": {
        "version": "1.3.120",
        "published_at": "…",
        "assets": ["…-arm64.apk", "…-armeabi-v7a.apk"],
        "arches": {
          "arm64": { "version": "1.3.120", "filename": "…-arm64.apk", "published_at": "…" },
          "armeabi-v7a": { "version": "1.3.110", "filename": "…-armeabi-v7a.apk", "published_at": "…" }
        },
        "downloader_codes": { "arm64": "482913", "armeabi-v7a": "482914" }
      }
    }
  }

`platforms.*.version` is the max semver across arches (glance / old clients).
Truth for updates = `arches.{arch}.{version,filename}`.

Optional env:
  FORJA_DOWNLOADER_CODES=arm64=482913,armeabi-v7a=482914
    AFTVnews Downloader short codes for Android TV APKs (go.aftvnews.com).
    Merged into platforms.android_tv.downloader_codes by arch; website shows them.
    Prefer --patch-downloader-codes after upload (interactive release_local does this).
    Set before <version> <asset-dir> only for headless/CI one-shot uploads.

Within a platform, incoming assets replace only the same architecture
(arm64 / x86_64 / …). Other arches already in latest/ are kept — a one-arch
macOS or Android TV publish must not delete the sibling arch.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from base64 import b64encode
from datetime import datetime, timezone
from pathlib import Path

REGION = "auto"
SERVICE = "s3"
# Default account (not secret). Override with R2_ACCOUNT_ID if needed.
_DEFAULT_R2_ACCOUNT_ID = "e8d83ffa2ffe56b9b95da0f8ba54e956"


def die(msg: str, code: int = 1) -> None:
    print(f"::error::{msg}", file=sys.stderr)
    raise SystemExit(code)


def sign(key: bytes, msg: str) -> bytes:
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()


def aws_v4_headers(
    *,
    method: str,
    host: str,
    canonical_uri: str,
    query: str,
    access_key: str,
    secret_key: str,
    extra_headers: dict[str, str],
    body: bytes,
    unsigned_payload: bool = False,
) -> dict[str, str]:
    now = datetime.now(timezone.utc)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    payload_hash = (
        "UNSIGNED-PAYLOAD"
        if unsigned_payload
        else hashlib.sha256(body).hexdigest()
    )

    headers = {k.lower(): v for k, v in extra_headers.items()}
    headers["host"] = host
    headers["x-amz-content-sha256"] = payload_hash
    headers["x-amz-date"] = amz_date

    signed_header_names = sorted(headers)
    canonical_headers = "".join(f"{k}:{headers[k]}\n" for k in signed_header_names)
    signed_headers = ";".join(signed_header_names)
    canonical_request = "\n".join(
        [
            method,
            canonical_uri,
            query,
            canonical_headers,
            signed_headers,
            payload_hash,
        ]
    )
    credential_scope = f"{date_stamp}/{REGION}/{SERVICE}/aws4_request"
    string_to_sign = "\n".join(
        [
            "AWS4-HMAC-SHA256",
            amz_date,
            credential_scope,
            hashlib.sha256(canonical_request.encode("utf-8")).hexdigest(),
        ]
    )
    k_date = sign(f"AWS4{secret_key}".encode("utf-8"), date_stamp)
    k_region = sign(k_date, REGION)
    k_service = sign(k_region, SERVICE)
    k_signing = sign(k_service, "aws4_request")
    signature = hmac.new(
        k_signing, string_to_sign.encode("utf-8"), hashlib.sha256
    ).hexdigest()
    headers["authorization"] = (
        f"AWS4-HMAC-SHA256 Credential={access_key}/{credential_scope}, "
        f"SignedHeaders={signed_headers}, Signature={signature}"
    )
    return headers


def request(
    *,
    endpoint: str,
    method: str,
    canonical_uri: str,
    query: str = "",
    access_key: str,
    secret_key: str,
    extra_headers: dict[str, str] | None = None,
    body: bytes = b"",
    unsigned_payload: bool = False,
) -> bytes:
    host = endpoint.removeprefix("https://").removeprefix("http://")
    headers = aws_v4_headers(
        method=method,
        host=host,
        canonical_uri=canonical_uri,
        query=query,
        access_key=access_key,
        secret_key=secret_key,
        extra_headers=extra_headers or {},
        body=body,
        unsigned_payload=unsigned_payload,
    )
    url = f"{endpoint}{canonical_uri}"
    if query:
        url = f"{url}?{query}"
    req = urllib.request.Request(
        url,
        data=body if body or method in ("PUT", "POST") else None,
        method=method,
        headers=headers,
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        die(f"R2 {method} {canonical_uri} failed HTTP {e.code}: {err}")


def put_object(
    *,
    endpoint: str,
    bucket: str,
    key: str,
    path: Path,
    access_key: str,
    secret_key: str,
    content_type: str = "application/octet-stream",
) -> None:
    body = path.read_bytes()
    # Encode each path segment; keep slashes.
    encoded_key = "/".join(urllib.parse.quote(p, safe="") for p in key.split("/"))
    canonical_uri = f"/{bucket}/{encoded_key}"
    request(
        endpoint=endpoint,
        method="PUT",
        canonical_uri=canonical_uri,
        access_key=access_key,
        secret_key=secret_key,
        extra_headers={"content-type": content_type},
        body=body,
        unsigned_payload=True,
    )


def get_object_bytes(
    *,
    endpoint: str,
    bucket: str,
    key: str,
    access_key: str,
    secret_key: str,
) -> bytes | None:
    """Return object body, or None on 404."""
    encoded_key = "/".join(urllib.parse.quote(p, safe="") for p in key.split("/"))
    canonical_uri = f"/{bucket}/{encoded_key}"
    host = endpoint.removeprefix("https://").removeprefix("http://")
    headers = aws_v4_headers(
        method="GET",
        host=host,
        canonical_uri=canonical_uri,
        query="",
        access_key=access_key,
        secret_key=secret_key,
        extra_headers={},
        body=b"",
    )
    url = f"{endpoint}{canonical_uri}"
    req = urllib.request.Request(url, method="GET", headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        err = e.read().decode("utf-8", errors="replace")
        die(f"R2 GET {canonical_uri} failed HTTP {e.code}: {err}")
        return None


def detect_platform(name: str) -> str | None:
    """Map installer filename → showcase platform id (or None if unknown)."""
    lower = name.lower()
    if "windows" in lower or lower.endswith(".exe") or lower.endswith(".msi"):
        return "windows"
    if "macos" in lower or "darwin" in lower or lower.endswith(".dmg"):
        return "macos"
    if (
        "linux" in lower
        or lower.endswith(".appimage")
        or lower.endswith(".deb")
        or lower.endswith(".rpm")
    ):
        return "linux"
    if (
        "android-tv" in lower
        or "android_tv" in lower
        or "androidtv" in lower
        or lower.endswith(".apk")
        or "android" in lower
    ):
        return "android_tv"
    return None


_VERSION_IN_NAME = re.compile(r"(?i)forja-(\d+\.\d+\.\d+)")


def version_from_filename(name: str) -> str | None:
    """Semver embedded in Forja-{ver}-… installer names."""
    match = _VERSION_IN_NAME.search(name)
    return match.group(1) if match else None


def detect_arch(name: str) -> str:
    """
    Architecture slot for merge within a platform.

    Same slot → incoming replaces prior file. Different slot → both kept.
    Platforms with a single unversioned installer (Windows EXE) use "default".
    """
    lower = name.lower()
    if "armeabi-v7a" in lower or "armeabi_v7a" in lower:
        return "armeabi-v7a"
    if "arm64" in lower or "aarch64" in lower:
        return "arm64"
    if "x86_64" in lower or "x86-64" in lower or "amd64" in lower:
        return "x86_64"
    if re.search(r"(?<![a-z0-9])x86(?![_a-z0-9])", lower):
        return "x86"
    return "default"


def max_semver(versions: list[str]) -> str | None:
    cleaned = [v.strip().lstrip("v") for v in versions if v and str(v).strip()]
    if not cleaned:
        return None
    return max(cleaned, key=semver_key)


def build_arches(
    filenames: list[str],
    *,
    published_at: str,
    prior_arches: dict[str, dict] | None = None,
    incoming_arches: set[str] | None = None,
    fallback_version: str | None = None,
) -> dict[str, dict]:
    """
    Per-arch version + filename map.

    Replaced arches (in incoming_arches) get [published_at]; siblings keep prior
    arch published_at when present.
    """
    prior = prior_arches if isinstance(prior_arches, dict) else {}
    replaced = incoming_arches if incoming_arches is not None else set()
    out: dict[str, dict] = {}
    for name in filenames:
        if not isinstance(name, str) or not name.strip():
            continue
        arch = detect_arch(name)
        ver = version_from_filename(name) or (
            fallback_version.strip().lstrip("v")
            if isinstance(fallback_version, str) and fallback_version.strip()
            else None
        )
        if not ver:
            continue
        prior_entry = prior.get(arch) if isinstance(prior.get(arch), dict) else None
        if arch in replaced or prior_entry is None:
            arch_published = published_at
        else:
            prior_pub = prior_entry.get("published_at")
            arch_published = (
                prior_pub
                if isinstance(prior_pub, str) and prior_pub.strip()
                else published_at
            )
        out[arch] = {
            "version": ver,
            "filename": name,
            "published_at": arch_published,
        }
    return {
        arch: out[arch]
        for arch in sorted(out, key=lambda a: (_ARCH_ORDER.get(a, 50), a))
    }


def assets_from_arches(arches: dict[str, dict]) -> list[str]:
    return [
        entry["filename"]
        for arch in sorted(arches, key=lambda a: (_ARCH_ORDER.get(a, 50), a))
        if isinstance((entry := arches[arch]), dict)
        and isinstance(entry.get("filename"), str)
        and entry["filename"].strip()
    ]


def prior_arches_from_entry(entry: dict | None) -> dict[str, dict]:
    if not isinstance(entry, dict):
        return {}
    raw = entry.get("arches")
    if isinstance(raw, dict) and raw:
        out: dict[str, dict] = {}
        for arch, meta in raw.items():
            if not isinstance(arch, str) or not isinstance(meta, dict):
                continue
            filename = meta.get("filename")
            version = meta.get("version")
            if not isinstance(filename, str) or not filename.strip():
                continue
            ver = (
                version.strip().lstrip("v")
                if isinstance(version, str) and version.strip()
                else version_from_filename(filename)
            )
            if not ver:
                continue
            arch_entry: dict = {"version": ver, "filename": filename}
            pub = meta.get("published_at")
            if isinstance(pub, str) and pub.strip():
                arch_entry["published_at"] = pub
            out[arch] = arch_entry
        if out:
            return out
    # Derive from assets list when arches missing (legacy manifests).
    assets = entry.get("assets")
    if not isinstance(assets, list):
        return {}
    names = [a for a in assets if isinstance(a, str) and a.strip()]
    platform_pub = entry.get("published_at")
    published = platform_pub if isinstance(platform_pub, str) else ""
    fallback = entry.get("version")
    return build_arches(
        names,
        published_at=published or "",
        fallback_version=fallback if isinstance(fallback, str) else None,
    )


def platforms_from_filenames(
    filenames: list[str],
    *,
    version: str,
    published_at: str,
) -> dict[str, dict]:
    """Group filenames into a platforms map for one release version."""
    by_platform: dict[str, list[str]] = {}
    for name in filenames:
        platform = detect_platform(name)
        if platform is None:
            print(f"::warning::Skipping unrecognized asset (no platform): {name}")
            continue
        by_platform.setdefault(platform, []).append(name)
    out: dict[str, dict] = {}
    for platform, names in sorted(by_platform.items()):
        arches = build_arches(
            names,
            published_at=published_at,
            incoming_arches={detect_arch(n) for n in names},
            fallback_version=version,
        )
        if not arches:
            continue
        assets = assets_from_arches(arches)
        plat_ver = max_semver([e["version"] for e in arches.values()]) or version
        out[platform] = {
            "version": plat_ver,
            "published_at": published_at,
            "assets": assets,
            "arches": arches,
        }
    return out


_ARCH_ORDER = {"arm64": 0, "x86_64": 1, "armeabi-v7a": 2, "x86": 3, "default": 4}


def normalize_downloader_codes(raw: object) -> dict[str, str]:
    """arch → numeric AFTVnews Downloader code (digits only)."""
    if not isinstance(raw, dict):
        return {}
    out: dict[str, str] = {}
    for arch, code in raw.items():
        if not isinstance(arch, str) or not isinstance(code, (str, int)):
            continue
        arch_key = arch.strip()
        code_s = str(code).strip()
        if not arch_key or not code_s or not code_s.isdigit():
            continue
        out[arch_key] = code_s
    return out


def parse_downloader_codes_env(raw: str | None) -> dict[str, str]:
    """
    Parse FORJA_DOWNLOADER_CODES.

    Formats:
      arm64=482913,armeabi-v7a=482914
      {"arm64":"482913","armeabi-v7a":"482914"}
    """
    text = (raw or "").strip()
    if not text:
        return {}
    if text.startswith("{"):
        try:
            decoded = json.loads(text)
        except json.JSONDecodeError as e:
            die(f"FORJA_DOWNLOADER_CODES is not valid JSON: {e}")
        return normalize_downloader_codes(decoded)

    out: dict[str, str] = {}
    for part in text.split(","):
        part = part.strip()
        if not part:
            continue
        if "=" not in part and ":" not in part:
            die(
                f"FORJA_DOWNLOADER_CODES entry '{part}' "
                "want arch=code (e.g. arm64=482913)"
            )
        sep = "=" if "=" in part else ":"
        arch, code = part.split(sep, 1)
        arch = arch.strip()
        code = code.strip()
        if not arch or not code.isdigit():
            die(
                f"FORJA_DOWNLOADER_CODES entry '{part}' "
                "want arch=digits (e.g. arm64=482913)"
            )
        out[arch] = code
    return out


def merge_downloader_codes(
    *,
    prior_codes: dict[str, str],
    prior_assets: list[str],
    incoming_codes: dict[str, str],
    incoming_assets: list[str],
    merged_assets: list[str],
) -> dict[str, str]:
    """
    Keep codes for unchanged arches; require a fresh code when an arch APK is replaced.

    A replaced arch without an incoming code drops the stale code (old URL is gone).
    """
    prior_by_arch = {detect_arch(n): n for n in prior_assets}
    incoming_arches = {detect_arch(n) for n in incoming_assets}
    merged_arches = {detect_arch(n) for n in merged_assets}
    out: dict[str, str] = {}

    for arch in sorted(merged_arches, key=lambda a: (_ARCH_ORDER.get(a, 50), a)):
        if arch in incoming_codes:
            out[arch] = incoming_codes[arch]
            continue
        if arch in incoming_arches:
            # APK replaced/added this run — prior code pointed at the old filename.
            continue
        prior_name = prior_by_arch.get(arch)
        merged_name = next(
            (n for n in merged_assets if detect_arch(n) == arch), None
        )
        if (
            prior_name
            and merged_name
            and prior_name == merged_name
            and arch in prior_codes
        ):
            out[arch] = prior_codes[arch]

    return {
        arch: out[arch]
        for arch in sorted(out, key=lambda a: (_ARCH_ORDER.get(a, 50), a))
    }


def atv_arch_keys(entry: dict) -> set[str]:
    """Architecture slots present on an android_tv platform entry."""
    arches = entry.get("arches")
    if isinstance(arches, dict) and arches:
        return {a for a in arches if isinstance(a, str) and a.strip()}
    assets = entry.get("assets")
    if isinstance(assets, list):
        return {detect_arch(n) for n in assets if isinstance(n, str) and n.strip()}
    return set()


def apply_downloader_codes_to_atv_entry(
    entry: dict,
    codes: dict[str, str],
) -> tuple[dict, dict[str, str]]:
    """
    Merge incoming codes into platforms.android_tv.downloader_codes.

    Incoming wins per arch; other arches keep prior codes. Returns
    (updated_entry, applied_codes_for_present_arches).
    """
    present = atv_arch_keys(entry)
    applied = {a: c for a, c in codes.items() if a in present}
    merged = normalize_downloader_codes(entry.get("downloader_codes"))
    merged.update(applied)
    merged = {a: c for a, c in merged.items() if a in present}
    out = dict(entry)
    if merged:
        out["downloader_codes"] = {
            arch: merged[arch]
            for arch in sorted(merged, key=lambda a: (_ARCH_ORDER.get(a, 50), a))
        }
    else:
        out.pop("downloader_codes", None)
    return out, {
        arch: applied[arch]
        for arch in sorted(applied, key=lambda a: (_ARCH_ORDER.get(a, 50), a))
    }


def _normalize_platform_entry(
    entry: dict,
    *,
    fallback_published_at: str | None,
) -> dict | None:
    published = entry.get("published_at")
    if not isinstance(published, str) or not published.strip():
        published = fallback_published_at
    published_s = published if isinstance(published, str) and published.strip() else ""

    arches = prior_arches_from_entry(entry)
    if not arches and isinstance(entry.get("assets"), list):
        names = [a for a in entry["assets"] if isinstance(a, str) and a.strip()]
        fallback = entry.get("version")
        arches = build_arches(
            names,
            published_at=published_s,
            fallback_version=fallback if isinstance(fallback, str) else None,
        )
    if not arches:
        return None

    # Refresh published_at on arch entries missing it.
    for arch, meta in list(arches.items()):
        if "published_at" not in meta and published_s:
            arches[arch] = {**meta, "published_at": published_s}

    assets = assets_from_arches(arches)
    from_names = [e["version"] for e in arches.values() if isinstance(e.get("version"), str)]
    ver = entry.get("version")
    if isinstance(ver, str) and ver.strip():
        from_names.append(ver.strip().lstrip("v"))
    version = max_semver(from_names)
    if not version:
        return None

    out: dict = {
        "version": version,
        "assets": assets,
        "arches": arches,
    }
    if published_s:
        out["published_at"] = published_s
    codes = normalize_downloader_codes(entry.get("downloader_codes"))
    if codes:
        present = set(arches)
        codes = {a: c for a, c in codes.items() if a in present}
        if codes:
            out["downloader_codes"] = {
                arch: codes[arch]
                for arch in sorted(codes, key=lambda a: (_ARCH_ORDER.get(a, 50), a))
            }
    return out


def merge_assets_by_arch(existing_names: list[str], incoming_names: list[str]) -> list[str]:
    """
    Merge installer lists: incoming wins per architecture slot; other slots kept.
    """
    by_arch: dict[str, str] = {}
    for name in existing_names:
        by_arch[detect_arch(name)] = name
    for name in incoming_names:
        by_arch[detect_arch(name)] = name
    return [
        name
        for _, name in sorted(
            by_arch.items(),
            key=lambda item: (_ARCH_ORDER.get(item[0], 50), item[0], item[1]),
        )
    ]


def merge_platform_manifest(
    existing: dict | None,
    incoming: dict[str, dict],
    *,
    published_at: str,
) -> dict:
    """
    Merge incoming platform entries into existing latest manifest.

    - Platforms not in this upload are kept untouched.
    - Platforms in this upload merge **by architecture**: only the uploaded
      arch(es) replace prior files; sibling arches stay (may be older versions).
    - Platform `version` is the max semver among remaining arch entries.
    - `arches` is the per-arch source of truth (version + filename).
    - `downloader_codes` merge by arch (Android TV AFTVnews codes).
    """
    platforms: dict[str, dict] = {}
    if isinstance(existing, dict):
        raw = existing.get("platforms")
        if isinstance(raw, dict):
            for key, entry in raw.items():
                if not isinstance(key, str) or not isinstance(entry, dict):
                    continue
                normalized = _normalize_platform_entry(
                    entry,
                    fallback_published_at=(
                        entry.get("published_at")
                        if isinstance(entry.get("published_at"), str)
                        else existing.get("published_at")
                        if isinstance(existing.get("published_at"), str)
                        else published_at
                    ),
                )
                if normalized:
                    platforms[key] = normalized
        elif isinstance(existing.get("assets"), list) and existing.get("version"):
            # Legacy flat manifest → one synthetic entry set (all assets same version).
            legacy_ver = str(existing["version"]).strip().lstrip("v")
            legacy_names = [
                a for a in existing["assets"] if isinstance(a, str) and a.strip()
            ]
            platforms.update(
                platforms_from_filenames(
                    legacy_names,
                    version=legacy_ver,
                    published_at=(
                        existing.get("published_at")
                        if isinstance(existing.get("published_at"), str)
                        else published_at
                    ),
                )
            )

    for key, entry in incoming.items():
        if not isinstance(entry, dict):
            continue
        incoming_assets = entry.get("assets")
        if not isinstance(incoming_assets, list):
            continue
        new_names = [a for a in incoming_assets if isinstance(a, str) and a.strip()]
        if not new_names:
            continue
        prior = platforms.get(key)
        prior_names = (
            [a for a in prior["assets"] if isinstance(a, str)]
            if isinstance(prior, dict) and isinstance(prior.get("assets"), list)
            else []
        )
        prior_codes = (
            normalize_downloader_codes(prior.get("downloader_codes"))
            if isinstance(prior, dict)
            else {}
        )
        incoming_codes = normalize_downloader_codes(entry.get("downloader_codes"))
        merged_names = merge_assets_by_arch(prior_names, new_names)
        incoming_arch_keys = {detect_arch(n) for n in new_names}
        entry_published = (
            entry.get("published_at")
            if isinstance(entry.get("published_at"), str)
            else published_at
        )
        arches = build_arches(
            merged_names,
            published_at=entry_published,
            prior_arches=prior_arches_from_entry(prior),
            incoming_arches=incoming_arch_keys,
            fallback_version=(
                entry.get("version")
                if isinstance(entry.get("version"), str)
                else None
            ),
        )
        from_names = [e["version"] for e in arches.values()]
        entry_ver = entry.get("version")
        if isinstance(entry_ver, str) and entry_ver.strip():
            from_names.append(entry_ver.strip().lstrip("v"))
        version = max_semver(from_names) or (
            entry_ver.strip().lstrip("v")
            if isinstance(entry_ver, str) and entry_ver.strip()
            else None
        )
        if not version or not arches:
            continue
        platform_entry: dict = {
            "version": version,
            "published_at": entry_published,
            "assets": assets_from_arches(arches),
            "arches": arches,
        }
        codes = merge_downloader_codes(
            prior_codes=prior_codes,
            prior_assets=prior_names,
            incoming_codes=incoming_codes,
            incoming_assets=new_names,
            merged_assets=merged_names,
        )
        if codes:
            platform_entry["downloader_codes"] = codes
        if key == "android_tv":
            for arch in sorted(
                incoming_arch_keys,
                key=lambda a: (_ARCH_ORDER.get(a, 50), a),
            ):
                if arch not in codes:
                    print(
                        f"::warning::No Downloader code for {key}/{arch} — "
                        "set FORJA_DOWNLOADER_CODES and run "
                        "--patch-downloader-codes, or pass codes on upload"
                    )
        platforms[key] = platform_entry

    return {
        "published_at": published_at,
        "platforms": platforms,
    }


def flat_assets_from_platforms(platforms: dict[str, dict]) -> list[str]:
    out: list[str] = []
    for entry in platforms.values():
        assets = entry.get("assets")
        if not isinstance(assets, list):
            continue
        out.extend(a for a in assets if isinstance(a, str) and a.strip())
    return out


def stale_latest_keys(
    *,
    all_keys: list[str],
    merged_assets: list[str],
    replaced_platforms: set[str],
) -> list[str]:
    """
    latest/ files to delete after a partial upload.

    Only drop files for platforms touched this run that are no longer in the
    merged asset list (superseded same-arch builds). Sibling arches that
    merge_platform_manifest kept stay in merged_assets and are not deleted.
    Never wipe other platforms.
    """
    keep = {f"latest/{n}" for n in merged_assets} | {"latest/manifest.json"}
    stale: list[str] = []
    for key in all_keys:
        if not key.startswith("latest/") or key in keep:
            continue
        name = key[len("latest/") :]
        if name == "manifest.json":
            continue
        platform = detect_platform(name)
        if platform is None or platform not in replaced_platforms:
            continue
        stale.append(key)
    return stale


def referenced_version_prefixes(platforms: dict[str, dict]) -> set[str]:
    """v{semver} prefixes still serving any platform latest asset — never prune."""
    out: set[str] = set()
    for entry in platforms.values():
        if not isinstance(entry, dict):
            continue
        ver = entry.get("version")
        if isinstance(ver, str) and ver.strip():
            out.add(f"v{ver.strip().lstrip('v')}")
        assets = entry.get("assets")
        if not isinstance(assets, list):
            continue
        for name in assets:
            if not isinstance(name, str):
                continue
            from_name = version_from_filename(name)
            if from_name:
                out.add(f"v{from_name}")
    return out


_RELEASED_MD = re.compile(r"^(\d+\.\d+\.\d+)-\[released\]\.md$")


def changelog_done_dir() -> Path:
    return Path(__file__).resolve().parent.parent / "docs" / "changelog" / "done"


def collect_released_changelogs(done_dir: Path) -> list[tuple[str, Path]]:
    """Return (version, path) for every docs/changelog/done/*-[released].md."""
    if not done_dir.is_dir():
        return []
    out: list[tuple[str, Path]] = []
    for path in sorted(done_dir.iterdir()):
        if not path.is_file():
            continue
        match = _RELEASED_MD.match(path.name)
        if not match:
            continue
        out.append((match.group(1), path))
    out.sort(key=lambda item: semver_key(item[0]), reverse=True)
    return out


def upload_changelog_archive(
    *,
    endpoint: str,
    bucket: str,
    access_key: str,
    secret_key: str,
) -> int:
    """Mirror frozen changelog markdown under changelog/ (never pruned)."""
    entries = collect_released_changelogs(changelog_done_dir())
    if not entries:
        print("No docs/changelog/done/*-[released].md files; skipping changelog/ upload.")
        return 0

    uploaded = 0
    for version, path in entries:
        key = f"changelog/{version}.md"
        print(f"Uploading {path.name} → s3://{bucket}/{key}")
        put_object(
            endpoint=endpoint,
            bucket=bucket,
            key=key,
            path=path,
            access_key=access_key,
            secret_key=secret_key,
            content_type="text/markdown; charset=utf-8",
        )
        uploaded += 1

    index = {
        "versions": [version for version, _ in entries],
    }
    index_bytes = (json.dumps(index, indent=2) + "\n").encode("utf-8")
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tmp:
        tmp.write(index_bytes)
        tmp_path = Path(tmp.name)
    try:
        print(f"Uploading changelog/index.json → s3://{bucket}/changelog/index.json")
        put_object(
            endpoint=endpoint,
            bucket=bucket,
            key="changelog/index.json",
            path=tmp_path,
            access_key=access_key,
            secret_key=secret_key,
            content_type="application/json; charset=utf-8",
        )
    finally:
        tmp_path.unlink(missing_ok=True)

    print(f"Uploaded {uploaded} changelog markdown file(s) + index.json under changelog/.")
    return uploaded


def list_keys(
    *,
    endpoint: str,
    bucket: str,
    access_key: str,
    secret_key: str,
) -> list[str]:
    keys: list[str] = []
    token: str | None = None
    while True:
        params: dict[str, str] = {"list-type": "2"}
        if token:
            params["continuation-token"] = token
        query = urllib.parse.urlencode(params)
        raw = request(
            endpoint=endpoint,
            method="GET",
            canonical_uri=f"/{bucket}",
            query=query,
            access_key=access_key,
            secret_key=secret_key,
        )
        root = ET.fromstring(raw)
        ns = root.tag.split("}")[0] + "}" if root.tag.startswith("{") else ""
        for contents in root.findall(f"{ns}Contents"):
            key_el = contents.find(f"{ns}Key")
            if key_el is not None and key_el.text:
                keys.append(key_el.text)
        truncated = root.find(f"{ns}IsTruncated")
        if truncated is not None and truncated.text == "true":
            next_token = root.find(f"{ns}NextContinuationToken")
            token = next_token.text if next_token is not None else None
            if not token:
                break
        else:
            break
    return keys


def delete_keys(
    *,
    endpoint: str,
    bucket: str,
    keys: list[str],
    access_key: str,
    secret_key: str,
) -> None:
    for i in range(0, len(keys), 1000):
        chunk = keys[i : i + 1000]
        parts = [
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<Delete xmlns="http://s3.amazonaws.com/doc/2006-03-01/">',
            "<Quiet>true</Quiet>",
        ]
        for key in chunk:
            safe = (
                key.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
            )
            parts.append(f"<Object><Key>{safe}</Key></Object>")
        parts.append("</Delete>")
        body = "".join(parts).encode("utf-8")
        md5 = b64encode(hashlib.md5(body).digest()).decode("ascii")
        request(
            endpoint=endpoint,
            method="POST",
            canonical_uri=f"/{bucket}",
            query="delete=",
            access_key=access_key,
            secret_key=secret_key,
            extra_headers={
                "content-type": "application/xml",
                "content-md5": md5,
            },
            body=body,
        )
        for key in chunk:
            print(f"  removed {key}")


def semver_key(tag: str) -> tuple[int, int, int]:
    ver = tag[1:] if tag.startswith("v") else tag
    parts = ver.split(".")
    nums: list[int] = []
    for i in range(3):
        try:
            nums.append(int(parts[i]) if i < len(parts) else 0)
        except ValueError:
            nums.append(0)
    return nums[0], nums[1], nums[2]


def human_size(n: int) -> str:
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unit == "GiB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} GiB"


def r2_config() -> tuple[str, str, str, str]:
    """Return (endpoint, bucket, access_key, secret_key)."""
    bucket = os.environ.get("R2_BUCKET", "forja-releases")
    account_id = os.environ.get("R2_ACCOUNT_ID", _DEFAULT_R2_ACCOUNT_ID).strip()
    access_key = os.environ.get("R2_ACCESS_KEY_ID", "").strip()
    secret_key = os.environ.get("R2_SECRET_ACCESS_KEY", "").strip()
    endpoint = os.environ.get("R2_ENDPOINT", "").strip()

    if not access_key or not secret_key:
        die("R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY are required.")
    if not account_id:
        die("R2_ACCOUNT_ID is required.")
    if not endpoint:
        endpoint = f"https://{account_id}.r2.cloudflarestorage.com"
    return endpoint.rstrip("/"), bucket, access_key, secret_key


def put_json_object(
    *,
    endpoint: str,
    bucket: str,
    key: str,
    payload: dict,
    access_key: str,
    secret_key: str,
) -> None:
    body = (json.dumps(payload, indent=2) + "\n").encode("utf-8")
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tmp:
        tmp.write(body)
        tmp_path = Path(tmp.name)
    try:
        print(f"Uploading {key} → s3://{bucket}/{key}")
        put_object(
            endpoint=endpoint,
            bucket=bucket,
            key=key,
            path=tmp_path,
            access_key=access_key,
            secret_key=secret_key,
            content_type="application/json; charset=utf-8",
        )
    finally:
        tmp_path.unlink(missing_ok=True)


def load_manifest_json(
    *,
    endpoint: str,
    bucket: str,
    key: str,
    access_key: str,
    secret_key: str,
) -> dict | None:
    raw = get_object_bytes(
        endpoint=endpoint,
        bucket=bucket,
        key=key,
        access_key=access_key,
        secret_key=secret_key,
    )
    if not raw:
        return None
    try:
        decoded = json.loads(raw.decode("utf-8"))
    except json.JSONDecodeError:
        print(f"::warning::{key} is not valid JSON; treating as missing.")
        return None
    return decoded if isinstance(decoded, dict) else None


def patch_downloader_codes(version: str) -> None:
    """
    Merge FORJA_DOWNLOADER_CODES into latest/ + v{version}/ manifests.

    APKs must already be on CDN — interactive release_local prompts after upload.
    """
    version = version.lstrip("v")
    codes = parse_downloader_codes_env(os.environ.get("FORJA_DOWNLOADER_CODES"))
    if not codes:
        die(
            "FORJA_DOWNLOADER_CODES required "
            "(e.g. arm64=482913,armeabi-v7a=482914)"
        )

    endpoint, bucket, access_key, secret_key = r2_config()
    prefix = f"v{version}"
    latest_key = "latest/manifest.json"
    version_key = f"{prefix}/manifest.json"

    latest = load_manifest_json(
        endpoint=endpoint,
        bucket=bucket,
        key=latest_key,
        access_key=access_key,
        secret_key=secret_key,
    )
    if not latest:
        die(f"{latest_key} missing — upload Android TV APKs before patching codes")

    platforms = latest.get("platforms")
    if not isinstance(platforms, dict):
        die(f"{latest_key} has no platforms object")
    atv = platforms.get("android_tv")
    if not isinstance(atv, dict):
        die(f"{latest_key} has no android_tv platform — upload APKs first")

    present = atv_arch_keys(atv)
    unused = sorted(a for a in codes if a not in present)
    if unused:
        print(
            "::warning::Downloader codes for arches not in latest android_tv "
            f"(ignored): {', '.join(unused)}"
        )
    updated_atv, applied = apply_downloader_codes_to_atv_entry(atv, codes)
    if not applied:
        die(
            "No Downloader codes matched android_tv arches in latest/manifest.json "
            f"(present: {', '.join(sorted(present)) or 'none'})"
        )
    platforms = dict(platforms)
    platforms["android_tv"] = updated_atv
    latest = dict(latest)
    latest["platforms"] = platforms
    put_json_object(
        endpoint=endpoint,
        bucket=bucket,
        key=latest_key,
        payload=latest,
        access_key=access_key,
        secret_key=secret_key,
    )

    version_manifest = load_manifest_json(
        endpoint=endpoint,
        bucket=bucket,
        key=version_key,
        access_key=access_key,
        secret_key=secret_key,
    )
    if version_manifest:
        v_platforms = version_manifest.get("platforms")
        if isinstance(v_platforms, dict):
            v_atv = v_platforms.get("android_tv")
            if isinstance(v_atv, dict):
                v_updated, v_applied = apply_downloader_codes_to_atv_entry(v_atv, codes)
                if v_applied:
                    v_platforms = dict(v_platforms)
                    v_platforms["android_tv"] = v_updated
                    version_manifest = dict(version_manifest)
                    version_manifest["platforms"] = v_platforms
                    put_json_object(
                        endpoint=endpoint,
                        bucket=bucket,
                        key=version_key,
                        payload=version_manifest,
                        access_key=access_key,
                        secret_key=secret_key,
                    )
                else:
                    print(
                        f"::warning::{version_key} android_tv has no matching arches "
                        "for these codes — latest/ updated only"
                    )
            else:
                print(
                    f"::warning::{version_key} has no android_tv — latest/ updated only"
                )
        else:
            print(f"::warning::{version_key} has no platforms — latest/ updated only")
    else:
        print(f"::warning::{version_key} missing — latest/ updated only")

    print(
        "Patched downloader_codes: "
        + ", ".join(f"{a}={c}" for a, c in applied.items())
    )


def main() -> None:
    if len(sys.argv) >= 2 and sys.argv[1] == "--patch-downloader-codes":
        if len(sys.argv) != 3:
            die(
                "Usage: upload_release_to_r2.py --patch-downloader-codes <version>"
            )
        patch_downloader_codes(sys.argv[2])
        return

    if len(sys.argv) != 3:
        die(
            "Usage: upload_release_to_r2.py <version> <asset-dir>\n"
            "       upload_release_to_r2.py --patch-downloader-codes <version>"
        )

    version = sys.argv[1].lstrip("v")
    asset_dir = Path(sys.argv[2])
    keep = max(1, int(os.environ.get("RELEASE_STORAGE_KEEP", "3")))
    endpoint, bucket, access_key, secret_key = r2_config()

    if not asset_dir.is_dir():
        die(f"Asset directory not found: {asset_dir}")

    files = sorted(
        p
        for p in asset_dir.iterdir()
        if p.is_file()
        and (
            p.suffix.lower() in {".dmg", ".exe", ".apk"}
            or p.name.endswith(".AppImage")
        )
    )
    if not files:
        die(f"No .dmg / .exe / .AppImage / .apk files in {asset_dir}")

    prefix = f"v{version}"
    uploaded = 0
    latest_names: list[str] = []
    for path in files:
        key = f"{prefix}/{path.name}"
        size = path.stat().st_size
        print(f"Uploading {path.name} ({human_size(size)}) → s3://{bucket}/{key}")
        put_object(
            endpoint=endpoint,
            bucket=bucket,
            key=key,
            path=path,
            access_key=access_key,
            secret_key=secret_key,
        )
        latest_key = f"latest/{path.name}"
        print(f"  mirror → s3://{bucket}/{latest_key}")
        put_object(
            endpoint=endpoint,
            bucket=bucket,
            key=latest_key,
            path=path,
            access_key=access_key,
            secret_key=secret_key,
        )
        latest_names.append(path.name)
        uploaded += 1

    published_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    incoming_platforms = platforms_from_filenames(
        latest_names,
        version=version,
        published_at=published_at,
    )
    if not incoming_platforms:
        die("No assets mapped to a known platform (windows/macos/linux/android_tv).")

    # AFTVnews Downloader codes → platforms.android_tv.downloader_codes (website).
    # Headless/CI: set FORJA_DOWNLOADER_CODES before upload. Interactive release_local
    # uploads first, then --patch-downloader-codes.
    env_codes = parse_downloader_codes_env(os.environ.get("FORJA_DOWNLOADER_CODES"))
    if env_codes:
        atv = incoming_platforms.get("android_tv")
        if not isinstance(atv, dict):
            print(
                "::warning::FORJA_DOWNLOADER_CODES set but this upload has no "
                "Android TV APKs — codes ignored"
            )
        else:
            atv_arches = {detect_arch(n) for n in atv.get("assets", []) if isinstance(n, str)}
            unused = sorted(a for a in env_codes if a not in atv_arches)
            if unused:
                print(
                    "::warning::Downloader codes for arches not in this upload "
                    f"(ignored): {', '.join(unused)}"
                )
            applied = {a: c for a, c in env_codes.items() if a in atv_arches}
            if applied:
                atv["downloader_codes"] = {
                    arch: applied[arch]
                    for arch in sorted(
                        applied, key=lambda a: (_ARCH_ORDER.get(a, 50), a)
                    )
                }
                print(
                    "Downloader codes: "
                    + ", ".join(f"{a}={c}" for a, c in atv["downloader_codes"].items())
                )

    existing_manifest = load_manifest_json(
        endpoint=endpoint,
        bucket=bucket,
        key="latest/manifest.json",
        access_key=access_key,
        secret_key=secret_key,
    )

    merged = merge_platform_manifest(
        existing_manifest,
        incoming_platforms,
        published_at=published_at,
    )

    # Versioned tree: this release only. latest/: merged per-platform view.
    version_manifest = {
        "version": version,
        "published_at": published_at,
        "assets": latest_names,
        "platforms": incoming_platforms,
    }

    put_json_object(
        endpoint=endpoint,
        bucket=bucket,
        key="latest/manifest.json",
        payload=merged,
        access_key=access_key,
        secret_key=secret_key,
    )
    put_json_object(
        endpoint=endpoint,
        bucket=bucket,
        key=f"{prefix}/manifest.json",
        payload=version_manifest,
        access_key=access_key,
        secret_key=secret_key,
    )

    # Permanent notes archive — never pruned with installer retention.
    upload_changelog_archive(
        endpoint=endpoint,
        bucket=bucket,
        access_key=access_key,
        secret_key=secret_key,
    )

    merged_assets = flat_assets_from_platforms(merged["platforms"])
    print(
        f"Uploaded {uploaded} release asset(s) + merged latest/manifest "
        f"({bucket}/{prefix}/ + latest/). Platforms: "
        + ", ".join(
            f"{p}@{e['version']}" for p, e in sorted(merged["platforms"].items())
        )
    )

    # Drop superseded installers only for platforms this run replaced.
    # Never wipe other platforms' latest/ files. Never touch changelog/.
    all_keys = list_keys(
        endpoint=endpoint,
        bucket=bucket,
        access_key=access_key,
        secret_key=secret_key,
    )
    stale_latest = stale_latest_keys(
        all_keys=all_keys,
        merged_assets=merged_assets,
        replaced_platforms=set(incoming_platforms),
    )
    if stale_latest:
        print(
            f"Removing {len(stale_latest)} superseded latest/ object(s) "
            f"for {', '.join(sorted(incoming_platforms))}…"
        )
        delete_keys(
            endpoint=endpoint,
            bucket=bucket,
            keys=stale_latest,
            access_key=access_key,
            secret_key=secret_key,
        )

    print(f"Pruning R2 installer prefixes to newest {keep} version(s)…")

    keys = all_keys
    versions = sorted(
        {
            k.split("/", 1)[0]
            for k in keys
            if "/" in k and k.split("/", 1)[0].startswith("v")
        },
        key=semver_key,
        reverse=True,
    )
    if not versions:
        print("No version prefixes found; nothing to prune.")
        return

    # Never prune a version still serving any platform latest (incl. older arch).
    referenced = referenced_version_prefixes(merged["platforms"])
    keep_set = set(versions[:keep]) | referenced
    drop = [v for v in versions if v not in keep_set]
    print(f"Keeping (window): {', '.join(versions[:keep])}")
    if referenced - set(versions[:keep]):
        print(
            "Keeping (platform latest): "
            + ", ".join(sorted(referenced - set(versions[:keep])))
        )
    if not drop:
        print("Nothing older than retention window.")
        return

    print(f"Deleting: {', '.join(drop)}")
    # Only v{version}/ installer trees — never changelog/ or latest/.
    to_remove = [
        k
        for k in keys
        if k.split("/", 1)[0] in drop and not k.startswith("changelog/")
    ]
    if not to_remove:
        print(f"No objects under {', '.join(drop)}; done.")
        return

    delete_keys(
        endpoint=endpoint,
        bucket=bucket,
        keys=to_remove,
        access_key=access_key,
        secret_key=secret_key,
    )
    print(f"Pruned {len(to_remove)} object(s) from {len(drop)} old version(s).")


if __name__ == "__main__":
    main()
