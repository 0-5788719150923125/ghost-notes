extends RefCounted
class_name ComicSpread

## ComicSpread - the two facing pages of an open comic book. What [ComicMedium] flies over.
##
## A comic is not read a page at a time. It is read a SPREAD at a time: you open the book
## and two pages face you across the spine, and the leaf you turn carries a page on each of
## its sides. Drawing one page at a time was the first cut of this medium and it cost three
## things at once - a portrait sheet inside a landscape frame leaves a wedge of desk in shot
## however close the camera gets; a pan has only one page's width of content to travel
## across before it runs onto the trim edge; and a "page turn" of a single sheet has no
## hinge that means anything, because a real page hinges on a SPINE and the spine is the
## thing a single page does not have.
##
## THE SPREAD IS THE UNIT, therefore. Two [ComicPage] layouts side by side, sharing one
## print style, indexed as one reading order that runs the left page and then the right.
##
## SPREAD SPACE: x in [0, 2] with the spine at x = 1 (so the left page is x in [0, 1] and
## the right is x in [1, 2]), y in [0, aspect] and DOWN, exactly as [ComicPage] uses its own
## unit box. A page-local point becomes a spread point by adding the page's side index to x,
## and that is the whole mapping - which is why the pages can stay unaware they are in a
## spread at all.
##
## ONE PRINT STYLE ACROSS THE SPREAD, and that is not a simplification, it is what a printed
## book does. The gutter, the margin, the corner radius and the page proportion are
## properties of the EDITION; only the panel grid is a property of the page. Sampling them
## per page gave the left page rounded corners and the right page square ones, facing each
## other across two feet of paper, which reads as two different books rather than as one
## spread.

## How many pages face each other. Named rather than written as 2, because every mapping
## below is "+ side" and the reader deserves to know which 2 that is.
const PAGES := 2

## The most panels a spread can hold, and therefore how many render targets a pool needs.
## See [constant ComicMedium.POOL].
const MAX_PANELS := ComicPage.MAX_PANELS * PAGES

## ONE PAGE is this many units wide in the world, so the spread is twice it and is centered on the
## origin with the spine on the world Y axis. Deliberately unchanged from the single-page medium: a
## panel therefore has exactly the world size it always had, every framing constant of
## [ComicCamera] keeps the meaning it was tuned with, and the only thing that grew is the sheet.
const PAGE_W := 2.0

## THE AIM NEVER LEAVES THE SHEET. Spread coordinates, as a margin inside the trim.
##
## A move that aims past the outer edge is aiming at the desk, and no framing distance can
## then put paper across the whole frame - the covering solve has nothing to solve. Sweeps
## and tracks deliberately run to and past the edges, so they are clamped here rather than
## being written not to.
const AIM_MARGIN := 0.06

## HOW MUCH PANEL IS UNDER THE AIM: the shape of the falloff, in units of the panel's own
## half-size, measured Chebyshev (so it is the panel's rectangle, not a disc inside it).
##
## THIS IS THE FIX FOR THE WHOLE REPORT, and it is one number turned into a constraint:
## "focusing a zoom-in camera at the corner of a frame is terrible". Everything before this
## tried to make the camera AIM well; nothing stopped it from being TIGHT while aiming
## badly, and tight-while-badly-aimed is the only combination that actually looks broken.
## Wide over a gutter shows four panels and reads as a page. Tight over a gutter shows
## paper.
##
## So content is scored, and the framing is a function of it (see [ComicCamera]'s place_eye).
## Inside CORE - the middle 55% of a panel - the score is 1 and the shot is exactly as tight as
## the move asked for. By EDGE, just inside the panel's border, it is 0 and the shot has opened
## to its OFF_FILL. Between them it is smooth, so a pan across a gutter WIDENS as it crosses and
## closes again on the far panel, which is what a camera operator does without being told.
const CONTENT_CORE := 0.55
const CONTENT_EDGE := 0.98
## How much content a move's RESTING aim must have. Not 1.0: snapping every terminal aim to
## a panel's dead center would make every settled shot the same shot, and the whole point of
## sampling a station is that it is not. This is "far enough inside the panel that the shot
## is of the panel", and [method settle_aim] walks the aim in until it clears the bar.
const SETTLE_CONTENT := 0.72

## The print style, shared by both leaves. Sampled here and handed down, see the note above.
var aspect := 1.5
var gutter := 0.045
var margin := 0.06
var radius := 0.0

## The two [ComicPage] layouts, left first.
var pages: Array = []

## Every panel of the spread in READING ORDER - the left page's panels, then the right's.
## Each entry is `{rect: Rect2, cant: float, side: int, local: int}`, where `rect` is in
## SPREAD space and `side`/`local` say which page it came from and its index there.
var panels: Array = []


## Roll a spread. [param key] is folded into every draw, exactly as [ComicPage] does it, so
## the same session seed and spread index always produce the same two pages.
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
		# A SEPARATE DRAW PER PAGE, not a walk of one stream: the two grids must be
		# independent, or a spread whose left page happens to roll three rows biases the
		# right page toward matching it, and a book of symmetrical spreads is a book that
		# looks printed by a machine with one idea.
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


## The x of the spine in spread coordinates. The leaf hinges here and the mirror reflects
## about it, so it is named once rather than written as 1.0 in five places.
const SPINE := 1.0


## Which page panel [param i] is on: 0 for the left, 1 for the right.
func side_of(i: int) -> int:
	return int(panels[i]["side"])


## The global indices of every panel on page [param side], in reading order. What the leaf
## draw walks - a turning leaf carries ONE page, not the spread.
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


## The four corners of the WHOLE spread, for the covering solve.
func spread_corners() -> Array:
	return [Vector2(0, 0), Vector2(2, 0), Vector2(2, aspect), Vector2(0, aspect)]


## Reflect a spread point about the spine. This is what makes the leaf's BACK face work:
## the incoming left page, mirrored here and then rotated about the spine by pi, lands
## exactly back on itself.
##
##   mirror(q).x = 2 - q.x, so a left-page point q.x in [0, 1] becomes [1, 2]
##   rotating about the spine by pi maps world x -> -x, i.e. spread x -> 2 - x
##   composed: 2 - (2 - q.x) = q.x
##
## That identity is the whole reason the turn can be a real leaf with a printed back rather
## than a cross-dissolve: at the end of the swing the leaf IS the new left page, in exactly
## the place the new left page will be drawn flat the moment the turn ends, so there is
## nothing to blend and nothing that jumps.
static func mirror(p: Vector2) -> Vector2:
	return Vector2(2.0 * SPINE - p.x, p.y)


## Map a point in panel [param i]'s own unit square (0..1, y down) into SPREAD space, cant
## included. The textured grid walks this: the panel's UV grid IS its unit square, so the
## same call gives both the position and the texture coordinate.
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


## The inverse of [method panel_point] for a point already in spread space: where
## [param p] falls in panel [param i]'s own unit square. Outside 0..1 means outside the
## panel, and by how much - which is what [method content_at] reads to decide
## whether the camera is looking at a picture or at the paper between pictures.
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


## Panel [param i]'s four corners in spread space, cant applied. Counter-clockwise from the
## top-left, so a caller can walk them directly.
func corners(i: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		out.append(panel_point(i, q))
	return out


## Panel [param i]'s aspect (width / height). The medium sizes that panel's render target
## to it, so a scene is never squeezed or cropped to fit its frame.
func panel_aspect(i: int) -> float:
	var r: Rect2 = panels[i]["rect"]
	return r.size.x / maxf(r.size.y, 1e-4)


## The center of panel [param i] in spread space - what the reading camera aims at.
func panel_center(i: int) -> Vector2:
	var r: Rect2 = panels[i]["rect"]
	return r.position + r.size * 0.5


## The middle of the page panel [param i] is printed on - what an aim is pulled toward, and
## what a swoop is pushed away from. See [constant ComicCamera.AIM_PULL] for why this is the page
## and not the sheet.
func page_center(i: int) -> Vector2:
	return Vector2(float(side_of(i)) + 0.5, aspect * 0.5)


## The panel with the most area on the sheet - what a page designer made big because it is the
## one to look at, and therefore the fallback grabber when there is no footage.
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


## The panel whose aspect is nearest [param want] (width / height, above 0) - where a clip of
## that shape is cropped least. Compared in LOG space, because aspect is a ratio: 2.0 and 0.5
## are equally wrong for a square clip, and subtracting them would call one of them nearly right.
func nearest_aspect(want: float) -> int:
	var best := 0
	var best_err := INF
	for i in panels.size():
		var err := absf(log(maxf(panel_aspect(i), 0.01) / want))
		if err < best_err:
			best_err = err
			best = i
	return best


## HOW MUCH PANEL IS UNDER [param aim], 0 to 1. See CONTENT_CORE.
##
## The MAXIMUM over panels rather than a sum: two panels never overlap, so at most one can
## contain the aim, and taking the max means a point just outside a big panel scores by its
## distance from THAT panel rather than being diluted by the eleven it is nowhere near.
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


## WHICH PANEL SETS THE FRAMING SCALE: the one the aim is most inside, and only failing that
## the one whose center is nearest.
##
## [method nearest_panel] alone was wrong and measurably so. It compares CENTERS, so an aim
## sitting squarely inside a wide panel can be nearer to the center of the small panel beside
## it - and then the camera sizes the shot to the small panel, which is a framing computed for
## something that is not in the middle of the picture.
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


## Which panel the camera is over. Nearest center in spread coordinates - the fallback for
## [method framing_panel] when the aim is inside nothing at all.
func nearest_panel(aim: Vector2) -> int:
	var best := 0
	var best_d := 1e9
	for i in panels.size():
		var d := aim.distance_squared_to(panel_center(i))
		if d < best_d:
			best_d = d
			best = i
	return best


## Walk an aim in toward its panel until it is far enough inside to be worth stopping on.
##
## PULLED, NOT SNAPPED, and only as far as it has to go - see SETTLE_CONTENT. A move that
## already ends well inside a panel is returned untouched, so this costs the vocabulary
## nothing; a move that ends on a border is walked in until the shot would be of the panel
## rather than of the rule around it.
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


## THE PRINTED AREA: the box that contains every panel on the spread, grown by AIM_MARGIN.
##
## The aim used to be clamped to the SHEET, so a move that ran past its subject - a track
## overruns by nearly half a page width by design - came to rest out on the trim margin, in a
## corner of the paper with no picture anywhere near it. The chain then took the camera back
## toward the reading, which is the "drifts into a corner then bounces back from it again"
## exactly: out to the corner because the move said so, back again because the reading did.
##
## Clamping to the PRINTED area instead means an overrun still leaves its panel - that is the
## gesture, and it still passes over the gutter and out to the edge of the outermost panel -
## but it cannot reach the blank margin, so there is no corner to be retrieved from. The
## outset by AIM_MARGIN is what keeps "past the last panel" from meaning "exactly on its edge".
func printed_bounds() -> Rect2:
	if panels.is_empty():
		return Rect2(AIM_MARGIN, AIM_MARGIN, 2.0 - AIM_MARGIN * 2.0, 1.0)
	var r: Rect2 = panels[0]["rect"]
	for i in panels.size():
		r = r.merge(panels[i]["rect"])
	return r.grow(AIM_MARGIN)


## A point in SPREAD space (x 0..2 with the spine at 1, y 0..aspect and DOWN) -> world
## space. Everything drawn on the sheet goes through this one call, so the paper, the
## panels, the gutters and the ink can never disagree about where the spread is.
##
## [param m] IS THE WHOLE TRANSFORM, handed in already built: the spread's attitude for a
## flat page, or the attitude times the leaf's hinge rotation for a turning one. It used to
## build Basis.from_euler(att) here, per vertex - six trig calls and a matrix, roughly 2500
## times a frame with an argument that had not changed - and the live-performance audit
## (2026-09-03, perf_probe) attributed most of the page's cost to exactly that. Hoisting it is
## not an approximation; the value was always identical.
##
## [param mirrored] reflects the point about the spine before placing it, which is what draws
## the BACK of a turning leaf. See [method mirror].
func world(p: Vector2, m: Basis, mirrored := false, depth := 0.0) -> Vector3:
	var x := (2.0 * SPINE - p.x) if mirrored else p.x
	# THE TURN HINGES ON THE SPINE, and on a spread the spine is the origin - so unlike the
	# single page, which had to rotate about an off-center pivot to avoid reading as a card
	# spinning in place, there is no pivot term here at all. The leaf's rotation is simply
	# part of `m`.
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
