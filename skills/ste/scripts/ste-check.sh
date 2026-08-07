#!/bin/sh
# ste-check v2 — deterministic ASD-STE100 Issue 9 checker.
#
# Usage:
#   ste-check.sh [--annotated] --verified <draft>   full report + rule checklist
#   ste-check.sh [--annotated] --marked   <draft>   report + <draft>.marked.md
#   ste-check.sh --clean <draft>                    strip annotations, emit text
#                                                   (--clean implies --annotated)
#   ste-check.sh --entry <word>                     print the dictionary entries
#
# Exit codes: 0 = automated checks clean, 1 = compliance findings remain,
#             2 = invocation / cache / parser failure.
#
# The dictionary index is parsed ONLY from the real word-list section of the
# Issue 9 cache (bounded by structural markers; exactly 875 approved entries
# are required). Annotations (word~tnN, word~tvNx, [[tnN: multi word]]) are
# consumed only under --annotated and only validated for syntax, category code,
# and dictionary relationship — semantic category membership stays with the
# author. Known approximation limits of the sentence segmentation: proper
# nouns, titles, placards, and labels cannot be detected and must be counted
# manually (rule 8.6); procedural vs descriptive context is reported, not
# decided.

DICT="${XDG_CACHE_HOME:-$HOME/.cache}/asd-ste100/ste100.txt"
GAWK_BIN=$(command -v gawk) || { echo "ste-check requires GNU awk (gawk)" >&2; exit 2; }

MODE=""; ANNOT=0; TARGET=""; ENTRYWORD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --annotated) ANNOT=1 ;;
    --verified|--marked|--clean) [ -n "$MODE" ] && { echo "one mode only" >&2; exit 2; }; MODE="${1#--}" ;;
    --entry) [ -n "$MODE" ] && { echo "one mode only" >&2; exit 2; }; MODE="entry"; shift; ENTRYWORD="$1" ;;
    --) shift; TARGET="$1" ;;
    -h|--help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
    -*) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
    *) [ -n "$TARGET" ] && { echo "one input file only" >&2; exit 2; }; TARGET="$1" ;;
  esac
  shift
done
[ -n "$MODE" ] || { echo "usage: ste-check.sh [--annotated] --verified|--marked|--clean <draft> | --entry <word>" >&2; exit 2; }
[ "$MODE" = "clean" ] && ANNOT=1   # --clean exists to validate/strip annotations; bare --clean is a no-op otherwise

if [ "$MODE" = "entry" ]; then
  [ -n "$ENTRYWORD" ] || { echo "--entry needs a word" >&2; exit 2; }
else
  [ -n "$TARGET" ] && [ -f "$TARGET" ] || { echo "input file not found: $TARGET" >&2; exit 2; }
fi

MARKOUT=""
if [ "$MODE" = "marked" ]; then
  MARKOUT="${TARGET}.marked.md"
  [ -e "$MARKOUT" ] && { echo "refusing to overwrite existing $MARKOUT" >&2; exit 2; }
fi

if [ "$MODE" != "clean" ]; then
  [ -s "$DICT" ] || { echo "dictionary not found: $DICT — run Step 0 of the ste skill (pdftotext -layout)" >&2; exit 2; }
fi

"$GAWK_BIN" -v MODE="$MODE" -v ANNOT="$ANNOT" -v DICT="$DICT" -v ENTRYWORD="$ENTRYWORD" -v MARKOUT="$MARKOUT" '
function trim(s){ gsub(/^[ \t]+|[ \t]+$/,"",s); return s }
function lc(s){ return tolower(s) }

# ---------- dictionary loading (bounded, validated) ----------
function die(msg){ printf "ste-check: %s\n", msg > "/dev/stderr"; died = 1; exit 2 }

function load_dict(   line, n, i, stage, col1, col2, pend, pendline, head, ok875) {
  n = 0
  while ((getline line < DICT) > 0) { dl[++n] = line }
  close(DICT)
  if (n < 1000) die("cache too small — regenerate with pdftotext -layout")
  for (i = 1; i <= 50 && i <= n; i++) if (dl[i] ~ /ISSUE 9, JANUARY 2025/) { titleok = 1; break }
  if (!titleok) die("Issue 9 title marker not found — wrong or corrupted cache")
  for (i = 1; i <= n; i++)
    if (dl[i] ~ /^Page 2-0-20[ \t]+Part 2 - Dictionary[ \t]+Issue 9/) { bstart = i; break }
  if (!bstart) die("dictionary boundary page marker not found")
  for (i = bstart; i <= bstart+10 && i <= n; i++)
    if (dl[i] ~ /^\(part of speech\)[ \t]+ALTERNATIVES[ \t]+STE EXAMPLE[ \t]+Non-STE example/) { set_cols(dl[i]); hdrok = 1; break }
  if (!hdrok) die("four-column header not found after boundary")
  for (i = i+1; i <= i+10 && i <= n; i++)
    if (dl[i] ~ /^A \(art\)[ \t][ \t]+/) { dstart = i; break }
  if (!dstart) die("first dictionary entry A (art) not found")

  nent = 0; pend = ""; informs = 0
  HEADRE = "^[A-Za-z][A-Za-z-]*( [A-Za-z][A-Za-z-]*)*( \\([^)]*\\))? \\((art|n|v|adj|adv|prep|conj|pron|prefix)\\),?"
  for (i = dstart; i <= n; i++) {
    line = dl[i]
    if (line ~ /^\(part of speech\)[ \t]+ALTERNATIVES/) { set_cols(line); pend=""; continue }
    if (line ~ /^Page [0-9]/ || line ~ /ASD-STE100 Simplified Technical English/ || \
        line ~ /^Word[ \t]+Approved meaning\// || line ~ /^[ \t]*Issue 9[ \t]*$/) { continue }
    if (line ~ /^[ \t][ \t]/) col1 = ""
    else { col1 = line; sub(/  .*$/, "", col1); col1 = trim(col1) }
    col2 = ste_col > alt_col ? trim(substr(line, alt_col, ste_col-alt_col)) : ""
    if (col1 == "") { if (nent && col2 != "" && !e_app[nent]) add_alt(nent, col2); continue }
    if (match(line, HEADRE) && (RLENGTH == length(line) || substr(line, RLENGTH+1, 1) == " ")) {
      pend = ""
      head = substr(line, 1, RLENGTH)
      col2 = ste_col > RLENGTH+1 ? trim(substr(line, RLENGTH+1, ste_col-RLENGTH-1)) : ""
      new_entry(head, col2, i)
      continue
    }
    if (informs && !(next_col1(i) ~ /^\((art|n|v|adj|adv|prep|conj|pron|prefix)\)$/) && harvest_form(col1)) continue
    if (pend != "") {
      head = pend " " col1
      if (is_head(head)) { new_entry(head, pendcol2 != "" ? pendcol2 : col2, pendline); pend=""; continue }
      pend = ""
    }
    if (col1 ~ /^[A-Za-z(]/ && col1 !~ /^No other/) { pend = col1; pendline = i; pendcol2 = col2; informs = 0; continue }
    informs = 0
  }
  if (ENVIRON["STE_DEBUG"] != "") for (i = 1; i <= nent; i++) printf "%s\t%s\t%s\t%d\n", e_app[i] ? "APP" : "low", e_word[i], e_pos[i], e_line[i] > "/dev/stderr"
  if (e_word[nent] != "zero" || e_pos[nent] != "v") die("last entry is not zero (v) — parse drifted (got: " e_word[nent] " " e_pos[nent] ")")
  ok875 = 0; for (i = 1; i <= nent; i++) if (e_app[i]) ok875++
  if (ok875 != 875) die("approved head count is " ok875 ", expected exactly 875 — regenerate the cache with pdftotext -layout")
}
function next_col1(i,   j, line, c) {
  for (j = i+1; j <= i+6 && j in dl; j++) {
    line = dl[j]
    if (line ~ /^Page [0-9]/ || line ~ /ASD-STE100 Simplified/ || line ~ /^\(part of speech\)/ || line ~ /^Word[ \t]+Approved/) continue
    c = trim(substr(line, 1, alt_col-1))
    if (c != "") return c
  }
  return ""
}
function set_cols(hline) {
  alt_col = index(hline, "ALTERNATIVES")
  ste_col = index(hline, "STE EXAMPLE")
  nonste_col = index(hline, "Non-STE example")
  if (!alt_col || !ste_col) die("could not derive column offsets from header")
}
function is_head(s,   t) {
  t = s; sub(/,$/, "", t)
  return t ~ /^[A-Za-z][A-Za-z-]*( [A-Za-z][A-Za-z-]*)*( \([^)]*\))? \((art|n|v|adj|adv|prep|conj|pron|prefix)\)$/
}
function new_entry(head, col2, lineno,   t, pos, base, qual, w, hadcomma) {
  t = head; hadcomma = sub(/,$/, "", t)
  match(t, / \((art|n|v|adj|adv|prep|conj|pron|prefix)\)$/)
  pos = substr(t, RSTART+2, RLENGTH-3)
  base = substr(t, 1, RSTART-1)
  qual = ""
  if (match(base, / \([^)]*\)$/)) { qual = substr(base, RSTART+2, RLENGTH-3); base = substr(base, 1, RSTART-1) }
  nent++
  e_word[nent] = lc(base); e_pos[nent] = pos; e_line[nent] = lineno
  e_app[nent] = (base == toupper(base) && base ~ /[A-Z]/) ? 1 : 0
  e_alt[nent] = ""
  index_word(lc(base), nent)
  if (qual != "") {
    if (qual ~ /^or /) { w = qual; sub(/^or /, "", w); index_word(lc(w), nent); if (e_app[nent]) appwd[lc(w)] = 1 }
    else index_phrase(lc(qual), nent)
  }
  if (!e_app[nent] && col2 != "") add_alt(nent, col2)
  informs = (e_app[nent] && (pos == "v" || pos == "adj") && hadcomma) ? 1 : 0
}
function index_word(w, id,   k) {
  if (w ~ / /) { index_phrase(w, id) }
  if (e_app[id]) appwd[w] = 1; else lowwd[w] = 1
  idsof[w] = (w in idsof) ? idsof[w] "," id : "" id
}
function index_phrase(p, id,   k) {
  k = split(p, tmp_, " ")
  if (k >= 2 && k <= 5) { if (e_app[id]) appph[p] = 1; else lowph[p] = 1; phids[p] = (p in phids) ? phids[p] "," id : "" id; maxph = k > maxph ? k : maxph }
}
function add_alt(id, txt) {
  if (e_alt[id] != "" && length(e_alt[id]) > 160) return
  e_alt[id] = e_alt[id] == "" ? txt : e_alt[id] " | " txt
}
function harvest_form(col1,   t, k, j, f) {
  t = col1
  if (t ~ /^\(also [A-Z, ]+\)$/) { gsub(/^\(also |\)$/, "", t) }
  else if (t !~ /^[A-Z][A-Z, -]*,?$/) return 0
  gsub(/,$/, "", t)
  k = split(t, fs_, /, */)
  for (j = 1; j <= k; j++) { f = trim(fs_[j]); if (f != "" && f == toupper(f)) { appwd[lc(f)] = 1; idsof[lc(f)] = (lc(f) in idsof) ? idsof[lc(f)] : idsof[e_word[nent]] } }
  return 1
}
function alts_for(w,   k, ids, j, out, id) {
  k = split(idsof[w], ids, ","); out = ""
  for (j = 1; j <= k; j++) { id = ids[j]; if (!e_app[id] && e_alt[id] != "") out = out (out=="" ? "" : " ; ") "(" e_pos[id] ") " e_alt[id] }
  return out == "" ? "(no alternative extracted — use --entry " w ")" : out
}

# ---------- entry mode ----------
function entry_mode(   w, i, j, k, ids, id, stop) {
  w = lc(ENTRYWORD)
  if (!(w in idsof)) { printf "no dictionary entry for: %s\n", w; exit 1 }
  k = split(idsof[w], ids, ",")
  for (j = 1; j <= k; j++) {
    id = ids[j]
    printf "---- %s (%s) [%s] ----\n", e_word[id], e_pos[id], e_app[id] ? "APPROVED" : "not approved"
    stop = (id < nent) ? e_line[id+1] - 1 : e_line[id] + 12
    for (i = e_line[id]; i <= stop && i - e_line[id] < 14; i++) {
      if (dl[i] ~ /^Page [0-9]/ || dl[i] ~ /ASD-STE100 Simplified/ || dl[i] ~ /^\(part of speech\)/ || dl[i] ~ /^Word[ \t]+Approved/) continue
      if (trim(dl[i]) != "") print dl[i]
    }
  }
  exit 0
}

# ---------- draft processing ----------
BEGIN {
  if (MODE != "clean") load_dict()
  if (MODE == "entry") entry_mode()
}
{ raw[NR] = $0 }
END {
  if (died) exit 2
  if (MODE == "entry") exit 0
  nl = NR
  errs = 0
  # --- annotations ---
  for (i = 1; i <= nl; i++) {
    line = raw[i]
    if (ANNOT) {
      while (match(line, /\[\[t[nv][0-9]*[a-z]?:[^\]]*\]\]/)) {
        rs = RSTART; rl = RLENGTH
        tok = substr(line, rs, rl)
        register_ann(tok, i)
        inner = tok; sub(/^\[\[t[nv][0-9]*[a-z]?:[ ]*/, "", inner); sub(/\]\]$/, "", inner)
        line = substr(line, 1, rs-1) inner substr(line, rs+rl)
      }
      while (match(line, /[A-Za-z][A-Za-z-]*~t[nv][0-9]*[a-z]?/)) {
        rs = RSTART; rl = RLENGTH
        tok = substr(line, rs, rl)
        register_ann(tok, i)
        inner = tok; sub(/~t[nv][0-9]*[a-z]?$/, "", inner)
        line = substr(line, 1, rs-1) inner substr(line, rs+rl)
      }
      if (line ~ /~t[A-Za-z0-9]/ || line ~ /\[\[t[A-Za-z0-9]/) die("malformed TN/TV annotation on line " i ": " raw[i])
    }
    stripped[i] = line
  }
  if (MODE == "clean") { for (i = 1; i <= nl; i++) print stripped[i]; exit annerr ? 2 : 0 }
  if (annerr) exit 2

  # --- backtick spans, tokens, buckets ---
  for (i = 1; i <= nl; i++) {
    line = stripped[i]
    while (match(line, /`[^`]+`/)) {
      span = substr(line, RSTART+1, RLENGTH-2)
      cls = span_class(span)
      if (cls == "id") repl = " xIDTOKx "
      else if (cls == "review") { idrev[lc(span)] = idrev[lc(span)] i ","; repl = " xIDTOKx " }
      else { prose_note[i] = span; repl = " " span " " }
      line = substr(line, 1, RSTART-1) repl substr(line, RSTART+RLENGTH)
    }
    logical[i] = line
  }
  # tokenize with phrase matching
  for (i = 1; i <= nl; i++) {
    line = logical[i]
    if (line ~ /^#/) continue
    gsub(/[\x27’]/, "\x27", line)
    ntk = split(line, tk, /[^A-Za-z0-9\x27-]+/)
    for (j = 1; j <= ntk; j++) {
      t = tk[j]; gsub(/^[\x27-]+|[\x27-]+$/, "", t)
      if (t == "") continue
      if (t ~ /\x27/) { contr[lc(t)] = contr[lc(t)] i ","; continue }
      if (t ~ /[0-9]/ || t == "xIDTOKx") continue
      if (length(t) == 1) { if (lc(t) == "i") flag_i = flag_i i ","; continue }
      toks[++ntok] = lc(t); tokline[ntok] = i; tokorig[ntok] = t
    }
  }
  # phrase pass (longest first)
  for (p = 1; p <= ntok; p++) {
    if (used[p]) continue
    for (L = maxph; L >= 2; L--) {
      if (p + L - 1 > ntok) continue
      ph = toks[p]; bad = 0
      for (q = 1; q < L; q++) { if (tokline[p+q] != tokline[p]) { bad = 1; break }; ph = ph " " toks[p+q] }
      if (bad) continue
      if (ph in annph) {
        for (q = 0; q < L; q++) used[p+q] = 1
        if (ph in appph || ph in lowph) review[ph] = review[ph] "annotated but the dictionary lists this phrase — line " tokline[p] ","
        else if (anncat[ph] == "") nocat[ph] = toupper(anns[ph])
        else decl[ph] = toupper(anns[ph]) " category " anncat[ph]
        break
      }
      if (!(ph in phids)) continue
      for (q = 0; q < L; q++) used[p+q] = 1
      if (ph in appph) okc++
      else napp[ph] = napp[ph] tokline[p] ","
      break
    }
  }
  # single-token classification
  for (p = 1; p <= ntok; p++) {
    if (used[p]) continue
    t = toks[p]
    if (t in anns) { classify_ann(t, p); continue }
    if (t in appwd) { okc++; okseen[t] = 1; continue }
    if (t in lowwd) { napp[t] = napp[t] tokline[p] ","; continue }
    st = plural_stem(t)
    if (st == "AMBIG") { review[t] = review[t] "ambiguous plural — line " tokline[p] ","; continue }
    if (st != "") { if (st in appwd) okc++; else napp[t " (plural of " st ")"] = napp[t " (plural of " st ")"] tokline[p] ","; continue }
    if (t ~ /-/) { if (hyph_ok(t)) { okc++; continue } }
    noent[t] = noent[t] tokline[p] ","
  }
  mech_checks()
  report()
  if (MODE == "marked") emit_marked()
  exit (findings ? 1 : 0)
}
function register_ann(tok, lineno,   ty, cat, w) {
  if (tok ~ /^\[\[/) {
    match(tok, /^\[\[t[nv][0-9]*[a-z]?/); ty = substr(tok, 3, RLENGTH-2)
    w = tok; sub(/^\[\[t[nv][0-9]*[a-z]?:[ ]*/, "", w); sub(/\]\]$/, "", w)
  } else {
    match(tok, /~t[nv][0-9]*[a-z]?$/); ty = substr(tok, RSTART+1, RLENGTH-1)
    w = substr(tok, 1, RSTART-1)
  }
  cat = ty; sub(/^t[nv]/, "", cat)
  ty = substr(ty, 1, 2)
  if (cat != "") {
    if (ty == "tn" && (cat+0 < 1 || cat+0 > 22 || cat !~ /^[0-9]+$/)) { printf "ste-check: invalid TN category %s on line %d\n", cat, lineno > "/dev/stderr"; annerr = 1 }
    if (ty == "tv" && (substr(cat,1,1)+0 < 1 || substr(cat,1,1)+0 > 4)) { printf "ste-check: invalid TV category %s on line %d\n", cat, lineno > "/dev/stderr"; annerr = 1 }
  }
  anns[lc(w)] = ty; anncat[lc(w)] = cat; annline[lc(w)] = lineno
  if (w ~ / /) { annph[lc(w)] = 1; k_ = split(w, tmp_, " "); if (k_ > maxph) maxph = k_ }
}
function classify_ann(t, p,   ty, cat) {
  ty = anns[t]; cat = anncat[t]
  if (t in appwd) { review[t] = review[t] "annotated " toupper(ty) " but an APPROVED entry exists — annotation likely unnecessary — line " tokline[p] ","; return }
  if (t in lowwd) { review[t] = review[t] "annotated " toupper(ty) " but the dictionary lists it (rules 1.6/1.12) — alternatives: " alts_for(t) " — line " tokline[p] ","; return }
  if (cat == "") { nocat[t] = toupper(ty); return }
  decl[t] = toupper(ty) " category " cat
}
function plural_stem(t,   c, cands, ncand, j, seen_) {
  ncand = 0; delete cands
  if (t ~ /ies$/) cands[++ncand] = substr(t,1,length(t)-3) "y"
  if (t ~ /(s|x|z|ch|sh|o)es$/) cands[++ncand] = substr(t,1,length(t)-2)
  if (t ~ /s$/ && t !~ /ss$/) cands[++ncand] = substr(t,1,length(t)-1)
  delete seen_
  c = ""
  for (j = 1; j <= ncand; j++) {
    if (!noun_entry(cands[j]) || (cands[j] in seen_)) continue
    seen_[cands[j]] = 1
    if (c != "" && cands[j] != c) return "AMBIG"
    if (c == "" || length(cands[j]) > length(c)) c = cands[j]
  }
  return c
}
function noun_entry(w,   k, ids, j) {
  if (!(w in idsof)) return 0
  k = split(idsof[w], ids, ",")
  for (j = 1; j <= k; j++) if (e_pos[ids[j]] == "n") return 1
  return 0
}
function hyph_ok(t,   k, pr, j) {
  k = split(t, pr, "-")
  for (j = 1; j <= k; j++) if (!(pr[j] in appwd)) return 0
  return 1
}
function span_class(s) {
  if (s ~ /[0-9_.\/:={}\[\]]/ || s ~ /[a-z][A-Z]/ || s ~ /^[A-Z-]+$/) return "id"
  if (s ~ / /) { if (s ~ /^[a-z]+( [a-z]+)+$/) return "prose"; return "id" }
  if (s ~ /^[a-z-]+$/) return "review"
  return "id"
}
# ---------- mechanical checks ----------
function mech_checks(   i, para, pn, s, w, sn) {
  pn = 0; para = ""
  for (i = 1; i <= nl; i++) {
    line = logical[i]
    if (trim(line) == "" || line ~ /^#/) { if (para != "") { check_para(para, pstart); para = "" }; continue }
    if (line ~ /^[ \t]*([-*]|[0-9]+\.)[ \t]/) { if (para != "") { check_para(para, pstart); para = "" }; sub(/^[ \t]*([-*]|[0-9]+\.)[ \t]/, "", line); check_sentences(line, i, 1) }
    else { if (para == "") pstart = i; para = para (para=="" ? "" : " ") line }
    if (index(logical[i], ";")) { semis = semis i ","; findings++ }
  }
  if (para != "") check_para(para, pstart)
}
function check_para(text, lineno,   sn) {
  sn = check_sentences(text, lineno, 0)
  if (sn > 6) paranote[lineno] = sn
}
function check_sentences(text, lineno, islist,   k, ss, j, s, w, n) {
  sub(/:[ \t]*$/, ".", text)
  gsub(/([0-9])\.([0-9])/, "\\1xDOTx\\2", text)
  k = split(text, ss, /[.!?]+/)
  n = 0
  for (j = 1; j <= k; j++) {
    s = trim(ss[j]); if (s == "") continue
    n++
    w = word_count(s)
    if (w > 25) { over[lineno "." j] = w "w (limit 25): " substr(s, 1, 60); findings++ }
    else if (w > 20) chk20[lineno "." j] = w "w (procedural limit is 20): " substr(s, 1, 60)
    while (match(s, /\([^)]+\)/)) { inner = substr(s, RSTART+1, RLENGTH-2); if (inner ~ / /) { iw = word_count_plain(inner); if (iw > 25) { over[lineno ".p"] = iw "w parenthetical (rule 8.5): " substr(inner,1,50); findings++ } }; s = substr(s, RSTART+RLENGTH) }
  }
  return n
}
function word_count(s,   t) {
  t = s
  gsub(/\([^)]*\)/, " xW ", t)          # parenthetical = 1 word (8.5)
  gsub(/"[^"]*"/, " xW ", t)            # quoted text = 1 word (8.6)
  gsub(/[0-9][0-9.,]*[ \t]+(mm|cm|m|km|in|ft|mA|A|V|W|Hz|s|min|h|kg|g|lb|psi|bar|C|F|%)([^A-Za-z]|$)/, " xW ", t)  # number+unit = 1 (8.6)
  return word_count_plain(t)
}
function word_count_plain(s,   k, a, j, c) {
  k = split(s, a, /[ \t]+/); c = 0
  for (j = 1; j <= k; j++) if (a[j] ~ /[A-Za-z0-9]/) c++
  return c
}
# ---------- output ----------
function bucket(title, arr,   w, any, m, srt, x) {
  printf "== %s ==\n", title
  any = 0
  m = asorti(arr, srt)
  for (x = 1; x <= m; x++) { w = srt[x]; printf "  %s -> %s\n", w, arr[w]; any = 1; findings++ }
  if (!any) print "  (none)"
}
function report(   w, m, srt, x, any) {
  printf "== NOT APPROVED (use the alternative, or justify as TN/TV per rules 1.6/1.12) ==\n"
  m = asorti(napp, srt); any = 0
  for (x = 1; x <= m; x++) { w = srt[x]; sub(/,$/, "", napp[w]); printf "  %s -> %s [lines %s]\n", w, alts_for(alts_key(w)), napp[w]; any = 1; findings++ }
  if (!any) print "  (none)"
  printf "== NO ENTRY (must be TN/TV, or rewrite) ==\n"
  m = asorti(noent, srt); any = 0
  for (x = 1; x <= m; x++) { w = srt[x]; sub(/,$/, "", noent[w]); printf "  %s [lines %s]\n", w, noent[w]; any = 1; findings++ }
  if (!any) print "  (none)"
  printf "== DECLARED TN/TV (inventory — semantic category is the author\x27s judgment) ==\n"
  m = asorti(decl, srt); any = 0
  for (x = 1; x <= m; x++) { w = srt[x]; printf "  %s — %s\n", w, decl[w]; any = 1 }
  if (!any) print "  (none)"
  bucket("DECLARED, CATEGORY REQUIRED", nocat)
  bucket("REVIEW", review)
  bucket("CONTRACTIONS (rule 4.2 — not permitted)", contr)
  bucket("IDENTIFIER REVIEW (single plain-lowercase backtick span — declare or verify)", idrev)
  if (flag_i != "") { sub(/,$/, "", flag_i); printf "== OTHER ==\n  standalone \"i\" is not approved — address the reader as \"you\" [lines %s]\n", flag_i; findings++ }
  printf "== MECHANICAL ==\n"
  if (semis != "") { sub(/,$/, "", semis); printf "  semicolons (rule 8.1) on lines: %s\n", semis }
  m = asorti(over, srt); for (x = 1; x <= m; x++) printf "  over limit @%s: %s\n", srt[x], over[srt[x]]
  m = asorti(chk20, srt); for (x = 1; x <= m; x++) printf "  check text type @%s: %s\n", srt[x], chk20[srt[x]]
  m = asorti(paranote, srt); for (x = 1; x <= m; x++) printf "  paragraph at line %s has %d sentences (check if descriptive, rule 6.6)\n", srt[x], paranote[srt[x]]
  for (w in prose_note) printf "  backtick span reads as prose (checked as text): `%s` line %d\n", prose_note[w], w
  ing_warnings()
  printf "== approved: %d unique surface forms (POS and meaning still must match your use) ==\n", okc
  if (MODE == "verified") { print_checklist(); }
  if (length(nocat) || length(noent) || cat_needed_in_review()) print_categories()
}
function strip_note(w){ sub(/ \(plural of .*\)$/, "", w); return w }
function alts_key(w,   m2) { if (match(w, / \(plural of (.*)\)$/, m2)) return m2[1]; return w }
function cat_needed_in_review(   w){ for (w in review) if (anns[w] != "") return 1; return 0 }
function ing_warnings(   p, t, any) {
  for (p = 1; p <= ntok; p++) {
    t = toks[p]
    if (t ~ /ing$/ && !(t in appwd) && !(t in anns) && !ingseen[t]) { ingseen[t] = 1; printf "  \"-ing\" form outside a technical noun? %s (rule 3.5) line %d\n", t, tokline[p] }
  }
}
function print_checklist() {
  print "== MANUAL CHECKLIST (no automated check covers these — confirm each before the Verified label) =="
  print "  - POS and approved meaning of every approved word you relied on (1.2, 1.3)"
  print "  - Technical nouns not used as verbs, technical verbs not as nouns (1.7, 1.13)"
  print "  - One term per item, consistent everywhere (1.11, 9.4); shortest clear TN (1.9); no jargon (1.10)"
  print "  - American spelling (1.14)"
  print "  - Only allowed verb forms; no auxiliaries/perfect/progressive; active voice (3.2, 3.4, 3.6)"
  print "  - No omitted words; articles present (4.2, 4.5); connecting words between related sentences (4.4)"
  print "  - Procedural: imperative, one instruction/sentence, condition first with comma (5.2-5.4); notes give info only (5.5)"
  print "  - Descriptive: gradual info, one topic/paragraph, key words repeated (6.1, 6.2, 6.5)"
  print "  - Safety: WARNING=injury / CAUTION=damage; risk word -> command/condition -> consequence (7.1-7.3)"
  print "  - Word counts for proper nouns, titles, placards, labels (8.6 — manual)"
  print "  - No phrasal verbs (9.3); keep \"that\" (GR-1); re-read every \"with\" (GR-2); pronouns unambiguous (GR-3/4)"
  print "  - Gender-neutral language (GR-7); no Latin abbreviations (GR-6)"
}
function print_categories() {
  print "== TN/TV CATEGORIES (assign one to every declared/no-entry word before the Verified label) =="
  print "  TN (rule 1.5): 1 Official parts information; 2 Vehicles or machines, and locations on them;"
  print "  3 Tools and support equipment, their parts, and locations on them; 4 Materials, consumables, and unwanted material;"
  print "  5 Facilities, infrastructure, and logistic procedures; 6 Systems, components and circuits, their functions, configurations, and parts;"
  print "  7 Mathematical, scientific, engineering terms, and formulas; 8 Navigation and geographic terms;"
  print "  9 Numbers, units of measurement and time; 10 Quoted text; 11 Professional roles, individuals, groups, organizations, and geopolitical entities;"
  print "  12 Parts of the body; 13 Common personal effects, food, and beverages; 14 Medical terms;"
  print "  15 Official documents, parts of documentation, standards, and guidelines; 16 Environmental and operational conditions;"
  print "  17 Colors; 18 Damage terms; 19 Computer science, information and communication technology;"
  print "  20 Civil and military operations; 21 Law and regulations; 22 Animals, plants, and other life forms"
  print "  TV (rule 1.12): 1 Manufacturing processes; 2 Computer processes and applications;"
  print "  3 Instructions and information for applicable subject fields; 4 Law and regulations"
}
# ---------- marked output ----------
function emit_marked(   i, line, w) {
  for (i = 1; i <= nl; i++) {
    line = stripped[i]
    for (w in napp) line = mark_word(line, strip_note(w), "**", "**")
    for (w in noent) line = mark_word(line, w, "{{?", "}}")
    for (w in nocat) line = mark_word(line, w, "{{cat?", "}}")
    for (w in review) line = mark_word(line, w, "{{rev:", "}}")
    for (w in contr) line = mark_word(line, w, "{{c:", "}}")
    print line > MARKOUT
  }
  close(MARKOUT)
  printf "marked text written to: %s\n", MARKOUT
}
function mark_word(line, w, pre, post,   out, seg, nb, bt, j, low, pos, off, bef, aft, wl) {
  # mark outside backtick spans only, by position, preserving original casing
  nb = split(line, bt, /`/)
  out = ""
  wl = length(w)
  for (j = 1; j <= nb; j++) {
    seg = bt[j]
    if (j % 2 == 1) {
      low = lc(seg); off = 1
      while ((pos = index(substr(low, off), w)) > 0) {
        pos = pos + off - 1
        bef = pos > 1 ? substr(low, pos-1, 1) : " "
        aft = pos + wl <= length(low) ? substr(low, pos+wl, 1) : " "
        if (bef !~ /[a-z-]/ && aft !~ /[a-z-]/) {
          seg = substr(seg, 1, pos-1) pre substr(seg, pos, wl) post substr(seg, pos+wl)
          low = lc(seg)
          off = pos + wl + length(pre) + length(post)
        } else off = pos + 1
      }
    }
    out = out (j > 1 ? "`" : "") seg
  }
  return out
}
' ${TARGET:+"$TARGET"} /dev/null
rc=$?
exit $rc
