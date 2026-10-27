extends Node

## NOTHING IN THE BOX PASSES THROUGH ANYTHING (the user, 2026-10-18, of the-shoebox 32533: a card put back
## in the box lay "on the top of the pile", and "every future draw clips-through that card"; a search
## pulled cards up "clipping through the card on top every single time", and "they never stop to even
## look at the cards"):
##
##   - FRAME BY FRAME through whole box shows - an open tin of loose cards, an open box of piles, a
##     shoebox of loose cards, cards filed on edge in an open box and in a shoebox, and a tin with room
##     for one pile - each with cards put back between later draws and a search, over several seeds:
##     no card of the show, and no card a search looks at, passes through another card or lies in one,
##     the box's own filed cards included. A card put back lies where no card still to be drawn waits
##     under it ([method TableBox._pile_places]).
##   - A TIN WITH ROOM FOR ONE PILE, whose reading puts a card back before another is drawn, files its
##     cards on edge ([method TableBox.contents]), and the card put back goes back into its own place.
##   - A SEARCH STOPS ON EACH CARD: its front is held to the eye for most of a second at least, lying or
##     on edge ([constant TableActions.RUMMAGE], [method TableCardPose.searched_xf]).
##
## WHAT COUNTS IS WHAT SHOWS: in a box of cards filed on edge, a crossing below the tops of the filed
## cards is behind the cards in front of it. A card drawn part of the way up out of a file and leaned
## back to the eye (the user, 2026-10-13) swings its foot into the cards in front of it there, as a real
## card rocks in its file - unseen, and not counted.
##
## Two-sided: the card put back laid instead on the pile a later card is drawn from is passed through
## by that draw, and the check says so; a look half as long holds a front up too briefly.
##
##   tests/run_boot_probe.sh tests/table/box_clip_check.gd 300
##
## A BOOT probe (the medium reaches the Director); no GPU - poses are transforms.

const SEEDS := [32533, 41, 9907]
## Where the fixture's table is written: the tin of the-shoebox 32533 (14 by 21 cm, 7 deep), which holds
## two piles of its baseball cards - a box made by no set dresser is smaller, and holds one.
const DIR := "user://box_clip_check"
const TIN := {"things": [{"name": "the tin", "place": "by the deck", "holds_cards": true, "parts": [
	{"shape": "extrude", "outline": "rect", "size": [14.0, 21.0], "height": 7.0, "wall": 0.25, "material": "tin"}]}],
	"materials": {"tin": {"kind": "painted", "color": "#3f8a86", "color2": "#8a5434", "polish": 0.45, "wear": 0.35}}}
## Frames a second the show is posed at.
const FPS := 30.0
## The least a searched card's front is held to the eye, seconds.
const LOOK_LEAST := 0.8

var _fails := 0
var medium: TableMedium
var subs: Subtitles


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(640, 360)
	stage.own_world_3d = true
	add_child(stage)
	Director.detach()
	medium = Medium.make("table") as TableMedium
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	subs = preload("res://src/show/subtitles.gd").new()
	add_child(subs)
	medium.bind_captions(subs)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var back := {"destination": "box", "comment": "brief"}
	var shows := [
		["an open tin of loose cards", {"box_style": "open", "contents": "loose"}, "baseball",
			[{}, back, {"comes": "swept"}, {"comes": "swept"}, {"comes": "swept"},
				{"comes": "searched", "destination": "box", "comment": "aside"}, {}, {}]],
		["an open box of piles", {"box_style": "open", "contents": "piles"}, "trading",
			[{}, back, {"comes": "searched"}, {}, back, {}]],
		["a shoebox of loose cards", {"box_style": "shoebox", "contents": "loose"}, "baseball",
			[{"destination": "stack"}, {"destination": "box", "comment": "none"}, {"destination": "stack", "on": true},
				{"comes": "searched"}, back, {}]],
		["an open box filed on edge", {"box_style": "open", "contents": "file"}, "trading",
			[back, {"comes": "searched"}, back, {}]],
		["a shoebox filed on edge", {"box_style": "shoebox", "contents": "file"}, "trading",
			[back, {"comes": "searched"}, {}]],
		["a tin with room for one pile", {"box_style": "open", "contents": "loose"}, "large",
			[{}, back, {}, {}]],
	]
	for s in shows:
		for seed in SEEDS:
			_show(String(s[0]), seed, s[1] as Dictionary, String(s[2]), s[3] as Array)
	_one_pile()
	_control()
	Director.hold(false)
	Director.detach()
	print("box_clip_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	get_tree().quit(1 if _fails > 0 else 0)


## One box show posed frame by frame from its first card to its spread.
func _show(what: String, seed: int, staging: Dictionary, size: String, positions: Array) -> void:
	print("-- %s, seed %d" % [what, seed])
	staging["source"] = "box"
	staging["text"] = "back"
	_load(seed, positions, {"look": {"candles": 0, "card_size": size}, "staging": staging, "deck": _deck(24)},
		String(staging["box_style"]) == "open" and size != "large")
	_ok(String(staging["contents"]) == "file" or size == "large" or medium._box_part.contents() == String(staging["contents"]),
		"the box holds its cards as planned (%s)" % medium._box_part.contents())
	var tm := medium._times()
	var t0 := _at(0, "arrive") - 0.5
	var t1 := float(tm["spread"]) + 2.0
	var c := _clips(t0, t1)
	_ok(int(c["hits"]) == 0, "nothing in the box or out of it passes through a card (%d times, first at %.2f s: %s)" % [
		int(c["hits"]), float(c["first"]), String(c["what"])])
	var looks := _looks(tm)
	if not looks.is_empty():
		var least: float = looks.min()
		_ok(least >= LOOK_LEAST, "each card a search looks at is held to the eye %.2f s at the least (%d looks)" % [least, looks.size()])


## A TIN WITH ROOM FOR ONE PILE: filed on edge, and a card put back goes back into its own place.
func _one_pile() -> void:
	print("-- one pile's room")
	var back := {"destination": "box", "comment": "brief"}
	_load(32533, [{}, back, {}, {}], {"look": {"candles": 0, "card_size": "large"},
		"staging": {"source": "box", "text": "back", "box_style": "open", "contents": "loose"}, "deck": _deck(24)})
	var size := CardTable.card_size(medium._plan.look)
	var plots := TablePositions.box_plots(medium._box_part.stood["inner"], size)
	_ok(plots.x * plots.y == 1 and medium._box_part.contents() == "file" and medium._box_part.filed_on_edge(),
		"a tin with room for one pile, a card put back before another is drawn, files its cards (%s, %d plot)" % [
			medium._box_part.contents(), plots.x * plots.y])
	var own: Transform3D = (medium._box_part.stood["at_k"] as Array)[1]
	var gone: Transform3D = medium._slot_xf(1)
	_ok(gone.origin.distance_to(own.origin) < 0.0005, "the card put back goes back into its own place in the file")
	# the same tin when nothing is put back keeps its loose cards
	_load(32534, [{}, {}, {}, {}], {"look": {"candles": 0, "card_size": "large"},
		"staging": {"source": "box", "text": "back", "box_style": "open", "contents": "loose"}, "deck": _deck(24)})
	_ok(medium._box_part.contents() == "loose", "control: with nothing put back, the same tin keeps its cards loose")


## THE CONTROL: an open tin's card put back, laid instead on top of the pile the last card is drawn from,
## is passed through when that card is pulled out from under it.
func _control() -> void:
	print("-- control")
	var back := {"destination": "box", "comment": "brief"}
	_load(32535, [{}, back, {}, {}, {}], {"look": {"candles": 0, "card_size": "baseball"},
		"staging": {"source": "box", "text": "back", "box_style": "open", "contents": "loose"}, "deck": _deck(24)}, true)
	var stood: Dictionary = medium._box_part.stood
	var last: Transform3D = (stood["at_k"] as Array)[4]
	var kept: Vector3 = stood["return_at"]
	var turn := float(stood["return_turn"])
	stood["return_at"] = last.origin + Vector3(0.0, TableMedium.CARD_T * 1.5, 0.0)
	stood["return_turn"] = atan2(-last.basis.x.z, last.basis.x.x)
	var c := _clips(_at(4, "arrive") - 0.2, _at(4, "arrive") + 3.0)
	stood["return_at"] = kept
	stood["return_turn"] = turn
	_ok(int(c["hits"]) > 0, "control: put back on the pile the last card waits in, it is passed through by that draw (%d times)" % int(c["hits"]))
	# and a look half as long holds a front up too briefly
	_load(42, [{}, {"comes": "searched"}, {}], {"look": {"candles": 0, "card_size": "trading"},
		"staging": {"source": "box", "text": "back", "box_style": "shoebox", "contents": "piles"}, "deck": _deck(24)})
	var looks := _looks(medium._times(), 0.5)
	_ok(not looks.is_empty() and looks.min() < LOOK_LEAST, "control: a look half as long holds a front up %.2f s" % (looks.min() if not looks.is_empty() else 0.0))


## How many times, between [param t0] and [param t1], a card passes through another or lies in one: the
## show's cards, the cards a search looks at (and one lent for a look) and the box's own filed cards.
## `{hits, first, what}`.
func _clips(t0: float, t1: float) -> Dictionary:
	var half := CardTable.card_size(medium._plan.look) * 0.5
	var reach := half.length() * 2.0
	var move: Transform3D = medium._box_part.stood.get("move", Transform3D.IDENTITY)
	var statics: Array = []
	for xf in medium._box_part.stood.get("filed", []):
		statics.append(move * (xf as Transform3D))
	var out := {"hits": 0, "first": INF, "what": ""}
	# below the tops of a file's cards, nothing shows
	var hidden := float(medium._box_part.stood.get("top_y", -INF)) if medium._box_part.contents() == "file" else -INF
	var t := t0
	_posed(t)
	var prev := _cards_now()
	var first := true
	while t < t1:
		t += 1.0 / FPS
		_posed(t)
		var now := _cards_now()
		for a in now.size():
			if prev[a] == null or now[a] == null:
				continue
			var moved := first or not (prev[a] as Transform3D).is_equal_approx(now[a] as Transform3D)
			for b in range(a + 1, now.size()):
				if prev[b] == null or now[b] == null:
					continue
				if not moved and (prev[b] as Transform3D).is_equal_approx(now[b] as Transform3D):
					continue
				if _meets(prev[a], now[a], prev[b], now[b], half, hidden):
					_hit(out, t, "card %d and card %d" % [a, b])
			if not moved:
				continue
			for s in statics:
				var o: Vector3 = (s as Transform3D).origin
				var p: Vector3 = (now[a] as Transform3D).origin
				if Vector2(o.x - p.x, o.z - p.z).length() > reach or absf(o.y - p.y) > reach:
					continue
				if _meets(prev[a], now[a], s, s, half, hidden):
					_hit(out, t, "card %d and a filed card" % a)
		first = false
		prev = now
	return out


func _hit(out: Dictionary, t: float, what: String) -> void:
	out["hits"] = int(out["hits"]) + 1
	if float(out["first"]) == INF:
		out["first"] = t
		out["what"] = what


## Whether card a (from [param fa] to [param ta]) passes through card b ([param fb] to [param tb]) or lies
## in it, a frame apart - either's points over the other's face changing sides of it, or within it - at a
## height over [param hidden].
func _meets(fa: Transform3D, ta: Transform3D, fb: Transform3D, tb: Transform3D, half: Vector2, hidden: float) -> bool:
	return _crosses(fa, ta, fb, tb, half, hidden) or _crosses(fb, tb, fa, ta, half, hidden)


func _crosses(fa: Transform3D, ta: Transform3D, fb: Transform3D, tb: Transform3D, half: Vector2, hidden: float) -> bool:
	var ib := fb.affine_inverse()
	var jb := tb.affine_inverse()
	for gx in [-0.96, 0.0, 0.96]:
		for gz in [-0.96, -0.5, 0.0, 0.5, 0.96]:
			var p := Vector3(float(gx) * half.x, 0.0, float(gz) * half.y)
			if (ta * p).y < hidden:
				continue
			var was: Vector3 = ib * (fa * p)
			var now: Vector3 = jb * (ta * p)
			if absf(was.x) > half.x or absf(was.z) > half.y or absf(now.x) > half.x or absf(now.z) > half.y:
				continue
			if signf(was.y) != signf(now.y) or absf(now.y) < TableMedium.CARD_T * 0.9:
				return true
	return false


## Every card that moves in a box show, as it is now (null when unseen): the drawn cards, the box's cards
## a search looks at, and the card lent for a look.
func _cards_now() -> Array:
	var out: Array = []
	for c in medium._cards:
		out.append((c as MeshInstance3D).transform if (c as MeshInstance3D).visible else null)
	for c in medium._box_part.searched:
		out.append((c as MeshInstance3D).transform if (c as MeshInstance3D).visible else null)
	out.append(medium._rummage_card.transform if medium._rummage_card.visible else null)
	return out


## How long each card a search looks at shows the eye its front, seconds (a look [param scale] as long).
func _looks(tm: Dictionary, scale := 1.0) -> Array:
	var out: Array = []
	for e in tm["rummages"]:
		var span := TableActions.RUMMAGE * float((e as Dictionary)["s"]) * scale
		var n := medium._card_poses.search_looks()
		for i in n:
			var shown := 0
			for step in 200:
				var xf := medium._card_poses.searched_xf(i, float(step) / 199.0)
				if _faces_camera(xf) > 0.7:
					shown += 1
			out.append(float(shown) / 200.0 * span / float(n))
	return out


## How squarely [param xf]'s card shows the camera its FACE (1) or its back (-1).
func _faces_camera(xf: Transform3D) -> float:
	return -xf.basis.y.normalized().dot((medium._plan.cam_base.origin - xf.origin).normalized())


func _deck(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({"key": "d%d" % i, "name": "Deck card %d" % i})
	return out


func _cards(positions: Array) -> Array:
	var out: Array = []
	for i in positions.size():
		out.append({"key": "c%d" % i, "name": "Card %d" % (i + 1), "numeral": "", "reversed": false, "jumper": false,
			"position": positions[i], "booklet": {"keywords": ["Shortstop", "Bats left"], "upright": "A kid with a glove."}, "art": ""})
	return out


## Load [param positions] as an episode, timed as a voice would read it - its cards in the tin
## ([constant TIN]) when [param tin], else in the box the table makes when no set dresser did.
func _load(seed: int, positions: Array, plan: Dictionary, tin := false) -> void:
	var spec := DIR.path_join("table.json")
	if tin:
		var f := FileAccess.open(spec, FileAccess.WRITE)
		f.store_string(JSON.stringify(TIN))
		f.close()
	elif FileAccess.file_exists(spec):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(spec))
	var cards := _cards(positions)
	plan["spread"] = {"positions": positions}
	var passages: Array = []
	for m in TableProducer.choreography(plan, cards):
		passages.append({"kind": m["kind"], "card": m.get("card", 0), "last": m.get("last", m.get("card", 0)),
			"text": "Some words said about it, at an easy pace, for a while." if not String(m.get("say", "")).is_empty() else ""})
	var script := CardReading.compose(passages)
	var doc := {"show": "box-clip-check", "seed": seed, "dir": DIR, "plan": plan, "cards": cards}
	subs.words = load("res://tests/table/table_look_probe.gd").timeline(CardReading.parse(script), 0.36, Director.intro_hold)
	subs.document = {"source": script, "title": "Box Clip Check", "table": doc}
	medium._key = ""
	medium._ensure_doc()
	medium._follow.extend(subs.words)
	medium._sched = medium._follow.place(medium._plan.parse["actions"], maxf(Director.intro_hold, 0.6), TableMedium.LEAD, TableMedium.TAIL)


## When card [param k]'s event of kind [param kind] begins.
func _at(k: int, kind: String) -> float:
	for e in (medium._times()["events"] as Array)[k]:
		if String((e as Dictionary)["k"]) == kind:
			return float((e as Dictionary)["t0"])
	return INF


func _posed(t: float) -> void:
	medium._now = t
	medium._pose(t)
