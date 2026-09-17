import 'package:flutter/material.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/horizontal_scroller.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Horizontal cast row under a details hero — props only.
class DetailsCastSection extends StatelessWidget {
  const DetailsCastSection({
    super.key,
    required this.cast,
    this.title = 'Cast',
    this.outdentHorizontal = 0,
    this.itemBuilder,
  });

  final List<Map<String, String>> cast;
  final String title;
  /// Cancels parent horizontal padding so row insets match home catalog rows.
  final double outdentHorizontal;
  /// Optional host wrap (TV focus / shellFocusableTap). Defaults to paint scope.
  final Widget Function(
    BuildContext context, {
    required int index,
    required Widget child,
  })? itemBuilder;

  static const double _avatarNameGap = 8;
  static const double _nameCharacterGap = 3;

  static double _rowHeight(double avatarSize) =>
      avatarSize * ForjaMotionTheme.defaults.cardLift.focusScale +
      _avatarNameGap +
      16 +
      _nameCharacterGap +
      15 +
      4;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();

    final tv = ShellPaintScope.usesTvDensityOf(context);
    final avatarSize =
        tv ? DetailsTokens.castAvatarSizeTv : DetailsTokens.castAvatarSize;
    final itemWidth =
        tv ? DetailsTokens.castItemWidthTv : DetailsTokens.castItemWidth;
    final horizontalGap =
        tv ? DetailsTokens.castGapTv : DetailsTokens.castGap;
    final titleGap = tv
        ? DetailsTokens.sectionTitleGapTv
        : DetailsTokens.sectionTitleGap;
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: tv
          ? DetailsTokens.sectionTitleFontSizeTv
          : ShellTokens.sectionTitleFontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: ShellTokens.sectionTitleLetterSpacing,
    );
    const homePad = ShellTokens.homeSectionHorizontalPadding;
    final outdent = outdentHorizontal;

    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            homePad,
            0,
            homePad,
            titleGap,
          ),
          child: Text(title, style: titleStyle),
        ),
        FocusTraversalGroup(
          child: HorizontalScroller(
            height: _rowHeight(avatarSize),
            padding: const EdgeInsets.symmetric(horizontal: homePad),
            itemCount: cast.length,
            separatorBuilder: (_, _) => SizedBox(width: horizontalGap),
            itemBuilder: (context, i) {
              final m = cast[i];
              final profilePath = m['profilePath'] ?? '';
              final name = m['name'] ?? '';
              final character = m['character'] ?? '';
              final avatar = ClipOval(
                child: profilePath.startsWith('http')
                    ? ForjaNetworkImage(
                        url: profilePath,
                        width: avatarSize,
                        height: avatarSize,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: avatarSize,
                        height: avatarSize,
                        color: Colors.white.withValues(alpha: 0.08),
                        child: Icon(
                          Icons.person,
                          color: Colors.white.withValues(alpha: 0.24),
                          size: 36,
                        ),
                      ),
              );
              final focusChild = itemBuilder != null
                  ? itemBuilder!(context, index: i, child: avatar)
                  : _defaultAvatarTap(
                      context,
                      index: i,
                      avatarSize: avatarSize,
                      child: avatar,
                    );
              return SizedBox(
                width: itemWidth,
                child: Column(
                  children: [
                    focusChild,
                    const SizedBox(height: _avatarNameGap),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (character.isNotEmpty) ...[
                      const SizedBox(height: _nameCharacterGap),
                      Text(
                        character,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );

    if (outdent <= 0) return row;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth + outdent * 2,
          child: Transform.translate(
            offset: Offset(-outdent, 0),
            child: row,
          ),
        );
      },
    );
  }

  static Widget _defaultAvatarTap(
    BuildContext context, {
    required int index,
    required double avatarSize,
    required Widget child,
  }) {
    return ShellPaintScope.focusableTap(
      context: context,
      borderRadius: avatarSize / 2,
      showFocusBorder: true,
      showFocusFill: false,
      listIndex: index,
      motion: ForjaMotionPreset.cardLift,
      child: child,
    );
  }
}

/// Host alias.
typedef MediaDetailsCastSection = DetailsCastSection;
