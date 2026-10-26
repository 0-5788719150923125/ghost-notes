extends SceneTree

## WHO A SPEAKER NUMBER IS: the model config's reader ids joined to LibriTTS-P's annotations.
##
##   godot --headless --path . --script tests/voice/voice_readers_check.gd
##
## Needs en_US-libritts-high installed (the voice host downloads it on first use); without it
## the voice half is skipped, said so, and only the data file is checked.

var _fail := 0


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fail += 1
		print("  FAIL: ", what)
	else:
		print("  ok: ", what)


func _initialize() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(VoiceReaders.DATA))
	_ok(data is Dictionary and ((data as Dictionary)["readers"] as Dictionary).size() > 2000,
		"the LibriTTS-P data file loads")
	_ok(VoiceReaders.all("no-such-voice").is_empty() and VoiceReaders.describe("no-such-voice", 0).is_empty(),
		"a voice with no config has no descriptions, and nothing breaks")
	# READERS THE HOST SAYS (kokoro's voicepacks): described from what was offered, in speaker order
	VoiceReaders.offer("kokoro-check", [{"reader": "af_heart", "g": "F", "d": "heart, American, grade A"},
		{"reader": "am_puck", "g": "M", "d": "puck, American, grade C+"}], "Grades: the host's own.")
	var puck := VoiceReaders.describe("kokoro-check", 1)
	_ok(String(puck.get("reader", "")) == "am_puck" and String(puck.get("g", "")) == "M",
		"an offered speaker 1 is the second reader offered: %s" % str(puck))
	_ok(VoiceReaders.describe("kokoro-check", 2).is_empty(), "past the offered readers is nobody")
	var offered := VoiceReaders.all("kokoro-check")
	_ok(offered.size() == 2 and int((offered[1] as Dictionary)["i"]) == 1, "all() numbers the offered readers")
	_ok(VoiceReaders.about_of("kokoro-check") == "Grades: the host's own.", "the host says who described them")
	_ok(VoiceReaders.about_of("no-such-voice") == VoiceReaders.LIBRITTS_ABOUT,
		"a voice nothing was offered for keeps LibriTTS-P's credit")
	var vid := "en_US-libritts-high"
	if not FileAccess.file_exists(Deps.data_dir().path_join("voices/piper/%s.onnx.json" % vid)):
		print("  (skipped: %s is not installed)" % vid)
	else:
		var all := VoiceReaders.all(vid)
		_ok(all.size() == 904, "every speaker of %s is listed (%d)" % [vid, all.size()])
		var ten := VoiceReaders.describe(vid, 10)
		_ok(String(ten.get("reader", "")) == "3615" and String(ten.get("g", "")) == "F",
			"speaker 10 is reader 3615, female: %s" % str(ten))
		var known := 0
		for r in all:
			if not String((r as Dictionary)["g"]).is_empty():
				known += 1
		_ok(known > 880, "nearly every speaker has a gender (%d of %d)" % [known, all.size()])
		_ok(VoiceReaders.line(ten).begins_with("♀ female"), "the line leads with the gender: %s" % VoiceReaders.line(ten))
	print("voice_readers_check: %s" % ("PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	quit(1 if _fail > 0 else 0)
