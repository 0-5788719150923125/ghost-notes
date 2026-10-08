#!/usr/bin/env bash
# Run a probe (tests/<probe>.gd) inside a REAL boot, with autoloads alive.
#
# WHY THIS EXISTS
# ---------------
# `godot --headless --script X.gd` runs a SceneTree script with no autoloads, so
# anything touching Spectrum or Director fails to compile with "Identifier not
# found". That limitation is real, but the conclusion drawn from it - that such
# code cannot be tested headlessly - was wrong, and it cost a string of bugs
# that were shipped on a compile check and a careful read instead of a run.
#
# A real boot has autoloads. All that is needed is to point the app at a probe
# scene instead of main, and Godot takes that as a POSITIONAL ARGUMENT - a scene
# path after the options runs that scene, autoloads and all.
#
#   tests/run_boot_probe.sh <probe.gd> [timeout_seconds] [probe args ...]
#   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh <probe.gd>   # real renderer, no window
#
# It used to say so in override.cfg instead, and that file is project-wide state:
# the exporter writes one too, so this script had to refuse to run at all while a
# render was in flight, and a run killed uncleanly left ghost itself booting into
# a probe. An argument is local to the process. Nothing global is touched now and
# a probe runs perfectly happily alongside a render.
#
# EACH RUN BOOTS A SCENE OF ITS OWN, `tests/_probe_<pid>.tscn`, naming the probe
# where it lies (a probe outside the project is copied to `tests/_probe_<pid>.gd`
# first), and removes it on exit. It used to copy the probe over one shared
# `tests/boot_probe.gd` and restore a stub afterwards - so two runs at once (two
# dispatched agents, or an agent and you) ran each other's probes and could
# restore the WRONG file permanently, and the "stub" that was committed had
# itself become an old copy of a probe. Nothing is shared now: runs can overlap,
# and nothing tracked is ever touched. Settings treats any scene under res://tests/
# as a probe (Settings.is_probe_launch), so every run is read-only.
#
# Print what you want to see and call get_tree().quit(); the timeout is a
# backstop for a probe that hangs. Note that most probe locals need explicit
# types - objects loaded with load().new() are untyped Variants and inference
# will fail on them.

set -uo pipefail
cd "$(dirname "$0")/.."          # the project root
PROBE_SRC="${1:-}"
TIMEOUT="${2:-90}"
if [[ -z "$PROBE_SRC" || ! -f "$PROBE_SRC" ]]; then
  echo "run_boot_probe: no such probe: ${PROBE_SRC:-(none given)}" >&2
  echo "usage: tests/run_boot_probe.sh <probe.gd> [timeout_seconds] [probe args ...]" >&2
  exit 2
fi

# ARMED BEFORE ANYTHING IS WRITTEN, so an early exit can never leave a private scene
# (or a copied probe) behind in the project.
SCENE="tests/_probe_$$.tscn"
COPY=""
cleanup() {
  rm -f "$SCENE"
  if [[ -n "$COPY" ]]; then rm -f "$COPY" "$COPY.uid"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

ROOT=$(pwd -P)
SRC=$(realpath "$PROBE_SRC")
if [[ "$SRC" == "$ROOT"/* ]]; then
  PROBE_RES="res://${SRC#"$ROOT"/}"
else
  COPY="tests/_probe_$$.gd"
  cp "$SRC" "$COPY"
  PROBE_RES="res://$COPY"
fi
cat > "$SCENE" <<EOF
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="$PROBE_RES" id="1"]

[node name="BootProbe" type="Node"]
script = ExtResource("1")
EOF

# THE RENDERER. A probe that needs autoloads AND REAL PIXELS has nowhere else to
# go: `--headless` is the dummy driver, whose viewport readback returns nothing
# (run_quiet.sh's header spells that out), and `godot --script` has no autoloads at
# all. GHOST_PROBE_GPU=1 boots this same probe scene on the real GPU inside a
# VIRTUAL DISPLAY, so it still never puts a window on screen. Needs
# xorg-server-xvfb, exactly like run_quiet.sh.
RUNNER=(godot --headless)
if [[ "${GHOST_PROBE_GPU:-0}" != "0" ]]; then
  if command -v xvfb-run >/dev/null 2>&1; then
    RUNNER=(xvfb-run -a -s "-screen 0 1280x1024x24" godot)
  else
    echo "run_boot_probe: GHOST_PROBE_GPU set but xvfb-run not found -" \
         "falling back to a VISIBLE window." >&2
    RUNNER=(godot)
  fi
fi

# A probe logs to a file of its own: every Godot process opens user://logs/godot.log, and a new
# one truncates it under a session that is running - the author's live log lost its lines to
# the probes run beside it. Its output still comes here, on stdout.
PROBE_LOG=$(mktemp)
trap 'cleanup; rm -f "$PROBE_LOG"' EXIT
RUNNER+=(--log-file "$PROBE_LOG")
# SILENT, on the real renderer: `--headless` already implies the Dummy audio driver, but a GPU
# probe that plays a reading would otherwise speak it out of the author's speakers.
# GHOST_PROBE_MUTE=1 keeps the mixer running - playback positions still advance - and sends
# the sound nowhere.
if [[ "${GHOST_PROBE_MUTE:-0}" != "0" ]]; then
  RUNNER+=(--audio-driver Dummy)
fi

# Anything after the timeout is handed to the PROBE as user args (read them with
# OS.get_cmdline_user_args), so a probe can take options the way clown_look_probe does.
# Keep the runner in the terminal's process group so Ctrl+C reaches Godot too.
timeout --foreground "$TIMEOUT" "${RUNNER[@]}" --path . "res://$SCENE" -- "${@:3}" 2>&1
status=$?
if [[ $status -eq 124 ]]; then
  echo "run_boot_probe: TIMED OUT after ${TIMEOUT}s (probe never quit)" >&2
fi
exit $status
