extends Scene3D

## Terrain city - blocks rising as a city over real 3D terrain, growing nonlinearly.
##
## The metropolis idea on the [Terrain] foundation: a [Swarm] development field creeps across a
## landscape (rolling hills / mesa), and where it has grown, blocks stand on the surface, plumb
## (the street grid, not any lean, keeps the field from being a rigid lattice; see _heading).
## Heights are driven by development x a per-block spectral band (nonlinear), so the skyline
## rises with the music. Some plots detach, their blocks floating a little off the ground. The
## camera orbits under a wide lens; the city grows over time from a few seeds.
##
## Sampled per session: the terrain (one of four landforms under a climate that suits it), the
## layout (sparse dendritic arms, a broad sprawl, thin ribbons along ridges, or several towns),
## the skyline law (even heights, or a rare few spires), and a [Scheme] mood coloring the
## blocks, developed districts walking toward its accent.

## Which climates suit which landform.
const TERRAINS := {
	"hills":   ["temperate", "verdant", "tundra", "arid"],
	"mesa":    ["arid", "temperate"],
	"valleys": ["verdant", "temperate", "tundra"],
	"canyon":  ["arid", "temperate"],
}
## City layouts. The ridged "arm" field's frequency and how hard off-ridge plots are penalized
## decide the plan together, so they are sampled as a set: high frequency plus a hard penalty
## gives thin ribbons, low frequency plus a soft one gives sprawl.
const LAYOUTS := {
	"dendritic": {"arm": [1.6, 2.4], "penalty": 0.90, "band": [0.46, 0.64], "cores": [1, 2], "detach": 0.12},
	"sprawl":    {"arm": [0.9, 1.4], "penalty": 0.45, "band": [0.35, 0.60], "cores": [2, 3], "detach": 0.08},
	"ribbon":    {"arm": [2.6, 3.6], "penalty": 1.10, "band": [0.52, 0.70], "cores": [1, 1], "detach": 0.15},
	"towns":     {"arm": [2.0, 3.0], "penalty": 0.70, "band": [0.44, 0.62], "cores": [3, 4], "detach": 0.10},
}
## Skyline laws: how tall potential is distributed over the plots. A high exponent means almost
## everything is low with a rare tower; a low one an even mid-rise mass.
const SKYLINES := {
	"spires":  {"exp": 4.6, "hbase": 0.7, "hspan": 3.4, "foot": 0.9, "sky": 0.06},
	"even":    {"exp": 1.4, "hbase": 1.1, "hspan": 1.2, "foot": 0.7, "sky": 0.02},
	"stepped": {"exp": 3.2, "hbase": 0.9, "hspan": 2.5, "foot": 1.0, "sky": 0.05},
	"slabs":   {"exp": 2.0, "hbase": 0.8, "hspan": 1.8, "foot": 1.5, "sky": 0.03},
}

var C := 30                      # city grid is C x C plots - density is sampled, not fixed

var _f: AudioFeatures = AudioFeatures.new()
var _terrain: Terrain
var _dev: Swarm
var _detach := PackedFloat32Array()   # per-plot float-off height (0 = grounded)
var _thresh := PackedFloat32Array()   # per-plot development level needed before a building rises
var _grown := PackedFloat32Array()    # per-plot BUILT height 0..1, eased up over time (starts small)
var _foot := PackedFloat32Array()     # per-plot footprint scale (skewed: many small, a few big anchors)
var _hclass := PackedFloat32Array()   # per-plot MAX height potential (reached only at critical mass)
var _sky := PackedFloat32Array()      # per-plot "tower from the start" propensity (rare, for variety)
var _phase := PackedFloat32Array()    # per-plot phase for the slow rearrange wobble
## Per-plot heading, in radians: which way the block's footprint faces. It keeps the city from
## being one rigid lattice (see the roll in [method build_params]) while every building stays
## plumb. A lean toward the terrain normal would not do: the normal is a nearest-cell finite
## difference of a fractal heightfield, so neighboring towers would lean independently and read
## as a city falling over. A heading mimics real platting: a dominant grid, districts on their
## own alignment, plots a degree or two off true.
var _heading := PackedFloat32Array()
var _maturity := 0.0                  # 0..1, rises over the scene: thresholds drop -> arms thicken, gaps fill
var _forge := FrameForge.new()        # off-thread frame builder (FrameForge contract)
var _cores: Array = []                # the 1-2 valley cells the city grows out from (re-pinned each frame)
var _light_az := 0.0
var _light_el := 0.5
var _light_dir := 1.0
var _hue := 0.0
var _hue_dev := 0.25      # hue walk toward the scheme accent per unit development
var _hue_elev := 0.12     # ... and per unit terrain height
var _sat := 0.45          # block saturation, from the mood
var _vmul := 1.0          # block value multiplier, from the mood
var _glow := 0.0
var _yaw := 0.0
var _dist := 7.5
var _pitch := 0.5
var _beat_prev := 0.0


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a
## storyboard entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"landform": {"label": "Landform", "type": "choice", "options": "TERRAINS", "default": null,
		"blurb": "The land the city is built on: hills, a mesa, valleys or a canyon."},
	"layout": {"label": "Layout", "type": "choice", "options": "LAYOUTS", "default": null,
		"blurb": "The city's plan: branching dendritic arms, a loose sprawl, thin ribbons, or separate towns."},
	"skyline": {"label": "Skyline", "type": "choice", "options": "SKYLINES", "default": null,
		"blurb": "How building heights are spread over the plots: mostly low with rare spires, an even mid-rise mass, stepped, or slabs."},
	"plots": {"label": "Plots", "type": "num", "range": [26, 34], "default": null,
		"blurb": "How many plots each side of the city grid has; fewer makes bigger blocks on a smaller town."},
	"distance": {"label": "Camera distance", "type": "num", "range": [6.5, 8.5], "default": null,
		"blurb": "How far from the city the camera orbits."},
	"pitch": {"label": "Camera pitch", "type": "num", "range": [0.34, 0.55], "default": null,
		"blurb": "How steeply the camera looks down on the city."},
	"sun_height": {"label": "Sun height", "type": "num", "range": [0.34, 0.52], "default": null,
		"blurb": "How high the sun stands; a low sun casts long shadows."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	framing = "field"
	var ttype := String(choice("landform", rng))
	var climates: Array = TERRAINS[ttype]
	var climate := String(climates[rng.randi() % climates.size()])
	# Plot size is the city's grain: a coarse grid gives big blocks on a small town, a fine one
	# a dense field of smaller buildings over the same land.
	C = number("plots", rng)
	_terrain = Terrain.new()
	_terrain.build(rng, ttype, 3.0, rng.randf_range(0.35, 0.55), null, climate)
	# Buildings take a [Scheme] mood (concrete-gray, brass, bone, or a lit-up violet or teal night).
	var sch := Scheme.among(["ash", "bone", "brass", "sodium", "dawn", "glacier",
		"abyss", "violet", "teal", "ember", "rose"], rng)
	_hue = sch.hue
	_sat = sch.sat * 0.65
	_vmul = sch.val * 1.15
	# Development walks the blocks toward the accent (the short way round), so the built-up core
	# is a different, related color from the frontier.
	var to_accent := fposmod(sch.accent - sch.hue + 0.5, 1.0) - 0.5
	_hue_dev = to_accent * rng.randf_range(0.35, 0.9)
	_hue_elev = to_accent * rng.randf_range(0.1, 0.4)
	var layout := String(choice("layout", rng))
	var lay: Dictionary = LAYOUTS[layout]
	var skyline := String(choice("skyline", rng))
	var sky_law: Dictionary = SKYLINES[skyline]
	# The city grows from a few cores, each seeded in a low valley (easy ground): sample a handful
	# of central cells and keep the lowest. Development creeps outward from there; the cores are
	# re-pinned every frame so the origin never fades. How many cores is the layout's call.
	_dev = Swarm.new(C, C, Swarm.GROW, rng, 0)
	for k in rng.randi_range(int(lay.cores[0]), int(lay.cores[1])):
		var bx := C / 2
		var by := C / 2
		var blo := 1e9
		for _t in 10:
			var cx := rng.randi_range(int(C * 0.28), int(C * 0.72))
			var cy := rng.randi_range(int(C * 0.28), int(C * 0.72))
			var hh: float = _terrain.height_at(_plot_wx(cx), _plot_wz(cy))
			if hh < blo:
				blo = hh
				bx = cx
				by = cy
		_cores.append(Vector2i(bx, by))
		_dev.inject(bx, by, 1.0)
	# Per-plot build threshold, biased by terrain height: valleys need little development, so they
	# fill first; hillsides need more; peaks stay bare. A little noise ragged-ifies the frontier.
	_thresh.resize(C * C)
	_grown.resize(C * C)
	_foot.resize(C * C)
	_hclass.resize(C * C)
	_sky.resize(C * C)
	_phase.resize(C * C)
	_heading.resize(C * C)
	# The street grid: one dominant alignment, a second for a district platted on its own (which
	# stops a grid reading as wallpaper), and a couple of degrees of per-plot slop. A square
	# footprint repeats every quarter turn, so the second grid is offset by well inside one.
	var grid_a := rng.randf() * TAU
	var grid_b := grid_a + rng.randf_range(0.30, 1.10)
	var slop := rng.randf_range(0.012, 0.045)
	# The district is a smooth function of position (two low harmonics across the grid), so the
	# second alignment is a contiguous quarter of the city, not salt and pepper.
	var dk := Vector2(rng.randf_range(1.2, 3.0), rng.randf_range(1.2, 3.0))
	var dp := Vector2(rng.randf() * TAU, rng.randf() * TAU)
	var dthr := rng.randf_range(0.35, 1.15)
	# A ridged "arm" field: its branching high ridges become the channels the city builds along,
	# so development reads as dendritic arms reaching out from the core rather than a filled blob.
	var armf := Field.make("ridged", rng.randi(), rng.randf_range(float(lay.arm[0]), float(lay.arm[1])), 3)
	var band0: float = float(lay.band[0])
	var band1: float = float(lay.band[1])
	var penalty: float = float(lay.penalty)
	var hexp: float = float(sky_law.exp)
	for cy in C:
		for cx in C:
			var i := cy * C + cx
			var p := Vector2(float(cx) / float(C - 1) - 0.5, float(cy) / float(C - 1) - 0.5) * 2.0
			var elev: float = clampf(_terrain.height_at(_plot_wx(cx), _plot_wz(cy)), 0.0, 1.0)
			var arm: float = armf.at(p)
			# Threshold = valley bias + an off-arm penalty (the layout sets its strength): on an
			# arm ridge in a valley a plot builds first; between arms and up the hills it needs far
			# more development. A preference, not a hard gate (a hard gate starved a rugged map of
			# any city). Elevation adds a gentle bias; noise ragged-ifies the frontier.
			_thresh[i] = 0.05 + 0.2 * elev + (1.0 - smoothstep(band0, band1, arm)) * penalty + rng.randf_range(-0.03, 0.05)
			_grown[i] = 0.0
			# Footprint and max-height potential, distributed by the skyline law: a steep exponent
			# leaves most plots modest with a rare big anchor, a shallow one an even mid-rise mass.
			# Height is realized only once the district hits critical mass (see the draw).
			var big := pow(rng.randf(), hexp)
			_foot[i] = 0.5 + float(sky_law.foot) * big
			_hclass[i] = float(sky_law.hbase) + float(sky_law.hspan) * big + rng.randf_range(-0.1, 0.3)
			# A rare few plots are skyscrapers from the start; most are 0 (grow up naturally).
			_sky[i] = rng.randf_range(0.55, 1.0) if rng.randf() < float(sky_law.sky) else 0.0
			_phase[i] = rng.randf() * TAU
			var district := sin(p.x * dk.x + dp.x) + sin(p.y * dk.y + dp.y)
			_heading[i] = (grid_b if district > dthr else grid_a) + rng.randf_range(-slop, slop)
	# Per-plot detach: a few districts float off the ground (how many is the layout's).
	_detach.resize(C * C)
	for i in C * C:
		_detach[i] = rng.randf_range(0.10, 0.30) if rng.randf() < float(lay.detach) else 0.0
	lens.fov = rng.randf_range(56.0, 72.0)
	_dist = number("distance", rng)
	_pitch = number("pitch", rng)
	_yaw = rng.randf() * TAU
	# A low key light so the mountains and skyline cast long, gently sweeping shadows.
	_light_az = rng.randf() * TAU
	_light_dir = 1.0 if rng.randf() < 0.5 else -1.0
	_light_el = number("sun_height", rng)
	_terrain.set_light(_light_az, _light_el)
	return {"type": ttype, "climate": climate, "mood": sch.name,
		"layout": layout, "skyline": skyline, "grid": C}


func _plot_wx(cx: int) -> float:
	return (float(cx) / float(C - 1) - 0.5) * 2.0 * _terrain.half


func _plot_wz(cy: int) -> float:
	return (float(cy) / float(C - 1) - 0.5) * 2.0 * _terrain.half


func update(f: AudioFeatures, delta: float) -> void:
	_f = f
	tick(f, delta)
	drift_view(f, 0.012, 0.018)
	# Burst then decay: growth is fast in the opening seconds and eases to a slow crawl, so even
	# a short scene (a few seconds on an energetic passage) bursts into a small city up front while
	# a long one keeps creeping. `_life` starts near 0.6 after the pre-warm, which already banks
	# some burst growth. The decay is fast (about 1 s): a brief opener, not a fill.
	var burst: float = 1.0 + 3.5 * exp(-_life * 0.7)
	# Nonlinear growth drive: beats lunge development outward through a spike curve.
	var drive := (1.0 + 1.1 * Nonlinear.apply("spike", clampf(0.7 * f.energy + f.beat, 0.0, 1.0), 2.0)) * (0.7 + 0.3 * burst)
	for core in _cores:
		_dev.inject(core.x, core.y, 1.0)          # keep the origin cores alive
	_dev.step(drive, delta, 0.015)
	# The city matures over the scene: effective thresholds drop, so the arms thicken a little but
	# stay sparse and dendritic, never a solid blob. Slow base rate (the burst supplies the pop).
	_maturity = minf(1.0, _maturity + delta * 0.05 * burst)
	# Ease each plot's built height toward its current maturity: buildings start small and grow
	# taller as their district matures; the most developed plots grow tallest.
	var rise := delta * 0.35 * burst
	for cy in C:
		for cx in C:
			var i := cy * C + cx
			var thr: float = maxf(0.04, float(_thresh[i]) - _maturity * 0.1)
			var target: float = clampf((_dev.at(cx, cy) - thr) / maxf(0.05, 1.0 - thr), 0.0, 1.0)
			_grown[i] = move_toward(float(_grown[i]), target, rise)
	_glow = lerpf(_glow, clampf(0.3 * f.energy + 0.5 * f.beat, 0.0, 1.0), 1.0 - exp(-5.0 * delta))
	_yaw += delta * (0.08 + 0.16 * f.energy)
	lens.orbit(Vector3(0.0, _terrain.relief * 0.25, 0.0), _dist, _yaw, _pitch + 0.04 * sin(_life * 0.13))
	# Drift the key light and refresh the terrain's sweeping cast shadows.
	_light_az += delta * 0.035 * _light_dir
	_terrain.set_light(_light_az, _light_el)
	_terrain.step_light(delta)
	# Snapshot the frame into a job for the worker (see FrameForge): swarm and grown fields are
	# duplicated (main keeps stepping them), immutable-after-build plot arrays and the terrain go
	# by reference (its light writes are benign in-place float updates), the lens is copied.
	var job := CityJob.new()
	job.f = f
	job.c = C
	job.u = unit()
	job.life = _life
	job.glow = _glow
	job.hue = _hue
	job.hue_dev = _hue_dev
	job.hue_elev = _hue_elev
	job.sat = _sat
	job.vmul = _vmul
	job.maturity = _maturity
	job.reveal = view.reveal
	job.terrain = _terrain
	job.tex_rid = Terrain.detail_texture().get_rid()
	job.dev = _dev.f.duplicate()
	job.grown = _grown.duplicate()
	job.detach = _detach
	job.foot = _foot
	job.hclass = _hclass
	job.sky = _sky
	job.phase = _phase
	job.yaw = _heading
	job.lens = Lens3D.new()
	job.lens.eye = lens.eye
	job.lens.look = lens.look
	job.lens.up = lens.up
	job.lens.fov = lens.fov
	job.lens.near = lens.near
	_forge.kick(job.run, {}, self, job)   # retain: a Callable alone will not keep the job alive


func _draw() -> void:
	begin_draw()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_forge.submit(self)


## The whole frame off the main thread (the FrameForge job): shadow raster, building
## realization, terrain merge, painter sort, batch runs. Reads only its own members.
class CityJob:
	extends RefCounted

	var f: AudioFeatures
	var c := 30
	var u := 1.0
	var life := 0.0
	var glow := 0.0
	var hue := 0.0
	var hue_dev := 0.25
	var hue_elev := 0.12
	var sat := 0.45
	var vmul := 1.0
	var maturity := 0.0
	var reveal := 1.0
	var terrain: Terrain
	var tex_rid := RID()
	var lens: Lens3D
	var dev := PackedFloat32Array()
	var grown := PackedFloat32Array()
	var detach := PackedFloat32Array()
	var foot := PackedFloat32Array()
	var hclass := PackedFloat32Array()
	var sky := PackedFloat32Array()
	var phase := PackedFloat32Array()
	var yaw := PackedFloat32Array()

	func run(_s: Dictionary) -> Array:
		lens.prepare()
		var lit := clampf(0.7 + 0.4 * glow + 0.3 * f.energy, 0.4, 1.4)
		var bw := terrain.half / float(c) * 0.62          # block half-footprint (world)
		var bgain := 0.5 + 0.3 * f.energy
		# How deep each building is sunk into the terrain: the merged land hides the buried part,
		# so the visible base is ragged, never a clean line.
		var embed: float = 0.35 * terrain.relief + 0.14
		# Pass A: compute every building and rasterize it into the light-space shadow map; this
		# must finish before shading, since a building shadows the ground and other buildings.
		var shadow := ShadowField.new()
		shadow.build(terrain.light_dir(), Vector3(-terrain.half, -terrain.relief, -terrain.half),
			Vector3(terrain.half, terrain.relief + 3.0, terrain.half))
		var blds: Array = []
		for cy in c:
			for cx in c:
				if reveal < 0.02:                       # still fading the terrain in - no buildings yet
					break
				var i := cy * c + cx
				var grown_i: float = grown[i]
				if grown_i < 0.02:                      # nothing built here yet (a gap / bare peak)
					continue
				var wx := (float(cx) / float(c - 1) - 0.5) * 2.0 * terrain.half
				var wz := (float(cy) / float(c - 1) - 0.5) * 2.0 * terrain.half
				var ground := terrain.height_at(wx, wz) * terrain.relief
				var float_off: float = detach[i]
				var dv := dev[i]
				var react := f.sample(clampf(terrain.height_at(wx, wz) + 0.5, 0.0, 1.0))
				# A slow per-plot wobble keeps the built skyline rearranging over time.
				var wob := 0.85 + 0.28 * sin(life * 0.12 + float(phase[i]))
				# Critical mass: blocks are built small and reach their tall potential as their
				# district densifies and the city matures; a rare few (`sky`) tower from the start.
				var crit := clampf(dv * lerpf(0.28, 1.0, maturity), 0.0, 1.0)
				var realize := clampf(maxf(Nonlinear.apply("spike", crit, 2.4), float(sky[i])), 0.0, 1.0)
				var tall := lerpf(0.5, float(hclass[i]), realize)
				var h := grown_i * tall * (0.42 + 0.4 * bgain + 0.5 * react) * wob
				var bw_i := bw * float(foot[i])
				# Plumb, and turned on its own heading: the buildings do not follow the ground
				# (see _heading).
				var up := Vector3.UP
				var ya: float = yaw[i]
				var cy_ := cos(ya)
				var sy_ := sin(ya)
				var bx := Vector3(cy_, 0.0, sy_)
				var bz := Vector3(-sy_, 0.0, cy_)
				# Sink the base below the surface so its bottom is buried; the top stays put.
				var base := Vector3(wx, ground + float_off - embed, wz)
				var htot := h + embed
				var bhue := fposmod(hue + hue_elev * terrain.height_at(wx, wz) + hue_dev * dv, 1.0)
				# The terrain also shadows the building (a block in a hill's cast shadow darkens).
				var tsh: float = terrain.shadow_at(wx, wz)
				var blit := clampf(0.18 + 0.5 * dv + 0.5 * react + 0.6 * glow, 0.05, 1.2) * lit * (0.35 + 0.65 * tsh)
				var ext := shadow.add_box(base, up, bx, bz, bw_i, htot)   # rasterize + self-shadow bias
				blds.append({"base": base, "up": up, "bx": bx, "bz": bz, "w": bw_i, "h": htot,
					"hue": bhue, "lit": blit, "ext": ext})

		# One merged list: terrain quads and building faces, depth-sorted together so the land
		# occludes the buried bases.
		var faces: Array = terrain.collect_surface(lens, u, lit, life, shadow)
		for b in blds:
			_block_faces(faces, shadow, b.base, b.up, b.bx, b.bz, b.w, b.h, b.hue, b.lit, float(b.ext))
		faces = TriBatch.painter_sort(faces)
		var tb := TriBatch.new()
		for fc in faces:
			if fc.has("uvs"):
				tb.mark_run(true, tex_rid)
				tb.quad_textured(fc.poly, fc.cols, fc.uvs)
			else:
				tb.mark_run(false, RID())
				tb.quad_colored(fc.poly, fc.cols)
		return tb.take_chunks()

	# Append the camera-facing faces of one oriented box to `out` (each {poly, cols, d}), per-vertex
	# shaded by the key light and the cast-shadow map.
	func _block_faces(out: Array, shadow: ShadowField, base: Vector3, up: Vector3, bx: Vector3,
			bz: Vector3, w: float, h: float, bhue: float, lit: float, ext: float) -> void:
		var top := base + up * h
		var corners := [
			base - bx * w - bz * w, base + bx * w - bz * w, base + bx * w + bz * w, base - bx * w + bz * w,
			top - bx * w - bz * w, top + bx * w - bz * w, top + bx * w + bz * w, top - bx * w + bz * w]
		var pr: Array = []
		for cwld in corners:
			var pj := lens.project(cwld)
			pr.append(Vector3(pj.x * u, pj.y * u, pj.z))
		var quads := [[4, 5, 6, 7, up],                     # top
			[0, 1, 5, 4, -bz], [1, 2, 6, 5, bx], [2, 3, 7, 6, bz], [3, 0, 4, 7, -bx]]
		for q in quads:
			var i0: int = q[0]
			var i1: int = q[1]
			var i2: int = q[2]
			var i3: int = q[3]
			var fn: Vector3 = q[4]
			var fc: Vector3 = (corners[i0] + corners[i1] + corners[i2] + corners[i3]) * 0.25
			if fn.dot(lens.eye - fc) <= 0.0:                 # facing away
				continue
			var p0: Vector3 = pr[i0]
			var p1: Vector3 = pr[i1]
			var p2: Vector3 = pr[i2]
			var p3: Vector3 = pr[i3]
			if p0.z <= lens.near or p1.z <= lens.near or p2.z <= lens.near or p3.z <= lens.near:
				continue
			var fpoly := PackedVector2Array([Vector2(p0.x, p0.y), Vector2(p1.x, p1.y),
				Vector2(p2.x, p2.y), Vector2(p3.x, p3.y)])
			if Terrain._quad_area(fpoly) < 1.0:        # edge-on face - skip
				continue
			var shade := 0.34 + 0.72 * clampf(fn.dot(terrain.light_dir()), 0.0, 1.0)
			var cols := PackedColorArray()
			for idx in [i0, i1, i2, i3]:
				var sf: float = shadow.factor(corners[idx], ext + 0.06)
				# Saturation and brightness carry the mood (an ash city is gray concrete, a violet
				# one glows); the lighting maths is untouched.
				var cc := Color.from_hsv(bhue, sat, clampf(lit * shade * sf * vmul, 0.0, 1.0))
				# A plot below the waterline is in the lake, not on it (see Terrain.submerged).
				cc = terrain.submerged(cc, corners[idx].y)
				cc.a = reveal                          # fade the buildings in AFTER the terrain
				cols.append(cc)
			out.append({"d": (p0.z + p1.z + p2.z + p3.z) * 0.25, "poly": fpoly, "cols": cols})
