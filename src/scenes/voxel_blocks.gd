extends GhostScene

## Voxel blocks - an isometric heightfield equalizer.
##
## A grid of iso cubes whose stack height tracks the spectrum, a 3D equalizer terrain. By seed it
## is one of three scales (see [constant SCALES]):
##   plot    - a small grid held centered in the frame.
##   terrace - a mid grid that just overflows the frame, stacks running tall.
##   city    - thousands of blocks spilling off every edge, the camera down among them like a
##             skyline. City blocks carry a structural base height so the skyline stands in
##             quiet, the spectrum bouncing on top.
## The iso squash and the color scheme are sampled too, in any of [Scheme]'s moods. An
## [Activation] decides who moves: with sparsity some columns stay rooted while others rise and
## fall. Three flat faces per cube, painted back-to-front; always at least a one-block floor so
## it reads in silence.

## The mood brightness the face shading was tuned against; exposure is relative to it, so only
## the mood's own value shifts it.
const NOMINAL_VAL := 0.85

## The scales this equalizer is built at. `over` > 0 means the grid overflows the frame (the
## camera down among the blocks); `base` is a structural floor so a skyline stands in silence.
const SCALES := {
	"plot": {"grid": [5, 10], "over": [0.0, 0.0], "max_h": [0.09, 0.20], "base": [0.0, 0.0]},
	"terrace": {"grid": [11, 20], "over": [1.0, 1.4], "max_h": [0.18, 0.34], "base": [0.0, 0.14]},
	"city": {"grid": [26, 44], "over": [1.5, 1.9], "max_h": [0.14, 0.28], "base": [0.18, 0.40]},
}

var _f: AudioFeatures = AudioFeatures.new()
var _h := PackedFloat32Array()    # eased column heights, 0..1
var _act: Activation
var _sch: Scheme


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a
## storyboard entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"scale": {"label": "Scale", "type": "choice", "options": "SCALES", "default": null,
		"blurb": "The scale the equalizer is built at: a small plot, a terrace that overflows the frame, or a vast city with the camera down among the blocks."},
	"terrace_still": {"label": "Terrace stillness", "type": "num", "range": [0.2, 0.65], "default": null,
		"blurb": "How many of a terrace's columns stand still as a skyline instead of moving with the music."},
	"city_still": {"label": "City stillness", "type": "num", "range": [0.45, 0.8], "default": null,
		"blurb": "How many of a city's columns stand still as a skyline instead of moving with the music."},
	"tile": {"label": "Tile size", "type": "num", "range": [0.050, 0.095], "default": null,
		"blurb": "How wide each block's tile is, when the build is a small plot."},
	"pitch": {"label": "View pitch", "type": "num", "range": [0.40, 0.66], "default": null,
		"blurb": "How steeply the view looks down on the blocks."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	framing = "field"
	# Blocks are neutral matter: any mood paints them.
	_sch = Scheme.pick(rng)
	var sname := String(choice("scale", rng))
	var sc: Dictionary = SCALES[sname]
	var gr: Array = sc["grid"]
	var ov: Array = sc["over"]
	var mh: Array = sc["max_h"]
	var bs: Array = sc["base"]
	var grid := rng.randi_range(int(gr[0]), int(gr[1]))
	var base := rng.randf_range(float(bs[0]), float(bs[1]))
	# The bigger the build, the more structural it leans: more rooted columns, a standing
	# skyline. A small plot is often all-active.
	var sparsity: float
	if sname == "plot":
		sparsity = 0.0 if rng.randf() < 0.4 else rng.randf_range(0.35, 0.7)
	elif sname == "terrace":
		sparsity = number("terrace_still", rng)
	else:
		sparsity = number("city_still", rng)
	_act = Activation.new(grid * grid, rng, sparsity)
	# Tall blocks travel toward the accent hue, so height is a color axis on the scheme.
	var to_accent := fposmod(_sch.accent - _sch.hue + 0.5, 1.0) - 0.5
	return {
		"grid": grid,
		"scale": sname,
		"mood": _sch.name,
		"over": rng.randf_range(float(ov[0]), float(ov[1])),   # >0 => span the frame
		"tile": number("tile", rng),                 # plot tile half-width
		"pitch": number("pitch", rng),                  # iso squash
		"max_h": rng.randf_range(float(mh[0]), float(mh[1])),
		"base": base,                                          # structural floor (skyline)
		"hue": _sch.hue,
		"hue_h": to_accent * rng.randf_range(0.35, 1.1),       # hue shift with height
		"hue_pos": to_accent * rng.randf_range(0.0, 0.5),      # hue gradient across the grid
		"swirl": rng.randf() < 0.5,                            # radial vs. linear spectrum map
	}


func update(f: AudioFeatures, delta: float) -> void:
	_f = f
	tick(f, delta)
	_act.update(f.energy + 0.4 * f.beat, delta)
	var g := int(params.grid)
	if _h.size() != g * g:
		_h.resize(g * g)
	var swirl: bool = params.swirl
	var base: float = params.base
	for gy in g:
		for gx in g:
			var idx := gx * g + gy
			var t: float
			if swirl:
				var dx := float(gx) - (g - 1) * 0.5
				var dy := float(gy) - (g - 1) * 0.5
				t = sqrt(dx * dx + dy * dy) / (g * 0.7)
			else:
				t = float(idx) / float(g * g - 1)
			var spec := _f.sample(clampf(t, 0.0, 1.0))
			# City: a structural base, the spectrum bouncing on top (only on activated columns;
			# rooted ones hold the skyline).
			var target: float
			if base > 0.0:
				target = base + (1.0 - base) * spec * (0.25 + 0.75 * _act.level(idx))
			else:
				target = spec * (0.2 + 0.8 * _act.level(idx))
			_h[idx] = lerpf(_h[idx], target, 0.18)
	queue_redraw()


func _draw() -> void:
	begin_draw()
	var u := unit()
	var g := int(params.grid)
	var over: float = params.over
	# City sizes tiles to overflow the frame; plot uses the fixed centered tile.
	var tw: float = (size.x * over) / float(g) * 0.5 if over > 0.0 else float(params.tile) * u
	var th: float = tw * float(params.pitch)            # iso squash: how steeply we look down
	var bh: float = float(params.max_h) * u
	var hue: float = params.hue
	var hue_h: float = params.hue_h
	var hue_pos: float = params.hue_pos

	# Back-to-front: outer gy, inner gx keeps each tile in front of the one behind.
	for gy in g:
		for gx in g:
			var idx := gx * g + gy
			var top := maxf(1.0, _h[idx] * bh)         # min 1px stack -> valid faces
			var cx := float(gx - gy) * tw
			var cy := (float(gx + gy) - float(g - 1)) * th
			var hbias := hue_pos * (float(gx + gy) / float(2 * g))   # gradient across grid
			_draw_cube(Vector2(cx, cy), tw, th, top, _h[idx], fposmod(hue + hbias, 1.0), hue_h)


# One iso cube: front-left and front-right side quads, then the top diamond.
func _draw_cube(base: Vector2, tw: float, th: float, top: float, e: float, hue: float, hue_h: float) -> void:
	var h := fposmod(hue + hue_h * e, 1.0)
	var lift := Vector2(0, -top)
	var n_b := base + Vector2(0, -th)
	var e_b := base + Vector2(tw, 0)
	var s_b := base + Vector2(0, th)
	var w_b := base + Vector2(-tw, 0)
	var n_t := n_b + lift
	var e_t := e_b + lift
	var s_t := s_b + lift
	var w_t := w_b + lift

	var lit := (0.26 + 0.6 * e) / NOMINAL_VAL
	# Faces differ only in how much light they catch; the mood decides the character they catch
	# it with (an ash city is gray and dim, a toxic one glares). Dividing by NOMINAL_VAL keeps a
	# mid-brightness mood at nominal exposure.
	var left_face := _sch.color(h, 0.85, lit * 0.55)
	var right_face := _sch.color(h, 0.85, lit * 0.86)
	var top_face := _sch.color(h, 0.62, lit + 0.18 / NOMINAL_VAL)

	draw_colored_polygon(PackedVector2Array([w_t, s_t, s_b, w_b]), left_face)
	draw_colored_polygon(PackedVector2Array([s_t, e_t, e_b, s_b]), right_face)
	draw_colored_polygon(PackedVector2Array([n_t, e_t, s_t, w_t]), top_face)
