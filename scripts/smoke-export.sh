#!/usr/bin/env bash
# Start the exported Linux app from outside the project with an empty user profile.
set -uo pipefail

if [ "$#" -ne 1 ]; then
	echo "usage: scripts/smoke-export.sh path/to/ghost-notes-linux.x86_64" >&2
	exit 2
fi

artifact=$(realpath "$1")
if [ ! -x "$artifact" ]; then
	echo "smoke-export.sh: no executable at $artifact" >&2
	exit 2
fi

profile=$(mktemp -d)
trap 'rm -rf "$profile"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$profile/data" "$profile/config" "$profile/cache" "$profile/work"
log="$profile/run.log"
cat >"$profile/work/cards-note.md" <<'EOF'
---
title: Export smoke
ghost:
  cards:
    show: export-smoke
---

An exported note with a Cards block.
EOF

(
	cd "$profile/work" || exit 2
	env XDG_DATA_HOME="$profile/data" XDG_CONFIG_HOME="$profile/config" \
		XDG_CACHE_HOME="$profile/cache" timeout --foreground 30 "$artifact" --headless -- \
		--export-smoke --export-smoke-note "$profile/work/cards-note.md"
) >"$log" 2>&1
status=$?
if [ "$status" -ne 0 ] || grep -qiE 'SCRIPT ERROR:|Parse Error:|ERROR:|Failed to load' "$log"; then
	echo "smoke-export.sh: exported app failed to start cleanly (exit $status):" >&2
	cat "$log" >&2
	exit 1
fi
if ! grep -q 'ghost/export-smoke: PASS' "$log"; then
	echo "smoke-export.sh: exported app did not pass its resource check:" >&2
	cat "$log" >&2
	exit 1
fi
echo "smoke-export.sh: $artifact starts, reads a Cards note, and unpacks its hosts from an empty profile outside the repository"
