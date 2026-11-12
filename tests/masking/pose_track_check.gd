extends SceneTree

## The pose track's format contract, checked from the reading side, for one window of it (the clip is read
## a window at a time, see MaskEditor's `_pt_*` half).
##   godot --headless --path . --script res://tests/masking/pose_track_check.gd
##
## hosts/face/pose_track.py writes the file and MaskEditor reads it, so the layout is agreed in two places.
## A sample also carries 5 KB of silhouette, so a stride off by one byte turns the body into noise.
## Builds a track byte by byte to the documented layout, reads it through the editor's own reader and
## checks the values come back. Needs no mediapipe, venv or clip.

const POINTS := 33
const COUNT := 24
## The window this file claims to be. Sample numbering is global, so a window that misstates its start would
## put the ghost on the wrong frame: the reader checks the header against the filename and this checks the
## reader.
const CHUNK := 3
const RATE := 12.0
const MW := 96
const MH := 54

var _fails: PackedStringArray = []


func _initialize() -> void:
	var path := ProjectSettings.globalize_path("user://pose_tracks")
	DirAccess.make_dir_recursive_absolute(path)
	path = path.path_join("_check.bin")
	var base := CHUNK * int(RATE * 20.0)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("GST2".to_ascii_buffer())
	f.store_32(2)
	f.store_float(RATE)
	f.store_32(COUNT)
	f.store_32(POINTS)
	f.store_32(MW)
	f.store_32(MH)
	f.store_32(CHUNK * int(RATE * 20.0))
	# A cast direction that is neither axis-aligned nor unit-length: a dropped float or swapped pair would
	# still look plausible from (1, 0).
	f.store_float(0.8)
	f.store_float(-0.6)
	f.store_float(0.5)
	for i in COUNT:
		# Samples 7 and 8 are lost, two in a row: the hold-the-nearest rule must reach past more than one.
		var found := 0 if (i == 7 or i == 8) else 1
		f.store_8(found)
		for k in POINTS:
			f.store_float(_expect_x(i, k))
			f.store_float(_expect_y(i, k))
		for k in POINTS:
			f.store_float(1.0 if found == 1 else 0.0)
		for c in MW * MH:
			f.store_8(_expect_cell(i, c))
	f.close()

	var ed: Node = load("res://src/masking/mask_editor.gd").new()
	var s := MaskSession.new()
	s.video_path = "res://masks/_pose_check/video.ogv"
	ed.session = s
	ed._pt_state = "ready"
	ed._pose._pt_load_chunk(CHUNK, path)
	var loaded: bool = ed._pose._pt_chunks.has(CHUNK)
	print("loaded=%s count=%d points=%d rate=%.1f mask=%dx%d dir=(%.3f, %.3f) w=%.2f"
		% [str(loaded), (int(ed._pose._pt_chunks[CHUNK]["count"]) if loaded else -1),
			ed._pose._pt_points, ed._pose._pt_rate, ed._pose._pt_mw, ed._pose._pt_mh,
			ed._pt_dir.x, ed._pt_dir.y, ed._pose._pt_conf])
	_expect(loaded, "the reader rejected a well-formed window")
	if not loaded:
		quit(1)
		return
	_expect(int(ed._pose._pt_chunks[CHUNK]["count"]) == COUNT,
		"count read as %d, wrote %d" % [int(ed._pose._pt_chunks[CHUNK]["count"]), COUNT])
	_expect(ed._pose._pt_points == POINTS, "points read as %d, wrote %d" % [ed._pose._pt_points, POINTS])
	_expect(ed._pose._pt_mw == MW and ed._pose._pt_mh == MH,
		"mask read as %dx%d, wrote %dx%d" % [ed._pose._pt_mw, ed._pose._pt_mh, MW, MH])
	# The direction is stored raw and normalized on read: the angle survives and the length is 1.
	_expect(absf(ed._pt_dir.length() - 1.0) < 1e-4,
		"cast direction came back length %.4f, expected 1" % ed._pt_dir.length())
	_expect(absf(ed._pt_dir.x - 0.8) < 0.01 and absf(ed._pt_dir.y + 0.6) < 0.01,
		"cast direction came back (%.3f, %.3f), expected (0.8, -0.6)"
			% [ed._pt_dir.x, ed._pt_dir.y])
	_expect(absf(ed._pose._pt_conf - 0.5) < 1e-4,
		"the accumulated direction weight came back %.3f, expected this window's 0.5"
			% ed._pose._pt_conf)

	# Landmarks round-trip at their own sample, with no smoothing (blending two silhouettes would give a
	# ghost two outlines), so this is an exact equality and a stride error names itself.
	for probe in [0, 1, 11, 23]:
		var p: Vector2 = ed._pose.point(base + probe, 5)
		_expect(absf(p.x - _expect_x(probe, 5)) < 1e-5
				and absf(p.y - _expect_y(probe, 5)) < 1e-5,
			"landmark 5 of sample %d read (%.5f, %.5f), wrote (%.5f, %.5f)"
				% [probe, p.x, p.y, _expect_x(probe, 5), _expect_y(probe, 5)])
	var last: Vector2 = ed._pose.point(base + COUNT - 1, POINTS - 1)
	_expect(absf(last.x - _expect_x(COUNT - 1, POINTS - 1)) < 1e-5,
		"the LAST landmark of the LAST sample read %.5f - a stride error shows here first"
			% last.x)
	# ...and a sample in a window that is not loaded reads as absent.
	_expect(not ed._pose._pt_found_at(0), "a sample outside the loaded window read as present")
	_expect(not ed._pose._pt_found_at(base + COUNT + 3),
		"a sample past this window's own count read as present")

	# The silhouette is what a stride error destroys most visibly and has no landmark to cross-check it.
	# Sampled at cells whose value is a function of (sample, cell), so a shift of one byte, row or sample
	# is a different number.
	for probe in [0, 3, 23]:
		var mask: PackedByteArray = ed._pose._pt_chunks[CHUNK]["mask"]
		for cell in [0, 1, MW, MW * MH - 1]:
			var got: int = mask[probe * MW * MH + cell]
			_expect(got == _expect_cell(probe, cell),
				"mask cell %d of sample %d read %d, wrote %d"
					% [cell, probe, got, _expect_cell(probe, cell)])

	# Lost samples are held, not drawn: a body that vanishes for a frame is worse than one sample stale.
	var at7: int = ed._pose.slot_at(float(base + 7) / RATE)
	_expect(at7 == base + 6 or at7 == base + 9,
		"a lost sample resolved to %d, expected the nearest found one" % at7)
	_expect(ed._pose.slot_at(float(base + 3) / RATE) == base + 3,
		"a found sample did not resolve to itself")
	# ...and a time with no window loaded under it says so.
	_expect(ed._pose.slot_at(-5.0) == -1, "a time before the clip returned a sample")
	_expect(ed._pose.slot_at(1e5) == -1, "a time with no loaded window returned a sample")

	# A truncated track is rejected and deleted, so the next open rebuilds it.
	var short := path.get_basename() + "_short.bin"
	var raw := FileAccess.get_file_as_bytes(path)
	var g := FileAccess.open(short, FileAccess.WRITE)
	g.store_buffer(raw.slice(0, raw.size() - 900))
	g.close()
	var ed2: Node = load("res://src/masking/mask_editor.gd").new()
	ed2.session = s
	ed2._pt_state = "ready"
	ed2._pose._pt_load_chunk(CHUNK, short)
	_expect(not ed2._pose._pt_chunks.has(CHUNK), "a truncated window loaded anyway")
	_expect(not FileAccess.file_exists(short), "a truncated window was left on disk")

	# A window that misstates where it starts is discarded: the file is the right length and every field
	# parses, so nothing else in the reader catches it.
	var wrong := path.get_basename() + "_wrong.bin"
	DirAccess.copy_absolute(path, wrong)
	ed2._pose._pt_load_chunk(CHUNK + 1, wrong)
	_expect(not ed2._pose._pt_chunks.has(CHUNK + 1),
		"a window claiming the wrong start index was accepted")

	ed.free()
	ed2.free()
	DirAccess.remove_absolute(path)

	print("")
	if _fails.is_empty():
		print("pose_track_check: PASS - a window round-trips, holds through a gap, ",
			"and refuses what it should.")
		quit(0)
	else:
		for x in _fails:
			print("pose_track_check: FAIL - ", x)
		quit(1)


## Distinct per (sample, landmark) so a misread is identifiable, and small enough to stay in 0..1.
static func _expect_x(i: int, k: int) -> float:
	return 0.10 + 0.004 * float(i) + 0.0008 * float(k)


static func _expect_y(i: int, k: int) -> float:
	return 0.30 + 0.003 * float(i) + 0.0005 * float(k)


## Distinct per (sample, cell), so a shift by one cell, row or sample lands on a different value.
static func _expect_cell(i: int, c: int) -> int:
	return (i * 37 + c * 7) % 251


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
