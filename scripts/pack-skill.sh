#!/usr/bin/env bash
# Package a skill folder into a zip for upload to claude.ai (Settings → Capabilities → Skills).
# Usage: scripts/pack-skill.sh <skill-name>
# Output: dist/<skill-name>.zip  (contains <skill-name>/SKILL.md + supporting files)
set -euo pipefail

skill="${1:?usage: pack-skill.sh <skill-name>}"
root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/skills/$skill"

[ -f "$src/SKILL.md" ] || { echo "ERROR: $src/SKILL.md not found" >&2; exit 1; }

mkdir -p "$root/dist"
out="$root/dist/$skill.zip"
rm -f "$out"

# zip with the skill name as the top-level folder, excluding junk
( cd "$root/skills" && zip -r -X "$out" "$skill" \
    -x '*.DS_Store' -x '*/.git/*' -x '*/__pycache__/*' )

echo "Built $out"
unzip -l "$out"
