#!/usr/bin/env bash
# PostToolUse (Write|Edit): flag AI-slop register in prose the model just wrote.
#
# Wired with asyncRewake so it never blocks the edit. Exit 2 wakes the model with
# the findings; exit 0 is silent.
#
# Markdown only. Code comments and identifiers are out of scope: a variable named
# "robust_parse" is not slop, and false positives there would be constant.
set -uo pipefail

payload=$(cat)
jq=$(command -v jq) || exit 0
file=$("$jq" -r '.tool_response.filePath // .tool_input.file_path // ""' <<<"$payload")
[[ -n $file && -f $file ]] || exit 0
case $file in *.md | *.markdown | *.txt) ;; *) exit 0 ;; esac

# A file that DEFINES this vocabulary has to contain it. Style guides, skills and
# the banned-word list itself opt out with a marker line, rather than the hook
# guessing from the path.
grep -q 'slop-check: ignore' "$file" && exit 0

report=""
add() { report="${report}  $1"$'\n'; }

# Em dashes. CLAUDE.md forbids these outright, and ASD-STE100 agrees.
# grep -c counts matching LINES; count occurrences instead.
n=$(grep -o '—' "$file" 2>/dev/null | wc -l)
[[ $n -gt 0 ]] && add "$n em dash(es). Rewrite as two sentences, or use a colon."

# Register words that mark generated prose.
while read -r w c; do
    [[ ${c:-0} -gt 0 ]] && add "\"$w\" x$c"
done < <(for w in delve robust leverage seamless comprehensive "crucial" "pivotal" \
    "landscape" "realm" "testament" "underscore" "myriad" "intricate" "nuanced"; do
    c=$(grep -oic "\\b${w}[a-z]*\\b" "$file" 2>/dev/null || true)
    printf '%s %s\n' "$w" "${c:-0}"
done)

# "It's not X, it's Y" and its variants.
if grep -qiE "(it'?s|it is|this is|that'?s) not (just |merely |only )?[a-z' -]{2,40}, (it'?s|it is|but|rather) " "$file"; then
    add "negation-parallelism construction (\"it's not X, it's Y\"). State the thing directly."
fi

# Opener and closer pleasantries.
grep -qiE '^\s*(great|excellent|perfect) (question|point)' "$file" && add "opener pleasantry"
grep -qiE '(hope this helps|let me know if|feel free to)' "$file" && add "closer pleasantry"

[[ -n $report ]] || exit 0

{
    printf 'Slop check on %s:\n%s' "$file" "$report"
    printf 'CLAUDE.md bans this register. Fix it in the file, do not just acknowledge it.\n'
} >&2
exit 2
