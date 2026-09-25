import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/utils/cover_urls.dart';

enum HeroTitleStyle { details, home }

/// Line height for details fallback titles. `1.0` smashes wrapped lines.
const double kHeroTitleLineHeight = 1.12;

/// Keeps neg letterSpacing / chromatic offsets + descenders out of the parent
/// clip and off the meta row.
const EdgeInsets kHeroTitlePad = EdgeInsets.fromLTRB(4, 2, 4, 8);

/// Largest font size ≤ [preferredSize] that fits [title] in [maxWidth]×[maxHeight]
/// with at most [maxLines] (then ellipsis).
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
  TextDirection textDirection = TextDirection.ltr,
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
      textDirection: textDirection,
    )..layout(maxWidth: availW);
    return painter.height;
  }

  var lo = minSize;
  var hi = preferredSize;
  if (measure(hi) <= availH) return hi;
  if (measure(lo) > availH) return lo;

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

double heroTitlePreferredFontSize(
  double maxHeight, {
  bool tvDensity = false,
}) {
  if (tvDensity) {
    if (maxHeight <= 40) return 12;
    if (maxHeight <= 56) return 14;
    if (maxHeight <= 72) return 16;
    return ShellTokens.heroFallbackTitlePreferredMaxTv;
  }
  if (maxHeight <= 56) return 26;
  if (maxHeight <= 72) return 32;
  if (maxHeight <= 100) return 36;
  return ShellTokens.heroFallbackTitlePreferredMax;
}

double heroTitleMinFontSize({bool tvDensity = false}) => tvDensity
    ? ShellTokens.heroFallbackTitleMinTv
    : ShellTokens.heroFallbackTitleMin;

Widget _wrapSelectable(Widget child, {required bool selectable}) {
  if (!selectable) return child;
  return SelectionArea(child: child);
}

Widget _selectionGhost(Widget child) => SelectionContainer.disabled(child: child);

/// Cyan/amber offset layers under white — desktop/mobile details look.
/// On TV ([plainTitle]), a single plain [Text].
class ChromaticHeroTitleText extends StatelessWidget {
  const ChromaticHeroTitleText({
    super.key,
    required this.title,
    required this.style,
    this.maxLines = 3,
    this.plainTitle = false,
    this.selectable = false,
  });

  final String title;
  final TextStyle style;
  final int maxLines;
  final bool plainTitle;
  final bool selectable;

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
    if (plainTitle) {
      return Padding(
        padding: _pad,
        child: _wrapSelectable(plain, selectable: selectable),
      );
    }
    return Padding(
      padding: _pad,
      child: _wrapSelectable(
        Stack(
          clipBehavior: Clip.none,
          children: [
            _selectionGhost(
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
            _selectionGhost(
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
        selectable: selectable,
      ),
    );
  }
}

/// Logo or stylized title for hero surfaces. Host passes [title] (not `Movie`).
class HeroTitle extends StatelessWidget {
  const HeroTitle({
    super.key,
    required this.title,
    this.logoUrl,
    this.style = HeroTitleStyle.details,
    this.isLandscape = false,
    this.desktop = false,
    this.compact = false,
    this.maxWidth,
    this.slotHeight,
    this.logoMaxHeight,
    this.tvDensity = false,
    this.plainTitle = false,
    this.selectable = false,
  });

  final String title;
  final String? logoUrl;
  final HeroTitleStyle style;
  final bool isLandscape;
  final bool desktop;
  final bool compact;
  final double? maxWidth;
  final double? slotHeight;
  /// Pack override; null → ShellTokens logo max for density/desktop/compact.
  final double? logoMaxHeight;
  final bool tvDensity;
  final bool plainTitle;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    if (style == HeroTitleStyle.details) {
      return _DetailsHeroTitle(
        title: title,
        logoUrl: logoUrl,
        slotHeight: slotHeight,
        logoMaxHeight: logoMaxHeight,
        tvDensity: tvDensity,
        plainTitle: plainTitle,
        selectable: selectable,
      );
    }
    return _HomeHeroTitleSlot(
      title: title,
      logoUrl: logoUrl,
      isLandscape: isLandscape,
      desktop: desktop,
      compact: compact,
      maxWidth: maxWidth,
      slotHeight: slotHeight,
      logoMaxHeight: logoMaxHeight,
      tvDensity: tvDensity,
      selectable: selectable,
    );
  }
}

class _DetailsHeroTitle extends StatefulWidget {
  const _DetailsHeroTitle({
    required this.title,
    this.logoUrl,
    this.slotHeight,
    this.logoMaxHeight,
    required this.tvDensity,
    required this.plainTitle,
    required this.selectable,
  });

  final String title;
  final String? logoUrl;
  final double? slotHeight;
  final double? logoMaxHeight;
  final bool tvDensity;
  final bool plainTitle;
  final bool selectable;

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
    final logoUrl = paintableNetworkImageUrl(widget.logoUrl?.trim() ?? '');
    final defaultHeight = widget.logoMaxHeight ??
        (widget.tvDensity ? ShellTokens.heroLogoMaxHeightTv : 96.0);
    final logoHeight = widget.slotHeight == null
        ? defaultHeight
        : widget.tvDensity
            ? widget.slotHeight!.clamp(
                0.0,
                widget.logoMaxHeight ?? ShellTokens.heroLogoMaxHeightTv,
              )
            : widget.slotHeight!;
    final fallback = _fallbackTitle(widget.title, logoHeight);
    if (logoUrl.isEmpty) return fallback;

    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        IgnorePointer(
          ignoring: _logoReady,
          child: AnimatedOpacity(
            opacity: _logoReady ? 0 : 1,
            duration: ForjaMotionTheme.of(context).pageFade.duration,
            curve: Curves.easeOutCubic,
            child: fallback,
          ),
        ),
        Image.network(
          logoUrl,
          height: logoHeight,
          fit: BoxFit.contain,
          alignment: AlignmentDirectional.centerStart,
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

  Widget _fallbackTitle(String title, double maxHeight) {
    final maxLines = heroTitleMaxLinesForSlot(maxHeight);
    final preferred = heroTitlePreferredFontSize(
      maxHeight,
      tvDensity: widget.tvDensity,
    );
    final minSize = heroTitleMinFontSize(tvDensity: widget.tvDensity);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final fontSize = fitHeroTitleFontSize(
          title: title,
          maxWidth: maxW,
          maxHeight: maxHeight,
          maxLines: maxLines,
          preferredSize: preferred,
          minSize: minSize,
          textDirection: Directionality.of(context),
        );
        return ChromaticHeroTitleText(
          title: title,
          maxLines: maxLines,
          plainTitle: widget.plainTitle,
          selectable: widget.selectable,
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
    required this.title,
    this.logoUrl,
    required this.isLandscape,
    this.desktop = false,
    this.compact = false,
    this.maxWidth,
    this.slotHeight,
    this.logoMaxHeight,
    required this.tvDensity,
    required this.selectable,
  });

  final String title;
  final String? logoUrl;
  final bool isLandscape;
  final bool desktop;
  final bool compact;
  final double? maxWidth;
  final double? slotHeight;
  final double? logoMaxHeight;
  final bool tvDensity;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final bodyWidth = MediaQuery.sizeOf(context).width;
    final resolvedLogoMax = logoMaxHeight ??
        (tvDensity
            ? ShellTokens.heroLogoMaxHeightTv
            : compact
                ? ShellTokens.heroLogoMaxHeightCompact
                : desktop
                    ? ShellTokens.heroLogoMaxHeightDesktop
                    : (isLandscape ? 140.0 : 110.0));
    final resolvedMaxWidth = maxWidth ??
        (compact
            ? bodyWidth * 0.72
            : desktop
                ? ShellTokens.heroTextColumnWidthDesktop
                : (isLandscape ? 420.0 : bodyWidth * 0.75));
    final resolvedSlotHeight = slotHeight ??
        (compact
            ? ShellTokens.heroTitleSlotHeightCompact
            : tvDensity
                ? ShellTokens.heroTitleSlotHeightTv
                : desktop
                    ? ShellTokens.heroTitleSlotHeightDesktop
                    : resolvedLogoMax + 14);
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    final paintLogo = hasLogo ? paintableNetworkImageUrl(logoUrl!) : '';
    final textMaxHeight = hasLogo ? resolvedLogoMax : resolvedSlotHeight;
    final fallback = _plainTitleText(
      context,
      title,
      isLandscape,
      desktop: desktop,
      compact: compact,
      maxWidth: resolvedMaxWidth,
      maxHeight: textMaxHeight,
    );

    return SizedBox(
      height: compact && slotHeight == null ? null : resolvedSlotHeight,
      width: resolvedMaxWidth,
      child: Align(
        alignment: AlignmentDirectional.bottomStart,
        child: Padding(
          padding: EdgeInsets.only(bottom: desktop || compact ? 0 : 14),
          child: paintLogo.isNotEmpty
              ? SizedBox(
                  height: resolvedLogoMax,
                  width: resolvedMaxWidth,
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: Image.network(
                      paintLogo,
                      height: resolvedLogoMax,
                      width: resolvedMaxWidth,
                      fit: BoxFit.contain,
                      alignment: AlignmentDirectional.centerStart,
                      errorBuilder: (_, _, _) => fallback,
                      frameBuilder: (context, child, frame, sync) {
                        if (frame == null && !sync) return fallback;
                        return AnimatedOpacity(
                          opacity: 1,
                          duration: const Duration(milliseconds: 550),
                          child: child,
                        );
                      },
                    ),
                  ),
                )
              : fallback,
        ),
      ),
    );
  }

  Widget _plainTitleText(
    BuildContext context,
    String title,
    bool isLandscape, {
    bool desktop = false,
    bool compact = false,
    required double maxWidth,
    required double maxHeight,
  }) {
    final maxLines = compact ? 2 : 3;
    final preferred = tvDensity
        ? heroTitlePreferredFontSize(maxHeight, tvDensity: true)
        : compact
            ? 22.0
            : desktop
                ? 32.0
                : (isLandscape ? 48.0 : 36.0);
    final minSize = heroTitleMinFontSize(tvDensity: tvDensity);
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
          title: title,
          maxWidth: w,
          maxHeight: h,
          maxLines: maxLines,
          preferredSize: preferred,
          minSize: minSize,
          height: height,
          letterSpacing: letterSpacing,
          pad: EdgeInsets.zero,
          textDirection: Directionality.of(context),
        );
        return _wrapSelectable(
          Text(
            title,
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
          selectable: selectable,
        );
      },
    );
  }
}
