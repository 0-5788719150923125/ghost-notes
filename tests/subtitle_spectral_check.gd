extends Node

## Synthetic FFT gate for the shared synthesis, generative, and cards overlay.
## tests/run_boot_probe.sh tests/subtitle_spectral_check.gd 60

var _fails := 0


func _ready() -> void:
	var subs := Subtitles.new()
	add_child(subs)
	var overlay := subs._overlay
	var quiet := AudioFeatures.new()
	quiet.bands.resize(Spectrum.BAND_COUNT)
	quiet.time = 1.0
	subs._advance_spectral(quiet, 0.1)
	var baseline: Color = overlay._glyph_color(0.2, 0, 0.5, 1.0)
	var loud := AudioFeatures.new()
	loud.bands.resize(Spectrum.BAND_COUNT)
	for i in range(13, 18):
		loud.bands[i] = 0.8
	loud.time = 1.1
	subs._advance_spectral(loud, 0.15)
	var low: Color = overlay._glyph_color(0.2, 0, 0.5, 1.1)
	var high: Color = overlay._glyph_color(0.2, 21, 21.5, 1.1)
	_check(low.s > baseline.s + 0.1 and low.v > baseline.v, "low spectral component did not light its glyph")
	_check(high.s < low.s - 0.1, "unrelated glyph responded to the low component")
	var at_peak: float = subs._spectral_levels[0]
	quiet.time = 1.2
	subs._advance_spectral(quiet, 0.1)
	_check(subs._spectral_levels[0] > 0.0 and subs._spectral_levels[0] < at_peak,
		"spectral pulse did not persist and decay")
	var full := AudioFeatures.new()
	full.bands.resize(Spectrum.BAND_COUNT)
	full.bands.fill(0.8)
	full.time = 1.3
	subs._advance_spectral(full, 1.0)
	quiet.time = 1.4
	subs._advance_spectral(quiet, 0.3)
	_check(subs._spectral_levels[7] > subs._spectral_levels[0] + 0.15,
		"frequency components have the same persistence")
	quiet.time = 0.0
	subs._advance_spectral(quiet, 0.01)
	_check(subs._spectral_levels[0] < 0.001, "seek left an old spectral trail")
	print("subtitle_spectral_check: %s" % ("ALL OK" if _fails == 0 else "%d failures" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, reason: String) -> void:
	if not ok:
		_fails += 1
		printerr("subtitle_spectral_check: " + reason)
