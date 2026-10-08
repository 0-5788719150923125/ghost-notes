extends SceneTree

## bake_runner - a headless one-shot that analyzes a song and writes its spectrum
## cache, then quits. The exporter launches this (with --headless, so NO window
## appears) before the video render, so the render can just load the cache and start
## drawing immediately instead of freezing while it bakes. Run as:
##   godot --headless --path . --script res://src/bake_runner.gd -- \
##         --bake-song <path> --bake-out <cache.spec>
##
## The analysis parameters here MUST match Spectrum's (BAND_COUNT / FREQ_MIN /
## FREQ_MAX / DB_FLOOR / BAKE_FPS) so the cache the render loads is the right shape.

func _init() -> void:
	quit(SpectrumBake.run_cli(OS.get_cmdline_user_args()))
