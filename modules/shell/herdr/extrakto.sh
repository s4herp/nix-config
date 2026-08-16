#!/usr/bin/env bash
# extrakto for herdr: grab tokens off the focused pane, pick one with fzf,
# then type it back into that pane, copy it, or open it.
#
# Bind it as a [[keys.command]] popup. Herdr exports HERDR_ACTIVE_PANE_ID into
# custom commands; the api snapshot is the fallback when it is missing.

set -uo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"

tokenize() {
  local mode="$1" buf="$2"
  case "$mode" in
    word)
      tr -s '[:space:]' '\n' <"$buf" |
        sed -E "s/^[[:punct:]]+//; s/[[:punct:]]+$//" |
        grep -E '.{2,}' || true
      ;;
    path)
      grep -oE '(~|\.{1,2})?(/[A-Za-z0-9._@%+-]+)+/?|[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+' "$buf" || true
      ;;
    url)
      grep -oE '(https?|ftp|file|git)://[^][:space:]"'"'"'<>()]+|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$buf" || true
      ;;
    line)
      sed -E 's/[[:space:]]+$//' "$buf" | grep -E '\S' || true
      ;;
  esac | awk 'NF && !seen[$0]++' | tail -r
}

# fzf reload hook: `herdr-extrakto --tokens <mode> <buf>`
if [[ "${1:-}" == "--tokens" ]]; then
  tokenize "$2" "$3"
  exit 0
fi

die() { echo "herdr-extrakto: $1" >&2; read -r -n 1 -s; exit 1; }

pane="${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}"
if [[ -z "$pane" ]]; then
  pane=$("$herdr_bin" api snapshot 2>/dev/null |
    sed -n 's/.*"focused_pane_id":"\([^"]*\)".*/\1/p' | head -1)
fi
[[ -n "$pane" ]] || die "no pane id (HERDR_ACTIVE_PANE_ID unset, snapshot empty)"

lines="${EXTRAKTO_LINES:-1000}"
mode="${EXTRAKTO_MODE:-word}"
buf="${TMPDIR:-/tmp}/herdr-extrakto-${pane//:/_}.txt"
trap 'rm -f "$buf"' EXIT

"$herdr_bin" pane read "$pane" --source recent-unwrapped --lines "$lines" --format text >"$buf" ||
  die "could not read pane $pane"

self="${BASH_SOURCE[0]}"
picked=$(
  tokenize "$mode" "$buf" | fzf \
    --multi \
    --no-sort \
    --exit-0 \
    --expect=ctrl-y,ctrl-o \
    --header "enter insert · ctrl-y copy · ctrl-o open  |  ctrl-w word · ctrl-p path · ctrl-u url · ctrl-t line" \
    --bind "ctrl-w:reload($self --tokens word $buf)" \
    --bind "ctrl-p:reload($self --tokens path $buf)" \
    --bind "ctrl-u:reload($self --tokens url $buf)" \
    --bind "ctrl-t:reload($self --tokens line $buf)"
) || exit 0

key=$(head -1 <<<"$picked")
text=$(tail -n +2 <<<"$picked" | paste -sd' ' -)
[[ -n "$text" ]] || exit 0

case "$key" in
  ctrl-y) printf '%s' "$text" | pbcopy ;;
  ctrl-o)
    # extrakto's @extrakto_open_tool, resolving relative paths against the
    # pane's cwd rather than the popup's.
    cwd="${HERDR_ACTIVE_PANE_CWD:-$PWD}"
    (cd "$cwd" && "${EXTRAKTO_OPEN_TOOL:-/usr/bin/open}" "$text") ||
      die "open failed: $text"
    ;;
  *)      "$herdr_bin" pane send-text "$pane" "$text" ;;
esac
