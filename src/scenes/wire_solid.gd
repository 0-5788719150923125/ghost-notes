extends Scene3D

## Wire solid - a translucent polyhedron on the unified 3D path.
##
## A true cube / octahedron / tetrahedron / icosahedron ([Mesh3D]) projected through a [Lens3D]:
## perspective, depth sorted, faces faint and edges bright so you see through it. It rotates
## slowly and continuously, which is how the volume reveals itself; energy only nudges the pace
## and audio drives the glow. The body lives in a [Scene3D] camera world, and the lens eases in.
##
## A [constant SOLID] rolls the form and the proportions together, and a [Scheme] supplies the
## saturation as well as the hue (an ash body reads as smoked glass, a toxic one as acid).

## The body: which forms suit a given set of proportions, how far they are stretched, and how
## transparent the faces are. They belong together: a dense geodesic cage needs fainter faces
## than a cube or the overlap turns solid, and an obelisk is convincing only from forms with a
## clear top and bottom.
##
## The scales squash rather than grow: a slab is the ratio between its axes, and a body already
## fills the frame at 1:1:1, so stretching the long axis would only crop it.
const SOLID := {
	"platonic": {"forms": ["cube", "octa", "tetra", "icosa"],
		"scale": Vector3(1.00, 1.00, 1.00), "alpha": [0.16, 0.28]},
	"obelisk":  {"forms": ["cube", "octa", "tetra"],
		"scale": Vector3(0.36, 1.30, 0.36), "alpha": [0.14, 0.24]},
	"slab":     {"forms": ["cube", "octa", "icosa"],
		"scale": Vector3(1.15, 0.33, 1.15), "alpha": [0.18, 0.30]},
	"blade":    {"forms": ["cube", "tetra", "icosa"],
		"scale": Vector3(1.20, 0.72, 0.26), "alpha": [0.18, 0.30]},
	"geode":    {"forms": ["geodesic"],
		"scale": Vector3(1.00, 1.00, 1.00), "alpha": [0.09, 0.16]},
}

var _f: AudioFeatures = AudioFeatures.new()
var _mesh: Mesh3D
var _rot := Vector3.ZERO
var _hue := 0.0
var _sat := 0.5
var _glow := 0.0
# Async per-face flicker (a random roll): each face lights on its own phase and rate, so the
# solid shimmers face by face.
var _async := false
var _fphase := PackedFloat32Array()
var _frate := PackedFloat32Array()
var _fglow := PackedFloat32Array()


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a
## storyboard entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"body": {"label": "Body", "type": "choice", "options": "SOLID", "default": null,
		"blurb": "The body's proportions: platonic, a tall obelisk, a flat slab, a thin blade, or a geodesic geode."},
	"fov": {"label": "Field of view", "type": "num", "range": [42.0, 56.0], "default": null,
		"blurb": "How wide the camera's view of the solid is."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	framing = "plane"                       # the lens frames it; keep the 2D view square-on
	var kind := String(choice("body", rng))
	var sd: Dictionary = SOLID[kind]
	var forms: Array = sd["forms"]
	var form := String(forms[rng.randi() % forms.size()])
	_mesh = _make(form)
	var sc: Vector3 = sd["scale"]
	if not sc.is_equal_approx(Vector3.ONE):
		_mesh.stretch(sc)                   # same topology, a different silhouette
	_rot = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	# Any mood: a translucent solid is convincing in all of them, and the scheme carries the
	# saturation too.
	var sch := Scheme.pick(rng)
	_hue = sch.vary(rng)
	_sat = clampf(sch.sat * rng.randf_range(0.85, 1.1), 0.0, 1.0)
	# Roll for the async per-face flicker; if on, seed each face its own phase and rate.
	_async = rng.randf() < 0.6
	var nf := _mesh.faces.size()
	_fglow.resize(nf)
	for i in nf:
		_fphase.append(rng.randf() * TAU)
		_frate.append(rng.randf_range(0.5, 2.6))
	lens.fov = number("fov", rng)
	lens.eye = Vector3(0.0, 0.0, rng.randf_range(3.4, 4.4))   # a touch of perspective
	var ab: Array = sd["alpha"]
	return {
		# Slow tumble axis (rad/s): a full turn takes the better part of a minute.
		"spin": Vector3(
			rng.randf_range(0.04, 0.12),
			rng.randf_range(0.04, 0.12),
			rng.randf_range(-0.06, 0.06)),
		"face_alpha": rng.randf_range(float(ab[0]), float(ab[1])),
		"solid": kind, "form": form, "mood": sch.name, "hue": _hue, "sat": _sat,
		"faces": _mesh.faces.size(), "async": _async,
	}


# One body of the named form. `geodesic` is the icosahedron subdivided once: eighty faces of wire
# instead of twenty.
func _make(form: String) -> Mesh3D:
	match form:
		"cube": return Mesh3D.cube()
		"octa": return Mesh3D.octahedron()
		"tetra": return Mesh3D.tetrahedron()
		"geodesic": return Mesh3D.icosphere(1)
		_: return Mesh3D.icosphere(0)


func update(f: AudioFeatures, delta: float) -> void:
	_f = f
	tick(f, delta)
	drift_view(f, 0.03, 0.05)
	var spin: Vector3 = params.spin
	# Slow continuous 3D rotation reveals the solid; energy only nudges the pace.
	_rot += spin * delta * (0.7 + 0.5 * f.energy)
	# Audio drives the *glow*, not the size - the solid holds its shape.
	if _async:
		# Each face flickers on its own phase and rate, driven (not synced) by the audio.
		var drive := 0.25 + 0.55 * f.beat + 0.3 * f.energy
		for i in _mesh.faces.size():
			_fglow[i] = clampf((0.5 + 0.5 * sin(_life * float(_frate[i]) + float(_fphase[i]))) * drive, 0.0, 0.85)
		_mesh.face_glow = _fglow
		_glow = 0.04
	else:
		_mesh.face_glow = PackedFloat32Array()
		_glow = 0.35 * f.beat + 0.18 * f.energy
	bodies.clear()
	add_body(_mesh, Basis.from_euler(_rot), Vector3.ZERO, 0.7,
		fposmod(_hue + 0.04 * f.energy, 1.0), _sat, 2, float(params.face_alpha), _glow)
	queue_redraw()


func _draw() -> void:
	begin_draw()
	render_world()
