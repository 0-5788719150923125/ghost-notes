class_name PaintLayers
extends RefCounted

## Repaints a picture of the finished surface with the table's own paints and tools (next/painted_surface.md).
##
## Each operation (a tool, a pot, a manner, and where it works: an element of the decorator's, in its act's order) lays paint only where
## the canvas still differs from the picture, as far as the tool can resolve, and only where the tool's footprint fits. A foundation goes
## on whole; then, coarse to fine, the picture's own colors in their own order. After Hertzmann, "Painterly Rendering with Curved Brush
## Strokes of Multiple Sizes" (1998), with each stroke a pot.
##
## The picture only says where paint is still wanted. Every mark is a tool's: it is made by the program a show plays
## ([method Skins._Prog.dab], [method Skins._Prog.stroke]: loads, trips back to the pot, the hand) and drawn as the tool lays it
## ([method raster]). A sponge's dab has pores and a ragged edge and runs dry dab by dab; a brush's pull has the width it is pressed to
## and streaks as it runs dry; a liner's line is crisp. The canvas each look corrects is those marks, so a patchy patch is gone over again,
## and the paint a show draws is their coverage ([method lay]'s `coverage`).
##
## Every operation but a foundation paints toward the picture itself, point for point: its ground is balanced to the foundation's paint
## with the light taken out where it falls off ([method _ground_to]). Marks are fitted by what they actually lay ([method _fit_op]: each
## is rastered as it will be drawn, at each press and thinning it may take, and kept only where it brings the shown canvas nearer the
## picture). The canvas is the show's own ([member pre]: blended as the skin's canvas blends sprites, shown as prop.gdshader shows them).
## A foundation goes on area by area ([method _coat]).
##
## A pure function of what it is handed: no tree, no globals; built on a worker.

## Pixels a millimeter it decides at, and draws a show's marks at.
const PX := 2.0
const FOOT_PX := 4.0
## A paint laid whole, thinned, thinner, and as a glaze (its share over what lies under it, times an operation's own opacity).
const ALPHAS := [1.0, 0.6, 0.3, 0.15]
## How far off the picture a point must be to want paint, and how much nearer a paint must bring it (OKLab distance x 100; 2 is about
## the least a viewer tells apart). A foundation is gone over until each point is within [constant BASE_NEED] of its own paint.
const NEED := 10.0
const GAIN := 4.0
## A foundation is held to 3 so it is whole: at 5, 85% of its paint counted as done and the bare surface showed through; at 2 it took 13 minutes.
const BASE_NEED := 3.0
## ...and what it leaves under this after its last look, evened by the print beside it.
const BASE_FINISH := 1.5
## ...the prints it is evened by are found in cells this wide (millimeters).
const EVEN_CELL := 10.0
## A footprint may cover a point it makes this much further off the picture, no more - and must lie this share where it may.
const WORSE := 1.5
const FIT := 0.96
## Looks an operation takes at what is left; a foundation's.
const ROUNDS := 3
const BASE_ROUNDS := 8
## A fitted mark ([method _fit_op]) is laid only where it puts at least this much right (OKLab x 100, summed over what it lays, per square
## millimeter) and this much on average where it lays; a point it makes worse counts this many times one it makes better; judged at this
## share of a full load's paint; at most this many marks an operation; the next sought this near the last (millimeters).
const MARK_GAIN := 12.0
const MARK_AVG := 3.0
const WORSE_WEIGHT := 3.0
const GAIN_DEPOSIT := 0.8
## ...each tried as thick as its paint goes and thinned to these shares of that (a thinned dark pot is the light tint a gradient asks for).
const THINNINGS := [1.0, 0.5, 0.25]
const FIT_MOST := 500
## ...and none sought past this many refused in a row.
const FIT_REFUSED_MOST := 40
const NEAR_MM := 15.0
## A stroke's way: along the run of what still wants its paint - across the slope of that want where it runs one way this clearly, else
## the long way of the patch where it is this much longer than wide - looked at this many times its width round it (at least a
## millimeter); turned no more than this a step (radians), drawn on while what lies ahead wants it this much.
const WAY_COHERENT := 0.3
const WAY_LONG := 0.15
const WAY_LOOK := 1.5
const TRACE_TURN := 0.9
const TRACE_GAIN := 1.5
## ...and runs on only while the picture under it stays this near the color where the stroke began (OKLab x 100), the picture softened
## over this far (millimeters).
const TRACE_SAME := 9.0
const SAME_SOFT := 1.2
## A line traced from the picture ([method _trace_lines]): where it stands nearer the paint than what is round it by this far
## (millimeters), this share at least and this much (OKLab x 100); none shorter than this (millimeters); kept to its turns within this
## (millimeters); its faintest drawn this thin, a share of its paint's.
const TRACE_ROUND := 1.2
const TRACE_NEAR := 0.3
const TRACE_CONTRAST := 6.0
## ...and followed on as faint as this share of those, while it runs on from where it was clear.
const TRACE_FAINT := 0.4
## ...and wherever the picture is this near the paint itself (OKLab x 100), whatever is round it.
const TRACE_SAME_PAINT := 12.0
## ...no wider than this each side of its middle (millimeters); deeper in is an area.
const TRACE_WIDEST := 4.0
## ...a line wider than the brush pressed down is filled with side-by-side passes, this share of its width apart.
const TRACE_SIDE_BY := 0.8
const TRACE_SHORTEST := 1.0
const TRACE_KEEP := 0.15
const TRACE_THIN := 0.45
## ...drawn this fast up to this long (millimeters a second, millimeters), a careful hand's pace (Skins.LINE_SPEED) from this long on, and
## the work looked back at every so many strokes.
const TRACE_SPEED := 18.0
const TRACE_FLICK := 6.0
const TRACE_CAREFUL := 30.0
const TRACE_LOOK_EVERY := 12
## ...and carried on into the next without lifting where it begins this near where the last ended (millimeters).
const TRACE_JOIN := 0.8
## A blend ([method _blend_op]): where the canvas changes this much more across a millimeter than the picture does (OKLab x 100); pulled
## this many times its width each way across the edge, at these presses; laying this share of what it carries (times the operation's
## strength), taking up this share of what lies under it at each point.
const BLEND_EDGE := 6.0
const BLEND_LONG := 2.0
const BLEND_PRESSES := [1.0, 0.4]
const BLEND_LAYS := [0.6, 0.3]
const BLEND_PICK := 0.25
## A mix on the palette ([method _mixes]): these shares of the other paint.
const MIX_SHARES := [0.25, 0.5, 0.75]
## A coat's areas ([method _coat]): this many dabs across, each looked at again until done - at most this many times - before the hand
## moves on, and beside each other with their middles this many areas apart or nearer.
const AREA_DABS := 3.0
const AREA_LOOKS := 24
const AREA_BESIDE := 1.75
## What a show is told of how each point was built up ([method render]'s `built`): what it holds after this many marks reach it, the last
## slot after the last (fewer lump every later mark into the last, its rise cut along that mark's edge).
const BUILT_SLOTS := 8
## The picture an operation paints toward: each point the color most of a window this share of its tool's width round it is nearest; a
## liner's is its own point (a hairline under half a liner's window would be no part of its picture).
const WINDOW := 1.0
const LINE_WINDOW := 0.5
## A stroke traced in steps of this share of its width, no longer than this (millimeters); a dab's places this share of its width apart.
const STEP := 0.45
const LONGEST := 45.0
const DAB_APART := 0.75
## ...a footprint laid only where it covers this share of its area that still wants its paint.
const NEW_LEAST := 0.12
## The least cell judged by its average (millimeters): a liner's own width had judged the picture's grain point by point.
const AREA_LEAST := 2.0
## A stroke of one point - a tap - is laid only where it stands this many times [constant NEED] off (a highlight, not grain).
const DOT_OFF := 2.0
## How far the picture's channels may be scaled to make its ground the foundation's paint.
const GAIN_RANGE := Vector2(0.5, 2.5)
## ...and its light taken out where it falls off, found this far round each point (millimeters) and held to these shares of the ground's
## middle - [method _ground_shade]
const SHADE_BLUR := 12.0
const SHADE_RANGE := Vector2(0.55, 1.25)
## An operation works this far round what its element covers (millimeters): the element says where, the picture what, and the traced
## shape is rough. And no nearer the surface's edge than this, but for a foundation.
const REGION_GROW := 8.0
const RIM_KEEP := 3.0

## A dab: how far its edge wanders and how finely (millimeters), how soft it is, its pores' grain, how much of the surface they leave
## (the least, and how far it varies), what one press of a full load lays - a thin film, two or three dabs to build - and what a tool
## all but dry still lays of that.
const RAGGED := 0.9
const RAGGED_GRAIN := 1.4
const EDGE_SOFT := 0.5
const PORE_GRAIN := 1.2
const PORES := Vector2(0.8, 0.3)
const FILM := 0.95
const DRY_LEAST := 0.55
## ...A sponge's dab lays what is on the side it presses, as hard as it presses: [constant FILM] of a fresh load pressed hard by the side
## just loaded (near solid, pores filled), the load's share of that to this power (a load runs out dab by dab, Skins.DRY_DABS), a light
## press this share of a hard one's, a side other than the one loaded this share of what it would lay.
const LOAD_POWER := 0.8
const PRESS_DEPOSIT := 0.45
const OTHER_SIDE := 0.5
## ...each press laying its own share of that, as little as this; and lighter toward its edge, where the foam was pressed least - this far
## in from it (millimeters), or for a broad print this share of its half-width, laying this share there (a fade over only the last 2 mm
## leaves a flat brow's print a sharp-cornered rectangle).
const FILM_LEAST := 0.55
const EDGE_FADE := 2.0
const EDGE_FADE_SHARE := 0.3
const EDGE_LEAST := 0.4
## ...and pressed hardest in its middle: from this share of the way to its farthest touch out, laying less and less, its farthest corners
## this share - a flat face's print is an oval, never a rectangle.
const CORNER_FROM := 0.5
const CORNER_LEAST := 0.15
## ...a dab pressed lightly lays this share of its width, and shows this long after the moment its press begins (seconds: the shader fades
## a point in from a little before its moment - skin_paint.gdshader's EDGE).
const DAB_PRESS_LEAST := 0.7
## ...a brush's dot as small as its tip: a round brush barely touching lays a dot this share of its width (a sponge's corner no smaller
## than the share above), its edge crisp, wandering this far and this soft (millimeters).
const TIP_LEAST := 0.15
const TIP_RAGGED := 0.12
const TIP_SOFT := 0.2
const DAB_MEETS := 0.18
## A pull: how soft its edge is (a liner's crisper), how narrow it is pressed lightly - its tip alone, a share of its width - and its
## bristles: streaks across it this fine, this long along it, showing this much at a full load, this much more as it runs dry, and no
## more than this.
const BRUSH_EDGE := 0.25
const LINE_EDGE := 0.12
## ...a brush's belly: the outer share of a pull's half width its paint thins out over, and a blending brush's (strokes laid flat to a
## crisp edge stand as smears and never build a gradient).
const BELLY := 0.5
const BLEND_BELLY := 0.85
const PRESS_NARROW := 0.12
const STREAK_ACROSS := 0.3
const STREAK_ALONG := 6.0
const STREAK := Vector3(0.12, 0.9, 0.8)
const LINE_STREAK := 0.15
## The least a liner draws as a line (millimeters).
const LINE_LEAST := 2.5
## The most marks an operation makes: a sponge's dabs, a brush's or liner's strokes.
const DABS_MOST := 2600
const PULLS_MOST := 140
## ...and the most taps (a stroke shorter than a line) an operation lays, those standing furthest off the picture.
const TAPS_MOST := 40
## A pull's time beside its length, for how many an act's time holds (seconds: down, up, on to the next).
const PULL_AROUND := 1.2
## A foundation's patch still bare is gone back to where the cell round it, 2 mm, stands this share of [constant BASE_NEED] off on
## average (aimed at every point it would chase what lies between a sponge's pores).
const BASE_AREA := 0.6
## A hand backs off to look at its work once every this many strokes, not after each.
const LOOK_EVERY := 6
## How many points the surface's colors are carried past its edge before the picture is shrunk.
const EDGE_PAD := 6
## What a tool's touch says of it: a point touched each this many millimeters (TablePaint.TOUCH_EVERY); and the side each dab is held by,
## as TablePaint.WAYS counts them.
const TOUCH_CELL := 1.0
## The noise a mark is cut from: this many samples a side, this many a cell of it.
const NOISE_SIDE := 256
const NOISE_FINE := 8
## ...a load of a sponge's paint, printed (square millimeters of full paint - [method _per_load])
const TOUCH_LOAD_AREA := 12000.0
## ...its touched points softened this far (millimeters), the touch cut at the middle of the soft.
const TOUCH_SOFT := 1.5
## ...where the softened touch is cut, wandering this much about its middle (a share of the soft's 0-1), and how far either side of the
## cut its edge feathers out.
const TOUCH_RAGGED := 0.5
const TOUCH_FEATHER := 0.35
## ...a side whose touch lands this share on what wants the paint is taken without asking the narrower ones.
const SIDE_GOOD := 0.6
## ...and a side is kept - an area's first dabs, its broadest; going back over, the one it is held by - where its touch lands this share on
## what wants the paint ([method _press_all]; the broadest, going back over, [constant SIDE_GOOD]).
const SIDE_KEEP := 0.3
## ...and going back over, never a miss: a dab there lands at least this share on what still wants the paint, aimed at the middle of what
## wants it in its cell ([method _wanting]), not its worst point.
const LOOK_LEAST := 0.5
const SIDE_WAYS := {"corner": 1, "end": 2, "face": 3, "tilt12": 4, "tilt25": 5, "tilt40": 6}
## A dab off its lattice point by up to this share of the spacing, and pressed no lighter than this.
const JITTER := 0.35
const PRESS_UNEVEN := 0.55
## The presses a mark is tried at, heaviest first, until one fits: a sponge's dab, a brush's pull, a liner's line (its tip bent over
## its belly at the heaviest - TablePaint.TIP_PUSH).
const DAB_PRESSES := [1.0, 0.6, 0.25, 0.0]
const PULL_PRESSES := [1.0, 0.7, 0.4, 0.0]
const LINE_PRESSES := [0.6, 0.3, 0.0]

var w := 0
var h := 0
var mm := Vector2.ZERO
# (the surface: one a point; and the surface [constant RIM_KEEP] in from its edge)
var face := PackedByteArray()
var _inner := PackedByteArray()
# The canvas as the show holds and shows it (next/painted_surface.md): what the skin's color canvas holds - its color times its coverage
# (sRGB, as a 2D viewport blends sprites over clear) and its coverage - the bare surface under it (linear), and what that shows: linear RGB
# and OKLab ([method _shown], prop.gdshader's skin mix). Paints mix in sRGB here because the show's canvas does.
var pre := PackedVector3Array()
var alp := PackedFloat32Array()
var bare_lin := Vector3.ZERO
var lin := PackedVector3Array()
var labs := PackedVector3Array()
# (the picture, linear and OKLab, balanced to its ground - what every operation but a foundation paints toward, point for point)
var raw_lin := PackedVector3Array()
var raw := PackedVector3Array()
# (the picture at its own resolution, and its pixels a millimeter - [method _trace_lines])
var hi: Image
var hi_px := 3.0
# (the colors an operation's marks may carry: its paint, then its mixes - [method _mixes])
var _fit_cols := PackedVector3Array()
# (the picture softened, for where a stroke stays one color - [method _trace])
var _raw_soft := PackedVector3Array()
# (the foundation's paint, OKLab: what only the foundation lays - [method _want])
var ground_lab := Vector3(INF, INF, INF)
# (a foundation's aim - its own paint everywhere - and the slope a brushed foundation's strokes follow)
var aim := PackedVector3Array()
var grad := PackedVector2Array()
# (an operation being fitted - [method _fit_op]: how much laying its paint would put each point right, and that summed a cell, with the
# cell's best point)
var _g := PackedFloat32Array()
var _cell_sum := PackedFloat32Array()
var _cell_best := PackedInt32Array()
var _cs := 1
var _cw := 0
var _chh := 0
var _fit_mask := PackedByteArray()
var _fit_pv := Vector3.ZERO
var _fit_a0 := 1.0
# (the smooth noise a mark's edge and pores are cut from, made once - [method _noise])
static var _NOISE_TAB := PackedFloat32Array()
static var _noise_lock := Mutex.new()


## A painting begun: picture [param ref] (RGBA, its alpha the surface, [param size_mm] millimeters across) to be painted on a surface
## [param bare] with [param creams] (Colors, the table's paints), its ground - the color most of it is nearest of them - balanced to
## [param ground], the foundation's paint. [param surface] (one a point at PX), if given, is the surface's own outline; without it the
## picture's clear edge stands a little inside the surface and the rim between gets no dab.
static func begin(ref: Image, size_mm: Vector2, bare: Color, creams: Array, ground: Color, surface := PackedByteArray()) -> PaintLayers:
	var pl := PaintLayers.new()
	pl._setup(ref, size_mm, bare, surface)
	pl._ground_to(ground, creams)
	pl.ground_lab = _shown_lab(ground)
	return pl


## The whole picture laid (a probe's, a gate's): on [param bare] with [param paints] (`[{name, color}]`) and [param tools] (`[{name, kind:
## "dab"|"stroke", width}]`, millimeters; any order) - a foundation of the paint most of it is nearest, then tool by tool, widest first,
## each paint it can lay in turn, those that put most right first; a tool is kept until it has done what it can. Returns
## `{layers: [{tool, paint, alpha, marks, base?}], canvas, passes: [{tool, canvas, off}], off, left}`.
static func plan(ref: Image, size_mm: Vector2, bare: Color, paints: Array, tools: Array) -> Dictionary:
	var creams: Array = paints.map(func(p: Dictionary) -> Color: return p["color"])
	var probe := PaintLayers.new()
	probe._setup(ref, size_mm, bare)
	var gi := probe._vote(creams)
	var layers: Array = []
	var passes: Array = []
	if gi < 0 or tools.is_empty():
		return {"layers": layers, "canvas": probe.picture(), "passes": passes, "off": 0.0, "left": 1.0}
	var pl := begin(ref, size_mm, bare, creams, creams[gi])
	var order := tools.duplicate()
	order.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["width"]) > float(y["width"]))
	var frame := Rect2(Vector2.ZERO, size_mm)
	var widest: Dictionary = order[0]
	var res := pl.lay({"id": "foundation", "manner": "stipple", "paint": creams[gi], "r": float(widest["width"]) * 0.5, "base": true,
		"rect": frame, "frame": size_mm, "seed": 1})
	layers.append({"tool": String(widest["name"]), "paint": String((paints[gi] as Dictionary)["name"]), "alpha": 1.0, "marks": int(res["marks"]),
		"base": true})
	passes.append({"tool": "foundation", "canvas": pl.picture(), "off": pl.off()})
	var seed := 2
	for tool in order:
		var t: Dictionary = tool
		var manner := "stipple" if String(t["kind"]) == "dab" else ("line" if float(t["width"]) <= 1.5 else "sweep")
		var r := float(t["width"]) * 0.5
		var ranked: Array = []
		for pi in paints.size():
			var gain := pl.gain_of((paints[pi] as Dictionary)["color"], 1.0, r, PackedByteArray())
			if gain > 0.0:
				ranked.append([gain, pi])
		ranked.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
		for rk in ranked:
			var pi := int(rk[1])
			seed += 1
			var lr := pl.lay({"id": "%s %s" % [t["name"], (paints[pi] as Dictionary)["name"]], "manner": manner, "paint": (paints[pi] as Dictionary)["color"],
				"r": r, "rect": frame, "frame": size_mm, "seed": seed})
			if int(lr["marks"]) > 0:
				layers.append({"tool": String(t["name"]), "paint": String((paints[pi] as Dictionary)["name"]), "alpha": 1.0, "marks": int(lr["marks"])})
		passes.append({"tool": String(t["name"]), "canvas": pl.picture(), "off": pl.off()})
	return {"layers": layers, "canvas": pl.picture(), "passes": passes, "off": pl.off(), "left": pl.left()}


## OKLab of a linear RGB color (x 100), for how far apart two colors look.
static func lab(r: float, g: float, b: float) -> Vector3:
	var l := 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
	var m := 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
	var s := 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
	l = pow(maxf(l, 0.0), 1.0 / 3.0)
	m = pow(maxf(m, 0.0), 1.0 / 3.0)
	s = pow(maxf(s, 0.0), 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s) * 100.0


# --- an operation ------------------------------------------------------------------------------------------------------------

## One operation laid: `{id, manner: "stipple" (a sponge's dabs) | "dab" (a brush's dots) | "sweep" (a brush's pulls) | "line" (a fine
## brush's), paint: Color, opacity (its most), r (millimeters, half its tool's mark), region (PackedByteArray at PX over the surface; empty,
## all of it), base (a foundation: its own paint, whole, everywhere it may go), rect (the element's picture, millimeters), frame (the
## surface's size, for the way a brush is pulled), seed, budget (seconds its act has: no more is begun past it), touch (a Callable: what the
## tool, dabbed at a point held one of its sides, touches - `touch.call(xy, side, press) -> PackedVector2Array`, millimeters a millimeter
## apart), sides (the sides it may dab with, the broadest first: a sponge's face, its corner)}`. Its marks are made by the program a show
## plays, each composited onto the canvas as it is laid, a look at what is left after each pass. Returns `{program, coverage: Image (L8,
## FOOT_PX over rect: what it laid), when: Image (RGBF: each point's moment, 0-1 of the program; Skins.NEVER where it laid nothing),
## built, built_when (how each point was built up, four marks an image - [method render]), marks (how many), laid (the marks themselves:
## `{m, th, salt}`, in the order laid - each drawn again as [method raster] draws it), kind (how [method raster] draws them), traced (a
## line's lines found in the picture: `{lines, drawn, mm, left_mm, left_seconds}` - [method _trace_lines]; else empty)}`.
func lay(op: Dictionary) -> Dictionary:
	var manner := String(op.get("manner", "stipple"))
	var r := maxf(float(op.get("r", 1.0)), 0.3)
	var pot: Color = op["paint"]
	# (the paint as the show's canvas holds it: sRGB)
	var pv := Vector3(pot.r, pot.g, pot.b)
	var most := clampf(float(op.get("opacity", 1.0)), 0.1, 1.0)
	var thins := PackedFloat32Array()
	for a in ALPHAS:
		var t := snappedf(float(a) * most, 0.01)
		if t >= 0.08 and not thins.has(t):
			thins.append(t)
	var rect: Rect2 = op.get("rect", Rect2(Vector2.ZERO, mm))
	var base := bool(op.get("base", false))
	var mask := _mask_of(op.get("region", PackedByteArray()), rect, r, base, float(op.get("grow", REGION_GROW)))
	var p: Variant = Skins._Prog.new()
	p.seed = int(op.get("seed", 0))
	var kind := "dab" if manner in ["stipple", "dab"] else ("line" if manner == "line" else ("blend" if manner == "blend" else "pull"))
	var marks: Array = []
	if base:
		# A foundation: its own paint, whole, everywhere it may go, area by area ([method _coat]).
		aim = PackedVector3Array()
		aim.resize(w * h)
		aim.fill(_shown_lab(pot))
		grad = PackedVector2Array()
		grad.resize(w * h)
		if kind == "dab":
			_coat(p, op, mask, pv, thins, r, marks, base)
		else:
			for _round in BASE_ROUNDS:
				var want := _want(mask, pv, thins, r, BASE_NEED, base)
				if _pulls(p, op, kind, want, mask, pv, thins, r, marks) == 0:
					break
	else:
		# Every other: toward the picture itself, by what each mark really lays ([method _fit_op]). A line's lines are first traced from the
		# picture at its own resolution (hairlines no fitted stroke finds), and only where it shows any - fitted first, a liner hatches a haze
		# in bars. A blend moves the paint already on, with a clean brush.
		if kind == "blend":
			_blend_op(p, op, mask, r, marks, most)
		elif kind != "line" or _trace_lines(p, op, mask, pv, r, marks, most) == 0:
			_fit_op(p, op, kind, mask, pv, r, marks, most)
	# ...and what no side of it can reach, a foundation paints all the same: each point still short of its paint is laid with the dab
	# pressed nearest it, at that dab's moment (beside a nostril neither the face nor the corner of a sponge touches).
	if base and kind == "dab" and not marks.is_empty():
		# ...and its last thin places, nearly whole, evened by the print beside them as it was pressed ([constant BASE_FINISH]).
		var left := _want(mask, pv, thins, r, BASE_FINISH, true)
		var centers := PackedVector2Array()
		var by_cell := {}
		for mk in marks:
			var c0: Vector2 = ((mk as Dictionary)["m"]["pts"] as PackedVector2Array)[0]
			var g0 := Vector2i(floori(c0.x / EVEN_CELL), floori(c0.y / EVEN_CELL))
			if not by_cell.has(g0):
				by_cell[g0] = PackedInt32Array()
			var cell: PackedInt32Array = by_cell[g0]
			cell.append(centers.size())
			by_cell[g0] = cell
			centers.append(c0)
		var given := {}
		for k in w * h:
			if left[k] < 0:
				continue
			var q := (Vector2(float(k % w), float(k / w)) + Vector2(0.5, 0.5)) / PX
			var best := 0
			var bd := INF
			# ...the nearest print among those in the cells round it, widening until one is found (each point against every print is too slow).
			var gq := Vector2i(floori(q.x / EVEN_CELL), floori(q.y / EVEN_CELL))
			for reach_c in [1, 2, 4, 8]:
				for dy in range(-reach_c, reach_c + 1):
					for dx in range(-reach_c, reach_c + 1):
						for i in by_cell.get(gq + Vector2i(dx, dy), PackedInt32Array()) as PackedInt32Array:
							var d := centers[i].distance_squared_to(q)
							if d < bd:
								bd = d
								best = i
				if bd < INF:
					break
			var got: PackedVector2Array = given.get(best, PackedVector2Array())
			got.append(q)
			given[best] = got
		for i in given:
			var mk: Dictionary = marks[int(i)]
			var extra := {"pts": PackedVector2Array([centers[int(i)]]), "t": mk["m"]["t"], "r": mk["m"]["r"], "load": mk["m"].get("load", PackedFloat32Array()),
				"touch": given[i], "even": true}
			_lay(extra, "dab", float(mk["th"]), pv, int(mk["salt"]))
			marks.append({"m": extra, "th": mk["th"], "salt": mk["salt"]})
	var prog: Dictionary = p.done()
	prog["manner"] = manner
	# (...and the side each dab was pressed with, by its place - TablePaint._held_keys poses it so)
	prog["way_at"] = op.get("_way_at", {})
	# (...a painter only trying it on the canvas needs no maps for a show - the painter's tools)
	if bool(op.get("no_maps", false)):
		return {"program": prog, "marks": marks.size(), "laid": marks, "kind": kind, "traced": op.get("_traced", {})}
	var drawn := render(marks, kind, rect, FOOT_PX, maxf(float(prog["natural"]), 1e-3), pv)
	return {"program": prog, "coverage": drawn["coverage"], "when": drawn["when"], "built": drawn["built"], "built_when": drawn["built_when"],
		"tint": drawn.get("tint"), "marks": marks.size(), "laid": marks, "kind": kind, "traced": op.get("_traced", {})}


## A foundation laid by another hand (the table's own stipple, its corner's touches - TablePaint._from_picture): [param paint], whole,
## over every point of the surface.
func lay_whole(paint: Color) -> void:
	var ps := Vector3(paint.r, paint.g, paint.b)
	var q := _shown(ps, 1.0)
	var l := lab(q.x, q.y, q.z)
	for k in w * h:
		if face[k] != 0:
			pre[k] = ps
			alp[k] = 1.0
			lin[k] = q
			labs[k] = l


## How much laying [param paint] (at most [param most]) with a tool [param r] across would put right over [param region] (empty: all),
## summed - for which paint a tool lays first.
func gain_of(paint: Color, most: float, _r: float, region: PackedByteArray) -> float:
	var pv := Vector3(paint.r, paint.g, paint.b)
	var sum := 0.0
	for k in range(0, w * h, 2):
		if face[k] == 0 or (region.size() == w * h and region[k] == 0):
			continue
		var now := labs[k].distance_to(raw[k])
		var best := now
		for a in ALPHAS:
			best = minf(best, _after(k, pv, float(a) * most).distance_to(raw[k]))
		if now - best >= GAIN:
			sum += now - best
	return sum


## Where an operation may go: the surface, inside [param region] grown [constant REGION_GROW] (if given), and inside [param rect] by its
## tool's reach [param r] - a mark is never cut off at the edge of the picture a show draws it in.
func _mask_of(region: PackedByteArray, rect: Rect2, r: float, base := false, grow := REGION_GROW) -> PackedByteArray:
	# ...and, but for a foundation, [constant RIM_KEEP] in from the surface's edge, where the picture shows its own light and takes no paint.
	var out := face.duplicate() if base else _inner.duplicate()
	if region.size() == w * h:
		# (...grown [param grow] millimeters: shrunk that far and grown back by the engine, anything it touched kept)
		var bytes := PackedByteArray()
		bytes.resize(w * h)
		for k in w * h:
			bytes[k] = 255 if region[k] != 0 else 0
		var img := Image.create_from_data(w, h, false, Image.FORMAT_L8, bytes)
		var by := maxf(grow * PX, 1.0)
		img.resize(maxi(int(round(float(w) / by)), 1), maxi(int(round(float(h) / by)), 1), Image.INTERPOLATE_BILINEAR)
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		var grown := img.get_data()
		for k in w * h:
			out[k] = out[k] if grown[k] > 2 or region[k] != 0 else 0
	# (...only on a side of the picture with surface beyond it: at the surface's own frame nothing lies past)
	var reach := r + RAGGED + EDGE_SOFT
	var inset := Rect2(rect.position, rect.size)
	if rect.position.x > 0.01:
		inset = inset.grow_individual(-reach, 0, 0, 0)
	if rect.position.y > 0.01:
		inset = inset.grow_individual(0, -reach, 0, 0)
	if rect.end.x < mm.x - 0.01:
		inset = inset.grow_individual(0, 0, -reach, 0)
	if rect.end.y < mm.y - 0.01:
		inset = inset.grow_individual(0, 0, 0, -reach)
	for k in w * h:
		if out[k] == 0:
			continue
		var q := (Vector2(float(k % w), float(k / w)) + Vector2(0.5, 0.5)) / PX
		if not inset.has_point(q):
			out[k] = 0
	return out


## What still wants the paint [param pv], by area (Hertzmann's area error - a point worked only where the cell round it, as wide as the
## tool's footprint, is off on average too): each point of [param mask] off its aim by [param need] or more that a thinness of
## [param thins] brings at least [constant GAIN] nearer (a foundation: any nearer), given the index of the one that brings it nearest; -1
## elsewhere.
func _want(mask: PackedByteArray, pv: Vector3, thins: PackedFloat32Array, r: float, need: float, base: bool, within := Rect2i()) -> PackedInt32Array:
	var want := PackedInt32Array()
	want.resize(w * h)
	want.fill(-1)
	var cell := int(AREA_LEAST * PX) if base else maxi(int(r * PX), int(AREA_LEAST * PX))
	var cw := (w + cell - 1) / cell
	var ch := (h + cell - 1) / cell
	# (...only inside [param within] (pixels), when it is given - out to whole cells, so each is judged as it would be over all)
	var x0 := 0
	var y0 := 0
	var x1 := w
	var y1 := h
	if within.has_area():
		x0 = clampi((within.position.x / cell) * cell, 0, w)
		y0 = clampi((within.position.y / cell) * cell, 0, h)
		x1 = clampi(((within.end.x + cell - 1) / cell) * cell, 0, w)
		y1 = clampi(((within.end.y + cell - 1) / cell) * cell, 0, h)
	var sums := PackedFloat32Array()
	sums.resize(cw * ch)
	var counts := PackedInt32Array()
	counts.resize(cw * ch)
	var offs := PackedFloat32Array()
	offs.resize(w * h)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var k := y * w + x
			if mask[k] == 0:
				continue
			offs[k] = labs[k].distance_to(aim[k])
			var ci := (y / cell) * cw + x / cell
			sums[ci] += offs[k]
			counts[ci] += 1
	# ...and, but for a foundation, never where the picture is the foundation's own paint: that is the foundation's to finish.
	var own_ground := not base and ground_lab.x < INF
	for y in range(y0, y1):
		for x in range(x0, x1):
			var k := y * w + x
			if mask[k] == 0 or offs[k] < need:
				continue
			if own_ground and aim[k].distance_to(ground_lab) < need:
				continue
			var ci := (y / cell) * cw + x / cell
			if sums[ci] / float(maxi(counts[ci], 1)) < need * (BASE_AREA if base else 1.0):
				continue
			# ...a foundation, its own paint whole: always its full thickness, weighed point by point.
			if base:
				want[k] = 0
				continue
			var best := -1
			var best_off := offs[k] - GAIN
			for ti in thins.size():
				var o := _off_with(k, pv, thins[ti])
				if o < best_off:
					best_off = o
					best = ti
			want[k] = best
	return want


## How far point [param k] would stand off its aim with paint [param pv] (sRGB) laid over it at [param a].
func _off_with(k: int, pv: Vector3, a: float) -> float:
	return _after(k, pv, a).distance_to(aim[k])


## What point [param k] would show (OKLab) with paint [param pv] (sRGB) laid over it at [param a] - as the show's canvas blends it and the
## mask's shader shows it ([method _shown]).
func _after(k: int, pv: Vector3, a: float) -> Vector3:
	var p2 := pv * a + pre[k] * (1.0 - a)
	var a2 := a + alp[k] * (1.0 - a)
	var d := _shown(p2, a2)
	return lab(d.x, d.y, d.z)


## What a point of the canvas shows (linear RGB): its paint [param p] (sRGB, times its coverage) over the bare surface by its coverage
## [param a] - prop.gdshader's skin mix, the color taken out of its coverage and decoded (`pow 2.2`).
func _shown(p: Vector3, a: float) -> Vector3:
	if a <= 1e-5:
		return bare_lin
	var c := p / a
	return bare_lin * (1.0 - a) + Vector3(_dec(c.x), _dec(c.y), _dec(c.z)) * a


## sRGB [param v] decoded as prop.gdshader decodes the skin's canvas.
static func _dec(v: float) -> float:
	return pow(clampf(v, 0.0, 1.0), 2.2)


## What paint [param c] laid whole shows, OKLab.
static func _shown_lab(c: Color) -> Vector3:
	return lab(_dec(c.r), _dec(c.g), _dec(c.b))


## Whether a footprint [param r] (millimeters) at [param c] (millimeters) may go - `Vector3(share where it may, share that still wants it,
## the thinness most of what wants it wants)`.
func _fit(c: Vector2, r: float, want: PackedInt32Array, mask: PackedByteArray, pv: Vector3, thins: PackedFloat32Array, base: bool) -> Vector3:
	var cp := c * PX
	var rp := r * PX
	var n := 0
	var ok := 0
	var wanted := 0
	var votes := PackedInt32Array()
	votes.resize(thins.size())
	for y in range(maxi(int(cp.y - rp), 0), mini(int(cp.y + rp) + 1, h)):
		for x in range(maxi(int(cp.x - rp), 0), mini(int(cp.x + rp) + 1, w)):
			if (Vector2(float(x), float(y)) + Vector2(0.5, 0.5)).distance_squared_to(cp) > rp * rp:
				continue
			var k := y * w + x
			n += 1
			# ...off the surface, paint lands nowhere: no spill.
			if face[k] == 0:
				ok += 1
				continue
			if mask[k] == 0:
				continue
			if base or want[k] >= 0 or _off_with(k, pv, thins[0]) <= labs[k].distance_to(aim[k]) + WORSE:
				ok += 1
			if want[k] >= 0:
				wanted += 1
				votes[want[k]] += 1
	if n == 0:
		return Vector3.ZERO
	var ti := 0
	for i in thins.size():
		if votes[i] > votes[ti]:
			ti = i
	return Vector3(float(ok) / float(n), float(wanted) / float(n), float(ti))


## A sponge's dabs (or a brush's dots), a coat laid area by area: what wants the paint is shared out among areas [constant AREA_DABS]
## dabs across, begun where its broadest side lands most of itself nearest the middle, and each area is worked whole before the hand
## moves to the one beside it nearest where it is - its dabs a dab's width apart, each pressed where it fits and still has work to do,
## the nearest next; then looked at again and its patches still short gone back over ([constant AREA_LOOKS]); last, what the areas left,
## patch by patch from where the hand is. Each mark is made by the program ([method Skins._Prog.dab]: its load, its trips back to the
## pot) and laid on the canvas as it is pressed.
func _coat(p: Variant, op: Dictionary, mask: PackedByteArray, pv: Vector3, thins: PackedFloat32Array, r: float, marks: Array, base: bool) -> void:
	var need := BASE_NEED if base else NEED
	var want := _want(mask, pv, thins, r, need, base)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var mid := Vector2.ZERO
	var n := 0
	for k in w * h:
		if want[k] >= 0:
			var q := (Vector2(float(k % w), float(k / w)) + Vector2(0.5, 0.5)) / PX
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
			mid += q
			n += 1
	if n == 0:
		return
	mid /= float(n)
	var st := {"p": p, "op": op, "pv": pv, "thins": thins, "r": r, "marks": marks, "base": base, "mask": mask, "at": mid, "stop": false,
		"salt": int(op.get("seed", 0)), "sponge": String(op.get("manner", "stipple")) == "stipple",
		"presses": maxi(roundi(Skins.LOAD_AREA_DABS / (PI * r * r)), 4), "touch": op.get("touch", Callable()), "sides": op.get("sides", []),
		"way_at": op.get("_way_at", {}),
		# ...its time held to, but a foundation's whole whatever it takes.
		"budget": float(op.get("budget", INF)) if not base else INF}
	st["by_touch"] = (st["touch"] as Callable).is_valid() and not (st["sides"] as Array).is_empty()
	var apart := maxf(r * 2.0 * DAB_APART, 0.6)
	# ...any side of it, as the work needs: a first coat's places as far apart as its broadest side's touch is wide.
	var broad := ""
	if bool(st["by_touch"]):
		var widest := 0
		for sd in st["sides"]:
			var got: PackedVector2Array = (st["touch"] as Callable).call(mid, String(sd), 1.0)
			if got.size() > widest:
				widest = got.size()
				broad = String(sd)
		var r_side := sqrt(maxf(float(widest), 1.0) * TOUCH_CELL * TOUCH_CELL / PI)
		apart = maxf(apart, r_side * 2.0 * DAB_APART)
	st["apart"] = apart
	var size := apart * AREA_DABS
	var ar := _areas_of(lo, hi, size, int(st["salt"]) + 17)
	var seeds: Array = ar["seeds"]
	# ...each point that wants the paint, its area's - an area works its own points, each cell's that most wants it among them (picked
	# among all a cell's, then left to the area beside it) - and the areas with work in them.
	var labels := PackedInt32Array()
	labels.resize(w * h)
	labels.fill(-1)
	var live := PackedByteArray()
	live.resize(seeds.size())
	for k in w * h:
		if want[k] >= 0:
			labels[k] = _area_at(ar, (Vector2(float(k % w), float(k / w)) + Vector2(0.5, 0.5)) / PX)
			live[labels[k]] = 1
	st["labels"] = labels
	var by_area: Array = []
	for i in seeds.size():
		by_area.append([])
	for c in _lattice(lo, hi, apart, int(st["salt"])):
		(by_area[_area_at(ar, c)] as Array).append(c)
	# ...begun where the broadest side lands most of itself (a cheek's or a brow's breadth, never a nose's), nearest the middle.
	var start := -1
	var best := -INF
	for i in seeds.size():
		if live[i] == 0:
			continue
		var score := -(seeds[i] as Vector2).distance_to(mid) / size * 0.1
		if not broad.is_empty():
			score += float(((st["touch"] as Callable).call(seeds[i], broad, 1.0) as PackedVector2Array).size()) / maxf(float(PI * apart * apart), 1.0)
		if score > best:
			best = score
			start = i
	var done0 := PackedByteArray()
	done0.resize(seeds.size())
	var walk := {"done": done0, "front": {}}
	var cur := start
	while cur >= 0 and not bool(st["stop"]):
		_done_area(ar, walk, live, cur)
		_area(st, cur, ar, by_area[cur], need)
		cur = _next_area(ar, live, walk, st["at"])
	# ...and what the areas left, patch by patch from where the hand is.
	for _round in (BASE_ROUNDS if base else ROUNDS) - 1:
		if bool(st["stop"]):
			break
		var left := _want(mask, pv, thins, r, need, base)
		var cands := _wanting(left, Rect2i(0, 0, w, h), apart)
		if cands.is_empty() or _press_all(st, _walked(cands, ar, st["at"]), left, true) == 0:
			break
	op["_way_at"] = st["way_at"]


## One area of a coat, worked whole ([method _coat]): area [param i] of [param ar] ([method _areas_of]) - its places [param places], the
## nearest next from where the hand is, then looked at again and its patches still short gone back over until none is.
func _area(st: Dictionary, i: int, ar: Dictionary, places: Array, need: float) -> void:
	var c0: Vector2 = (ar["seeds"] as Array)[i]
	var size := float(ar["size"])
	var rect := Rect2i(Vector2i(floori((c0.x - size) * PX), floori((c0.y - size) * PX)), Vector2i(ceili(size * 2.0 * PX), ceili(size * 2.0 * PX)))
	rect = rect.intersection(Rect2i(0, 0, w, h))
	if not rect.has_area():
		return
	var mask: PackedByteArray = st["mask"]
	var wa := _want(mask, st["pv"], st["thins"], float(st["r"]), need, bool(st["base"]), rect)
	_press_all(st, _nn(places, st["at"]), wa, false)
	for _look in AREA_LOOKS:
		if bool(st["stop"]):
			return
		wa = _want(mask, st["pv"], st["thins"], float(st["r"]), need, bool(st["base"]), rect)
		var cands := _wanting(wa, rect, float(st["apart"]), st["labels"], i)
		if cands.is_empty() or _press_all(st, _nn(cands, st["at"]), wa, true) == 0:
			return


## The dabs at [param places], in turn, as [method _coat]'s [param st] lays them against what still wants the paint [param want]: each with
## the side of the tool that lands most on what wants it, or pressed as hard as fits - [param again], going back over, kept a hand's spacing
## from the dabs it has pressed. How many it pressed.
func _press_all(st: Dictionary, places: Array, want: PackedInt32Array, again: bool) -> int:
	var p: Variant = st["p"]
	var marks: Array = st["marks"]
	var mask: PackedByteArray = st["mask"]
	var pv: Vector3 = st["pv"]
	var thins: PackedFloat32Array = st["thins"]
	var r := float(st["r"])
	var base := bool(st["base"])
	var apart := float(st["apart"])
	var salt := int(st["salt"])
	var by_touch := bool(st["by_touch"])
	var sides: Array = st["sides"]
	var way_at: Dictionary = st["way_at"]
	var laid := 0
	var pressed_at := PackedVector2Array()
	var pressed_r := PackedFloat32Array()
	# ...one side, then the other, never turned in the hand dab by dab: an area's first dabs its broadest side where it lands well, going
	# back over the side it is held by where that lands well - its broadest on a gap as wide as it; what only another side lands on, after.
	var first := ""
	if by_touch:
		first = String(st.get("side", "")) if again else String(sides[0])
		if not sides.has(first):
			first = String(sides.back())
	var queue: Array = places
	var later: Array = []
	for sweep in 2:
		for c in queue:
			if marks.size() >= DABS_MOST or float(p.t) > float(st["budget"]):
				st["stop"] = true
				break
			if again:
				# ...a hand's spacing apart, as the first pass's - the spacing of the dab already there, broad or a corner's (aimed at every thin point
				# and kept most of a dab apart, the goings-back lay too close and go over what is done).
				var near := false
				for i in pressed_at.size():
					var keep := maxf(apart, pressed_r[i] * 2.0 * DAB_APART)
					if pressed_at[i].distance_squared_to(c) < keep * keep:
						near = true
						break
				if near:
					continue
			var press := -1.0
			var f := Vector3.ZERO
			var side := ""
			var touched := PackedVector2Array()
			if by_touch:
				# (...the side held, where it lands well; later, whichever lands most - a broader where two land alike)
				var got := _side_for(st, c, want, again, [first], maxf(SIDE_GOOD if again and first == String(sides[0]) else SIDE_KEEP, LOOK_LEAST if again else 0.0), true) \
					if sweep == 0 else _nearest_side(st, c, want, again, sides)
				if got.is_empty():
					if sweep == 0:
						later.append(c)
					continue
				side = got["side"]
				touched = got["touched"]
				f = got["f"]
				st["side"] = side
				press = 1.0
			else:
				# ...pressed as hard as fits: the heaviest press whose dab lies where it may (a lighter one lays a smaller dab).
				for pr in DAB_PRESSES:
					f = _fit(c, r * lerpf(DAB_PRESS_LEAST, 1.0, float(pr)), want, mask, pv, thins, base)
					if f.x >= FIT:
						press = float(pr)
						break
				if press < 0.0 or (f.y < NEW_LEAST and not again):
					continue
			pressed_at.append(c)
			pressed_r.append(sqrt(maxf(float(touched.size()), 1.0) * TOUCH_CELL * TOUCH_CELL / PI) if by_touch else r)
			# (...each pressed a little harder or softer than the last, so each lays its own size)
			press *= lerpf(PRESS_UNEVEN, 1.0, _hash(c + Vector2(13.3, salt)))
			if bool(st["sponge"]):
				# ...a load is spent by what it lays: as many dabs a load as its area holds this dab's touch, counted in a corner's dabs.
				var per_load := int(st["presses"])
				if by_touch:
					per_load = _per_load(touched.size(), thins[int(f.z)])
				p.dab(c, r, Skins.DAB, Skins.DAB_LIFT, per_load, false, Skins.DRY_DABS, press)
			else:
				p.dab(c, r, Vector3(Skins.DAB.x, Skins.DAB.y * 2.0, Skins.DAB.z), Skins.HOVER, Skins.RELOAD_DOTS, false, 1.0, press)
			var m: Dictionary = (p.strokes as Array).back()
			# (...and how much of it landed where paint was still wanted - a miss is what did not)
			m["useful"] = f.y
			if by_touch:
				m["touch"] = touched
				way_at[c] = SIDE_WAYS.get(side, 0)
				# ...which side carries the paint: the one pressed into the pot - the next dab's, after a trip back to it (its load come back up) - and
				# another only what has come round onto it.
				var ld := float((m["load"] as PackedFloat32Array)[0]) if (m.get("load", PackedFloat32Array()) as PackedFloat32Array).size() > 0 else 1.0
				# (a face tipped onto its corner carries the face's paint)
				var carrier := "face" if side.begins_with("tilt") else side
				if String(st.get("loaded", "")).is_empty() or ld > float(st.get("last_load", 0.0)) + 0.02:
					st["loaded"] = carrier
				st["last_load"] = ld
				m["share"] = 1.0 if carrier == String(st["loaded"]) else OTHER_SIDE
			var th := thins[int(f.z)]
			_lay(m, "dab", th, pv, marks.size())
			marks.append({"m": m, "th": th, "salt": marks.size()})
			st["at"] = c
			laid += 1
		if bool(st["stop"]) or later.is_empty():
			break
		queue = _nn(later, st["at"])
	return laid


## The side nearest the one it is held by that lands well, for a dab at [param c] ([method _press_all]'s second sweep): [param sides] (the
## broadest first, each tipped further onto its corner than the one before) tried nearest the side held first, the first landing
## [constant SIDE_KEEP] on what wants the paint taken - else, of them all, whichever lands most ([method _side_for]).
func _nearest_side(st: Dictionary, c: Vector2, want: PackedInt32Array, again: bool, sides: Array) -> Dictionary:
	var at := maxi(sides.find(String(st.get("side", ""))), 0)
	var order: Array = sides.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool:
		var da := absi(sides.find(a) - at)
		var db := absi(sides.find(b) - at)
		return da < db if da != db else sides.find(a) < sides.find(b))
	var least := maxf(SIDE_KEEP, LOOK_LEAST if again else 0.0)
	for sd in order:
		var got := _side_for(st, c, want, again, [sd], least, true)
		if not got.is_empty():
			return got
	# ...going back over, never a dab that lands mostly where nothing is wanted: what no side lands on well is left for a later look.
	return {} if again else _side_for(st, c, want, again, sides, SIDE_KEEP, false)


## Which side of the tool a dab at [param c] is pressed with ([method _press_all]), of [param sides]: what each really touches there
## ([method _coat]'s `touch`, as the show poses it), where it fits and lands on what still wants the paint [param want] - a first coat's,
## on a share of it worth a dab ([constant NEW_LEAST]) - the one that lands most, a broader where two land alike; [param held], the first
## that lands on [param least] of it or more, else none. `{side, touched, f}` ([method _fit_points]'s), or empty.
func _side_for(st: Dictionary, c: Vector2, want: PackedInt32Array, again: bool, sides: Array, least: float, held: bool) -> Dictionary:
	var touch: Callable = st["touch"]
	var best := -1.0
	var out := {}
	for sd in sides:
		var got: PackedVector2Array = touch.call(c, String(sd), 1.0)
		if got.size() < 3:
			continue
		var fs := _fit_points(got, want, st["mask"], st["pv"], st["thins"], bool(st["base"]))
		if fs.x < FIT or (fs.y < NEW_LEAST and not again):
			continue
		if held:
			if fs.y >= least:
				return {"side": String(sd), "touched": got, "f": fs}
			continue
		var score := fs.y + float(got.size()) * 1e-5
		if score > best:
			best = score
			out = {"side": String(sd), "touched": got, "f": fs}
		# (...a broad side landing mostly on what wants it is taken as it is: the narrower is not asked)
		if fs.y >= SIDE_GOOD:
			break
	return out


## One place a cell [param apart] wide of what wants the paint [param want] inside [param rect] (pixels): the middle of what wants it there -
## of area [param area]'s points alone, where [param labels] says whose each is.
func _wanting(want: PackedInt32Array, rect: Rect2i, apart: float, labels := PackedInt32Array(), area := -1) -> Array:
	var cellp := maxi(int(apart * PX), 1)
	var sums := {}
	var mine := area >= 0 and labels.size() == w * h
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var k := y * w + x
			if want[k] < 0 or (mine and labels[k] != area):
				continue
			var ck := Vector2i(x / cellp, y / cellp)
			var o := labs[k].distance_to(aim[k])
			var acc: Vector3 = sums.get(ck, Vector3.ZERO)
			sums[ck] = acc + Vector3(float(x) * o, float(y) * o, o)
	# (...the middle of what wants it there, weighed by how much each point wants it)
	var out: Array = []
	for ck in sums:
		var acc: Vector3 = sums[ck]
		if acc.z > 0.0:
			out.append((Vector2(acc.x / acc.z, acc.y / acc.z) + Vector2(0.5, 0.5)) / PX)
	return out


## [param pts] in the order a hand takes them from [param from]: the nearest next, each time.
static func _nn(pts: Array, from: Vector2) -> Array:
	var left: Array = pts.duplicate()
	var out: Array = []
	var at := from
	while not left.is_empty():
		var bi := 0
		var bd := INF
		for i in left.size():
			var d := at.distance_squared_to(left[i] as Vector2)
			if d < bd:
				bd = d
				bi = i
		at = left[bi]
		out.append(at)
		left.remove_at(bi)
	return out


## A coat's areas ([method _coat]): their middles [param size] apart over [param lo]..[param hi] (millimeters, as a hand places them -
## [method _lattice]), found by where they are (`grid`): `{seeds, size, grid, beside}`.
func _areas_of(lo: Vector2, hi: Vector2, size: float, salt: int) -> Dictionary:
	var seeds := _lattice(lo, hi, size, salt)
	var grid := {}
	for i in seeds.size():
		var g := Vector2i(floori((seeds[i] as Vector2).x / size), floori((seeds[i] as Vector2).y / size))
		if not grid.has(g):
			grid[g] = PackedInt32Array()
		var cell: PackedInt32Array = grid[g]
		cell.append(i)
		grid[g] = cell
	return {"seeds": seeds, "size": size, "grid": grid, "beside": {}}


## The area of [param ar] whose middle is nearest [param q].
static func _area_at(ar: Dictionary, q: Vector2) -> int:
	var seeds: Array = ar["seeds"]
	var size := float(ar["size"])
	var grid: Dictionary = ar["grid"]
	var g := Vector2i(floori(q.x / size), floori(q.y / size))
	var bi := -1
	var bd := INF
	for reach in [1, 2]:
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				for i in grid.get(g + Vector2i(dx, dy), PackedInt32Array()) as PackedInt32Array:
					var d := q.distance_squared_to(seeds[i] as Vector2)
					if d < bd:
						bd = d
						bi = i
		if bi >= 0:
			return bi
	for i in seeds.size():
		var d := q.distance_squared_to(seeds[i] as Vector2)
		if d < bd:
			bd = d
			bi = i
	return maxi(bi, 0)


## The areas of [param ar] beside area [param i] ([constant AREA_BESIDE]), found once.
static func _beside(ar: Dictionary, i: int) -> PackedInt32Array:
	var memo: Dictionary = ar["beside"]
	if memo.has(i):
		return memo[i]
	var seeds: Array = ar["seeds"]
	var size := float(ar["size"])
	var grid: Dictionary = ar["grid"]
	var c: Vector2 = seeds[i]
	var g := Vector2i(floori(c.x / size), floori(c.y / size))
	var out := PackedInt32Array()
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			for j in grid.get(g + Vector2i(dx, dy), PackedInt32Array()) as PackedInt32Array:
				if j != i and c.distance_to(seeds[j] as Vector2) <= size * AREA_BESIDE:
					out.append(j)
	memo[i] = out
	return out


## Area [param i] of [param ar] taken up by [param walk] (`{done, front}`): done, and those beside it with work in them ([param live]) its
## front - where the hand may go next.
static func _done_area(ar: Dictionary, walk: Dictionary, live: PackedByteArray, i: int) -> void:
	var done: PackedByteArray = walk["done"]
	done[i] = 1
	walk["done"] = done
	var front: Dictionary = walk["front"]
	front.erase(i)
	for j in _beside(ar, i):
		if live[j] == 1 and done[j] == 0:
			front[j] = true


## The area worked next ([method _coat]): of those beside one done ([param walk]'s front), the one nearest where the hand is [param at] -
## else, of those with work in them ([param live]) not done, the nearest. -1 when none is left.
static func _next_area(ar: Dictionary, live: PackedByteArray, walk: Dictionary, at: Vector2) -> int:
	var seeds: Array = ar["seeds"]
	var done: PackedByteArray = walk["done"]
	var front: Dictionary = walk["front"]
	var best := -1
	var bd := INF
	for i in front:
		var d := (seeds[int(i)] as Vector2).distance_squared_to(at)
		if d < bd:
			bd = d
			best = int(i)
	if best >= 0:
		return best
	for i in seeds.size():
		if live[i] == 0 or done[i] == 1:
			continue
		var d := (seeds[i] as Vector2).distance_squared_to(at)
		if d < bd:
			bd = d
			best = i
	return best


## [param pts] patch by patch: shared among the areas of [param ar], the areas taken beside one another from the one nearest [param from]
## ([method _next_area]), each area's the nearest next.
static func _walked(pts: Array, ar: Dictionary, from: Vector2) -> Array:
	var seeds: Array = ar["seeds"]
	var groups := {}
	var live := PackedByteArray()
	live.resize(seeds.size())
	for q in pts:
		var i := _area_at(ar, q)
		if not groups.has(i):
			groups[i] = []
		(groups[i] as Array).append(q)
		live[i] = 1
	var done0 := PackedByteArray()
	done0.resize(seeds.size())
	var walk := {"done": done0, "front": {}}
	var out: Array = []
	var at := from
	var first := _area_at(ar, from)
	var cur := first if live[first] == 1 else _next_area(ar, live, walk, from)
	while cur >= 0:
		_done_area(ar, walk, live, cur)
		for q in _nn(groups[cur], at):
			out.append(q)
			at = q
		cur = _next_area(ar, live, walk, at)
	return out


## Places [param apart] apart on a staggered grid over [param lo]..[param hi] (millimeters), each off its lattice point by up to
## [constant JITTER] of the spacing, as a hand places them.
func _lattice(lo: Vector2, hi: Vector2, apart: float, salt: int) -> Array:
	var out: Array = []
	var row := 0
	var y := lo.y
	while y <= hi.y + apart * 0.5:
		var x := lo.x + (apart * 0.5 if row % 2 == 1 else 0.0)
		while x <= hi.x + apart * 0.5:
			var j := Vector2(_hash(Vector2(x, y) + Vector2(salt, 3.1)), _hash(Vector2(y, x) + Vector2(7.7, salt))) - Vector2(0.5, 0.5)
			out.append(Vector2(x, y) + j * 2.0 * JITTER * apart)
			x += apart
		y += apart * 0.866
		row += 1
	return out


## Whether a dab that touches [param pts] (millimeters) may go - `Vector3(share where it may, share that still wants it, the thinness
## most of what wants it wants)`: [method _fit] for what a tool really touches.
func _fit_points(pts: PackedVector2Array, want: PackedInt32Array, mask: PackedByteArray, pv: Vector3, thins: PackedFloat32Array, base: bool) -> Vector3:
	var n := 0
	var ok := 0
	var wanted := 0
	var votes := PackedInt32Array()
	votes.resize(thins.size())
	for q in pts:
		var k := _k(q)
		n += 1
		if k < 0 or face[k] == 0:
			ok += 1
			continue
		if mask[k] == 0:
			continue
		if base or want[k] >= 0 or _off_with(k, pv, thins[0]) <= labs[k].distance_to(aim[k]) + WORSE:
			ok += 1
		if want[k] >= 0:
			wanted += 1
			votes[want[k]] += 1
	if n == 0:
		return Vector3.ZERO
	var ti := 0
	for i in thins.size():
		if votes[i] > votes[ti]:
			ti = i
	return Vector3(float(ok) / float(n), float(wanted) / float(n), float(ti))


## A brush's pulls (or a liner's lines): from the point of each cell of what wants the paint that most wants it, the cells taken round
## and round out from the middle as a hand works an area, traced both ways along the picture's edges (across its lightness's slope) while
## the footprint fits and the way still wants the paint; pulled toward the hand ([method Skins.pull_toward]); its mark made by the program
## ([method Skins._Prog.stroke]: its load running pale along it, its trips back) and laid on the canvas as it is drawn. Returns how many.
func _pulls(p: Variant, op: Dictionary, kind: String, want: PackedInt32Array, mask: PackedByteArray, pv: Vector3, thins: PackedFloat32Array,
		r: float, marks: Array) -> int:
	var cell := maxi(int(r * PX), 1)
	var seeds: Array = []
	var mid := Vector2.ZERO
	for y in range(0, h, cell):
		for x in range(0, w, cell):
			var best := -1
			var best_off := -1.0
			for yy in range(y, mini(y + cell, h)):
				for xx in range(x, mini(x + cell, w)):
					var k := yy * w + xx
					if want[k] >= 0 and labs[k].distance_to(aim[k]) > best_off:
						best_off = labs[k].distance_to(aim[k])
						best = k
			if best >= 0:
				var q := (Vector2(float(best % w), float(best / w)) + Vector2(0.5, 0.5)) / PX
				seeds.append(Vector3(q.x, q.y, best_off))
				mid += q
	if seeds.is_empty():
		return 0
	mid /= float(seeds.size())
	# ...as many as its time holds: the most wanted first, as many as the act's time left would draw, then taken in the hand's order.
	var budget := float(op.get("budget", INF))
	if budget < INF:
		var speed := Skins.LINE_SPEED if kind == "line" else Skins.SWEEP_SPEED
		var room := maxi(int((budget - float(p.t)) / (LONGEST * 0.25 / speed + PULL_AROUND)), 0)
		if room == 0:
			return 0
		if seeds.size() > room:
			seeds.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z > b.z)
			seeds = seeds.slice(0, room)
	var ring := maxf(r * 4.0, 2.0)
	seeds.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		var ra := floorf(Vector2(a.x, a.y).distance_to(mid) / ring)
		var rb := floorf(Vector2(b.x, b.y).distance_to(mid) / ring)
		if ra != rb:
			return ra < rb
		return (Vector2(a.x, a.y) - mid).angle() < (Vector2(b.x, b.y) - mid).angle())
	var frame: Vector2 = op.get("frame", mm)
	var step := maxf(r * 2.0 * STEP, 0.4)
	var longest := int(LONGEST / step)
	var laid := 0
	var taps: Array = []
	for sd in seeds:
		if marks.size() >= PULLS_MOST or float(p.t) > budget:
			break
		var s0 := Vector2(sd.x, sd.y)
		var k0 := _k(s0)
		if k0 < 0 or labs[k0].distance_to(aim[k0]) < NEED:
			continue
		# ...pressed as hard as fits: the heaviest press whose band lies where it may - a brush pressed lightly lays a narrower line.
		var press := -1.0
		var rw := r
		var f0 := Vector3.ZERO
		for pr in (LINE_PRESSES if kind == "line" else PULL_PRESSES):
			rw = r * lerpf(PRESS_NARROW, 1.0, float(pr))
			f0 = _fit(s0, rw, want, mask, pv, thins, false)
			if f0.x >= FIT:
				press = float(pr)
				break
		if press < 0.0 or f0.y < NEW_LEAST * 0.5:
			continue
		var th := thins[int(f0.z)]
		var pts := PackedVector2Array([s0])
		for way in [1.0, -1.0]:
			var cur := s0
			var dir := Vector2.ZERO
			for _i in longest:
				var kc := _k(cur)
				var g := grad[kc] if kc >= 0 else Vector2.ZERO
				var along := Vector2(-g.y, g.x).normalized() if g.length() > 0.5 else (dir if dir != Vector2.ZERO else Vector2.RIGHT)
				if dir != Vector2.ZERO and along.dot(dir) < 0.0:
					along = -along
				if dir == Vector2.ZERO:
					along *= way
				var nxt := cur + along * step
				var kn := _k(nxt)
				if kn < 0 or mask[kn] == 0 or _off_with(kn, pv, th) > labs[kn].distance_to(aim[kn]) - GAIN * 0.5:
					break
				if _fit(nxt, rw, want, mask, pv, thins, false).x < FIT:
					break
				dir = along
				cur = nxt
				if way > 0.0:
					pts.append(cur)
				else:
					pts.insert(0, cur)
		# ...a liner draws lines: one shorter than [constant LINE_LEAST] is a tap too.
		var run := 0.0
		for i in range(1, pts.size()):
			run += pts[i - 1].distance_to(pts[i])
		if pts.size() == 1 or (kind == "line" and run < LINE_LEAST):
			# (...taps, not lines: kept to the end, and only the [constant TAPS_MOST] standing furthest off laid - a highlight, a rivet's
			# light, never a picture's grain a fleck at a time)
			if sd.z >= NEED * DOT_OFF:
				taps.append([sd.z, s0, th, press])
			continue
		laid += _draw(p, op, kind, pts, th, pv, marks, frame, r, press)
	taps.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for tp in taps.slice(0, TAPS_MOST):
		var c: Vector2 = tp[1]
		var k := _k(c)
		if k < 0 or labs[k].distance_to(aim[k]) < NEED:
			continue
		laid += _draw(p, op, kind, PackedVector2Array([c, c + Vector2(r * 0.5, 0.0)]), float(tp[2]), pv, marks, frame, r, float(tp[3]))
	return laid


## Stroke [param pts] drawn: pulled toward the hand ([method Skins.pull_toward]), its mark made by the program ([method Skins._Prog.stroke]:
## its load running pale along it, its trips back), pressed as [param presses] says at each point (else [param pressed]), as fast as
## [param speed] (millimeters a second; else as its kind is), a look back at the work every [param look_every] strokes, lifted
## [param lift] (millimeters) on its way to the next, carrying the colors [param own] where it is given them (`cc`), and laid on the
## canvas as it is drawn. Returns 1.
func _draw(p: Variant, _op: Dictionary, kind: String, pts_in: PackedVector2Array, th: float, pv: Vector3, marks: Array, frame: Vector2, r: float,
		pressed := 1.0, presses := PackedFloat32Array(), speed := 0.0, look_every := LOOK_EVERY, lift := Skins.HOVER, own := PackedVector3Array()) -> int:
	var pts := pts_in
	# (pressed as [param presses] says point by point, where it says, else [param pressed] all along)
	var press := presses.duplicate() if presses.size() == pts.size() else PackedFloat32Array()
	if press.is_empty():
		press.resize(pts.size())
		press.fill(pressed)
	# ...pulled toward the hand, never pushed
	if (pts[pts.size() - 1] - pts[0]).dot(Skins.pull_toward(pts[pts.size() / 2], frame)) < 0.0:
		pts.reverse()
		press.reverse()
	var look := (marks.size() + 1) % look_every == 0
	if kind == "line":
		p.stroke(pts, speed if speed > 0.0 else Skins.LINE_SPEED, r, Skins.RELOAD_LINE, true, 1.0, lift, look, true, press)
	else:
		p.stroke(pts, Skins.SWEEP_SPEED, r, Skins.RELOAD_SWEEP, true, Skins.DRY_SWEEP, Skins.HOVER, look, false, press)
	var m: Dictionary = (p.strokes as Array).back()
	if not own.is_empty():
		m["cc"] = own
	_lay(m, kind, th, pv, marks.size())
	marks.append({"m": m, "th": th, "salt": marks.size()})
	return 1


# --- every operation but a foundation: marks fitted to the picture ---------------------------------------------------------------

## An operation's marks fitted to the picture by what they really lay (next/painted_surface.md): the picture itself is the aim, point for
## point (never the palette's nearest or a majority over the tool's width, which would throw gradients, flakes, cracks and highlights away
## before a mark is chosen), and each mark is rastered as it will be drawn ([method raster]) and laid only where, over all it touches, it
## brings what the show will draw nearer the picture ([method _gain_of_mark]). Where: where laying this paint helps most ([method _regain]),
## the next near the last ([constant NEAR_MM]); a stroke traced along the run of what still wants this paint ([method _way_at]) while it
## still helps, tried at each press it may take, the one that helps most laid; a dab at each press, or with each side of a sponge. Until
## nothing worth a mark is left, its time is spent, or [constant FIT_MOST] marks.
func _fit_op(p: Variant, op: Dictionary, kind: String, mask: PackedByteArray, pv: Vector3, r: float, marks: Array, most: float) -> void:
	var budget := float(op.get("budget", INF))
	var frame: Vector2 = op.get("frame", mm)
	var touch: Callable = op.get("touch", Callable())
	var sides: Array = op.get("sides", [])
	var by_touch := touch.is_valid() and not sides.is_empty() and kind == "dab"
	var way_at: Dictionary = op.get("_way_at", {})
	var sponge := String(op.get("manner", "")) == "stipple"
	var salt := int(op.get("seed", 0))
	_fit_mask = mask
	_fit_pv = pv
	_fit_a0 = most * GAIN_DEPOSIT
	# (...in its paint, or mixed on the palette with those it is told it may take - each mark the mix that helps most)
	_fit_cols = _mixes(pv, op.get("mix", []))
	_g = PackedFloat32Array()
	_g.resize(w * h)
	_cs = maxi(int(round(maxf(r * 2.0, 2.0) * PX)), 3)
	_cw = (w + _cs - 1) / _cs
	_chh = (h + _cs - 1) / _cs
	_cell_sum = PackedFloat32Array()
	_cell_sum.resize(_cw * _chh)
	_cell_best = PackedInt32Array()
	_cell_best.resize(_cw * _chh)
	_cell_best.fill(-1)
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for k in w * h:
		if mask[k] != 0:
			x0 = mini(x0, k % w)
			x1 = maxi(x1, k % w)
			y0 = mini(y0, k / w)
			y1 = maxi(y1, k / w)
	if x1 < 0:
		return
	_regain(x0, y0, x1, y1)
	var presses: Array = DAB_PRESSES if kind == "dab" else (LINE_PRESSES if kind == "line" else PULL_PRESSES)
	var cell_least := MARK_GAIN * 0.5 * PX * PX
	var last := Vector2(-1.0, -1.0)
	var tried := {}
	var refused := 0
	var m0 := marks.size()
	var reach := r + RAGGED + EDGE_SOFT + TOUCH_SOFT
	while marks.size() - m0 < FIT_MOST and float(p.t) <= budget:
		var c := _pick(last, tried, cell_least)
		if c < 0:
			break
		var k0 := _cell_best[c]
		var seed := (Vector2(float(k0 % w), float(k0 / w)) + Vector2(0.5, 0.5)) / PX
		var load := clampf(float(p.product) if float(p.product) >= 0.0 else 1.0, Skins.LAYS_LEAST, 1.0)
		var best := {}
		var best_gain := -INF
		if kind == "dab":
			if by_touch:
				for sd in sides:
					# (...a narrower side asked only where the broader did not help enough: each side asked is a pose found and a print drawn)
					if best_gain >= MARK_GAIN * 2.0:
						break
					var got: PackedVector2Array = touch.call(seed, String(sd), 1.0)
					if got.size() < 3:
						continue
					var m := {"pts": PackedVector2Array([seed]), "t": PackedFloat32Array([0.0]), "r": r, "load": PackedFloat32Array([load]),
						"press": PackedFloat32Array([1.0]), "touch": got}
					var rg := raster(m, "dab", PX, Vector2.ZERO, w, h, 1.0, salt + marks.size(), true)
					for ci in _fit_cols.size():
						var own := PackedVector3Array() if ci == 0 else PackedVector3Array([_fit_cols[ci]])
						for thin in THINNINGS:
							var gv := _gain_of_raster(rg, most * float(thin), own)
							if gv.x > best_gain:
								best_gain = gv.x
								best = {"m": m, "gain": gv, "press": 1.0, "side": String(sd), "th": most * float(thin), "cc": own}
			else:
				for pr in presses:
					var m := {"pts": PackedVector2Array([seed]), "t": PackedFloat32Array([0.0]), "r": r, "load": PackedFloat32Array([load]),
						"press": PackedFloat32Array([float(pr)]), "tip": not sponge}
					var got := raster(m, "dab", PX, Vector2.ZERO, w, h, 1.0, salt + marks.size(), true)
					for ci in _fit_cols.size():
						var own := PackedVector3Array() if ci == 0 else PackedVector3Array([_fit_cols[ci]])
						for thin in THINNINGS:
							var gv := _gain_of_raster(got, most * float(thin), own)
							if gv.x > best_gain:
								best_gain = gv.x
								best = {"m": m, "gain": gv, "press": float(pr), "th": most * float(thin), "cc": own}
		else:
			# (...traced as wide as what wants the paint is there, never wider than the brush pressed down - a fat brush follows a hairline
			# with its tip)
			var rw := clampf(_wide_at(seed, Vector2.ZERO, r), r * PRESS_NARROW, r * lerpf(PRESS_NARROW, 1.0, 0.7))
			var pts := _trace(seed, rw, frame)
			if pts.size() == 1:
				# (a tap: a stroke as short as half its width, the way a hand would pull it)
				pts.append(seed + Skins.pull_toward(seed, frame).normalized() * maxf(r * 0.5, 0.3))
			# (...and tried pressed to the width of what wants it point by point - lighter where it narrows, harder where it widens - as
			# well as at each even press)
			var shaped := _pressed_to(pts, r)
			for pr in presses + [shaped]:
				var n := pts.size()
				var ts := PackedFloat32Array()
				ts.resize(n)
				var ld := PackedFloat32Array()
				ld.resize(n)
				ld.fill(load)
				var ps := PackedFloat32Array()
				if pr is PackedFloat32Array:
					ps = pr
				else:
					ps.resize(n)
					ps.fill(float(pr))
				var m := {"pts": pts, "t": ts, "r": r, "load": ld, "press": ps}
				var got := raster(m, kind, PX, Vector2.ZERO, w, h, 1.0, salt + marks.size(), true)
				for ci in _fit_cols.size():
					var own := PackedVector3Array() if ci == 0 else PackedVector3Array([_fit_cols[ci]])
					for thin in THINNINGS:
						var gv := _gain_of_raster(got, most * float(thin), own)
						if gv.x > best_gain:
							best_gain = gv.x
							best = {"pts": pts, "gain": gv, "press": ps, "th": most * float(thin), "cc": own}
		var gain: Vector2 = best.get("gain", Vector2.ZERO)
		if best.is_empty() or gain.x < MARK_GAIN or gain.x < MARK_AVG * gain.y:
			tried[c] = true
			refused += 1
			if refused >= FIT_REFUSED_MOST:
				break
			continue
		refused = 0
		# ...laid: made by the program the show plays (its load, its trips back to the pot, its hand) and composited as it is drawn
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		if kind == "dab":
			var press := float(best["press"]) * lerpf(PRESS_UNEVEN, 1.0, _hash(seed + Vector2(13.3, salt)))
			if sponge:
				var per_load := maxi(roundi(Skins.LOAD_AREA_DABS / (PI * r * r)), 4)
				if best.has("side"):
					per_load = _per_load(((best["m"] as Dictionary)["touch"] as PackedVector2Array).size(), float(best.get("th", most)))
				p.dab(seed, r, Skins.DAB, Skins.DAB_LIFT, per_load, false, Skins.DRY_DABS, press)
			else:
				p.dab(seed, r, Vector3(Skins.DAB.x, Skins.DAB.y * 2.0, Skins.DAB.z), Skins.HOVER, Skins.RELOAD_DOTS, false, 1.0, press)
			var dm: Dictionary = (p.strokes as Array).back()
			dm["tip"] = not sponge
			if best.has("side"):
				dm["touch"] = (best["m"] as Dictionary)["touch"]
				way_at[seed] = SIDE_WAYS.get(String(best["side"]), 0)
				for q in dm["touch"] as PackedVector2Array:
					lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
					hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
			var th_d := float(best.get("th", most))
			if not (best.get("cc", PackedVector3Array()) as PackedVector3Array).is_empty():
				dm["cc"] = best["cc"]
			_lay(dm, "dab", th_d, pv, marks.size())
			marks.append({"m": dm, "th": th_d, "salt": marks.size()})
			last = seed
		else:
			var pts2: PackedVector2Array = best["pts"]
			_draw(p, op, kind, pts2, float(best.get("th", most)), pv, marks, frame, r, 1.0, best["press"], 0.0, LOOK_EVERY, Skins.HOVER,
					best.get("cc", PackedVector3Array()))
			var drawn: PackedVector2Array = ((marks.back() as Dictionary)["m"] as Dictionary)["pts"]
			last = drawn[drawn.size() - 1]
		for q in ((marks.back() as Dictionary)["m"] as Dictionary)["pts"] as PackedVector2Array:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		var rx0 := maxi(int((lo.x - reach) * PX), 0)
		var ry0 := maxi(int((lo.y - reach) * PX), 0)
		var rx1 := mini(int((hi.x + reach) * PX), w - 1)
		var ry1 := mini(int((hi.y + reach) * PX), h - 1)
		_regain(rx0, ry0, rx1, ry1)
		# (what was tried and refused round it may be worth a mark now)
		for cy in range(ry0 / _cs, ry1 / _cs + 1):
			for cx in range(rx0 / _cs, rx1 / _cs + 1):
				tried.erase(cy * _cw + cx)
	op["_way_at"] = way_at


## A blend: the paint already on, moved by a clean brush. Where the canvas changes more sharply than the picture does ([method _reedge]),
## a short pull across that edge ([method _across], [constant BLEND_LONG] times its width each way, at each press and both ways), the
## brush taking up what lies under it as it goes and laying it on along the way ([method _picked_up], [constant BLEND_PICK]) - laid only
## where, over all it touches, it brings the canvas nearer the picture ([method _gain_of_raster]), the next near the last. Until no edge
## worth softening is left, its time is spent, or [constant FIT_MOST] marks. Never a paint of its own: each mark carries the colors it
## took up (`cc`).
func _blend_op(p: Variant, op: Dictionary, mask: PackedByteArray, r: float, marks: Array, most: float) -> void:
	var budget := float(op.get("budget", INF))
	var salt := int(op.get("seed", 0))
	_fit_mask = mask
	_g = PackedFloat32Array()
	_g.resize(w * h)
	_cs = maxi(int(round(maxf(r * 2.0, 2.0) * PX)), 3)
	_cw = (w + _cs - 1) / _cs
	_chh = (h + _cs - 1) / _cs
	_cell_sum = PackedFloat32Array()
	_cell_sum.resize(_cw * _chh)
	_cell_best = PackedInt32Array()
	_cell_best.resize(_cw * _chh)
	_cell_best.fill(-1)
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for k in w * h:
		if mask[k] != 0:
			x0 = mini(x0, k % w)
			x1 = maxi(x1, k % w)
			y0 = mini(y0, k / w)
			y1 = maxi(y1, k / w)
	if x1 < 0:
		return
	_reedge(x0, y0, x1, y1)
	var last := Vector2(-1.0, -1.0)
	var tried := {}
	var refused := 0
	var m0 := marks.size()
	var reach := r + BRUSH_EDGE + RAGGED
	while marks.size() - m0 < FIT_MOST and float(p.t) <= budget:
		var c := _pick(last, tried, BLEND_EDGE * PX * PX)
		if c < 0:
			break
		var k0 := _cell_best[c]
		var seed := (Vector2(float(k0 % w), float(k0 / w)) + Vector2(0.5, 0.5)) / PX
		var across := _across(seed, r)
		if across == Vector2.ZERO:
			across = Skins.pull_toward(seed, op.get("frame", mm)).normalized()
		var best := {}
		var best_gain := -INF
		for way in [1.0, -1.0]:
			for pr in BLEND_PRESSES:
				var rw := r * lerpf(PRESS_NARROW, 1.0, float(pr))
				var half := maxf(rw * BLEND_LONG, 1.0)
				var a: Vector2 = seed - across * float(way) * half
				var n := maxi(int(ceil(half * 2.0 * PX)), 2)
				var pts := PackedVector2Array()
				for i in n + 1:
					pts.append(a + across * float(way) * half * 2.0 * float(i) / float(n))
				var cc := _picked_up(pts, rw)
				var ts := PackedFloat32Array()
				ts.resize(pts.size())
				var ld := PackedFloat32Array()
				ld.resize(pts.size())
				ld.fill(1.0)
				var ps := PackedFloat32Array()
				ps.resize(pts.size())
				ps.fill(float(pr))
				var m := {"pts": pts, "t": ts, "r": r, "load": ld, "press": ps, "cc": cc}
				var got := raster(m, "blend", PX, Vector2.ZERO, w, h, 1.0, salt + marks.size(), true)
				for lay_by in BLEND_LAYS:
					var gv := _gain_of_raster(got, float(lay_by) * most, cc)
					if gv.x > best_gain:
						best_gain = gv.x
						best = {"pts": pts, "press": ps, "cc": cc, "th": float(lay_by) * most, "gain": gv}
		var gain: Vector2 = best.get("gain", Vector2.ZERO)
		if best.is_empty() or gain.x < MARK_GAIN:
			tried[c] = true
			refused += 1
			if refused >= FIT_REFUSED_MOST:
				break
			continue
		refused = 0
		# ...pulled as the show will play it: no paint taken up, never a trip back for more
		var pts2: PackedVector2Array = best["pts"]
		p.stroke(pts2, Skins.BLEND_SPEED, r, INF, true, 1.0, Skins.HOVER, (marks.size() + 1) % LOOK_EVERY == 0, true, best["press"])
		var dm: Dictionary = (p.strokes as Array).back()
		dm["cc"] = best["cc"]
		_lay(dm, "blend", float(best["th"]), Vector3.ONE, marks.size())
		marks.append({"m": dm, "th": float(best["th"]), "salt": marks.size()})
		last = pts2[pts2.size() - 1]
		var lo := pts2[0].min(pts2[pts2.size() - 1])
		var hi_q := pts2[0].max(pts2[pts2.size() - 1])
		var rx0 := maxi(int((lo.x - reach) * PX) - 1, 0)
		var ry0 := maxi(int((lo.y - reach) * PX) - 1, 0)
		var rx1 := mini(int((hi_q.x + reach) * PX) + 1, w - 1)
		var ry1 := mini(int((hi_q.y + reach) * PX) + 1, h - 1)
		_reedge(rx0, ry0, rx1, ry1)
		for cy in range(ry0 / _cs, ry1 / _cs + 1):
			for cx in range(rx0 / _cs, rx1 / _cs + 1):
				tried.erase(cy * _cw + cx)


## Where the canvas changes more sharply than the picture does, within [param x0]..[param x1], [param y0]..[param y1] (canvas points):
## each point's change across a millimeter - the canvas's less the picture's, past [constant BLEND_EDGE] - in [member _g], and each cell's
## sum and sharpest point ([method _pick]).
func _reedge(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(maxi(y0, 0), mini(y1 + 1, h)):
		for x in range(maxi(x0, 0), mini(x1 + 1, w)):
			var k := y * w + x
			if _fit_mask[k] == 0 or face[k] == 0 or x < 1 or y < 1 or x >= w - 1 or y >= h - 1:
				_g[k] = 0.0
				continue
			var here := labs[k + 1].distance_to(labs[k - 1]) + labs[k + w].distance_to(labs[k - w])
			var there := raw[k + 1].distance_to(raw[k - 1]) + raw[k + w].distance_to(raw[k - w])
			_g[k] = maxf(here - there - BLEND_EDGE, 0.0)
	for cy in range(maxi(y0, 0) / _cs, mini(y1, h - 1) / _cs + 1):
		for cx in range(maxi(x0, 0) / _cs, mini(x1, w - 1) / _cs + 1):
			var sum := 0.0
			var best := -1
			var bg := 0.0
			for y in range(cy * _cs, mini((cy + 1) * _cs, h)):
				for x in range(cx * _cs, mini((cx + 1) * _cs, w)):
					var gv := _g[y * w + x]
					if gv > 0.0:
						sum += gv
						if gv > bg:
							bg = gv
							best = y * w + x
			_cell_sum[cy * _cw + cx] = sum
			_cell_best[cy * _cw + cx] = best


## Which way the canvas changes at [param q] (millimeters), looked at as far round it as a brush [param r] reaches: the way across its
## edge, either sign (the strongest way of its change, all three of its colors' together); ZERO where it changes no way.
func _across(q: Vector2, r: float) -> Vector2:
	var rp := maxi(ceili(maxf(r, 1.0) * PX), 2)
	var qx := int(q.x * PX)
	var qy := int(q.y * PX)
	var jxx := 0.0
	var jxy := 0.0
	var jyy := 0.0
	for dy in range(-rp, rp + 1):
		var y := qy + dy
		if y < 1 or y >= h - 1:
			continue
		for dx in range(-rp, rp + 1):
			var x := qx + dx
			if x < 1 or x >= w - 1:
				continue
			var k := y * w + x
			var gx := labs[k + 1] - labs[k - 1]
			var gy := labs[k + w] - labs[k - w]
			jxx += gx.dot(gx)
			jxy += gx.dot(gy)
			jyy += gy.dot(gy)
	if jxx + jyy < 1e-3:
		return Vector2.ZERO
	var ang := 0.5 * atan2(2.0 * jxy, jxx - jyy)
	return Vector2(cos(ang), sin(ang))


## The colors a clean brush carries along [param pts], [param rw] wide (sRGB, a point each): what lies under it where it comes down,
## then at each point that much again of what lies under it there ([constant BLEND_PICK]) - the paint it drags.
func _picked_up(pts: PackedVector2Array, rw: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var held := Vector3(-1.0, -1.0, -1.0)
	var rp := maxi(int(rw * PX), 0)
	for q in pts:
		var qx := int(q.x * PX)
		var qy := int(q.y * PX)
		var sum := Vector3.ZERO
		var n := 0
		for dy in range(-rp, rp + 1):
			for dx in range(-rp, rp + 1):
				var x := qx + dx
				var y := qy + dy
				if x < 0 or y < 0 or x >= w or y >= h or dx * dx + dy * dy > rp * rp or face[y * w + x] == 0:
					continue
				sum += lin[y * w + x]
				n += 1
		var under := sum / float(n) if n > 0 else (held if held.x >= 0.0 else bare_lin)
		held = under if held.x < 0.0 else held.lerp(under, BLEND_PICK)
		out.append(Vector3(pow(maxf(held.x, 0.0), 1.0 / 2.2), pow(maxf(held.y, 0.0), 1.0 / 2.2), pow(maxf(held.z, 0.0), 1.0 / 2.2)))
	return out


## A line operation's lines traced from the picture, for hairlines finer than the canvas that no fitted stroke finds: at the picture's own
## resolution ([member hi]), where it stands nearer the operation's paint [param pv] than what is round it does ([constant TRACE_ROUND],
## [constant TRACE_NEAR], at least [constant TRACE_CONTRAST] nearer; on along it where it fades, [constant TRACE_FAINT]), inside where it
## may go ([param mask]), thinned to a pixel's width and followed into lines as a hand draws them, none shorter than
## [constant TRACE_SHORTEST] - each drawn as the liner draws it ([method _draw]), pressed to the line's own width point by point, thinner
## where the line is fainter, the nearest next; no longer than its time. Returns how many it drew; what it found and left is in
## `op._traced`.
func _trace_lines(p: Variant, op: Dictionary, mask: PackedByteArray, pv: Vector3, r: float, marks: Array, most: float) -> int:
	if hi == null:
		return 0
	var budget := float(op.get("budget", INF))
	var frame: Vector2 = op.get("frame", mm)
	var hw := hi.get_width()
	var hh := hi.get_height()
	# (where it may go, at the picture's resolution: its bounds)
	var x0 := hw
	var y0 := hh
	var x1 := -1
	var y1 := -1
	for k in w * h:
		if mask[k] != 0:
			x0 = mini(x0, int(float(k % w) / PX * hi_px))
			x1 = maxi(x1, int(float(k % w + 1) / PX * hi_px))
			y0 = mini(y0, int(float(k / w) / PX * hi_px))
			y1 = maxi(y1, int(float(k / w + 1) / PX * hi_px))
	if x1 < 0:
		return 0
	x0 = maxi(x0, 0)
	y0 = maxi(y0, 0)
	x1 = mini(x1, hw - 1)
	y1 = mini(y1, hh - 1)
	var bw := x1 - x0 + 1
	var bh := y1 - y0 + 1
	var pot := lab(_dec(pv.x), _dec(pv.y), _dec(pv.z))
	# (each point's color and what is round it, OKLab)
	var labs_hi := PackedVector3Array()
	labs_hi.resize(bw * bh)
	var chans := [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	for c in 3:
		(chans[c] as PackedFloat32Array).resize(bw * bh)
	var lr := PackedFloat32Array()
	lr.resize(bw * bh)
	var la := PackedFloat32Array()
	la.resize(bw * bh)
	var lb := PackedFloat32Array()
	lb.resize(bw * bh)
	for y in bh:
		for x in bw:
			var c := hi.get_pixel(x0 + x, y0 + y).srgb_to_linear()
			var l := lab(c.r, c.g, c.b)
			labs_hi[y * bw + x] = l
			lr[y * bw + x] = l.x
			la[y * bw + x] = l.y
			lb[y * bw + x] = l.z
	var by := maxf(TRACE_ROUND * hi_px, 1.0)
	var blur := func(v: PackedFloat32Array) -> PackedFloat32Array:
		var img := Image.create_from_data(bw, bh, false, Image.FORMAT_RF, v.to_byte_array())
		img.resize(maxi(int(round(float(bw) / by)), 1), maxi(int(round(float(bh) / by)), 1), Image.INTERPOLATE_BILINEAR)
		img.resize(bw, bh, Image.INTERPOLATE_BILINEAR)
		return img.get_data().to_float32_array()
	var br: PackedFloat32Array = blur.call(lr)
	var ba: PackedFloat32Array = blur.call(la)
	var bb: PackedFloat32Array = blur.call(lb)
	# (how much nearer the paint each point stands than what is round it, a share - where it may go)
	var near := PackedFloat32Array()
	near.resize(bw * bh)
	var on := PackedByteArray()
	on.resize(bw * bh)
	for y in bh:
		for x in bw:
			var i := y * bw + x
			var k := _k(Vector2(float(x0 + x) + 0.5, float(y0 + y) + 0.5) / hi_px)
			if k < 0 or mask[k] == 0:
				continue
			var d_here := labs_hi[i].distance_to(pot)
			var d_round := Vector3(br[i], ba[i], bb[i]).distance_to(pot)
			# (...or where it is the paint itself, whatever is round it: the middle of a bar wider than the look round it is kept, not just
			# its two edges)
			if d_here <= TRACE_SAME_PAINT:
				near[i] = 1.0
				on[i] = 1
				continue
			if d_round - d_here < TRACE_CONTRAST * TRACE_FAINT:
				continue
			near[i] = clampf((d_round - d_here) / maxf(d_round, 1.0), 0.0, 1.0)
			if near[i] >= TRACE_NEAR and d_round - d_here >= TRACE_CONTRAST:
				on[i] = 1
	# (...and on along it where it goes fainter, as long as it runs on from where it was clear - [constant TRACE_FAINT]; a faint stretch
	# must not break a hairline into dashes)
	var queue := PackedInt32Array()
	for i in bw * bh:
		if on[i] == 1:
			queue.append(i)
	var qi := 0
	while qi < queue.size():
		var i := queue[qi]
		qi += 1
		var x := i % bw
		var y := i / bw
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var xx: int = x + dx
				var yy: int = y + dy
				if xx < 0 or yy < 0 or xx >= bw or yy >= bh:
					continue
				var j := yy * bw + xx
				if on[j] == 0 and near[j] >= TRACE_NEAR * TRACE_FAINT:
					on[j] = 1
					queue.append(j)
	# (...how far each point on lies inside the line - its half width, a chamfer's two passes - before...)
	var inside := PackedFloat32Array()
	inside.resize(bw * bh)
	for i in bw * bh:
		inside[i] = 1e6 if on[i] == 1 else 0.0
	for y in bh:
		for x in bw:
			var i := y * bw + x
			if on[i] == 0:
				continue
			var v := inside[i]
			v = minf(v, (inside[i - 1] if x > 0 else 0.0) + 1.0)
			v = minf(v, (inside[i - bw] if y > 0 else 0.0) + 1.0)
			v = minf(v, (inside[i - bw - 1] if x > 0 and y > 0 else 0.0) + 1.414)
			v = minf(v, (inside[i - bw + 1] if x < bw - 1 and y > 0 else 0.0) + 1.414)
			inside[i] = v
	for y in range(bh - 1, -1, -1):
		for x in range(bw - 1, -1, -1):
			var i := y * bw + x
			if on[i] == 0:
				continue
			var v := inside[i]
			v = minf(v, (inside[i + 1] if x < bw - 1 else 0.0) + 1.0)
			v = minf(v, (inside[i + bw] if y < bh - 1 else 0.0) + 1.0)
			v = minf(v, (inside[i + bw + 1] if x < bw - 1 and y < bh - 1 else 0.0) + 1.414)
			v = minf(v, (inside[i + bw - 1] if x > 0 and y < bh - 1 else 0.0) + 1.414)
			inside[i] = v
	# (...its gaps bridged - a hairline in the picture is a dotted run of pixels, each dot too short to follow alone - by one pixel's
	# growth that thinning takes back off...)
	var grown := on.duplicate()
	for y in range(1, bh - 1):
		for x in range(1, bw - 1):
			var i := y * bw + x
			if on[i] == 1:
				continue
			for j in [i - 1, i + 1, i - bw, i + bw, i - bw - 1, i - bw + 1, i + bw - 1, i + bw + 1]:
				if on[j] == 1:
					grown[i] = 1
					break
	on = grown
	# (...thinned to a pixel's width, Zhang and Suen's way, the points on kept in a list)
	var pts := PackedInt32Array()
	for i in bw * bh:
		if on[i] == 1:
			pts.append(i)
	var nb := func(i: int, dx: int, dy: int) -> int:
		var x := i % bw + dx
		var y := i / bw + dy
		return on[y * bw + x] if x >= 0 and y >= 0 and x < bw and y < bh else 0
	var changed := true
	var guard := 0
	while changed and guard < 40:
		changed = false
		guard += 1
		for sub in 2:
			var gone := PackedInt32Array()
			for i in pts:
				if on[i] == 0:
					continue
				var p2: int = nb.call(i, 0, -1)
				var p3: int = nb.call(i, 1, -1)
				var p4: int = nb.call(i, 1, 0)
				var p5: int = nb.call(i, 1, 1)
				var p6: int = nb.call(i, 0, 1)
				var p7: int = nb.call(i, -1, 1)
				var p8: int = nb.call(i, -1, 0)
				var p9: int = nb.call(i, -1, -1)
				var n := p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9
				if n < 2 or n > 6:
					continue
				var seq := [p2, p3, p4, p5, p6, p7, p8, p9, p2]
				var a := 0
				for j in 8:
					if int(seq[j]) == 0 and int(seq[j + 1]) == 1:
						a += 1
				if a != 1:
					continue
				if sub == 0 and (p2 * p4 * p6 != 0 or p4 * p6 * p8 != 0):
					continue
				if sub == 1 and (p2 * p4 * p8 != 0 or p2 * p6 * p8 != 0):
					continue
				gone.append(i)
			for i in gone:
				on[i] = 0
			if not gone.is_empty():
				changed = true
	# (...and only where it is a line: what lies deeper in than [constant TRACE_WIDEST] is an area, the fitter's)
	var wide := TRACE_WIDEST * hi_px
	for i in pts:
		if on[i] == 1 and inside[i] > wide:
			on[i] = 0
	# (...followed into lines as a hand draws them: from each end first, on through where lines meet the straightest way, joined to what
	# is drawn already at either end - split at every meeting and every corner of the thinned line, each shorter than
	# [constant TRACE_SHORTEST] dropped)
	var count := func(i: int) -> int:
		var n := 0
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if (dx != 0 or dy != 0) and int(nb.call(i, dx, dy)) == 1:
					n += 1
		return n
	var seen := PackedByteArray()
	seen.resize(bw * bh)
	var lines: Array = []
	var starts: Array = []
	for i in pts:
		if on[i] == 1 and int(count.call(i)) == 1:
			starts.append(i)
	for i in pts:
		if on[i] == 1:
			starts.append(i)
	var joined := func(i: int, but: PackedInt32Array) -> int:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var x: int = i % bw + dx
				var y: int = i / bw + dy
				if (dx == 0 and dy == 0) or x < 0 or y < 0 or x >= bw or y >= bh:
					continue
				var j := y * bw + x
				if on[j] == 1 and seen[j] == 1 and not but.has(j):
					return j
		return -1
	for st in starts:
		if seen[st] == 1:
			continue
		var line := PackedInt32Array()
		var before: int = joined.call(st, PackedInt32Array())
		if before >= 0:
			line.append(before)
		line.append(st)
		seen[st] = 1
		var cur: int = st
		while true:
			var back := line[maxi(line.size() - 4, 0)]
			var dir := Vector2(float(cur % bw - back % bw), float(cur / bw - back / bw))
			var nxt := -1
			var best := -INF
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var x: int = cur % bw + dx
					var y: int = cur / bw + dy
					if x < 0 or y < 0 or x >= bw or y >= bh:
						continue
					var j := y * bw + x
					if on[j] == 1 and seen[j] == 0:
						var sc := Vector2(dx, dy).normalized().dot(dir.normalized()) if dir.length() > 0.0 else -absf(float(dx * dy))
						if sc > best:
							best = sc
							nxt = j
			if nxt < 0:
				break
			line.append(nxt)
			seen[nxt] = 1
			cur = nxt
		var after: int = joined.call(cur, line.slice(maxi(line.size() - 4, 0)))
		if after >= 0:
			line.append(after)
		lines.append(line)
	# (...each in millimeters, kept to its turns, as strong as the line is there and pressed to its width point by point - a brush's tip
	# for a hairline, pressed down where the line widens, whatever the brush; none too short)
	var strokes: Array = []
	for ln in lines:
		var l: PackedInt32Array = ln
		var path := PackedVector2Array()
		var strength := 0.0
		var halves := PackedFloat32Array()
		for i in l:
			path.append((Vector2(float(x0 + i % bw), float(y0 + i / bw)) + Vector2(0.5, 0.5)) / hi_px)
			strength += near[i]
			halves.append(maxf(inside[i] - 0.5, 0.5) / hi_px)
		var length := 0.0
		for j in range(1, path.size()):
			length += path[j - 1].distance_to(path[j])
		if length < TRACE_SHORTEST:
			continue
		var kept := _kept(path, 0, path.size() - 1, TRACE_KEEP)
		var kp := PackedVector2Array()
		var ps := PackedFloat32Array()
		for j in kept.size():
			kp.append(path[kept[j]])
			# (the width over the run round each kept point, its middle)
			var a := kept[maxi(j - 1, 0)]
			var b := kept[mini(j + 1, kept.size() - 1)]
			var run := halves.slice(mini(a, kept[j]), maxi(b, kept[j]) + 1)
			run.sort()
			ps.append(clampf((run[run.size() / 2] / maxf(r, 1e-3) - PRESS_NARROW) / (1.0 - PRESS_NARROW), 0.0, 1.0))
		var hs := halves.duplicate()
		hs.sort()
		strokes.append({"pts": kp, "press": ps, "strength": strength / float(l.size()), "half": hs[hs.size() / 2]})
	if strokes.is_empty():
		return 0
	# (...the nearest next, from where the hand is - on without lifting into the next where it begins within [constant TRACE_JOIN] of
	# where this one ended, as a crackle's lines meet)
	var at: Vector2 = (strokes[0] as Dictionary)["pts"][0]
	var left: Array = strokes.duplicate()
	var t0 := float(p.t)
	var drawn_n := 0
	var piece := PackedVector2Array()
	var pp := PackedFloat32Array()
	var run := 0.0
	var thick := 0.0
	# (a lambda sees its locals as they were when it was made: what it draws is handed to it)
	var draw_piece := func(pc: PackedVector2Array, pr: PackedFloat32Array, th: float) -> void:
		if pc.size() >= 2:
			# (...a short one flicked on quicker than a long one is drawn - [constant TRACE_SPEED] up to [constant TRACE_FLICK] millimeters, a
			# careful hand's pace by [constant TRACE_CAREFUL]; lifted no more than a pull is between them, the next a few millimeters off)
			var length := 0.0
			for j in range(1, pc.size()):
				length += pc[j - 1].distance_to(pc[j])
			_draw(p, op, "line", pc, th, pv, marks, frame, r, 1.0, pr,
					lerpf(TRACE_SPEED, Skins.LINE_SPEED, smoothstep(TRACE_FLICK, TRACE_CAREFUL, length)), TRACE_LOOK_EVERY, Skins.PULL_LIFT)
	while not left.is_empty() and float(p.t) <= budget and marks.size() < FIT_MOST:
		var bi := 0
		var bd := INF
		var flip := false
		for i in left.size():
			var sp: PackedVector2Array = (left[i] as Dictionary)["pts"]
			var d0 := at.distance_squared_to(sp[0])
			var d1 := at.distance_squared_to(sp[sp.size() - 1])
			if minf(d0, d1) < bd:
				bd = minf(d0, d1)
				bi = i
				flip = d1 < d0
		var sd: Dictionary = left[bi]
		left.remove_at(bi)
		if not sd.has("beside"):
			drawn_n += 1
		var path2: PackedVector2Array = sd["pts"]
		var ps2: PackedFloat32Array = sd["press"]
		if flip:
			path2.reverse()
			ps2.reverse()
		var th_line := most * lerpf(TRACE_THIN, 1.0, float(sd["strength"]))
		# (...a line wider than the brush: passes beside it, each side, until they reach its edge)
		var half := float(sd.get("half", 0.0))
		var sides_n := ceili((half - r) / (r * 2.0 * TRACE_SIDE_BY)) if half > r * 1.15 else 0
		for j in range(1, sides_n + 1):
			for sgn in [1.0, -1.0]:
				var off := _offset(path2, float(sgn) * minf(float(j) * r * 2.0 * TRACE_SIDE_BY, half - r * 0.5))
				var full := PackedFloat32Array()
				full.resize(off.size())
				full.fill(1.0)
				left.append({"pts": off, "press": full, "strength": sd["strength"], "half": 0.0, "beside": true})
		if piece.is_empty() or sqrt(bd) > TRACE_JOIN:
			draw_piece.call(piece, pp, thick)
			piece = PackedVector2Array([path2[0]])
			pp = PackedFloat32Array([ps2[0]])
			run = 0.0
			thick = th_line
		else:
			thick = maxf(thick, th_line)
		# (...no longer than a pull a hand draws at once)
		for j in range(1, path2.size()):
			run += path2[j - 1].distance_to(path2[j])
			piece.append(path2[j])
			pp.append(ps2[j])
			if run >= LONGEST:
				draw_piece.call(piece, pp, thick)
				piece = PackedVector2Array([path2[j]])
				pp = PackedFloat32Array([ps2[j]])
				run = 0.0
		at = path2[path2.size() - 1]
	draw_piece.call(piece, pp, thick)
	# (...and what it found and drew, and about how long the rest would take at the pace it drew these - for the hand that asked for it)
	var length_of := func(sd: Dictionary) -> float:
		var sp: PackedVector2Array = sd["pts"]
		var mm_of := 0.0
		for j in range(1, sp.size()):
			mm_of += sp[j - 1].distance_to(sp[j])
		return mm_of
	var all_mm := 0.0
	for sd in strokes:
		all_mm += float(length_of.call(sd))
	var left_mm := 0.0
	for sd in left:
		if not (sd as Dictionary).has("beside"):
			left_mm += float(length_of.call(sd))
	var took := float(p.t) - t0
	var drawn_mm := all_mm - left_mm
	op["_traced"] = {"lines": strokes.size(), "drawn": drawn_n, "mm": all_mm, "left_mm": left_mm,
		"left_seconds": left_mm * took / drawn_mm if drawn_mm > 1.0 else left_mm / TRACE_SPEED}
	return drawn_n


## Colors [param v] (one a point of the canvas) softened over about [param by] millimeters.
func _softened(v: PackedVector3Array, by: float) -> PackedVector3Array:
	var chans: Array = []
	for c in 3:
		var f := PackedFloat32Array()
		f.resize(w * h)
		for k in w * h:
			f[k] = v[k][c]
		var img := Image.create_from_data(w, h, false, Image.FORMAT_RF, f.to_byte_array())
		img.resize(maxi(int(round(float(w) / maxf(by * PX, 1.0))), 1), maxi(int(round(float(h) / maxf(by * PX, 1.0))), 1), Image.INTERPOLATE_BILINEAR)
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		chans.append(img.get_data().to_float32_array())
	var out := PackedVector3Array()
	out.resize(w * h)
	for k in w * h:
		out[k] = Vector3((chans[0] as PackedFloat32Array)[k], (chans[1] as PackedFloat32Array)[k], (chans[2] as PackedFloat32Array)[k])
	return out


## Path [param pts] moved [param by] millimeters to its left (its right, less than nothing), each point along the way it runs there.
static func _offset(pts: PackedVector2Array, by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size():
		var way := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		out.append(pts[i] + Vector2(-way.y, way.x) * by)
	return out


## Which points of path [param pts] from [param i0] to [param i1] keep it to its turns: none left out further than [param keep] millimeters
## from the line through those kept round it (Ramer, Douglas and Peucker's way), their indices in order.
static func _kept(pts: PackedVector2Array, i0: int, i1: int, keep: float) -> PackedInt32Array:
	if i1 - i0 < 2:
		return PackedInt32Array([i0, i1]) if i1 > i0 else PackedInt32Array([i0])
	var far := -1.0
	var at := i0
	for i in range(i0 + 1, i1):
		var d := Geometry2D.get_closest_point_to_segment(pts[i], pts[i0], pts[i1]).distance_to(pts[i])
		if d > far:
			far = d
			at = i
	if far <= keep:
		return PackedInt32Array([i0, i1])
	var left := _kept(pts, i0, at, keep)
	left.remove_at(left.size() - 1)
	left.append_array(_kept(pts, at, i1, keep))
	return left


## How much laying the operation's paint would put each point right, from ([param x0], [param y0]) to ([param x1], [param y1]) (pixels):
## how much nearer the picture it would stand laid at [constant GAIN_DEPOSIT] of a full load - where the operation may go, 0 elsewhere -
## and each cell over it its sum of what helps and its best point.
func _regain(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(maxi(y0, 0), mini(y1 + 1, h)):
		for x in range(maxi(x0, 0), mini(x1 + 1, w)):
			var k := y * w + x
			if _fit_mask[k] == 0 or face[k] == 0:
				_g[k] = 0.0
				continue
			var gk := -INF
			for c in _fit_cols:
				gk = maxf(gk, labs[k].distance_to(raw[k]) - _after(k, c, _fit_a0).distance_to(raw[k]))
			_g[k] = gk
	for cy in range(maxi(y0, 0) / _cs, mini(y1, h - 1) / _cs + 1):
		for cx in range(maxi(x0, 0) / _cs, mini(x1, w - 1) / _cs + 1):
			var sum := 0.0
			var best := -1
			var bg := 0.0
			for y in range(cy * _cs, mini((cy + 1) * _cs, h)):
				for x in range(cx * _cs, mini((cx + 1) * _cs, w)):
					var gv := _g[y * w + x]
					if gv > 0.0:
						sum += gv
						if gv > bg:
							bg = gv
							best = y * w + x
			_cell_sum[cy * _cw + cx] = sum
			_cell_best[cy * _cw + cx] = best


## The cell worked next: of those whose laying would put at least [param least] right (summed) and that were not [param tried], the one
## that would put most right for how far it is from where the hand last was [param last] ([constant NEAR_MM]). -1 when none is left.
func _pick(last: Vector2, tried: Dictionary, least: float) -> int:
	var best := -1
	var bs := 0.0
	for c in _cw * _chh:
		var sum := _cell_sum[c]
		if sum < least or _cell_best[c] < 0 or tried.has(c):
			continue
		var score := sum
		if last.x >= 0.0:
			var at := (Vector2(float(c % _cw), float(c / _cw)) + Vector2(0.5, 0.5)) * float(_cs) / PX
			score = sum / (1.0 + at.distance_to(last) / NEAR_MM)
		if score > bs:
			bs = score
			best = c
	return best


## A stroke's path from [param seed] (millimeters), a brush [param rw] wide: both ways along what still wants its paint ([method _way_at];
## where nothing says which way, as a hand pulls across [param frame]), a step a share of its width at a time, as long as what lies ahead
## wants it ([constant TRACE_GAIN]), the picture stays near the color it was at [param seed] ([constant TRACE_SAME]) and it turns no more
## than [constant TRACE_TURN] a step - no longer than [constant LONGEST].
func _trace(seed: Vector2, rw: float, frame: Vector2) -> PackedVector2Array:
	var step := maxf(rw * 2.0 * STEP, 0.4)
	var longest := int(LONGEST / step)
	var k_seed := _k(seed)
	if _raw_soft.size() != raw.size():
		_raw_soft = _softened(raw, SAME_SOFT)
	var keep: Vector3 = _raw_soft[k_seed] if k_seed >= 0 else Vector3.ZERO
	var first := _way_at(seed, rw, Vector2.ZERO)
	if first == Vector2.ZERO:
		first = Skins.pull_toward(seed, frame).normalized()
	var pts := PackedVector2Array([seed])
	for way in [1.0, -1.0]:
		var cur := seed
		var dir: Vector2 = first * way
		for _i in longest:
			var d := _way_at(cur, rw, dir)
			if d == Vector2.ZERO:
				d = dir
			if d.dot(dir) < 0.0:
				d = -d
			if absf(d.angle_to(dir)) > TRACE_TURN:
				break
			var nxt := cur + d * step
			var kn := _k(nxt)
			if kn < 0 or _fit_mask[kn] == 0 or _g_around(nxt, rw * 0.6) < TRACE_GAIN:
				break
			# (...and no further than the picture stays the color it was where it began: one stroke, one color, as a painter lays it)
			if k_seed >= 0 and _raw_soft[kn].distance_to(keep) > TRACE_SAME:
				break
			dir = d
			cur = nxt
			if way > 0.0:
				pts.append(cur)
			else:
				pts.insert(0, cur)
	return pts


## Which way what still wants the paint runs at [param q] (millimeters), looked at [constant WAY_LOOK] times a tool [param rw] wide round
## it: across its slope where that runs one way clearly ([constant WAY_COHERENT]), else the long way of the patch of it there
## ([constant WAY_LONG]); turned to go on the way [param prev] went. ZERO where it runs no way at all.
func _way_at(q: Vector2, rw: float, prev: Vector2) -> Vector2:
	var rp := maxi(ceili(maxf(rw * WAY_LOOK, 1.0) * PX), 2)
	var stride := 2 if rp > 8 else 1
	var qx := int(q.x * PX)
	var qy := int(q.y * PX)
	var jxx := 0.0
	var jxy := 0.0
	var jyy := 0.0
	var m0 := 0.0
	var mx := 0.0
	var my := 0.0
	var sxx := 0.0
	var sxy := 0.0
	var syy := 0.0
	for dy in range(-rp, rp + 1, stride):
		var y := qy + dy
		if y < 1 or y >= h - 1:
			continue
		for dx in range(-rp, rp + 1, stride):
			var x := qx + dx
			if x < 1 or x >= w - 1 or dx * dx + dy * dy > rp * rp:
				continue
			var k := y * w + x
			var gx := _g[k + 1] - _g[k - 1]
			var gy := _g[k + w] - _g[k - w]
			jxx += gx * gx
			jxy += gx * gy
			jyy += gy * gy
			var gv := maxf(_g[k], 0.0)
			m0 += gv
			mx += gv * float(dx)
			my += gv * float(dy)
			sxx += gv * float(dx * dx)
			sxy += gv * float(dx * dy)
			syy += gv * float(dy * dy)
	var out := Vector2.ZERO
	var tr := jxx + jyy
	if tr > 1e-6:
		var half := sqrt(pow((jxx - jyy) * 0.5, 2.0) + jxy * jxy)
		if half * 2.0 / tr > WAY_COHERENT:
			var th := 0.5 * atan2(2.0 * jxy, jxx - jyy) + PI * 0.5
			out = Vector2(cos(th), sin(th))
	if out == Vector2.ZERO and m0 > 1e-6:
		var ax := mx / m0
		var ay := my / m0
		var cxx := sxx / m0 - ax * ax
		var cxy := sxy / m0 - ax * ay
		var cyy := syy / m0 - ay * ay
		var ctr := cxx + cyy
		var chalf := sqrt(pow((cxx - cyy) * 0.5, 2.0) + cxy * cxy)
		if ctr > 1e-6 and chalf * 2.0 / ctr > WAY_LONG:
			var th2 := 0.5 * atan2(2.0 * cxy, cxx - cyy)
			out = Vector2(cos(th2), sin(th2))
	if out != Vector2.ZERO and prev != Vector2.ZERO and out.dot(prev) < 0.0:
		out = -out
	return out


## How much laying the paint would put right round [param q], on average within [param rad] millimeters of it ([member _g]).
func _g_around(q: Vector2, rad: float) -> float:
	var rp := maxi(int(rad * PX), 0)
	var qx := int(q.x * PX)
	var qy := int(q.y * PX)
	var sum := 0.0
	var n := 0
	for dy in range(-rp, rp + 1):
		for dx in range(-rp, rp + 1):
			var x := qx + dx
			var y := qy + dy
			if x < 0 or y < 0 or x >= w or y >= h or dx * dx + dy * dy > rp * rp:
				continue
			sum += _g[y * w + x]
			n += 1
	return sum / float(maxi(n, 1))


## How wide what still wants the paint is at [param q] (millimeters, half of it): from [param q], the nearest it stops wanting it
## ([member _g]) across [param way] - or every way, where [param way] is ZERO - looked no further than [param most].
func _wide_at(q: Vector2, way: Vector2, most: float) -> float:
	var ways: Array = [way.orthogonal().normalized()] if way.length() > 0.0 else \
			[Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2.DOWN, Vector2(-1, 1).normalized()]
	var least := most
	var step := 0.5 / PX
	for a in ways:
		var d := a as Vector2
		var both := 0.0
		var narrow := most
		for side in [1.0, -1.0]:
			var run := 0.0
			while run + step <= most:
				var kq := _k(q + d * side * (run + step))
				if kq < 0 or _fit_mask[kq] == 0 or _g[kq] <= 0.0:
					break
				run += step
			narrow = minf(narrow, run)
			both += run
		# (...a line the stroke runs along is as wide as both sides together, kept to the nearer twice over where it lies off center)
		least = minf(least, minf(both * 0.5, narrow * 2.0) + 0.5 / PX)
	return least


## A stroke's press point by point ([param pts], a brush [param r] at its widest): as hard as makes it as wide as what still wants its
## paint across its way there ([method _wide_at]; [constant PRESS_NARROW] at the lightest touch), eased along it.
func _pressed_to(pts: PackedVector2Array, r: float) -> PackedFloat32Array:
	var n := pts.size()
	var raw_p := PackedFloat32Array()
	raw_p.resize(n)
	for i in n:
		var way := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var half := _wide_at(pts[i], way, r)
		raw_p[i] = clampf((half / maxf(r, 1e-3) - PRESS_NARROW) / (1.0 - PRESS_NARROW), 0.0, 1.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var sum := 0.0
		var c := 0
		for j in range(maxi(i - 1, 0), mini(i + 2, n)):
			sum += raw_p[j]
			c += 1
		out[i] = sum / float(c)
	return out


## What mark [param m] ([param kind], at thinness [param th]) would put right, laid as [method raster] draws it in the operation's paint:
## `Vector2(how much nearer the picture what the show draws would stand, summed over all it touches - a point made worse counting
## [constant WORSE_WEIGHT] times - and how much paint it lays)`, each in square millimeters' worth.
func _gain_of_mark(m: Dictionary, kind: String, th: float, salt: int) -> Vector2:
	return _gain_of_raster(raster(m, kind, PX, Vector2.ZERO, w, h, 1.0, salt), th)


## What a mark rastered as [param got] ([method raster]) would put right laid at thinness [param th] ([method _gain_of_mark]).
func _gain_of_raster(got: Dictionary, th: float, cc := PackedVector3Array()) -> Vector2:
	var ks: PackedInt32Array = got["k"]
	var al: PackedFloat32Array = got["a"]
	var fs: PackedFloat32Array = got.get("f", PackedFloat32Array())
	var sum := 0.0
	var laid := 0.0
	for i in ks.size():
		var k := ks[i]
		if face[k] == 0:
			continue
		var a := al[i] * th
		if a < 0.01:
			continue
		var c := _fit_pv if cc.is_empty() else color_at(cc, fs[i] if i < fs.size() else 0.0)
		var d := labs[k].distance_to(raw[k]) - _after(k, c, a).distance_to(raw[k])
		sum += d if d >= 0.0 else d * WORSE_WEIGHT
		laid += a
	return Vector2(sum, laid) / (PX * PX)


## The point of the canvas at [param q] (millimeters), or -1 off it.
func _k(q: Vector2) -> int:
	var x := int(q.x * PX)
	var y := int(q.y * PX)
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	return y * w + x


## Mark [param m] ([param kind]), laid at thinness [param th] in paint [param pv] (sRGB) - or the colors it carries, `cc` ([method
## color_at]) - on the canvas as the show's canvas blends it: each point it reaches, as much as it lays there ([method raster]).
func _lay(m: Dictionary, kind: String, th: float, pv: Vector3, salt: int) -> void:
	var got := raster(m, kind, PX, Vector2.ZERO, w, h, 1.0, salt)
	var ks: PackedInt32Array = got["k"]
	var al: PackedFloat32Array = got["a"]
	var fs: PackedFloat32Array = got.get("f", PackedFloat32Array())
	var cc: PackedVector3Array = m.get("cc", PackedVector3Array())
	for i in ks.size():
		var k := ks[i]
		if face[k] == 0:
			continue
		var a := al[i] * th
		var c := pv if cc.is_empty() else color_at(cc, fs[i] if i < fs.size() else 0.0)
		pre[k] = c * a + pre[k] * (1.0 - a)
		alp[k] = a + alp[k] * (1.0 - a)
		lin[k] = _shown(pre[k], alp[k])
		labs[k] = lab(lin[k].x, lin[k].y, lin[k].z)


## The colors paint [param pv] may be laid in (sRGB): itself first, then mixed on the palette with each of [param with] (Colors) by each
## of [constant MIX_SHARES] - pigments mixed darken as they absorb, so the mix is the weighted geometric mean of their linear light, not
## its average (teal and red a muddy brown, not a lilac).
static func _mixes(pv: Vector3, with: Array) -> PackedVector3Array:
	var out := PackedVector3Array([pv])
	var a := Vector3(_dec(pv.x), _dec(pv.y), _dec(pv.z))
	for c in with:
		var col := c as Color
		var b := Vector3(_dec(col.r), _dec(col.g), _dec(col.b))
		for sh in MIX_SHARES:
			var t := float(sh)
			var m := Vector3(pow(maxf(a.x, 1e-4), 1.0 - t) * pow(maxf(b.x, 1e-4), t), pow(maxf(a.y, 1e-4), 1.0 - t) * pow(maxf(b.y, 1e-4), t),
					pow(maxf(a.z, 1e-4), 1.0 - t) * pow(maxf(b.z, 1e-4), t))
			out.append(Vector3(pow(m.x, 1.0 / 2.2), pow(m.y, 1.0 / 2.2), pow(m.z, 1.0 / 2.2)))
	return out


## The color a mark carries at [param f] along it (its points counted from 0): `cc`, a color (sRGB) a point - one, all along it - each
## mixed on the palette or picked up from the surface ([method _mixes], [method _blend_op]).
static func color_at(cc: PackedVector3Array, f: float) -> Vector3:
	if cc.size() == 1:
		return cc[0]
	var i := clampi(int(f), 0, cc.size() - 1)
	return cc[i].lerp(cc[mini(i + 1, cc.size() - 1)], clampf(f - float(i), 0.0, 1.0))


# --- marks as their tools lay them --------------------------------------------------------------------------------------------

## What mark [param m] lays (a program's stroke: `pts`, `t`, `r`, `load`, `press` - [method Skins._Prog.done]) on a map [param px] pixels a
## millimeter from [param origin], [param ww] by [param hh]: `{k: each point it reaches, a: how much it lays there (0-1), u: when, 0-1 of
## [param natural], f: a pull's - where along it, its points counted from 0 (the color it carries there - [method color_at])}`. A dab has
## its ragged edge, its pores, its share of a load; a pull is as wide as it is pressed, thinning to its tail, its bristles streaking as its
## load runs pale; a line is crisp. [param salt] keeps one mark's grain its own. [param quick]: its grain left out - for weighing a mark
## before it is laid, never for drawing one.
static func raster(m: Dictionary, kind: String, px: float, origin: Vector2, ww: int, hh: int, natural: float, salt: int, quick := false) -> Dictionary:
	var out_k := PackedInt32Array()
	var out_a := PackedFloat32Array()
	var out_u := PackedFloat32Array()
	var pts: PackedVector2Array = m["pts"]
	var ts: PackedFloat32Array = m["t"]
	var loads: PackedFloat32Array = m.get("load", PackedFloat32Array())
	var press: PackedFloat32Array = m.get("press", PackedFloat32Array())
	var r := float(m["r"])
	var off := Vector2(fposmod(float(salt) * 17.31, 211.0), fposmod(float(salt) * 29.17, 197.0))
	if pts.is_empty():
		return {"k": out_k, "a": out_a, "u": out_u}
	if m.has("touch"):
		# A dab as its side touched: each point of the face it touched, a millimeter's cell round it, its edge wandering a little - then its
		# pores, its film, its share of a load
		var tp: PackedVector2Array = m["touch"]
		var loadt := loads[0] if not loads.is_empty() else 1.0
		var ut := ((ts[0] if not ts.is_empty() else 0.0) + DAB_MEETS) / natural
		# (...the points it touched marked once on a small map of their own, softened by the engine and cut at the middle of the soft, its edge
		# wandering a little: drawn as a disc a point, the millimeter grid the touch was found on shows as stair steps along every edge)
		var most := {}
		if tp.is_empty():
			return {"k": out_k, "a": out_a, "u": out_u}
		var lo_q := tp[0]
		var hi_q := tp[0]
		for q0 in tp:
			lo_q = Vector2(minf(lo_q.x, q0.x), minf(lo_q.y, q0.y))
			hi_q = Vector2(maxf(hi_q.x, q0.x), maxf(hi_q.y, q0.y))
		var pad := TOUCH_CELL + TOUCH_SOFT + RAGGED
		var x0 := maxi(int((lo_q.x - pad - origin.x) * px), 0)
		var y0 := maxi(int((lo_q.y - pad - origin.y) * px), 0)
		var x1 := mini(int((hi_q.x + pad - origin.x) * px) + 1, ww)
		var y1 := mini(int((hi_q.y + pad - origin.y) * px) + 1, hh)
		var bw := x1 - x0
		var bh := y1 - y0
		if bw <= 0 or bh <= 0:
			return {"k": out_k, "a": out_a, "u": out_u}
		var buf := PackedByteArray()
		buf.resize(bw * bh)
		var half := maxf(TOUCH_CELL * 0.5 * px, 0.5)
		for q0 in tp:
			var cx := (q0.x - origin.x) * px - float(x0)
			var cy := (q0.y - origin.y) * px - float(y0)
			for y in range(maxi(int(cy - half), 0), mini(int(cy + half) + 1, bh)):
				for x in range(maxi(int(cx - half), 0), mini(int(cx + half) + 1, bw)):
					buf[y * bw + x] = 255
		var img := Image.create_from_data(bw, bh, false, Image.FORMAT_L8, buf)
		# (...and softened further, as far as its edge fades in, for how far in from its edge each point is)
		var fade := img.duplicate() as Image
		var by := maxf(TOUCH_SOFT * px, 1.0)
		img.resize(maxi(int(round(float(bw) / by)), 1), maxi(int(round(float(bh) / by)), 1), Image.INTERPOLATE_LANCZOS)
		img.resize(bw, bh, Image.INTERPOLATE_BILINEAR)
		var soft := img.get_data()
		var by_f := maxf(maxf(EDGE_FADE, sqrt(float(tp.size()) * TOUCH_CELL * TOUCH_CELL / PI) * EDGE_FADE_SHARE) * px, 1.0)
		fade.resize(maxi(int(round(float(bw) / by_f)), 1), maxi(int(round(float(bh) / by_f)), 1), Image.INTERPOLATE_LANCZOS)
		fade.resize(bw, bh, Image.INTERPOLATE_BILINEAR)
		var faded := fade.get_data()
		for y in bh:
			for x in bw:
				var v := float(soft[y * bw + x]) / 255.0
				if v <= 0.02:
					continue
				var q := origin + (Vector2(float(x + x0), float(y + y0)) + Vector2(0.5, 0.5)) / px
				var cut := 0.5 + (_noise(q / RAGGED_GRAIN + off) - 0.5) * TOUCH_RAGGED if not quick else 0.5
				var a := smoothstep(cut - TOUCH_FEATHER, cut + TOUCH_FEATHER, v)
				if a > 0.0:
					if not bool(m.get("even", false)):
						a *= lerpf(EDGE_LEAST, 1.0, smoothstep(0.35, 0.9, float(faded[y * bw + x]) / 255.0))
					most[(y + y0) * ww + (x + x0)] = a
		var even := bool(m.get("even", false))
		var dep := deposit(m, salt) if not even else FILM
		# (...pressed hardest in its middle, its farthest corners least: a flat face's print on a flat brow, laid evenly to its edge, would be
		# the face's rectangle)
		var mid_q := Vector2.ZERO
		for q0 in tp:
			mid_q += q0
		mid_q /= float(tp.size())
		var far_q := 0.0
		for q0 in tp:
			far_q = maxf(far_q, q0.distance_to(mid_q))
		far_q = maxf(far_q + TOUCH_CELL, 1.0)
		for kq in most:
			var q := origin + (Vector2(float(int(kq) % ww), float(int(kq) / ww)) + Vector2(0.5, 0.5)) / px
			var pores := clampf(PORES.x + (_fbm(q / PORE_GRAIN + off * 1.7) - 0.5) * 2.0 * PORES.y, 0.0, 1.0) if not quick else PORES.x
			var a := float(most[kq]) * dep * lerpf(pores, 1.0, dep * dep) * (1.0 if even else lerpf(1.0, CORNER_LEAST, smoothstep(CORNER_FROM, 1.0, q.distance_to(mid_q) / far_q)))
			if a <= 0.004:
				continue
			out_k.append(int(kq))
			out_a.append(a)
			out_u.append(ut)
		return {"k": out_k, "a": out_a, "u": out_u}
	if kind == "dab" or pts.size() == 1:
		var c := pts[0]
		var load := loads[0] if not loads.is_empty() else 1.0
		var tip := bool(m.get("tip", false))
		var rr := r * lerpf(TIP_LEAST if tip else DAB_PRESS_LEAST, 1.0, press[0] if not press.is_empty() else 1.0)
		var ragged := TIP_RAGGED if tip else RAGGED
		var soft := TIP_SOFT if tip else EDGE_SOFT
		var reach := rr + ragged + soft
		var u := ((ts[0] if not ts.is_empty() else 0.0) + DAB_MEETS) / natural
		for y in range(maxi(int((c.y - reach - origin.y) * px), 0), mini(int((c.y + reach - origin.y) * px) + 1, hh)):
			for x in range(maxi(int((c.x - reach - origin.x) * px), 0), mini(int((c.x + reach - origin.x) * px) + 1, ww)):
				var q := origin + (Vector2(float(x), float(y)) + Vector2(0.5, 0.5)) / px
				var d := q.distance_to(c)
				if d > reach:
					continue
				var edge := rr + (_noise(q / RAGGED_GRAIN + off) - 0.5) * 2.0 * ragged if not quick else rr
				var a := clampf((edge - d) / soft + 0.5, 0.0, 1.0)
				if a <= 0.0:
					continue
				var pores := clampf(PORES.x + (_fbm(q / PORE_GRAIN + off * 1.7) - 0.5) * 2.0 * PORES.y, 0.0, 1.0) if not quick else PORES.x
				var dep := deposit(m, salt)
				a *= dep * lerpf(pores, 1.0, dep * dep) * lerpf(EDGE_LEAST, 1.0, clampf((edge - d) / minf(EDGE_FADE, rr * 0.5), 0.0, 1.0))
				if a <= 0.004:
					continue
				out_k.append(y * ww + x)
				out_a.append(a)
				out_u.append(u)
		return {"k": out_k, "a": out_a, "u": out_u}
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
	var length := maxf(cum[cum.size() - 1], 1e-3)
	var edge_w := LINE_EDGE if kind == "line" else BRUSH_EDGE
	var soft_of := 0.0 if kind == "line" else (BLEND_BELLY if kind == "blend" else BELLY)
	var best := {}
	for i in range(pts.size() - 1):
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var seg := p1 - p0
		var sl := maxf(seg.length(), 1e-4)
		var dir := seg / sl
		var nrm := Vector2(-dir.y, dir.x)
		var reach := r + edge_w
		var lo := Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)) - Vector2(reach, reach)
		var hi := Vector2(maxf(p0.x, p1.x), maxf(p0.y, p1.y)) + Vector2(reach, reach)
		for y in range(maxi(int((lo.y - origin.y) * px), 0), mini(int((hi.y - origin.y) * px) + 1, hh)):
			for x in range(maxi(int((lo.x - origin.x) * px), 0), mini(int((hi.x - origin.x) * px) + 1, ww)):
				var q := origin + (Vector2(float(x), float(y)) + Vector2(0.5, 0.5)) / px
				var v := q - p0
				var s := clampf(v.dot(dir) / sl, 0.0, 1.0)
				var dist := q.distance_to(p0 + seg * s)
				var along := cum[i] + s * sl
				var uu := along / length
				var tail := smoothstep(1.0 - Skins.TAIL_SHARE, 1.0, uu)
				var pr := lerpf(press[i], press[i + 1], s) if press.size() == pts.size() else 1.0
				var wdt := r * lerpf(PRESS_NARROW, 1.0, pr) * lerpf(1.0, Skins.TAIL_NARROW, tail)
				# (...a brush's belly: thickest along its middle, thinning out toward its edges where its hairs splay - a blending brush's the more -
				# never a band laid flat to a crisp edge; a liner's line crisp)
				var a := clampf((wdt - dist) / edge_w + 0.5, 0.0, 1.0) if soft_of <= 0.0 else \
						1.0 - smoothstep(wdt * (1.0 - soft_of) - edge_w * 0.5, wdt + edge_w * 0.5, dist)
				if a <= 0.0:
					continue
				var load := lerpf(loads[i], loads[i + 1], s) if loads.size() == pts.size() else 1.0
				var dry := clampf(1.0 - load, 0.0, 1.0)
				# ...its bristles: streaks along the way it is pulled, opening as it runs dry
				var n := _noise(Vector2(v.dot(nrm) / STREAK_ACROSS, along / STREAK_ALONG) + off) if not quick else 0.5
				var amount := LINE_STREAK if kind == "line" else clampf(STREAK.x + dry * STREAK.y, 0.0, STREAK.z)
				a *= lerpf(1.0, smoothstep(0.25, 0.65, n), amount) * lerpf(1.0, Skins.TAIL_LEFT, tail) * lerpf(DRY_LEAST, 1.0, load)
				if a <= 0.004:
					continue
				var k := y * ww + x
				var u := lerpf(ts[i], ts[i + 1], s) / natural if ts.size() == pts.size() else 0.0
				if not best.has(k) or a > float((best[k] as Vector3).x):
					best[k] = Vector3(a, minf(u, float((best[k] as Vector3).y)) if best.has(k) else u, float(i) + s)
	var out_f := PackedFloat32Array()
	for k in best:
		var bv: Vector3 = best[k]
		out_k.append(int(k))
		out_a.append(bv.x)
		out_u.append(bv.y)
		out_f.append(bv.z)
	return {"k": out_k, "a": out_a, "u": out_u, "f": out_f}


## What an operation laid, for a show: [param marks] (`[{m, th, salt}]`, [param kind]) drawn over [param rect] at [param px] -
## `{coverage: Image (L8: what each point holds of its paint, the marks laid one over another), when: Image (RGBF: the moment the first
## reached it, 0-1 of [param natural]; its load laid in already, 1; Skins.NEVER where none did), built: [Image] (RGBA8, four slots an image:
## what it holds after each of the first [constant BUILT_SLOTS] - 1 marks that reach it, and after the last), built_when: [Image] (RGBAF:
## the moments of those, 0-1; Skins.NEVER where none did), tint: Image (RGB8, sRGB: the color each point shows, where any mark carries its
## own - `cc`; the rest in [param pv]; none where none does)}`. Built up as it was laid: each point is shown at what the marks so far have
## laid there, never at what all of them come to from the first that touches it.
static func render(marks: Array, kind: String, rect: Rect2, px: float, natural: float, pv := Vector3.ZERO) -> Dictionary:
	var ww := maxi(int(ceil(rect.size.x * px)), 1)
	var hh := maxi(int(ceil(rect.size.y * px)), 1)
	# (...the colors its marks carry, where any carries its own - mixed on the palette, picked up from the surface: what the operation's own
	# layer shows at each point, its marks laid one over another, the rest in [param pv])
	var tinted := marks.any(func(mk: Dictionary) -> bool: return (mk["m"] as Dictionary).has("cc"))
	var lp := PackedVector3Array()
	var la := PackedFloat32Array()
	if tinted:
		lp.resize(ww * hh)
		la.resize(ww * hh)
	var clear := PackedFloat32Array()
	clear.resize(ww * hh)
	clear.fill(1.0)
	var first := PackedFloat32Array()
	first.resize(ww * hh)
	first.fill(Skins.NEVER)
	var count := PackedByteArray()
	count.resize(ww * hh)
	# (...each point's slots side by side in one array: a packed array taken out of an Array is written as a copy)
	var at_t := PackedFloat32Array()
	at_t.resize(ww * hh * BUILT_SLOTS)
	at_t.fill(Skins.NEVER)
	var at_c := PackedFloat32Array()
	at_c.resize(ww * hh * BUILT_SLOTS)
	# (...in the order they were laid: what a foundation painted anyway rides on the dab it was nearest, laid after them all)
	var order: Array = range(marks.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var ta: PackedFloat32Array = ((marks[a] as Dictionary)["m"] as Dictionary)["t"]
		var tb: PackedFloat32Array = ((marks[b] as Dictionary)["m"] as Dictionary)["t"]
		var fa := ta[0] if not ta.is_empty() else 0.0
		var fb := tb[0] if not tb.is_empty() else 0.0
		return fa < fb if fa != fb else a < b)
	for oi in order:
		var mk: Dictionary = marks[int(oi)]
		var got := raster(mk["m"], kind, px, rect.position, ww, hh, natural, int(mk["salt"]))
		var th := float(mk["th"])
		var ks: PackedInt32Array = got["k"]
		var al: PackedFloat32Array = got["a"]
		var us: PackedFloat32Array = got["u"]
		var fs: PackedFloat32Array = got.get("f", PackedFloat32Array())
		var cc: PackedVector3Array = (mk["m"] as Dictionary).get("cc", PackedVector3Array())
		for i in ks.size():
			var k := ks[i]
			if tinted:
				var a := al[i] * th
				lp[k] = (pv if cc.is_empty() else color_at(cc, fs[i] if i < fs.size() else 0.0)) * a + lp[k] * (1.0 - a)
				la[k] = a + la[k] * (1.0 - a)
			clear[k] *= 1.0 - al[i] * th
			if al[i] * th > 0.02:
				first[k] = minf(first[k], us[i])
				var slot := mini(int(count[k]), BUILT_SLOTS - 1)
				count[k] = mini(int(count[k]) + 1, 255)
				at_t[k * BUILT_SLOTS + slot] = us[i]
				at_c[k * BUILT_SLOTS + slot] = 1.0 - clear[k]
	var bytes := PackedByteArray()
	bytes.resize(ww * hh)
	var whens := PackedFloat32Array()
	whens.resize(ww * hh * 3)
	# (...all its slots side by side, then cut four to an image: the first four marks in one, the rest - the last of them what it holds at
	# the end - in the next; a packed array taken out of an Array is written as a copy)
	var built := PackedByteArray()
	built.resize(ww * hh * BUILT_SLOTS)
	var built_t := PackedFloat32Array()
	built_t.resize(ww * hh * BUILT_SLOTS)
	for k in ww * hh:
		bytes[k] = roundi((1.0 - clear[k]) * 255.0)
		whens[k * 3] = first[k]
		whens[k * 3 + 1] = 1.0
		whens[k * 3 + 2] = Skins.NEVER
		# (...the last slot what it holds at the end, at the last mark that reached it; slots no mark filled as the one before)
		var n := int(count[k])
		for j in BUILT_SLOTS:
			var src := mini(j, n - 1)
			var c := 0.0
			var t := Skins.NEVER
			if src >= 0:
				t = at_t[k * BUILT_SLOTS + src]
				c = at_c[k * BUILT_SLOTS + src] if j < BUILT_SLOTS - 1 else 1.0 - clear[k]
			built[k * BUILT_SLOTS + j] = roundi(clampf(c, 0.0, 1.0) * 255.0)
			built_t[k * BUILT_SLOTS + j] = t
	var cov := Image.create_from_data(ww, hh, false, Image.FORMAT_L8, bytes)
	cov.generate_mipmaps()
	var built_img: Array = []
	var built_when: Array = []
	for pg in BUILT_SLOTS / 4:
		var bb := PackedByteArray()
		bb.resize(ww * hh * 4)
		var bt := PackedFloat32Array()
		bt.resize(ww * hh * 4)
		for k in ww * hh:
			for j in 4:
				bb[k * 4 + j] = built[k * BUILT_SLOTS + pg * 4 + j]
				bt[k * 4 + j] = built_t[k * BUILT_SLOTS + pg * 4 + j]
		built_img.append(Image.create_from_data(ww, hh, false, Image.FORMAT_RGBA8, bb))
		built_when.append(Image.create_from_data(ww, hh, false, Image.FORMAT_RGBAF, bt.to_byte_array()))
	var out := {"coverage": cov, "when": Image.create_from_data(ww, hh, false, Image.FORMAT_RGBF, whens.to_byte_array()),
		"built": built_img, "built_when": built_when}
	if tinted:
		var tb := PackedByteArray()
		tb.resize(ww * hh * 3)
		for k in ww * hh:
			var c := lp[k] / la[k] if la[k] > 1e-4 else pv
			tb[k * 3] = roundi(clampf(c.x, 0.0, 1.0) * 255.0)
			tb[k * 3 + 1] = roundi(clampf(c.y, 0.0, 1.0) * 255.0)
			tb[k * 3 + 2] = roundi(clampf(c.z, 0.0, 1.0) * 255.0)
		out["tint"] = Image.create_from_data(ww, hh, false, Image.FORMAT_RGB8, tb)
	return out


## What a sponge's dab [param m] lays where it presses fully (0-1, before its pores and its edge): [constant FILM] of what is on the side
## it presses - its load's share ([constant LOAD_POWER]), the side just loaded or another ([constant OTHER_SIDE], `share`) - as hard as it
## presses ([constant PRESS_DEPOSIT], `press`), its own share of that ([method _film_of]).
static func deposit(m: Dictionary, salt: int) -> float:
	var loads: PackedFloat32Array = m.get("load", PackedFloat32Array())
	var press: PackedFloat32Array = m.get("press", PackedFloat32Array())
	var load := clampf(loads[0] if not loads.is_empty() else 1.0, 0.05, 1.0)
	var pr := clampf(press[0] if not press.is_empty() else 1.0, 0.0, 1.0)
	return FILM * pow(load, LOAD_POWER) * lerpf(PRESS_DEPOSIT, 1.0, pr) * float(m.get("share", 1.0)) * _film_of(salt)


## How many prints a sponge's load makes, each touching [param touched] points a millimeter apart, laid at thinness [param th]: as many as
## [constant TOUCH_LOAD_AREA] square millimeters of full paint holds - a thin tint's prints more.
static func _per_load(touched: int, th: float) -> int:
	return maxi(roundi(TOUCH_LOAD_AREA / maxf(float(touched) * TOUCH_CELL * TOUCH_CELL * maxf(th, 0.15), 1.0)), 3)


## What share of the film the press [param salt] lays ([constant FILM_LEAST]-1): its own, some lighter than others.
static func _film_of(salt: int) -> float:
	return lerpf(FILM_LEAST, 1.0, _hash(Vector2(float(salt) * 0.731, 5.3)))


## Value noise in [0, 1), smooth, no grid in it to see. Read from a table made once (computing it point by point is far slower).
static func _noise(q: Vector2) -> float:
	if _NOISE_TAB.is_empty():
		_noise_lock.lock()
		if _NOISE_TAB.is_empty():
			_NOISE_TAB = _noise_table()
		_noise_lock.unlock()
	var x := posmod(int(floorf(q.x * NOISE_FINE)), NOISE_SIDE)
	var y := posmod(int(floorf(q.y * NOISE_FINE)), NOISE_SIDE)
	return _NOISE_TAB[y * NOISE_SIDE + x]


## Smooth value noise over [constant NOISE_SIDE] / [constant NOISE_FINE] cells a side, wrapping round, [constant NOISE_FINE] samples a cell.
static func _noise_table() -> PackedFloat32Array:
	var cells := NOISE_SIDE / NOISE_FINE
	var out := PackedFloat32Array()
	out.resize(NOISE_SIDE * NOISE_SIDE)
	for y in NOISE_SIDE:
		for x in NOISE_SIDE:
			var q := Vector2(float(x) + 0.5, float(y) + 0.5) / float(NOISE_FINE)
			var i := Vector2(floorf(q.x), floorf(q.y))
			var f := q - i
			var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
			var a := _hash(Vector2(fposmod(i.x, cells), fposmod(i.y, cells)))
			var b := _hash(Vector2(fposmod(i.x + 1.0, cells), fposmod(i.y, cells)))
			var c := _hash(Vector2(fposmod(i.x, cells), fposmod(i.y + 1.0, cells)))
			var d := _hash(Vector2(fposmod(i.x + 1.0, cells), fposmod(i.y + 1.0, cells)))
			out[y * NOISE_SIDE + x] = lerpf(lerpf(a, b, u.x), lerpf(c, d, u.x), u.y)
	return out


static func _fbm(q: Vector2) -> float:
	return _noise(q) * 0.6 + _noise(q * 2.07 + Vector2(5.2, 1.3)) * 0.3 + _noise(q * 4.13 + Vector2(1.7, 9.2)) * 0.1


static func _hash(q: Vector2) -> float:
	var v := sin(q.x * 127.1 + q.y * 311.7) * 43758.5453
	return v - floorf(v)


# --- the canvas and the picture --------------------------------------------------------------------------------------------

func _setup(ref: Image, size_mm: Vector2, bare: Color, surface := PackedByteArray()) -> void:
	mm = size_mm
	w = maxi(int(round(size_mm.x * PX)), 1)
	h = maxi(int(round(size_mm.y * PX)), 1)
	var r := ref.duplicate() as Image
	r.convert(Image.FORMAT_RGBA8)
	# (...and kept at its own resolution, for what is finer than the canvas - [method _trace_lines])
	hi = r.duplicate() as Image
	hi_px = float(hi.get_width()) / maxf(size_mm.x, 1.0)
	_pad_edge(r)
	r.resize(w, h, Image.INTERPOLATE_BILINEAR)
	face.resize(w * h)
	raw_lin.resize(w * h)
	raw.resize(w * h)
	for k in w * h:
		var c := r.get_pixel(k % w, k / w)
		face[k] = (1 if c.a > 0.5 else 0) if surface.size() != w * h else (1 if surface[k] != 0 else 0)
		var p := c.srgb_to_linear()
		raw_lin[k] = Vector3(p.r, p.g, p.b)
		raw[k] = lab(p.r, p.g, p.b)
	_inner = face.duplicate()
	for _i in ceili(RIM_KEEP * PX):
		var was := _inner.duplicate()
		for y in h:
			for x in w:
				var k := y * w + x
				if was[k] != 0 and (x == 0 or y == 0 or x == w - 1 or y == h - 1 or was[k - 1] == 0 or was[k + 1] == 0 or was[k - w] == 0 or was[k + w] == 0):
					_inner[k] = 0
	var b := bare.srgb_to_linear()
	bare_lin = Vector3(b.r, b.g, b.b)
	pre.resize(w * h)
	pre.fill(Vector3.ZERO)
	alp.resize(w * h)
	alp.fill(0.0)
	lin.resize(w * h)
	lin.fill(bare_lin)
	labs.resize(w * h)
	labs.fill(lab(b.r, b.g, b.b))


## The surface's colors carried past its edge in picture [param img] (in place), a few points out, each from the surface beside it: shrunk
## without this, its edge is mixed with the black round it.
static func _pad_edge(img: Image) -> void:
	var iw := img.get_width()
	var ih := img.get_height()
	var data := img.get_data()
	var known := PackedByteArray()
	known.resize(iw * ih)
	for k in iw * ih:
		known[k] = 1 if data[k * 4 + 3] > 127 else 0
	for _pass in EDGE_PAD:
		var was := known.duplicate()
		for y in ih:
			for x in iw:
				var k := y * iw + x
				if was[k] == 1:
					continue
				var sum := Vector3.ZERO
				var n := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var qx: int = x + d.x
					var qy: int = y + d.y
					if qx >= 0 and qy >= 0 and qx < iw and qy < ih and was[qy * iw + qx] == 1:
						var q := (qy * iw + qx) * 4
						sum += Vector3(data[q], data[q + 1], data[q + 2])
						n += 1
				if n > 0:
					sum /= float(n)
					data[k * 4] = int(sum.x)
					data[k * 4 + 1] = int(sum.y)
					data[k * 4 + 2] = int(sum.z)
					known[k] = 1
	img.set_data(iw, ih, false, Image.FORMAT_RGBA8, data)


## Which of [param creams] (laid whole) the most points of the picture stand nearest, by vote (every third point), or -1: a sum would
## favor a grey between the white and the rust over the white most of the face is.
func _vote(creams: Array) -> int:
	var votes := PackedInt32Array()
	votes.resize(creams.size())
	var labs_c := PackedVector3Array()
	for c in creams:
		var p := (c as Color).srgb_to_linear()
		labs_c.append(lab(p.r, p.g, p.b))
	for k in range(0, w * h, 3):
		if face[k] == 0:
			continue
		var best := -1
		var bd := INF
		for i in labs_c.size():
			var d := labs_c[i].distance_to(raw[k])
			if d < bd:
				bd = d
				best = i
		if best >= 0:
			votes[best] += 1
	var most := -1
	for i in creams.size():
		if votes[i] > 0 and (most < 0 or votes[i] > votes[most]):
			most = i
	return most


## How light the picture's ground stands round each point, as a share of its middle [param mid] (linear): the luminance of the points
## nearer the ground [param g_lab] than any of [param others], spread smooth over the surface [constant SHADE_BLUR] millimeters (each
## point's share of ground weighing it), and held to [constant SHADE_RANGE] - 1 where no ground is near.
func _ground_shade(others: PackedVector3Array, g_lab: Vector3, mid: Vector3) -> PackedFloat32Array:
	var mid_l := maxf(mid.x * 0.2126 + mid.y * 0.7152 + mid.z * 0.0722, 1e-4)
	var lum := PackedFloat32Array()
	lum.resize(w * h)
	var wt := PackedFloat32Array()
	wt.resize(w * h)
	for k in w * h:
		if face[k] == 0:
			continue
		var near := true
		for l in others:
			if l.distance_to(raw[k]) < g_lab.distance_to(raw[k]):
				near = false
				break
		if near:
			wt[k] = 1.0
			lum[k] = (raw_lin[k].x * 0.2126 + raw_lin[k].y * 0.7152 + raw_lin[k].z * 0.0722) / mid_l
	# (spread by the engine: the weighed light and its weight each shrunk and grown back, one over the other)
	var by := maxf(SHADE_BLUR * PX, 1.0)
	var spread := func(vals: PackedFloat32Array) -> PackedFloat32Array:
		var img := Image.create_from_data(w, h, false, Image.FORMAT_RF, vals.to_byte_array())
		img.resize(maxi(int(round(float(w) / by)), 1), maxi(int(round(float(h) / by)), 1), Image.INTERPOLATE_BILINEAR)
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		return img.get_data().to_float32_array()
	var lw := PackedFloat32Array()
	lw.resize(w * h)
	for k in w * h:
		lw[k] = lum[k] * wt[k]
	var sl: PackedFloat32Array = spread.call(lw)
	var sw: PackedFloat32Array = spread.call(wt)
	var out := PackedFloat32Array()
	out.resize(w * h)
	for k in w * h:
		out[k] = clampf(sl[k] / sw[k], SHADE_RANGE.x, SHADE_RANGE.y) if sw[k] > 0.05 else 1.0
	return out


## The picture's ground is the foundation's paint: the picture balanced, channel by channel, so the middle of what stands nearest
## [param ground] of [param creams] becomes it - its light taken out by the bare surface's picture (a white face would otherwise stand
## tan), and matched as it was, a rust thinned over the white would be pink.
func _ground_to(ground: Color, creams: Array) -> void:
	var gp := ground.srgb_to_linear()
	var g_lab := lab(gp.r, gp.g, gp.b)
	var others := PackedVector3Array()
	for c in creams:
		var p := (c as Color).srgb_to_linear()
		var l := lab(p.r, p.g, p.b)
		if l.distance_to(g_lab) > 0.5:
			others.append(l)
	var rs := PackedFloat32Array()
	var gs := PackedFloat32Array()
	var bs := PackedFloat32Array()
	for k in range(0, w * h, 2):
		if face[k] == 0:
			continue
		var near := true
		for l in others:
			if l.distance_to(raw[k]) < g_lab.distance_to(raw[k]):
				near = false
				break
		if near:
			rs.append(raw_lin[k].x)
			gs.append(raw_lin[k].y)
			bs.append(raw_lin[k].z)
	if rs.size() < 16:
		return
	rs.sort()
	gs.sort()
	bs.sort()
	var mid := Vector3(rs[rs.size() / 2], gs[gs.size() / 2], bs[bs.size() / 2])
	var gain := Vector3(clampf(gp.r / maxf(mid.x, 1e-4), GAIN_RANGE.x, GAIN_RANGE.y), clampf(gp.g / maxf(mid.y, 1e-4), GAIN_RANGE.x, GAIN_RANGE.y),
		clampf(gp.b / maxf(mid.z, 1e-4), GAIN_RANGE.x, GAIN_RANGE.y))
	# ...and its light taken out where it falls off (a flat field): how light the ground stands round each point, from the ground's own
	# points spread smooth over the surface ([constant SHADE_BLUR]), divided out - a painted picture's soft shadow at the rim and beside the
	# nose is its light, not paint (the mask is lit by the table's own light)
	var shade := _ground_shade(others, g_lab, mid)
	for k in w * h:
		var f := shade[k]
		var q := Vector3(minf(raw_lin[k].x * gain.x / f, 1.0), minf(raw_lin[k].y * gain.y / f, 1.0), minf(raw_lin[k].z * gain.z / f, 1.0))
		raw_lin[k] = q
		raw[k] = lab(q.x, q.y, q.z)


## How far the canvas stands from the picture itself, on average over the surface.
func off() -> float:
	var sum := 0.0
	var n := 0
	for k in w * h:
		if face[k] != 0:
			sum += labs[k].distance_to(raw[k])
			n += 1
	return sum / maxf(float(n), 1.0)


## The share of the surface still more than [constant NEED] off the picture itself.
func left() -> float:
	var over := 0
	var n := 0
	for k in w * h:
		if face[k] != 0:
			n += 1
			over += 1 if labs[k].distance_to(raw[k]) >= NEED else 0
	return float(over) / maxf(float(n), 1.0)


## The canvas as a picture (sRGB), clear off the surface.
func picture() -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for k in w * h:
		var q := lin[k]
		img.set_pixel(k % w, k / w, Color(q.x, q.y, q.z, 1.0).linear_to_srgb() if face[k] != 0 else Color(0, 0, 0, 0))
	return img
