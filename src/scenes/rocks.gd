extends GhostScene

## Rocks - faceted stones in real 3D, sampled from a small material/geometry spec.
##
## Each rock is a [Mesh3D] rotated by a 3D basis, depth-sorted and shaded. The look is a sampled
## configuration of composable layers: a geometry family, a surface texture, a material (gloss,
## roughness) and sometimes a partial wireframe reveal. The seeded style sets the character:
##   plain   - smooth rounded mass, satin sheen.
##   rough   - craggy boulder, matte, dark facet relief.
##   crystal - faceted gem, bright edges, glossy.
##   hybrid  - a geometric base (cube / octa / tetra) with rock crusting over part of it
##             (gaussian-masked growth).
## Independently, a rock may be partially revealed: a gaussian alpha mask punches holes in its
## coat (a sampled threshold, from sparse bare patches to half-and-half) so the wireframe
## lattice shows through. The seeded mode sets the motion: `pulse` (breathe), `explode` (faces
## burst out on the beat), `crumble` (faces push apart once, then the scene ends).
##
## Material, responsiveness and reveal are sampled per rock around the style's center. Color is
## a [Scheme] mood suited to the style (matte stone gets earthy moods, the gem jewel ones); the
## stones share a tight hue family or spread base-to-accent. The composition is sampled too: a
## couple of colossal boulders, a resting cluster, or a wide scatter of scree.

enum Mode { PULSE, EXPLODE, CRUMBLE }
## ARRANGEMENTS - how many stones and how big, sampled as a set: a couple of colossi filling the
## frame, a resting cluster, or a wide scatter of small stones. A scatter carries its own style
## list (scree is chips and shards, and the smooth style is the heaviest mesh, too costly for a
## dozen).
const ARRANGEMENTS := {
	"boulders": {"count": [1, 3],  "zoom": [1.9, 2.8], "spread": [0.0, 0.45], "radius": [0.12, 0.22],
		"styles": ["plain", "rough", "crystal", "hybrid"]},
	"cluster":  {"count": [3, 5],  "zoom": [1.4, 2.2], "spread": [0.0, 0.65], "radius": [0.10, 0.20],
		"styles": ["plain", "rough", "crystal", "hybrid"]},
	"scree":    {"count": [6, 10], "zoom": [0.8, 1.2], "spread": [0.20, 1.0], "radius": [0.07, 0.16],
		"styles": ["rough", "crystal", "hybrid"]},
}
## Which moods a stone of each style can be: earthy moods for the matte styles, jewel ones for
## the faceted gem; within that, any.
const STYLE_MOODS := {
	"plain":   ["ash", "bone", "brass", "dawn", "sodium", "abyss", "glacier", "verdant"],
	"rough":   ["ash", "bone", "brass", "ember", "dawn", "sodium", "verdant", "abyss"],
	"crystal": ["violet", "magenta", "teal", "glacier", "rose", "toxic", "abyss", "ember"],
}
# Per-style material centers (each rock samples around these): [edge, sat, gloss, roughness].
const MATERIAL := {
	"plain":   {"edge": 0, "sat": 0.30, "gloss": 0.18, "rough": 0.6},
	"rough":   {"edge": 1, "sat": 0.42, "gloss": 0.05, "rough": 0.95},
	"crystal": {"edge": 2, "sat": 0.50, "gloss": 0.55, "rough": 0.18},
	"hybrid":  {"edge": 1, "sat": 0.38, "gloss": 0.30, "rough": 0.45},
}

var _f: AudioFeatures = AudioFeatures.new()
var _mode := Mode.PULSE
var _style := "plain"
var _rocks: Array = []
var _act: Activation
var _edge := 0
var _crumble_t := 0.0
var _done := false


## What this scene can be told ([method GhostScene.choice]): a storyboard entry's `set`, by
## name; a setting not told is drawn from the seed.
const FIELDS := {
	"arrangement": {"label": "Arrangement", "type": "choice", "options": "ARRANGEMENTS", "default": null,
		"blurb": "How many stones and how big: a couple of boulders filling the frame, a resting cluster, or a wide scatter of small scree."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "mesh3d"
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # so the panned reveal mask wraps seamlessly
	_mode = rng.randi_range(0, 2)
	# Composition first: it decides which stone styles belong in it (see ARRANGEMENTS).
	var arrangement := String(choice("arrangement", rng))
	var arr: Dictionary = ARRANGEMENTS[arrangement]
	var styles: Array = arr.styles
	_style = String(styles[rng.randi() % styles.size()])
	lifecycle = "oneshot" if _mode == Mode.CRUMBLE else "loop"

	var mat: Dictionary = MATERIAL[_style]
	_edge = int(mat.edge)
	# How much of this scene leans skeletal is sampled: from all solid to mostly wireframe.
	var reveal_chance := 0.0 if rng.randf() < 0.3 else rng.randf_range(0.3, 0.9)

	# Color comes from a shared [Scheme] mood suited to the style.
	var sch := Scheme.pick(rng) if _style == "hybrid" else Scheme.among(STYLE_MOODS[_style], rng)
	# Two ways a set of stones can relate: a tight family (near the base hue, one stone type) or
	# a spread from base to accent (a mixed deposit).
	var family := rng.randf() < 0.45
	var count := rng.randi_range(int(arr.count[0]), int(arr.count[1]))
	var zoom := rng.randf_range(float(arr.zoom[0]), float(arr.zoom[1]))   # > 1 pushes rocks off-frame
	for i in count:
		# Sample the geometry family for this rock.
		var mesh := Mesh3D.hybrid(rng) if _style == "hybrid" else Mesh3D.rock(_style, rng)
		var spin := Vector3(
			rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.4))
		# Spread wide, well past the frame edges, so big rocks are only partly on screen.
		var spread := rng.randf_range(float(arr.spread[0]), float(arr.spread[1]))
		var ang := rng.randf() * TAU
		# Family: everyone drifts a little off the base. Spread: the i-th of `count` related hues,
		# base through accent.
		var hue := sch.vary(rng) if family else fposmod(
			sch.hue_at(i, count) + rng.randf_range(-0.02, 0.02), 1.0)
		var rock := {
			"mesh": mesh,
			"verts0": mesh.verts.duplicate(),   # pristine geometry, for the collision dent
			"center": Vector2(cos(ang), sin(ang)) * spread + Vector2(
				rng.randf_range(-0.12, 0.12), rng.randf_range(-0.10, 0.10)),
			"radius": rng.randf_range(float(arr.radius[0]), float(arr.radius[1])) * zoom,
			"hue": hue,
			"basis": Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0.0)),
			"spin": spin.normalized() * rng.randf_range(0.07, 0.16),   # gentle
			"e": 0.0,
			"glow": 0.0,
			# Material sampled around the style center, then scaled by the mood's own saturation
			# (ash stones come out gray, toxic ones lurid).
			"sat": clampf(float(mat.sat) * (0.35 + 1.3 * sch.sat)
				+ rng.randf_range(-0.10, 0.10), 0.0, 1.0),
			"gloss": clampf(float(mat.gloss) * rng.randf_range(0.7, 1.3), 0.0, 1.0),
			"rough": clampf(float(mat.rough) + rng.randf_range(-0.12, 0.12), 0.05, 1.0),
			"react": rng.randf_range(0.75, 1.3),   # per-rock responsiveness to the audio
			"reveal": false,
			"rtex": null,
			"wire": Color.WHITE,
			"pan": 0.0, "pan_rate": 0.0,   # reveal rocks: continuous mask drift (set below)
			"pan_seed": 0.0,               # per-rock phase for the spatially-varying drift field
		}
		# Partial wireframe reveal with a sampled masking threshold: low = mostly coat with sparse
		# bare patches, near 0 = roughly half-and-half.
		if rng.randf() < reveal_chance:
			rock.reveal = true
			# -0.35 = mostly coat, sparse bare patches; 0.0 = roughly half-and-half (the heaviest).
			var threshold := rng.randf_range(-0.35, 0.0)
			rock.rtex = Mesh3D.reveal_texture(rng, threshold,
				rng.randf_range(0.10, 0.22), rng.randf_range(0.03, 0.07))
			# The lattice under the coat is the mood's accent, near-white.
			rock.wire = sch.color(sch.accent, rng.randf_range(0.1, 0.4),
				1.4, rng.randf_range(0.6, 0.85))
				# Each revealed rock's crust drifts at its own slow rate and direction, so the
				# mask is always gently panning.
			rock.pan_rate = rng.randf_range(0.015, 0.055) * (1.0 if rng.randf() < 0.5 else -1.0)
			rock.pan_seed = rng.randf_range(0.0, TAU)
		_rocks.append(rock)
	# Settle the cluster so stones rest against each other instead of passing through; a light
	# overlap is left so the contact dent still shows.
	_relax_positions(rng)
	# Some instances have everyone stir; others keep most rocks rooted.
	var sparsity := 0.0 if rng.randf() < 0.4 else rng.randf_range(0.3, 0.7)
	_act = Activation.new(count, rng, sparsity)
	return {"mood": sch.name, "style": _style, "arrangement": arrangement,
		"count": count, "hues": "family" if family else "spread"}


# Push overlapping rock centers apart over a few relaxation passes until they only lightly
# overlap. The pushes are symmetric so the cluster stays centered (the biggest stones still
# overflow the frame). Positions are static after this, so one settle at build time is enough.
func _relax_positions(rng: RandomNumberGenerator) -> void:
	for _iter in 32:
		var moved := false
		for i in _rocks.size():
			for j in range(i + 1, _rocks.size()):
				var a: Dictionary = _rocks[i]
				var b: Dictionary = _rocks[j]
				var d: Vector2 = Vector2(b.center) - Vector2(a.center)
				var dist := d.length()
				var mind: float = (float(a.radius) + float(b.radius)) * 0.86   # ~14% overlap kept
				if dist < 1e-4:
					d = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
					dist = 0.001
				if dist < mind:
					var push: Vector2 = (d / dist) * (mind - dist) * 0.5
					a.center = Vector2(a.center) - push
					b.center = Vector2(b.center) + push
					moved = true
		if not moved:
			break


func finished() -> bool:
	return _done


func update(f: AudioFeatures, delta: float) -> void:
	_f = f
	tick(f, delta)
	drift_view(f, 0.03, 0.04, 0.03, 0.05)
	var drive := clampf(f.energy * 0.8 + f.beat * 0.7, 0.0, 1.3)
	_act.update(drive, delta)

	for ri in _rocks.size():
		var rock: Dictionary = _rocks[ri]
		var a := _act.level(ri)
		var react: float = rock.react
		# Drift the reveal mask (slightly faster with activation) so the crust keeps panning.
		rock.pan += delta * float(rock.pan_rate) * (1.0 + 0.6 * a)
		# Rooted rocks barely turn; activation earns rotation.
		rock.basis = rock.basis * Basis.from_euler(rock.spin * delta * (0.1 + 0.9 * a))
		match _mode:
			Mode.PULSE:
				# Pulse the light, not the size - the rock holds its form.
				rock.glow = (0.25 * f.energy + 0.40 * f.beat) * a * react
			Mode.EXPLODE:
				rock.e = maxf(rock.e, f.beat * a * 0.5 * react)
				rock.e = maxf(0.0, rock.e - delta * 0.5)
			Mode.CRUMBLE:
				rock.e = minf(0.55, rock.e + delta * 0.22)

	if _mode == Mode.CRUMBLE:
		_crumble_t += delta
		if _crumble_t > 4.5:
			_done = true
	_deform_collisions()
	queue_redraw()


# Where two rocks overlap (their screen circles intersect), dent the contact-facing faces inward
# so the panels bend. The dent is in world space at the contact: each frame the pristine
# geometry is restored and the vertices that currently rotate into the contact direction are
# pushed back along it, so a spinning rock's surface flows through a dent that stays put.
# Bounded and only while overlapping.
func _deform_collisions() -> void:
	var n := _rocks.size()
	for i in n:
		var rock: Dictionary = _rocks[i]
		var verts: PackedVector3Array = (rock.verts0 as PackedVector3Array).duplicate()
		var ci: Vector2 = rock.center
		var ri: float = rock.radius
		var basinv := (rock.basis as Basis).inverse()
		for j in n:
			if j == i:
				continue
			var other: Dictionary = _rocks[j]
			var d: Vector2 = Vector2(other.center) - ci
			var dist := d.length()
			var overlap: float = (ri + float(other.radius)) - dist
			if overlap <= 0.0 or dist < 1e-4:
				continue
			# Contact direction (toward the neighbor), mapped from world/screen into this rock's
			# object space; dent depth grows with the overlap.
			var ldir := (basinv * Vector3(d.x / dist, d.y / dist, 0.0)).normalized()
			var dent := clampf(overlap / ri, 0.0, 0.7) * 0.45
			for k in verts.size():
				var v := verts[k]
				var vl := v.length()
				if vl < 1e-5:
					continue
				var facing := (v / vl).dot(ldir)
				if facing > 0.15:
					verts[k] = v - ldir * ((facing - 0.15) * dent * vl)
		rock.mesh.verts = verts


func _draw() -> void:
	begin_draw()
	var u := unit()
	for rock: Dictionary in _rocks:
		var mesh: Mesh3D = rock.mesh
		var c := Vector2(rock.center) * u
		var rad := float(rock.radius) * u
		if rock.reveal:
			# Exploded-faces modes do not apply to a revealed shell (they would tear the lattice
			# apart); reveal rocks breathe with light only.
			mesh.draw_revealed(self, rock.basis, c, rad,
				float(rock.hue), float(rock.sat), float(rock.glow), rock.wire, rock.rtex,
				float(rock.pan), float(rock.pan_seed))
		else:
			mesh.draw_shaded(self, rock.basis, c, rad, float(rock.hue), float(rock.sat),
				float(rock.e), _edge, 1.0, float(rock.glow), float(rock.gloss), float(rock.rough))
