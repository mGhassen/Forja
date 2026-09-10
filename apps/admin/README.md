# Moved

Admin lives in the sibling repo **[forja-admin](https://github.com/mGhassen/forja-admin)**.

```text
Workspace/
├── Forja/
└── forja-admin/   ← ops console (pnpm dev → :4000)
```

Delete this `apps/admin/` tree once Vercel / local workflows point at that repo. Schema migrations stay in `apps/web/supabase`.
