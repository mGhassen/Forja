import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_visibility_provider.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/animated_logo.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shown when every shell feature tab is hidden — guides users to Addons,
/// Features, and plugin install instead of landing on an empty Settings body.
class ShellEmptyFeaturesScreen extends ConsumerStatefulWidget {
  const ShellEmptyFeaturesScreen({
    super.key,
    required this.onOpenFeatures,
    this.onOpenAddons,
    this.onInstallPlugins,
  });

  final VoidCallback onOpenFeatures;
  final VoidCallback? onOpenAddons;
  final VoidCallback? onInstallPlugins;

  @override
  ConsumerState<ShellEmptyFeaturesScreen> createState() =>
      _ShellEmptyFeaturesScreenState();
}

class _ShellEmptyFeaturesScreenState
    extends ConsumerState<ShellEmptyFeaturesScreen> {
  final List<FocusNode> _cardFocus = [];
  var _focusScheduled = false;

  @override
  void dispose() {
    for (final n in _cardFocus) {
      n.dispose();
    }
    super.dispose();
  }

  void _ensureFocusNodes(int count) {
    while (_cardFocus.length < count) {
      final i = _cardFocus.length;
      _cardFocus.add(FocusNode(debugLabel: 'empty-shell-card-$i'));
    }
    while (_cardFocus.length > count) {
      _cardFocus.removeLast().dispose();
    }
  }

  /// Beat the nav-rail autofocus that steals primary focus on TV tab paint.
  void _scheduleAddonsCardFocus() {
    if (_focusScheduled) return;
    if (!ShellScope.metricsOf(context).usesTvDensity) return;
    if (_cardFocus.isEmpty) return;
    _focusScheduled = true;

    void tryFocus(int attempt) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final n = _cardFocus.first;
        if (n.canRequestFocus) {
          n.requestFocus();
        }
        if (attempt < 10 && !n.hasFocus) {
          tryFocus(attempt + 1);
        }
      });
    }

    tryFocus(0);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ShellScope.metricsOf(context);
    final tv = metrics.usesTvDensity;
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final visibility = ref.watch(settingsVisibilityProvider).valueOrNull;
    final showPlugins = visibility?.showSourcesCategory ?? true;
    final showAddons = showPlugins && widget.onOpenAddons != null;
    final profile = ShellScope.profileOf(context);

    final specs = <_CardSpec>[
      if (showAddons)
        _CardSpec(
          icon: Icons.extension_rounded,
          title: 'Addons',
          body: tv
              ? 'IPTV, Live Sports, torrent, Stremio, Nuvio, and more.'
              : 'Turn on IPTV, Live Sports, torrent, Stremio, Nuvio, and other playback surfaces.',
          accent: const Color(0xFF22D3EE),
          onAction: widget.onOpenAddons!,
        ),
      _CardSpec(
        icon: Icons.tab_rounded,
        title: 'Features',
        body: tv
            ? 'Choose which tabs appear in the rail.'
            : 'Choose which tabs appear — Home, Anime, IPTV, Live Matches, Lists, and more.',
        accent: const Color(0xFF34D399),
        onAction: widget.onOpenFeatures,
      ),
      if (showPlugins && widget.onInstallPlugins != null)
        _CardSpec(
          icon: Icons.inventory_2_outlined,
          title: 'Plugins',
          body: tv
              ? 'Install hub and stream packs from a URL or profile.'
              : 'Install hub and stream packs from a manifest URL, or sync packs from your profile.',
          accent: const Color(0xFFFBBF24),
          onAction: widget.onInstallPlugins!,
        ),
    ];

    _ensureFocusNodes(specs.length);
    _scheduleAddonsCardFocus();

    final logoHeight = tv
        ? 48.0
        : profile == ShellProfile.mobile
            ? 72.0
            : 88.0;
    final titleSize = tv ? 20.0 : 22.0;
    final bodySize = tv ? 13.0 : 14.0;
    final hPad = tv
        ? 16.0
        : profile == ShellProfile.mobile
            ? 24.0
            : 40.0;
    final vPad = tv ? 16.0 : 32.0;

    return ColoredBox(
      color: AppTheme.bgDark,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = (tv || profile != ShellProfile.mobile) &&
                constraints.maxWidth >= 640 &&
                specs.length > 1;
            // TV: span the body (rail already inset by scaffold) so the row
            // reads centered — a narrow 620 island next to the rail looks skewed.
            final maxW = tv
                ? constraints.maxWidth
                : horizontal
                    ? 840.0
                    : 480.0;

            Widget cardAt(int i, {required bool expandBody, required bool compact}) {
              return _HintCard(
                spec: specs[i],
                tvFocus: tvFocus,
                autofocus: tvFocus && i == 0,
                focusNode: _cardFocus[i],
                expandBody: expandBody,
                compact: compact,
                tvItemIndex: i,
                onFocusLeft: horizontal
                    ? (i == 0
                        ? ShellTvFocusCoordinator.focusActiveNavTab
                        : () => _cardFocus[i - 1].requestFocus())
                    : ShellTvFocusCoordinator.focusActiveNavTab,
                onFocusRight: horizontal && i < specs.length - 1
                    ? () => _cardFocus[i + 1].requestFocus()
                    : null,
                onFocusUp: !horizontal && i > 0
                    ? () => _cardFocus[i - 1].requestFocus()
                    : null,
                onFocusDown: !horizontal && i < specs.length - 1
                    ? () => _cardFocus[i + 1].requestFocus()
                    : null,
              );
            }

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ForjaLogoIdle(logoHeight: logoHeight),
                      SizedBox(height: tv ? 14 : 28),
                      Text(
                        'Turn on a feature to get started',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: ForjaShellColors.textPrimary,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: tv ? 10 : 14),
                      Text(
                        'Pick Addons, Features, or install packs.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: ForjaShellColors.textPrimary.withValues(
                            alpha: 0.62,
                          ),
                          fontSize: bodySize,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: tv ? 20 : 32),
                      if (horizontal)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < specs.length; i++) ...[
                                if (i > 0) SizedBox(width: tv ? 12 : 12),
                                Expanded(
                                  child: cardAt(
                                    i,
                                    expandBody: true,
                                    compact: tv,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            for (var i = 0; i < specs.length; i++) ...[
                              if (i > 0) SizedBox(height: tv ? 10 : 12),
                              cardAt(i, expandBody: false, compact: tv),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CardSpec {
  const _CardSpec({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final VoidCallback onAction;
}

class _HintCard extends StatefulWidget {
  const _HintCard({
    required this.spec,
    required this.tvFocus,
    this.autofocus = false,
    this.focusNode,
    this.expandBody = false,
    this.compact = false,
    this.tvItemIndex = 0,
    this.onFocusLeft,
    this.onFocusRight,
    this.onFocusUp,
    this.onFocusDown,
  });

  final _CardSpec spec;
  final bool tvFocus;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool expandBody;
  final bool compact;
  final int tvItemIndex;
  final VoidCallback? onFocusLeft;
  final VoidCallback? onFocusRight;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;

  @override
  State<_HintCard> createState() => _HintCardState();
}

class _HintCardState extends State<_HintCard> {
  bool _hover = false;
  bool _focused = false;

  /// Desktop: mouse hover only. Focus fill sticks after click otherwise.
  /// TV / keyboard: use shell chrome visibility (same as FocusableControl).
  bool _isLit(BuildContext context) {
    if (_hover) return true;
    final policy = ShellScope.inputPolicyOf(context);
    return policy.focusChromeVisible(context, focused: _focused);
  }

  @override
  Widget build(BuildContext context) {
    final lit = _isLit(context);
    final accent = widget.spec.accent;
    final pad = widget.compact ? 14.0 : 18.0;
    final titleSize = widget.compact ? 15.0 : 16.0;
    final bodySize = widget.compact ? 12.0 : 13.0;
    final iconSize = widget.compact ? 22.0 : 24.0;
    final radius = 16.0;

    final idleBg = ForjaShellColors.surfaceElevated.withValues(alpha: 0.28);
    final litBg = accent.withValues(alpha: 0.28);
    final titleColor = accent;
    final bodyColor = lit
        ? ForjaShellColors.textPrimary.withValues(alpha: 0.92)
        : ForjaShellColors.textSecondary.withValues(alpha: 0.9);
    final iconColor = accent;
    final borderColor = accent;

    final inner = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: lit ? litBg : idleBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: lit ? 1.5 : 1.2),
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.spec.icon, size: iconSize, color: iconColor),
            SizedBox(height: widget.compact ? 10 : 12),
            Text(
              widget.spec.title,
              style: GoogleFonts.plusJakartaSans(
                color: titleColor,
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: widget.compact ? 6 : 8),
            if (widget.expandBody)
              Expanded(
                child: Text(
                  widget.spec.body,
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: bodySize,
                    height: 1.45,
                  ),
                ),
              )
            else
              Text(
                widget.spec.body,
                style: TextStyle(
                  color: bodyColor,
                  fontSize: bodySize,
                  height: 1.45,
                ),
              ),
          ],
        ),
      ),
    );

    // Desktop also uses focusable chips — still need mouse hover fill.
    if (widget.tvFocus) {
      return shellFocusableTap(
        context: context,
        onTap: widget.spec.onAction,
        focusNode: widget.focusNode,
        autoFocus: widget.autofocus,
        borderRadius: radius,
        scaleOnFocus: 1.03,
        showFocusBorder: false,
        showFocusFill: false,
        onFocusChange: (f) {
          if (_focused == f) return;
          setState(() => _focused = f);
        },
        onHoverChange: (h) {
          if (_hover == h) return;
          setState(() => _hover = h);
        },
        tvTabId: 'settings',
        tvRowId: 'empty-shell-cards',
        tvItemIndex: widget.tvItemIndex,
        tvZone: ShellTvZone.row,
        listIndex: widget.tvItemIndex,
        onLeftEdge: widget.onFocusLeft,
        onRightEdge: widget.onFocusRight,
        onUpEdge: widget.onFocusUp,
        onDownEdge: widget.onFocusDown,
        ensureVisibleMode: ShellTvEnsureVisibleMode.item,
        child: inner,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.spec.onAction,
        child: inner,
      ),
    );
  }
}
