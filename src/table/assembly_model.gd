extends RefCounted
class_name AssemblyModel

## AssemblyModel - the thing being built, designed before a piece is picked up (next/assembly.md "The model").
##
## What an agent writes is shapes, not pieces ([constant SHAPES]): a program of boxes, rounds, land from a formula, walls along a line, a
## roof, all painted into a grid of cells a stud across and a plate tall, in named sections, in the order they are built. Nothing it
## writes is run as code: formulas are [Formula]'s.
##
## What is laid is real parts ([method _lay]): what the cells come to in what is really made, each course's joints off the last's so it
## holds together, plates across wide floors and bricks in thin walls - whatever takes up the most at once. Hollow inside
## ([method _hollowed]), because nobody can see in and a solid hill is thousands of pieces.
##
## It really holds ([method _ordered]): every part is joined to the plate through studs, what is joined only through the plate above it
## hung from that, in an order a hand could build it. A floor over a hollow gets a pillar under it where that was hidden anyway; what was
## designed to hang in the air is said to the designer in words, with where.
##
## A pure function of what was written, safe on a worker: no node, no global.

## What a model is made of: each kind of shape, its `fields`, its words an agent's. Every shape also takes those of [constant ANY_SHAPE].
const SHAPES := {
	"box": {"label": "Box", "blurb": "a solid block: a wall, a floor, a tower, a base", "fields": [["from", "[x, z, y] one corner cell"], ["to", "[x, z, y] the other, inclusive"]]},
	"round": {"label": "Round", "blurb": "an upright round: a tower, a tree's trunk, a silo; given `top_radius`, a cone or a tapering stack", "fields": [["at", "[x, z] its middle"], ["radius", "cells, or [across, deep] for an oval"], ["y", "[from, to] levels"], ["top_radius", "cells at its top (left out: as at its foot)"], ["step", "how many levels stand alike before it changes (left out: 3, a brick's: 1 is smooth and costs far more)"]]},
	"ball": {"label": "Ball", "blurb": "a ball or a squashed one: a treetop, a boulder, a dome", "fields": [["at", "[x, z, y] its middle"], ["radius", "cells, or [across, deep, up]: a plate is much thinner than a stud is wide, so a round ball is about 2.5 times as many levels up as cells across"], ["step", "as a round's"]]},
	"land": {"label": "Land", "blurb": "ground whose height is a formula: hills, shores, cliffs, dunes, everything up from `floor` to that height at each x and z. Most of anything big and natural is this", "fields": [["height", "a formula of x and z, in levels: 0 or less leaves that place empty. \"30*exp(-((x-24)^2+(z-24)^2)/120)+3*noise2(x*0.2,z*0.2)\" is a lumpy hill"], ["from", "[x, z] one corner of where it is worked out (left out: the whole plate)"], ["to", "[x, z] the other"], ["floor", "the level it fills up from (left out: 0)"], ["step", "its height is rounded to this many levels: 3, a brick's, is cheap and bold, and 1 is smooth and costs far more (left out: 3)"]]},
	"where": {"label": "Where", "blurb": "any shape at all: a cell is filled where a formula of x, z and y comes to more than 0. Arches, spirals, hulls, rock, anything", "fields": [["if", "a formula of x, z and y"], ["from", "[x, z, y] one corner of where it is looked for"], ["to", "[x, z, y] the other"], ["step", "y is rounded down to this many levels before the formula sees it (left out: 3, a brick's, for what changes from level to level costs a plate there; 1 is exact and costs far more)"]]},
	"line": {"label": "Line", "blurb": "a stroke along points: a wall that bends, a road, a river, a path, a ramp, a bridge's deck", "fields": [["points", "[[x, z], ...], or [[x, z, y], ...] where its foot climbs along the way"], ["width", "cells across (left out: 2)"], ["y", "the level its foot is at, for points with no y (left out: 0)"], ["tall", "levels from its foot up (left out: 3)"]]},
	"roof": {"label": "Roof", "blurb": "a pitched roof over a rectangle, laid in real sloped parts: two sides stepping in to a ridge, its gable ends filled", "fields": [["from", "[x, z] one corner of what it covers"], ["to", "[x, z] the other"], ["y", "the level it starts at"], ["ridge", "\"x\" or \"z\": which way the ridge runs (left out: along the longer side)"]]},
	"part": {"label": "Part", "blurb": "one real part where it must be exactly that part: an arch for a doorway, a round post, a window's sill. What is written here is kept as it is, whatever else fills round it", "fields": [["part", "\"<kind> <across>x<deep> <color>\""], ["at", "[x, z, level] its far left corner"], ["turn", "0, 90, 180 or 270"]]},
}
## What any shape takes.
const ANY_SHAPE := [["color", "a color's name (a `part` has its own)"],
	["carve", "true: cut this shape out of what is there, for a door, a window, a cove, a tunnel"],
	["paint", "true: color what is already there, inside this shape, and add nothing: strata, a stripe, a shoreline, moss, snow"],
	["top", "with `paint`: only what is open to the sky: grass on land, snow on rock"],
	["slopes", "true: where its edges drop by a brick or more they are finished in sloped parts rather than square steps: rock, roofs of land, hulls"],
	["repeat", "{\"n\": how many, \"by\": [x, z, y] from each to the next}: a row of windows, of posts, a stair"],
	["mirror", "\"x\": it and its copy across the plate's middle, left and right; \"z\": near and far; \"both\": four"]]
## The limits: how tall (levels), how many sections and shapes, and how many parts it may come to.
const TALL_MOST := 150
const SECTIONS_MOST := 24
const SHAPES_MOST := 400
const PARTS_MOST := 1100
## What a model should come to (parts): about five seconds a piece, so this is most of an hour.
const PARTS_AIM := Vector2i(350, 800)
## How many levels make a course: a brick's height. Everything lies on these unless it was written otherwise, and a brick not on one goes down only where nothing goes on above it.
const COURSE := 3
## A hollow's walls: how far from anything empty a cell must be to be left out: studs across, levels up and down.
const SHELL := Vector2i(1, 3)
## Passes at what was hollowed out and left hanging ([method _pillars]).
const PILLAR_PASSES := 6
## The runs of sloped parts along an edge, as they are made.
const SLOPE_RUNS := [4, 3, 2, 1]

const EMPTY := 0
const TAKEN := 255


## How a model is written, in words, for whoever designs one.
static func describe() -> String:
	var lines := PackedStringArray()
	lines.append("A MODEL IS {\"name\": what it is in plain words, \"size\": [across, deep] studs of its plate, %d to %d, \"colors\": {a name: \"#rrggbb\", up to %d}, \"base_color\": the plate's color, \"sections\": [each {\"name\", \"about\": a short phrase, \"shapes\": [...]}, in the order they are built, up to %d]}." % [Assembly.BASE_SIZES.x, Assembly.BASE_SIZES.y, Assembly.MAX_COLORS, SECTIONS_MOST])
	lines.append("THE GRID: a cell is one stud across and one level up. x runs left to right, z from far to near, both from 0 on the plate, and y up from 0 on the plate. A level is thin: 3 levels are a brick's height, and a stud is about as wide as 2.5 levels are tall, so a cube is about 8 cells across, 8 deep and 20 up, and a door a figure could use is 2 across and 12 up.")
	lines.append("THE SHAPES, painted into it in the order written, each {\"shape\": its name, and its fields} (a later one over an earlier one wins):")
	for k in SHAPES:
		var row: Dictionary = SHAPES[k]
		lines.append("- %s: %s." % [k, String(row["blurb"])])
		for f in row["fields"]:
			lines.append("    `%s`: %s" % [String(f[0]), String(f[1])])
	lines.append("ANY SHAPE ALSO TAKES:")
	for f in ANY_SHAPE:
		lines.append("    `%s`: %s" % [String(f[0]), String(f[1])])
	lines.append("A FORMULA: numbers, x, z and y, + - * / %% ^, parentheses, and %s. noise2(a, b) is smooth noise from -1 to 1: scale what goes into it to set how broad its lumps are." % ", ".join(PackedStringArray(Formula.FUNCS.keys())))
	lines.append("WHAT IT COMES TO: you say the shapes, and the real parts are worked out for you: the fewest that will do, each course's joints off the last's, hollow inside where nobody can see. Aim for %d to %d parts in all: about five seconds each, so that is most of an hour's work. Over %d is too many. What costs parts is edge, not size: a wide floor is a few big plates, and a rough shoreline is many small ones. A heavy color change a level at a time costs a plate each; on whole courses of 3 levels it costs nothing." % [PARTS_AIM.x, PARTS_AIM.y, PARTS_MOST])
	return "\n".join(lines)


# --- made ------------------------------------------------------------------------------------------------------

## What [param raw] comes to: `{name, size, colors, base_color, sections: [{name, about, parts}], parts: [{kind, w, d, turn, color, x, z, l, section}, in the order they go on], floating: [words], notes, top,
## cells}`. [param raw] as far as it can be used: what could not be is in `notes`.
static func make(raw: Variant) -> Dictionary:
	var out := {"name": "", "size": [Assembly.BASE_SIZE, Assembly.BASE_SIZE], "colors": {}, "base_color": "", "sections": [], "parts": [], "floating": [], "notes": PackedStringArray(), "top": 0, "cells": 0}
	var notes: PackedStringArray = out["notes"]
	if not (raw is Dictionary):
		notes.append("a model is an object: {name, size, colors, sections}")
		return out
	var d: Dictionary = raw
	out["name"] = String(d.get("name", "")).strip_edges() if d.get("name") is String else ""
	var size: Array = d.get("size") if d.get("size") is Array and (d.get("size") as Array).size() == 2 else [Assembly.BASE_SIZE, Assembly.BASE_SIZE]
	var w := clampi(int(Assembly._num(size[0], Assembly.BASE_SIZE)), Assembly.BASE_SIZES.x, Assembly.BASE_SIZES.y)
	var dp := clampi(int(Assembly._num(size[1], Assembly.BASE_SIZE)), Assembly.BASE_SIZES.x, Assembly.BASE_SIZES.y)
	out["size"] = [w, dp]
	var colors: Dictionary = {}
	for k in (d.get("colors") if d.get("colors") is Dictionary else {}):
		var name := String(k).strip_edges().to_lower()
		var v: Variant = (d["colors"] as Dictionary)[k]
		if name.is_empty() or not (v is String) or not Color.html_is_valid(String(v).strip_edges()):
			notes.append("the color \"%s\" is not {name: \"#rrggbb\"}: left out" % str(k))
		elif colors.size() >= Assembly.MAX_COLORS:
			notes.append("more than %d colors: \"%s\" left out" % [Assembly.MAX_COLORS, name])
		else:
			colors[name] = "#" + Color.html(String(v).strip_edges()).to_html(false)
	out["colors"] = colors
	if colors.is_empty():
		notes.append("no colors: a model needs {\"colors\": {\"its name\": \"#rrggbb\"}}")
		return out
	var bc := String(d.get("base_color", "")).strip_edges().to_lower() if d.get("base_color") is String else ""
	if not colors.has(bc) and not bc.is_empty():
		notes.append("base_color \"%s\" is none of the colors" % bc)
	out["base_color"] = bc if colors.has(bc) else String(colors.keys()[0])
	var g := Grid.new(w, dp, TALL_MOST, colors.keys())
	var sections: Array = out["sections"]
	var count := 0
	for s in (d.get("sections") if d.get("sections") is Array else []):
		if sections.size() >= SECTIONS_MOST:
			notes.append("more than %d sections: the rest left out" % SECTIONS_MOST)
			break
		if not (s is Dictionary):
			continue
		var sd: Dictionary = s
		var nm := String(sd.get("name", "")).strip_edges().to_lower() if sd.get("name") is String else ""
		if nm.is_empty():
			nm = "section %d" % (sections.size() + 1)
		var si := sections.size()
		sections.append({"name": nm, "about": String(sd.get("about", "")).strip_edges() if sd.get("about") is String else "", "parts": 0})
		for sh in (sd.get("shapes") if sd.get("shapes") is Array else []):
			count += 1
			if count > SHAPES_MOST:
				notes.append("more than %d shapes: the rest left out" % SHAPES_MOST)
				break
			if sh is Dictionary:
				_shape(g, sh as Dictionary, si, notes)
			else:
				notes.append("a shape is {\"shape\": ..., ...}")
	if sections.is_empty():
		notes.append("no sections: a model needs {\"sections\": [{\"name\", \"shapes\"}]}")
		return out
	g.slope_edges()
	var filled := g.filled()
	out["cells"] = filled
	var parts: Array = []
	var floating: Array = []
	var extra := {}
	var bridge := {}
	var least := INF
	for pass_i in PILLAR_PASSES:
		var kept := _hollowed(g, extra)
		var tried: Array = g.fixed.duplicate()
		_lay(g, kept, tried, bridge)
		var hung := _ordered(tried, w, dp)
		# ...the best of them is what is kept: what hangs because it was written in the air will go on hanging, and thickening round it would only cost
		if float((hung["floating"] as Array).size()) < least:
			least = float((hung["floating"] as Array).size())
			floating = hung["floating"]
			parts = hung["parts"]
		if (hung["floating"] as Array).is_empty():
			break
		var thicker := _pillars(g, hung["floating"], extra, pass_i + 1)
		var bridged := _bridged(g, hung["floating"], bridge)
		if not thicker and not bridged:
			break
	var top := 0
	for p in parts:
		var q: Dictionary = p
		top = maxi(top, int(q["l"]) + int((Assembly.KINDS[String(q["kind"])] as Dictionary)["h"]))
		var sec: Dictionary = sections[int(q["section"])]
		sec["parts"] = int(sec["parts"]) + 1
	out["parts"] = parts
	out["top"] = top
	for f in floating:
		var q: Dictionary = f
		(out["floating"] as Array).append("%s at [%d, %d, %d] of \"%s\"" % [Assembly.part_key(q), int(q["x"]), int(q["z"]), int(q["l"]), String((sections[int(q["section"])] as Dictionary)["name"])])
	return out


## What was made, as anyone would say it: its size, its parts by section, and what floats.
static func report(m: Dictionary) -> String:
	var lines := PackedStringArray()
	var parts: Array = m["parts"]
	lines.append("\"%s\": %d parts, on a plate of %d x %d studs, %d levels tall (%.0f cm)." % [String(m["name"]), parts.size(), int((m["size"] as Array)[0]), int((m["size"] as Array)[1]), int(m["top"]), float(m["top"]) * Assembly.PLATE * 100.0])
	for s in m["sections"]:
		lines.append("  %-24s %4d parts%s" % [String((s as Dictionary)["name"]), int((s as Dictionary)["parts"]), (": " + String((s as Dictionary)["about"])) if not String((s as Dictionary)["about"]).is_empty() else ""])
	if parts.size() > PARTS_MOST:
		lines.append("THAT IS TOO MANY: at most %d. Use `step` 3 on land, fewer small things, wider sizes." % PARTS_MOST)
	elif parts.size() < PARTS_AIM.x:
		lines.append("That is few for what the time allows: %d to %d is the aim. It can be bigger, and it can have more in it." % [PARTS_AIM.x, PARTS_AIM.y])
	elif parts.size() > PARTS_AIM.y:
		lines.append("That is more than the aim of %d to %d, and it may run long." % [PARTS_AIM.x, PARTS_AIM.y])
	if not (m["floating"] as Array).is_empty():
		var some: Array = (m["floating"] as Array).slice(0, 6)
		lines.append("%d PARTS HOLD ON TO NOTHING, no stud joining them to the plate: most often a thing standing in the air over ground lower than you thought, or parts side by side with nothing across them, for what lies beside another is not joined to it. Run it down to the ground, or lay another course across. For one: %s." % [(m["floating"] as Array).size(), ", ".join(PackedStringArray(some))])
	for n in m["notes"]:
		lines.append("NOTE: " + String(n))
	return "\n".join(lines)


## The model from straight above: each stud's highest color, by its first letter, and how many levels up, for what a picture cannot quite say.
static func plan_text(m: Dictionary) -> String:
	var w := int((m["size"] as Array)[0])
	var dp := int((m["size"] as Array)[1])
	var letter := {}
	var high := {}
	for p in m["parts"]:
		var q: Dictionary = p
		var top := int(q["l"]) + int((Assembly.KINDS[String(q["kind"])] as Dictionary)["h"])
		for c in Assembly.cells_of(String(q["kind"]), int(q["w"]), int(q["d"]), int(q["turn"]), int(q["x"]), int(q["z"]), int(q["l"])):
			var at := Vector2i(int(c[0]), int(c[1]))
			if top >= int(high.get(at, -1)):
				high[at] = top
				letter[at] = String(q["color"]).left(1).to_upper()
	var lines := PackedStringArray(["From straight above, z from far (top) to near, each stud's highest color by its first letter (. nothing):"])
	for z in dp:
		var row := ""
		for x in w:
			row += String(letter.get(Vector2i(x, z), "."))
		lines.append("  " + row)
	return "\n".join(lines)


# --- painted -----------------------------------------------------------------------------------------------------

## Shape [param sh] of section [param si] painted, or said why not.
static func _shape(g: Grid, sh: Dictionary, si: int, notes: PackedStringArray) -> void:
	var kind := String(sh.get("shape", "")).strip_edges().to_lower()
	if not SHAPES.has(kind):
		notes.append("\"%s\" is not a shape (%s)" % [kind, ", ".join(PackedStringArray(SHAPES.keys()))])
		return
	var mirror := String(sh.get("mirror", "")) if sh.get("mirror") is String else ""
	var rep: Dictionary = sh.get("repeat") if sh.get("repeat") is Dictionary else {}
	var n := clampi(int(Assembly._num(rep.get("n"), 1.0)), 1, 64)
	var by: Array = rep.get("by") if rep.get("by") is Array and (rep.get("by") as Array).size() == 3 else [0, 0, 0]
	var color := -1
	if kind != "part":
		var named := String(sh.get("color", "")).strip_edges().to_lower() if sh.get("color") is String else ""
		color = g.names.find(named)
		if color < 0 and not bool(sh.get("carve", false)):
			notes.append("a %s's color \"%s\" is none of the colors (%s)" % [kind, named, ", ".join(PackedStringArray(g.names))])
			return
	var compiled := {}
	for key in ["height", "if"]:
		if sh.has(key):
			var got := Formula.compile(str(sh[key]), PackedStringArray(["x", "z", "y"]))
			if not bool(got["ok"]):
				notes.append("a %s's %s \"%s\": %s" % [kind, key, str(sh[key]), String(got["error"])])
				return
			compiled[key] = got["code"]
	for i in n:
		var off := Vector3i(int(Assembly._num(by[0], 0.0)) * i, int(Assembly._num(by[2], 0.0)) * i, int(Assembly._num(by[1], 0.0)) * i)
		for mx in ([false, true] if mirror == "x" or mirror == "both" else [false]):
			for mz in ([false, true] if mirror == "z" or mirror == "both" else [false]):
				var fx := Flip.new(g, off, mx, mz)
				_paint(g, sh, kind, color, si, compiled, fx, notes)


## Where a shape's own cell lands: repeated along, and mirrored across the plate's middle.
class Flip:
	var w := 0
	var d := 0
	var off := Vector3i.ZERO
	var mx := false
	var mz := false

	func _init(g: Grid, o: Vector3i, x_flip: bool, z_flip: bool) -> void:
		w = g.w
		d = g.d
		off = o
		mx = x_flip
		mz = z_flip

	func at(x: int, z: int, y: int) -> Vector3i:
		var nx := x + off.x
		var nz := z + off.z
		return Vector3i(w - 1 - nx if mx else nx, y + off.y, d - 1 - nz if mz else nz)


## One copy of a shape, as a run over what could be in it: each cell a shape says is in it goes through [method Grid.touch].
static func _paint(g: Grid, sh: Dictionary, kind: String, color: int, si: int, compiled: Dictionary, fx: Flip, notes: PackedStringArray) -> void:
	var act := Stroke.new(g, sh, color, si, fx)
	match kind:
		"box":
			var a := _three(sh.get("from"))
			var b := _three(sh.get("to"))
			if a.is_empty() or b.is_empty():
				notes.append("a box needs `from` and `to`, each [x, z, y]")
				return
			for y in range(mini(a[2], b[2]), maxi(a[2], b[2]) + 1):
				for z in range(mini(a[1], b[1]), maxi(a[1], b[1]) + 1):
					for x in range(mini(a[0], b[0]), maxi(a[0], b[0]) + 1):
						act.cell(x, z, y)
		"round":
			var at: Array = sh.get("at") if sh.get("at") is Array and (sh.get("at") as Array).size() >= 2 else []
			var ys: Array = sh.get("y") if sh.get("y") is Array and (sh.get("y") as Array).size() == 2 else []
			if at.is_empty() or ys.is_empty():
				notes.append("a round needs `at` [x, z], `radius` and `y` [from, to]")
				return
			var r := _radii(sh.get("radius"))
			var tr := _radii(sh.get("top_radius")) if sh.has("top_radius") else r
			var y0 := int(Assembly._num(ys[0], 0.0))
			var y1 := int(Assembly._num(ys[1], 0.0))
			var reach := maxf(maxf(r.x, r.y), maxf(tr.x, tr.y))
			var cx := Assembly._num(at[0], 0.0)
			var cz := Assembly._num(at[1], 0.0)
			var course := maxi(int(Assembly._num(sh.get("step"), 3.0)), 1)
			for y in range(mini(y0, y1), maxi(y0, y1) + 1):
				var u := clampf(float(y - posmod(y - y0, course) - y0) / float(maxi(y1 - y0, 1)), 0.0, 1.0)
				var rx := maxf(lerpf(r.x, tr.x, u), 0.01)
				var rz := maxf(lerpf(r.y, tr.y, u), 0.01)
				for z in range(floori(cz - reach), ceili(cz + reach) + 1):
					for x in range(floori(cx - reach), ceili(cx + reach) + 1):
						if pow((float(x) + 0.5 - cx) / rx, 2.0) + pow((float(z) + 0.5 - cz) / rz, 2.0) <= 1.0:
							act.cell(x, z, y)
		"ball":
			var at: Array = sh.get("at") if sh.get("at") is Array and (sh.get("at") as Array).size() == 3 else []
			if at.is_empty():
				notes.append("a ball needs `at` [x, z, y] and `radius`")
				return
			var v: Variant = sh.get("radius")
			var rx := 4.0
			var rz := 4.0
			var ry := 10.0
			if v is Array and (v as Array).size() == 3:
				rx = Assembly._num(v[0], 4.0)
				rz = Assembly._num(v[1], 4.0)
				ry = Assembly._num(v[2], 10.0)
			elif Assembly._is_num(v):
				rx = float(v)
				rz = float(v)
				ry = float(v) * 2.5
			var cx := Assembly._num(at[0], 0.0)
			var cz := Assembly._num(at[1], 0.0)
			var cy := Assembly._num(at[2], 0.0)
			var course := maxi(int(Assembly._num(sh.get("step"), 3.0)), 1)
			for y in range(floori(cy - ry), ceili(cy + ry) + 1):
				var mid := float(y - posmod(y, course)) + float(course) * 0.5
				for z in range(floori(cz - rz), ceili(cz + rz) + 1):
					for x in range(floori(cx - rx), ceili(cx + rx) + 1):
						if pow((float(x) + 0.5 - cx) / maxf(rx, 0.01), 2.0) + pow((float(z) + 0.5 - cz) / maxf(rz, 0.01), 2.0) + pow((mid - cy) / maxf(ry, 0.01), 2.0) <= 1.0:
							act.cell(x, z, y)
		"land":
			if not compiled.has("height"):
				notes.append("land needs `height`, a formula of x and z")
				return
			var a := _two(sh.get("from"), Vector2i.ZERO)
			var b := _two(sh.get("to"), Vector2i(g.w - 1, g.d - 1))
			var step := maxi(int(Assembly._num(sh.get("step"), 3.0)), 1)
			var from_y := int(Assembly._num(sh.get("floor"), 0.0))
			var vars := {"x": 0.0, "z": 0.0, "y": 0.0}
			for z in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
					vars["x"] = float(x)
					vars["z"] = float(z)
					var h := int(round(Formula.run(compiled["height"], vars) / float(step))) * step
					for y in range(from_y, mini(h, TALL_MOST)):
						act.cell(x, z, y)
		"where":
			if not compiled.has("if"):
				notes.append("where needs `if`, a formula of x, z and y")
				return
			var a := _three(sh.get("from"))
			var b := _three(sh.get("to"))
			if a.is_empty() or b.is_empty():
				notes.append("a where needs `from` and `to`, each [x, z, y]: where to look")
				return
			var vars := {"x": 0.0, "z": 0.0, "y": 0.0}
			var course := maxi(int(Assembly._num(sh.get("step"), 3.0)), 1)
			for y in range(mini(a[2], b[2]), maxi(a[2], b[2]) + 1):
				vars["y"] = float(y - posmod(y, course))
				for z in range(mini(a[1], b[1]), maxi(a[1], b[1]) + 1):
					vars["z"] = float(z)
					for x in range(mini(a[0], b[0]), maxi(a[0], b[0]) + 1):
						vars["x"] = float(x)
						if Formula.run(compiled["if"], vars) > 0.0:
							act.cell(x, z, y)
		"line":
			var pts: Array = sh.get("points") if sh.get("points") is Array else []
			if pts.size() < 2:
				notes.append("a line needs `points`, at least two")
				return
			var half := Assembly._num(sh.get("width"), 2.0) * 0.5
			var tall := maxi(int(Assembly._num(sh.get("tall"), 3.0)), 1)
			var y0 := int(Assembly._num(sh.get("y"), 0.0))
			for i in range(1, pts.size()):
				var p0 := _point(pts[i - 1], y0)
				var p1 := _point(pts[i], y0)
				var lo := Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)) - Vector2(half, half)
				var hi := Vector2(maxf(p0.x, p1.x), maxf(p0.y, p1.y)) + Vector2(half, half)
				for z in range(floori(lo.y), ceili(hi.y) + 1):
					for x in range(floori(lo.x), ceili(hi.x) + 1):
						var q := Vector2(float(x) + 0.5, float(z) + 0.5)
						var a2 := Vector2(p0.x, p0.y)
						var ab := Vector2(p1.x, p1.y) - a2
						var u := clampf((q - a2).dot(ab) / maxf(ab.length_squared(), 1e-5), 0.0, 1.0)
						if (a2 + ab * u).distance_to(q) <= half:
							var foot := int(round(lerpf(p0.z, p1.z, u)))
							for y in range(foot, foot + tall):
								act.cell(x, z, y)
		"roof":
			_roof(g, sh, color, si, fx, notes)
		"part":
			_written_part(g, sh, si, fx, notes)


## A roof of real sloped parts over the rectangle written, its two sides stepping in, a stud a brick, to a ridge. Each side's run is what is made ([constant SLOPE_RUNS]); its gable ends are filled in cells.
static func _roof(g: Grid, sh: Dictionary, color: int, si: int, fx: Flip, notes: PackedStringArray) -> void:
	if not (sh.get("from") is Array and sh.get("to") is Array):
		notes.append("a roof needs `from` and `to`, each [x, z]")
		return
	var a := _two(sh.get("from"), Vector2i.ZERO)
	var b := _two(sh.get("to"), Vector2i.ZERO)
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var z0 := mini(a.y, b.y)
	var z1 := maxi(a.y, b.y)
	var y := int(Assembly._num(sh.get("y"), 0.0))
	var ridge := String(sh.get("ridge", "")) if sh.get("ridge") is String else ""
	if ridge != "x" and ridge != "z":
		ridge = "x" if x1 - x0 >= z1 - z0 else "z"
	var name := String(g.names[color])
	# ...along x it falls toward z, the near side at no turn and the far at half a turn; along z, the same a quarter on
	var along := x1 - x0 + 1 if ridge == "x" else z1 - z0 + 1
	var across := z1 - z0 + 1 if ridge == "x" else x1 - x0 + 1
	var course := 0
	while across - course * 2 >= 2:
		var lv := y + course * 3
		var taken := 0
		while taken < along:
			var run := 1
			for r in SLOPE_RUNS:
				if int(r) <= along - taken:
					run = int(r)
					break
			if ridge == "x":
				var px := x0 + taken
				var turn_near := 0
				var turn_far := 180
				_slope(g, run, 2, turn_near, px, z1 - course - 1, lv, name, si, fx)
				_slope(g, run, 2, turn_far, px, z0 + course, lv, name, si, fx)
			else:
				var pz := z0 + taken
				_slope(g, run, 2, 90, x1 - course - 1, pz, lv, name, si, fx)
				_slope(g, run, 2, 270, x0 + course, pz, lv, name, si, fx)
			taken += run
		course += 1
	# ...the rows left under the ridge, and the gable ends, in cells
	var stroke := Stroke.new(g, {}, color, si, fx)
	for c in course + 1:
		var lv := y + c * 3
		for l in range(lv, lv + 3):
			for t in [0, along - 1]:
				for u in range(c, across - c):
					if c < course and (u == c or u == across - c - 1 or u == c + 1 or u == across - c - 2):
						continue
					if ridge == "x":
						stroke.cell(x0 + int(t), z0 + u, l)
					else:
						stroke.cell(x0 + u, z0 + int(t), l)


## A sloped part put down as the model has it, whichever way it was flipped.
static func _slope(g: Grid, across: int, deep: int, turn: int, x: int, z: int, l: int, color: String, si: int, fx: Flip) -> void:
	var size := Assembly.turned_size(across, deep, turn)
	var corner := fx.at(x, z, l)
	var t := turn
	if fx.mx:
		corner.x -= size.x - 1
		t = posmod(360 - t, 360)
	if fx.mz:
		corner.z -= size.y - 1
		t = posmod(180 - t, 360)
	g.put({"kind": "slope", "w": across, "d": deep, "turn": t, "color": color, "x": corner.x, "z": corner.z, "l": corner.y, "section": si})


static func _written_part(g: Grid, sh: Dictionary, si: int, fx: Flip, notes: PackedStringArray) -> void:
	var colors := {}
	for n in g.names:
		colors[n] = true
	var why: Array = []
	var part := Assembly.parse_part(sh.get("part"), colors, why)
	if part.is_empty():
		notes.append(String(why[0]) if not why.is_empty() else "a part could not be read")
		return
	var at := _three(sh.get("at"))
	if at.is_empty():
		notes.append("a part needs `at` [x, z, level]")
		return
	var turn := posmod(int(Assembly._num(sh.get("turn"), 0.0)), 360)
	if bool(part.get("swap", false)):
		turn = posmod(turn + 90, 360)
	var size := Assembly.turned_size(int(part["w"]), int(part["d"]), turn)
	var corner := fx.at(int(at[0]), int(at[1]), int(at[2]))
	if fx.mx:
		corner.x -= size.x - 1
		turn = posmod(360 - turn, 360)
	if fx.mz:
		corner.z -= size.y - 1
		turn = posmod(180 - turn, 360)
	g.put({"kind": String(part["kind"]), "w": int(part["w"]), "d": int(part["d"]), "turn": turn, "color": String(part["color"]), "x": corner.x, "z": corner.z, "l": corner.y, "section": si})


static func _three(v: Variant) -> Array:
	if v is Array and (v as Array).size() == 3 and Assembly._is_num(v[0]) and Assembly._is_num(v[1]) and Assembly._is_num(v[2]):
		return [int(v[0]), int(v[1]), int(v[2])]
	return []


static func _two(v: Variant, fallback: Vector2i) -> Vector2i:
	if v is Array and (v as Array).size() >= 2 and Assembly._is_num(v[0]) and Assembly._is_num(v[1]):
		return Vector2i(int(v[0]), int(v[1]))
	return fallback


static func _radii(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() == 2:
		return Vector2(Assembly._num(v[0], 3.0), Assembly._num(v[1], 3.0))
	var r := Assembly._num(v, 3.0)
	return Vector2(r, r)


static func _point(v: Variant, y: int) -> Vector3:
	if v is Array and (v as Array).size() >= 3:
		return Vector3(Assembly._num(v[0], 0.0), Assembly._num(v[1], 0.0), Assembly._num(v[2], float(y)))
	if v is Array and (v as Array).size() == 2:
		return Vector3(Assembly._num(v[0], 0.0), Assembly._num(v[1], 0.0), float(y))
	return Vector3(0.0, 0.0, float(y))


## What a shape does to each cell it is said to be in.
class Stroke:
	var g: Grid
	var color := 0
	var section := 0
	var carve := false
	var paint := false
	var top := false
	var smooth := false
	var fx: Flip

	func _init(grid: Grid, sh: Dictionary, c: int, si: int, flip: Flip) -> void:
		g = grid
		color = c
		section = si
		fx = flip
		carve = bool(sh.get("carve", false))
		paint = bool(sh.get("paint", false))
		top = bool(sh.get("top", false))
		smooth = bool(sh.get("slopes", false))

	func cell(x: int, z: int, y: int) -> void:
		var p := fx.at(x, z, y)
		if not g.has(p.x, p.z, p.y):
			return
		var i := g.index(p.x, p.z, p.y)
		if g.cells[i] == AssemblyModel.TAKEN:
			return
		var cover := g.cells[i]
		if carve:
			g.cells[i] = AssemblyModel.EMPTY
			g.smooth[i] = 0
			return
		if paint:
			if g.cells[i] == AssemblyModel.EMPTY:
				return
			g.cells[i] = color + 1
			if top:
								# ...only what is open to the sky, and the brick's height under it: a single level is a plate over every stud of it
				g.cells[i] = cover
				if not g.filled_at(p.x, p.z, p.y + 1):
					for k in AssemblyModel.COURSE:
						if g.filled_at(p.x, p.z, p.y - k) and g.cells[g.index(p.x, p.z, p.y - k)] != AssemblyModel.TAKEN:
							g.cells[g.index(p.x, p.z, p.y - k)] = color + 1
			return
		g.cells[i] = color + 1
		g.of_section[i] = section
		g.smooth[i] = 1 if smooth else 0


## The cells, and the parts already said.
class Grid:
	var w := 0
	var d := 0
	var h := 0
	var names: Array = []
	var cells := PackedByteArray()
	var of_section := PackedByteArray()
	var smooth := PackedByteArray()
	var fixed: Array = []

	func _init(across: int, deep: int, tall: int, color_names: Array) -> void:
		w = across
		d = deep
		h = tall
		names = color_names
		cells.resize(w * d * h)
		of_section.resize(w * d * h)
		smooth.resize(w * d * h)

	func index(x: int, z: int, y: int) -> int:
		return x + z * w + y * w * d

	func has(x: int, z: int, y: int) -> bool:
		return x >= 0 and z >= 0 and y >= 0 and x < w and z < d and y < h

	func filled_at(x: int, z: int, y: int) -> bool:
		return has(x, z, y) and cells[index(x, z, y)] != AssemblyModel.EMPTY

	func filled() -> int:
		var n := 0
		for v in cells:
			if v != AssemblyModel.EMPTY:
				n += 1
		return n

	## A real part, kept as it is said, if it fits where nothing else was said.
	func put(p: Dictionary) -> void:
		var all := Assembly.cells_of(String(p["kind"]), int(p["w"]), int(p["d"]), int(p["turn"]), int(p["x"]), int(p["z"]), int(p["l"]))
		for c in all:
			if not has(int(c[0]), int(c[1]), int(c[2])) or cells[index(int(c[0]), int(c[1]), int(c[2]))] == AssemblyModel.TAKEN:
				return
		for c in all:
			cells[index(int(c[0]), int(c[1]), int(c[2]))] = AssemblyModel.TAKEN
		fixed.append(p)

	## Where land's edges drop by a brick, the sloped parts that finish them ([constant ANY_SHAPE] `slopes`): over the edge and the row behind it, its low side out, in runs along the edge as long as are made. What is above it, or would be cut, stays square.
	func slope_edges() -> void:
		var dirs := [[Vector2i(0, 1), 0], [Vector2i(1, 0), 90], [Vector2i(0, -1), 180], [Vector2i(-1, 0), 270]]
		for y in range(h - 3, -1, -1):
			for z in d:
				for x in w:
					for dd in dirs:
						var out: Vector2i = dd[0]
						if not _edge_here(x, z, y, out):
							continue
						var along := Vector2i(1, 0) if out.x == 0 else Vector2i(0, 1)
						var run := 1
						while run < AssemblyModel.SLOPE_RUNS[0] and _edge_here(x + along.x * run, z + along.y * run, y, out) and cells[index(x + along.x * run, z + along.y * run, y)] == cells[index(x, z, y)]:
							run += 1
						_slope_run(x, z, y, out, along, run, int(dd[1]))
						break

	## Whether the column at [param x], [param z] ends in a brick's height of one color at [param y] with nothing past it toward [param out], and the row behind it the same, open above.
	func _edge_here(x: int, z: int, y: int, out: Vector2i) -> bool:
		if not has(x, z, y + 2):
			return false
		var i := index(x, z, y + 2)
		if smooth[i] == 0 or cells[i] == AssemblyModel.EMPTY or cells[i] == AssemblyModel.TAKEN or filled_at(x, z, y + 3):
			return false
		var col := cells[i]
		if not _solid(x, z, y, col) or not _solid(x - out.x, z - out.y, y, col) or filled_at(x - out.x, z - out.y, y + 3):
			return false
		return not (filled_at(x + out.x, z + out.y, y) or filled_at(x + out.x, z + out.y, y + 1) or filled_at(x + out.x, z + out.y, y + 2))

	func _solid(x: int, z: int, y: int, col: int) -> bool:
		for k in 3:
			if not has(x, z, y + k) or cells[index(x, z, y + k)] != col:
				return false
		return true

	func _slope_run(x: int, z: int, y: int, out: Vector2i, along: Vector2i, run: int, turn: int) -> void:
		var corner := Vector2i(mini(x, x - out.x), mini(z, z - out.y))
		var i := index(x, z, y)
		var col := cells[i]
		var section := of_section[i]
		var color := String(names[col - 1])
		var size := Assembly.turned_size(run, 2, turn)
		assert(size.x >= 1 and along != Vector2i.ZERO)
		put({"kind": "slope", "w": run, "d": 2, "turn": turn, "color": color, "x": corner.x, "z": corner.y, "l": y, "section": section})


# --- what stays, and what it is laid in ------------------------------------------------------------------------

## What nobody will see is left out: a cell is kept if there is anything empty within [constant SHELL] of it. [param extra] holds cells kept all the same ([method _pillars]). A byte per cell.
static func _hollowed(g: Grid, extra: Dictionary) -> PackedByteArray:
	var kept := PackedByteArray()
	kept.resize(g.cells.size())
	var w := g.w
	var wd := g.w * g.d
	for y in g.h:
		for z in g.d:
			for x in g.w:
				var i := x + z * w + y * wd
				var v := g.cells[i]
				if v == EMPTY or v == TAKEN:
					continue
				var open := extra.has(i)
				if not open:
					open = x == 0 or z == 0 or x == w - 1 or z == g.d - 1
				if not open:
					for dy in range(-SHELL.y, SHELL.y + 1):
						var yy := y + dy
						if yy < 0:
							continue
						if yy >= g.h:
							open = true
							break
						for dz in range(-SHELL.x, SHELL.x + 1):
							for dx in range(-SHELL.x, SHELL.x + 1):
								if g.cells[(x + dx) + (z + dz) * w + yy * wd] == EMPTY:
									open = true
									break
							if open:
								break
						if open:
							break
				if open:
					kept[i] = 1
	return kept


## The cells in real parts, bottom up, added to [param parts]. What takes up the most goes down first, wherever on the level it fits, and
## only then what fits round it: going cell by cell, a curved edge comes apart into hundreds of single studs. Each course is gone over the
## other way from the last, and what would run its joint straight over a joint below waits for a smaller part, so a wall holds together.
## What was left hanging last time is bridged: [param bridge] says which cells must first take a long plate, running in from there over what holds.
static func _lay(g: Grid, kept: PackedByteArray, parts: Array, bridge: Dictionary = {}) -> void:
	var used := PackedByteArray()
	used.resize(g.cells.size())
	var owner := PackedInt32Array()
	owner.resize(g.cells.size())
	owner.fill(-1)
	var n := parts.size()
	for p in parts:
		for c in Assembly.cells_of(String((p as Dictionary)["kind"]), int((p as Dictionary)["w"]), int((p as Dictionary)["d"]), int((p as Dictionary)["turn"]), int((p as Dictionary)["x"]), int((p as Dictionary)["z"]), int((p as Dictionary)["l"])):
			used[g.index(int(c[0]), int(c[1]), int(c[2]))] = 1
			owner[g.index(int(c[0]), int(c[1]), int(c[2]))] = n
		n += 1
	var sizes := _sizes_largest_first()
	var wd := g.w * g.d
	for y in g.h:
		# ...what is left on this level, by the cell
		var free: Array[int] = []
		var from := y * wd
		for i in wd:
			var ci := from + i
			if kept[ci] != 0 and used[ci] == 0:
				free.append(i)
		if free.is_empty():
			continue
		if y % 2 == 1:
			free.reverse()
		var flip := y % 2 == 1
		if not bridge.is_empty():
			for i in free:
				if bridge.has(from + i) and used[from + i] == 0:
					var strip := _strip(g, kept, used, i % g.w, i / g.w, y, g.cells[from + i])
					if not strip.is_empty():
						strip["section"] = int(g.of_section[from + i])
						strip["color"] = String(g.names[g.cells[from + i] - 1])
						for c in Assembly.cells_of("plate", int(strip["w"]), int(strip["d"]), int(strip["turn"]), int(strip["x"]), int(strip["z"]), y):
							var ci := g.index(int(c[0]), int(c[1]), int(c[2]))
							used[ci] = 1
							owner[ci] = n
						parts.append(strip)
						n += 1
		for pass_i in sizes.size():
			var sz: Array = sizes[pass_i]
			var sx := int(sz[1])
			var sd := int(sz[2])
			var tall := int(sz[3])
			var left := 0
			for i in free:
				if used[from + i] != 0:
					continue
				left += 1
				var x := i % g.w
				var z := i / g.w
				var px := x - sx + 1 if flip else x
				var pz := z - sd + 1 if flip else z
				if px < 0 or pz < 0 or px + sx > g.w or pz + sd > g.d or y + tall > g.h:
					continue
				if not _all_free(g, kept, used, px, pz, y, sx, sd, tall, g.cells[from + i]):
					continue
								# ...what overhangs is plates, whose joints can be off each other a level apart: a brick out over nothing is joined to nothing
				if tall == COURSE and y > 0 and not _any_under(g, px, pz, y, sx, sd):
					continue
								# ...a brick lies on a course, where colors and shapes change: off one, it goes only where it fills what is left
				if tall == COURSE and y % COURSE != 0 and y + tall < g.h and _all_free(g, kept, used, px, pz, y + tall, 1, 1, 1, g.cells[from + i]):
					continue
				# ...the last size of its height always goes down; any other waits if its far edge lies along a joint below
				if not bool(sz[5]) and _on_a_joint(g, owner, px, pz, y, sx, sd):
					continue
				var part := {"kind": String(sz[0]), "w": int(sz[4][0]), "d": int(sz[4][1]), "turn": int(sz[4][2]), "x": px, "z": pz, "l": y, "section": int(g.of_section[from + i]), "color": String(g.names[g.cells[from + i] - 1])}
				for k in tall:
					for dz in sd:
						for dx in sx:
							var ci := g.index(px + dx, pz + dz, y + k)
							used[ci] = 1
							owner[ci] = n
				parts.append(part)
				n += 1
			if left == 0:
				break


## The longest plate running either way from the cell [param x], [param z], or `{}`: across a joint, for what is under it or over it to hold by.
static func _strip(g: Grid, kept: PackedByteArray, used: PackedByteArray, x: int, z: int, y: int, col: int) -> Dictionary:
	for length in [8, 6, 4, 3, 2]:
		# ...each level across the last
		for way in ([[1, 0], [-1, 0], [0, 1], [0, -1]] if y % 2 == 0 else [[0, 1], [0, -1], [1, 0], [-1, 0]]):
			var along_x := int(way[0]) != 0
			var px := x if int(way[0]) >= 0 else x - int(length) + 1
			var pz := z if int(way[1]) >= 0 else z - int(length) + 1
			var sx: int = int(length) if along_x else 1
			var sd: int = 1 if along_x else int(length)
			if px < 0 or pz < 0 or px + sx > g.w or pz + sd > g.d:
				continue
			if _all_free(g, kept, used, px, pz, y, sx, sd, 1, col):
				return {"kind": "plate", "w": 1, "d": int(length), "turn": 90 if along_x else 0, "x": px, "z": pz, "l": y}
	return {}


## Every part laid from cells, as footprints across and deep, most taken up first: `[kind, across, deep, tall, [w, d, turn], whether it goes down wherever it fits]`.
static func _sizes_largest_first() -> Array:
	var out: Array = []
	for family in [["plate", 1], ["brick", 3]]:
		for s in (Assembly.KINDS[String(family[0])] as Dictionary)["sizes"]:
			var a: Array = s
			var w := int(a[0])
			var d := int(a[1])
			out.append([String(family[0]), w, d, int(family[1]), [w, d, 0], w * d <= 2])
			if w != d:
				out.append([String(family[0]), d, w, int(family[1]), [w, d, 90], w * d <= 2])
		# ...by how much of a level it covers, more for a brick's height: bricks in thin walls, where they save the most, and wide plates over anything wider (a plate across a hollow is held by all its walls)
	out.sort_custom(func(p: Array, q: Array) -> bool:
		var vp := float(int(p[1]) * int(p[2])) * sqrt(float(p[3]))
		var vq := float(int(q[1]) * int(q[2])) * sqrt(float(q[3]))
		if not is_equal_approx(vp, vq):
			return vp > vq
		return int(p[3]) < int(q[3]))
	return out


## Whether anything stands under a footprint at level [param y].
static func _any_under(g: Grid, px: int, pz: int, y: int, sx: int, sd: int) -> bool:
	var lv := (y - 1) * g.w * g.d
	for dz in sd:
		for dx in sx:
			if g.cells[lv + (pz + dz) * g.w + px + dx] != EMPTY:
				return true
	return false


static func _all_free(g: Grid, kept: PackedByteArray, used: PackedByteArray, px: int, pz: int, y: int, sx: int, sd: int, tall: int, col: int) -> bool:
	var wd := g.w * g.d
	for k in tall:
		var lv := (y + k) * wd
		for dz in sd:
			var row := lv + (pz + dz) * g.w + px
			for dx in sx:
				var ci := row + dx
				if g.cells[ci] != col or kept[ci] == 0 or used[ci] != 0:
					return false
	return true


## Whether more than half of a part's side edges lie straight over a joint between two parts below: nothing would bind what is either side of it.
static func _on_a_joint(g: Grid, owner: PackedInt32Array, px: int, pz: int, y: int, sx: int, sd: int) -> bool:
	if y == 0:
		return false
	var edges := 0
	var joints := 0
	var lv := (y - 1) * g.w * g.d
	if px + sx < g.w:
		for dz in sd:
			var a := owner[lv + (pz + dz) * g.w + px + sx - 1]
			var b := owner[lv + (pz + dz) * g.w + px + sx]
			if a >= 0 and b >= 0:
				edges += 1
				if a != b:
					joints += 1
	if px > 0:
		for dz in sd:
			var a := owner[lv + (pz + dz) * g.w + px]
			var b := owner[lv + (pz + dz) * g.w + px - 1]
			if a >= 0 and b >= 0:
				edges += 1
				if a != b:
					joints += 1
	if pz + sd < g.d:
		for dx in sx:
			var a := owner[lv + (pz + sd - 1) * g.w + px + dx]
			var b := owner[lv + (pz + sd) * g.w + px + dx]
			if a >= 0 and b >= 0:
				edges += 1
				if a != b:
					joints += 1
	if pz > 0:
		for dx in sx:
			var a := owner[lv + pz * g.w + px + dx]
			var b := owner[lv + (pz - 1) * g.w + px + dx]
			if a >= 0 and b >= 0:
				edges += 1
				if a != b:
					joints += 1
	return edges > 0 and joints * 2 > edges


# --- how it holds, and the order it goes on ----------------------------------------------------------------------

## The order a hand could build it in, and what can never be joined: `{parts, floating}`. A part goes on once it is on the plate or a stud joins it to what is there, from below or hanging from above: within a section,
## the lowest course first, each part next to the last where it can be, so the hand goes round as a builder goes. A later section's part is only taken early if nothing before it could go on without it.
static func _ordered(parts: Array, w: int, d: int) -> Dictionary:
	var at := {}
	for i in parts.size():
		var q: Dictionary = parts[i]
		for c in Assembly.cells_of(String(q["kind"]), int(q["w"]), int(q["d"]), int(q["turn"]), int(q["x"]), int(q["z"]), int(q["l"])):
			at[Assembly._key(int(c[0]), int(c[1]), int(c[2]))] = i
	var links: Array = []
	links.resize(parts.size())
	var ready := PackedByteArray()
	ready.resize(parts.size())
	for i in parts.size():
		links[i] = {}
	for i in parts.size():
		var q: Dictionary = parts[i]
		var kind := String(q["kind"])
		var pw := int(q["w"])
		var pd := int(q["d"])
		var turn := int(q["turn"])
		var l := int(q["l"])
		var h := int((Assembly.KINDS[kind] as Dictionary)["h"])
		for j in pd:
			for k in pw:
				var c := Assembly._turned_cell(k, j, pw, pd, turn, int(q["x"]), int(q["z"]))
				var open := kind == "arch" and j > 0 and j < pd - 1
				if not open:
					if l == 0 and c.x >= 0 and c.y >= 0 and c.x < w and c.y < d:
						ready[i] = 1
					var under: Variant = at.get(Assembly._key(c.x, c.y, l - 1))
					if under != null and _has_stud_at(parts[int(under)], c.x, c.y):
						(links[i] as Dictionary)[int(under)] = true
						(links[int(under)] as Dictionary)[i] = true
				if Assembly._studded(kind, j):
					var over: Variant = at.get(Assembly._key(c.x, c.y, l + h))
					if over != null and over != i and _solid_foot_at(parts[int(over)], c.x, c.y):
						(links[i] as Dictionary)[int(over)] = true
						(links[int(over)] as Dictionary)[i] = true
	var open_set := {}
	var left := {}
	for i in parts.size():
		left[i] = true
		if ready[i] != 0:
			open_set[i] = true
	var out: Array = []
	var last := Vector2(-100.0, -100.0)
	while not open_set.is_empty():
		var pick := -1
		var key := Vector3(INF, INF, INF)
		for i in open_set:
			var q: Dictionary = parts[int(i)]
			var here := Vector2(float(q["x"]), float(q["z"]))
			var k := Vector3(float(q["section"]), float(q["l"]), here.distance_squared_to(last))
			if k.x < key.x or (k.x == key.x and (k.y < key.y or (k.y == key.y and k.z < key.z))):
				key = k
				pick = int(i)
		var q: Dictionary = parts[pick]
		out.append(q)
		last = Vector2(float(q["x"]), float(q["z"]))
		open_set.erase(pick)
		left.erase(pick)
		for other in links[pick]:
			if left.has(other):
				open_set[other] = true
	var floating: Array = []
	for i in left:
		floating.append(parts[int(i)])
	out.append_array(floating)
	return {"parts": out, "floating": floating}


static func _has_stud_at(q: Dictionary, x: int, z: int) -> bool:
	var w := int(q["w"])
	var d := int(q["d"])
	for j in d:
		for i in w:
			if Assembly._turned_cell(i, j, w, d, int(q["turn"]), int(q["x"]), int(q["z"])) == Vector2i(x, z):
				return Assembly._studded(String(q["kind"]), j)
	return false


static func _solid_foot_at(q: Dictionary, x: int, z: int) -> bool:
	var w := int(q["w"])
	var d := int(q["d"])
	for j in d:
		for i in w:
			if Assembly._turned_cell(i, j, w, d, int(q["turn"]), int(q["x"]), int(q["z"])) == Vector2i(x, z):
				return not (String(q["kind"]) == "arch" and j > 0 and j < d - 1)
	return false


## What lies over or under what hangs is to run across it: its cells marked for [method _lay]. Whether any were new.
static func _bridged(g: Grid, floating: Array, bridge: Dictionary) -> bool:
	var any := false
	for f in floating:
		var q: Dictionary = f
		var size := Assembly.turned_size(int(q["w"]), int(q["d"]), int(q["turn"]))
		var above := int(q["l"]) + int((Assembly.KINDS[String(q["kind"])] as Dictionary)["h"])
		for z in range(int(q["z"]), int(q["z"]) + size.y):
			for x in range(int(q["x"]), int(q["x"]) + size.x):
				var l := above if g.filled_at(x, z, above) else int(q["l"]) - 1
				if g.filled_at(x, z, l) and g.cells[g.index(x, z, l)] != TAKEN and not bridge.has(g.index(x, z, l)):
					bridge[g.index(x, z, l)] = true
					any = true
	return any


## What was hollowed out and left hanging is held by what was left out, hidden in what is there anyway: the wall is left thicker round it, by more on each pass [param reach], so a ring out over the last one has something to bite on, and the cells straight under it come back down to what is under them. Whether any did: what hangs over cells nobody wrote is for its designer to say.
static func _pillars(g: Grid, floating: Array, extra: Dictionary, reach: int) -> bool:
	var any := false
	for f in floating:
		var q: Dictionary = f
		var size := Assembly.turned_size(int(q["w"]), int(q["d"]), int(q["turn"]))
		var h := int((Assembly.KINDS[String(q["kind"])] as Dictionary)["h"])
		var l0 := int(q["l"])
		for l in range(l0 - COURSE, l0 + h + COURSE):
			for z in range(int(q["z"]) - reach, int(q["z"]) + size.y + reach):
				for x in range(int(q["x"]) - reach, int(q["x"]) + size.x + reach):
					if not g.has(x, z, l):
						continue
					var i := g.index(x, z, l)
					if g.cells[i] != EMPTY and g.cells[i] != TAKEN and not extra.has(i):
						extra[i] = true
						any = true
		# ...and a pillar, where there are cells to stand it in
		var cx := int(q["x"])
		var cz := int(q["z"])
		var l := l0 - 1
		while l >= 0 and g.has(cx, cz, l) and g.cells[g.index(cx, cz, l)] != EMPTY:
			var i := g.index(cx, cz, l)
			if g.cells[i] != TAKEN and not extra.has(i):
				extra[i] = true
				any = true
			l -= 1
	return any
