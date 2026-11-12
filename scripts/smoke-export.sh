#!/usr/bin/env bash
# Start the exported app from outside the project with an empty user profile.
# Linux: the .x86_64. Windows (from Git Bash, as on a CI runner): the .exe. It is a GUI program
# with no stdout to read, so its words are read from the engine's own --log-file. macOS: the
# unpacked .app, whose program is the one file in Contents/MacOS.
#
# macOS keeps user:// under $HOME/Library/Application Support, so HOME is pointed at the empty
# profile as well as XDG. It has no GNU `timeout` either: Perl's alarm stands in for it there.
# And its bash is 3.2, where `set -u` calls an empty array unbound: `engine`, empty off Windows, is
# spelled `${engine[@]+"${engine[@]}"}` (CI: "engine[@]: unbound variable").
set -uo pipefail

if [ "$#" -ne 1 ]; then
	echo "usage: scripts/smoke-export.sh path/to/ghost-notes-linux.x86_64 (or ghost-notes.exe, or Ghost Notes.app)" >&2
	exit 2
fi

artifact=$(realpath "$1")
program="$artifact"
if [ -d "$artifact" ] && [[ "$artifact" == *.app ]]; then
	program=$(find "$artifact/Contents/MacOS" -maxdepth 1 -type f -perm -u+x | head -n 1)
fi
if [ -z "$program" ] || [ ! -f "$program" ] || [ ! -x "$program" ]; then
	echo "smoke-export.sh: no executable at $artifact" >&2
	exit 2
fi

profile=$(mktemp -d)
trap 'rm -rf "$profile"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$profile/data" "$profile/config" "$profile/cache" "$profile/work" "$profile/home"
log="$profile/run.log"
note="$profile/work/cards-note.md"
engine=()
isolate=(XDG_DATA_HOME="$profile/data" XDG_CONFIG_HOME="$profile/config" XDG_CACHE_HOME="$profile/cache")
case "$artifact" in
	*.exe)  # Windows keeps user:// under %APPDATA%, and a native program wants native paths
		note=$(cygpath -m "$note")
		engine=(--log-file "$(cygpath -m "$profile/engine.log")")
		isolate=(APPDATA="$(cygpath -w "$profile/data")" LOCALAPPDATA="$(cygpath -w "$profile/cache")") ;;
	*.app)
		isolate+=(HOME="$profile/home") ;;
esac
cat >"$profile/work/cards-note.md" <<'EOF'
---
title: Export smoke
ghost:
  table:
    show: export-smoke
---

An exported note with a Cards block.
EOF

## Run "$@" for at most $1 seconds.
within() {
	local seconds=$1
	shift
	if command -v timeout >/dev/null 2>&1; then
		timeout --foreground "$seconds" "$@"
	else
		perl -e 'alarm shift; exec @ARGV or die "smoke-export.sh: cannot run $ARGV[0]: $!\n"' "$seconds" "$@"
	fi
}

(
	cd "$profile/work" || exit 2
	within 30 env "${isolate[@]}" "$program" --headless ${engine[@]+"${engine[@]}"} -- \
		--export-smoke --export-smoke-note "$note"
) >"$log" 2>&1
status=$?
[ -f "$profile/engine.log" ] && cat "$profile/engine.log" >>"$log"
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
