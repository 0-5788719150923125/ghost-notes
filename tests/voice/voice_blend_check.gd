extends SceneTree

## voice_blend_check - a blend of readers written as one line ([VoiceBlend]), read here as the host reads it:
##
##   godot --headless --path . --script tests/voice/voice_blend_check.gd
##
## What it holds:
## - the lines hosts/voice/test_kokoro.py holds blend.py to (`BLEND_LINES`) read the same here: the method, an
##   accent, each reader's weight and part, an unknown method a mix, an unknown accent unsaid, a weight clamped;
## - a line is written back as it was read: a weight of 1 unsaid (and every weight, where the method weighs nothing),
##   a part only where the method gives parts;
## - said for a person: each reader by its pack's short name and its share, a part in Sound and delivery, the
##   readers alone when brief;
## - the methods, parts and accents here are blend.py's, each with a label and a blurb.
##
## THE CONTROLS: a line of one reader, one with no colon, and nothing are no blend, and write back as "".

var _fail := 0


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fail += 1
		print("  FAIL: ", what)
	else:
		print("  ok: ", what)


func _voices(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		out.append({"reader": r[0], "weight": float(r[1]), "part": r[2]})
	return out


func _initialize() -> void:
	# the same lines test_kokoro.py's BLEND_LINES holds blend.py to
	var lines := {
		"mix: af_heart 2, bf_emma 1": {"method": "mix", "accent": "",
			"voices": _voices([["af_heart", 2, "both"], ["bf_emma", 1, "both"]])},
		"split british: af_heart sound, bf_emma 0.5 delivery": {"method": "split", "accent": "british",
			"voices": _voices([["af_heart", 1, "sound"], ["bf_emma", 0.5, "delivery"]])},
		"Swirl welsh: af_heart 99, bf_emma -3, am_puck": {"method": "mix", "accent": "",
			"voices": _voices([["af_heart", 10, "both"], ["bf_emma", 0.1, "both"], ["am_puck", 1, "both"]])},
	}
	for line in lines:
		var got := VoiceBlend.parse(line)
		_ok(str(got) == str(lines[line]), "%s reads as the host reads it: %s" % [line, str(got)])
	_ok(VoiceBlend.parse("").is_empty(), "CONTROL: nothing is no blend")
	_ok((VoiceBlend.parse("mix: af_heart")["voices"] as Array).size() == 1, "one reader reads as one reader")
	_ok(VoiceBlend.parse("af_heart, bf_emma").is_empty(), "CONTROL: a line with no colon is no blend")

	# written back as read
	for line in ["mix: af_heart 2, bf_emma", "split british: af_heart sound, bf_emma 0.5 delivery",
			"spherical: af_heart, am_puck 3.5, bf_emma"]:
		var b := VoiceBlend.parse(line)
		var back := VoiceBlend.compose(String(b["method"]), String(b["accent"]), b["voices"])
		_ok(back == line, "written back as it was read: %s -> %s" % [line, back])
	var mixed := VoiceBlend.compose("mix", "", _voices([["af_heart", 1, "sound"], ["bf_emma", 1, "delivery"]]))
	_ok(mixed == "mix: af_heart, bf_emma", "a part is written only where the method gives parts: %s" % mixed)
	var most := VoiceBlend.compose("max", "", _voices([["af_heart", 2, "both"], ["bf_emma", 1, "both"]]))
	_ok(most == "max: af_heart, bf_emma", "a weight is unsaid where the method weighs nothing: %s" % most)
	_ok(VoiceBlend.line(most) == "Max: heart, emma", "...and said without shares: %s" % VoiceBlend.line(most))
	_ok(VoiceBlend.compose("mix", "", _voices([["af_heart", 1, "both"]])) == "", "CONTROL: one reader writes no blend")
	_ok(VoiceBlend.compose("mix", "", []) == "", "CONTROL: nobody writes no blend")
	_ok(VoiceBlend.readers("mix: af_heart 2, bf_emma") == PackedStringArray(["af_heart", "bf_emma"]),
		"its readers, in its order")

	# said for a person
	var said := VoiceBlend.line("mix: af_heart 2, bf_emma")
	_ok(said == "Mix: heart 67%, emma 33%", "a mix said with each reader's share: %s" % said)
	said = VoiceBlend.line("split british: af_heart sound, bf_emma 2 delivery")
	_ok(said == "Sound and delivery: heart sound, emma delivery 2 (British)", "a split said by parts: %s" % said)
	_ok(VoiceBlend.line("mix: af_heart, bf_emma, am_puck", true) == "heart + emma + puck", "brief: the readers alone")
	_ok(VoiceBlend.line("mix: af_heart") == "" and VoiceBlend.line("") == "", "CONTROL: no blend is said as nothing")

	# the host's words are these
	var host := FileAccess.get_file_as_string("res://hosts/voice/blend.py")
	for pair in [["METHODS", VoiceBlend.METHODS], ["PARTS", VoiceBlend.PARTS], ["ACCENTS", VoiceBlend.ACCENTS]]:
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

	print("voice_blend_check: ", "ALL OK" if _fail == 0 else "%d FAILED" % _fail)
	quit(1 if _fail else 0)
