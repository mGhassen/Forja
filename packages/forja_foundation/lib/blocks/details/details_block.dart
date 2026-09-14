import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/details/details_body.dart';
import 'package:forja_foundation/widgets/details/details_hero.dart';
import 'package:forja_foundation/widgets/details/play_row.dart';

/// Prebuilt media-details page: [DetailsHero] + body sections from props.
///
/// Pack JSON example:
/// ```json
/// {
///   "type": "details",
///   "props": {
///     "title": "…",
///     "backdropUrl": "…",
///     "overview": "…",
///     "genres": ["Drama"],
///     "metaParts": ["2024", "TV-14"],
///     "rating": 8.1
///   }
/// }
/// ```
/// Host injects [actionRow] / [overlay] / [onRetry] only — never product widgets
/// invented in the painter.
class DetailsBlock extends StatelessWidget {
  const DetailsBlock({
    super.key,
    required this.hero,
    this.playRow,
    required this.body,
    this.scrollable = true,
    this.scrollController,
    this.physics,
    this.backgroundColor,
  });

  /// Builds the full details design from a props map (+ host action/overlay).
  ///
  /// Returns [DetailsScreen] wrapping a composed [DetailsHero] + body.
  static Widget fromProps(
    Map<String, dynamic> props, {
    Widget? actionRow,
    Widget? overlay,
    VoidCallback? onRetry,
    List<Widget> sections = const [],
    ScrollController? scrollController,
    Color? fallbackBackground,
  }) {
    final bg = propsColor(props, 'backgroundColor') ??
        fallbackBackground ??
        const Color(0xFF141414);
    final hero = DetailsHero(
      backdropUrl: propsStringOr(props, 'backdropUrl', ''),
      backdropUrls: propsStringList(props, 'backdropUrls'),
      title: propsStringOr(props, 'title', ''),
      subtitle: propsString(props, 'subtitle'),
      genres: propsStringList(props, 'genres'),
      metaParts: propsStringList(props, 'metaParts'),
      rating: propsNum(props, 'rating'),
      overview: propsStringOr(props, 'overview', ''),
      logoUrl: propsString(props, 'logoUrl'),
      actionRow: actionRow,
      enableKenBurns: propsBool(props, 'enableKenBurns', true),
      tvDensity: propsBool(props, 'tvDensity'),
      plainTitle: propsBool(props, 'plainTitle'),
      selectableTitle: propsBool(props, 'selectableTitle'),
      chromeOnly: propsBool(props, 'chromeOnly'),
      contentScrim: propsBool(props, 'contentScrim'),
      height: propsNum(props, 'height'),
    );

    final scroll = DetailsBlock(
      hero: hero,
      scrollController: scrollController,
      backgroundColor: bg,
      body: sections.isEmpty
          ? const SizedBox.shrink()
          : DetailsBody(
              backgroundColor: bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < sections.length; i++) ...[
                    if (i > 0)
                      const SizedBox(height: DetailsTokens.sectionSpacing),
                    sections[i],
                  ],
                ],
              ),
            ),
    );

    return DetailsScreen(
      backgroundColor: bg,
      loading: propsBool(props, 'loading'),
      errorMessage: propsString(props, 'errorMessage'),
      onRetry: onRetry,
      overlay: overlay,
      body: scroll,
    );
  }

  final Widget hero;
  final PlayRow? playRow;
  final Widget body;
  final bool scrollable;
  final ScrollController? scrollController;
  final ScrollPhysics? physics;
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

    final child = scrollable
        ? SingleChildScrollView(
            controller: scrollController,
            physics: physics,
            child: column,
          )
        : column;
    final bg = backgroundColor ?? theme.bgDark;
    return ColoredBox(color: bg, child: child);
  }
}

/// Loading / error / body scaffold used by [DetailsBlock.fromProps].
class DetailsScreen extends StatelessWidget {
  const DetailsScreen({
    super.key,
    required this.backgroundColor,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    this.loadingChild,
    this.errorChild,
    this.body,
    this.overlay,
  });

  factory DetailsScreen.fromProps(
    Map<String, dynamic> props, {
    Widget? body,
    Widget? overlay,
    Widget? loadingChild,
    Widget? errorChild,
    VoidCallback? onRetry,
    Color? fallbackBackground,
  }) {
    return DetailsScreen(
      backgroundColor:
          propsColor(props, 'backgroundColor') ??
          fallbackBackground ??
          const Color(0xFF141414),
      loading: propsBool(props, 'loading'),
      errorMessage: propsString(props, 'errorMessage'),
      onRetry: onRetry,
      loadingChild: loadingChild,
      errorChild: errorChild,
      body: body,
      overlay: overlay,
    );
  }

  final Color backgroundColor;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Widget? loadingChild;
  final Widget? errorChild;
  final Widget? body;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    Widget content;
    if (loading) {
      content = loadingChild ??
          Center(
            child: CircularProgressIndicator(color: theme.brandGreen),
          );
    } else if (errorMessage != null && errorMessage!.trim().isNotEmpty) {
      content = errorChild ??
          Center(
            child: Padding(
              padding: EdgeInsets.all(theme.spaceLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textSecondary),
                  ),
                  if (onRetry != null) ...[
                    SizedBox(height: theme.spaceMd),
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ],
              ),
            ),
          );
    } else {
      content = body ?? const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          content,
          ?overlay,
        ],
      ),
    );
  }
}

/// Host helper: [DetailsScreen] + hero slot + section list.
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
    this.scrollController,
    this.sectionSpacing,
    this.loadingChild,
    this.errorChild,
  });

  final Widget hero;
  final PlayRow? playRow;
  final List<Widget> sections;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Widget? overlay;
  final Color? backgroundColor;
  final ScrollController? scrollController;
  final double? sectionSpacing;
  final Widget? loadingChild;
  final Widget? errorChild;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final bg = backgroundColor ?? theme.bgDark;
    final gap = sectionSpacing ?? theme.spaceLg;
    return DetailsScreen(
      backgroundColor: bg,
      loading: loading,
      errorMessage: errorMessage,
      onRetry: onRetry,
      loadingChild: loadingChild,
      errorChild: errorChild,
      overlay: overlay,
      body: DetailsBlock(
        hero: hero,
        playRow: playRow,
        scrollController: scrollController,
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
                if (i > 0) SizedBox(height: gap),
                sections[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry details: title chrome + body (props-driven empty copy).
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

/// Prebuilt entry-details page from props.
///
/// ```json
/// { "type": "entryDetails", "props": { "title": "…", "emptyMessage": "…" } }
/// ```
class EntryDetails extends StatelessWidget {
  const EntryDetails({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.emptyMessage = 'No details panel for this list',
  });

  factory EntryDetails.fromProps(
    Map<String, dynamic> props, {
    Widget? body,
    VoidCallback? onBack,
  }) {
    final empty = propsStringOr(
      props,
      'emptyMessage',
      'No details panel for this list',
    );
    return EntryDetails(
      title: propsStringOr(props, 'title', ''),
      body: body,
      onBack: onBack,
      emptyMessage: empty,
    );
  }

  final String title;
  final Widget? body;
  final VoidCallback? onBack;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return EntryDetailsChrome(
      title: title,
      onBack: onBack,
      body: body ??
          Center(
            child: Text(
              emptyMessage,
              style: const TextStyle(color: ForjaShellColors.textSecondary),
            ),
          ),
    );
  }
}
