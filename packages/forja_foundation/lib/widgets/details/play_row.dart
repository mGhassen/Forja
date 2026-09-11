import 'package:flutter/material.dart';
import 'package:forja_foundation/components/button_group.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Details play / action row — [ButtonGroup] of play/actions (RFC-106 G5).
class PlayRow extends StatelessWidget {
  const PlayRow({
    super.key,
    required this.children,
    this.orientation = Axis.horizontal,
    this.spacing,
  });

  final List<Widget> children;
  final Axis orientation;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    return ButtonGroup(
      orientation: orientation,
      spacing: spacing,
      children: children,
    );
  }
}

/// Optionally scales hero action rows down on narrow viewports.
///
/// Pass [scaleDown]: false when the row must keep intrinsic size (e.g. live
/// match Providers / Live TV + search).
class DetailsHeroActionRowFit extends StatelessWidget {
  const DetailsHeroActionRowFit({
    super.key,
    required this.child,
    this.scaleDown = true,
  });

  final Widget child;
  final bool scaleDown;

  @override
  Widget build(BuildContext context) {
    final body = scaleDown
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: child,
          )
        : child;
    return Align(
      alignment: Alignment.centerLeft,
      child: body,
    );
  }
}

/// Soft “not playable yet” chip for hub details heroes (upcoming titles).
///
/// Height matches [ShellTokens.shellButtonHeight] so hero footer budget fits.
class DetailsUpcomingNotice extends StatelessWidget {
  const DetailsUpcomingNotice({
    super.key,
    this.releaseDateLabel,
  });

  static const double height = ShellTokens.shellButtonHeight;

  /// Human premiere label (e.g. `Jun 14, 2026`), or null/empty if unknown.
  final String? releaseDateLabel;

  @override
  Widget build(BuildContext context) {
    final date = releaseDateLabel?.trim() ?? '';
    final hasDate = date.isNotEmpty;
    final label = hasDate ? 'Coming soon · $date' : 'Coming soon';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: Colors.amber.shade200,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.96),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
