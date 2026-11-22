extends SceneTree

## formant_singing_check - that Ghost Notes' own voice sings a phrase as the host sings one ([FormantSinging], [VoiceHost],
## [Singers]).
##
##   godot --headless --path . --script tests/voice/formant_singing_check.gd
##
## Holds:
## - a word's phones split into syllables at their vowels, a run between two going to the second as far as English lets a
##   syllable begin ("never": N EH | V ER; "extra": EH K | S T R AH) - the control: NG never begins one;
## - THE VOWEL IS ON THE BEAT: each syllable's vowel starts on its note, its onset sung before it;
## - every note is heard at its own pitch, a held one through its length (the control: the same phrase written a fourth
##   higher is heard a fourth higher);
## - Tune 1 holds every note flat, and Tune 0 with vibrato sways a held note (the control: the two curves differ only
##   there);
## - the reply is the host's: a WAV at its rate, `start` before the first note by the first onset and the lead, a vowel
##   onset a syllable;
## - the host sings it in-process: a sung request for the formant voice is answered on `synthesized` with no host running,
##   and a phrase with no words is a `failed("sing")`;
## - a kept formant voice sings: [method Singers.sings] says so (the control: a Piper voice does not), its summary carries the
##   voice and a center over the pitch it speaks at, and what the host is asked carries the voice and its Tone's size.
##
## Its takes go to a folder of its own under user://, removed at the end.

const DIR := "user://formant_singing_check"
const MIDI := [55, 59, 62]

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_check_syllables()
	_check_laid()
	_check_pitch()
	_check_tune()
	_check_singers()
	await _check_host()
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))
	DirAccess.remove_absolute(DIR)
	print("formant_singing_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


## Three words, a note each; the last held.
func _phrase(lift := 0) -> Array:
	var said := ["Sing", "a", "song"]
	var lens := [0.45, 0.3, 1.4]
	var out: Array = []
	var at := 0.0
	for i in said.size():
		out.append({"text": said[i], "notes": [{"t": at, "len": float(lens[i]), "midi": float(int(MIDI[i]) + lift)}]})
		at += float(lens[i]) + 0.05
	return out


func _check_syllables() -> void:
	var never := FormantSinging.syllables(FormantSinging.phones_of({"text": "never"}))
	var extra := FormantSinging.syllables(["EH", "K", "S", "T", "R", "AH"])
	var sing_it := FormantSinging.syllables(["S", "IH", "NG", "IH", "T"])
	_ok(never.size() == 2 and (never[1]["on"] as Array) == ["V"] and (extra[0]["co"] as Array) == ["K"]
		and (extra[1]["on"] as Array) == ["S", "T", "R"] and (sing_it[0]["co"] as Array) == ["NG"] and (sing_it[1]["on"] as Array).is_empty(),
		"syllables split where English lets one begin (%s, %s); the control: NG never begins one (%s)" % [str(never), str(extra), str(sing_it)])


func _check_laid() -> void:
	var spec := FormantVoice.spec_of({})
	spec.song = 1.0
	var words := _phrase()
	var laid := FormantSinging.plan(words, spec, {"tune": 1.0})
	var sung: Array = laid["sung"]
	var on_beat := sung.size() == words.size()
	for i in mini(sung.size(), words.size()):
		on_beat = on_beat and absf(float(sung[i]["t"]) - float(words[i]["notes"][0]["t"])) < 0.002
	var first_onset := 0.0
	for p in ["S"]:
		first_onset += float((Phonemes.TABLE.get(p, {}) as Dictionary).get("dur", 80.0)) * 0.001 / spec.rate
	_ok(on_beat and is_equal_approx(snappedf(float(laid["start"]), 0.001), snappedf(-first_onset - FormantSinging.LEAD, 0.001)),
		"each vowel starts on its note, the take starting before the first by its onset and the lead (%s, start %.3f)" % [str(sung), float(laid["start"])])


## The pitch heard at [param t] seconds of [param pcm] (at [param sr]): the first strong peak of the normalized
## autocorrelation, in midi.
func _heard(pcm: PackedFloat32Array, sr: float, t: float) -> float:
	var c := int(t * sr)
	var n := 1024
	if c < 0 or c + n + 400 >= pcm.size():
		return -1.0
	var mean := 0.0
	for k in n:
		mean += pcm[c + k]
	mean /= float(n)
	var ac := PackedFloat32Array()
	ac.resize(int(sr / 60.0) + 1)
	var zero := 0.0
	for k in n:
		zero += (pcm[c + k] - mean) * (pcm[c + k] - mean)
	var lo := int(sr / 500.0)
	var top := 0.0
	for lag in range(lo, ac.size()):
		var acc := 0.0
		for k in n:
			acc += (pcm[c + k] - mean) * (pcm[c + k + lag] - mean)
		ac[lag] = acc / maxf(zero, 1e-9)
		top = maxf(top, ac[lag])
	var lag := lo
	while lag < ac.size() and ac[lag] < 0.85 * top:
		lag += 1
	while lag + 1 < ac.size() and ac[lag + 1] > ac[lag]:
		lag += 1
	var hz := sr / float(lag)
	return 69.0 + 12.0 * log(hz / 440.0) / log(2.0)


func _sung(words: Array, name: String, style := {"tune": 1.0}) -> Dictionary:
	var got := FormantSinging.sing(words, {}, style, ProjectSettings.globalize_path(DIR.path_join(name)))
	if not bool(got.get("ok", false)):
		return got
	var f := FileAccess.open(String(got["wav"]), FileAccess.READ)
	var bytes := f.get_buffer(f.get_length())
	var pcm := PackedFloat32Array()
	pcm.resize((bytes.size() - 44) / 2)
	for i in pcm.size():
		pcm[i] = float(bytes.decode_s16(44 + i * 2)) / 32767.0
	got["pcm"] = pcm
	return got


func _check_pitch() -> void:
	var low := _sung(_phrase(), "low.wav")
	var high := _sung(_phrase(5), "high.wav")
	if not low.has("pcm") or not high.has("pcm"):
		_ok(false, "the phrase was not sung (%s, %s)" % [str(low.get("error", "")), str(high.get("error", ""))])
		return
	var sr := float(int(low["sample_rate"]))
	var words := _phrase()
	var on_pitch := true
	var said := PackedStringArray()
	for i in words.size():
		var nt: Dictionary = words[i]["notes"][0]
		for u in ([0.6] if i < 2 else [0.3, 0.6, 0.85]):
			var t := float(nt["t"]) + float(nt["len"]) * float(u)
			var a := _heard(low["pcm"], sr, t - float(low["start"]))
			var b := _heard(high["pcm"], sr, t - float(high["start"]))
			on_pitch = on_pitch and absf(a - float(nt["midi"])) < 0.5 and absf(b - a - 5.0) < 0.5
			said.append("%.1f/%.1f of %d" % [a, b, int(nt["midi"])])
	_ok(on_pitch and int(low["sample_rate"]) == FormantVoice.RATE and float(low["start"]) < 0.0 and (low["sung"] as Array).size() == 3,
		"every note is heard at its pitch, a held one through its length, and the phrase a fourth higher a fourth higher (%s)" % ", ".join(said))


func _check_tune() -> void:
	var spec := FormantVoice.spec_of({})
	var flat: PackedFloat32Array = FormantSinging.plan(_phrase(), spec, {"tune": 1.0})["curve"]
	var sway: PackedFloat32Array = FormantSinging.plan(_phrase(), spec, {"tune": 0.0, "vibrato": 0.3, "vibrato_rate": 5.5, "drift": 0.0})["curve"]
	var held: Dictionary = _phrase()[2]["notes"][0]
	var start := float(FormantSinging.plan(_phrase(), spec, {"tune": 1.0})["start"])
	var i0 := int((float(held["t"]) + 0.6 - start) / Voice.BEND_STEP)
	var i1 := int((float(held["t"]) + float(held["len"]) - 0.1 - start) / Voice.BEND_STEP)
	var flat_dev := 0.0
	var sway_dev := 0.0
	for i in range(i0, i1):
		flat_dev = maxf(flat_dev, absf(flat[i] - float(held["midi"])))
		sway_dev = maxf(sway_dev, absf(sway[i] - float(held["midi"])))
	_ok(flat_dev < 0.01 and sway_dev > 0.2 and sway_dev < 0.45,
		"Tune 1 holds the note flat (%.3f), Tune 0 sways it by its vibrato (%.3f semitones)" % [flat_dev, sway_dev])


func _check_singers() -> void:
	var kept := {"voice": FormantVoice.ID, "formant": FormantVoice.kept([7, 11], {"pitch": -0.5}, {}, {}, []), "tone": 0,
		"vibrato": 0.2, "vibrato_rate": 5.0, "drift": 0.02}
	var s := Singers.summary(kept)
	var speaks := 69.0 + 12.0 * log(FormantVoice.spec_of(FormantVoice.voice_of(kept["formant"])).f0_base * 1.06 / 440.0) / log(2.0)
	var asked := SongBake.params_of({"voice": FormantVoice.ID, "formant": kept["formant"], "semis": -2.0})
	_ok(Singers.sings(kept) and not Singers.sings({"voice": "en_US-libritts-high"}) and (s["formant"] as Dictionary).has("lineage")
		and absf(float(s["center"]) - speaks - Singers.ABOVE_SPEAKING) <= 0.5 and asked.has("formant") and is_equal_approx(float(asked["semis"]), -2.0),
		"a kept formant voice sings, sitting over the pitch it speaks at, and is asked with its voice and size (center %d over %.1f); the control: a Piper voice does not sing"
			% [int(s["center"]), speaks])


func _check_host() -> void:
	var host := VoiceHost.new()
	root.add_child(host)
	var answers := {}
	var failures: Array = []
	host.synthesized.connect(func(id: int, result: Dictionary) -> void: answers[id] = result)
	host.failed.connect(func(stage: String, why: String) -> void: failures.append([stage, why]))
	var id := host.sing(_phrase(), FormantVoice.ID, DIR.path_join("hosted.wav"), {}, {"tune": 0.5})
	var bad := host.sing([], FormantVoice.ID, DIR.path_join("none.wav"), {}, {})
	for _i in 2000:
		if answers.has(id) and not failures.is_empty():
			break
		await process_frame
	var got: Dictionary = answers.get(id, {})
	_ok(bool(got.get("ok", false)) and FileAccess.file_exists(String(got.get("wav", ""))) and got.has("start") and got.has("duration")
		and not answers.has(bad) and failures.size() == 1 and String(failures[0][0]) == "sing",
		"a sung request is answered on `synthesized` with no host running, a phrase with no words a failed sing (%s, %s)" % [str(got.keys()), str(failures)])
	host.queue_free()
	await process_frame


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1
