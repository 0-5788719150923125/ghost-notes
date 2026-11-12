extends SceneTree

## The Umbra's cast transform: the geometry, asserted without a clip, a renderer or mediapipe.
##   godot --headless --path . --script res://tests/masking/umbra_cast_check.gd
##
## The effect's claim is positional: the ghost's head lands where it was placed, its eyes land on that head,
## and it stands clear of her. Each fails silently (a transposed pair of matrix columns is still a
## rotation). Two-sided wherever a check could pass by the effect doing nothing: eyes on the head is paired
## with size and separation, and the Lean check evaluates the retired rise formula beside it, which must
## fail.

const POINTS := 33
const COUNT := 48
const RATE := 12.0
const MW := 96
const MH := 54
const ASP := 1.7778

# A synthetic subject, in frame UV: shoulders wide and low, eyes and ears where a head would put them. A
# close-up (her eyes at 0.19 of the frame height), the framing every placement rule has to survive.
const SH_L := Vector2(0.72, 0.60)
const SH_R := Vector2(0.40, 0.56)
const EYE_L := Vector2(0.60, 0.16)
const EYE_R := Vector2(0.52, 0.15)
const EAR_L := Vector2(0.63, 0.20)
const EAR_R := Vector2(0.49, 0.19)
## How far she moves between samples in the synthetic track: enough that a lead of a few samples is
## unmistakable, small enough that she never leaves the frame.
const WALK := 0.004

var _fails: PackedStringArray = []
var _ed: Node


func _initialize() -> void:
	var path := ProjectSettings.globalize_path("user://pose_tracks")
	DirAccess.make_dir_recursive_absolute(path)
	path = path.path_join("_cast_check.bin")
	_write_track(path)

	_ed = load("res://src/masking/mask_editor.gd").new()
	var s := MaskSession.new()
	s.video_path = "res://masks/_cast_check/video.ogv"
	_ed.session = s
	_ed._pt_state = "ready"
	_ed._pose._pt_load_chunk(0, path)
	if not _ed._pose._pt_chunks.has(0):
		print("umbra_cast_check: the synthetic window did not load")
		quit(2)
		return

	_forward_and_inverse_agree()
	_eyes_land_on_the_head()
	_it_stands_clear_of_her()
	_it_stands_where_there_is_room()
	_scale_and_lean_do_something()
	_the_rise_is_not_pinned()
	_the_lead_actually_leads()

	_ed.free()
	DirAccess.remove_absolute(path)
	print("")
	if _fails.is_empty():
		print("umbra_cast_check: PASS - the throw puts the ghost where it says it does.")
		quit(0)
	else:
		for x in _fails:
			print("umbra_cast_check: FAIL - ", x)
		quit(1)


## Every knob at once, so a case is one line and nothing keeps the last case's setting.
func _solve(scale: float, lean: float, narrow: float, stand: float,
		pan := Vector2.ZERO, loom := 0.45) -> bool:
	_ed._umb_scale = scale
	_ed._umb_lean = lean
	_ed._umb_narrow = narrow
	_ed._umb_stand = stand
	_ed._umb_pan = pan
	_ed._umb_loom = loom
	return _ed._umb_cast_from(0, ASP)


## The inverse the shader uses must undo the forward map the eyes use. Both come from the same pair of
## columns and are used at opposite ends of the effect (the CPU pushes her eyes forward, the fragment
## pulls its own position back), so a transposition or bad determinant makes the body and the eyes
## describe two ghosts. Checked by round-tripping her landmarks: source -> screen -> source.
func _forward_and_inverse_agree() -> void:
	if not _solve(1.7, 0.5, 0.35, 1.05):
		_fails.append("the solve refused a perfectly ordinary case")
		return
	var av := Vector2(ASP, 1.0)
	# Her eye line maps to the ghost's eye line, and the shader's inverse of that must be her eye line.
	var mid_screen: Vector2 = (_ed._umb_eye_l + _ed._umb_eye_r) * 0.5 * av
	var d: Vector2 = mid_screen - _ed._umb_anchor
	var back: Vector2 = _ed._umb_src + _ed._umb_inv0 * d.x + _ed._umb_inv1 * d.y
	var want := (EYE_L + EYE_R) * 0.5 * av
	var err := back.distance_to(want)
	print("round-trip: her eye line %s -> ghost %s -> back %s   error %.5f"
		% [want, mid_screen, back, err])
	_expect(err < 1e-3,
		"the shader's inverse does not undo the forward map (error %.4f) - a "
		% err + "transposed column pair reads exactly like this")
	# ...and the ghost's eye line is at the anchor plus scale x unit along the body axis.
	var reach: float = (mid_screen - _ed._umb_anchor).length()
	_expect(absf(reach - _ed._umb_unit * 1.7) < 0.02,
		"the ghost's head sits %.3f from its anchor, expected %.3f (scale x unit)"
			% [reach, _ed._umb_unit * 1.7])


## The eyes are on the head, and there are two of them. Landing alone is satisfied by a transform that
## collapses everything onto one point, so the separation is asserted too, at three Scales (the
## placement is scale-dependent).
func _eyes_land_on_the_head() -> void:
	for sc in [0.8, 1.6, 2.8]:
		if not _solve(sc, 0.5, 0.35, 1.05):
			_fails.append("the solve refused scale %.1f" % sc)
			continue
		var l: Vector2 = _ed._umb_eye_l
		var r: Vector2 = _ed._umb_eye_r
		var sep: float = ((l - r) * Vector2(ASP, 1.0)).length()
		var her_sep: float = ((EYE_L - EYE_R) * Vector2(ASP, 1.0)).length()
		print("scale %.1f: eyes %s %s  separation %.4f (hers %.4f)  radius %.4f"
			% [sc, l, r, sep, her_sep, _ed._umb_eye_rad])
		_expect(l.x > 0.0 and l.x < 1.0 and l.y > 0.0 and l.y < 1.0
				and r.x > 0.0 and r.x < 1.0 and r.y > 0.0 and r.y < 1.0,
			"at scale %.1f an eye is off the frame (%s, %s)" % [sc, l, r])
		_expect(sep > 0.4 * her_sep,
			"at scale %.1f the eyes collapsed together (separation %.4f)" % [sc, sep])
		_expect(absf(sep - her_sep * sc * 0.65) < her_sep * sc * 0.35,
			"at scale %.1f the separation %.4f is not near hers scaled (%.4f)"
				% [sc, sep, her_sep * sc * 0.65])
		_expect(_ed._umb_eye_rad > 0.004 and _ed._umb_eye_rad < 0.12,
			"at scale %.1f the socket radius is %.4f" % [sc, _ed._umb_eye_rad])


## It stands clear of her head. The separation is the two skulls' half-widths, so this holds at every
## Scale: a ghost drawn on her is eaten by her own exclusion mask.
func _it_stands_clear_of_her() -> void:
	var her_hw := absf(EAR_L.x - EAR_R.x) * ASP * 0.5
	for sc in [0.8, 1.6, 2.8]:
		if not _solve(sc, 0.5, 0.35, 1.05):
			continue
		var mid: Vector2 = (_ed._umb_eye_l + _ed._umb_eye_r) * 0.5
		var her_mid := (EYE_L + EYE_R) * 0.5
		var dx := absf(mid.x - her_mid.x) * ASP
		var want: float = her_hw + her_hw * sc * 0.65
		print("scale %.1f: ghost head %.4f clear of hers (need ~%.4f)" % [sc, dx, want])
		_expect(dx > want * 0.6,
			"at scale %.1f the ghost's head is only %.4f from hers, needs ~%.4f"
				% [sc, dx, want])


## It stands on the side there is room for. Driven by moving her: with her against the right edge there is
## no room on the throw side, so the ghost must cross to her left (clamping alone would leave the head
## against the frame edge).
func _it_stands_where_there_is_room() -> void:
	_shift_subject(0.34)   # her eye line to ~0.94 of the frame width
	_solve(1.6, 0.5, 0.35, 1.05)
	var mid: Vector2 = (_ed._umb_eye_l + _ed._umb_eye_r) * 0.5
	print("crowded right: her eyes at %.3f, ghost at %.3f" % [(EYE_L.x + EYE_R.x) * 0.5 + 0.34, mid.x])
	_expect(mid.x < (EYE_L.x + EYE_R.x) * 0.5 + 0.34,
		"with her against the right edge the ghost stayed on the throw side (x %.3f)" % mid.x)
	_expect(mid.x > 0.02 and mid.x < 0.98, "the ghost's head left the frame (x %.3f)" % mid.x)
	_shift_subject(0.0)


## Scale and Lean both move something (a control can be inert while the render looks plausible).
func _scale_and_lean_do_something() -> void:
	_solve(1.0, 0.5, 0.35, 1.05)
	var small: float = ((_ed._umb_eye_l - _ed._umb_eye_r) * Vector2(ASP, 1.0)).length()
	_solve(2.6, 0.5, 0.35, 1.05)
	var big: float = ((_ed._umb_eye_l - _ed._umb_eye_r) * Vector2(ASP, 1.0)).length()
	print("Scale 1.0 -> 2.6: eye separation %.4f -> %.4f" % [small, big])
	_expect(big > small * 1.8, "Scale barely changed the ghost (%.4f -> %.4f)" % [small, big])

	_solve(1.6, 0.0, 0.35, 1.05)
	var up: Vector2 = (_ed._umb_eye_l + _ed._umb_eye_r) * 0.5
	var ax0: Vector2 = _ed._umb_eye_l - _ed._umb_eye_r
	_solve(1.6, 1.0, 0.35, 1.05)
	var over: Vector2 = (_ed._umb_eye_l + _ed._umb_eye_r) * 0.5
	var ax1: Vector2 = _ed._umb_eye_l - _ed._umb_eye_r
	var rose := up.y - over.y
	var turned := absf(ax1.angle() - ax0.angle())
	print("Lean 0 -> 1: head rose %.4f, eye line turned %.1f degrees"
		% [rose, rad_to_deg(turned)])
	_expect(rose > 0.01, "Lean did not raise the ghost at all (%.4f)" % rose)
	_expect(rad_to_deg(turned) > 3.0,
		"Lean did not tilt the ghost's body (%.1f degrees)" % rad_to_deg(turned))

	_solve(1.6, 0.5, 0.35, 0.5)
	var near: Vector2 = (_ed._umb_eye_l + _ed._umb_eye_r) * 0.5
	_solve(1.6, 0.5, 0.35, 2.2)
	var far: Vector2 = (_ed._umb_eye_l + _ed._umb_eye_r) * 0.5
	print("Stand 0.5 -> 2.2: head x %.3f -> %.3f" % [near.x, far.x])
	_expect(absf(far.x - near.x) > 0.03, "Stand did not move the ghost sideways")


## The rise is measured against the headroom. The control is the retired formulation, `eye.y - k * unit *
## scale` clamped, evaluated on the same subject: it returns one height for every Lean on a close-up, so
## it must be pinned or this assertion is about nothing.
func _the_rise_is_not_pinned() -> void:
	var her_hw := absf(EAR_L.x - EAR_R.x) * ASP * 0.5
	var eye_y := (EYE_L.y + EYE_R.y) * 0.5
	var unit := ((EYE_L + EYE_R) * 0.5 - (SH_L + SH_R) * 0.5) * Vector2(ASP, 1.0)
	var sc := 1.6
	var ghost_hw := her_hw * sc * 0.65
	var old_lo: float = clampf(eye_y - (0.10 + 0.45 * 0.0) * unit.length() * sc,
		ghost_hw * 1.05 + 0.02, 0.72)
	var old_hi: float = clampf(eye_y - (0.10 + 0.45 * 1.0) * unit.length() * sc,
		ghost_hw * 1.05 + 0.02, 0.72)
	_solve(sc, 0.0, 0.35, 1.05)
	var new_lo: float = (_ed._umb_eye_l.y + _ed._umb_eye_r.y) * 0.5
	_solve(sc, 1.0, 0.35, 1.05)
	var new_hi: float = (_ed._umb_eye_l.y + _ed._umb_eye_r.y) * 0.5
	print("rise over the whole Lean range - retired rule %.4f -> %.4f, this one %.4f -> %.4f"
		% [old_lo, old_hi, new_lo, new_hi])
	_expect(absf(old_hi - old_lo) < 0.005,
		"the CONTROL did not reproduce the pinned rise (%.4f -> %.4f) - it moved, so "
		% [old_lo, old_hi] + "this check is not measuring what it claims to")
	_expect(absf(new_hi - new_lo) > 0.02,
		"the rise is still pinned on a close-up (%.4f -> %.4f)" % [new_lo, new_hi])


## The lead is the effect: a ghost that follows her is a shadow, one that arrives first needs a frame that
## has not been decoded, which is why the track is offline. With a subject who walks across the synthetic
## track, the ghost solved at `t + Lead` must be further along than the one at `t`, by about the distance
## she covers in that time. The control is Lead = 0 on the same track, which must not be ahead.
func _the_lead_actually_leads() -> void:
	var rate := RATE
	var now := 0.5
	var lead := 0.5
	var i_now: int = _ed._pose.slot_at(now)
	var i_lead: int = _ed._pose.slot_at(now + lead)
	_expect(i_lead > i_now,
		"a Lead of %.2fs selected sample %d, the same or earlier than %d at t=%.2f"
			% [lead, i_lead, i_now, now])
	_expect(i_lead - i_now == int(round(lead * rate)),
		"a Lead of %.2fs advanced %d samples, expected %d"
			% [lead, i_lead - i_now, int(round(lead * rate))])
	_ed._umb_cast_from(i_now, ASP)
	var here: float = (_ed._umb_eye_l.x + _ed._umb_eye_r.x) * 0.5
	_ed._umb_cast_from(i_lead, ASP)
	var ahead: float = (_ed._umb_eye_l.x + _ed._umb_eye_r.x) * 0.5
	var her_step := WALK * float(i_lead - i_now)
	print("Lead %.2fs: ghost head x %.4f -> %.4f (she covers %.4f in that time)"
		% [lead, here, ahead, her_step])
	_expect(ahead - here > her_step * 0.5,
		"the ghost moved %.4f over a %.2fs lead while she moved %.4f - it is not "
			% [ahead - here, lead, her_step] + "reading ahead of the playhead")


## Move the whole subject sideways by rewriting the track in place (the room rule is about where she is).
func _shift_subject(dx: float) -> void:
	var xy: PackedFloat32Array = _ed._pose._pt_chunks[0]["xy"]
	for k in [_ed.PT_SH_L, _ed.PT_SH_R, _ed.PT_EYE_L, _ed.PT_EYE_R,
			_ed.PT_EAR_L, _ed.PT_EAR_R]:
		xy[(0 * POINTS + int(k)) * 2] = _base_x(int(k)) + dx
	_ed._pose._pt_chunks[0]["xy"] = xy


static func _base_x(k: int) -> float:
	match k:
		11: return SH_L.x
		12: return SH_R.x
		2: return EYE_L.x
		5: return EYE_R.x
		7: return EAR_L.x
		8: return EAR_R.x
	return 0.5


func _write_track(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("GST2".to_ascii_buffer())
	f.store_32(2)
	f.store_float(RATE)
	f.store_32(COUNT)
	f.store_32(POINTS)
	f.store_32(MW)
	f.store_32(MH)
	f.store_32(0)
	# The throw points right and up, as it does on the reference clip.
	f.store_float(0.88)
	f.store_float(-0.47)
	f.store_float(0.45)
	var pts := {11: SH_L, 12: SH_R, 2: EYE_L, 5: EYE_R, 7: EAR_L, 8: EAR_R}
	for i in COUNT:
		f.store_8(1)
		for k in POINTS:
			var p: Vector2 = pts.get(k, Vector2(0.5, 0.5))
			# She walks from sample 1 onward; sample 0 stays where the placement checks expect her.
			f.store_float(p.x + WALK * float(i))
			f.store_float(p.y)
		for k in POINTS:
			f.store_float(1.0)
		for c in MW * MH:
			f.store_8(255)
	f.close()


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
