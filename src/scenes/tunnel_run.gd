extends Scene3D

## Tunnel run - the camera on a track, falling forward through a tube that twists, banks and
## sometimes turns right over.
## A first-person ride: the camera is on a track inside the tube, with almost no shot or drift,
## since a tunnel is only a tunnel while the vanishing point holds still.
##
## The track is integrated, not splined, so it can loop and roll: a frame (right / up / forward)
## is carried along and turned each step by three seeded curvature functions of arclength (yaw
## about its own up, pitch about its right, roll about its forward). A sustained pitch is a loop,
## a sustained yaw a spiral staircase, roll the barrel the tube turns through. The functions are
## sums of incommensurate sinusoids, so the track never repeats; stations are generated ahead of
## the camera and dropped behind it, so it is endless at constant memory.
##
## The wall's cross-section is a small Fourier series in the angle that twists along the track
## and swells and closes on a long wavelength. Ribs mark distance at a fixed arclength interval,
## seams run the length at fixed angles (they make the roll legible), motes stream past, and
## everything fades into fog at the view distance.
##
## Music: speed (loud is fast), and the wall's radius per angle from the spectrum, wound along
## the track; beats brighten the ribs. The track's shape is never touched.
##
## Cost: about a thousand quads a frame (five to fifteen ms of GDScript), built in a
## [FrameForge] job; its one frame of latency is uniform.

## Arclength between stations: fine enough that the wall's curvature is smooth at the near end,
## coarse enough that the visible track is a few dozen rings.
const STEP := 0.55

## Stations kept ahead of the camera (the view distance is STEP * AHEAD; the fog is sized from it)
## and behind it. BEHIND is large because the camera aims up the track, so on a bend the frustum
## sweeps back over passed tube (too few rings show black wedges); rings behind the eye fail the
## near-plane test and cost one comparison.
const AHEAD := 56
const BEHIND := 16

## How far up the track the camera aims, in stations: enough that a bend reads as a bend being
## taken, not so far that the view axis leaves the tube on the tightest tracks.
const LOOK_AHEAD := 5.0

## The cross-section's resolution: at a 90-degree lens the first ring subtends most of the frame,
## so sixteen facets read as enormous flat plates; twenty-eight reads as a tube with Gouraud
## shading.
const SIDES := 28

## The seeded cross-sections: each a pair of Fourier terms on the angle (amplitude and harmonic).
const PROFILES := {
	"round": {"a1": [0.0, 0.04], "n1": [2, 3], "a2": [0.0, 0.03], "n2": [5, 7]},
	"fluted": {"a1": [0.07, 0.16], "n1": [6, 12], "a2": [0.0, 0.04], "n2": [3, 4]},
	"star": {"a1": [0.16, 0.30], "n1": [3, 6], "a2": [0.0, 0.06], "n2": [8, 12]},
	"duct": {"a1": [0.10, 0.20], "n1": [2, 2], "a2": [0.04, 0.10], "n2": [4, 4]},
	"ribbed": {"a1": [0.05, 0.10], "n1": [4, 5], "a2": [0.06, 0.12], "n2": [9, 14]},
}

## Track characters. Curvature amplitudes are radians per unit of arclength: 0.2 held over a
## quarter wavelength is most of a loop, so `coaster` always turns right over
## (tests/scenes/tunnel_track_check.gd). They say how hard a track turns, not which way: after
## roll, a yaw about the tilted up axis is world pitch.
const TRACKS := {
	"glide": {"yaw": [0.03, 0.09], "pitch": [0.02, 0.06], "roll": [0.02, 0.10], "wave": [55.0, 110.0]},
	"weave": {"yaw": [0.10, 0.19], "pitch": [0.05, 0.12], "roll": [0.06, 0.18], "wave": [30.0, 60.0]},
	"corkscrew": {"yaw": [0.05, 0.11], "pitch": [0.05, 0.11], "roll": [0.22, 0.48], "wave": [40.0, 80.0]},
	"coaster": {"yaw": [0.06, 0.14], "pitch": [0.16, 0.30], "roll": [0.10, 0.28], "wave": [45.0, 95.0]},
}

var _forge := FrameForge.new()
var _sch: Scheme

# The track's shape, as three curvature functions of arclength: two sinusoids each at
# wavelengths sharing no common multiple, so the ride never returns to itself.
var _k_yaw := PackedFloat32Array()      # [amp0, w0, ph0, amp1, w1, ph1]
var _k_pitch := PackedFloat32Array()
var _k_roll := PackedFloat32Array()

# The stations: the track, generated ahead and dropped behind.
var _pos: Array = []                    # Vector3
var _bas: Array = []                    # Basis (x right, y up, -z forward)
var _s0 := 0.0                          # arclength of station 0

# Where the camera is, and how fast.
var _s := 0.0
var _speed := 6.0
var _base_speed := 6.0

# The tube.
var _radius := 1.25
var _prof_name := "round"
var _a1 := 0.0
var _n1 := 3.0
var _o1 := 0.0
var _a2 := 0.0
var _n2 := 7.0
var _o2 := 0.0
var _twist := 0.0                       # radians of cross-section rotation per unit arclength
var _swell := 0.18                      # how much the radius opens into chambers
var _swell_w := 40.0
var _rib_every := 9
var _rib_depth := 0.16
var _seams := PackedInt32Array()
var _band_gain := 0.16
var _band_wind := 0.05                  # how fast the spectrum spirals along the track

# Look.
var _hue := 0.0
var _hue_travel := 0.004                # color zones per unit of track (a period, not a rate)
var _fog := Color.BLACK
var _lit := 1.0
var _mote_n := 0
var _motes: Array = []
var _light_th := 1.2          # where the lit strip runs, as an angle in the cross-section
var _glow := 0.0
var _energy := 0.0
var _ch := Vector2.ZERO
var _f: AudioFeatures = AudioFeatures.new()


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a
## storyboard entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"track": {"label": "Track", "type": "choice", "options": "TRACKS", "default": null,
		"blurb": "How hard the track turns: a gentle glide, a weave, a corkscrew that rolls, or a coaster that turns right over."},
	"profile": {"label": "Cross-section", "type": "choice", "options": "PROFILES", "default": null,
		"blurb": "The tube's cross-section: round, fluted, star-shaped, a duct, or ribbed."},
	"twist": {"label": "Twist", "type": "num", "range": [-0.16, 0.16], "default": null,
		"blurb": "How fast the tunnel's grooves spiral past, and which way."},
	"width": {"label": "Tunnel width", "type": "num", "range": [1.0, 1.7], "default": null,
		"blurb": "How wide the tunnel is."},
	"chambers": {"label": "Chambers", "type": "num", "range": [0.10, 0.30], "default": null,
		"blurb": "How much the tunnel opens out into wider chambers along its length."},
	"seams": {"label": "Seams", "type": "num", "range": [0, 4], "default": null,
		"blurb": "How many pale seams run along the tunnel wall."},
	"speed": {"label": "Speed", "type": "num", "range": [4.0, 10.0], "default": null,
		"blurb": "How fast the ride travels down the tunnel."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "scene3d"
	# A tunnel fills the frame, so it takes the gentle shots, damped hard in update(): anything
	# that moves the vanishing point is the camera coming loose from the vehicle.
	framing = "field"
	_sch = Scheme.pick(rng)
	_hue = _sch.vary(rng)
	# One full swing between the scheme's two hues every 60 to 300 units of track.
	_hue_travel = rng.randf_range(0.0033, 0.0167)

	var track := String(choice("track", rng))
	var tr: Dictionary = TRACKS[track]
	_k_yaw = _roll_curve(rng, tr["yaw"], tr["wave"])
	_k_pitch = _roll_curve(rng, tr["pitch"], tr["wave"])
	_k_roll = _roll_curve(rng, tr["roll"], tr["wave"])

	_prof_name = String(choice("profile", rng))
	var pf: Dictionary = PROFILES[_prof_name]
	_a1 = _pick(rng, pf["a1"])
	_n1 = float(rng.randi_range(int(pf["n1"][0]), int(pf["n1"][1])))
	_a2 = _pick(rng, pf["a2"])
	_n2 = float(rng.randi_range(int(pf["n2"][0]), int(pf["n2"][1])))
	_o1 = rng.randf() * TAU
	_o2 = rng.randf() * TAU
	# The twist keeps a shaped cross-section from reading as an extrusion: without it the flutes
	# are straight rails to the vanishing point and the tube reads as a static pipe.
	_twist = number("twist", rng)

	_radius = number("width", rng)
	_swell = number("chambers", rng)
	_swell_w = rng.randf_range(26.0, 70.0)
	_rib_every = rng.randi_range(5, 14)
	_rib_depth = rng.randf_range(0.08, 0.22)
	var seam_n: int = number("seams", rng)
	var seam_off := rng.randi() % SIDES
	for i in seam_n:
		_seams.append((seam_off + i * int(SIDES / maxi(1, seam_n))) % SIDES)
	_band_gain = rng.randf_range(0.09, 0.22)
	_band_wind = rng.randf_range(0.015, 0.075)

	_base_speed = number("speed", rng)
	_speed = _base_speed
	lens.fov = rng.randf_range(66.0, 92.0)          # wide: the walls have to rush past
	_lit = rng.randf_range(0.85, 1.25)
	_light_th = rng.randf() * TAU
	_fog = _sch.color(_sch.opposed(_hue, 0.22), 0.55, rng.randf_range(0.05, 0.16))

	_mote_n = 0 if rng.randf() < 0.25 else rng.randi_range(30, 110)
	for i in _mote_n:
		# `at` is an absolute arclength, not an offset from the camera: as an offset, every mote
		# sits the same distance ahead forever and nothing streams past. It is recycled a
		# view-length forward once the camera has gone by (see _advance_track).
		_motes.append({
			"at": rng.randf() * STEP * float(AHEAD),
			"th": rng.randf() * TAU,
			"rr": rng.randf_range(0.10, 0.86),
			"sz": rng.randf_range(0.012, 0.045),
			"hue": fposmod(_hue + rng.randf_range(-0.12, 0.12), 1.0),
		})

	_seed_track()

	return {
		"track": track,
		"profile": _prof_name,
		"mood": _sch.name,
		"speed": _base_speed,
		"radius": _radius,
		"fov": lens.fov,
		"twist": _twist,
		"ribs": _rib_every,
		"seams": seam_n,
		"motes": _mote_n,
	}


func _pick(rng: RandomNumberGenerator, band: Array) -> float:
	return rng.randf_range(float(band[0]), float(band[1]))


## One curvature function: two sinusoids in arclength, with wavelengths deliberately not in a
## simple ratio (turns sharing a period come back to the same shape every few seconds, which
## reads as driving in circles).
func _roll_curve(rng: RandomNumberGenerator, amp: Array, wave: Array) -> PackedFloat32Array:
	var w0 := _pick(rng, wave)
	var out := PackedFloat32Array()
	out.append(_pick(rng, amp))
	out.append(TAU / w0)
	out.append(rng.randf() * TAU)
	out.append(_pick(rng, amp) * rng.randf_range(0.3, 0.7))
	out.append(TAU / (w0 * rng.randf_range(0.37, 0.61)))
	out.append(rng.randf() * TAU)
	return out


func _curve(k: PackedFloat32Array, s: float) -> float:
	return k[0] * sin(k[1] * s + k[2]) + k[3] * sin(k[4] * s + k[5])


# ---------------------------------------------------------------------------------
# The track
# ---------------------------------------------------------------------------------

func _seed_track() -> void:
	_pos.clear()
	_bas.clear()
	_s0 = 0.0
	# The camera starts where it will live, `BEHIND` stations in (_advance_track holds that
	# offset); starting at zero would pin the eye until the track catches up, then lurch.
	_s = float(BEHIND) * STEP
	_pos.append(Vector3.ZERO)
	_bas.append(Basis.IDENTITY)
	while _pos.size() < AHEAD + BEHIND + 2:
		_extend()


## Push one more station, by turning the carried frame and stepping along its forward axis.
## Godot's -Z is forward, so the step is `-basis.z`; yaw turns about the frame's own up and pitch
## about its own right, so they compose into corkscrews and loops, not a wobble in a world plane.
func _extend() -> void:
	var b: Basis = _bas[_bas.size() - 1]
	var p: Vector3 = _pos[_pos.size() - 1]
	var s := _s0 + float(_pos.size() - 1) * STEP
	b = b.rotated(b.y, _curve(_k_yaw, s) * STEP)
	b = b.rotated(b.x, _curve(_k_pitch, s) * STEP)
	b = b.rotated(-b.z, _curve(_k_roll, s) * STEP)
	# Re-orthonormalized every step: successive rotations of a stored basis accumulate skew, and
	# over a song's thousands of stations the tube would shear into an ellipse.
	b = b.orthonormalized()
	_pos.append(p + (-b.z) * STEP)
	_bas.append(b)


## Drop stations the camera has passed and generate the same number ahead, so the buffer holds
## the same window of track whatever distance has been covered.
func _advance_track() -> void:
	while _s - _s0 > float(BEHIND) * STEP and _pos.size() > 2:
		_pos.remove_at(0)
		_bas.remove_at(0)
		_s0 += STEP
	while _pos.size() < AHEAD + BEHIND + 2:
		_extend()
	# Motes the camera has gone past come back a view-length ahead, so a fixed handful serves an
	# endless track.
	var span := STEP * float(AHEAD)
	for m in _motes:
		if float(m["at"]) < _s - STEP:
			m["at"] = float(m["at"]) + span


## The frame at an arclength. Returns [position, basis]. Cubic (Catmull-Rom through four
## stations, the orientation likewise on the quaternion): linear interpolation puts the eye on a
## polyline whose velocity jumps at every station, which reads as jitter.
func _frame_at(s: float) -> Array:
	var fi := (s - _s0) / STEP
	# One station of margin either side, for the cubic's four points.
	var i := clampi(int(floor(fi)), 1, _pos.size() - 3)
	var t := clampf(fi - float(i), 0.0, 1.0)
	var p: Vector3 = (_pos[i] as Vector3).cubic_interpolate(
		_pos[i + 1] as Vector3, _pos[i - 1] as Vector3, _pos[i + 2] as Vector3, t)
	var q := Quaternion(_bas[i] as Basis).spherical_cubic_interpolate(
		Quaternion(_bas[i + 1] as Basis), Quaternion(_bas[i - 1] as Basis),
		Quaternion(_bas[i + 2] as Basis), t)
	return [p, Basis(q)]


func update(f: AudioFeatures, delta: float) -> void:
	_f = f
	tick(f, delta)
	# Almost nothing: the 2D view drift that suits a field scene reads here as the camera coming
	# loose.
	drift_view(f, 0.004, 0.006)
	update_layers(f, delta)
	_ch = chroma_hue()
	var e := clampf(f.energy, 0.0, 1.0)
	_energy = lerpf(_energy, e, 1.0 - exp(-2.5 * delta))
	_glow = maxf(_glow * exp(-3.6 * delta), clampf(f.beat, 0.0, 1.0))

	# Speed is the feeling, so it is what the music gets. Bounded well above zero: a tunnel that
	# stops is a corridor.
	_speed = _base_speed * (0.55 + 0.95 * _energy)
	_s += _speed * delta
	_advance_track()

	var fr := _frame_at(_s)
	var p: Vector3 = fr[0]
	var b: Basis = fr[1]
	# The eye sits at the station and looks a few units up the track rather than along the
	# tangent: the vanishing point leads into the turn, so a bend reads as a bend being taken.
	var la := _frame_at(_s + STEP * LOOK_AHEAD)
	lens.eye = p
	lens.look = la[0]
	lens.up = b.y
	queue_redraw()

	var job := TunnelJob.new()
	job.f = f
	job.s = _s
	job.s0 = _s0
	job.step = STEP
	job.sides = SIDES
	job.n = mini(_pos.size(), AHEAD + BEHIND + 2)
	for i in job.n:
		var q: Vector3 = _pos[i]
		var bb: Basis = _bas[i]
		job.px.append(q.x)
		job.py.append(q.y)
		job.pz.append(q.z)
		job.rx.append(bb.x.x)
		job.ry.append(bb.x.y)
		job.rz.append(bb.x.z)
		job.ux.append(bb.y.x)
		job.uy.append(bb.y.y)
		job.uz.append(bb.y.z)
	job.lens = Lens3D.new()
	job.lens.eye = lens.eye
	job.lens.look = lens.look
	job.lens.up = lens.up
	job.lens.fov = lens.fov
	job.u = unit()
	job.radius = _radius
	job.a1 = _a1
	job.n1 = _n1
	job.o1 = _o1
	job.a2 = _a2
	job.n2 = _n2
	job.o2 = _o2
	job.twist = _twist
	job.swell = _swell
	job.swell_w = _swell_w
	job.rib_every = _rib_every
	job.rib_depth = _rib_depth
	job.seams = _seams
	job.band_gain = _band_gain
	job.band_wind = _band_wind
	# The wall's hue travels along the track, so the ride passes through color zones; the tonal
	# center pulls the whole thing toward the music's key.
	job.hue = GhostScene.blend_hue(_hue, _ch.x, clampf(_ch.y, 0.0, 1.0) * 0.35)
	job.hue_travel = _hue_travel
	job.accent = _sch.accent
	job.sat = _sch.sat
	job.lit = _lit * (0.8 + 0.45 * _energy)
	job.glow = _glow
	job.fog = _fog
	job.light_th = _light_th
	# Copied, not handed over: `_motes` keeps being recycled by _advance_track while the worker
	# reads, and [FrameForge]'s contract forbids a job sharing a mutable array with the sim.
	for m in _motes:
		job.m_at.append(float(m["at"]))
		job.m_th.append(float(m["th"]))
		job.m_rr.append(float(m["rr"]))
		job.m_sz.append(float(m["sz"]))
		job.m_hue.append(float(m["hue"]))
	_forge.kick(job.run, {}, self, job)


func _draw() -> void:
	begin_draw()
	# The fog color behind everything: the far end of the tube fades into it, and so does the
	# frame outside the near wall on a hard bend.
	var x := size.x * 0.5 * 1.25 / maxf(0.001, view.zoom_actual())
	var y := size.y * 0.5 * 1.25 / maxf(0.001, view.zoom_actual())
	draw_colored_polygon(PackedVector2Array([
		Vector2(-x, -y), Vector2(x, -y), Vector2(x, y), Vector2(-x, y)]), _fog)
	_forge.submit(self)


# ---------------------------------------------------------------------------------
# The worker job: ring the track, cull, shade, sort, batch
# ---------------------------------------------------------------------------------

## One frame of tunnel, built off the main thread ([FrameForge]'s job form: a fresh object per
## kick). It reads only its own members, never the scene node.
class TunnelJob:
	extends RefCounted

	## The eye plane the wall is clipped against, further out than [member Lens3D.near]: a vertex
	## a hundredth of a unit in front of the camera projects tens of thousands of pixels off screen.
	const NEAR := 0.12

	## The fraction of the generated track at which the fog is complete; under 1.0, so the last
	## several rings are pure haze.
	const FOG_REACH := 0.72

	var f: AudioFeatures
	var lens: Lens3D
	var u := 1.0
	var s := 0.0
	var s0 := 0.0
	var step := 0.55
	var sides := 16
	var n := 0
	# The stations, flattened: position and the two cross-section axes. Flat arrays because they
	# cross onto a worker thread while the scene keeps generating track.
	var px := PackedFloat32Array()
	var py := PackedFloat32Array()
	var pz := PackedFloat32Array()
	var rx := PackedFloat32Array()
	var ry := PackedFloat32Array()
	var rz := PackedFloat32Array()
	var ux := PackedFloat32Array()
	var uy := PackedFloat32Array()
	var uz := PackedFloat32Array()

	var radius := 1.25
	var a1 := 0.0
	var n1 := 3.0
	var o1 := 0.0
	var a2 := 0.0
	var n2 := 7.0
	var o2 := 0.0
	var twist := 0.0
	var swell := 0.18
	var swell_w := 40.0
	var rib_every := 9
	var rib_depth := 0.16
	var seams := PackedInt32Array()
	var band_gain := 0.16
	var band_wind := 0.05
	var hue := 0.0
	var hue_travel := 0.004
	var accent := 0.5
	var sat := 0.6
	var lit := 1.0
	var glow := 0.0
	var fog := Color.BLACK
	var light_th := 1.2
	var m_at := PackedFloat32Array()
	var m_th := PackedFloat32Array()
	var m_rr := PackedFloat32Array()
	var m_sz := PackedFloat32Array()
	var m_hue := PackedFloat32Array()

	func run(_snapshot: Dictionary) -> Array:
		var tb := TriBatch.new()
		if n < 3 or sides < 3:
			return tb.take_chunks()
		lens.prepare()
		var reach := step * float(n - 1)
		var faces: Array = []

		# The ring vertices, projected and shaded once each (adjacent quads share them). Color
		# belongs to the vertex (Gouraud): the shading must be continuous across a quad edge or the
		# facets are the picture.
		var vx := PackedFloat32Array()
		var vy := PackedFloat32Array()
		var vd := PackedFloat32Array()          # camera depth
		var vc := PackedColorArray()
		var wx := PackedFloat32Array()          # ...and the world position, for the cull
		var wy := PackedFloat32Array()
		var wz := PackedFloat32Array()
		var cnt := n * sides
		vx.resize(cnt)
		vy.resize(cnt)
		vd.resize(cnt)
		vc.resize(cnt)
		wx.resize(cnt)
		wy.resize(cnt)
		wz.resize(cnt)
		var rad := PackedFloat32Array()
		rad.resize(n)
		for i in n:
			var si := s0 + float(i) * step
			# The radius: the seeded swell (chambers opening, necking down) in arclength, so it
			# belongs to the tunnel and not to the camera.
			var rr := radius * (1.0 + swell * sin(TAU * si / maxf(4.0, swell_w)))
			# The ribs belong to the tunnel, not the window on it: `si / step` is the absolute
			# station number (s0 advances by one step per retirement), whereas `i % rib_every`
			# would step ribs backward as stations retire.
			var rib := rib_every > 0 and (int(round(si / step)) % rib_every) == 0
			if rib:
				rr *= 1.0 - rib_depth
			rad[i] = rr
			var base := i * sides
			# The hue walks between the scheme's two colors and comes back, rather than accumulating
			# (arclength grows without bound, so the tunnel would leave the palette).
			var hue_i := GhostScene.blend_hue(hue, accent,
				0.5 - 0.5 * cos(TAU * si * hue_travel))
			for k in sides:
				var th := TAU * float(k) / float(sides) + twist * si
				# The spectrum, wound along the track: mapping bands straight onto the angle makes a
				# bent bar chart; adding the arclength winds it into a helix.
				var band: float = f.sample(fposmod(th / TAU + si * band_wind, 1.0))
				var pr := rr * _prof(th) * (1.0 + band_gain * band)
				var cx := cos(th)
				var cy := sin(th)
				var qx := px[i] + rx[i] * cx * pr + ux[i] * cy * pr
				var qy := py[i] + ry[i] * cx * pr + uy[i] * cy * pr
				var qz := pz[i] + rz[i] * cx * pr + uz[i] * cy * pr
				var pj := lens.project(Vector3(qx, qy, qz))
				var vi := base + k
				vx[vi] = pj.x * u
				vy[vi] = pj.y * u
				vd[vi] = pj.z
				wx[vi] = qx
				wy[vi] = qy
				wz[vi] = qz
				# The light is fixed in the tube's cross-section, so it rolls with the tube (a
				# headlight shades the wall flat; a world light sweeps as the track banks). Wrapped,
				# not clamped: `max(0, cos)` leaves half the frame at the ambient floor.
				var lam := 0.5 + 0.5 * cos(th - light_th)
				# A fine banding along the track, so the near wall (most of the frame) has some surface.
				var panel := 0.90 + 0.10 * sin(si * 2.7)
				var shade := (0.20 + 0.80 * pow(lam, 1.35)) * panel
				var sa := sat
				var vv := shade * lit
				var h := hue_i
				if rib:
					h = GhostScene.blend_hue(hue_i, accent, 0.65)
					vv = vv * 0.9 + 0.22 + 0.30 * glow
					sa = clampf(sat * 1.1, 0.0, 1.0)
				elif seams.has(k):
					vv = vv * 0.85 + 0.30
					sa = clampf(sat * 0.55, 0.0, 1.0)
				vc[vi] = _fogged(Color.from_hsv(h, sa, clampf(vv, 0.0, 1.35)), si - s, reach)

		# --- The wall, two triangles per (station, side).
		# A groove (ribbed, fluted and star profiles) makes a quad a saddle whose halves face
		# opposite ways, so one normal culls wrongly; hence two triangles, each shaded and sorted
		# at its own depth (a fan is also valid only on a convex polygon).
		for i in n - 1:
			for k in sides:
				var k2 := (k + 1) % sides
				var i0 := i * sides + k
				var i1 := i * sides + k2
				var i2 := (i + 1) * sides + k2
				var i3 := (i + 1) * sides + k
				# The cull is the quad's, the depth each triangle's: culling per triangle pops at
				# grazing angles (a saddle's back half is hidden only by painter's order), so both
				# halves are drawn, sorted apart.
				var q1 := Vector3(wx[i1], wy[i1], wz[i1])
				var q3 := Vector3(wx[i3], wy[i3], wz[i3])
				var q0 := Vector3(wx[i0], wy[i0], wz[i0])
				var q2 := Vector3(wx[i2], wy[i2], wz[i2])
				var mid := (q0 + q1 + q2 + q3) * 0.25
				var nA := (q1 - q0).cross(q2 - q0)
				var nB := (q2 - q0).cross(q3 - q0)
				var toward := lens.eye - mid
				if nA.length_squared() < 1e-12 and nB.length_squared() < 1e-12:
					continue
				if nA.dot(toward) <= 0.0 and nB.dot(toward) <= 0.0:
					continue
				for t in 2:
					var a := i0
					var b := i1 if t == 0 else i2
					var c := i2 if t == 0 else i3
					var pa := Vector3(wx[a], wy[a], wz[a])
					var pb := Vector3(wx[b], wy[b], wz[b])
					var pc := Vector3(wx[c], wy[c], wz[c])
					if (pb - pa).cross(pc - pa).length_squared() < 1e-12:
						continue
					var behind := int(vd[a] <= NEAR) + int(vd[b] <= NEAR) + int(vd[c] <= NEAR)
					if behind == 3:
						continue
					if behind == 0:
						faces.append({"d": (vd[a] + vd[b] + vd[c]) / 3.0,
							"p": PackedVector2Array([
								Vector2(vx[a], vy[a]), Vector2(vx[b], vy[b]),
								Vector2(vx[c], vy[c])]),
							"c": PackedColorArray([vc[a], vc[b], vc[c]])})
						continue
					# Straddling the eye plane: dropping such a face punches black wedges into the
					# frame (at a wide field of view the nearest ring is enormous on screen), hence
					# the clip.
					var cl := _clip_near([pa, pb, pc], [vd[a], vd[b], vd[c]],
						[vc[a], vc[b], vc[c]])
					var cp: Array = cl[0]
					if cp.size() < 3:
						continue
					var sp := PackedVector2Array()
					var sc := PackedColorArray()
					var dsum := 0.0
					for w in cp.size():
						var pj3 := lens.project(cp[w])
						sp.append(Vector2(pj3.x * u, pj3.y * u))
						sc.append((cl[1] as Array)[w])
						dsum += pj3.z
					faces.append({"d": dsum / float(cp.size()), "p": sp, "c": sc})

		# --- Motes: specks hanging in the tube, so the air between the camera and the wall is not
		# empty. They make the speed legible up close (the wall's detail is far away and slow).
		for k in m_at.size():
			var si2: float = m_at[k]
			# Interpolated between stations, never snapped to one (snapping teleports every mote a
			# whole station at a time, on the objects nearest the lens).
			var fidx := (si2 - s0) / step
			var idx := int(floor(fidx))
			if idx < 0 or idx >= n - 1:
				continue
			var ft := clampf(fidx - float(idx), 0.0, 1.0)
			var rr2: float = lerpf(rad[idx], rad[idx + 1], ft) * m_rr[k]
			var th2: float = m_th[k] + twist * si2
			var cx2 := cos(th2)
			var cy2 := sin(th2)
			var pj2 := lens.project(Vector3(
				lerpf(px[idx], px[idx + 1], ft)
					+ lerpf(rx[idx], rx[idx + 1], ft) * cx2 * rr2
					+ lerpf(ux[idx], ux[idx + 1], ft) * cy2 * rr2,
				lerpf(py[idx], py[idx + 1], ft)
					+ lerpf(ry[idx], ry[idx + 1], ft) * cx2 * rr2
					+ lerpf(uy[idx], uy[idx + 1], ft) * cy2 * rr2,
				lerpf(pz[idx], pz[idx + 1], ft)
					+ lerpf(rz[idx], rz[idx + 1], ft) * cx2 * rr2
					+ lerpf(uz[idx], uz[idx + 1], ft) * cy2 * rr2))
			if pj2.z <= 0.35:
				continue                        # too close to be a speck; it would be a plate
			# Clamped: a screen size of `world / depth` is unbounded as the depth goes to zero, and an
			# unclamped mote at the lens is a flat square filling a tenth of the frame.
			var sz := clampf(m_sz[k] * u / pj2.z, 1.0, u * 0.008)
			var near_fade := clampf((pj2.z - 0.35) * 1.6, 0.0, 1.0)
			var c := Vector2(pj2.x * u, pj2.y * u)
			var mc := Color.from_hsv(m_hue[k], clampf(sat * 0.7, 0.0, 1.0),
				clampf(0.75 + 0.5 * glow, 0.0, 1.0), near_fade)
			var fc := _fogged(mc, si2 - s, reach)
			fc.a = mc.a
			faces.append({"d": pj2.z,
				"p": PackedVector2Array([
					c + Vector2(-sz, -sz), c + Vector2(sz, -sz),
					c + Vector2(sz, sz), c + Vector2(-sz, sz)]),
				"c": PackedColorArray([fc, fc, fc, fc])})

		# Far first: a tube mostly does not occlude itself, but a looping track brings far track
		# back into the near field, and the sort makes that case correct.
		faces.sort_custom(func(a, b): return float(a["d"]) > float(b["d"]))
		for fc2 in faces:
			# Emitted as a fan, not a quad: the near clip can return a triangle or a pentagon.
			var fp: PackedVector2Array = fc2["p"]
			var fcol: PackedColorArray = fc2["c"]
			for w in range(1, fp.size() - 1):
				tb.tri_colored(fp[0], fp[w], fp[w + 1], fcol[0], fcol[w], fcol[w + 1])
		return tb.take_chunks()


	## Sutherland-Hodgman against the eye plane: keep the part of a polygon in front of the camera,
	## cutting each crossing edge at the plane and interpolating its color there. Returns
	## [points, colors].
	func _clip_near(pts: Array, dep: Array, cols: Array) -> Array:
		var op: Array = []
		var oc: Array = []
		var m := pts.size()
		for e in m:
			var b := (e + 1) % m
			var da: float = dep[e]
			var db: float = dep[b]
			if da > NEAR:
				op.append(pts[e])
				oc.append(cols[e])
			if (da > NEAR) != (db > NEAR):
				var t := clampf((NEAR - da) / (db - da), 0.0, 1.0)
				op.append((pts[e] as Vector3).lerp(pts[b] as Vector3, t))
				oc.append((cols[e] as Color).lerp(cols[b] as Color, t))
		return [op, oc]

	## The cross-section, as a two-term Fourier series in the angle: one roll of the amplitudes
	## gives a circle, a lobed star, a flattened duct or a fluted column.
	func _prof(th: float) -> float:
		return maxf(0.35, 1.0 + a1 * cos(n1 * th + o1) + a2 * cos(n2 * th + o2))

	## Fade toward the fog by distance along the track, not from the camera: on a hard bend the far
	## end is a few units away in a straight line but thirty along the tube, and the last ring
	## would hang in mid-air. Smoothstep, because an exponential never reaches full fog.
	func _fogged(c: Color, ahead: float, reach: float) -> Color:
		return c.lerp(fog, smoothstep(0.04, FOG_REACH, ahead / maxf(0.01, reach)))
