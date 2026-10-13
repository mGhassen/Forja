import 'package:flutter/material.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/forja_interactive.dart';
import 'package:forja/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/details/hero_pill_surfaces.dart';

/// SUB | DUB glass group — each segment opens a multiselect language dropdown.
///
/// Selection is exclusive across kinds: picking a SUB language clears DUB
/// (and the reverse). Empty selection = all providers.
class KitMultiselectPlayFilter extends StatelessWidget {
  const KitMultiselectPlayFilter({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.tvTabId,
    this.tvItemIndexStart,
    this.onUpEdge,
  });

  final List<PluginLanguage> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final String? tvTabId;
  final int? tvItemIndexStart;
  final VoidCallback? onUpEdge;

  @override
  Widget build(BuildContext context) {
    final subs = [for (final o in options) if (o.kind == 'sub') o];
    final dubs = [for (final o in options) if (o.kind == 'dub') o];
    if (subs.isEmpty && dubs.isEmpty) return const SizedBox.shrink();

    final useTvCompact = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final segments = <({
      String kind,
      String label,
      IconData icon,
      List<PluginLanguage> langs,
    })>[
      if (subs.isNotEmpty)
        (
          kind: 'sub',
          label: 'SUB',
          icon: Icons.subtitles_rounded,
          langs: subs,
        ),
      if (dubs.isNotEmpty)
        (
          kind: 'dub',
          label: 'DUB',
          icon: Icons.mic_rounded,
          langs: dubs,
        ),
    ];

    return HeroPillGlassShell(
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const HeroPillSlotDivider(),
          _KindDropdownSegment(
            kind: segments[i].kind,
            label: segments[i].label,
            icon: segments[i].icon,
            langs: segments[i].langs,
            selected: selected,
            onChanged: onChanged,
            isFirst: i == 0,
            isLast: i == segments.length - 1,
            useTvCompact: useTvCompact,
            tvTabId: tvTabId,
            tvItemIndex: tvItemIndexStart != null
                ? tvItemIndexStart! + i
                : null,
            onUpEdge: onUpEdge,
          ),
        ],
      ],
    );
  }
}

class _KindDropdownSegment extends StatefulWidget {
  const _KindDropdownSegment({
    required this.kind,
    required this.label,
    required this.icon,
    required this.langs,
    required this.selected,
    required this.onChanged,
    required this.isFirst,
    required this.isLast,
    required this.useTvCompact,
    this.tvTabId,
    this.tvItemIndex,
    this.onUpEdge,
  });

  final String kind;
  final String label;
  final IconData icon;
  final List<PluginLanguage> langs;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool isFirst;
  final bool isLast;
  final bool useTvCompact;
  final String? tvTabId;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;

  @override
  State<_KindDropdownSegment> createState() => _KindDropdownSegmentState();
}

class _KindDropdownSegmentState extends State<_KindDropdownSegment> {
  final MenuController _menu = MenuController();
  bool _keepOpen = false;

  bool get _kindActive {
    if (widget.selected.isEmpty) return false;
    return widget.langs.any((l) => widget.selected.contains(l.key));
  }

  int get _kindCount =>
      widget.langs.where((l) => widget.selected.contains(l.key)).length;

  void _toggleKey(String key, bool? checked) {
    final next = <String>{};
    if (checked == true) {
      // Exclusive kind: drop the other kind's keys.
      for (final k in widget.selected) {
        if (k.startsWith('${widget.kind}:')) next.add(k);
      }
      next.add(key);
    } else {
      for (final k in widget.selected) {
        if (k != key) next.add(k);
      }
    }
    _keepOpen = true;
    widget.onChanged(next);
  }

  void _clearKind() {
    final next = {
      for (final k in widget.selected)
        if (!k.startsWith('${widget.kind}:')) k,
    };
    _keepOpen = true;
    widget.onChanged(next);
  }

  @override
  void didUpdateWidget(covariant _KindDropdownSegment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_keepOpen && !_menu.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_keepOpen) return;
        _menu.open();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final active = _kindActive;
    final count = _kindCount;
    final chipLabel = !active
        ? '${widget.label} ▾'
        : (count == widget.langs.length
            ? '${widget.label} ▾'
            : '${widget.label} · $count ▾');

    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, 6),
      onClose: () => _keepOpen = false,
      onOpen: () => _keepOpen = true,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(cinematic.menuSurface),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(220, 0)),
        maximumSize: const WidgetStatePropertyAll(Size(320, 420)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShellTokens.shellChipRadius),
          ),
        ),
      ),
      menuChildren: [
        MenuItemButton(
          closeOnActivate: false,
          onPressed: _clearKind,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Text(
              active ? 'Clear ${widget.label}' : 'All ${widget.label}',
              style: TextStyle(
                color: cinematic.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const Divider(height: 12),
        for (final lang in widget.langs)
          CheckboxMenuButton(
            closeOnActivate: false,
            value: widget.selected.contains(lang.key),
            onChanged: (v) => _toggleKey(lang.key, v),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              minimumSize: const WidgetStatePropertyAll(Size(200, 36)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              lang.label,
              style: TextStyle(
                color: cinematic.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
      ],
      builder: (context, controller, child) {
        void toggle() {
          if (controller.isOpen) {
            _keepOpen = false;
            controller.close();
          } else {
            _keepOpen = true;
            controller.open();
          }
        }

        final tvMeta = widget.tvTabId != null && widget.useTvCompact
            ? ShellTvFocusMeta(
                tabId: widget.tvTabId!,
                zone: widget.tvItemIndex != null
                    ? ShellTvZone.row
                    : ShellTvZone.hero,
                rowId: widget.tvItemIndex != null
                    ? MediaDetailsTv.heroRowId
                    : null,
                itemIndex: widget.tvItemIndex,
              )
            : null;
        final onKey = widget.onUpEdge != null
            ? (FocusNode node, KeyEvent event) => shellTvHandleRowArrows(
                  event: event,
                  tvMeta: tvMeta,
                  onUpEdge: widget.onUpEdge,
                )
            : null;

        return ForjaInteractive(
          onTap: toggle,
          hoverScale: 1.03,
          pressScale: 0.97,
          tvMeta: tvMeta,
          onKeyEvent: onKey,
          builder: (hover, pressed) {
            return HeroPillSegmentSurface(
              label: chipLabel,
              icon: widget.icon,
              selected: active,
              lit: hover || pressed || controller.isOpen,
              pressed: pressed,
              isFirst: widget.isFirst,
              isLast: widget.isLast,
            );
          },
        );
      },
    );
  }
}
