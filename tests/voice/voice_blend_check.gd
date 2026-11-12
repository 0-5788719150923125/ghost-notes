extends SceneTree

## voice_blend_check - a blend of readers, and its shape, written as one line ([VoiceBlend]), read here as the host
## reads it:
##
##   godot --headless --path . --script tests/voice/voice_blend_check.gd
##
## What it holds:
## - the lines hosts/voice/test_kokoro.py holds blend.py to (`BLEND_LINES`, each found there) read the same here: the
##   method, an accent, each reader's weights (one, or points across a paragraph) and part, the lanes and the noise,
##   an unknown method a mix, an unknown accent, clause or number unsaid, a number clamped; one reader shaped is a voice;
## - a curve read across a paragraph as blend.py reads it (`CURVE_POINTS`, the same values), and shares from weights;
## - whether a line moves within a paragraph (a curve that moves, or noise that wanders), so a request says where its
##   sentence stands;
## - a line written back as it was read: a weight of 1 unsaid, every weight unsaid where all are equal, a curve that
##   never moves as one number, a part only where the method gives parts, a lane only off zero, noise only above none;
## - the Shapes: the last reader's share moved around the shares as they stand, the others giving way, never under 5
##   in a hundred; the lanes the shape's;
## - said for a person: each reader's share (from its first word's to its last's where it moves), a part in Sound
##   and delivery, the lanes and the noise; brief, the readers and what shapes them in a word;
## - the methods, parts, accents, lanes and noises here are blend.py's, each with a label and a blurb.
##
## THE CONTROLS: one reader shaped by nothing, a line with no colon, noise of nothing and nothing are no voice, and
## write back as "".

var _fail := 0


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fail += 1
		print("  FAIL: ", what)
	else:
		print("  ok: ", what)


func _read(method: String, accent: String, voices: Array, breath: Array, push: Array, noise: Dictionary) -> Dictionary:
	var vs: Array = []
	for v in voices:
		var w: Array = []
		for x in v[1]:
			w.append(float(x))
		vs.append({"reader": v[0], "weights": w, "part": v[2]})
	var b: Array = []
	for x in breath:
		b.append(float(x))
	var p: Array = []
	for x in push:
		p.append(float(x))
	return {"method": method, "accent": accent, "voices": vs, "breath": b, "push": p, "noise": noise}


func _initialize() -> void:
	var kept := FileAccess.get_file_as_string("res://hosts/voice/test_kokoro.py")
	# the same lines test_kokoro.py's BLEND_LINES holds blend.py to
	var lines := {
		"mix: af_heart 2, bf_emma 1": _read("mix", "", [["af_heart", [2], "both"], ["bf_emma", [1], "both"]],
			[0], [0], {}),
		"split british: af_heart sound, bf_emma 0.5 delivery": _read("split", "british",
			[["af_heart", [1], "sound"], ["bf_emma", [0.5], "delivery"]], [0], [0], {}),
		"Swirl welsh: af_heart 999, bf_emma -3, am_puck": _read("mix", "",
			[["af_heart", [100], "both"], ["bf_emma", [0], "both"], ["am_puck", [1], "both"]], [0], [0], {}),
		"max: am_santa 60/50/30, af_nicole 40/50/70; breath 0.2/0.6; noise wander 0.3 17": _read("max", "",
			[["am_santa", [60, 50, 30], "both"], ["af_nicole", [40, 50, 70], "both"]], [0.2, 0.6], [0],
			{"kind": "wander", "amount": 0.3, "seed": 17}),
		"mix: bf_emma; breath 0.7; push -2; noise fixed 0.5": _read("mix", "", [["bf_emma", [1], "both"]], [0.7], [-1],
			{"kind": "fixed", "amount": 0.5, "seed": 0}),
		"mix: af_heart, bf_emma; breath x/1; noise hiss 0.4; tremble 3": _read("mix", "",
			[["af_heart", [1], "both"], ["bf_emma", [1], "both"]], [0], [0], {}),
	}
	for line in lines:
		var got := VoiceBlend.parse(line)
		_ok(str(got) == str(lines[line]), "%s reads as the host reads it: %s" % [line, str(got)])
		_ok(kept.contains('"%s"' % line), "...and is one of test_kokoro.py's lines")
	for line in ["mix: af_heart", "af_heart, bf_emma", "mix: af_heart; noise fixed 0", ""]:
		_ok(VoiceBlend.parse(line).is_empty(), "CONTROL: '%s' is no voice" % line)

	# a curve across a paragraph, as blend.py's CURVE_POINTS
	var curves := [[[0.0, 1.0], {0.25: 0.25}], [[0.0, 1.0, 0.0], {0.25: 0.625, 0.5: 1.0, 0.75: 0.625}],
		[[60.0, 50.0, 30.0, 35.0, 30.0], {0.1: 56.48, 0.3: 46.0, 0.6: 31.76, 0.9: 32.48}],
		[[0.0, 0.0, 1.0, 1.0], {0.4: 0.104, 0.5: 0.5, 0.6: 0.896}], [[0.7], {0.4: 0.7}]]
	for c in curves:
		for u in (c[1] as Dictionary):
			var v := VoiceBlend.curve_at(c[0], float(u))
			_ok(absf(v - float(c[1][u])) < 1e-6, "%s at %s is %s, as blend.py reads it (%f)" % [str(c[0]), u, c[1][u], v])
	_ok(kept.contains("(60.0, 50.0, 30.0, 35.0, 30.0): {0.1: 56.48, 0.3: 46.0, 0.6: 31.76, 0.9: 32.48}"),
		"...the values test_kokoro.py holds blend.py to")
	var low := 1.0
	var high := 0.0
	for k in 101:
		var v := VoiceBlend.curve_at([0.0, 0.0, 1.0, 1.0], k / 100.0)
		low = minf(low, v)
		high = maxf(high, v)
	_ok(low >= 0.0 and high <= 1.0, "a curve never goes past its points")
	var s := VoiceBlend.shares_at([[60, 50], [40, 50]], 0.0)
	_ok(absf(s[0] - 0.6) < 1e-6 and absf(s[1] - 0.4) < 1e-6, "shares at a place add to one: %s" % s)
	s = VoiceBlend.shares_at([[0], [0]], 0.5)
	_ok(absf(s[0] - 0.5) < 1e-6, "every weight nothing: each counts once")

	# written back as read
	for line in ["mix: af_heart 2, bf_emma", "split british: af_heart sound, bf_emma 0.5 delivery",
			"spherical: af_heart, am_puck 3.5, bf_emma",
			"max: am_santa 60/50/30, af_nicole 40/50/70; breath 0.2/0.6; noise wander 0.3 17",
			"mix: bf_emma; breath 0.7; push -1; noise fixed 0.5"]:
		var b := VoiceBlend.parse(line)
		var back := VoiceBlend.compose(String(b["method"]), String(b["accent"]), b["voices"], b)
		_ok(back == line, "written back as it was read: %s -> %s" % [line, back])
	var two := [{"reader": "af_heart", "weights": [50, 50, 50, 50, 50], "part": "sound"},
		{"reader": "bf_emma", "weights": [50, 50, 50, 50, 50], "part": "delivery"}]
	var said := VoiceBlend.compose("mix", "", two)
	_ok(said == "mix: af_heart, bf_emma", "equal shares unsaid, and a part only where the method gives parts: %s" % said)
	said = VoiceBlend.compose("max", "", [{"reader": "af_heart", "weights": [60, 60, 60, 60, 60]},
		{"reader": "bf_emma", "weights": [40, 40, 40, 40, 40]}])
	_ok(said == "max: af_heart 60, bf_emma 40", "a share that never moves is one number - and Max weighs it: %s" % said)
	said = VoiceBlend.compose("mix", "", [{"reader": "bf_emma", "weight": 1.0}], {"breath": [0.7, 0.7, 0.7, 0.7, 0.7],
		"push": [0, 0, 0, 0, 0], "noise": {"kind": "wander", "amount": 0.0, "seed": 3}})
	_ok(said == "mix: bf_emma; breath 0.7", "one reader shaped is a line; a lane of nothing and noise of nothing unsaid: %s" % said)
	_ok(VoiceBlend.compose("mix", "", [{"reader": "af_heart", "weight": 1.0}]) == "", "CONTROL: one reader unshaped writes nothing")
	_ok(VoiceBlend.compose("mix", "", []) == "", "CONTROL: nobody writes nothing")
	_ok(VoiceBlend.readers("mix: af_heart 2, bf_emma") == PackedStringArray(["af_heart", "bf_emma"]),
		"its readers, in its order")
	_ok(VoiceBlend.wanders("mix: bf_emma; noise wander 0.2") and not VoiceBlend.wanders("mix: bf_emma; noise fixed 0.2"),
		"whether its noise wanders")
	_ok(VoiceBlend.moves("mix: af_heart 60/40, bf_emma") and VoiceBlend.moves("mix: bf_emma; breath 0/0.5")
		and VoiceBlend.moves("mix: bf_emma; noise wander 0.2"), "a curve that moves, or noise that wanders, moves within a paragraph")
	_ok(not VoiceBlend.moves("mix: af_heart 2, bf_emma") and not VoiceBlend.moves("mix: bf_emma; breath 0.5/0.5")
		and not VoiceBlend.moves("mix: bf_emma; noise fixed 0.2") and not VoiceBlend.moves(""),
		"CONTROL: one weight, a flat lane, fixed noise and nothing do not")

	# the Shapes
	var settle := VoiceBlend.reshaped("settle", [[1.0], [1.0]])
	var last: Array = settle["weights"][1]
	var first: Array = settle["weights"][0]
	_ok(absf(float(last[0]) - 0.38) < 1e-3 and absf(float(last[4]) - 0.65) < 1e-3 and absf(float(first[0]) - 0.62) < 1e-3,
		"Settle over an even pair: the last 38 to 65 in a hundred, the first giving way: %s / %s" % [first, last])
	_ok(str(settle["breath"]) == str(VoiceBlend.SHAPES["settle"]["breath"]), "...its lanes the shape's")
	var steady := VoiceBlend.reshaped("steady", [[80, 20], [20, 80]])
	_ok(absf(float(steady["weights"][0][0]) - 0.5) < 1e-3 and absf(float(steady["weights"][0][4]) - 0.5) < 1e-3,
		"Steady: a moving mix held at its mean")
	var edge := VoiceBlend.reshaped("settle", [[5], [95]])
	_ok(float(edge["weights"][1][4]) <= 0.95 + 1e-6 and float(edge["weights"][0][4]) >= 0.05 - 1e-6,
		"never under 5 in a hundred")
	_ok((VoiceBlend.reshaped("hush", [[1.0]])["weights"] as Array).size() == 1, "one reader keeps the whole")

	# said for a person
	said = VoiceBlend.line("mix: af_heart 2, bf_emma")
	_ok(said == "Mix: heart 67%, emma 33%", "a mix said with each reader's share: %s" % said)
	said = VoiceBlend.line("split british: af_heart sound, bf_emma 2 delivery")
	_ok(said == "Sound and delivery: heart sound, emma delivery (British)", "a split said by parts: %s" % said)
	said = VoiceBlend.line("max: am_santa 60/50/30, af_nicole 40/50/70; breath 0.2/0.6; noise wander 0.3 17")
	_ok(said == "Max: santa 60→30%, nicole 40→70% · breath +0.2 → +0.6 · noise: wander 0.3",
		"a moving blend said from a paragraph's first word to its last: %s" % said)
	said = VoiceBlend.line("mix: bf_emma; breath 0.7; push -1")
	_ok(said == "emma · breath +0.7 · push -1", "one reader shaped: %s" % said)
	_ok(VoiceBlend.line("mix: af_heart, bf_emma, am_puck", true) == "heart + emma + puck", "brief: the readers alone")
	said = VoiceBlend.line("mix: bf_emma; breath 0.7; push -0.5; noise fixed 0.2", true)
	_ok(said == "emma, breathy, soft, varied", "brief: and what shapes them in a word: %s" % said)
	_ok(VoiceBlend.line("mix: af_heart") == "" and VoiceBlend.line("") == "", "CONTROL: no voice is said as nothing")

	# the host's words are these
	var host := FileAccess.get_file_as_string("res://hosts/voice/blend.py")
	for pair in [["METHODS", VoiceBlend.METHODS], ["PARTS", VoiceBlend.PARTS], ["ACCENTS", VoiceBlend.ACCENTS],
			["LANES", VoiceBlend.LANES], ["NOISES", VoiceBlend.NOISES]]:
		var re := RegEx.create_from_string("(?m)^%s = \\(([^)]*)\\)" % pair[0])
		var m := re.search(host)
		var theirs := PackedStringArray()
		if m != null:
			for w in m.get_string(1).split(","):
				if not w.strip_edges().is_empty():
					theirs.append(w.strip_edges().trim_prefix("\"").trim_suffix("\""))
		var ours := PackedStringArray()
		for k in (pair[1] as Dictionary):
			if not String(k).is_empty():
				ours.append(String(k))
		_ok(not theirs.is_empty() and theirs == ours, "%s here are blend.py's: %s / %s" % [pair[0], ours, theirs])
		for k in (pair[1] as Dictionary):
			_ok(not Registry.label(pair[1], k).is_empty() and not Registry.blurb(pair[1], k).is_empty(),
				"%s row '%s' has a label and a blurb" % [pair[0], k])
	for k in VoiceBlend.SHAPES:
		var row: Dictionary = VoiceBlend.SHAPES[k]
		_ok(not Registry.label(VoiceBlend.SHAPES, k).is_empty() and not Registry.blurb(VoiceBlend.SHAPES, k).is_empty()
			and (row["mix"] as Array).size() == VoiceBlend.POINTS and (row["breath"] as Array).size() == VoiceBlend.POINTS
			and (row["push"] as Array).size() == VoiceBlend.POINTS, "Shape '%s' has a label, a blurb and its points" % k)
	_ok(host.contains("WEIGHT_MAX = %d.0" % int(VoiceBlend.WEIGHT_MAX)) and host.contains("POINTS_MOST = %d" % VoiceBlend.POINTS_MOST),
		"a weight's most and a curve's most points are blend.py's")

	print("voice_blend_check: ", "ALL OK" if _fail == 0 else "%d FAILED" % _fail)
	quit(1 if _fail else 0)
