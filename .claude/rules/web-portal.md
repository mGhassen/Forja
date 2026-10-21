---
paths:
  - "apps/web/**"
  - "packages/forja-auth/**"
  - "apps/tmdb-gateway/**"
---

# Web portal (apps/web) and TS packages

Stack as of `apps/web/package.json`: React 19, TanStack Start + Router (file routes under `src/routes`, generated `routeTree.gen.ts` — never hand-edit), TanStack Query, Vite 8, Tailwind 4, Radix primitives, i18next (`src/i18n`), PostHog, Cloudflare Turnstile. Lint is `oxlint` (`pnpm lint`), package manager is pnpm. Deployed on Vercel; auth helpers in `packages/forja-auth`; `apps/tmdb-gateway` is a Vercel function.

Rules that still apply here: user-facing copy truth, changelog same-turn (portal changes users see go under **Features** or **UI**), Supabase discipline (`.claude/rules/supabase.md`). Keep `VITE_*` public keys only — never R2 keys or `service_role` in Vite env. Portal origin must be public for `/connect` and Web login (Vercel Deployment Protection breaks QR login — see `docs/DEVELOPMENT.md`).
