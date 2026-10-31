import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/l10n/l10n.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shared/services/update/app_updater_service.dart';
import 'package:forja/shared/telemetry/product_analytics.dart';
import 'package:forja/shared/telemetry/telemetry.dart';
import 'package:forja/features/settings/about/macos_keychain_consent_screen.dart';
import 'package:forja/shell/update/update_dialog.dart';
import 'package:rust/rust.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';

class SettingsAboutPanel extends StatefulWidget {
  const SettingsAboutPanel({super.key});

  @override
  State<SettingsAboutPanel> createState() => _SettingsAboutPanelState();
}

class _SettingsAboutPanelState extends State<SettingsAboutPanel> {
  bool _isChecking = false;
  final AppUpdaterService _updater = AppUpdaterService();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.aboutCheckForUpdatesBlurb,
            style: TextStyle(
              fontSize: SettingsTokens.typeSizeOf(context, 13),
              color: ForjaShellColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SettingsFilledButton(
            label: _isChecking
                ? context.l10n.aboutCheckingButton
                : context.l10n.aboutCheckForUpdatesButton,
            icon: Icons.system_update_rounded,
            busy: _isChecking,
            onPressed: _isChecking ? null : _checkForUpdates,
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isChecking = true);

    try {
      final result = await _updater.checkForUpdates();

      if (mounted) {
        setState(() => _isChecking = false);

        if (result.isAvailable && result.info != null) {
          unawaited(UpdateDialog.show(context, result.info!));
        } else if (result.isFailed) {
          ForjaToast.error(
            result.failureMessage ?? context.l10n.aboutCheckForUpdatesFailed,
          );
        } else {
        ForjaToast.success(context.l10n.aboutUpToDate);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChecking = false);
        ForjaToast.error(context.l10n.aboutCheckForUpdatesError('$e'));
      }
    }
  }
}

/// Opt-in Sentry crash reporting (RFC-043).
class SettingsCrashReportingRow extends ConsumerStatefulWidget {
  const SettingsCrashReportingRow({super.key});

  @override
  ConsumerState<SettingsCrashReportingRow> createState() =>
      _SettingsCrashReportingRowState();
}

class _SettingsCrashReportingRowState
    extends ConsumerState<SettingsCrashReportingRow> {
  /// Optimistic value — same pattern as Playback toggles. Do not wait on
  /// [crashReportingEnabledProvider] invalidate (fallback `true` + Sentry
  /// close latency made the switch look stuck ON while KV was already off).
  bool? _override;

  @override
  Widget build(BuildContext context) {
    final enabled =
        _override ?? ref.watch(crashReportingEnabledProvider).valueOrNull;
    if (enabled == null) return const SizedBox.shrink();
    return SettingsToggleRow(
      title: context.l10n.aboutCrashReportingTitle,
      subtitle: kDebugMode
          ? context.l10n.aboutTelemetryDebugSubtitle
          : Telemetry.isConfigured
          ? context.l10n.aboutCrashReportingSubtitle
          : context.l10n.aboutTelemetryUnavailableSubtitle,
      value: enabled,
      onChanged: _setCrashReporting,
    );
  }

  Future<void> _setCrashReporting(bool value) async {
    setState(() => _override = value);
    try {
      await Telemetry.setEnabled(value);
      ref.invalidate(crashReportingEnabledProvider);
      if (!mounted) return;
      if (value && kDebugMode) {
        ForjaToast.info(context.l10n.aboutCrashReportingSavedDebug);
      } else if (value && !Telemetry.isConfigured) {
        ForjaToast.info(context.l10n.aboutCrashReportingUnavailable);
      } else if (value && Telemetry.isActive) {
        ForjaToast.success(context.l10n.aboutCrashReportingOn);
      } else if (!value) {
        ForjaToast.success(context.l10n.aboutCrashReportingOff);
      }
    } catch (e, st) {
      debugPrint('[About] crash reporting toggle failed: $e\n$st');
      if (!mounted) return;
      setState(() => _override = null);
      ref.invalidate(crashReportingEnabledProvider);
      ForjaToast.error(context.l10n.aboutCrashReportingUpdateFailed);
    }
  }
}

/// Opt-in PostHog product analytics (RFC-043).
class SettingsProductAnalyticsRow extends ConsumerStatefulWidget {
  const SettingsProductAnalyticsRow({super.key});

  @override
  ConsumerState<SettingsProductAnalyticsRow> createState() =>
      _SettingsProductAnalyticsRowState();
}

class _SettingsProductAnalyticsRowState
    extends ConsumerState<SettingsProductAnalyticsRow> {
  bool? _override;

  @override
  Widget build(BuildContext context) {
    final enabled =
        _override ?? ref.watch(productAnalyticsEnabledProvider).valueOrNull;
    if (enabled == null) return const SizedBox.shrink();
    return SettingsToggleRow(
      title: context.l10n.aboutProductAnalyticsTitle,
      subtitle: kDebugMode
          ? context.l10n.aboutTelemetryDebugSubtitle
          : ProductAnalytics.isConfigured
          ? context.l10n.aboutProductAnalyticsSubtitle
          : context.l10n.aboutTelemetryUnavailableSubtitle,
      value: enabled,
      onChanged: _setEnabled,
    );
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _override = value);
    try {
      await Telemetry.setAnalyticsEnabled(value);
      ref.invalidate(productAnalyticsEnabledProvider);
      if (!mounted) return;
      if (value && kDebugMode) {
        ForjaToast.info(context.l10n.aboutProductAnalyticsSavedDebug);
      } else if (value && !ProductAnalytics.isConfigured) {
        ForjaToast.info(context.l10n.aboutProductAnalyticsUnavailable);
      } else if (value && ProductAnalytics.isActive) {
        ForjaToast.success(context.l10n.aboutProductAnalyticsOn);
      } else if (!value) {
        ForjaToast.success(context.l10n.aboutProductAnalyticsOff);
      }
    } catch (e, st) {
      debugPrint('[About] product analytics toggle failed: $e\n$st');
      if (!mounted) return;
      setState(() => _override = null);
      ref.invalidate(productAnalyticsEnabledProvider);
      ForjaToast.error(context.l10n.aboutProductAnalyticsUpdateFailed);
    }
  }
}

/// macOS only — opt into Keychain for secrets (default is local app file).
class SettingsMacOsKeychainRow extends ConsumerStatefulWidget {
  const SettingsMacOsKeychainRow({super.key});

  @override
  ConsumerState<SettingsMacOsKeychainRow> createState() =>
      _SettingsMacOsKeychainRowState();
}

class _SettingsMacOsKeychainRowState
    extends ConsumerState<SettingsMacOsKeychainRow> {
  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return const SizedBox.shrink();
    final enabled = ref.watch(macOsKeychainEnabledProvider).valueOrNull;
    if (enabled == null) return const SizedBox.shrink();
    return SettingsToggleRow(
      title: context.l10n.aboutKeychainRowTitle,
      subtitle: context.l10n.aboutKeychainRowSubtitle,
      value: enabled,
      onChanged: _setEnabled,
      adminOnly: true,
    );
  }

  Future<void> _setEnabled(bool value) async {
    if (value) {
      final result = await showMacOsKeychainConsentDialog(context);
      if (!mounted) return;
      final accepted = result == ForjaKeychainConsent.accepted;
      ref.invalidate(macOsKeychainEnabledProvider);
      if (accepted) {
        ForjaToast.success(context.l10n.aboutKeychainEnabled);
      }
      return;
    }
    await ForjaPlatformSecureStore.setKeychainConsent(
      ForjaKeychainConsent.declined,
    );
    ref.invalidate(macOsKeychainEnabledProvider);
    if (!mounted) return;
    ForjaToast.success(context.l10n.aboutKeychainLocalStorage);
  }
}
