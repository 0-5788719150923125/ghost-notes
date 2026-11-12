extends RefCounted
class_name MaskPoseTrack

## MaskPoseTrack - the subject's silhouette and skeleton, read by time: Masking's pose track, a part of [MaskEditor].
## It bootstraps the offline pre-pass (`hosts/face/pose_track.py`, which has the file format), runs it one window at a
## time, and answers what the track says at a moment: where a joint is ([method point]), whether it is seen
## ([method vis_at]), which loaded window holds it ([method slot_at]), and the mask texture for the shader
## ([method upload_mask]). The umbra's whole shape comes from it.
##
## It shares the clown's venv (the mediapipe package is the same; only the model file differs).
##
## The pre-pass is offline so the track can look ahead: a ghost that moves a beat before the subject reads as a
## puppeteer, one that follows as a shadow, and no live tracker has the frame it would need.
##
## Chunked: the pre-pass runs at about real time, so the clip is cut into POSE_CHUNK_SECS windows on one global sample
## grid (pose_track.py writes each chunk's starting index in its header, so chunks from separate runs butt together).
## The editor asks only for the window the playhead is in and the next, and evicts windows it has left.
##
## Two state machines: `_pt_state` is the one-off install of the venv and model (shaped like the `_ft_*` half); the
## windows are a pump - the playhead names the wanted ones and one child at a time reads them.

## The [MaskEditor] this is a part of: everything read through it is something this part is handed.
var editor: MaskEditor

const POSE_TRACK_DIR := "user://pose_tracks"
const POSE_TRACK_RATE := 12.0    # samples/sec - must match what pose_track.py wrote
const POSE_TRACK_POINTS := 33
## 4 magic + u32 version + f32 rate + u32 count + u32 points + u32 mask_w + u32 mask_h + u32 start + f32 dir_x +
## f32 dir_y + f32 conf. tests/masking/pose_track_check.gd reads a hand-built file through this reader.
const POSE_TRACK_HEADER := 44
## How much clip one window covers. 20 s is the cast direction's floor: the throw is measured from how the background
## varies as the subject moves, and on the reference clip confidence is 0.97 over ten minutes, 0.45 over 20 s and 0.06
## over 6 s (below what the editor will believe).
const POSE_CHUNK_SECS := 20.0
## How many windows stay in memory (~1.3 MB each at 96x54); bounds a long clip scrubbed end to end.
const POSE_CHUNK_KEEP := 4
var _pt_log := ""
var _pt_rate := POSE_TRACK_RATE
var _pt_points := POSE_TRACK_POINTS
var _pt_mw := 96
var _pt_mh := 54
var _pt_dir_acc := Vector2.ZERO
var _pt_dir_w := 0.0
var _pt_conf := 0.0
## Loaded windows by index: {count, found, xy, vis, mask}. Sample numbering is global (window k holds samples
## [k * _pt_chunk_n, ...)).
var _pt_chunks := {}
var _pt_chunk_n := int(POSE_CHUNK_SECS * POSE_TRACK_RATE)
## The window being read, and the ones known to be missing (so the pump does not stat an absent file every frame).
var _pt_job := -1          # chunk index, or -1
var _pt_job_pid := -1
var _pt_progress_ms := 0
var _pt_missing := {}
## How many windows the clip has, so the pump never waits for a file that cannot exist.
var _pt_chunk_total := 0
var _pt_img: Image = null
var _pt_bytes := PackedByteArray()
## The silhouette grid: a cell is 12 px of a 1080p frame, which brings the shader's grid-dissolving jitter to +-10 px
## (96x54 gave +-34). A 20 s window is 3.5 MB. The grid is in the window filename, so a change asks for new windows.
const _UMB_W := 160
const _UMB_H := 90

# --- the pose track: bootstrap, then one window at a time -------------------------------------

func _pt_model_path() -> String:
	return Provision.file_path("pose_model")


func _pt_dir_path() -> String:
	return ProjectSettings.globalize_path(POSE_TRACK_DIR)


## Where window `k` of this clip lives, keyed by the clip and the sample grid so a changed rate or grid never reads
## old windows.
func _pt_chunk_path(k: int) -> String:
	return _pt_dir_path().path_join("%d_%dx%d_%02d.bin"
		% [hash(editor.session.video_path), _UMB_W, _UMB_H, k])


## Called every frame while an umbra layer is live: bootstraps once, then pumps the window the playhead needs; a
## cheap no-op in the steady state.
func ensure() -> void:
	if editor._pt_state == "failed" or editor.session == null or editor.session.video_path.is_empty():
		return
	if editor._pt_state != "ready":
		# Before any step: the tracker logs here, and an empty path makes its redirect fail.
		DirAccess.make_dir_recursive_absolute(_pt_dir_path())
		_pt_log = _pt_dir_path().path_join("last_run.log")
		var why := Provision.unsupported(MaskEditor.FACE_ENV)
		if not why.is_empty():
			_pt_fail("not available on this machine: " + why)
			return
		if not Provision.ensure(MaskEditor.FACE_ENV):
			editor._pt_state = "provisioning"
			var s := Provision.state(MaskEditor.FACE_ENV)
			if not bool(s.get("running", false)) and (s.has("error") or not Provision.can_install()):
				_pt_fail(String(s.get("error", Provision.hint(MaskEditor.FACE_ENV))))
			else:
				editor._set_status("⏳  Preparing the pose tracker - " + Provision.describe(MaskEditor.FACE_ENV, s))
			return
		Provision.hold(MaskEditor.FACE_ENV, "mask editor")
		_pt_chunk_n = int(POSE_CHUNK_SECS * POSE_TRACK_RATE)
		_pt_chunk_total = maxi(1, int(ceil(editor.session.duration / POSE_CHUNK_SECS)))
		editor._pt_state = "ready"
	_pt_pump()


func _pt_fail(why: String) -> void:
	editor._pt_state = "failed"
	push_warning("ghost pose: " + why)
	# Say so: the umbra has no fallback (its shape is the track), so silence reads as the effect being off.
	editor._set_status("⚠  The umbra can't see the body - " + why)


## stdout+stderr to one file, like [method _ft_spawn_logged]. The windows run at the lowest priority the OS has, and
## pose_track.py lowers itself (`--background`: nice 19, IDLE_PRIORITY_CLASS on Windows) before loading anything:
## mediapipe saturates every core it is given, and starving the video decode stops `_player.stream_position`, so the
## A/V rule in `_process` holds the audio and cannot release.
func _pt_spawn_logged(exe: String, args: PackedStringArray) -> int:
	return Subprocess.start_logged(exe, args, _pt_log, "pose track")


## The pump. The wanted windows are a pure function of the playhead: the one it is in and the next. Anything on disk
## is loaded; the nearest missing one is read; everything far away is dropped.
func _pt_pump() -> void:
	if editor._player == null:
		return
	var t := editor._player.stream_position + clampf(editor._umb_lead, 0.0, 2.0)
	var here := clampi(int(floor(t / POSE_CHUNK_SECS)), 0, maxi(0, _pt_chunk_total - 1))
	var want: Array[int] = [here]
	# The guard reads the playhead itself, a different window from the lead's near a boundary.
	var guard_k := clampi(int(floor(editor._player.stream_position / POSE_CHUNK_SECS)),
		0, maxi(0, _pt_chunk_total - 1))
	if guard_k != here:
		want.append(guard_k)
	if here + 1 < _pt_chunk_total:
		want.append(here + 1)

	_pt_poll_job(here)

	for k in want:
		if _pt_chunks.has(k):
			continue
		var path := _pt_chunk_path(k)
		if FileAccess.file_exists(path):
			_pt_load_chunk(k, path)
		elif _pt_job < 0 and not _pt_missing.has(k):
			_pt_start_chunk(k)
			break   # one child at a time: two of these compete for the same cores

	# Evict windows walked away from.
	if _pt_chunks.size() > POSE_CHUNK_KEEP:
		var far := -1
		var far_d := -1
		for k in _pt_chunks:
			var d: int = absi(int(k) - here)
			if d > far_d:
				far_d = d
				far = int(k)
		if far >= 0 and far_d > 1:
			_pt_chunks.erase(far)


## Progress for the window being read, reported as the window's own progress.
func _pt_poll_job(here: int) -> void:
	if _pt_job < 0:
		return
	if Subprocess.alive(_pt_job_pid):
		# Four times a second: the child writes once a second, and this is the main thread.
		var now := Time.get_ticks_msec()
		if now - _pt_progress_ms < 250:
			return
		_pt_progress_ms = now
		var pf := _pt_dir_path().path_join("progress")
		var frac := 0.0
		if FileAccess.file_exists(pf):
			var f := FileAccess.open(pf, FileAccess.READ)
			if f != null:
				frac = f.get_as_text().strip_edges().to_float()
		editor._set_status("⏳  Reading the body around %s…  %d%%"
			% [_clock(float(_pt_job) * POSE_CHUNK_SECS), int(clampf(frac, 0.0, 1.0) * 100.0)])
		return
	_pt_job_pid = -1
	var done := _pt_job
	_pt_job = -1
	var path := _pt_chunk_path(done)
	if FileAccess.file_exists(path):
		# Not if already resident: the pump's "is it on disk" branch can reach the file the frame the child finishes, and
		# a second load double-counts its confidence into the accumulated cast direction.
		if not _pt_chunks.has(done):
			_pt_load_chunk(done, path)
		editor._set_status("✓  The umbra can see her here")
	else:
		# Remember the failure so the pump does not rerun the same child every frame. A window with no pose in it
		# (a title card, a cutaway) lands here too.
		_pt_missing[done] = true
		if done == here:
			editor._set_status("⚠  No body found around " + _clock(float(done) * POSE_CHUNK_SECS))


func _pt_start_chunk(k: int) -> void:
	var script := BundledHosts.path("res://hosts/face/pose_track.py")
	if not FileAccess.file_exists(script):
		_pt_fail("hosts/face/pose_track.py is missing")
		return
	# The original source where it exists, as the face track does: the prepared .ogv is theora q6, whose chroma
	# blocks a segmentation model has to see past.
	var src := editor.session.source_path
	if src.is_empty() or not FileAccess.file_exists(src):
		src = ProjectSettings.globalize_path(editor.session.video_path)
	_pt_job_pid = _pt_spawn_logged(editor._face.bin_path("python"), PackedStringArray([
		script, "--video", src, "--out", _pt_chunk_path(k), "--model", _pt_model_path(),
		"--rate", str(POSE_TRACK_RATE), "--mask-w", str(_UMB_W), "--mask-h", str(_UMB_H),
		"--start", str(float(k) * POSE_CHUNK_SECS), "--duration", str(POSE_CHUNK_SECS),
		"--progress", _pt_dir_path().path_join("progress"), "--background"]))
	if _pt_job_pid <= 0:
		_pt_missing[k] = true
		_pt_fail("could not start the pose tracker")
		return
	_pt_job = k
	print("ghost pose: reading window %d (%s)" % [k, _clock(float(k) * POSE_CHUNK_SECS)])


func _clock(secs: float) -> String:
	return Clock.text(secs)


## Read one window. Rejects and deletes anything that is not exactly the file this reader expects, so a stale grid
## or half-written chunk is rebuilt.
func _pt_load_chunk(k: int, path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_pt_missing[k] = true
		return
	if f.get_buffer(4).get_string_from_ascii() != "GST2":
		f.close()
		DirAccess.remove_absolute(path)
		return
	var _version := f.get_32()
	var rate := f.get_float()
	var count := f.get_32()
	var points := f.get_32()
	var mw := f.get_32()
	var mh := f.get_32()
	var start := f.get_32()
	var dx := f.get_float()
	var dy := f.get_float()
	var conf := f.get_float()
	var cells := mw * mh
	var stride := 1 + points * 8 + points * 4 + cells
	if count <= 0 or points <= 0 or cells <= 0 \
			or f.get_length() != POSE_TRACK_HEADER + count * stride:
		f.close()
		DirAccess.remove_absolute(path)
		_pt_missing[k] = true
		push_warning("ghost pose: window %d was truncated - it will be read again" % k)
		return
	# The header's own start index is the authority, not the filename: a misplaced window would put the ghost on the
	# wrong frame.
	if start != k * int(rate * POSE_CHUNK_SECS):
		f.close()
		DirAccess.remove_absolute(path)
		_pt_missing[k] = true
		push_warning("ghost pose: window %d starts at sample %d, expected %d - discarded"
			% [k, start, k * int(rate * POSE_CHUNK_SECS)])
		return
	_pt_rate = rate
	_pt_points = points
	_pt_mw = mw
	_pt_mh = mh
	_pt_chunk_n = int(rate * POSE_CHUNK_SECS)
	var found := PackedByteArray()
	var xy := PackedFloat32Array()
	var vis := PackedFloat32Array()
	var mask := PackedByteArray()
	found.resize(count)
	# Appended in whole buffers, never cell by cell (a window is 240 samples of 5184 cells: over a million interpreted
	# iterations).
	var found_n := 0
	for i in count:
		found[i] = f.get_8()
		found_n += found[i]
		xy.append_array(f.get_buffer(points * 8).to_float32_array())
		vis.append_array(f.get_buffer(points * 4).to_float32_array())
		mask.append_array(f.get_buffer(cells))
	f.close()
	_pt_chunks[k] = {"count": count, "found": found, "xy": xy, "vis": vis, "mask": mask}
	editor._pt_slot = -1
	# The throw, accumulated. One window measures it poorly (conf 0.97 over ten minutes, 0.45 over 20 s, 0.06 over 6 s);
	# weighting by each window's confidence lets a dozen converge while a window that measured nothing adds nothing.
	var d := Vector2(dx, dy)
	if conf > 0.0 and d.length() > 1e-4:
		_pt_dir_acc += d.normalized() * conf
		_pt_dir_w += conf
	_pt_conf = _pt_dir_w
	editor._pt_dir = _pt_dir_acc.normalized() if _pt_dir_w > 0.12 else Vector2(1.0, 0.0)
	print("ghost pose: window %d ready - %d samples, body in %d, cast (%.2f, %.2f) w %.2f"
		% [k, count, found_n, editor._pt_dir.x, editor._pt_dir.y, _pt_dir_w])


## Is there a usable sample at clip time `t`, and which? A global sample index, or -1. The nearest sample, not an
## interpolation: the silhouette is a bitmap, and cross-fading two makes two outlines. Smoothness comes from the field
## sim, which advects at frame rate over the 12 Hz deposit.
func slot_at(t: float) -> int:
	if editor._pt_state != "ready" or _pt_chunk_n <= 0:
		return -1
	var i := maxi(0, int(round(t * _pt_rate)))
	if _pt_found_at(i):
		return i
	# Hold the nearest real sample rather than drop the ghost for a frame, bounded to this window (reaching into one
	# not loaded turns a hold into a jump).
	for k in range(1, 8):
		if i - k >= 0 and _pt_found_at(i - k):
			return i - k
		if _pt_found_at(i + k):
			return i + k
	return -1


## Global sample index -> the window holding it, or an empty Dictionary.
func _pt_chunk_of(i: int) -> Dictionary:
	if _pt_chunk_n <= 0:
		return {}
	var k := i / _pt_chunk_n
	var c = _pt_chunks.get(k, null)
	if c == null:
		return {}
	if i - k * _pt_chunk_n >= int(c["count"]):
		return {}
	return c


func _pt_found_at(i: int) -> bool:
	if i < 0:
		return false
	var c := _pt_chunk_of(i)
	if c.is_empty():
		return false
	return c["found"][i - (i / _pt_chunk_n) * _pt_chunk_n] != 0


## Landmark `idx` of global sample `i`, in frame UV.
func point(i: int, idx: int) -> Vector2:
	var c := _pt_chunk_of(i)
	if c.is_empty():
		return Vector2(0.5, 0.5)
	var b := ((i - (i / _pt_chunk_n) * _pt_chunk_n) * _pt_points + idx) * 2
	var xy: PackedFloat32Array = c["xy"]
	return Vector2(xy[b], xy[b + 1])


## ...and how much the model believes it. MediaPipe gives an unseen landmark (below a half-body framing, an ear behind
## a turned head) a plausible extrapolated position with visibility near zero, so the coordinate alone never says no
## (on the reference clip the hips are at y = 1.37 on every sample, at visibility 0.00).
func vis_at(i: int, idx: int) -> float:
	var c := _pt_chunk_of(i)
	if c.is_empty():
		return 0.0
	var vis: PackedFloat32Array = c["vis"]
	return vis[(i - (i / _pt_chunk_n) * _pt_chunk_n) * _pt_points + idx]


## Upload global sample `i`'s silhouette as the field sim's source texture. R and B are the same mask at two
## dilations: R is the body the throw magnifies, B is the guard read at plain screen uv, grown a cell so its exclusion
## starts before the outline (the effect must stay off the subject). The channels come from two moments: the body is
## the silhouette at `t + Lead` (the ghost is ahead of the subject), the guard is the silhouette now (`guard_i`), since
## it keeps the ghost off what is on screen at `t`. One sample for both would cut a hole in the ghost ahead of a
## moving hand and leave the hand uncovered.
func upload_mask(i: int, guard_i: int) -> void:
	var c := _pt_chunk_of(i)
	if c.is_empty():
		return
	var gc := _pt_chunk_of(guard_i)
	if gc.is_empty():
		gc = c            # no sample for now: a stale guard beats no guard
		guard_i = i
	var cells := _pt_mw * _pt_mh
	if _pt_bytes.size() != cells * 4:
		_pt_bytes.resize(cells * 4)
	var src: PackedByteArray = c["mask"]
	var gsrc: PackedByteArray = gc["mask"]
	# A centered three-tap over time. The segmentation wobbles a cell or two per sample at 12 Hz, so the raw outline
	# shimmers and steps. An EMA would add lag, which this effect cannot spend; the track is offline, so the neighbor
	# on each side is weighted equally: zero phase, no wobble (as the face track's `_ft_point` smoothing, one
	# dimension up). The neighbors are offsets inside this window's own array; across a window boundary the neighbor
	# is absent (-1), since the next window may not be resident.
	var local := i - (i / _pt_chunk_n) * _pt_chunk_n
	var last := int(c["count"]) - 1
	var prev_b := (local - 1) * cells if local > 0 else -1
	var next_b := (local + 1) * cells if local < last else -1
	var gbase := (guard_i - (guard_i / _pt_chunk_n) * _pt_chunk_n) * cells
	var base := (i - (i / _pt_chunk_n) * _pt_chunk_n) * cells
	for y in _pt_mh:
		for x in _pt_mw:
			var k := y * _pt_mw + x
			var v := src[base + k]
			# A one-cell max dilation, not a gain: scaling coverage only widens the guard across the mask's soft rim, and
			# nothing where the rim is hard (a crisp shoulder against a plain wall).
			var g := int(gsrc[gbase + k])
			if x > 0:
				g = maxi(g, gsrc[gbase + k - 1])
			if x < _pt_mw - 1:
				g = maxi(g, gsrc[gbase + k + 1])
			if y > 0:
				g = maxi(g, gsrc[gbase + k - _pt_mw])
			if y < _pt_mh - 1:
				g = maxi(g, gsrc[gbase + k + _pt_mw])
			var b4 := k * 4
			# 0.25 / 0.50 / 0.25. A missing neighbor falls back to this sample, not zero (which would pull the outline
			# inward near every window boundary).
			var sm := int(v)
			if prev_b >= 0 or next_b >= 0:
				var a := int(src[prev_b + k]) if prev_b >= 0 else int(v)
				var bnx := int(src[next_b + k]) if next_b >= 0 else int(v)
				sm = (a + int(v) * 2 + bnx) / 4
			_pt_bytes[b4] = sm
			_pt_bytes[b4 + 1] = 0
			_pt_bytes[b4 + 2] = g
			_pt_bytes[b4 + 3] = 255
	if _pt_img == null or _pt_img.get_width() != _pt_mw or _pt_img.get_height() != _pt_mh:
		_pt_img = Image.create_from_data(_pt_mw, _pt_mh, false, Image.FORMAT_RGBA8, _pt_bytes)
		editor._pt_tex = ImageTexture.create_from_image(_pt_img)
	else:
		_pt_img.set_data(_pt_mw, _pt_mh, false, Image.FORMAT_RGBA8, _pt_bytes)
		editor._pt_tex.update(_pt_img)
