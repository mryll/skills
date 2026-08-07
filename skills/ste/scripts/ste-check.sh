#!/bin/sh
# ste-check — deterministic vocabulary check against the ASD-STE100 dictionary.
# Usage: ste-check.sh <draft-file>
#
# Classifies every word of the draft into three buckets:
#   NOT APPROVED — the dictionary lists the word in lowercase (has approved
#                  alternatives: grep -A6 "^word (" the dictionary to see them)
#   NO ENTRY     — not in the dictionary: must be a technical noun (rule 1.5)
#                  or technical verb (rule 1.12), or you must rewrite
#   approved     — an UPPERCASE entry exists for the lemma (count only)
#
# "approved" here means only that an uppercase entry exists — the part of
# speech and the approved meaning still must match your use (rules 1.2, 1.3).
# Text inside backticks is ignored (identifiers, rule 8.6). Requires gawk.

DICT="${XDG_CACHE_HOME:-$HOME/.cache}/asd-ste100/ste100.txt"
[ -s "$DICT" ] || { echo "dictionary not found: $DICT (run Step 0 of the ste skill)" >&2; exit 2; }
[ -n "$1" ] && [ -f "$1" ] || { echo "usage: ste-check.sh <draft-file>" >&2; exit 2; }

awk -v dictfile="$DICT" '
BEGIN {
  # irregular inflections -> lemma (the de-inflector only handles regular forms)
  ni = split("is:be are:be was:be were:be been:be am:be has:have had:have " \
             "did:do done:do went:go gone:go got:get made:make gave:give " \
             "given:give came:come took:take taken:take kept:keep said:say " \
             "sent:send tried:try cannot:can wrote:write written:write " \
             "found:find left:leave lost:lose", pairs, " ")
  for (i = 1; i <= ni; i++) { split(pairs[i], kv, ":"); irr[kv[1]] = kv[2] }
  while ((getline line < dictfile) > 0) {
    if (line ~ /^[A-Za-z][A-Za-z-]* \(/) {
      split(line, a, / \(/)
      w = a[1]
      lw = tolower(w)
      if (w == toupper(w)) up[lw] = 1
      else low[lw] = 1
    }
  }
  close(dictfile)
}
{
  gsub(/`[^`]*`/, " ")            # identifiers in backticks: one word, rule 8.6
  line = tolower($0)
  gsub(/[^a-z-]/, " ", line)
  n = split(line, toks, /[ \t]+/)
  for (i = 1; i <= n; i++) {
    t = toks[i]
    gsub(/^-+|-+$/, "", t)
    if (length(t) < 2) continue
    seen[t] = 1
  }
}
END {
  m = asorti(seen, sorted)
  for (s = 1; s <= m; s++) {
    t = sorted[s]
    lemma = lookup(t)
    if (lemma != "") {
      if (up[lemma]) ok++
      else notapproved = notapproved "  " t " -> " lemma "\n"
      continue
    }
    if (t ~ /-/) {                # hyphenated with no entry: judge each part
      p = split(t, parts, "-"); bad = 0
      for (j = 1; j <= p; j++) {
        pl = lookup(parts[j])
        if (pl == "" || !up[pl]) bad = 1
      }
      if (!bad) { ok++; continue }
    }
    noentry = noentry "  " t "\n"
  }
  printf "== NOT APPROVED (rewrite with the dictionary alternatives) ==\n%s", notapproved == "" ? "  (none)\n" : notapproved
  printf "== NO ENTRY (must be TN/TV, or rewrite) ==\n%s", noentry == "" ? "  (none)\n" : noentry
  printf "== approved lemmas: %d words (POS and meaning still must match your use) ==\n", ok
}
function lookup(t,   c, cand, k) {
  # try the token, then simple de-inflections; return the lemma that has an entry
  c = 0
  cand[++c] = t
  if (t in irr) cand[++c] = irr[t]
  if (t ~ /ies$/)  cand[++c] = substr(t, 1, length(t)-3) "y"
  if (t ~ /es$/)   cand[++c] = substr(t, 1, length(t)-2)
  if (t ~ /s$/)    cand[++c] = substr(t, 1, length(t)-1)
  if (t ~ /ing$/) { cand[++c] = substr(t, 1, length(t)-3); cand[++c] = substr(t, 1, length(t)-3) "e" }
  if (t ~ /ed$/)  { cand[++c] = substr(t, 1, length(t)-2); cand[++c] = substr(t, 1, length(t)-1) }
  for (k = 1; k <= c; k++)
    if (up[cand[k]] || low[cand[k]]) return cand[k]
  return ""
}
' "$1"
