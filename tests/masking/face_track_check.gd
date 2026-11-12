extends SceneTree

## The face track's format contract, checked from the reading side.
##   godot --headless --path . --script res://tests/masking/face_track_check.gd
##
## hosts/face/face_track.py writes the file and MaskEditor reads it, so the layout is agreed in two places.
## This builds a track byte by byte to the documented layout, reads it through the editor's own reader and
## checks the values come back. It needs no mediapipe, venv or clip: the contract is under test, not the
## detector.

const POINTS := 478
const COUNT := 40
const RATE := 15.0
## The steadiness check's own track: long enough that the widest kernel (2.5 sigma either side of sigma 10)
## stays inside it where it is read, and a wobble slow enough to tell the dial's ends apart.
const JIGGLE_N := 120
const JIGGLE_PERIOD := 12.0

var _fails: PackedStringArray = []


func _initialize() -> void:
	var path := ProjectSettings.globalize_path("user://face_tracks")
	DirAccess.make_dir_recursive_absolute(path)
	path = path.path_join("_check.bin")
	# A synthetic track: landmark k of sample i is a pure function of (i, k), so any misread (header,
	# stride, endianness, off-by-one sample) lands on a value the check can name.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("GFT1".to_ascii_buffer())
	f.store_32(1)
	f.store_float(RATE)
	f.store_32(COUNT)
	f.store_32(POINTS)
	for i in COUNT:
		# Sample 7 is a lost frame: the reader must not interpolate across it.
		f.store_8(0 if i == 7 else 1)
		for k in POINTS:
			f.store_float(_expect_x(i, k))
			f.store_float(_expect_y(i, k))
	f.close()

	var ed: Node = load("res://src/masking/mask_editor.gd").new()
	var s := MaskSession.new()
	s.video_path = "res://masks/_face_check/video.ogv"
	ed.session = s
	ed._face._ft_path = path
	ed._face._ft_load()
	print("state=%s count=%d points=%d rate=%.1f" % [ed._ft_state, ed._face._ft_count, ed._face._ft_points, ed._face._ft_rate])
	_expect(ed._ft_state == "ready", "the reader rejected a well-formed track (%s)" % ed._ft_state)
	_expect(ed._face._ft_count == COUNT, "count read as %d, wrote %d" % [ed._face._ft_count, COUNT])
	_expect(ed._face._ft_points == POINTS, "points read as %d, wrote %d" % [ed._face._ft_points, POINTS])

	# Exact sample times must return exactly what was written; this survives the reader's smoothing because
	# the synthetic track is linear in the sample index (see _expect_x). Probes stay away from both ends
	# (the kernel is truncated there, so no longer symmetric) and from the lost sample at 7 (its window is
	# missing a member).
	for probe in [[16, 0], [16, 33], [20, 263], [27, 1], [30, 477]]:
		var i: int = probe[0]
		var k: int = probe[1]
		var got: Vector2 = ed._face._ft_point(k, float(i) / RATE)
		var want := Vector2(_expect_x(i, k), _expect_y(i, k))
		print("  sample %2d landmark %3d -> (%.4f, %.4f)  want (%.4f, %.4f)"
			% [i, k, got.x, got.y, want.x, want.y])
		_expect(got.distance_to(want) < 0.0005,
			"sample %d landmark %d read (%.4f,%.4f), wrote (%.4f,%.4f)"
			% [i, k, got.x, got.y, want.x, want.y])

	# Between samples the reader interpolates, so the mask moves continuously. Mid-track, for the same
	# symmetry reason.
	var mid: Vector2 = ed._face._ft_point(0, 20.5 / RATE)
	var a := Vector2(_expect_x(20, 0), _expect_y(20, 0))
	var b := Vector2(_expect_x(21, 0), _expect_y(21, 0))
	print("  halfway between samples 20 and 21 -> (%.4f, %.4f)" % [mid.x, mid.y])
	_expect(mid.distance_to(a.lerp(b, 0.5)) < 0.0005,
		"the reader did not interpolate between samples (got %.4f, wanted %.4f)"
		% [mid.x, a.lerp(b, 0.5).x])

	# ...but never across a lost sample: reading just before the gap returns the last good sample.
	_expect(not ed._face.has_track(7.0 / RATE), "sample 7 was written lost but reads as found")
	_expect(ed._face.has_track(6.0 / RATE), "sample 6 was written found but reads as lost")
	# A lost sample is skipped by the smoothing, not averaged in (its stored coordinates are a held copy of
	# a neighbor). A correctly skipped gap stays near the line; an averaged-in hold pulls visibly off it.
	var near_gap: Vector2 = ed._face._ft_point(0, 7.0 / RATE)
	var on_line := Vector2(_expect_x(7, 0), _expect_y(7, 0))
	print("  at the lost sample -> (%.4f, %.4f)  (the line there is %.4f, %.4f)"
		% [near_gap.x, near_gap.y, on_line.x, on_line.y])
	_expect(near_gap.distance_to(on_line) < 0.004,
		"reading at a lost sample landed (%.4f,%.4f) against a line at (%.4f,%.4f) - "
		% [near_gap.x, near_gap.y, on_line.x, on_line.y]
		+ "the held coordinates were averaged in instead of skipped")

	# The smoothing is reachable: a wider centered kernel over a linear track returns the same line (no lag,
	# no bias), so the reader must accept the setting and stay on the line.
	ed._ft_sigma = 6.0
	var wide: Vector2 = ed._face._ft_point(0, 20.0 / RATE)
	var line20 := Vector2(_expect_x(20, 0), _expect_y(20, 0))
	print("  sigma 6.0 at sample 20 -> (%.4f, %.4f)  line (%.4f, %.4f)"
		% [wide.x, wide.y, line20.x, line20.y])
	_expect(wide.distance_to(line20) < 0.004,
		"heavy smoothing pulled the value off the line (%.4f vs %.4f) - a centered "
		% [wide.x, line20.x] + "kernel must not bias, only smooth")
	ed._ft_sigma = 2.5

	# A truncated file is refused and removed, not read as garbage.
	var t2 := ProjectSettings.globalize_path("user://face_tracks/_check_short.bin")
	var g := FileAccess.open(t2, FileAccess.WRITE)
	g.store_buffer("GFT1".to_ascii_buffer())
	g.store_32(1)
	g.store_float(RATE)
	g.store_32(COUNT)
	g.store_32(POINTS)
	g.store_8(1)          # one byte of one sample, then nothing
	g.close()
	var ed2: Node = load("res://src/masking/mask_editor.gd").new()
	ed2.session = s
	ed2._face._ft_path = t2
	ed2._face._ft_load()
	print("truncated track -> state=%s, file still present=%s"
		% [ed2._ft_state, FileAccess.file_exists(t2)])
	_expect(ed2._ft_state == "failed", "a truncated track was accepted (%s)" % ed2._ft_state)
	_expect(not FileAccess.file_exists(t2),
		"a truncated track was left on disk - it would be re-read forever")
	ed.free()
	ed2.free()
	DirAccess.remove_absolute(path)

	_check_steady(s)

	print("")
	if _fails.is_empty():
		print("face_track_check: PASS - the track round-trips, interpolates, and ",
			"refuses what it should.")
		quit(0)
	else:
		for x in _fails:
			print("face_track_check: FAIL - ", x)
		quit(1)


## Steadiness calms a jiggle. The clown's Steadiness dial sets the face track's kernel
## (`MaskFaceTrack.sigma_for`, asked through the editor: a class named here would be compiled with this
## gate, before the autoloads it names exist); a track whose landmark shakes a pixel each way every sample
## is read at both ends of the dial, and the top must move the drawn point well under half as much from
## sample to sample. That the kernel never biases a straight line is held above.
func _check_steady(s: MaskSession) -> void:
	var path := ProjectSettings.globalize_path("user://face_tracks/_check_jiggle.bin")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("GFT1".to_ascii_buffer())
	f.store_32(1)
	f.store_float(RATE)
	f.store_32(JIGGLE_N)
	f.store_32(POINTS)
	for i in JIGGLE_N:
		f.store_8(1)
		for k in POINTS:
			f.store_float(0.5 + 0.002 * sin(TAU * float(i) / JIGGLE_PERIOD))
			f.store_float(0.5)
	f.close()
	var ed: Node = load("res://src/masking/mask_editor.gd").new()
	ed.session = s
	ed._face._ft_path = path
	ed._face._ft_load()
	var moved := {}
	for steady in [0.0, 0.9]:
		ed._ft_sigma = ed._face.sigma_for(steady)
		var acc := 0.0
		for i in range(54, 66):
			acc += absf(ed._face._ft_point(0, float(i + 1) / RATE).x - ed._face._ft_point(0, float(i) / RATE).x)
		moved[steady] = acc / 12.0
	print("steadiness against a track wobbling 0.002 each way every %d samples:" % int(JIGGLE_PERIOD))
	print("  Steadiness 0.0 (sigma %.2f) -> %.6f per sample" % [ed._face.sigma_for(0.0), moved[0.0]])
	print("  Steadiness 0.9 (sigma %.2f) -> %.6f per sample" % [ed._face.sigma_for(0.9), moved[0.9]])
	_expect(moved[0.0] > 0.0, "CONTROL: the jiggle never reached the reader - the check below proves nothing")
	_expect(moved[0.9] < moved[0.0] * 0.5,
		"Steadiness barely calmed the jiggle (%.6f at 0.9 vs %.6f at 0.0) - the dial is not "
		% [moved[0.9], moved[0.0]] + "reaching the smoothing it claims to set")
	ed.free()
	DirAccess.remove_absolute(path)


## Distinct per (sample, landmark) so a misread is identifiable, linear in the sample index, and small
## enough never to wrap. Linearity matters: the reader smooths with a centered kernel and returns a
## weighted average of the sample and its neighbors, which over a linear function a symmetric kernel
## gives exactly at its center, so the round trip stays an exact assertion.
static func _expect_x(i: int, k: int) -> float:
	return 0.10 + 0.004 * float(i) + 0.0008 * float(k)


static func _expect_y(i: int, k: int) -> float:
	return 0.30 + 0.003 * float(i) + 0.0005 * float(k)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
