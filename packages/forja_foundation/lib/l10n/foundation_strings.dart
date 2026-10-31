import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Words the design system shows when its caller passes none. The package
/// cannot read the app's language files, so the app wraps its tree in
/// [ForjaFoundationStringsScope] with translated values. Defaults are English.
@immutable
class ForjaFoundationStrings {
  const ForjaFoundationStrings({
    this.readMore = 'Read More',
    this.readLess = 'Read Less',
    this.retry = 'Retry',
    this.back = 'Back',
    this.nothingHere = 'Nothing here',
    this.noCategories = 'No categories',
    this.noMatches = 'No matches',
    this.search = 'Search',
    this.all = 'All',
    this.factLabels = const {},
    this.statusLabels = const {},
    this.shortMonths = const [],
    this.datePattern = '{month} {day}, {year}',
  });

  final String readMore;
  final String readLess;
  final String retry;
  final String back;
  final String nothingHere;
  final String noCategories;
  final String noMatches;
  final String search;
  final String all;

  /// Facts panel row labels, keyed by the English label ("Release Date").
  final Map<String, String> factLabels;

  /// Facts panel status values, keyed by the English value ("Released").
  final Map<String, String> statusLabels;

  /// Twelve short month names, January first. Empty keeps the English dates.
  final List<String> shortMonths;

  /// Date layout with `{day}`, `{month}` and `{year}` placeholders.
  final String datePattern;

  static const ForjaFoundationStrings english = ForjaFoundationStrings();

  /// The nearest scope's strings, or English when there is none.
  static ForjaFoundationStrings of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ForjaFoundationStringsScope>()
          ?.strings ??
      english;

  @override
  bool operator ==(Object other) =>
      other is ForjaFoundationStrings &&
      other.readMore == readMore &&
      other.readLess == readLess &&
      other.retry == retry &&
      other.back == back &&
      other.nothingHere == nothingHere &&
      other.noCategories == noCategories &&
      other.noMatches == noMatches &&
      other.search == search &&
      other.all == all &&
      mapEquals(other.factLabels, factLabels) &&
      mapEquals(other.statusLabels, statusLabels) &&
      listEquals(other.shortMonths, shortMonths) &&
      other.datePattern == datePattern;

  @override
  int get hashCode => Object.hash(
    readMore,
    readLess,
    retry,
    back,
    nothingHere,
    noCategories,
    noMatches,
    search,
    all,
    Object.hashAll(factLabels.entries.map((e) => Object.hash(e.key, e.value))),
    Object.hashAll(
      statusLabels.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAll(shortMonths),
    datePattern,
  );
}

class ForjaFoundationStringsScope extends InheritedWidget {
  const ForjaFoundationStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final ForjaFoundationStrings strings;

  @override
  bool updateShouldNotify(ForjaFoundationStringsScope oldWidget) =>
      strings != oldWidget.strings;
}
