import 'package:flutter/material.dart';
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
  int _lastFocusCount = -1;

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
    if (count != _lastFocusCount) {
      _lastFocusCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!ShellScope.metricsOf(context).usesTvDensity) return;
        if (_cardFocus.isEmpty) return;
        final n = _cardFocus.first;
        if (n.canRequestFocus) n.requestFocus();
      });
    }
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
          actionLabel: 'Open Addons',
          onAction: widget.onOpenAddons!,
        ),
      _CardSpec(
        icon: Icons.tab_rounded,
        title: 'Features',
        body: tv
            ? 'Choose which tabs appear in the rail.'
            : 'Choose which tabs appear — Home, Anime, IPTV, Live Matches, Lists, and more.',
        actionLabel: 'Open Features',
        onAction: widget.onOpenFeatures,
      ),
      if (showPlugins && widget.onInstallPlugins != null)
        _CardSpec(
          icon: Icons.inventory_2_outlined,
          title: 'Plugins',
          body: tv
              ? 'Install hub and stream packs from a URL or profile.'
              : 'Install hub and stream packs from a manifest URL, or sync packs from your profile.',
          actionLabel: 'Install plugins',
          onAction: widget.onInstallPlugins!,
        ),
    ];

    _ensureFocusNodes(specs.length);

    final logoHeight = tv
        ? 48.0
        : profile == ShellProfile.mobile
            ? 72.0
            : 88.0;
    final titleSize = tv ? 20.0 : 22.0;
    final bodySize = tv ? 13.0 : 14.0;
    final hPad = tv
        ? 24.0
        : profile == ShellProfile.mobile
            ? 24.0
            : 40.0;
    final vPad = tv ? 16.0 : 32.0;

    return ColoredBox(
      color: AppTheme.bgDark,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // TV / desktop: side-by-side when there is room; phone stays stacked.
            final horizontal = (tv || profile != ShellProfile.mobile) &&
                constraints.maxWidth >= 640 &&
                specs.length > 1;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: horizontal ? 900 : 480,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ForjaLogoIdle(logoHeight: logoHeight),
                      SizedBox(height: tv ? 16 : 28),
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
                      SizedBox(height: tv ? 8 : 12),
                      Text(
                        tv
                            ? 'Enable Addons and Features, or install packs.'
                            : 'Forja is built from plugins. Enable Addons and Features '
                                'in Settings, or install catalog and stream packs for a '
                                'fuller experience.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: ForjaShellColors.textSecondary.withValues(
                            alpha: 0.92,
                          ),
                          fontSize: bodySize,
                          height: 1.45,
                        ),
                      ),
                      SizedBox(height: tv ? 18 : 28),
                      if (horizontal)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < specs.length; i++) ...[
                                if (i > 0) SizedBox(width: tv ? 10 : 12),
                                Expanded(
                                  child: _HintCard(
                                    spec: specs[i],
                                    tvFocus: tvFocus,
                                    autofocus: tvFocus && i == 0,
                                    focusNode: _cardFocus[i],
                                    expandBody: true,
                                    compact: tv,
                                    tvItemIndex: i,
                                    onFocusLeft: i == 0
                                        ? ShellTvFocusCoordinator
                                            .focusActiveNavTab
                                        : () => _cardFocus[i - 1].requestFocus(),
                                    onFocusRight: i < specs.length - 1
                                        ? () => _cardFocus[i + 1].requestFocus()
                                        : null,
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
                              _HintCard(
                                spec: specs[i],
                                tvFocus: tvFocus,
                                autofocus: tvFocus && i == 0,
                                focusNode: _cardFocus[i],
                                compact: tv,
                                tvItemIndex: i,
                                onFocusLeft:
                                    ShellTvFocusCoordinator.focusActiveNavTab,
                                onFocusUp: i > 0
                                    ? () => _cardFocus[i - 1].requestFocus()
                                    : null,
                                onFocusDown: i < specs.length - 1
                                    ? () => _cardFocus[i + 1].requestFocus()
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      if (!tv) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Tap the Forja logo in the sidebar to return here, or use '
                          'your profile avatar to open Settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ForjaShellColors.textSecondary.withValues(
                              alpha: 0.65,
                            ),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
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
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
}

class _HintCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final border = ForjaShellColors.borderSubtle.withValues(alpha: 0.55);
    final surface = ForjaShellColors.surfaceElevated.withValues(alpha: 0.35);
    final pad = compact ? 12.0 : 16.0;
    final titleSize = compact ? 14.0 : 15.0;
    final bodySize = compact ? 12.0 : 13.0;
    final iconSize = compact ? 20.0 : 22.0;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              spec.icon,
              size: iconSize,
              color: ForjaShellColors.sectionAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                spec.title,
                style: GoogleFonts.plusJakartaSans(
                  color: ForjaShellColors.textPrimary,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 6 : 8),
        if (expandBody)
          Expanded(
            child: Text(
              spec.body,
              style: TextStyle(
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
                fontSize: bodySize,
                height: 1.4,
              ),
            ),
          )
        else
          Text(
            spec.body,
            style: TextStyle(
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
              fontSize: bodySize,
              height: 1.4,
            ),
          ),
        SizedBox(height: compact ? 10 : 12),
        Align(
          alignment: Alignment.centerRight,
          child: _ActionChip(label: spec.actionLabel, compact: compact),
        ),
      ],
    );

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, compact ? 10 : 12),
        child: body,
      ),
    );

    if (!tvFocus) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: spec.onAction,
          borderRadius: BorderRadius.circular(14),
          child: card,
        ),
      );
    }

    // Whole card is the D-pad target (not only the chip).
    return shellFocusableTap(
      context: context,
      onTap: spec.onAction,
      focusNode: focusNode,
      autoFocus: autofocus,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      showFocusFill: true,
      tvTabId: 'settings',
      tvRowId: 'empty-shell-cards',
      tvItemIndex: tvItemIndex,
      tvZone: ShellTvZone.row,
      listIndex: tvItemIndex,
      onLeftEdge: onFocusLeft,
      onRightEdge: onFocusRight,
      onUpEdge: onFocusUp,
      onDownEdge: onFocusDown,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      child: card,
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 7 : 9,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
