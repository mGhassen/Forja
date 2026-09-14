import 'package:flutter/material.dart';
import 'package:forja/shell/filters/vertical_filters.dart';

/// Hub `vertical_filters` — registers for shell [VerticalFiltersRail]; body empty.
class PackVerticalFiltersSlot extends StatefulWidget {
  const PackVerticalFiltersSlot({
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
  State<PackVerticalFiltersSlot> createState() =>
      _PackVerticalFiltersSlotState();
}

class _PackVerticalFiltersSlotState extends State<PackVerticalFiltersSlot> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant PackVerticalFiltersSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec != widget.spec ||
        oldWidget.pluginId != widget.pluginId ||
        oldWidget.tabId != widget.tabId) {
      _sync();
    }
  }

  void _sync() {
    final tabId = widget.tabId?.trim() ?? '';
    if (tabId.isEmpty) return;
    VerticalFiltersRegistry.register(
      VerticalFiltersSpec.fromWidget(
        widget: widget.spec,
        tabId: tabId,
        pluginId: widget.pluginId,
        packSourceUrl: widget.packSourceUrl ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
