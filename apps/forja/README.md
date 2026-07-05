# Forja App

Main Flutter product. See [README_FORJA.md](../../README_FORJA.md) for monorepo layout.

```bash
flutter pub get
flutter run -d macos
```

## Layout

- `lib/app/` — bootstrap
- `lib/shell/` — nav, `AppRouter`, `ShellBus`
- `lib/features/` — one folder per nav tab
- `lib/shared/` — player, widgets, Phase 3 stubs (design/casting/sync)
