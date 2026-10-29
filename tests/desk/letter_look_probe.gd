extends Node

## NOT a gate. Drives a real letter-medium session ([LetterMedium]) over a letter with a SYNTHETIC voice
## ([method DeskScript.rehearsal] over [method LetterScript.parse]: every spoken word at a steady pace,
## and the rests the letter asks the voice for) - and writes PNGs to look at.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/desk/letter_look_probe.gd 400 \
##       --out <dir>/l --letter <a letter .md> [--svgs <key -> svg .json>] [--ink <typeset answer .json>] \
##       [--picture <png>] [--seed N] [--hand kalam] [--things mug,dog_tag] [--mood lamplight] \
##       --times 3,8,20 [--every S] [--page 1] [--words W]
##
## `--svgs` and `--ink` are what the Letter card would hand it (a sketch's drawing by its key, and
## hosts/math/typeset.py's answer for them); `--picture` stands in for every picture the letter shows.
## `--every S` photographs every S seconds to the end instead of `--times`; `--page 1` also writes the
## flat pad texture beside each frame. `--words W` reads at W seconds a word (0.32 by default). `--things` and
## `--mood` are what the card chose for the desk ([method DeskLook.picks_of]; none: the seed's).
## It asserts only that a frame is not uniform.

const W := 1280
const H := 720
const DT := 1.0 / 30.0
const SENTENCE := 0.35

var _out := "user://letter"
var _letter := ""
var _svgs := ""
var _ink := ""
var _picture := ""
var _seed := 7
var _hand := LetterHand.DEFAULT
var _times: Array = [3.0, 10.0]
var _every := 0.0
var _page := false
var _word := 0.32
var _flat := 0
var _things: Variant = null
var _mood := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			break
		match args[i]:
			"--out": _out = args[i + 1]
			"--letter": _letter = args[i + 1]
			"--svgs": _svgs = args[i + 1]
			"--ink": _ink = args[i + 1]
			"--picture": _picture = args[i + 1]
			"--seed": _seed = int(args[i + 1])
			"--hand": _hand = args[i + 1]
			"--every": _every = float(args[i + 1])
			"--page": _page = args[i + 1] == "1"
			"--words": _word = float(args[i + 1])
			"--things": _things = Array(String(args[i + 1]).split(",", false))
			"--mood": _mood = args[i + 1]
			"--times":
				_times = []
				for s in String(args[i + 1]).split(","):
					_times.append(float(s))
	var source := FileAccess.get_file_as_string(_letter)
	if source.is_empty():
		print("letter_look_probe: no letter at '%s'" % _letter)
		get_tree().quit(2)
		return
	var svgs: Variant = JSON.parse_string(FileAccess.get_file_as_string(_svgs)) if not _svgs.is_empty() else {}
	var ink: Variant = JSON.parse_string(FileAccess.get_file_as_string(_ink)) if not _ink.is_empty() else {}
	var pictures := {}
	if not _picture.is_empty():
		for s in LetterScript.parse(source, _seed)["spans"]:
			if String((s as Dictionary)["kind"]) == "image":
				pictures[String(s["key"])] = _picture
	var letter := {"seed": _seed, "hand": _hand, "svgs": svgs if svgs is Dictionary else {},
		"ink": ink if ink is Dictionary else {}, "pictures": pictures}
	if _things is Array:
		letter["things"] = _things
	if not _mood.is_empty():
		letter["mood"] = _mood
	var records := LetterScript.records_of(letter["ink"])
	var fonts: Dictionary = (letter["ink"] as Dictionary).get("fonts", {})
	var parsed := LetterScript.parse(source, _seed, letter["svgs"], LetterScript.lengths_of(records, _seed, fonts), records,
		_hand)
	var words := _rehearse(parsed, _word, SENTENCE, 1.0)
	var stage := SubViewport.new()
	stage.size = Vector2i(W, H)
	stage.own_world_3d = true
	stage.transparent_bg = false
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	Director.detach()
	var medium: Medium = Medium.make("letter")
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	subs.words = words
	subs.document = {"source": source, "letter": letter, "title": _field(source, "title"),
		"author": _field(source, "author")}
	add_child(subs)
	if medium.bind_captions(subs):
		subs.overlay_hidden = true
	var end := float((words.back() as Dictionary)["t1"]) + 8.0
	# WHERE THINGS HAPPEN, for choosing `--times`: each action but a line, and each span, at its first word
	for a in parsed["actions"]:
		var k := String((a as Dictionary)["kind"])
		if k != "pad-text" or bool(a.get("turn", false)):
			print("letter_look_probe: %-8s at %7.1fs  %s" % [k + ("+turn" if bool(a.get("turn", false)) else ""),
				_at(words, int(a.get("after", 0))), String(a.get("text", a.get("target", ""))).substr(0, 50)])
	for s in parsed["spans"]:
		print("letter_look_probe: span %-8s %7.1fs to %7.1fs" % [String((s as Dictionary)["kind"]),
			_at(words, int(s["from"])), _at(words, int(s["to"]) - 1)])
	print("letter_look_probe: %d synthetic words, %d pen actions, %d spans, %.0fs" % [words.size(),
		(parsed["actions"] as Array).size(), (parsed["spans"] as Array).size(), end])
	if _every > 0.0:
		_times = []
		var tt := _every
		while tt < end:
			_times.append(tt)
			tt += _every
	_times.sort()
	var t := 0.0
	Spectrum.virtual_clock = 0.0
	for want in _times:
		while t < float(want):
			t += DT
			Spectrum.virtual_clock = t
			Spectrum.current.time = t
			medium.advance(Spectrum.current, DT, 1.0)
			# the desk is a function of time and its camera's springs step on their own: only the last
			# seconds before a photograph need rendering
			if float(want) - t < 1.5 or int(round(t / DT)) % 300 == 0:
				await get_tree().process_frame
		await get_tree().process_frame
		var img := stage.get_texture().get_image()
		var path := "%s_t%06.1f.png" % [_out, float(want)]
		img.save_png(path)
		if _page:
			(medium as DeskMedium)._vp.get_texture().get_image().save_png("%s_t%06.1f_page.png" % [_out, float(want)])
		var st := _spread(img)
		if st < 0.02:
			_flat += 1
		var desk := medium as DeskMedium
		# what is being said then, against what is being written
		var saying := ""
		for w in words:
			if float((w as Dictionary)["t0"]) <= desk._now and float(w["t1"]) >= desk._now - 0.3:
				saying = String(w["text"])
		var writing := ""
		for i in desk._actions.size():
			var a: Dictionary = desk._actions[i]
			if float(desk._plan[i]["start"]) <= desk._now and float(desk._plan[i]["end"]) > desk._now:
				writing = String(a.get("text", a["kind"])).substr(0, 40)
		print("letter_look_probe: t=%.1f (spread %.3f) %s - the desk at %.2f, the pen at %s - saying \"%s\", writing \"%s\"" % [want, st,
			path, desk._now, desk.pen_at()["p"], saying, writing])
	print("letter_look_probe: done, %d flat" % _flat)
	Spectrum.virtual_clock = -1.0
	Director.hold(false)
	Director.detach()
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame
	get_tree().quit(1 if _flat > 0 else 0)


## [method DeskScript.rehearsal], and a hesitation's rest too (a timed one its seconds, a bare one
## [constant HESITATE]): a letter's still is held over one, and a rehearsal that skipped it held it over
## nothing.
const HESITATE := 1.5


static func _rehearse(parsed: Dictionary, word: float, pause: float, lead: float) -> Array:
	var spoken: PackedStringArray = parsed["spoken"]
	var token := RegEx.create_from_string("<!--\\s*action-hold\\s*:\\s*([0-9.]+)\\s*-->|<!--\\s*hesitation\\s*(?::\\s*([0-9.]+))?\\s*-->|<!--.*?-->|\\S+")
	var out: Array = []
	var t := lead
	for chunk in String(parsed["speakable"]).split("\n\n"):
		var words := false
		for m in token.search_all(String(chunk)):
			if not m.get_string(1).is_empty():
				t += float(m.get_string(1))
			elif m.get_string().contains("hesitation"):
				t += float(m.get_string(2)) if not m.get_string(2).is_empty() else HESITATE
			elif not m.get_string().begins_with("<!--") and not TabletScript.norm(m.get_string()).is_empty():
				if out.size() < spoken.size():
					out.append({"text": spoken[out.size()], "t0": t, "t1": t + word * 0.9, "sentence": 0})
				t += word
				words = true
		if words:
			t += pause
	return out


## When spoken word [param i] of [param words] begins (the last word's end past it).
static func _at(words: Array, i: int) -> float:
	if i < words.size():
		return float((words[maxi(i, 0)] as Dictionary)["t0"])
	return float((words.back() as Dictionary)["t1"])


## A top-level frontmatter field of [param src].
static func _field(src: String, key: String) -> String:
	var m := RegEx.create_from_string("(?m)^%s:\\s*(.+)$" % key).search(src)
	return m.get_string(1).strip_edges() if m != null else ""


func _spread(img: Image) -> float:
	var lo := 1.0
	var hi := 0.0
	for y in range(0, img.get_height(), 24):
		for x in range(0, img.get_width(), 24):
			var v := img.get_pixel(x, y).get_luminance()
			lo = minf(lo, v)
			hi = maxf(hi, v)
	return hi - lo
