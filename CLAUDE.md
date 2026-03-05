# CLAUDE.md

## Skill File Format

Each skill lives at `skills/<name>/SKILL.md` with YAML frontmatter:

```yaml
---
name: skill-name
description: Single-line string. Do NOT use YAML block scalars (| or >).
---
```

- `description` MUST be a single-line string — multi-line block scalars break skill registration
- Optional `references/` subdirectory for supporting docs, linked from SKILL.md

## Non-Obvious Rules

- Markdown only — no code, no build, no tests, no linters
- Keep skills self-contained: each SKILL.md should work standalone without depending on other skills
