---
name: ste
version: 1.1.0
description: "Use when the user asks to write, rewrite, translate, or check text in Simplified Technical English — any mention of STE, STE100, ASD-STE100, Simplified Technical English, 'inglés técnico simplificado', 'inglés controlado', 'controlled English', 'lenguaje controlado', 'en STE', 'reescribí esto en STE', 'redactá este procedimiento / warning / manual en STE', or a request to check procedures, warnings, manuals, or technical descriptions for STE compliance. Do NOT use for generic simplification or ELI5-style requests that do not mention STE or a controlled language."
---

# STE — Simplified Technical English (ASD-STE100)

STE is a controlled language: ~53 writing rules plus a dictionary of 875 approved
words where each word has exactly one meaning and one part of speech. Compliance
with the dictionary CANNOT come from memory — words you would swear are approved
("qualified", "ensure", "perform") are not. Every claim of compliance in your
output must come from a lookup, not from intuition.

STE is defined for English only. You always write the STE text in English first,
verified against the official dictionary. If the user asked in another language
or asks for a translation, you translate FROM the verified STE English as a
second pass — never draft directly in the other language.

## When to use

- "Reescribí esto en STE" / "rewrite this in Simplified Technical English"
- "Explicame X en STE" — draft the explanation in STE English, then translate if asked
- "Redactá este warning / procedimiento en STE"
- "¿Esto cumple ASD-STE100?" — compliance check of existing text

Not for generic "make it simpler" requests that never mention STE or controlled
language.

## Step 0 — Get the official dictionary (cached)

```bash
C="${XDG_CACHE_HOME:-$HOME/.cache}/asd-ste100"
if [ ! -s "$C/ste100.txt" ]; then
  mkdir -p "$C"
  curl -sL -o "$C/spec.pdf" "https://www.asd-ste100.org/assets/files/ASD-STE100_ISSUE9.pdf"
  pdftotext "$C/spec.pdf" "$C/ste100.txt"
fi
```

`pdftotext` comes with poppler (`poppler-utils` on Debian). If the download or
extraction fails, continue with the workflow and mark every dictionary claim as
unverified in the compliance note (see below).

## Workflow

1. Read `references/rules.md` in this skill directory — the distilled Issue 9
   rules. Draft nothing before reading it.
2. Draft the text in STE English, applying the rules for the text type
   (procedural: ≤20 words/sentence, imperative; descriptive: ≤25 words, no
   imperative; safety instruction: WARNING/CAUTION → command or condition →
   consequence).
3. Verify the vocabulary. Write the draft to a file and run the checker script
   (in this skill directory) — one deterministic pass over every word:

   ```bash
   scripts/ste-check.sh draft.txt
   ```

   Work through its output:
   - NOT APPROVED (lowercase dictionary entry) → look up the approved
     alternatives with `grep -A6 -iE "^word \(" "$C/ste100.txt"` and use one,
     or justify the word as part of a technical noun.
   - NO ENTRY → usable only as a technical noun (rule 1.5 categories) or
     technical verb (rule 1.12). Decide which category it fits and label it TN
     or TV. If it fits no category, rewrite without it.
   - The approved count covers existence only: for any word whose part of
     speech or meaning you are not sure of, read its entry — the dictionary
     approves many words in one function only (DISPLAY noun yes, verb no;
     LEVEL adjective yes, noun no).
4. Run the mechanical checks on the draft:

   ```bash
   grep -n ';' draft.txt                      # rule 8.1: no semicolons
   grep -oE '[^.!?]+[.!?]' draft.txt | awk '{print NF"w:", $0}' | sort -rn | head
   ```

   The second command lists sentences by word count — check anything over the
   limit against the counting rules (8.5–8.7: parentheses, numbers, identifiers
   and hyphenated words count as one word). Then scan by eye for: verb tenses
   outside the rule 3.2 list, "-ing" forms outside technical nouns, noun
   clusters over three words, paragraphs over six sentences, pronouns with
   ambiguous referents.
5. Fix every violation and re-verify the sentences you changed.
6. Deliver in this order:
   - The STE English text.
   - The translation, if the user asked in another language or requested one:
     sentence by sentence from the verified English, same source term → same
     target term everywhere, conditions stay before commands, warnings keep the
     risk word → command → consequence shape. State that the translation
     inherits the STE structure but that formal STE compliance exists only for
     the English text.
   - The compliance note.

## Compliance note (required)

Every STE deliverable ends with a short note containing exactly these three
items:

- **TN/TV**: the words used as technical nouns or technical verbs, each with
  its category (e.g., "residual current device — TN, category 2 devices").
- **Replaced**: unapproved words from the source (or from your first draft) and
  the approved word that replaced each one (e.g., "qualified → APPROVED").
- **Unverified**: words you could not check because the dictionary was
  unavailable — or "none".

An empty claim like "all vocabulary is approved" is not a compliance note. If
you did not grep a word, it goes under Unverified.

## Common mistakes

- Asserting compliance from memory. "qualified" is not approved (use
  APPROVED); "display" is approved only as a noun; "domestic" is not in the
  dictionary at all. Grep first, claim after.
- Keeping a 4+ word noun cluster ("pressure relief valve assembly"). Rule 2.2:
  write it in full once, then hyphenate the unit ("pressure-relief valve") or
  give a shorter form.
- "This prevents..." with a bare pronoun. GR-4: give "this" a noun or repeat
  the referent ("These precautions prevent...").
- Using Issue 8 terminology: "technical name" no longer exists — Issue 9 says
  technical noun / technical verb.
- Calling a compositional verb + adverb a phrasal verb. The dictionary itself
  approves "GO BACK" for "return" — rule 9.3 bans only combinations whose
  meaning differs from their parts ("put out" → "extinguish").
- Drafting directly in Spanish (or any non-English language). The dictionary
  only exists for English — draft in STE English, verify, then translate.
