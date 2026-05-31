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

## Complementary evidence: efficiency (Lulla et al., ICSE JAWs 2026)

**Paper:** [https://arxiv.org/abs/2601.20404](https://arxiv.org/abs/2601.20404) — "On the Impact of AGENTS.md Files on the Efficiency of AI Coding Agents." Lulla, Mohsenimofidi, Galster, Zhang, Baltes & Treude. Paired study on Codex (`gpt-5.2-codex`): 124 real PRs from 10 repos that ship a curated root `AGENTS.md`, each task run with and without the file (same task/repo/state).

This measures a **different axis than Gloaguen**: operational **efficiency** (wall-clock time + tokens), not resolution rate.

| Metric | Δ median | Δ mean | Significant? |
|---|---|---|---|
| Wall-clock time | **−28.6%** | −20.3% | yes (Wilcoxon p<0.05) |
| Output tokens | **−16.6%** | −20.1% | yes |
| Input / total tokens | ~flat | ≈−10% | no |

### Takeaways for this skill

1. A minimal, curated `AGENTS.md` is not merely "less harmful" — it makes the agent **faster and cheaper per output**. A *positive* reason for minimalism, not just harm-avoidance.
2. The gain comes from **curated conventions** (the "Non-Obvious Rules" / "Project-Specific Patterns" this skill already recommends), NOT from overviews or structure dumps — Gloaguen measured that overviews don't help agents find files faster. The include/exclude line in this skill is unchanged.
3. **Caveats:** Codex-only (one model); efficiency axis only (output quality / success rate not measured). Don't overgeneralize the magnitudes.

**Combined reading:** what you measure differs, but both papers point the same way — the value is in a *curated, minimal* file. Bloat (auto-generated overviews, duplicated docs) hurts success rate (Gloaguen); curation helps efficiency (Lulla). Keep it minimal and convention-focused.
