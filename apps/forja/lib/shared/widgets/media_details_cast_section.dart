import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/details_tokens.dart';
import 'package:forja/shared/design/src/shell_section_title.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:rust/rust.dart';

class MediaDetailsCastSection extends StatefulWidget {
  const MediaDetailsCastSection({
    super.key,
    required this.cast,
    this.title = 'Cast',
    this.outdentHorizontal = 0,
    this.tvTabId,
    this.tvRowId,
    this.tvRowOrder = 0,
    this.tvFocusUp,
  });

  final List<Map<String, String>> cast;
  final String title;
  /// Cancels parent horizontal padding so row insets match home catalog rows.
  final double outdentHorizontal;
  final String? tvTabId;
  final String? tvRowId;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;

  static const double _avatarSize = 88;
  static const double _itemWidth = 112;
  static const double _horizontalGap = 32;
  static const double _titleGap = DetailsTokens.sectionTitleGap;
  static const double _avatarNameGap = 8;
  static const double _nameCharacterGap = 3;

  static const double _rowHeight =
      _avatarSize + _avatarNameGap + 16 + _nameCharacterGap + 14;

  @override
  State<MediaDetailsCastSection> createState() =>
      _MediaDetailsCastSectionState();
}

class _MediaDetailsCastSectionState extends State<MediaDetailsCastSection> {
  String get _rowId => widget.tvRowId ?? 'cast';

  @override
  void dispose() {
    final tabId = widget.tvTabId ?? ShellTvFocus.currentNavTabId;
    if (tabId != null && widget.tvRowId != null) {
      shellTvUnregisterRow(tabId: tabId, rowId: _rowId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cast.isEmpty) return const SizedBox.shrink();

    final tabId = widget.tvTabId ?? ShellTvFocus.currentNavTabId;
    if (tabId != null && widget.tvRowId != null) {
      shellTvRegisterRow(
        tabId: tabId,
        rowId: _rowId,
        sortOrder: widget.tvRowOrder,
        itemCount: widget.cast.length,
        onFocusUp: widget.tvFocusUp,
      );
    }

    final homePad = ShellTokens.homeSectionHorizontalPadding;
    final outdent = widget.outdentHorizontal;
    final useHomeInsets = outdent > 0;

    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (useHomeInsets)
          ShellSectionTitle(
            title: widget.title,
            padding: EdgeInsets.fromLTRB(
              homePad,
              0,
              homePad,
              DetailsTokens.sectionTitleGap,
            ),
          )
        else ...[
          Text(widget.title, style: ShellSectionTitle.titleStyle),
          const SizedBox(height: MediaDetailsCastSection._titleGap),
        ],
        FocusTraversalGroup(
          child: HorizontalScroller(
            height: MediaDetailsCastSection._rowHeight,
            padding: useHomeInsets
                ? EdgeInsets.only(left: homePad)
                : EdgeInsets.zero,
            itemCount: widget.cast.length,
            separatorBuilder: (_, _) => const SizedBox(
              width: MediaDetailsCastSection._horizontalGap,
            ),
            itemBuilder: (_, i) {
              final m = widget.cast[i];
              final profilePath = m['profilePath'] ?? '';
              final name = m['name'] ?? '';
              final character = m['character'] ?? '';
              return shellFocusableTap(
                context: context,
                borderRadius: MediaDetailsCastSection._avatarSize / 2,
                listIndex: i,
                tvTabId: tabId,
                tvRowId: widget.tvRowId != null ? _rowId : null,
                tvItemIndex: i,
                child: SizedBox(
                  width: MediaDetailsCastSection._itemWidth,
                  child: Column(
                    children: [
                      ClipOval(
                        child: profilePath.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: TmdbApi.getProfileUrl(profilePath),
                                width: MediaDetailsCastSection._avatarSize,
                                height: MediaDetailsCastSection._avatarSize,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: MediaDetailsCastSection._avatarSize,
                                height: MediaDetailsCastSection._avatarSize,
                                color: Colors.white.withValues(alpha: 0.08),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white.withValues(alpha: 0.24),
                                  size: 36,
                                ),
                              ),
                      ),
                      const SizedBox(
                        height: MediaDetailsCastSection._avatarNameGap,
                      ),
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
                        const SizedBox(
                          height: MediaDetailsCastSection._nameCharacterGap,
                        ),
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
}
