/// Host re-export — prefer `package:forja_foundation/utils/title_clean.dart`.
library;

export 'package:forja_foundation/utils/title_clean.dart';

import 'package:forja_foundation/utils/title_clean.dart';

/// Migration alias used by live player paths.
CleanedMediaTitle cleanStreamMediaTitle(String raw) => cleanMediaTitle(raw);
