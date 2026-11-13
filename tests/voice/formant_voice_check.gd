extends SceneTree

## formant_voice_check - that Ghost Notes' own voice answers a reading as the host answers for a neural one
## ([FormantVoice], [VoiceHost]).
##
##   godot --headless --path . --script tests/voice/formant_voice_check.gd
##
## Holds:
## - a request's tokens come back as a WAV at the host's rate, every token with a span in order inside the take, and
##   a rest after it no earlier than its end;
## - a word the tokens and the synthesizer disagree on goes without a span and the rest still align (the control: the
##   same request with one token missing loses that token's span alone);
## - the tab's rows reach the voice: a faster Pace reads shorter, the same request twice reads the same (the control);
## - every voice reads at the neural voices' level (the host's TARGET, measured the host's way): two whose own levels
##   lie more than 6 dB apart (the control: leveled by nothing, they would read that far apart) both come out of a
##   request within 1 dB of it;
## - a voice kept on a row comes back as the synthesizer reads it, its bank whole;
## - the host makes it in-process: a request for it is answered on `synthesized` with no host running, a request
##   cancelled while it waits is never answered, and a listing of the host's voices carries its row.
##
## Its takes go to a folder of its own under user://, removed at the end.

const DIR := "user://formant_voice_check"
const TEXT := ["The", "river", "spoke", "softly", "to", "the", "stones."]

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_check_say()
	_check_tuned()
	_check_level()
	_check_kept()
	await _check_host()
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	print("formant_voice_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILURE(S)" % _fails))
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1


## A sentence as the reading hands it: each word its spelling, its spoken form and its mark.
func _tokens(words: Array) -> Array:
	var out: Array = []
	for w in words:
		var s := String(w)
		var punct := s.right(1) if s.right(1) in [".", ",", "?", "!"] else ""
		var bare := s.trim_suffix(punct)
		out.append({"text": bare.to_lower(), "cased": bare, "punct": punct})
	return out


func _out(name: String) -> String:
	return ProjectSettings.globalize_path(DIR.path_join(name + ".wav"))


## The rate a WAV declares (canonical header, byte 24).
func _rate(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 44:
		return 0
	f.seek(24)
	var r := f.get_32()
	f.close()
	return r


func _check_say() -> void:
	print("-- a request's tokens in, a take and every token's span out")
	var got := FormantVoice.say(_tokens(TEXT), {}, {}, _out("say"))
	_ok(bool(got.get("ok", false)) and FileAccess.file_exists(String(got.get("wav", ""))), "the take is written (%s)" % got.get("error", "ok"))
	_ok(_rate(String(got.get("wav", ""))) == FormantVoice.RATE and int(got.get("sample_rate", 0)) == FormantVoice.RATE,
		"at the host's rate (%d)" % _rate(String(got.get("wav", ""))))
	var dur := float(got.get("duration", 0.0))
	var spans: Array = got.get("tokens", [])
	var indices: Array = spans.map(func(s: Dictionary) -> int: return int(s["index"]))
	_ok(indices == range(TEXT.size()), "every token has a span, in order (%s)" % str(indices))
	var inside := spans.all(func(s: Dictionary) -> bool:
		return float(s["t0"]) < float(s["t1"]) and float(s["t1"]) <= dur + 0.01 and float(s["rest"]) >= float(s["t1"]))
	var ordered := true
	for i in range(1, spans.size()):
		ordered = ordered and float(spans[i]["t0"]) >= float(spans[i - 1]["t1"]) - 0.002
	_ok(inside and ordered, "each span inside the %.2f s take, after the one before, its rest no earlier than its end" % dur)
	_ok((got.get("phones", []) as Array).size() > TEXT.size(), "its sounds come with it, each on its token")
	var short := _tokens(TEXT)
	short.remove_at(3)                # "softly" is said, but no token asks for it
	var less := FormantVoice.word_index(short, FormantVoice.text_of(_tokens(TEXT)))
	_ok(less.size() == TEXT.size() - 1 and not less.values().has(TEXT.size() - 1),
		"control: a word no token asks for goes without a span, and the rest align (%d of %d)" % [less.size(), TEXT.size()])


func _check_tuned() -> void:
	print("-- the tab's rows reach the voice")
	var tokens := _tokens(TEXT)
	var a := FormantVoice.say(tokens, {}, {"length_scale": 1.0, "play_ratio": 1.0}, _out("pace1"))
	var b := FormantVoice.say(tokens, {}, {"length_scale": 1.0, "play_ratio": 1.0}, _out("pace1b"))
	var c := FormantVoice.say(tokens, {}, {"length_scale": 1.0 / 1.5, "play_ratio": 1.0}, _out("pace15"))
	_ok(is_equal_approx(float(a["duration"]), float(b["duration"])), "control: the same request reads the same (%.3f, %.3f)"
		% [float(a["duration"]), float(b["duration"])])
	_ok(float(c["duration"]) < 0.85 * float(a["duration"]), "a Pace of 1.5 reads shorter (%.2f s against %.2f s)"
		% [float(c["duration"]), float(a["duration"])])
	var spec := FormantVoice.tuned(FormantVoice.spec_of({}), {"play_ratio": 2.0, "length_scale": 2.0, "pause_scale": 0.5})
	var plain := FormantVoice.spec_of({})
	_ok(is_equal_approx(spec.f0_base, plain.f0_base * 2.0) and is_equal_approx(spec.rate, plain.rate)
		and is_equal_approx(spec.pause_stop, plain.pause_stop * 0.5),
		"a Tone's pitch moves the pitch alone, and the Pause the rests")


func _check_level() -> void:
	print("-- every voice at one level")
	var words: Array = Array(FormantVoice.LEVEL_TEXT.split(" "))
	var raw: Array = []
	var out: Array = []
	for seed_value in [901, 903]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var voice := FormantVoice.kept([seed_value], Voice.Spec.sample(rng).traits, {}, {}, [])
		raw.append(FormantVoice.speaking_level(Voice.render(FormantVoice.LEVEL_TEXT,
			FormantVoice.spec_of(FormantVoice.voice_of(voice))).pcm, Voice.SR))
		var got := FormantVoice.say(_tokens(words), voice, {}, _out("level_%d" % seed_value))
		out.append(FormantVoice.speaking_level(Splice.decode_wav(String(got["wav"])), FormantVoice.RATE))
	var db := func(x: float) -> float: return 20.0 * log(x / FormantVoice.TARGET) / log(10.0)
	_ok(absf(float(db.call(raw[0])) - float(db.call(raw[1]))) > 6.0,
		"control: the two voices' own levels lie apart (%+.1f dB, %+.1f dB)" % [db.call(raw[0]), db.call(raw[1])])
	_ok(absf(float(db.call(out[0]))) < 1.0 and absf(float(db.call(out[1]))) < 1.0,
		"...and both read at the neural voices' level (%+.1f dB, %+.1f dB)" % [db.call(out[0]), db.call(out[1])])


func _check_kept() -> void:
	print("-- a voice kept on a row")
	var bank := [[5.0, 0.25, 1.0], [7.0, 0.5, -0.3]]
	var kept := FormantVoice.kept([12, 345678], {"pitch": 0.5}, {"heat": 1.2}, {"prox": 0.3, "freq": 440.0}, bank)
	_ok((kept["bank"] as Array).size() == 6, "its bank is one flat list on the row")
	var read := FormantVoice.voice_of(MiniYaml.parse(MiniYaml.emit({"formant": kept}))["data"]["formant"])
	_ok(read["lineage"] == [12, 345678] and read["bank"] == bank and is_equal_approx(float(read["traits"]["pitch"]), 0.5),
		"...and comes back through the note whole (%s)" % str(read))
	var spec := FormantVoice.spec_of(read)
	_ok(spec.reading == [12, 345678] and spec.sustain_bank == bank and is_equal_approx(float(spec.adrenochrome["heat"]), 1.2),
		"the synthesizer reads it as kept")
	_ok(FormantVoice.voice_of({}).is_empty() and FormantVoice.spec_of({}).reading == [1],
		"control: a row with no voice is the default speaker")


func _check_host() -> void:
	print("-- the host makes it in-process")
	var host := VoiceHost.new()
	root.add_child(host)
	var answers := {}
	host.synthesized.connect(func(id: int, result: Dictionary) -> void: answers[id] = result)
	var first := host.request("", FormantVoice.ID, DIR.path_join("host_a.wav"), {"tokens": _tokens(TEXT)})
	var dropped := host.request("", FormantVoice.ID, DIR.path_join("host_b.wav"), {"tokens": _tokens(TEXT)})
	var last := host.request("", FormantVoice.ID, DIR.path_join("host_c.wav"), {"tokens": _tokens(["Hello."])})
	host.cancel([dropped])
	for _i in 600:
		if answers.has(last):
			break
		await process_frame
	_ok(answers.has(first) and answers.has(last) and FileAccess.file_exists(String((answers.get(last, {}) as Dictionary).get("wav", ""))),
		"two requests answered on `synthesized`, with no host running (%s)" % str(answers.keys()))
	_ok(not answers.has(dropped), "control: one cancelled while it waited is never answered")
	var listed := []
	host.synthesized.connect(func(_id: int, result: Dictionary) -> void:
		if result.has("voices"):
			listed.append_array(result["voices"]))
	host._handle(JSON.stringify({"id": 99, "ok": true, "voices": [{"id": "en_US-libritts-high"}]}))
	_ok(listed.any(func(v: Dictionary) -> bool: return String(v.get("id", "")) == FormantVoice.ID)
		and listed.any(func(v: Dictionary) -> bool: return String(v.get("id", "")) == "en_US-libritts-high"),
		"a listing of the host's voices carries the formant row beside them (%d listed)" % listed.size())
	host.queue_free()
	await process_frame
