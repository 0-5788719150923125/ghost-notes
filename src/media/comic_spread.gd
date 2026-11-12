extends RefCounted
class_name ComicSpread

## ComicSpread - the two facing pages of an open comic book: what [ComicMedium] flies over.
##
## A comic is read a spread at a time, so the spread is the unit: two [ComicPage] layouts side by
## side sharing one print style, indexed as one reading order (the left page, then the right). A
## single page in a landscape frame leaves desk in shot, gives a pan too little to travel across, and
## has no spine to hinge a page turn on.
##
## Spread space: x in [0, 2] with the spine at x = 1, y in [0, aspect] and down, as [ComicPage] uses
## its own unit box. A page-local point becomes a spread point by adding the page's side index to x,
## so the pages stay unaware they are in a spread.
##
## One print style across the spread, as in a printed book: gutter, margin, corner radius and page
## proportion belong to the edition; only the panel grid belongs to the page.

## How many pages face each other (every mapping below is "+ side").
const PAGES := 2

## The most panels a spread can hold, and therefore how many render targets a pool needs.
## See [constant ComicMedium.POOL].
const MAX_PANELS := ComicPage.MAX_PANELS * PAGES

## One page is this many units wide in the world; the spread is twice it, centered on the origin with
## the spine on the world Y axis. A panel keeps the world size it had on a single page, so every
## framing constant of [ComicCamera] keeps its meaning.
const PAGE_W := 2.0

## The aim never leaves the sheet: spread coordinates, as a margin inside the trim. An aim past the
## outer edge is aiming at the desk, and no framing distance can then cover the frame with paper (the
## covering solve has nothing to solve). Sweeps and tracks run to and past the edges, so they are
## clamped here.
const AIM_MARGIN := 0.06

## How much panel is under the aim: the shape of the falloff, in units of the panel's own half-size,
## measured Chebyshev (the panel's rectangle, not a disc inside it).
##
## A tight shot badly aimed is the one combination that looks broken (wide over a gutter shows four
## panels; tight over a gutter shows paper), so the framing is a function of the content score (see
## [ComicCamera]'s place_eye). Inside CONTENT_CORE, the middle 55% of a panel, the score is 1 and the shot is
## as tight as the move asked for; at CONTENT_EDGE, just inside the border, it is 0 and the shot has opened to
## its OFF_FILL; between them it is smooth, so a pan across a gutter widens as it crosses and closes
## again on the far panel.
const CONTENT_CORE := 0.55
const CONTENT_EDGE := 0.98
## How much content a move's resting aim must have. Not 1.0: snapping every terminal aim to a panel's
## dead center would make every settled shot the same. [method settle_aim] walks the aim in until it
## clears this bar.
const SETTLE_CONTENT := 0.72

## The print style, shared by both leaves: sampled here and handed down.
var aspect := 1.5
var gutter := 0.045
var margin := 0.06
var radius := 0.0

## The two [ComicPage] layouts, left first.
var pages: Array = []

## Every panel of the spread in reading order (the left page's, then the right's). Each entry is
## `{rect: Rect2, cant: float, side: int, local: int}`: `rect` in spread space, `side`/`local` the page
## it came from and its index there.
var panels: Array = []


## Roll a spread. [param key] is folded into every draw, as [ComicPage] does, so the same session seed
## and spread index give the same two pages.
func _init(key: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = key
	aspect = rng.randf_range(ComicPage.ASPECT.x, ComicPage.ASPECT.y)
	gutter = rng.randf_range(ComicPage.GUTTER.x, ComicPage.GUTTER.y)
	margin = maxf(gutter, rng.randf_range(ComicPage.MARGIN.x, ComicPage.MARGIN.y))
	# Hard corners are the classic look, so weight toward zero - see ComicPage.RADIUS.
	radius = ComicPage.RADIUS.y * pow(rng.randf(), 2.2)
	var style := {"aspect": aspect, "gutter": gutter, "margin": margin, "radius": radius}
	for side in PAGES:
		# A separate draw per page, not a walk of one stream, so the two grids are independent.
		var pg := ComicPage.new(hash([key, "spread-page", side]), style)
		pages.append(pg)
		for i in pg.panels.size():
			var p: Dictionary = pg.panels[i]
			var r: Rect2 = p["rect"]
			panels.append({
				"rect": Rect2(r.position + Vector2(float(side), 0.0), r.size),
				"cant": p["cant"],
				"side": side,
				"local": i,
			})


## The x of the spine in spread coordinates: the leaf hinges here and the mirror reflects about it.
const SPINE := 1.0


## Which page panel [param i] is on: 0 for the left, 1 for the right.
func side_of(i: int) -> int:
	return int(panels[i]["side"])


## The global indices of every panel on page [param side], in reading order. What the leaf draw walks.
func page_panels(side: int) -> Array:
	var out: Array = []
	for i in panels.size():
		if int(panels[i]["side"]) == side:
			out.append(i)
	return out


## The four corners of page [param side] in spread coordinates, counter-clockwise from the
## top-left. The paper quad and the shadow walk these.
func page_corners(side: int) -> Array:
	var x := float(side)
	return [Vector2(x, 0.0), Vector2(x + 1.0, 0.0),
		Vector2(x + 1.0, aspect), Vector2(x, aspect)]


## The four corners of the whole spread, for the covering solve.
func spread_corners() -> Array:
	return [Vector2(0, 0), Vector2(2, 0), Vector2(2, aspect), Vector2(0, aspect)]


## Reflect a spread point about the spine, which makes the leaf's back face work: the incoming left
## page, mirrored here then rotated about the spine by pi, lands back on itself.
##
##   mirror(q).x = 2 - q.x; rotating about the spine by pi maps spread x -> 2 - x;
##   composed: 2 - (2 - q.x) = q.x
##
## So at the end of the swing the leaf is the new left page, where it will be drawn flat the moment
## the turn ends: nothing to blend, nothing that jumps.
static func mirror(p: Vector2) -> Vector2:
	return Vector2(2.0 * SPINE - p.x, p.y)


## Map a point in panel [param i]'s own unit square (0..1, y down) into spread space, cant included.
## The textured grid walks this: the panel's UV grid is its unit square.
func panel_point(i: int, uv: Vector2) -> Vector2:
	var p: Dictionary = panels[i]
	var r: Rect2 = p["rect"]
	var c := r.position + r.size * 0.5
	var ca: float = p["cant"]
	var v := r.position + r.size * uv - c
	if is_zero_approx(ca):
		return c + v
	var cs := cos(ca)
	var sn := sin(ca)
	return c + Vector2(v.x * cs - v.y * sn, v.x * sn + v.y * cs)


## The inverse of [method panel_point] for a point already in spread space: where [param p] falls in
## panel [param i]'s own unit square (outside 0..1 is outside the panel, and by how much, which
## [method content_at] reads).
func panel_uv(i: int, p: Vector2) -> Vector2:
	var e: Dictionary = panels[i]
	var r: Rect2 = e["rect"]
	var c := r.position + r.size * 0.5
	var ca: float = e["cant"]
	var v := p - c
	if not is_zero_approx(ca):
		var cs := cos(-ca)
		var sn := sin(-ca)
		v = Vector2(v.x * cs - v.y * sn, v.x * sn + v.y * cs)
	return (v + r.size * 0.5) / Vector2(maxf(r.size.x, 1e-4), maxf(r.size.y, 1e-4))


## Panel [param i]'s four corners in spread space, cant applied, counter-clockwise from the top-left.
func corners(i: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		out.append(panel_point(i, q))
	return out


## Panel [param i]'s aspect (width / height); the medium sizes that panel's render target to it.
func panel_aspect(i: int) -> float:
	var r: Rect2 = panels[i]["rect"]
	return r.size.x / maxf(r.size.y, 1e-4)


## The center of panel [param i] in spread space - what the reading camera aims at.
func panel_center(i: int) -> Vector2:
	var r: Rect2 = panels[i]["rect"]
	return r.position + r.size * 0.5


## The middle of the page panel [param i] is printed on: what an aim is pulled toward and a swoop is
## pushed away from (see [constant ComicCamera.AIM_PULL]).
func page_center(i: int) -> Vector2:
	return Vector2(float(side_of(i)) + 0.5, aspect * 0.5)


## The panel with the most area on the sheet, the fallback grabber when there is no footage.
func largest_panel() -> int:
	var best := 0
	var best_a := -1.0
	for i in panels.size():
		var rr: Rect2 = panels[i]["rect"]
		var a := rr.size.x * rr.size.y
		if a > best_a:
			best_a = a
			best = i
	return best


## The panel whose aspect is nearest [param want] (width / height, above 0), where a clip of that
## shape is cropped least. Compared in log space, since aspect is a ratio.
func nearest_aspect(want: float) -> int:
	var best := 0
	var best_err := INF
	for i in panels.size():
		var err := absf(log(maxf(panel_aspect(i), 0.01) / want))
		if err < best_err:
			best_err = err
			best = i
	return best


## How much panel is under [param aim], 0 to 1 (see CONTENT_CORE). The maximum over panels, not a sum:
## panels never overlap, so a point outside a big panel scores by its distance from that panel.
func content_at(aim: Vector2) -> float:
	var best := 0.0
	for i in panels.size():
		var q := panel_uv(i, aim)
		var d := maxf(absf(q.x - 0.5), absf(q.y - 0.5)) * 2.0
		var s := 1.0 - smoothstep(CONTENT_CORE, CONTENT_EDGE, d)
		if s > best:
			best = s
			if best > 0.999:
				break
	return best


## Which panel sets the framing scale: the one the aim is most inside, failing that the one whose
## center is nearest. ([method nearest_panel] alone compares centers, so an aim inside a wide panel
## can size the shot to the small panel beside it.)
func framing_panel(aim: Vector2) -> int:
	var best := -1
	var best_s := 0.0
	for i in panels.size():
		var q := panel_uv(i, aim)
		var d := maxf(absf(q.x - 0.5), absf(q.y - 0.5)) * 2.0
		var s := 1.0 - smoothstep(CONTENT_CORE, CONTENT_EDGE, d)
		if s > best_s:
			best_s = s
			best = i
	return best if best >= 0 else nearest_panel(aim)


## Which panel the camera is over: nearest center in spread coordinates, the fallback for
## [method framing_panel] when the aim is inside nothing.
func nearest_panel(aim: Vector2) -> int:
	var best := 0
	var best_d := 1e9
	for i in panels.size():
		var d := aim.distance_squared_to(panel_center(i))
		if d < best_d:
			best_d = d
			best = i
	return best


## Walk an aim in toward its panel until it is far enough inside to be worth stopping on (see
## SETTLE_CONTENT). Pulled, not snapped: a move that already ends well inside a panel is returned
## untouched; one that ends on a border is walked in until the shot is of the panel.
func settle_aim(aim: Vector2) -> Vector2:
	var i := framing_panel(aim)
	if i < 0:
		return aim
	var c: Vector2 = panel_center(i)
	for _k in 8:
		if content_at(aim) >= SETTLE_CONTENT:
			break
		aim = aim.lerp(c, 0.35)
	return aim


## Keep an aim on the paper - see AIM_MARGIN. Spread coordinates, so x runs to 2.
func clamp_aim(p: Vector2) -> Vector2:
	var b := printed_bounds()
	return Vector2(clampf(p.x, b.position.x, b.end.x), clampf(p.y, b.position.y, b.end.y))


## The printed area: the box that contains every panel on the spread, grown by AIM_MARGIN. The aim is
## clamped to it rather than to the sheet, so an overrun move (a track overruns by nearly half a page
## width by design) still leaves its panel, passing over the gutter out to the outermost panel's edge,
## but cannot reach the blank margin. The outset keeps "past the last panel" from meaning "on its edge".
func printed_bounds() -> Rect2:
	if panels.is_empty():
		return Rect2(AIM_MARGIN, AIM_MARGIN, 2.0 - AIM_MARGIN * 2.0, 1.0)
	var r: Rect2 = panels[0]["rect"]
	for i in panels.size():
		r = r.merge(panels[i]["rect"])
	return r.grow(AIM_MARGIN)


## A point in spread space (x 0..2 with the spine at 1, y 0..aspect and down) -> world space. Everything
## drawn on the sheet goes through this one call, so paper, panels, gutters and ink agree.
##
## [param m] is the whole transform, handed in already built: the spread's attitude for a flat page, or
## the attitude times the leaf's hinge rotation for a turning one (building it per vertex is costly).
##
## [param mirrored] reflects the point about the spine first, which draws the back of a turning leaf.
## See [method mirror].
func world(p: Vector2, m: Basis, mirrored := false, depth := 0.0) -> Vector3:
	var x := (2.0 * SPINE - p.x) if mirrored else p.x
	# The turn hinges on the spine, which is the origin on a spread, so there is no pivot term: the
	# leaf's rotation is part of `m`.
	return m * Vector3(
		(x - SPINE) * PAGE_W,
		-(p.y - aspect * 0.5) * PAGE_W,   # spread y is DOWN, world y is up
		-depth * PAGE_W)                  # behind the sheet, along its own normal


## The four world corners of panel [param i], cant applied, placed by [param m].
func panel_world(i: int, m: Basis) -> Array:
	var out: Array = []
	for uv in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		out.append(world(panel_point(i, uv), m))
	return out


## The four world corners of the whole spread, placed by [param m] - for the covering solve.
func world_corners(m: Basis) -> Array:
	var out: Array = []
	for p in spread_corners():
		out.append(world(p, m))
	return out
