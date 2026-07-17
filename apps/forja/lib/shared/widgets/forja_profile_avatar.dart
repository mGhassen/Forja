import 'package:flutter/material.dart';
import 'package:forja/shared/sync/sync.dart';

class _AvatarPalette {
  const _AvatarPalette(this.background, this.foreground, this.accent);

  final Color background;
  final Color foreground;
  final Color accent;
}

const Map<String, _AvatarPalette> _avatarPalettes = {
  'forge': _AvatarPalette(
    Color(0xFF1B1B1B),
    Color(0xFF1CE783),
    Color(0xFF0A2D21),
  ),
  'flame': _AvatarPalette(
    Color(0xFFFF4D1C),
    Color(0xFFFFD1A8),
    Color(0xFF3A130A),
  ),
  'mint': _AvatarPalette(
    Color(0xFF1CE783),
    Color(0xFFF5FFF9),
    Color(0xFF0C3B2A),
  ),
  'captain': _AvatarPalette(
    Color(0xFF123A68),
    Color(0xFFF4C7A1),
    Color(0xFFFACC15),
  ),
  'rebel': _AvatarPalette(
    Color(0xFF9F1239),
    Color(0xFFFFD2B3),
    Color(0xFF1F1020),
  ),
  'ninja': _AvatarPalette(
    Color(0xFF111827),
    Color(0xFFC084FC),
    Color(0xFF05070C),
  ),
  'royal': _AvatarPalette(
    Color(0xFF6D28D9),
    Color(0xFFF6D0AD),
    Color(0xFFFACC15),
  ),
  'racer': _AvatarPalette(
    Color(0xFFDC2626),
    Color(0xFFF8D5BA),
    Color(0xFF111827),
  ),
  'night': _AvatarPalette(
    Color(0xFF10172C),
    Color(0xFF64748B),
    Color(0xFF1CE783),
  ),
  'panda': _AvatarPalette(
    Color(0xFFF8FAFC),
    Color(0xFF111827),
    Color(0xFFFB7185),
  ),
  'fox': _AvatarPalette(
    Color(0xFFEA580C),
    Color(0xFFFFF7ED),
    Color(0xFF431407),
  ),
  'owl': _AvatarPalette(
    Color(0xFF92400E),
    Color(0xFFFDE68A),
    Color(0xFF1E3A8A),
  ),
  'shark': _AvatarPalette(
    Color(0xFF0369A1),
    Color(0xFFBAE6FD),
    Color(0xFF172554),
  ),
  'dragon': _AvatarPalette(
    Color(0xFF166534),
    Color(0xFF86EFAC),
    Color(0xFFFACC15),
  ),
  'bunny': _AvatarPalette(
    Color(0xFFF9A8D4),
    Color(0xFFFFF1F2),
    Color(0xFF831843),
  ),
  'yeti': _AvatarPalette(
    Color(0xFFDBEAFE),
    Color(0xFFF8FAFC),
    Color(0xFF1E40AF),
  ),
  'orbit': _AvatarPalette(
    Color(0xFF3978D5),
    Color(0xFFDCECFF),
    Color(0xFF152B4D),
  ),
  'comet': _AvatarPalette(
    Color(0xFF312E81),
    Color(0xFFF97316),
    Color(0xFFFEF3C7),
  ),
  'nova': _AvatarPalette(
    Color(0xFF701A75),
    Color(0xFFF0ABFC),
    Color(0xFFFACC15),
  ),
  'alien': _AvatarPalette(
    Color(0xFF052E16),
    Color(0xFF4ADE80),
    Color(0xFF111827),
  ),
  'rover': _AvatarPalette(
    Color(0xFF7C2D12),
    Color(0xFFFED7AA),
    Color(0xFF292524),
  ),
  'lunar': _AvatarPalette(
    Color(0xFF1E293B),
    Color(0xFFE2E8F0),
    Color(0xFF38BDF8),
  ),
  'solar': _AvatarPalette(
    Color(0xFF9A3412),
    Color(0xFFFACC15),
    Color(0xFFFFF7ED),
  ),
  'void': _AvatarPalette(
    Color(0xFF020617),
    Color(0xFF7C3AED),
    Color(0xFF22D3EE),
  ),
  'pixel': _AvatarPalette(
    Color(0xFF7C3AED),
    Color(0xFFDED7FF),
    Color(0xFF1CE783),
  ),
  'arcade': _AvatarPalette(
    Color(0xFF172554),
    Color(0xFF22D3EE),
    Color(0xFFF472B6),
  ),
  'cassette': _AvatarPalette(
    Color(0xFFF59E0B),
    Color(0xFF292524),
    Color(0xFFFEF3C7),
  ),
  'glitch': _AvatarPalette(
    Color(0xFF111827),
    Color(0xFFEF4444),
    Color(0xFF22D3EE),
  ),
  'neon': _AvatarPalette(
    Color(0xFF4A044E),
    Color(0xFFF0ABFC),
    Color(0xFFA3E635),
  ),
  'synth': _AvatarPalette(
    Color(0xFF312E81),
    Color(0xFFFB7185),
    Color(0xFF67E8F9),
  ),
};

IconData _avatarIcon(String key) {
  final keys = _avatarPalettes.keys.toList(growable: false);
  final index = keys.indexOf(key);
  if (index >= 24) return Icons.sports_esports_rounded;
  if (index >= 16) return Icons.rocket_launch_rounded;
  if (index >= 8) return Icons.pets_rounded;
  return Icons.person_rounded;
}

/// Compact Flutter rendering of the same named avatar palettes used by web.
class ForjaProfileAvatar extends StatelessWidget {
  const ForjaProfileAvatar({
    super.key,
    required this.avatarKey,
    required this.name,
    this.size = 42,
    this.selected = false,
  });

  final String avatarKey;
  final String name;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = _avatarPalettes[avatarKey] ?? _avatarPalettes['forge']!;
    return Semantics(
      image: true,
      label: '$name avatar',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.background, palette.accent],
          ),
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.foreground,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _avatarIcon(avatarKey),
            color: palette.accent,
            size: size * 0.48,
          ),
        ),
      ),
    );
  }
}

class ForjaActiveProfileAvatar extends StatefulWidget {
  const ForjaActiveProfileAvatar({
    super.key,
    this.size = 42,
    this.selected = false,
    this.onProfile,
  });

  final double size;
  final bool selected;
  final ValueChanged<SyncProfile?>? onProfile;

  @override
  State<ForjaActiveProfileAvatar> createState() =>
      _ForjaActiveProfileAvatarState();
}

class _ForjaActiveProfileAvatarState extends State<ForjaActiveProfileAvatar> {
  SyncProfile? _profile;

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
    final profile = await SyncService.instance.activeProfile();
    if (!mounted) return;
    setState(() => _profile = profile);
    widget.onProfile?.call(profile);
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
      );
    }
    return ForjaProfileAvatar(
      avatarKey: profile.avatarKey,
      name: profile.name,
      size: widget.size,
      selected: widget.selected,
    );
  }
}
