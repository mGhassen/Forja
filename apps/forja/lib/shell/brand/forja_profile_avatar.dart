import 'package:flutter/material.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja_foundation/brand/forja_profile_avatar.dart';

export 'package:forja_foundation/brand/forja_profile_avatar.dart';

class ForjaActiveProfileAvatar extends StatefulWidget {
  const ForjaActiveProfileAvatar({
    super.key,
    this.size = 42,
    this.selected = false,
    this.showBorder = true,
    this.onProfile,
  });

  final double size;
  final bool selected;
  final bool showBorder;
  final ValueChanged<SyncProfile?>? onProfile;

  @override
  State<ForjaActiveProfileAvatar> createState() =>
      _ForjaActiveProfileAvatarState();
}

class _ForjaActiveProfileAvatarState extends State<ForjaActiveProfileAvatar> {
  SyncProfile? _profile;
  int _reloadGen = 0;

  @override
  void initState() {
    super.initState();
    SyncService.instance.identityRevision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    SyncService.instance.identityRevision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final gen = ++_reloadGen;
    // Paint the locally cached profile first. Cold start mounts this before
    // the restored session finishes refreshing, and `activeProfile` is a
    // network call - without the seed the rail sat on "Profile"/forge while
    // Settings showed the real one.
    await _seedFromCache(gen);
    // Keep painting the last known profile while loading - clearing to null
    // left the rail stuck on "Guest" when activeProfile hung or failed.
    try {
      final profile = await SyncService.instance.activeProfile();
      if (!mounted || gen != _reloadGen) return;
      setState(() => _profile = profile);
      widget.onProfile?.call(profile);
    } catch (e) {
      debugPrint('[ForjaActiveProfileAvatar] reload failed: $e');
      if (!mounted || gen != _reloadGen) return;
      // Preserve prior chrome on failure; only push null when we never had one.
      widget.onProfile?.call(_profile);
    }
  }

  Future<void> _seedFromCache(int gen) async {
    if (_profile != null) return;
    final cached = await SyncService.instance.lastKnownActiveProfile();
    if (cached == null || !mounted || gen != _reloadGen || _profile != null) {
      return;
    }
    setState(() => _profile = cached);
    widget.onProfile?.call(cached);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return ForjaProfileAvatar(
        avatarKey: 'forge',
        name: SyncService.instance.isSignedIn ? 'Profile' : 'Guest',
        size: widget.size,
        selected: widget.selected,
        showBorder: widget.showBorder,
      );
    }
    return ForjaProfileAvatar(
      avatarKey: profile.avatarKey,
      name: profile.name,
      size: widget.size,
      selected: widget.selected,
      showBorder: widget.showBorder,
    );
  }
}
