import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_updater_service.dart';
import 'package:forja/shared/telemetry/product_analytics.dart';
import 'package:forja/shared/telemetry/telemetry.dart';
import 'package:forja/shared/widgets/update_dialog.dart';
import 'package:rust/rust.dart';

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
          const Text(
            'Check for new versions of Forja',
            style: TextStyle(
              fontSize: 13,
              color: ForjaShellColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SettingsFilledButton(
            label: _isChecking ? 'Checking...' : 'Check for Updates',
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
      final updateInfo = await _updater.checkForUpdates();

      if (mounted) {
        setState(() => _isChecking = false);

        if (updateInfo != null) {
          unawaited(UpdateDialog.show(context, updateInfo));
        } else {
          ForjaToast.success("You're running the latest version!");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChecking = false);
        ForjaToast.error('Failed to check for updates: $e');
      }
    }
  }
}

/// Opt-in Sentry crash reporting (RFC-043).
class SettingsCrashReportingRow extends StatefulWidget {
  const SettingsCrashReportingRow({super.key});

  @override
  State<SettingsCrashReportingRow> createState() =>
      _SettingsCrashReportingRowState();
}

class _SettingsCrashReportingRowState extends State<SettingsCrashReportingRow> {
  bool _crashReporting = false;
  bool _loaded = false;
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final enabled = await _settings.isCrashReportingEnabled();
    if (!mounted) return;
    setState(() {
      _crashReporting = enabled;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return SettingsToggleRow(
      title: 'Crash reporting',
      subtitle: Telemetry.isConfigured
          ? 'Send anonymized crash reports to help fix bugs. Off by default.'
          : 'Unavailable in this build (no Sentry DSN). Preference still saved.',
      value: _crashReporting,
      onChanged: _setCrashReporting,
    );
  }

  Future<void> _setCrashReporting(bool value) async {
    setState(() => _crashReporting = value);
    await Telemetry.setEnabled(value);
    if (!mounted) return;
    if (value && !Telemetry.isConfigured) {
      ForjaToast.info(
        'Crash reporting will activate once this build includes a Sentry DSN.',
      );
    } else if (value && Telemetry.isActive) {
      ForjaToast.success('Crash reporting on');
    } else if (!value) {
      ForjaToast.success('Crash reporting off');
    }
  }
}

/// Opt-in PostHog product analytics (RFC-043).
class SettingsProductAnalyticsRow extends StatefulWidget {
  const SettingsProductAnalyticsRow({super.key});

  @override
  State<SettingsProductAnalyticsRow> createState() =>
      _SettingsProductAnalyticsRowState();
}

class _SettingsProductAnalyticsRowState
    extends State<SettingsProductAnalyticsRow> {
  bool _enabled = false;
  bool _loaded = false;
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final enabled = await _settings.isProductAnalyticsEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return SettingsToggleRow(
      title: 'Product analytics',
      subtitle: ProductAnalytics.isConfigured
          ? 'Anonymous usage events + session replay (text/images masked). Off by default.'
          : 'Unavailable in this build (no PostHog API key). Preference still saved.',
      value: _enabled,
      onChanged: _setEnabled,
    );
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    await Telemetry.setAnalyticsEnabled(value);
    if (!mounted) return;
    if (value && !ProductAnalytics.isConfigured) {
      ForjaToast.info(
        'Analytics will activate once this build includes a PostHog API key.',
      );
    } else if (value && ProductAnalytics.isActive) {
      ForjaToast.success('Product analytics on');
    } else if (!value) {
      ForjaToast.success('Product analytics off');
    }
  }
}
