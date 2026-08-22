import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/pages/settings_category_bodies.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/widgets/settings_hub_scaffold.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/telemetry/product_analytics.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

/// Settings tab - RFC-033 category hub; RFC-024 R24-A13: local prefs only.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedId = SettingsCategoryId.profile;
  final FocusNode _firstHubFocus = FocusNode(debugLabel: 'settings-hub-0');

  @override
  void initState() {
    super.initState();
    final pending = ShellBus.requestSettingsCategory.value;
    if (pending != null) {
      _selectedId = pending;
      ShellBus.requestSettingsCategory.value = null;
    }
    ShellBus.requestSettingsCategory.addListener(_applyRequestedCategory);
    TvHeroActions.bind(
      'settings',
      defaultFocus: () => _firstHubFocus,
      enterFromNavFocus: () {
        if (!ShellScope.metricsOf(context).usesTvDensity) return;
        if (_firstHubFocus.canRequestFocus) {
          _firstHubFocus.requestFocus();
        }
      },
      restoreFocus: () {
        if (!ShellScope.metricsOf(context).usesTvDensity) return false;
        if (_firstHubFocus.canRequestFocus) {
          _firstHubFocus.requestFocus();
          return true;
        }
        return false;
      },
    );
  }

  @override
  void dispose() {
    ShellBus.requestSettingsCategory.removeListener(_applyRequestedCategory);
    ShellTvFocusCoordinator.clearTab('settings');
    _firstHubFocus.dispose();
    super.dispose();
  }

  void _applyRequestedCategory() {
    final id = ShellBus.requestSettingsCategory.value;
    if (id == null || !mounted) return;
    ShellBus.requestSettingsCategory.value = null;
    if (id == _selectedId) return;
    setState(() => _selectedId = id);
  }

  void _onSelect(String id) {
    unawaited(ProductAnalytics.screen('settings/$id'));
    if (SettingsTokens.useSplitLayout(context)) {
      setState(() => _selectedId = id);
      return;
    }
    pushShellRoute(
      context,
      AppRouter.slideShellRoute(
        (_) => SettingsCategoryPage(categoryId: id),
        settings: RouteSettings(name: 'settings/$id'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsHubScaffold(
      selectedId: _selectedId,
      onSelect: _onSelect,
      firstTileFocusNode: _firstHubFocus,
    );
  }
}
