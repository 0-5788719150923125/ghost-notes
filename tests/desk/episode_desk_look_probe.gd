extends Node

## Not a gate. Drives a real desk session ([EpisodeDesk]) over a table episode with a synthetic voice (every spoken word of
## its script at a steady pace, and each silence it writes) and writes PNGs to look at.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/desk/episode_desk_look_probe.gd 600 \
##       --out <dir>/d [--episode <an episode's folder>] [--seed N] [--things mug,taper] [--mood candlelight] \
##       --times 3,8,20 [--every S] [--page 1] [--words W] [--plan 1] [--take <a take's .json>] [--live S] [--audit 1]
##
## The episode's `acts.json` and `script.md` are read, and its `ink.json` - laid out here with TeX where it has none (the
## ink step's own call, [method TableInk.typeset]). With no `--episode` it plays a lesson of its own: a page and more of
## words, formulas and a drawing, a point and a strike, written to a scratch folder. `--every S` photographs every S
## seconds to the end instead of `--times`; `--page 1` also writes the flat pad texture beside each frame. `--words W` reads
## at W seconds a word (0.32 by default). `--things` and `--mood` are what the Medium card chose for the desk ([method
## DeskLook.picks_of]; none: the seed's). `--audit 1` renders nothing: every write's pen against its voice ([method
## PenPace.audit]) - how far behind and ahead of the words, its quickest pace, how often its pace jumps, how long it crawls -
## for voices of 0.35, 0.45 and 0.55 s a word reading the desk's rests (and `--take`'s, as it was recorded), each with every
## word's time known and handed live a sentence at a time (a second ahead, and as it begins); and the rests the voice takes.
## `--live S` hands the desk each sentence's words only S seconds before it begins, as a
## live reading's arrive. `--take` reads a kept take's word times (`generative/take_N.json`) in place of the
## synthetic voice. `--plan 1` prints each pen action's words against when the pen begins and ends it, how far it runs past
## them, and for a write the most its pen is behind a word as it is said and ahead of the voice in words ([method
## PenPace.audit], on its map), and renders nothing. It asserts only that a frame is not uniform.

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
var _plan_only := false
var _take := ""
var _live := -1.0
var _audit := false
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
			"--plan": _plan_only = args[i + 1] == "1"
			"--take": _take = args[i + 1]
			"--live": _live = float(args[i + 1])
			"--audit": _audit = args[i + 1] == "1"
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
	# ...with the episode's plan where it has one: its beats say which of its acts are played
	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("plan.json"))) if FileAccess.file_exists(dir.path_join("plan.json")) else {}
	var pay := {"dir": ProjectSettings.globalize_path(dir), "seed": _seed, "plan": plan if plan is Dictionary else {}}
	# the voice reads the script with the desk's rests in it, as the reading's walk hands it ([method EpisodeDesk.voiced])
	var parsed := CardReading.parse(EpisodeDesk.voiced(source, pay))
	if _audit:
		_audit_all(source, pay)
		get_tree().quit(0)
		return
	var words := _rehearse(parsed, _word, EpisodeDesk.voiced(source, pay)) if _take.is_empty() else _taken(_take)
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
	var opens := _sentence_starts(words)
	subs.words = words if _live < 0.0 else _arrived(words, opens, 0.0)
	subs.document = {"source": source, "table": pay, "medium": rows, "title": "Theorem-Grooving", "byline": "with Pen & Ink"}
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
	if _plan_only:
		_print_plan(desk, words)
		Director.hold(false)
		Director.detach()
		stage.queue_free()
		for _i in 3:
			await get_tree().process_frame
		get_tree().quit(0)
		return
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
			if _live >= 0.0:
				subs.words = _arrived(words, opens, t)
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
static func _rehearse(parsed: Dictionary, word: float, text := "") -> Array:
	var spoken: PackedStringArray = parsed["spoken"]
	var quiet := {}
	for q in parsed.get("quiets", []):
		quiet[int((q as Dictionary)["si"])] = float(q["s"])
	# ...which words end a sentence, read off the script (the spoken words are normalized: no stops in them)
	var ends: Array = EpisodeDesk._word_ends(text) if not text.is_empty() else []
	var out: Array = []
	var t := 1.0 + float(parsed.get("settle", 0.0))
	var sentence := 0
	for i in spoken.size():
		t += float(quiet.get(i, 0.0))
		out.append({"text": spoken[i], "t0": t, "t1": t + word * 0.9, "sentence": sentence})
		t += word
		if i < ends.size() and bool((ends[i] as Dictionary)["stop"]):
			t += EpisodeDesk.VOICE_PAUSE
			sentence += 1
	return out


## Each pen action: its words (from its first to the last it keeps with), when the pen begins and ends it, and how far past
## its words it runs.
static func _print_plan(desk: EpisodeDesk, words: Array) -> void:
	print("episode_desk_look_probe: kind      words from - to     pen from - to      past  write  behind  ahead  what")
	for i in desk._actions.size():
		var a: Dictionary = desk._actions[i]
		var after := int(a.get("after", 0))
		var span := maxi(int(a.get("span", 0)), 1)
		var w0 := _at(words, after)
		var w1 := float((words[mini(after + span - 1, words.size() - 1)] as Dictionary)["t1"])
		var p: Dictionary = desk._plan[i]
		var kept := _kept(desk, words, i) if a.has("map") else {}
		print("episode_desk_look_probe: %-9s %7.1f - %7.1f  %7.1f - %7.1f  %+6.1f  %5.1f  %6s  %5s  %s" % [String(a["kind"]), w0, w1,
			float(p["start"]), float(p["end"]), float(p["end"]) - w1, float(a.get("write", 0.0)),
			"%.1f" % float(kept["behind"]) if not kept.is_empty() else "-", "%.1f" % float(kept["ahead"]) if not kept.is_empty() else "-",
			String(a.get("tex", a.get("target", ""))).substr(0, 40).replace("\n", " ")])


## How write [param i]'s pen keeps with its own words ([method PenPace.audit]), every word's time known ([param words]).
static func _kept(desk: EpisodeDesk, words: Array, i: int) -> Dictionary:
	var a: Dictionary = desk._actions[i]
	var said: Array = []
	for k in (a["own"] as PackedInt32Array):
		said.append(Vector2(float((words[k] as Dictionary)["t0"]), float((words[k] as Dictionary)["t1"])))
	var keep := desk._now
	var times := PackedFloat32Array()
	var drawn := PackedFloat32Array()
	var t := float(desk._plan[i]["start"])
	while t <= float(desk._plan[i]["end"]) + 0.5:
		desk._now = t
		times.append(t)
		drawn.append(desk._written(i))
		t += 0.05
	desk._now = keep
	return PenPace.audit(a["map"], said, times, drawn, desk._length(i)) if times.size() > 1 else {}


## When each word's sentence begins: its `sentence` where the words carry one, else a sentence ends at a word ending in a stop
## or a colon.
static func _sentence_starts(words: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var begun := 0.0
	var fresh := true
	var was := -1
	for w in words:
		var numbered := (w as Dictionary).has("sentence") and int(w["sentence"]) != was
		if fresh or numbered:
			begun = float(w["t0"])
		was = int(w.get("sentence", was))
		out.append(begun)
		var text := String(w["text"])
		fresh = not (w as Dictionary).has("sentence") and (text.ends_with(".") or text.ends_with("?") or text.ends_with("!") or text.ends_with(":"))
	return out


## The words a live reading has handed over by [param t]: each sentence's [member _live] seconds before it begins.
func _arrived(words: Array, opens: PackedFloat32Array, t: float) -> Array:
	var n := 0
	while n < words.size() and opens[n] <= t + _live:
		n += 1
	return words.slice(0, n)


## The audit (see the header): a line per voice and way of handing its words, and each write past the bounds below.
const AUDIT_BEHIND := 1.0
const AUDIT_AHEAD := 6.0
const AUDIT_JUMPS := 3
const AUDIT_CRAWL := 1.5
const AUDIT_FASTEST := 4.3


func _audit_all(source: String, pay: Dictionary) -> void:
	var heard := EpisodeDesk.voiced(source, pay)
	var parsed := CardReading.parse(heard)
	var added := _rests_added(source, heard)
	print("episode_desk_look_probe: audit - the voice's rests for the pens: %d, %.1f s in all, the longest %.1f s" % [added.size(),
		_sum(added), _most(added)])
	var voices: Array = []
	if not _take.is_empty():
		voices.append(["take", _taken(_take)])
	for w in [0.35, 0.45, 0.55]:
		voices.append(["%.2f s a word" % w, _rehearse(parsed, w, heard)])
	print("episode_desk_look_probe: audit - voice / words        behind(s)  ahead(words)  fastest  jumps  crawl(s)  writes past")
	for v in voices:
		for live in [-1.0, 1.0, 0.0]:
			var got := _audit_run(source, pay, v[1], live)
			var worst := {"behind": -INF, "ahead": 0.0, "fastest": 0.0, "jumps": 0, "crawl": 0.0}
			var past: Array = []
			for r in got:
				var a: Dictionary = r["audit"]
				worst["behind"] = maxf(float(worst["behind"]), float(a["behind"]))
				worst["ahead"] = maxf(float(worst["ahead"]), float(a["ahead"]))
				worst["fastest"] = maxf(float(worst["fastest"]), float(a["fastest"]))
				worst["jumps"] = maxi(int(worst["jumps"]), int(a["jumps"]))
				worst["crawl"] = maxf(float(worst["crawl"]), float(a["crawl"]))
				if float(a["behind"]) > AUDIT_BEHIND or float(a["ahead"]) > AUDIT_AHEAD or int(a["jumps"]) > AUDIT_JUMPS \
						or float(a["crawl"]) > AUDIT_CRAWL or float(a["fastest"]) > AUDIT_FASTEST:
					past.append(r)
			print("episode_desk_look_probe: audit - %-14s %-7s %8.1f  %12.1f  %7.1f  %5d  %8.1f  %d" % [v[0],
				"known" if live < 0.0 else "live %.0f" % live, worst["behind"], worst["ahead"], worst["fastest"], worst["jumps"],
				worst["crawl"], past.size()])
			for r in past:
				var a: Dictionary = r["audit"]
				print("episode_desk_look_probe: audit -     %6.1f s  %-34s behind %.1f  ahead %.1f  fastest %.1f (at %.1f)  jumps %d  crawl %.1f" % [
					float(r["at"]), String(r["what"]).substr(0, 34).replace("\n", " "), a["behind"], a["ahead"], a["fastest"],
					a["fastest_at"], a["jumps"], a["crawl"]])


## One desk playing [param words] - all known ([param live] below 0), or handed a sentence at a time [param live] seconds
## before it begins - asked every tenth of a second: each write's audit.
func _audit_run(source: String, pay: Dictionary, words: Array, live: float) -> Array:
	var m := EpisodeDesk.new()
	m.feed = ShowFeed.new()
	m.feed.intro_hold = 1.0
	m._pad = LegalPad.new()
	m.load_episode(pay, source)
	var opens := _sentence_starts(words)
	var writes: Array = []
	for i in m._actions.size():
		if (m._actions[i] as Dictionary).has("map"):
			writes.append(i)
	var times_of := {}
	var drawn_of := {}
	for i in writes:
		times_of[i] = PackedFloat32Array()
		drawn_of[i] = PackedFloat32Array()
	var end := float((words.back() as Dictionary)["t1"]) + 4.0
	var t := 0.0
	while t < end:
		var n := words.size()
		if live >= 0.0:
			n = 0
			while n < words.size() and opens[n] <= t + live:
				n += 1
		m._now = t
		m.take_words(words.slice(0, n) if n < words.size() else words)
		for i in writes:
			var start := float(m._plan[i]["start"])
			if start <= t and t <= float(m._plan[i]["end"]) + 0.5:
				# (a packed array is a value: taken out, grown, and put back)
				var ts: PackedFloat32Array = times_of[i]
				ts.append(t)
				times_of[i] = ts
				var ds: PackedFloat32Array = drawn_of[i]
				ds.append(m._written(i))
				drawn_of[i] = ds
		t += 0.1
	var out: Array = []
	for i in writes:
		var a: Dictionary = m._actions[i]
		var said: Array = []
		for k in a["own"]:
			said.append(Vector2(float((words[k] as Dictionary)["t0"]), float((words[k] as Dictionary)["t1"])))
		var times: PackedFloat32Array = times_of[i]
		if times.size() < 2:
			continue
		out.append({"at": times[0], "what": String(a.get("tex", "")), "audit": PenPace.audit(a["map"], said, times, drawn_of[i],
			m._length(i))})
	m._pad.free()
	m.free()
	return out


## The silences [param heard] has that [param source] has not (seconds each).
static func _rests_added(source: String, heard: String) -> PackedFloat32Array:
	var rx := RegEx.create_from_string("<!--\\s*quiet\\s*:\\s*([0-9.]+)\\s*-->")
	var had := rx.search_all(source).size()
	var out := PackedFloat32Array()
	var all := rx.search_all(heard)
	for m in all:
		out.append(float(m.get_string(1)))
	# (the source's own silences are among them: the ones added are the rest)
	out.sort()
	return out.slice(0, maxi(all.size() - had, 0)) if had > 0 else out


static func _sum(xs: PackedFloat32Array) -> float:
	var s := 0.0
	for x in xs:
		s += x
	return s


static func _most(xs: PackedFloat32Array) -> float:
	var s := 0.0
	for x in xs:
		s = maxf(s, x)
	return s


## A kept take's words (`{text, t0, t1, sentence}`), as the overlay would hold them.
static func _taken(path: String) -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out: Array = []
	for w in (d as Dictionary).get("words", []) if d is Dictionary else []:
		out.append({"text": String(w["text"]), "t0": float(w["t0"]), "t1": float(w["t1"]), "sentence": int(w.get("sentence", 0))})
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
