# Foundation primitives

App-wide atomic UI. Domains:

| Folder | Holds |
|--------|--------|
| `tokens/` | colors, theme, shell/details/settings tokens |
| `shell/` | scope, metrics, layout, platform, section title |
| `controls/` | buttons, switch, chips, tabs |
| `feedback/` | toast, loading, frosted / player overlays |
| `chrome/` | scroller, focus tap, posters, mood circle |
| `brand/` · `desktop/` · `tv/` | platform / brand leafs |

```dart
import 'package:forja/shared/foundation/primitives/primitives.dart';
```

Composers (`kit.categoryBar`, hero, media_details, posters, …) live under `../components/`.
There is no peer `shared/widgets/` package.
