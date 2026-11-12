extends Node

## Not a gate. Drives a real desk session ([EpisodeDesk]) over a table episode with a synthetic voice (every spoken word of
## its script at a steady pace, and each silence it writes) and writes PNGs to look at.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/desk/episode_desk_look_probe.gd 600 \
##       --out <dir>/d [--episode <an episode's folder>] [--seed N] [--things mug,taper] [--mood candlelight] \
##       --times 3,8,20 [--every S] [--page 1] [--words W]
##
## The episode's `acts.json` and `script.md` are read, and its `ink.json` - laid out here with TeX where it has none (the
## ink step's own call, [method TableInk.typeset]). With no `--episode` it plays a lesson of its own: a page and more of
## words, formulas and a drawing, a point and a strike, written to a scratch folder. `--every S` photographs every S
## seconds to the end instead of `--times`; `--page 1` also writes the flat pad texture beside each frame. `--words W` reads
## at W seconds a word (0.32 by default). `--things` and `--mood` are what the Medium card chose for the desk ([method
## DeskLook.picks_of]; none: the seed's). It asserts only that a frame is not uniform.

const W := 1280
const H := 720
const DT := 1.0 / 30.0
const SAMPLE := "user://episode_desk_probe"

var _out := "user://episode_desk"
var _episode := ""
var _seed := 7
var _times: Array = [3.0, 10.0]
var _every := 0.0
var _page := false
var _word := 0.32
var _things: Variant = null
var _mood := ""
var _flat := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			break
		match args[i]:
			"--out": _out = args[i + 1]
			"--episode": _episode = args[i + 1]
			"--seed": _seed = int(args[i + 1])
			"--every": _every = float(args[i + 1])
			"--page": _page = args[i + 1] == "1"
			"--words": _word = float(args[i + 1])
			"--things": _things = Array(String(args[i + 1]).split(",", false))
			"--mood": _mood = args[i + 1]
			"--times":
				_times = []
				for s in String(args[i + 1]).split(","):
					_times.append(float(s))
	var dir := _episode if not _episode.is_empty() else _sample()
	var source := FileAccess.get_file_as_string(dir.path_join("script.md"))
	if source.is_empty():
		print("episode_desk_look_probe: no script at '%s'" % dir)
		get_tree().quit(2)
		return
	if not FileAccess.file_exists(dir.path_join("ink.json")):
		var acts: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("acts.json")))
		var answer: Dictionary = await TableInk.typeset(TableInk.items_of(acts), {}, ProjectSettings.globalize_path("user://episode_desk_probe_tex"))
		if answer.has("error"):
			print("episode_desk_look_probe: TeX did not lay the writing out (%s)" % String(answer["error"]))
		else:
			var f := FileAccess.open(dir.path_join("ink.json"), FileAccess.WRITE)
			f.store_string(JSON.stringify(answer))
			f.close()
	var parsed := CardReading.parse(source)
	var words := _rehearse(parsed, _word)
	var stage := SubViewport.new()
	stage.size = Vector2i(W, H)
	stage.own_world_3d = true
	stage.transparent_bg = false
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	Director.detach()
	var medium: Medium = Medium.make("desk")
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	var rows := {}
	if _things is Array:
		rows["things"] = _things
	if not _mood.is_empty():
		rows["mood"] = _mood
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	subs.words = words
	subs.document = {"source": source, "table": {"dir": ProjectSettings.globalize_path(dir), "seed": _seed, "plan": {}},
		"medium": rows, "title": "Theorem-Grooving", "byline": "with Pen & Ink"}
	add_child(subs)
	if medium.bind_captions(subs):
		subs.overlay_hidden = true
	var end := float((words.back() as Dictionary)["t1"]) + 8.0
	var desk := medium as EpisodeDesk
	desk.advance(Spectrum.current, DT, 1.0)
	for i in desk._actions.size():
		var a: Dictionary = desk._actions[i]
		print("episode_desk_look_probe: %-9s page %d at %6.1fs  %s" % [String(a["kind"]) + ("+turn" if bool(a.get("turn", false)) else ""),
			int(a.get("page", 0)), _at(words, int(a.get("after", 0))), String(a.get("tex", a.get("target", ""))).substr(0, 50)])
	print("episode_desk_look_probe: %d synthetic words, %d pen actions, %.0fs; notes: %s" % [words.size(), desk._actions.size(), end,
		", ".join(desk.notes)])
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
			if float(want) - t < 1.5 or int(round(t / DT)) % 300 == 0:
				await get_tree().process_frame
		await get_tree().process_frame
		var img := stage.get_texture().get_image()
		var path := "%s_t%06.1f.png" % [_out, float(want)]
		img.save_png(path)
		if _page:
			desk._vp.get_texture().get_image().save_png("%s_t%06.1f_page.png" % [_out, float(want)])
		var st := _spread(img)
		if st < 0.02:
			_flat += 1
		var writing := ""
		for i in desk._actions.size():
			if float(desk._plan[i]["start"]) <= desk._now and float(desk._plan[i]["end"]) > desk._now:
				writing = String((desk._actions[i] as Dictionary).get("tex", desk._actions[i]["kind"])).substr(0, 40)
		print("episode_desk_look_probe: t=%.1f (spread %.3f) %s - the pen at %s, page %d, writing \"%s\"" % [want, st, path,
			desk.pen_at()["p"], desk._pages().x, writing])
	print("episode_desk_look_probe: done, %d flat" % _flat)
	Spectrum.virtual_clock = -1.0
	Director.hold(false)
	Director.detach()
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame
	get_tree().quit(1 if _flat > 0 else 0)


## A lesson of the probe's own, written to [constant SAMPLE]: its acts and script (TeX lays it out when it plays).
func _sample() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAMPLE))
	var acts: Array = []
	var script := PackedStringArray(["<!-- table: begin -->", ""])
	var lines := [
		["title", "text", "Adding one, in ones and zeros", "Today we ask one question, and write it at the top of the page."],
		["six", "tex", "6 = 4 + 2 = 110_2", "Six is four plus two, so in ones and zeros it is one, one, zero."],
		["seven", "tex", "7 = 4 + 2 + 1 = 111_2", "Seven adds a one at the end, so it is one, one, one."],
		["rule", "text", "Flip trailing ones to zeros, then the first zero to a one.", "Here is the rule a careful hand follows."],
		["tape", "draw", "<svg viewBox=\"0 0 240 60\"><rect x=\"10\" y=\"15\" width=\"40\" height=\"30\"/><rect x=\"50\" y=\"15\" width=\"40\" height=\"30\"/><rect x=\"90\" y=\"15\" width=\"40\" height=\"30\"/><rect x=\"130\" y=\"15\" width=\"40\" height=\"30\"/><text x=\"30\" y=\"36\">1</text><text x=\"70\" y=\"36\">0</text><text x=\"110\" y=\"36\">1</text><text x=\"150\" y=\"36\">1</text><path id=\"head\" d=\"M 150 58 L 150 48\"/></svg>", "We draw the tape, square by square, with the head under the last square."],
		["wrong", "strike", "rule", "That rule was too loose, so we cross it out and say it exactly."],
		["sum", "tex", "\\sum_{k=0}^{n-1} 2^k = 2^n - 1", "All ones in n places add up to two to the n, minus one."],
		["plus", "tex", "(2^n - 1) + 1 = 2^n", "Add one, and every one becomes a zero with a new one in front."],
		["check", "text", "Checked by Lean: the machine adds one to every number.", "Lean checked that the machine does this for every number."],
		["eleven", "tex", "11 = 1011_2", "Eleven is one, zero, one, one."],
		["twelve", "tex", "12 = 1100_2", "Twelve is one, one, zero, zero."],
		["thirteen", "tex", "13 = 1101_2", "Thirteen is one, one, zero, one."],
		["fourteen", "tex", "14 = 1110_2", "Fourteen is one, one, one, zero."],
		["fifteen", "tex", "15 = 1111_2", "Fifteen is all ones."],
		["sixteen", "tex", "16 = 10000_2", "And sixteen is a one with four zeros behind it."],
		["end", "text", "Every number has a next one, and the machine finds it.", "So every number has a next one."],
		["more", "text", "Over the page: the machine's rule table.", "Now the page is full, so we turn to a fresh one."],
		["table1", "tex", "(q_0, 1) \\to (q_0, 0, \\leftarrow)", "In the first state, a one becomes a zero, and the head moves left."],
		["table2", "tex", "(q_0, 0) \\to (q_1, 1, \\rightarrow)", "A zero becomes a one, and the machine moves on to stop."],
		["table3", "tex", "(q_0, \\sqcup) \\to (q_1, 1, \\rightarrow)", "A blank becomes a one too, for a number that was all ones."],
	]
	for l in lines:
		var tr := {"law": "write", "thing": "legal pad", "part": "sheet 1", "with": "pen"}
		if String(l[1]) == "strike":
			tr["strike"] = l[2]
		else:
			tr[String(l[1])] = l[2]
		acts.append({"name": l[0], "beat": "intro", "tracks": [tr]})
		script.append("<!-- act: %s --> %s" % [String(l[0]), String(l[3])])
		script.append("")
		if String(l[0]) == "seven":
			acts.append({"name": "look", "beat": "intro", "tracks": [{"law": "point", "thing": "pen", "on": "legal pad", "at": "six"}]})
			script.append("Look at <!-- act: look --> six again: it ends in a zero, so adding one only changes the last place.")
			script.append("")
	var put := func(name: String, text: String) -> void:
		var f := FileAccess.open(SAMPLE.path_join(name), FileAccess.WRITE)
		f.store_string(text)
		f.close()
	put.call("acts.json", JSON.stringify({"acts": acts}))
	put.call("script.md", "\n".join(script))
	return SAMPLE


## Every spoken word of [param parsed] at [param word] seconds, a breath between passages, and each silence it writes.
static func _rehearse(parsed: Dictionary, word: float) -> Array:
	var spoken: PackedStringArray = parsed["spoken"]
	var quiet := {}
	for q in parsed.get("quiets", []):
		quiet[int((q as Dictionary)["si"])] = float(q["s"])
	var out: Array = []
	var t := 1.0 + float(parsed.get("settle", 0.0))
	for i in spoken.size():
		t += float(quiet.get(i, 0.0))
		out.append({"text": spoken[i], "t0": t, "t1": t + word * 0.9, "sentence": 0})
		t += word
		if spoken[i].ends_with("."):
			t += 0.35
	return out


static func _at(words: Array, i: int) -> float:
	if i < words.size():
		return float((words[maxi(i, 0)] as Dictionary)["t0"])
	return float((words.back() as Dictionary)["t1"])


func _spread(img: Image) -> float:
	var lo := 1.0
	var hi := 0.0
	for y in range(0, img.get_height(), 24):
		for x in range(0, img.get_width(), 24):
			var v := img.get_pixel(x, y).get_luminance()
			lo = minf(lo, v)
			hi = maxf(hi, v)
	return hi - lo
