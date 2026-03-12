# mryll/skills

A collection of agent skills for coding CLIs — [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview), [Codex](https://github.com/openai/codex), [Gemini CLI](https://github.com/google-gemini/gemini-cli), [Copilot](https://github.com/features/copilot), and others.

Skills are markdown-only instructions that shape how your coding agent writes, reviews, and architects code. No runtime dependencies, no build steps — just drop them in and go.

[Skills](#skills) | [Installation](#installation) | [Usage](#usage)

## Skills

| Skill | Description |
|---|---|
| **[agentmd](skills/agentmd)** | Generate minimal, research-backed `CLAUDE.md` / `AGENTS.md` context files. Based on [ETH Zurich research](https://arxiv.org/abs/2502.11911) showing that auto-generated context files *decrease* performance while minimal human-written ones improve it. |
| **[low-complexity](skills/low-complexity)** | Automatically enforce low Cognitive Complexity (SonarSource) and Cyclomatic Complexity in all generated code. Activates on every code write/modify — no explicit trigger needed. |
| **[vertical-slice-architecture](skills/vertical-slice-architecture)** | Organize code by feature/use-case instead of technical layers. Works with any language and app type (web API, CLI, event-driven, etc.). |
| **[codex-review](skills/codex-review)** | Iterative code review debate between Claude Code and Codex CLI until both reach consensus. Supports plan-mode review with implementation contracts. |
| **[test-namer](skills/test-namer)** | Write expressive, behavior-focused tests following Vladimir Khorikov's testing principles. Plain English names, test behavior not implementation. |

## Installation

### All skills

```bash
npx skills add mryll/skills
```

### Individual skills

```bash
npx skills add mryll/skills --skill <skill-name>
```

For example:

```bash
npx skills add mryll/skills --skill low-complexity
npx skills add mryll/skills --skill codex-review
```

> [!TIP]
> You can install multiple individual skills by running the command once per skill. Only install what you need — each skill is fully self-contained.

## Usage

Once installed, skills activate automatically based on context. Some examples:

- **agentmd** — Ask your agent to "generate CLAUDE.md" or "create AGENTS.md"
- **low-complexity** — Activates automatically whenever code is written or modified
- **vertical-slice-architecture** — Ask to "use vertical slice architecture" or start building features in a VSA project
- **codex-review** — Ask to "review with codex" or "validate plan with codex"
- **test-namer** — Activates whenever tests are written, created, or reviewed
