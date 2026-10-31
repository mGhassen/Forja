import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/about/about_panel.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/l10n/l10n.dart';
import 'package:forja/shared/services/update/app_version.dart';
import 'package:forja/shared/telemetry/product_analytics.dart';
import 'package:forja/shared/telemetry/telemetry.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';

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
        SettingsGroup(
          label: context.l10n.aboutUpdatesGroupLabel,
          children: const [SettingsAboutPanel()],
        ),
        SettingsGroup(
          label: context.l10n.aboutPrivacyGroupLabel,
          children: [
            const SettingsCrashReportingRow(),
            const SettingsProductAnalyticsRow(),
            if (isAdmin && Platform.isMacOS) const SettingsMacOsKeychainRow(),
          ],
        ),
        if (showDeveloperTools)
          SettingsGroup(
            label: context.l10n.aboutDeveloperGroupLabel,
            children: [
              SettingsActionRow(
                leading: const Icon(
                  Icons.bug_report_outlined,
                  color: ForjaShellColors.iconActive,
                ),
                title: context.l10n.aboutVerifySentryTitle,
                subtitle: Telemetry.isActive
                    ? context.l10n.aboutVerifySentrySubtitleActive
                    : context.l10n.aboutVerifySentrySubtitleInactive,
                adminOnly: true,
                onTap: () async {
                  final sentMessage = context.l10n.aboutVerifySentrySent;
                  try {
                    await Telemetry.sendTestException();
                    ForjaToast.success(sentMessage);
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
                title: context.l10n.aboutVerifyPostHogTitle,
                subtitle: Telemetry.isAnalyticsActive
                    ? context.l10n.aboutVerifyPostHogSubtitleActive
                    : context.l10n.aboutVerifyPostHogSubtitleInactive,
                adminOnly: true,
                onTap: () async {
                  final sentMessage = context.l10n.aboutVerifyPostHogSent;
                  try {
                    await ProductAnalytics.sendTestEvent();
                    ForjaToast.success(sentMessage);
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
              fontSize: SettingsTokens.typeSizeOf(context, 13),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
