#!/usr/bin/env bash
# Rebuild homey-app.skill — the installable bundle — from SKILL.md + references/.
#
# The archive's top-level folder must be `homey-app/` so that
#   tar -xzf homey-app.skill -C ~/.claude/skills/
# yields ~/.claude/skills/homey-app/SKILL.md directly.
#
# Usage: ./scripts/build-skill.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/homey-app.skill"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

[ -f "$ROOT/SKILL.md" ] || { echo "SKILL.md not found in $ROOT" >&2; exit 1; }
[ -d "$ROOT/references" ] || { echo "references/ not found in $ROOT" >&2; exit 1; }

mkdir -p "$STAGE/homey-app"
cp "$ROOT/SKILL.md" "$STAGE/homey-app/"
cp -R "$ROOT/references" "$STAGE/homey-app/"

# Fail loudly if SKILL.md routes to a reference file that does not exist.
missing=0
while read -r ref; do
  [ -f "$STAGE/homey-app/references/$ref" ] || { echo "dangling link in SKILL.md: references/$ref" >&2; missing=1; }
done < <(grep -oE 'references/[a-z0-9-]+\.md' "$ROOT/SKILL.md" | sed 's|references/||' | sort -u)
[ "$missing" -eq 0 ] || exit 1

# Deterministic archive: sorted entries, fixed ownership, no gzip timestamp.
( cd "$STAGE" && find homey-app -print0 | LC_ALL=C sort -z \
    | tar --null --files-from=- --owner=0 --group=0 --numeric-owner --mtime='UTC 2020-01-01' -cf - ) \
  | gzip -n -9 > "$OUT"

echo "built $OUT"
tar -tzf "$OUT" | sed 's/^/  /'
printf '  %s bytes\n' "$(wc -c < "$OUT")"
