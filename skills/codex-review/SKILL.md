---
name: codex-review
version: 1.0.0
description: "Iterative code review and planning discussion between the local agent and Codex CLI (model and reasoning effort taken from the user's local Codex configuration at ~/.codex/config.toml, overridable per invocation). Orchestrates an automatic back-and-forth debate where both agents discuss findings, architecture decisions, or implementation plans until reaching consensus. Codex CLI operates in READ-ONLY mode — it never modifies files. Supports plan mode: when the local agent has a plan ready, invoke this skill to have Codex evaluate and iterate on the plan before implementation, producing an updated consensus plan. Use when the user asks to review with codex, analyze with codex, discuss with codex, iterate with codex, consult codex, ask codex, review the plan with codex, validate plan with codex, or any request involving Codex CLI for code review, architecture review, planning discussion, or collaborative analysis of code, design, or implementation strategy."
---

# Codex Review — Iterative Consensus Skill

Orchestrate an iterative debate between the local agent and Codex CLI until both reach consensus on code review findings, architecture decisions, or implementation plans.

**Guiding principle: KISS (Keep It Simple, Stupid).** Both sides should favor the simplest solution that works. Complexity must be justified.

## Codex Independence

Codex is an **independent reviewer**, not a compliance checker. Do NOT instruct Codex to validate against AGENTS.md / CLAUDE.md conventions or treat them as rules to follow. Codex should form its own engineering opinions based on the code/plan it reads.

- **The local agent** follows the project's AGENTS.md / CLAUDE.md conventions (it already does naturally)
- **Codex** reviews with its own engineering judgment — it may agree with, be unaware of, or even challenge AGENTS.md / CLAUDE.md conventions
- **When they disagree**: the local agent may cite AGENTS.md / CLAUDE.md as one argument, but Codex is free to push back if it has a better reasoning. The debate resolves on merits, not authority.
- **If truly unresolved**: flag it for the user to decide

Give Codex only a brief project description (what it does, tech stack) for context — not a rulebook.

## Codex CLI Configuration

- **Model & reasoning effort**: NOT hardcoded — Codex CLI reads them from `~/.codex/config.toml` (top-level `model` and `model_reasoning_effort` keys, or whichever profile is active). Do NOT pass `-m` or `-c model_reasoning_effort` unless the user explicitly overrides them in their trigger message.
- **Command**: `codex exec -s read-only --skip-git-repo-check "prompt" < /dev/null` — minimal canonical form. Add `-m <model>` and/or `-c model_reasoning_effort="<effort>"` only when the user overrides them. The `< /dev/null` is mandatory (see Command Execution for why).
- **CRITICAL**: Codex CLI must NEVER modify files. Always pass `-s read-only` and include the read-only constraint in every prompt sent to Codex.

### Model and Reasoning Effort

Defaults come from the user's `~/.codex/config.toml` (top-level `model` and `model_reasoning_effort` keys, or the active profile). The skill does NOT hardcode them and does NOT need to know what they are. If the user has nothing configured there, Codex CLI falls back to its own internal defaults — also not the skill's concern.

Pass `-m` or `-c model_reasoning_effort="..."` ONLY when the user explicitly overrides them in their trigger message (e.g., "review with codex using gpt-5.4", "analyze with codex effort medium").

**IMPORTANT CLI syntax**: Reasoning effort is NOT a CLI flag — when overriding, use the `-c` config override: `-c model_reasoning_effort="<value>"`. The `--reasoning-effort` flag does not exist and will cause an error.

```bash
# Default — Codex uses whatever is in ~/.codex/config.toml
codex exec -s read-only --skip-git-repo-check "prompt" < /dev/null

# User overrides model only (e.g., "review with codex using gpt-5.4")
codex exec -m gpt-5.4 -s read-only --skip-git-repo-check "prompt" < /dev/null

# User overrides reasoning effort only (e.g., "analyze with codex effort medium")
codex exec -c model_reasoning_effort="medium" -s read-only --skip-git-repo-check "prompt" < /dev/null

# User overrides both
codex exec -m gpt-5.4 -c model_reasoning_effort="medium" -s read-only --skip-git-repo-check "prompt" < /dev/null
```

If the user provides an override, use the same value for ALL rounds within the session. Do not change it mid-discussion. (Round 2+ uses `codex exec resume`, which inherits session settings — no need to re-pass flags.)

### Trust and Git Repo Check

**Always pass `--skip-git-repo-check`** in every `codex exec` call. Without it, Codex CLI will refuse to run if the working directory is not inside a trusted git repository — this causes failures when the local agent invokes the skill from projects not yet marked as trusted in Codex's config. Since we always run in read-only mode, skipping this check is safe.

**`codex exec resume` does NOT accept `--skip-git-repo-check`** (the flag is ignored or rejected). For resume calls, the cwd must be a real git repository (a directory containing `.git/`). Setting `[projects."<path>"].trust_level = "trusted"` in `~/.codex/config.toml` is NOT sufficient — Codex still requires the `.git/` directory. **Practical workaround**: if your initial `codex exec` ran from a workspace root without `.git/` (e.g. a `go.work` monorepo or a `pnpm-workspace.yaml` directory), `cd` into a sub-module that has its own `.git/` before issuing `codex exec resume`. The session is global, so the cwd at resume time is independent from the cwd at the original `codex exec`.

### Session Persistence

Codex CLI auto-persists sessions to `~/.codex/sessions/`. Use this to maintain a **continuous conversation** across all rounds — Codex retains its own analysis, reasoning, and the full discussion history.

**How it works:**

1. **Round 1**: Run `codex exec --json` with all required flags. Parse the session ID from the JSONL output (look for a `session_id` field). Store it for all subsequent rounds.
2. **Round 2+**: Run `codex exec resume <SESSION_ID> "prompt"`. This continues the existing conversation with full prior context. No need to re-pass `-m`, `-s`, `-c`, or `--skip-git-repo-check` — session settings are inherited.

**Why this matters**: Without `resume`, each `codex exec` starts a blank session — Codex loses its own previous analysis, can contradict itself, and follow-up prompts must re-summarize everything. With `resume`, the conversation flows naturally and follow-up prompts are minimal.

**Parallel safety**: Always capture and use the specific session ID — never use `--last`, which would pick up the wrong session if multiple reviews run concurrently.

## Token Efficiency — Let Codex Navigate

**CRITICAL**: Do NOT paste file contents, git diffs, or large code blocks inline into Codex prompts. Codex CLI has full filesystem access and can read files on its own. Inlining content wastes input tokens.

**What to pass inline** (Codex cannot discover these on its own):
- Description of the problem, requirement, or what the user wants to achieve
- Plan content (when in plan mode — it exists in conversation context, not in a file)
- Key conventions summary (or tell Codex to read AGENTS.md / CLAUDE.md directly)

**What to pass as paths/references** (let Codex read them):
- Changed file paths (e.g., "review the changes in `internal/catalog/list_products/handler.go`")
- Directories to explore (e.g., "examine the files under `internal/scraping/worker/`")
- Git instructions (e.g., "run `git diff HEAD~1` to see recent changes")
- Config/migration files to check

## Round Efficiency — Minimize Iterations

Each round costs time and tokens. Maximize the value of every round:

### Local Agent Pre-Analysis (Before Round 1)

Before calling Codex, the local agent MUST do its own review first. Read the code/plan and form its own findings with severity. **BUT do NOT send these findings to Codex in round 1.** Keep them internal. This ensures Codex's first response is completely unbiased.

After round 1, compare Codex's findings against your internal list:
- Findings that match → immediately agree (saves a round)
- Codex findings you missed → evaluate on merits
- Your findings that Codex missed → introduce them in round 2 as "Additional Observations"

### Batch Everything

Both sides MUST respond to ALL pending points in each round. Never address a single finding per round. Every response should cover:
- Agreements/disagreements on every finding raised
- All new observations (don't hold back findings for later)
- All counter-arguments at once

### Severity-Based Discussion

Only debate critical and major findings. For minor/suggestion severity:
- Accept them without debate unless there's a strong reason to disagree
- List them in the "Agreed" section immediately
- Don't waste a round arguing about style preferences or minor improvements

### Exhaustive First Round

Instruct Codex to be exhaustive in its first response — cover everything it can find. It's better to have a longer first response than multiple short rounds discovering things incrementally.

## Workflow

### 1. Gather Context and Pre-Analyze

Identify what Codex needs to review, but do NOT read file contents to paste into the prompt. Instead, collect:

- **Code review after implementation**: Run `git diff --name-only` to get the list of changed files. Pass those paths to Codex.
- **Review of specific files/paths**: Pass the paths directly. If the user specifies directories, tell Codex to explore within them.
- **Planning/architecture discussion**: Summarize the plan inline (it's in conversation context). Tell Codex to read AGENTS.md / CLAUDE.md and relevant source files by path.
- **General analysis**: Identify the scope and relevant paths. Let Codex navigate from there.

**Then, do your own review.** Read the relevant code/plan, form your own findings (with severity), and keep them internal. Do NOT include them in the initial prompt — they will be introduced in round 2 after seeing Codex's unbiased response. Use the same review focus areas (edge cases, error paths, concurrency, input boundaries, resource management, contract violations) to guide your pre-analysis.

### 2. Craft Initial Prompt to Codex

Structure the first prompt to Codex. Do NOT inline file contents — give paths and let Codex read them.

```
You are participating in a collaborative code review / planning discussion.
You are operating in READ-ONLY mode — do NOT modify, create, or delete any files.
You may read any files in the codebase to inform your analysis.

## Context
[Brief project description: what the project does, tech stack, relevant architectural context.
Keep it short — just enough for Codex to understand what it's looking at. Do NOT point Codex
to AGENTS.md / CLAUDE.md or tell it to follow specific conventions. Let it form its own opinions.]

## Scope
[Describe what is being reviewed and provide paths/commands for Codex to explore:]
- Files to review: [list of file paths]
- To see changes: run `git diff` or `git diff HEAD~N`
- Directories to explore: [paths if relevant]

## Your Task
[Specific analysis requested: review code quality, find bugs, evaluate architecture, discuss plan trade-offs, etc.]

## Review Focus Areas
Beyond general code quality, actively look for:
- **Edge cases**: missing nil/null checks, empty collections, zero values, boundary conditions, off-by-one errors
- **Error paths**: unhandled errors, swallowed exceptions, missing rollback/cleanup on failure, misleading error messages
- **Concurrency**: race conditions, shared mutable state, missing locks/synchronization, goroutine/thread leaks
- **Input boundaries**: unvalidated user input, missing size/length limits, type coercion issues, injection vectors
- **Resource management**: unclosed connections/files/channels, missing timeouts, unbounded growth (queues, caches, maps)
- **Contract violations**: functions that don't honor their documented behavior, broken invariants, silent data loss

Not all apply to every review — focus on what's relevant to the code at hand.

## Instructions
- Read the files and code yourself — navigate freely within the codebase
- If you need more context or information to do a thorough review, do not hesitate to ask. I will provide whatever you need.
- Be EXHAUSTIVE in this first response — cover everything you can find. It's better to be thorough now than to discover things in later rounds.
- Provide your own findings with severity (critical/major/minor/suggestion)
- Reference specific file paths and line numbers
- Explain WHY something is a problem, not just WHAT
- If reviewing a plan, evaluate trade-offs and propose alternatives where relevant
- For minor/suggestion findings: only flag them, no need for deep discussion
- When you have no more findings or observations, explicitly state: "No further observations."
```

Execute this prompt using the round 1 command format (see Command Execution). **Capture the session ID** from the `--json` JSONL output — all subsequent rounds use `codex exec resume <SESSION_ID>` to continue this conversation.

### 3. Iterative Loop (max 10 rounds per cycle)

**After Round 1 (Codex's unbiased response):**

Compare Codex's findings against your internal pre-analysis:
- **Overlap**: Findings both sides found independently → immediately mark as agreed
- **Codex-only findings**: Evaluate on merits — agree or prepare counter-arguments
- **Local-agent-only findings**: These become your "Additional Observations" in round 2

**For each subsequent round:**

1. **Send follow-up to Codex** via `codex exec resume <SESSION_ID> "prompt"` (use heredoc for multi-line prompts). Codex has full context from all prior rounds — no need to re-summarize the discussion.
2. **Analyze Codex's response**: Identify findings, agreements, disagreements, or questions
3. **Formulate the local agent's response**:
   - If Codex asks for more context: provide it (read the files/paths Codex requests, summarize relevant info, or point to additional paths)
   - Agree with valid findings
   - Counter-argue with specific reasoning when disagreeing (reference code, conventions, or constraints)
   - Add observations Codex may have missed (from your internal pre-analysis or newly discovered)
   - Ask clarifying questions if Codex's finding is ambiguous
4. **Check for consensus**: If BOTH sides have no new findings and all disagreements are resolved, exit the loop

**Follow-up prompt structure:**

Since Codex retains full context via session persistence, follow-up prompts are minimal — just the local agent's new input for the ongoing conversation.

```
## My Response to Your Findings
[the local agent's agreements, disagreements, and counter-arguments for each finding Codex raised — address ALL of them at once]

## Additional Observations
[New findings from the local agent, if any — don't hold anything back for later rounds]

## Open Questions
[Any clarifications needed, if any]

Respond to ALL my points at once. If you agree with everything and have nothing more to add, state: "No further observations."
```

**Consensus detection**: The loop ends when Codex responds with "No further observations" (or equivalent) AND the local agent also has nothing more to add.

### 4. Round Limit Handling

After 10 rounds without consensus:
- Pause and notify the user
- Present a summary of: agreed findings, unresolved disagreements, and each side's position
- Ask the user if they want to continue for another 10 rounds or stop with the current findings

### 5. Implementation Contracts (critical/major findings only)

After findings consensus, the review is NOT done yet. Abstract agreement ("add validation") leads to implementation disagreements. Both sides must now agree on **how** each critical/major finding will be implemented.

Skip this phase only if there are no critical/major findings that require code changes (e.g., review found only minor/suggestion items, or findings are purely observational).

**Process:**

1. The local agent drafts an **implementation contract** for each critical/major finding that requires code changes. Each contract specifies:
   - **Files to modify**: exact paths
   - **Approach**: the specific pattern, technique, or strategy (e.g., "add a validation middleware in `middleware/validate.go` that checks X before the handler runs" — not just "add validation")
   - **Key decisions**: explicit choices where multiple valid approaches exist (e.g., "use a JOIN, not a batch preload" or "inline validation, not a separate middleware")
   - **Code sketch**: the key structural parts — function signatures, type definitions, control flow — enough that two engineers would write essentially the same implementation. NOT full code, just the skeleton that disambiguates the approach.
   - **Edge cases**: specific scenarios to handle, with the agreed behavior for each

2. Send ALL contracts to Codex via `codex exec resume <SESSION_ID>` (same session as the findings discussion):

```
We agreed on the findings. Now let's agree on HOW to implement the fixes so there's no ambiguity during implementation.

For each critical/major finding, I'm proposing a concrete implementation approach. Please review each one and:
- AGREE if the approach is sound
- COUNTER-PROPOSE if you'd do it differently (explain why, provide your alternative sketch)
- ASK if you need to read additional files for context (specify which paths)

## Implementation Contract 1: [Finding title]
**Finding**: [brief reference to the agreed finding]
**Files**: [exact paths to modify]
**Approach**: [specific pattern/technique]
**Key decisions**: [explicit choices made]
**Code sketch**:
[structural skeleton — signatures, types, control flow]
**Edge cases**: [scenarios and expected behavior]

## Implementation Contract 2: [Finding title]
...

Respond to ALL contracts at once. For each, state AGREE, COUNTER-PROPOSE, or ASK.
When you have no objections, state: "All contracts approved."
```

3. Iterate until both sides agree on every contract (same batching rules as findings loop, max 5 rounds for this phase).

4. If a contract can't be agreed upon after 5 rounds, flag it as "unresolved implementation" — the user will decide the approach.

**Why code sketches matter**: "Add error handling" is ambiguous — it could be a wrapper, a middleware, inline checks, or a Result type. A code sketch like `func validateInput(req Request) error { check A; check B; return nil }` called from the handler removes that ambiguity. Both sides know exactly what will be built.

### 6. Final Output

Present to the user:

```markdown
## Codex Review — Consensus Report

### Summary
[1-2 sentence overview: what was reviewed, how many rounds (findings + contracts), outcome]

### Findings (Agreed)

#### Critical
- [Finding with file:line reference and explanation]

#### Major
- [Finding with file:line reference and explanation]

#### Minor
- [Finding with file:line reference and explanation]

#### Suggestions
- [Improvement suggestions]

### Implementation Contracts (Agreed)

#### [Finding 1 title]
- **Files**: [paths]
- **Approach**: [agreed pattern]
- **Code sketch**: [agreed skeleton]
- **Edge cases**: [agreed handling]

#### [Finding 2 title]
...

### Unresolved (if any)
- [Topic]: the local agent's position vs Codex's position — **user decides**

### Discussion Log
<details>
<summary>Full discussion (N findings rounds + M contract rounds)</summary>

**Round 1 — Codex**: [summary]
**Round 1 — the local agent**: [summary]
...
</details>
```

**IMPORTANT**: Do NOT implement any changes automatically. Present the report and wait for the user to decide what to do next. When the user approves, the local agent implements following the agreed contracts exactly.

## Plan Mode Workflow

When invoked during plan mode (the local agent has a plan ready for review before implementation):

### Context Gathering for Plans

- Identify the plan content (from conversation context — this IS passed inline since it's not in a file)
- Identify paths of files the plan will modify or build upon (pass as paths, not content)
- Identify the user's original request

### Initial Prompt to Codex (Plan Mode)

The plan content is the one exception where inline content is necessary — it exists in conversation context, not as a file. But for everything else, pass paths.

```
You are participating in a collaborative PLAN REVIEW discussion.
You are operating in READ-ONLY mode — do NOT modify, create, or delete any files.
You may read any files in the codebase to inform your analysis.

## Project Context
[Brief project description: what it does, tech stack, relevant context for this plan.
Do NOT point Codex to AGENTS.md / CLAUDE.md. Let it evaluate the plan with its own engineering judgment.]

## Files Relevant to This Plan
[List of file paths the plan will touch — Codex should read them to understand current state]

## The Plan Under Review
[Full plan content — this is inline because it's not saved to a file]

## User's Original Request
[What the user asked for that led to this plan]

## Your Task
Read the relevant files yourself, then evaluate this plan. If you need more context or information, do not hesitate to ask — I will provide whatever you need.

For each step, consider:
- Is the approach correct given the project's architecture and conventions?
- Are there missing steps, edge cases, or risks not addressed?
- Are there simpler alternatives that achieve the same goal?
- Does the ordering of steps make sense (dependencies, logical sequence)?
- Are there any conflicts with existing code or patterns?

Provide findings as:
- **Plan changes**: Concrete modifications to the plan (add/remove/reorder steps)
- **Concerns**: Risks or issues that need discussion
- **Questions**: Ambiguities that need clarification

When you have no more observations, explicitly state: "No further observations."
```

### Iterative Loop (same rules as code review)

Follow the same iterative loop (Section 3) with these adaptations:
- The local agent defends or adjusts plan steps based on Codex's feedback
- Both sides can propose alternative approaches with trade-off analysis
- Consensus means agreement on the final plan structure AND implementation approach, not just high-level steps

### Implementation Detail in Plans

Plans must go beyond task-level steps. Each step that involves code changes must include implementation contracts (same format as Section 5 of the code review workflow). This happens within the same iterative loop — no separate phase needed since the plan is being built from scratch.

**Transition checkpoint**: First resolve the plan structure (what steps, what order, add/remove). Only once both sides agree on the structure (no more step-level disagreements), the local agent proposes implementation detail (code sketches, key decisions) for each step. Proposing sketches while the structure is still in flux wastes effort if steps get removed or reordered.

Each plan step should specify:
- **What**: the task description
- **Files**: exact paths to create/modify
- **Approach**: specific pattern or technique
- **Code sketch**: structural skeleton for non-trivial changes
- **Key decisions**: explicit choices where alternatives exist

This ensures that when the local agent implements the plan, every step has a pre-approved approach — eliminating the need for a post-implementation review.

### Plan Mode Final Output

Instead of a findings report, produce an **updated plan with implementation contracts**:

```markdown
## Codex Review — Plan Consensus

### Summary
[1-2 sentences: what was planned, rounds taken, key changes from original]

### Updated Plan

#### Step 1: [Step title]
- **What**: [task description]
- **Files**: [paths to create/modify]
- **Approach**: [agreed pattern/technique]
- **Code sketch**: [structural skeleton — signatures, types, control flow]
- **Key decisions**: [explicit choices and why]

#### Step 2: [Step title]
...

### Changes from Original Plan
- [Change 1: what changed and why (agreed with Codex)]
- [Change 2: what changed and why]

### Unresolved (if any)
- [Topic]: the local agent's position vs Codex's position — **user decides**

### Discussion Log
<details>
<summary>Full discussion (N rounds)</summary>

**Round 1 — Codex**: [summary]
**Round 1 — the local agent**: [summary]
...
</details>
```

**After presenting the updated plan**: Wait for the user to approve, request modifications, or reject. Do NOT exit plan mode or start implementing automatically. When approved, the local agent implements following the agreed contracts exactly.

## Command Execution

Always use heredoc for multi-line prompts to Codex.

### Round 1 — Initial Call

Include ALL required flags. Use `--json` to capture the session ID from the JSONL output. **Always redirect stdin with `< /dev/null`** — when invoked from any non-interactive shell (agent harnesses running shell tools, CI runners, background processes, scripts piping into other commands), stdin is non-TTY but still open, and Codex CLI hangs on "Reading additional input from stdin..." instead of using the prompt argument. Closing stdin forces Codex to rely solely on the positional prompt:

```bash
codex exec --json -s read-only --skip-git-repo-check "$(cat <<'PROMPT'
Your multi-line prompt here...
PROMPT
)" < /dev/null

# If the user overrode model and/or effort in their trigger message, add them:
# codex exec --json -m <model> -c model_reasoning_effort="<effort>" -s read-only --skip-git-repo-check "..." < /dev/null
```

After execution, parse the session ID from the JSONL output and store it for subsequent rounds.

### Round 2+ — Session Continuation

Use `codex exec resume` with the captured session ID. Session settings (model, sandbox, reasoning effort) are inherited — no need to re-pass flags:

```bash
codex exec resume <SESSION_ID> "$(cat <<'PROMPT'
Your follow-up prompt here...
PROMPT
)" < /dev/null
```

The `< /dev/null` redirection is required on every `codex exec` and `codex exec resume` call for the same reason explained in Round 1 — without it, the process hangs waiting for stdin in non-interactive contexts.

### Timeouts

Set a generous timeout (up to 10 minutes) for Codex calls since high reasoning efforts can take time:

```bash
# In Bash tool, use timeout: 600000
```

### Required Flags Checklist (Round 1 only)

The initial `codex exec` call MUST include these flags (in any order):
- `--json` — JSONL output to capture session ID
- `-s read-only` — enforce read-only sandbox
- `--skip-git-repo-check` — avoid trusted directory errors
- `< /dev/null` (stdin redirection, not a flag) — required to prevent Codex CLI from hanging waiting for stdin input in non-interactive contexts

Optional flags (pass ONLY when the user overrides defaults in the trigger message):
- `-m <model>` — model to use (otherwise inherited from `~/.codex/config.toml`)
- `-c model_reasoning_effort="<effort>"` — reasoning effort (otherwise inherited from `~/.codex/config.toml`)

Subsequent `codex exec resume` calls only need the session ID and the prompt — all settings are inherited from the original session. The `< /dev/null` redirection is still required.

## Important Rules

- **Never skip the read-only constraint**. Include it in the initial prompt and enforce via `-s read-only`. With session persistence, Codex retains this constraint across rounds.
- **Never auto-implement fixes**. The user decides what to act on.
- **Pass paths, not content**. Never inline file contents or diffs. Give Codex file paths, directory paths, or git commands and let it read on its own. Only inline content that doesn't exist as files (plans, requirements, conversation context).
- **KISS**. Both sides should favor the simplest solution. If a simpler approach works, prefer it.
- **Be a fair debater**. Accept valid findings from Codex. Don't dismiss observations without specific reasoning.
- **Track rounds explicitly**. Maintain a mental count and summarize progress periodically.
- **Keep Codex independent**. Never instruct Codex to follow AGENTS.md / CLAUDE.md as a rulebook. The local agent may cite AGENTS.md / CLAUDE.md conventions in its own arguments, but Codex is free to challenge them.
- **Agree on implementation, not just findings**. Never close a review with abstract action items. Every critical/major finding must have an agreed implementation contract before the review is complete. When implementing after review, follow the contracts exactly.
