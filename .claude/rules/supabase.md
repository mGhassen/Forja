---
paths:
  - "apps/web/supabase/**"
  - "apps/web/**/*supabase*"
  - "scripts/*supabase*"
---

# Supabase is production

Read `.cursor/rules/supabase-migrations.mdc`.

Schema changes only through `cd apps/web && supabase migration new <name>`, then edit that new file. Shipped migrations (73 files) are immutable — the `guard-edit` hook denies edits to existing ones. Database reset, push, and link commands and the reset script are denied by settings and by the `guard-bash` hook; applying anything to a database needs the user's explicit yes in this conversation. `seed.sql` is local-only data. Local vs remote disagree → stop and ask.
