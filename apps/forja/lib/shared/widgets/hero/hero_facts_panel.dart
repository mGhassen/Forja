import 'package:flutter/material.dart';
import 'package:forja/shared/widgets/hero/hero_meta_line.dart';
import 'package:rust/rust.dart';

/// Right-column production metadata panel on media details hero.
class HeroFactsPanel extends StatelessWidget {
  const HeroFactsPanel({
    super.key,
    required this.movie,
    this.status,
    this.budget,
    this.revenue,
    this.languageCode,
    this.spokenLanguages = const [],
    this.productionCompanies = const [],
    this.originCountries = const [],
    this.lastAirDate,
    this.networks = const [],
    this.creators = const [],
    this.positionMs,
    this.durationMs,
  });

  final Movie movie;
  final String? status;
  final int? budget;
  final int? revenue;
  final String? languageCode;
  final List<String> spokenLanguages;
  final List<String> productionCompanies;
  final List<String> originCountries;
  final String? lastAirDate;
  final List<String> networks;
  final List<String> creators;
  final int? positionMs;
  final int? durationMs;

  bool get _isTv => movie.mediaType == 'tv';

  bool get hasContent =>
      _statusLabel.isNotEmpty ||
      _runtimeLabel.isNotEmpty ||
      _languageLabel.isNotEmpty ||
      _firstAiredLabel.isNotEmpty ||
      _lastAiredLabel.isNotEmpty ||
      _seasonsLabel.isNotEmpty ||
      _episodesLabel.isNotEmpty ||
      _networkLabel.isNotEmpty ||
      _productionLabel.isNotEmpty ||
      _originLabel.isNotEmpty ||
      _creatorsLabel.isNotEmpty ||
      _formatMoney(budget).isNotEmpty ||
      _formatMoney(revenue).isNotEmpty;

  String get _statusLabel => status?.trim() ?? '';

  String get _runtimeLabel {
    if (_isTv) return '';
    final runtime = HeroMetaLine.formatRuntime(movie.runtime);
    if (runtime.isEmpty) return '';
    final remainingMs = (positionMs != null && durationMs != null)
        ? durationMs! - positionMs!
        : null;
    if (remainingMs != null && remainingMs > 0) {
      final ends = DateTime.now().add(Duration(milliseconds: remainingMs));
      final hour = ends.hour > 12 ? ends.hour - 12 : (ends.hour == 0 ? 12 : ends.hour);
      final minute = ends.minute.toString().padLeft(2, '0');
      final period = ends.hour >= 12 ? 'PM' : 'AM';
      return '$runtime • Ends $hour:$minute $period';
    }
    return runtime;
  }

  String get _languageLabel {
    final code = languageCode?.trim();
    if (code != null && code.isNotEmpty) return code.toUpperCase();
    if (spokenLanguages.isNotEmpty) {
      return spokenLanguages.first.length <= 3
          ? spokenLanguages.first.toUpperCase()
          : spokenLanguages.first;
    }
    return '';
  }

  String get _firstAiredLabel => _formatReleaseDate(movie.releaseDate);

  String get _lastAiredLabel {
    if (!_isTv) return '';
    return _formatReleaseDate(lastAirDate ?? '');
  }

  String get _seasonsLabel {
    if (!_isTv || movie.numberOfSeasons <= 0) return '';
    return '${movie.numberOfSeasons}';
  }

  String get _episodesLabel {
    if (!_isTv || movie.numberOfEpisodes <= 0) return '';
    return '${movie.numberOfEpisodes}';
  }

  String get _networkLabel {
    final items = networks.where((s) => s.trim().isNotEmpty).toList();
    if (items.isEmpty) return '';
    return items.join(', ');
  }

  String get _productionLabel {
    final items = productionCompanies.where((s) => s.trim().isNotEmpty).toList();
    if (items.isEmpty) return '';
    return items.join(', ');
  }

  String get _originLabel {
    final items = originCountries.where((s) => s.trim().isNotEmpty).toList();
    if (items.isEmpty) return '';
    return items.join(', ');
  }

  String get _creatorsLabel {
    if (!_isTv) return '';
    final items = creators.where((s) => s.trim().isNotEmpty).toList();
    if (items.isEmpty) return '';
    return items.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    if (!hasContent) return const SizedBox.shrink();

    final rows = <({String label, String value})>[
      if (_statusLabel.isNotEmpty) (label: 'Status', value: _statusLabel),
      if (_languageLabel.isNotEmpty) (label: 'Language', value: _languageLabel),
      if (_isTv) ...[
        if (_firstAiredLabel.isNotEmpty) (label: 'First Aired', value: _firstAiredLabel),
        if (_lastAiredLabel.isNotEmpty) (label: 'Last Aired', value: _lastAiredLabel),
        if (_seasonsLabel.isNotEmpty) (label: 'Seasons', value: _seasonsLabel),
        if (_episodesLabel.isNotEmpty) (label: 'Episodes', value: _episodesLabel),
        if (_networkLabel.isNotEmpty) (label: 'Network', value: _networkLabel),
      ] else ...[
        if (_firstAiredLabel.isNotEmpty) (label: 'Release Date', value: _firstAiredLabel),
        if (_runtimeLabel.isNotEmpty) (label: 'Runtime', value: _runtimeLabel),
      ],
      if (_productionLabel.isNotEmpty) (label: 'Production', value: _productionLabel),
      if (_originLabel.isNotEmpty) (label: 'Origin', value: _originLabel),
      if (_creatorsLabel.isNotEmpty) (label: 'Created by', value: _creatorsLabel),
      if (!_isTv && _formatMoney(budget).isNotEmpty)
        (label: 'Budget', value: _formatMoney(budget)),
      if (!_isTv && _formatMoney(revenue).isNotEmpty)
        (label: 'Revenue', value: _formatMoney(revenue)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Production Info',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.92),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 20,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            _HeroFactRow(label: rows[i].label, value: rows[i].value),
          ],
        ],
      ),
    );
  }

  static String _formatReleaseDate(String iso) {
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

  static String _formatMoney(int? amount) {
    if (amount == null || amount <= 0) return '';
    final s = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '\$${buf.toString()}';
  }
}

class _HeroFactRow extends StatelessWidget {
  const _HeroFactRow({required this.label, required this.value});

  final String label;
  final String value;

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
