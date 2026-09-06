import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:forja/shared/sync/src/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Web → app Features / Addons: subscribe to `profile_settings` and soft-pull.
///
/// Uses the same [SyncDomainBridge.syncFromCloud] path (dirty skip, push grace).
/// Requires `profile_settings` in `supabase_realtime` publication.
abstract final class ProfileSettingsRealtime {
  static RealtimeChannel? _channel;
  static String? _profileId;
  static Timer? _debounce;
  static const _debounceDelay = Duration(milliseconds: 400);

  /// Start or retarget the channel for the active signed-in profile.
  static Future<void> ensureListening() async {
    if (!ForjaSupabase.isConfigured || !SyncService.instance.isSignedIn) {
      await stop();
      return;
    }
    final profile = await SyncService.instance.activeProfile();
    final client = ForjaSupabase.clientOrNull;
    if (profile == null || client == null) {
      await stop();
      return;
    }
    if (_profileId == profile.id && _channel != null) return;

    await stop();
    _profileId = profile.id;
    final channel = client.channel('profile_settings_app:${profile.id}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'profile_settings',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'profile_id',
        value: profile.id,
      ),
      callback: (_) {
        _debounce?.cancel();
        _debounce = Timer(_debounceDelay, () {
          debugPrint(
            '[Sync] profile_settings realtime → soft-pull '
            '(profile=$_profileId)',
          );
          unawaited(SyncDomainBridge.instance.syncFromCloud(force: true));
        });
      },
    );
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint(
          '[Sync] profile_settings realtime subscribed profile=${profile.id}',
        );
      } else if (error != null) {
        debugPrint('[Sync] profile_settings realtime status=$status error=$error');
      }
    });
    _channel = channel;
  }

  static Future<void> stop() async {
    _debounce?.cancel();
    _debounce = null;
    final channel = _channel;
    _channel = null;
    _profileId = null;
    if (channel == null) return;
    final client = ForjaSupabase.clientOrNull;
    if (client != null) {
      try {
        await client.removeChannel(channel);
      } catch (e) {
        debugPrint('[Sync] profile_settings realtime remove failed: $e');
      }
    }
  }
}
