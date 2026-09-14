/// Host re-export — prefer `package:forja_foundation/utils/title_clean.dart`.
library;

export 'package:forja_foundation/utils/title_clean.dart';

import 'package:forja_foundation/utils/title_clean.dart';

/// Migration alias used by live player paths.
CleanedMediaTitle cleanStreamMediaTitle(String raw) => cleanMediaTitle(raw);

/// @Deprecated('Use cleanMediaTitle / cleanStreamMediaTitle')
CleanedMediaTitle cleanIptvMediaTitle(String raw) => cleanMediaTitle(raw);

/// @Deprecated('Use CleanedMediaTitle')
typedef IptvCleanedTitle = CleanedMediaTitle;
