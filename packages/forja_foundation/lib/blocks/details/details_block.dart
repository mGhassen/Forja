import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/details/details_hero.dart';
import 'package:forja_foundation/widgets/details/details_screen.dart';
import 'package:forja_foundation/widgets/details/play_row.dart';

/// Details page template — hero + optional play row + body (RFC-106 G6).
class DetailsBlock extends StatelessWidget {
  const DetailsBlock({
    super.key,
    required this.hero,
    this.playRow,
    required this.body,
    this.scrollable = true,
    this.backgroundColor,
  });

  final DetailsHero hero;
  final PlayRow? playRow;
  final Widget body;
  final bool scrollable;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hero,
        if (playRow != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spaceLg,
              theme.spaceMd,
              theme.spaceLg,
              0,
            ),
            child: playRow,
          ),
        body,
      ],
    );

    final child = scrollable ? SingleChildScrollView(child: column) : column;
    final bg = backgroundColor ?? theme.bgDark;
    return ColoredBox(color: bg, child: child);
  }
}

/// Convenience scaffold wrapping [DetailsScreen] + [DetailsBlock].
class DetailsPageBlock extends StatelessWidget {
  const DetailsPageBlock({
    super.key,
    required this.hero,
    required this.sections,
    this.playRow,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    this.overlay,
    this.backgroundColor,
  });

  final DetailsHero hero;
  final PlayRow? playRow;
  final List<Widget> sections;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Widget? overlay;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final bg = backgroundColor ?? theme.bgDark;
    return DetailsScreen(
      backgroundColor: bg,
      loading: loading,
      errorMessage: errorMessage,
      onRetry: onRetry,
      overlay: overlay,
      body: DetailsBlock(
        hero: hero,
        playRow: playRow,
        backgroundColor: bg,
        body: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ShellTokens.homeSectionHorizontalPadding,
            vertical: theme.spaceLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) SizedBox(height: theme.spaceLg),
                sections[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry details chrome — title bar + body slot (host fills panel).
class EntryDetailsChrome extends StatelessWidget {
  const EntryDetailsChrome({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ForjaShellColors.surfaceElevated,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                ShellTokens.bodyHorizontalPadding,
                8,
                ShellTokens.bodyHorizontalPadding,
                8,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    color: ForjaShellColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ForjaShellColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: ForjaShellColors.borderSubtle),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
