import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/features/iptv/iptv/data/iptv_portal_csv.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';

/// Settings → Data & backup — export / import Xtream portals as CSV.
class SettingsIptvPortalsSection extends StatefulWidget {
  const SettingsIptvPortalsSection({super.key});

  @override
  State<SettingsIptvPortalsSection> createState() =>
      _SettingsIptvPortalsSectionState();
}

class _SettingsIptvPortalsSectionState extends State<SettingsIptvPortalsSection> {
  bool _exporting = false;
  bool _importing = false;
  List<MergePortalsCsvLogEntry>? _log;
  String? _logSummary;
  String? _error;

  Future<void> _exportCsv() async {
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      final portals = await IptvStore.load();
      if (portals.isEmpty) {
        if (mounted) ForjaToast.info('No IPTV portals to export');
        return;
      }
      final favorites = await IptvStore.loadFavorites();
      final csv = portalsToCsv(portals: portals, favoriteKeys: favorites);
      final fileName = iptvPortalsCsvFilename();
      final bytes = Uint8List.fromList(utf8.encode(csv));

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export IPTV portals',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );

      if (result != null) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          await File(result).writeAsString(csv);
        }
      }

      if (result != null && mounted) {
        ForjaToast.success(
          'Exported ${portals.length} portal${portals.length == 1 ? '' : 's'}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Export failed: $e');
        ForjaToast.error('Export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importCsv() async {
    final pick = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import IPTV portals',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (pick == null || pick.files.isEmpty) return;

    final file = pick.files.single;
    final String text;
    if (file.bytes != null) {
      text = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      text = await File(file.path!).readAsString();
    } else {
      if (mounted) ForjaToast.error('Could not read file.');
      return;
    }

    setState(() {
      _importing = true;
      _error = null;
      _log = null;
      _logSummary = null;
    });

    try {
      final parsed = parsePortalsCsv(text);
      final existing = await IptvStore.load();
      final favorites = await IptvStore.loadFavorites();
      final merged = mergePortalsFromCsv(
        existingPortals: existing,
        existingFavorites: favorites,
        parsed: parsed.portals,
      );

      if (merged.added > 0) {
        await IptvStore.save(merged.portals);
        await IptvStore.saveFavorites(merged.favoriteKeys);
        IptvStore.notifyListChanged();
      }

      final parts = <String>[
        if (merged.added > 0) '${merged.added} added',
        if (merged.skippedExisting > 0)
          '${merged.skippedExisting} already present',
        if (parsed.skipped > 0) '${parsed.skipped} invalid',
      ];
      final summary = parts.isEmpty
          ? 'No changes'
          : parts.join(' · ');

      if (!mounted) return;
      setState(() {
        _log = merged.log;
        _logSummary = summary;
      });

      if (merged.added > 0) {
        ForjaToast.success('$summary — open IPTV to browse');
      } else {
        ForjaToast.info(summary);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is StateError ? e.message : 'Import failed: $e';
          _log = null;
          _logSummary = null;
        });
        ForjaToast.error(_error!);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      label: 'IPTV portals',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Export or import Xtream portals as a CSV file. The file '
                'includes passwords in plain text — keep it private. On this '
                'device, portal passwords are stored in the system Keychain / '
                'Keystore. Import adds only portals that are not already saved.',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SettingsFilledButton(
                    label: 'Import CSV',
                    icon: Icons.upload_file_rounded,
                    secondary: true,
                    busy: _importing,
                    onPressed: _importing || _exporting ? null : _importCsv,
                  ),
                  const SizedBox(width: 12),
                  SettingsFilledButton(
                    label: 'Export CSV',
                    icon: Icons.download_rounded,
                    busy: _exporting,
                    onPressed: _importing || _exporting ? null : _exportCsv,
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFF87171),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
              if (_log != null) ...[
                const SizedBox(height: 14),
                _ImportLogPanel(
                  summary: _logSummary ?? '',
                  log: _log!,
                  onClose: () => setState(() {
                    _log = null;
                    _logSummary = null;
                  }),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ImportLogPanel extends StatelessWidget {
  const _ImportLogPanel({
    required this.summary,
    required this.log,
    required this.onClose,
  });

  final String summary;
  final List<MergePortalsCsvLogEntry> log;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ForjaShellColors.inkHover.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ForjaShellColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import log',
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary.withValues(
                            alpha: 0.85,
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: const TextStyle(
                            color: ForjaShellColors.brandGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close import log',
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: ForjaShellColors.iconMuted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ForjaShellColors.borderSubtle),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shrinkWrap: true,
              itemCount: log.length,
              itemBuilder: (context, index) {
                final entry = log[index];
                final added = entry.status == 'added';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          (index + 1).toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: ForjaShellColors.textSecondary.withValues(
                              alpha: 0.45,
                            ),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          added ? 'added' : 'skip',
                          style: TextStyle(
                            color: added
                                ? ForjaShellColors.brandGreen
                                : ForjaShellColors.textSecondary,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: entry.label,
                                style: const TextStyle(
                                  color: ForjaShellColors.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                              TextSpan(
                                text: '  ${entry.username}@${entry.url}',
                                style: TextStyle(
                                  color: ForjaShellColors.textSecondary
                                      .withValues(alpha: 0.55),
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              if (!added)
                                TextSpan(
                                  text: '  already present',
                                  style: TextStyle(
                                    color: const Color(0xFFFBBF24)
                                        .withValues(alpha: 0.9),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
