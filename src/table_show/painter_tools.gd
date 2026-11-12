extends RefCounted
class_name PainterTools

## PainterTools - the painter's tools (next/painted_surface.md, "The painter"): where a face was painted first (`face_ref.png`), it is painted
## again at the table, an operation at a time, by a writer that sees each land. Served over ghost's MCP server ([AgentTools]) in the
## `skin` step ([TableProducer]).
##
## An operation is a tool of the table's, a paint of its pots, how it is laid (a sponge's dabs, a brush's dots, sweeps or fine lines) and
## where (a closed path, or the whole surface), as strong as asked and no longer than asked, in one of the episode's beats - its intro, a
## stage, its close. [PaintLayers] lays it as the show will ([method PaintLayers.lay]: toward the painting itself, each mark by what it
## really lays) on a canvas that is the show's own, and the writer looks: the painting, the canvas and where it is still wrong side by side.
## What it hands in is the design ([method designs]: `skin.json`, an element per operation, its `plan` saying with what and when) from
## which the acts are made, a beat's operations in order, a tool's run an act ([method TableProducer._acts_from_painting]).

const SUBMITTED := "submitted.json"
const LOOKS := 60
## Operations at most, and undone at most in a row.
const PAINTS_MOST := 90
const UNDO_KEEP := 6
## The painting's time (seconds) the writer is told it has, all its beats together.
const BUDGET := 1500.0
## An operation laid at most this long (seconds) if it says no time of its own, and never longer than this.
const SECONDS_GUESS := 60.0
const SECONDS_MOST := 420.0
## A look's pictures, this many pixels a millimeter, a grid line every this many millimeters (brighter every five).
const LOOK_PX := 3.0
const GRID := 10.0
## A paint this polished, or that plays (a glitter), is a finish: never the painting's ground.
const FINISH_POLISH := 0.9
## A sponge is laid on the canvas as a dab this share of its width across (it presses its real sides, its broad face most; sized as a
## corner's touch, a foundation took 3,636 dabs); a foundation's is half again as wide.
const SPONGE_DAB := 0.35
const SPONGE_GROUND := 0.5
## How each way of laying is named to the writer, and what [PaintLayers] lays it as (a blend has no paint of its own: a clean brush moves
## the paint already on).
const HOWS := {"sponge": "stipple", "dab": "dab", "sweep": "sweep", "line": "line", "blend": "blend"}
## A brush whose tip is a cotton swab's bud ([constant Bristles.KINDS]) lays no paint of its own: it lifts, or blends.
const SWAB_TIP := "bud"
const FINISHES := {"pat": "powder"}

var dir := ""
var submitted := false
var skins: Array = []
var table: Dictionary = {}
var plan: Dictionary = {}

var _pl: PaintLayers
var _frame := Vector2.ZERO
var _outline := ""
var _ref: Image
var _ground := Color.WHITE
var _bare := Color.WHITE
var _creams: Array = []
var _surface := PackedByteArray()
var _tools: Array = []       # [{name, thing, part, kind, mm, tip}]
var _paints: Array = []      # [{name, color, pot, powder}]
var _beats: Array = []       # [{key, name, work}]
var _ops: Array = []         # the operations laid, in order
var _snaps: Array = []       # the canvas before each of the last few
var _laid := {}              # each operation's marks as laid, by its id - [method laid]
var _based := false
var _looks := 0
var _busy := false
var _released := false
var _name := ""


func _init(job_dir: String, table_doc: Dictionary, plan_doc: Dictionary, reference: String, only_scan := false) -> void:
	dir = job_dir
	table = table_doc
	plan = plan_doc
	# only what is on the table, looked at ([method scan]): no folder touched, no canvas
	if only_scan:
		_find_tools()
		return
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		var fs := String(f)
		if fs == SUBMITTED or fs == "tools.jsonl" or (fs.begins_with("look_") and fs.ends_with(".jpg")):
			DirAccess.remove_absolute(dir.path_join(fs))
	skins = Skins.skins_of(table)
	_ref = Image.load_from_file(reference) if FileAccess.file_exists(reference) else null
	_find_tools()
	_find_beats()
	if skins.is_empty() or _ref == null:
		return
	var skin: Dictionary = skins[0]
	_frame = skin["frame"]
	_outline = String(skin.get("outline", ""))
	_bare = Color.html(String(skin.get("color", "#c89e80"))) if Color.html_is_valid(String(skin.get("color", ""))) else Color("#c89e80")
	_creams = []
	for p in _paints:
		if not bool((p as Dictionary)["powder"]):
			_creams.append((p as Dictionary)["color"])


## The canvas begun, on the first call (a worker's - a few seconds of the engine's, never the app's thread): the picture balanced to its
## ground, the plain paint most of it stands nearest (a gloss or a glitter is a finish, never a ground) until the first operation over
## the whole surface says what the ground is.
func _begin() -> void:
	if _pl != null or _creams.is_empty() or _ref == null:
		return
	var plain: Array = []
	for p in _paints:
		if not bool((p as Dictionary)["powder"]) and not bool((p as Dictionary)["finish"]):
			plain.append((p as Dictionary)["color"])
	var probe := PaintLayers.new()
	probe._setup(_ref, _frame, _bare)
	var voters: Array = plain if not plain.is_empty() else _creams
	_ground = voters[maxi(probe._vote(voters), 0)]
	var whole := Skins.cover({"kind": "fill", "d": "all"}, Rect2(Vector2.ZERO, _frame), PaintLayers.PX, _outline, _frame)
	if whole != null:
		_surface = TablePaint.covered_in(whole)
	_pl = PaintLayers.begin(_ref, _frame, _bare, _creams, _ground, _surface)


func release() -> void:
	_released = true


func looks_used() -> int:
	return _looks


## The episode's beats as the painter is told them: `[{key, name, work}]`.
func beats() -> Array:
	return _beats


## Whether there is a painting to paint again and a table to paint it with.
func ready() -> bool:
	return _ref != null and not skins.is_empty() and not _creams.is_empty() and not _tools.is_empty()


func instructions() -> String:
	return "Tools for painting the face again at the table, an operation at a time: look at the painting and the canvas, lay an operation, undo it, and hand the painting in."


func list_tools() -> Array:
	return [
		{"name": "look", "description": "See the painting to copy, the canvas as it stands (as the show will draw it) and where the canvas is still off the painting (bright where it is), side by side, each with a grid every 10 mm (brighter every 50); and the time used, the operations so far, the tools and the paints.",
			"inputSchema": {"type": "object", "properties": {}}},
		{"name": "paint", "description": "Lay one operation: `tool` (one of the table's tools, as `look` names them), `paint` (one of its paints, by name; none for a blend), `mix` (optional: other paints, by name, it may be mixed with on the palette, mark by mark, wherever a mix is nearer the painting than the paint alone), `how` (sponge: a sponge's dabs; dab: a brush's dots; sweep: a brush's strokes, each pressed lighter or harder to the width the painting asks for; line: the painting's own lines in that paint, traced and drawn, pressed to their width - a thick brush draws a hairline with its tip; blend: a clean brush drags the paint already on across edges the painting softens - feathering, smudging; pat: a powder pressed on with a puff), `where` (\"all\", or a closed SVG path in millimeters on the grid - the region the operation works in; it lays paint only where the painting asks for it there), `strength` (0.1-1: how thick the paint may go on; for a blend, how much it moves), `seconds` (the most it may take), `beat` (the episode's beat it is laid in, as `look` names them) and an `id`. Answers with what it laid, how long it took, how much nearer the painting the canvas came, and the look.",
			"inputSchema": {"type": "object", "properties": {
				"id": {"type": "string"}, "beat": {"type": "string"}, "tool": {"type": "string"}, "paint": {"type": "string"},
				"mix": {"type": "array", "items": {"type": "string"}},
				"how": {"type": "string"}, "where": {"type": "string"}, "strength": {"type": "number"}, "seconds": {"type": "number"}},
				"required": ["beat", "tool", "how", "where"]}},
		{"name": "undo", "description": "Take back the last operation laid, the canvas as it was before it.", "inputSchema": {"type": "object", "properties": {}}},
		{"name": "submit", "description": "Hand the painting in as it now stands: `name` it in a few plain words. Answers with what keeps it from being handed in, if anything; otherwise the painting is done, and so is your work.",
			"inputSchema": {"type": "object", "properties": {"name": {"type": "string"}}}},
	]


func call_tool(name: String, args: Dictionary) -> Dictionary:
	while _busy and not _released:
		await TablePreview._tree().process_frame
	if _released:
		return {"text": "The painting has been handed in and its tools are closed.", "error": true}
	_busy = true
	# laid on a worker, never on the app's thread (a foundation takes the engine ten seconds): the frame goes on while it works
	var out := {}
	var task := WorkerThreadPool.add_task(func() -> void: out.merge(_call(name, args), true))
	while not WorkerThreadPool.is_task_completed(task):
		await TablePreview._tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	_busy = false
	return out


func _call(name: String, args: Dictionary) -> Dictionary:
	if not ready():
		return {"text": "There is no painting to copy, or no tool on the table to paint with.", "error": true}
	_begin()
	match name:
		"look":
			return _look()
		"paint":
			return _paint(args)
		"undo":
			return _undo()
		"submit":
			return _submit(args)
	return {"text": "There is no tool called \"%s\": look, paint, undo and submit are the tools." % name, "error": true}


# --- the table: its tools, its paints, the episode's beats -------------------------------------------------------------------------

## The table's tools and paints as the painter is given them ([method _find_tools]), for a step that paints without one (the painter
## run as a host, TableProducer._land_skin_host): `{tools: [{name, thing, part, kind, mm, tip}], paints: [{name, color, pot, powder, finish}]}`.
static func scan(table_doc: Dictionary) -> Dictionary:
	var pt := PainterTools.new("", table_doc, {}, "", true)
	return {"tools": pt._tools, "paints": pt._paints}


## The tools that paint on the table: each movable part a brush (its hairs) or a sponge (its foam) - or a puff, for a powder - named as a
## track names it (`thing/part`), its kind and how wide it lays (millimeters, [method Skins.width_for]).
func _find_tools() -> void:
	_tools = []
	_paints = []
	var safe := Props.sanitize(table, [])
	var mats: Dictionary = safe.get("materials", {})
	for t in safe.get("things", []):
		var td: Dictionary = t
		_tools_in(td["parts"], String(td["name"]), mats)
		# its pots: a thing holding a cream or a powder - the paint named as its material is
		for pd in _leaf_parts(td["parts"]):
			var mn := String((pd as Dictionary).get("material", ""))
			var m: Dictionary = mats.get(mn, {})
			if String(m.get("kind", "")) in ["cream", "powder"] and Props._is_color(m.get("color")):
				_paints.append({"name": mn, "color": Color.html(Props._color(m["color"], "#808080")), "pot": String(td["name"]),
					"powder": String(m.get("kind", "")) == "powder", "finish": float(m.get("polish", 0.0)) >= FINISH_POLISH or m.has("play")})


func _tools_in(parts: Array, thing: String, mats: Dictionary) -> void:
	for p in parts:
		var pd: Dictionary = p
		var named := String((pd.get("work", {}) as Dictionary).get("name", ""))
		if not named.is_empty():
			var got := Skins._tool_of_parts([pd], mats)
			var kind := String(got[0]) if not got.is_empty() else ""
			if kind in ["brush", "sponge"] or (kind == "tool" and _soft(pd, mats)):
				# a brush's tip, its tuft's kind: a cotton swab's bud lays no paint ([constant Bristles.KINDS])
				_tools.append({"name": "%s/%s" % [thing, named], "thing": thing, "part": named, "kind": kind if kind != "tool" else "puff",
					"mm": float(got[1]), "tip": String(got[2]) if got.size() > 2 else ""})
				continue
		if pd.get("parts") is Array:
			_tools_in(pd["parts"], thing, mats)


## Whether part [param pd] is soft all through (a puff's velvet, a pad's cotton).
static func _soft(pd: Dictionary, mats: Dictionary) -> bool:
	var leaves := _leaf_parts([pd])
	for l in leaves:
		var m: Dictionary = mats.get(String((l as Dictionary).get("material", "")), {})
		if not String(m.get("kind", "")) in ["fabric"]:
			return false
	return not leaves.is_empty()


static func _leaf_parts(parts: Array) -> Array:
	var out: Array = []
	for p in parts:
		var pd: Dictionary = p
		if pd.get("parts") is Array:
			out.append_array(_leaf_parts(pd["parts"]))
		else:
			out.append(pd)
	return out


## The episode's beats, as its readers speak over them: its intro, each stage of its plan, its close - what each was planned to paint.
func _find_beats() -> void:
	_beats = [{"key": "intro", "name": "intro", "work": String(plan.get("work_intro", ""))}]
	var spread: Dictionary = plan.get("spread", {}) if plan.get("spread") is Dictionary else {}
	var k := 0
	for pos in spread.get("positions", []):
		k += 1
		var pd: Dictionary = pos if pos is Dictionary else {}
		_beats.append({"key": str(k), "name": String(pd.get("name", "stage %d" % k)), "work": String(pd.get("work", ""))})
	_beats.append({"key": "close", "name": "close", "work": String(plan.get("work_close", ""))})


func _beat_of(v: Variant) -> Dictionary:
	var s := str(v).strip_edges().to_lower()
	for b in _beats:
		if s == String((b as Dictionary)["key"]) or s == String((b as Dictionary)["name"]).to_lower():
			return b
	return {}


func _tool_of(v: Variant) -> Dictionary:
	var s := str(v).strip_edges().to_lower()
	for t in _tools:
		var td: Dictionary = t
		if s == String(td["name"]).to_lower() or s == String(td["part"]).to_lower():
			return td
	return {}


func _paint_of(v: Variant) -> Dictionary:
	var s := str(v).strip_edges().to_lower()
	for p in _paints:
		var pd: Dictionary = p
		if s == String(pd["name"]).to_lower() or s == String(pd["pot"]).to_lower() or s == "#" + (pd["color"] as Color).to_html(false):
			return pd
	return {}


# --- laying an operation ------------------------------------------------------------------------------------------------------------

func _paint(args: Dictionary) -> Dictionary:
	if _ops.size() >= PAINTS_MOST:
		return {"text": "No operations left: submit the painting.", "error": true}
	var beat := _beat_of(args.get("beat", ""))
	var tool := _tool_of(args.get("tool", ""))
	var paint := _paint_of(args.get("paint", ""))
	var how := str(args.get("how", "")).strip_edges().to_lower()
	var wrong := PackedStringArray()
	if beat.is_empty():
		wrong.append("`beat` is one of %s" % ", ".join(_beats.map(func(b: Dictionary) -> String: return "\"%s\"" % b["key"])))
	if tool.is_empty():
		wrong.append("`tool` is one of %s" % ", ".join(_tools.map(func(t: Dictionary) -> String: return "\"%s\"" % t["name"])))
	# a blend lays no paint of its own: the brush is clean
	if how == "blend":
		paint = {"name": "nothing - a clean brush", "pot": "", "color": _ground, "powder": false}
	if paint.is_empty():
		wrong.append("`paint` is one of %s" % ", ".join(_paints.map(func(p: Dictionary) -> String: return "\"%s\"" % p["name"])))
	# what it may be mixed with on the palette, mark by mark
	var mixes: Array = []
	var mix_of: Variant = args.get("mix", [])
	for m in (mix_of if mix_of is Array else [mix_of]):
		if str(m).strip_edges().is_empty():
			continue
		var mp := _paint_of(m)
		if mp.is_empty() or bool(mp.get("powder", false)):
			wrong.append("`mix` names creams on the table: %s" % ", ".join(_paints.filter(func(p: Dictionary) -> bool: return not bool(p.get("powder", false))).map(
					func(p: Dictionary) -> String: return "\"%s\"" % p["name"])))
			break
		if how != "blend" and mp["name"] != paint.get("name") and not mixes.has(mp):
			mixes.append(mp)
	if not HOWS.has(how) and not FINISHES.has(how):
		wrong.append("`how` is one of %s" % ", ".join(PackedStringArray(HOWS.keys() + FINISHES.keys())))
	elif not tool.is_empty():
		var kind := String(tool["kind"])
		if (how == "sponge" and kind != "sponge") or (how in ["dab", "sweep", "line", "blend"] and kind != "brush") or (how == "pat" and kind != "puff"):
			wrong.append("a %s does not lay `%s`" % [kind, how])
		elif String(tool.get("tip", "")) == SWAB_TIP and how != "blend":
			wrong.append("a cotton swab lays no paint: it only blends")
	var where := str(args.get("where", "")).strip_edges()
	var region := PackedByteArray()
	if where.to_lower() == "all":
		where = "all"
	else:
		var path := Skins._path_text(where)
		var cov := Skins.cover({"kind": "fill", "d": path}, Rect2(Vector2.ZERO, _frame), PaintLayers.PX, _outline, _frame) if not path.is_empty() else null
		if cov == null:
			wrong.append("`where` is \"all\" or a closed SVG path (M, L, C, Q, A, Z ...) in millimeters")
		else:
			region = TablePaint.covered_in(cov)
			if region.count(1) == 0:
				wrong.append("`where` lies off the surface")
	if not wrong.is_empty():
		return {"text": "Not laid: " + "; ".join(wrong) + ".", "error": true}
	var id := str(args.get("id", "")).strip_edges()
	if id.is_empty() or _ops.any(func(o: Dictionary) -> bool: return String(o["id"]) == id):
		id = "%s %d" % [how, _ops.size() + 1]
	var strength := clampf(float(args.get("strength", 1.0)), 0.1, 1.0)
	var seconds := clampf(float(args.get("seconds", SECONDS_GUESS)), 5.0, SECONDS_MOST)
	var op := {"id": id, "beat": String(beat["key"]), "tool": tool["name"], "thing": tool["thing"], "part": tool["part"], "kind": tool["kind"],
		"how": how, "paint": paint["name"], "pot": paint["pot"], "color": "#" + (paint["color"] as Color).to_html(false), "where": where,
		"strength": strength, "seconds": seconds, "marks": 0, "took": 0.0,
		"mix": mixes.map(func(m: Dictionary) -> String: return String(m["name"])), "mix_colors": mixes.map(func(m: Dictionary) -> String: return "#" + (m["color"] as Color).to_html(false))}
	var before := _pl.off()
	_snaps.append(_snapshot())
	if _snaps.size() > UNDO_KEEP:
		_snaps.pop_front()
	if FINISHES.has(how):
		# a finish lays no color the canvas follows: its time as asked
		op["took"] = seconds
	else:
		var manner: String = HOWS[how]
		var base := where == "all" and not _based and manner in ["stipple", "sweep"]
		# the painting's ground is the first whole-surface operation's paint; the canvas is begun again on it where nothing is laid yet
		if base and _ops.is_empty() and (paint["color"] as Color) != _ground:
			_ground = paint["color"]
			_pl = PaintLayers.begin(_ref, _frame, _bare, _creams, _ground, _surface)
			_snaps[_snaps.size() - 1] = _snapshot()
		var mm := float(tool["mm"]) * ((SPONGE_GROUND if base else SPONGE_DAB) if manner == "stipple" else 0.5)
		var res := _pl.lay({"id": id, "manner": manner, "paint": paint["color"], "opacity": strength,
			"r": mm, "region": region if where != "all" else PackedByteArray(),
			"base": base, "rect": Rect2(Vector2.ZERO, _frame), "frame": _frame, "seed": hash([id, manner]), "budget": seconds, "grow": TablePaint.PAINTER_GROW,
			"mix": mixes.map(func(m: Dictionary) -> Color: return m["color"]), "no_maps": true})
		op["marks"] = int(res["marks"])
		op["took"] = float((res["program"] as Dictionary).get("natural", 0.0))
	# its marks kept as laid, for drawing again ([method laid])
		_laid[id] = {"kind": res["kind"], "marks": res["laid"], "color": paint["color"]}
		op["traced"] = res.get("traced", {})
		if base:
			_based = true
			op["base"] = true
	_ops.append(op)
	var after := _pl.off()
	var said := "Laid \"%s\" in %s: %d marks in %.0f s; the canvas %.1f off the painting on average, from %.1f.%s" % [id, beat["name"], int(op["marks"]),
		float(op["took"]), after, before, " It laid nothing: the painting asks for none of that paint there, with that tool." if int(op["marks"]) == 0 and not FINISHES.has(how) else ""]
	# a line's lines found in the painting: how many it drew, and how long the rest would take (a whole crackle needs the time)
	var tr: Dictionary = op.get("traced", {})
	if int(tr.get("lines", 0)) > 0:
		said += " It found %d lines of that paint in the painting there (%.0f mm in all) and drew %d of them%s." % [int(tr["lines"]),
			float(tr["mm"]), int(tr["drawn"]), "" if int(tr["drawn"]) >= int(tr["lines"]) else
			"; about %.0f s more would draw the rest" % float(tr["left_seconds"])]
	var look := _look()
	look["text"] = said + "\n\n" + String(look["text"])
	return look


func _snapshot() -> Dictionary:
	return {"pre": _pl.pre.duplicate(), "alp": _pl.alp.duplicate(), "lin": _pl.lin.duplicate(), "labs": _pl.labs.duplicate(), "based": _based}


func _undo() -> Dictionary:
	if _ops.is_empty() or _snaps.is_empty():
		return {"text": "Nothing to take back%s." % (" (only the last %d can be)" % UNDO_KEEP if not _ops.is_empty() else ""), "error": true}
	var sn: Dictionary = _snaps.pop_back()
	_pl.pre = sn["pre"]
	_pl.alp = sn["alp"]
	_pl.lin = sn["lin"]
	_pl.labs = sn["labs"]
	_based = bool(sn["based"])
	var op: Dictionary = _ops.pop_back()
	_laid.erase(op["id"])
	var look := _look()
	look["text"] = "Took back \"%s\".\n\n%s" % [op["id"], look["text"]]
	return look


# --- looking ----------------------------------------------------------------------------------------------------------------------

func _look() -> Dictionary:
	if _looks >= LOOKS:
		return {"text": "No looks left: submit the painting.", "error": false}
	_looks += 1
	var img := _picture()
	img.save_jpg(dir.path_join("look_%02d.jpg" % _looks), 0.9)
	return {"text": _said(), "images": [img]}


## The painting, the canvas and where the canvas is off it, side by side at [constant LOOK_PX], a grid over each.
func _picture() -> Image:
	var w := int(ceil(_frame.x * LOOK_PX))
	var h := int(ceil(_frame.y * LOOK_PX))
	var ref := _ref.duplicate() as Image
	ref.convert(Image.FORMAT_RGB8)
	ref.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var canvas := _pl.picture()
	canvas.convert(Image.FORMAT_RGB8)
	canvas.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var off := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var k := _pl._k(Vector2((float(x) + 0.5) / LOOK_PX, (float(y) + 0.5) / LOOK_PX))
			if k < 0 or _pl.face[k] == 0:
				continue
			var d := clampf(_pl.labs[k].distance_to(_pl.raw[k]) / 40.0, 0.0, 1.0)
			off.set_pixel(x, y, Color(d, d * 0.85, d * 0.3))
	var gap := 8
	var out := Image.create(w * 3 + gap * 2, h, false, Image.FORMAT_RGB8)
	out.fill(Color(0.05, 0.05, 0.05))
	var k := 0
	for im in [ref, canvas, off]:
		var at := k * (w + gap)
		out.blit_rect(im, Rect2i(0, 0, w, h), Vector2i(at, 0))
		for gx in range(0, int(_frame.x) + 1, int(GRID)):
			var bright := gx % int(GRID * 5.0) == 0
			for y in h:
				var px := at + mini(int(float(gx) * LOOK_PX), w - 1)
				var c := out.get_pixel(px, y)
				out.set_pixel(px, y, c.lerp(Color(0.3, 0.8, 1.0), 0.55 if bright else 0.3))
		for gy in range(0, int(_frame.y) + 1, int(GRID)):
			var bright := gy % int(GRID * 5.0) == 0
			for x in w:
				var py := mini(int(float(gy) * LOOK_PX), h - 1)
				var c := out.get_pixel(at + x, py)
				out.set_pixel(at + x, py, c.lerp(Color(0.3, 0.8, 1.0), 0.55 if bright else 0.3))
		k += 1
	return out


## What `look` says: the time used and left, the beats and what each was planned to paint with the operations laid in it, the tools and
## the paints.
func _said() -> String:
	var lines := PackedStringArray()
	var used := 0.0
	for o in _ops:
		used += float((o as Dictionary)["took"])
	lines.append("THE PICTURES: the painting to copy (left), the canvas as it stands (middle), and where the canvas is still off the painting (right: brighter is further off). Grid lines every 10 mm, brighter every 50; [0, 0] is the top left. The canvas is %.1f off the painting on average." % _pl.off())
	lines.append("TIME: %.0f s of the painting's %.0f s used." % [used, BUDGET])
	lines.append("THE BEATS and what each was planned to paint:")
	for b in _beats:
		var bd: Dictionary = b
		var laid := _ops.filter(func(o: Dictionary) -> bool: return String(o["beat"]) == String(bd["key"]))
		lines.append("- \"%s\" (%s): %s" % [bd["key"], bd["name"], String(bd["work"]).left(400) if not String(bd["work"]).is_empty() else "-"])
		for o in laid:
			var od: Dictionary = o
			var mixed := "" if (od.get("mix", []) as Array).is_empty() else " mixed with " + ", ".join(od["mix"])
			lines.append("    \"%s\": %s, %s%s with the %s in %s, strength %.2f - %d marks, %.0f s" % [od["id"], od["how"], od["paint"], mixed, od["tool"],
				"the whole surface" if String(od["where"]) == "all" else "a region", float(od["strength"]), int(od["marks"]), float(od["took"])])
	lines.append("THE TOOLS: " + ", ".join(_tools.map(func(t: Dictionary) -> String: return "\"%s\" (a %s, %.0f mm)" % [t["name"],
		"cotton swab, which lays no paint and only blends" if String(t.get("tip", "")) == SWAB_TIP else t["kind"], float(t["mm"])])))
	lines.append("THE PAINTS: " + ", ".join(_paints.map(func(p: Dictionary) -> String: return "\"%s\" %s%s" % [p["name"], "#" + (p["color"] as Color).to_html(false), " (a powder)" if bool(p["powder"]) else ""])))
	lines.append("Looks left: %d. Operations left: %d." % [LOOKS - _looks, PAINTS_MOST - _ops.size()])
	return "\n".join(lines)


# --- handing it in ------------------------------------------------------------------------------------------------------------------

## Each operation's marks as the canvas laid them, by its id: `{kind, marks: [{m, th, salt}], color}` ([method PaintLayers.lay]).
func laid() -> Dictionary:
	return _laid


## The painting as a design ([TablePaint] reads `skin.json`): an element per operation, in the order laid - its region a fill, its paint
## its pot's, its strength its opacity - and its `plan`: the tool, how, the beat, and the seconds it took.
func designs() -> Dictionary:
	var skin: Dictionary = skins[0]
	var elements: Array = []
	for o in _ops:
		var od: Dictionary = o
		var e := {"id": od["id"], "stage": String((_beat_of(od["beat"]) as Dictionary).get("name", od["beat"])), "paint": od["color"],
			"opacity": od["strength"], "finish": FINISHES.get(String(od["how"]), "matte"),
			"plan": {"thing": od["thing"], "part": od["part"], "how": od["how"], "beat": od["beat"], "seconds": float(od["took"]), "pot": od["pot"]}}
		if not (od.get("mix_colors", []) as Array).is_empty():
			(e["plan"] as Dictionary)["mix"] = od["mix_colors"]
		e["fill"] = od["where"]
		elements.append(e)
	return {"designs": [{"thing": skin["thing"], "part": skin["part"], "frame": [_frame.x, _frame.y], "outline": _outline,
		"name": _name, "elements": elements}]}


func _submit(args: Dictionary) -> Dictionary:
	if args.get("name") is String and not String(args["name"]).strip_edges().is_empty():
		_name = String(args["name"]).strip_edges()
	if _ops.is_empty():
		return {"text": "Nothing is painted yet: lay operations with `paint`.", "error": true}
	if _name.is_empty():
		return {"text": "Name the painting (`submit` with `name`): what it is, in a few plain words.", "error": true}
	var err := TextGen.put(dir.path_join(SUBMITTED) + ".part", JSON.stringify(designs(), "\t"))
	if err.is_empty() and DirAccess.rename_absolute(dir.path_join(SUBMITTED) + ".part", dir.path_join(SUBMITTED)) != OK:
		err = "could not move the painting into place"
	if not err.is_empty():
		return {"text": "The painting could not be handed in: %s" % err, "error": true}
	submitted = true
	return {"text": "Handed in. The painting is done - your work is done; end with one short line."}
