import 'dart:ui';

import 'package:rust/rust.dart';

/// Wire TMDB catalog region to the device locale (country code).
void initTmdbUserRegion() {
  TmdbWatchRegion.resolve = () {
    final locale = PlatformDispatcher.instance.locale;
    final country = locale.countryCode;
    if (country != null && country.isNotEmpty) {
      return country;
    }
    return TmdbWatchRegion.fallback;
  };
}
