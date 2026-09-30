#!/usr/bin/env bash
# Lists notes by next_review date (from each note's frontmatter), due ones first.
#
#   ./scripts/review.sh          # notes due today or overdue
#   ./scripts/review.sh --all    # every tracked note
#
# After reviewing a note, update its frontmatter:
#   last_reviewed: today
#   next_review:   today + interval   (recalled well → double the gap: 1 → 3 → 7 → 14 → 30 → 90 days;
#                                      struggled → back to 1 day)
#   confidence:    1–5

set -euo pipefail
cd "$(dirname "$0")/.."

today=$(date +%F)
show_all=${1:-}

find . -name '*.md' -not -path './.git/*' -not -path './_templates/*' -print0 |
  while IFS= read -r -d '' f; do
    next=$(awk -F': *' '/^next_review:/{print $2; exit}' "$f")
    [[ -z "$next" ]] && continue
    conf=$(awk -F': *' '/^confidence:/{print $2; exit}' "$f")
    status=$(awk -F': *' '/^status:/{print $2; exit}' "$f")
    printf '%s\t%s\t%s\t%s\n' "$next" "${conf:-?}" "${status:-?}" "${f#./}"
  done |
  sort |
  awk -F'\t' -v today="$today" -v all="$show_all" '
    BEGIN { printf "%-4s %-11s %-4s %-9s %s\n", "", "NEXT", "CONF", "STATUS", "NOTE" }
    {
      due = ($1 <= today)
      if (!due && all != "--all") next
      printf "%-4s %-11s %-4s %-9s %s\n", (due ? "DUE" : ""), $1, $2, $3, $4
      n++
    }
    END { if (n == 0) print "Nothing due today. 🎉  (use --all to see everything)" }'
