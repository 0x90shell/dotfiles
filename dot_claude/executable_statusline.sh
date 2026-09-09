#!/usr/bin/env bash
# Status line. Receives the session JSON on stdin.
#
# Runs on every render, so it must stay fast and must never fail: a broken status
# line is a broken prompt. Every field is optional and every lookup falls back.
set -uo pipefail

jq=$(command -v jq) || { printf 'claude'; exit 0; }
p=$(cat 2>/dev/null) || p='{}'
f() { "$jq" -r "$1 // empty" <<<"$p" 2>/dev/null; }

model=$(f '.model.display_name'); [[ -n $model ]] || model=$(f '.model.id')
[[ -n $model ]] || model=claude
dir=$(f '.workspace.current_dir'); [[ -n $dir ]] || dir=$(f '.cwd'); [[ -n $dir ]] || dir=$PWD
style=$(f '.output_style.name')

# Context remaining. The field has moved between versions, so try the shapes in
# order rather than assuming one.
rem=$(f '.context.remaining')
[[ -n $rem ]] || rem=$(f '.context.remaining_tokens')
used=$(f '.context.used_tokens')
total=$(f '.context.total_tokens')
if [[ -z $rem && -n $used && -n $total && $total -gt 0 ]]; then
    rem=$((total - used))
fi

# Colours: dim separators, and the context figure turns amber then red as it goes.
d=$'\033[2m'; r=$'\033[0m'; b=$'\033[1m'
out="${b}${model}${r}"

if [[ -n $style && $style != "null" && $style != "default" ]]; then
    out="$out ${d}[$style]${r}"
fi

out="$out ${d}|${r} ${dir/#$HOME/\~}"

if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    br=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo detached)
    n=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l)
    g="$br"
    [[ $n -gt 0 ]] && g="$g${d}+${r}$n"
    out="$out ${d}|${r} $g"
fi

if [[ -n $rem && $rem =~ ^[0-9]+$ ]]; then
    k=$((rem / 1000))
    if [[ $rem -lt 30000 ]]; then c=$'\033[31m'
    elif [[ $rem -lt 100000 ]]; then c=$'\033[33m'
    else c=$'\033[32m'; fi
    out="$out ${d}|${r} ${c}${k}k${r}${d} left${r}"
fi

printf '%s' "$out"
