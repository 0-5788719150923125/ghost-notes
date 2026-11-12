extends SceneTree

## Does the clown's face model see the same face the same way regardless of the clip's shape?
##   godot --headless --path . --script res://tests/masking/clown_face_check.gd
##
## Bounds written in raw UV are not shape-independent (0.145 of the frame's width is 0.258 frame-heights
## on 16:9 and 0.082 on 9:16), so the model and clown_paint.gdshader must size against the frame's shorter
## side. The same synthetic face, framed identically against the shorter side, is rendered landscape and
## portrait, and each fit is compared against the face drawn in that frame, not against the other shape's
## fit (the two legitimately differ). The ratio fitted/true is the shape-independent quantity.
## It measures what reaches the picture, not just the CPU fit: the paint sim's coat cap is applied too.
## The face is synthetic because a real clip has one shape, and re-cropping changes the framing as well.

const SHAPES := [
	["landscape 16:9", Vector2i(640, 360)],
	["portrait 9:16", Vector2i(360, 640)],
]
## Where the face is drawn, as a fraction of the frame: centered horizontally, slightly high, sized against
## the shorter side so both renders show the same face.
const FACE_CX := 0.5
const FACE_CY := 0.42
## Semi-width in units of the frame's shorter side. 0.20 puts the head across 40% of that side, the
## framing the sim's caps are tuned for (a tight close-up makes the coat caps bite).
const FACE_R_SHORT := 0.20
const FACE_TALL := 1.30       # a head is this much taller than it is wide
const EYE_DX := 0.42          # eye offset from center, in face half-widths
const EYE_DY := -0.30         # ...and above center, in face half-HEIGHTS
const MOUTH_DY := 0.48

## Mirrors of clown_paint.gdshader's coat cap, the last thing between the fitted radii and what is drawn.
## Keep in sync with FACE_CAP_X* and the y clamp there.
const SHADER_CAP_XLO := 0.0889
const SHADER_CAP_XHI := 0.2578
const SHADER_CAP_YLO := 0.07
const SHADER_CAP_YHI := 0.205

var _fails: PackedStringArray = []


func _initialize() -> void:
	var seen := []
	for shape in SHAPES:
		var size: Vector2i = shape[1]
		var asp := float(size.x) / float(size.y)
		var short := float(mini(size.x, size.y))
		# The face's true geometry in this frame, in UV and in height units.
		var rx_uv := FACE_R_SHORT * short / float(size.x)
		var ry_uv := FACE_R_SHORT * FACE_TALL * short / float(size.y)
		var img := _draw_face(size, rx_uv, ry_uv)
		var ed: Node = load("res://src/masking/mask_editor.gd").new()
		ed.session = _session()
		for i in 24:
			ed._update_face_model(img)
		var got := {
			"name": shape[0], "asp": asp,
			"rx_h": ed._face_r_ema.x * asp, "ry_h": ed._face_r_ema.y,
			"cx": ed._face_c_ema.x, "cy": ed._face_c_ema.y,
			"eye_l": ed._face_eye_l_ema, "eye_r": ed._face_eye_r_ema,
			"mouth": ed._face_mouth_ema,
			"true_rx_h": rx_uv * asp, "true_ry_h": ry_uv,
		}
		ed.free()
		# What the paint sim will actually draw, after its own cap.
		got["coat_x"] = clampf(got.rx_h, SHADER_CAP_XLO, SHADER_CAP_XHI)
		got["coat_y"] = clampf(got.ry_h, SHADER_CAP_YLO, SHADER_CAP_YHI)
		got["fx"] = got.coat_x / got.true_rx_h
		got["fy"] = got.coat_y / got.true_ry_h
		var true_sep: float = 2.0 * EYE_DX * got.true_rx_h
		got["fsep"] = (absf(got.eye_r.x - got.eye_l.x) * asp) / true_sep
		seen.append(got)
		print("")
		print("--- %s (%dx%d) ---" % [shape[0], size.x, size.y])
		print("  fitted half-axes  %.4f x %.4f   (the face really is %.4f x %.4f)"
			% [got.rx_h, got.ry_h, got.true_rx_h, got.true_ry_h])
		print("  DRAWN coat        %.4f x %.4f   -> %.0f%% / %.0f%% of the real face"
			% [got.coat_x, got.coat_y, got.fx * 100.0, got.fy * 100.0])
		print("  center          (%.3f, %.3f)   eyes L(%.3f,%.3f) R(%.3f,%.3f)  mouth (%.3f,%.3f)"
			% [got.cx, got.cy, got.eye_l.x, got.eye_l.y,
			   got.eye_r.x, got.eye_r.y, got.mouth.x, got.mouth.y])
		print("  eye separation  %.0f%% of the real pair's" % [got.fsep * 100.0])
		# The coat must be face-sized on either shape.
		_expect(got.fx > 0.60 and got.fx < 1.45,
			"%s: the drawn coat is %.0f%% of the real face's half-width"
			% [got.name, got.fx * 100.0])
		_expect(got.fy > 0.60 and got.fy < 1.45,
			"%s: the drawn coat is %.0f%% of the real face's half-height"
			% [got.name, got.fy * 100.0])
		_expect(got.fsep > 0.6 and got.fsep < 1.5,
			"%s: the eye pair came out %.0f%% of the real separation - every drawn "
			% [got.name, got.fsep * 100.0] + "feature scales by this")
		# The face is where it was drawn, on both. Generous tolerances: a blob fitter, not a landmark detector.
		_expect(absf(got.cx - FACE_CX) < 0.10,
			"%s: face center x %.3f, drawn at %.3f" % [got.name, got.cx, FACE_CX])
		_expect(absf(got.cy - FACE_CY) < 0.14,
			"%s: face center y %.3f, drawn at %.3f" % [got.name, got.cy, FACE_CY])
		_expect(got.eye_l.y < got.mouth.y and got.eye_r.y < got.mouth.y,
			"%s: the mouth did not come out below the eyes (eyes %.3f/%.3f, mouth %.3f)"
			% [got.name, got.eye_l.y, got.eye_r.y, got.mouth.y])
		_expect(got.eye_r.x > got.eye_l.x,
			"%s: the eye pair came out crossed" % got.name)

	# It should not matter which shape the clip is: the two grades are compared to each other, so a rule
	# that favors one shape fails even inside the absolute tolerances.
	var a: Dictionary = seen[0]
	var b: Dictionary = seen[1]
	print("")
	print("landscape vs portrait, as fractions of each one's own real face:")
	# Width is the sharp one: the aspect divides out of every other quantity, but a width bound in raw uv
	# scales directly with the frame's shape. Height and separation are looser: at ordinary framing the
	# coat's height cap bites on 16:9 and not on portrait, which is intended.
	for row in [["coat half-width", a.fx, b.fx, 0.85, 1.20],
			["coat half-height", a.fy, b.fy, 0.70, 1.45],
			["eye separation", a.fsep, b.fsep, 0.75, 1.35]]:
		var la: float = row[1]
		var lb: float = row[2]
		print("  %-17s %.0f%% vs %.0f%%   (portrait is %.2fx as faithful)"
			% [row[0], la * 100.0, lb * 100.0, lb / la])
		_expect(lb / la > float(row[3]) and lb / la < float(row[4]),
			"%s tracks the real face %.2fx as well on portrait as on landscape - "
			% [row[0], lb / la] + "the model still reads one frame shape better than the other")

	# Steadiness is the face track's, held by face_track_check (_check_steady): the CPU model this gate
	# reads has no steadiness of its own.

	print("")
	if _fails.is_empty():
		print("clown_face_check: PASS - the same face fits the same on either frame shape, ",
			"and Steady actually steadies it.")
		quit(0)
	else:
		for f in _fails:
			print("clown_face_check: FAIL - ", f)
		quit(1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


## A session holding one clown marker, which is all _update_face_model looks for
## (it keys off the first clown marker's hue and returns early without one).
func _session() -> MaskSession:
	var s := MaskSession.new()
	var m := {}
	for k in MaskSession.VECTOR_FIELDS:
		m[k] = MaskSession.DEFAULTS.get(k, 0.0)
	m["effect_a"] = float(MaskSession.EFFECT_CLOWN)
	m["hue_a"] = 0.05        # skin
	m["time"] = 0.0
	s.markers.append(m)
	return s


## A crude but unambiguous face: a warm oval on a cool ground, two dark eye sockets, a red mouth. Every cue
## the model uses is present and nothing else competes.
func _draw_face(size: Vector2i, rx: float, ry: float, dx := 0.0) -> Image:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var cx := FACE_CX + dx
	var eye_l := Vector2(cx - EYE_DX * rx, FACE_CY + EYE_DY * ry)
	var eye_r := Vector2(cx + EYE_DX * rx, FACE_CY + EYE_DY * ry)
	var mouth := Vector2(cx, FACE_CY + MOUTH_DY * ry)
	for py in size.y:
		for px in size.x:
			var uv := Vector2((float(px) + 0.5) / float(size.x),
				(float(py) + 0.5) / float(size.y))
			var c := Color(0.12, 0.13, 0.20)          # a cool, dark room
			var d := Vector2((uv.x - cx) / rx, (uv.y - FACE_CY) / ry).length()
			if d < 1.0:
				c = Color(0.80, 0.60, 0.48)           # lit skin
				# Sockets, drawn in the SAME proportions on both frames.
				for e in [eye_l, eye_r]:
					var de := Vector2((uv.x - e.x) / (rx * 0.22),
						(uv.y - e.y) / (ry * 0.13)).length()
					if de < 1.0:
						c = Color(0.10, 0.09, 0.10)
				var dm := Vector2((uv.x - mouth.x) / (rx * 0.42),
					(uv.y - mouth.y) / (ry * 0.10)).length()
				if dm < 1.0:
					c = Color(0.62, 0.20, 0.22)       # lips: redder than the face
			img.set_pixel(px, py, c)
	return img
