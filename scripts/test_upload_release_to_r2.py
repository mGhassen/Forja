#!/usr/bin/env python3
"""Unit tests for per-platform latest/ merge helpers."""

from __future__ import annotations

import unittest

from upload_release_to_r2 import (
    detect_platform,
    merge_platform_manifest,
    platforms_from_filenames,
    stale_latest_keys,
)


class DetectPlatformTest(unittest.TestCase):
    def test_known(self) -> None:
        self.assertEqual(detect_platform("Forja-1.2.1-windows-setup.exe"), "windows")
        self.assertEqual(detect_platform("Forja-1.2.1-macos-arm64.dmg"), "macos")
        self.assertEqual(
            detect_platform("Forja-1.2.1-linux-x86_64.AppImage"), "linux"
        )
        self.assertEqual(
            detect_platform("Forja-1.2.1-android-tv-arm64.apk"), "android_tv"
        )


class MergePlatformManifestTest(unittest.TestCase):
    def test_partial_macos_keeps_windows(self) -> None:
        existing = {
            "version": "1.2.400",
            "published_at": "2026-07-01T00:00:00Z",
            "platforms": {
                "windows": {
                    "version": "1.2.400",
                    "published_at": "2026-07-01T00:00:00Z",
                    "assets": ["Forja-1.2.400-windows-setup.exe"],
                },
                "macos": {
                    "version": "1.2.399",
                    "published_at": "2026-06-30T00:00:00Z",
                    "assets": ["Forja-1.2.399-macos-arm64.dmg"],
                },
            },
            "assets": [
                "Forja-1.2.400-windows-setup.exe",
                "Forja-1.2.399-macos-arm64.dmg",
            ],
        }
        incoming = platforms_from_filenames(
            ["Forja-1.2.406-macos-arm64.dmg"],
            version="1.2.406",
            published_at="2026-07-21T00:00:00Z",
        )
        merged = merge_platform_manifest(
            existing, incoming, published_at="2026-07-21T00:00:00Z"
        )
        self.assertEqual(merged["platforms"]["macos"]["version"], "1.2.406")
        self.assertEqual(merged["platforms"]["windows"]["version"], "1.2.400")
        self.assertNotIn("version", merged)
        self.assertNotIn("assets", merged)
        flat = [
            a
            for e in merged["platforms"].values()
            for a in e["assets"]
        ]
        self.assertIn("Forja-1.2.400-windows-setup.exe", flat)
        self.assertIn("Forja-1.2.406-macos-arm64.dmg", flat)
        self.assertNotIn("Forja-1.2.399-macos-arm64.dmg", flat)

    def test_legacy_flat_manifest_promotes(self) -> None:
        existing = {
            "version": "1.2.400",
            "published_at": "2026-07-01T00:00:00Z",
            "assets": [
                "Forja-1.2.400-windows-setup.exe",
                "Forja-1.2.400-macos-arm64.dmg",
            ],
        }
        incoming = platforms_from_filenames(
            ["Forja-1.2.406-macos-arm64.dmg"],
            version="1.2.406",
            published_at="2026-07-21T00:00:00Z",
        )
        merged = merge_platform_manifest(
            existing, incoming, published_at="2026-07-21T00:00:00Z"
        )
        self.assertEqual(merged["platforms"]["windows"]["version"], "1.2.400")
        self.assertEqual(merged["platforms"]["macos"]["version"], "1.2.406")


class StaleLatestKeysTest(unittest.TestCase):
    def test_only_replaced_platform_files(self) -> None:
        keys = [
            "latest/manifest.json",
            "latest/Forja-1.2.399-macos-arm64.dmg",
            "latest/Forja-1.2.406-macos-arm64.dmg",
            "latest/Forja-1.2.400-windows-setup.exe",
            "changelog/1.2.400.md",
        ]
        stale = stale_latest_keys(
            all_keys=keys,
            merged_assets=[
                "Forja-1.2.406-macos-arm64.dmg",
                "Forja-1.2.400-windows-setup.exe",
            ],
            replaced_platforms={"macos"},
        )
        self.assertEqual(stale, ["latest/Forja-1.2.399-macos-arm64.dmg"])


if __name__ == "__main__":
    unittest.main()
