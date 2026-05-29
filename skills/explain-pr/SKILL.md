---
name: explain-pr
version: 1.0.0
description: "Explain a GitHub Pull Request (PR) or GitLab Merge Request (MR) to the user in plain, easy-to-understand language: WHAT was done, WHY/what for, and HOW — with the relevant code snippets embedded. Invoke this proactively and automatically right after creating or finishing a PR/MR (e.g. after running `gh pr create`, `glab mr create`, or pushing a branch and opening a PR/MR), even if the user did not explicitly ask for an explanation. Also use whenever the user asks to explain, summarize, walk through, recap, or 'tell me what you did' about a PR/MR or the changes in a branch. Works with any coding agent and relies on the local git diff, so it does NOT require gh/glab to function. Do NOT use for unrelated code reviews, bug hunting, or writing the PR/MR description itself — this skill only explains finished work back to the user."
---

# Explain PR — explain a PR/MR in plain language

Turn a freshly created Pull Request / Merge Request into a clear, friendly explanation the user can read in one pass to understand **what** changed, **why** it was done, and **how** it works — with the relevant code shown inline.

This replaces the manual prompt a user would otherwise type ("explain what you did, why, and how, in simple terms, with the relevant code"). The point is that the user shouldn't *have* to ask: once a PR/MR exists, they almost always want this recap.

## When to use this skill

Trigger it on your own, without waiting to be asked, right after a PR/MR is created or finished — that's the moment the user wants the recap. Concretely:

- Just after `gh pr create`, `glab mr create`, or opening a PR/MR through any other means.
- When the user says things like "explica lo que hiciste", "explain the PR", "what did you change?", "walk me through this MR", "recap the changes".

If you just finished a PR/MR in this same conversation, you already did the work — you know most of the *why* firsthand. Use that, but still anchor the *what* and *how* in the real diff (see below) so nothing is misremembered or invented.

## What this skill does NOT do

- It does **not** post anything to the PR/MR (no comments, no description edits). The explanation goes to the user, in the chat, and nowhere else. The user can copy it somewhere if they want.
- It does **not** review the code, hunt for bugs, or suggest improvements. It explains finished work. If the user wants a critique, that's a different task.
- It does **not** reformat, rename, or "improve" anything in the diff.

## Process

### 1. Determine the change set

You're explaining the changes a branch introduces relative to its base. Find that range, in this order of preference:

1. **Use what you already know.** If you created the PR/MR in this conversation, you know the base branch (often `main`/`master`/`develop`) and the title/description you wrote. Start there.
2. **Ask the tooling, if present.** If `gh`/`glab` is available and you're unsure of the base:
   - GitHub: `gh pr view --json baseRefName,title,body,commits`
   - GitLab: `glab mr view`
   These also hand you the title and description — useful for the *why*.
3. **Fall back to git heuristics.** Pick the base branch that exists (`main`, then `master`, then `develop`), then use it below.

Once you know the base branch, read the actual changes (the `...` form diffs against the merge-base, which is what a PR/MR shows):

```bash
git diff <base>...HEAD --stat   # scope first: which files, how much
git log  <base>..HEAD --oneline # the commits on this branch
git diff <base>...HEAD          # the actual changes
```

Look at `--stat` first to gauge scope, then read the diff. For a large diff, don't dump everything — focus on the changes that carry the intent and skim or skip noise (lockfiles, generated files, pure formatting, vendored code). Mention that you skipped them rather than pretending they don't exist.

If you can't establish a clean range (e.g. the PR is already merged, or you're sitting on the base branch), say so and work from the most recent commits and the conversation context instead of guessing silently.

### 2. Gather the "why"

The diff tells you *what* and *how*, but rarely *why*. Pull the intent from, in order: the conversation you just had, the PR/MR title and description, the commit messages, and any referenced issue/ticket. If, after all that, the reason for a change genuinely isn't recoverable, say so plainly ("no encontré en qué se basa este cambio") instead of inventing a motivation. A confident-sounding made-up reason is worse than an honest gap.

### 3. Write the explanation

Compose the recap using the structure below. Keep it grounded: every code snippet you show must come from the real diff, with a `path/to/file.ext:line` reference so the user can click straight to it.

## Output structure

Deliver it in the chat using **exactly these three sections, always, in this order** (translate the headings into the conversation's language). This fixed shape is the whole point: it makes the output predictable across runs, models, and agents instead of leaving the format up to each model's interpretation. A reader should recognize the layout at a glance, every single time.

```
## 📋 Qué hice
<1–3 sentences, plain language: the change in a nutshell. No jargon dumps.>

## 🎯 Por qué / para qué
<The problem, need, or goal this addresses. Tie it to the user's intent.>

## 🔧 Cómo lo hice
<The approach, walked through in the order that makes it easiest to follow.
 Embed the relevant code as fenced blocks with a `file:line` reference, e.g.:>

`src/auth/token.ts:42`
​```ts
export function verifyToken(raw: string) {
  // ...the actual lines from the diff...
}
​```

<Explain what each shown snippet does and why it matters. Group related
 changes together rather than going file-by-file in arbitrary order.>
```

Keep all three sections even for a tiny PR (a one-line fix, a config tweak) — that consistency is what makes the output predictable. What scales with the size of the change is the *amount of detail inside* each section, not whether the section exists: for a trivial change each section can be a single line; for a large PR, lead **Cómo lo hice** with the headline change, group the rest by area, and prioritize what a reviewer most needs to understand. Trim filler, never drop a section.

**Pin each snippet to the real line.** The `file:line` reference must point to where the code actually lives so the user clicks straight to it — don't default to `:1`:

- Modified file → the line of the actual change. Read the diff's hunk headers (the `@@ -x,y +a,b @@` markers give you the new line numbers), or grep the file for the changed code to find its current line.
- New file → `:1`, or the line where the relevant function/section starts.

**Show the *before* when a change alters existing behavior.** Seeing only the final code hides what actually changed. When a PR modifies behavior that already existed, include the prior version too — a `// antes` / `// después` pair of snippets, or a short before/after table — so the contrast makes the change obvious. Get the base side from `git show <base>:<path>` or the `-` lines of the diff. Skip this for brand-new files (there's no "before") and for trivial changes where it would just add noise; the goal is clarity, not ceremony.

## How to write it (behavioral rules, and why)

- **Match the conversation's language.** Write the whole explanation in whatever language the user has been speaking. If they've been writing in Spanish, explain in Spanish; if English, English. The user reads this to understand their own project — meet them where they are.
- **Scale detail, not shape.** The three sections are always present; what varies with the PR's size is how much you write inside them — terse for a small change, fuller for a big one. Keeping the shape fixed while flexing the depth is deliberate: it's what gives the user a predictable output instead of a fresh improvisation each time, without padding trivial changes or rushing large ones.
- **Anchor everything in the real diff.** The *what* and *how* must reflect code that's actually in the diff — real file paths, real lines. This is the guardrail against plausible-sounding fiction. The *why* can come from context, but flag it when it's missing rather than filling the gap with a guess.
- **Plain over precise-but-dense.** Favor language a teammate could skim and get. Define a term if the change introduces an unusual one, but don't lecture. The user asked for "fácil y simple de entender" — honor that.
- **Explain, don't review.** Resist the urge to critique or suggest. If you genuinely spot something that looks wrong, you can flag it in one line at the end, but the body stays explanatory.

## Example (shape, not content)

For a PR that adds rate limiting to an API endpoint, a good recap reads like:

> **📋 Qué hice** — Agregué un límite de requests por IP al endpoint de login para frenar intentos de fuerza bruta.
>
> **🎯 Por qué** — Veníamos sin protección contra brute force en `/login`; un atacante podía probar miles de contraseñas. Esto cierra esa puerta.
>
> **🔧 Cómo** — Metí un middleware con una ventana deslizante… *(then the actual middleware snippet with its `file:line`, and a line on how it's wired in).*

The headings are fixed; the prose, snippets, and depth come from the actual change.
