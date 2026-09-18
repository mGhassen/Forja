import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/addons/addons_host.dart';
import 'package:forja/features/settings/about/page.dart';
import 'package:forja/features/settings/data/page.dart';
import 'package:forja/features/settings/features/page.dart';
import 'package:forja/features/settings/packs/page.dart';
import 'package:forja/features/settings/profile/page.dart';
import 'package:forja/features/settings/shell/catalog.dart';
import 'package:forja/features/settings/shell/visibility.dart';
import 'package:forja/features/settings/shell/visibility_provider.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

Widget buildSettingsCategoryBody(
  String categoryId,
  SettingsVisibility visibility,
) {
  switch (categoryId) {
    case SettingsCategoryId.profile:
      return const SettingsProfileAccountPageBody();
    case SettingsCategoryId.sources:
      return SettingsAddonsHost(visibility: visibility);
    case SettingsCategoryId.forjaPacks:
      return SettingsForjaPacksPageBody(visibility: visibility);
    case SettingsCategoryId.data:
      return SettingsDataPageBody(visibility: visibility);
    case SettingsCategoryId.navigation:
      return const SettingsNavigationPageBody();
    case SettingsCategoryId.about:
      return const SettingsAboutPageBody();
    default:
      return const SizedBox.shrink();
  }
}

/// Pushed detail route for mobile / TV.
class SettingsCategoryPage extends ConsumerStatefulWidget {
  const SettingsCategoryPage({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<SettingsCategoryPage> createState() =>
      _SettingsCategoryPageState();
}

class _SettingsCategoryPageState extends ConsumerState<SettingsCategoryPage> {
  SettingsVisibility? _visibility;

  @override
  Widget build(BuildContext context) {
    final visibilityAsync = ref.watch(settingsVisibilityProvider);
    ref.listen(settingsVisibilityProvider, (_, next) {
      next.whenData((v) {
        if (!mounted || _visibility == v) return;
        setState(() => _visibility = v);
      });
    });
    // Keep last visibility while navbar/pack reloads — blanking remounts the
    // body and drops Forja Packs mid-remove (same as hub scaffold / 224).
    final visibility = visibilityAsync.valueOrNull ?? _visibility;
    if (visibility == null) {
      return const Scaffold(
        backgroundColor: ForjaShellColors.bgDark,
        body: SizedBox.expand(),
      );
    }
    final meta = settingsCategoryById(widget.categoryId, visibility);
    return Scaffold(
      // Overlay sits above the Settings hub Stack — must be opaque or the
      // category list bleeds through on compact list→push.
      backgroundColor: ForjaShellColors.bgDark,
      body: ShellTvContainDpad(
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: SettingsAddonsAwareScaffold(
            categoryTitle: meta?.title ?? 'Settings',
            categoryId: widget.categoryId,
            categoryAdminOnly: meta?.adminOnly ?? false,
            categoryBack: true,
            scrollable: !(meta?.fillViewport ?? false),
            child: buildSettingsCategoryBody(widget.categoryId, visibility),
          ),
        ),
      ),
    );
  }
}
