extends RefCounted
class_name MaskFaceTrack

## MaskFaceTrack - the face, fitted once and read by time: Masking's face track and the stencil rasterized from it, a
## part of [MaskEditor]. It bootstraps the offline pre-pass (`hosts/face/face_track.py`, which has the file format),
## reads the landmarks at a moment, fits the clown's face model to them ([method clown_model_now],
## [method apply_model]) and draws the feature stencil the shader keys on ([method update_stencil]); the per-clip
## follow settings are its own ([method load_follow], [method save_follow]).
##
## Same architecture as the umbra look-ahead track: the live editor and the export relaunch are separate processes that
## agree frame for frame by reading one cached file; no detection runs inside the render loop; and the whole track
## exists before playback, so smoothing can use frames on both sides of now (a live tracker must choose lag or jitter).
##
## The environment is ghost's own (`face_venv`, see [Provision]), built on first use, so a session that never touches
## the clown installs nothing.
##
## The feature stencil: an analytic ellipse can only make a nose a circle and a mouth an ellipse, so the deposit goes
## through a rasterized stencil of the landmark contours, four polygons drawn once per tick into a small texture, one
## channel each:
##
##   R  the two eyes      G  the lips      B  the nose      A  the face oval
##
## Drawn on the GPU into a SubViewport (additively, each polygon in its own channel). The paint sim reads a shape, so
## advection, bleed, settle and drip work on the real silhouette.

## The [MaskEditor] this is a part of: everything read through it is something this part is handed.
var editor: MaskEditor

const FACE_VENV_DIR := "user://face_venv"
const FACE_TRACK_DIR := "user://face_tracks"
## Per-user editor preferences. One cfg serves the whole app, so every write is a read-modify-write of just the [mask]
## section (as Director._save_pacing); a fresh ConfigFile.save() would wipe the other sections.
const PREFS_CFG := "user://ghost.cfg"
const FACE_TRACK_RATE := 15.0    # samples/sec - must match what face_track.py wrote
const FACE_TRACK_POINTS := 478
const FACE_TRACK_HEADER := 20    # 4 magic + u32 version + f32 rate + u32 count + u32 points
var _ft_path := ""        # the cached track for THIS clip
var _ft_log := ""
var _ft_rate := FACE_TRACK_RATE
var _ft_count := 0
var _ft_points := FACE_TRACK_POINTS
## The whole track in memory: count x points x (x, y), plus a found flag per sample (~12 MB for four minutes at 15 Hz).
var _ft_xy := PackedFloat32Array()
var _ft_found := PackedByteArray()
## MediaPipe's canonical face-mesh indices, only the ones this effect consumes (mediapipe 1.0.1 is Tasks-only and no
## longer ships the FACEMESH_* tables). LEFT/RIGHT are the image's, not the subject's. Each is a contour point set,
## not an ordered ring: every shape is rasterized as the convex hull of its set (see _ft_hull), which cannot
## self-intersect however the indices are ordered.
const FT_EYE_L := [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
const FT_EYE_R := [263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388, 466]
const FT_LIPS := [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409, 270, 269, 267, 0, 37, 39, 40, 185]
const FT_OVAL := [10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379,
	378, 400, 377, 152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109]
## The ball of the nose, not the nose: the supratip and tip (5, 4, 1), the columella and subnasale (19, 94, 2) and the
## alae with their creases (48, 115, 220, 45 and 278, 344, 440, 275). Including the bridge chain (168, 6, 197, 195)
## would make the hull a wedge up to the brow. Scale grows it from there.
const FT_NOSE := [5, 4, 1, 19, 94, 2, 48, 115, 220, 45, 278, 344, 440, 275]
const FT_NOSE_TIP := 1
const FT_FACE_TOP := 10
const FT_FACE_CHIN := 152
const FT_FACE_LEFT := 234
const FT_FACE_RIGHT := 454
const _STENCIL_H := 384      # tall enough for a face, small enough to be free
var _stencil_draw: Node2D
var _stencil_cut: Node2D
var _stencil_cuts: Array = []
var _stencil_shapes := []    # [eyes, lips, nose, oval] as PackedVector2Array, in VIEWPORT px

# --- the feature stencil: the contours, rasterized --------------------------------------------

func _ensure_stencil() -> void:
	if editor._stencil_vp != null:
		return
	var asp := editor._source_prep.source_aspect()
	editor._stencil_vp = SubViewport.new()
	editor._stencil_vp.size = Vector2i(maxi(2, int(round(_STENCIL_H * asp))), _STENCIL_H)
	editor._stencil_vp.disable_3d = true
	editor._stencil_vp.transparent_bg = true
	# Cleared every draw, unlike the paint field: this states where the features are this instant; the paint sim that
	# reads it holds the persistence.
	editor._stencil_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	editor._stencil_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_stencil_draw = Node2D.new()
	var cm := CanvasItemMaterial.new()
	# Premultiplied, not ADD: Godot's additive blend multiplies the source by its own alpha, so a color written to
	# isolate one channel, (1,0,0,0) for the eyes, would add nothing. Premultiplied takes the color as written
	# (dst = src + dst*(1-a)), so an a=0 color adds into RGB and leaves alpha alone.
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_stencil_draw.material = cm
	_stencil_draw.draw.connect(_draw_stencil)
	editor._stencil_vp.add_child(_stencil_draw)
	# The eye openings are cut out of the coat in a second pass: premultiplied blending cannot remove alpha
	# (`dst = src + dst * (1 - src.a)` leaves it at src.a = 0 and replaces it at src.a = 1, and a negative color
	# clamps). A child with a subtractive material draws after its parent, giving dst.a - 1 = 0 inside each opening
	# with rgb untouched. Without it the coat's white would cover the opening, so the hole in the black would show
	# white instead of an eyeball.
	_stencil_cut = Node2D.new()
	var cut_m := CanvasItemMaterial.new()
	cut_m.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
	_stencil_cut.material = cut_m
	_stencil_cut.draw.connect(_draw_stencil_cut)
	editor._stencil_vp.add_child(_stencil_cut)
	editor.add_child(editor._stencil_vp)


## The eye openings, subtracted from the coat's silhouette (a separate pass, see _ensure_stencil).
## The Follow switch, out of and into user://ghost.cfg; defaults to on.
func load_follow() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PREFS_CFG) != OK:
		return true
	return bool(cfg.get_value("mask", "follow_playhead", true))


func save_follow(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PREFS_CFG)     # read-modify-write - see PREFS_CFG
	cfg.set_value("mask", "follow_playhead", on)
	cfg.save(PREFS_CFG)


func _draw_stencil_cut() -> void:
	for pts in _stencil_cuts:
		if pts.size() >= 3:
			_stencil_cut.draw_colored_polygon(pts, Color(0, 0, 0, 1))


func _draw_stencil() -> void:
	# One channel each; the two eyes are separate polygons sharing a channel (one hull around both is a mask across the
	# bridge of the nose). Additive blending lets eye and nose overlap the oval without either erasing the other.
	for entry in _stencil_shapes:
		var pts: PackedVector2Array = entry[0]
		# Degenerate polygons are skipped: where two hulls touch the ring's triangle has no area, and Godot logs
		# "Invalid polygon data, triangulation failed" every frame. The shape is invisible either way.
		if pts.size() >= 3 and absf(_poly_area(pts)) > 1e-9:
			_stencil_draw.draw_colored_polygon(pts, entry[1])


## Twice the signed area; only the magnitude is used, as a degeneracy test.
static func _poly_area(pts: PackedVector2Array) -> float:
	var acc := 0.0
	for i in pts.size():
		var p0 := pts[i]
		var p1 := pts[(i + 1) % pts.size()]
		acc += p0.x * p1.y - p1.x * p0.y
	return acc * 0.5


## The convex hull of a landmark set at `t`, in frame UV (a hull, not the points in order: see the FT_* sets).
func _ft_hull(ring: Array, t: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in ring:
		pts.append(_ft_point(int(i), t))
	return Geometry2D.convex_hull(pts)


## The ring between two hulls, as quads: paint around a feature rather than over it. Both hulls come from _grow_hull
## of the same source, so their point counts and correspondence match, and the ring is one quad per edge. Built
## geometrically because a hole cannot be drawn: a negative color clamps on a normal target (and returns 0.92, not 0, on
## an HDR one), and Godot's polygon drawing has no hole support.
static func _ring_quads(outer: PackedVector2Array, inner: PackedVector2Array) -> Array:
	var out := []
	if outer.size() < 3 or outer.size() != inner.size():
		return out
	# Two triangles per segment, not one quad: where a hull is nearly pointed (an eye's corners) the four points are
	# close to collinear and a quad (outer[i], outer[j], inner[j], inner[i]) draws as a bow-tie.
	for i in outer.size():
		var j := (i + 1) % outer.size()
		out.append(PackedVector2Array([outer[i], outer[j], inner[j]]))
		out.append(PackedVector2Array([outer[i], inner[j], inner[i]]))
	return out


## The unit one step of eye size is worth, in aspect space: mostly the hull's short reach (lid to lash) with a share
## of its long one. Pure minor (0.0169 on the measured eye) barely moves the patch past the corners, which is what
## the control is for; pure major (0.1406) inflates the short axis into a blob. The mix grows the patch rounder
## rather than longer while still reaching across the socket.
static func _hull_step(pts: PackedVector2Array, asp: float) -> float:
	if pts.is_empty():
		return 0.0
	var a := Vector2(asp, 1.0)
	var c := Vector2.ZERO
	for p in pts:
		c += p * a
	c /= float(pts.size())
	var lo := 1e9
	var hi := 0.0
	for p in pts:
		var d := (p * a - c).length()
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return lo * 0.35 + hi * 0.28


## Offset a convex hull outward by `d` along its own normals (negative = inward), in aspect space so the band is the
## same width at the top as at the side. An offset adds the same distance in every direction, so a thin eye hull
## (0.141 along its major axis, 0.0169 across) fills out where scaling would stretch it into spikes. The unit is the
## minor radius (the mean radius is dominated by the long axis and inflates the patch into a blob); the miter is
## clamped tightly because the exact miter at a lens's corner runs away toward infinity.
static func _offset_hull(pts: PackedVector2Array, d: float, asp: float) -> PackedVector2Array:
	var m := pts.size()
	if m < 3 or absf(d) < 1e-6:
		return pts
	var a := Vector2(asp, 1.0)
	var area := 0.0
	for i in m:
		var q0: Vector2 = pts[i] * a
		var q1: Vector2 = pts[(i + 1) % m] * a
		area += q0.x * q1.y - q1.x * q0.y
	var w := 1.0 if area > 0.0 else -1.0
	var out := PackedVector2Array()
	for i in m:
		var p_prev: Vector2 = pts[(i - 1 + m) % m] * a
		var p: Vector2 = pts[i] * a
		var p_next: Vector2 = pts[(i + 1) % m] * a
		var e0 := (p - p_prev).normalized()
		var e1 := (p_next - p).normalized()
		if e0.length() < 0.5 or e1.length() < 0.5:
			out.append(pts[i])
			continue
		var bis := Vector2(e0.y, -e0.x) * w + Vector2(e1.y, -e1.x) * w
		if bis.length() < 1e-5:
			out.append(pts[i])
			continue
		bis = bis.normalized()
		out.append((p + bis * (d / maxf(bis.dot(Vector2(e1.y, -e1.x) * w), 0.62))) / a)
	return out


## Squeeze a hull against a line instead of cutting it on one: vertices compress smoothly as they approach `lim` and
## asymptote to it, so the line is pressure rather than a wall (a hard clamp lands vertices exactly on the line and
## draws a straight edge). The response is `x / (1 + x)`: saturating, monotone, slope 1 at the knee so it joins the
## untouched part without a crease. The vertex count is preserved, which _ring_quads requires: it pairs the outer
## and inner hulls by index and draws nothing if their sizes differ.
static func _press_hull(pts: PackedVector2Array, origin: Vector2, n: Vector2,
		lim: float, knee: float, asp: float) -> PackedVector2Array:
	if knee <= 1e-6:
		return pts
	var a := Vector2(asp, 1.0)
	var start := lim - knee
	var out := PackedVector2Array()
	for p in pts:
		var q: Vector2 = p * a
		var d := (q - origin).dot(n)
		if d <= start:
			out.append(p)
			continue
		var x := (d - start) / knee
		out.append((q + n * (start + knee * (x / (1.0 + x)) - d)) / a)
	return out


## How far a hull reaches along `n` from `origin`.
static func _hull_extent(pts: PackedVector2Array, origin: Vector2, n: Vector2,
		asp: float) -> float:
	var a := Vector2(asp, 1.0)
	var m := -1e9
	for p in pts:
		m = maxf(m, (p * a - origin).dot(n))
	return m


## Push the inner hull away from the outer wherever the two are closer than `min_d`, so the ring has a real width
## everywhere, including at the corners where two concentric scaled copies of a pointed hull always meet. Vertex for
## vertex (the count is preserved, see _ring_quads), and untouched where the gap is already wide enough, so Hollow
## sizes the opening as before.
static func _open_band(outer: PackedVector2Array, inner: PackedVector2Array,
		min_d: float, asp: float) -> PackedVector2Array:
	if outer.size() != inner.size() or outer.is_empty() or min_d <= 0.0:
		return inner
	var a := Vector2(asp, 1.0)
	var c := Vector2.ZERO
	for p in inner:
		c += p * a
	c /= float(inner.size())
	var out := PackedVector2Array()
	for i in inner.size():
		var qi: Vector2 = inner[i] * a
		var qo: Vector2 = outer[i] * a
		var v := qi - qo
		if v.length() >= min_d:
			out.append(inner[i])
			continue
		# Toward the hull's own center if the two points coincide (a corner where scaling collapsed the gap).
		var dir := v.normalized() if v.length() > 1e-6 else (c - qo).normalized()
		out.append((qo + dir * min_d) / a)
	return out


## Grow a hull, but never past a line: each vertex is allowed only the growth that keeps it on the near side of the
## half-plane `dot(p * asp - origin, n) <= lim`, so the hull swells freely except in the bounded direction, where it
## flattens against the line. Capping per vertex rather than capping k for the whole hull keeps the outer corner
## full size. The vertex count is preserved (see _ring_quads). The clearance must account for Smudge, which rubs the
## edges outward (see the caller).
static func _grow_hull_bounded(pts: PackedVector2Array, k: float, origin: Vector2,
		n: Vector2, lim: float, asp: float) -> PackedVector2Array:
	if pts.is_empty():
		return pts
	var a := Vector2(asp, 1.0)
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	# How far the centroid already sits from the line; if it is past it, growth is not allowed to make it worse.
	var head := (c * a - origin).dot(n) - lim
	var out := PackedVector2Array()
	for p in pts:
		var b := ((p - c) * a).dot(n)
		var kp := k
		if b > 1e-6:
			# Floored at 1.0: the measured contour is never clipped. Growth may be limited, never the outline it starts
			# from (below the floor the cap would eat the eye itself).
			kp = clampf(-head / b, 1.0, k)
		out.append(c + (p - c) * kp)
	return out


## Grow a hull about its own centroid: "bigger eyes" is a bigger version of this eye, keeping its shape.
static func _grow_hull(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	if pts.is_empty() or absf(k - 1.0) < 0.001:
		return pts
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p - c) * k)
	return out


## The smile. A clown's mouth runs past anatomy, so the lip hull is stretched horizontally about its center and its
## outer ends swept along a curve before rasterizing. Width 1 and curve 0 leave the real mouth as measured. The curve
## is proportional to the square of the horizontal distance from center, so the middle of the lips stays put and the
## corners travel.
static func _smile_hull(pts: PackedVector2Array, width: float, curve: float) -> PackedVector2Array:
	if pts.is_empty():
		return pts
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	var half := 0.0001
	for p in pts:
		half = maxf(half, absf(p.x - c.x))
	var out := PackedVector2Array()
	for p in pts:
		var dx := (p.x - c.x) * width
		var u := clampf(dx / (half * maxf(width, 0.001)), -1.0, 1.0)
		out.append(Vector2(c.x + dx, p.y + curve * u * u))
	return out


## Rebuild the stencil for clip time `t`: four convex hulls of at most 36 points and one small viewport draw.
func update_stencil(t: float) -> void:
	if editor._ft_state != "ready":
		return
	_ensure_stencil()
	var sz := Vector2(editor._stencil_vp.size)
	var eyes := PackedVector2Array()
	# The two eyes share a channel but not a hull. Each eye is a ring (a clown paints around the eye, not over the
	# eyeball); Hollow sizes the opening. Both radii are relative to the measured eye opening: the patch must be
	# comfortably bigger than the eye, and the hole must reach slightly past it so the eyeball is clear of the
	# landmark's own error.
	var eye_l_src := _ft_hull(FT_EYE_L, t)
	var eye_r_src := _ft_hull(FT_EYE_R, t)
	# 0.9x the eye opening at the stored default, widening to 1.5x. Starting from 0 would leave the patch solid over the
	# eyeball by default.
	var hole := 0.9 + clampf(editor._clown_hollow, 0.0, 1.0) * 0.6
	# The eye patch is the measured eye, scaled. Alternatives fail: bounding the growth against a line through the
	# bridge emptied the inner side; normal offsets on both hulls made an angular blob (an eye hull is 8 to 1); gating
	# the paint on the coat's alpha cut a straight edge down each socket. Scaling wraps the eye all the way round, and
	# its one fault (a ring between two scaled copies of a pointed hull pinches at the corners) is fixed by _open_band.
	var eye_l := _grow_hull(eye_l_src, editor._clown_eye_size)
	var eye_r := _grow_hull(eye_r_src, editor._clown_eye_size)
	var eye_l_in := _grow_hull(eye_l_src, hole)
	var eye_r_in := _grow_hull(eye_r_src, hole)
	var asp_e := editor._source_prep.source_aspect()
	var band_l := _hull_step(eye_l_src, asp_e) * 0.45
	var band_r := _hull_step(eye_r_src, asp_e) * 0.45
	# Nothing holds the hulls back from the bridge: a hull here has sixteen vertices, and no operation on sixteen
	# points is soft, so any bound drew a visible edge down each socket. The bridge is kept bare per pixel instead, by
	# a wide fade in the deposit (see clown_paint's `bridge pressure`).
	var lips := _smile_hull(_ft_hull(FT_LIPS, t), editor._clown_smile_w, editor._clown_smile_curve)
	var nose := _ft_hull(FT_NOSE, t)
	# The coat's outline is dilated a little past the measured jawline: two soft edges sit between the polygon and the
	# picture (the deposit's smoothstep on the rasterized alpha, and mask_split's gate on the coat field), each costing
	# a pixel or two. Growing the hull puts both outside the visible jaw. It cannot spill onto the background: the layer
	# is also gated on matching the face's own color (match16 in the clown branch).
	var oval := _grow_hull(_ft_hull(FT_OVAL, t), 1.015)
	const EYE := Color(1, 0, 0, 0)
	# Ring quads when Hollow has opened one, the whole hull when it has not.
	var eye_shapes := []
	if hole > 0.02:
		for quad in _ring_quads(_to_px(eye_l, sz), _to_px(eye_l_in, sz)):
			eye_shapes.append([quad, EYE])
		for quad in _ring_quads(_to_px(eye_r, sz), _to_px(eye_r_in, sz)):
			eye_shapes.append([quad, EYE])
	else:
		eye_shapes.append([_to_px(eye_l, sz), EYE])
		eye_shapes.append([_to_px(eye_r, sz), EYE])
	# The oval goes first: its color is the only one carrying alpha, and in premultiplied blending an a=1 source
	# replaces what is under it, so drawn last it would wipe the other three channels.
	_stencil_shapes = [[_to_px(oval, sz), Color(0, 0, 0, 1)]]
	_stencil_shapes.append_array(eye_shapes)
	_stencil_shapes.append([_to_px(lips, sz), Color(0, 1, 0, 0)])
	_stencil_shapes.append([_to_px(nose, sz), Color(0, 0, 1, 0)])
	# The eye openings come out of the coat as well as the black (see _ensure_stencil), cut at the ring's own inner
	# hull so the hole in the white is the hole in the black and Hollow sizes both.
	_stencil_cuts = []
	if hole > 0.02:
		_stencil_cuts = [_to_px(eye_l_in, sz), _to_px(eye_r_in, sz)]
	editor._stencil_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_stencil_draw.queue_redraw()
	_stencil_cut.queue_redraw()


static func _to_px(pts: PackedVector2Array, sz: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x * sz.x, p.y * sz.y))
	return out


## The centroid of a landmark ring at `t`.
func _ft_ring_center(ring: Array, t: float) -> Vector2:
	var acc := Vector2.ZERO
	for i in ring:
		acc += _ft_point(int(i), t)
	return acc / float(ring.size())


## A ring's half-extent, aspect-corrected so a radius means the same on either axis, in raw UV (the shaders' contract).
func _ft_ring_radius(ring: Array, t: float, asp: float) -> float:
	var c := _ft_ring_center(ring, t)
	var m := 0.0
	for i in ring:
		m = maxf(m, ((_ft_point(int(i), t) - c) * Vector2(asp, 1.0)).length())
	return m


## The whole face model, from measured landmarks instead of a fitted blob: every value is a measurement of a named
## part of the face, and a turned head just reports different landmark positions.
func apply_model(t: float) -> void:
	var asp := editor._source_prep.source_aspect()
	var eye_l := _ft_ring_center(FT_EYE_L, t)
	var eye_r := _ft_ring_center(FT_EYE_R, t)
	var lips := _ft_ring_center(FT_LIPS, t)
	var top := _ft_point(FT_FACE_TOP, t)
	var chin := _ft_point(FT_FACE_CHIN, t)
	var left := _ft_point(FT_FACE_LEFT, t)
	var right := _ft_point(FT_FACE_RIGHT, t)
	# No EMA and no prediction: the track is fitted offline over the whole clip, so it is already smooth and knows the
	# future; writing straight through keeps the mask still.
	editor._face_eye_l_ema = eye_l
	editor._face_eye_r_ema = eye_r
	editor._face_mouth_ema = lips
	editor._face_nose_ema = _ft_point(FT_NOSE_TIP, t)
	editor._face_c_ema = (top + chin + left + right) * 0.25
	editor._face_r_ema = Vector2(absf(right.x - left.x) * 0.5, absf(chin.y - top.y) * 0.5)
	editor._face_eye_lr_ema = _ft_ring_radius(FT_EYE_L, t, asp)
	editor._face_eye_rr_ema = _ft_ring_radius(FT_EYE_R, t, asp)
	# The mouth's half-width and half-height, measured corner to corner and lip to lip, so it opens and closes with
	# the real mouth.
	var mw := 0.0
	var mh := 0.0
	for i in FT_LIPS:
		var d := _ft_point(int(i), t) - lips
		mw = maxf(mw, absf(d.x))
		mh = maxf(mh, absf(d.y))
	editor._face_mouth_r_ema = Vector2(mw, mh)
	# The face's mean tint and luminance still come from the picture (the coat is a per-pixel color match) - see
	# _update_face_model, which still runs for those when no track is available.
	editor._face_prev_lum = PackedFloat32Array()


func bin_path(tool_name: String) -> String:
	return Deps.venv_bin(FACE_VENV_DIR, tool_name)


func _ft_model_path() -> String:
	return Provision.file_path("face_model")


## Kick the pre-pass off (or discover it cached). Called per frame while a clown layer is live; every branch is a
## cheap no-op once the track is ready. Lazy: a session that never uses the clown installs nothing.
func ensure() -> void:
	if editor._ft_state == "provisioning":
		_ft_wait_for_env()
		return
	if editor._ft_state in ["ready", "failed", "tracking"]:
		_ft_poll()
		return
	if editor.session == null or editor.session.video_path.is_empty():
		return
	var src := ProjectSettings.globalize_path(editor.session.video_path)
	if not FileAccess.file_exists(src):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FACE_TRACK_DIR))
	_ft_path = ProjectSettings.globalize_path(FACE_TRACK_DIR).path_join(
		str(hash(editor.session.video_path)) + ".bin")
	_ft_log = ProjectSettings.globalize_path(FACE_TRACK_DIR).path_join("last_run.log")
	if FileAccess.file_exists(_ft_path):
		_ft_load()
		return
	editor._ft_state = "provisioning"
	_ft_wait_for_env()


## Track once the environment (and its models) is ready; until then show what its install is doing, and fail with the
## install's own reason if it cannot be had.
func _ft_wait_for_env() -> void:
	var why := Provision.unsupported(MaskEditor.FACE_ENV)
	if not why.is_empty():
		_ft_fail("not available on this machine: " + why)
		return
	if Provision.ensure(MaskEditor.FACE_ENV):
		Provision.hold(MaskEditor.FACE_ENV, "mask editor")
		_ft_start_track()
		return
	var s := Provision.state(MaskEditor.FACE_ENV)
	if not bool(s.get("running", false)) and (s.has("error") or not Provision.can_install()):
		_ft_fail(String(s.get("error", Provision.hint(MaskEditor.FACE_ENV))))
		return
	editor._set_status("⏳  Preparing the face tracker - " + Provision.describe(MaskEditor.FACE_ENV, s))


func _ft_start_track() -> void:
	var script := BundledHosts.path("res://hosts/face/face_track.py")
	if not FileAccess.file_exists(script):
		_ft_fail("hosts/face/face_track.py is missing")
		return
	# The original source where it exists, else the prepared .ogv: the transcode is theora q6, whose chroma blocks are
	# an artifact a landmarker has to see past.
	var src := editor.session.source_path
	if src.is_empty() or not FileAccess.file_exists(src):
		src = ProjectSettings.globalize_path(editor.session.video_path)
	print("ghost face: tracking ", src)
	editor._ft_pid = _ft_spawn_logged(bin_path("python"), PackedStringArray([
		script, "--video", src, "--out", _ft_path, "--model", _ft_model_path(),
		"--rate", str(FACE_TRACK_RATE),
		"--progress", ProjectSettings.globalize_path(FACE_TRACK_DIR).path_join("progress")]))
	editor._ft_state = "tracking" if editor._ft_pid > 0 else "failed"
	editor._set_status("⏳  Finding the face through the clip…" if editor._ft_pid > 0
		else "⚠  Could not start the face tracker")


func _ft_poll() -> void:
	if editor._ft_pid <= 0 or Subprocess.alive(editor._ft_pid):
		if editor._ft_state == "tracking":
			var pf := ProjectSettings.globalize_path(FACE_TRACK_DIR).path_join("progress")
			if FileAccess.file_exists(pf):
				var f := FileAccess.open(pf, FileAccess.READ)
				if f != null:
					editor._set_status("⏳  Finding the face through the clip…  %d%%"
						% int(f.get_as_text().strip_edges().to_float() * 100.0))
		return
	editor._ft_pid = -1
	match editor._ft_state:
		"tracking":
			if FileAccess.file_exists(_ft_path):
				_ft_load()
			else:
				_ft_fail("the face pre-pass produced no track (see the log)")


func _ft_fail(why: String) -> void:
	editor._ft_state = "failed"
	push_warning("ghost face: " + why)
	# Say so: the fallback fitter still runs, and the author needs to know they are looking at it.
	editor._set_status("⚠  Face tracking unavailable - " + why)


## stdout+stderr to one file, so a mediapipe error is readable afterwards.
func _ft_spawn_logged(exe: String, args: PackedStringArray) -> int:
	return Subprocess.start_logged(exe, args, _ft_log, "face track")


func _ft_load() -> void:
	var f := FileAccess.open(_ft_path, FileAccess.READ)
	if f == null:
		_ft_fail("the cached track could not be opened")
		return
	if f.get_buffer(4).get_string_from_ascii() != "GFT1":
		f.close()
		DirAccess.remove_absolute(_ft_path)   # a stale/foreign file - rebuild next open
		_ft_fail("the cached track is not a face track")
		return
	var _version := f.get_32()
	_ft_rate = f.get_float()
	_ft_count = f.get_32()
	_ft_points = f.get_32()
	var stride := 1 + _ft_points * 8
	if _ft_count <= 0 or _ft_points <= 0 \
			or f.get_length() != FACE_TRACK_HEADER + _ft_count * stride:
		f.close()
		DirAccess.remove_absolute(_ft_path)
		_ft_fail("the cached track is truncated")
		return
	_ft_found.resize(_ft_count)
	_ft_xy.resize(_ft_count * _ft_points * 2)
	var found_n := 0
	for i in _ft_count:
		_ft_found[i] = f.get_8()
		found_n += _ft_found[i]
		var row := f.get_buffer(_ft_points * 8).to_float32_array()
		for k in _ft_points * 2:
			_ft_xy[i * _ft_points * 2 + k] = row[k]
	f.close()
	editor._ft_state = "ready"
	print("ghost face: track ready - %d samples at %.1f Hz, face in %d (%.0f%%)"
		% [_ft_count, _ft_rate, found_n, 100.0 * float(found_n) / float(maxi(_ft_count, 1))])
	editor._set_status("✓  Face tracked (%d%% of the clip)"
		% int(100.0 * float(found_n) / float(maxi(_ft_count, 1))))


## The Steadiness dial's kernel: the Gaussian's width in samples for a Steadiness of [param steady] (0-1, the clown
## marker's `hue_b`). 0 is a good value, not "off" (some smoothing is always wanted): calm (2.5) to calmer (10).
static func sigma_for(steady: float) -> float:
	return 2.5 + clampf(steady, 0.0, 1.0) * 7.5


## Landmark `idx` at clip time `t`, in frame UV, smoothed by a centered Gaussian over the samples.
func _ft_point(idx: int, t: float) -> Vector2:
	if editor._ft_state != "ready" or _ft_count <= 0:
		return Vector2.ZERO
	var s := clampf(t * _ft_rate, 0.0, float(_ft_count - 1))
	# A centered Gaussian smooths and interpolates in one pass. The track is offline, so it needs no lag compensation,
	# but the detector still wobbles a pixel or two per sample, and a lerp between noisy samples has a corner at every
	# one. Weighting neighbors on both sides has zero phase (the mask moves no later than the face), and the weight is
	# a smooth function of the continuous position, so there are no corners at sample boundaries.
	var sigma := editor._ft_sigma
	var half := maxi(1, int(ceil(sigma * 2.5)))
	var lo := maxi(0, int(s) - half)
	var hi := mini(_ft_count - 1, int(s) + half + 1)
	var acc := Vector2.ZERO
	var wsum := 0.0
	var base := idx * 2
	for i in range(lo, hi + 1):
		# Lost samples are skipped, not averaged in: their coordinates are a held copy of a neighbor.
		if _ft_found[i] == 0:
			continue
		var d := (float(i) - s) / sigma
		var w := exp(-0.5 * d * d)
		var b := i * _ft_points * 2 + base
		acc += Vector2(_ft_xy[b], _ft_xy[b + 1]) * w
		wsum += w
	if wsum <= 1e-6:
		# Every sample in the window was lost: fall back to the nearest one that is not, rather than the origin.
		var n := clampi(int(round(s)), 0, _ft_count - 1)
		var bn := n * _ft_points * 2 + base
		return Vector2(_ft_xy[bn], _ft_xy[bn + 1])
	return acc / wsum


## Is there a real detection at `t`? The caller needs it to hold when there is no face (the mean of a few landmarks
## is meaningless then).
func has_track(t: float) -> bool:
	if editor._ft_state != "ready" or _ft_count <= 0:
		return false
	return _ft_found[clampi(int(t * _ft_rate), 0, _ft_count - 1)] != 0


## The clown model's current display state: positions velocity-extrapolated by the fraction through the capture tick,
## sizes straight from their EMAs (predicting a size amplifies shape twitch). One source for _push_anchor and the
## paint sim's deposit targets.
func clown_model_now() -> Dictionary:
	# Lead scales the prediction: it cancels the capture+EMA delay when detection is clean but amplifies noise when it
	# is not, so it is the author's call. 0 is off (calmest, laggiest), 1 the default, 2 over-predicts for fast motion.
	var ff := clampf(fposmod(editor._player.stream_position, MaskEditor._FACE_INTERVAL) / MaskEditor._FACE_INTERVAL, 0.0, 1.0)
	# With a track, do not predict: the prediction cancels a live detector's delay by ramping a fraction 0 to 1 across
	# each capture tick and snapping back (a sawtooth). The offline track has no lag to cancel, so only the sawtooth
	# would remain, lurching the mask forward several times a second.
	if editor._ft_state == "ready":
		ff = 0.0
	return {
		"eye_l": editor._face_eye_l_ema + (editor._face_eye_l_ema - editor._face_eye_l_prev) * ff,
		"eye_r": editor._face_eye_r_ema + (editor._face_eye_r_ema - editor._face_eye_r_prev) * ff,
		"mouth": editor._face_mouth_ema + (editor._face_mouth_ema - editor._face_mouth_prev) * ff,
		"nose": editor._face_nose_ema + (editor._face_nose_ema - editor._face_nose_prev) * ff,
		"face_c": editor._face_c_ema + (editor._face_c_ema - editor._face_c_prev) * ff,
		"eye_lr": editor._face_eye_lr_ema, "eye_rr": editor._face_eye_rr_ema,
		"mouth_r": editor._face_mouth_r_ema,
	}
