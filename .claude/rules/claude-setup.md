---
paths:
  - ".claude/**"
  - ".cursor/**"
  - "CLAUDE.md"
  - ".mcp.json"
---

# Maintaining the agent setup

Map: `.claude/README.md`. Single source of rule text: `.cursor/rules/*.mdc`. Single source of skills: `.cursor/skills/*/SKILL.md` (`.claude/skills` is a symlink — never create a parallel copy). `.claude/rules/*.md` are path-scoped bridges: they name which `.mdc` to read and repeat only the one-line law; when you change a rule's `globs`, update the bridge's `paths`.

Hooks live in `.claude/hooks/` and are wired in `.claude/settings.json`. The `guard-bash` hook matches forbidden commands only at command position (line start or after `;` `&` `|` `(`), so prose that mentions them is fine, but a shell command whose text contains one at that position is blocked — write such files with the Write tool, or base64-encode test fixtures. Test a hook with simulated stdin:

```bash
printf '{"tool_name":"Bash","tool_input":{"command":"git stash"}}' | bash .claude/hooks/guard-bash.sh; echo "exit=$?"
```

Exit 0 + JSON = decision/context; exit 2 = block with stderr reason. Keep `CLAUDE.md` under 200 lines: always-true facts there, path-specific text in rules, procedures in skills.
