#!/usr/bin/env bash
# build-plugin.sh: assemble a Claude Code plugin from this repository.
#
# Usage: scripts/build-plugin.sh <out-dir> <plugin-name> [version]
#
# The plugin carries the hooks, the reviewer agent and the skills. It cannot
# carry permissions or the sandbox (a plugin's settings apply only agent and
# subagentStatusLine), so a project still needs .claude/settings.json for
# those; see docs/decisions/0002-plugin-packaging.md.
#
# Names starting with "claude-" are reserved by Claude Code; the name is
# passed in, not fixed here. Needs jq. Writes only into <out-dir>, which must
# not exist yet.
set -eu

usage() { echo "usage: scripts/build-plugin.sh <out-dir> <plugin-name> [version]" >&2; exit 2; }
if [ $# -lt 2 ] || [ $# -gt 3 ]; then usage; fi
OUT="$1"; NAME="$2"; VERSION="${3:-0.0.0}"

case "$NAME" in
  ''|*[!a-z0-9-]*) echo "build-plugin: name must be lowercase letters, digits and -" >&2; exit 2 ;;
  claude-*|anthropic-*) echo "build-plugin: names starting with claude- or anthropic- are reserved" >&2; exit 2 ;;
esac
command -v jq >/dev/null 2>&1 || { echo "build-plugin: jq is required" >&2; exit 2; }
[ ! -e "$OUT" ] || { echo "build-plugin: $OUT already exists" >&2; exit 2; }

SRC="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$OUT/.claude-plugin" "$OUT/hooks" "$OUT/scripts"
cp "$SRC"/.claude/hooks/*.sh "$OUT/scripts/"
chmod +x "$OUT"/scripts/*.sh
cp -R "$SRC/.claude/agents" "$OUT/agents"
cp -R "$SRC/.claude/skills" "$OUT/skills"
cp "$SRC/LICENSE" "$OUT/LICENSE"

# Repository copy: scripts/build-plugin.sh plugins/avem-starter avem-starter 1.0.0
# (CI rebuilds it into a temp folder and fails if the committed copy differs).

# The same hooks as the project settings, with every path moved from the
# project's .claude/hooks/ to the plugin's scripts/.
jq '{hooks: (.hooks | walk(if type == "string"
      then gsub("\\$\\{CLAUDE_PROJECT_DIR\\}/\\.claude/hooks/"; "${CLAUDE_PLUGIN_ROOT}/scripts/")
      else . end))}' "$SRC/.claude/settings.example.json" > "$OUT/hooks/hooks.json"

jq -n --arg n "$NAME" --arg v "$VERSION" '{
  name: $n,
  version: $v,
  description: "Guards that prove they work: secret, git and send guards that fail closed, a selftest with calibration, a reviewer without a shell.",
  author: {name: "Avem Investment GmbH"},
  homepage: "https://github.com/avemhq/avem-starter",
  repository: "https://github.com/avemhq/avem-starter",
  license: "MIT"
}' > "$OUT/.claude-plugin/plugin.json"

if grep -q 'CLAUDE_PROJECT_DIR' "$OUT/hooks/hooks.json"; then
  echo "build-plugin: a project path is left in hooks.json" >&2
  exit 1
fi
echo "plugin written to $OUT (name $NAME, version $VERSION)"
echo "check: bash $OUT/scripts/selftest.sh && bash $OUT/scripts/selftest.sh --calibrate"
