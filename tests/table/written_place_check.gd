extends Node

## THINGS STAND WHERE THE SET DRESSER WROTE THEM (the user, 2026-10-18: "do the planning and desired
## placements up-front, then verify with screenshots at the end"). A thing with an `at` is stood by
## [method TableMedium._stand_at], not hunted for in a zone; over several seeds, on a fixture of its own:
##
##   - a thing whose written spot is clear stands EXACTLY there, turned and sized as written - no hand's
##     jitter; one moved was moved for a reason that is real: its written foot runs off the top, into
##     where the cards go, into another thing, or is a flame in front of the middle (the control: each
##     move's written foot is tested by the gate's own geometry, and must hit one of those);
##   - a thing written across the edge of the cards' room is moved out of it, no further than it must
##     go (control: its written foot overlaps the room), and its reason names the cards;
##   - a thing written on top of another stands beside it, never in it (control: the written feet overlap);
##   - a flame written in front of the middle is moved behind it (control: it was written in front);
##   - a thing written deep in the cards' room finds no spot within [constant CardTable.NUDGE_MOST] and is
##     left off, kept in the blueprint's `unstood` with where it was written and why;
##   - a thing with no `at` still finds a spot in its zone, clear of every written thing;
##   - a crowded table - 28 small things written in rows round the back and sides - stands nearly whole;
##   - the blueprint ([method TableMedium.blueprint]) holds every stood thing, its written spot and move,
##     the spread's cards, where nothing may stand, the camera; and the drawing ([method TableBlueprint.view])
##     fits every thing.
##
##   tests/run_boot_probe.sh tests/table/written_place_check.gd 300
##
## A BOOT probe (the medium reaches the Director); no GPU needed - placement is geometry.

const DIR := "user://written_place_check"
const SEEDS := 6

var _fails := 0
var medium: TableMedium
var subs: Subtitles
var _script := ""


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


static func _box(name: String, size: Array, at: Variant = null, turn := 0.0, scale := 1.0) -> Dictionary:
	var out := {"name": name, "parts": [{"shape": "box", "size": size, "material": "wood"}], "turn": turn, "scale": scale}
	if at != null:
		out["at"] = at
	return out


static func _candle(name: String, at: Array) -> Dictionary:
	return {"name": name, "at": at, "parts": [{"shape": "lathe", "profile": [[0, 0], [2.2, 0], [2.2, 7], [0, 7]], "material": "wax", "wick": true}]}


const MATERIALS := {"wood": {"kind": "wood", "color": "#6a4a2a"}, "wax": {"kind": "wax", "color": "#e8dcc0"}}


func _run() -> void:
	_fixture()
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
	_script = CardReading.compose([{"kind": "shuffle", "card": 0, "text": "Shuffle the deck."},
		{"kind": "draw", "card": 1, "text": "One."}, {"kind": "draw", "card": 2, "text": "Two."},
		{"kind": "draw", "card": 3, "text": "Three."}, {"kind": "spread", "card": 0, "text": "Done."}])

	var n := {"exact": 0, "exact_clear": 0, "written": 0, "moved": 0, "moved_real": 0, "jitter": 0, "edge_out": 0, "edge_ok": 0, "edge_far": 0,
		"edge_hit": 0, "edge_cards": 0, "on_ok": 0, "on_hit": 0, "on_named": 0, "flame_ok": 0, "flame_front": 0, "deep_off": 0, "deep_hit": 0,
		"zone_ok": 0, "crowd": 0, "crowd_of": 0, "print_ok": 0, "touching": 0}
	for s in range(1, SEEDS + 1):
		# a first build, to learn where this seed's cards go
		_build(s, {"materials": MATERIALS, "things": []})
		var mid: Vector3 = medium._plan.mid
		var room: Rect2 = medium._shuffle_rect()
		var away := -signf(medium._deck_base.x) if absf(medium._deck_base.x) > 0.01 else -1.0
		var cm := func(p: Vector2) -> Array: return [(p.x - Tables.ORIGIN.x) * 100.0, (p.y - Tables.ORIGIN.y) * 100.0]
		var edge_at := Vector2(room.get_center().x, room.position.y)
		var flame_at := Vector2(mid.x + away * 0.45, mid.z + 0.03)
		var things: Array = [
			_box("a ledger", [14, 3, 10], [-42.0, -26.0], 25.0),
			_box("a tin", [5, 4, 5], [44.0, -28.0], -40.0, 1.5),
			_box("a block", [8, 6, 8], [-46.0, -14.0]),
			# across the back edge of the cards' room
			_box("a dish", [6, 2, 6], cm.call(edge_at)),
			# on top of the ledger, written second
			_box("a stone", [5, 3, 5], [-42.0, -26.0]),
			_candle("a pillar", cm.call(flame_at)),
			# deep in the cards' room
			_box("a crate", [10, 5, 10], cm.call(room.get_center())),
			# no spot written: its zone's
			{"name": "a bottle", "place": "back right", "parts": [{"shape": "box", "size": [4, 8, 4], "material": "wood"}]},
		]
		_build(s, {"materials": MATERIALS, "things": things})
		var stood := {}
		for th in medium._things:
			stood[String((th as Dictionary)["name"])] = th
		var keep: Array = medium._keep_out()
		for t in things:
			var d: Dictionary = t
			if not d.has("at") or not stood.has(String(d["name"])):
				continue
			var th: Dictionary = stood[String(d["name"])]
			var node: Node3D = th["node"]
			var want := Tables.ORIGIN + Vector2(float(d["at"][0]), float(d["at"][1])) * 0.01
			n["written"] += 1
			var yaw := atan2(-node.transform.basis.x.z, node.transform.basis.x.x)
			var k := node.transform.basis.get_scale().x
			if absf(angle_difference(yaw, deg_to_rad(float(d.get("turn", 0.0))))) > 0.001 or absf(k - float(d.get("scale", 1.0))) > 0.001:
				n["jitter"] += 1
			var at := Vector2(node.position.x, node.position.z)
			if at.distance_to(want) < 0.001:
				n["exact"] += 1
				n["exact_clear"] += 0 if _hits(th["outline"], keep, th, false) else 1
			else:
				n["moved"] += 1
				# the gate's own geometry: the written foot must really hit something
				var foot: PackedVector2Array = TableMedium._translated(th["outline"], want - at)
				if _hits(foot, keep, th, int(th["lit"]) > 0 and want.y > mid.z):
					n["moved_real"] += 1
		# ACROSS THE CARDS' ROOM: out of it, no further than it must go
		var dish: Dictionary = stood.get("a dish", {})
		if not dish.is_empty():
			var at := Vector2((dish["node"] as Node3D).position.x, (dish["node"] as Node3D).position.z)
			n["edge_ok"] += 1 if not _hits(dish["outline"], keep, dish, false) and not _hits_room(dish["outline"], keep) else 0
			n["edge_far"] += _nearer_clear(dish, edge_at, keep)
			n["edge_hit"] += 1 if _hits(TableMedium._translated(dish["outline"], edge_at - at), keep, {}, false) else 0
			n["edge_cards"] += 1 if String(dish["why"]).contains("cards") else 0
		else:
			n["edge_out"] += 1
		# ON ANOTHER: beside it, never in it
		var stone: Dictionary = stood.get("a stone", {})
		var ledger: Dictionary = stood.get("a ledger", {})
		if not stone.is_empty() and not ledger.is_empty():
			n["on_ok"] += 1 if not TableMedium._convex_overlap(stone["outline"], ledger["outline"], 0.0) else 0
			var was := TableMedium._translated(stone["outline"], Tables.ORIGIN + Vector2(-0.42, -0.26) - Vector2((stone["node"] as Node3D).position.x, (stone["node"] as Node3D).position.z))
			n["on_hit"] += 1 if TableMedium._convex_overlap(was, ledger["outline"], 0.0) else 0
			n["on_named"] += 1 if String(stone["why"]).contains("a ledger") else 0
		# A FLAME IN FRONT OF THE MIDDLE goes behind it
		var pillar: Dictionary = stood.get("a pillar", {})
		if not pillar.is_empty():
			n["flame_ok"] += 1 if (pillar["node"] as Node3D).position.z <= mid.z + 1e-4 else 0
			n["flame_front"] += 1 if flame_at.y > mid.z else 0
		# DEEP IN THE CARDS' ROOM: left off, and the blueprint says where it was written and why
		var bp: Dictionary = medium.blueprint()
		for u in bp["unstood"]:
			if String((u as Dictionary)["name"]) == "a crate" and ((u as Dictionary)["written"] as Vector2).distance_to(room.get_center()) < 0.001 \
					and String((u as Dictionary)["why"]).contains("cards"):
				n["deep_off"] += 1
		n["deep_hit"] += 1 if room.has_point(room.get_center()) and not stood.has("a crate") else 0
		# A ZONE'S THING among written ones
		var bottle: Dictionary = stood.get("a bottle", {})
		if not bottle.is_empty() and bottle.get("written") == null:
			var clear := true
			for other in medium._things:
				if other != bottle and TableMedium._convex_overlap(bottle["outline"], (other as Dictionary)["outline"], 0.0):
					clear = false
			n["zone_ok"] += 1 if clear else 0
		# THE BLUEPRINT holds what stood, and the drawing fits it
		var fits := (bp["things"] as Array).size() == medium._things.size() and (bp["cards"] as Array).size() == (medium._plan.slots as Array).size() \
			and not (bp["keep_out"] as Array).is_empty() and bp["camera"] is Transform3D
		for t in bp["things"]:
			if String((t as Dictionary)["name"]) == "a stone":
				fits = fits and (t as Dictionary)["written"] is Vector2 and float((t as Dictionary)["moved"]) > 0.0
		var v := TableBlueprint.view(bp)
		var room_px: Rect2 = v["room"]
		for t in bp["things"]:
			var bb: Rect2 = (t as Dictionary)["bb"]
			fits = fits and room_px.grow(1.0).has_point(TableBlueprint._to_px(v, bb.position)) and room_px.grow(1.0).has_point(TableBlueprint._to_px(v, bb.end))
		n["print_ok"] += 1 if fits else 0
		# A CROWDED TABLE: rows of small things round the back and the sides
		var crowd: Array = []
		for i in 14:
			crowd.append(_box("back %d" % i, [4, 3, 4], [-52.0 + i * 8.0, -30.0], i * 13.0))
		for i in 7:
			crowd.append(_box("left %d" % i, [4, 5, 4], [-50.0, -24.0 + i * 6.0]))
			crowd.append(_box("right %d" % i, [4, 5, 4], [50.0, -24.0 + i * 6.0]))
		_build(s, {"materials": MATERIALS, "things": crowd})
		n["crowd"] += medium._things.size()
		n["crowd_of"] += crowd.size()
		for i in medium._things.size():
			for j in range(i + 1, medium._things.size()):
				if TableMedium._convex_overlap((medium._things[i] as Dictionary)["outline"], (medium._things[j] as Dictionary)["outline"], 0.0):
					n["touching"] += 1
	print(n)
	_ok(n["written"] >= SEEDS * 6 and n["exact"] >= n["written"] - SEEDS * 3, "a clear written spot is where a thing stands (%d of %d exactly where written)" % [n["exact"], n["written"]])
	_ok(n["exact_clear"] == n["exact"], "control: every thing that stood where written stood clear (%d of %d)" % [n["exact_clear"], n["exact"]])
	_ok(n["jitter"] == 0, "every written thing turned and sized as written (%d not)" % n["jitter"])
	_ok(n["moved"] > 0 and n["moved_real"] == n["moved"], "every move was for a real reason (%d of %d) - and some were made" % [n["moved_real"], n["moved"]])
	_ok(n["edge_out"] == 0 and n["edge_ok"] == SEEDS and n["edge_far"] == 0, "a thing across the cards' room is moved out of it, no further than it must (%d clear, %d nearer spots were clear, %d left off)"
		% [n["edge_ok"], n["edge_far"], n["edge_out"]])
	_ok(n["edge_hit"] == SEEDS and n["edge_cards"] == SEEDS, "control: its written spot was in the cards' room, and its reason says so (%d, %d)" % [n["edge_hit"], n["edge_cards"]])
	_ok(n["on_ok"] == SEEDS and n["on_named"] == SEEDS, "a thing written on another stands beside it, the other named (%d, %d)" % [n["on_ok"], n["on_named"]])
	_ok(n["on_hit"] == SEEDS, "control: written where it was, it stood in the other (%d)" % n["on_hit"])
	_ok(n["flame_ok"] == SEEDS and n["flame_front"] == SEEDS, "a flame written in front of the middle stands behind it (%d; control %d written in front)" % [n["flame_ok"], n["flame_front"]])
	_ok(n["deep_off"] == SEEDS and n["deep_hit"] == SEEDS, "a thing deep in the cards' room is left off, the blueprint saying where and why (%d)" % n["deep_off"])
	_ok(n["zone_ok"] == SEEDS, "a thing with no written spot still finds one, clear of the written (%d)" % n["zone_ok"])
	_ok(n["print_ok"] == SEEDS, "the blueprint holds every stood thing, and the drawing fits it (%d)" % n["print_ok"])
	_ok(n["crowd"] >= int(n["crowd_of"] * 0.9) and n["touching"] == 0, "a crowded table stands nearly whole, nothing in anything (%d of %d, %d touching)"
		% [n["crowd"], n["crowd_of"], n["touching"]])
	Director.hold(false)
	Director.detach()
	_clear()
	print("written_place_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## The table for seed [param s] with [param table] as its set dresser's.
func _build(s: int, table: Dictionary) -> void:
	var f := FileAccess.open(DIR.path_join("table.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(table))
	f.close()
	var cards: Array = []
	for i in 3:
		cards.append({"key": "c%d" % i, "name": "Card %d" % i, "numeral": str(i), "reversed": false,
			"jumper": false, "position": {}, "booklet": {}, "art": ""})
	var doc := {"show": "written-check", "seed": s, "dir": DIR, "images": {"surface": DIR.path_join("surface.png")},
		"plan": {"look": {"candles": 1}}, "cards": cards}
	subs.document = {"source": _script, "title": "Written Check", "table": doc}
	medium._key = ""
	medium._ensure_doc()


## How many spots nearer [param written] than [param th] was moved to would have been clear for it, on a
## grid as fine as the nudge's step (none, when it went no further than it must). Only what stood before it
## counts - here, the cards' room and the table's edge, the things before it standing far off.
func _nearer_clear(th: Dictionary, written: Vector2, keep: Array) -> int:
	var at := Vector2((th["node"] as Node3D).position.x, (th["node"] as Node3D).position.z)
	var reach := at.distance_to(written) - 2.0 * TableMedium.NUDGE_STEP
	var step := TableMedium.NUDGE_STEP
	var out := 0
	var y := -reach
	while y <= reach:
		var x := -reach
		while x <= reach:
			if Vector2(x, y).length() <= reach:
				var foot := TableMedium._translated(th["outline"], written + Vector2(x, y) - at)
				if not _hits_room(foot, keep):
					out += 1
			x += step
		y += step
	return out


func _hits_room(foot: PackedVector2Array, keep: Array) -> bool:
	for q in foot:
		if Tables.sdf(medium._top_o, q) > -Tables.THING_EDGE:
			return true
	for r in keep:
		if TableMedium._convex_overlap(foot, TableMedium._rect_poly(r as Rect2), 0.0):
			return true
	return false


## Whether [param foot] may not stand: off the top, where the cards go, in another stood thing (not
## [param self]), or [param flame_front].
func _hits(foot: PackedVector2Array, keep: Array, self_: Dictionary, flame_front: bool) -> bool:
	if flame_front:
		return true
	for q in foot:
		if Tables.sdf(medium._top_o, q) > -Tables.THING_EDGE:
			return true
	for r in keep:
		if TableMedium._convex_overlap(foot, TableMedium._rect_poly(r as Rect2), 0.0):
			return true
	for th in medium._things:
		if th != self_ and String((th as Dictionary)["name"]) != String(self_.get("name", "")) \
				and TableMedium._convex_overlap(foot, (th as Dictionary)["outline"], TableMedium.WRITTEN_GAP):
			return true
	return false


func _fixture() -> void:
	_clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var surf := Image.create(256, 160, false, Image.FORMAT_RGB8)
	surf.fill(Color(0.3, 0.12, 0.14))
	surf.save_png(DIR.path_join("surface.png"))


func _clear() -> void:
	var da := DirAccess.open(DIR)
	if da == null:
		return
	for fn in da.get_files():
		da.remove(fn)
