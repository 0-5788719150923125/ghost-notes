extends RefCounted
class_name Ink

## Ink - a formula written by hand, as a function of time.
##
## TEX LAYS OUT, A HAND WRITES. `hosts/math/typeset.py` sets each formula with TeX and answers where
## every glyph and rule landed, in TeX's own order, with each glyph's PostScript NAME ("alpha",
## "summationdisplay", "radicalbig"). This draws each glyph as pen strokes from the Hershey fonts
## (centerline fonts made for plotters - fonts/hands/hershey/, free with credit), fitted into the box
## TeX gave it, so the structure is TeX's and the writing is a hand's: a fraction's bar lands between
## its numerator and its denominator because that is where TeX set it.
##
## Three pure steps, so a desk can draw any moment without having drawn the ones before:
##   [method strokes_of] - one typeset item and a seed -> its strokes, in writing order;
##   [method schedule]   - strokes and a pace -> when each is drawn;
##   [method at]         - a schedule and a time -> the ink on the page then.
##
## What was measured (next/proof.md, "Ink"), and is held by tests/desk/ink_check.gd:
## - A GLYPH KEEPS ITS OWN PROPORTIONS. Stretching a stroke glyph to its TeX box crowded
##   superscripts into their bases and swelled commas; it is scaled uniformly and centered in the
##   box, shrunk only where it would overrun it by much (a little overflow is handwriting).
## - TEX'S ORDER IS A HAND'S ORDER, with one exception: TeX sets a sum's upper limit before the
##   sign, so a big operator is moved ahead of the limits above it.
## - WRITING TAKES AS LONG AS WRITING: a^2 + b^2 = c^2 is about 5 s at pace 1, so a desk writes under
##   the voice rather than between its sentences.
## - NOTHING LEAVES SILENTLY. A glyph the hand has no strokes for is drawn as its outline traced
##   (the typeset answer's `fonts`, when asked for) and named in `missing` either way.

## The stroke fonts, by the name the table below uses.
const FONTS := {
	"futural": "res://fonts/hands/hershey/futural.jhf",     # simplex Roman: Latin, digits, punctuation
	"greeks": "res://fonts/hands/hershey/greeks.jhf",       # simplex Greek, lowercase italic
	"scripts": "res://fonts/hands/hershey/scripts.jhf",     # script capitals, for \mathcal
	"mathlow": "res://fonts/hands/hershey/mathlow.jhf",     # operators, big delimiters, integrals
}

## Lowercase and uppercase Greek in the order the Greek font keeps them, from its "a" and its "A".
const GREEK := ["alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota",
	"kappa", "lambda", "mu", "nu", "xi", "omicron", "pi", "rho", "sigma", "tau", "upsilon", "phi",
	"chi", "psi", "omega"]
const DIGITS := ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]

## A glyph TeX names -> "font:character" in the stroke fonts. Letters, digits and Greek are filled
## in by [method _table]; this is the rest. A name with `bigg`/`Big` sizes shares its row.
const NAMED := {
	"plus": "mathlow:+", "minus": "mathlow:-", "equal": "mathlow:=", "less": "mathlow:<",
	"greater": "mathlow:>", "plusminus": "mathlow:!", "minusplus": "mathlow:\"",
	"multiply": "mathlow:#", "periodcentered": "mathlow:$", "asteriskmath": "mathlow:*",
	"parenleft": "futural:(", "parenright": "futural:)", "bracketleft": "futural:[",
	"bracketright": "futural:]", "braceleft": "mathlow:{", "braceright": "mathlow:}",
	"comma": "futural:,", "period": "futural:.", "colon": "futural::", "semicolon": "futural:;",
	"slash": "futural:/", "bar": "futural:|", "exclam": "futural:!", "question": "futural:?",
	"quoteright": "futural:'", "prime": "futural:'", "backslash": "mathlow:\\",
	"equivalence": "mathlow:@", "proportional": "mathlow:^", "infinity": "mathlow:_",
	"degree": "mathlow:`", "radical": "mathlow:c", "radicalbig": "mathlow:c",
	"radicalBig": "mathlow:o", "radicalbigg": "mathlow:o", "radicalBigg": "mathlow:o",
	"propersubset": "mathlow:d", "union": "mathlow:e", "propersuperset": "mathlow:f",
	"intersection": "mathlow:g", "element": "mathlow:h", "arrowright": "mathlow:i",
	"arrowup": "mathlow:j", "arrowleft": "mathlow:k", "arrowdown": "mathlow:l",
	"partialdiff": "mathlow:m", "nabla": "mathlow:n", "integraltext": "mathlow:q",
	"integraldisplay": "mathlow:q", "summationtext": "mathlow:;", "summationdisplay": "mathlow:;",
	"producttext": "mathlow::", "productdisplay": "mathlow::", "existential": "mathlow:v",
	"aleph": "mathlow:w", "divide": "mathlow:x", "bardbl": "mathlow:y", "perpendicular": "mathlow:z",
	"angle": "mathlow:|", "similar": "mathlow:~", "negationslash": "futural:/",
	"parenleftbig": "mathlow:r", "parenrightbig": "mathlow:s", "bracketleftbig": "mathlow:t",
	"bracketrightbig": "mathlow:u", "braceleftbig": "mathlow:{", "bracerightbig": "mathlow:}",
	"epsilon1": "greeks:e", "theta1": "greeks:h", "phi1": "greeks:u", "pi1": "greeks:p",
	"rho1": "greeks:q", "sigma1": "greeks:r", "dotlessi": "futural:i", "dotlessj": "futural:j",
}

## Glyphs drawn from other glyphs. `flip`: upside down (an A is "for all"). `under`: the glyph with a
## bar under it ("less or equal", "subset or equal" - a hand writes one bar, not the Hershey two).
## `slash`: struck through ("empty set"). `strokes`: drawn outright, in the unit box (cap heights
## both ways, baseline 0, up negative).
const RECIPES := {
	"universal": {"flip": "futural:A"},
	"lessequal": {"under": "mathlow:<"},
	"greaterequal": {"under": "mathlow:>"},
	"reflexsubset": {"under": "mathlow:d"},
	"reflexsuperset": {"under": "mathlow:f"},
	"emptyset": {"slash": "futural:0"},
	"arrowdblright": {"strokes": [[[0.0, -0.32], [0.82, -0.32]], [[0.0, -0.12], [0.82, -0.12]],
		[[0.6, -0.5], [1.0, -0.22], [0.6, 0.06]]]},
	"arrowdblleft": {"strokes": [[[0.18, -0.32], [1.0, -0.32]], [[0.18, -0.12], [1.0, -0.12]],
		[[0.4, -0.5], [0.0, -0.22], [0.4, 0.06]]]},
	"arrowdblboth": {"strokes": [[[0.15, -0.32], [0.85, -0.32]], [[0.15, -0.12], [0.85, -0.12]],
		[[0.32, -0.5], [0.0, -0.22], [0.32, 0.06]], [[0.68, -0.5], [1.0, -0.22], [0.68, 0.06]]]},
	"logicalnot": {"strokes": [[[0.0, -0.42], [0.9, -0.42], [0.9, -0.18]]]},
	# LONG ARROWS: TeX builds `\implies` and `\longrightarrow` from two glyphs, a bar kerned under an
	# arrow (see [method _writing_order]); a hand writes one long arrow
	"arrowdbllong": {"strokes": [[[0.0, -0.32], [1.62, -0.32]], [[0.0, -0.12], [1.62, -0.12]],
		[[1.4, -0.5], [1.82, -0.22], [1.4, 0.06]]]},
	"arrowlong": {"strokes": [[[0.0, -0.22], [1.62, -0.22]], [[1.4, -0.4], [1.82, -0.22], [1.4, -0.04]]]},
	"logicaland": {"strokes": [[[0.05, 0.0], [0.5, -0.62], [0.95, 0.0]]]},
	"logicalor": {"strokes": [[[0.05, -0.62], [0.5, 0.0], [0.95, -0.62]]]},
	"approxequal": {"strokes": [[[0.0, -0.36], [0.25, -0.44], [0.5, -0.36], [0.75, -0.28], [1.0, -0.36]],
		[[0.0, -0.14], [0.25, -0.22], [0.5, -0.14], [0.75, -0.06], [1.0, -0.14]]]},
	"mapsto": {"strokes": [[[0.0, -0.36], [0.0, -0.08]], [[0.0, -0.22], [1.0, -0.22]],
		[[0.75, -0.4], [1.0, -0.22], [0.75, -0.04]]]},
	"circle": {"strokes": [[[0.5, -0.5], [0.8, -0.38], [0.8, -0.12], [0.5, 0.0], [0.2, -0.12],
		[0.2, -0.38], [0.5, -0.5]]]},
}

## TeX's big operators, written before the limits TeX set above them first.
const BIG_OPS := ["summationdisplay", "summationtext", "productdisplay", "producttext",
	"integraldisplay", "integraltext"]

## The pen, at pace 1 (measured by eye on the spike's frames; a desk scales it).
const PEN_SPEED := 55.0           # points of stroke a second
const PEN_TRAVEL := 220.0         # points a second, lifted between strokes
const STROKE_MIN := 0.05          # the shortest stroke (a dot) still takes this
const LIFT_MIN := 0.03            # and every lift this
const GLYPH_GAP := Vector2(0.06, 0.14)   # a breath between glyphs, uniform in this range
const RELATION_PAUSE := 0.25      # a longer one before a relation: "=", "<", an arrow

const RELATIONS := ["equal", "less", "greater", "lessequal", "greaterequal", "arrowdblright",
	"arrowright", "equivalence", "approxequal", "element", "reflexsubset", "propersubset"]

static var _fonts := {}          # font name -> [[left, right, strokes], ...], ASCII order from 32
static var _names := {}          # glyph name -> "font:character", NAMED with the letters filled in
static var _lock := Mutex.new()


## The strokes of one typeset item (one record of typeset.py's answer), in writing order:
## [{name, k, points: PackedVector2Array, width}] in the item's TeX points, y down from its first
## baseline. `width` is the nib for that stroke (it follows the glyph's size). `outlines` is the
## answer's `fonts` (glyphs' contours), for a glyph no stroke font has. The hand is seeded: the same
## item and seed always write the same strokes; `missing` names what had no strokes of its own.
static func strokes_of(item: Dictionary, seed: int, outlines: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["desk-ink", seed, String(item.get("id", ""))])
	var order := _writing_order(item)
	var out: Array = []
	var missing: PackedStringArray = []
	for e in order:
		var entry: Dictionary = e
		if entry.has("n"):
			var placed := _glyph(entry, rng, outlines)
			if placed.is_empty():
				missing.append("%s:%s" % [String(entry.get("f", "")), String(entry.get("n", ""))])
				continue
			if bool(placed.get("traced", false)):
				missing.append("%s:%s" % [String(entry.get("f", "")), String(entry.get("n", ""))])
			for pts in placed["strokes"]:
				out.append({"name": String(entry["n"]), "k": int(entry.get("k", 0)),
					"points": pts, "width": _nib(float(entry.get("s", 10.0)))})
		else:
			out.append({"name": "rule", "k": int(entry.get("k", 0)), "points": _rule(entry, rng),
				"width": _nib(maxf(10.0, float(entry.get("h", 0.4)) * 20.0))})
	return {"strokes": out, "missing": missing}


## When each stroke is drawn: {strokes: [{points, width, name, t0, t1}], length}, seconds from the
## item's start. A stroke's time is its length at the pen's speed (`pace` > 1 writes faster); a lift
## costs its distance at the travel speed; there is a breath between glyphs and a longer one before
## a relation. Seeded like the strokes, so a schedule is a function of (strokes, seed, pace).
static func schedule(strokes: Array, seed: int, pace := 1.0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["desk-ink-pace", seed, strokes.size()])
	var t := 0.0
	var last := Vector2.INF
	var glyph := -1
	var out: Array = []
	for s in strokes:
		var st: Dictionary = s
		var pts: PackedVector2Array = st["points"]
		if pts.is_empty():
			continue
		if int(st.get("k", 0)) != glyph:
			glyph = int(st.get("k", 0))
			t += rng.randf_range(GLYPH_GAP.x, GLYPH_GAP.y) / pace
			if RELATIONS.has(String(st.get("name", ""))):
				t += RELATION_PAUSE / pace
		if last != Vector2.INF:
			t += (LIFT_MIN + last.distance_to(pts[0]) / PEN_TRAVEL) / pace
		var dur := (STROKE_MIN + _length(pts) / PEN_SPEED) / pace
		var row := st.duplicate()
		row["t0"] = t
		row["t1"] = t + dur
		out.append(row)
		t += dur
		last = pts[pts.size() - 1]
	return {"strokes": out, "length": t}


## The ink on the page `t` seconds into a schedule: [{points, width}], every stroke begun by then,
## the one under the pen cut where the pen is (a minimum-jerk stroke: slow off the mark, slow into
## the end), and `pen` - where the nib is, Vector2.INF when it is lifted or done.
static func at(sched: Dictionary, t: float) -> Dictionary:
	var ink: Array = []
	var pen := Vector2.INF
	for s in sched.get("strokes", []):
		var st: Dictionary = s
		var t0 := float(st["t0"])
		if t <= t0:
			break
		var t1 := float(st["t1"])
		var pts: PackedVector2Array = st["points"]
		if t >= t1:
			ink.append({"points": pts, "width": float(st["width"])})
			continue
		var u := clampf((t - t0) / maxf(t1 - t0, 1e-6), 0.0, 1.0)
		var part := _partial(pts, u * u * u * (10.0 - 15.0 * u + 6.0 * u * u))
		ink.append({"points": part, "width": float(st["width"])})
		pen = part[part.size() - 1]
	return {"ink": ink, "pen": pen}


## Can the hand write the glyph TeX names `name` (in font `font`)? For the gate and the audit.
static func covered(name: String, font := "cmr10") -> bool:
	return not _source(name, font).is_empty()


# --- the glyphs -------------------------------------------------------------------

## Where a glyph's strokes come from: {glyph: [l, r, strokes]} or {recipe: {...}}, {} for none.
## Calligraphic capitals are cmsy's letters, blackboard bold msbm's.
static func _source(name: String, font: String) -> Dictionary:
	if name.length() == 1 and name.to_upper() == name and name.to_lower() != name:
		if font.begins_with("cmsy"):
			return {"glyph": _hershey("scripts", name)}
		if font.begins_with("msbm"):
			return {"glyph": _hershey("futural", name), "double": true}
	if RECIPES.has(name):
		return {"recipe": RECIPES[name]}
	var at := String(_table().get(name, ""))
	if at.is_empty():
		var base := name
		for size in ["Bigg", "bigg", "Big", "big"]:
			if base.ends_with(size):
				base = base.substr(0, base.length() - size.length())
				break
		at = String(_table().get(base + "big", _table().get(base, "")))
	if at.is_empty():
		return {}
	var g := _hershey(at.get_slice(":", 0), at.substr(at.find(":") + 1))
	return {} if g.is_empty() else {"glyph": g}


static func _table() -> Dictionary:
	_lock.lock()
	if _names.is_empty():
		_names = _build_table()
	var t: Dictionary = _names
	_lock.unlock()
	return t


static func _build_table() -> Dictionary:
	var t := NAMED.duplicate()
	for i in DIGITS.size():
		t[DIGITS[i]] = "futural:%d" % i
	for c in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ":
		t[c] = "futural:" + c
	for i in GREEK.size():
		t[GREEK[i]] = "greeks:" + char("a".unicode_at(0) + i)
		var up := String(GREEK[i]).capitalize()
		t[up] = "greeks:" + char("A".unicode_at(0) + i)
	return t


## One glyph placed: {strokes: [PackedVector2Array], traced}, {} when nothing can draw it.
static func _glyph(g: Dictionary, rng: RandomNumberGenerator, outlines: Dictionary) -> Dictionary:
	var name := String(g.get("n", ""))
	var font := String(g.get("f", ""))
	var src := _source(name, font)
	var unit: Array = []          # strokes in the unit box: cap heights both ways, baseline 0, up negative
	var traced := false
	if src.has("glyph"):
		unit = _unit(src["glyph"])
		if bool(src.get("double", false)) and not unit.is_empty():
			var first: Array = unit[0]
			var twin: Array = []
			for p in first:
				twin.append(Vector2(p.x + 0.12, p.y))
			unit.append(twin)
	elif src.has("recipe"):
		unit = _recipe(src["recipe"])
	else:
		unit = _outline(outlines, font, int(g.get("c", -1)))
		traced = not unit.is_empty()
	if unit.is_empty():
		return {}
	return {"strokes": _place(unit, g, rng, font.begins_with("cmmi")), "traced": traced}


## A Hershey glyph's strokes in the unit box: both axes in cap heights (21 font units), x from its
## left margin, baseline 0 (the font's y = 9), up negative. ONE SCALE FOR BOTH AXES: measuring x by
## each glyph's own advance instead drew a comma (8 units wide) 2.6 times too wide - it read as "›".
static func _unit(glyph: Array) -> Array:
	var left := float(glyph[0])
	var out: Array = []
	for st in glyph[2]:
		var pts: Array = []
		for p in st:
			pts.append(Vector2((float(p.x) - left) / 21.0, (float(p.y) - 9.0) / 21.0))
		out.append(pts)
	return out


static func _recipe(r: Dictionary) -> Array:
	if r.has("flip"):
		var at := String(r["flip"])
		var flipped: Array = []
		for st in _unit(_hershey(at.get_slice(":", 0), at.substr(at.find(":") + 1))):
			var pts: Array = []
			for p in st:
				pts.append(Vector2(p.x, -1.0 - p.y))
			flipped.append(pts)
		return flipped
	if r.has("under") or r.has("slash"):
		var at := String(r.get("under", r.get("slash", "")))
		var base := _unit(_hershey(at.get_slice(":", 0), at.substr(at.find(":") + 1)))
		var out: Array = []
		if r.has("under"):
			for st in base:
				var pts: Array = []
				for p in st:
					pts.append(Vector2(p.x, p.y * 0.8 - 0.15))
				out.append(pts)
			out.append([Vector2(0.1, 0.1), Vector2(0.9, 0.1)])
		else:
			out = base
			out.append([Vector2(0.95, -1.1), Vector2(0.05, 0.15)])
		return out
	var drawn: Array = []
	for st in r.get("strokes", []):
		var pts: Array = []
		for p in st:
			pts.append(Vector2(float(p[0]), float(p[1])))
		drawn.append(pts)
	return drawn


## A glyph's outline (from the typeset answer's `fonts`), as strokes in the unit box: the fallback
## for what no stroke font has. Type 1 contours are in 1/1000 em, y up.
static func _outline(outlines: Dictionary, font: String, code: int) -> Array:
	var slot: Dictionary = outlines.get(font, {}).get(str(code), {})
	var out: Array = []
	for c in slot.get("contours", []):
		var flat: Array = c
		var pts: Array = []
		var i := 0
		while i + 1 < flat.size():
			pts.append(Vector2(float(flat[i]) / 683.0, -float(flat[i + 1]) / 683.0))
			i += 2
		if pts.size() > 1:
			pts.append(pts[0])
			out.append(pts)
	return out


## Unit strokes fitted into the glyph's TeX box, with the hand's own wobble: a glyph keeps its
## proportions (uniform scale, centered, shrunk only where it would overrun its box by much);
## a big operator or delimiter is stretched to its box, which is what TeX grew it to; a math
## italic leans.
static func _place(unit: Array, g: Dictionary, rng: RandomNumberGenerator, italic: bool) -> Array:
	var x0 := float(g.get("x", 0.0))
	var y0 := float(g.get("y", 0.0))
	var w := float(g.get("w", 0.0))
	var ht := float(g.get("ht", 0.0))
	var dp := float(g.get("dp", 0.0))
	var size := float(g.get("s", 10.0))
	var name := String(g.get("n", ""))
	var big := String(g.get("f", "")).begins_with("cmex") or name.begins_with("radical")
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for st in unit:
		for p in st:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var span := (hi - lo).max(Vector2(1e-6, 1e-6))
	var em := size * 0.66
	var k := 1.0
	var ox := x0
	if not big:
		var gw := span.x * em
		if gw > 0.0 and w > 0.0:
			k = clampf(w * 0.92 / gw, 0.72, 1.0)
		ox = x0 + (w - gw * k) * 0.5
	var slant := 0.1 if italic else 0.03
	var rot := rng.randfn(0.0, 0.025)
	var scale := 1.0 + rng.randfn(0.0, 0.035)
	var shift := Vector2(rng.randfn(0.0, 0.02), rng.randfn(0.0, 0.03)) * size
	var phase := rng.randf() * TAU
	var center := Vector2(x0 + w * 0.5, y0 - (ht - dp) * 0.5)
	var out: Array = []
	for st in unit:
		var pts := PackedVector2Array()
		var i := 0
		for p in st:
			var q: Vector2
			if big:
				var u: Vector2 = (p - lo) / span
				q = Vector2(x0 + w * (0.12 + 0.76 * u.x), y0 - ht + (ht + dp) * u.y)
			else:
				q = Vector2(ox + (p.x - lo.x) * em * k, y0 + p.y * em * k)
			q.x += slant * (y0 - q.y)
			q = center + ((q - center) * scale).rotated(rot) + shift
			q += Vector2(sin(phase + i * 0.9), cos(phase * 1.3 + i * 0.7)) * 0.012 * size
			pts.append(q)
			i += 1
		out.append(pts)
	return out


## A rule (a fraction's bar, a radical's) as one stroke along its middle, a little uneven.
static func _rule(r: Dictionary, rng: RandomNumberGenerator) -> PackedVector2Array:
	var x := float(r.get("x", 0.0))
	var w := float(r.get("w", 0.0))
	var y := float(r.get("y", 0.0)) + float(r.get("h", 0.0)) * 0.5
	var j := rng.randfn(0.0, 0.4)
	return PackedVector2Array([Vector2(x - 0.5, y + j),
		Vector2(x + w * 0.5, y + j * 0.5 + rng.randfn(0.0, 0.2)), Vector2(x + w + 0.8, y)])


## The order a hand writes an item in: TeX's (one count over glyphs and rules), each big operator
## moved ahead of the limits TeX set above it before it, and each overlay given the box it strikes.
static func _writing_order(item: Dictionary) -> Array:
	var seq: Array = []
	for g in item.get("glyphs", []):
		seq.append(g)
	for r in item.get("rules", []):
		seq.append(r)
	seq.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("k", 0)) < int(b.get("k", 0)))
	# A BAR UNDER AN ARROW IS ONE LONG ARROW: TeX sets `\implies` as an equals sign with a double
	# arrow kerned back over its end (`\longrightarrow`, a minus and an arrow); drawn as two glyphs
	# each in its own box, the first real lesson's pad said "=⇒" with a gap in it
	var at := 0
	while at < seq.size() - 1:
		var bar: Dictionary = seq[at]
		var nx: Dictionary = seq[at + 1]
		var pair := "%s+%s" % [String(bar.get("n", "")), String(nx.get("n", ""))]
		var long: String = String({"equal+arrowdblright": "arrowdbllong", "minus+arrowright": "arrowlong"}.get(pair, ""))
		if not long.is_empty() and float(nx.get("x", 0.0)) < float(bar.get("x", 0.0)) + float(bar.get("w", 0.0)) - 0.01:
			var merged := bar.duplicate()
			merged["n"] = long
			merged["w"] = float(nx.get("x", 0.0)) + float(nx.get("w", 0.0)) - float(bar.get("x", 0.0))
			merged["ht"] = maxf(float(bar.get("ht", 0.0)), float(nx.get("ht", 0.0)))
			seq[at] = merged
			seq.remove_at(at + 1)
		at += 1
	# AN OVERLAY STRIKES WHAT FOLLOWS IT: TeX's "not" slash (`negationslash`, in a not-equal) is a
	# glyph of no width laid over the next one, so it is drawn over that one's box, not its own.
	for n in range(seq.size() - 1):
		var g: Dictionary = seq[n]
		var next: Dictionary = seq[n + 1]
		if g.has("n") and next.has("n") and float(g.get("w", 0.0)) <= 0.01:
			g = g.duplicate()
			g["x"] = next.get("x", 0.0)
			g["w"] = next.get("w", 0.0)
			seq[n] = g
	var i := 0
	while i < seq.size():
		var g: Dictionary = seq[i]
		if BIG_OPS.has(String(g.get("n", ""))):
			var j := i
			while j > 0:
				var p: Dictionary = seq[j - 1]
				if not p.has("n"):
					break
				var cx := float(p.get("x", 0.0)) + float(p.get("w", 0.0)) * 0.5
				var gx := float(g.get("x", 0.0))
				var above := float(p.get("y", 0.0)) < float(g.get("y", 0.0)) - float(g.get("ht", 0.0)) * 0.5
				if cx >= gx - 1.0 and cx <= gx + float(g.get("w", 0.0)) + 1.0 and above:
					j -= 1
				else:
					break
			if j < i:
				seq.insert(j, seq.pop_at(i))
		i += 1
	return seq


static func _nib(size: float) -> float:
	return clampf(size * 0.055, 0.35, 1.6)


static func _length(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	return total


## The first `f` (0..1) of a polyline by length.
static func _partial(pts: PackedVector2Array, f: float) -> PackedVector2Array:
	if f >= 1.0 or pts.size() < 2:
		return pts
	var left := _length(pts) * maxf(f, 0.0)
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if left >= seg:
			out.append(pts[i])
			left -= seg
			continue
		out.append(pts[i - 1].lerp(pts[i], left / maxf(seg, 1e-6)))
		break
	return out


# --- the stroke fonts ------------------------------------------------------------

## One glyph of a Hershey font by its ASCII character: [left, right, strokes], [] when none. The
## fonts are the original data (.jhf, one glyph a line from code 32), read once and kept; locked,
## because a desk may build off the main thread.
static func _hershey(font: String, ch: String) -> Array:
	if ch.is_empty():
		return []
	_lock.lock()
	if not _fonts.has(font):
		_fonts[font] = _parse_jhf(String(FONTS.get(font, "")))
	var glyphs: Array = _fonts[font]
	_lock.unlock()
	var i := ch.unicode_at(0) - 32
	return glyphs[i] if i >= 0 and i < glyphs.size() else []


static func _parse_jhf(path: String) -> Array:
	var out: Array = []
	if path.is_empty() or not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.strip_edges().is_empty() or line.length() < 10:
			continue
		var n := line.substr(5, 3).strip_edges().to_int()
		var r := "R".unicode_at(0)
		var left := line.unicode_at(8) - r
		var right := line.unicode_at(9) - r
		var strokes: Array = []
		var cur: Array = []
		var i := 10
		while i + 1 < line.length() and i < 10 + (n - 1) * 2:
			var a := line.substr(i, 1)
			var b := line.substr(i + 1, 1)
			if a == " " and b == "R":
				if not cur.is_empty():
					strokes.append(cur)
				cur = []
			else:
				cur.append(Vector2(line.unicode_at(i) - r, line.unicode_at(i + 1) - r))
			i += 2
		if not cur.is_empty():
			strokes.append(cur)
		out.append([left, right, strokes])
	return out
