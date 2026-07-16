import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/announcement_service.dart';

/// In-app banner for active Supabase announcements.
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  Announcement? _current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AnnouncementService.instance.fetchActive();
    if (!mounted) return;
    setState(() => _current = list.isEmpty ? null : list.first);
  }

  Future<void> _dismiss() async {
    final a = _current;
    if (a == null) return;
    await AnnouncementService.instance.dismiss(a.id);
    if (!mounted) return;
    setState(() => _current = null);
  }

  @override
  Widget build(BuildContext context) {
    final a = _current;
    if (a == null) return const SizedBox.shrink();

    final accent = switch (a.severity) {
      'warning' => Colors.amber,
      'error' => Colors.redAccent,
      _ => ForjaShellColors.brandGreen,
    };

    return Material(
      color: ForjaShellColors.surfaceElevated,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.5))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.campaign_outlined, size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: const TextStyle(
                      color: ForjaShellColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (a.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      a.body,
                      style: const TextStyle(
                        color: ForjaShellColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: _dismiss,
              icon: const Icon(Icons.close, size: 18),
              color: ForjaShellColors.iconMuted,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
