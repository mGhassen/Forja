# RFC-001: Monorepo boundaries

## Packages

- `forja_core` — types only, no Flutter UI
- `forja_storage` — SharedPreferences repos
- Feature packages depend on core + storage, never on `apps/forja`

## Rules

- Widgets call repositories, not `http` directly
- Cross-feature navigation lives in `apps/forja`
