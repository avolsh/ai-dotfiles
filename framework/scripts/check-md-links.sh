#!/usr/bin/env bash
# framework/scripts/check-md-links.sh
#
# Verifies that every relative markdown link [text](path) inside the
# ai-dotfiles markdown sources resolves to an existing file in the repo.
#
# Scope (default): framework/**/*.md (excluding framework/templates/,
# framework/upstream/, and framework/skills/.system/ — vendored upstream
# mirrors whose links target their original hosting site), docs/**/*.md,
# and the ai-dotfiles README.md.
#
# Custom scope: ./framework/scripts/check-md-links.sh path1 path2 ...
#
# Ignored:
#   - absolute URLs (http://, https://, mailto:, tel:, ftp:, protocol-relative)
#   - in-page anchors (#section)
#   - reference-style links ([text][ref])
#   - links inside fenced code blocks and inline code spans
#
# Exit 0 if all links resolve, exit 1 with a per-link report otherwise.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [[ $# -gt 0 ]]; then
  files=("$@")
else
  mapfile -t files < <(
    {
      [[ -d "$ROOT/framework" ]] && find "$ROOT/framework" -type f -name '*.md' \
        -not -path "$ROOT/framework/templates/*" \
        -not -path "$ROOT/framework/upstream/*" \
        -not -path "$ROOT/framework/skills/.system/*"
      [[ -d "$ROOT/docs" ]] && find "$ROOT/docs" -type f -name '*.md'
      [[ -f "$ROOT/README.md" ]] && echo "$ROOT/README.md"
    } | sort -u
  )
fi

TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

for src in "${files[@]}"; do
  [[ -f "$src" ]] || continue
  src_dir="$(dirname "$src")"  # Strip fenced code blocks AND HTML comments, then emit "lineno:linecontent".
  # Multi-line <!-- ... --> blocks are removed before line splitting.
  perl -0777 -ne 's/<!--.*?-->//gs; print' "$src" | \
  awk '
    BEGIN { fence=0 }
    /^[[:space:]]*```/ { fence = 1 - fence; next }
    fence == 0 { print NR ":" $0 }
  ' | \
  perl -ne '
    my ($ln, $line) = split /:/, $_, 2;
    $line =~ s/`[^`]*`//g;
    while ($line =~ /\[(?:[^\]]|\\.)*?\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g) {
      print "$ln\t$1\n";
    }
  ' | \
  while IFS=$'\t' read -r line target; do
    case "$target" in
      http://*|https://*|mailto:*|tel:*|ftp://*|//*) continue ;;
      \#*) continue ;;
    esac
    path="${target%%#*}"
    path="${path%%\?*}"
    [[ -z "$path" ]] && continue
    if [[ "$path" = /* ]]; then
      candidate="$ROOT$path"
    else
      candidate="$src_dir/$path"
    fi
    resolved="$(python3 -c 'import os,sys; print(os.path.normpath(sys.argv[1]))' "$candidate")"
    if [[ ! -e "$resolved" ]]; then
      rel_src="${src#"$ROOT"/}"
      echo "$rel_src:$line -> $target" >> "$TMP_OUT"
    fi
  done
done

if [[ -s "$TMP_OUT" ]]; then
  echo "Broken markdown links:" >&2
  sort -u "$TMP_OUT" | sed 's/^/  /' >&2
  echo "" >&2
  echo "Total: $(wc -l < "$TMP_OUT" | tr -d ' ') broken link(s)" >&2
  exit 1
fi

echo "Markdown link check passed (scope: ${#files[@]} files)."
exit 0

