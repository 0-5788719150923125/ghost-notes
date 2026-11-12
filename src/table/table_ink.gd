extends RefCounted
class_name TableInk

## TableInk - what a pen writes that TeX lays out, at the table: a formula, a drawing, a line of words with math in it,
## each a `write` of the work ([constant Motions.LAWS]). ghost's own TeX (`hosts/math/typeset.py`, the episode's `ink`
## step) lays each out once; it is drawn here as the hand writes it ([Ink]), into the picture a sheet's writing shows
## ([SheetWriting]). Any show's page can carry a formula or a graph (next/proof.md).
## TeX lays out and a hand writes: the structure is TeX's (a fraction's bar between numerator and denominator where
## TeX set it) and the strokes are the Hershey hand's, in the order a hand writes them.
##
## Which writes ([method items_of]): a `tex` (TeX math on its own line; an `align*` or `gather*` is set as the display it
## is), a `draw` (an SVG in figure.py's words: lines, curves, arrows, labels, axes with curves computed from their
## expressions or plotted from the series the solve kept) and a `text` with `$...$` in it (words and math, wrapped at
## the page's width). Words with no math are the sheet's own hand ([SheetWriting.picture]) and never go through TeX.
##
## An item's picture ([method picture_of]): R the ink's coverage, G when each point is put down, on the hand's own
## schedule ([method Ink.schedule]: the pen's speed, its lifts, a breath between glyphs, a longer one before a
## relation), so a formula is written stroke by stroke as the act's `written` goes from 0 to 1.

## The episode's file of TeX's layout: typeset.py's answer, `{items: [records], fonts}`.
const FILE := "ink.json"
## TeX's measure for a page: a column this many points wide - where words with math wrap, and how wide a page is taken to be.
const PAD_WIDTH := 270.0
## The line a hand writes on, points: TeX's 12 pt type's baseline skip and a little, which a page's words are scaled to.
const LINE_PT := 15.0
## The most words-with-math and formula characters one write may carry.
const MOST_CHARS := 600
## The most characters of an SVG one drawing may carry.
const MOST_SVG := 12000
## The pixels kept clear round a record's ink in its picture ([method picture_of]).
const PAD_PX := 3
## A display environment TeX sets only outside math ([method item]).
static var DISPLAY := RegEx.create_from_string("^\\s*\\\\begin\\{(align|gather|multline|flalign|alignat)\\*?\\}")


## The item a write lays out by TeX ([param kind] "tex", "draw" or "text"), as typeset.py takes it: `{id, tex, mode}`. Its id is
## a digest of what it is, so the bake finds TeX's record of it from the write alone.
static func item(kind: String, tex: String) -> Dictionary:
	var mode := "text"
	if kind == "draw":
		mode = "figure"
	elif kind == "tex":
		# Math, unless it is a display environment of its own (align*, gather*), which TeX sets only outside math.
		mode = "display" if DISPLAY.search(tex) != null else "math"
	return {"id": "i" + (kind + "|" + tex).sha256_text().substr(0, 12), "tex": tex, "mode": mode}


## The item [param track] (a `write`, as [method Motions.law] made it) lays out by TeX, or `{}` for words in the sheet's own hand.
static func item_of_track(track: Dictionary) -> Dictionary:
	if not String(track.get("draw", "")).is_empty():
		return item("draw", String(track["draw"]))
	if not String(track.get("tex", "")).is_empty():
		return item("tex", String(track["tex"]))
	var text := String(track.get("text", ""))
	if text.count("$") >= 2:
		return item("text", text)
	return {}


## Every item the acts [param raw] (`acts.json` as parsed) write by TeX, once each, in order: what the ink step typesets.
static func items_of(raw: Variant) -> Array:
	var acts: Array = (raw as Dictionary).get("acts", []) if raw is Dictionary and (raw as Dictionary).get("acts") is Array \
		else (raw if raw is Array else [])
	var seen := {}
	var out: Array = []
	for a in acts:
		if not (a is Dictionary) or not ((a as Dictionary).get("tracks") is Array):
			continue
		for t in (a as Dictionary)["tracks"]:
			if not (t is Dictionary) or String((t as Dictionary).get("law", "")) != "write":
				continue
			var it := item_of_track(raw_write(t as Dictionary))
			if not it.is_empty() and not seen.has(String(it["id"])):
				seen[String(it["id"])] = true
				out.append(it)
	return out


## A write as an agent wrote it, read as [method Motions.law] reads it: what it writes, trimmed to what a write may carry.
static func raw_write(t: Dictionary) -> Dictionary:
	var out := {}
	var draw := String(t.get("draw", "")).strip_edges()
	if draw.begins_with("<svg") and draw.length() <= MOST_SVG:
		out["draw"] = draw
		return out
	var tex := String(t.get("tex", "")).strip_edges().trim_prefix("$$").trim_suffix("$$").strip_edges()
	if not tex.is_empty():
		out["tex"] = tex.left(MOST_CHARS)
		return out
	var text := String(t.get("text", "")).strip_edges().replace("\\n", "\n")
	out["text"] = text.left(MOST_CHARS) if text.count("$") >= 2 else text.left(160)
	return out


## TeX's layout of [param items] now (typeset.py), for an agent waiting on it - the puppeteer's `act`, so it sees its
## formulas as they will be written and hears what TeX refuses while it can still fix them ([PuppeteerTools]); never
## called in a build. [param data] names the series a drawing plots, [param work] is a folder of its own. Awaits the
## host: the answer `{items, fonts}`, or `{error}` ("" when TeX is not installed yet and the ink step will lay it out
## later).
static func typeset(items: Array, data: Dictionary, work: String) -> Dictionary:
	var py := Deps.venv_bin("user://math_venv", "python")
	var host := BundledHosts.path("res://hosts/math/typeset.py")
	var latex := Provision.tool_path("tex", "latex")
	if host.is_empty() or latex.is_empty() or not FileAccess.file_exists(py):
		return {"error": ""}
	DirAccess.make_dir_recursive_absolute(work)
	var stamp := "%d_%d" % [Time.get_ticks_usec(), randi()]
	var spec := work.path_join("ink_%s.json" % stamp)
	var out := work.path_join("ink_%s.out.json" % stamp)
	var log := work.path_join("ink_%s.log" % stamp)
	var err := TextGen.put(spec, JSON.stringify({"items": items, "out": out, "work": work.path_join("tex"), "width": PAD_WIDTH,
		"outlines": true, "bin": latex.get_base_dir(), "data": data}))
	if not err.is_empty():
		return {"error": err}
	var pid := Subprocess.start_logged(py, PackedStringArray(["-I", host, spec]), log, "ink")
	if pid <= 0:
		return {"error": "TeX's layout could not start"}
	var tree := Engine.get_main_loop() as SceneTree
	while Subprocess.alive(pid):
		await tree.create_timer(0.1).timeout
	var answer: Variant = JSON.parse_string(FileAccess.get_file_as_string(out)) if FileAccess.file_exists(out) else null
	for f in [spec, out]:
		DirAccess.remove_absolute(f)
	if not (answer is Dictionary):
		return {"error": "TeX's layout failed: " + FileAccess.get_file_as_string(log).strip_edges().right(300)}
	DirAccess.remove_absolute(log)
	return answer


## TeX's record of [param it] in [param doc] (the ink step's answer), `{}` when it has none or TeX refused it.
static func record_in(doc: Dictionary, it: Dictionary) -> Dictionary:
	if it.is_empty():
		return {}
	for r in doc.get("items", []):
		if r is Dictionary and String((r as Dictionary).get("id", "")) == String(it["id"]):
			return r if bool((r as Dictionary).get("ok", false)) else {}
	return {}


## The size of record [param rec] in TeX points: `Vector2(w, h + d)`.
static func size_of(rec: Dictionary) -> Vector2:
	return Vector2(maxf(float(rec.get("w", 0.0)), 1.0), maxf(float(rec.get("h", 0.0)) + float(rec.get("d", 0.0)), 1.0))


## Record [param rec] written by the hand seeded [param seed], at [param px] pixels a TeX point ([method picture_of_schedule]).
## [param outlines] is the answer's `fonts`, for a glyph no stroke font has. `{image, missing, seconds, strokes}`: `missing`
## the glyphs it found no stroke for; `strokes` the hand's schedule ([method Ink.schedule]: each stroke's points in the
## record's TeX points and when it is drawn), which a pen seen follows ([method TableWork._pen_nib]).
static func picture_of(rec: Dictionary, seed: int, px: float, outlines: Dictionary = {}) -> Dictionary:
	var made := Ink.strokes_of(rec, seed, outlines)
	var sched := Ink.schedule(made["strokes"], seed)
	return {"image": picture_of_schedule(sched, size_of(rec), float(rec.get("h", 0.0)), px), "missing": made["missing"],
		"seconds": maxf(float(sched["length"]), 1e-3), "strokes": sched["strokes"]}


## A hand's schedule ([method Ink.schedule]) as ink, at [param px] pixels a TeX point in a box [param size] TeX points (and
## [constant PAD_PX] round it), its strokes' y [param top] down from the box's top: an image whose R is the ink's coverage
## and G when each point is put down, 0 to 0.98 along the schedule - each point when the hand's stroke reaches it ([method
## Ink.share]), so a pen following the schedule is at the ink's front. A formula's strokes and a hand's words alike.
static func picture_of_schedule(sched: Dictionary, size: Vector2, top: float, px: float) -> Image:
	var length := maxf(float(sched["length"]), 1e-3)
	var pad := PAD_PX
	var w := int(ceil(size.x * px)) + pad * 2
	var h := int(ceil(size.y * px)) + pad * 2
	var img := Image.create(maxi(w, 2), maxi(h, 2), false, Image.FORMAT_RGBAH)
	img.fill(Color(0.0, 1.0, 0.0, 1.0))
	for s in sched["strokes"]:
		var st: Dictionary = s
		var pts: PackedVector2Array = st["points"]
		if pts.is_empty():
			continue
		var t0 := float(st["t0"])
		var t1 := float(st["t1"])
		var total := 0.0
		for i in range(1, pts.size()):
			total += pts[i - 1].distance_to(pts[i])
		var r := maxf(float(st.get("width", 0.6)) * px * 0.5, 0.6)
		var shade := 0.35 if bool(st.get("faint", false)) else 1.0
		var at := 0.0
		var prev := Vector2((pts[0].x) * px + pad, (pts[0].y + top) * px + pad)
		if pts.size() == 1:
			_dot(img, prev, r, (t0 / length) * 0.98, shade)
			continue
		for i in range(1, pts.size()):
			var seg := pts[i - 1].distance_to(pts[i])
			var a_t := t0 + (t1 - t0) * Ink.when_along(at / maxf(total, 1e-6))
			at += seg
			var b_t := t0 + (t1 - t0) * Ink.when_along(at / maxf(total, 1e-6))
			var cur := Vector2(pts[i].x * px + pad, (pts[i].y + top) * px + pad)
			_segment(img, prev, cur, r, a_t / length * 0.98, b_t / length * 0.98, shade)
			prev = cur
	return img


## A segment of ink from [param a] to [param b] (pixels), [param r] its half width, put down from [param wa] to [param wb]: each
## pixel it covers takes the most coverage and the earliest time of all the ink over it.
static func _segment(img: Image, a: Vector2, b: Vector2, r: float, wa: float, wb: float, shade: float) -> void:
	var lo := Vector2i(int(floor(minf(a.x, b.x) - r - 1.0)), int(floor(minf(a.y, b.y) - r - 1.0)))
	var hi := Vector2i(int(ceil(maxf(a.x, b.x) + r + 1.0)), int(ceil(maxf(a.y, b.y) + r + 1.0)))
	lo = lo.clamp(Vector2i.ZERO, Vector2i(img.get_width() - 1, img.get_height() - 1))
	hi = hi.clamp(Vector2i.ZERO, Vector2i(img.get_width() - 1, img.get_height() - 1))
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 1e-9)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var u := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			var d := p.distance_to(a + ab * u)
			var cov := clampf(r + 0.5 - d, 0.0, 1.0) * shade
			if cov <= 0.0:
				continue
			_put(img, x, y, cov, lerpf(wa, wb, u))


## A dot of ink at [param c], [param r] its radius, put down at [param when].
static func _dot(img: Image, c: Vector2, r: float, when: float, shade: float) -> void:
	_segment(img, c, c + Vector2(0.001, 0.0), r, when, when, shade)


static func _put(img: Image, x: int, y: int, cov: float, when: float) -> void:
	var was := img.get_pixel(x, y)
	img.set_pixel(x, y, Color(maxf(was.r, cov), minf(was.g, when), 0.0, 1.0))
