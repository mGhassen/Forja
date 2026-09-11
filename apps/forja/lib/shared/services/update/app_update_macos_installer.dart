import 'dart:io';

import 'package:forja/shared/services/update/app_update_download_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:forja/shared/shell/forja_toast.dart';

/// Silent macOS apply: replace installed [Forja.app] from a downloaded DMG.
///
/// Windows / Linux keep opening the installer; this path is macOS-only.
abstract final class AppUpdateMacosInstaller {
  static const _markerPendingVersion = 'pending_version';
  static const _markerPendingStartedAt = 'pending_started_at';
  static const _markerApplyFailed = 'apply_failed';
  static const _markerAppliedOk = 'applied_ok';
  static const _markerTargetBundle = 'apply_target_bundle';

  /// Spawns a detached apply script, then exits the process.
  static Future<void> applyAndQuit({
    required String dmgPath,
    required String version,
  }) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('macOS silent apply is only available on macOS');
    }

    final dmg = File(dmgPath);
    if (!await dmg.exists()) {
      throw StateError('Downloaded update file is missing');
    }

    final bundlePath = resolveRunningAppBundlePath();
    if (bundlePath == null) {
      throw StateError('Could not locate Forja.app for this process');
    }

    final markerDir = await markerDirectory();
    await markerDir.create(recursive: true);
    await _clearMarkers(markerDir, keepPending: false);
    await File(
      path.join(markerDir.path, _markerPendingVersion),
    ).writeAsString(version, flush: true);
    await File(
      path.join(markerDir.path, _markerPendingStartedAt),
    ).writeAsString(DateTime.now().toUtc().toIso8601String(), flush: true);

    final scriptFile = File(
      path.join(
        Directory.systemTemp.path,
        'forja_macos_apply_${pid}_${DateTime.now().millisecondsSinceEpoch}.sh',
      ),
    );
    await scriptFile.writeAsString(_applyScript, flush: true);
    final chmod = await Process.run('chmod', ['+x', scriptFile.path]);
    if (chmod.exitCode != 0) {
      throw StateError('Could not prepare the update helper');
    }

    await Process.start(scriptFile.path, [
      '$pid',
      dmgPath,
      bundlePath,
      markerDir.path,
      version,
    ], mode: ProcessStartMode.detached);

    exit(0);
  }

  /// Walk `…/Forja.app/Contents/MacOS/<exe>` → `…/Forja.app`.
  static String? resolveRunningAppBundlePath() {
    final exe = path.normalize(Platform.resolvedExecutable);
    var current = path.dirname(exe);
    for (var i = 0; i < 6; i++) {
      final base = path.basename(current);
      if (base.endsWith('.app')) {
        return current;
      }
      final parent = path.dirname(current);
      if (parent == current) break;
      current = parent;
    }
    return null;
  }

  static Future<Directory> markerDirectory() async {
    final support = await AppUpdateDownloadStorage.supportUpdatesDirectory();
    return Directory(path.join(support.path, 'macos_apply'));
  }

  /// Next-launch safety net: toast if the last silent apply failed or stalled.
  static Future<void> consumeAndToastIfNeeded() async {
    if (!Platform.isMacOS) return;

    try {
      final markerDir = await markerDirectory();
      if (!await markerDir.exists()) return;

      final failedFile = File(path.join(markerDir.path, _markerApplyFailed));
      if (await failedFile.exists()) {
        final reason = (await failedFile.readAsString()).trim();
        await failedFile.delete();
        ForjaToast.error(
          reason.isEmpty
              ? 'The Mac update could not finish. Try Install again, or allow Forja in System Settings → Privacy & Security.'
              : reason,
          duration: const Duration(seconds: 12),
        );
        return;
      }

      final pendingFile = File(
        path.join(markerDir.path, _markerPendingVersion),
      );
      if (!await pendingFile.exists()) {
        final okFile = File(path.join(markerDir.path, _markerAppliedOk));
        if (await okFile.exists()) {
          await okFile.delete();
        }
        return;
      }

      final pending = (await pendingFile.readAsString()).trim();
      if (pending.isEmpty) {
        await _clearMarkers(markerDir, keepPending: false);
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.version == pending) {
        await _clearMarkers(markerDir, keepPending: false);
        return;
      }

      // Still on the old build after a pending apply — helper likely failed
      // without writing apply_failed, or the user launched an old binary.
      final startedAtFile = File(
        path.join(markerDir.path, _markerPendingStartedAt),
      );
      if (await startedAtFile.exists()) {
        final raw = (await startedAtFile.readAsString()).trim();
        final started = DateTime.tryParse(raw);
        if (started != null &&
            DateTime.now().toUtc().difference(started) <
                const Duration(seconds: 45)) {
          // Apply script may still be running; skip toast this launch.
          return;
        }
      }

      await _clearMarkers(markerDir, keepPending: false);
      ForjaToast.error(
        'Forja $pending did not install. Try Install again from the update dialog.',
        duration: const Duration(seconds: 12),
      );
    } catch (_) {
      // Never block startup on marker IO.
    }
  }

  static Future<void> _clearMarkers(
    Directory markerDir, {
    required bool keepPending,
  }) async {
    final names = <String>[
      _markerApplyFailed,
      _markerAppliedOk,
      _markerTargetBundle,
      if (!keepPending) ...[_markerPendingVersion, _markerPendingStartedAt],
    ];
    for (final name in names) {
      final file = File(path.join(markerDir.path, name));
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  /// Bash helper: wait for Forja to exit, ditto from DMG, strip quarantine, reopen.
  static const _applyScript = r'''#!/bin/bash
set +e
PARENT_PID="$1"
DMG="$2"
APP_BUNDLE="$3"
MARKER_DIR="$4"
VERSION="$5"

mkdir -p "$MARKER_DIR"

fail() {
  reason="$1"
  printf '%s\n' "$reason" > "$MARKER_DIR/apply_failed"
  /usr/bin/osascript <<'OSA' >/dev/null 2>&1 || true
display dialog "macOS blocked opening the updated Forja. Right-click Forja and choose Open, or allow it under System Settings → Privacy & Security." buttons {"OK"} default button 1 with title "Forja update"
OSA
  exit 1
}

i=0
while /bin/kill -0 "$PARENT_PID" 2>/dev/null; do
  /bin/sleep 0.2
  i=$((i + 1))
  if [ "$i" -gt 150 ]; then
    break
  fi
done
/bin/sleep 0.5

TARGET="$APP_BUNDLE"
PARENT_DIR="$(/usr/bin/dirname "$APP_BUNDLE")"
if [ ! -d "$APP_BUNDLE" ] || { [ ! -w "$APP_BUNDLE" ] && [ ! -w "$PARENT_DIR" ]; }; then
  /bin/mkdir -p "$HOME/Applications" 2>/dev/null || true
  TARGET="$HOME/Applications/Forja.app"
fi

ATTACH_OUT="$(/usr/bin/hdiutil attach -nobrowse -readonly -quiet "$DMG" 2>&1)"
ATTACH_RC=$?
if [ "$ATTACH_RC" -ne 0 ]; then
  fail "Could not mount the update disk image."
fi

MOUNT="$(printf '%s\n' "$ATTACH_OUT" | /usr/bin/awk 'NF { mount=$NF } END { print mount }')"
if [ -z "$MOUNT" ] || [ ! -d "$MOUNT" ]; then
  fail "Could not find the mounted update volume."
fi

SRC=""
if [ -d "$MOUNT/Forja.app" ]; then
  SRC="$MOUNT/Forja.app"
elif [ -d "$MOUNT/forja.app" ]; then
  SRC="$MOUNT/forja.app"
else
  SRC="$(/usr/bin/find "$MOUNT" -maxdepth 3 -name 'Forja.app' -type d 2>/dev/null | /usr/bin/head -n 1)"
fi

if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  /usr/bin/hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || /usr/bin/hdiutil detach "$MOUNT" -force -quiet >/dev/null 2>&1 || true
  fail "Update image is missing Forja.app."
fi

if ! /usr/bin/ditto "$SRC" "$TARGET"; then
  /usr/bin/hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || /usr/bin/hdiutil detach "$MOUNT" -force -quiet >/dev/null 2>&1 || true
  fail "Could not copy the update into place."
fi

/usr/bin/xattr -cr "$TARGET" >/dev/null 2>&1 || true
/usr/bin/hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || /usr/bin/hdiutil detach "$MOUNT" -force -quiet >/dev/null 2>&1 || true

printf '%s\n' "$TARGET" > "$MARKER_DIR/apply_target_bundle"

if ! /usr/bin/open "$TARGET"; then
  fail "macOS blocked opening the updated Forja. Right-click Forja and choose Open, or allow it under System Settings → Privacy & Security."
fi

ok=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  /bin/sleep 0.5
  if /usr/bin/pgrep -f "$TARGET/Contents/MacOS/" >/dev/null 2>&1; then
    ok=1
    break
  fi
  if /usr/bin/pgrep -xq forja >/dev/null 2>&1 || /usr/bin/pgrep -xq Forja >/dev/null 2>&1; then
    ok=1
    break
  fi
done

if [ "$ok" -ne 1 ]; then
  fail "macOS blocked opening the updated Forja. Right-click Forja and choose Open, or allow it under System Settings → Privacy & Security."
fi

/bin/rm -f "$MARKER_DIR/apply_failed"
printf '%s\n' "$VERSION" > "$MARKER_DIR/applied_ok"
/bin/rm -f "$MARKER_DIR/pending_version" "$MARKER_DIR/pending_started_at"
exit 0
''';
}
