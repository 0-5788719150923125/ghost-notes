extends Scene3D

## Canopy - trees growing on real terrain, from taproot to leaf, through one season.
##
## A wooded slope under a low raking sun. Two to six hundred trees stand on a [Terrain] heightfield, each a 3D
## branching structure grown by [Branch3D]. Trunks and crowns rasterize into a [ShadowField], and the wood
## merges into [method Terrain.collect_surface]'s quad list before the depth sort, so a hill occludes the
## trees behind it. A handful of models (three to five per stand) are grown once in [method build_params];
## every tree is one of them, yawed, scaled and bent at draw time.
##
## What tests/scenes/canopy_scatter_check.gd holds:
##   Size: a tree is a small fraction of the landscape's relief (mean 0.11).
##   Density: two to six hundred trees.
##   Distribution: stands. Clump centers are rejection-sampled against a density field, trees scatter around
##   them with a gaussian falloff, plus a minority of stragglers. A minimum-distance test cannot make stands
##   (nearest-neighbor spread 0.20 against 0.52 for random scatter); this reads 0.9 to 1.3.
##   Where: [method _density_at] - tree line, wetness, groves and slope.
##   Foliage: [constant FOLIAGE]. A wood has two stands, a canopy and an understory, each with its own
##   architecture, hue and leaf form, and a share of clusters in a second hue.
##
## Wind is a traveling front: a gust has a position, crossing speed and gaussian width, so far trees answer
## late. `f.bass` drives trunk sway as an angular cantilever displacement (never a scale); `f.high` plus
## `f.treble` drive the leaf clusters' flutter alone.
##
## The season is the first draw of the seed and sets the mood, climate, leaf density, hue turn, saturation and
## the air. Shedding is not an rng draw: each leaf carries a fixed release threshold set at build and detaches
## when the running peak of an EMA of `f.beat` crosses it (live and offline feature streams differ), so it is
## a pure function of (threshold, shed level).
##
## LOD is structural: the nearest dozen trees get full tubes on heavy wood and ribbons on twigs, the middle
## band drops the finest order and thins foliage, the rest collapse to three to six crown puffs over a trunk
## ribbon. The frame is built off the main thread through [FrameForge]; under `--export` the builder runs
## synchronously, so the LOD budget is the render wall time.
##
## The seed decides: season and mood; the wooded landform and climate; the sun (8-35 degrees) and its drift;
## the species rule table; model and tree counts; the density field and stands; the refused slope; the gust;
## the LOD distances.

## SEASONS - the top-level choice, adapted from rooted_growth's table. Color, density and form are
## read off one entry so they agree about the time of year.
##   `climates` the [Terrain] climates this season may take.
##   `leaf`     foliage density, 0..1. Winter is nearly bare wood.
##   `bare`     the fraction of leaves that carry a reachable release threshold at all.
##   `turn`     how far foliage hue walks from base to tip. Autumn turns hardest.
##   `sat`/`val` scale the mood's own character rather than replacing it.
##   `ground`   what drifts through the frame, from the shared [Layer] registry.
##   `veil`     the chance of a soft coverage haze over the wood.
const SEASONS := {
	"spring": {
		"moods": ["verdant", "toxic", "teal", "rose", "dawn", "bone", "glacier"],
		"climates": ["verdant", "temperate"],
		"leaf": 0.85, "bare": 0.04, "turn": [0.04, 0.12], "sat": 0.88, "val": 1.12,
		"ground": [{"kind": "petals", "n": [14, 28]}, {"kind": "dust", "n": [40, 80]}],
		"veil": 0.25,
	},
	"summer": {
		"moods": ["verdant", "toxic", "teal", "brass", "sodium", "abyss", "ember"],
		"climates": ["verdant", "temperate", "arid"],
		"leaf": 1.00, "bare": 0.08, "turn": [0.05, 0.16], "sat": 1.15, "val": 1.00,
		"ground": [{"kind": "dust", "n": [50, 95]}, {"kind": "fog", "n": [4, 8]}],
		"veil": 0.12,
	},
	"autumn": {
		"moods": ["ember", "dawn", "sodium", "brass", "rose", "ash", "verdant"],
		"climates": ["temperate", "arid", "tundra"],
		"leaf": 0.72, "bare": 0.62, "turn": [0.20, 0.42], "sat": 1.10, "val": 0.94,
		"ground": [{"kind": "petals", "n": [12, 24]}, {"kind": "fog", "n": [4, 9]}],
		"veil": 0.35,
	},
	"winter": {
		"moods": ["ash", "bone", "glacier", "abyss", "violet", "teal", "ember"],
		"climates": ["tundra", "temperate"],
		"leaf": 0.16, "bare": 0.92, "turn": [0.02, 0.07], "sat": 0.42, "val": 1.06,
		"ground": [{"kind": "snow", "n": [70, 130]}, {"kind": "fog", "n": [5, 9]}],
		"veil": 0.60,
	},
}

## Which climates suit which landform. The season's own list is intersected with this.
const TERRAINS := {
	"hills":   ["temperate", "verdant", "tundra", "arid"],
	"valleys": ["verdant", "temperate", "tundra"],
	# `mesa` is absent from canopy's own landform list below: a plateau of scarps renders as spikes at this relief.
	"mesa":    ["arid", "temperate"],
	"islands": ["verdant", "temperate"],
}

## FOLIAGE ARCHETYPES - what the leaf mass is, apart from its color.
##
## `size`   cluster radius as a fraction of the model's crown radius, against the ~140 sites
##          Branch3D lays through the outer orders. Few big clusters overlap into a cloud, many small
##          ones read as grain.
## `sides`  rim points on the billboard fan, and `ragged` how far the rim wanders.
## `hard`   how much alpha the cluster's rim keeps (see Branch3D.billboard_fan): the coarse/fluffy dial.
##          At 0 a cluster is a soft radial gradient; needles are hardest, fronds softest, nothing is 0.
## `sat`/`val` the band the mood moves the foliage inside, not a multiplier (a multiplier turns pale
##          schemes into cream leaves).
## `turn`   scales the season's base-to-tip hue walk.
## `acc`    the share of clusters that take a second hue (the scheme's opposed color).
## `stride` thins the cluster count (a conifer has many small tufts, a palm a few big fronds).
const FOLIAGE := {
	"broadleaf": {"size": [0.15, 0.24], "sides": 8, "ragged": [0.26, 0.44], "hard": [0.55, 0.78],
		"sat": [0.42, 0.78], "val": [0.52, 0.86], "turn": 1.0, "acc": [0.0, 0.12], "stride": 1},
	"needle":    {"size": [0.09, 0.15], "sides": 6, "ragged": [0.50, 0.80], "hard": [0.72, 0.92],
		"sat": [0.34, 0.62], "val": [0.30, 0.54], "turn": 0.5, "acc": [0.0, 0.05], "stride": 1},
	"frond":     {"size": [0.20, 0.32], "sides": 6, "ragged": [0.55, 0.85], "hard": [0.34, 0.55],
		"sat": [0.40, 0.72], "val": [0.46, 0.78], "turn": 0.8, "acc": [0.0, 0.10], "stride": 2},
	"blossom":   {"size": [0.13, 0.22], "sides": 9, "ragged": [0.18, 0.34], "hard": [0.48, 0.70],
		"sat": [0.35, 0.70], "val": [0.62, 0.95], "turn": 1.3, "acc": [0.25, 0.55], "stride": 1},
	"scrub":     {"size": [0.12, 0.20], "sides": 7, "ragged": [0.40, 0.65], "hard": [0.60, 0.85],
		"sat": [0.26, 0.52], "val": [0.38, 0.62], "turn": 0.7, "acc": [0.0, 0.08], "stride": 1},
}

## Which foliage a season may put in a wood.
const SEASON_FOLIAGE := {
	"spring": ["broadleaf", "broadleaf", "blossom", "needle", "frond", "scrub"],
	"summer": ["broadleaf", "broadleaf", "needle", "frond", "scrub", "blossom"],
	"autumn": ["broadleaf", "broadleaf", "needle", "scrub"],
	"winter": ["needle", "needle", "broadleaf", "scrub"],
}

## A label for the sampled density weights below; the distribution itself is [method _density_at].
const LAWS := ["even", "ridge", "valley", "glade"]

var _terrain: Terrain
var _models: Array = []              # the grown tree models (immutable after build)
var _stands: Array = []              # one entry per stand: foliage archetype + its color
# The distribution field (see _density_at).
var _elev_bias := 0.0                # <0 the wood prefers valleys, >0 it climbs the ridges
var _tree_line := 0.8                # normalized height where the wood gives up
var _line_soft := 0.2
var _wet_k := 1.4
var _grove_thr := 0.5
var _grove_soft := 0.1
var _grove_f: Field
var _wet_f: Field
var _trees: Array = []               # instances: model index, place, yaw, scale, phase
var _forge := FrameForge.new()
var _sim := SimClock.new(60.0)       # the wind / season / shed simulation clock
var _light: Lighting
var _sch: Scheme
var _species: Dictionary = {}
var _season := "summer"
var _law := "even"
var _ground_layer := "dust"

# Wind. `_front` is the gust's position along `_wind`, in world units; it crosses and wraps.
var _wind := Vector3(1, 0, 0)
var _front := 0.0
var _span := 5.4
var _gust := 0.0
var _gust_speed := 1.6
var _gust_width := 0.9
var _gust_amp := 0.18
var _breeze := 0.0
var _flutter := 0.0

# The season's own clock, and the shedding level (a running peak of an EMA of the beat).
var _season_t := 0.0
var _beat_ema := 0.0
var _shed := 0.0

var _glow := 0.0
var _chroma := Vector2.ZERO
var _yaw := 0.0
var _yaw_dir := 1.0
var _dist := 8.0
var _pitch := 0.45
var h_cam_clear := 0.4               # how far above the ground the eye is kept (see update)
var _focus := Vector3.ZERO           # the densest part of the wood - what the orbit looks at
var _look_y := 0.35
var _light_az := 0.0
var _light_el := 0.35
var _light_drift := 1.0
var _bark_hue := 0.08
var _bark_sat := 0.34
var _bark_val := 0.62
var _leaf_hue := 0.32
var _leaf_sat := 0.60
var _leaf_val := 0.82
var _leaf_turn := 0.10
var _leaf_density := 1.0
var _fog_col := Color(0.62, 0.66, 0.72)
var _lod_near := 3.2
var _lod_far := 5.4
var _near_max := 12
var _mid_max := 34
var _embed := 0.03


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a storyboard
## entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"season": {"label": "Season", "type": "choice", "options": "SEASONS", "default": null,
		"blurb": "The time of year the wood is in - spring, summer, autumn or winter - which sets its colors, how thick the leaves are, which climates it may take and what drifts through the air."},
	"ridges": {"label": "Ridges or valleys", "type": "num", "range": [-1.0, 0.55], "default": null,
		"blurb": "Whether the wood gathers down in the valleys or up along the ridges."},
	"tree_line": {"label": "Tree line", "type": "num", "range": [0.55, 0.95], "default": null,
		"blurb": "How high up the hills the trees grow before the wood gives out."},
	"trees": {"label": "Trees", "type": "num", "range": [260, 620], "default": null,
		"blurb": "How many trees the wood tries to grow on the hillside."},
	"stands": {"label": "Stands", "type": "num", "range": [5, 14], "default": null,
		"blurb": "How many separate stands of trees the wood is gathered into."},
	"gust": {"label": "Gust strength", "type": "num", "range": [0.10, 0.26], "default": null,
		"blurb": "How hard each gust of wind bends the trees as it crosses the wood."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	framing = "field"
	# The season first: every decision below is read through it.
	_season = String(choice("season", rng))
	var sea: Dictionary = SEASONS[_season]
	_sch = Scheme.among(sea["moods"], rng)
	var sat_mul: float = float(sea["sat"])
	var val_mul: float = float(sea["val"])
	_leaf_density = float(sea["leaf"])
	var bare: float = float(sea["bare"])

	# Landform crossed with a climate both the land and the season accept. `mesa` is out of the
	# bag: it renders as a wall of spikes at this relief.
	var wooded := ["hills", "hills", "valleys", "valleys", "islands"]
	var ttype := String(wooded[rng.randi() % wooded.size()])
	var land_cl: Array = TERRAINS[ttype]
	var sea_cl: Array = sea["climates"]
	var ok: Array = []
	for c in land_cl:
		if sea_cl.has(c):
			ok.append(c)
	if ok.is_empty():
		ok = land_cl
	var climate := String(ok[rng.randi() % ok.size()])
	_terrain = Terrain.new()
	# Relief, half-extent and camera move together. A tree is a small fraction of the relief
	# (tests/scenes/canopy_scatter_check.gd), so the relief must be deep enough for that fraction to be a
	# tree. Relief over a small extent is a wall of spikes (slope is relief/half), so the world stays
	# full size and the camera sits a handful of tree heights out.
	_terrain.build(rng, ttype, 3.0, rng.randf_range(0.85, 1.35), null, climate)
	# Each base sinks a little below the surface so the trunk rises from a ragged root line; scaled
	# by relief.
	_embed = _terrain.relief * rng.randf_range(0.03, 0.10)

	# A low sun (8 to 35 degrees) for long shadows; the terrain's shadow march resolves down to about 1.1 degrees.
	_light_el = deg_to_rad(rng.randf_range(8.0, 35.0))
	_light_az = rng.randf() * TAU
	_light_drift = 1.0 if rng.randf() < 0.5 else -1.0
	_terrain.set_light(_light_az, _light_el)
	var sun := Vector3(cos(_light_el) * cos(_light_az), sin(_light_el),
		cos(_light_el) * sin(_light_az))

	# One species for the whole wood, a handful of models grown from it. The phototropic bias is baked
	# into the model and yawed with each instance, which is invisible at 8-35 degrees of elevation.
	# Two stands: the dominant one takes most trees; the second is shorter, differently leaved and
	# tinted, so the wood has depth without a second L-system per tree.
	_species = Branch3D.sample_species(rng)
	var fol_bag: Array = SEASON_FOLIAGE[_season]
	var nstands := 1 if rng.randf() < 0.18 else 2
	var seg_budget := rng.randi_range(140, 230)
	# Height is a fraction of the landscape's relief (0.18 mean, 0.30 ceiling, held by
	# tests/scenes/canopy_scatter_check.gd).
	var h_hi: float = _terrain.relief * rng.randf_range(0.13, 0.185)
	for si in nstands:
		var arche := String(fol_bag[rng.randi() % fol_bag.size()])
		var fo: Dictionary = FOLIAGE[arche]
		# The understory is reliably shorter.
		var band := 1.0 if si == 0 else rng.randf_range(0.45, 0.72)
		var sp: Dictionary = _species.duplicate()
		if si > 0:
			# Its own fork angle and crown fraction, so it is not a scaled-down copy.
			sp["angle"] = clampf(float(sp["angle"]) * rng.randf_range(0.75, 1.30), 14.0, 62.0)
			sp["crown"] = clampf(float(sp["crown"]) * rng.randf_range(0.7, 1.35), 0.18, 0.78)
			sp["droop"] = clampf(float(sp["droop"]) + rng.randf_range(-0.1, 0.18), 0.0, 0.5)
		var nmodels := rng.randi_range(3, 5)
		# The stand's foliage look, resolved once; the mood chooses where inside the archetype's band.
		var fsat := lerpf(float(fo["sat"][0]), float(fo["sat"][1]),
			clampf(_sch.sat * rng.randf_range(0.8, 1.2), 0.0, 1.0))
		var fval := lerpf(float(fo["val"][0]), float(fo["val"][1]),
			clampf(_sch.val * rng.randf_range(0.8, 1.15), 0.0, 1.0))
		var stand := {
			"arche": arche,
			"dh": 0.0 if si == 0 else rng.randf_range(-0.09, 0.09),
			"sat": fsat * sat_mul,
			"val": fval * val_mul,
			"sides": int(fo["sides"]),
			"ragged": rng.randf_range(float(fo["ragged"][0]), float(fo["ragged"][1])),
			"hard": rng.randf_range(float(fo["hard"][0]), float(fo["hard"][1])),
			"turn": float(fo["turn"]),
			"acc": rng.randf_range(float(fo["acc"][0]), float(fo["acc"][1])),
			# The accent hue shift runs along the arc from the foliage hue toward the scheme's own base
			# (a free offset of +-0.3 turn gives cyan blossom on a green wood).
			"acc_dh": (fposmod(_sch.hue - _sch.accent + 0.5, 1.0) - 0.5)
				* rng.randf_range(0.45, 1.0),
			"stride": int(fo["stride"]),
			"scale": [0.78 * band, 1.22 * band],
			"share": 1.0 if si == 0 else rng.randf_range(0.18, 0.45),
		}
		_stands.append(stand)
		for _mi in nmodels:
			var h := h_hi * band * rng.randf_range(0.72, 1.0)
			var sp2: Dictionary = sp.duplicate()
			# Cluster size is set from the crown this model will have, so the archetype speaks in
			# fractions of it.
			sp2["leaf_size"] = float(sp2["leaf_size"])
			# Trunk radius as a fraction of height; real proportion (about 2%) is a two-pixel line at this framing.
			var model: Dictionary = Branch3D.grow(sp2, rng, h,
				h * rng.randf_range(0.032, 0.052), sun, seg_budget)
			var crad: float = maxf(0.001, float(model["crown_r"]))
			var csize := crad * rng.randf_range(float(fo["size"][0]), float(fo["size"][1]))
			var lv: Array = model["leaves"]
			for entry in lv:
				var lf: Dictionary = entry
				# The cluster, re-sized off the crown, keeping Branch3D's per-leaf variation.
				lf["size"] = csize * rng.randf_range(0.72, 1.28)
				# Release thresholds: which leaves are ever sheddable, and in what order. Sampled at
				# build off the seeded rng, never on an audio event.
				lf["release"] = rng.randf_range(0.03, 0.45) if rng.randf() < bare else 99.0
				# Which leaves carry the stand's second hue.
				lf["acc"] = 1.0 if rng.randf() < float(stand["acc"]) else 0.0
				# Dapple: each cluster is a little brighter or darker than its neighbor, for good.
				lf["dap"] = rng.randf_range(0.74, 1.26)
			model["stand"] = si
			_models.append(model)

	# The scatter: rejection against the real surface (never in the water, never on ground too steep
	# to root), weighted by the density field, spaced by a Poisson-disc test through a hash grid
	# (build_params runs synchronously on the main thread at every cut).
	_elev_bias = number("ridges", rng)     # negative: valleys. positive: ridges.
	_tree_line = number("tree_line", rng)     # where the wood gives up, in normalized height
	_line_soft = rng.randf_range(0.10, 0.30)
	_wet_k = rng.randf_range(0.8, 2.2)
	_grove_f = Field.make("fbm", rng.randi(), rng.randf_range(0.55, 1.15), 3)
	_wet_f = Field.make("fbm", rng.randi(), rng.randf_range(0.30, 0.70), 2)
	_grove_thr = rng.randf_range(0.40, 0.56)
	_grove_soft = rng.randf_range(0.06, 0.16)
	_law = "ridge" if _elev_bias > 0.25 else ("valley" if _elev_bias < -0.35 else "even")
	if _grove_thr > 0.52:
		_law = "glade"
	# A wood, not a specimen collection; the LOD bands (rank-capped) carry the rest as silhouettes.
	var want: int = number("trees", rng)
	var margin: float = _terrain.half * 0.94
	# Slope rejection as a quantile of this landform's own steepness: an absolute normal threshold
	# does not transfer between recipes, since a heightfield's gradient scales with its relief.
	var slopes := PackedFloat32Array()
	slopes.resize(256)
	for i in 256:
		slopes[i] = _terrain.normal_world(rng.randf_range(-margin, margin),
			rng.randf_range(-margin, margin)).y
	slopes.sort()
	var reject := rng.randf_range(0.08, 0.40)
	var slope_min: float = slopes[clampi(int(reject * 256.0), 0, 255)]
	# Stands are built, not hoped for: a minimum-distance test forbids close neighbors, so its
	# output is evenly spread by construction (nearest-neighbor spread 0.20 against 0.52 for random
	# scatter; stands read above 0.6).
	#
	# So: clump centers first, rejection-sampled against the density field, then trees scattered
	# around each center with a gaussian falloff, each still tested against the land and the field. A
	# minority are stragglers placed the old way, which keeps the gaps between stands from reading as
	# walls. The only distance test left is a trunk guard.
	var spacing: float = _terrain.half * 2.0 / sqrt(float(want))
	# The trunk guard is small: it only stops two trees sharing a trunk. Near the nominal spacing it
	# saturates every stand into a lattice (0.39-0.52 nearest-neighbor spread against 0.55 for a wood).
	var guard := spacing * rng.randf_range(0.07, 0.16)
	var hmax := 0.001
	for hv in _terrain.hgrid:
		hmax = maxf(hmax, hv)
	hmax = maxf(0.05, hmax - _terrain.water)
	var cells: Dictionary = {}
	var inv_cell := 1.0 / maxf(0.001, guard * 3.0)
	# Stand size and spread, sampled.
	var clump_n: int = number("stands", rng)
	# The stands must not tile the hill: the radius is solved from a target coverage, so whatever the
	# count, the stands together claim a third or so of the usable ground and leave gaps.
	var cover := rng.randf_range(0.09, 0.26)
	var usable := (2.0 * margin) * (2.0 * margin)
	var clump_r: float = sqrt(cover * usable / (PI * float(clump_n)))
	var stragglers := rng.randf_range(0.06, 0.18)
	var centers: Array = []
	var ctries := 0
	while centers.size() < clump_n and ctries < clump_n * 60:
		ctries += 1
		var cxw := rng.randf_range(-margin, margin)
		var czw := rng.randf_range(-margin, margin)
		var chh: float = _terrain.height_at(cxw, czw)
		if chh <= 0.02:
			continue
		var cn: Vector3 = _terrain.normal_world(cxw, czw)
		if cn.y < slope_min:
			continue
		var cd := _density_at(cxw, czw, clampf(chh / hmax, 0.0, 1.0), cn.y)
		# A stand center is held to a higher bar than a single tree.
		if rng.randf() > cd * cd:
			continue
		centers.append(Vector2(cxw, czw))
	# Per-stand quotas, unequal: stands filled to their packing limit are each a lattice. A squared
	# uniform weighting makes some stands thick and others a handful of trees.
	var quotas := PackedFloat32Array()
	var wsum := 0.0
	for ci in centers.size():
		var w := rng.randf()
		w = w * w * rng.randf_range(0.5, 1.5) + 0.05
		quotas.append(w)
		wsum += w
	var placed_target := int(round(float(want) * (1.0 - stragglers)))
	var tries := 0
	for ci in centers.size():
		var c: Vector2 = centers[ci]
		var quota := int(round(placed_target * quotas[ci] / maxf(0.0001, wsum)))
		# Each stand crowds to its own degree.
		var guard_i := guard * rng.randf_range(0.7, 1.7)
		# ...and has its own spread.
		var clump_ri := clump_r * rng.randf_range(0.45, 1.85)
		var got := 0
		var t2 := 0
		while got < quota and t2 < quota * 14 + 40:
			t2 += 1
			tries += 1
			# Gaussian about the center (three uniforms summed): a dense heart and a ragged edge.
			var off := Vector2(rng.randf() + rng.randf() + rng.randf() - 1.5,
				rng.randf() + rng.randf() + rng.randf() - 1.5) * clump_ri
			if _place_tree(rng, clampf(c.x + off.x, -margin, margin),
					clampf(c.y + off.y, -margin, margin), slope_min, hmax, guard_i,
					inv_cell, cells, true):
				got += 1
	# Stragglers, on open ground between the stands, capped at their own share and never used to
	# backfill: when stands under-deliver the wood is simply smaller (backfilling makes a lattice).
	var straggle_want := int(round(float(want) * stragglers))
	var straggled := 0
	while straggled < straggle_want and tries < want * 45:
		tries += 1
		if _place_tree(rng, rng.randf_range(-margin, margin), rng.randf_range(-margin, margin),
				slope_min, hmax, guard, inv_cell, cells, false):
			straggled += 1


	# Where the shot looks: the orbit centers on the densest part of the wood (each tree votes,
	# weighted by its neighbors), so the target lands inside a stand and not in a gap between two.
	if not _trees.is_empty():
		var best := Vector3.ZERO
		var best_w := -1.0
		var probe := mini(_trees.size(), 96)
		for k in probe:
			var tr: Dictionary = _trees[(k * 7 + 3) % _trees.size()]
			var pp: Vector3 = tr["pos"]
			var w := 0.0
			for j in _trees.size():
				var qq: Vector3 = (_trees[j] as Dictionary)["pos"]
				if absf(qq.x - pp.x) < clump_r and absf(qq.z - pp.z) < clump_r:
					w += 1.0
			if w > best_w:
				best_w = w
				best = pp
		_focus = Vector3(best.x, 0.0, best.z)

	# The gust: a front with a crossing speed and width; `_span` is wider than the land so it enters and leaves.
	var wa := rng.randf() * TAU
	_wind = Vector3(cos(wa), 0.0, sin(wa))
	_gust_speed = rng.randf_range(0.9, 2.6)
	_gust_width = rng.randf_range(0.5, 1.4)
	_gust_amp = number("gust", rng)
	_span = _terrain.half * 1.8
	_front = -_span

	# Color. Bark takes the mood's base darkened and drained; foliage takes the accent; the season
	# scales both rather than replacing them. Bark is brown tinted toward the scheme (taken straight
	# from the mood, a `teal` scheme gives teal trunks).
	_bark_hue = _blend_hue(rng.randf_range(0.045, 0.10), _sch.hue,
		rng.randf_range(0.12, 0.30))
	# Bark saturation: the mood chooses where inside a plausible band (drained straight off the mood,
	# pale schemes give near-white trunks).
	_bark_sat = clampf(lerpf(0.30, 0.58, clampf(_sch.sat, 0.0, 1.0))
		* rng.randf_range(0.85, 1.15), 0.12, 0.8)
	# Dark enough to be wood, light enough to read against a shaded hillside (0.16-0.38 vanishes into the floor).
	_bark_val = clampf(lerpf(0.34, 0.58, clampf(_sch.val, 0.0, 1.0)) * val_mul
		* rng.randf_range(0.9, 1.12), 0.14, 0.72)
	_leaf_hue = fposmod(_sch.accent + rng.randf_range(-0.03, 0.03), 1.0)
	_leaf_sat = clampf(_sch.sat * sat_mul * rng.randf_range(0.7, 1.05), 0.05, 0.95)
	_leaf_val = clampf(_sch.val * val_mul * rng.randf_range(0.78, 1.05), 0.1, 1.2)
	var to_accent := fposmod(_sch.opposed(_leaf_hue, 0.18) - _leaf_hue + 0.5, 1.0) - 0.5
	_leaf_turn = to_accent * rng.randf_range(float(sea["turn"][0]), float(sea["turn"][1])) * 1.6
	_fog_col = Color.from_hsv(fposmod(_sch.hue + rng.randf_range(0.38, 0.58), 1.0),
		rng.randf_range(0.04, 0.16), rng.randf_range(0.55, 0.86))

	# Camera: in the wood, not above it. A forest is photographed from inside, a slope filling the
	# frame; the heightfield is six units across, so this sees a third of it and the far rim stays
	# above the frame at these pitches (no void band).
	lens.fov = rng.randf_range(46.0, 58.0)
	# Off the terrain, not absolute: the orbit clears hills up to 1.65 units tall.
	# Distance is framed on the wood's own spacing, which decides how many trees are in shot: roughly
	# eight to eighteen tree-spacings across the frame, floored so a tree is never sub-pixel and
	# capped so the shot never backs out into an aerial view. (Relief and height are sampled
	# independently, so a tree-height multiplier alone frames six trees on one seed and a crown
	# interior on the next.)
	_dist = clampf(spacing * rng.randf_range(7.0, 16.0),
		maxf(0.9, h_hi * 7.0), _terrain.half * 1.45)
	h_cam_clear = h_hi * rng.randf_range(1.0, 2.2)
	_pitch = rng.randf_range(0.16, 0.34)
	_look_y = h_hi * rng.randf_range(0.45, 0.95)
	_yaw = rng.randf() * TAU
	_yaw_dir = 1.0 if rng.randf() < 0.5 else -1.0

	# LOD distances are sampled, since how far "near" reaches decides look and cost. They are
	# measured from the nearest tree, not the camera: they are depths into the wood that detail
	# reaches, and the wood starts a couple of units from the camera.
	_lod_near = rng.randf_range(0.9, 1.7)
	_lod_far = _lod_near + rng.randf_range(0.8, 1.6)
	_near_max = rng.randi_range(8, 12)
	_mid_max = _near_max + rng.randi_range(18, 30)

	_light = Lighting.new(rng, 3)

	# A sky behind the land: a heightfield has no horizon, and at these pitches the far rim sits
	# below the top of the frame. `bed` (a back layer) fills the band with the pale distance the fog
	# fades toward, so the ridge reads as a skyline.
	add_layer("bed", rng, {"z": "back", "hue": _fog_col.h, "sat": _fog_col.s + 0.06,
		"val": rng.randf_range(0.34, 0.58), "pools": rng.randi_range(2, 4)})

	# The season's air, and an optional coverage veil / low sun-shafts.
	var ground: Array = sea["ground"]
	var pick: Dictionary = ground[rng.randi() % ground.size()]
	_ground_layer = String(pick["kind"])
	# Thinned for this framing: from inside the wood the old counts read as popcorn.
	var air_n := int(round(rng.randi_range(int(pick["n"][0]), int(pick["n"][1])) * 0.42))
	add_layer(_ground_layer, rng, _air_cfg(_ground_layer, maxi(3, air_n)))
	if rng.randf() < float(sea["veil"]):
		add_layer("veil", rng, {"hue": _fog_col.h, "sat": 0.05, "val": _fog_col.v,
			"max": rng.randf_range(0.18, 0.38)})
	# Rarer and thinner: from inside the wood these are full-height curtains.
	if _light_el < deg_to_rad(18.0) and rng.randf() < 0.15:
		add_layer("rays", rng, {"count": rng.randi_range(2, 3),
			"hue": fposmod(_sch.accent + 0.02, 1.0), "z": "front"})
	return {"season": _season, "mood": _sch.name, "terrain": ttype, "climate": climate,
		"law": _law, "trees": _trees.size(), "models": _models.size(),
		"stands": _stands.size(),
		"foliage": ", ".join(_stand_names()), "elev_bias": _elev_bias,
		"tree_line": _tree_line,
		"depth": int(_species["depth"]), "children": int(_species["children"]),
		"angle": float(_species["angle"]), "roll": float(_species["roll"]),
		"ratio": float(_species["ratio"]), "taper": float(_species["taper"]),
		"crown": float(_species["crown"]), "leaf_density": _leaf_density,
		"sun_deg": rad_to_deg(_light_el), "gust_speed": _gust_speed,
		"gust_width": _gust_width, "lod_near": _lod_near, "slope_reject": reject,
		"air": _ground_layer}


## How dense the wood is at one place, in 0..1.
##
## A power of height is monotonic, so it thins in one direction and cannot know where a valley is.
## Four terms decide where trees grow:
##   Tree line: above it nothing, as a soft edge so the wood thins into stragglers first.
##   Wetness: low ground holds water, so valleys carry the dense wood. It is mixed with a
##   low-frequency moisture field so the elevation preference does not read as a rule.
##   Groves: a low-frequency field thresholded hard, so the wood is in stands with real gaps.
##   Slope: gentle ground holds more than a steep flank.
##
## `_elev_bias` runs the elevation term from valley-loving through indifferent to ridge-loving.
##
## One candidate tree, tested against the land and the density field and (if it survives) added.
## Returns whether it took.
func _place_tree(rng: RandomNumberGenerator, wx: float, wz: float, slope_min: float,
		hmax: float, guard: float, inv_cell: float, cells: Dictionary,
		in_clump: bool) -> bool:
	var hh: float = _terrain.height_at(wx, wz)
	if hh <= 0.015:
		return false                                   # in the water, or on the shoreline
	var nrm: Vector3 = _terrain.normal_world(wx, wz)
	if nrm.y < slope_min:
		return false                                   # too steep to hold a root plate
	var hn := clampf(hh / hmax, 0.0, 1.0)
	var dens := _density_at(wx, wz, hn, nrm.y)
	# A tree inside a stand is held to a gentler bar than a straggler: pow(d, 0.45) lifts the middle
	# of the range and still returns zero where the field does, so the tree line holds.
	if rng.randf() > (pow(dens, 0.45) if in_clump else dens):
		return false
	var cx := int(floor(wx * inv_cell))
	var cz := int(floor(wz * inv_cell))
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var key := Vector2i(cx + dx, cz + dz)
			if not cells.has(key):
				continue
			for o in (cells[key] as Array):
				if (o as Vector2).distance_to(Vector2(wx, wz)) < guard:
					return false                       # trees may crowd; they may not intersect
	var key2 := Vector2i(cx, cz)
	if not cells.has(key2):
		cells[key2] = []
	(cells[key2] as Array).append(Vector2(wx, wz))
	var mi := rng.randi() % _models.size()
	if _stands.size() > 1:
		var want_s := 0 if rng.randf() > float((_stands[1] as Dictionary)["share"]) else 1
		for k in _models.size():
			var cand: Dictionary = _models[(mi + k) % _models.size()]
			if int(cand["stand"]) == want_s:
				mi = (mi + k) % _models.size()
				break
	var model: Dictionary = _models[mi]
	var st: Dictionary = _stands[int(model["stand"])]
	var srange: Array = st["scale"]
	var sc := rng.randf_range(float(srange[0]), float(srange[1]))
	var yaw := rng.randf() * TAU
	var gy: float = hh * _terrain.relief - _embed
	_trees.append({
		"pos": Vector3(wx, gy, wz), "model": mi, "scale": sc,
		"cy": cos(yaw), "sy": sin(yaw),
		"h": float(model["height"]) * sc,
		"trunk": float(model["radius"]) * sc * float(_species["flare"]),
		"crown_r": float(model["crown_r"]) * sc,
		"stand": int(model["stand"]),
		"phase": rng.randf() * TAU,
		"rate": rng.randf_range(2.6, 4.6),
		"delay": rng.randf_range(0.0, 0.55),
		"shed_bias": rng.randf_range(0.7, 1.35),
		"hue": rng.randf_range(-0.04, 0.04),
		# Pinned to a spectral position by elevation: the ridge rings with the top of the spectrum.
		"t": hn})
	return true


func _stand_names() -> PackedStringArray:
	var out := PackedStringArray()
	for st in _stands:
		out.append(String((st as Dictionary)["arche"]))
	return out


func _density_at(wx: float, wz: float, hn: float, ny: float) -> float:
	var line := 1.0 - smoothstep(_tree_line - _line_soft, _tree_line + _line_soft, hn)
	var wet_pref := pow(clampf(1.0 - hn, 0.0, 1.0), _wet_k) if _elev_bias <= 0.0 \
		else pow(hn, _wet_k)
	var strength := absf(_elev_bias)
	var moisture := clampf(_wet_f.at(Vector2(wx, wz)) * 1.15, 0.0, 1.0)
	var wet := lerpf(0.55 + 0.45 * moisture, wet_pref * (0.45 + 0.75 * moisture), strength)
	var grove := smoothstep(_grove_thr - _grove_soft, _grove_thr + _grove_soft,
		_grove_f.at(Vector2(wx, wz)))
	var slope := smoothstep(0.0, 0.35, ny - 0.45)
	return clampf(line * wet * (0.10 + 0.95 * grove) * (0.45 + 0.65 * slope), 0.0, 1.0)


# Tint the season's airborne layer to the wood it falls from: blossom and dry leaves take the
# foliage hue, snow and fog the pale sky color.
func _air_cfg(kind: String, n: int) -> Dictionary:
	match kind:
		"petals":
			return {"count": n, "hue": _leaf_hue, "sat": clampf(_leaf_sat, 0.05, 0.9)}
		"snow":
			return {"count": n, "hue": _fog_col.h, "sat": 0.06, "size": 0.005}
		"fog":
			return {"count": n, "hue": _fog_col.h, "sat": 0.10, "z": "front"}
		_:
			return {"count": n, "hue": _fog_col.h, "shaft": false}


func update(f: AudioFeatures, delta: float) -> void:
	tick(f, delta)
	drift_view(f, 0.012, 0.02)
	_light.update(f, delta)
	update_layers(f, delta)
	_glow = Nonlinear.flare(_glow, clampf(0.3 * f.energy + 0.7 * f.beat, 0.0, 1.0),
		delta, 9.0, 1.6)
	# Wind, season and shedding integrate state, so they advance on wall-clock ticks at a fixed
	# rate, never once per update() call (the Director sub-steps, pre-warms and fast-forwards).
	for _i in _sim.ticks(delta):
		_step(f, _sim.dt)
	_chroma = chroma_hue()
	_yaw += delta * (0.028 + 0.075 * f.energy) * _yaw_dir
	lens.orbit(Vector3(_focus.x, _terrain.height_at(_focus.x, _focus.z) * _terrain.relief
		+ _look_y, _focus.z), _dist, _yaw, _pitch + 0.02 * sin(_life * 0.09))
	# The eye may not be inside a hill: it is lifted to clear the land beneath it plus headroom; the
	# look point is unchanged.
	var ex: float = lens.eye.x
	var ez: float = lens.eye.z
	var ground: float = _terrain.height_at(ex, ez) * _terrain.relief
	var floor_y: float = ground + h_cam_clear
	if lens.eye.y < floor_y:
		# The look point rises with it, half of the lift and capped: lifting the eye alone turns a
		# shallow shot top-down, and lifting the target fully aims over the stand.
		var lift: float = minf(floor_y - lens.eye.y, _dist * 0.35)
		lens.eye = Vector3(ex, maxf(lens.eye.y, floor_y), ez)
		lens.look = lens.look + Vector3(0.0, lift * 0.5, 0.0)
	# Line of sight to the wood: orbiting through hill country puts a hill between camera and stand
	# for part of every revolution. March the ray and lift the eye until the ground clears it (eight
	# height samples a frame); the lift is converted from clearance along the ray back to a lift at
	# the eye, and capped.
	var need := 0.0
	for k in range(1, 9):
		var t := float(k) / 9.0
		var gy: float = _terrain.height_at(lerpf(lens.eye.x, lens.look.x, t),
			lerpf(lens.eye.z, lens.look.z, t)) * _terrain.relief + h_cam_clear * 0.6
		var ry: float = lerpf(lens.eye.y, lens.look.y, t)
		if gy > ry:
			need = maxf(need, (gy - ry) / maxf(0.12, 1.0 - t))
	if need > 0.001:
		lens.eye = lens.eye + Vector3(0.0, minf(need, _dist * 1.1), 0.0)
	_light_az += delta * 0.02 * _light_drift
	_terrain.set_light(_light_az, _light_el)
	_terrain.step_light(delta)

	# The pre-warm runs before the scene enters the tree, so `size` is still zero; a packet built now
	# would collapse the wood onto a point and be the first drawn frame. Skip only the build.
	if size.x < 1.0 or size.y < 1.0:
		return

	# Snapshot the frame into a job. Models and tree records are immutable after build and ride by
	# reference; the terrain's per-frame light writes are in-place float updates; the lens is copied
	# because main re-orbits it.
	var job := CanopyJob.new()
	job.f = f
	job.terrain = _terrain
	job.tex_rid = Terrain.detail_texture().get_rid()
	job.models = _models
	job.trees = _trees
	job.u = unit()
	job.size = size
	job.clock = _sim.elapsed()
	job.life = _life
	job.reveal = view.reveal
	job.glow = _glow
	# [Lighting]'s glow drives the bark rim only - the one place a beat touches the wood.
	job.rim = _light.glow()
	# Raised with the tree count: hundreds of crowns cast into one map, so the floor is dark and the key must be up.
	job.lit = clampf(0.82 + 0.4 * _glow + 0.3 * f.energy, 0.5, 1.5)
	job.front = _front
	job.gust = _gust
	job.breeze = _breeze
	job.flutter = _flutter
	job.season_t = _season_t
	job.shed = _shed
	job.wind = _wind
	job.gust_width = _gust_width
	job.gust_amp = _gust_amp
	job.bark_hue = _bark_hue
	job.bark_sat = _bark_sat
	job.bark_val = _bark_val
	# Foliage is pulled toward the music's key hue by a quarter of how tonal the moment is.
	job.leaf_hue = _blend_hue(_leaf_hue, _chroma.x, 0.25 * _chroma.y)
	job.leaf_sat = _leaf_sat
	job.leaf_val = _leaf_val
	job.leaf_turn = _leaf_turn
	job.leaf_density = _leaf_density
	job.stands = _stands
	job.fog_col = _fog_col
	# Aerial perspective belongs to the landscape, not the camera: anchored to the terrain's extent,
	# so the far rim hazes and the wood in front keeps its color (tied to `_dist`, a close camera
	# fogs the whole wood to gray).
	job.fog_near = _dist + _terrain.half * 0.45
	job.fog_far = _dist + _terrain.half * 2.3
	job.lod_near = _lod_near
	job.lod_far = _lod_far
	job.near_max = _near_max
	job.mid_max = _mid_max
	job.lens = Lens3D.new()
	job.lens.eye = lens.eye
	job.lens.look = lens.look
	job.lens.up = lens.up
	job.lens.fov = lens.fov
	job.lens.near = lens.near
	_forge.kick(job.run, {}, self, job)
	queue_redraw()


# One fixed simulation tick: the gust crosses, the season advances, the wood sheds.
func _step(f: AudioFeatures, dt: float) -> void:
	_front = wrapf(_front + _gust_speed * dt, -_span, _span)
	# A section change raises a real gust; the beat only ruffles it. Gains are written for the
	# range these inputs occupy (well under 1.0), with a floor so a steady passage stays breezy.
	_gust = Nonlinear.flare(_gust,
		clampf(0.16 + 1.7 * f.movement + 0.45 * f.beat, 0.0, 1.0), dt, 8.0, 1.5)
	_breeze = Nonlinear.flare(_breeze, clampf(0.95 * f.bass, 0.0, 1.0), dt, 3.0, 1.0)
	_flutter = Nonlinear.flare(_flutter,
		clampf(0.6 * f.high + 0.7 * f.treble, 0.0, 1.0), dt, 12.0, 4.0)
	# The season's front: beats lunge it forward through a spike curve, quiet barely moves it. It
	# runs past 1.0 so the last trees finish.
	_season_t = minf(1.7, _season_t + dt * 0.055
		* (0.25 + 1.6 * Nonlinear.apply("spike", f.energy, 2.2)))
	_beat_ema = lerpf(_beat_ema, f.beat, 1.0 - exp(-0.7 * dt))
	_shed = maxf(_shed, _beat_ema)      # a running PEAK: a wood does not re-leaf mid-autumn


# Walk `h` toward `toward` by `amount`, the short way round the wheel.
func _blend_hue(h: float, toward: float, amount: float) -> float:
	var d := toward - h
	return fposmod(h + (d - round(d)) * clampf(amount, 0.0, 1.0), 1.0)


func _draw() -> void:
	begin_draw()
	draw_layers("back")                  # the sky, behind the land
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_forge.submit(self)
	draw_layers("front")                 # what falls through the wood, in front of it


## The whole frame, built off the main thread (the [FrameForge] contract): the shadow pass,
## the terrain merge, every tree at its LOD, the painter sort, and the batch runs. Reads only
## its own members - never the scene node - so a mid-job Director cut is harmless.
class CanopyJob:
	extends RefCounted

	const SIDES := 6                 # facets around a lofted limb
	const LEAF_SIDES := 5            # rim points on a leaf-mass billboard
	## Shadow-map resolution. The map is only read at terrain vertices (a 112x112 lattice over
	## 2 * half world units, 0.054 apart); a finer map aliases below the lattice's Nyquist limit. 128
	## puts a texel about 1.4 vertex spacings wide, so the bilinear tap interpolates and edges feather
	## over about two quads. 16k floats, cleared once per built frame.
	const SHADOW_RES := 128

	var f: AudioFeatures
	var lens: Lens3D
	var terrain: Terrain
	var tex_rid := RID()
	var models: Array = []
	var trees: Array = []
	var u := 1.0
	var clock := 0.0
	var life := 0.0
	var reveal := 1.0
	var glow := 0.0
	var rim := 0.0
	var lit := 1.0
	var front := 0.0
	var gust := 0.0
	var breeze := 0.0
	var flutter := 0.0
	var season_t := 0.0
	var shed := 0.0
	var wind := Vector3(1, 0, 0)
	var gust_width := 1.0
	var gust_amp := 0.18
	var bark_hue := 0.08
	var bark_sat := 0.34
	var bark_val := 0.62
	var leaf_hue := 0.32
	var leaf_sat := 0.6
	var leaf_val := 0.82
	var leaf_turn := 0.1
	var leaf_density := 1.0
	## One entry per stand (see the scene's FOLIAGE table): the foliage look each tree draws with.
	## Hue/sat/val are deltas and multipliers on the job's global leaf color, so the live chroma
	## modulation reaches every stand.
	var stands: Array = []
	var size := Vector2(1920, 1080)  # the frame, for the frustum cull in run()
	var fog_col := Color(0.62, 0.66, 0.72)
	var fog_near := 4.0
	var fog_far := 16.0
	var lod_near := 3.2
	var lod_far := 5.4
	var near_max := 12
	var mid_max := 34

	var _cam_r := Vector3.RIGHT
	var _cam_u := Vector3.UP

	func run(_s: Dictionary) -> Array:
		lens.prepare()
		var axes := Branch3D.cam_axes(lens)
		_cam_r = axes[0]
		_cam_u = axes[1]
		var ldir: Vector3 = terrain.light_dir()
		# Rank the wood near-first through the native-key sort (a sort_custom lambda is a hundred
		# interpreter calls a frame).
		# Frustum cull first: the camera stands among the trees, so most are behind or beside it
		# (emitting all cost 283 ms a frame at 1920x1080). Trees are culled from the draw only - every
		# tree still casts into the shadow map.
		var hx := 0.5 * float(size.x) / maxf(1.0, u)
		var hy := 0.5 * float(size.y) / maxf(1.0, u)
		var order: Array = []
		for i in trees.size():
			var tr: Dictionary = trees[i]
			var p: Vector3 = tr["pos"]
			var mid := p + Vector3.UP * (float(tr["h"]) * 0.6)
			var pc := lens.project(mid)
			if pc.z <= lens.near:
				continue                                  # behind the camera
			# A generous screen radius for the whole tree.
			var rad := (float(tr["crown_r"]) + float(tr["h"]) * 0.5) * 2.4 / pc.z
			if absf(pc.x) > hx + rad or absf(pc.y) > hy + rad:
				continue                                  # off the side of the frame
			if rad * u < 0.8:
				continue                                  # sub-pixel: nothing to draw
			order.append({"d": -(p - lens.eye).length(), "i": i})
		order = TriBatch.painter_sort(order)

		# Pass A: rasterize trunks (and crowns where there is foliage) into a light-space shadow map.
		var shadow := ShadowField.new()
		shadow.build(ldir, Vector3(-terrain.half, -terrain.relief, -terrain.half),
			Vector3(terrain.half, terrain.relief + 1.4, terrain.half), SHADOW_RES)
		if reveal >= 0.02:
			# Every tree casts: a camera-dependent subset makes shadows blink as trees change rank, and
			# add_box fills only a small rect, so casting all costs less than the map's clear.
			for i in trees.size():
				var tr: Dictionary = trees[i]
				var g := _grown(tr)
				if g < 0.1:
					continue
				var p: Vector3 = tr["pos"]
				var th: float = float(tr["h"]) * g
				# Round silhouettes (the last argument): add_box otherwise rasterizes the bounding
				# square. See ShadowField.add_box.
				shadow.add_box(p, Vector3.UP, Vector3.RIGHT, Vector3.BACK,
					float(tr["trunk"]), th * 0.7, true)
				if leaf_density > 0.25:
					# 0.72 of the crown: at full radius hundreds of casts merge into one blanket.
					shadow.add_box(p + Vector3.UP * (th * 0.6), Vector3.UP, Vector3.RIGHT,
						Vector3.BACK, float(tr["crown_r"]) * g * leaf_density * 0.72,
						th * 0.34, true)

		# One merged list: terrain quads (already shadowed by the wood) plus every tree face,
		# depth-sorted together.
		var faces: Array = terrain.collect_surface(lens, u, lit, life, shadow)
		if reveal >= 0.02:
			# The detail bands start at the near edge of the wood (see _lod_near). Both a distance
			# test, which decides what looks right, and a rank cap, the hard ceiling on frame cost.
			var d0 := 0.0
			if not order.is_empty():
				var first: Dictionary = order[0]
				d0 = -float(first["d"])
			var near_d := d0 + lod_near
			var far_d := d0 + lod_far
			for oi in order.size():
				var it: Dictionary = order[oi]
				var dst := -float(it["d"])
				var mode := 2
				if dst < near_d and oi < near_max:
					mode = 0
				elif dst < far_d and oi < mid_max:
					mode = 1
				_emit_tree(faces, trees[int(it["i"])], mode, dst, ldir)
		faces = TriBatch.painter_sort(faces)
		var tb := TriBatch.new()
		for entry in faces:
			var fc: Dictionary = entry
			if fc.has("fan"):                                # a soft leaf mass / crown puff
				tb.mark_run(false, RID())
				var fp: PackedVector2Array = fc["fan"]
				var fcl: PackedColorArray = fc["fcols"]
				for k in range(1, fp.size() - 1):
					tb.tri_colored(fp[0], fp[k], fp[k + 1], fcl[0], fcl[k], fcl[k + 1])
			elif fc.has("uvs"):                              # terrain land (textured run)
				tb.mark_run(true, tex_rid)
				tb.quad_textured(fc["poly"], fc["cols"], fc["uvs"])
			else:                                            # wood
				tb.mark_run(false, RID())
				tb.quad_colored(fc["poly"], fc["cols"])
		return tb.take_chunks()

	# How far this tree has come this season, staggered per tree so the wood fills in as stands.
	func _grown(tr: Dictionary) -> float:
		return clampf((season_t - float(tr["delay"])) / 0.45, 0.0, 1.0)

	# Place a model-local point into the world: yaw, scale, then the wind bend - a cantilever
	# displacement growing as the square of height above the base. It never resizes the wood.
	func _pose(p: Vector3, base: Vector3, s: float, cy: float, sy: float,
			bend: float, inv_h: float) -> Vector3:
		var x := p.x * cy - p.z * sy
		var z := p.x * sy + p.z * cy
		var hy := p.y * s
		var t := clampf(hy * inv_h, 0.0, 1.0)
		var k := bend * t * t
		return Vector3(base.x + x * s + wind.x * k, base.y + hy, base.z + z * s + wind.z * k)

	func _fog(c: Color, t: float) -> Color:
		if t <= 0.002:
			return c
		return Color(lerpf(c.r, fog_col.r, t), lerpf(c.g, fog_col.g, t),
			lerpf(c.b, fog_col.b, t), c.a)

	# One tree at LOD `mode`: 0 = articulated (tubes on heavy wood, ribbons on twigs, full foliage),
	# 1 = ribbons with the finest order dropped and thinned foliage, 2 = a silhouette (trunk ribbon
	# plus crown puffs).
	func _emit_tree(faces: Array, tree_entry, mode: int, dst: float, ldir: Vector3) -> void:
		var tr: Dictionary = tree_entry
		var g := _grown(tr)
		if g <= 0.02:
			return
		var model: Dictionary = models[int(tr["model"])]
		var base: Vector3 = tr["pos"]
		var s: float = float(tr["scale"])
		var cy: float = float(tr["cy"])
		var sy: float = float(tr["sy"])
		var th: float = maxf(0.001, float(tr["h"]))
		var inv_h := 1.0 / th
		# The gust arrives here and not everywhere: `along` is this tree's coordinate on the wind
		# axis and the front is a gaussian window traveling along it.
		var along := wind.x * base.x + wind.z * base.z
		var ph := (along - front) / maxf(0.05, gust_width)
		var local := gust * exp(-ph * ph)
		var swing := sin(clock * float(tr["rate"]) + float(tr["phase"]))
		var ripple := sin(clock * float(tr["rate"]) * 1.7 + float(tr["phase"]) * 1.3)
		var bend := th * (gust_amp * (0.16 + 0.30 * breeze) * swing
			+ gust_amp * 1.5 * local * (0.65 + 0.35 * ripple))
		var shade := 0.42 + 0.58 * terrain.shadow_at(base.x, base.z)
		var band := clampf(f.sample(float(tr["t"])), 0.0, 1.0)
		var fogt := clampf(smoothstep(fog_near, fog_far, dst), 0.0, 1.0)
		var hue_off: float = float(tr["hue"])
		var segs: Array = model["segs"]
		var lends: PackedInt32Array = model["level_end"]
		# How much of the structure this LOD walks. Segments are stored in level order, so one index
		# is the whole cull.
		var limit := segs.size()
		if mode == 2:
			limit = int(lends[0]) if lends.size() > 0 else 0
		elif mode == 1 and lends.size() > 1:
			limit = int(lends[clampi(lends.size() - 3, 1, lends.size() - 1)])
		var barkv := clampf(bark_val * shade * (0.72 + 0.30 * band) * lit, 0.05, 1.4)
		for si in limit:
			var sg: Dictionary = segs[si]
			var b0: float = float(sg["born0"])
			if b0 > g:
				continue
			var sd: int = int(sg["depth"])
			# The segment straddling the growth front is shortened, so the wood extends smoothly.
			var la: Vector3 = sg["a"]
			var lb: Vector3 = sg["b"]
			var frac := clampf((g - b0) / maxf(1e-4, float(sg["born"]) - b0), 0.0, 1.0)
			if frac < 0.999:
				lb = la.lerp(lb, frac)
			var wa := _pose(la, base, s, cy, sy, bend, inv_h)
			var wb := _pose(lb, base, s, cy, sy, bend, inv_h)
			var w0: float = float(sg["w0"]) * s
			var w1: float = float(sg["w1"]) * s
			# Finer wood is paler and less saturated.
			var fine := clampf(float(sd) / 4.0, 0.0, 1.0)
			var col := Color.from_hsv(fposmod(bark_hue + hue_off * 0.5, 1.0),
				clampf(bark_sat * (1.0 - 0.3 * fine), 0.02, 0.95),
				clampf(barkv * (1.0 + 0.22 * fine), 0.03, 1.4), reveal)
			col = _fog(col, fogt * 0.85)
			if mode == 0 and sd <= 1:
				# Only heavy wood is worth a closed tube; a twig's tube is three sub-pixel quads.
				Branch3D.loft_tube(faces, lens, u, wa, wb, w0, w1, SIDES, col, ldir,
					0.42, rim * 0.55)
			else:
				var dim := Color(col.r * 0.78, col.g * 0.78, col.b * 0.78, col.a)
				Branch3D.loft_ribbon(faces, lens, u, wa, wb, w0, w1, dim, col)
		if mode == 2:
			_emit_puffs(faces, tr, model, base, s, cy, sy, bend, inv_h, g, band, shade, fogt, ldir)
			return
		if leaf_density <= 0.02:
			return
		# Foliage: density thins the cluster count by striding the leaf sites; the middle LOD band thins it again.
		var lv: Array = model["leaves"]
		var crown_cen: Vector3 = model["crown"]
		var st: Dictionary = stands[int(tr["stand"])] if not stands.is_empty() else {}
		var st_stride := int(st.get("stride", 1))
		var stride := maxi(1, int(round(float(st_stride) / maxf(0.05, leaf_density))))
		if mode == 1:
			stride *= 3
		var shed_level := shed * float(tr["shed_bias"])
		var st_sat := float(st.get("sat", 0.6))
		var st_val := float(st.get("val", 0.8))
		var st_dh := float(st.get("dh", 0.0))
		var st_turn := float(st.get("turn", 1.0))
		var st_acc := float(st.get("acc_dh", 0.2))
		var st_sides := int(st.get("sides", 7))
		var st_ragged := float(st.get("ragged", 0.25))
		var st_hard := float(st.get("hard", 0.6))
		var lsat := clampf(st_sat * (0.85 + 0.3 * band), 0.03, 0.98)
		for li in range(0, lv.size(), stride):
			var lf: Dictionary = lv[li]
			if float(lf["born"]) > g:
				continue
			# The leaf is on the tree until the season's shed level passes its threshold, then fades
			# over a short band: a pure function of the two.
			var rel: float = float(lf["release"])
			var alive := 1.0 - smoothstep(rel, rel + 0.07, shed_level)
			if alive <= 0.02:
				continue
			var lpos: Vector3 = lf["p"]
			var lp := _pose(lpos, base, s, cy, sy, bend, inv_h)
			# The fast half of the wind: leaf masses flutter where the trunk sways.
			var fw := flutter * float(lf["size"]) * s * 1.4
			var fa := clock * 9.0 + float(lf["phase"])
			lp += _cam_r * (sin(fa) * fw) + _cam_u * (cos(fa * 1.3) * fw * 0.6)
			# The stand's hue, this leaf's jitter and the base-to-tip turn, and on the accent share a
			# second hue. `leaf_hue` carries the live chroma blend.
			var h := fposmod(leaf_hue + st_dh + hue_off + float(lf["hue"])
				+ leaf_turn * st_turn * float(lf["along"])
				+ st_acc * float(lf.get("acc", 0.0)), 1.0)
			# Crown volume: each cluster is shaded by which side of the crown it sits on (toward the key
			# light or away), one dot product per billboard. The offset is yawed with the instance.
			var away := lpos - crown_cen
			var ax := away.x * cy - away.z * sy
			var az := away.x * sy + away.z * cy
			var facing := clampf((ax * ldir.x + away.y * ldir.y + az * ldir.z)
				/ maxf(0.0001, away.length()) * 0.5 + 0.5, 0.0, 1.0)
			var v := clampf(st_val * shade * (0.68 + 0.36 * band + 0.22 * glow) * lit
				* (0.62 + 0.62 * facing) * float(lf.get("dap", 1.0)), 0.05, 1.35)
			var core := Color.from_hsv(h, lsat, v, reveal * alive * 0.92)
			Branch3D.billboard_fan(faces, lens, u, lp, _cam_r, _cam_u,
				float(lf["size"]) * s, _fog(core, fogt * 0.8), st_sides,
				st_ragged, float(lf["ragged"]), st_hard)

	# The silhouette: a distant tree is its crown, three to six puffs sized off the model's leaf mass.
	func _emit_puffs(faces: Array, tr: Dictionary, model: Dictionary, base: Vector3, s: float,
			cy: float, sy: float, bend: float, inv_h: float, g: float, band: float,
			shade: float, fogt: float, ldir := Vector3.UP) -> void:
		if leaf_density <= 0.05 or g < 0.5:
			return
		var open := smoothstep(0.45, 1.0, g) * clampf(leaf_density * 1.2, 0.0, 1.0)
		var alive := 1.0 - smoothstep(0.35, 0.85, shed * float(tr["shed_bias"]))
		var a := reveal * (0.35 + 0.5 * alive) * open
		if a <= 0.02:
			return
		var st: Dictionary = stands[int(tr["stand"])] if not stands.is_empty() else {}
		var v := clampf(float(st.get("val", 0.8)) * shade * (0.62 + 0.3 * band) * lit, 0.05, 1.3)
		var col := _fog(Color.from_hsv(fposmod(leaf_hue + float(st.get("dh", 0.0))
			+ float(tr["hue"]) + leaf_turn * float(st.get("turn", 1.0)), 1.0),
			clampf(float(st.get("sat", 0.6)) * 0.9, 0.03, 0.95), v, a), fogt * 0.9)
		var puffs: Array = model["puffs"]
		# Rounder and wider-faceted than a leaf cluster, since it stands in for a whole crown (a
		# five-point fan with a leaf's raggedness reads as a star). Same color as the near trees' foliage.
		var cen: Vector3 = model["crown"]
		for entry in puffs:
			var pf: Dictionary = entry
			var pp: Vector3 = pf["p"]
			var wp := _pose(pp, base, s, cy, sy, bend, inv_h)
			# The same crown shading as near trees, so lighting does not change across a LOD band.
			var aw := pp - cen
			var axx := aw.x * cy - aw.z * sy
			var azz := aw.x * sy + aw.z * cy
			var fac := clampf((axx * ldir.x + aw.y * ldir.y + azz * ldir.z)
				/ maxf(0.0001, aw.length()) * 0.5 + 0.5, 0.0, 1.0)
			var pcol := Color(col.r * (0.66 + 0.58 * fac), col.g * (0.66 + 0.58 * fac),
				col.b * (0.66 + 0.58 * fac), col.a)
			# Distant crowns keep the stand's hardness: the far half of the wood is most of it, and a
			# soft puff reads as cotton wool. Haze is the fog term's job.
			Branch3D.billboard_fan(faces, lens, u, wp, _cam_r, _cam_u,
				float(pf["r"]) * s * open, pcol, 8, 0.42, float(pf["ragged"]),
				0.82 * float(st.get("hard", 0.6)))
