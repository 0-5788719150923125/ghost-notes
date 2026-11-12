extends RefCounted
class_name Skins

## Skins: the painted surface (next/painted_surface.md; next/table_work.md section 11): what is painted on a part's `skin`, and how a tool
## lays it on. Nothing here knows a face: a skin is any part painted from one side - a mask's face, a cake's top, a sign, a miniature -
## and a design is its elements.
##
## A design is data, never a picture: its elements, in the order they go on, each a shape in millimeters across and down the skin as it is
## seen from its side (x to the right, y down, from its top left corner) - a `fill` (an SVG path, or "all" of the surface), a `line` (an
## SVG path drawn with a `width`), `dots` or `stones` - with its `paint`, its `finish` and its `stage`. The decorator writes it ([method
## sanitize]); Godot draws each shape from its own SVG ([method cover]) so the edges are the design's exactly.
##
## A tool lays it on as a hand does ([method program]): a line drawn along its path in slow strokes, lifted at its corners; a fill swept
## back and forth along its length; a base stippled with a sponge from its middle out, twice; a powder patted; dots dabbed; stones carried
## from their dish and pressed on - going back to the paint when the tool runs dry. Every point of an element is given the moment the tool
## first covers it, as a share of its program ([method when_map]), so the paint shows exactly where the tool has been, a pure function of
## time ([TablePaint] plays it).

## The finishes paint can have: how rough it is (0 a mirror, 1 chalk), how metallic, how much glitter is in it, and how much of what is
## under it it hides (`opacity`, when the element says none).
const FINISHES := {
	"matte": {"label": "Matte", "blurb": "a soft, flat finish - greasepaint, face paint, gouache, a set foundation", "rough": 0.62, "metal": 0.0, "glitter": 0.0, "opacity": 1.0},
	"satin": {"label": "Satin", "blurb": "a soft sheen - cream paint, a satin lipstick, acrylic", "rough": 0.4, "metal": 0.0, "glitter": 0.0, "opacity": 1.0},
	"gloss": {"label": "Gloss", "blurb": "wet-looking and shining - a glossy lipstick, lacquer, a glaze, a varnish", "rough": 0.06, "metal": 0.0, "glitter": 0.0, "opacity": 1.0},
	"glitter": {"label": "Glitter", "blurb": "fine flakes that catch the light - a glitter gel, a sparkling dust", "rough": 0.35, "metal": 0.3, "glitter": 1.0, "opacity": 0.9},
	"metal": {"label": "Metal", "blurb": "a metal's shine - gold leaf, silver paint, a metallic pigment", "rough": 0.28, "metal": 0.9, "glitter": 0.0, "opacity": 1.0},
	"pearl": {"label": "Pearl", "blurb": "a soft pearly shimmer - a highlighter, a pearl paint, an iridescent powder", "rough": 0.24, "metal": 0.35, "glitter": 0.15, "opacity": 0.8},
	"powder": {"label": "Powder", "blurb": "a fine translucent veil that takes the shine off what is under it - a setting powder, a dusting of flour or chalk; patted on, and patted again to sweep its excess away", "rough": 0.97, "metal": 0.0, "glitter": 0.0, "opacity": 0.38},
}
## What a second pass of powder leaves of the first (its excess swept off).
const SWEPT := 0.35
## The manners a tool lays an element on in - the first that suits it is taken unless the act says another.
const MANNERS := {
	"line": {"label": "Line", "blurb": "drawn along its path in short pulls, each begun back over the last and now and then gone over again, lifted between them"},
	"sweep": {"label": "Sweep", "blurb": "a fill swept back and forth along its length, each stroke beside the last - a flat or round brush, or a sponge's flat face"},
	"stipple": {"label": "Stipple", "blurb": "small presses from its middle outward, over it twice, the second filling what the first left - a sponge's corner"},
	"pat": {"label": "Pat", "blurb": "patted all over, light and quick, a press at a time, a faint cloud off its first press of each load - a powder puff or sock"},
	"dab": {"label": "Dab", "blurb": "each dot set with one press of the tool's end"},
	"place": {"label": "Place", "blurb": "each stone taken from its dish, carried over and pressed on where it goes"},
	"blend": {"label": "Blend", "blurb": "an element already on, gone over again with nothing on the tool so its edges soften and smear - a blending brush or a sponge's flat face; a puff presses it again instead, never slid"},
	"smear": {"label": "Smear", "blurb": "paint already on dragged along a path in one pressed stroke, thinning and streaking as it goes - a sponge's edge, a fingertip, a dry brush"},
	"spray": {"label": "Spray", "blurb": "a mist sprayed over it from a hand's length away, a few pumps across it - a setting spray, a mister"},
}
## A smear: how wide it is when none is given (millimeters), how much of its paint is left at its end, the streaks across it, and how
## many pieces along it its paint thins over. A mist: the sheen it leaves (roughness), what of it is left once dry, and how long that
## takes (seconds).
const SMEAR_WIDTH := 6.0
const SMEAR_LEFT := 0.2
const SMEAR_STREAKS := 6
const SMEAR_PIECES := 12
const DEW := 0.08
const DEW_LEFT := 0.35
const DEW_DRIES := 75.0
## A design's limits: elements, the characters of one path, dots and stones one element has, and a line's width (mm).
const MOST_ELEMENTS := 120
const MOST_PATH := 6000
const MOST_DOTS := 120
const MOST_STONES := 60
const WIDTH := Vector2(0.2, 25.0)
## How far an element's edge may be softened (millimeters), and how far a blend softens it when its `soft` says none - a fill, at most
## this share of how far its middle is from its edge ([method inner_reach]; a flat softening would blur a thin lip through and through);
## a line is feathered as far as it was.
const SOFT_MOST := 15.0
const BLEND_SOFT := 4.0
const BLEND_SHARE := 0.3
## How finely an element is drawn (pixels a millimeter) and its reveal map ([method when_map]), and how finely a path is
## followed (millimeters).
const PX_MM := 5.0
const WHEN_PX := 1.0
## How far a press's ragged edge reads its reveal map from each point, at most along each axis (millimeters) - line for line
## skin_paint.gdshader's `RAGGED` ([method touch_map]'s spread).
const PRESS_RAGGED := 1.6
## A brush's paint is smoothed as paint spreads ([method touch_map]'s `foot_out`): what its hairs touched shrunk to a point this wide
## (millimeters) and grown back smoothly, and laid where that is between these shares of whole - each bit of a hair stamped on its own
## would leave a stray one beside a liner's line standing out as a bead. A lone bit fades out (0.29 of whole), a millimeter's line stays
## whole (0.85), and what is thinner than half of one fades.
const FOOT_SOFT := 1.0
const FOOT_HALF := Vector2(0.25, 0.55)
## ...and a point no tool ever touched (of the program's length: never reached in it) - [method touch_map].
const NEVER := 1000.0
## A point is touched again by a touch at any other moment of its program than its first (a share of it - a press's own touches are one
## moment, and the next press is hardly a two-thousandth of a long act on): a pressed element's film thickens only where and when it is
## ([method touch_map]'s third channel, skin_paint.gdshader's `again`).
const AGAIN_AFTER := 0.00001
## ...and closed in where it is all but surrounded ([method closed_in]): of its eight neighbours this many laid, this many times over (a
## millimeter a time).
const CLOSE_LEAST := 5
const CLOSE_PASSES := 2
const PATH_STEP := 0.5

## The pace of a hand at this work, at its own speed - a careful hand's, a face painted as a work of art: millimeters a second along a
## line, across a sweep and a blend; how long it takes to come down onto the surface and to lift off it; how far it lifts between strokes
## (millimeters); how fast it moves between them (mm/s, never quicker than TRAVEL_LEAST seconds).
const LINE_SPEED := 7.0
## A line is pressed as far as it is wide: at the least this share of what its tool gives - a hairline with a big brush still bends its
## tip over ([method program], TablePaint.TIP_PUSH).
const LINE_PRESS_LEAST := 0.15
const SWEEP_SPEED := 14.0
## ...its edge cut in slower, as an outline is laid (millimeters a second).
const CUT_SPEED := 10.0
const BLEND_SPEED := 16.0
const DOWN := 0.5
const UP := 0.45
const HOVER := 4.0
const TRAVEL := 60.0
const TRAVEL_LEAST := 0.35
## A look after each stroke: the tool backs off this far (millimeters) and the eye checks what it did, for between these (seconds),
## before the next - drawn by the stroke, so the same design paints the same way.
const LOOK := Vector2(0.6, 1.8)
const LOOK_LIFT := 9.0
## A dab: down, held, up (seconds), how high it lifts between dabs and how fast it moves - a sponge bounced lightly, a press a half
## second (it touches only what its corner touches now, so it presses many more times); a pat the same, as light: a puff is pressed on
## and lifted again and again, briskly - two pats a second - and never slid.
const DAB := Vector3(0.16, 0.1, 0.16)
const DAB_LIFT := 2.5
const DAB_MOVE := 70.0
const PAT := Vector3(0.16, 0.12, 0.16)
const PAT_LIFT := 4.0
## A PRESS (an element gone over again by a tool that is never slid - [method blend_manner]) never goes back for more.
const PRESS_MOST := 1 << 20
## A trip back to the paint in the middle of an element (seconds), and how much is laid before the tool runs dry: of a line (mm), a sweep
## (mm of stroke), stipple dabs, pats and dots - a sponge and a puff a few presses a load.
const RELOAD := 3.4
const RELOAD_LINE := 110.0
const RELOAD_SWEEP := 260.0
const RELOAD_DABS := 16
const RELOAD_PATS := 12
const RELOAD_DOTS := 14
## ...a stipple's and a pat's load by the face it covers (square millimeters - a sponge's 16 presses a disc 24 mm across, a puff's 12 of
## 45): a tool that presses lays what of it touches (TablePaint._touch_width), and a corner touching less presses more times a load.
const LOAD_AREA_DABS := 7200.0
const LOAD_AREA_PATS := 19000.0
## ...and it lays less as it runs dry: what each press or stretch lays, of what the first after a load lays, by the time the tool goes
## back for more - a stipple's and a pat's presses much less, a sweep a little; a line (a liner, a pencil), a dot, a smear and a mist as
## much to the end ([method when_map]'s second channel).
const DRY_DABS := 0.25
const DRY_PATS := 0.3
const DRY_SWEEP := 0.85
## ...as a hand runs a tool dry, never by a count: what is on the tool is taken off a share at a time - each press (or stroke) its own
## hand, this share more or less than the manner's - so it never runs out; each load is taken up this share more or less full; and the
## hand goes back for more once a press would lay less than this load's own STOP (shares of the manner's dry) - or, one load in PUSH_ON,
## only far later (PUSH_STOP). How many presses a load lasts is what comes of it. Never less than LAYS_LEAST of a full first press. What
## never runs pale (a line, a dot) goes back after LOAD_SPREAD either way of its number. All drawn from the element, so the same design
## always paints the same way.
const TAKE_SPREAD := 0.45
const AMOUNT_SPREAD := 0.15
const STOP := Vector2(0.75, 1.5)
const PUSH_ON := 0.2
const PUSH_STOP := Vector2(0.25, 0.55)
const LAYS_LEAST := 0.03
const LOAD_SPREAD := 0.4
## ...a sweep's, gently: its strokes and its loads this share more or less, back for more about its dry - a fill is gone over once, and a
## stroke laid pale or a load pushed on is a stripe in it to the end.
const TAKE_SPREAD_SWEEP := 0.08
const AMOUNT_SPREAD_SWEEP := 0.05
const STOP_SWEEP := Vector2(0.92, 1.04)
## A smear's pace (millimeters a second). A spray: how long it is held up and aimed, each pump, the time between pumps, how wide one
## pump's mist lands (millimeters), and how much surface a pump covers (square millimeters).
const SMEAR_SPEED := 10.0
const AIM := 1.5
const PUMP := Vector2(0.3, 0.6)
const PUMP_MOVE := 1.2
const PUMP_REACH := 45.0
const PUMP_AREA := 2500.0
## A STONE: to its dish and picked up (seconds), down onto its place, pressed, up.
const PICK := 3.2
const PLACE := Vector3(0.8, 0.7, 0.6)
## Where a line is cut into runs: at a corner sharper than this (degrees).
const CORNER := 75.0
## A run is drawn in short pulls: each pull this long (mm, each its own), started this far back over the last one's end so they join,
## lifted this far between them (mm) and down and up this fast (seconds); its pace each its own share of [constant LINE_SPEED], eased in
## and out; and now and then - this share of them - part of a pull gone over again, slower, before the next. A look back only where a run
## ends.
const PULL := Vector2(6.0, 16.0)
const PULL_OVER := 1.5
const PULL_LIFT := 1.2
const PULL_DOWN := 0.22
const PULL_UP := 0.2
const PULL_PACE := Vector2(0.8, 1.25)
const PULL_AGAIN := 0.14
## A shape apart within an element at least this many coverage pixels ([method _islands]); a smaller speck is part of the nearest.
const ISLAND_LEAST := 12
## A sweep's rows, apart (a share of the tool's width); a stipple's dabs apart, and a pat's.
const ROWS := 0.7
const DABS := 0.78
const PATS := 1.05
## ...and a sweep's row is kept every this far along (millimeters): a hand's tool is held clear of the surface at each place it is kept
## ([method TablePaint._cleared]), and a row with only its two ends would cross the nose at the ends' angle.
const ROW_KEYS := 4.0
## A fill keeps inside its shape, its edge cut in first: since a brush lays its paint where its hairs touch, a sweep goes once round each
## of its shape's outlines this share of its brush's half width inside it, the side of the hairs along the edge ([method _cut_in]), and
## its rows stay as far inside ([method sweep_paths]) - what still runs past is cut back where it is drawn ([method
## TablePaint._keep_inside]). A run of the edge shorter than this (millimeters) is not drawn.
const CUT_IN := 1.0
const CUT_LEAST := 3.0
## A sponge is held two ways: its flat face for the manners that spread, its corner for every other - and a corner lays paint this much
## of its face's width ([method width_for]).
const FLAT_MANNERS := ["sweep", "blend"]
const CORNER_WIDE := 0.75


# --- the design ---------------------------------------------------------------------------------------

## Whatever a decorator wrote, as a design that can be painted on a skin [param frame] millimeters across and down: `{name, elements:
## [{id, stage, paint, finish, opacity, soft, kind (fill, line, dots, stones), d (a path, or "all"), width, dots, stones}], notes}` -
## every element with a shape and an id of its own, in the order written.
static func sanitize(raw: Variant, frame: Vector2, outline := "") -> Dictionary:
	var notes := PackedStringArray()
	var d: Dictionary = raw if raw is Dictionary else {}
	var list: Variant = d.get("elements", raw if raw is Array else [])
	var out: Array = []
	var ids := {}
	for e in (list if list is Array else []):
		if out.size() >= MOST_ELEMENTS:
			notes.append("more than %d elements: the rest are left out" % MOST_ELEMENTS)
			break
		if not (e is Dictionary):
			continue
		var made := _element(e as Dictionary, frame, notes, out)
		if made.is_empty():
			continue
		var id := String(made["id"])
		if id.is_empty() or ids.has(id.to_lower()):
			var k := out.size() + 1
			while ids.has(("%s %d" % [String(made["stage"]) if not String(made["stage"]).is_empty() else "element", k]).to_lower()):
				k += 1
			if not id.is_empty():
				notes.append("two elements are called \"%s\": the second is \"%s %d\"" % [id, String(made["stage"]) if not String(made["stage"]).is_empty() else "element", k])
			id = "%s %d" % [String(made["stage"]) if not String(made["stage"]).is_empty() else "element", k]
			made["id"] = id
		ids[id.to_lower()] = true
		out.append(made)
	_based(out, outline if not outline.is_empty() else String(d.get("outline", "")), frame, notes)
	return {"name": Props._text(d.get("name", ""), 80), "elements": out, "notes": notes}


## A base covers all of what it is the base of: of elements [param els], the fills a design opens on that each cover at least
## [constant BASE_SHARE] of its surface (inside [param outline], else its [param frame]) are laid over all of it, to its edges, their soft
## edge kept off its rim - a second base drawn short of an edge would otherwise leave the first coat showing past it as a missed spot.
## Thinner or darker toward an edge is an element of its own over the base (decorator.yaml).
const BASE_SHARE := 0.6
## ...measured this many pixels a millimeter
const BASE_PX := 1.0


static func _based(els: Array, outline: String, frame: Vector2, notes: PackedStringArray) -> void:
	var rect := Rect2(Vector2.ZERO, frame)
	var whole := cover({"kind": "fill", "d": "all"}, rect, BASE_PX, outline, frame)
	if whole == null:
		return
	var surface := 0
	for y in whole.get_height():
		for x in whole.get_width():
			surface += int(whole.get_pixel(x, y).a > 0.5)
	if surface == 0:
		return
	for e in els:
		var ed: Dictionary = e
		if String(ed.get("kind", "")) != "fill":
			break
		if String(ed["d"]) == "all":
			continue
		var c := cover(ed, rect, BASE_PX, outline, frame)
		if c == null:
			break
		var on := 0
		for y in mini(c.get_height(), whole.get_height()):
			for x in mini(c.get_width(), whole.get_width()):
				on += int(c.get_pixel(x, y).a > 0.5 and whole.get_pixel(x, y).a > 0.5)
		var share := float(on) / float(surface)
		if share < BASE_SHARE:
			break
		ed["d"] = "all"
		ed.erase("rule")
		ed["soft"] = 0.0
		notes.append("%s: a base covers all of its surface - laid to its edges (it covered %.0f%%)" % [String(ed["id"]), share * 100.0])


static func _element(e: Dictionary, frame: Vector2, notes: PackedStringArray, before: Array = []) -> Dictionary:
	var id := Props._text(e.get("id", e.get("name", "")), 40)
	var out := {"id": id, "stage": Props._text(e.get("stage", ""), 30).to_lower()}
	# (...and, laid by a painter at the table, its plan: the tool, how it is laid, the beat and the seconds it took - the painter's tools -
	# and, laid by the painter host, the element of its output it plays (`host`, [method TablePaint._from_host]; dropped here, or the
	# host's elements would fall back to the old painter))
	if e.get("plan") is Dictionary:
		var pl: Dictionary = e["plan"]
		out["plan"] = {"thing": Props._text(pl.get("thing", ""), 60), "part": Props._text(pl.get("part", ""), 60), "how": Props._text(pl.get("how", ""), 12),
			"beat": Props._text(str(pl.get("beat", "")), 20), "seconds": float(Props._num(pl.get("seconds"), 0.0, 0.0, 900.0)), "pot": Props._text(pl.get("pot", ""), 60)}
		if pl.get("host") is String and not String(pl["host"]).is_empty():
			out["plan"]["host"] = Props._text(pl["host"], 40)
	# A smear takes the paint of what it drags, an element laid before it
	if e.has("smear"):
		var from := String(e["smear"]).strip_edges().to_lower()
		var src: Dictionary = {}
		for b in before:
			if String((b as Dictionary)["id"]).to_lower() == from:
				src = b
		if src.is_empty() or String(src["kind"]) in ["stones", "mist"]:
			notes.append("%s: a smear drags the paint of an element laid before it (`smear`: its id) - \"%s\" is none - left out" % [id, from])
			return {}
		var dl := _path_text(e.get("line", ""))
		if dl.is_empty() or flatten(dl).is_empty():
			notes.append("%s: a smear's `line` is the path it is dragged along - left out" % id)
			return {}
		out.merge({"kind": "smear", "d": dl, "from_el": String(src["id"]), "width": Props._num(e.get("width"), SMEAR_WIDTH, WIDTH.x, WIDTH.y),
			"paint": Props._color(e["paint"], "#202020") if Props._is_color(e.get("paint")) else String(src["paint"]),
			"finish": String(e["finish"]) if FINISHES.has(String(e.get("finish", ""))) else String(src["finish"]),
			"opacity": Props._num(e.get("opacity"), float(src["opacity"]), 0.05, 1.0), "soft": Props._num(e.get("soft"), 1.0, 0.0, SOFT_MOST)})
		return out
	# A mist lays no color: a wet sheen over what it lands on, which dries to a soft glow
	if e.has("mist"):
		var m: Variant = e["mist"]
		var dm := "all" if (m is String and String(m).strip_edges().to_lower() == "all") or m == true else _path_text(m)
		if dm.is_empty():
			notes.append("%s: a `mist` is \"all\" or a closed path it lands on - left out" % id)
			return {}
		out.merge({"kind": "mist", "d": dm, "paint": "#ffffff", "finish": "gloss", "opacity": Props._num(e.get("opacity"), 1.0, 0.05, 1.0),
			"soft": Props._num(e.get("soft"), 6.0, 0.0, SOFT_MOST)})
		return out
	var finish := String(e.get("finish", "matte")).strip_edges().to_lower()
	if not FINISHES.has(finish):
		if not finish.is_empty():
			notes.append("%s: \"%s\" is not a finish (%s) - matte" % [id, finish, ", ".join(PackedStringArray(FINISHES.keys()))])
		finish = "matte"
	out["finish"] = finish
	out["paint"] = Props._color(e.get("paint", e.get("color", "")), "#202020") if Props._is_color(e.get("paint", e.get("color", ""))) else ""
	out["opacity"] = Props._num(e.get("opacity"), float((FINISHES[finish] as Dictionary)["opacity"]), 0.05, 1.0)
	out["soft"] = Props._num(e.get("soft"), 0.0, 0.0, SOFT_MOST)
	if e.has("stones"):
		out["kind"] = "stones"
		out["stones"] = _circles(e["stones"], frame, MOST_STONES, Vector2(0.4, 8.0))
		if (out["stones"] as Array).is_empty():
			notes.append("%s: its stones are [[x, y, r], ...] millimeters - left out" % id)
			return {}
		if String(out["paint"]).is_empty():
			out["paint"] = "#e8f0ff"
		return out
	if String(out["paint"]).is_empty():
		notes.append("%s: no `paint` (\"#rrggbb\") - left out" % id)
		return {}
	if e.has("dots"):
		out["kind"] = "dots"
		out["dots"] = _circles(e["dots"], frame, MOST_DOTS, Vector2(0.2, 15.0))
		if (out["dots"] as Array).is_empty():
			notes.append("%s: its dots are [[x, y, r], ...] millimeters - left out" % id)
			return {}
		return out
	if e.has("line"):
		var dl := _path_text(e["line"])
		if dl.is_empty() or flatten(dl).is_empty():
			notes.append("%s: its `line` is not a path (SVG's M, L, H, V, C, S, Q, T, A, Z) - left out" % id)
			return {}
		out["kind"] = "line"
		out["d"] = dl
		out["width"] = Props._num(e.get("width"), 1.5, WIDTH.x, WIDTH.y)
		return out
	if e.has("fill"):
		var f: Variant = e["fill"]
		if f is String and String(f).strip_edges().to_lower() == "all":
			out["kind"] = "fill"
			out["d"] = "all"
			return out
		var df := _path_text(f)
		if df.is_empty() or flatten(df).is_empty():
			notes.append("%s: its `fill` is not a closed path (SVG's M, L, C, Q, A, Z ...) or \"all\" - left out" % id)
			return {}
		out["kind"] = "fill"
		out["d"] = df
		out["rule"] = "evenodd" if String(e.get("rule", "")).strip_edges().to_lower() == "evenodd" else "nonzero"
		return out
	notes.append("%s: an element is a `fill`, a `line`, `dots` or `stones` - left out" % id)
	return {}


## A path as written, if it is only a path's letters and numbers.
static func _path_text(v: Variant) -> String:
	if not (v is String):
		return ""
	var s := String(v).strip_edges()
	if s.is_empty() or s.length() > MOST_PATH:
		return ""
	var rx := RegEx.create_from_string("^[MmLlHhVvCcSsQqTtAaZz0-9eE.,+\\-\\s]+$")
	return s if rx.search(s) != null else ""


static func _circles(v: Variant, frame: Vector2, most: int, r: Vector2) -> Array:
	var out: Array = []
	for c in (v if v is Array else []):
		if out.size() >= most:
			break
		if c is Array and (c as Array).size() >= 2:
			var x := float(Props._num((c as Array)[0], 0.0, -frame.x, frame.x * 2.0))
			var y := float(Props._num((c as Array)[1], 0.0, -frame.y, frame.y * 2.0))
			var rr := float(Props._num((c as Array)[2] if (c as Array).size() > 2 else 1.5, 1.5, r.x, r.y))
			out.append([x, y, rr])
	return out


## Where a design paints on its skin, as a decorator reads it back: each element by id, its stage, what it is and how big.
static func summary(design: Dictionary, frame: Vector2) -> PackedStringArray:
	var lines := PackedStringArray()
	for e in design.get("elements", []):
		var ed: Dictionary = e
		var r := bounds(ed, frame)
		lines.append("- \"%s\" (%s): a %s%s in %s, %s, %d x %d mm at [%d, %d]" % [ed["id"], ed["stage"] if not String(ed["stage"]).is_empty() else "no stage",
			ed["kind"], " %.1f mm wide" % float(ed["width"]) if ed["kind"] == "line" else "", ed["paint"], ed["finish"],
			roundi(r.size.x), roundi(r.size.y), roundi(r.position.x), roundi(r.position.y)])
	return lines


# --- paths --------------------------------------------------------------------------------------------

## An SVG path as lines: each subpath `{pts: PackedVector2Array, closed}` - curves and arcs followed every [param step] millimeters.
## Commands SVG's own: M L H V C S Q T A Z, absolute and relative.
static func flatten(d: String, step := PATH_STEP) -> Array:
	var rd := _PathReader.new()
	rd.read(d, step)
	return rd.out


static func _steps_of(length: float, step: float) -> int:
	return clampi(int(ceil(length / maxf(step, 0.05))), 1, 400)


## An SVG arc from [param a] to [param b], as points after [param a] (the spec's own conversion to its middle).
static func _arc(a: Vector2, b: Vector2, rx: float, ry: float, phi: float, fa: bool, fs: bool, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if rx < 1e-6 or ry < 1e-6 or a.distance_to(b) < 1e-6:
		out.append(b)
		return out
	var c := cos(phi)
	var s := sin(phi)
	var d := (a - b) * 0.5
	var x1 := c * d.x + s * d.y
	var y1 := -s * d.x + c * d.y
	var lam := (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
	if lam > 1.0:
		rx *= sqrt(lam)
		ry *= sqrt(lam)
	var num := rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
	var den := rx * rx * y1 * y1 + ry * ry * x1 * x1
	var k := sqrt(maxf(num / maxf(den, 1e-12), 0.0)) * (-1.0 if fa == fs else 1.0)
	var cx1 := k * rx * y1 / ry
	var cy1 := -k * ry * x1 / rx
	var mid := (a + b) * 0.5
	var cx := c * cx1 - s * cy1 + mid.x
	var cy := s * cx1 + c * cy1 + mid.y
	var ang := func(u: Vector2, v: Vector2) -> float: return atan2(u.x * v.y - u.y * v.x, u.dot(v))
	var t1: float = ang.call(Vector2(1, 0), Vector2((x1 - cx1) / rx, (y1 - cy1) / ry))
	var dt: float = ang.call(Vector2((x1 - cx1) / rx, (y1 - cy1) / ry), Vector2((-x1 - cx1) / rx, (-y1 - cy1) / ry))
	if not fs and dt > 0.0:
		dt -= TAU
	elif fs and dt < 0.0:
		dt += TAU
	var n := _steps_of(absf(dt) * maxf(rx, ry), step)
	for i in range(1, n + 1):
		var t := t1 + dt * float(i) / float(n)
		out.append(Vector2(cx + c * rx * cos(t) - s * ry * sin(t), cy + s * rx * cos(t) + c * ry * sin(t)))
	return out


## An element's extent in millimeters, its line's width and its dots' size in it.
static func bounds(e: Dictionary, frame := Vector2.ZERO) -> Rect2:
	var pts := PackedVector2Array()
	var grow := 0.0
	match String(e.get("kind", "")):
		"fill", "line", "smear", "mist":
			if String(e.get("d", "")) == "all":
				return Rect2(Vector2.ZERO, frame)
			for sp in flatten(String(e["d"]), 1.0):
				pts.append_array((sp as Dictionary)["pts"])
			grow = float(e.get("width", 0.0)) * 0.5
		"dots", "stones":
			for c in e.get(String(e["kind"]), []):
				pts.append(Vector2(float(c[0]), float(c[1])))
				grow = maxf(grow, float(c[2]))
	if pts.is_empty():
		return Rect2()
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	return r.grow(grow)


# --- what each element covers -------------------------------------------------------------------------

## The SVG of one element, white on nothing, over [param rect] (millimeters) at [param px] pixels a millimeter - clipped to the surface's
## [param outline] (a path, millimeters; "" for none).
static func svg_of(e: Dictionary, rect: Rect2, px: float, outline: String, frame: Vector2) -> String:
	var w := maxi(int(ceil(rect.size.x * px)), 1)
	var h := maxi(int(ceil(rect.size.y * px)), 1)
	var body := ""
	match String(e["kind"]):
		"fill":
			var d := String(e["d"])
			if d == "all":
				d = outline if not outline.is_empty() else "M0 0 H%.2f V%.2f H0 Z" % [frame.x, frame.y]
			body = "<path d=\"%s\" fill=\"#ffffff\" fill-rule=\"%s\"/>" % [d, String(e.get("rule", "nonzero"))]
		"line":
			body = "<path d=\"%s\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"%.3f\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>" % [String(e["d"]), float(e["width"])]
		"dots":
			for c in e["dots"]:
				body += "<circle cx=\"%.3f\" cy=\"%.3f\" r=\"%.3f\" fill=\"#ffffff\"/>" % [float(c[0]), float(c[1]), float(c[2])]
		"smear":
			body = smear_svg(e, "#ffffff")
		"mist":
			var dm := String(e["d"])
			if dm == "all":
				dm = outline if not outline.is_empty() else "M0 0 H%.2f V%.2f H0 Z" % [frame.x, frame.y]
			body = "<path d=\"%s\" fill=\"#ffffff\"/>" % dm
		"stones":
			return ""
	var clip := ""
	if not outline.is_empty():
		clip = "<defs><clipPath id=\"s\"><path d=\"%s\"/></clipPath></defs>" % outline
		body = "<g clip-path=\"url(#s)\">%s</g>" % body
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"%.4f %.4f %.4f %.4f\">%s%s</svg>" % [
		w, h, rect.position.x, rect.position.y, float(w) / px, float(h) / px, clip, body]


## A smear as SVG, in [param color]: streaks side by side across its width, each thinning along the way it is dragged, from its paint's
## own strength to [constant SMEAR_LEFT] of it - pieces along it, each a little fainter, so it fades as paint does.
static func smear_svg(e: Dictionary, color: String) -> String:
	var out := ""
	var w := float(e.get("width", SMEAR_WIDTH))
	for sp in flatten(String(e["d"])):
		var pts := _resampled((sp as Dictionary)["pts"], 1.0)
		if pts.size() < 2:
			continue
		var total := 0.0
		for k in range(1, pts.size()):
			total += pts[k - 1].distance_to(pts[k])
		for j in SMEAR_STREAKS:
			# each streak a lane across the width, its own strength and width - what the tool's edge left
			var lane := (float(j) + 0.5) / float(SMEAR_STREAKS) - 0.5
			var strength := 0.55 + 0.45 * fposmod(sin(float(j) * 12.9898 + float(hash(e.get("id", ""))) * 0.001) * 43758.5, 1.0)
			var lw := w / float(SMEAR_STREAKS) * (1.3 + 0.6 * fposmod(float(j) * 0.618, 1.0))
			var line := _offset(pts, lane * w * 0.92)
			var run := 0.0
			var piece := PackedVector2Array([line[0]])
			var k0 := 0
			for k in range(1, line.size()):
				run += pts[k - 1].distance_to(pts[k])
				piece.append(line[k])
				var at := run / maxf(total, 1e-3)
				if at >= float(k0 + 1) / float(SMEAR_PIECES) or k == line.size() - 1:
					var fade := lerpf(1.0, SMEAR_LEFT, (float(k0) + 0.5) / float(SMEAR_PIECES))
					var d := "M %.2f %.2f" % [piece[0].x, piece[0].y]
					for q in range(1, piece.size()):
						d += " L %.2f %.2f" % [piece[q].x, piece[q].y]
					out += "<path d=\"%s\" fill=\"none\" stroke=\"%s\" stroke-opacity=\"%.3f\" stroke-width=\"%.3f\" stroke-linecap=\"butt\" stroke-linejoin=\"round\"/>" % [d, color, strength * fade, lw]
					piece = PackedVector2Array([line[k]])
					k0 += 1
	return out


## [param pts] moved [param by] millimeters to its left as it goes.
static func _offset(pts: PackedVector2Array, by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in pts.size():
		var a := pts[maxi(k - 1, 0)]
		var b := pts[mini(k + 1, pts.size() - 1)]
		var d := (b - a).normalized()
		out.append(pts[k] + Vector2(-d.y, d.x) * by)
	return out


## What element [param e] covers over [param rect] at [param px] pixels a millimeter: an image whose alpha is its coverage (Godot draws it
## from its SVG - ThorVG - so its edges are the design's), or null for stones, which are things, not paint.
static func cover(e: Dictionary, rect: Rect2, px: float, outline: String, frame: Vector2) -> Image:
	var svg := svg_of(e, rect, px, outline, frame)
	if svg.is_empty():
		return null
	var img := Image.new()
	if img.load_svg_from_string(svg, 1.0) != OK or img.is_empty():
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


## The rect an element's pictures cover (millimeters): its extent, grown by [param margin] (for softening), on its skin.
static func rect_of(e: Dictionary, frame: Vector2, margin: float) -> Rect2:
	var r := bounds(e, frame).grow(margin + 1.0)
	var on := Rect2(Vector2.ZERO, frame)
	r = r.intersection(on) if r.intersects(on) else Rect2(Vector2.ZERO, Vector2(1.0, 1.0))
	return Rect2(r.position.floor(), (r.end.ceil() - r.position.floor()).max(Vector2(1.0, 1.0)))


# --- how a tool lays it on ----------------------------------------------------------------------------

## The manner [param e] is laid on in by a tool of kind [param tool] ("brush", "sponge" or "tool"), unless [param asked].
static func manner_of(e: Dictionary, tool: String, asked := "") -> String:
	var kind := String(e.get("kind", ""))
	if asked == "blend":
		return "blend"
	# (...laid by a painter: as it said - the painter's tools)
	var how := String((e.get("plan", {}) as Dictionary).get("how", "")) if e.get("plan") is Dictionary else ""
	if not how.is_empty():
		return String(PAINTER_HOWS.get(how, "pat"))
	match kind:
		"stones":
			return "place"
		"dots":
			return "dab"
		"line":
			return "line"
		"smear":
			return "smear"
		"mist":
			return "spray"
	if asked in ["sweep", "stipple", "pat", "dab"]:
		return asked
	match tool:
		"brush":
			return "sweep"
		"sponge":
			return "stipple"
	return "pat"


## How an element already on is gone over by a tool of [param kind]: a brush and a sponge's flat face blend it, stroke by stroke; any
## other tool - a powder puff - presses it again where it lies, a press at a time.
static func blend_manner(kind: String) -> String:
	return "blend" if kind in ["brush", "sponge"] else "press"


## How wide a tool of [param kind] ("brush", "sponge" or "tool"), [param mm] millimeters across its face, lays paint in [param manner]: a
## sponge held by its corner ([constant FLAT_MANNERS]) lays [constant CORNER_WIDE] of it. A painter's ways of laying, as the manners they
## are (the painter's tools; a powder patted on, a mist sprayed).
const PAINTER_HOWS := {"sponge": "stipple", "dab": "dab", "sweep": "sweep", "line": "line", "blend": "blend", "pat": "pat", "spray": "spray"}


static func width_for(kind: String, mm: float, manner: String) -> float:
	return mm * CORNER_WIDE if kind == "sponge" and not manner in FLAT_MANNERS else mm


## A program: the tool's way over element [param e] in [param manner], a tool [param tool_mm] millimeters across, at a hand's own pace -
## `{keys: [[t, x, y, lift, press, at]] (seconds, millimeters; at 0 on the surface, 1 back at its paint, 2 at its stones' dish), strokes:
## [{pts, t, r}] (where it lays paint: millimeters, seconds, its radius), stones: [[t pick, t placed, x, y, r]], natural (seconds), pats:
## [t], manner}`. [param cov]: what the element covers at [constant WHEN_PX] pixels a millimeter over [param rect] (an image, or null).
static func program(e: Dictionary, manner: String, tool_mm: float, cov: Image, rect: Rect2, inserts := {}, paths: Variant = null,
		frame := Vector2.ZERO) -> Dictionary:
	var p := _Prog.new()
	p.seed = hash([String(e.get("id", "")), manner])
	var r := maxf(tool_mm * 0.5, 0.4)
	match manner:
		"line":
			var lw := maxf(float(e.get("width", 1.0)) * 0.5, 0.4)
			# ...pressed as far as it is wide: the share of the tool a line is, its width over the tool's, is how hard it is pressed - a
			# brush's tip bent over that much of its belly (TablePaint.TIP_PUSH), never the point of it alone
			var share := clampf(float(e.get("width", 1.0)) / maxf(tool_mm, 0.5), LINE_PRESS_LEAST, 1.0)
			# ...a line wider than its brush in pulls side by side, each as wide as the brush ([method _beside]) - a pull lays no wider
			var passes := _beside(String(e["d"]), float(e.get("width", 1.0)), tool_mm)
			if passes.size() > 1:
				lw = maxf(tool_mm * 0.5, 0.4)
			var ri := 0
			for st in passes:
				var pulls := _pulls(st, hash([p.seed, ri]))
				ri += 1
				for i in pulls.size():
					var pl: Dictionary = pulls[i]
					var last := i == pulls.size() - 1
					var line_pts: PackedVector2Array = pl["pts"]
					# (...drawn the way its handle leans there: pulled, never pushed - [method _pulled_ways])
					if frame != Vector2.ZERO and line_pts.size() >= 2 and (line_pts[line_pts.size() - 1] - line_pts[0]).dot(pull_toward(line_pts[line_pts.size() / 2], frame)) < 0.0:
						line_pts.reverse()
					var line_press := PackedFloat32Array()
					line_press.resize(line_pts.size())
					line_press.fill(share)
					p.stroke(line_pts, LINE_SPEED * float(pl["pace"]), lw, RELOAD_LINE, true, 1.0,
						Skins.HOVER if i == 0 else PULL_LIFT, last, true, line_press)
					p.planned(inserts, lw)
		# ...a shape at a time: an element of several apart (both eyes' diamonds) is finished in one before the next is begun
		"sweep", "blend":
			# (...a sweep's edge cut in and its rows kept inside, or the ways [param paths] given - eased off and cut back where they ran
			# past, [method TablePaint._keep_inside]: `{pts, press}` each, a press a point)
			var ways: Array = []
			if paths == null:
				for part in _islands(cov):
					# (...a shape too fine for the brush, drawn along its middle as a line - [method _spine])
					if manner == "sweep" and String(e.get("d", "all")) != "all" and _eroded(part, tool_mm * 0.5 * CUT_IN) == null:
						var spine := _spine(part, rect, tool_mm, hash([p.seed, ways.size()]))
						if not spine.is_empty():
							ways.append_array(spine)
							continue
					var made := sweep_paths(e, part, rect, tool_mm) if manner == "sweep" else {"cut": [], "rows": _rows(part, rect, tool_mm * ROWS)}
					for kind in ["cut", "rows"]:
						for st in made[kind]:
							var pts := _resampled(st, ROW_KEYS)
							var press := PackedFloat32Array()
							press.resize(pts.size())
							press.fill(1.0)
							var wd := {"pts": pts, "press": press}
							if kind == "cut":
								wd["speed"] = CUT_SPEED
							ways.append(wd)
				ways = _pulled_ways(ways, frame)
			else:
				ways = (paths as Array).duplicate()
			for wd in ways:
				p.stroke((wd as Dictionary)["pts"], float((wd as Dictionary).get("speed", SWEEP_SPEED if manner == "sweep" else BLEND_SPEED)), r, RELOAD_SWEEP if manner == "sweep" else INF, manner == "sweep",
					DRY_SWEEP if manner == "sweep" else 1.0, Skins.HOVER, true, false, (wd as Dictionary)["press"])
				p.planned(inserts, r)
			p.ways = ways
		"stipple", "pat":
			return pressed(e, manner, tool_mm, press_places(manner, tool_mm, cov, rect))
		"press":
			for part in _islands(cov):
				for c in _dabs(part, rect, tool_mm * PATS, 0):
					p.dab(c, r, PAT, PAT_LIFT, PRESS_MOST)
		"dab":
			for c in e.get("dots", []):
				p.dab(Vector2(float(c[0]), float(c[1])), maxf(float(c[2]), 0.4), Vector3(DAB.x, DAB.y * 2.0, DAB.z), HOVER, RELOAD_DOTS)
		"place":
			for c in e.get("stones", []):
				p.place(Vector2(float(c[0]), float(c[1])), float(c[2]))
		"smear":
			for st in flatten(String(e["d"])):
				p.stroke(_resampled((st as Dictionary)["pts"], 2.0), SMEAR_SPEED, maxf(float(e.get("width", SMEAR_WIDTH)) * 0.5, 0.5), INF, true)
		"spray":
			for c in _pumps(cov, rect):
				p.pump(c)
	var out := p.done()
	out["manner"] = manner
	out["origin"] = p.origin
	if not p.ways.is_empty():
		out["ways"] = p.ways
	return out


## A sweep's ways over shape [param part] of element [param e] ([constant CUT_IN]): its edge cut in, a brush [param tool_mm] across
## running round inside each outline with its hairs' side along it ([method _cut_in]), then rows back and forth over what is as far
## inside it ([method _rows]) - a stretch at a time, millimeters: `{cut, rows}`. A shape too narrow for the brush to keep inside is rowed
## as it is.
static func sweep_paths(e: Dictionary, part: Image, rect: Rect2, tool_mm: float) -> Dictionary:
	var by := tool_mm * 0.5 * CUT_IN
	var rows_in := _eroded(part, by)
	if rows_in == null or String(e.get("d", "all")) == "all":
		return {"cut": [], "rows": _rows(part, rect, tool_mm * ROWS)}
	return {"cut": _cut_in(e, by, _eroded(part, maxf(by - 1.0, 0.0)), rect), "rows": _rows(rows_in, rect, tool_mm * ROWS)}


## A line's runs as a brush lays them: path [param d]'s runs ([method _strokes_of]) - and for a line [param width] millimeters wider than a
## [param tool_mm] brush, each run beside itself as many times as covers its width, each a brush's width across, side by side.
static func _beside(d: String, width: float, tool_mm: float) -> Array:
	var runs := _strokes_of(d)
	if width <= tool_mm * 1.05 or tool_mm <= 0.0:
		return runs
	var n := int(ceil(width / tool_mm))
	var out: Array = []
	for run in runs:
		var pts: PackedVector2Array = run
		for j in n:
			var off := lerpf(-(width - tool_mm) * 0.5, (width - tool_mm) * 0.5, float(j) / float(n - 1))
			var moved := PackedVector2Array()
			for k in pts.size():
				var t := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
				moved.append(pts[k] + Vector2(-t.y, t.x) * off)
			out.append(moved)
	return out


## Which way a hand's brush leans over (x, y) [param at] millimeters of a [param frame] surface, along the surface (y down): up, and out to
## the side the work is on - as TablePaint holds it ([constant TablePaint.HELD_UP], [constant TablePaint.HELD_SIDE]).
static func pull_toward(at: Vector2, frame: Vector2) -> Vector2:
	var side := clampf((at.x - frame.x * 0.5) / maxf(frame.x * TablePaint.HELD_SIDE_EDGE, 1e-3), -1.0, 1.0)
	return Vector2(side * TablePaint.HELD_SIDE, -TablePaint.HELD_UP).normalized()


## A brush is pulled through every stroke, never pushed: each of [param ways] (`{pts, press}`) cut where it turns against the way the hand
## leans the brush over [param frame] ([method pull_toward]), and each piece drawn toward it - the handle ahead, its hairs trailing -
## lifted back between. A piece under [constant PULL_PIECE_LEAST] is drawn as the piece before it goes. Unchanged with no frame.
const PULL_PIECE_LEAST := 3.0


static func _pulled_ways(ways: Array, frame: Vector2) -> Array:
	if frame == Vector2.ZERO:
		return ways
	var out: Array = []
	for w in ways:
		var wd: Dictionary = w
		var pts: PackedVector2Array = wd["pts"]
		var press: PackedFloat32Array = wd["press"]
		if pts.size() < 2:
			out.append(wd)
			continue
		# ...the runs of its steps that go along the lean (1) or against it (-1), a run too short to turn for joined to the one before
		# (the first, to the one after): `[first step, last step, way, length]`
		var runs: Array = []
		for k in range(pts.size() - 1):
			var d := pts[k + 1] - pts[k]
			var sg := 1 if d.dot(pull_toward(pts[k], frame)) >= 0.0 else -1
			if not runs.is_empty() and int((runs.back() as Array)[2]) == sg:
				(runs.back() as Array)[1] = k
				(runs.back() as Array)[3] = float((runs.back() as Array)[3]) + d.length()
			else:
				runs.append([k, k, sg, d.length()])
		var pieces: Array = []
		for r in runs:
			var ra: Array = r
			if not pieces.is_empty() and float(ra[3]) < PULL_PIECE_LEAST:
				(pieces.back() as Array)[1] = ra[1]
				(pieces.back() as Array)[3] = float((pieces.back() as Array)[3]) + float(ra[3])
			elif pieces.size() == 1 and float((pieces[0] as Array)[3]) < PULL_PIECE_LEAST:
				pieces[0] = [(pieces[0] as Array)[0], ra[1], ra[2], float((pieces[0] as Array)[3]) + float(ra[3])]
			else:
				pieces.append(ra.duplicate())
		# (steps a..b are points a..b+1)
		for pc in pieces:
			(pc as Array)[1] = int((pc as Array)[1]) + 1
		for pc in pieces:
			var a := int(pc[0])
			var b := int(pc[1])
			if b - a < 1:
				continue
			var pp := pts.slice(a, b + 1)
			var pr := press.slice(a, b + 1)
			if int(pc[2]) < 0:
				pp.reverse()
				pr.reverse()
			var piece := wd.duplicate()
			piece["pts"] = pp
			piece["press"] = pr
			out.append(piece)
	return out


## A fill too fine for its brush is drawn along its middle: shape [param part] followed along its long way in pulls, as a line is
## ([method _pulls]) - the middle of it every [constant SPINE_STEP] across - each point pressed as far as the shape is thick there for a
## [param tool_mm] brush ([constant LINE_PRESS_LEAST] at the least), heavy in its middle and light at its tails. `[{pts, press, speed}]`
## (millimeters); empty for a shape with no length to follow. (A crescent narrower than its brush has nothing a row could keep inside.)
const SPINE_STEP := 1.0


static func _spine(part: Image, rect: Rect2, tool_mm: float, seed: int) -> Array:
	var pts := PackedVector2Array()
	for y in part.get_height():
		for x in part.get_width():
			if part.get_pixel(x, y).a > 0.3:
				pts.append(rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) / WHEN_PX)
	if pts.size() < 3:
		return []
	var way := _long_way(pts)
	var mid: Vector2 = way[0]
	var along: Vector2 = way[1]
	var across: Vector2 = way[2]
	# ...each step along it: how far across it reaches either side
	var bins := {}
	for q in pts:
		var b := floori((q - mid).dot(along) / SPINE_STEP)
		var c := (q - mid).dot(across)
		var got: Vector2 = bins.get(b, Vector2(INF, -INF))
		bins[b] = Vector2(minf(got.x, c), maxf(got.y, c))
	var keys := bins.keys()
	keys.sort()
	var spine := PackedVector2Array()
	var thick := PackedFloat32Array()
	for b in keys:
		var r: Vector2 = bins[b]
		spine.append(mid + along * (float(b) + 0.5) * SPINE_STEP + across * (r.x + r.y) * 0.5)
		thick.append(r.y - r.x + 1.0 / WHEN_PX)
	if spine.size() < 2:
		return []
	# (its middle eased, the ends where they are)
	var eased := spine.duplicate()
	for k in range(1, spine.size() - 1):
		eased[k] = (spine[k - 1] + spine[k] * 2.0 + spine[k + 1]) * 0.25
	var out: Array = []
	for pl in _pulls(eased, seed):
		var pp: PackedVector2Array = (pl as Dictionary)["pts"]
		var press := PackedFloat32Array()
		press.resize(pp.size())
		for k in pp.size():
			var near := 0
			for j in eased.size():
				if eased[j].distance_squared_to(pp[k]) < eased[near].distance_squared_to(pp[k]):
					near = j
			press[k] = clampf(thick[near] / maxf(tool_mm, 0.5), LINE_PRESS_LEAST, 1.0)
		out.append({"pts": pp, "press": press, "speed": LINE_SPEED * float((pl as Dictionary).get("pace", 1.0))})
	return out


## The long way of points [param pts]: `[their middle, the way they run longest (their own principal axis), the way across it]`.
static func _long_way(pts: PackedVector2Array) -> Array:
	var mid := Vector2.ZERO
	for q in pts:
		mid += q
	mid /= float(pts.size())
	var sxx := 0.0
	var syy := 0.0
	var sxy := 0.0
	for q in pts:
		var d := q - mid
		sxx += d.x * d.x
		syy += d.y * d.y
		sxy += d.x * d.y
	var ang := 0.5 * atan2(2.0 * sxy, sxx - syy)
	var along := Vector2(cos(ang), sin(ang))
	return [mid, along, Vector2(-along.y, along.x)]


## How far the middle of what [param cov] covers is from its edge (millimeters; [constant WHEN_PX] pixels a millimeter): the most any
## covered point is from one not covered, or past the picture's edge - a chamfer's two passes.
static func inner_reach(cov: Image) -> float:
	if cov == null:
		return 0.0
	var w := cov.get_width()
	var h := cov.get_height()
	var d := PackedFloat32Array()
	d.resize(w * h)
	for y in h:
		for x in w:
			d[y * w + x] = 1e9 if cov.get_pixel(x, y).a > 0.3 else 0.0
	var at := func(x: int, y: int) -> float: return 0.0 if x < 0 or y < 0 or x >= w or y >= h else d[y * w + x]
	for y in h:
		for x in w:
			var k := y * w + x
			if d[k] > 0.0:
				d[k] = minf(d[k], minf(minf(at.call(x - 1, y) + 1.0, at.call(x, y - 1) + 1.0), minf(at.call(x - 1, y - 1) + 1.414, at.call(x + 1, y - 1) + 1.414)))
	var most := 0.0
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var k := y * w + x
			if d[k] > 0.0:
				d[k] = minf(d[k], minf(minf(at.call(x + 1, y) + 1.0, at.call(x, y + 1) + 1.0), minf(at.call(x + 1, y + 1) + 1.414, at.call(x - 1, y + 1) + 1.414)))
				most = maxf(most, d[k])
	return most / WHEN_PX


## What of coverage [param cov] ([constant WHEN_PX] pixels a millimeter) is [param by] millimeters or more inside its edge - every point
## with all within that of it covered - or null when nothing is.
static func _eroded(cov: Image, by: float) -> Image:
	if cov == null:
		return null
	var w := cov.get_width()
	var h := cov.get_height()
	var inside := PackedByteArray()
	inside.resize(w * h)
	for y in h:
		for x in w:
			inside[y * w + x] = 1 if cov.get_pixel(x, y).a > 0.3 else 0
	var rp := by * WHEN_PX
	var ring: Array = []
	for dy in range(-ceili(rp), ceili(rp) + 1):
		for dx in range(-ceili(rp), ceili(rp) + 1):
			if Vector2(dx, dy).length() <= rp and (dx != 0 or dy != 0):
				ring.append(Vector2i(dx, dy))
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var any := false
	for y in h:
		for x in w:
			if inside[y * w + x] == 0:
				continue
			var keep := true
			for d in ring:
				var q: Vector2i = Vector2i(x, y) + (d as Vector2i)
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or inside[q.y * w + q.x] == 0:
					keep = false
					break
			if keep:
				out.set_pixel(x, y, Color(1, 1, 1, 1))
				any = true
	return out if any else null


## A fill's edge cut in ([constant CUT_IN]): each closed outline of element [param e] moved [param by] millimeters in - each point along
## the way between its sides' insides, as far as keeps both that far in - in runs cut at its sharp corners ([constant CORNER]) and
## wherever the shape is too narrow for it (a point not in [param inside], what is that far in, over [param rect]); none shorter than
## [constant CUT_LEAST].
static func _cut_in(e: Dictionary, by: float, inside: Image, rect: Rect2) -> Array:
	var out: Array = []
	if inside == null:
		return out
	var w := inside.get_width()
	var h := inside.get_height()
	var is_in := func(q: Vector2) -> bool:
		var px := Vector2i(((q - rect.position) * WHEN_PX).floor())
		return px.x >= 0 and px.y >= 0 and px.x < w and px.y < h and inside.get_pixel(px.x, px.y).a > 0.5
	for sp in flatten(String(e.get("d", ""))):
		var pts: PackedVector2Array = _resampled((sp as Dictionary)["pts"], 1.0)
		if not bool((sp as Dictionary).get("closed", false)) or pts.size() < 3:
			continue
		if pts[0].distance_to(pts[pts.size() - 1]) < 0.01:
			pts.resize(pts.size() - 1)
		var n := pts.size()
		# ...moved in on whichever side more of it lands inside
		var best: PackedVector2Array
		var best_in := -1
		for side in [1.0, -1.0]:
			var moved := PackedVector2Array()
			var count := 0
			for k in n:
				var d0 := (pts[k] - pts[(k - 1 + n) % n]).normalized()
				var d1 := (pts[(k + 1) % n] - pts[k]).normalized()
				var n0 := Vector2(-d0.y, d0.x) * float(side)
				var n1 := Vector2(-d1.y, d1.x) * float(side)
				var m := (n0 + n1).normalized() if (n0 + n1).length() > 1e-4 else n0
				var q := pts[k] + m * by / maxf(m.dot(n0), 0.25)
				moved.append(q)
				count += int(is_in.call(q))
			if count > best_in:
				best_in = count
				best = moved
		# ...in runs, cut where it leaves what is that far in and at its sharp corners - starting where a run begins, so none wraps
		var start := 0
		for k in n:
			if not is_in.call(best[k]):
				start = (k + 1) % n
				break
		var cur := PackedVector2Array()
		for j in n + 1:
			var k := (start + j) % n
			var q := best[k]
			if not is_in.call(q):
				if cur.size() >= 2:
					out.append(cur)
				cur = PackedVector2Array()
				continue
			cur.append(q)
			if cur.size() >= 3:
				var a := cur[cur.size() - 3]
				var b := cur[cur.size() - 2]
				var dd0 := (b - a).normalized()
				var dd1 := (q - b).normalized()
				if rad_to_deg(acos(clampf(dd0.dot(dd1), -1.0, 1.0))) > CORNER:
					cur.resize(cur.size() - 1)
					out.append(cur)
					cur = PackedVector2Array([b, q])
		if cur.size() >= 2:
			out.append(cur)
	var kept: Array = []
	for run in out:
		var length := 0.0
		for k in range(1, (run as PackedVector2Array).size()):
			length += (run as PackedVector2Array)[k - 1].distance_to((run as PackedVector2Array)[k])
		if length >= CUT_LEAST:
			kept.append(run)
	return kept


## Where a spray is aimed, pump by pump: across what [param cov] covers along its long way, one a [constant PUMP_AREA] of it.
static func _pumps(cov: Image, rect: Rect2) -> Array:
	var out: Array = []
	if cov == null:
		return out
	var pts := PackedVector2Array()
	for y in cov.get_height():
		for x in cov.get_width():
			if cov.get_pixel(x, y).a > 0.3:
				pts.append(rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) / WHEN_PX)
	if pts.is_empty():
		return out
	var n := clampi(int(round(float(pts.size()) / (PUMP_AREA * WHEN_PX * WHEN_PX))), 1, 6)
	var lo := pts[0]
	var hi := pts[0]
	var mid := Vector2.ZERO
	for q in pts:
		lo = lo.min(q)
		hi = hi.max(q)
		mid += q
	mid /= float(pts.size())
	var wide := (hi.y - lo.y) > (hi.x - lo.x)
	for k in n:
		var f := (float(k) + 0.5) / float(n)
		out.append(Vector2(mid.x, lerpf(lo.y, hi.y, f)) if wide else Vector2(lerpf(lo.x, hi.x, f), mid.y))
	return out


## A line's runs: each subpath cut at its sharp corners - and drawn in short pulls ([method _pulls]).
static func _strokes_of(d: String) -> Array:
	var out: Array = []
	for sp in flatten(d):
		var pts := _resampled((sp as Dictionary)["pts"], 2.0)
		var cur := PackedVector2Array([pts[0]])
		for k in range(1, pts.size()):
			var a := pts[k - 1]
			var b := pts[k]
			cur.append(b)
			var sharp := false
			if k + 1 < pts.size():
				var d0 := (b - a).normalized()
				var d1 := (pts[k + 1] - b).normalized()
				sharp = d0.length() > 0.5 and d1.length() > 0.5 and rad_to_deg(acos(clampf(d0.dot(d1), -1.0, 1.0))) > CORNER
			if sharp and k + 1 < pts.size():
				out.append(cur)
				cur = PackedVector2Array([b])
		if cur.size() >= 2:
			out.append(cur)
	return out


## A run [param run] as a hand draws it ([constant PULL]): short pulls along it, each started back over the last one's end, and now and
## then part of one gone over again - `[{pts, pace}]` in the order drawn, the same for the same [param seed].
static func _pulls(run: PackedVector2Array, seed: int) -> Array:
	var cum := PackedFloat32Array([0.0])
	for k in range(1, run.size()):
		cum.append(cum[k - 1] + run[k - 1].distance_to(run[k]))
	var total := cum[cum.size() - 1]
	var out: Array = []
	var drawn := func(k: int) -> float: return float(absi(hash([seed, k])) % 100003) / 100003.0
	var s0 := 0.0
	var k := 0
	while s0 < total - 0.01:
		var len := lerpf(PULL.x, PULL.y, drawn.call(k * 3))
		# (what would be left too short to pull is taken in this one)
		var s1 := total if total - (s0 + len) < PULL.x * 0.5 else s0 + len
		var pace := lerpf(PULL_PACE.x, PULL_PACE.y, drawn.call(k * 3 + 1))
		out.append({"pts": _along(run, cum, s0, s1), "pace": pace})
		# ...gone over again: its last part, slower, from a little way back
		if drawn.call(k * 3 + 2) < PULL_AGAIN and s1 - s0 > PULL.x:
			out.append({"pts": _along(run, cum, lerpf(s0, s1, 0.35), s1), "pace": pace * 0.7})
		if s1 >= total:
			break
		s0 = maxf(s1 - PULL_OVER, s0 + 0.5)
		k += 1
	return out


## The part of [param run] between [param s0] and [param s1] millimeters along it ([param cum]: how far along each point is).
static func _along(run: PackedVector2Array, cum: PackedFloat32Array, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var at := func(s: float) -> Vector2:
		var j := clampi(cum.bsearch(s), 1, cum.size() - 1)
		var span := maxf(cum[j] - cum[j - 1], 1e-6)
		return run[j - 1].lerp(run[j], clampf((s - cum[j - 1]) / span, 0.0, 1.0))
	out.append(at.call(s0))
	for j in cum.size():
		if cum[j] > s0 + 1e-4 and cum[j] < s1 - 1e-4:
			out.append(run[j])
	out.append(at.call(s1))
	return out


## [param pts] with no stretch longer than [param most] millimeters (a long straight line cut where a hand would lift).
static func _resampled(pts: PackedVector2Array, most: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in pts.size():
		if k > 0:
			var n := int(ceil(pts[k - 1].distance_to(pts[k]) / most))
			for j in range(1, n):
				out.append(pts[k - 1].lerp(pts[k], float(j) / float(n)))
		out.append(pts[k])
	return out


## A fill's sweeps: rows [param spacing] millimeters apart along the long way of what [param cov] covers, back and forth, each row's
## covered stretches a stroke.
## Coverage [param cov] as the shapes apart in it (8-connected, alpha over 0.3), each an image of its own the same size - left to right by
## their middles; a speck under [constant ISLAND_LEAST] pixels goes with the shape nearest it. Itself, alone, when it is one shape.
static func _islands(cov: Image) -> Array:
	if cov == null:
		return [cov]
	var w := cov.get_width()
	var h := cov.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var sizes := PackedInt32Array()
	var mids: Array = []
	for y0 in h:
		for x0 in w:
			if label[y0 * w + x0] >= 0 or cov.get_pixel(x0, y0).a <= 0.3:
				continue
			var id := sizes.size()
			var stack := PackedInt32Array([y0 * w + x0])
			label[y0 * w + x0] = id
			var n := 0
			var sum := Vector2.ZERO
			while not stack.is_empty():
				var i := stack[stack.size() - 1]
				stack.resize(stack.size() - 1)
				var x := i % w
				var y := i / w
				n += 1
				sum += Vector2(x, y)
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var nx: int = x + dx
						var ny: int = y + dy
						if nx < 0 or ny < 0 or nx >= w or ny >= h:
							continue
						var j := ny * w + nx
						if label[j] < 0 and cov.get_pixel(nx, ny).a > 0.3:
							label[j] = id
							stack.append(j)
			sizes.append(n)
			mids.append(sum / float(n))
	var big: Array = []
	for id in sizes.size():
		if sizes[id] >= ISLAND_LEAST:
			big.append(id)
	if big.size() <= 1:
		return [cov]
	big.sort_custom(func(a: int, b: int) -> bool: return (mids[a] as Vector2).x < (mids[b] as Vector2).x)
	# (a speck goes with the shape whose middle is nearest)
	var home := PackedInt32Array()
	home.resize(sizes.size())
	for id in sizes.size():
		var best := 0
		var bd := INF
		for bi in big.size():
			var dd := (mids[id] as Vector2).distance_to(mids[big[bi]])
			if dd < bd:
				bd = dd
				best = bi
		home[id] = best
	var out: Array = []
	for bi in big.size():
		out.append(Image.create(w, h, false, cov.get_format()))
	for y in h:
		for x in w:
			var id := label[y * w + x]
			if id >= 0:
				(out[home[id]] as Image).set_pixel(x, y, cov.get_pixel(x, y))
	return out


static func _rows(cov: Image, rect: Rect2, spacing: float) -> Array:
	var out: Array = []
	if cov == null:
		return out
	var w := cov.get_width()
	var h := cov.get_height()
	var pts := PackedVector2Array()
	for y in h:
		for x in w:
			if cov.get_pixel(x, y).a > 0.3:
				pts.append(rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) / WHEN_PX)
	if pts.is_empty():
		return out
	# the long way: the covered points' own principal axis
	var way := _long_way(pts)
	var mid: Vector2 = way[0]
	var along: Vector2 = way[1]
	var across: Vector2 = way[2]
	var lo := INF
	var hi := -INF
	var a_lo := INF
	var a_hi := -INF
	for q in pts:
		lo = minf(lo, (q - mid).dot(across))
		hi = maxf(hi, (q - mid).dot(across))
		a_lo = minf(a_lo, (q - mid).dot(along))
		a_hi = maxf(a_hi, (q - mid).dot(along))
	var spacing_ := maxf(spacing, 0.5)
	var n := maxi(int(ceil((hi - lo) / spacing_)), 1)
	var reach := spacing_ * 0.55
	for k in n:
		var o := lo + (float(k) + 0.5) * (hi - lo) / float(n)
		var row: Array = []
		var inside := false
		var cur := PackedVector2Array()
		var s := a_lo - 1.0
		while s <= a_hi + 1.0:
			var q := mid + along * s + across * o
			var hit := _covered_near(cov, rect, q, reach)
			if hit and not inside:
				cur = PackedVector2Array([q])
				inside = true
			elif hit:
				if cur.size() == 1:
					cur.append(q)
				else:
					cur[1] = q
			elif inside:
				if cur.size() == 1:
					cur.append(cur[0] + along * 0.5)
				row.append(cur)
				inside = false
			s += 1.0
		if inside:
			if cur.size() == 1:
				cur.append(cur[0] + along * 0.5)
			row.append(cur)
		# back and forth: every other row the other way, its stretches in the order it meets them
		if k % 2 == 1:
			row.reverse()
			for j in row.size():
				var st: PackedVector2Array = row[j]
				st.reverse()
				row[j] = st
		out.append_array(row)
	return out


static func _covered_near(cov: Image, rect: Rect2, q: Vector2, reach: float) -> bool:
	for d in [Vector2.ZERO, Vector2(reach, 0), Vector2(-reach, 0), Vector2(0, reach), Vector2(0, -reach)]:
		var px := ((q + (d as Vector2)) - rect.position) * WHEN_PX
		var x := int(px.x)
		var y := int(px.y)
		if x >= 0 and y >= 0 and x < cov.get_width() and y < cov.get_height() and cov.get_pixel(x, y).a > 0.3:
			return true
	return false


## A stipple's dabs over what [param cov] covers, [param spacing] millimeters apart on a staggered grid (the second pass [param second]
## off by half), from the middle outward ring by ring, round each ring as a hand goes.
static func _dabs(cov: Image, rect: Rect2, spacing: float, second: int) -> Array:
	var out: Array = []
	if cov == null:
		return out
	var spacing_ := maxf(spacing, 0.6)
	var pts: Array = []
	var mid := Vector2.ZERO
	var rows := int(ceil(rect.size.y / (spacing_ * 0.866))) + 1
	var cols := int(ceil(rect.size.x / spacing_)) + 1
	var off := Vector2(spacing_ * 0.5, spacing_ * 0.433) * float(second)
	for j in rows:
		for i in cols:
			var q := rect.position + off + Vector2(float(i) * spacing_ + (spacing_ * 0.5 if j % 2 == 1 else 0.0), float(j) * spacing_ * 0.866)
			if _covered_near(cov, rect, q, spacing_ * 0.35):
				pts.append(q)
				mid += q
	if pts.is_empty():
		return out
	mid /= float(pts.size())
	pts.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var ra := floorf(a.distance_to(mid) / spacing_)
		var rb := floorf(b.distance_to(mid) / spacing_)
		if ra != rb:
			return ra < rb
		return (a - mid).angle() < (b - mid).angle())
	return pts


## Where a tool that presses presses ([param manner] "stipple" or "pat", a tool [param tool_mm] across, over what [param cov] covers of
## [param rect]): each shape apart in turn, its presses in the order a hand lays them ([method _grown]) - `[Vector3(x, y, how hard)]`.
static func press_places(manner: String, tool_mm: float, cov: Image, rect: Rect2) -> Array:
	var spacing := tool_mm * (DABS if manner == "stipple" else PATS)
	var out: Array = []
	for part in _islands(cov):
		var places: Array = []
		for k in (2 if manner == "stipple" else 1):
			places.append_array(_dabs(part, rect, spacing, k))
		for c in _grown(places, spacing):
			out.append(Vector3((c as Vector2).x, (c as Vector2).y, 1.0))
	return out


## The program of a tool that presses at [param places] in turn ([method press_places]'s, or those with presses put in where it missed -
## TablePaint._cover_gaps): each a press as hard as its z, the tool going back for more as a load runs out ([constant LOAD_AREA_DABS]).
static func pressed(e: Dictionary, manner: String, tool_mm: float, places: Array) -> Dictionary:
	var p := _Prog.new()
	p.seed = hash([String(e.get("id", "")), manner])
	var r := maxf(tool_mm * 0.5, 0.4)
	var presses := maxi(roundi((LOAD_AREA_DABS if manner == "stipple" else LOAD_AREA_PATS) / (PI * r * r)), 4)
	for q in places:
		var c := Vector2((q as Vector3).x, (q as Vector3).y)
		if manner == "stipple":
			p.dab(c, r, DAB, DAB_LIFT, presses, false, DRY_DABS, (q as Vector3).z)
		else:
			p.dab(c, r, PAT, PAT_LIFT, presses, true, DRY_PATS, (q as Vector3).z)
	var out := p.done()
	out["manner"] = manner
	return out


## Presses in the order a hand lays them, an area finished before the next: [param places] (each pass's, [method _dabs]) laid as one,
## round and round out from their middle - every press within a ring [param spacing] wide before the next ring, each ring the way round
## from where the last ended - never a pass out to the rim and another back over what it left.
static func _grown(places: Array, spacing: float) -> Array:
	var out: Array = places.duplicate()
	if out.is_empty():
		return out
	var mid := Vector2.ZERO
	for q in out:
		mid += q
	mid /= float(out.size())
	var ring := maxf(spacing, 0.5)
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var ra := floorf(a.distance_to(mid) / ring)
		var rb := floorf(b.distance_to(mid) / ring)
		if ra != rb:
			return ra < rb
		return (a - mid).angle() < (b - mid).angle())
	return out


## The reveal map of program [param prog] over [param rect] (millimeters): when along the program (0-1) each point is first covered by
## the paint it lays, and how much of a full load the tool had on it then ([constant DRY_DABS]), at [constant WHEN_PX] pixels a
## millimeter - a point of the element never reached takes the nearest reached one's. FORMAT_RGF.
static func when_map(prog: Dictionary, rect: Rect2) -> Image:
	var w := maxi(int(ceil(rect.size.x * WHEN_PX)), 1)
	var h := maxi(int(ceil(rect.size.y * WHEN_PX)), 1)
	var vals := PackedFloat32Array()
	vals.resize(w * h)
	vals.fill(-1.0)
	var natural := maxf(float(prog["natural"]), 1e-3)
	var st := _Stamps.new()
	st.vals = vals
	st.loads.resize(w * h)
	st.loads.fill(1.0)
	st.w = w
	st.h = h
	st.origin = rect.position
	for s in prog["strokes"]:
		var pts: PackedVector2Array = (s as Dictionary)["pts"]
		var ts: PackedFloat32Array = (s as Dictionary)["t"]
		var r := float((s as Dictionary)["r"])
		var ld: PackedFloat32Array = (s as Dictionary).get("load", PackedFloat32Array())
		if pts.size() == 1:
			st.stamp(pts[0], r, ts[0] / natural, ld[0] if not ld.is_empty() else 1.0)
			continue
		for k in range(1, pts.size()):
			var a := pts[k - 1]
			var b := pts[k]
			var n := maxi(int(ceil(a.distance_to(b) / (0.5 / WHEN_PX))), 1)
			for j in n + 1:
				var f := float(j) / float(n)
				st.stamp(a.lerp(b, f), r, lerpf(ts[k - 1], ts[k], f) / natural, lerpf(ld[k - 1], ld[k], f) if ld.size() == pts.size() else 1.0)
	vals = st.vals
	var loads := st.loads
	# ...and the rest from the nearest reached
	var queue := PackedInt32Array()
	for k in vals.size():
		if vals[k] >= 0.0:
			queue.append(k)
	var head := 0
	while head < queue.size():
		var k := queue[head]
		head += 1
		var x := k % w
		var y := k / w
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nk := ny * w + nx
			if vals[nk] < 0.0:
				vals[nk] = vals[k]
				loads[nk] = loads[k]
				queue.append(nk)
	var img := Image.create(w, h, false, Image.FORMAT_RGF)
	for k in vals.size():
		img.set_pixel(k % w, k / w, Color(vals[k] if vals[k] >= 0.0 else 1.0, loads[k], 0.0))
	return img


## A reveal map of what a tool touched, and nothing else: each of [param touches] (`[{u, load, pts}]` - when, 0-1 of the program, what was
## on the tool, and every millimeter of the skin it touched then, [method TablePaint._touched]) stamped where it touched, [param spot_mm]
## across, on a map [param px] pixels a millimeter (a brush's line finer than a sponge's press, or its edge is drawn in steps), the first
## touch giving a point its moment; a point never touched is never shown ([constant NEVER]) - [method when_map] gives every point the
## nearest reach's, so a dab would show all that was nearest it. Given the element's cover ([param inside], one a point it covers) and
## [param spread_mm], what lies past its edge takes the edge's moment that far out ([method _spread_out]).
##
## Given an array [param foot_out], what it touched is put in it as paint: each disc's own share of each point it reaches - an edge as
## smooth as the canvas draws it, never in the map's steps - and what the map closed round, whole; an image whose mipmaps soften it as a
## cover's do (skin_paint.gdshader's `foot`). Every point it reaches takes the moment of the touch that reached it.
static func touch_map(touches: Array, rect: Rect2, px := WHEN_PX, spot_mm := 0.75 / WHEN_PX, inside := PackedByteArray(), spread_mm := 0.0,
		foot_out: Variant = null) -> Image:
	var w := maxi(int(ceil(rect.size.x * px)), 1)
	var h := maxi(int(ceil(rect.size.y * px)), 1)
	var st := _Stamps.new()
	st.px = px
	st.vals.resize(w * h)
	st.vals.fill(-1.0)
	st.loads.resize(w * h)
	st.loads.fill(1.0)
	st.again.resize(w * h)
	st.again.fill(-1.0)
	st.w = w
	st.h = h
	st.origin = rect.position
	if foot_out != null:
		st.cov.resize(w * h)
		st.cov.fill(0.0)
	var spot := spot_mm
	for tc in touches:
		var d: Dictionary = tc
		for p in d["pts"]:
			st.stamp(p, spot, float(d["u"]), float(d.get("load", 1.0)))
	if spread_mm > 0.0 and inside.size() == w * h:
		_spread_out(st.vals, st.loads, inside, w, h, ceili(spread_mm * px) + 1)
	var laid := st.vals.duplicate() if foot_out != null else PackedFloat32Array()
	var before_closing := st.vals.duplicate()
	closed_in(st.vals, st.loads, w, h)
	# (...a point the map closes round, laid whole as it is: no first press's film)
	for k in w * h:
		if before_closing[k] < 0.0 and st.vals[k] >= 0.0:
			st.again[k] = st.vals[k]
	if foot_out != null:
		# ...a point the map closed round laid whole; then the whole smoothed as paint spreads, [constant FOOT_SOFT]: a stray hair's lone
		# disc fades out, a pinhole closes, a line keeps its width)
		var cov := PackedFloat32Array()
		cov.resize(w * h)
		for k in w * h:
			cov[k] = 1.0 if laid[k] < 0.0 and st.vals[k] >= 0.0 else clampf(st.cov[k], 0.0, 1.0)
		cov = _blurred(cov, w, h, FOOT_SOFT * px)
		var bytes := PackedByteArray()
		bytes.resize(w * h)
		var reached := PackedByteArray()
		reached.resize(w * h)
		for k in w * h:
			var c := smoothstep(FOOT_HALF.x, FOOT_HALF.y, cov[k])
			bytes[k] = roundi(c * 255.0)
			reached[k] = 1 if c > 0.0 else 0
		# ...and every point it now reaches given the moment of the latest touch beside it
		_grown_into(st.vals, st.loads, reached, w, h, ceili(FOOT_SOFT * px) + 1)
		var fi := Image.create_from_data(w, h, false, Image.FORMAT_L8, bytes)
		fi.generate_mipmaps()
		(foot_out as Array).append(fi)
	var img := Image.create(w, h, false, Image.FORMAT_RGBF)
	for k in st.vals.size():
		img.set_pixel(k % w, k / w, Color(st.vals[k] if st.vals[k] >= 0.0 else NEVER, st.loads[k], st.again[k] if st.again[k] >= 0.0 else NEVER))
	return img


## A line as a brush lays it: each of program [param prog]'s strokes the band its hairs' patch sweeps - as wide as the line (a stroke's
## `r`), pressed as far as that takes ([constant LINE_PRESS_LEAST]) - its edges clean, narrowing to [constant TAIL_NARROW] and thinning
## to [constant TAIL_LEFT] over the last [constant TAIL_SHARE] of each pull, laid as the stroke passes. Its reveal map as [method
## touch_map]'s (each point's share of the program when it was first covered, and the load then) over [param rect] at [param px], and
## its paint into [param foot_out] (an L8 picture, mipmapped). Laid where its hairs' tips were found at moments apart, a line would be
## beads with gaps between them.
const TAIL_SHARE := 0.25
const TAIL_LEFT := 0.55
const TAIL_NARROW := 0.75
## ...the band followed this often along a stroke (millimeters)
const BAND_STEP := 0.25


static func band_map(prog: Dictionary, rect: Rect2, px: float, foot_out: Array) -> Image:
	var w := maxi(int(ceil(rect.size.x * px)), 1)
	var h := maxi(int(ceil(rect.size.y * px)), 1)
	var vals := PackedFloat32Array()
	vals.resize(w * h)
	vals.fill(-1.0)
	var loads := PackedFloat32Array()
	loads.resize(w * h)
	var cov := PackedFloat32Array()
	cov.resize(w * h)
	var natural := maxf(float(prog["natural"]), 1e-3)
	for st in prog["strokes"]:
		var sd: Dictionary = st
		var pts: PackedVector2Array = sd["pts"]
		var ts: PackedFloat32Array = sd["t"]
		if pts.size() < 2 or ts.size() != pts.size():
			continue
		var ld: Variant = sd.get("load", 1.0)
		var r := float(sd["r"])
		var cum := PackedFloat32Array([0.0])
		for k in range(1, pts.size()):
			cum.append(cum[k - 1] + pts[k - 1].distance_to(pts[k]))
		var length := maxf(cum[cum.size() - 1], 1e-4)
		var n := maxi(int(ceil(length / BAND_STEP)), 1)
		var seg := 0
		for i in n + 1:
			var at := length * float(i) / float(n)
			while seg < pts.size() - 2 and cum[seg + 1] < at:
				seg += 1
			var f := clampf((at - cum[seg]) / maxf(cum[seg + 1] - cum[seg], 1e-6), 0.0, 1.0)
			var p := pts[seg].lerp(pts[seg + 1], f)
			var u := lerpf(ts[seg], ts[seg + 1], f) / natural
			var load := float((ld as PackedFloat32Array)[seg]) if ld is PackedFloat32Array and seg < (ld as PackedFloat32Array).size() else (float(ld) if ld is float else 1.0)
			# (...thinning over its tail)
			var tail := smoothstep(1.0 - TAIL_SHARE, 1.0, at / length)
			var rad := r * lerpf(1.0, TAIL_NARROW, tail)
			var shown := lerpf(1.0, TAIL_LEFT, tail)
			var c := (p - rect.position) * px
			var reach := rad * px + 1.0
			for y in range(maxi(int(c.y - reach), 0), mini(int(c.y + reach) + 1, h)):
				for x in range(maxi(int(c.x - reach), 0), mini(int(c.x + reach) + 1, w)):
					var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(c)
					var a := clampf(rad * px - d + 0.5, 0.0, 1.0) * shown
					if a <= 0.0:
						continue
					var k := y * w + x
					cov[k] = maxf(cov[k], a)
					if vals[k] < 0.0 or u < vals[k]:
						vals[k] = u
						loads[k] = load
	var bytes := PackedByteArray()
	bytes.resize(w * h)
	for k in w * h:
		bytes[k] = roundi(cov[k] * 255.0)
	var fi := Image.create_from_data(w, h, false, Image.FORMAT_L8, bytes)
	fi.generate_mipmaps()
	foot_out.append(fi)
	var img := Image.create(w, h, false, Image.FORMAT_RGF)
	for k in vals.size():
		img.set_pixel(k % w, k / w, Color(vals[k] if vals[k] >= 0.0 else NEVER, loads[k], 0.0))
	return img


## [param vals] (one a point, [param w] by [param h]) blurred: shrunk to a point every [param by] points and grown back smoothly, by the
## engine (a blur by hand is slow; shrunk without filtering, a lone dot comes through or not by where it falls).
static func _blurred(vals: PackedFloat32Array, w: int, h: int, by: float) -> PackedFloat32Array:
	var f := maxf(by, 1.0)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RF, vals.to_byte_array())
	img.resize(maxi(roundi(float(w) / f), 1), maxi(roundi(float(h) / f), 1), Image.INTERPOLATE_LANCZOS)
	img.resize(w, h, Image.INTERPOLATE_CUBIC)
	return img.get_data().to_float32_array()


## Every point [param reached] holds (one a point, nonzero) and [param vals] has no moment for, given the latest of its eight neighbours'
## (and its load), grown [param passes] points in. In place.
static func _grown_into(vals: PackedFloat32Array, loads: PackedFloat32Array, reached: PackedByteArray, w: int, h: int, passes: int) -> void:
	for _pass in passes:
		var was := vals.duplicate()
		var any := false
		for y in h:
			for x in w:
				var k := y * w + x
				if was[k] >= 0.0 or reached[k] == 0:
					continue
				var last := -1.0
				var by := k
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var qx: int = x + dx
						var qy: int = y + dy
						if qx >= 0 and qy >= 0 and qx < w and qy < h and was[qy * w + qx] > last:
							last = was[qy * w + qx]
							by = qy * w + qx
				if last >= 0.0:
					vals[k] = last
					loads[k] = loads[by]
					any = true
		if not any:
			return


## What lies past an element's edge takes the edge's moment (and load): [param vals] grown [param passes] points out from what is laid
## into the points [param inside] does not have (zero), each from the latest of its eight neighbours - never shown (its picture covers
## none of them), but read by a press's ragged edge (skin_paint.gdshader's `RAGGED`, [constant PRESS_RAGGED]), which reads the map up to
## that far from each point: read past the face's edge into points no tool touched, a base stippled to the rim would show a ragged bare
## band along it. In place.
static func _spread_out(vals: PackedFloat32Array, loads: PackedFloat32Array, inside: PackedByteArray, w: int, h: int, passes: int) -> void:
	for _pass in passes:
		var was := vals.duplicate()
		var any := false
		for y in range(1, h - 1):
			var row := y * w
			for x in range(1, w - 1):
				var k := row + x
				if was[k] >= 0.0 or inside[k] != 0:
					continue
				var last := -1.0
				var by := k
				for d in [-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1]:
					if was[k + d] > last:
						last = was[k + d]
						by = k + d
				if last >= 0.0:
					vals[k] = last
					if not loads.is_empty():
						loads[k] = loads[by]
					any = true
		if not any:
			return


## What presses spread into, as cream does under the foam: [param vals] (each point's moment, -1 none) with every point all but closed in
## by what is laid round it - [constant CLOSE_LEAST] of its eight neighbours - laid as its last neighbour is, [constant CLOSE_PASSES]
## times; [param loads] with it (or empty); only the points [param mask] has (non-zero, one a point; empty all). In place. (Holes a
## millimeter across between presses would otherwise be grown by a press's ragged edge into flecks.)
static func closed_in(vals: PackedFloat32Array, loads: PackedFloat32Array, w: int, h: int, mask := PackedByteArray()) -> void:
	var masked := mask.size() == vals.size()
	var ring := PackedInt32Array([-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1])
	for _pass in CLOSE_PASSES:
		var was := vals.duplicate()
		for y in range(1, h - 1):
			var row := y * w
			for x in range(1, w - 1):
				var k := row + x
				if was[k] >= 0.0 or (masked and mask[k] == 0):
					continue
				# (how many round it are laid, read out by hand: most points have none, and are passed at once)
				var n := int(was[k - w - 1] >= 0.0) + int(was[k - w] >= 0.0) + int(was[k - w + 1] >= 0.0) + int(was[k - 1] >= 0.0) \
						+ int(was[k + 1] >= 0.0) + int(was[k + w - 1] >= 0.0) + int(was[k + w] >= 0.0) + int(was[k + w + 1] >= 0.0)
				if n < CLOSE_LEAST:
					continue
				var last := -1.0
				var by := k
				for d in ring:
					if was[k + d] > last:
						last = was[k + d]
						by = k + d
				vals[k] = last
				if not loads.is_empty():
					loads[k] = loads[by]


## Paint stamped into a reveal map ([method when_map]): the first to reach a point gives it its moment.
class _Stamps:
	extends RefCounted
	var vals := PackedFloat32Array()
	var loads := PackedFloat32Array()
	# (asked for, when each point was first touched again by a later touch - [method Skins.touch_map]'s third channel; -1 none)
	var again := PackedFloat32Array()
	# (asked for, how much of each point a disc covers - [method Skins.touch_map]'s `foot_out`)
	var cov := PackedFloat32Array()
	var w := 0
	var h := 0
	var origin := Vector2.ZERO
	var px := Skins.WHEN_PX

	func stamp(c: Vector2, r: float, u: float, load := 1.0) -> void:
		var pc := (c - origin) * px
		var rp := maxf(r * px, 0.75)
		if not cov.is_empty():
			# ...and each point's share of it, the edge half a point either side: every point it reaches takes its moment
			for y in range(maxi(int(pc.y - rp - 0.5), 0), mini(int(pc.y + rp + 0.5) + 1, h)):
				for x in range(maxi(int(pc.x - rp - 0.5), 0), mini(int(pc.x + rp + 0.5) + 1, w)):
					var share := rp + 0.5 - Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(pc)
					if share <= 0.0:
						continue
					var k := y * w + x
					cov[k] = maxf(cov[k], minf(share, 1.0))
					_at(k, u, load)
			return
		for y in range(maxi(int(pc.y - rp), 0), mini(int(pc.y + rp) + 1, h)):
			for x in range(maxi(int(pc.x - rp), 0), mini(int(pc.x + rp) + 1, w)):
				if Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(pc) <= rp:
					_at(y * w + x, u, load)

	# ...point [param k] touched at [param u]: its first touch - and, asked for, the first touch after it [constant Skins.AGAIN_AFTER] on
	func _at(k: int, u: float, load: float) -> void:
		if vals[k] < 0.0:
			vals[k] = u
			loads[k] = load
		elif again.is_empty():
			return
		elif u < vals[k] - Skins.AGAIN_AFTER:
			again[k] = vals[k] if again[k] < 0.0 else minf(again[k], vals[k])
			vals[k] = u
			loads[k] = load
		elif u > vals[k] + Skins.AGAIN_AFTER and (again[k] < 0.0 or u < again[k]):
			again[k] = u


## An SVG path read ([method flatten]): its tokens in turn, the subpath being followed, and those done.
class _PathReader:
	extends RefCounted
	const LETTERS := "MmLlHhVvCcSsQqTtAaZz"
	var toks := PackedStringArray()
	var i := 0
	var out: Array = []
	var cur := PackedVector2Array()

	func num() -> float:
		var v := float(toks[i]) if i < toks.size() else 0.0
		i += 1
		return v

	func is_num(k: int) -> bool:
		return k < toks.size() and not (toks[k].length() == 1 and LETTERS.contains(toks[k]))

	func close_sub(closed: bool) -> void:
		if cur.size() >= 2:
			out.append({"pts": cur, "closed": closed})
		cur = PackedVector2Array()

	func read(d: String, step: float) -> void:
		var rx := RegEx.create_from_string("[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][-+]?\\d+)?")
		for m in rx.search_all(d):
			toks.append(m.get_string())
		var p := Vector2.ZERO
		var start := Vector2.ZERO
		var last_c := Vector2.INF     # the last cubic's second control, for S
		var last_q := Vector2.INF     # the last quadratic's control, for T
		var cmd := ""
		var guard := 0
		while i < toks.size() and guard < 100000:
			guard += 1
			var tk := toks[i]
			if tk.length() == 1 and LETTERS.contains(tk):
				cmd = tk
				i += 1
				if cmd == "Z" or cmd == "z":
					if cur.size() >= 1 and cur[0].distance_to(p) > 1e-6:
						cur.append(cur[0])
					p = start
					close_sub(true)
					last_c = Vector2.INF
					last_q = Vector2.INF
					continue
			elif cmd.is_empty():
				out = []
				return
			if not is_num(i):
				continue
			var rel := cmd == cmd.to_lower()
			var o := p if rel else Vector2.ZERO
			match cmd.to_upper():
				"M":
					close_sub(false)
					p = o + Vector2(num(), num())
					start = p
					cur.append(p)
					# further pairs are lines
					cmd = "l" if rel else "L"
					last_c = Vector2.INF
					last_q = Vector2.INF
				"L":
					p = o + Vector2(num(), num())
					if cur.is_empty():
						cur.append(start)
					cur.append(p)
					last_c = Vector2.INF
					last_q = Vector2.INF
				"H":
					p = Vector2((p.x if rel else 0.0) + num(), p.y)
					cur.append(p)
					last_c = Vector2.INF
					last_q = Vector2.INF
				"V":
					p = Vector2(p.x, (p.y if rel else 0.0) + num())
					cur.append(p)
					last_c = Vector2.INF
					last_q = Vector2.INF
				"C", "S":
					var c1: Vector2
					if cmd.to_upper() == "C":
						c1 = o + Vector2(num(), num())
					else:
						c1 = p * 2.0 - last_c if last_c != Vector2.INF else p
					var c2: Vector2 = o + Vector2(num(), num())
					var e: Vector2 = o + Vector2(num(), num())
					var n := Skins._steps_of(p.distance_to(c1) + c1.distance_to(c2) + c2.distance_to(e), step)
					if cur.is_empty():
						cur.append(p)
					for k in range(1, n + 1):
						var t := float(k) / float(n)
						var u := 1.0 - t
						cur.append(p * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + e * t * t * t)
					last_c = c2
					last_q = Vector2.INF
					p = e
				"Q", "T":
					var c: Vector2
					if cmd.to_upper() == "Q":
						c = o + Vector2(num(), num())
					else:
						c = p * 2.0 - last_q if last_q != Vector2.INF else p
					var e: Vector2 = o + Vector2(num(), num())
					var n := Skins._steps_of(p.distance_to(c) + c.distance_to(e), step)
					if cur.is_empty():
						cur.append(p)
					for k in range(1, n + 1):
						var t := float(k) / float(n)
						var u := 1.0 - t
						cur.append(p * u * u + c * 2.0 * u * t + e * t * t)
					last_q = c
					last_c = Vector2.INF
					p = e
				"A":
					var rx_ := absf(num())
					var ry_ := absf(num())
					var phi := deg_to_rad(num())
					var fa := num() != 0.0
					var fs := num() != 0.0
					var e: Vector2 = o + Vector2(num(), num())
					if cur.is_empty():
						cur.append(p)
					cur.append_array(Skins._arc(p, e, rx_, ry_, phi, fa, fs, step))
					last_c = Vector2.INF
					last_q = Vector2.INF
					p = e
				_:
					i += 1
		close_sub(false)


## A program as it is built, a step at a time.
class _Prog:
	extends RefCounted
	var keys: Array = []
	var strokes: Array = []
	var stones: Array = []
	var pats := PackedFloat32Array()
	var mists: Array = []
	var t := 0.0
	var at := Vector2.INF       # where it is over the surface
	var laid := 0.0             # what it has laid since it was loaded (millimeters)
	var count := 0              # presses since it was loaded
	var seed := 0               # the element's: what each load and each press come to ([constant Skins.TAKE_SPREAD])
	var loads := 0              # the loads taken up since the element began (its first, the act's own)
	var presses := 0
	var product := -1.0         # WHAT IS ON THE TOOL, of a full load (-1: what never runs pale, or nothing taken up yet)
	var stop := 0.0             # ...and how little it lays before the hand goes back for more: this load's own
	var ways: Array = []        # a sweep's ways over its shape, as given its strokes ([method Skins.sweep_paths])

	## A number in [0, 1) drawn from the element and [param k].
	func _drawn(k: int) -> float:
		return float(absi(hash([seed, k])) % 100003) / 100003.0

	## How long this load lasts of [param most] (presses, millimeters) - for what never runs pale (a line, a dot), which goes back by
	## how much it has laid.
	func _load_of(most: float) -> float:
		return most * lerpf(1.0 - Skins.LOAD_SPREAD, 1.0 + Skins.LOAD_SPREAD, _drawn(loads * 4 + 3)) if most < INF else INF

	## A load taken up: as full as this one happens to be ([constant Skins.AMOUNT_SPREAD]), and how little a press may lay before the hand
	## goes back for more - about the manner's [param dry] ([constant Skins.STOP]), and now and then ([constant Skins.PUSH_ON]) far less.
	## A sweep's ([param pressed] false) keeps nearer its manner's, and never pushes on: no later pass fills what it leaves pale.
	func _fresh(dry: float, pressed := true) -> void:
		var amount := Skins.AMOUNT_SPREAD if pressed else Skins.AMOUNT_SPREAD_SWEEP
		product = lerpf(1.0 - amount, 1.0 + amount, _drawn(loads * 4))
		var r := _drawn(loads * 4 + 1)
		var on := pressed and _drawn(loads * 4 + 2) < Skins.PUSH_ON
		var span := Skins.STOP if pressed else Skins.STOP_SWEEP
		stop = dry * (lerpf(Skins.PUSH_STOP.x, Skins.PUSH_STOP.y, r) if on else lerpf(span.x, span.y, r))
		# (never before it is halfway from full to its manner's dry: a sweep's, nearly full, would go back after every stroke)
		stop = minf(stop, product * (1.0 + dry) * 0.5)

	## A press's (or a stroke's) own hand: how much more or less than the manner's share it takes and lays ([constant Skins.TAKE_SPREAD]).
	func _hand(spread := Skins.TAKE_SPREAD) -> float:
		presses += 1
		return lerpf(1.0 - spread, 1.0 + spread, _drawn(100000 + presses))

	## How much a press with hand [param f] lays now, of what the first of a full load lays: what is left on the tool, as hard as it is
	## pressed - never nothing; what never runs pale, all of it.
	func _shown(f: float) -> float:
		return clampf(product * f, Skins.LAYS_LEAST, 1.0) if product >= 0.0 else 1.0

	## [param units] presses or millimeters at the manner's [param rate], with hand [param f], taken off the tool: a share of what is left,
	## never all of it - there is always a little more to be had, less and less.
	func _take(rate: float, units: float, f: float) -> void:
		if product >= 0.0:
			product *= exp(-rate * units * f)

	func _key(x: Vector2, lift: float, press: float, where := 0) -> void:
		keys.append([t, x.x, x.y, lift, press, where])

	## Over [param x], lifted [param lift] - from wherever it was, at a hand's pace between strokes.
	func _go(x: Vector2, lift: float) -> void:
		if at == Vector2.INF:
			at = x
			_key(x, lift, 0.0)
			return
		var d := at.distance_to(x)
		if d < 1e-3 and not keys.is_empty() and float((keys[keys.size() - 1] as Array)[3]) == lift:
			return
		if not keys.is_empty():
			var k: Array = keys[keys.size() - 1]
			if float(k[3]) < lift:
				t += Skins.UP
				_key(at, lift, 0.0)
		t += maxf(d / Skins.TRAVEL, Skins.TRAVEL_LEAST)
		at = x
		_key(x, lift, 0.0)

	## Back to its paint for more: there and back (TablePaint finds the way).
	func _trip_back() -> void:
		laid = 0.0
		count = 0
		loads += 1
		var x := at
		t += Skins.UP
		_key(x, Skins.HOVER * 3.0, 0.0)
		_key(x, Skins.HOVER * 3.0, 0.0, 1)
		t += Skins.RELOAD
		_key(x, Skins.HOVER * 3.0, 0.0, 1)
		t += 0.01
		_key(x, Skins.HOVER * 3.0, 0.0)

	## Back to its paint for more, if it needs it: what runs pale ([param dry] below 1) once what is left lays less than this load's own
	## [member stop] (its first load the act's own, taken up before); what never does once it has laid this load's share of [param most].
	## A sweep's stroke [param ahead] millimeters long is not begun on a tool that would be below its stop by its end (a long row begun just
	## over it would end a stripe).
	func _reload(most: float, dry := 1.0, pressed := true, ahead := 0.0) -> void:
		if dry < 1.0 and most < INF:
			if product < 0.0:
				_fresh(dry, pressed)
			elif product * exp(log(dry) / maxf(most, 1e-3) * ahead) < stop:
				_trip_back()
				_fresh(dry, pressed)
			return
		if laid >= _load_of(most):
			_trip_back()

	## A STROKE along [param pts] at [param speed] (mm/s), laying paint [param r] wide (when [param paints]) - running pale over a load of
	## about [param most] millimeters to about [param dry] of what it lays just loaded (1: never).
	## A PULL ([constant Skins.PULL]) comes over [param lift] (millimeters), down and up the quicker, eased in and out along the way, and
	## gets [param look] only where its run ends.
	func stroke(pts: PackedVector2Array, speed: float, r: float, most: float, paints: bool, dry := 1.0, lift := Skins.HOVER, look := true,
			pull := false, press := PackedFloat32Array()) -> void:
		if pts.size() < 2:
			return
		var length := 0.0
		for k in range(1, pts.size()):
			length += pts[k - 1].distance_to(pts[k])
		_reload(most, dry, false, length)
		_go(pts[0], lift)
		t += Skins.PULL_DOWN if pull else Skins.DOWN
		# (pressed as hard as [param press] says at each point, where it is given - eased off near an edge it would run past)
		_key(pts[0], 0.0, press[0] if press.size() == pts.size() else 1.0)
		var ts := PackedFloat32Array([t])
		var rate := -log(dry) / maxf(most, 1e-3) if dry < 1.0 and most < INF else 0.0
		var f := _hand(Skins.TAKE_SPREAD_SWEEP)
		var left := PackedFloat32Array([_shown(f)])
		var along := 0.0
		for k in range(1, pts.size()):
			var d := pts[k - 1].distance_to(pts[k])
			# (a pull starts slow, runs, and slows into its end)
			var u := (along + d * 0.5) / maxf(length, 1e-3)
			along += d
			t += d / (speed * ((0.55 + 0.45 * sin(PI * u)) / 0.84 if pull else 1.0))
			laid += d
			_take(rate, d, f)
			_key(pts[k], 0.0, press[k] if press.size() == pts.size() else 1.0)
			ts.append(t)
			left.append(_shown(f))
		if paints:
			strokes.append({"pts": pts, "t": ts, "r": r, "load": left, "press": press})
		at = pts[pts.size() - 1]
		t += Skins.PULL_UP if pull and not look else Skins.UP
		_key(at, Skins.PULL_LIFT if pull and not look else Skins.HOVER, 0.0)
		if not look:
			return
		# ...and a look at it, backing off a little ([constant Skins.LOOK])
		t += lerpf(Skins.LOOK.x, Skins.LOOK.y, fposmod(sin(float(keys.size()) * 12.9898 + at.x * 0.731 + at.y * 0.317) * 43758.5453, 1.0))
		_key(at, Skins.LOOK_LIFT, 0.0)

	## A dab at [param c]: down, held, up ([param pace]), [param lift] over it between - a pat too - each press taking its own share of what
	## is left, about [param dry] of a full load's first by about [param most] presses (1: never pale, back every so many).
	func dab(c: Vector2, r: float, pace: Vector3, lift: float, most: int, pat := false, dry := 1.0, press := 1.0) -> void:
		if dry < 1.0:
			_reload(float(most), dry)
		elif count >= maxi(roundi(_load_of(float(most))), 2):
			_trip_back()
		var f := _hand()
		var load := _shown(f)
		if dry < 1.0:
			_take(-log(dry) / maxf(float(most) - 1.0, 1.0), 1.0, f)
		count += 1
		var d := at.distance_to(c) if at != Vector2.INF else 0.0
		if at == Vector2.INF:
			_key(c, lift, 0.0)
		else:
			t += maxf(d / Skins.DAB_MOVE, 0.08)
			_key(c, lift, 0.0)
		at = c
		t += pace.x
		_key(c, 0.0, press)
		strokes.append({"pts": PackedVector2Array([c]), "t": PackedFloat32Array([t]), "r": r, "load": PackedFloat32Array([load]),
			"press": PackedFloat32Array([press])})
		# ...a cloud only off a loaded puff: its first press after it took up its powder, and none after
		if pat and count == 1:
			pats.append(t)
		t += pace.y
		_key(c, 0.0, press)
		t += pace.z
		_key(c, lift, 0.0)

	## A pump of mist at [param c], from a hand's length off (`at` 3): aimed, pumped, and on to the next.
	func pump(c: Vector2) -> void:
		var off := TablePaint.SPRAY_STANDOFF
		if keys.is_empty():
			_key(c, off, 0.0, 3)
			t += Skins.AIM
		else:
			t += Skins.PUMP_MOVE
		_key(c, off, 0.0, 3)
		t += Skins.PUMP.x
		_key(c, off, 1.0, 3)
		strokes.append({"pts": PackedVector2Array([c]), "t": PackedFloat32Array([t]), "r": Skins.PUMP_REACH})
		mists.append([t, c.x, c.y])
		t += Skins.PUMP.y
		_key(c, off, 0.0, 3)
		at = c

	## A stone, picked from its dish and pressed on at [param c].
	func place(c: Vector2, r: float) -> void:
		var x := at if at != Vector2.INF else c
		if at != Vector2.INF:
			t += Skins.UP
			_key(x, Skins.HOVER * 3.0, 0.0)
		_key(x, Skins.HOVER * 3.0, 0.0, 2)
		t += Skins.PICK
		var picked := t - Skins.PICK * 0.5
		_key(c, Skins.HOVER * 3.0, 0.0, 2)
		t += 0.01
		_key(c, Skins.HOVER * 3.0, 0.0)
		at = c
		t += maxf(Skins.HOVER * 3.0 / Skins.TRAVEL, 0.3)
		_key(c, Skins.HOVER, 0.0)
		t += Skins.PLACE.x
		_key(c, 0.0, 1.0)
		stones.append([picked, t, c.x, c.y, r])
		t += Skins.PLACE.y
		_key(c, 0.0, 1.0)
		t += Skins.PLACE.z
		_key(c, Skins.HOVER, 0.0)

	## A planned stroke done ([method Skins.program]): each stroke laid since counted as its, and the dabs put in after it where it left gaps
	## ([param inserts]: planned stroke -> [Vector3(x, y, how hard)], TablePaint._cover_gaps) laid now, [param r] across, counted as its too.
	var origin := PackedInt32Array()
	var planned_n := -1

	func planned(inserts: Dictionary, r: float) -> void:
		planned_n += 1
		while origin.size() < strokes.size():
			origin.append(planned_n)
		for q in inserts.get(planned_n, []):
			dab(Vector2((q as Vector3).x, (q as Vector3).y), r, Skins.DAB, Skins.DAB_LIFT, Skins.PRESS_MOST, false, 1.0, (q as Vector3).z)
		while origin.size() < strokes.size():
			origin.append(planned_n)

	func done() -> Dictionary:
		if keys.is_empty():
			_key(Vector2.ZERO, Skins.HOVER, 0.0)
		return {"keys": keys, "strokes": strokes, "stones": stones, "pats": pats, "mists": mists, "natural": maxf(t, 0.1)}


# --- the skins a table has, and a design seen on one ---------------------------------------------------

## The skins of table [param table] (the set dresser's `table.json`, as parsed): every part painted from its front - `{thing, part, shape,
## frame (millimeters across and down its front), outline (an SVG path in them, "" for its whole frame), landmarks (a mask's: name ->
## {at, wide}), color, part (made safe)}` - as a designer is told them before anything is built.
static func skins_of(table: Variant) -> Array:
	var out: Array = []
	if not (table is Dictionary):
		return out
	var safe := Props.sanitize(table as Dictionary, [])
	for t in safe.get("things", []):
		_skins_in((t as Dictionary).get("parts", []), String((t as Dictionary)["name"]), safe.get("materials", {}), out)
	return out


static func _skins_in(parts: Array, thing: String, mats: Dictionary, out: Array) -> void:
	for p in parts:
		var pd: Dictionary = p
		if pd.get("parts") is Array:
			_skins_in(pd["parts"], thing, mats, out)
			continue
		if pd.get("skin") != true:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var box := AABB()
		var first := true
		for g in Props._geometry(pd, rng):
			var b := Props._bounds_of((g as Dictionary)["geo"])
			box = b if first else box.merge(b)
			first = false
		var shape := String(pd["shape"])
		var m: Dictionary = mats.get(String(pd.get("material", "")), {})
		out.append({"thing": thing, "part": String((pd.get("work", {}) as Dictionary).get("name", "")), "shape": shape,
			"frame": Vector2(box.size.x, box.size.y) * 1000.0, "outline": FaceForm.outline_path(pd["size"]) if shape == "mask" else "",
			"landmarks": FaceForm.landmarks(pd["size"]) if shape == "mask" else {}, "color": String(m.get("color", "#e8e2d6")), "part_spec": pd,
			"box": box})


## The skin [param skin] ([method skins_of]) seen from its front with [param design] painted on it, as far as stage [param upto] ("" all
## of it): its bare surface shaded by a light from the top left, every element in its paint, its stones as small rings, and over it a
## faint grid every 10 millimeters (brighter every 50), its outline and its landmarks - drawn on the processor, [param px] pixels a
## millimeter. A designer's own look at what it wrote.
static func look(skin: Dictionary, design: Dictionary, upto := "", px := 3.0, guides := true) -> Image:
	var frame: Vector2 = skin["frame"]
	var w := maxi(int(ceil(frame.x * px)), 8)
	var h := maxi(int(ceil(frame.y * px)), 8)
	var base := _bare_front(skin, frame)
	base.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var body := ""
	var stages_done := false
	for e in design.get("elements", []):
		var ed: Dictionary = e
		if not upto.is_empty() and stages_done and String(ed["stage"]) != upto.to_lower():
			break
		if not upto.is_empty() and String(ed["stage"]) == upto.to_lower():
			stages_done = true
		match String(ed["kind"]):
			"fill":
				var d := String(ed["d"])
				if d == "all":
					d = String(skin.get("outline", "")) if not String(skin.get("outline", "")).is_empty() else "M0 0 H%.2f V%.2f H0 Z" % [frame.x, frame.y]
				body += "<path d=\"%s\" fill=\"%s\" fill-opacity=\"%.2f\" fill-rule=\"%s\"/>" % [d, ed["paint"], float(ed["opacity"]), String(ed.get("rule", "nonzero"))]
			"line":
				body += "<path d=\"%s\" fill=\"none\" stroke=\"%s\" stroke-opacity=\"%.2f\" stroke-width=\"%.3f\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>" % [ed["d"], ed["paint"], float(ed["opacity"]), float(ed["width"])]
			"dots":
				for c in ed["dots"]:
					body += "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"%.2f\" fill=\"%s\" fill-opacity=\"%.2f\"/>" % [float(c[0]), float(c[1]), float(c[2]), ed["paint"], float(ed["opacity"])]
			"smear":
				body += smear_svg(ed, String(ed["paint"]))
			"mist":
				pass
			"stones":
				for c in ed["stones"]:
					body += "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"%.2f\" fill=\"%s\" stroke=\"#202020\" stroke-width=\"0.25\"/>" % [float(c[0]), float(c[1]), float(c[2]), ed["paint"]]
	var outline := String(skin.get("outline", ""))
	var clip := ""
	if not outline.is_empty():
		clip = "<defs><clipPath id=\"s\"><path d=\"%s\"/></clipPath></defs>" % outline
		body = "<g clip-path=\"url(#s)\">%s</g>" % body
	if guides:
		var g := ""
		var x := 10.0
		while x < frame.x:
			g += "<line x1=\"%.1f\" y1=\"0\" x2=\"%.1f\" y2=\"%.1f\" stroke=\"#4fd0ff\" stroke-opacity=\"%.2f\" stroke-width=\"%.2f\"/>" % [x, x, frame.y, 0.55 if int(x) % 50 == 0 else 0.22, 0.35 if int(x) % 50 == 0 else 0.2]
			x += 10.0
		var y := 10.0
		while y < frame.y:
			g += "<line x1=\"0\" y1=\"%.1f\" x2=\"%.1f\" y2=\"%.1f\" stroke=\"#4fd0ff\" stroke-opacity=\"%.2f\" stroke-width=\"%.2f\"/>" % [y, frame.x, y, 0.55 if int(y) % 50 == 0 else 0.22, 0.35 if int(y) % 50 == 0 else 0.2]
			y += 10.0
		if not outline.is_empty():
			g += "<path d=\"%s\" fill=\"none\" stroke=\"#4fd0ff\" stroke-opacity=\"0.6\" stroke-width=\"0.4\" stroke-dasharray=\"2 1.5\"/>" % outline
		for k in skin.get("landmarks", {}):
			var at: Vector2 = (skin["landmarks"][k] as Dictionary)["at"]
			g += "<circle cx=\"%.1f\" cy=\"%.1f\" r=\"1.2\" fill=\"none\" stroke=\"#ff5a5a\" stroke-opacity=\"0.8\" stroke-width=\"0.4\"/>" % [at.x, at.y]
		body += g
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %.3f %.3f\">%s%s</svg>" % [w, h, float(w) / px, float(h) / px, clip, body]
	var over := Image.new()
	if over.load_svg_from_string(svg, 1.0) == OK and not over.is_empty():
		if over.get_format() != Image.FORMAT_RGBA8:
			over.convert(Image.FORMAT_RGBA8)
		base.blend_rect(over, Rect2i(Vector2i.ZERO, over.get_size()), Vector2i.ZERO)
	return base


## A skin's bare front, one pixel a millimeter: its surface shaded by a light from the top left, the room dark round it.
static func _bare_front(skin: Dictionary, frame: Vector2, light := Vector3(-0.45, 0.55, 0.7), ambient := 0.38,
		room := Color(0.1, 0.1, 0.11)) -> Image:
	var w := maxi(int(ceil(frame.x)), 2)
	var h := maxi(int(ceil(frame.y)), 2)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(room)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var faces := PackedVector3Array()
	for g in Props._geometry(skin["part_spec"], rng):
		var geo: Props.Tris = (g as Dictionary)["geo"]
		faces.append_array(geo.v)
	if faces.is_empty():
		return img
	var tm := TableWork._ray_mesh(faces)
	var box: AABB = skin["box"]
	var base := Color.html(String(skin.get("color", "#e8e2d6")))
	light = light.normalized()
	for j in h:
		for i in w:
			var from := Vector3(box.position.x + (float(i) + 0.5) * 0.001, box.end.y - (float(j) + 0.5) * 0.001, box.end.z + 0.02)
			var got := TableWork._ray(tm, from, Vector3.FORWARD)
			if got.is_empty():
				continue
			var n: Vector3 = (got["normal"] as Vector3).normalized()
			if n.z < 0.0:
				n = -n
			var lit := ambient + (1.0 - ambient) * maxf(n.dot(light), 0.0)
			img.set_pixel(i, j, Color(base.r * lit, base.g * lit, base.b * lit))
	return img


# --- the face painted first ----------------------------------------------------------------------------

## The face painted first (next/painted_surface.md): the painter is handed the bare surface seen from its front in its own millimeters,
## FACE_PX pixels a millimeter, lit from the front ([constant FACE_LIGHT], [constant FACE_AMBIENT]) so its features show and little
## else, the room round it black - in the middle of a canvas of the shape it paints in ([constant FACE_CANVAS], upright 2:3), so it
## paints it where it is.
const FACE_PX := 3.0
const FACE_LIGHT := Vector3(0.0, 0.25, 1.0)
const FACE_AMBIENT := 0.62
const FACE_CANVAS := Vector2(2.0, 3.0)
## ...and a painting handed back is the surface's only where it lies on it: the box of what is painted, and the surface's own, within this
## share of the canvas of each other at every side, and no more than this share of the room round the surface painted
const FACE_ALIGN := 0.05
const FACE_SPILL := 0.08
## ...and in it, a point is painted (or the surface) brighter than this, and the room round it darker
const FACE_DARK := 0.08


## The canvas the painter paints on for [param skin] ([method skins_of]): `{image: the bare surface in the middle of it, at: where the
## surface's top-left is (pixels), px: pixels a millimeter, size: the surface's own (pixels)}`.
static func face_canvas(skin: Dictionary) -> Dictionary:
	var frame: Vector2 = skin["frame"]
	var bare := _bare_front(skin, frame, FACE_LIGHT, FACE_AMBIENT, Color.BLACK)
	var w := int(ceil(frame.x * FACE_PX))
	var h := int(ceil(frame.y * FACE_PX))
	# (drawn a millimeter a pixel and grown smooth: a look's own cost, and the surface has nothing finer to show)
	bare.resize(w, h, Image.INTERPOLATE_CUBIC)
	var cw := w
	var ch := h
	if float(w) / float(h) > FACE_CANVAS.x / FACE_CANVAS.y:
		ch = int(ceil(float(w) * FACE_CANVAS.y / FACE_CANVAS.x))
	else:
		cw = int(ceil(float(h) * FACE_CANVAS.x / FACE_CANVAS.y))
	var img := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	var at := Vector2i((cw - w) / 2, (ch - h) / 2)
	img.blit_rect(bare, Rect2i(Vector2i.ZERO, Vector2i(w, h)), at)
	return {"image": img, "at": at, "px": FACE_PX, "size": Vector2i(w, h)}


## Whether a painting [param painted] lies on the surface of [param bare] (its canvas, [method face_canvas]): what is painted and the
## surface each within [constant FACE_ALIGN] of the canvas of the other at every side, and little of the room round it painted
## ([constant FACE_SPILL]) - "" where it does, else what is wrong, said to the painter.
static func face_fit(bare: Image, painted: Image) -> String:
	var p := painted.duplicate() as Image
	if p.get_size() != bare.get_size():
		p.resize(bare.get_width(), bare.get_height(), Image.INTERPOLATE_BILINEAR)
	var w := bare.get_width()
	var h := bare.get_height()
	var on_box := Rect2i()
	var p_box := Rect2i()
	var room := 0
	var spilled := 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var on := bare.get_pixel(x, y).get_luminance() > FACE_DARK
			var lit := p.get_pixel(x, y).get_luminance() > FACE_DARK
			if on:
				on_box = Rect2i(x, y, 1, 1) if on_box.size == Vector2i.ZERO else on_box.expand(Vector2i(x, y))
			else:
				room += 1
				# (a millimeter or two round the surface is its edge, drawn soft)
				if lit and not _near_lit(bare, x, y, int(FACE_PX * 2.0)):
					spilled += 1
			if lit:
				p_box = Rect2i(x, y, 1, 1) if p_box.size == Vector2i.ZERO else p_box.expand(Vector2i(x, y))
	if p_box.size == Vector2i.ZERO:
		return "nothing is painted: the picture is dark"
	var tol := FACE_ALIGN * float(maxi(w, h))
	for side in [[on_box.position.x, p_box.position.x], [on_box.end.x, p_box.end.x], [on_box.position.y, p_box.position.y], [on_box.end.y, p_box.end.y]]:
		if absf(float(side[0]) - float(side[1])) > tol:
			return "the face is not where the bare surface is in the attached picture: moved, grown, shrunk or cropped"
	if room > 0 and float(spilled) / float(room) > FACE_SPILL:
		return "it is painted past the surface's edge, onto the black around it"
	return ""


static func _near_lit(img: Image, x: int, y: int, r: int) -> bool:
	for dy in [-r, 0, r]:
		for dx in [-r, 0, r]:
			var qx: int = clampi(x + dx, 0, img.get_width() - 1)
			var qy: int = clampi(y + dy, 0, img.get_height() - 1)
			if img.get_pixel(qx, qy).get_luminance() > FACE_DARK:
				return true
	return false


## The painting as the surface wears it: [param painted] cut back to the surface's own millimeters from its canvas [param canvas]
## ([method face_canvas]; its bare picture [param bare]), FACE_PX pixels a millimeter, with the light the bare surface was shown in taken
## out - a color as laid, for the decorator to copy (never laid by the table); clear where the surface is not.
static func face_reference(painted: Image, bare: Image, canvas: Dictionary, skin: Dictionary) -> Image:
	var p := painted.duplicate() as Image
	if p.get_size() != bare.get_size():
		p.resize(bare.get_width(), bare.get_height(), Image.INTERPOLATE_BILINEAR)
	p.convert(Image.FORMAT_RGBA8)
	var at: Vector2i = canvas["at"]
	var size: Vector2i = canvas["size"]
	var base := Color.html(String(skin.get("color", "#e8e2d6")))
	var base_l := maxf(base.get_luminance(), 0.05)
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var c := p.get_pixel(at.x + x, at.y + y)
			var b := bare.get_pixel(at.x + x, at.y + y)
			var lit := clampf(b.get_luminance() / base_l, FACE_AMBIENT, 1.0)
			# (the room round the surface, inside its frame's corners, is none of it)
			out.set_pixel(x, y, Color(minf(c.r / lit, 1.0), minf(c.g / lit, 1.0), minf(c.b / lit, 1.0), 1.0 if b.get_luminance() > FACE_DARK else 0.0))
	return out


## The paints on table [param table] (`table.json`'s): each cream's and powder's name and color, `["name #rrggbb", ...]` - what the face
## painted first is told to paint with, so a hand at the table can lay every color of it.
static func table_paints(table: Dictionary) -> Array:
	var out: Array = []
	var mats: Dictionary = table.get("materials", {})
	for nm in mats:
		var m: Dictionary = mats[nm] if mats[nm] is Dictionary else {}
		if String(m.get("kind", "")) in ["cream", "powder"] and Props._is_color(m.get("color")):
			out.append("%s %s" % [String(nm), Props._color(m["color"], "#808080")])
	return out


## The painting's own colors, as a decorator copies them: [param ref] ([method face_reference]) taken [param many] colors, most of the
## surface first - `[{hex, share}]`, each color's share of the surface's points.
static func face_palette(ref: Image, many := 8) -> Array:
	var pts := PackedColorArray()
	# (every second millimeter: a few thousand points, on the thread the decorator is started from)
	for y in range(0, ref.get_height(), 6):
		for x in range(0, ref.get_width(), 6):
			var c := ref.get_pixel(x, y)
			if c.a > 0.5:
				pts.append(c)
	if pts.is_empty():
		return []
	# (k-means from points spread through the picture, a few rounds: colors a painter could mix)
	var centers := PackedColorArray()
	for k in many:
		centers.append(pts[(k * pts.size()) / many])
	var owner := PackedInt32Array()
	owner.resize(pts.size())
	for _round in 8:
		var sums: Array = []
		var counts := PackedInt32Array()
		counts.resize(many)
		for k in many:
			sums.append(Vector3.ZERO)
		for i in pts.size():
			var c := pts[i]
			var best := 0
			var bd := INF
			for k in many:
				var d := Vector3(c.r - centers[k].r, c.g - centers[k].g, c.b - centers[k].b).length_squared()
				if d < bd:
					bd = d
					best = k
			owner[i] = best
			sums[best] += Vector3(c.r, c.g, c.b)
			counts[best] += 1
		for k in many:
			if counts[k] > 0:
				var m: Vector3 = sums[k] / float(counts[k])
				centers[k] = Color(m.x, m.y, m.z)
	var counts2 := PackedInt32Array()
	counts2.resize(many)
	for i in pts.size():
		counts2[owner[i]] += 1
	var out: Array = []
	for k in many:
		if counts2[k] > 0:
			out.append({"hex": "#" + centers[k].to_html(false), "share": float(counts2[k]) / float(pts.size())})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["share"]) > float(b["share"]))
	# (two that came out alike are one)
	var kept: Array = []
	for c in out:
		var cc := Color.html(String((c as Dictionary)["hex"]))
		var same := false
		for k in kept:
			var kc := Color.html(String((k as Dictionary)["hex"]))
			if Vector3(cc.r - kc.r, cc.g - kc.g, cc.b - kc.b).length() < 0.06:
				(k as Dictionary)["share"] = float((k as Dictionary)["share"]) + float((c as Dictionary)["share"])
				same = true
				break
		if not same:
			kept.append(c)
	return kept


## The language a design is written in, as a decorator reads it: the elements, their finishes and how a tool lays each.
static func describe() -> String:
	var lines := PackedStringArray()
	lines.append("A DESIGN is {\"name\", \"elements\": [...]}: its ELEMENTS in the order they go on - what goes on later lies over what went on before. Every place is in MILLIMETERS on the surface as it is seen straight from the front: x from its left edge to the right, y from its top edge down. Each element is {\"id\" (a short name of its own), \"stage\" (which stage of the work it belongs to, a word or two), \"paint\": \"#rrggbb\", \"finish\", \"opacity\" (0.05-1: how much of what is under it shows through, left out: the finish's), \"soft\" (millimeters its edge is softened, 0-%d: a blended shadow or a glow), and its shape - one of:" % int(SOFT_MOST))
	lines.append("- \"fill\": a closed SVG path (M, L, H, V, C, S, Q, T, A, Z - absolute or relative), filled - or \"all\", the whole surface (a base color). \"rule\": \"evenodd\" cuts holes where it crosses itself.")
	lines.append("- \"line\": an SVG path drawn along with \"width\" (millimeters, %.1f-%.0f), rounded at its ends - outlines, brows, cracks, filigree. Each subpath is drawn in its own strokes." % [WIDTH.x, WIDTH.y])
	lines.append("- \"dots\": [[x, y, r], ...] millimeters, each set with one press - up to %d." % MOST_DOTS)
	lines.append("- \"stones\": [[x, y, r], ...] - small gems carried from their dish and pressed on one at a time, up to %d; \"paint\" is their color." % MOST_STONES)
	lines.append("- \"smear\": the id of an element listed before it, and \"line\" the path that paint is dragged along with \"width\" (left out: %d): one pressed stroke that takes the paint from where it starts and thins and streaks it as it goes - a smudged edge, a dragged tear, a mouth smeared past its corner. It takes that element's paint and finish unless it says its own." % int(SMEAR_WIDTH))
	lines.append("- \"mist\": \"all\" or a closed path - a fine spray that lays no color, only a wet sheen over what is there, which dries to a soft glow in about a minute (a setting spray, last).")
	lines.append("FINISHES:")
	for k in FINISHES:
		lines.append("- %s: %s" % [k, String((FINISHES[k] as Dictionary)["blurb"])])
	lines.append("HOW EACH IS LAID, by the tool the work gives it: %s." % "; ".join(PackedStringArray(MANNERS.keys().map(func(k: String) -> String: return "%s - %s" % [k, String((MANNERS[k] as Dictionary)["blurb"])]))))
	return "\n".join(lines)


## A surface as a designer is told it ([method skins_of]): its name, its size, its outline and its landmarks.
static func told(skin: Dictionary) -> String:
	var frame: Vector2 = skin["frame"]
	var nm := String(skin["thing"]) + ("/" + String(skin["part"]) if not String(skin["part"]).is_empty() else "")
	var lines := PackedStringArray()
	lines.append("\"%s\": %d mm across and %d mm down, painted from its front over a bare %s %s." % [nm, roundi(frame.x), roundi(frame.y), skin.get("color", ""), String(skin["shape"])])
	if not String(skin.get("outline", "")).is_empty():
		lines.append("Its outline (where the surface ends - paint past it is on nothing): %s" % String(skin["outline"]))
	var lm: Dictionary = skin.get("landmarks", {})
	if not lm.is_empty():
		lines.append("Its landmarks (millimeters, left and right as you look at it):")
		for k in lm:
			var d: Dictionary = lm[k]
			var at: Vector2 = d["at"]
			var bit := "- %s: [%d, %d]" % [k, roundi(at.x), roundi(at.y)]
			if d.has("from"):
				bit += " from [%d, %d] to [%d, %d]" % [roundi((d["from"] as Vector2).x), roundi((d["from"] as Vector2).y), roundi((d["to"] as Vector2).x), roundi((d["to"] as Vector2).y)]
			elif float(d.get("wide", 0.0)) > 0.0:
				bit += ", about %d mm across" % roundi(float(d["wide"]))
			lines.append(bit)
	return "\n".join(lines)


## How long paint act [param act] takes at a hand's pace (seconds), from the files alone - the designs ([param doc], `skin.json`) and the
## table ([param table], `table.json`) - as [TablePaint] works it out on a table that stands; what a reader is told before one does.
static func act_natural(act: Dictionary, doc: Dictionary, table: Variant, pictured := false, folded := {}) -> float:
	var most := 0.0
	for tr in act.get("tracks", []):
		var t: Dictionary = tr
		if String(t.get("law", "")) != "paint":
			continue
		var on := String(t.get("on", ""))
		var design: Dictionary = {}
		for g in doc.get("designs", []):
			if g is Dictionary and String((g as Dictionary).get("thing", "")).to_lower() == on.get_slice("/", 0).to_lower():
				design = g
		if design.is_empty():
			continue
		var fr: Array = design.get("frame", [150.0, 210.0])
		var frame := Vector2(float(fr[0]), float(fr[1]))
		var made := sanitize(design, frame)
		var tool := _tool_in(table, String(t.get("thing", "")), String(t.get("part", "")))
		var total := TablePaint.FETCH + TablePaint.RETURN
		var loaded := ""
		for id in t.get("paint", []):
			# (...a coat the table folds into one before it lays nothing: [method folded_coats], TablePaint._one_coat)
			if folded.has(String(id).to_lower()):
				continue
			for e in made["elements"]:
				var ed: Dictionary = e
				if String(ed["id"]).to_lower() != String(id).to_lower():
					continue
				var manner := manner_of(ed, String(tool[0]), String(t.get("manner", "")))
				var mm := float(t["size"]) if t.has("size") else width_for(String(tool[0]), float(tool[1]), manner)
				var rect := rect_of(ed, frame, 0.0)
				var prog := program(ed, manner, mm, cover(ed, rect, WHEN_PX, String(design.get("outline", "")), frame), rect)
				# ...laid from the picture, as long as the table lets it take ([method TablePaint._from_picture]): its shape's program's time
				# and the share more it may run to - a foundation's, whole, the most
				var slack := 1.0
				if pictured and manner in TablePaint.PICTURE_MANNERS and String(ed["kind"]) in ["fill", "line", "dots"]:
					slack = TablePaint.FOUNDATION_SLACK if String(ed["kind"]) == "fill" and String(ed.get("d", "")) == "all" else TablePaint.PICTURE_TOLD
				# (...laid by a painter at the table: the seconds it took there - the painter's tools)
				var planned := float((ed.get("plan", {}) as Dictionary).get("seconds", 0.0)) if ed.get("plan") is Dictionary else 0.0
				total += TablePaint.MOVE + (planned if planned > 0.0 else float(prog["natural"]) * slack)
				if not String(ed["kind"]) in ["stones", "smear", "mist"] and manner != "blend" and String(ed["paint"]) != loaded:
					total += TablePaint.LOAD
					loaded = String(ed["paint"])
		most = maxf(most, total)
	return most


## The coats a table folds into one before (TablePaint._one_coat), as [param acts] (`acts.json`'s, in their order) and [param doc] say:
## each fill over the whole surface taken up from a pot an earlier one was taken from - `{id: true}` (lowered). Their acts lay nothing, so
## a reader must not be told time for them.
static func folded_coats(acts: Array, doc: Dictionary) -> Dictionary:
	var whole := {}
	for g in doc.get("designs", []):
		if not (g is Dictionary):
			continue
		# (...as the table reads it: an opening fill over most of the surface is one over all of it - [method _based])
		var fr: Array = (g as Dictionary).get("frame", [150.0, 210.0])
		var made := sanitize(g, Vector2(float(fr[0]), float(fr[1])), String((g as Dictionary).get("outline", "")))
		for e in made["elements"]:
			if String((e as Dictionary).get("kind", "")) == "fill" and String((e as Dictionary).get("d", "")) == "all":
				whole[String((e as Dictionary).get("id", "")).to_lower()] = true
	var seen := {}
	var out := {}
	for a in acts:
		for tr in (a as Dictionary).get("tracks", []) if a is Dictionary else []:
			var t: Dictionary = tr
			if String(t.get("law", "")) != "paint":
				continue
			var pot := String(t.get("from", "")).to_lower()
			for id in t.get("paint", []):
				var k := String(id).to_lower()
				if not whole.has(k) or pot.is_empty():
					continue
				if seen.has(pot) and seen[pot] != k:
					out[k] = true
				elif not seen.has(pot):
					seen[pot] = k
	return out


## What tool [param thing] (its part [param part]) is on table [param table]: [its kind - brush, sponge or tool -, how wide it works].
static func _tool_in(table: Variant, thing: String, part: String) -> Array:
	if not (table is Dictionary):
		return ["tool", 6.0]
	var safe := Props.sanitize(table as Dictionary, [])
	for t in safe.get("things", []):
		if String((t as Dictionary)["name"]).to_lower() != thing.to_lower():
			continue
		var found := _tool_of_parts((t as Dictionary)["parts"], safe.get("materials", {})) if part.is_empty() \
			else _tool_parts((t as Dictionary)["parts"], part.to_lower(), false, safe.get("materials", {}))
		if not found.is_empty():
			return found
	return ["tool", 6.0]


static func _tool_parts(parts: Array, part: String, within: bool, mats: Dictionary) -> Array:
	for p in parts:
		var pd: Dictionary = p
		var named := String((pd.get("work", {}) as Dictionary).get("name", "")).to_lower()
		if (within and part.is_empty()) or (not part.is_empty() and named == part):
			return _tool_of_parts([pd], mats)
		if pd.get("parts") is Array:
			var got := _tool_parts(pd["parts"], part, false, mats)
			if not got.is_empty():
				return got
	return []


## A tool made of [param parts] (made safe), measured as [method TablePaint.tool_of] measures one that stands: a tuft makes it a brush
## as wide as its hairs - and says its tip's kind, a third (a cotton swab's bud lays no paint: [constant Bristles.KINDS]); sponge makes it
## a sponge as wide as its face; anything else a tool as thin as it is.
static func _tool_of_parts(parts: Array, mats: Dictionary) -> Array:
	var leaves: Array = []
	_leaves_of(parts, Transform3D.IDENTITY, leaves)
	var box := AABB()
	var first := true
	var sponge := false
	for lf in leaves:
		var pd: Dictionary = lf[0]
		if String(pd.get("shape", "")) == "tuft":
			return ["brush", float(pd.get("width", 0.7)) * 10.0, String(pd.get("kind", "round"))]
		var m: Dictionary = mats.get(String(pd.get("material", "")), {})
		sponge = sponge or String(m.get("kind", "")) == "sponge"
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		for g in Props._geometry(pd, rng):
			var b: AABB = (lf[1] as Transform3D) * Props._bounds_of((g as Dictionary)["geo"])
			box = b if first else box.merge(b)
			first = false
	if first:
		return []
	var dims := [box.size.x, box.size.y, box.size.z]
	dims.sort()
	if sponge:
		return ["sponge", sqrt(float(dims[1]) * float(dims[2])) * 1000.0 * 0.7]
	if float(dims[0]) < float(dims[1]) * 0.5 and float(dims[1]) > float(dims[2]) * 0.5:
		return ["tool", clampf(sqrt(float(dims[1]) * float(dims[2])) * 1000.0 * 0.7, 3.0, 60.0)]
	return ["tool", clampf(float(dims[0]) * 1000.0, 3.0, 40.0)]


static func _leaves_of(parts: Array, xf: Transform3D, out: Array) -> void:
	for p in parts:
		var pd: Dictionary = p
		var own := xf * Transform3D(Basis.from_euler((pd.get("turn", Vector3.ZERO) as Vector3) * (PI / 180.0)), (pd.get("at", Vector3.ZERO) as Vector3) * 0.01)
		if pd.get("parts") is Array:
			_leaves_of(pd["parts"], own, out)
		else:
			out.append([pd, own])
