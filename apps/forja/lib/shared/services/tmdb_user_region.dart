import 'dart:ui';

import 'package:rust/rust.dart';

/// Wire TMDB watch region to the device locale (country code).
void initTmdbUserRegion() {
  TmdbWatchRegion.resolve = () {
    final country = PlatformDispatcher.instance.locale.countryCode;
    if (country != null && country.isNotEmpty) return country;
    return TmdbWatchRegion.fallback;
  };
}
