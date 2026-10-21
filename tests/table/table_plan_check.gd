extends Node

## table_plan_check - THE TABLE'S PLAN IS A FUNCTION OF THE EPISODE ([TablePlan], next/structure.md
## step 24), on fixture episodes of its own: a deck's reading, a jumper's, a long spread that crowds the
## deck, a box's and a shoebox's, a spread whose places are given, and a set dresser's table with
## things written where they stand.
##
##   tests/run_boot_probe.sh tests/table/table_plan_check.gd 600
##
##   - PURE: [method TablePlan.make] on the same (document, table, intro hold) twice gives the same plan,
##     field for field - and on another seed another one, or the comparison sees nothing (the control);
##   - ITS INPUTS ARE ALL IT READS: the intro hold moves the reckoned time of every word (the past a
##     mid-way start is replayed in) and nothing the plan decides - a jumper's held wash is reckoned from
##     the first word, so the hold cancels out of it; and the same episode in another folder with the
##     same table is the same plan, the folder aside;
##   - THE MEDIUM DECIDES NOTHING OF ITS OWN: the plan [method TableMedium._ensure_doc] makes is
##     [method TablePlan.make]'s for the document it was handed, and its camera and the deck's place
##     are the plan's;
##   - PLAYING NEVER WRITES IT: the table posed across the whole show (the shuffle, every draw and lay,
##     the spread) leaves the plan as it was - against the control, one field written, which the
##     comparison must see.
##
## The plan's draws keeping their order (every episode already made plays the show it played) was
## checked when the plan moved out of the medium, by dumping both over 84 episodes; a salt renamed or
## a draw moved re-rolls them, and no gate can tell that from an intended change.

const DIR := "user://table_plan_check"
const SEEDS := 8

const WRITTEN := {"materials": {"wax": {"kind": "wax", "color": "#e8dcc0"}, "brass": {"kind": "metal", "color": "#b48a43"}},
	"things": [
		{"name": "a written pillar", "at": [-40, -20], "turn": 10, "parts": [{"shape": "lathe", "profile": [[0, 0], [2.2, 0], [2.2, 7], [0, 7]], "material": "wax", "wick": true}]},
		{"name": "a zoned book", "place": "left", "turn": 20, "parts": [{"shape": "box", "size": [14, 3, 10], "round": 0.4, "material": "brass"}]},
	]}

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
	var configs := _configs()

	print("pure: the same episode, the same plan")
	var unequal := 0
	var reseeded_same := 0
	var made := 0
	for c in configs:
		for s in range(1, SEEDS + 1):
			var doc := _doc(c, s)
			var json: Variant = c["table"] if c["table"] is Dictionary else null
			var a := _snap(TablePlan.make(doc, json, 0.6))
			var b := _snap(TablePlan.make(doc.duplicate(true), json, 0.6))
			unequal += 0 if a == b else 1
			reseeded_same += 1 if a == _snap(TablePlan.make(_doc(c, s + 100), json, 0.6)) else 0
			made += 1
	_ok(unequal == 0, "made twice, every plan the same (%d of %d not)" % [unequal, made])
	_ok(reseeded_same == 0, "the control: another seed, another plan (%d of %d the same)" % [reseeded_same, made])

	print("its inputs are all it reads")
	var jumper: Dictionary = configs[1]
	var held := 0
	var shifted := 0
	var others := 0
	for s in range(1, 41):
		var doc := _doc(jumper, s)
		var p := TablePlan.make(doc, null, 0.6)
		var q := TablePlan.make(doc, null, 3.6)
		held += 1 if p.wash_held else 0
		# the hold is when the past of a mid-way start is replayed: every word's time moves by it
		var n: int = (p.parse["spoken"] as PackedStringArray).size()
		var a := p.estimated_times(n)
		var b := q.estimated_times(n)
		var by := true
		for j in n:
			by = by and is_equal_approx(b[j] - a[j], 3.0)
		shifted += 1 if by and n > 0 else 0
		var pa := _snap(p)
		var qa := _snap(q)
		pa.erase("hold")
		qa.erase("hold")
		others += 0 if pa == qa else 1
	_ok(shifted == 40, "the intro hold moves every word's reckoned time by itself (%d of 40)" % shifted)
	_ok(held > 0 and others == 0, "...and nothing the plan decides, a jumper's held wash included (%d of 40 changed; %d held)" % [others, held])
	var elsewhere := 0
	for c in configs:
		var doc := _doc(c, 3)
		var there := doc.duplicate(true)
		(there["table"] as Dictionary)["dir"] = DIR.path_join("elsewhere")
		var a := _snap(TablePlan.make(doc, c["table"] if c["table"] is Dictionary else null, 0.6))
		var b := _snap(TablePlan.make(there, c["table"] if c["table"] is Dictionary else null, 0.6))
		a.erase("pay")
		b.erase("pay")
		elsewhere += 0 if a == b else 1
	_ok(elsewhere == 0, "the same episode in another folder is the same plan (%d not)" % elsewhere)

	print("the medium decides nothing of its own; playing never writes the plan")
	var differs := 0
	var off_plan := 0
	var written := 0
	var poses := 0
	for c in configs:
		for s in [2, 5]:
			_write_table(c)
			subs.document = {"source": c["script"], "title": "Plan Check", "table": _doc(c, s)["table"]}
			medium._key = ""
			medium._ensure_doc()
			var json: Variant = c["table"] if c["table"] is Dictionary else null
			var want := _snap(TablePlan.make(subs.document, json, Director.intro_hold))
			var have := _snap(medium._plan)
			if have != want:
				differs += 1
				for k in want:
					if have.get(k) != want[k]:
						print("    %s seed %d: %s differs" % [c["label"], s, k])
			off_plan += 0 if medium._cam.transform.is_equal_approx(medium._plan.cam_base) and is_equal_approx(medium._cam.fov, medium._plan.fov) \
				and medium._cur_base.is_equal_approx(medium._plan.mid) else 1
			# the whole show: the shuffle, each draw and lay, the spread, as the voice's words land
			medium._sched = medium._follow.place(medium._plan.parse["actions"], maxf(Director.intro_hold, 0.6), TableMedium.LEAD, TableMedium.TAIL)
			var t := 0.0
			while t < 90.0:
				medium._pose(t)
				poses += 1
				t += 1.7
			written += 0 if _snap(medium._plan) == have else 1
	_ok(differs == 0, "the medium's plan is TablePlan.make's for the document it was handed (%d not)" % differs)
	_ok(off_plan == 0, "its camera and the deck's place are the plan's (%d not)" % off_plan)
	_ok(written == 0, "posed %d times across the show, no plan written (%d were)" % [poses, written])
	var control := _snap(medium._plan)
	medium._plan.slots[0] = {"pos": Vector3(9, 9, 9), "yaw": 0.0}
	_ok(_snap(medium._plan) != control, "the control: one field written, and the comparison sees it")

	_clear()
	print("table_plan_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## The fixture episodes: a label, a reading, how many cards, the plan's staging, and the set dresser's
## table (a Dictionary), the spread's places given ("given"), or none.
func _configs() -> Array:
	var plain := CardReading.compose([{"kind": "shuffle", "card": 0, "text": "Shuffle the deck."},
		{"kind": "draw", "card": 1, "text": "One."}, {"kind": "draw", "card": 2, "text": "Two."},
		{"kind": "draw", "card": 3, "text": "Three."}, {"kind": "spread", "card": 0, "text": "Done."}])
	var jumper := CardReading.compose([{"kind": "shuffle", "card": 0, "text": "Shuffle the deck, and shuffle it for a long while, as the voice goes on and on."},
		{"kind": "jumper", "card": 1, "text": "One jumped."}, {"kind": "draw", "card": 2, "text": "Two."},
		{"kind": "draw", "card": 3, "text": "Three."}, {"kind": "spread", "card": 0, "text": "Done."}])
	var boxed := CardReading.compose([{"kind": "open", "card": 0, "text": "Open the box."},
		{"kind": "draw", "card": 1, "text": "One."}, {"kind": "draw", "card": 2, "text": "Two."},
		{"kind": "draw", "card": 3, "text": "Three."}, {"kind": "spread", "card": 0, "text": "Done."}])
	var long := [{"kind": "shuffle", "card": 0, "text": "Shuffle."}]
	for i in 7:
		long.append({"kind": "draw", "card": i + 1, "text": "Card %d." % (i + 1)})
	long.append({"kind": "spread", "card": 0, "text": "Done."})
	return [
		{"label": "deck", "script": plain, "n": 3, "plan": {}, "table": null},
		{"label": "jumper", "script": jumper, "n": 3, "plan": {}, "table": null},
		{"label": "seven", "script": CardReading.compose(long), "n": 7, "plan": {}, "table": null},
		{"label": "box", "script": boxed, "n": 3, "plan": {"staging": {"source": "box"}}, "table": null},
		{"label": "shoebox", "script": boxed, "n": 3, "plan": {"staging": {"source": "box", "box_style": "shoebox", "contents": "piles"}}, "table": null},
		{"label": "given", "script": plain, "n": 3, "plan": {}, "table": "given"},
		{"label": "written", "script": plain, "n": 3, "plan": {}, "table": WRITTEN},
	]


## The document the panel would hand the medium for fixture [param c] on seed [param seed].
func _doc(c: Dictionary, seed: int) -> Dictionary:
	var cards: Array = []
	for i in int(c["n"]):
		var pos := {}
		if c["table"] is String and c["table"] == "given":
			pos = {"name": "P%d" % i, "x": -0.12 + 0.12 * i, "z": -0.1, "yaw": 3.0 * i}
		cards.append({"key": "c%d" % i, "name": "Card %d" % i, "numeral": str(i), "reversed": i == 1,
			"jumper": false, "position": pos, "booklet": {}, "art": ""})
	return {"source": c["script"], "title": "Plan Check", "table": {"show": "plan-check", "seed": seed,
		"dir": DIR.path_join(String(c["label"])), "plan": (c["plan"] as Dictionary).duplicate(true), "cards": cards}}


## Fixture [param c]'s `table.json`, where the medium reads it - or none.
func _write_table(c: Dictionary) -> void:
	var dir := DIR.path_join(String(c["label"]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var tf := dir.path_join("table.json")
	if c["table"] is Dictionary:
		var f := FileAccess.open(tf, FileAccess.WRITE)
		f.store_string(JSON.stringify(c["table"]))
		f.close()
	elif FileAccess.file_exists(tf):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tf))


## A plan, field by field, as text: what two plans are compared by.
func _snap(p: TablePlan) -> Dictionary:
	var out := {}
	for prop in p.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out[String(prop["name"])] = var_to_str(p.get(String(prop["name"])))
	return out


func _clear() -> void:
	var root := DirAccess.open(DIR)
	if root == null:
		return
	for sub in root.get_directories():
		var da := DirAccess.open(DIR.path_join(sub))
		for fn in da.get_files():
			da.remove(fn)
		root.remove(sub)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
