import 'package:flutter/material.dart';
import 'package:forja/features/settings/categories/packs/packs_section.dart';
import 'package:forja/features/settings/hub/visibility.dart';

class SettingsForjaPacksPageBody extends StatelessWidget {
  const SettingsForjaPacksPageBody({super.key, required this.visibility});

  final SettingsVisibility visibility;

  @override
  Widget build(BuildContext context) {
    return SettingsForjaPacksSection(visibility: visibility);
  }
}
