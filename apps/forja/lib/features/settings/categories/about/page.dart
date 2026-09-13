import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/categories/about/about_panel.dart';
import 'package:forja/features/settings/chrome/settings_ui.dart';
import 'package:forja/shared/services/update/app_version.dart';
import 'package:forja/shared/telemetry/product_analytics.dart';
import 'package:forja/shared/telemetry/telemetry.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

class SettingsAboutPageBody extends ConsumerWidget {
  const SettingsAboutPageBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(accountFeaturesProvider).isAdmin;
    // Profile/release only — SDKs are hard-blocked in kDebugMode.
    final showDeveloperTools =
        isAdmin &&
        !kDebugMode &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(label: 'Updates', children: const [SettingsAboutPanel()]),
        SettingsGroup(
          label: 'Privacy',
          children: [
            const SettingsCrashReportingRow(),
            const SettingsProductAnalyticsRow(),
            if (isAdmin && Platform.isMacOS) const SettingsMacOsKeychainRow(),
          ],
        ),
        if (showDeveloperTools)
          SettingsGroup(
            label: 'Developer',
            children: [
              SettingsActionRow(
                leading: const Icon(
                  Icons.bug_report_outlined,
                  color: ForjaShellColors.iconActive,
                ),
                title: 'Verify Sentry',
                subtitle: Telemetry.isActive
                    ? 'Send a test exception to the Forja Flutter project'
                    : 'Enable Crash reporting first, then tap again',
                adminOnly: true,
                onTap: () async {
                  try {
                    await Telemetry.sendTestException();
                    ForjaToast.success('Test event sent - check Sentry Issues');
                  } catch (e) {
                    ForjaToast.info('$e');
                  }
                },
              ),
              SettingsActionRow(
                leading: const Icon(
                  Icons.insights_outlined,
                  color: ForjaShellColors.iconActive,
                ),
                title: 'Verify PostHog',
                subtitle: Telemetry.isAnalyticsActive
                    ? 'Send analytics_verify to your PostHog project'
                    : 'Enable Product analytics first, then tap again',
                adminOnly: true,
                onTap: () async {
                  try {
                    await ProductAnalytics.sendTestEvent();
                    ForjaToast.success(
                      'Test event sent - check PostHog → Activity',
                    );
                  } catch (e) {
                    ForjaToast.info('$e');
                  }
                },
              ),
            ],
          ),
        const SizedBox(height: 24),
        Center(
          child: AppVersionLabel(
            style: TextStyle(
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 13,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
