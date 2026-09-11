import 'dart:math' as math;

import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja/shared/host/kit/kit_list_host_hooks.dart';
import 'package:forja/shared/host/kit/kit_event_card.dart';
import 'package:forja/shared/engine/live/match_event.dart';
import 'package:forja/shared/engine/live/schedule_sport_filter.dart';

/// Registers MatchEvent cards / dense viewers on [KitListHostHooks] (RFC-106).
abstract final class KitListLiveCards {
  KitListLiveCards._();

  static void register() {
    KitListHostHooks.entryViewers = (entry) {
      final fromRow = parseLiveViewerCount(entry.legacyRow['viewers']);
      final fromMeta = entry.meta.viewers ?? 0;
      return fromRow > fromMeta ? fromRow : fromMeta;
    };
    KitListHostHooks.cardsGridLayout = (
      context, {
      required maxWidth,
      required chromeTop,
    }) {
      final minW = KitEventCard.cardWidth(context);
      final minH = KitEventCard.cardHeight(context);
      final gap = KitEventCard.gridGap(context);
      final pad = shellHomeSectionHorizontalPadding(context);
      final inner = math.max(0.0, maxWidth - pad * 2);
      final columns =
          math.max(1, ((inner + gap) / (minW + gap)).floor()).clamp(1, 8);
      final cardW = columns <= 1
          ? inner
          : (inner - (columns - 1) * gap) / columns;
      final cardH = minW > 0 ? minH * (cardW / minW) : minH;
      return (
        columns: columns,
        cardW: cardW,
        cardH: cardH,
        gap: gap,
        leading: pad,
        rightPad: pad,
        topPad: chromeTop + 4,
      );
    };
    KitListHostHooks.buildCardsEntry = (
      context, {
      required entry,
      required index,
      required columns,
      required cardW,
      required cardH,
      required selected,
      required tabId,
      required gridRowId,
      onUpEdge,
      onRightEdge,
      required onTap,
    }) {
      final match = MatchEvent.fromLegacyRow(entry.legacyRow);
      return KitEventCard(
        match: match,
        width: cardW,
        height: cardH,
        gridIndex: index,
        gridColumns: columns,
        selected: selected,
        tvTabId: tabId,
        tvRowId: gridRowId,
        onUpEdge: onUpEdge,
        onRightEdge: onRightEdge,
        onTap: onTap,
      );
    };
  }
}
