extends SceneTree

## bake_runner - a headless one-shot that analyzes a song and writes its spectrum cache, then quits. The
## exporter launches it (with --headless, so no window appears) before the video render, so the render loads
## the cache instead of freezing while it bakes. Run as:
##   godot --headless --path . --script res://src/audio/bake_runner.gd -- \
##         --bake-song <path> --bake-out <cache.spec>
##
## The analysis parameters must match Spectrum's (BAND_COUNT / FREQ_MIN / FREQ_MAX / DB_FLOOR / BAKE_FPS).

func _init() -> void:
	quit(SpectrumBake.run_cli(OS.get_cmdline_user_args()))
