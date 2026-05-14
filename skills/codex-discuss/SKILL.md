---
name: codex-discuss
version: 1.0.0
description: "Iterative non-code discussion between the local agent and Codex CLI on any topic — diet, fitness, writing, decisions, strategy, study plans, life choices, brainstorming, or any open-ended subject. Orchestrates an automatic back-and-forth debate where both agents critique, propose alternatives, and iterate on the user's idea until reaching consensus. Codex CLI runs READ-ONLY and forms its own opinions (it does not navigate the filesystem since the topic lives in conversation context, not files). Model and reasoning effort are inherited from the user's local Codex configuration at ~/.codex/config.toml, overridable per invocation. Use when the user says discuss with codex, iterate with codex, consult codex, debate with codex, ask codex for a second opinion, get codex's take, brainstorm with codex, or any variant asking Codex CLI to weigh in on a non-code topic — including the user pasting or describing a plan, draft, idea, decision, or proposal and wanting a critical iterative review. Does NOT trigger on: code review, plan-mode review of implementation plans, architecture discussions, or any technical software-engineering analysis — use codex-review for those."
---

# Codex Discuss — Iterative Non-Code Consensus Skill

Orchestrate an iterative debate between the local agent and Codex CLI on any non-code topic — diet, fitness, writing, decisions, strategy, brainstorming, or anything open-ended — until both reach consensus.

**Guiding principle: Simplicity + evidence-first.** The simplest proposal that fits the user's evidence and stated assumptions wins. Added complexity must be justified by concrete benefit, not "just in case." Both sides should challenge each other to keep proposals lean and grounded.

## Codex Independence

Codex is an **independent contributor**, not a yes-man. Do NOT load Codex with the local agent's pre-formed conclusions or framing. Codex should form its own opinions based on the topic and content provided.

- **The local agent** forms its own critical reading and proposals, kept internal until round 2
- **Codex** weighs in with its own reasoning — it may agree, partially agree, disagree, or surface considerations the local agent missed
- **When they disagree**: each side argues on merits with concrete reasoning (evidence, trade-off analysis, examples, counter-examples). The debate resolves on substance, not deference.
- **If truly unresolved**: flag it explicitly so the user decides

Give Codex only what it needs: the topic content, the user's stated goal, and any constraints — not a rubric of "the right answer."

## Codex CLI Configuration

- **Model & reasoning effort**: NOT hardcoded — Codex CLI reads them from `~/.codex/config.toml` (top-level `model` and `model_reasoning_effort` keys, or whichever profile is active). Do NOT pass `-m` or `-c model_reasoning_effort` unless the user explicitly overrides them in their trigger message.
- **Command**: `codex exec -s read-only --skip-git-repo-check "prompt" < /dev/null` — minimal canonical form. Add `-m <model>` and/or `-c model_reasoning_effort="<effort>"` only when the user overrides them. The `< /dev/null` is mandatory (see Command Execution for why).
- **CRITICAL**: Codex CLI must NEVER modify files. Always pass `-s read-only` and include the read-only constraint in every prompt sent to Codex.

### Model and Reasoning Effort

Defaults come from the user's `~/.codex/config.toml` (top-level `model` and `model_reasoning_effort` keys, or the active profile). The skill does NOT hardcode them and does NOT need to know what they are. If the user has nothing configured there, Codex CLI falls back to its own internal defaults — also not the skill's concern.

Pass `-m` or `-c model_reasoning_effort="..."` ONLY when the user explicitly overrides them in their trigger message (e.g., "discuss with codex using gpt-5.4", "iterate with codex effort medium").

**IMPORTANT CLI syntax**: Reasoning effort is NOT a CLI flag — when overriding, use the `-c` config override: `-c model_reasoning_effort="<value>"`. The `--reasoning-effort` flag does not exist and will cause an error.

```bash
# Default — Codex uses whatever is in ~/.codex/config.toml
codex exec -s read-only --skip-git-repo-check "prompt" < /dev/null

# User overrides model only (e.g., "discuss with codex using gpt-5.4")
codex exec -m gpt-5.4 -s read-only --skip-git-repo-check "prompt" < /dev/null

# User overrides reasoning effort only (e.g., "iterate with codex effort medium")
codex exec -c model_reasoning_effort="medium" -s read-only --skip-git-repo-check "prompt" < /dev/null

# User overrides both
codex exec -m gpt-5.4 -c model_reasoning_effort="medium" -s read-only --skip-git-repo-check "prompt" < /dev/null
```

If the user provides an override, use the same value for ALL rounds within the session. Do not change it mid-discussion. (Round 2+ uses `codex exec resume`, which inherits session settings — no need to re-pass flags.)

### Trust and Git Repo Check

**Always pass `--skip-git-repo-check`** in every `codex exec` call. Without it, Codex CLI will refuse to run if the working directory is not inside a trusted git repository — this causes failures when the local agent invokes the skill from directories not yet marked as trusted in Codex's config. Since we always run in read-only mode, skipping this check is safe.

**`codex exec resume` does NOT accept `--skip-git-repo-check`** (the flag is ignored or rejected). For resume calls, the cwd must be a real git repository (a directory containing `.git/`). Setting `[projects."<path>"].trust_level = "trusted"` in `~/.codex/config.toml` is NOT sufficient — Codex still requires the `.git/` directory. **Practical workaround**: if the initial `codex exec` ran from a non-git cwd, `cd` into any git-tracked directory before issuing `codex exec resume`. The session is global — the cwd at resume time is independent of the cwd at the original `codex exec`.

### Session Persistence

Codex CLI auto-persists sessions to `~/.codex/sessions/`. Use this to maintain a **continuous conversation** across all rounds — Codex retains its own analysis, reasoning, and the full discussion history.

**How it works:**

1. **Round 1**: Run `codex exec --json` with all required flags. Parse the session ID from the JSONL output (look for a `session_id` field). Store it for all subsequent rounds.
2. **Round 2+**: Run `codex exec resume <SESSION_ID> "prompt"`. This continues the existing conversation with full prior context. No need to re-pass `-m`, `-s`, `-c`, or `--skip-git-repo-check` — session settings are inherited.

**Why this matters**: Without `resume`, each `codex exec` starts a blank session — Codex loses its own previous analysis, can contradict itself, and follow-up prompts must re-summarize everything. With `resume`, the conversation flows naturally and follow-up prompts are minimal.

**Parallel safety**: Always capture and use the specific session ID — never use `--last`, which would pick up the wrong session if multiple discussions run concurrently.

## Inline Content vs Paths

**Critical difference from code review**: the topic of discussion lives in the **conversation context**, not in files. Codex has no other way to retrieve it — so you DO inline the content when prompting Codex.

**What to inline** (Codex cannot access these on its own):
- The user's idea, plan, draft, decision, or topic — verbatim or summarized faithfully (don't paraphrase in a way that changes substance)
- The user's stated goal, success criteria, or hard constraints
- Background context the user provided (current state, prior attempts, preferences, what they've already ruled out)

**What to pass as paths** (let Codex read):
- Files the user explicitly attached or referenced (PDF of a plan, a draft document, a spreadsheet) — give the path, don't paste the contents
- Local notes or documents the user pointed at by path

**What NOT to inline**:
- Web pages or external articles Codex cannot verify — if you must reference them for context, quote sparingly and flag as unverified
- Long boilerplate or repeated material — summarize

## Round Efficiency — Minimize Iterations

Each round costs time and tokens. Maximize the value of every round.

### Local Agent Pre-Analysis (Before Round 1)

Before calling Codex, the local agent MUST form its own critical reading of the topic. Identify weak points, missing evidence, hidden trade-offs, biases, and alternatives — with severity. **Keep these internal.** Do NOT send them in round 1. Codex's first response must be unbiased.

After round 1, compare Codex's points against your internal list:
- **Overlap** → immediately agree (saves a round)
- **Codex-only points** → evaluate on merits, agree or prepare counter-arguments
- **Local-only points** → introduce them in round 2 as "Additional Observations"

### Batch Everything

Both sides MUST respond to ALL pending points in each round. Never address a single point per round. Every response should cover:
- Agreements/disagreements on every point raised
- All new observations (don't hold back findings for later)
- All counter-arguments at once

### Severity-Based Discussion

Only debate **critical** and **major** points. For minor/suggestion severity:
- Accept them without debate unless there's a strong reason to disagree
- List them in the "Agreed" section immediately
- Don't burn a round arguing about preferences or minor improvements

### Exhaustive First Round

Instruct Codex to be exhaustive in its first response — cover everything it can find. A longer first response is better than several short rounds discovering things incrementally.

## Evaluation Focus Areas

Beyond the topic-specific content, actively look for:

- **Unvalidated assumptions**: claims taken for granted that deserve examination (e.g., "I need 3000 kcal/day" without evidence on actual expenditure; "this email tone is fine" without checking how the recipient might read it)
- **Trade-offs, explicit vs hidden**: every choice has costs — surface the ones the proposal glosses over (time, money, relationships, opportunity cost, sustainability, reversibility)
- **Risks and failure modes**: what can go wrong, how likely, how bad, how recoverable
- **Missing evidence or sources**: claims that would benefit from data, measurement, or testing before committing
- **Cognitive biases**: confirmation bias, sunk cost, recency bias, anchoring, planning fallacy — flag when the reasoning shows the pattern
- **Alternatives not considered**: at least one viable alternative the user did not enumerate
- **Internal coherence**: contradictions between stated goal and proposed steps, or between different parts of the proposal
- **Time horizon and sustainability**: short-term wins vs. long-term cost; is the plan sustainable for its stated duration?
- **Scope creep**: is the proposal trying to solve more than the stated problem?

Not all apply to every topic — pick what fits the subject at hand. A dietary plan needs different focus than an email draft; a career decision needs different focus than a gym routine.

## Workflow

### 1. Gather Context and Pre-Analyze

Identify what is being discussed from the conversation context:

- **Plan or idea review**: extract the full plan/idea as the user stated it, plus their stated goal
- **Draft review (writing)**: the text the user wants iterated on, plus audience and purpose if stated
- **Decision evaluation**: the decision, the options the user considered, the constraints, the user's current leaning if any
- **Brainstorming**: the seed idea and the boundaries of the brainstorm (what's in scope, what's not)

**Then, do your own pre-analysis.** Read the topic carefully, form your own findings (with severity), and keep them internal. Do NOT include them in the initial prompt — they get introduced in round 2 after Codex's unbiased response.

### 2. Craft Initial Prompt to Codex

Structure the first prompt to Codex. Inline the topic content (it lives in conversation, not in files).

```
You are participating in a collaborative non-code discussion.
You are operating in READ-ONLY mode — do NOT modify, create, or delete any files.

## Context
[Brief: what the user is trying to figure out, why this discussion is happening, any high-level
constraints. Keep it short — just enough for Codex to orient.]

## Topic Under Discussion
[Full content of the user's idea/plan/draft/decision, inline and verbatim where possible.
This is the substance of the discussion — be faithful to what the user actually said.]

## User's Goal and Constraints
[What the user wants out of this. Stated success criteria, hard limits (time, money, health,
relationships), things already ruled out, preferences.]

## Your Task
Read the topic and evaluate it on its own merits. Be EXHAUSTIVE in this first response — cover
everything you can find. Better to be thorough now than to discover things in later rounds.

## Evaluation Focus Areas
Look for what's relevant — not all apply to every topic:
- Unvalidated assumptions
- Trade-offs (explicit vs. hidden)
- Risks and failure modes
- Missing evidence or sources
- Cognitive biases in the reasoning
- Alternatives not considered
- Internal coherence
- Time horizon and sustainability
- Scope creep

## Instructions
- Form your own opinion. Don't try to validate any pre-existing framing.
- Provide findings with severity (critical/major/minor/suggestion)
- Explain WHY each finding matters, not just WHAT
- Reference specific parts of the user's content
- Propose concrete alternatives where relevant
- For minor/suggestion findings: only flag them, no deep discussion needed
- If you need clarification on the user's intent or constraints, ASK — don't speculate
- For topics in regulated domains (health, legal, financial), flag when professional consultation is warranted
- When you have no more findings or observations, explicitly state: "No further observations."
```

Execute this prompt using the round 1 command format (see Command Execution). **Capture the session ID** from the `--json` JSONL output — all subsequent rounds use `codex exec resume <SESSION_ID>` to continue this conversation.

### 3. Iterative Loop (max 10 rounds per cycle)

**After Round 1 (Codex's unbiased response):**

Compare Codex's findings against your internal pre-analysis:
- **Overlap**: findings both sides found independently → immediately mark as agreed
- **Codex-only findings**: evaluate on merits — agree or prepare counter-arguments
- **Local-agent-only findings**: these become your "Additional Observations" in round 2

**For each subsequent round:**

1. **Send follow-up to Codex** via `codex exec resume <SESSION_ID> "prompt"` (use heredoc for multi-line prompts). Codex has full context from all prior rounds — no need to re-summarize the discussion.
2. **Analyze Codex's response**: identify findings, agreements, disagreements, or questions
3. **Formulate the local agent's response**:
   - If Codex asks for more context: provide it
   - Agree with valid findings
   - Counter-argue with specific reasoning when disagreeing (reference the topic content, evidence, or constraints)
   - Add observations Codex may have missed (from your pre-analysis or newly discovered)
   - Ask clarifying questions if Codex's finding is ambiguous
4. **Check for consensus**: if BOTH sides have no new findings and all disagreements are resolved, exit the loop

**Follow-up prompt structure:**

Since Codex retains full context via session persistence, follow-up prompts are minimal — just the local agent's new input for the ongoing conversation.

```
## My Response to Your Findings
[Agreements, disagreements, and counter-arguments for each finding Codex raised — address ALL of them at once]

## Additional Observations
[New findings from the local agent, if any — don't hold back for later rounds]

## Open Questions
[Any clarifications needed, if any]

Respond to ALL my points at once. If you agree with everything and have nothing more to add, state: "No further observations."
```

**Consensus detection**: the loop ends when Codex responds with "No further observations" (or equivalent) AND the local agent also has nothing more to add.

### 4. Round Limit Handling

After 10 rounds without consensus:
- Pause and notify the user
- Present a summary of: agreed findings, unresolved disagreements, each side's position
- Ask the user whether to continue for another 10 rounds or stop with the current state

### 5. Concrete Agreements (critical/major findings only)

After findings consensus, the discussion is NOT done yet. Abstract agreement ("increase protein", "tighten the email", "consider alternatives") leads to vague follow-through. Both sides must now agree on **what the user will concretely do** for each critical/major finding.

Skip this phase only if there are no critical/major findings that require action (e.g., the discussion found only minor items, or findings are purely observational).

**A concrete agreement specifies:**
- **What exactly**: the specific change, not a category
- **How much / how often**: numbers, frequency, magnitude
- **When**: timing, order, sequencing if multiple changes
- **Conditions**: when the change kicks in, when it doesn't
- **How we'll know it's working**: the observable signal that the change is having the intended effect

**Why this matters**: "Increase protein" is ambiguous — could be 5 g, 50 g, at every meal, only post-workout, for a week or forever. A concrete agreement removes that ambiguity. The user (or anyone else reading the consensus report) knows exactly what was agreed to.

**Example contrast (diet)**:
- Vague: "increase protein"
- Concrete: "increase protein to 1.8 g/kg/day, distributed across 4 meals — add 30 g chicken breast at dinner and 20 g Greek yogurt at breakfast, starting Monday. Re-evaluate in 4 weeks: target signal is +0.5 kg lean mass on the scale and recovery feeling improved (self-reported)."

**Example contrast (email)**:
- Vague: "make the ask clearer"
- Concrete: "move the ask to the first paragraph. Replace 'I was wondering if maybe we could perhaps' with 'Can we [specific action] by [date]?'. Cut the second paragraph that re-explains context the recipient already has."

**Example contrast (decision)**:
- Vague: "weigh the pros and cons more"
- Concrete: "before deciding by Friday, list the top 3 outcomes you'd regret most under option A and option B. If the worst-regret list under A is recoverable within 6 months and B's isn't, pick A. Otherwise pick B."

**Process:**

1. The local agent drafts a concrete agreement for each critical/major finding.
2. Send ALL drafts to Codex via `codex exec resume <SESSION_ID>` (same session):

```
We agreed on the findings. Now let's agree on the CONCRETE actions for each so there's no ambiguity for the user.

For each critical/major finding, I'm proposing a specific action. Please review each one and:
- AGREE if it's specific and well-targeted
- COUNTER-PROPOSE if you'd structure it differently (explain why, provide alternative)
- ASK if you need more info to evaluate

## Concrete Agreement 1: [Finding title]
**Finding**: [brief reference to the agreed finding]
**What exactly**: [specific change]
**How much / how often**: [numbers, frequency]
**When**: [timing, sequencing]
**Conditions**: [when it applies / doesn't]
**Signal it's working**: [observable indicator]

## Concrete Agreement 2: [Finding title]
...

Respond to ALL agreements at once. For each, state AGREE, COUNTER-PROPOSE, or ASK.
When you have no objections, state: "All agreements approved."
```

3. Iterate until both sides agree on every action (same batching rules, max 5 rounds for this phase).

4. If an agreement can't be reached after 5 rounds, flag it as "unresolved action" — the user decides.

### 6. Final Output

Present to the user:

```markdown
## Codex Discussion — Consensus Report

### Summary
[1-2 sentences: what was discussed, how many rounds (findings + actions), outcome]

### Findings (Agreed)

#### Critical
- [Finding with reference to the topic content and why it matters]

#### Major
- [Finding with reference and explanation]

#### Minor
- [Finding briefly stated]

#### Suggestions
- [Improvement ideas]

### Concrete Agreements

#### [Finding 1 title]
- **What exactly**: ...
- **How much / how often**: ...
- **When**: ...
- **Conditions**: ...
- **Signal it's working**: ...

#### [Finding 2 title]
...

### Unresolved (if any)
- [Topic]: local agent's position vs. Codex's position — **user decides**

### Caveats
- [If applicable: limits of this analysis, domains where professional consultation is warranted]

### Discussion Log
<details>
<summary>Full discussion (N findings rounds + M action rounds)</summary>

**Round 1 — Codex**: [summary]
**Round 1 — local agent**: [summary]
...
</details>
```

**IMPORTANT**: Do NOT take any external action automatically (don't message anyone, don't change calendars, don't book anything, don't apply changes to files unless the user explicitly asks afterward). Present the report and wait for the user to decide what to act on.

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
- **Never act on the user's behalf automatically**. The user decides what to do after the discussion — don't send messages, change calendars, book anything, or apply edits unless explicitly asked.
- **Inline the topic, pass paths for files**. The substance of the discussion lives in conversation context — inline it faithfully. If the user attached files, pass paths and let Codex read them.
- **Simplicity + evidence-first**. Both sides favor the simplest proposal that fits the evidence. Complexity needs justification, not "just in case."
- **Be a fair debater**. Accept valid findings from Codex. Don't dismiss observations without specific reasoning.
- **Track rounds explicitly**. Maintain a count and summarize progress periodically.
- **Keep Codex independent**. Don't load Codex with your pre-formed conclusions. Let it react to the content.
- **Agree on the concrete, not just the abstract**. Never close with vague action items. Every critical/major finding gets a concrete agreement (what exactly, how much, when, signal) before the discussion is done.
- **Don't pretend to be a domain expert**. For health, legal, financial, medical, or other professionally-regulated topics, both agents can reason about trade-offs and structure but MUST flag when the user should consult a qualified human professional. Be explicit about the limits of this analysis in the Caveats section of the final report.
