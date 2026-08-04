---
name: pr-quiz
version: 1.1.0
description: "Use when a PR/MR explanation was just delivered (e.g. right after the explain-pr skill finishes) and the change was substantially agent-written, or whenever the user asks to be quizzed on a change: 'quiz me on this change', 'tomame el quiz', 'quiz del MR', 'tomame la lección', '/pr-quiz'. Counters comprehension debt: verifies the user can defend code they delegated to a coding agent. Do NOT use for code review, bug hunting, or explaining changes (that's explain-pr) — this skill asks questions and grades answers."
---

# MR Quiz — can you defend this change?

The user just shipped a change that an agent largely wrote. The explanation (`explain-pr`) told them what/why/how; this skill verifies the understanding actually landed, by making **the user** articulate it. Evidence on AI-assisted coding shows delegation without active recall hollows out the mental model — answering questions is the active recall.

**The user answers. You grade. Never the other way around.**

## The quiz contract

1. **Ground yourself in the real diff.** Same range as explain-pr (`git diff <base>...HEAD`). You usually just explained it — reuse that knowledge.
2. **Pick 3–5 questions** (3 for small changes, 5 for large ones) from the question types below, tailored to this specific change. Skip the quiz entirely only for pure-noise changes (lockfile bumps, formatting) — say so in one line.
3. **Ask ONE question per message.** Send question 1, end your turn, wait for the answer. Never list all questions upfront.
4. **Grade each answer before the next question**, with a three-level verdict and code evidence:
   - ✅ **solid** — correct and complete for the question's scope.
   - 🟡 **partial** — right direction, missing a piece. Name the missing piece, show the `file:line` that proves it.
   - ❌ **weak** — wrong or "I don't know". Give the real answer briefly, anchored in `file:line`.
   "I don't know" is a legitimate answer — grade it ❌ without ceremony and teach the answer. Guessing dressed as knowledge is worse.
5. **Close with a scorecard**: one line per question (verdict + topic), then the list of weak topics (🟡/❌).
6. **Update the tracking page** if the user keeps one (see below). Record only what the user demonstrated — verdicts and weak topics, never theory they didn't articulate.

## Question types

Ask what a colleague, reviewer, or 3 AM incident would ask — never trivia (names of functions, line counts).

| Type | Shape |
|---|---|
| Design-why | "Why was this solved with X and not Y?" |
| Failure mode | "What happens if <dependency/input> fails or arrives malformed?" |
| Blast radius | "What other part of the system does this touch? Who consumes it?" |
| Invariant | "What guarantees that <property> still holds?" |
| Operational | "How would you find out in production that this broke?" |

## Grading honestly

The entire value of the quiz is calibration. A 🟡 graded as ✅ is a lie that costs the user at incident time. State plainly what was missing; quote the code that proves it. No "exactly!" unless it actually was.

## Tracking page

If the user keeps a per-project comprehension map (a markdown page tracking which subsystems they can defend), update the affected subsystem's row: status only if demonstrated, last-defended = today, weak topics += the scorecard's 🟡/❌ items. To find it: use the location the user's instructions or memory name; otherwise ask once. If they don't have one, offer to create it:

```markdown
# <Project> — comprehension map
| Subsystem | Repo/path | Status | Last defended | Weak topics |
|---|---|---|---|---|
| ... | ... | not-assessed | — | — |
```

Statuses: **defensible** (explained design and failure modes unaided) / **shaky** (needed heavy correction) / **not-assessed**. The golden rule of the page: it only records what the user demonstrated in a quiz or study session — never agent-written theory.

## Red flags — stop and fix

- All questions in one message.
- Answering your own question before the user tried.
- ✅ verdict for an answer you had to complete.
- Trivia questions.
- Recording understanding the user didn't demonstrate.

Match the conversation's language (quiz in Spanish if the user speaks Spanish).
