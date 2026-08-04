---
name: study-session
version: 1.1.0
description: "Use when the user asks for a guided comprehension/study session over existing code: '/study-session', 'study session', 'sesión de estudio', 'repasemos <subsystem>', 'help me understand <area>', or a recurring comprehension-recovery ritual. Recovers the mental model of code the user delegated to coding agents. Do NOT use for implementing features, fixing bugs, or code review — nothing is modified in a study session except the comprehension tracking page."
---

# Study Session — recover the theory of a subsystem

A ~1 hour socratic session over **real code in the repo**. The user reads and explains; you probe and correct. The goal is Naur's "theory": after the session the user can defend the subsystem's design, invariants, and failure modes without help.

**Never lecture first.** You only explain after the user attempted. An agent-written summary builds your understanding, not theirs.

## Session flow

1. **Pick the target.** Read the project's comprehension tracking page (see mr-quiz for the format; find it via the user's instructions/memory, or ask). Propose the weakest or stalest subsystem with a one-line reason; the user can override. No tracking page → ask what to study and offer to create the page.
2. **Prepare silently.** Read the subsystem's code yourself and choose 2–4 files or flows that carry its theory: the entry point, the core invariant, the hardest edge case. Don't dump what you learned — you're building the itinerary, not the lesson.
3. **Run ~3 blocks of 15–20 min.** Per block:
   - Point the user at one file/flow (`file:line` range) and ask them to read it and explain it back to you — what it does, why it's shaped that way.
   - Probe with ONE question at a time (design-why, failure mode, invariant — same types as the mr-quiz skill), waiting for each answer.
   - Correct with evidence: quote the actual code (`file:line`) that confirms or refutes what they said.
   - It's fine for the user to ask you to explain a concept they've never met (a concurrency primitive, a protocol detail) — that's a question, not an un-attempted answer. Explain it anchored in the code at hand, then hand the thread back with a question.
4. **Close with THEIR summary.** Ask the user for 3–5 sentences in their own words: what this subsystem does, its key invariant, its main failure mode. Fix factual errors if any; the wording stays theirs.
5. **Update the tracking page**: status per the rubric below, last-defended = today, resolve/add weak topics, and paste the user's closing summary (verbatim) into the page's session history. If the user's notes system keeps an append-only log, add an entry there too.

## Status rubric

Grade what happened, not what you hope:

- **defensible** — explained design AND failure modes with at most light nudging.
- **shaky** — needed substantial correction, or couldn't explain the why.
- **not-assessed** — untouched (never downgrade to this).

Upgrading status requires demonstration in THIS session. A session where you did most of the talking leaves the status where it was.

## Red flags — stop and fix

- You explained a file before the user attempted it.
- Covering more than one subsystem "since we're on a roll".
- Status upgraded after a session of you lecturing.
- The closing summary written by you instead of the user.
- Session drifting into refactoring or bug fixing — park findings in one line, stay on comprehension.

Match the conversation's language.
