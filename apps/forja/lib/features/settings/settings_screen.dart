import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/pages/settings_category_bodies.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/widgets/settings_hub_scaffold.dart';
import 'package:forja/shell/app_router.dart';
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
    TvHeroActions.bind(
      'settings',
      defaultFocus: () => _firstHubFocus,
      enterFromNavFocus: () {
        if (_firstHubFocus.canRequestFocus) {
          _firstHubFocus.requestFocus();
        }
      },
      restoreFocus: () {
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
    ShellTvFocusCoordinator.clearTab('settings');
    _firstHubFocus.dispose();
    super.dispose();
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
