#!/usr/bin/env bash
# Is this tree green? Every gate, from one command.
#
#   scripts/check.sh                 # parse, every headless gate, then docs.py --check
#   scripts/check.sh --gpu           # ...and the gates that need a real renderer (xvfb + GPU)
#   scripts/check.sh --only a,b      # just these (gate names without .gd; parse/docs/scene_smoke too)
#   scripts/check.sh --skip a,b      # everything but these
#   scripts/check.sh --fail-fast     # stop at the first failing gate (CI: no compute spent on a red run)
#   scripts/check.sh --jobs 4        # run four gates at once (`auto` = one per core); the default is 1
#   scripts/check.sh --list          # what would run, how, and (with --jobs) in what order
#   scripts/check.sh --for           # the gates that cover what changed since the last commit
#   scripts/check.sh --for src/table # ...or what is under these paths
#
# Logs go to dist/check/<gate>.log; a passing gate's log is removed unless --keep. Two runs in one
# working tree (two sessions at once) each name a folder of their own - GHOST_CHECK_OUT=dist/check_b -
# or the second overwrites the first's logs and its record of how long each gate took.
#
# WHICH GATES. Every tests/<folder>/*_check.gd on disk (and the few cross-cutting ones at the top
# of tests/) - a new gate needs no edit here. The folders mirror src/: a gate lives in the folder of
# what it holds, which is what `--for` reads (below). A gate's name is unique. How each runs
# is read off the gate: `extends SceneTree` runs under `godot --script`, anything else is a
# boot probe (tests/run_boot_probe.sh: the real app with its autoloads, in a scene of its
# own, read-only). A gate that needs a REAL RENDERER is named in GPU below - a pixel read
# back under --headless is null - and runs only with --gpu, under xvfb, never in a window.
# Three more: `parse` (the editor's own load of every script, first, because a parse error
# fails every gate after it in a less readable way), `scene_smoke` (tests/run_scene_smoke.sh,
# every scene in the roster) and `docs` (python docs.py --check).
#
# THE VERDICT. Exit 0 is a pass. Several gates print their verdict and then the ENGINE dies
# in its own teardown - an abort, a segfault, or a hang until the timeout - the fault
# tests/run_scene_smoke.sh documents. A gate that printed its own passing verdict
# (`<name>: ALL OK` or `<name>: PASS`) and no FAIL line is counted as a pass and marked
# `ok*`; one that died before saying anything is a failure, and so is one that printed a
# `SCRIPT ERROR` its header does not declare (`## script errors: N`). Exit codes are never trusted
# alone, and neither is silence.
#
# THE TIMEOUT is the one in the gate's own run line (`run_boot_probe.sh tests/<folder>/<name>.gd 120`,
# or for a SceneTree gate `timeout 600 godot --headless --path . --script res://tests/<folder>/<name>.gd`),
# else 300 s; anything after it on a probe's line is handed to the probe as its args.
#
# THE LONGEST GATES START FIRST (--jobs above 1), by how long each took the last time it passed
# (dist/check/.times, written by every run; CI carries it from run to run in a cache). Left in
# the order they are found, the two longest gates started near the end and ran by themselves for
# almost half the run, three of four cores idle - measured on a runner, 2026-10-13: 1040 s of
# gates, 260 s at best four at a time, 372 s taken. A gate with no time yet starts before the
# timed ones, the longest timeout first: a new gate is the one most worth an early answer. The
# last lines of a run say what the gates added up to and what that is at best over the cores,
# so a run that is not using them shows it.
#
# WHAT `--for` RUNS. src/ is a stack of folders, and a change can reach only the folders above the
# one it is in (docs/structure.md). So the gates for a change are those in the folder it touched
# and in every folder above it, with parse, docs and compile_check: a change in src/table/ runs
# the table's, the cards', Masking's and the shell's gates, and none of the voice's. A gate that
# changed runs itself. A path outside src/ and tests/ (a shader, a host, the rules) gives no
# folder, so `--for` says so and runs everything - it never guesses smaller. The order of the
# stack is docs.py's (`python3 docs.py --folders`), never a copy here.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
declare -A running=()   # pid -> gate, while --jobs runs several at once
## A gate runs in a process group of its own under --jobs (set -m), so a stop reaches its Godot and
## everything below it. Exact groups, by the pid this script started; never a pattern.
stop_running() {
	local p
	for p in "${!running[@]}"; do kill -TERM -- "-$p" 2>/dev/null; done
}
trap stop_running EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

GODOT="${GODOT:-godot}"
OUT="${GHOST_CHECK_OUT:-dist/check}"

## Gates that need a real renderer (pixels, shader compiles). Boot probes among them run
## with GHOST_PROBE_GPU=1; SceneTree gates run through tests/run_quiet.sh.
GPU=(clown_anchor_check clown_coat_check clown_controls_check clown_coverage_check
	clown_drip_check clown_scale_check clown_shader_check paint_sim_check repaint_check
	rain_check umbra_shader_check umbra_sim_check intro_blur_check stage_filter_check
	ambience_severity_check feedback_ask_check film_clock_check fractal_depth_check
	strata_band_check tunnel_face_check tunnel_smooth_check vapor_check portrait_render_check
	light_screen_check table_thread_check card_veil_check warp_check likeness_determinism_check
	splat_head_check table_shadow_check)

gpu=0
keep=0
fail_fast=0
jobs=1
list=0
only=""
skip=""
for_set=0
for_paths=()
while [ "$#" -gt 0 ]; do
	case "$1" in
		--gpu) gpu=1 ;;
		--keep) keep=1 ;;
		--fail-fast) fail_fast=1 ;;
		--jobs|-j) jobs="${2:-1}"; shift ;;
		--jobs=*) jobs="${1#--jobs=}" ;;
		--list) list=1 ;;
		--only) only="${2:-}"; shift ;;
		--only=*) only="${1#--only=}" ;;
		--skip) skip="${2:-}"; shift ;;
		--skip=*) skip="${1#--skip=}" ;;
		--for)
			for_set=1
			while [ "$#" -gt 1 ] && [[ "$2" != --* ]]; do for_paths+=("$2"); shift; done ;;
		-h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "check.sh: unknown option '$1'. Try --help." >&2; exit 2 ;;
	esac
	shift
done

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
bad() { printf '\033[1;31mcheck.sh:\033[0m %s\n' "$*" >&2; }

if ! command -v "$GODOT" >/dev/null 2>&1; then
	bad "no '$GODOT' on PATH. Set GODOT=/path/to/godot."
	exit 2
fi

in_list() {  # in_list <word> <comma-or-space list>
	local w="$1" l=",${2// /,},"
	[[ "$l" == *",$w,"* ]]
}
is_gpu() { in_list "$1" "${GPU[*]}"; }
## WHERE EACH GATE IS: name -> tests/<folder>/<name>.gd (or tests/<name>.gd for a cross-cutting one).
declare -A path_of=()
for f in tests/*_check.gd tests/*/*_check.gd; do
	[ -f "$f" ] || continue
	n=$(basename "$f" .gd)
	[ -z "${path_of[$n]:-}" ] || { bad "two gates are called $n: ${path_of[$n]} and $f"; exit 2; }
	path_of[$n]="$f"
done
kind_of() {  # script | probe
	if grep -qE '^extends SceneTree' "${path_of[$1]}"; then echo script; else echo probe; fi
}
timeout_of() {
	local t p="${path_of[$1]:-}"
	[ -n "$p" ] && [ -f "$p" ] || { echo 300; return; }
	t=$(grep -m1 -oE "run_boot_probe\.sh ${p//./\\.} [0-9]+" "$p" | grep -oE '[0-9]+$')
	# a SceneTree gate that needs longer says so the same way, in its own run line
	[ -n "$t" ] || t=$(grep -m1 -oE "timeout [0-9]+ godot .*--script (res://)?${p//./\\.}" "$p" \
		| grep -oE '^timeout [0-9]+' | grep -oE '[0-9]+')
	echo "${t:-300}"
}
## ...and the rest of that line is the probe's args (`... 400 --seed 2491232026`), so the
## documented command and the gatekeeping run the same show.
args_of() {
	local p="${path_of[$1]}"
	grep -m1 -oE "run_boot_probe\.sh ${p//./\\.} [0-9]+.*" "$p" | cut -d' ' -f4-
}

# -- what runs ------------------------------------------------------------------

## `docs` is a second long, so it runs second: a stale generated doc fails before any slow gate starts.
gates=(parse docs)
for name in $(printf '%s\n' "${!path_of[@]}" | sort); do
	if is_gpu "$name" && [ "$gpu" -eq 0 ] && [ -z "$only" ]; then
		continue
	fi
	gates+=("$name")
done
gates+=(scene_smoke)

## --for: the folders a change touched, and every folder above them in the stack.
if [ "$for_set" -eq 1 ]; then
	if [ "${#for_paths[@]}" -eq 0 ]; then
		mapfile -t for_paths < <({ git diff --name-only HEAD; git ls-files --others --exclude-standard; } 2>/dev/null | sort -u)
	fi
	mapfile -t stack < <(python3 docs.py --folders)
	declare -A touched=() own=()
	everything=0
	for p in "${for_paths[@]}"; do
		p="${p#./}"
		case "$p" in
			src/*/*) touched[$(cut -d/ -f2 <<<"$p")]=1 ;;
			src/*) touched[$(cut -d/ -f2 <<<"$p")]=1 ;;
			tests/*/*_check.gd|tests/*_check.gd) own[$(basename "$p" .gd)]=1 ;;
			tests/*|docs/*|next/*|*.md|docs.py) ;;
			*) everything=1; say "--for: $p is outside src/ and tests/, so everything runs" ;;
		esac
	done
	if [ "$everything" -eq 0 ]; then
		declare -A reach=()
		low=-1
		for i in "${!stack[@]}"; do
			if [ -n "${touched[${stack[$i]}]:-}" ] && [ "$low" -lt 0 ]; then low=$i; fi
		done
		if [ "$low" -ge 0 ]; then
			for i in "${!stack[@]}"; do [ "$i" -ge "$low" ] && reach[${stack[$i]}]=1; done
		fi
		picked=()
		for g in "${gates[@]}"; do
			case "$g" in
				parse|docs|compile_check) picked+=("$g"); continue ;;
				scene_smoke) [ -n "${reach[scenes]:-}" ] && picked+=("$g"); continue ;;
			esac
			folder=$(cut -d/ -f2 <<<"${path_of[$g]}")
			if [ -n "${own[$g]:-}" ] || [ -n "${reach[$folder]:-}" ]; then picked+=("$g"); fi
		done
		gates=("${picked[@]}")
		tk="${!touched[*]}"
		ok_="${!own[*]}"
		say "--for: touched ${tk:-no folder}${ok_:+, and the gates $ok_} - so the folders from ${stack[$low]:-none} up"
	fi
fi
if [ -n "$only" ]; then
	picked=()
	for g in "${gates[@]}"; do in_list "$g" "$only" && picked+=("$g"); done
	for w in ${only//,/ }; do
		in_list "$w" "${gates[*]}" || { bad "no gate called '$w'. Try --list."; exit 2; }
	done
	gates=("${picked[@]}")
fi
if [ -n "$skip" ]; then
	kept=()
	for g in "${gates[@]}"; do in_list "$g" "$skip" || kept+=("$g"); done
	gates=("${kept[@]}")
fi

how() {
	case "$1" in
		parse) echo "godot --headless --editor --quit (every script loads)" ;;
		scene_smoke) echo "tests/run_scene_smoke.sh" ;;
		docs) echo "python3 docs.py --check" ;;
		*)
			local k t
			k=$(kind_of "$1"); t=$(timeout_of "$1")
			if [ "$k" = script ]; then
				if is_gpu "$1"; then echo "tests/run_quiet.sh (xvfb)"; else echo "godot --headless --script, ${t}s"; fi
			else
				local a
				a=$(args_of "$1")
				if is_gpu "$1"; then echo "boot probe on the GPU (xvfb), ${t}s${a:+, $a}"; else echo "boot probe, ${t}s${a:+, $a}"; fi
			fi ;;
	esac
}

## HOW LONG EACH GATE TOOK the last time it passed: `<gate> <seconds>` a line in $OUT/.times.
## Read here, kept current as gates finish, written back when the run ends - a run cut short
## still keeps what it measured. Only a pass is a time worth keeping: a gate that failed fast,
## or ran into its timeout, says nothing about how long it takes.
declare -A took=()
if [ -f "$OUT/.times" ]; then
	while read -r tg ts; do
		[[ "$ts" =~ ^[0-9]+$ ]] && took[$tg]=$ts
	done <"$OUT/.times"
fi

## THE ORDER GATES START IN when several run at once: `parse` and `docs` first and alone, then
## THE LONGEST FIRST, so none of them is left running alone at the end with the other cores idle -
## by the time each took when it last passed, and a gate with no time yet before all of those, the
## longest timeout first (see the header). Prints one gate a line.
start_order() {
	local g
	for g in "$@"; do [ "$g" = parse ] || [ "$g" = docs ] && echo "$g"; done
	for g in "$@"; do
		[ "$g" = parse ] || [ "$g" = docs ] && continue
		if [ -n "${took[$g]:-}" ]; then echo "${took[$g]} $g"; else echo "$((100000 + $(timeout_of "$g"))) $g"; fi
	done | sort -k1,1nr -k2,2 | cut -d' ' -f2
}

[ "$jobs" = auto ] && jobs=$(nproc 2>/dev/null || echo 1)
if ! [[ "$jobs" =~ ^[1-9][0-9]*$ ]]; then
	bad "--jobs wants a positive number or 'auto', not '$jobs'."
	exit 2
fi

if [ "$list" -eq 1 ]; then
	# in the order they would start, each with how it runs and how long it took last time
	listed=("${gates[@]}")
	[ "$jobs" -gt 1 ] && mapfile -t listed < <(start_order "${gates[@]}")
	for g in "${listed[@]}"; do
		printf '    %-28s %-46s %s\n' "$g" "$(how "$g")" "${took[$g]:+last ${took[$g]}s}"
	done
	[ "$gpu" -eq 0 ] && [ -z "$only" ] && printf '    (%d GPU gates need --gpu)\n' "${#GPU[@]}"
	exit 0
fi

mkdir -p "$OUT"
# ONE RUN AT A TIME: two runs would write the same logs. Probes themselves may overlap with
# anything (each boots its own scene), so this guards only this script's own output.
exec 9>"$OUT/.lock"
if command -v flock >/dev/null 2>&1 && ! flock -n 9; then
	bad "another scripts/check.sh is running (it holds $OUT/.lock)."
	exit 2
fi

save_times() {
	local g
	for g in "${!took[@]}"; do echo "$g ${took[$g]}"; done | sort >"$OUT/.times.new" \
		&& mv -f "$OUT/.times.new" "$OUT/.times"
}
trap 'stop_running; save_times' EXIT
work=0          # this run's gates, added up, in seconds
longest=0
longest_g=""

# -- run ------------------------------------------------------------------------

run_gate() {  # run_gate <name> <log>; returns the raw exit code
	local g="$1" log="$2" t
	case "$g" in
		parse)
			# The editor's own scan: every script parsed, every class registered, every UID
			# resolved. It also refreshes the class cache, which a `--script` gate needs for a
			# class_name added since the editor last ran.
			# Keep Godot in the terminal's process group so Ctrl+C reaches it.
			timeout --foreground 600 "$GODOT" --headless --path . --editor --quit >"$log" 2>&1
			local rc=$?
			if grep -qiE 'Parse Error|Failed to load script|Failed loading resource|invalid UID|Unrecognized UID|SCRIPT ERROR|Compile Error' "$log"; then
				return 1
			fi
			return "$rc" ;;
		scene_smoke) tests/run_scene_smoke.sh 900 >"$log" 2>&1 ;;
		docs) python3 docs.py --check >"$log" 2>&1 ;;
		*)
			t=$(timeout_of "$g")
			if [ "$(kind_of "$g")" = script ]; then
				if is_gpu "$g"; then
					timeout --foreground "$t" tests/run_quiet.sh "${path_of[$g]}" >"$log" 2>&1
				else
					local plog
					plog=$(mktemp)
					timeout --foreground "$t" "$GODOT" --headless --log-file "$plog" --path . --script "res://${path_of[$g]}" >"$log" 2>&1
					local rc=$?
					rm -f "$plog"
					return "$rc"
				fi
			else
				local -a pa=()
				read -ra pa <<<"$(args_of "$g")"
				if is_gpu "$g"; then
					GHOST_PROBE_GPU=1 GHOST_PROBE_MUTE=1 tests/run_boot_probe.sh "${path_of[$g]}" "$t" "${pa[@]}" >"$log" 2>&1
				else
					tests/run_boot_probe.sh "${path_of[$g]}" "$t" "${pa[@]}" >"$log" 2>&1
				fi
			fi ;;
	esac
}

## The gate's own words: did it print a passing verdict, and no failure?
said_pass() {
	local g="$1" log="$2"
	grep -qE "^$g: (ALL OK|PASS)" "$log" && ! grep -qE "^$g: .*FAIL|FAILED" "$log"
}

say "${#gates[@]} gate(s)$([ "$gpu" -eq 1 ] && echo ', GPU included')"
failed=()
dirty=()
t_all=$(date +%s)

## Run one gate; leave its exit code and seconds in $OUT/.res.<gate> for settle.
run_one() {
	local g="$1" t0 rc
	t0=$(date +%s)
	run_gate "$g" "$OUT/$g.log"
	rc=$?
	echo "$rc $(( $(date +%s) - t0 ))" >"$OUT/.res.$g"
}

## Print one finished gate's verdict. Returns 1 when it failed.
settle() {
	local g="$1" log="$OUT/$1.log" rc dt
	read -r rc dt <"$OUT/.res.$g"
	rm -f "$OUT/.res.$g"
	work=$((work + dt))
	if [ "$dt" -gt "$longest" ]; then longest=$dt; longest_g=$g; fi
	# a shader compile check reports through its output, not its exit code
	if [ "$rc" -eq 0 ] && grep -q 'SHADER ERROR' "$log"; then
		rc=98
	fi
	# A RUNTIME ERROR BEHIND A PASS IS A FAILURE. A GDScript error prints and carries on, so the
	# check that hit one ended early and the gate went on to print its verdict over everything it
	# skipped - clown_face_check set two members that no longer existed and passed for a week with
	# its Steadiness check never reached. A gate that makes runtime errors on purpose (a control)
	# says how many in its header, `## script errors: N`, and more than that fails it. COMPILE
	# errors are not counted here: a `--script` gate is compiled once before the autoloads exist,
	# so every script it names that names one prints a compile error and is compiled again a moment
	# later (compile_check's note) - a harness artifact, and `parse` and `compile_check` hold the
	# real ones.
	local errs allowed
	errs=$(grep 'SCRIPT ERROR' "$log" 2>/dev/null | grep -vcE 'Compile Error|Parse Error')
	allowed=$(grep -m1 -oE '^## script errors: [0-9]+' "${path_of[$g]:-/dev/null}" 2>/dev/null | grep -oE '[0-9]+$')
	if [ "${errs:-0}" -gt "${allowed:-0}" ] && [ "$g" != parse ]; then
		echo "check.sh: $g printed ${errs} SCRIPT ERROR(s), its header allows ${allowed:-0}" >>"$log"
		rc=97
	fi
	if [ "$rc" -eq 0 ]; then
		printf '  ok     %-28s %4ds\n' "$g" "$dt"
		took[$g]=$dt
		[ "$keep" -eq 1 ] || rm -f "$log"
	elif [ "$rc" -eq 137 ] && said_pass "$g" "$log"; then
		# the probe ended itself with a SIGKILL after its verdict, to skip the engine's teardown
		printf '  ok     %-28s %4ds   (hard exit after its verdict)\n' "$g" "$dt"
		took[$g]=$dt
		[ "$keep" -eq 1 ] || rm -f "$log"
	elif { [ "$rc" -eq 124 ] || [ "$rc" -ge 128 ]; } && said_pass "$g" "$log"; then
		printf '  ok*    %-28s %4ds   passed, then the engine %s in teardown (exit %d)\n' "$g" "$dt" \
			"$([ "$rc" -eq 124 ] && echo 'hung' || echo 'crashed')" "$rc"
		dirty+=("$g")
		# (a hang's time is its timeout, not the gate's: only a crash after the verdict is kept)
		[ "$rc" -eq 124 ] || took[$g]=$dt
		[ "$keep" -eq 1 ] || rm -f "$log"
	else
		printf '  FAIL   %-28s %4ds   exit %d - %s\n' "$g" "$dt" "$rc" "$log"
		grep -E 'FAIL|ERROR|Error|TIMED OUT' "$log" | grep -vE '^\s*at:' | head -5 | sed 's/^/           /'
		failed+=("$g")
		if [ "$fail_fast" -eq 1 ]; then
			echo "  --- $log (first 80 lines) ---"
			head -n 80 "$log" | sed 's/^/  | /'
		fi
		return 1
	fi
}

if [ "$jobs" -le 1 ]; then
	for g in "${gates[@]}"; do
		run_one "$g"
		settle "$g" || [ "$fail_fast" -eq 0 ] || break
	done
else
	set -m
	## `parse` first and alone (it registers the class names every other gate loads), then `docs`.
	queue=()
	for g in "${gates[@]}"; do
		if [ "$g" = parse ] || [ "$g" = docs ]; then
			[ "${#failed[@]}" -gt 0 ] && [ "$fail_fast" -eq 1 ] && continue
			run_one "$g"
			settle "$g"
		else
			queue+=("$g")
		fi
	done
	[ "${#failed[@]}" -gt 0 ] && [ "$fail_fast" -eq 1 ] && queue=()
	## the longest first (see start_order)
	timed=0
	for g in "${queue[@]}"; do [ -n "${took[$g]:-}" ] && timed=$((timed + 1)); done
	say "$jobs at a time, the longest first ($timed of ${#queue[@]} timed by an earlier run)"
	[ "${#queue[@]}" -gt 0 ] && mapfile -t queue < <(start_order "${queue[@]}")
	stop=0
	while [ "${#queue[@]}" -gt 0 ] || [ "${#running[@]}" -gt 0 ]; do
		while [ "$stop" -eq 0 ] && [ "${#queue[@]}" -gt 0 ] && [ "${#running[@]}" -lt "$jobs" ]; do
			g="${queue[0]}"
			queue=("${queue[@]:1}")
			run_one "$g" &
			running[$!]="$g"
		done
		[ "${#running[@]}" -gt 0 ] || break
		done_pid=""
		wait -n -p done_pid
		g="${running[$done_pid]:-}"
		[ -n "$g" ] || continue
		unset "running[$done_pid]"
		if ! settle "$g" && [ "$fail_fast" -eq 1 ] && [ "$stop" -eq 0 ]; then
			stop=1
			stop_running
			wait 2>/dev/null
			for g in "${running[@]}"; do rm -f "$OUT/.res.$g"; done
			running=()
		fi
	done
fi

echo
t_total=$(( $(date +%s) - t_all ))
## WHAT THE CORES WERE GIVEN, so a run that is not using them shows it: the gates added up, what
## that is at best over this many at a time, and the one gate no number of cores makes shorter.
clock() { printf '%dm%02ds' $(($1 / 60)) $(($1 % 60)); }
if [ "$jobs" -gt 1 ] && [ "$work" -gt 0 ]; then
	best=$(( (work + jobs - 1) / jobs ))
	[ "$longest" -gt "$best" ] && best=$longest
	say "$(clock "$work") of gates in $(clock "$t_total"), $jobs at a time: $(clock "$best") at best (the longest alone, $longest_g, is $(clock "$longest"))"
fi
if [ "${#dirty[@]}" -gt 0 ]; then
	say "ok* = passed, then the engine died in teardown: ${dirty[*]}"
fi
if [ "${#failed[@]}" -eq 0 ]; then
	say "all ${#gates[@]} gate(s) passed in $((t_total / 60))m$((t_total % 60))s$([ "$gpu" -eq 0 ] && echo ' (GPU gates not run: --gpu)')"
	exit 0
fi
bad "${#failed[@]} of ${#gates[@]} gate(s) FAILED: ${failed[*]}$([ "$fail_fast" -eq 1 ] && echo " (--fail-fast: the rest did not run)")"
exit 1
