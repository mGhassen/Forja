import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Two quick-action cards: official ForjaHQ install + Community Packs browse.
class ForjaPackChoiceCards extends StatelessWidget {
  const ForjaPackChoiceCards({
    super.key,
    required this.onInstallOfficial,
    required this.onBrowseCommunity,
    this.installFocusNode,
    this.browseFocusNode,
    this.compact = false,
    this.communitySubtitle,
    this.autofocusInstall = false,
  });

  final VoidCallback onInstallOfficial;
  final VoidCallback onBrowseCommunity;
  final FocusNode? installFocusNode;
  final FocusNode? browseFocusNode;
  final bool compact;
  final String? communitySubtitle;
  final bool autofocusInstall;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 10.0 : 14.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ForjaPackChoiceCard(
            focusNode: installFocusNode,
            autofocus: autofocusInstall,
            compact: compact,
            icon: Icons.inventory_2_rounded,
            title: 'Official packs',
            subtitle: compact
                ? 'Install the ForjaHQ bundle'
                : 'Best experience — install the ForjaHQ bundle',
            accent: true,
            onTap: onInstallOfficial,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: ForjaPackChoiceCard(
            focusNode: browseFocusNode,
            compact: compact,
            icon: Icons.public_rounded,
            title: 'Community Packs',
            subtitle: communitySubtitle ??
                (compact
                    ? 'Browse packs on the web'
                    : 'Browse and pick packs on the web'),
            onTap: onBrowseCommunity,
          ),
        ),
      ],
    );
  }
}

class ForjaPackChoiceCard extends StatelessWidget {
  const ForjaPackChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.focusNode,
    this.accent = false,
    this.autofocus = false,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final bool accent;
  final bool autofocus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final node = focusNode;
    final radius = compact ? 12.0 : 16.0;
    final minHeight = compact ? 112.0 : 168.0;
    final pad = compact
        ? const EdgeInsets.fromLTRB(12, 12, 12, 12)
        : const EdgeInsets.fromLTRB(18, 20, 18, 18);
    final iconSize = compact ? 22.0 : 32.0;
    final titleSize = compact ? 13.0 : 16.0;
    final subSize = compact ? 11.0 : 13.0;

    Widget card({required bool focused}) {
      final borderColor = accent
          ? ForjaShellColors.brandGreen.withValues(
              alpha: focused ? 0.95 : 0.55,
            )
          : ForjaShellColors.borderSubtle.withValues(
              alpha: focused ? 0.95 : 0.7,
            );
      return AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        constraints: BoxConstraints(minHeight: minHeight),
        padding: pad,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: focused ? 0.42 : 0.28),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: focused ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: accent
                  ? ForjaShellColors.brandGreen
                  : ForjaShellColors.textPrimary,
            ),
            SizedBox(height: compact ? 10 : 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: ForjaShellColors.textPrimary,
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            SizedBox(height: compact ? 4 : 8),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                color: ForjaShellColors.textSecondary,
                fontSize: subSize,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    if (node != null) {
      return FocusableControl(
        focusNode: node,
        autoFocus: autofocus,
        onTap: onTap,
        borderRadius: radius,
        scaleOnFocus: compact ? 1.01 : 1.02,
        showFocusBorder: true,
        showFocusFill: false,
        child: AnimatedBuilder(
          animation: node,
          builder: (context, _) => card(focused: node.hasFocus),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card(focused: false),
      ),
    );
  }
}
