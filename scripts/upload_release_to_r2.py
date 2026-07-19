#!/usr/bin/env python3
"""Upload flattened release installers to Cloudflare R2 (S3 API).

Usage:
  R2_ACCOUNT_ID=… R2_ACCESS_KEY_ID=… R2_SECRET_ACCESS_KEY=… \\
    ./scripts/upload_release_to_r2.py <version> <asset-dir>

Optional env:
  R2_BUCKET=forja-releases
  R2_ENDPOINT=https://{account}.r2.cloudflarestorage.com
  RELEASE_STORAGE_KEEP=3

Objects:
  v{version}/{filename}
  latest/{filename}
  latest/manifest.json   — app updater discovery (version + asset filenames only)
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
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
        extra_headers={"content-type": "application/octet-stream"},
        body=body,
        unsigned_payload=True,
    )


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


def main() -> None:
    if len(sys.argv) != 3:
        die("Usage: upload_release_to_r2.py <version> <asset-dir>")

    version = sys.argv[1].lstrip("v")
    asset_dir = Path(sys.argv[2])
    keep = max(1, int(os.environ.get("RELEASE_STORAGE_KEEP", "3")))
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
    endpoint = endpoint.rstrip("/")

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

    # Changelog/notes stay on GitHub Releases — manifest is version + files only.
    published_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    manifest = {
        "version": version,
        "published_at": published_at,
        "assets": latest_names,
    }
    manifest_bytes = (json.dumps(manifest, indent=2) + "\n").encode("utf-8")
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tmp:
        tmp.write(manifest_bytes)
        tmp_path = Path(tmp.name)
    try:
        print(f"Uploading latest/manifest.json → s3://{bucket}/latest/manifest.json")
        put_object(
            endpoint=endpoint,
            bucket=bucket,
            key="latest/manifest.json",
            path=tmp_path,
            access_key=access_key,
            secret_key=secret_key,
        )
        print(f"  mirror → s3://{bucket}/{prefix}/manifest.json")
        put_object(
            endpoint=endpoint,
            bucket=bucket,
            key=f"{prefix}/manifest.json",
            path=tmp_path,
            access_key=access_key,
            secret_key=secret_key,
        )
    finally:
        tmp_path.unlink(missing_ok=True)

    print(
        f"Uploaded {uploaded} release asset(s) + manifest to R2 "
        f"({bucket}/{prefix}/ + latest/)."
    )

    # Drop stale objects under latest/ that are not part of this release.
    all_keys = list_keys(
        endpoint=endpoint,
        bucket=bucket,
        access_key=access_key,
        secret_key=secret_key,
    )
    latest_keep = {f"latest/{n}" for n in latest_names} | {"latest/manifest.json"}
    stale_latest = [
        k
        for k in all_keys
        if k.startswith("latest/") and k not in latest_keep
    ]
    if stale_latest:
        print(f"Removing {len(stale_latest)} stale latest/ object(s)…")
        delete_keys(
            endpoint=endpoint,
            bucket=bucket,
            keys=stale_latest,
            access_key=access_key,
            secret_key=secret_key,
        )

    print(f"Pruning R2 to newest {keep} version(s)…")

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

    keep_set = set(versions[:keep])
    drop = [v for v in versions if v not in keep_set]
    print(f"Keeping: {', '.join(versions[:keep])}")
    if not drop:
        print("Nothing older than retention window.")
        return

    print(f"Deleting: {', '.join(drop)}")
    to_remove = [k for k in keys if k.split("/", 1)[0] in drop]
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
