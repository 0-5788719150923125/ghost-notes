extends SceneTree

## A probe for LISTENING to [Soundscape]: renders a few places to WAV files, and prints how long each
## took to make (as a share of real time), its level, and how closely its loudness follows the wind.
##
##   godot --headless --path . --script res://tests/soundscape_probe.gd -- [seconds] [out dir] [dial]
##
## Defaults: 60 s each, into dist/soundscape/ (a real disk - /tmp is RAM), at the dial's middle.

const SR := 22050

const PLACES := {
	"boat_at_sea": {"sound": {"water": {"kind": "hull", "size": 0.6}, "wind": {"through": "rigging"}},
		"wind": {"from": "left", "strength": 0.6, "gusts": 0.7, "every": 14}},
	"dock": {"sound": {"water": {"kind": "dock", "size": 0.4, "from": "back"}, "wind": {"through": "open", "level": 0.6}},
		"wind": {"from": "back right", "strength": 0.4, "gusts": 0.6, "every": 18}},
	"shore": {"sound": {"water": {"kind": "shore", "size": 0.6, "from": "back", "distance": 0.4}},
		"wind": {"from": "back", "strength": 0.3, "gusts": 0.4, "every": 25}},
	"petals_under_a_tree": {"sound": {"wind": {"through": "trees"}},
		"wind": {"from": "right", "strength": 0.45, "gusts": 0.8, "every": 12}},
	"field": {"sound": {"wind": {"through": "grass"}, "insects": {"kind": "cicadas", "strength": 0.5}},
		"wind": {"from": "left", "strength": 0.35, "gusts": 0.5, "every": 20}},
	"market_awning": {"sound": {"wind": {"through": "canvas"}},
		"wind": {"from": "front left", "strength": 0.6, "gusts": 0.9, "every": 10}},
	"storm_outside": {"sound": {"wind": {"through": "eaves", "strength": 0.8, "gusts": 0.9, "every": 9}, "rain": {"on": "window", "strength": 0.7}},
		"wind": {}},
	"hearth": {"sound": {"fire": {"size": 0.6, "from": "left", "distance": 0.3}, "rain": {"on": "roof", "strength": 0.3}}, "wind": {}},
	"campfire_night": {"sound": {"fire": {"size": 0.8, "from": "front", "distance": 0.2}, "insects": {"kind": "crickets", "strength": 0.6},
		"wind": {"through": "trees", "level": 0.4}}, "wind": {"from": "right", "strength": 0.2, "gusts": 0.4, "every": 30}},
	"rain_on_canvas": {"sound": {"rain": {"on": "canvas", "strength": 0.6}}, "wind": {}},
	"brook": {"sound": {"stream": {"size": 0.5, "from": "right", "distance": 0.2}, "wind": {"through": "trees", "level": 0.5}},
		"wind": {"from": "back", "strength": 0.25, "gusts": 0.4, "every": 25}},
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var secs := float(args[0]) if args.size() > 0 else 60.0
	var out_dir := args[1] if args.size() > 1 else ProjectSettings.globalize_path("res://").path_join("dist/soundscape")
	var dial := float(args[2]) if args.size() > 2 else 0.5
	DirAccess.make_dir_recursive_absolute(out_dir)
	# inside the project, the editor would import every file written here: tell it not to
	var ignore := FileAccess.open(out_dir.path_join(".gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	for name in PLACES:
		var p: Dictionary = PLACES[name]
		var table := {"sound": p["sound"]}
		if not (p["wind"] as Dictionary).is_empty():
			table["light"] = {"wind": p["wind"]}
		var made := Soundscape.of_table(table, 11)
		var sc := Soundscape.new(made["sound"], made["wind"], 11, SR, 0.0)
		sc.set_level(dial)
		var n := int(secs * SR)
		var t0 := Time.get_ticks_usec()
		var pcm := PackedVector2Array()
		var step := 2048
		var at := 0
		while at < n:
			pcm.append_array(sc.render(mini(step, n - at)))
			at += step
		var took := float(Time.get_ticks_usec() - t0) / 1e6
		# its loudness, every 0.25 s, against the wind's speed then
		var win := SR / 4
		var lv := PackedFloat32Array()
		var ws := PackedFloat32Array()
		var sum := 0.0
		var peak := 0.0
		for i in pcm.size():
			var v := pcm[i]
			sum += v.x * v.x + v.y * v.y
			peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
		for k in pcm.size() / win:
			var e := 0.0
			for i in range(k * win, (k + 1) * win):
				e += pcm[i].x * pcm[i].x + pcm[i].y * pcm[i].y
			lv.append(sqrt(e / float(win * 2)))
			ws.append(Winds.speed_at(made["wind"], (float(k) + 0.5) * 0.25) if not (made["wind"] as Dictionary).is_empty() else 0.0)
		var rms := sqrt(sum / float(pcm.size() * 2))
		print("%-22s %5.1f%% of real time   rms %6.1f dBFS   peak %6.1f dBFS   level~wind r=%.2f" % [name, took / secs * 100.0,
			linear_to_db(rms), linear_to_db(peak), _corr(lv, ws)])
		_wav(out_dir.path_join(name + ".wav"), pcm)
	print("written to " + out_dir)
	quit()


static func _corr(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var n := mini(a.size(), b.size())
	if n < 3:
		return 0.0
	var ma := 0.0
	var mb := 0.0
	for i in n:
		ma += a[i]
		mb += b[i]
	ma /= n
	mb /= n
	var sab := 0.0
	var saa := 0.0
	var sbb := 0.0
	for i in n:
		sab += (a[i] - ma) * (b[i] - mb)
		saa += (a[i] - ma) * (a[i] - ma)
		sbb += (b[i] - mb) * (b[i] - mb)
	return sab / sqrt(maxf(1e-12, saa * sbb))


static func _wav(path: String, frames: PackedVector2Array) -> void:
	var data := PackedByteArray()
	data.resize(frames.size() * 4)
	for i in frames.size():
		data.encode_s16(i * 4, int(clampf(frames[i].x, -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 4 + 2, int(clampf(frames[i].y, -1.0, 1.0) * 32767.0))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(2)
	f.store_32(SR)
	f.store_32(SR * 4)
	f.store_16(4)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
