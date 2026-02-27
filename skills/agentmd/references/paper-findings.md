# Paper Findings: "Evaluating AGENTS.md" (ETH Zurich, Feb 2026)

**Full paper:** [https://arxiv.org/abs/2602.11988](https://arxiv.org/abs/2602.11988)
**Authors:** Thibaud Gloaguen, Niels Mundler, Mark Muller, Veselin Raychev, Martin Vechev
**Affiliations:** ETH Zurich (Dept. of Computer Science) & LogicStar.ai
**Benchmark:** 438 tasks — SWE-bench Lite (300) + AGENTbench (138, novel benchmark by the authors)
**Agents evaluated:** Claude Code (Sonnet-4.5), Codex (GPT-5.2, GPT-5.1 mini), Qwen Code (Qwen3-30b-coder)

## Key Metrics

| Setting | Avg Resolution Rate Change | Cost Change | Steps Change |
|---|---|---|---|
| LLM-generated context file | -3% (AGENTbench) | +23% | +3.92 |
| Human-written context file | +4% (AGENTbench) | +19% | +3.34 |
| LLM-generated (no-docs repo) | +2.7% | — | — |

## What Works (Human-Written Files)

1. **Specific tool mentions** — When a tool (e.g. `uv`) is mentioned in the context file, agents use it 1.6x/instance vs 0.01x without mention. Agents reliably follow tooling instructions.
2. **Minimal requirements only** — Human files that specify only what the agent can't discover outperform verbose ones.
3. **Non-obvious conventions** — Rules that would cause the agent to waste time if unknown (e.g. "migrations aren't auto-committed", "new endpoints go in v2/").

## What Hurts (Avoid These)

1. **Codebase overviews** — 100% of LLM-generated files include them, but they do NOT help agents find relevant files faster (Finding 3).
2. **Directory structure listings** — Agents discover structure via `ls`/`find`/`grep` naturally.
3. **Duplicating existing docs** — LLM-generated files are highly redundant with README/docs (Finding 4).
4. **Verbose instructions** — More content = +14-22% reasoning tokens without better results (Finding 7).
5. **Generic code style guides** — If a linter is configured (ruff, eslint), the config file IS the style guide.
6. **Installation instructions** — Already in README, pyproject.toml, package.json, etc.
7. **Git workflow descriptions** — Irrelevant for task resolution.

## Why Auto-Generated Files Fail

- They include everything discoverable (overviews, structure, docs summary)
- They add unnecessary requirements that make tasks harder
- They increase reasoning token usage by 14-22% without improving results
- Stronger models don't generate better context files (Finding: ablation)
- Different prompts don't help either (Finding: ablation)

## When Context Files ARE Valuable

1. Repos with little/no existing documentation — LLM-generated files improve by +2.7%
2. Specifying mandatory tooling (build commands, test runners, formatters)
3. Documenting non-obvious constraints the agent would trip over
