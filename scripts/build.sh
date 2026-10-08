#!/usr/bin/env bash
# Build Ghost Notes, from one command.
#
#   scripts/build.sh                    # check, then every target whose templates are installed
#   scripts/build.sh android            # only that one (linux, windows, android, all)
#   scripts/build.sh linux android      # or several
#   scripts/build.sh --release          # release mode instead of debug
#   scripts/build.sh --no-setup linux    # use an already installed Godot and templates
#   scripts/build.sh --no-smoke linux    # skip the exported Linux launch check
#   scripts/build.sh --install android  # and put the APK on a connected phone
#   scripts/build.sh --no-check         # skip the gates. The build is then not known to work.
#   scripts/build.sh --list             # what targets exist
#
# Artifacts: dist/ghost-notes-<target>.<ext>. Modeled on monotone's build.sh.
#
# THE TARGETS ARE THE EXPORT PRESETS. This script has no list of platforms: it reads
# export_presets.cfg, so a preset added in the editor is a target here with no edit. The
# preset file is tracked, and names no secret - the debug keystore comes from the editor's
# settings and a release keystore from the environment, never from the file.
#
# A BUILD SCRIPT THAT LIES IS WORSE THAN NONE. Godot's exporter reports plenty of failures on
# stderr and still exits 0 - a missing template, an SDK it could not find. So the exit code
# is not trusted alone: the artifact must exist, must have been written by this run, and must
# be at least FLOOR bytes. An empty file is a failed build wearing a filename.
#
# IT REFUSES TO SHIP A RED TREE. scripts/check.sh runs first.
#
# RELEASE SIGNING IS THE USER'S. A release APK needs GODOT_ANDROID_KEYSTORE_RELEASE_PATH,
# _USER and _PASSWORD in the environment (the names Godot reads); this refuses --release
# without them and never prints them.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
trap 'exit 130' INT
trap 'exit 143' TERM

godot_requested="${GODOT:-}"
GODOT="${godot_requested:-godot}"
OUT="${OUT:-dist}"
PRESETS="export_presets.cfg"
## Below this, in bytes, an "artifact" is a failure with a filename on it.
FLOOR=1000000

mode="debug"
check=1
install=0
list=0
setup=1
smoke=1
wanted=()
for arg in "$@"; do
	case "$arg" in
		--release) mode="release" ;;
		--debug) mode="debug" ;;
		--no-check) check=0 ;;
		--no-setup) setup=0 ;;
		--no-smoke) smoke=0 ;;
		--install) install=1 ;;
		--list) list=1 ;;
		-h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		-*) echo "build.sh: unknown option '$arg'. Try --help." >&2; exit 2 ;;
		all) ;;
		*) wanted+=("$arg") ;;
	esac
done

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
bad() { printf '\033[1;31mbuild.sh:\033[0m %s\n' "$*" >&2; }

# -- what can be built ------------------------------------------------------------

if [ ! -f "$PRESETS" ]; then
	bad "no $PRESETS."
	exit 2
fi
mapfile -t names < <(sed -n 's/^name="\(.*\)"$/\1/p' "$PRESETS")
mapfile -t platforms < <(sed -n 's/^platform="\(.*\)"$/\1/p' "$PRESETS")
if [ "${#names[@]}" -eq 0 ]; then
	bad "$PRESETS defines no presets."
	exit 2
fi

## The file a platform's artifact wants: Godot picks the format from the extension.
extension_for() {
	case "$1" in
		Android) echo ".apk" ;;
		Linux|"Linux/X11") echo ".x86_64" ;;
		"Windows Desktop") echo ".exe" ;;
		macOS) echo ".zip" ;;
		Web) echo ".html" ;;
		*) echo "" ;;
	esac
}

## What a platform's export templates start with. A prefix, not a filename: the exact names
## carry an architecture and a build type and change between versions.
template_prefix_for() {
	case "$1" in
		Android) echo "android_" ;;
		Linux|"Linux/X11") echo "linux_" ;;
		"Windows Desktop") echo "windows_" ;;
		macOS) echo "macos" ;;
		Web) echo "web_" ;;
		*) echo "" ;;
	esac
}

have_templates_for() {
	local prefix
	prefix=$(template_prefix_for "$1")
	[ -z "$prefix" ] && return 0
	compgen -G "$templates/$prefix*" >/dev/null 2>&1
}

if [ "$list" -eq 1 ]; then
	say "targets in $PRESETS:"
	for i in "${!names[@]}"; do
		printf '    %-10s %s\n' "${names[$i]}" "${platforms[$i]:-?}"
	done
	exit 0
fi

# No target named (or `all`) means every one - and that may skip a platform whose templates
# are not installed, where a target asked for by name may not.
explicit=1
if [ "${#wanted[@]}" -eq 0 ]; then
	wanted=("${names[@]}")
	explicit=0
fi

index_of() {
	local want
	want=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
	for i in "${!names[@]}"; do
		if [ "$(printf '%s' "${names[$i]}" | tr '[:upper:]' '[:lower:]')" = "$want" ]; then
			echo "$i"
			return 0
		fi
	done
	return 1
}

# -- what it takes to build -------------------------------------------------------

# Fetch the pinned editor and matching templates on a fresh machine. The same helper can
# be called directly, and a caller-supplied GODOT remains authoritative.
if [ "$setup" -eq 1 ]; then
	setup_args=()
	if [ -n "$godot_requested" ]; then
		setup_args+=(--godot "$godot_requested")
	fi
	if [ "$explicit" -eq 0 ]; then
		setup_args+=(--target linux)
	else
		for target in "${wanted[@]}"; do
			if ! i=$(index_of "$target"); then
				bad "no preset called '$target'. Try --list."
				exit 2
			fi
			case "${platforms[$i]:-}" in
				Linux|"Linux/X11") setup_args+=(--target linux) ;;
				"Windows Desktop") setup_args+=(--target windows) ;;
			esac
		done
	fi
	if [ "${#setup_args[@]}" -gt 0 ]; then
		if ! GODOT=$(python3 scripts/setup_godot.py "${setup_args[@]}" --print-godot); then
			bad "could not prepare Godot and its export templates."
			exit 2
		fi
	fi
fi

if ! command -v "$GODOT" >/dev/null 2>&1; then
	bad "no '$GODOT' on PATH. Set GODOT=/path/to/godot."
	exit 2
fi
version=$("$GODOT" --headless --version 2>/dev/null | tail -n1 | tr -d '\r')
# "4.7.2.stable.arch_linux.ed1daf0" -> "4.7.2.stable", which is what the template directory
# is named, and "4.7", which is what the project declares.
short=$(printf '%s' "$version" | cut -d. -f1-4)
minor=$(printf '%s' "$version" | cut -d. -f1-2)
want_minor=$(sed -n 's/^config\/features=PackedStringArray("\([0-9]*\.[0-9]*\)".*/\1/p' project.godot)
if [ -n "$want_minor" ] && [ "$minor" != "$want_minor" ]; then
	bad "this is Godot $version; the project is for $want_minor."
	exit 2
fi
templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$short"
if [ ! -d "$templates" ]; then
	bad "no export templates for $short (looked in $templates)."
	bad "  fix: Editor > Manage Export Templates > Download and Install"
	exit 2
fi

# A fresh clone has no .godot/ - no class cache, no imported fonts - and exports a project
# full of unresolved identifiers. Import first; it costs a minute, once.
if [ ! -d .godot ]; then
	say "no .godot/ (a fresh clone): importing the project first"
	import_log=$(mktemp)
	if ! "$GODOT" --headless --path . --import >"$import_log" 2>&1; then
		bad "the fresh project could not be imported. Log:"
		sed 's/^/    /' "$import_log" >&2
		rm -f "$import_log"
		exit 1
	fi
	rm -f "$import_log"
fi

if [ "$check" -eq 1 ]; then
	say "running the gates (scripts/check.sh)"
	if ! scripts/check.sh; then
		bad "the gates are not green. Nothing was built."
		bad "Build anyway with --no-check, and know why you did."
		exit 1
	fi
else
	say "SKIPPING the gates (--no-check). This build is not known to work."
fi

# Python subprocesses need real files. Export this small, deterministic archive inside the
# PCK; the app expands it into user:// when a host is first needed.
if ! python3 scripts/package_hosts.py; then
	bad "could not bundle the Python hosts."
	exit 1
fi
if [ "$smoke" -eq 0 ]; then
	say "SKIPPING the standalone Linux launch check (--no-smoke)."
fi

# What this was built from, printed but NOT put in the filename: one artifact per target,
# always the latest.
stamp=$(git rev-parse --short HEAD 2>/dev/null || echo "nogit")
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
	stamp="$stamp-dirty"
fi
say "building $stamp, $mode, Godot $short"
mkdir -p "$OUT"

# -- build ------------------------------------------------------------------------

## The Android SDK Godot will use: the editor's own setting first, then ANDROID_HOME. On this
## machine ANDROID_HOME points at a directory with only cmdline-tools, so the order matters.
android_sdk() {
	local sdk
	sdk=$(sed -n 's/^export\/android\/android_sdk_path = "\(.*\)"$/\1/p' \
		"${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-$minor.tres" 2>/dev/null | tail -n1)
	: "${sdk:=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}}"
	echo "$sdk"
}

built=()
skipped=()
for target in "${wanted[@]}"; do
	if ! i=$(index_of "$target"); then
		bad "no preset called '$target'. Try --list."
		exit 2
	fi
	name="${names[$i]}"
	platform="${platforms[$i]:-}"
	ext=$(extension_for "$platform")
	if ! have_templates_for "$platform"; then
		if [ "$explicit" -eq 1 ]; then
			bad "no $platform export templates in $templates."
			bad "  fix: Editor > Manage Export Templates > Download and Install"
			exit 2
		fi
		say "skipping $name - no $platform templates installed"
		skipped+=("$name")
		continue
	fi
	artifact="$OUT/ghost-notes-$(printf '%s' "$name" | tr '[:upper:] ' '[:lower:]-')$ext"

	if [ "$platform" = "Android" ]; then
		sdk=$(android_sdk)
		if [ -z "$sdk" ] || [ ! -d "$sdk/platform-tools" ]; then
			bad "no usable Android SDK (tried the editor setting, then ANDROID_HOME: '${sdk:-unset}')."
			bad "  fix: Editor > Editor Settings > Export > Android > Android SDK Path"
			exit 2
		fi
		export ANDROID_HOME="$sdk"
		if [ "$mode" = "release" ]; then
			for v in GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER \
					GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
				if [ -z "${!v:-}" ]; then
					bad "a release APK needs $v set (and its two siblings). Or build --debug."
					exit 2
				fi
			done
		fi
	fi

	rm -f "$artifact"
	say "$name -> $artifact"
	log=$(mktemp)
	"$GODOT" --headless --path . "--export-$mode" "$name" "$artifact" >"$log" 2>&1
	status=$?
	# Only what is worth reading; the whole log is printed if the build fails.
	grep -iE 'error|warning|failed' "$log" \
		| grep -viE 'daemon at tcp:|^[[:space:]]*at: ' \
		| sed 's/^/    /' | head -20
	size=0
	[ -f "$artifact" ] && size=$(stat -c%s "$artifact" 2>/dev/null || echo 0)
	if [ "$status" -ne 0 ] || [ "$size" -lt "$FLOOR" ] || \
			grep -qiE 'SCRIPT ERROR:|Parse Error:|ERROR:|Failed to export' "$log"; then
		bad "$name did not build cleanly (godot exited $status, wrote $size bytes). Log:"
		sed 's/^/    /' "$log" >&2
		rm -f "$log"
		rm -f "$artifact"
		exit 1
	fi
	rm -f "$log"
	if [ "$smoke" -eq 1 ] && { [ "$platform" = "Linux" ] || [ "$platform" = "Linux/X11" ]; }; then
		if ! scripts/smoke-export.sh "$artifact"; then
			bad "$name exported, but its standalone launch check failed."
			rm -f "$artifact"
			exit 1
		fi
	fi
	printf '    %s MB\n' "$((size / 1048576))"
	built+=("$artifact:$platform")
done

# -- and, if asked, put it on the phone ---------------------------------------------

if [ "$install" -eq 1 ]; then
	adb="adb"
	if ! command -v adb >/dev/null 2>&1; then
		adb="$(android_sdk)/platform-tools/adb"     # not on PATH on this machine
	fi
	for entry in "${built[@]}"; do
		[ "${entry##*:}" = "Android" ] || continue
		file="${entry%:*}"
		if [ ! -x "$adb" ] && ! command -v "$adb" >/dev/null 2>&1; then
			bad "no adb (not on PATH, not in the SDK's platform-tools); cannot install $file."
			exit 2
		fi
		if [ -z "$("$adb" devices | sed -n '2p')" ]; then
			bad "no device connected. Plug one in and enable USB debugging."
			exit 2
		fi
		say "installing $file"
		"$adb" install -r "$file" || exit 1
		say "run it, then watch: $adb logcat -s godot"
	done
fi

if [ "${#skipped[@]}" -gt 0 ]; then
	say "skipped: ${skipped[*]} (templates not installed)"
fi
if [ "${#built[@]}" -eq 0 ]; then
	bad "nothing was built."
	exit 1
fi
say "built ${#built[@]} target(s) into $OUT/"
for entry in "${built[@]}"; do
	printf '    %s\n' "${entry%:*}"
done
