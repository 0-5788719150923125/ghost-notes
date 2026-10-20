extends RefCounted
class_name MaskFaceTrack

## MaskFaceTrack - the face, fitted once and read by time: Masking's face track and the stencil
## rasterized from it, a part of [MaskEditor]. It bootstraps the offline pre-pass
## (`hosts/face/face_track.py`), reads the landmarks at a moment, fits the clown's face model
## to them ([method clown_model_now], [method apply_model]) and draws the feature stencil the
## shader keys on ([method update_stencil]); the per-clip follow settings are its own
## ([method load_follow], [method save_follow]).
##
## WHAT IT IS HANDED is written out: every `editor.` below is something it reads of the editor
## (the session, the install's state, the eased face it shares with the paint, the status line).
##
## What the clown's feature positions come from now. See hosts/face/face_track.py for
## the pre-pass and the file format; this half bootstraps it, runs it, and reads it.
##
## Same architecture as the umbra look-ahead track (_umb_ensure_track), for the same
## three reasons: the live editor and the export relaunch are separate PROCESSES
## that must agree frame-for-frame and do because they read one cached file; no
## detection ever runs inside the render loop; and because the whole track exists
## before playback, smoothing can use frames on BOTH sides of now, which a live
## tracker cannot - it only has the past, so it must choose between lag and jitter.
##
## The environment is ghost's OWN (`face_venv`, see [Provision]): one effect's
## dependency must never become the project's, and it is built on first use rather
## than required up front, so a session that never touches the clown installs nothing.
##
## THE FEATURE STENCIL: the contours, rasterized ([method update_stencil]).
## An analytic ellipse deposit - `win(p, center, radius)` - can only make a nose a
## circle and a mouth an ellipse, however well placed: no cheekbone, no eye corner,
## no cupid's bow. The landmarks describe the actual outlines, so the deposit goes
## through a RASTERIZED STENCIL of them: four polygons drawn once per tick into a
## small texture, one per channel.
##
##   R  the two eyes      G  the lips      B  the nose      A  the face oval
##
## Drawn on the GPU into a SubViewport (additively, so each polygon writes its own
## channel and nothing clobbers a neighbor) rather than scanline-filled on the CPU,
## because it is four convex polygons a frame and the GPU antialiases them for free.
## The paint sim then reads a shape instead of evaluating an ellipse, and every
## downstream behavior it already has - advection, bleed, settle, the drip - works
## on the real silhouette without knowing anything changed.

## The [MaskEditor] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var editor: MaskEditor

const FACE_VENV_DIR := "user://face_venv"
const FACE_TRACK_DIR := "user://face_tracks"
## Per-user editor preferences. ONE cfg serves the whole app ([notes], [director],
## [synth], [generative] ...), so every write here is a
## READ-MODIFY-WRITE of just the [mask] section - a fresh ConfigFile.save() would
## silently wipe all of those. Same discipline as Director._save_pacing.
const PREFS_CFG := "user://ghost.cfg"
const FACE_TRACK_RATE := 15.0    # samples/sec - must match what face_track.py wrote
const FACE_TRACK_POINTS := 478
const FACE_TRACK_HEADER := 20    # 4 magic + u32 version + f32 rate + u32 count + u32 points
var _ft_path := ""        # the cached track for THIS clip
var _ft_log := ""
var _ft_rate := FACE_TRACK_RATE
var _ft_count := 0
var _ft_points := FACE_TRACK_POINTS
## The whole track in memory: count x points x (x, y), plus a found flag per
## sample. ~12 MB for a four-minute clip at 15 Hz, read once.
var _ft_xy := PackedFloat32Array()
var _ft_found := PackedByteArray()
## MediaPipe's canonical face-mesh indices, only the ones this effect consumes.
## Named rather than inlined because a bare 263 in the middle of a size
## calculation is unreadable and unverifiable.
## LEFT/RIGHT here are the IMAGE's left and right, not the subject's.
## CONTOUR POINT SETS, not ordered rings. Every shape below is rasterized as the
## CONVEX HULL of its set (see _ft_hull), which cannot self-intersect however the
## indices are ordered - and an ordering mistake is otherwise invisible until you
## look at a render and find a bow-tie where a nose should be, which is exactly
## what a hand-ordered nose ring produced here first time.
##
## The indices are MediaPipe's canonical face-mesh numbering. They are written out
## because mediapipe 1.0.1 is Tasks-only and no longer ships the FACEMESH_* tables
## the older `solutions` module carried; the numbering itself is fixed by the
## canonical model and has not changed since the mesh was published. Verified by
## drawing all four on real footage - the oval follows the jaw, the eyes come out
## almond rather than round, the lips sit exactly on the lips.
const FT_EYE_L := [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
const FT_EYE_R := [263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388, 466]
const FT_LIPS := [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409, 270, 269, 267, 0, 37, 39, 40, 185]
const FT_OVAL := [10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379,
	378, 400, 377, 152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109]
## THE BALL OF THE NOSE, not the nose. This used to open at 168 - the nasion,
## the dip BETWEEN THE EYES - and run the whole dorsum down: 168, 6, 197, 195 are
## the bridge chain, and their convex hull is a wedge covering the entire length
## of it, so the red streaked from the tip up to the brow. A clown paints the ball
## and nothing else. What is left is the supratip and tip (5, 4, 1), the columella
## and subnasale (19, 94, 2), and the alae with their creases (48, 115, 220, 45 and
## 278, 344, 440, 275) - a hull around the round part, which is the shape being
## drawn. Scale still grows it from there.
## THE BALL OF THE NOSE, not the nose. This used to open at 168 - the nasion, the
## dip BETWEEN THE EYES - and run the whole dorsum down: 168, 6, 197 and 195 are
## the bridge chain, and their convex hull is a wedge covering its entire length,
## so the red streaked from the tip up to the brow. Most clowns paint the ball and
## nothing else. What is left is the supratip and tip (5, 4, 1), the columella and
## subnasale (19, 94, 2) and the alae with their creases (48, 115, 220, 45 and 278,
## 344, 440, 275) - a hull around the round part. Scale still grows it from there.
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

# --- THE FEATURE STENCIL: the contours, rasterized --------------------------------------------

func _ensure_stencil() -> void:
	if editor._stencil_vp != null:
		return
	var asp := editor._source_prep.source_aspect()
	editor._stencil_vp = SubViewport.new()
	editor._stencil_vp.size = Vector2i(maxi(2, int(round(_STENCIL_H * asp))), _STENCIL_H)
	editor._stencil_vp.disable_3d = true
	editor._stencil_vp.transparent_bg = true
	# CLEARED EVERY DRAW, unlike the paint field next door: this is a statement of
	# where the features ARE this instant, not an accumulation. The persistence
	# lives in the paint sim that reads it.
	editor._stencil_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	editor._stencil_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_stencil_draw = Node2D.new()
	var cm := CanvasItemMaterial.new()
	# PREMULTIPLIED, not ADD. Godot's additive blend multiplies the source by its
	# own alpha before adding, so a color written to isolate one channel -
	# (1,0,0,0) for the eyes - contributes exactly nothing, and the first cut of
	# this drew only the oval (the one shape whose color had any alpha in it).
	# In premultiplied mode the color is taken as written: dst = src + dst*(1-a),
	# so an a=0 color adds into RGB and leaves the alpha channel alone.
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_stencil_draw.material = cm
	_stencil_draw.draw.connect(_draw_stencil)
	editor._stencil_vp.add_child(_stencil_draw)
	# THE EYE OPENINGS ARE CUT OUT OF THE COAT, in a second pass, because
	# premultiplied blending cannot REMOVE alpha - `dst = src + dst * (1 - src.a)`
	# leaves the alpha channel alone at src.a = 0 and REPLACES it at src.a = 1, and
	# there is no color in between that subtracts. A negative color clamps (that
	# was tried). So the openings are drawn by a child with a SUBTRACTIVE material,
	# which children being drawn after their parent puts in exactly the right
	# order: dst.a - 1 = 0 inside each opening, and rgb untouched because the
	# color's rgb is zero.
	#
	# What it is FOR: the eye patch is an annulus so a clown paints AROUND the eye,
	# and that worked - but the white coat underneath went on covering the opening,
	# so the hole in the black revealed white instead of an eyeball. Same fault as
	# the black over the eyeball, with the color inverted. A hole has to be a hole
	# in the whole mask.
	_stencil_cut = Node2D.new()
	var cut_m := CanvasItemMaterial.new()
	cut_m.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
	_stencil_cut.material = cut_m
	_stencil_cut.draw.connect(_draw_stencil_cut)
	editor._stencil_vp.add_child(_stencil_cut)
	editor.add_child(editor._stencil_vp)


## The eye openings, subtracted from the coat's silhouette. See _ensure_stencil
## for why this is a separate pass and not another entry in _stencil_shapes.
## The Follow switch, out of and into user://ghost.cfg. Defaults to ON, which is
## the behavior every session had before the switch existed.
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
	# One channel each, and the two EYES are separate polygons sharing a channel -
	# a single hull around both is a bandit's mask across the bridge of the nose.
	# Additive blending lets the eye and nose polygons overlap the oval without
	# either erasing the other, which a normal alpha blend would.
	for entry in _stencil_shapes:
		var pts: PackedVector2Array = entry[0]
		# DEGENERATE POLYGONS ARE SKIPPED, not handed to the renderer. A ring is
		# decomposed into triangles between two hulls, and wherever those hulls
		# touch - a collapsed corner, a vertex flattened onto the bridge line beside
		# its neighbor - the triangle has no area, and Godot answers that with
		# "Invalid polygon data, triangulation failed" once per frame in the log.
		# The shape is invisible either way; the difference is a clean console.
		if pts.size() >= 3 and absf(_poly_area(pts)) > 1e-9:
			_stencil_draw.draw_colored_polygon(pts, entry[1])


## Twice the signed area - the sign is unused, only the magnitude, as a
## degeneracy test.
static func _poly_area(pts: PackedVector2Array) -> float:
	var acc := 0.0
	for i in pts.size():
		var p0 := pts[i]
		var p1 := pts[(i + 1) % pts.size()]
		acc += p0.x * p1.y - p1.x * p0.y
	return acc * 0.5


## The convex hull of a landmark set at `t`, in frame UV. Hull rather than the
## points in order: see the FT_* sets for why.
func _ft_hull(ring: Array, t: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in ring:
		pts.append(_ft_point(int(i), t))
	return Geometry2D.convex_hull(pts)


## The RING between two hulls, as quads - paint AROUND a feature rather than over
## it. Both hulls come from _grow_hull of the same source, so they have matching
## point counts and correspondence, and the ring is one quad per edge.
##
## Built geometrically because it cannot be drawn. Punching a hole by drawing the
## inner shape in a negative color reads as the obvious trick and does not work:
## on a normal target the value clamps and the hole stays solid, and on an HDR one
## it comes back at 0.92 rather than 0. Godot's polygon drawing has no hole
## support either. Quads between corresponding points have neither problem and are
## exact.
static func _ring_quads(outer: PackedVector2Array, inner: PackedVector2Array) -> Array:
	var out := []
	if outer.size() < 3 or outer.size() != inner.size():
		return out
	# TWO TRIANGLES per segment, not one quad. A quad in the order
	# (outer[i], outer[j], inner[j], inner[i]) is a valid trapezoid on paper, but
	# where the hull is nearly pointed - the corners of an eye - the four points
	# are close to collinear and the drawn polygon comes out as a BOW-TIE. Rendered
	# and looked at, the "ring" was a self-crossing outline rather than a band.
	# Triangles cannot cross themselves whatever the points do.
	for i in outer.size():
		var j := (i + 1) % outer.size()
		out.append(PackedVector2Array([outer[i], outer[j], inner[j]]))
		out.append(PackedVector2Array([outer[i], inner[j], inner[i]]))
	return out


## THE UNIT ONE STEP OF EYE SIZE IS WORTH, in aspect space. Mostly the hull's
## SHORT reach - for an eye, lid to lash - with a share of its long one.
##
## Neither alone works. Pure minor (0.0169 on the measured eye) makes Eye size
## barely move the patch past the corners, and covering the skin OUTSIDE the eye is
## what the control is for. Pure major (0.1406, eight times larger) inflates the
## short axis out of all proportion and the patch becomes a blob. The mix keeps the
## patch growing rounder rather than longer - which is the point of offsetting at
## all instead of scaling - while still reaching out across the socket.
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


## Offset a convex hull outward by `d` along its own normals (negative = inward),
## in aspect space so the band is the same width at the top as at the side.
##
## THIS IS WHY THE PATCH GROWS ROUNDER RATHER THAN LONGER. The eye hull measures
## 0.141 along its major axis and 0.0169 across - 8.3 to 1 - so SCALING it about
## its centroid (which is what Eye size used to do) multiplies that length by the
## same factor as its height, and at the stored 2.2x the patch reaches a fifth of
## the way across the face while staying almost as thin. Its ends become long
## spikes, and the ring between two such hulls is a spike too, not a band: the
## reported "it's cutting that inner eye too short - the black ring must go all the
## way around". An offset adds the same distance in every direction, so the shape
## fills out instead of stretching, and the ring has one width the whole way round.
##
## THE UNIT IS THE MINOR RADIUS, and getting that wrong is the whole difficulty: a
## first cut offset by the hull's MEAN radius, which on an 8-to-1 lens is dominated
## by the long axis, and the patch inflated into an angular blob three times the
## size of the eye socket (rendered, looked at, reverted). The miter is clamped
## tightly for the same reason - the exact miter at a lens's corner runs away
## toward infinity, and an unclamped one is what put the spikes back.
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


## Squeeze a hull against a line rather than cutting it on one: vertices are
## compressed smoothly as they approach `lim` and asymptote to it, so the line is
## PRESSURE against expanding further rather than a wall. Nothing ever reaches it.
##
## A hard clamp was tried first and it works geometrically - the two eye patches
## stop short of the bridge - but every vertex past the line lands exactly ON it,
## which draws a straight edge down the inner side of each socket. Reported as a
## cut, three times, in three different disguises. The soft version has no edge to
## see: the hull just gets denser as it nears the line, so the paint fills in and
## thins out instead of stopping.
##
## The response is `x / (1 + x)` - saturating, monotone, and with a slope of 1 at
## the knee, so it joins the untouched part of the hull without a crease. The
## vertex COUNT is preserved either way, which _ring_quads requires: it pairs the
## outer and inner hulls by index and draws nothing at all if their sizes differ.
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


## Push the inner hull away from the outer wherever the two have converged closer
## than `min_d`, so the ring between them has a real width everywhere - including
## at the corners, where two concentric SCALED copies of a pointed hull always
## meet. Vertex for vertex, so the count is preserved (_ring_quads pairs them by
## index and draws nothing at all if the sizes differ), and untouched wherever the
## gap is already wide enough - which is everywhere but the corners, so Hollow goes
## on sizing the opening exactly as before.
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
		# Toward the hull's own center if the two points coincide, which is what
		# happens at a corner where the scaling has collapsed the gap entirely.
		var dir := v.normalized() if v.length() > 1e-6 else (c - qo).normalized()
		out.append((qo + dir * min_d) / a)
	return out


## Grow a hull, but never past a line. Same as _grow_hull except that each vertex
## is allowed only as much growth as keeps it on the near side of the half-plane
## `dot(p * asp - origin, n) <= lim` - so the hull swells freely in every direction
## except the one that is bounded, where it flattens against the line.
##
## THE TWO EYE PATCHES MUST NOT MEET ACROSS THE BRIDGE OF THE NOSE. _grow_hull
## scales about a hull's own centroid and knows nothing about the other eye, so at
## the stored Eye size (2.2x) each patch grew that far toward the nose as well and
## the pair fused into one bandit's mask - the exact fault clown_scale_check was
## written for, which bounded the ANALYTIC radii and never saw this path, because
## the stencil replaced it. Smudge then rubs the edges outward on top, so the
## clearance has to account for it too (see the caller).
##
## Capping the growth PER VERTEX rather than capping k for the whole hull is what
## keeps the patch its full size: a single k low enough to clear the bridge shrinks
## the outer corner by the same fraction, and the outer corner is the part the
## author wants big. Vertex COUNT is preserved either way, which _ring_quads
## requires - it pairs the outer and inner hulls by index and silently draws
## nothing at all if their sizes differ.
static func _grow_hull_bounded(pts: PackedVector2Array, k: float, origin: Vector2,
		n: Vector2, lim: float, asp: float) -> PackedVector2Array:
	if pts.is_empty():
		return pts
	var a := Vector2(asp, 1.0)
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	# How far the centroid already sits from the line. If it is past it there is
	# nothing sensible to do, so growth is simply not allowed to make it worse.
	var head := (c * a - origin).dot(n) - lim
	var out := PackedVector2Array()
	for p in pts:
		var b := ((p - c) * a).dot(n)
		var kp := k
		if b > 1e-6:
			# FLOORED AT 1.0 - THE MEASURED CONTOUR IS NEVER CLIPPED. Without this
			# floor the cap eats into the eye itself whenever the clearance is wider
			# than the space between the eye's inner corner and the midline, and it
			# is: the reported result was the inner half of the patch simply gone,
			# with the eye opening cut in two. Growth is what may be limited here,
			# never the outline the growth started from.
			kp = clampf(-head / b, 1.0, k)
		out.append(c + (p - c) * kp)
	return out


## Grow a hull about its own centroid. The features are drawn from measured
## outlines now, so "bigger eyes" has to mean a bigger version of THIS eye rather
## than a bigger circle - scaling the hull keeps the shape and only changes how
## much of the face it covers.
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


## THE SMILE. A clown's mouth is not the wearer's mouth - the Joker's runs most of
## the way to his ears and curves up past where any face bends. So the lip hull is
## stretched horizontally about its own center and its outer ends are swept along a
## curve, before rasterizing. Width 1 and curve 0 leave the real mouth exactly as
## measured; both push far past anatomy on purpose, because that is the look.
## The curve is applied proportionally to the SQUARE of the horizontal distance
## from center, so the middle of the lips stays put and the corners travel - which
## is how a smile actually deforms, and what keeps it a mouth rather than a banana.
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


## Rebuild the stencil for clip time `t`. Cheap enough to run every frame: four
## convex hulls of at most 36 points, then one small viewport draw.
func update_stencil(t: float) -> void:
	if editor._ft_state != "ready":
		return
	_ensure_stencil()
	var sz := Vector2(editor._stencil_vp.size)
	var eyes := PackedVector2Array()
	# The two eyes share a channel but must NOT share a hull - one hull around both
	# is a bandit's mask across the bridge of the nose.
	# EACH EYE IS A RING, not a patch: a clown paints around the eye, not over the
	# eyeball. Hollow sizes the opening.
	#
	# BOTH RADII ARE RELATIVE TO THE MEASURED EYE OPENING, and getting that wrong
	# is why the paint still covered the eyeballs after the ring was added. The
	# outer hull was 1.0x the opening and the hole ran 0 -> 0.82x, so even at full
	# Hollow the "ring" was a thin band between 82% and 100% of the eye - entirely
	# ON the eyeball, with nothing at all around it. Backwards. The patch has to be
	# comfortably BIGGER than the eye (a clown's is), and the hole has to reach
	# slightly PAST it so the eyeball is genuinely clear rather than fringed by the
	# landmark's own error.
	var eye_l_src := _ft_hull(FT_EYE_L, t)
	var eye_r_src := _ft_hull(FT_EYE_R, t)
	# 0.9x the eye opening at the stored default, widening to 1.5x. It used to run
	# from 0, i.e. NO hole - so out of the box the patch was solid over the eyeball,
	# the control that fixes it sat at its inert end, and there was no way to tell
	# from the panel that it was the one to reach for. A clown paints around the
	# eye; that is the default now, and the slider widens the opening from there.
	var hole := 0.9 + clampf(editor._clown_hollow, 0.0, 1.0) * 0.6
	# THE EYE PATCH IS THE MEASURED EYE, SCALED - the original geometry, restored.
	# Three attempts to improve on it each traded one fault for another and are
	# recorded here so none of them comes back: bounding the growth against a line
	# through the bridge (to stop the two patches fusing over the nose) emptied the
	# INNER side; rebuilding both hulls as normal offsets fixed the band but made
	# the patch an angular blob, because an eye hull is 8 to 1 and an offset in any
	# averaged unit inflates the short axis out of proportion; and gating the paint
	# on the coat's alpha (to keep a wide Smudge off the eyeball) cut a straight
	# edge down each socket. Scaling wraps the eye all the way round, which is the
	# property that actually matters, and the one thing it genuinely gets wrong -
	# a ring between two SCALED copies of a pointed hull pinches to nothing at the
	# corners - is fixed by _open_band, which is a few lines and touches nothing
	# else.
	var eye_l := _grow_hull(eye_l_src, editor._clown_eye_size)
	var eye_r := _grow_hull(eye_r_src, editor._clown_eye_size)
	var eye_l_in := _grow_hull(eye_l_src, hole)
	var eye_r_in := _grow_hull(eye_r_src, hole)
	var asp_e := editor._source_prep.source_aspect()
	var band_l := _hull_step(eye_l_src, asp_e) * 0.45
	var band_r := _hull_step(eye_r_src, asp_e) * 0.45
	# NOTHING HOLDS THE HULLS BACK FROM THE BRIDGE. Three versions tried to - a
	# per-vertex growth cap, a hard flatten against a line, then a soft asymptotic
	# squeeze - and all three drew a visible edge down the inner side of each
	# socket, because a hull here has SIXTEEN vertices and no operation on sixteen
	# points can be soft. The eye patches are simply the measured eyes, grown; the
	# bridge is kept bare per PIXEL instead, by a wide fade in the deposit (see
	# clown_paint's `bridge pressure`), which has as many samples as the frame has
	# texels and can therefore actually be gradual.
	var lips := _smile_hull(_ft_hull(FT_LIPS, t), editor._clown_smile_w, editor._clown_smile_curve)
	var nose := _ft_hull(FT_NOSE, t)
	# THE COAT'S OUTLINE IS DILATED A LITTLE past the measured jawline. Two soft
	# edges sit between the polygon and the picture - the deposit reads the
	# rasterized alpha through a smoothstep, and mask_split gates the whole layer
	# on the coat field through another - and each costs a pixel or two at the
	# boundary. Growing the hull moves BOTH of those outside the visible jaw, so
	# the jaw itself is interior and fully painted. It cannot spill onto the
	# background: the layer is separately gated on matching the face's own color
	# (match16 in the clown branch), so paint that exists past the jaw in the
	# FIELD simply has nothing to draw on.
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
	# THE OVAL GOES FIRST. Its color is the only one carrying alpha, and in
	# premultiplied blending an a=1 source REPLACES what is under it - drawn last
	# it would wipe the three channels drawn before it.
	_stencil_shapes = [[_to_px(oval, sz), Color(0, 0, 0, 1)]]
	_stencil_shapes.append_array(eye_shapes)
	_stencil_shapes.append([_to_px(lips, sz), Color(0, 1, 0, 0)])
	_stencil_shapes.append([_to_px(nose, sz), Color(0, 0, 1, 0)])
	# The eye openings come out of the COAT as well as out of the black - see
	# _ensure_stencil. Cut at the ring's own inner hull, so the hole in the white
	# is exactly the hole in the black and Hollow sizes both.
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


## A ring's half-extent, aspect-corrected so a radius means the same thing on
## either axis. Returned in RAW UV (the shaders' contract for these fields).
func _ft_ring_radius(ring: Array, t: float, asp: float) -> float:
	var c := _ft_ring_center(ring, t)
	var m := 0.0
	for i in ring:
		m = maxf(m, ((_ft_point(int(i), t) - c) * Vector2(asp, 1.0)).length())
	return m


## THE WHOLE FACE MODEL, from measured landmarks instead of a fitted blob. This
## is what replaces _update_face_model's ~300 lines of weighted mass, second
## moments, dark-cluster hunting and hand-tuned plausibility bounds. Every value
## below is a MEASUREMENT of a named part of the face, so there is nothing left to
## tune and nothing left to be wrong about pose: a turned head simply reports
## different landmark positions, which is the whole point.
func apply_model(t: float) -> void:
	var asp := editor._source_prep.source_aspect()
	var eye_l := _ft_ring_center(FT_EYE_L, t)
	var eye_r := _ft_ring_center(FT_EYE_R, t)
	var lips := _ft_ring_center(FT_LIPS, t)
	var top := _ft_point(FT_FACE_TOP, t)
	var chin := _ft_point(FT_FACE_CHIN, t)
	var left := _ft_point(FT_FACE_LEFT, t)
	var right := _ft_point(FT_FACE_RIGHT, t)
	# No EMA and no prediction. Both existed to paper over a detector that
	# jittered and lagged; this one is fitted offline over the whole clip, so the
	# track is already smooth and already knows the future. Writing straight
	# through is what makes the mask sit still.
	editor._face_eye_l_ema = eye_l
	editor._face_eye_r_ema = eye_r
	editor._face_mouth_ema = lips
	editor._face_nose_ema = _ft_point(FT_NOSE_TIP, t)
	editor._face_c_ema = (top + chin + left + right) * 0.25
	editor._face_r_ema = Vector2(absf(right.x - left.x) * 0.5, absf(chin.y - top.y) * 0.5)
	editor._face_eye_lr_ema = _ft_ring_radius(FT_EYE_L, t, asp)
	editor._face_eye_rr_ema = _ft_ring_radius(FT_EYE_R, t, asp)
	# The mouth's own half-width and half-height, measured corner-to-corner and
	# lip-to-lip - so it opens and closes with the real mouth instead of holding
	# a fitted ellipse's proportions.
	var mw := 0.0
	var mh := 0.0
	for i in FT_LIPS:
		var d := _ft_point(int(i), t) - lips
		mw = maxf(mw, absf(d.x))
		mh = maxf(mh, absf(d.y))
	editor._face_mouth_r_ema = Vector2(mw, mh)
	# The face's mean tint/luminance still come from the picture (the coat is a
	# per-pixel color match, not a fitted oval) - see _update_face_model, which
	# still runs for those when no track is available.
	editor._face_prev_lum = PackedFloat32Array()


func bin_path(tool_name: String) -> String:
	return Deps.venv_bin(FACE_VENV_DIR, tool_name)


func _ft_model_path() -> String:
	return Provision.file_path("face_model")


## Kick the pre-pass off (or discover it already cached). Called per frame while a
## clown layer is live; every branch is a cheap no-op once the track is ready.
## Deliberately lazy: a session that never uses the clown never installs anything.
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


## Track once the environment (and its models) is ready; until then show what its
## install is doing, and fail with the install's own reason if it cannot be had.
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
	# The ORIGINAL source where we still have it, else the prepared .ogv. The
	# source is better evidence: the transcode is theora q6 and its chroma blocks
	# are exactly the artifact a landmarker has to see past.
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
	# SAY SO rather than quietly drawing a bad mask. The fallback fitter still
	# runs, but the author needs to know they are looking at the fallback - the
	# whole reason this exists is that the fallback is not good enough.
	editor._set_status("⚠  Face tracking unavailable - " + why)


## stdout+stderr to one file, so a mediapipe error is readable afterwards instead
## of vanishing into a GUI launch's missing console.
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


## THE STEADINESS DIAL'S KERNEL: the Gaussian's width, in samples, for a Steadiness of [param
## steady] (0-1, the clown marker's `hue_b`). 0 has to be a GOOD value rather than "off" - some
## smoothing is always wanted - so the range runs from calm (2.5) to calmer (10).
static func sigma_for(steady: float) -> float:
	return 2.5 + clampf(steady, 0.0, 1.0) * 7.5


## Landmark `idx` at clip time `t`, in frame UV. Linearly interpolated between the
## two nearest samples - at 15 Hz a talking head moves little enough between them
## that this is a short interpolation rather than a guess, and it means the drawn
## mask moves continuously instead of stepping at the sample rate.
func _ft_point(idx: int, t: float) -> Vector2:
	if editor._ft_state != "ready" or _ft_count <= 0:
		return Vector2.ZERO
	var s := clampf(t * _ft_rate, 0.0, float(_ft_count - 1))
	# A CENTERED GAUSSIAN OVER THE SAMPLES, which smooths and interpolates in one
	# pass. This replaced a plain lerp between the two nearest samples, and the
	# reasoning behind that lerp was wrong in a way worth writing down: the track
	# is fitted offline, so it needs no LAG COMPENSATION - but that is not the same
	# as needing no smoothing. The detector still wobbles a pixel or two per
	# sample, and a lerp between noisy samples is a piecewise-linear path with a
	# CORNER at every one of them, so the whole mask twitched at the sample rate.
	#
	# Weighting neighbors on BOTH sides is what the offline track exists for. A
	# live tracker only has the past, so its only smoothing is a lag; a centered
	# kernel has ZERO phase - it removes the jitter and moves the mask not one
	# frame later than the face. And because the weight is a smooth function of
	# the continuous position, the result is smooth in time by construction:
	# no corners at sample boundaries, nothing to step.
	var sigma := editor._ft_sigma
	var half := maxi(1, int(ceil(sigma * 2.5)))
	var lo := maxi(0, int(s) - half)
	var hi := mini(_ft_count - 1, int(s) + half + 1)
	var acc := Vector2.ZERO
	var wsum := 0.0
	var base := idx * 2
	for i in range(lo, hi + 1):
		# LOST SAMPLES ARE SKIPPED, not averaged in - their coordinates are a held
		# copy of a neighbor, so including them would drag the feature toward
		# wherever the hold happened to be.
		if _ft_found[i] == 0:
			continue
		var d := (float(i) - s) / sigma
		var w := exp(-0.5 * d * d)
		var b := i * _ft_points * 2 + base
		acc += Vector2(_ft_xy[b], _ft_xy[b + 1]) * w
		wsum += w
	if wsum <= 1e-6:
		# Every sample in the window was lost - fall back to the nearest one that
		# is not, rather than returning the origin and snapping the mask to a corner.
		var n := clampi(int(round(s)), 0, _ft_count - 1)
		var bn := n * _ft_points * 2 + base
		return Vector2(_ft_xy[bn], _ft_xy[bn + 1])
	return acc / wsum


## Is there a real detection at `t`? The mean of a few landmarks is meaningless
## when the answer is "no face here", and the caller has to be able to hold.
func has_track(t: float) -> bool:
	if editor._ft_state != "ready" or _ft_count <= 0:
		return false
	return _ft_found[clampi(int(t * _ft_rate), 0, _ft_count - 1)] != 0


## The clown model's current display state - positions velocity-extrapolated
## by the fraction through the capture tick (prediction cancels the capture +
## EMA lag), sizes taken straight from their EMAs (predicting a size just
## amplifies shape twitch). One source of truth for _push_anchor AND the
## paint sim's deposit targets.
func clown_model_now() -> Dictionary:
	# LEAD scales the prediction. It is a jitter AMPLIFIER as much as a lag
	# canceller - it continues whatever the last tick did, so when the detection
	# is clean it cancels the capture+EMA delay, and when the detection is noisy
	# it doubles the noise and the mask visibly shakes at the capture cadence.
	# Which of those dominates is a property of the footage, so it is the
	# author's call: 0 turns the prediction off entirely (calmest, laggiest), 1
	# is the behavior this always had, 2 over-predicts for fast motion.
	var ff := clampf(fposmod(editor._player.stream_position, MaskEditor._FACE_INTERVAL) / MaskEditor._FACE_INTERVAL, 0.0, 1.0)
	# WITH A TRACK, DO NOT PREDICT. The prediction exists to cancel a live
	# detector's delay, and it does that by ramping a fraction from 0 to 1 across
	# each capture tick and then snapping back to 0 - a sawtooth. On a laggy
	# detector that sawtooth is smaller than the lag it cancels and worth paying.
	# On the offline track there is NO lag to cancel (the smoothing is centered),
	# so all that is left is the sawtooth itself: the whole mask lurching forward
	# and resetting several times a second, which is exactly the twitch reported.
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
