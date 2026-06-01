# AGENTS.md

Markdown-only skills collection — no code, build, tests, or linters.

## Skill File Format

- Each skill lives at `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, `version`).
- `description` MUST be a single-line string — never a YAML block scalar (`|` or `>`); block scalars break skill registration.
- Keep `description` ≤1024 chars, or Codex CLI silently skips the skill.
- Optional `references/` subdirectory for supporting docs, linked from SKILL.md.

## Non-Obvious Rules

- Keep skills self-contained: each SKILL.md must work standalone, with no dependency on other skills.
- Register every new skill in `.claude-plugin/marketplace.json` (the `skills` array) or it won't be published.
- The skills.sh renderer crashes on Markdown tables and zero-width-char fence hacks in SKILL.md — use bullet lists and 4-backtick outer fences instead.
