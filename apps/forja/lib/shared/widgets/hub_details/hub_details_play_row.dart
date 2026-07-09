import 'package:flutter/material.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';

/// Primary play/resume row for hub details heroes.
class HubDetailsPlayRow extends StatelessWidget {
  const HubDetailsPlayRow({
    super.key,
    required this.label,
    this.onPlay,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPlay;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return HeroPillPlayButton(
      label: label,
      onTap: enabled ? onPlay : null,
    );
  }
}
