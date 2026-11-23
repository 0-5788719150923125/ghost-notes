extends Node

## NOT a gate. A game on the table, photographed ([TableGame], next/tabletop.md): a small session made through the same ledger the tools
## use, played with a synthetic voice, a frame at each moment asked or one on every event. Unpainted: a map is plain paper under its grid
## and a figure its owner's color, for judging where things are, how they read and how the dice go.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/game_look_probe.gd 400 [--times 12,30] [--out <dir>/game] [--size 1280x720]
##
## `--diorama` plays a session on a model's board instead ([GameDiorama]): a hand-made land and figures, a march, turns round the
## table and a page (a made picture standing in for a painted one; `--no-pages` for none, the board seen throughout), on a table
## as big as a game on a board wants.
##
## `--episode <dir>` stands a session really played instead (its `say_*` and `events_*`, [method TableProducer._write_game]'s way), its people from `--people A,B,C`.
##
## `--claims` prints what each camera wants of the session ([Cameras]) and quits, rendering nothing.
##
## `--clip A,B` writes every frame from A to B, for judging motion, and the dice's own sound under them to <out>.wav:
##   ffmpeg -framerate 30 -i <out>_c%04d.png -i <out>.wav -pix_fmt yuv420p -shortest game.mp4

const DT := 1.0 / 30.0
const DIR := "user://game_look"
const WORD := 0.34
const PEOPLE := ["Dell", "Bea", "Milo", "Rosa", "Guest"]


static func _table() -> Dictionary:
	return {"top": {"shape": "rect", "size": [170, 120], "thickness": 5, "edge": "eased", "material": "oak"},
		"materials": {"oak": {"kind": "wood", "color": "#7a5a3a", "color2": "#4a3422", "polish": 0.4, "pattern": 0.5, "grain": 1.4}, "card": {"kind": "painted", "color": "#7b3f2a", "polish": 0.1}, "mug": {"kind": "ceramic", "color": "#d8d4c8", "polish": 0.6}},
		"things": [
			{"name": "a game master's screen", "at": [0, -32], "parts": [{"shape": "box", "size": [44, 14, 0.5], "material": "card"}]},
			{"name": "a mug", "at": [48, 2], "parts": [{"shape": "lathe", "profile": [[0, 0], [3.5, 0], [4, 1], [4, 9], [3.4, 9], [3.2, 1], [0, 1]], "material": "mug"}]},
			{"name": "another mug", "at": [-50, -12], "parts": [{"shape": "lathe", "profile": [[0, 0], [3.5, 0], [4, 1], [4, 9], [3.4, 9], [3.2, 1], [0, 1]], "material": "mug"}]}],
		"light": {"lamps": [{"at": [0, 90, -10], "color": "#ffe2bd", "energy": 1.4}]}}


static func _session() -> Dictionary:
	var g := GameLedger.from({"Bea": {"hit points": 22}, "Milo": {"hit points": 9}, "Rosa": {"hit points": 15}, "Guest": {"hit points": 18}})
	var items: Array = []
	var say := func(who: String, words: String, extra := {}) -> void:
		var d := {"who": who, "says": words}
		d.merge(extra)
		items.append(d)
	var mark := func(got: Dictionary, kind: String) -> void:
		items.append({"mark": kind, "id": int((got["event"] as Dictionary)["id"])})
	say.call("Dell", "Okay. So it is late, and the bridge is still there, and the goat has not moved.")
	say.call("Bea", "It has not moved because it knows.")
	mark.call(g.map_down("The Toll Bridge", "a stone bridge over a gorge", [20, 14]), "map")
	say.call("Dell", "Here is the bridge. Everybody put your people on it, wherever you like.")
	mark.call(g.place("Bea's knight", [3, 6], "a stern knight", "Bea"), "place")
	mark.call(g.place("Milo's rogue", [5, 8], "a small grinning thief", "Milo"), "place")
	mark.call(g.place("Rosa's bard", [4, 4], "a tragic singer", "Rosa"), "place")
	mark.call(g.place("The Goat", [13, 7], "an enormous goat", ""), "place")
	say.call("Milo", "I walk right up to it. I have a sandwich.", {})
	mark.call(g.move("Milo's rogue", [12, 7]), "move")
	say.call("Dell", "Give me a roll to make friends with the goat.")
	mark.call(g.roll("Milo", "1d20+2", "befriending a goat", 41), "roll")
	say.call("Milo", "Oh, come on.", {})
	say.call("Bea", "What did you get?", {"over": 0.3})
	say.call("Rosa", "Milo, what did you get?", {"together": true})
	say.call("Milo", "It is not relevant what I got.")
	say.call("Dell", "It eats the sandwich, and then it looks at you, and I would like an attack from the goat.")
	mark.call(g.roll("Dell", "1d20+5", "the goat", 41), "roll")
	say.call("Dell", "That hits. Two dice for the horns.")
	mark.call(g.roll("Dell", "2d8+3", "horns", 41), "roll")
	mark.call(g.change("Milo", "hit points", {"by": -9}), "")
	mark.call(g.figure_state("fall", "Milo's rogue"), "fall")
	say.call("Milo", "No.", {})
	say.call("Bea", "Yes.", {"together": true})
	say.call("Guest", "Is that bad? Is he okay?", {"over": 0.2})
	say.call("Dell", "I want you to see what you are all looking at.")
	mark.call(g.reveal("The Goat", "an enormous goat, very calm"), "reveal")
	say.call("Dell", "It is chewing. It looks like this. Bea, you are next, and it is looking at you.")
	mark.call(g.roll("Bea", "2d20kh1+7", "the knight's charge", 41), "roll")
	say.call("Bea", "Natural twenty. Do not talk to me.")
	mark.call(g.roll("Bea", "8d6", "a very large hit", 41), "roll")
	say.call("Dell", "Eight dice. Take your time.")
	mark.call(g.map_down("The Boat", "a small boat on a gray lake", [10, 8]), "map")
	say.call("Dell", "So the goat is gone, and the river takes you all the way down to a lake. And there is a boat.")
	mark.call(g.place("Rosa's bard", [2, 3], "a tragic singer", "Rosa"), "place")
	say.call("Rosa", "I have never been more moved by a boat.")
	var clean: Array = items.filter(func(i: Dictionary) -> bool: return not String(i.get("mark", "x")).is_empty())
	var script := "<!-- table: begin -->\n\n" + GameTools.compose(clean, PackedStringArray(PEOPLE))
	var game := GameBoard.gather(g.events, PackedStringArray(PEOPLE), {"people": {
		"Bea": {"dice": {"material": "metal", "color": "#b8bcc4", "ink": "#101214"}},
		"Milo": {"dice": {"material": "plastic", "color": "#2fb36a", "ink": "#ffffff"}},
		"Rosa": {"dice": {"material": "stone", "color": "#5a3a70", "ink": "#f0e6c8"}},
		"Guest": {"dice": {"material": "plastic", "color": "#c8452a", "size": 1.5}},
		"Dell": {"dice": {"material": "wood", "color": "#8a6a40", "ink": "#1a120a"}}}}, {"Dell": 0.0, "Bea": -105.0, "Milo": 105.0, "Rosa": -50.0, "Guest": 50.0})
	return {"script": script, "game": game}


## The land, its places and the figures of [method _board_session].
const LAND := {"name": "the vale", "hills": [{"at": [195, 39], "radius": 40, "height": 14, "rough": 0.6}, {"at": [38, 125], "radius": 29, "height": 5}],
	"rivers": [{"path": [[0, 86], [75, 79], [131, 93], [244, 82]], "width": 7, "depth": 1.4}],
	"roads": [{"path": [[53, 129], [98, 93], [113, 54], [188, 43]], "width": 2.5}],
	"woods": [{"at": [47, 39], "radius": 25, "trees": 90, "sort": "pine", "tall": 9}, {"at": [169, 125], "radius": 22, "trees": 50, "sort": "leafy"}],
	"places": [
		{"name": "the inn", "at": [56, 132], "turn": 20, "thing": {"parts": [{"shape": "box", "size": [9, 6, 7], "material": "plaster"}, {"shape": "box", "size": [10, 4, 8], "taper": 0.9, "at": [0, 6, 0], "material": "thatch"}]}},
		{"name": "the bridge", "at": [105, 88], "turn": 95, "thing": {"parts": [{"shape": "box", "size": [4, 1.2, 14], "material": "stone", "at": [0, 0.5, 0]}]}},
		{"name": "the keep", "at": [195, 39], "thing": {"parts": [{"shape": "lathe", "profile": [[0, 0], [11, 0], [11, 32], [13, 32], [13, 38], [0, 38]], "sides": 8, "material": "stone"}]}}],
	"materials": {"plaster": {"kind": "painted", "color": "#d8ccb0"}, "thatch": {"kind": "painted", "color": "#a8884a"}, "stone": {"kind": "stone", "color": "#8a867c"}}}
const MINIS := {"figures": {
		"Bea's knight": {"parts": [{"shape": "lathe", "profile": [[0, 0], [0.8, 0], [0.9, 2.2], [0.6, 2.9], [0, 2.9]], "material": "steel"}, {"shape": "ball", "size": [1.0, 1.1, 1.0], "at": [0, 3.3, 0], "material": "steel"}]},
		"Milo's rogue": {"parts": [{"shape": "lathe", "profile": [[0, 0], [0.7, 0], [0.75, 2.0], [0.5, 2.6], [0, 2.6]], "material": "cloak"}, {"shape": "ball", "size": [0.9, 1.0, 0.9], "at": [0, 3.0, 0], "material": "skin"}]},
		"The Goat": {"parts": [{"shape": "box", "size": [1.6, 1.6, 3.6], "round": 0.6, "at": [0, 1.4, 0], "material": "fur"}, {"shape": "ball", "size": [1.0, 1.1, 1.4], "at": [0, 2.6, 2.0], "material": "fur"}]}},
	"materials": {"steel": {"kind": "metal", "color": "#b8bcc4"}, "cloak": {"kind": "painted", "color": "#2f5a3a"}, "skin": {"kind": "painted", "color": "#d8a888"}, "fur": {"kind": "painted", "color": "#e8e0d0"}}}


## A session on a model's board: figures set at places by name, a march across the bridge, turns, throws and a page.
static func _board_session() -> Dictionary:
	var board := GameDiorama.board_of(GameDiorama.sanitize(LAND))
	var g := GameLedger.from({"Bea": {"hit points": 22}, "Milo": {"hit points": 9}}, [], board)
	var items: Array = []
	var say := func(who: String, words: String) -> void:
		items.append({"who": who, "says": words})
	var mark := func(got: Dictionary, kind: String) -> void:
		if bool(got.get("ok", false)):
			items.append({"mark": kind, "id": int((got["event"] as Dictionary)["id"])})
	say.call("Dell", "So. You are at the inn, it is late, and somebody has to go and look at that keep.")
	mark.call(g.place("Bea's knight", [62, 125], "a stern knight", "Bea"), "place")
	mark.call(g.place("Milo's rogue", [68, 129], "a small grinning thief", "Milo"), "place")
	mark.call(g.place("The Goat", [113, 82], "an enormous goat", ""), "place")
	mark.call(g.picture("The inn at night", "a low inn under the hill, one window lit, two travelers at its door", ["Bea's knight", "Milo's rogue", "the inn"]), "picture")
	say.call("Dell", "The road goes down to the river, over the bridge, and up to the keep. It is a long walk and nobody has walked it in a while.")
	say.call("Dell", "There is a goat on the bridge. There is always a goat on the bridge.")
	mark.call(g.turn_to("Bea"), "turn")
	say.call("Bea", "We walk. Together. Quietly. Milo, quietly.")
	mark.call(g.move("Bea's knight", [101, 91]), "move")
	mark.call(g.move("Milo's rogue", [98, 95]), "move")
	say.call("Dell", "You go down the road. The grass is wet, the river is loud, and the keep gets no closer for a long while. Then the goat looks up.")
	say.call("Milo", "I have a sandwich.")
	mark.call(g.turn_to("Milo"), "turn")
	mark.call(g.roll("Milo", "1d20+2", "befriending a goat", 41), "roll")
	say.call("Milo", "Oh, come on.")
	say.call("Dell", "It eats the sandwich, and then it looks at you, and I would like an attack from the goat.")
	mark.call(g.roll("Dell", "1d20+5", "the goat", 41), "roll")
	say.call("Dell", "That hits. Two dice for the horns. And for a while after that, nobody says anything at all, and the river goes on, and the keep is still up there on its hill, waiting for somebody braver.")
	var script := "<!-- table: begin -->\n\n" + GameTools.compose(items, PackedStringArray(PEOPLE))
	var game := GameBoard.gather(g.events, PackedStringArray(PEOPLE), {}, {"Dell": 0.0, "Bea": -105.0, "Milo": 105.0, "Rosa": -50.0, "Guest": 50.0}, board)
	return {"script": script, "game": game}


## A session really played: as the producer gathers it, from what is there.
static func _played(dir: String, people: PackedStringArray) -> Dictionary:
	var names := DirAccess.get_files_at(dir)
	var order: Array = ["intro"]
	for k in range(1, 13):
		order.append(str(k))
	order.append("close")
	var parts := PackedStringArray(["<!-- table: begin -->"])
	var events: Array = []
	for n in order:
		var say := dir.path_join("say_%s.txt" % n)
		if FileAccess.file_exists(say):
			parts.append(FileAccess.get_file_as_string(say))
		var ev := dir.path_join("events_%s.json" % n)
		if FileAccess.file_exists(ev):
			var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(ev))
			if got is Array:
				events = got
	var prep: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("prep.json")))
	print("game_look_probe: %d events, %d files" % [events.size(), names.size()])
	return {"script": "\n\n".join(parts), "game": GameBoard.gather(events, people, prep if prep is Dictionary else {}, {"Bea": -105.0, "Milo": 105.0, "Rosa": -50.0, "Guest": 50.0})}


## The words' times a voice would give them, with each mark's rest; a turn over the last or together with it comes in early, as the join has it.
static func timeline(parse: Dictionary, intro: float) -> Array:
	var out: Array = []
	var rest_at := {}
	var over_at := {}
	var n := 0
	var rx := RegEx.new()
	rx.compile("<!--\\s*action-hold\\s*:\\s*([0-9.]+)\\s*-->|<!--\\s*(over|together)[^>]*-->|<!--[^>]*-->|([^\\s<]+)")
	for m in rx.search_all(String(parse["speakable"])):
		if not m.get_string(1).is_empty():
			rest_at[n] = float(rest_at.get(n, 0.0)) + float(m.get_string(1))
		elif not m.get_string(2).is_empty():
			over_at[n] = true
		elif not m.get_string(3).is_empty() and not TabletScript.norm(m.get_string(3)).is_empty():
			n += 1
	var t := intro
	var spoken: PackedStringArray = parse["spoken"]
	for i in spoken.size():
		t += float(rest_at.get(i, 0.0))
		if over_at.has(i):
			t -= WORD * 1.5
		out.append({"text": spoken[i], "t0": t, "t1": t + WORD * 0.85, "sentence": i / 8})
		t += WORD
	return out


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ProjectSettings.globalize_path(DIR).path_join("game")
	var times: Array = []
	var clip := Vector2(-1.0, -1.0)
	var size := Vector2i(1280, 720)
	for i in args.size() - 1:
		match args[i]:
			"--out":
				out = args[i + 1]
			"--times":
				for s in String(args[i + 1]).split(",", false):
					times.append(float(s))
			"--clip":
				var ab := String(args[i + 1]).split(",", false)
				if ab.size() == 2:
					clip = Vector2(float(ab[0]), float(ab[1]))
			"--size":
				var wh := String(args[i + 1]).split("x", false)
				if wh.size() == 2:
					size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var on_board := args.has("--diorama")
	var table := _table()
	if on_board:
		(table["top"] as Dictionary)["size"] = [GameBoard.TOP_LEAST.x, GameBoard.TOP_LEAST.y]
		table["things"] = []
	var h := FileAccess.open(DIR.path_join("table.json"), FileAccess.WRITE)
	h.store_string(JSON.stringify(table))
	h.close()
	for f in ["diorama.json", "minis.json", "page_1.png"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR).path_join(f))
	var session := _session()
	if on_board:
		session = _board_session()
		for pair in [["diorama.json", LAND], ["minis.json", MINIS]]:
			var fh := FileAccess.open(DIR.path_join(String(pair[0])), FileAccess.WRITE)
			fh.store_string(JSON.stringify(pair[1]))
			fh.close()
		# ...a picture standing in for a painted page: bands of color, so it is plain where it covers the frame
		var page := Image.create(768, 512, false, Image.FORMAT_RGB8)
		for y in 512:
			page.fill_rect(Rect2i(0, y, 768, 1), Color.from_hsv(float(y) / 512.0 * 0.3 + 0.55, 0.5, 0.8))
		if not args.has("--no-pages"):
			page.save_png(ProjectSettings.globalize_path(DIR).path_join("page_1.png"))
	var episode := ""
	var people := PackedStringArray()
	for i in args.size() - 1:
		if args[i] == "--episode":
			episode = args[i + 1]
		elif args[i] == "--people":
			people = String(args[i + 1]).split(",", false)
	if not episode.is_empty():
		session = _played(episode, people)
	var script := String(session["script"])
	var plan := {"game": true, "look": {"candles": 0, "palette": ["#3a2a20", "#c8a060", "#6a5a48"], "light": {"kind": "a lamp over a table at night", "color": "#ffe2bd", "warmth": "warm"}}, "spread": {"positions": []}, "staging": {"source": "none"}}
	var stage := SubViewport.new()
	stage.size = size
	stage.own_world_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	Director.detach()
	var medium: Medium = Medium.make("table")
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	var parse := CardReading.parse(script)
	subs.words = timeline(parse, Director.intro_hold)
	subs.document = {"source": script, "title": "Mistakes Were Made", "table": {"show": "game-look", "seed": 41, "dir": ProjectSettings.globalize_path(DIR), "plan": plan, "cards": [], "game": session["game"]}}
	add_child(subs)
	medium.bind_captions(subs)
	var tm := medium as TableMedium
	Spectrum.virtual_clock = 0.0
	Spectrum.current.time = 0.0
	subs._process(DT)
	medium.advance(Spectrum.current, DT, 1.0)
	var w: TableWork = tm._work
	if w.game == null:
		print("game_look_probe: NO GAME on the table")
		get_tree().quit(1)
		return
	print(w.game.report())
	for n in w.notes:
		print("game_look_probe: note - %s" % n)
	# the record, first: a render waits for it whole
	var t0 := Time.get_ticks_msec()
	w.game.wait_whole()
	print("game_look_probe: dice thrown in %d ms: %s" % [Time.get_ticks_msec() - t0, w.game.report()])
	var sched := {}
	var last := 0.0
	var events: Array = []
	subs.words = timeline(parse, Director.intro_hold)
	for wd in subs.words:
		last = maxf(last, float((wd as Dictionary)["t1"]))
	var end := last + 3.0
	print("game_look_probe: the show runs %.1f s" % end)
	if times.is_empty() and clip.x < 0.0:
		for e in tm._sched if not tm._sched.is_empty() else []:
			times.append(float((e as Dictionary)["t0"]))
	var t := 0.0
	var k := 0
	var c := 0
	var want := times.duplicate()
	want.sort()
	var costs := PackedFloat32Array()
	while t < end + 0.5:
		Spectrum.virtual_clock = t
		Spectrum.current.time = t
		subs.time_base = 0.0
		subs._process(DT)
		var began := Time.get_ticks_usec()
		medium.advance(Spectrum.current, DT, 1.0)
		costs.append(float(Time.get_ticks_usec() - began) / 1000.0)
		if t < 0.05 and times.is_empty() and clip.x < 0.0:
			# ...the placed moves are known now: one frame shortly after each
			for e in tm._sched:
				var d: Dictionary = e
				if TableActions.names_event(String((d["a"] as Dictionary)["kind"])):
					want.append(float(d["t0"]) + (2.4 if String((d["a"] as Dictionary)["kind"]) == "roll" else 0.9))
			want.sort()
		if args.has("--claims") and t > 0.5:
			# ...what each camera wants of the session, in the order they are laid
			for cl in w.game._claims:
				var cd: Dictionary = cl
				print("game_look_probe: claim %s %.1f-%.1f ease %.1f %s" % [String(cd["sort"]), float(cd["t0"]), float(cd["t1"]), float(cd.get("ease", Cameras.EASE)), String(cd.get("who", ""))])
			print("game_look_probe: %d marks placed, the first at %.1f" % [w.game._times.size(), w.game._times.values().min() if not w.game._times.is_empty() else -1.0])
			get_tree().quit(0)
			return
		var shoot := k < want.size() and t >= float(want[k])
		var in_clip := clip.x >= 0.0 and t >= clip.x and t <= clip.y
		if shoot or in_clip:
			await get_tree().process_frame
			await get_tree().process_frame
			var img := stage.get_texture().get_image()
			if in_clip:
				img.save_png("%s_c%04d.png" % [out, c])
				c += 1
			if shoot:
				img.save_png("%s_%05.1f.png" % [out, t])
				print("game_look_probe: %05.1f" % t)
				k += 1
		t += DT
	if clip.x >= 0.0:
		var sounds := WorkSounds.new(w)
		sounds._restart(clip.x)
		var pcm := sounds.render(int((clip.y - clip.x) * float(WorkSounds.RATE)))
		sounds.stop()
		Splice.write_wav(out + ".wav", pcm, 2, WorkSounds.RATE)
		var peak := 0.0
		for f in pcm:
			peak = maxf(peak, maxf(absf(f.x), absf(f.y)))
		print("game_look_probe: the dice's sound -> %s.wav, its peak %.4f" % [out, peak])
	costs.sort()
	if not costs.is_empty():
		print("game_look_probe: a frame's table: median %.1f ms, worst %.1f ms" % [costs[costs.size() / 2], costs[costs.size() - 1]])
	get_tree().quit(0)
