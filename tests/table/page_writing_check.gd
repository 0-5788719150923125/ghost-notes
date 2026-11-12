extends SceneTree

## The gate of a page written at the table ([TableInk], [SheetWriting.page], the `write` law; next/proof.md): which writes TeX lays out,
## how a record is written stroke by stroke, how a sheet's writes become a page, and the order a page is written in. No renderer, no
## TeX: the records are TeX's own answer, kept as the ink gate's fixture (tests/table/ink_layout.json).
##
##   godot --headless --path . --script res://tests/table/page_writing_check.gd
##
## - Which writes TeX lays out: a `tex` (math, or a display environment set as one), a `draw` (a figure) and words with `$...$` in them,
##   each once whatever acts repeat it; words with no math never (the control).
## - A record is written as a hand writes it: the picture has ink, every point of it put down between 0 and 0.98, and a formula is
##   written left to right (the left third's ink is put down before the right third's) - the control, a record with no glyphs, has none.
## - A sheet's writes are a page: the first write's ink is put down in the first half of the page's time and the second's in the
##   second; a few writes fit a sheet at their own size, and many run off it and are written smaller, said (`shrunk` - the control:
##   two writes are not). A line crossed out is drawn through the line it names, in its own share of the page's time, and takes no
##   room (the control: a strike at nothing draws nothing). Words in a hand are the hand's strokes ([Handwriting]) inside their line's
##   box, for a pen to follow; a typewriter's are set, with none (the control).
## - The law takes a formula and a drawing: `tex` and `draw` are kept; a `draw` that is no SVG is refused with a note; a write that
##   names nothing is refused (the control).
## - A page is written in the reading's order ([method TableWork._order_writing]): writes on one sheet, listed out of order, are
##   numbered by beat - the intro's first - each taking its share of the sheet's `written`; one write of plain words is the sheet's
##   alone (the control), fitted to it.
## - A pen seen writes it, and points: a write `with` a pen on a real table has the pen's tip on the ink as it goes down - on a
##   stroke, on the paper, inside the line's box - lifted before the first stroke and clear after the last; a `point` at the line
##   brings the tip beside its right end, just over the paper. Controls: a pen nobody put on the table, and a point at a name nothing
##   written carries, are refused, the names that can be pointed at said.

var _fails := 0
var _doc := {}


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	await process_frame
	_doc = JSON.parse_string(FileAccess.get_file_as_string("res://tests/table/ink_layout.json"))
	for check in [_items, _record, _page, _law, _order, _pen]:
		var done: Variant = (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("page_writing_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _rec(id: String) -> Dictionary:
	for r in _doc["items"]:
		if String((r as Dictionary).get("id", "")) == id:
			return r
	return {}


func _items() -> bool:
	var acts := {"acts": [
		{"name": "a", "beat": 1, "tracks": [{"law": "write", "tex": "a^2 + b^2 = c^2"}, {"law": "write", "text": "Suppose $p$ is prime."}]},
		{"name": "b", "beat": 2, "tracks": [{"law": "write", "tex": "\\begin{align*} x &= 1 \\end{align*}"},
			{"law": "write", "draw": "<svg viewBox=\"0 0 360 100\"><line x1=\"0\" y1=\"0\" x2=\"10\" y2=\"10\"/></svg>"},
			{"law": "write", "tex": "a^2 + b^2 = c^2"}, {"law": "write", "text": "Milk and eggs"}, {"law": "carry", "thing": "jar"}]}]}
	var items := TableInk.items_of(acts)
	var modes: Array = items.map(func(i: Dictionary) -> String: return String(i["mode"]))
	_ok(modes == ["math", "text", "display", "figure"], "a formula, words with math, a display and a drawing, each once (%s)" % str(modes))
	_ok(not items.any(func(i: Dictionary) -> bool: return String(i["tex"]).contains("Milk")), "CONTROL: words with no math are never TeX's")
	_ok(TableInk.item("tex", "x")["id"] == TableInk.item("tex", "x")["id"] and TableInk.item("tex", "x")["id"] != TableInk.item("text", "x")["id"],
		"an item's id is what it is: the same write the same id, another kind another")
	return true


func _record() -> bool:
	var rec := _rec("logic")
	var got := TableInk.picture_of(rec, 7, 4.0, _doc.get("fonts", {}))
	var img: Image = got["image"]
	var inked := 0
	var bad := 0
	var left := [0.0, 0]
	var right := [0.0, 0]
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r <= 0.0:
				continue
			inked += 1
			if c.g < 0.0 or c.g > 0.981:
				bad += 1
			if x < img.get_width() / 3:
				left = [float(left[0]) + c.g, int(left[1]) + 1]
			elif x > img.get_width() * 2 / 3:
				right = [float(right[0]) + c.g, int(right[1]) + 1]
	_ok(inked > 200 and bad == 0, "a record written has ink, every point put down between 0 and 0.98 (%d inked, %d out)" % [inked, bad])
	var lt := float(left[0]) / maxf(float(left[1]), 1.0)
	var rt := float(right[0]) / maxf(float(right[1]), 1.0)
	_ok(int(left[1]) > 0 and int(right[1]) > 0 and lt < rt, "a formula is written left to right (%.2f before %.2f)" % [lt, rt])
	var empty := TableInk.picture_of({"id": "none", "w": 20.0, "h": 8.0, "d": 2.0, "glyphs": [], "rules": []}, 7, 4.0)
	var any := false
	var e: Image = empty["image"]
	for y in e.get_height():
		for x in e.get_width():
			any = any or e.get_pixel(x, y).r > 0.0
	_ok(not any, "CONTROL: a record with nothing in it writes no ink")
	return true


func _page() -> bool:
	var room := Vector2(0.16, 0.22)
	var pic := SheetWriting.page([{"rec": _rec("pyth")}, {"rec": _rec("sum")}], room, 7, _doc.get("fonts", {}))
	var img: Image = pic["image"]
	var first := 0
	var second := 0
	var stray := 0
	var half := img.get_height() / 2
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r <= 0.0:
				continue
			if c.g < 0.5:
				first += 1
				stray += 1 if y > half else 0
			else:
				second += 1
	_ok(first > 0 and second > 0, "the first write is put down in the first half of the page's time, the second in the second (%d, %d)" % [first, second])
	_ok(stray == 0, "the first write is the page's head: none of its ink is low on the page (%d)" % stray)
	_ok(not bool(pic["shrunk"]) and float(pic["sharp"]) == SheetWriting.SHARP * 2.0, "two writes fit at their own size, the pen's front twice as sharp")
	var many: Array = []
	for i in 30:
		many.append({"rec": _rec("big")})
	_ok(bool(SheetWriting.page(many, room, 7, _doc.get("fonts", {}))["shrunk"]), "thirty writes run off a sheet and are written smaller, said")
	var struck := SheetWriting.page([{"rec": _rec("pyth")}, {"rec": _rec("sum")}, {"strike": 0}], room, 7, _doc.get("fonts", {}))
	var line: Dictionary = (struck["layout"]["items"] as Array)[0]
	var sim: Image = struck["image"]
	var late := 0
	var off_line := 0
	for y in sim.get_height():
		for x in sim.get_width():
			var c := sim.get_pixel(x, y)
			if c.r > 0.5 and c.g >= 2.0 / 3.0:
				late += 1
				var p := Vector2(float(x), float(y)) / (float(sim.get_width()) / (struck["layout"]["pt"] as Vector2).x)
				if p.y < float(line["y"]) - 1.0 or p.y > float(line["y"]) + float(line["h"]) + 1.0:
					off_line += 1
	_ok(late > 20 and off_line == 0, "a line crossed out is drawn through the line it names, last (%d inked, %d off it)" % [late, off_line])
	var nowhere := SheetWriting.page([{"rec": _rec("pyth")}, {"strike": -1}], room, 7, _doc.get("fonts", {}))
	var any_late := false
	for y in (nowhere["image"] as Image).get_height():
		for x in (nowhere["image"] as Image).get_width():
			var c := (nowhere["image"] as Image).get_pixel(x, y)
			any_late = any_late or (c.r > 0.5 and c.g >= 0.5)
	_ok(not any_late, "CONTROL: a strike at nothing draws nothing")
	var words := SheetWriting.page([{"text": "Milk and eggs", "hand": "neat"}, {"rec": _rec("frac")}], room, 7, _doc.get("fonts", {}))
	_ok((words["image"] as Image).get_width() > 2, "words in a hand and a formula share a page")
	# Words a pen writes are the hand's strokes ([Handwriting]), for a pen to follow, inside their box; a typewriter's are set
	var laid: Dictionary = ((words["layout"] as Dictionary)["items"] as Array)[0]
	var inside := true
	for st in laid["strokes"]:
		for q in (st as Dictionary)["points"] as PackedVector2Array:
			var at := q + Vector2(float(laid["ox"]), float(laid["oy"]))
			inside = inside and Rect2(float(laid["x"]) - 1.0, float(laid["y"]) - 1.0, float(laid["w"]) + 2.0, float(laid["h"]) + 4.0).has_point(at)
	_ok(not (laid["strokes"] as Array).is_empty() and inside, "words in a hand are written in the hand's strokes, inside their line's box (%d strokes)" % (laid["strokes"] as Array).size())
	var typed := SheetWriting.page([{"text": "Milk and eggs", "hand": "typed"}], room, 7)
	_ok((((typed["layout"] as Dictionary)["items"] as Array)[0]["strokes"] as Array).is_empty(), "CONTROL: a typewriter's words are set, with no strokes")
	var block := SheetWriting.words("Two lines\nof words", "quick", 3, 1.0, 0.0, true)
	_ok(int(block["lines"]) == 2 and float(block["seconds"]) > 0.5, "a hand's own lines stay its lines, written over time (%d lines, %.1f s)" % [int(block["lines"]), float(block["seconds"])])
	return true


func _law() -> bool:
	var notes := PackedStringArray()
	var tex := Motions.sanitize_law({"law": "write", "tex": "a^2 + b^2 = c^2"}, notes)
	_ok(String(tex.get("tex", "")) == "a^2 + b^2 = c^2" and String(tex.get("state", "")) == "written", "a write takes a formula (%s)" % str(tex))
	var svg := "<svg viewBox=\"0 0 360 100\"><line x1=\"0\" y1=\"0\" x2=\"10\" y2=\"10\"/></svg>"
	_ok(String(Motions.sanitize_law({"law": "write", "draw": svg}, notes).get("draw", "")) == svg, "a write takes a drawing")
	notes = PackedStringArray()
	_ok(Motions.sanitize_law({"law": "write", "draw": "a tree"}, notes).is_empty() and not notes.is_empty(), "a drawing that is no SVG is refused, said")
	_ok(String(Motions.sanitize_law({"law": "write", "strike": "first"}, PackedStringArray()).get("strike", "")) == "first", "a write may cross out an earlier one")
	notes = PackedStringArray()
	_ok(Motions.sanitize_law({"law": "write"}, notes).is_empty() and not notes.is_empty(), "CONTROL: a write that names nothing is refused")
	return true


func _order() -> bool:
	var work := TableWork.new()
	var sheet := {"w": 0.21, "l": 0.297, "outline": "rect"}
	work.works = [{"w": {"sheet": sheet}, "name": "page"}, {"w": {"sheet": sheet}, "name": "slip"}]
	var later := {"law": "write", "_wi": 0, "text": "", "tex": "a^2 + b^2 = c^2", "hand": "neat", "ink": "#2b2b2b", "value": 1.0}
	var sooner := {"law": "write", "_wi": 0, "text": "The question", "hand": "neat", "ink": "#2b2b2b", "value": 1.0}
	var alone := {"law": "write", "_wi": 1, "text": "Salt", "hand": "neat", "ink": "#2b2b2b", "value": 1.0}
	work.acts = [{"name": "later", "beat": 2, "tracks": [later]}, {"name": "slip", "beat": 1, "tracks": [alone]},
		{"name": "sooner", "beat": "intro", "tracks": [sooner]}]
	work.ink_doc = {"items": [_rec_as(TableInk.item("tex", "a^2 + b^2 = c^2"), "pyth")], "fonts": _doc.get("fonts", {})}
	work._order_writing()
	_ok(is_equal_approx(float(sooner["value"]), 0.5) and is_equal_approx(float(later["value"]), 1.0),
		"writes on one sheet are written in the reading's order, the intro's first (%s, %s)" % [sooner["value"], later["value"]])
	_ok((work._writing[0] as Dictionary).has("page"), "two writes on a sheet are a page")
	_ok(not (work._writing[1] as Dictionary).has("page") and is_equal_approx(float(alone["value"]), 1.0),
		"CONTROL: one write of plain words is the sheet's alone, fitted to it")
	_ok(TableWork._beat_rank("intro") < TableWork._beat_rank(1) and TableWork._beat_rank(1) < TableWork._beat_rank("2") \
		and TableWork._beat_rank("2") < TableWork._beat_rank("close"), "the intro comes first, the close last, a beat in its place")
	return true


## TeX's record [param id] of the fixture, as the record of item [param it].
func _rec_as(it: Dictionary, id: String) -> Dictionary:
	var r := _rec(id).duplicate(true)
	r["id"] = String(it["id"])
	return r


## A medium with no stage, as far as [TableWork] reads one (table_work_check's).
static func _medium() -> TableMedium:
	var m := TableMedium.new()
	m._root3 = Node3D.new()
	m._props = Node3D.new()
	m._root3.add_child(m._props)
	m._wind = {}
	return m


static func _stand(m: TableMedium, spec: Dictionary, name: String, at: Vector3) -> Dictionary:
	var safe := Props.sanitize(spec, [])
	var thing: Dictionary = {}
	for t in safe["things"]:
		if String((t as Dictionary)["name"]) == name:
			thing = t
	var b := Props.build(thing, safe["materials"], 5)
	var node: Node3D = b["node"]
	node.transform = Transform3D(Basis.IDENTITY, at)
	m._props.add_child(node)
	m._work.take(thing, b, node)
	return {"node": node, "built": b, "thing": thing}


func _pen() -> bool:
	var m := _medium()
	var spec := {"things": [
		{"name": "desk", "parts": [{"shape": "box", "size": [40, 2, 30], "material": "wood"},
			{"name": "page", "shape": "sheet", "outline": "rect", "size": [21, 28], "material": "paper", "at": [0, 2.0, 0], "joint": {"kind": "free"}}]},
		{"name": "pen", "parts": [{"shape": "lathe", "profile": [[0, 0], [0.45, 1.2], [0.5, 14], [0, 14]], "material": "lacquer"}]}],
		"materials": {"wood": {"kind": "wood", "color": "#6a4a2a"}, "paper": {"kind": "paper", "color": "#f3eedd"},
			"lacquer": {"kind": "plastic", "color": "#1d2b4a"}}}
	_stand(m, spec, "desk", Vector3(0.0, 0.0, 0.0))
	var pen_node: Node3D = _stand(m, spec, "pen", Vector3(0.18, 0.02, 0.05))["node"]
	m._work.ink_doc = {"items": [_rec_as(TableInk.item("tex", "a^2 + b^2 = c^2"), "pyth")], "fonts": _doc.get("fonts", {})}
	m._work.build({"acts": [
		{"name": "write-it", "beat": 1, "length": 6, "tracks": [{"thing": "desk", "part": "page", "law": "write", "tex": "a^2 + b^2 = c^2", "with": "pen"}]},
		{"name": "point-it", "beat": 1, "length": 4, "tracks": [{"thing": "pen", "law": "point", "on": "desk/page", "at": "write-it"}]},
		{"name": "quill", "beat": 1, "length": 2, "tracks": [{"thing": "desk", "part": "page", "law": "write", "text": "x", "with": "quill"}]},
		{"name": "point-nowhere", "beat": 1, "length": 2, "tracks": [{"thing": "pen", "law": "point", "on": "desk/page", "at": "nothing"}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 10.0, "t1": 16.0}, {"i": 1, "t0": 16.0, "t1": 20.0}]
	m._work._timelines()
	var said := "; ".join(m._work.notes)
	_ok(said.contains("its pen") and said.contains("quill"), "CONTROL: a write with a pen nobody put on the table is refused, said (%s)" % said)
	_ok(said.contains("\"nothing\"") and said.contains("write-it"), "CONTROL: a point at a name nothing carries is refused, naming what can be pointed at (%s)" % said)
	var pen_tr: Dictionary = {}
	var point_tr: Dictionary = {}
	for a in m._work.acts:
		for t in (a as Dictionary)["tracks"]:
			if String((t as Dictionary)["law"]) == "pen":
				pen_tr = t
			elif String((t as Dictionary)["law"]) == "point" and (t as Dictionary).has("_pointed"):
				point_tr = t
	_ok(not pen_tr.is_empty() and not point_tr.is_empty(), "a write with the pen brings the pen, and the point finds its line")
	if pen_tr.is_empty() or point_tr.is_empty():
		m._root3.free()
		return true
	var tool := {"tip": pen_tr["_tip"]}
	var tip_at := func(T: float) -> Vector3:
		m._work.tick(T)
		return m._work._world_of(pen_node) * (tool["tip"] as Vector3)
	# the line's box on the page, in the table's space, and the paper's height under it
	var wi := int((pen_tr["_write"] as Dictionary)["_sheet"])
	var item: Dictionary = (((m._work._writing[wi] as Dictionary)["page"] as Dictionary)["layout"] as Dictionary)["items"][0]
	var on_paper := 0
	var inside := 0
	var lifted := 0
	var samples := 0
	var judged := 0
	for i in 40:
		var T := 10.0 + 6.0 * (float(i) + 0.5) / 40.0
		# (...the hand brings it from where it lay over the first moment, as it brings any held tool)
		if T - 10.0 < TableWork.BLEND_IN:
			tip_at.call(T)
			continue
		judged += 1
		var nib := m._work._pen_nib(pen_tr, T)
		var tip: Vector3 = tip_at.call(T)
		# (...lifted, it drifts as a held thing does: [method Pen.drift])
		var want: Vector3 = m._work._page_world(wi, nib["at"], float(nib["lift"]), T) + Pen.drift(T, int(pen_tr.get("_hand", 0)), float(nib["lift"]))
		if tip.distance_to(want) > 0.003:
			continue
		samples += 1
		var p: Vector2 = nib["at"]
		if float(nib["lift"]) < 1e-4:
			on_paper += 1
			if Rect2(float(item["x"]) - 2.0, float(item["y"]) - 2.0, float(item["w"]) + 4.0, float(item["h"]) + 4.0).has_point(p):
				inside += 1
		else:
			lifted += 1
	_ok(judged >= 30 and samples == judged, "once the hand has brought it, the pen's tip is where its nib is meant to be (%d of %d moments)" % [samples, judged])
	_ok(on_paper >= 10 and inside == on_paper, "the tip is on the paper while the ink goes down, inside the line (%d on the paper, %d inside)" % [on_paper, inside])
	_ok(lifted >= 4, "the tip is lifted off the paper before the first stroke, between strokes and after the last (%d)" % lifted)
	var start := m._work._pen_nib(pen_tr, 10.05)
	var end := m._work._pen_nib(pen_tr, 15.98)
	_ok(float(start["lift"]) > SheetWriting.PEN_LEAD * 0.0 + Pen.LIFT and float(end["lift"]) > Pen.LIFT,
		"it comes down to the line, and lifts clear of it when the line is done (%.3f, %.3f m)" % [float(start["lift"]), float(end["lift"])])
	var box: Rect2 = (point_tr["_pointed"] as Dictionary)["box"]
	var held := m._work._point_nib(point_tr, 3.5, 4.0)
	var p2: Vector2 = held["at"]
	_ok(p2.x >= box.end.x and p2.x <= box.end.x + Pen.POINT_GAP and p2.y >= box.position.y and p2.y <= box.end.y and is_equal_approx(float(held["lift"]), Pen.POINT_LIFT),
		"a point holds the nib just over the paper beside the line's end (%s, the line %s)" % [str(p2), str(box)])
	var tip_pt: Vector3 = tip_at.call(19.5)
	var pointed_at := m._work._page_world(wi, p2, Pen.POINT_LIFT, 19.5) + Pen.drift(19.5, int(point_tr.get("_hand", 0)), Pen.POINT_LIFT)
	_ok(tip_pt.distance_to(pointed_at) < 0.003, "and the pen's tip is there")
	m._root3.free()
	return true
