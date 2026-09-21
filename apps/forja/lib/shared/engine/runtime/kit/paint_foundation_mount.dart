import 'package:flutter/material.dart'
    hide Badge, Checkbox, ListTile, Radio, Slider, Switch, Tooltip;
import 'package:forja_foundation/blocks/catalog/catalog_cards_grid.dart';
import 'package:forja_foundation/blocks/props_map.dart';
import 'package:forja_foundation/blocks/search/search_block.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
import 'package:forja_foundation/components/accordion.dart';
import 'package:forja_foundation/components/alert.dart';
import 'package:forja_foundation/components/avatar.dart';
import 'package:forja_foundation/components/badge.dart';
import 'package:forja_foundation/components/breadcrumb.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/components/button_group.dart';
import 'package:forja_foundation/components/checkbox.dart';
import 'package:forja_foundation/components/dialog.dart';
import 'package:forja_foundation/components/empty.dart';
import 'package:forja_foundation/components/field.dart';
import 'package:forja_foundation/components/input.dart';
import 'package:forja_foundation/components/input_group.dart';
import 'package:forja_foundation/components/item.dart';
import 'package:forja_foundation/components/kbd.dart';
import 'package:forja_foundation/components/label.dart';
import 'package:forja_foundation/components/list_tile.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/components/pagination.dart';
import 'package:forja_foundation/components/poster_frame.dart';
import 'package:forja_foundation/components/progress.dart';
import 'package:forja_foundation/components/radio.dart';
import 'package:forja_foundation/components/search_field.dart';
import 'package:forja_foundation/components/segmented.dart';
import 'package:forja_foundation/components/select.dart';
import 'package:forja_foundation/components/separator.dart';
import 'package:forja_foundation/components/settled_network_image.dart';
import 'package:forja_foundation/components/skeleton.dart';
import 'package:forja_foundation/components/slider.dart';
import 'package:forja_foundation/components/spinner.dart';
import 'package:forja_foundation/components/switch.dart';
import 'package:forja_foundation/components/textarea.dart';
import 'package:forja_foundation/components/toggle.dart';
import 'package:forja_foundation/components/tooltip.dart';
import 'package:forja_foundation/components/typography.dart';
import 'package:forja_foundation/components/vertical_menu.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/event_card_tokens.dart';
import 'package:forja_foundation/tokens/epg_guide_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/catalog_channel_card.dart';
import 'package:forja_foundation/widgets/catalog/catalog_epg_guide.dart';
import 'package:forja_foundation/widgets/catalog/catalog_search_filters.dart';
import 'package:forja_foundation/widgets/catalog/catalog_search_result_card.dart';
import 'package:forja_foundation/widgets/catalog/catalog_search_screen.dart';
import 'package:forja_foundation/widgets/catalog/category_circle_meta.dart';
import 'package:forja_foundation/widgets/catalog/continue_watching_card.dart';
import 'package:forja_foundation/widgets/catalog/event_dense_tile.dart';
import 'package:forja_foundation/widgets/catalog/home_loading_skeleton.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:forja_foundation/widgets/catalog/ken_burns_backdrop.dart';
import 'package:forja_foundation/widgets/catalog/poster_rail.dart';
import 'package:forja_foundation/widgets/catalog/recent_search_helper_tile.dart';
import 'package:forja_foundation/widgets/catalog/rotating_hero_backdrop.dart';
import 'package:forja_foundation/widgets/catalog/server_grid.dart';
import 'package:forja_foundation/widgets/catalog/shell_mood_circle.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/chrome/action_chip.dart';
import 'package:forja_foundation/widgets/chrome/catalog_category_rail.dart';
import 'package:forja_foundation/widgets/chrome/catalog_dense_list.dart';
import 'package:forja_foundation/widgets/chrome/catalog_filter_sheet.dart';
import 'package:forja_foundation/widgets/chrome/catalog_list.dart';
import 'package:forja_foundation/widgets/chrome/catalog_poster_grid.dart';
import 'package:forja_foundation/widgets/chrome/filter_sheet_option.dart';
import 'package:forja_foundation/widgets/chrome/horizontal_scroller.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_row.dart';
import 'package:forja_foundation/widgets/chrome/portals_chip.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja_foundation/widgets/chrome/shell_section_title.dart';
import 'package:forja_foundation/widgets/chrome/shell_tab_header.dart';
import 'package:forja_foundation/widgets/chrome/side_panel_overlay.dart';
import 'package:forja_foundation/widgets/chrome/top_bar_actions.dart';
import 'package:forja_foundation/widgets/chrome/view_button_group.dart';
import 'package:forja_foundation/widgets/chrome/widget_shelf.dart';
import 'package:forja_foundation/widgets/details/cast_section.dart';
import 'package:forja_foundation/widgets/details/details_body.dart';
import 'package:forja_foundation/widgets/details/details_hero.dart';
import 'package:forja_foundation/widgets/details/details_rails.dart';
import 'package:forja_foundation/widgets/details/details_scroll_page.dart';
import 'package:forja_foundation/widgets/details/episode_range_bar.dart';
import 'package:forja_foundation/widgets/details/facts_panel.dart';
import 'package:forja_foundation/widgets/details/hero_content_scrim.dart';
import 'package:forja_foundation/widgets/details/hero_overview_text.dart';
import 'package:forja_foundation/widgets/details/hero_pill_surfaces.dart';
import 'package:forja_foundation/widgets/details/hero_title.dart';
import 'package:forja_foundation/widgets/details/list_status_hero.dart';
import 'package:forja_foundation/widgets/details/list_status_pin.dart';
import 'package:forja_foundation/widgets/details/meta_line.dart';
import 'package:forja_foundation/widgets/details/play_row.dart';
import 'package:forja_foundation/widgets/details/trailers_section.dart';
import 'package:forja_foundation/widgets/details/tv_season_episode_picker.dart';
import 'package:forja_foundation/widgets/details/watch_progress_bar.dart';
import 'package:forja_foundation/widgets/details/watch_providers_row.dart';
import 'package:forja_foundation/widgets/details/watch_series_progress.dart';
import 'package:forja_foundation/widgets/feedback/card_play_overlay.dart';
import 'package:forja_foundation/widgets/feedback/catalog_loading_ticker.dart';
import 'package:forja_foundation/widgets/feedback/error_retry_panel.dart';
import 'package:forja_foundation/widgets/feedback/fractal_glass_gradient.dart';
import 'package:forja_foundation/widgets/feedback/frosted_panel.dart';
import 'package:forja_foundation/widgets/feedback/loading_dots.dart';
import 'package:forja_foundation/widgets/guide/channel_guide.dart';
import 'package:forja_foundation/widgets/guide/channel_guide_panel.dart';
import 'package:forja_foundation/widgets/guide/channel_search_overlay.dart';
import 'package:forja_foundation/widgets/guide/guide_browse_text_field.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';
import 'package:forja_foundation/widgets/guide/guide_epg_card.dart';
import 'package:forja_foundation/widgets/guide/guide_epg_programme.dart';
import 'package:forja_foundation/widgets/guide/player_stats_panel.dart';
import 'package:forja_foundation/widgets/sources/live_tv_browse.dart';
import 'package:forja_foundation/widgets/sources/panel_tabs.dart';
import 'package:forja_foundation/widgets/sources/sources_panel_chrome.dart';

/// Mount pack JSON `type` + `props` → forja_foundation widgets.
///
/// Returns null for unknown / shell-forbidden types (`toast`, `focusableTap`).
Widget? paintFoundationType(
  BuildContext context, {
  required String type,
  required Map<String, dynamic> props,
  List<Widget> children = const [],
}) {
  final t = type.trim();
  if (t.isEmpty || t == 'toast' || t == 'focusableTap') return null;

  Widget childOrEmpty() =>
      children.isEmpty ? const SizedBox.shrink() : children.first;
  List<Widget> kids() => children;

  switch (t) {
    // ── Atoms ──────────────────────────────────────────────────────────
    case 'button':
      return Button(
        label: propsString(props, 'label'),
        loading: propsBool(props, 'loading'),
        expand: propsBool(props, 'expand'),
        compact: propsBool(props, 'compact'),
        height: propsLength(context, props, 'height'),
        fontSize: propsLength(context, props, 'fontSize'),
        color: propsColor(props, 'color'),
        hoverColor: propsColor(props, 'hoverColor'),
        variant: _buttonVariant(propsString(props, 'variant')),
        size: _buttonSize(propsString(props, 'size')),
        onPressed: null,
        child: children.isEmpty ? null : children.first,
      );
    case 'buttonGroup':
      return ButtonGroup(
        orientation: _axis(propsString(props, 'orientation')),
        spacing: propsLength(context, props, 'spacing'),
        children: kids().isEmpty ? const [SizedBox.shrink()] : kids(),
      );
    case 'verticalMenu':
      return VerticalMenu(
        width: propsLengthOr(context, props, 'width', catalogSideRailWidth(context)),
        backgroundColor: propsColor(props, 'backgroundColor'),
        minHeight: propsLengthOr(context, props, 'minHeight', 40),
        fontSize: propsLengthOr(context, props, 'fontSize', 14),
        leadingSize: propsLengthOr(context, props, 'leadingSize', 28),
        children: kids().isEmpty
            ? [
                VerticalMenu.item(
                  label: propsStringOr(props, 'label', 'Item'),
                  onTap: null,
                  selected: propsBool(props, 'selected'),
                ),
              ]
            : kids(),
      );
    case 'switch':
    case 'forjaSwitch':
      return Switch(
        value: propsBool(props, 'value'),
        onChanged: (_) {},
        scale: propsNumOr(props, 'scale', 1),
        emphasized: propsBool(props, 'emphasized'),
      );
    case 'slider':
      return Slider(
        value: propsNumOr(props, 'value', 0),
        onChanged: (_) {},
        min: propsNumOr(props, 'min', 0),
        max: propsNumOr(props, 'max', 1),
        label: propsString(props, 'label'),
      );
    case 'input':
      return Input(
        hintText: propsString(props, 'hintText'),
        enabled: propsBool(props, 'enabled', true),
        obscureText: propsBool(props, 'obscureText'),
        onChanged: (_) {},
      );
    case 'field':
      return Field(
        label: propsString(props, 'label'),
        error: propsString(props, 'error'),
        isRequired: propsBool(props, 'isRequired'),
        child: childOrEmpty(),
      );
    case 'textarea':
      return Textarea(
        hintText: propsString(props, 'hintText'),
        enabled: propsBool(props, 'enabled', true),
        minLines: propsInt(props, 'minLines') ?? 3,
        maxLines: propsInt(props, 'maxLines') ?? 6,
        onChanged: (_) {},
      );
    case 'inputGroup':
      return InputGroup(child: childOrEmpty());
    case 'searchField':
      return SearchField(
        hintText: propsStringOr(props, 'hintText', 'Search'),
        enabled: propsBool(props, 'enabled', true),
        onChanged: (_) {},
        onClear: () {},
      );
    case 'select':
      final options = _stringOptions(props);
      final value = propsString(props, 'value') ??
          (options.isEmpty ? null : options.first.value);
      return Select<String>(
        value: value,
        options: options.isEmpty
            ? const [SelectOption(value: '', label: '—')]
            : options,
        onChanged: (_) {},
        hintText: propsString(props, 'hintText'),
        enabled: propsBool(props, 'enabled', true),
      );
    case 'checkbox':
      return Checkbox(
        value: propsBool(props, 'value'),
        onChanged: (_) {},
        label: propsString(props, 'label'),
      );
    case 'radio':
      final v = propsStringOr(props, 'value', 'a');
      return Radio<String>(
        value: v,
        groupValue: propsStringOr(props, 'groupValue', v),
        onChanged: (_) {},
        label: propsString(props, 'label'),
      );
    case 'toggle':
      return Toggle(
        pressed: propsBool(props, 'pressed'),
        onPressed: () {},
        label: propsString(props, 'label'),
        child: children.isEmpty ? null : children.first,
      );
    case 'segmentedControl':
      final options = _segmentedOptions(props);
      final value = propsString(props, 'value') ??
          (options.isEmpty ? '' : options.first.value);
      return SegmentedControl<String>(
        value: value,
        options: options.isEmpty
            ? const [SegmentedOption(value: '', label: '—')]
            : options,
        onChanged: (_) {},
      );
    case 'badge':
      return Badge(
        label: propsString(props, 'label'),
        variant: _badgeVariant(propsString(props, 'variant')),
        size: _badgeSize(propsString(props, 'size')),
        child: children.isEmpty ? null : children.first,
      );
    case 'label':
      return Label(
        text: propsStringOr(props, 'text', propsStringOr(props, 'label', '')),
        isRequired: propsBool(props, 'isRequired'),
      );
    case 'alert':
      return Alert(
        title: propsString(props, 'title'),
        description: propsString(props, 'description'),
        variant: _alertVariant(propsString(props, 'variant')),
        child: children.isEmpty ? null : children.first,
      );
    case 'forjaDialog':
      return ForjaDialog(
        title: propsStringOr(props, 'title', ''),
        description: propsString(props, 'description'),
        body: children.isEmpty ? null : children.first,
      );
    case 'sheet':
      // No Sheet widget — presentational chrome only.
      return Material(
        color: ForjaShellColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(propsLengthOr(context, props, 'padding', 16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: ForjaShellColors.borderSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              if (propsString(props, 'title') != null)
                Text(
                  propsString(props, 'title')!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ...kids(),
            ],
          ),
        ),
      );
    case 'emptyAtom':
      return Empty(
        title: propsString(props, 'title'),
        description: propsString(props, 'description'),
        size: _emptySize(propsString(props, 'size')),
      );
    case 'separator':
      return Separator(
        orientation: _axis(propsString(props, 'orientation')),
        thickness: propsLengthOr(context, props, 'thickness', 1),
        color: propsColor(props, 'color'),
        indent: propsLengthOr(context, props, 'indent', 0),
        endIndent: propsLengthOr(context, props, 'endIndent', 0),
      );
    case 'avatar':
      return Avatar(
        imageUrl: propsString(props, 'imageUrl'),
        initials: propsString(props, 'initials'),
        backgroundColor: propsColor(props, 'backgroundColor'),
        size: _avatarSize(propsString(props, 'size')),
      );
    case 'skeleton':
      return Skeleton(
        width: propsLength(context, props, 'width'),
        height: propsLengthOr(context, props, 'height', 16),
      );
    case 'progress':
      return Progress(
        value: propsNum(props, 'value'),
        size: propsLengthOr(context, props, 'size', 24),
        strokeWidth: propsLengthOr(context, props, 'strokeWidth', 2.5),
        color: propsColor(props, 'color'),
        variant: _progressVariant(propsString(props, 'variant')),
      );
    case 'spinner':
      return Spinner(color: propsColor(props, 'color'));
    case 'tooltip':
      return Tooltip(
        message: propsStringOr(props, 'message', ''),
        child: childOrEmpty(),
      );
    case 'accordion':
      return Accordion(
        title: propsStringOr(props, 'title', ''),
        initiallyExpanded: propsBool(props, 'initiallyExpanded'),
        child: childOrEmpty(),
      );
    case 'breadcrumb':
      final labels = propsStringList(props, 'items');
      return Breadcrumb(
        items: labels.isEmpty
            ? [BreadcrumbItem(label: propsStringOr(props, 'label', 'Home'))]
            : [for (final l in labels) BreadcrumbItem(label: l)],
      );
    case 'pageDots':
      return PageDots(
        count: propsInt(props, 'count') ?? 3,
        index: propsInt(props, 'index') ?? 0,
        size: propsLengthOr(context, props, 'size', 8),
        spacing: propsLength(context, props, 'spacing'),
        onChanged: (_) {},
      );
    case 'listTile':
      return ListTile(
        title: propsString(props, 'title') == null
            ? null
            : Text(propsString(props, 'title')!),
        subtitle: propsString(props, 'subtitle') == null
            ? null
            : Text(propsString(props, 'subtitle')!),
        selected: propsBool(props, 'selected'),
        onTap: () {},
      );
    case 'item':
      return Item(
        title: propsStringOr(props, 'title', ''),
        subtitle: propsString(props, 'subtitle'),
        selected: propsBool(props, 'selected'),
        onTap: () {},
      );
    case 'kbd':
      final keys = propsStringList(props, 'keys');
      return Kbd(keys: keys.isEmpty ? const ['⌘', 'K'] : keys);
    case 'heading':
      return Heading(
        propsStringOr(props, 'text', ''),
        level: _headingLevel(propsString(props, 'level')),
        color: propsColor(props, 'color'),
        maxLines: propsInt(props, 'maxLines'),
      );
    case 'body':
      return Body(
        propsStringOr(props, 'text', ''),
        size: propsLengthOr(context, props, 'size', 14),
        tone: _bodyTone(propsString(props, 'tone')),
        maxLines: propsInt(props, 'maxLines'),
      );
    case 'posterFrame':
      return PosterFrame(
        width: propsLength(context, props, 'width'),
        aspectRatio: propsNumOr(props, 'aspectRatio', 2 / 3),
        child: childOrEmpty(),
      );
    case 'networkImage':
      return ForjaNetworkImage(
        url: propsStringOr(props, 'url', propsStringOr(props, 'imageUrl', '')),
        width: propsLength(context, props, 'width'),
        height: propsLength(context, props, 'height'),
      );
    case 'settledNetworkImage':
      return SettledNetworkImage(
        imageUrl:
            propsStringOr(props, 'imageUrl', propsStringOr(props, 'url', '')),
      );
    case 'moodCircle':
      final tv = ShellPaintScope.usesTvDensityOf(context);
      return MoodCircle(
        label: propsStringOr(props, 'label', ''),
        imageUrl: propsString(props, 'imageUrl'),
        selected: propsBool(props, 'selected'),
        active: propsBool(props, 'active'),
        size: propsLengthOr(
          context,
          props,
          'size',
          tv ? ShellTokens.moodCircleSizeTv : 72,
        ),
        layout: tv ? MoodCircleLayout.tvScrollable : MoodCircleLayout.desktop,
        accent: propsColor(props, 'accent'),
        onTap: () {},
      );

    // ── Catalog ────────────────────────────────────────────────────────
    case 'posterRail':
      final items = _posterItems(props);
      return PosterRail(
        items: items.isEmpty && children.isEmpty ? const [] : items,
        itemWidth: propsLengthOr(context, props, 'itemWidth', 120),
        itemHeight: propsLengthOr(context, props, 'itemHeight', 180),
        height: propsLength(context, props, 'height'),
        gap: propsLength(context, props, 'gap'),
        children: items.isEmpty && children.isNotEmpty ? kids() : null,
      );
    case 'kenBurnsBackdrop':
      return SizedBox(
        height: propsLengthOr(context, props, 'height', 240),
        width: double.infinity,
        child: KenBurnsBackdrop(
          imageUrl: propsStringOr(props, 'imageUrl', propsStringOr(props, 'url', '')),
          blurSigma: propsNumOr(props, 'blurSigma', 28),
          minScale: propsNumOr(props, 'minScale', 1),
          maxScale: propsNumOr(props, 'maxScale', 1.25),
          showColorTint: propsBool(props, 'showColorTint', true),
          enableMotion: propsBool(props, 'enableMotion', true),
          tintDominant: propsColor(props, 'tintDominant'),
          tintMuted: propsColor(props, 'tintMuted'),
        ),
      );
    case 'rotatingHeroBackdrop':
      final urls = propsStringList(props, 'imageUrls');
      return SizedBox(
        height: propsLengthOr(context, props, 'height', 240),
        width: double.infinity,
        child: RotatingHeroBackdrop(
          imageUrls: urls.isEmpty
              ? [propsStringOr(props, 'imageUrl', '')]
              : urls,
          showColorTint: propsBool(props, 'showColorTint'),
          enableMotion: propsBool(props, 'enableMotion', true),
        ),
      );
    case 'homeLoadingSkeleton':
      // No HomeLoadingSkeleton class — functions in home_loading_skeleton.dart.
      return homePosterRowSkeleton(
        titleWidth: propsLengthOr(context, props, 'titleWidth', 140),
        itemCount: propsInt(props, 'itemCount') ?? 5,
        showSubtitle: propsBool(props, 'showSubtitle'),
        cardWidth: propsLengthOr(
          context,
          props,
          'cardWidth',
          InteractivePosterCard.cardWidth(context),
        ),
        cardHeight: propsLengthOr(
          context,
          props,
          'cardHeight',
          InteractivePosterCard.cardHeight(context),
        ),
      );
    case 'categoryCircleMeta':
      // Helper only — paint as MoodCircle using kitMoodCircleMeta.
      final meta = kitMoodCircleMeta(
        id: propsStringOr(props, 'id', ''),
        icon: propsString(props, 'icon'),
      );
      return MoodCircle(
        label: propsStringOr(
          props,
          'label',
          propsStringOr(props, 'id', ''),
        ),
        icon: meta.icon,
        accent: meta.accent,
        selected: propsBool(props, 'selected'),
        size: propsLengthOr(context, props, 'size', 72),
        onTap: () {},
      );
    case 'serverGrid':
      return ForjaServerGrid(
        providers: _idNameList(props, 'providers'),
        activeId: propsString(props, 'activeId'),
        onSelect: (_) {},
        crossAxisCount: propsInt(props, 'crossAxisCount') ?? 5,
      );
    case 'continueCard':
      return ContinueWatchingCard(
        title: propsStringOr(props, 'title', ''),
        coverUrl: propsStringOr(
          props,
          'coverUrl',
          propsStringOr(props, 'imageUrl', ''),
        ),
        width: propsLengthOr(context, props, 'width', ShellTokens.shellContinueWatchingCardWidthDesktop),
        height: propsLengthOr(context, props, 'height', ShellTokens.shellContinueWatchingCardHeightDesktop),
        subtitle: propsStringOr(props, 'subtitle', ''),
        progress: propsNumOr(props, 'progress', 0),
        remainingText: propsStringOr(props, 'remainingText', ''),
        isLoading: propsBool(props, 'isLoading'),
        active: propsBool(props, 'active'),
        showActionButtons: propsBool(props, 'showActionButtons', true),
        onTap: () {},
        onRemove: () {},
        onInfo: () {},
      );
    case 'eventDenseTile':
      return EventDenseTile(
        title: propsStringOr(props, 'title', ''),
        meta: propsStringOr(props, 'meta', ''),
        airing: propsBool(props, 'airing'),
        viewers: propsInt(props, 'viewers') ?? 0,
        selected: propsBool(props, 'selected'),
        playable: propsBool(props, 'playable', true),
        fontSize: propsLengthOr(context, props, 'fontSize', 14),
        metaFontSize: propsLengthOr(context, props, 'metaFontSize', 12),
        iconSize: propsLengthOr(context, props, 'iconSize', ShellTokens.eventSearchIconSize),
        onTap: () {},
      );
    case 'catalogSearchResultCard':
      final title = propsStringOr(props, 'title', '');
      final poster = propsStringOr(
        props,
        'posterUrl',
        propsStringOr(props, 'imageUrl', ''),
      );
      if (propsBool(props, 'compact')) {
        return CatalogSearchResultCard.compact(
          title: title,
          posterUrl: poster,
          subtitle: propsString(props, 'subtitle'),
          rating: propsNum(props, 'rating'),
          compactWidth: propsLength(context, props, 'compactWidth'),
          onTap: () {},
        );
      }
      return SizedBox(
        width: propsLengthOr(context, props, 'width', 160),
        height: propsLengthOr(context, props, 'height', 240),
        child: CatalogSearchResultCard.film(
          title: title,
          posterUrl: poster,
          subtitle: propsString(props, 'subtitle'),
          rating: propsNum(props, 'rating'),
          selected: propsBool(props, 'selected'),
          onTap: () {},
        ),
      );
    case 'recentSearchHelperTile':
      return RecentSearchHelperTile(
        title: propsStringOr(props, 'title', ''),
        selected: propsBool(props, 'selected'),
        onSelect: () {},
        onRemove: () {},
      );

    // ── Details ────────────────────────────────────────────────────────
    case 'detailsHero':
      return DetailsHero(
        backdropUrl: propsStringOr(
          props,
          'backdropUrl',
          propsStringOr(props, 'imageUrl', ''),
        ),
        title: propsStringOr(props, 'title', ''),
        subtitle: propsString(props, 'subtitle'),
        overview: propsStringOr(props, 'overview', ''),
        logoUrl: propsString(props, 'logoUrl'),
        height: propsLength(context, props, 'height'),
        contentScrim: propsBool(props, 'contentScrim'),
        enableKenBurns: propsBool(props, 'enableKenBurns', true),
        genres: propsStringList(props, 'genres'),
        metaParts: propsStringList(props, 'metaParts'),
        rating: propsNum(props, 'rating'),
        actionRow: const SizedBox.shrink(),
      );
    case 'detailsBody':
      return DetailsBody(
        backgroundColor: propsColor(props, 'backgroundColor'),
        bodyOverlap: propsLength(context, props, 'bodyOverlap'),
        topSpacing: propsLength(context, props, 'topSpacing'),
        child: childOrEmpty(),
      );
    case 'detailsScrollPage':
      return DetailsScrollPage(
        hero: children.isNotEmpty
            ? children.first
            : DetailsHero(
                backdropUrl: propsStringOr(props, 'backdropUrl', ''),
                title: propsStringOr(props, 'title', ''),
                actionRow: const SizedBox.shrink(),
              ),
        backgroundColor:
            propsColor(props, 'backgroundColor') ?? ForjaShellColors.bgDark,
        sections: children.length > 1 ? children.sublist(1) : const [],
        bodyOverlap: propsLength(context, props, 'bodyOverlap'),
        topSpacing: propsLength(context, props, 'topSpacing'),
      );
    case 'detailsRails':
      return DetailsRails(
        rowHeight: propsLengthOr(context, props, 'rowHeight', 180),
        sections: [
          DetailsRailSectionData(
            id: propsStringOr(props, 'id', 'rails'),
            title: propsStringOr(props, 'title', ''),
            cards: kids(),
          ),
        ],
      );
    case 'playRow':
      return PlayRow(
        orientation: _axis(propsString(props, 'orientation')),
        spacing: propsLength(context, props, 'spacing'),
        children: kids().isEmpty ? const [SizedBox.shrink()] : kids(),
      );
    case 'factsPanel':
      return FactsPanel(
        rows: _factRows(props),
        valueMaxLines: propsInt(props, 'valueMaxLines') ?? 1,
      );
    case 'metaLine':
      return MetaLine(
        releaseDate: propsStringOr(props, 'releaseDate', ''),
        mediaType: propsStringOr(props, 'mediaType', ''),
        runtimeMinutes: propsInt(props, 'runtimeMinutes') ?? 0,
        voteAverage: propsNumOr(props, 'voteAverage', 0),
        genres: propsStringList(props, 'genres'),
        certification: propsString(props, 'certification'),
        imdbRating: propsNum(props, 'imdbRating'),
        singleLine: propsBool(props, 'singleLine'),
      );
    case 'heroTitle':
      return HeroTitle(
        title: propsStringOr(props, 'title', ''),
        logoUrl: propsString(props, 'logoUrl'),
        compact: propsBool(props, 'compact'),
        desktop: propsBool(props, 'desktop'),
        isLandscape: propsBool(props, 'isLandscape'),
        maxWidth: propsLength(context, props, 'maxWidth'),
        plainTitle: propsBool(props, 'plainTitle'),
      );
    case 'heroOverview':
      return HeroOverviewText(
        overview: propsStringOr(props, 'overview', propsStringOr(props, 'text', '')),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: propsLengthOr(context, props, 'fontSize', 14),
        ),
        maxLines: propsInt(props, 'maxLines') ?? 3,
      );
    case 'heroContentScrim':
      return KitHeroContentScrim(
        tintAlpha: propsNumOr(props, 'tintAlpha', 0.66),
        blurSigma: propsNumOr(props, 'blurSigma', 24),
      );
    case 'heroWatchProviders':
      return HeroWatchProvidersRow(
        providers: _watchProviders(props),
        maxVisible: propsInt(props, 'maxVisible') ?? 8,
        visible: propsBool(props, 'visible', true),
      );
    case 'heroPillPlay':
      final tone = _pillTone(propsString(props, 'tone'));
      return HeroPillPlaySurface(
        style: HeroPillStyle.forTone(tone),
        active: propsBool(props, 'active', true),
        pressed: propsBool(props, 'pressed'),
        expanded: propsBool(props, 'expanded', true),
        label: propsStringOr(props, 'label', 'Play'),
        leading: const Icon(Icons.play_arrow_rounded, color: Colors.white),
      );
    case 'listStatusPin':
      return ListStatusPin(
        currentStatus: propsString(props, 'currentStatus'),
        onSelect: (_) async {},
        busy: propsBool(props, 'busy'),
        iconSize: propsLength(context, props, 'iconSize'),
        iconColor: propsColor(props, 'iconColor'),
      );
    case 'listStatusHero':
      return ListStatusHero(
        currentStatus: propsString(props, 'currentStatus'),
        onSetStatus: (_) async => true,
        triggerBuilder: (context, {required status, required onTap, required menuOpen}) =>
            SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.bookmark_outline, color: Colors.white),
          ),
        ),
      );
    case 'detailsCast':
      return DetailsCastSection(
        cast: _castMaps(props),
        title: propsStringOr(props, 'title', 'Cast'),
        outdentHorizontal: propsLengthOr(context, props, 'outdentHorizontal', 0),
      );
    case 'detailsTrailers':
      return DetailsTrailersSection(
        trailers: _trailers(props),
        onTap: (_) {},
        title: propsStringOr(props, 'title', 'Trailers'),
        outdentHorizontal: propsLengthOr(context, props, 'outdentHorizontal', 0),
      );
    case 'detailsRecommendations':
      // No dedicated Recommendations widget — DetailsRails / section.
      return DetailsRailSection(
        title: propsStringOr(props, 'title', 'Recommendations'),
        rowHeight: propsLengthOr(context, props, 'rowHeight', 180),
        cards: kids().isEmpty
            ? [SizedBox(width: propsLengthOr(context, props, 'cardWidth', 120), height: 1)]
            : kids(),
      );
    case 'watchProgressBar':
      return WatchProgressBar(
        positionMs: propsInt(props, 'positionMs') ?? 0,
        durationMs: propsInt(props, 'durationMs') ?? 1,
        accentColor: propsColor(props, 'accentColor'),
        compact: propsBool(props, 'compact'),
      );
    case 'watchSeriesProgress':
      return WatchSeriesProgress(
        watched: propsInt(props, 'watched') ?? 0,
        total: propsInt(props, 'total') ?? 0,
        compact: propsBool(props, 'compact'),
      );

    // ── Chrome ─────────────────────────────────────────────────────────
    case 'shellSectionTitle': {
      final tv = catalogUsesTvDensity(context);
      return ShellSectionTitle(
        title: propsStringOr(props, 'title', ''),
        subtitle: propsString(props, 'subtitle'),
        fontSize: propsNumOr(
          props,
          'fontSize',
          tv ? ShellTokens.tvTitleFontSize : ShellTokens.sectionTitleFontSize,
        ),
        subtitleFontSize: propsNumOr(
          props,
          'subtitleFontSize',
          tv ? ShellTokens.tvMetaFontSize : ShellTokens.sectionSubtitleFontSize,
        ),
        trailing: children.isEmpty ? null : kids(),
      );
    }
    case 'shellTabHeader':
      return ShellTabHeader(
        title: propsStringOr(props, 'title', ''),
        actions: children.isEmpty ? null : kids(),
      );
    case 'horizontalScroller':
      final count = kids().isEmpty ? 0 : kids().length;
      return HorizontalScroller(
        height: propsLengthOr(context, props, 'height', 180),
        itemCount: count,
        itemBuilder: (_, i) => kids()[i],
        arrowOffset: propsLengthOr(context, props, 'arrowOffset', ShellTokens.scrollerArrowOffset),
      );
    case 'shellChip': {
      final padN = propsLength(context, props, 'pad') ?? propsLength(context, props, 'padding');
      final tv = catalogUsesTvDensity(context);
      return ForjaShellChip(
        label: propsStringOr(props, 'label', ''),
        selected: propsBool(props, 'selected'),
        onTap: () {},
        loading: propsBool(props, 'loading'),
        accentHover: propsBool(props, 'accentHover'),
        fontSize: propsNumOr(
          props,
          'fontSize',
          tv ? ShellTokens.shellChipFontSizeTv : ShellTokens.shellChipFontSize,
        ),
        radius: propsLengthOr(context, props, 'radius', ShellTokens.shellChipRadiusPill),
        iconSize: propsLengthOr(context, props, 'iconSize', ShellTokens.shellChipIconSize),
        padding: padN != null
            ? EdgeInsets.symmetric(horizontal: padN, vertical: padN * 0.57)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      );
    }
    case 'sidePanelOverlay':
      return SidePanelOverlay(
        open: propsBool(props, 'open', true),
        panel: children.length > 1
            ? children[1]
            : SizedBox(
                width: propsLengthOr(context, props, 'panelWidth', ShellTokens.sidePanelWidth),
                child: const ColoredBox(color: Colors.black54),
              ),
        onDismiss: () {},
        panelWidth: propsLengthOr(context, props, 'panelWidth', ShellTokens.sidePanelWidth),
        scrimColor: propsColor(props, 'scrimColor'),
        child: children.isNotEmpty ? children.first : const SizedBox.expand(),
      );
    case 'portalList':
    case 'portalListPanel':
      final panelPad = propsLength(context, props, 'pad');
      return PortalListPanel(
        width: propsLengthOr(context, props, 'width', ShellTokens.sidePanelWidth),
        pad: panelPad != null ? EdgeInsets.all(panelPad) : null,
        statusFontSize: propsLengthOr(context, props, 'statusFontSize', 11),
        header: Text(
          propsStringOr(props, 'header', propsStringOr(props, 'title', 'Portals')),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        body: children.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    propsStringOr(
                      props,
                      'emptyTitle',
                      propsStringOr(props, 'emptyDescription', ''),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              )
            : children.first,
        searchOpen: propsBool(props, 'searchOpen'),
        statusText: propsStringOr(props, 'statusText', ''),
        surfaceColor: propsColor(props, 'surfaceColor'),
      );
    case 'portalsChip':
      final chipW = propsLength(context, props, 'width');
      return PortalsChip(
        label: propsStringOr(props, 'label', 'Portals'),
        onTap: () {},
        selected: propsBool(props, 'selected'),
        hasPortal: propsBool(props, 'hasPortal'),
        checking: propsBool(props, 'checking'),
        healthy: props['healthy'] is bool ? props['healthy'] as bool : null,
        seatsUsed: propsString(props, 'seatsUsed'),
        seatsMax: propsString(props, 'seatsMax'),
        compact: propsBool(props, 'compact'),
        width: chipW != null && chipW > 0 ? chipW : null,
        height: propsLengthOr(context, props, 'height', ShellTokens.portalsChipHeight),
        radius: propsLengthOr(context, props, 'radius', ShellTokens.portalsChipRadius),
        pad: propsLength(context, props, 'pad'),
        fontSize: propsLengthOr(context, props, 'fontSize', ShellTokens.portalsChipFontSize),
        iconSize: propsLengthOr(context, props, 'iconSize', ShellTokens.portalsChipIconSize),
        chevronSize:
            propsLengthOr(context, props, 'chevronSize', ShellTokens.portalsChipChevronSize),
        seatsFontSize: propsNumOr(
          props,
          'seatsFontSize',
          ShellTokens.portalsChipSeatsFontSize,
        ),
        accentColor: propsColor(props, 'accentColor'),
      );
    case 'catalogPosterGrid':
      final layout = CatalogPosterGridLayout(
        columns: propsInt(props, 'columns') ?? 4,
        cardW: propsLengthOr(context, props, 'cardW', propsLengthOr(context, props, 'cardWidth', catalogUsesTvDensity(context) ? ShellTokens.posterCardWidthTv : 120)),
        cardH: propsLengthOr(context, props, 'cardH', propsLengthOr(context, props, 'cardHeight', catalogUsesTvDensity(context) ? ShellTokens.posterCardWidthTv * ShellTokens.posterCardAspectRatio : 180)),
        gap: propsLengthOr(context, props, 'gap', 12),
        leading: propsLengthOr(context, props, 'leading', ShellTokens.homeSectionHorizontalPadding),
        rightPad: propsLengthOr(context, props, 'rightPad', ShellTokens.homeSectionHorizontalPadding),
        topPad: propsLengthOr(context, props, 'topPad', 8),
      );
      final n = kids().isEmpty ? (propsInt(props, 'itemCount') ?? 0) : kids().length;
      return SizedBox(
        height: propsLengthOr(context, props, 'height', 400),
        child: CatalogPosterGrid(
          layout: layout,
          itemCount: n,
          itemBuilder: (_, i) =>
              kids().isEmpty ? const SizedBox.shrink() : kids()[i % kids().length],
        ),
      );
    case 'catalogDenseList':
      final n = kids().isEmpty ? (propsInt(props, 'itemCount') ?? 0) : kids().length;
      return SizedBox(
        height: propsLengthOr(context, props, 'height', 320),
        child: CatalogDenseList(
          itemCount: n,
          itemBuilder: (_, i) =>
              kids().isEmpty ? const SizedBox(height: 48) : kids()[i % kids().length],
          topPadding: propsLengthOr(context, props, 'topPadding', 4),
          bottomPadding: propsLengthOr(context, props, 'bottomPadding', 0),
          separatorColor: propsColor(props, 'separatorColor'),
        ),
      );
    case 'catalogList':
      return SizedBox(
        height: propsLengthOr(context, props, 'height', 400),
        child: CatalogList(
          body: children.isNotEmpty ? children.first : const SizedBox.shrink(),
          header: children.length > 1 ? children[1] : null,
          sidePanelOpen: propsBool(props, 'sidePanelOpen'),
          panelWidth: propsLengthOr(context, props, 'panelWidth', ShellTokens.sidePanelWidth),
          sideSplit: propsBool(props, 'sideSplit'),
          onDismissSidePanel: () {},
        ),
      );

    // ── Sources / guide / feedback ─────────────────────────────────────
    case 'sourcesPanel':
      final tabs = _sourcesTabs(props);
      return SizedBox(
        width: propsLengthOr(context, props, 'width', ShellTokens.sidePanelWidth),
        height: propsLengthOr(context, props, 'height', 480),
        child: SourcesPanelChrome(
          title: propsStringOr(props, 'title', 'Sources'),
          subtitle: propsString(props, 'subtitle'),
          tabs: tabs.isEmpty
              ? const [SourcesTab(id: 'all', label: 'All')]
              : tabs,
          embedded: propsBool(props, 'embedded'),
          showTabs: propsBool(props, 'showTabs', true),
          loadTab: (tabId, {onPartial, force = false}) async => const [],
          onPlayRow: (_) async {},
        ),
      );
    case 'panelTabs':
      // Spec helpers only — paint as chip strip.
      final tabs = panelTabsFromSpec(props);
      if (tabs.isEmpty) {
        final labels = propsStringList(props, 'tabs');
        return Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              ForjaShellChip(label: labels[i], onTap: () {}),
            ],
          ],
        );
      }
      final selected = propsString(props, 'selectedId') ?? tabs.first.id;
      return Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            ForjaShellChip(
              label: tabs[i].label,
              selected: tabs[i].id == selected,
              onTap: () {},
            ),
          ],
        ],
      );
    case 'frostedPanel':
      return ForjaFrostedPanel(
        enableBlur: propsBool(props, 'enableBlur', true),
        blurSigma: propsNumOr(props, 'blurSigma', ForjaFrostedPanel.defaultBlurSigma),
        elevation: propsNumOr(props, 'elevation', 0),
        child: childOrEmpty(),
      );
    case 'loadingDots':
      return ForjaLoadingDots(
        color: propsColor(props, 'color') ?? Colors.white70,
        fontSize: propsLengthOr(context, props, 'fontSize', 13),
      );
    case 'errorRetryPanel':
      return ShellErrorRetryPanel(
        message: propsStringOr(props, 'message', 'Something went wrong'),
        onRetry: () {},
        label: propsStringOr(props, 'label', 'Retry'),
      );
    case 'cardPlayOverlay':
      return ShellCardPlayOverlay(
        active: propsBool(props, 'active'),
        visible: propsBool(props, 'visible', true),
        diameter: propsLengthOr(context, props, 'diameter', EventCardTokens.playOverlaySize),
        iconSize: propsLengthOr(context, props, 'iconSize', EventCardTokens.playIconSize),
        onTap: () {},
      );
    case 'fractalGlassGradient':
      return SizedBox(
        width: propsLengthOr(context, props, 'width', 200),
        height: propsLengthOr(context, props, 'height', 120),
        child: const FractalGlassGradient(),
      );
    case 'guideEpgCard':
      return GuideEpgCard(
        future: Future<List<GuideEpgProgramme>>.value(const []),
        compact: propsBool(props, 'compact'),
        floating: propsBool(props, 'floating'),
      );
    case 'channelGuidePanel':
      final gid = propsStringOr(props, 'selectedGroupId', 'g');
      final cid = propsStringOr(props, 'currentChannelId', 'c');
      return SizedBox(
        width: propsLengthOr(context, props, 'width', ChannelGuidePanel.panelWidthWide),
        height: propsLengthOr(context, props, 'height', 420),
        child: ChannelGuidePanel(
          guide: ChannelGuide(
            groups: [GuideGroup(id: gid, name: propsStringOr(props, 'groupName', 'All'))],
            channels: [
              GuideChannel(
                id: cid,
                name: propsStringOr(props, 'channelName', 'Channel'),
                groupId: gid,
              ),
            ],
            initialChannelId: cid,
            initialGroupId: gid,
          ),
          selectedGroupId: gid,
          currentChannelId: cid,
          onGroupSelected: (_) {},
          onChannelSelected: (_) {},
          onClose: () {},
          epgEnabled: propsBool(props, 'epgEnabled', true),
          isTv: propsBool(props, 'isTv'),
          isDesktop: propsBool(props, 'isDesktop'),
        ),
      );

    case 'catalogSearchScreen':
      return CatalogSearchScreen(
        onSearch: (_) async => const [],
        onOpen: (_) {},
        hintText: propsStringOr(
          props,
          'hintText',
          propsStringOr(props, 'hint', 'Search…'),
        ),
        structuredSearch: propsBool(props, 'structuredSearch'),
      );
    case 'catalogSearchFilters':
      return CatalogSearchFilters(
        filters: SearchFilters.empty,
        onChanged: (_) {},
      );
    case 'catalogSearchFilterLens':
      return CatalogSearchFilterLens(
        open: propsBool(props, 'open', true),
        filters: SearchFilters.empty,
        onFiltersChanged: (_) {},
        onSubmit: () {},
        allLabel: propsStringOr(props, 'allLabel', 'All'),
        movieLabel: propsStringOr(props, 'movieLabel', 'Films'),
        seriesLabel: propsStringOr(props, 'seriesLabel', 'Series'),
        tvLeanback: propsBool(props, 'tvLeanback') || propsBool(props, 'compact'),
      );
    case 'tvSeasonEpisodePicker':
      return TvSeasonEpisodePicker(
        tmdbId: propsInt(props, 'tmdbId') ?? 0,
        seasonCount: propsInt(props, 'seasonCount') ?? 1,
        selectedSeason: propsInt(props, 'selectedSeason') ?? 1,
        selectedEpisode: propsInt(props, 'selectedEpisode') ?? 1,
        isLoadingSeason: propsBool(props, 'isLoadingSeason'),
        seasonData: const {
          'episodes': [
            {'episode_number': 1, 'name': 'Episode 1'},
          ],
        },
        watchedEpisodes: const {},
        fallbackPosterPath: propsStringOr(props, 'fallbackPosterPath', ''),
        onSeasonSelected: (_) {},
        onEpisodeSelected: (_) {},
        onToggleWatched: (_, _) {},
      );
    case 'episodeRangeSelector':
      final ranges = _episodeRanges(props);
      return EpisodeRangeSelector(
        ranges: ranges.isEmpty
            ? const [EpisodeRange(index: 0, labelStart: 1, labelEnd: 50)]
            : ranges,
        selectedIndex: propsInt(props, 'selectedIndex') ?? 0,
        onSelected: (_) {},
        useFocusableChips: propsBool(props, 'useFocusableChips'),
      );
    case 'liveTvBrowse':
      return SourcesExpandingSearch(
        query: propsStringOr(props, 'query', ''),
        onQueryChanged: (_) {},
        useTvBrowse: propsBool(props, 'useTvBrowse') || propsBool(props, 'compact'),
      );
    case 'channelGuide':
      // ChannelGuide is a data model — paint via ChannelGuidePanel.
      final gid = propsStringOr(props, 'selectedGroupId', 'g');
      final cid = propsStringOr(props, 'currentChannelId', 'c');
      return SizedBox(
        width: propsLengthOr(context, props, 'width', ChannelGuidePanel.panelWidthWide),
        height: propsLengthOr(context, props, 'height', 420),
        child: ChannelGuidePanel(
          guide: ChannelGuide(
            groups: [
              GuideGroup(id: gid, name: propsStringOr(props, 'groupName', 'All')),
            ],
            channels: [
              GuideChannel(
                id: cid,
                name: propsStringOr(props, 'channelName', 'Channel'),
                groupId: gid,
              ),
            ],
            initialChannelId: cid,
            initialGroupId: gid,
          ),
          selectedGroupId: gid,
          currentChannelId: cid,
          onGroupSelected: (_) {},
          onChannelSelected: (_) {},
          onClose: () {},
          epgEnabled: propsBool(props, 'epgEnabled', true),
          isTv: propsBool(props, 'isTv') || propsBool(props, 'compact'),
          isDesktop: propsBool(props, 'isDesktop'),
        ),
      );
    case 'channelSearchOverlay':
      final gid = propsStringOr(props, 'selectedGroupId', 'g');
      final cid = propsStringOr(props, 'currentChannelId', 'c');
      return SizedBox(
        width: propsLengthOr(context, props, 'width', ChannelSearchOverlay.panelWidth),
        height: propsLengthOr(context, props, 'height', 320),
        child: ChannelSearchOverlay(
          guide: ChannelGuide(
            groups: [
              GuideGroup(id: gid, name: propsStringOr(props, 'groupName', 'All')),
            ],
            channels: [
              GuideChannel(
                id: cid,
                name: propsStringOr(props, 'channelName', 'Channel'),
                groupId: gid,
              ),
            ],
            initialChannelId: cid,
            initialGroupId: gid,
          ),
          currentChannelId: cid,
          onChannelSelected: (_) {},
          onClose: () {},
          isTv: propsBool(props, 'isTv') || propsBool(props, 'compact'),
        ),
      );
    case 'playerStatsPanel':
      return SizedBox(
        width: propsLengthOr(context, props, 'width', 320),
        height: propsLengthOr(context, props, 'height', 200),
        child: PlayerStatsList(rows: _playerStatsRows(props)),
      );
    case 'guideBrowseTextField':
      return _PaintGuideBrowseTextField(
        hint: propsStringOr(props, 'hint', propsStringOr(props, 'hintText', 'Search…')),
        tvBrowse: propsBool(props, 'tvBrowse') || propsBool(props, 'compact'),
        autofocus: propsBool(props, 'autofocus'),
      );
    case 'portalListRow':
      return PortalListRow(
        item: PortalListItem(
          id: propsStringOr(props, 'id', 'p'),
          label: propsStringOr(
            props,
            'label',
            propsStringOr(props, 'title', 'Portal'),
          ),
          subtitle: propsString(props, 'subtitle'),
          selected: propsBool(props, 'selected'),
          healthy: props['healthy'] is bool ? props['healthy'] as bool : null,
          checking: propsBool(props, 'checking'),
          platformLabel: propsString(props, 'platformLabel'),
          expiry: propsString(props, 'expiry'),
          activeConnections: propsString(props, 'activeConnections'),
          maxConnections: propsString(props, 'maxConnections'),
          favorite: propsBool(props, 'favorite'),
          isNew: propsBool(props, 'isNew'),
          deleting: propsBool(props, 'deleting'),
        ),
        leanback: propsBool(props, 'leanback') || propsBool(props, 'compact'),
        onSelect: () {},
      );
    case 'posterCardPaint':
      return PosterCard(
        imageUrl: propsStringOr(
          props,
          'imageUrl',
          propsStringOr(props, 'posterUrl', ''),
        ),
        title: propsStringOr(props, 'title', ''),
        width: propsLengthOr(context, props, 'width', 120),
        height: propsLengthOr(context, props, 'height', 180),
        subtitle: propsString(props, 'subtitle'),
        rating: propsNum(props, 'rating'),
        rank: propsInt(props, 'rank'),
        badge: propsString(props, 'badge'),
        aspect: _posterAspect(propsString(props, 'aspect')),
        borderRadius: propsLengthOr(context, props, 'borderRadius', ShellTokens.posterCardRadius),
        titleFontSize: propsLengthOr(context, props, 'titleFontSize', ShellTokens.posterTitleFontSizeMobile),
        metaFontSize: propsLengthOr(context, props, 'metaFontSize', 11),
        inset: propsLengthOr(context, props, 'inset', 10),
        backgroundColor:
            propsColor(props, 'backgroundColor') ?? const Color(0xFF0A0A0A),
        onTap: () {},
      );
    case 'catalogFilterSheet':
      final sheetPad = propsLength(context, props, 'padding') ?? propsLength(context, props, 'pad');
      return CatalogFilterSheet(
        current: propsStringOr(props, 'current', ''),
        options: _filterSheetOptions(props),
        tvFocus: propsBool(props, 'tvFocus'),
        autofocusFirst: propsBool(props, 'autofocusFirst'),
        radius: propsLength(context, props, 'radius'),
        fontSize: propsLength(context, props, 'fontSize'),
        padding: sheetPad != null ? EdgeInsets.all(sheetPad) : null,
      );
    case 'filterSheetOption':
      final optPad = propsLength(context, props, 'padding') ?? propsLength(context, props, 'pad');
      return FilterSheetOption(
        label: propsStringOr(props, 'label', ''),
        subtitle: propsString(props, 'subtitle'),
        selected: propsBool(props, 'selected'),
        icon: _filterSheetIcon(propsString(props, 'icon')),
        onSelected: () {},
        scaleOnHover: propsBool(props, 'scaleOnHover', true),
        tvFocus: propsBool(props, 'tvFocus'),
        radius: propsLengthOr(context, props, 'radius', 12),
        fontSize: propsLength(context, props, 'fontSize'),
        padding: optPad != null
            ? EdgeInsets.symmetric(vertical: optPad)
            : const EdgeInsets.symmetric(vertical: 2),
      );

    case 'searchBlock':
      return SearchBlock.fromProps(
        props,
        results: children.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
      );

    // ── Inventory slice (RFC-112) ──────────────────────────────────────
    case 'guideFloatingEpg':
      return GuideFloatingEpg(
        future: Future<List<GuideEpgProgramme>>.value(const []),
        maxWidth: propsLengthOr(context, props, 'maxWidth', 360),
      );
    case 'liveTvScrollbar':
      return _PaintLiveTvScrollbar(
        enabled: props['enabled'] is bool ? props['enabled'] as bool : true,
        child: childOrEmpty(),
      );
    case 'sourcesExpandingSearch':
      return SourcesExpandingSearch(
        query: propsStringOr(props, 'query', ''),
        onQueryChanged: (_) {},
        useTvBrowse:
            propsBool(props, 'useTvBrowse') || propsBool(props, 'compact'),
      );
    case 'sourcesCategoryRailRow':
      return SourcesCategoryRailRow(
        label: propsStringOr(props, 'label', ''),
        count: propsInt(props, 'count') ?? 0,
        selected: propsBool(props, 'selected'),
        onTap: () {},
        listIndex: propsInt(props, 'listIndex'),
      );
    case 'catalogChannelCard':
      return CatalogChannelCard(
        title: propsStringOr(props, 'title', ''),
        imageUrl: propsStringOr(
          props,
          'imageUrl',
          propsStringOr(props, 'logoUrl', ''),
        ),
        highlighted: propsBool(props, 'highlighted'),
        width: propsLength(context, props, 'width'),
        height: propsLength(context, props, 'height'),
        radius: propsLength(context, props, 'radius'),
        epgSlotHeight: propsLength(context, props, 'epgSlotHeight'),
        titleFontSize: propsLength(context, props, 'titleFontSize'),
        metaFontSize: propsLength(context, props, 'metaFontSize'),
        badgeFontSize: propsLength(context, props, 'badgeFontSize'),
        health: props['health'] is bool ? props['health'] as bool : null,
        onTap: () {},
      );
    case 'catalogEpgGuide':
      return SizedBox(
        height: propsLengthOr(context, props, 'height', 420),
        child: CatalogEpgGuide(
          channels: _epgChannels(props),
          onChannelTap: (_) {},
          highlightChannelId: propsString(props, 'highlightChannelId'),
          emptyTitle: propsStringOr(
            props,
            'emptyTitle',
            'No channels in this view',
          ),
          columnWidth: propsLength(context, props, 'columnWidth') ??
              EpgGuideTokens.columnWidth,
          rowHeight:
              propsLength(context, props, 'rowHeight') ?? EpgGuideTokens.rowHeight,
          headerHeight: propsLength(context, props, 'headerHeight') ??
              EpgGuideTokens.headerHeight,
        ),
      );
    case 'shellMoodCircle':
      final mood = kitMoodCircleMeta(
        id: propsStringOr(props, 'id', ''),
        icon: propsString(props, 'icon'),
      );
      return ShellMoodCircleItem(
        layout: ShellMoodCircleLayout.resolve(
          context,
          itemCount: 1,
          maxWidth: MediaQuery.sizeOf(context).width,
        ),
        label: propsStringOr(props, 'label', ''),
        icon: mood.icon,
        accent: propsColor(props, 'accent') ?? mood.accent,
        selected: propsBool(props, 'selected'),
        onTap: () {},
      );
    case 'certBadge':
      return CertBadge(label: propsStringOr(props, 'label', 'NR'));
    case 'ratingBadge':
      return RatingBadge(
        voteAverage: propsNumOr(props, 'voteAverage', propsNumOr(props, 'rating', 0)),
      );
    case 'ratingBadgeText':
      return RatingBadgeText(
        rating: propsStringOr(props, 'rating', propsStringOr(props, 'label', '—')),
      );
    case 'forjaActionChip':
      return ForjaActionChip(
        label: propsStringOr(props, 'label', ''),
        onTap: () {},
        icon: propsString(props, 'icon') == null
            ? null
            : _filterSheetIcon(propsString(props, 'icon')),
        selected: propsBool(props, 'selected'),
        iconOnly: propsBool(props, 'iconOnly'),
        height: propsLengthOr(context, props, 'height', ShellTokens.controlHeight),
        radius: propsLengthOr(context, props, 'radius', ShellTokens.shellChipRadiusPill),
        maxWidth: propsLengthOr(context, props, 'maxWidth', ShellTokens.actionChipMaxWidth),
        fontSize: propsLengthOr(context, props, 'fontSize', ShellTokens.actionChipFontSize),
        iconSize: propsLength(context, props, 'iconSize'),
        gap: propsLengthOr(context, props, 'gap', ShellTokens.actionChipGap),
      );
    case 'catalogListEmpty':
      return CatalogListEmpty(
        title: propsStringOr(props, 'title', 'Nothing here'),
        subtitle: propsStringOr(
          props,
          'subtitle',
          propsStringOr(props, 'description', ''),
        ),
        icon: _filterSheetIcon(propsString(props, 'icon')),
        topPadding: propsLengthOr(context, props, 'topPadding', 0),
      );
    case 'catalogLoadingTicker':
      return CatalogLoadingTicker(
        title: propsStringOr(props, 'title', 'Loading…'),
        detail: propsStringOr(props, 'detail', propsStringOr(props, 'subtitle', '')),
      );
    case 'inlineAlert':
      return InlineAlert(
        title: propsString(props, 'title'),
        description: propsString(props, 'description'),
        variant: _alertVariant(propsString(props, 'variant')),
      );
    case 'checkboxGroup':
      return CheckboxGroup(
        spacing: propsLength(context, props, 'spacing'),
        children: kids().isEmpty
            ? [
                Checkbox(value: false, onChanged: (_) {}, label: 'Option'),
              ]
            : kids(),
      );
    case 'toggleGroup':
      return ToggleGroup(
        orientation: _axis(propsString(props, 'orientation')),
        spacing: propsLength(context, props, 'spacing'),
        children: kids().isEmpty
            ? [
                Toggle(pressed: false, onPressed: () {}, label: 'A'),
                Toggle(pressed: true, onPressed: () {}, label: 'B'),
              ]
            : kids(),
      );
    case 'skeletonText':
      return SkeletonText(
        lines: propsInt(props, 'lines') ?? 3,
        lineHeight: propsLengthOr(context, props, 'lineHeight', 12),
        spacing: propsLength(context, props, 'spacing'),
        lastLineFraction: propsNumOr(props, 'lastLineFraction', 0.65),
      );
    case 'skeletonPoster':
      return SkeletonPoster(
        width: propsLengthOr(context, props, 'width', 120),
        aspectRatio: propsNumOr(props, 'aspectRatio', 2 / 3),
      );
    case 'listStatusMenuRow':
      return ListStatusMenuRow(
        selected: propsBool(props, 'selected'),
        icon: _filterSheetIcon(propsString(props, 'icon')),
        label: propsStringOr(props, 'label', ''),
        statusColor:
            propsColor(props, 'statusColor') ?? ForjaShellColors.sectionAccent,
        tvFocus: propsBool(props, 'tvFocus') || propsBool(props, 'compact'),
        autoFocus: propsBool(props, 'autoFocus'),
        onTap: () {},
      );
    case 'listStatusPopup':
      return ListStatusPopupPanel(
        currentStatus: propsString(props, 'currentStatus'),
        onSelect: (_) {},
        busy: propsBool(props, 'busy'),
        tvFocus: propsBool(props, 'tvFocus') || propsBool(props, 'compact'),
        autoFocusSelected: propsBool(props, 'autoFocusSelected'),
      );
    case 'heroMagnetIcon':
      return HeroMagnetIcon(
        size: propsLength(context, props, 'size'),
        color: propsColor(props, 'color'),
      );
    case 'detailsUpcomingNotice':
      return DetailsUpcomingNotice(
        releaseDateLabel: propsString(
          props,
          'releaseDateLabel',
        ) ??
            propsString(props, 'releaseDate'),
      );
    case 'interactiveEventCard':
      return InteractiveEventCard(
        props: props,
        width: propsLengthOr(context, props, 'width', ShellTokens.shellContinueWatchingCardWidthDesktop),
        height: propsLengthOr(context, props, 'height', 200),
        selected: propsBool(props, 'selected'),
        onTap: () {},
      );
    case 'topBarActions':
      final trailingCount = propsInt(props, 'trailingCount') ?? 0;
      final all = kids();
      final lead = trailingCount <= 0 || trailingCount >= all.length
          ? all
          : all.sublist(0, all.length - trailingCount);
      final trail = trailingCount <= 0 || trailingCount >= all.length
          ? const <Widget>[]
          : all.sublist(all.length - trailingCount);
      return TopBarActions(
        leading: lead,
        trailing: trail,
        height: propsLength(context, props, 'height'),
        gap: propsLengthOr(context, props, 'gap', 8),
      );
    case 'viewButtonGroup':
      final items = _viewButtonItems(props);
      return ViewButtonGroup(
        items: items.isEmpty
            ? const [
                ViewButtonItem(id: 'cards', icon: Icons.grid_view_rounded),
                ViewButtonItem(id: 'list', icon: Icons.view_list_rounded),
              ]
            : items,
        selectedId: propsString(props, 'selectedId') ??
            (items.isEmpty ? 'cards' : items.first.id),
        onSelect: (_) {},
        height: propsLengthOr(context, props, 'height', 36),
        iconSize: propsLengthOr(context, props, 'iconSize', ShellTokens.categoryRailIconSize),
        dividerHeight: propsLengthOr(context, props, 'dividerHeight', 16),
      );
    case 'widgetShelf': {
      final shelf = _widgetShelfItems(props);
      final tv = catalogUsesTvDensity(context);
      return WidgetShelf(
        items: shelf.isEmpty
            ? const [
                WidgetShelfItem(id: 'a', label: 'Live'),
                WidgetShelfItem(id: 'b', label: 'Movies'),
              ]
            : shelf,
        selectedId: propsString(props, 'selectedId') ??
            (shelf.isEmpty ? 'a' : shelf.first.id),
        onSelect: (_) {},
        height: propsLengthOr(context, props, 'height', 36),
        radius: propsLengthOr(context, props, 'radius', 8),
        fontSize: propsNumOr(
          props,
          'fontSize',
          tv ? ShellTokens.shellChipFontSizeTv : ShellTokens.shellChipFontSize,
        ),
        iconSize: propsLengthOr(context, props, 'iconSize', ShellTokens.actionChipIconSize),
        pad: propsLengthOr(context, props, 'pad', 14),
      );
    }
    case 'catalogSideRail':
      final side = _idLabelList(props, 'items');
      return SizedBox(
        height: propsLengthOr(context, props, 'height', 320),
        child: CatalogSideRail(
          items: side.isEmpty
              ? const [(id: 'all', label: 'All')]
              : side,
          selectedId: propsString(props, 'selectedId') ??
              (side.isEmpty ? 'all' : side.first.id),
          onSelect: (_) {},
          width: propsLengthOr(context, props, 'width', catalogSideRailWidth(context)),
        ),
      );
    case 'catalogCategoryRail':
      final cats = _categoryRailItems(props);
      return SizedBox(
        height: propsLengthOr(context, props, 'height', 320),
        child: CatalogCategoryRail(
          items: cats.isEmpty
              ? const [CatalogCategoryItem(id: 'all', label: 'All', fixed: true)]
              : cats,
          selectedId: propsString(props, 'selectedId') ??
              (cats.isEmpty ? 'all' : cats.first.id),
          onSelect: (_) {},
          width: propsLengthOr(context, props, 'width', catalogSideRailWidth(context)),
          compact: propsBool(props, 'compact'),
          rowHeight: propsLength(context, props, 'rowHeight'),
          fontSize: propsLength(context, props, 'fontSize'),
          iconSize: propsLength(context, props, 'iconSize'),
          rowPadH: propsLength(context, props, 'rowPadH'),
          listPadV: propsLengthOr(context, props, 'listPadV', 8),
          pinSlotWidth: propsLengthOr(context, props, 'pinSlotWidth', 28),
        ),
      );
    case 'catalogSearchTypeSegment':
      return CatalogSearchTypeSegment(
        value: _searchMediaFilter(propsString(props, 'value')),
        allLabel: propsStringOr(props, 'allLabel', 'All'),
        movieLabel: propsStringOr(props, 'movieLabel', 'Films'),
        seriesLabel: propsStringOr(props, 'seriesLabel', 'Series'),
        onChanged: (_) {},
      );
    case 'catalogSearchScoreArc':
      return CatalogSearchScoreArc(
        value: propsNum(props, 'value'),
        onChanged: (_) {},
        tvLeanback:
            propsBool(props, 'tvLeanback') || propsBool(props, 'compact'),
      );
    case 'catalogSearchYearTimeline':
      return CatalogSearchYearTimeline(
        start: propsInt(props, 'start'),
        end: propsInt(props, 'end'),
        onChanged: (_, _) {},
        tvLeanback:
            propsBool(props, 'tvLeanback') || propsBool(props, 'compact'),
      );
    case 'catalogSearchFilterChipSection':
      return CatalogSearchFilterChipSection(
        title: propsStringOr(props, 'title', ''),
        options: _searchFilterOptions(props),
        selectedToken: propsString(props, 'selectedToken'),
        onSelected: (_) {},
      );
    case 'catalogSearchFilterGhostChip':
      return CatalogSearchFilterGhostChip(
        label: propsStringOr(props, 'label', ''),
        selected: propsBool(props, 'selected'),
        onTap: () {},
      );
    case 'catalogSearchSkeletonCard':
      return SizedBox(
        width: propsLengthOr(context, props, 'width', 160),
        height: propsLengthOr(context, props, 'height', 240),
        child: const CatalogSearchSkeletonCard(),
      );
    case 'catalogDenseRowSkeleton':
      return CatalogDenseRowSkeleton(index: propsInt(props, 'index') ?? 0);
    case 'catalogScheduleDenseSkeleton':
      return SizedBox(
        height: propsLengthOr(context, props, 'height', 320),
        child: CatalogScheduleDenseSkeleton(
          leading: propsLength(context, props, 'leading'),
          topPadding: propsLengthOr(context, props, 'topPadding', 4),
          trailing: propsLength(context, props, 'trailing'),
          bottomPadding: propsLengthOr(context, props, 'bottomPadding', 0),
        ),
      );
    case 'catalogPosterLoadingGrid':
      final layout = CatalogPosterGridLayout(
        columns: propsInt(props, 'columns') ?? 4,
        cardW: propsLengthOr(context, props, 'cardW', propsLengthOr(context, props, 'cardWidth', catalogUsesTvDensity(context) ? ShellTokens.posterCardWidthTv : 120)),
        cardH: propsLengthOr(context, props, 'cardH', propsLengthOr(context, props, 'cardHeight', catalogUsesTvDensity(context) ? ShellTokens.posterCardWidthTv * ShellTokens.posterCardAspectRatio : 180)),
        gap: propsLengthOr(context, props, 'gap', 12),
        leading: propsLengthOr(context, props, 'leading', ShellTokens.homeSectionHorizontalPadding),
        rightPad: propsLengthOr(context, props, 'rightPad', ShellTokens.homeSectionHorizontalPadding),
        topPad: propsLengthOr(context, props, 'topPad', 8),
      );
      return SizedBox(
        height: propsLengthOr(context, props, 'height', 400),
        child: CatalogPosterLoadingGrid(
          layout: layout,
          placeholder: SkeletonPoster(
            width: layout.cardW,
            aspectRatio: layout.cardW / layout.cardH,
          ),
          rowCount: propsInt(props, 'rowCount') ?? 2,
          bottomPadding: propsLength(context, props, 'bottomPadding'),
        ),
      );

    default:
      return null;
  }
}

// ── helpers ──────────────────────────────────────────────────────────────

Axis _axis(String? raw) =>
    raw == 'vertical' ? Axis.vertical : Axis.horizontal;

ButtonVariant _buttonVariant(String? raw) => switch ((raw ?? '').toLowerCase()) {
      'primary' => ButtonVariant.primary,
      'ghost' => ButtonVariant.ghost,
      'outline' => ButtonVariant.outline,
      'destructive' => ButtonVariant.destructive,
      'accent' => ButtonVariant.accent,
      'link' => ButtonVariant.link,
      'plainicon' || 'plain_icon' => ButtonVariant.plainIcon,
      _ => ButtonVariant.secondary,
    };

ButtonSize _buttonSize(String? raw) => switch ((raw ?? '').toLowerCase()) {
      'sm' => ButtonSize.sm,
      'lg' => ButtonSize.lg,
      'icon' => ButtonSize.icon,
      _ => ButtonSize.md,
    };

BadgeVariant _badgeVariant(String? raw) => switch ((raw ?? '').toLowerCase()) {
      'secondary' => BadgeVariant.secondary,
      'destructive' => BadgeVariant.destructive,
      'outline' => BadgeVariant.outline,
      _ => BadgeVariant.default_,
    };

BadgeSize _badgeSize(String? raw) =>
    (raw ?? '').toLowerCase() == 'sm' ? BadgeSize.sm : BadgeSize.md;

AlertVariant _alertVariant(String? raw) => switch ((raw ?? '').toLowerCase()) {
      'success' => AlertVariant.success,
      'warning' => AlertVariant.warning,
      'destructive' => AlertVariant.destructive,
      _ => AlertVariant.info,
    };

EmptySize _emptySize(String? raw) => switch ((raw ?? '').toLowerCase()) {
      'sm' => EmptySize.sm,
      'lg' => EmptySize.lg,
      _ => EmptySize.md,
    };

AvatarSize _avatarSize(String? raw) => switch ((raw ?? '').toLowerCase()) {
      'sm' => AvatarSize.sm,
      'lg' => AvatarSize.lg,
      _ => AvatarSize.md,
    };

ProgressVariant _progressVariant(String? raw) =>
    (raw ?? '').toLowerCase() == 'circular'
        ? ProgressVariant.circular
        : ProgressVariant.linear;

HeadingLevel _headingLevel(String? raw) => switch ((raw ?? '').toLowerCase()) {
      'h1' || '1' => HeadingLevel.h1,
      'h3' || '3' => HeadingLevel.h3,
      'h4' || '4' => HeadingLevel.h4,
      _ => HeadingLevel.h2,
    };

BodyTone _bodyTone(String? raw) => switch ((raw ?? '').toLowerCase()) {
      'secondary' => BodyTone.secondary,
      'muted' => BodyTone.muted,
      _ => BodyTone.primary,
    };

HeroPillPlayTone _pillTone(String? raw) => switch ((raw ?? '').toLowerCase()) {
      'secondary' => HeroPillPlayTone.secondary,
      'streaming' => HeroPillPlayTone.streaming,
      _ => HeroPillPlayTone.primary,
    };

List<SelectOption<String>> _stringOptions(Map<String, dynamic> props) {
  final v = props['options'];
  if (v is! List) {
    return [
      for (final s in propsStringList(props, 'options'))
        SelectOption(value: s, label: s),
    ];
  }
  final out = <SelectOption<String>>[];
  for (final e in v) {
    if (e is Map) {
      final value = (e['value'] ?? e['id'] ?? '').toString();
      final label = (e['label'] ?? e['title'] ?? value).toString();
      if (value.isEmpty && label.isEmpty) continue;
      out.add(SelectOption(value: value.isEmpty ? label : value, label: label));
    } else {
      final s = e?.toString().trim() ?? '';
      if (s.isNotEmpty) out.add(SelectOption(value: s, label: s));
    }
  }
  return out;
}

List<SegmentedOption<String>> _segmentedOptions(Map<String, dynamic> props) {
  return [
    for (final o in _stringOptions(props))
      SegmentedOption(value: o.value, label: o.label),
  ];
}

List<PosterItem> _posterItems(Map<String, dynamic> props) {
  final v = props['items'];
  if (v is! List) return const [];
  final out = <PosterItem>[];
  for (final e in v) {
    if (e is! Map) continue;
    final url = (e['url'] ?? e['imageUrl'] ?? e['posterUrl'] ?? '').toString();
    if (url.isEmpty) continue;
    out.add(PosterItem(url: url, title: e['title']?.toString()));
  }
  return out;
}

List<({String id, String name})> _idNameList(
  Map<String, dynamic> props,
  String key,
) {
  final v = props[key];
  if (v is! List) return const [];
  final out = <({String id, String name})>[];
  for (final e in v) {
    if (e is! Map) continue;
    final id = (e['id'] ?? '').toString().trim();
    if (id.isEmpty) continue;
    final name = (e['name'] ?? e['label'] ?? id).toString();
    out.add((id: id, name: name));
  }
  return out;
}

List<({String label, String value})> _factRows(Map<String, dynamic> props) {
  final v = props['rows'];
  if (v is! List) {
    final label = propsString(props, 'label');
    final value = propsString(props, 'value');
    if (label != null && value != null) return [(label: label, value: value)];
    return const [];
  }
  final out = <({String label, String value})>[];
  for (final e in v) {
    if (e is! Map) continue;
    final label = (e['label'] ?? '').toString();
    final value = (e['value'] ?? '').toString();
    if (label.isEmpty && value.isEmpty) continue;
    out.add((label: label, value: value));
  }
  return out;
}

List<WatchProviderTile> _watchProviders(Map<String, dynamic> props) {
  final v = props['providers'];
  if (v is! List) return const [];
  final out = <WatchProviderTile>[];
  for (final e in v) {
    if (e is! Map) continue;
    final name = (e['name'] ?? e['label'] ?? '').toString();
    final logo = (e['logoUrl'] ?? e['logo'] ?? '').toString();
    if (name.isEmpty) continue;
    out.add(WatchProviderTile(name: name, logoUrl: logo));
  }
  return out;
}

List<Map<String, String>> _castMaps(Map<String, dynamic> props) {
  final v = props['cast'];
  if (v is! List) return const [];
  final out = <Map<String, String>>[];
  for (final e in v) {
    if (e is! Map) continue;
    out.add({
      for (final entry in e.entries)
        entry.key.toString(): entry.value?.toString() ?? '',
    });
  }
  return out;
}

List<DetailsTrailerItem> _trailers(Map<String, dynamic> props) {
  final v = props['trailers'];
  if (v is! List) return const [];
  final out = <DetailsTrailerItem>[];
  for (final e in v) {
    if (e is! Map) continue;
    final key = (e['key'] ?? e['id'] ?? '').toString();
    final name = (e['name'] ?? e['title'] ?? '').toString();
    final thumb = (e['thumbnailUrl'] ?? e['thumbnail'] ?? '').toString();
    if (key.isEmpty && name.isEmpty) continue;
    out.add(DetailsTrailerItem(
      key: key.isEmpty ? name : key,
      name: name.isEmpty ? key : name,
      thumbnailUrl: thumb,
      official: e['official'] == true,
    ));
  }
  return out;
}

List<SourcesTab> _sourcesTabs(Map<String, dynamic> props) {
  final v = props['tabs'];
  if (v is! List) return const [];
  final out = <SourcesTab>[];
  for (final e in v) {
    if (e is! Map) continue;
    final id = (e['id'] ?? '').toString().trim();
    if (id.isEmpty) continue;
    out.add(SourcesTab(
      id: id,
      label: (e['label'] ?? e['title'] ?? id).toString(),
      icon: (e['icon'] ?? '').toString(),
    ));
  }
  return out;
}

List<EpisodeRange> _episodeRanges(Map<String, dynamic> props) {
  final v = props['ranges'];
  if (v is! List) return const [];
  final out = <EpisodeRange>[];
  for (var i = 0; i < v.length; i++) {
    final e = v[i];
    if (e is! Map) continue;
    final start = int.tryParse((e['labelStart'] ?? e['start'] ?? '').toString());
    final end = int.tryParse((e['labelEnd'] ?? e['end'] ?? '').toString());
    if (start == null || end == null) continue;
    out.add(EpisodeRange(
      index: int.tryParse((e['index'] ?? i).toString()) ?? i,
      labelStart: start,
      labelEnd: end,
    ));
  }
  return out;
}

List<PlayerStatsRow> _playerStatsRows(Map<String, dynamic> props) {
  final v = props['rows'];
  if (v is! List) {
    final label = propsString(props, 'label');
    final value = propsString(props, 'value');
    if (label != null && value != null) {
      return [PlayerStatsRow(label, value)];
    }
    return const [
      PlayerStatsRow('Source', '—'),
      PlayerStatsRow('State', 'idle'),
    ];
  }
  final out = <PlayerStatsRow>[];
  for (final e in v) {
    if (e is! Map) continue;
    final label = (e['label'] ?? '').toString();
    final value = (e['value'] ?? '').toString();
    if (label.isEmpty && value.isEmpty) continue;
    out.add(PlayerStatsRow(label, value));
  }
  return out.isEmpty
      ? const [PlayerStatsRow('Source', '—')]
      : out;
}

List<({String id, String label, String? subtitle})> _filterSheetOptions(
  Map<String, dynamic> props,
) {
  final v = props['options'];
  if (v is! List) {
    final id = propsStringOr(props, 'id', 'all');
    final label = propsStringOr(props, 'label', 'All');
    return [(id: id, label: label, subtitle: propsString(props, 'subtitle'))];
  }
  final out = <({String id, String label, String? subtitle})>[];
  for (final e in v) {
    if (e is! Map) continue;
    final id = (e['id'] ?? e['value'] ?? '').toString().trim();
    final label = (e['label'] ?? e['title'] ?? id).toString();
    if (id.isEmpty && label.isEmpty) continue;
    out.add((
      id: id.isEmpty ? label : id,
      label: label.isEmpty ? id : label,
      subtitle: e['subtitle']?.toString(),
    ));
  }
  return out.isEmpty
      ? const [(id: 'all', label: 'All', subtitle: null)]
      : out;
}

PosterAspect _posterAspect(String? raw) =>
    (raw ?? '').toLowerCase() == 'landscape'
        ? PosterAspect.landscape
        : PosterAspect.portrait;

IconData _filterSheetIcon(String? raw) => switch ((raw ?? '').toLowerCase()) {
      'check' || 'done' => Icons.check_rounded,
      'movie' => Icons.movie_outlined,
      'tv' => Icons.tv_outlined,
      'star' => Icons.star_outline_rounded,
      'sort' => Icons.sort_rounded,
      'grid' || 'cards' => Icons.grid_view_rounded,
      'list' => Icons.view_list_rounded,
      'timeline' || 'schedule' => Icons.schedule_rounded,
      'refresh' => Icons.refresh_rounded,
      'bookmark' => Icons.bookmark_outline_rounded,
      _ => Icons.filter_list_rounded,
    };

List<CatalogEpgChannel> _epgChannels(Map<String, dynamic> props) {
  final v = props['channels'] ?? props['items'];
  if (v is! List) return const [];
  final out = <CatalogEpgChannel>[];
  for (final e in v) {
    if (e is! Map) continue;
    final id = (e['id'] ?? '').toString().trim();
    final title = (e['title'] ?? e['name'] ?? e['label'] ?? id).toString();
    if (id.isEmpty && title.isEmpty) continue;
    out.add(CatalogEpgChannel(
      id: id.isEmpty ? title : id,
      title: title.isEmpty ? id : title,
      imageUrl: (e['imageUrl'] ?? e['logoUrl'] ?? '').toString(),
    ));
  }
  return out;
}

List<({String id, String label})> _idLabelList(
  Map<String, dynamic> props,
  String key,
) {
  final v = props[key];
  if (v is! List) return const [];
  final out = <({String id, String label})>[];
  for (final e in v) {
    if (e is! Map) continue;
    final id = (e['id'] ?? e['value'] ?? '').toString().trim();
    final label = (e['label'] ?? e['title'] ?? e['name'] ?? id).toString();
    if (id.isEmpty && label.isEmpty) continue;
    out.add((id: id.isEmpty ? label : id, label: label.isEmpty ? id : label));
  }
  return out;
}

List<CatalogCategoryItem> _categoryRailItems(Map<String, dynamic> props) {
  final v = props['items'];
  if (v is! List) return const [];
  final out = <CatalogCategoryItem>[];
  for (final e in v) {
    if (e is! Map) continue;
    final id = (e['id'] ?? '').toString().trim();
    final label = (e['label'] ?? e['title'] ?? id).toString();
    if (id.isEmpty && label.isEmpty) continue;
    out.add(CatalogCategoryItem(
      id: id.isEmpty ? label : id,
      label: label.isEmpty ? id : label,
      icon: e['icon'] == null ? null : _filterSheetIcon(e['icon']?.toString()),
      pinnable: e['pinnable'] == true,
      pinned: e['pinned'] == true,
      fixed: e['fixed'] == true,
    ));
  }
  return out;
}

List<ViewButtonItem> _viewButtonItems(Map<String, dynamic> props) {
  final v = props['items'];
  if (v is! List) return const [];
  final out = <ViewButtonItem>[];
  for (final e in v) {
    if (e is! Map) continue;
    final id = (e['id'] ?? '').toString().trim();
    if (id.isEmpty) continue;
    out.add(ViewButtonItem(
      id: id,
      icon: _filterSheetIcon(e['icon']?.toString() ?? id),
      label: (e['label'] ?? '').toString(),
    ));
  }
  return out;
}

List<WidgetShelfItem> _widgetShelfItems(Map<String, dynamic> props) {
  final v = props['items'];
  if (v is! List) return const [];
  final out = <WidgetShelfItem>[];
  for (final e in v) {
    if (e is! Map) continue;
    final id = (e['id'] ?? '').toString().trim();
    final label = (e['label'] ?? e['title'] ?? id).toString();
    if (id.isEmpty && label.isEmpty) continue;
    out.add(WidgetShelfItem(
      id: id.isEmpty ? label : id,
      label: label.isEmpty ? id : label,
      icon: e['icon'] == null ? null : _filterSheetIcon(e['icon']?.toString()),
    ));
  }
  return out;
}

List<(String, String)> _searchFilterOptions(Map<String, dynamic> props) {
  final v = props['options'];
  if (v is! List) {
    final label = propsStringOr(props, 'label', 'All');
    final token = propsStringOr(props, 'token', 'all');
    return [(label, token)];
  }
  final out = <(String, String)>[];
  for (final e in v) {
    if (e is! Map) continue;
    final label = (e['label'] ?? e['title'] ?? '').toString();
    final token = (e['token'] ?? e['id'] ?? e['value'] ?? label).toString();
    if (label.isEmpty && token.isEmpty) continue;
    out.add((label.isEmpty ? token : label, token.isEmpty ? label : token));
  }
  return out.isEmpty ? const [('All', 'all')] : out;
}

SearchMediaFilter _searchMediaFilter(String? raw) =>
    switch ((raw ?? '').toLowerCase()) {
      'movie' || 'films' || 'film' => SearchMediaFilter.movie,
      'tv' || 'series' => SearchMediaFilter.tv,
      _ => SearchMediaFilter.all,
    };

/// Owns [ScrollController] for paint-only [LiveTvScrollbar] mounts.
class _PaintLiveTvScrollbar extends StatefulWidget {
  const _PaintLiveTvScrollbar({
    required this.child,
    required this.enabled,
  });

  final Widget child;
  final bool enabled;

  @override
  State<_PaintLiveTvScrollbar> createState() => _PaintLiveTvScrollbarState();
}

class _PaintLiveTvScrollbarState extends State<_PaintLiveTvScrollbar> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LiveTvScrollbar(
      controller: _controller,
      enabled: widget.enabled,
      child: PrimaryScrollController(
        controller: _controller,
        child: SingleChildScrollView(
          controller: _controller,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Owns [TextEditingController] / [FocusNode] for paint-only guide field mounts.
class _PaintGuideBrowseTextField extends StatefulWidget {
  const _PaintGuideBrowseTextField({
    required this.hint,
    required this.tvBrowse,
    required this.autofocus,
  });

  final String hint;
  final bool tvBrowse;
  final bool autofocus;

  @override
  State<_PaintGuideBrowseTextField> createState() =>
      _PaintGuideBrowseTextFieldState();
}

class _PaintGuideBrowseTextFieldState extends State<_PaintGuideBrowseTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode(debugLabel: 'paint-guide-browse');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GuideBrowseTextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: (_) {},
      decoration: InputDecoration(
        hintText: widget.hint,
        border: InputBorder.none,
        isDense: true,
      ),
      autofocus: widget.autofocus,
      tvBrowse: widget.tvBrowse,
      browsePlaceholder: widget.hint,
    );
  }
}
