import 'package:flutter/material.dart';
import 'package:forja/features/settings/profile/account_panel.dart';
import 'package:forja/features/settings/profile/language_group.dart';

class SettingsProfileAccountPageBody extends StatelessWidget {
  const SettingsProfileAccountPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(2, 8, 2, 0),
          child: SettingsLanguageGroup(),
        ),
        SettingsForjaAccountPanel(),
      ],
    );
  }
}
