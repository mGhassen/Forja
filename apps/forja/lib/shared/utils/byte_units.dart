import 'package:forja/shared/services/app/app_locale.dart';

/// Byte sizes written for the app language: `1.5 GB` in English, `1,5 Go` in
/// French. Display only — sizes that are read back by [TorrentMetaParser]
/// stay English.
abstract final class ByteUnits {
  static const _en = ['B', 'KB', 'MB', 'GB', 'TB'];
  static const _fr = ['o', 'Ko', 'Mo', 'Go', 'To'];

  static bool get _french => AppLocale.activeCode == 'fr';

  /// Unit names from bytes up to terabytes.
  static List<String> get suffixes => _french ? _fr : _en;

  /// [value] in [unit] (an index into [suffixes]) with [digits] decimals.
  static String format(double value, int unit, int digits) {
    final number = value.toStringAsFixed(digits);
    if (!_french) return '$number ${_en[unit]}';
    // Decimal comma and a non-breaking space, so a size never wraps.
    return '${number.replaceFirst('.', ',')} ${_fr[unit]}';
  }
}
