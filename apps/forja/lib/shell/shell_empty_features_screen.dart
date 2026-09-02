import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_visibility_provider.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/animated_logo.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shown when every shell feature tab is hidden — guides users to Features
/// and plugin install instead of landing on an empty Settings body.
class ShellEmptyFeaturesScreen extends ConsumerStatefulWidget {
  const ShellEmptyFeaturesScreen({
    super.key,
    required this.onOpenFeatures,
    this.onInstallPlugins,
  });

  final VoidCallback onOpenFeatures;
  final VoidCallback? onInstallPlugins;

  @override
  ConsumerState<ShellEmptyFeaturesScreen> createState() =>
      _ShellEmptyFeaturesScreenState();
}

class _ShellEmptyFeaturesScreenState
    extends ConsumerState<ShellEmptyFeaturesScreen> {
  final FocusNode _featuresFocus = FocusNode(debugLabel: 'empty-features-cta');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.metricsOf(context).usesTvDensity) return;
      if (_featuresFocus.canRequestFocus) {
        _featuresFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _featuresFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ShellScope.metricsOf(context);
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final visibility = ref.watch(settingsVisibilityProvider).valueOrNull;
    final showPlugins = visibility?.showSourcesCategory ?? true;
    final profile = ShellScope.profileOf(context);
    final logoHeight = metrics.usesTvDensity
        ? 96.0
        : profile == ShellProfile.mobile
            ? 72.0
            : 88.0;

    return ColoredBox(
      color: AppTheme.bgDark,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: profile == ShellProfile.mobile ? 24 : 40,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ForjaLogoIdle(logoHeight: logoHeight),
                  const SizedBox(height: 28),
                  Text(
                    'Turn on a feature to get started',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: ForjaShellColors.textPrimary,
                      fontSize: metrics.usesTvDensity ? 26 : 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Forja is built from plugins. Enable tabs you want in '
                    'Settings → Features, or install catalog and stream packs '
                    'for a fuller experience.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: ForjaShellColors.textSecondary.withValues(
                        alpha: 0.92,
                      ),
                      fontSize: metrics.usesTvDensity ? 15 : 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _HintCard(
                    icon: Icons.tab_rounded,
                    title: 'Features',
                    body:
                        'Choose which tabs appear — Home, Anime, IPTV, Live Matches, Lists, and more.',
                    actionLabel: 'Open Features',
                    onAction: widget.onOpenFeatures,
                    tvFocus: tvFocus,
                    autofocus: tvFocus,
                    focusNode: _featuresFocus,
                  ),
                  if (showPlugins && widget.onInstallPlugins != null) ...[
                    const SizedBox(height: 12),
                    _HintCard(
                      icon: Icons.extension_rounded,
                      title: 'Plugins',
                      body:
                          'Install hub and stream packs from a manifest URL, or sync packs from your profile.',
                      actionLabel: 'Install plugins',
                      onAction: widget.onInstallPlugins!,
                      tvFocus: tvFocus,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Your profile avatar in the sidebar opens Settings anytime.',
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    required this.tvFocus,
    this.autofocus = false,
    this.focusNode,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final bool tvFocus;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final border = ForjaShellColors.borderSubtle.withValues(alpha: 0.55);
    final surface = ForjaShellColors.surfaceElevated.withValues(alpha: 0.35);

    final action = tvFocus
        ? shellFocusableTap(
            context: context,
            onTap: onAction,
            focusNode: focusNode,
            autoFocus: autofocus,
            borderRadius: 20,
            scaleOnFocus: ShellTokens.focusActiveScale,
            ensureVisibleMode: ShellTvEnsureVisibleMode.item,
            child: _ActionChip(label: actionLabel),
          )
        : TextButton(
            onPressed: onAction,
            autofocus: autofocus,
            focusNode: focusNode,
            style: TextButton.styleFrom(
              foregroundColor: ForjaShellColors.sectionAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: ForjaShellColors.sectionAccent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: ForjaShellColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        body,
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary.withValues(
                            alpha: 0.9,
                          ),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
