#!/usr/bin/env python3
"""Unit tests for per-platform / per-arch latest/ merge helpers."""

from __future__ import annotations

import unittest

from upload_release_to_r2 import (
    apply_downloader_codes_to_atv_entry,
    detect_arch,
    detect_platform,
    merge_assets_by_arch,
    merge_downloader_codes,
    merge_platform_manifest,
    normalize_downloader_codes,
    parse_downloader_codes_env,
    platforms_from_filenames,
    referenced_version_prefixes,
    stale_latest_keys,
)


class DetectPlatformTest(unittest.TestCase):
    def test_known(self) -> None:
        self.assertEqual(detect_platform("Forja-1.2.1-windows-setup.exe"), "windows")
        self.assertEqual(detect_platform("Forja-1.2.1-macos-arm64.dmg"), "macos")
        self.assertEqual(detect_platform("Forja-1.2.1-macos-x86_64.dmg"), "macos")
        self.assertEqual(
            detect_platform("Forja-1.2.1-linux-x86_64.AppImage"), "linux"
        )
        self.assertEqual(
            detect_platform("Forja-1.2.1-android-tv-arm64.apk"), "android_tv"
        )


class DetectArchTest(unittest.TestCase):
    def test_slots(self) -> None:
        self.assertEqual(detect_arch("Forja-1.2.1-macos-arm64.dmg"), "arm64")
        self.assertEqual(detect_arch("Forja-1.2.1-macos-x86_64.dmg"), "x86_64")
        self.assertEqual(
            detect_arch("Forja-1.2.1-android-tv-armeabi-v7a.apk"), "armeabi-v7a"
        )
        self.assertEqual(detect_arch("Forja-1.2.1-windows-setup.exe"), "default")


class MergeAssetsByArchTest(unittest.TestCase):
    def test_incoming_x86_keeps_arm64(self) -> None:
        merged = merge_assets_by_arch(
            ["Forja-1.3.9-macos-arm64.dmg"],
            ["Forja-1.3.24-macos-x86_64.dmg"],
        )
        self.assertEqual(
            merged,
            [
                "Forja-1.3.9-macos-arm64.dmg",
                "Forja-1.3.24-macos-x86_64.dmg",
            ],
        )

    def test_incoming_arm64_replaces_same_slot(self) -> None:
        merged = merge_assets_by_arch(
            [
                "Forja-1.3.9-macos-arm64.dmg",
                "Forja-1.3.9-macos-x86_64.dmg",
            ],
            ["Forja-1.3.24-macos-arm64.dmg"],
        )
        self.assertEqual(
            merged,
            [
                "Forja-1.3.24-macos-arm64.dmg",
                "Forja-1.3.9-macos-x86_64.dmg",
            ],
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

    def test_macos_x86_only_upload_keeps_existing_arm64(self) -> None:
        """Regression: Intel-only publish must not wipe Apple Silicon from latest/."""
        existing = {
            "published_at": "2026-07-26T14:40:16Z",
            "platforms": {
                "macos": {
                    "version": "1.3.9",
                    "published_at": "2026-07-26T14:40:16Z",
                    "assets": [
                        "Forja-1.3.9-macos-arm64.dmg",
                        "Forja-1.3.9-macos-x86_64.dmg",
                    ],
                },
                "windows": {
                    "version": "1.3.0",
                    "published_at": "2026-07-25T00:00:00Z",
                    "assets": ["Forja-1.3.0-windows-setup.exe"],
                },
            },
        }
        incoming = platforms_from_filenames(
            [
                "Forja-1.3.24-macos-x86_64.dmg",
                "Forja-1.3.24-windows-setup.exe",
            ],
            version="1.3.24",
            published_at="2026-07-27T00:30:43Z",
        )
        merged = merge_platform_manifest(
            existing, incoming, published_at="2026-07-27T00:30:43Z"
        )
        macos = merged["platforms"]["macos"]
        self.assertEqual(
            macos["assets"],
            [
                "Forja-1.3.9-macos-arm64.dmg",
                "Forja-1.3.24-macos-x86_64.dmg",
            ],
        )
        self.assertEqual(macos["version"], "1.3.24")
        self.assertEqual(
            macos["arches"],
            {
                "arm64": {
                    "version": "1.3.9",
                    "filename": "Forja-1.3.9-macos-arm64.dmg",
                    "published_at": "2026-07-26T14:40:16Z",
                },
                "x86_64": {
                    "version": "1.3.24",
                    "filename": "Forja-1.3.24-macos-x86_64.dmg",
                    "published_at": "2026-07-27T00:30:43Z",
                },
            },
        )
        self.assertEqual(
            merged["platforms"]["windows"]["assets"],
            ["Forja-1.3.24-windows-setup.exe"],
        )
        self.assertEqual(
            merged["platforms"]["windows"]["arches"]["default"]["version"],
            "1.3.24",
        )

    def test_android_tv_split_arch_versions(self) -> None:
        existing = {
            "published_at": "2026-08-01T00:00:00Z",
            "platforms": {
                "android_tv": {
                    "version": "1.3.10",
                    "published_at": "2026-08-01T00:00:00Z",
                    "assets": [
                        "Forja-1.3.10-android-tv-arm64.apk",
                        "Forja-1.3.10-android-tv-armeabi-v7a.apk",
                    ],
                    "downloader_codes": {"arm64": "100", "armeabi-v7a": "200"},
                },
            },
        }
        incoming = platforms_from_filenames(
            ["Forja-1.3.20-android-tv-arm64.apk"],
            version="1.3.20",
            published_at="2026-08-02T00:00:00Z",
        )
        incoming["android_tv"]["downloader_codes"] = {"arm64": "300"}
        merged = merge_platform_manifest(
            existing, incoming, published_at="2026-08-02T00:00:00Z"
        )
        atv = merged["platforms"]["android_tv"]
        self.assertEqual(atv["version"], "1.3.20")
        self.assertEqual(atv["arches"]["arm64"]["version"], "1.3.20")
        self.assertEqual(atv["arches"]["armeabi-v7a"]["version"], "1.3.10")
        self.assertEqual(
            atv["arches"]["armeabi-v7a"]["published_at"],
            "2026-08-01T00:00:00Z",
        )
        self.assertEqual(
            atv["downloader_codes"],
            {"arm64": "300", "armeabi-v7a": "200"},
        )

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

    def test_kept_sibling_arch_not_stale(self) -> None:
        keys = [
            "latest/Forja-1.3.9-macos-arm64.dmg",
            "latest/Forja-1.3.9-macos-x86_64.dmg",
            "latest/Forja-1.3.24-macos-x86_64.dmg",
        ]
        stale = stale_latest_keys(
            all_keys=keys,
            merged_assets=[
                "Forja-1.3.9-macos-arm64.dmg",
                "Forja-1.3.24-macos-x86_64.dmg",
            ],
            replaced_platforms={"macos"},
        )
        self.assertEqual(stale, ["latest/Forja-1.3.9-macos-x86_64.dmg"])


class ReferencedVersionsTest(unittest.TestCase):
    def test_includes_older_arch_filename_version(self) -> None:
        refs = referenced_version_prefixes(
            {
                "macos": {
                    "version": "1.3.24",
                    "assets": [
                        "Forja-1.3.9-macos-arm64.dmg",
                        "Forja-1.3.24-macos-x86_64.dmg",
                    ],
                }
            }
        )
        self.assertEqual(refs, {"v1.3.9", "v1.3.24"})


class DownloaderCodesTest(unittest.TestCase):
    def test_parse_env_csv(self) -> None:
        self.assertEqual(
            parse_downloader_codes_env("arm64=482913,armeabi-v7a=482914"),
            {"arm64": "482913", "armeabi-v7a": "482914"},
        )

    def test_parse_env_json(self) -> None:
        self.assertEqual(
            parse_downloader_codes_env('{"arm64":"111","armeabi-v7a":222}'),
            {"arm64": "111", "armeabi-v7a": "222"},
        )

    def test_normalize_rejects_non_digits(self) -> None:
        self.assertEqual(
            normalize_downloader_codes({"arm64": "abc", "armeabi-v7a": "9"}),
            {"armeabi-v7a": "9"},
        )

    def test_merge_keeps_unchanged_arch_code(self) -> None:
        codes = merge_downloader_codes(
            prior_codes={"arm64": "100", "armeabi-v7a": "200"},
            prior_assets=[
                "Forja-1.3.1-android-tv-arm64.apk",
                "Forja-1.3.1-android-tv-armeabi-v7a.apk",
            ],
            incoming_codes={"arm64": "300"},
            incoming_assets=["Forja-1.3.2-android-tv-arm64.apk"],
            merged_assets=[
                "Forja-1.3.2-android-tv-arm64.apk",
                "Forja-1.3.1-android-tv-armeabi-v7a.apk",
            ],
        )
        self.assertEqual(codes, {"arm64": "300", "armeabi-v7a": "200"})

    def test_merge_drops_stale_code_when_apk_replaced_without_new_code(self) -> None:
        codes = merge_downloader_codes(
            prior_codes={"arm64": "100"},
            prior_assets=["Forja-1.3.1-android-tv-arm64.apk"],
            incoming_codes={},
            incoming_assets=["Forja-1.3.2-android-tv-arm64.apk"],
            merged_assets=["Forja-1.3.2-android-tv-arm64.apk"],
        )
        self.assertEqual(codes, {})

    def test_manifest_merge_preserves_codes_on_macos_only_upload(self) -> None:
        existing = {
            "published_at": "2026-08-01T00:00:00Z",
            "platforms": {
                "android_tv": {
                    "version": "1.3.1",
                    "published_at": "2026-08-01T00:00:00Z",
                    "assets": ["Forja-1.3.1-android-tv-arm64.apk"],
                    "downloader_codes": {"arm64": "555"},
                },
                "macos": {
                    "version": "1.3.1",
                    "published_at": "2026-08-01T00:00:00Z",
                    "assets": ["Forja-1.3.1-macos-arm64.dmg"],
                },
            },
        }
        incoming = platforms_from_filenames(
            ["Forja-1.3.2-macos-arm64.dmg"],
            version="1.3.2",
            published_at="2026-08-02T00:00:00Z",
        )
        merged = merge_platform_manifest(
            existing, incoming, published_at="2026-08-02T00:00:00Z"
        )
        self.assertEqual(
            merged["platforms"]["android_tv"]["downloader_codes"],
            {"arm64": "555"},
        )
        self.assertEqual(merged["platforms"]["macos"]["version"], "1.3.2")

    def test_apply_codes_merges_and_keeps_siblings(self) -> None:
        entry = {
            "version": "1.4.238",
            "assets": [
                "Forja-1.4.238-android-tv-arm64.apk",
                "Forja-1.4.200-android-tv-armeabi-v7a.apk",
            ],
            "arches": {
                "arm64": {
                    "version": "1.4.238",
                    "filename": "Forja-1.4.238-android-tv-arm64.apk",
                },
                "armeabi-v7a": {
                    "version": "1.4.200",
                    "filename": "Forja-1.4.200-android-tv-armeabi-v7a.apk",
                },
            },
            "downloader_codes": {"armeabi-v7a": "111"},
        }
        updated, applied = apply_downloader_codes_to_atv_entry(
            entry, {"arm64": "222", "x86": "999"}
        )
        self.assertEqual(applied, {"arm64": "222"})
        self.assertEqual(
            updated["downloader_codes"],
            {"arm64": "222", "armeabi-v7a": "111"},
        )


if __name__ == "__main__":
    unittest.main()
