# Backlog

One file **per release version**. Specs live in [RFCs](../rfc/README.md); each file here is the ship list for that version.

**Rules:** [docs-rfc-issues](../../.cursor/rules/docs-rfc-issues.mdc)

## Naming

Filename = **semver + status tag**. Tag matches `**Status:**` in the body.

| Filename example | Body status | Meaning |
|------------------|-------------|---------|
| `0.7.6-[draft].md` | `draft` | Version scoped, not started |
| `0.7.6-[open].md` | `open` | Actively shipping this version |
| `0.7.6-[partial].md` | `partial` | Release in progress, not complete |
| `done/0.7.6-[done].md` | `done` | Version shipped |
| `canceled/0.7.6-[canceled].md` | `canceled` | Version dropped — will not ship |

```
plan version   →  0.7.6-[draft].md
start release  →  0.7.6-[open].md
in progress    →  0.7.6-[partial].md
shipped        →  done/0.7.6-[done].md
dropped        →  canceled/0.7.6-[canceled].md
```

Inside each file: checklist of what ships (links to RFCs, issues). **The version is the file.**

## Active

| File | Status |
|------|--------|
| — | — |

## Done

[done/](done/) — shipped versions.

## Canceled

[canceled/](canceled/) — versions dropped (note why in the file body).

## Related

- [RFC index](../rfc/README.md)
- [Issues](../issues/README.md)
