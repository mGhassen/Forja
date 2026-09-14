import 'dart:math';

import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_load_paint.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shell/core/forja_shell_layout.dart';
import 'package:forja_foundation/components/mood_circle.dart';
import 'package:forja_foundation/widgets/catalog/category_circle_meta.dart';
import 'package:forja_foundation/widgets/catalog/mood_section.dart';

Color? _parseAccent(Object? raw) {
  final s = (raw ?? '').toString().trim();
  if (s.isEmpty) return null;
  var hex = s;
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  final v = int.tryParse(hex, radix: 16);
  if (v == null) return null;
  return Color(v);
}

String? _randomMoodOptionId(List options) {
  final ids = <String>[
    for (final o in options)
      if (o is Map && o['id'] != null) o['id'].toString(),
  ];
  if (ids.isEmpty) return null;
  return ids[Random().nextInt(ids.length)];
}

/// Hub `mood` slot — pack options chips + optional results via pack `load`.
class PackMoodSlot extends StatefulWidget {
  const PackMoodSlot({
    super.key,
    required this.spec,
    required this.pluginId,
    this.packSourceUrl,
    this.tabId,
  });

  final Map<String, dynamic> spec;
  final String pluginId;
  final String? packSourceUrl;
  final String? tabId;

  @override
  State<PackMoodSlot> createState() => _PackMoodSlotState();
}

class _PackMoodSlotState extends State<PackMoodSlot> {
  String? _selectedId;
  bool _pickedDefault = false;

  @override
  void initState() {
    super.initState();
    _ensureDefault();
  }

  @override
  void didUpdateWidget(covariant PackMoodSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec != widget.spec) {
      _pickedDefault = false;
      _ensureDefault();
    }
  }

  void _ensureDefault() {
    if (_pickedDefault) return;
    final options = widget.spec['options'];
    if (options is! List || options.isEmpty) return;
    _pickedDefault = true;
    _selectedId = _randomMoodOptionId(options);
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.spec['options'];
    if (options is! List || options.isEmpty) return const SizedBox.shrink();
    final title = (widget.spec['title'] ?? '').toString();
    final pad = shellHomeSectionHorizontalPadding(context);

    final chips = <Widget>[];
    for (final raw in options) {
      if (raw is! Map) continue;
      final opt = Map<String, dynamic>.from(raw);
      final id = (opt['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final selected = _selectedId == id;
      final token = kitMoodIconToken(opt['icon']?.toString() ?? id);
      final accent = _parseAccent(opt['accent']) ?? token.accent;
      chips.add(
        MoodCircle(
          label: (opt['label'] ?? id).toString(),
          selected: selected,
          active: selected,
          accent: accent,
          icon: token.icon,
          layout: MoodCircleLayout.desktop,
          onTap: () => setState(() {
            _selectedId = id;
          }),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    Widget? results;
    final load = packLoadSpec(widget.spec['load']);
    if (_selectedId != null && load != null) {
      results = PackLoadedPaint(
        pluginId: widget.pluginId,
        packSourceUrl: widget.packSourceUrl,
        tabId: widget.tabId,
        action: load.action,
        params: {
          ...load.params,
          'filter': {'field': 'mood', 'value': _selectedId},
        },
        fallbackSpec: const {'type': 'rail', 'title': ''},
        builder: (ctx, merged) => PackPaintArtifact.posterRow(
          ctx,
          node: merged,
          pluginId: widget.pluginId,
        ),
      );
    }

    return MoodSection(
      title: title.isEmpty ? null : title,
      titlePadding: EdgeInsets.fromLTRB(
        pad,
        shellHomeSectionTitleTop(context),
        pad,
        shellHomeSectionBottomGap(context),
      ),
      padding: EdgeInsets.symmetric(horizontal: pad),
      results: results,
      children: chips,
    );
  }
}
