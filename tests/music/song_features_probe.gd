extends SceneTree

## song_features_probe - how the show hears a song: the offline bake ([SpectrumBake]) of each file given, run through
## Spectrum's own beat, movement and chroma rules frame by frame, and a line a file - onsets a minute, the share of the
## song where the movement is up, and how far the harmony moves (the chroma's distance between 2 s stretches).
##   godot --headless --path . --log-file <scratch> --script tests/music/song_features_probe.gd -- <file> [<file> ...]

const FPS := 30


func _init() -> void:
	var files := OS.get_cmdline_user_args()
	for path in files:
		var frames := SpectrumBake.bake(path, FPS, AudioFeatures.BAND_COUNT, 30.0, 16000.0, 60.0)
		if frames.is_empty():
			print("song_features_probe: could not read %s" % path)
			continue
		print("song_features_probe: %s  %s" % [path.get_file(), _measure(frames)])
	quit(0)


func _measure(frames: Array) -> String:
	var avg := 0.0
	var high := false
	var onsets := 0
	var prev := PackedFloat32Array()
	var fast := 0.0
	var slow := 0.0
	var moving := 0
	var energies := PackedFloat32Array()
	var chroma: Array = []
	var pc := PackedInt32Array()
	pc.resize(AudioFeatures.BAND_COUNT)
	for b in AudioFeatures.BAND_COUNT:
		var f := 30.0 * pow(16000.0 / 30.0, (b + 0.5) / AudioFeatures.BAND_COUNT)
		pc[b] = int(posmod(round(12.0 * log(f / 16.35) / log(2.0)), 12.0))
	var acc := PackedFloat32Array()
	acc.resize(12)
	for i in frames.size():
		var bands: PackedFloat32Array = frames[i]
		var e := 0.0
		for v in bands:
			e += v
		e /= bands.size()
		energies.append(e)
		# Spectrum's onset rule, at its own rates (it runs at the app's frame rate; two steps a bake frame)
		for _k in 2:
			avg = lerpf(avg, e, 0.08)
		var on := e > avg * 1.4 + 0.02
		if on and not high:
			onsets += 1
		high = on
		var flux := 0.0
		if prev.size() == bands.size():
			for b in bands.size():
				flux += maxf(0.0, bands[b] - prev[b])
			flux /= bands.size()
		prev = bands
		for _k in 2:
			fast = lerpf(fast, flux, 0.18)
			slow = lerpf(slow, flux, 0.012)
		if clampf((fast / (slow + 0.0008) - 1.3) * 0.7, 0.0, 1.0) > 0.5:
			moving += 1
		for b in bands.size():
			acc[pc[b]] += bands[b]
		if i % (2 * FPS) == 2 * FPS - 1:
			chroma.append(_unit(acc))
			acc.fill(0.0)
	var drift := 0.0
	for k in range(1, chroma.size()):
		drift += 1.0 - _dot(chroma[k], chroma[k - 1])
	drift /= maxf(1.0, chroma.size() - 1)
	var minutes := frames.size() / float(FPS) / 60.0
	var sorted := energies.duplicate()
	sorted.sort()
	var spread := sorted[int(sorted.size() * 0.95)] - sorted[int(sorted.size() * 0.05)]
	return "onsets %.0f/min  moving %.1f%%  energy 5-95%% spread %.3f  harmony drift %.4f" % [onsets / minutes,
		100.0 * moving / frames.size(), spread, drift]


static func _unit(v: PackedFloat32Array) -> PackedFloat32Array:
	var s := 0.0
	for x in v:
		s += x * x
	var out := v.duplicate()
	if s > 0.0:
		for i in out.size():
			out[i] /= sqrt(s)
	return out


static func _dot(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var s := 0.0
	for i in a.size():
		s += a[i] * b[i]
	return s
