# skills

A collection of agent skills for coding CLIs (Claude Code, Codex, Gemini CLI, Copilot, etc.).

## Install all

```bash
npx skills add mryll/skills
```

## Install individual skills

```bash
npx skills add mryll/skills --skill agentmd
npx skills add mryll/skills --skill low-complexity
npx skills add mryll/skills --skill vertical-slice-architecture
npx skills add mryll/skills --skill codex-review
npx skills add mryll/skills --skill test-namer
```

## Skills

| Skill | Description |
|---|---|
| **agentmd** | Generate minimal, research-backed CLAUDE.md / AGENTS.md context files. Based on ETH Zurich research. |
| **low-complexity** | Enforce low Cognitive and Cyclomatic Complexity in all generated code. |
| **vertical-slice-architecture** | Enforce Vertical Slice Architecture (VSA) — organize code by feature, not by layer. |
| **codex-review** | Iterative code review and planning debate between Claude Code and Codex CLI until consensus. |
| **test-namer** | Write expressive, behavior-focused tests following Vladimir Khorikov's testing principles. |

