# Forja global migration

**Last updated:** 2026-07-07  
**Status:** fixed — Phases 1–3 complete  
**Boundary rules:** [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md)

**Rules:** [docs-rfc-issues](../../.cursor/rules/docs-rfc-issues.mdc)

Every phase file has a status tag in the filename matching `**Status:**` in the body. Complete phases live in [fixed/](fixed/).

## Phases

| # | File | Summary | Backlog |
|---|------|---------|---------|
| 1 | [01-[fixed]-…](fixed/01-[fixed]-rust-engine.md) | Rust crates + FFI primitives | [0.1.0](../backlog/done/0.1.0-[done].md)–[0.1.7](../backlog/done/0.1.7-[done].md) |
| 2 | [02-[fixed]-…](fixed/02-[fixed]-rust-engine-complete.md) | Playback engine → `crates/*` | [0.2.0](../backlog/done/0.2.0-[done].md)–[0.2.1](../backlog/done/0.2.1-[done].md) |
| 3 | [03-[fixed]-…](fixed/03-[fixed]-engine-catalog.md) | Catalog engine → `crates/*` | [0.3.0](../backlog/done/0.3.0-[done].md)–[0.3.3](../backlog/done/0.3.3-[done].md) |

Web client is **not** migration — [RFC-010](../rfc/010-[draft]-web-client.md) / [RFC-014](../rfc/014-[draft]-v3-web-rust.md).

---

## Two layers (normalized)

| Layer | Location | What belongs |
|-------|----------|--------------|
| **Engine** | `crates/*` | All non-platform logic (C1, C2, C7, C8, C9, Rust C11 pipelines) |
| **Host** | `apps/forja` | UI + platform (C3–C6, C10, C12, host C11 UX) |
| **FFI bridge** | `packages/rust` | Loader + parity tests only |

Residual Dart engine in `apps/forja` must port to `crates/*` on touch — not a permanent tier.

---

## Migration rules

**Engine move** = port to `crates/*`, expose FFI, delete Dart equivalent, test.

**No new engine logic in Dart** — port to `crates/*` when touching.

Agent workflow: [`.cursor/rules/rust-migration.mdc`](../../.cursor/rules/rust-migration.mdc)

---

## Principles

1. **Engine = `crates/*` only**
2. **Host = Flutter** — pixels + platform permanently
3. **Engine move = port + delete** — not rewire, not wrap
4. **Migration complete** — all phases `[fixed]` in `fixed/`

## Related

- [RFC index](../rfc/README.md)
- [Issues](../issues/README.md)
- [Backlog](../backlog/README.md)
