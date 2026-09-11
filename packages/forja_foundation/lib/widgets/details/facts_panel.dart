import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/details/meta_line.dart';

/// Right-column production metadata on a details hero — label/value rows only.
class FactsPanel extends StatelessWidget {
  const FactsPanel({
    super.key,
    required this.rows,
    this.valueMaxLines = 1,
  });

  /// Builds movie/TV fact rows from primitive fields (no host `Movie`).
  factory FactsPanel.fromFields({
    Key? key,
    required String title,
    String mediaType = '',
    int runtimeMinutes = 0,
    String releaseDate = '',
    int seasonCount = 0,
    int episodeCount = 0,
    String? status,
    int? budget,
    int? revenue,
    String? languageCode,
    List<String> spokenLanguages = const [],
    List<String> productionCompanies = const [],
    List<String> originCountries = const [],
    String? lastAirDate,
    List<String> networks = const [],
    List<String> creators = const [],
    int? positionMs,
    int? durationMs,
    int valueMaxLines = 1,
  }) {
    return FactsPanel(
      key: key,
      rows: factsRowsFromFields(
        title: title,
        mediaType: mediaType,
        runtimeMinutes: runtimeMinutes,
        releaseDate: releaseDate,
        seasonCount: seasonCount,
        episodeCount: episodeCount,
        status: status,
        budget: budget,
        revenue: revenue,
        languageCode: languageCode,
        spokenLanguages: spokenLanguages,
        productionCompanies: productionCompanies,
        originCountries: originCountries,
        lastAirDate: lastAirDate,
        networks: networks,
        creators: creators,
        positionMs: positionMs,
        durationMs: durationMs,
      ),
      valueMaxLines: valueMaxLines,
    );
  }

  final List<({String label, String value})> rows;
  final int valueMaxLines;

  bool get hasContent =>
      rows.any((r) => r.label.trim().isNotEmpty && r.value.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final visible = rows
        .where((r) => r.label.trim().isNotEmpty && r.value.trim().isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    const radius = 12.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                i == 0 ? 16 : 10,
                20,
                i == visible.length - 1 ? 16 : 10,
              ),
              child: _FactRow(
                label: visible[i].label,
                value: visible[i].value,
                valueMaxLines: valueMaxLines,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

List<({String label, String value})> factsRowsFromFields({
  required String title,
  String mediaType = '',
  int runtimeMinutes = 0,
  String releaseDate = '',
  int seasonCount = 0,
  int episodeCount = 0,
  String? status,
  int? budget,
  int? revenue,
  String? languageCode,
  List<String> spokenLanguages = const [],
  List<String> productionCompanies = const [],
  List<String> originCountries = const [],
  String? lastAirDate,
  List<String> networks = const [],
  List<String> creators = const [],
  int? positionMs,
  int? durationMs,
}) {
  final isTv = mediaType == 'tv';
  final name = title.trim();
  final nameLabel = (name.isEmpty || name == 'Unknown') ? '' : name;
  final statusLabel = status?.trim() ?? '';
  final languageLabel = () {
    final code = languageCode?.trim();
    if (code != null && code.isNotEmpty) return code.toUpperCase();
    if (spokenLanguages.isNotEmpty) {
      return spokenLanguages.first.length <= 3
          ? spokenLanguages.first.toUpperCase()
          : spokenLanguages.first;
    }
    return '';
  }();
  final firstAired = _formatReleaseDate(releaseDate);
  final lastAired = isTv ? _formatReleaseDate(lastAirDate ?? '') : '';
  final seasons = (isTv && seasonCount > 0) ? '$seasonCount' : '';
  final episodes = (isTv && episodeCount > 0) ? '$episodeCount' : '';
  final network = networks.where((s) => s.trim().isNotEmpty).join(', ');
  final production =
      productionCompanies.where((s) => s.trim().isNotEmpty).join(', ');
  final origin = originCountries.where((s) => s.trim().isNotEmpty).join(', ');
  final created =
      isTv ? creators.where((s) => s.trim().isNotEmpty).join(', ') : '';
  final runtimeLabel = isTv
      ? ''
      : _runtimeWithEnds(
          runtimeMinutes,
          positionMs: positionMs,
          durationMs: durationMs,
        );
  final budgetLabel = isTv ? '' : _formatMoney(budget);
  final revenueLabel = isTv ? '' : _formatMoney(revenue);

  return [
    if (nameLabel.isNotEmpty) (label: 'Name', value: nameLabel),
    if (statusLabel.isNotEmpty) (label: 'Status', value: statusLabel),
    if (languageLabel.isNotEmpty) (label: 'Language', value: languageLabel),
    if (isTv) ...[
      if (firstAired.isNotEmpty) (label: 'First Aired', value: firstAired),
      if (lastAired.isNotEmpty) (label: 'Last Aired', value: lastAired),
      if (seasons.isNotEmpty) (label: 'Seasons', value: seasons),
      if (episodes.isNotEmpty) (label: 'Episodes', value: episodes),
      if (network.isNotEmpty) (label: 'Network', value: network),
    ] else ...[
      if (firstAired.isNotEmpty) (label: 'Release Date', value: firstAired),
      if (runtimeLabel.isNotEmpty) (label: 'Runtime', value: runtimeLabel),
    ],
    if (production.isNotEmpty) (label: 'Production', value: production),
    if (origin.isNotEmpty) (label: 'Origin', value: origin),
    if (created.isNotEmpty) (label: 'Created by', value: created),
    if (budgetLabel.isNotEmpty) (label: 'Budget', value: budgetLabel),
    if (revenueLabel.isNotEmpty) (label: 'Revenue', value: revenueLabel),
  ];
}

String _runtimeWithEnds(
  int runtimeMinutes, {
  int? positionMs,
  int? durationMs,
}) {
  final runtime = MetaLine.formatRuntime(runtimeMinutes);
  if (runtime.isEmpty) return '';
  final remainingMs = (positionMs != null && durationMs != null)
      ? durationMs - positionMs
      : null;
  if (remainingMs != null && remainingMs > 0) {
    final ends = DateTime.now().add(Duration(milliseconds: remainingMs));
    final hour =
        ends.hour > 12 ? ends.hour - 12 : (ends.hour == 0 ? 12 : ends.hour);
    final minute = ends.minute.toString().padLeft(2, '0');
    final period = ends.hour >= 12 ? 'PM' : 'AM';
    return '$runtime • Ends $hour:$minute $period';
  }
  return runtime;
}

String _formatReleaseDate(String iso) {
  if (iso.length < 10) return iso;
  try {
    final d = DateTime.parse(iso);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) {
    return iso;
  }
}

String _formatMoney(int? amount) {
  if (amount == null || amount <= 0) return '';
  final s = amount.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '\$${buf.toString()}';
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    required this.value,
    required this.valueMaxLines,
  });

  final String label;
  final String value;
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: valueMaxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
