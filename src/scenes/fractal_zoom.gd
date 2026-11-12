extends GhostScene

## Fractal zoom - falling into (or back out of) an escape-time set, forever.
##
## The frame is one fragment program over the complex plane (shaders/fractal_field.gdshader); this half
## chooses which set, where in it, how it is colored and how the camera moves, all sampled per session.
##
## The zoom goes one way and never turns round: `direction` is PUSH (inward, two rolls in three) or PULL
## (outward, structure assembling out of the middle and receding). No mode reverses on a clock.
##
## Speed is a journey time, not a rate: what a family can resolve varies twenty-fold (see the floors), so
## the whole descent's duration is sampled and divided by the depth available. The music scales the rate
## (loud passages fall faster), the only thing audio touches: the set never deforms to the music.
##
## The zoom floor is the one hard constraint: float32 runs out at about 3e-4 of the starting view. The
## quadratic Mandelbrot escapes that through perturbation (see the shader's header): the reference orbit is
## iterated here in 64-bit floats and the shader handles only the difference. Other families iterate directly
## and are clamped to the depth float32 holds. `_zl_min` is set from the family's floor and the zoom eases
## to rest against it. The anchor is held as two loose `float`s, never a Vector2 (32-bit would round away
## the last six digits, which at depth are the whole location).
##
## The seed decides: the family (mandelbrot / julia / burning ship / tricorn / celtic / buffalo) and power;
## a Julia parameter's place on the cardioid; the anchor (a local search toward the boundary); the coloring
## and its parameters; a seamless cyclic palette from a [Scheme]; the interior treatment; the iteration
## budget; the zoom's direction, speed and turning points; the frame's rotation; the vignette.

const SHADER := preload("res://shaders/fractal_field.gdshader")

## Iteration ceiling. The escape loop runs per pixel per frame, so this is a real frame cost (most pixels
## leave in a handful of steps; the boundary runs the whole way). It also decides how deep the scene may
## go: too small a budget classifies points that would escape as interior, growing a flat black skirt with
## confetti outside it (335 iterations at a depth needing about 1400). FLOOR_PERTURB is set from this.
const ITER_MAX := 3000

## How long a reference orbit may be. The shader rebases when it runs off the end, so a short one costs
## accuracy; the anchor search hunts for slow-escaping points, so this is sized for them.
const REF_MAX := 4096

## The palette ramp's resolution (sampled with fract() and interpolated, so this is about banding).
const RAMP := 256

## Families, by shader index: the same iteration under a different fold of the plane, sharing one program.
const FAMILIES := ["mandelbrot", "julia", "burning_ship", "tricorn", "celtic", "buffalo"]

## Colorings, by shader index.
const COLORS := ["smooth", "stripe", "trap_point", "trap_cross", "trap_circle", "distance"]

## The zoom's directions as a bag: the fall inward is the common picture, the climb out is rarer.
const DIRECTION_BAG := ["push", "push", "pull"]

## How long the whole descent takes at nominal loudness, in seconds, divided by the depth available to get a
## rate. A scene holds at most about 60 to 134 s (`Director.max_hold` x `pace_calm_scale` x `pacing`), so a
## fast instance can still reach its bound; that is what the ease-to-rest is for.
const JOURNEY_MIN := 95.0
const JOURNEY_MAX := 260.0

## How many e-folds out from a bound the rate starts easing off; wide enough to read as settling.
const ARRIVE_SPAN := 1.6

## The family roll, weighted. The quadratic Mandelbrot is the only family perturbation is implemented
## for, so it can be flown into indefinitely and earns the largest share; the folded families wear out fastest.
const FAMILY_BAG := [0, 0, 0, 0, 1, 1, 1, 2, 2, 3, 4, 5]

## Scale (half the frame's height, in complex units) of the widest view: about the whole Mandelbrot set.
const SCALE_WIDE := 1.45

## The deepest scale each path may reach. The direct one is float32's limit with a margin under it; the
## perturbed one is set by ITER_MAX: about sixteen e-folds is as far as the escape count can be resolved
## inside the budget, one to five minutes of continuous fall at the sampled speeds.
const FLOOR_DIRECT := 3.0e-4
const FLOOR_PERTURB := 1.0e-7

var _mat := ShaderMaterial.new()
var _quad: Layer.FieldQuad = null
var _sch: Scheme

# The definition.
var _family := 0
var _power := 2
var _color := 0
var _perturb := false
var _iter_base := 320
var _iter_gain := 90.0
var _cycle := 0.06
var _stripe := 5.0
var _trap_p := Vector2.ZERO
var _trap_r := 0.6
var _interior := 0
var _in_col := Color(0.02, 0.02, 0.05)
var _gain := 1.0
var _vig := 0.25
var _bail := 256.0

## The anchor, in float64 and never in a Vector2 - see the header.
var _cx := -0.75
var _cy := 0.0

# The Julia parameter and its drift, apart from the anchor: for a Julia set the plane drawn is the z-plane
# and the parameter makes it that set.
var _jr := 0.0                # angle on the cardioid
var _jpush := 0.0             # how far off the cardioid boundary (0 = on it)
var _jx := -0.8
var _jy := 0.156

# The zoom.
var _zl := 0.0                # ln of the current scale
var _zl_min := 0.0
var _zl_max := 0.0
var _speed := 0.2             # e-folds per second at nominal loudness
var _dir := -1.0              # -1 inward (scale shrinking), +1 outward. NEVER REASSIGNED.

# Live state.
var _rot := 0.0
var _rot_rate := 0.0
var _phase := 0.0
var _phase_rate := 0.05
var _glow := 0.0
var _energy := 0.0
var _ch := Vector2.ZERO
var _ch_seeded := false


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a storyboard
## entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"family": {"label": "Family", "type": "choice", "options": "FAMILY_BAG", "names": "FAMILIES", "default": null,
		"blurb": "Which fractal family is drawn: the Mandelbrot set, a Julia set, the burning ship, the tricorn, the celtic or the buffalo."},
	"direction": {"label": "Direction", "type": "choice", "options": "DIRECTION_BAG", "default": null,
		"blurb": "Which way the zoom goes: falling inward (push) or climbing back out (pull)."},
	"bands": {"label": "Color bands", "type": "num", "range": [0.007, 0.033], "default": null,
		"blurb": "How tightly the bands of color repeat across the fractal."},
	"color_flow": {"label": "Color flow", "type": "num", "range": [-0.045, 0.045], "default": null,
		"blurb": "How fast the colors cycle through the bands, and which way."},
	"vignette": {"label": "Vignette", "type": "num", "range": [0.10, 0.42], "default": null,
		"blurb": "How much the corners of the frame darken."},
	"interior": {"label": "Interior brightness", "type": "num", "range": [0.02, 0.16], "default": null,
		"blurb": "How bright the inside of the set is drawn."},
	"spin": {"label": "Spin", "type": "num", "range": [-0.055, 0.055], "default": null,
		"blurb": "How fast the view turns as it zooms, and which way."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "canvas"
	framing = "field"
	# First, before anything below writes a uniform: the reference orbit is uploaded from inside
	# _find_anchor, and a parameter written to a material with no shader may not survive attaching it.
	_mat.shader = SHADER
	_sch = Scheme.pick(rng)

	_family = int(choice("family", rng))
	# The power. Two is the Mandelbrot; three and up are rounder multibrots, worth being rarer. The
	# Mandelbrot leans harder on two because perturbation is the quadratic Mandelbrot's alone.
	var keep_two := 0.80 if _family == 0 else 0.55
	_power = 2 if rng.randf() < keep_two else rng.randi_range(3, 6)
	_perturb = (_family == 0 and _power == 2)

	if _family == 1:
		# A Julia set is chosen by its parameter, and the interesting ones lie within a hair of the main
		# cardioid's boundary, `c = e^(it)/2 - e^(2it)/4`: the parameter is placed on it and pushed a
		# sampled hair off. It then holds still: a drifting parameter is a different set, and loses the
		# anchor's boundary from the frame within about 25 s.
		_jr = rng.randf() * TAU
		_jpush = rng.randf_range(-0.010, 0.014)
		_julia_at(_jr)

	# The anchor: a random point is almost always far outside the set (a wash) or deep inside (a hole), so
	# it is searched for on the boundary. See _find_anchor.
	var floor_scale := FLOOR_PERTURB if _perturb else FLOOR_DIRECT
	_find_anchor(rng, floor_scale)

	# The coloring. The distance estimate needs a derivative the perturbed path does not carry, so it is
	# offered only on the direct one; chosen here so the two cannot disagree.
	var pool: Array = [0, 0, 1, 1, 2, 3, 4]
	if not _perturb and (_family == 0 or _family == 1):
		pool.append(5)
	_color = int(pool[rng.randi() % pool.size()])
	_stripe = float(rng.randi_range(2, 9))
	var ta := rng.randf() * TAU
	var td := rng.randf_range(0.0, 0.9)
	_trap_p = Vector2(cos(ta) * td, sin(ta) * td)
	_trap_r = rng.randf_range(0.25, 1.10)
	# A bigger escape radius smooths the iteration count, a small one makes crisp bands; traps want a large one.
	_bail = rng.randf_range(64.0, 400.0) if _color < 2 else rng.randf_range(400.0, 4000.0)

	# The budget ramps with depth (see ITER_MAX): escape takes longer nearer the boundary, so a fixed
	# budget draws a deep view as a black skirt with confetti.
	_iter_base = rng.randi_range(420, 700)
	_iter_gain = rng.randf_range(115.0, 200.0)
	# One palette turn per 30 to 140 iterations: faster bands are finer than the screen resolves and the mip
	# sampling averages them to gray (a turn every 13 gave confetti).
	_cycle = number("bands", rng)
	_phase_rate = number("color_flow", rng)
	_gain = rng.randf_range(0.92, 1.18)
	_vig = number("vignette", rng)

	# The interior. Flat is right on a wide view (a silhouette); on a deep view the frame can be mostly
	# interior and how close the orbit came is the only structure, so deep paths lean toward treatments that show it.
	_interior = [0, 0, 1, 2][rng.randi() % 4]
	var iv: float = number("interior", rng)
	_in_col = Color.from_hsv(fposmod(_sch.hue + rng.randf_range(-0.1, 0.1), 1.0),
		clampf(_sch.sat * rng.randf_range(0.3, 0.9), 0.0, 1.0), iv)

	# The zoom.
	var dir_name := String(choice("direction", rng))
	_zl_max = log(SCALE_WIDE)
	_zl_min = log(floor_scale)
	if dir_name == "pull":
		_dir = 1.0
		# A pull begins deep: the picture is structure receding from the middle, which needs depth to climb out of.
		_zl = _zl_min + rng.randf_range(0.4, 2.0)
	else:
		_dir = -1.0
		# A push begins at the top of its range or there is nowhere to go.
		_zl = _zl_max - rng.randf_range(0.0, 1.2)
	# The rate comes from the distance (see JOURNEY_MIN): the depth this instance has in front of it, which
	# for a pull is one to two e-folds less than a push has to fall.
	var journey := rng.randf_range(JOURNEY_MIN, JOURNEY_MAX)
	_speed = absf(_zl_bound() - _zl) / journey
	_rot_rate = number("spin", rng)
	_rot = rng.randf() * TAU

	_build_ramp(rng)
	_push_static()

	return {
		"family": FAMILIES[_family],
		"power": _power,
		"perturbed": _perturb,
		"color": COLORS[_color],
		"direction": dir_name,
		"speed": _speed,
		"journey": "%.0fs" % journey,
		"mood": _sch.name,
		"interior": _interior,
		"iter_base": _iter_base,
		"cycle": _cycle,
		"anchor": "%.12f%+.12fi" % [_cx, _cy],
		"depth": String.num_scientific(exp(_zl_min)),
	}


func update(f: AudioFeatures, delta: float) -> void:
	tick(f, delta)
	# The camera barely breathes: the zoom is the motion, and a drifting frame reads as wobble.
	drift_view(f, 0.012, 0.012)
	update_layers(f, delta)
	if not _ch_seeded:
		_ch_seeded = true
		_ch = chroma_hue()
	# Loudness, smoothed. It only scales rates, so a fast attack would read as the zoom stuttering.
	var e := clampf(f.energy, 0.0, 1.0)
	_energy = lerpf(_energy, e, 1.0 - exp(-1.6 * delta))
	_glow = maxf(_glow * exp(-3.2 * delta), clampf(f.beat, 0.0, 1.0) * 0.22)

	_step_zoom(delta)
	_rot += _rot_rate * delta * (0.7 + 0.6 * _energy)
	_phase += _phase_rate * delta * (0.6 + 0.9 * _energy)
	_push_live()
	queue_redraw()


## Where this instance is headed, and the only bound it will meet: the floor for a push, the whole set for a pull.
func _zl_bound() -> float:
	return _zl_max if _dir > 0.0 else _zl_min


## The zoom, on a logarithmic scale: a constant e-folds per second opens the picture at the same visual rate
## at any depth. One direction, chosen once: `_dir` is written nowhere below.
func _step_zoom(dt: float) -> void:
	# Arrive, never bounce and never grind: past the floor the picture pixelates, past the ceiling there is
	# nothing to see, so the rate is taken off over the last ARRIVE_SPAN e-folds with a smoothstep (no
	# corner at either end). `_rot` and the palette phase keep running, and the journey is sized (see
	# JOURNEY_MIN) so only a long-held scene gets this far.
	var left := clampf(absf(_zl_bound() - _zl) / ARRIVE_SPAN, 0.0, 1.0)
	var arrive := left * left * (3.0 - 2.0 * left)
	_zl += _dir * _speed * (0.55 + 0.9 * _energy) * arrive * dt
	# The ease cannot overshoot, but a caller stepping a huge dt could.
	_zl = clampf(_zl, _zl_min, _zl_max)


## Place the Julia parameter at angle [param t] on the main cardioid, pushed off it by `_jpush`. The
## cardioid separates connected-blob parameters from dust; everything worth seeing is within a hair of it.
func _julia_at(t: float) -> void:
	var c := Vector2(cos(t), sin(t)) * 0.5 - Vector2(cos(2.0 * t), sin(2.0 * t)) * 0.25
	var n := c.normalized() if c.length() > 1e-6 else Vector2.RIGHT
	_jx = c.x + n.x * _jpush
	_jy = c.y + n.y * _jpush


# ---------------------------------------------------------------------------------
# The anchor, and the reference orbit that makes a deep one drawable
# ---------------------------------------------------------------------------------

## Find a point worth falling into, by local search toward the boundary. Escape time is small far from the
## set, infinite inside it and enormous just outside, where the structure is. So this starts wide, samples
## a ring of candidates, keeps the one that took longest to escape (a point that never escapes is rejected),
## halves the radius and repeats, walking the anchor down to the depth the zoom will reach. The iteration
## cap grows with depth, or every candidate would score the same.
func _find_anchor(rng: RandomNumberGenerator, floor_scale: float) -> void:
	var cx := -0.6
	var cy := 0.0
	if _family == 1:
		cx = 0.0
		cy = 0.0
	var radius := 1.35
	var best := -1
	# Seed the walk from the best of a wide scatter, so the search does not start in a lobe it cannot leave.
	for _i in 40:
		var px := cx + rng.randf_range(-radius, radius)
		var py := cy + rng.randf_range(-radius, radius)
		var n := _escape(px, py, 220)
		if n > best and n < 220:
			best = n
			_cx = px
			_cy = py
	if best < 0:
		_cx = cx
		_cy = cy
	# ... then descend, halving the radius each level until under the deepest scale the zoom reaches. Six
	# candidates a level is refinement, not exploration.
	var cap := 260
	while radius > floor_scale * 0.5:
		radius *= 0.5
		cap = mini(ITER_MAX, cap + 60)
		var bx := _cx
		var by := _cy
		var bn := _escape(_cx, _cy, cap)
		if bn >= cap:
			bn = -1              # the current point is interior at this cap: any escaper beats it
		for _i in 6:
			var a := rng.randf() * TAU
			var r := radius * sqrt(rng.randf())
			var px := _cx + cos(a) * r
			var py := _cy + sin(a) * r
			var n := _escape(px, py, cap)
			if n < cap and n > bn:
				bn = n
				bx = px
				by = py
		_cx = bx
		_cy = by
	# No composition pass: moving the center by a fraction of a mid-depth frame's width is thousands of
	# times the final anchor's refinement and throws away the descent. The descent itself guarantees the
	# anchor is on the boundary at every scale. A frame can still be half flat color; a fractal frame legitimately can.
	if _perturb:
		_upload_reference()


## Iterate one point in float64 and return where it escaped, or [param cap] if it never did. Mirrors the
## shader's families exactly, or the search would hunt on a different landscape from the one drawn.
func _escape(px: float, py: float, cap: int) -> int:
	var zx := 0.0
	var zy := 0.0
	var cx := px
	var cy := py
	if _family == 1:
		zx = px
		zy = py
		cx = _jx
		cy = _jy
	for i in cap:
		if _family == 2 or _family == 5:
			zx = absf(zx)
			zy = absf(zy)
		elif _family == 3:
			zy = -zy
		# z^p by repeated multiplication, as the shader does.
		var rx := zx
		var ry := zy
		for _k in _power - 1:
			var nx := rx * zx - ry * zy
			ry = rx * zy + ry * zx
			rx = nx
		if _family == 4 or _family == 5:
			rx = absf(rx)
		zx = rx + cx
		zy = ry + cy
		if zx * zx + zy * zy > 4.0:
			return i
	return cap


## Iterate the anchor's own orbit in float64 and hand it to the shader as a texture, one texel per
## iteration: all perturbation needs from this side (the shader never sees the anchor's coordinates).
## Stored as float32: an error in the reference perturbs the per-pixel delta by a relative amount, so seven
## digits suffice; what must be float64 is the iteration.
func _upload_reference() -> void:
	var zx := 0.0
	var zy := 0.0
	var data := PackedFloat32Array()
	data.append(0.0)                 # Z(0) = 0, which is what the shader's rebase assumes
	data.append(0.0)
	var n := 1
	for _i in REF_MAX - 1:
		var nx := zx * zx - zy * zy + _cx
		zy = 2.0 * zx * zy + _cy
		zx = nx
		data.append(zx)
		data.append(zy)
		n += 1
		if zx * zx + zy * zy > 4.0:
			break
	var img := Image.create_from_data(n, 1, false, Image.FORMAT_RGF, data.to_byte_array())
	_mat.set_shader_parameter("u_orbit", ImageTexture.create_from_image(img))
	_mat.set_shader_parameter("u_ref_len", n)


# ---------------------------------------------------------------------------------
# The palette
# ---------------------------------------------------------------------------------

## Build the color ramp as a closed loop of control colors: the shader samples it with fract(), so differing
## ends would put a hard seam at every palette repeat, and on a smooth iteration count those repeats are the
## image's contour lines. Hues walk from the scheme's base toward its accent and back, so a palette is two
## colors, not a rainbow; values do the same, so every palette has a dark and a bright band.
func _build_ramp(rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(3, 6)
	# The sweep stays inside the scheme's two hues, give or take a third: at 2.2x the ramp crossed three
	# more hues and the mip-averaged frame came out olive whatever the mood.
	var arc := fposmod(_sch.accent - _sch.hue + 0.5, 1.0) - 0.5
	arc *= rng.randf_range(0.7, 1.35)
	var v_lo := rng.randf_range(0.02, 0.16)
	var v_hi := rng.randf_range(0.72, 1.0)
	var s_lo := clampf(_sch.sat * rng.randf_range(0.35, 0.8), 0.0, 1.0)
	var s_hi := clampf(_sch.sat * rng.randf_range(1.0, 1.6), 0.15, 1.0)
	var v_ph := rng.randf() * TAU
	var stops: Array = []
	for i in n:
		var u := float(i) / float(n)
		var w := 0.5 - 0.5 * cos(TAU * u)              # 0 at the ends of the loop, 1 in the middle
		var vw := 0.5 - 0.5 * cos(TAU * u + v_ph)
		stops.append(Color.from_hsv(fposmod(_sch.hue + arc * w, 1.0),
			lerpf(s_hi, s_lo, vw), lerpf(v_lo, v_hi, vw)))
	var img := Image.create(RAMP, 1, false, Image.FORMAT_RGBA8)
	for x in RAMP:
		var t := float(x) / float(RAMP) * float(n)
		var i0 := int(floor(t)) % n
		var i1 := (i0 + 1) % n
		var fr: float = t - floor(t)
		img.set_pixel(x, 0, (stops[i0] as Color).lerp(stops[i1] as Color,
			fr * fr * (3.0 - 2.0 * fr)))
	# Mipmapped: near the set the palette repeats many times across a pixel and point-sampling is
	# confetti; the shader picks a mip level from the screen-space rate of change. See the shader's ANTIALIASING note.
	img.generate_mipmaps()
	_mat.set_shader_parameter("u_ramp", ImageTexture.create_from_image(img))


# ---------------------------------------------------------------------------------
# The uniforms
# ---------------------------------------------------------------------------------

# Everything that cannot change after the roll, split from the per-frame push so a frame is a handful of writes.
func _push_static() -> void:
	_mat.set_shader_parameter("u_family", _family)
	_mat.set_shader_parameter("u_power", _power)
	_mat.set_shader_parameter("u_perturb", _perturb)
	_mat.set_shader_parameter("u_color", _color)
	_mat.set_shader_parameter("u_trap_p", _trap_p)
	_mat.set_shader_parameter("u_trap_r", _trap_r)
	_mat.set_shader_parameter("u_stripe", _stripe)
	_mat.set_shader_parameter("u_cycle", _cycle)
	_mat.set_shader_parameter("u_interior", _interior)
	_mat.set_shader_parameter("u_in_col", Vector3(_in_col.r, _in_col.g, _in_col.b))
	_mat.set_shader_parameter("u_vig", _vig)
	_mat.set_shader_parameter("u_bail", _bail)
	# The anchor reaches the shader only on the direct path, where 32 bits hold it; the perturbed path never sees a coordinate.
	_mat.set_shader_parameter("u_center", Vector2(_cx, _cy))


func _push_live() -> void:
	var scale := exp(_zl)
	_mat.set_shader_parameter("u_scale", scale)
	_mat.set_shader_parameter("u_rot", _rot)
	_mat.set_shader_parameter("u_phase", _phase)
	_mat.set_shader_parameter("u_julia", Vector2(_jx, _jy))
	_mat.set_shader_parameter("u_glow", _glow)
	_mat.set_shader_parameter("u_gain", _gain * (0.94 + 0.12 * _energy))
	# The iteration budget rides the depth: points near the boundary take longer to escape the deeper the
	# view goes, so a fixed budget draws a deep frame as flat interior color. It scales with e-folds traveled.
	var efolds := maxf(0.0, log(SCALE_WIDE) - _zl)
	_mat.set_shader_parameter("u_iter",
		clampi(_iter_base + int(_iter_gain * efolds), 64, ITER_MAX))


func _draw() -> void:
	begin_draw()
	# A flat dark ground under the quad, seen only during the fade when the quad's alpha drops.
	var x := size.x * 0.5 * 1.25 / maxf(0.001, view.zoom_actual())
	var y := size.y * 0.5 * 1.25 / maxf(0.001, view.zoom_actual())
	draw_colored_polygon(PackedVector2Array([
		Vector2(-x, -y), Vector2(x, -y), Vector2(x, y), Vector2(-x, y)]),
		Color(_in_col.r * 0.5, _in_col.g * 0.5, _in_col.b * 0.5))
	if _quad == null:
		_quad = Layer.FieldQuad.new()
		_quad.material = _mat
		# Deferred: this runs inside _draw, and the tree may not change mid-pass.
		call_deferred("add_child", _quad)
		return
	# Oversized, like every layer: the 2D view drifts and zooms on top of the field.
	var half := Vector2(size.x, size.y) * 0.5 * 1.15
	_quad.px_half = half
	_mat.set_shader_parameter("u_half", half / maxf(1.0, unit()))
	_quad.queue_redraw()
