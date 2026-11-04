import 'package:flutter/material.dart' hide Switch;
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/l10n/l10n.dart';
import 'package:forja/shared/services/app/app_locale.dart';

/// App language picker: the device language, or one of the translated languages.
class SettingsLanguageGroup extends StatelessWidget {
  const SettingsLanguageGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final systemLabel = l10n.settingsLanguageSystemDefault;
    final names = <String, String>{
      systemLabel: AppLocale.system,
      for (final locale in AppLocalizations.supportedLocales)
        AppLocale.nativeNames[locale.languageCode] ?? locale.languageCode:
            locale.languageCode,
    };
    return ValueListenableBuilder<Locale?>(
      valueListenable: AppLocale.notifier,
      builder: (context, _, _) {
        final current = names.entries
            .firstWhere(
              (e) => e.value == AppLocale.code,
              orElse: () => names.entries.first,
            )
            .key;
        return SettingsGroup(
          label: l10n.settingsLanguageGroupLabel,
          children: [
            SettingsSelectRow(
              title: l10n.settingsLanguageRowTitle,
              subtitle: l10n.settingsLanguageRowSubtitle,
              value: current,
              options: names.keys.toList(),
              onChanged: (picked) {
                final code = names[picked];
                if (code != null) AppLocale.select(code);
              },
            ),
          ],
        );
      },
    );
  }
}
