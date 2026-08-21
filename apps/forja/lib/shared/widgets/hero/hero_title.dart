import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/hero/desktop_selectable_title.dart';
import 'package:rust/rust.dart';

enum HeroTitleStyle { details, home }

/// Line height for details fallback titles. `1.0` smashes wrapped lines.
const double kHeroTitleLineHeight = 1.12;

/// Keeps neg letterSpacing / chromatic offsets + descenders out of the parent
/// clip and off the meta row.
const EdgeInsets kHeroTitlePad = EdgeInsets.fromLTRB(4, 2, 4, 8);

/// Largest font size ≤ [preferredSize] that fits [title] in [maxWidth]×[maxHeight]
/// with at most [maxLines] (then ellipsis). Shared by hub / home / details heroes.
double fitHeroTitleFontSize({
  required String title,
  required double maxWidth,
  required double maxHeight,
  required int maxLines,
  double preferredSize = 48,
  double minSize = 20,
  double height = kHeroTitleLineHeight,
  double letterSpacing = -1.2,
  FontWeight fontWeight = FontWeight.w900,
  EdgeInsets pad = kHeroTitlePad,
}) {
  final availW = maxWidth - pad.horizontal;
  final availH = maxHeight - pad.vertical;
  if (availW <= 0 || availH <= 0 || title.isEmpty) {
    return minSize.clamp(minSize, preferredSize);
  }

  double measure(double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          fontSize: size,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing,
        ),
      ),
      maxLines: maxLines,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: availW);
    return painter.height;
  }

  var lo = minSize;
  var hi = preferredSize;
  if (measure(hi) <= availH) return hi;
  if (measure(lo) > availH) return lo;

  // Binary search largest size that fits.
  for (var i = 0; i < 12; i++) {
    final mid = (lo + hi) / 2;
    if (measure(mid) <= availH) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

int heroTitleMaxLinesForSlot(double maxHeight) {
  if (maxHeight < 48) return 1;
  if (maxHeight < 78) return 2;
  return 3;
}

double heroTitlePreferredFontSize(double maxHeight) {
  if (maxHeight <= 56) return 32;
  if (maxHeight <= 72) return 40;
  if (maxHeight <= 100) return 44;
  return 48;
}

/// Cyan/amber offset layers under white — desktop/mobile details look.
/// On TV, a single plain [Text]: stacked translucent offsets read as a
/// double image with soft antialiasing on Android TV GLES.
class ChromaticHeroTitleText extends StatelessWidget {
  const ChromaticHeroTitleText({
    super.key,
    required this.title,
    required this.style,
    this.maxLines = 3,
  });

  final String title;
  final TextStyle style;
  final int maxLines;

  static const _pad = kHeroTitlePad;

  Text _titleText(String value, TextStyle textStyle) => Text(
        value,
        style: textStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );

  @override
  Widget build(BuildContext context) {
    final plain = _titleText(title, style);
    if (ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
      return Padding(
        padding: _pad,
        child: wrapDesktopSelectableTitle(context, plain),
      );
    }
    return Padding(
      padding: _pad,
      child: wrapDesktopSelectableTitle(
        context,
        Stack(
          clipBehavior: Clip.none,
          children: [
            desktopTitleSelectionGhost(
              Transform.translate(
                offset: const Offset(-1.5, 0),
                child: _titleText(
                  title,
                  style.copyWith(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
            desktopTitleSelectionGhost(
              Transform.translate(
                offset: const Offset(1.5, 0),
                child: _titleText(
                  title,
                  style.copyWith(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            plain,
          ],
        ),
      ),
    );
  }
}

/// TMDB logo or stylized title for hero surfaces (Home carousel, media details).
class HeroTitle extends StatelessWidget {
  const HeroTitle({
    super.key,
    required this.movie,
    this.logoUrl,
    this.style = HeroTitleStyle.details,
    this.isLandscape = false,
    this.desktop = false,
    this.compact = false,
    this.maxWidth,
    this.slotHeight,
  });

  final Movie movie;
  final String? logoUrl;
  final HeroTitleStyle style;
  final bool isLandscape;
  final bool desktop;
  final bool compact;
  final double? maxWidth;
  final double? slotHeight;

  @override
  Widget build(BuildContext context) {
    if (style == HeroTitleStyle.details) {
      return _DetailsHeroTitle(
        movie: movie,
        logoUrl: logoUrl,
        slotHeight: slotHeight,
      );
    }
    return _HomeHeroTitleSlot(
      movie: movie,
      logoUrl: logoUrl,
      isLandscape: isLandscape,
      desktop: desktop,
      compact: compact,
      maxWidth: maxWidth,
      slotHeight: slotHeight,
    );
  }
}

class _DetailsHeroTitle extends StatefulWidget {
  const _DetailsHeroTitle({
    required this.movie,
    this.logoUrl,
    this.slotHeight,
  });

  final Movie movie;
  final String? logoUrl;
  final double? slotHeight;

  @override
  State<_DetailsHeroTitle> createState() => _DetailsHeroTitleState();
}

class _DetailsHeroTitleState extends State<_DetailsHeroTitle> {
  bool _logoReady = false;

  @override
  void didUpdateWidget(covariant _DetailsHeroTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logoUrl != widget.logoUrl) {
      _logoReady = false;
    }
  }

  void _revealLogo() {
    if (!mounted || _logoReady) return;
    setState(() => _logoReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = widget.logoUrl?.trim() ?? '';
    final logoHeight = widget.slotHeight ?? 96.0;
    final title = _fallbackTitle(widget.movie, logoHeight);
    if (logoUrl.isEmpty) return title;

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        IgnorePointer(
          ignoring: _logoReady,
          child: AnimatedOpacity(
            opacity: _logoReady ? 0 : 1,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            child: title,
          ),
        ),
        Image(
          image: CachedNetworkImageProvider(logoUrl),
          height: logoHeight,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
          frameBuilder: (context, child, frame, sync) {
            if (frame == null && !sync) return const SizedBox.shrink();
            if (!_logoReady) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _revealLogo());
            }
            return AnimatedOpacity(
              opacity: _logoReady ? 1 : 0,
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              child: child,
            );
          },
        ),
      ],
    );
  }

  Widget _fallbackTitle(Movie movie, double maxHeight) {
    final maxLines = heroTitleMaxLinesForSlot(maxHeight);
    final preferred = heroTitlePreferredFontSize(maxHeight);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final fontSize = fitHeroTitleFontSize(
          title: movie.title,
          maxWidth: maxW,
          maxHeight: maxHeight,
          maxLines: maxLines,
          preferredSize: preferred,
        );
        return ChromaticHeroTitleText(
          title: movie.title,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: kHeroTitleLineHeight,
            letterSpacing: -1.2,
          ),
        );
      },
    );
  }
}

class _HomeHeroTitleSlot extends StatelessWidget {
  const _HomeHeroTitleSlot({
    required this.movie,
    this.logoUrl,
    required this.isLandscape,
    this.desktop = false,
    this.compact = false,
    this.maxWidth,
    this.slotHeight,
  });

  final Movie movie;
  final String? logoUrl;
  final bool isLandscape;
  final bool desktop;
  final bool compact;
  final double? maxWidth;
  final double? slotHeight;

  @override
  Widget build(BuildContext context) {
    final bodyWidth = MediaQuery.sizeOf(context).width;
    final logoMaxHeight = compact
        ? ShellTokens.heroLogoMaxHeightCompact
        : desktop
            ? ShellTokens.heroLogoMaxHeightDesktop
            : (isLandscape ? 140.0 : 110.0);
    final resolvedMaxWidth = maxWidth ??
        (compact
            ? bodyWidth * 0.72
            : desktop
                ? ShellTokens.heroTextColumnWidthDesktop
                : (isLandscape ? 420.0 : bodyWidth * 0.75));
    final resolvedSlotHeight = slotHeight ??
        (compact
            ? ShellTokens.heroTitleSlotHeightCompact
            : desktop
                ? ShellTokens.heroTitleSlotHeightDesktop
                : logoMaxHeight + 14);
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    // Text titles use the full slot; logo placeholders fit the logo box.
    final textMaxHeight = hasLogo ? logoMaxHeight : resolvedSlotHeight;
    final title = _plainTitleText(
      context,
      movie,
      isLandscape,
      desktop: desktop,
      compact: compact,
      maxWidth: resolvedMaxWidth,
      maxHeight: textMaxHeight,
    );

    return SizedBox(
      // Compact home may rely on the parent slot; when [slotHeight] is set, honor it.
      height: compact && slotHeight == null ? null : resolvedSlotHeight,
      width: resolvedMaxWidth,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: desktop || compact ? 0 : 14),
          child: hasLogo
              ? SizedBox(
                  height: logoMaxHeight,
                  width: resolvedMaxWidth,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: CachedNetworkImage(
                      imageUrl: logoUrl!,
                      height: logoMaxHeight,
                      width: resolvedMaxWidth,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      placeholder: (_, _) => title,
                      errorWidget: (_, _, _) => title,
                      fadeInDuration: const Duration(milliseconds: 550),
                      fadeOutDuration: const Duration(milliseconds: 450),
                    ),
                  ),
                )
              : title,
        ),
      ),
    );
  }

  Widget _plainTitleText(
    BuildContext context,
    Movie movie,
    bool isLandscape, {
    bool desktop = false,
    bool compact = false,
    required double maxWidth,
    required double maxHeight,
  }) {
    final maxLines = compact ? 2 : 3;
    final preferred = compact
        ? 22.0
        : desktop
            ? 32.0
            : (isLandscape ? 48.0 : 36.0);
    const height = 1.05;
    const letterSpacing = -1.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxWidth;
        final h = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : maxHeight;
        final fontSize = fitHeroTitleFontSize(
          title: movie.title,
          maxWidth: w,
          maxHeight: h,
          maxLines: maxLines,
          preferredSize: preferred,
          minSize: compact ? 16 : 20,
          height: height,
          letterSpacing: letterSpacing,
          pad: EdgeInsets.zero,
        );
        return wrapDesktopSelectableTitle(
          context,
          Text(
            movie.title,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: height,
              letterSpacing: letterSpacing,
              shadows: [
                const Shadow(color: Colors.black, blurRadius: 40),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 80,
                ),
              ],
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
