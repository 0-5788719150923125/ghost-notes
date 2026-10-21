extends RefCounted
class_name MaskPoseTrack

## MaskPoseTrack - her silhouette and her skeleton, read by time: Masking's pose track, a part of
## [MaskEditor]. It bootstraps the offline pre-pass (`hosts/face/pose_track.py`), runs it one
## window at a time, and answers what the track says at a moment: where a joint is
## ([method point]), whether it is seen ([method vis_at]), which uploaded window holds it
## ([method slot_at]), and the mask texture for the shader ([method upload_mask]).
##
## WHAT IT IS HANDED is written out: every `editor.` below is something it reads of the editor
## (the session, the player, the shared state of the install, the status line).
##
## What the umbra's whole shape comes from. See hosts/face/pose_track.py for the
## pre-pass and the file format; this half bootstraps it, runs it, and reads it.
##
## It shares the CLOWN'S VENV rather than building a second one: mediapipe is the
## same package and it is 100 MB. Only the model file differs, so a session that has
## already tracked a face pays nothing but the 9 MB pose bundle.
##
## The look-ahead is the reason this is offline and not a live detector. A ghost that
## moves a beat BEFORE she does reads as a puppeteer; one that follows reads as a
## shadow. No live tracker can supply the first, at any amount of smoothing, because
## the frame it would need has not been decoded yet.
##
## WHY IT IS CHUNKED. The pre-pass runs at about real time, so reading a ten-minute
## clip up front is ten minutes of an effect that draws nothing - which is what the
## author saw, and it is the wrong shape for a tool you place a marker in and expect
## to see. The clip is cut into POSE_CHUNK_SECS windows on ONE GLOBAL SAMPLE GRID
## (pose_track.py writes each chunk's starting index into its header, so two chunks
## written by two runs butt together exactly), the editor asks only for the window
## the playhead is in and the one after it, and it evicts windows it has walked
## away from. So an umbra layer starts drawing about twenty seconds after it is
## placed, wherever in the clip that is, and scrubbing somewhere new costs the same
## twenty seconds rather than a re-read of everything before it.
##
## Two independent state machines, deliberately separated. `_pt_state` is about the
## VENV AND THE MODEL - a one-off install that either works or does not - and it
## runs the `_ft_*` half's shape because it is the same problem. The WINDOWS are a
## pump: the playhead names which ones are wanted, and one child at a time reads
## them, so nothing here is ever "waiting for the clip to finish".

## The [MaskEditor] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var editor: MaskEditor

const POSE_TRACK_DIR := "user://pose_tracks"
const POSE_TRACK_RATE := 12.0    # samples/sec - must match what pose_track.py wrote
const POSE_TRACK_POINTS := 33
## 4 magic + u32 version + f32 rate + u32 count + u32 points + u32 mask_w + u32 mask_h
## + u32 start + f32 dir_x + f32 dir_y + f32 conf. The face track's own header was
## read four bytes short once and every sample after it returned plausible, entirely
## wrong numbers - hence tests/masking/pose_track_check.gd, which reads a hand-built file
## through this reader.
const POSE_TRACK_HEADER := 44
## How much clip one window covers. TWENTY SECONDS IS THE CAST DIRECTION'S FLOOR,
## not a guess at a pleasant latency: the throw is measured from how the background
## VARIES as she moves, and measured on the reference clip that reads conf 0.97 over
## the whole ten minutes, 0.45 over twenty seconds and 0.06 over six - which is
## below the floor at which the editor will believe it at all. A shorter window
## would start faster and know nothing about the light.
const POSE_CHUNK_SECS := 20.0
## How many windows stay in memory. Each is ~1.3 MB at 96x54, and the reason to
## bound it at all is a long clip scrubbed end to end: without eviction every window
## ever visited stays resident.
const POSE_CHUNK_KEEP := 4
var _pt_log := ""
var _pt_rate := POSE_TRACK_RATE
var _pt_points := POSE_TRACK_POINTS
var _pt_mw := 96
var _pt_mh := 54
var _pt_dir_acc := Vector2.ZERO
var _pt_dir_w := 0.0
var _pt_conf := 0.0
## Loaded windows, keyed by index: {count, found, xy, vis, mask}. Sample numbering is
## GLOBAL - window k holds samples [k * _pt_chunk_n, ...) - so a sample index means
## the same thing whichever window produced it.
var _pt_chunks := {}
var _pt_chunk_n := int(POSE_CHUNK_SECS * POSE_TRACK_RATE)
## The window being read right now, and the ones already known to be missing so the
## per-frame pump does not stat the same absent file every frame.
var _pt_job := -1          # chunk index, or -1
var _pt_job_pid := -1
var _pt_progress_ms := 0
var _pt_missing := {}
## How many windows the clip has at all - so the pump never asks for one past the
## end and then waits forever for a file that cannot exist.
var _pt_chunk_total := 0
var _pt_img: Image = null
var _pt_bytes := PackedByteArray()
## The silhouette grid. 160x90 rather than 96x54: a cell is 12 px of a 1080p
## frame instead of 20, which is what lets the shader's grid-dissolving jitter
## come down from +-34 px (a visibly crawling outline) to +-10. It costs 2.8x the
## cache - 3.5 MB a twenty-second window - and the grid is in the window
## FILENAME, so raising it does not read stale coarse windows, it asks for finer
## ones and the old files are simply never opened again.
const _UMB_W := 160
const _UMB_H := 90

# --- the pose track: bootstrap, then one window at a time -------------------------------------

func _pt_model_path() -> String:
	return Provision.file_path("pose_model")


func _pt_dir_path() -> String:
	return ProjectSettings.globalize_path(POSE_TRACK_DIR)


## Where window `k` of THIS clip lives. Keyed by the clip and by the sample grid,
## so changing the rate or the grid cannot silently read windows written under the
## old one.
func _pt_chunk_path(k: int) -> String:
	return _pt_dir_path().path_join("%d_%dx%d_%02d.bin"
		% [hash(editor.session.video_path), _UMB_W, _UMB_H, k])


## Called every frame while an umbra layer is live. Bootstraps once, then pumps
## the window the playhead needs. Every branch is a cheap no-op in the steady
## state.
func ensure() -> void:
	if editor._pt_state == "failed" or editor.session == null or editor.session.video_path.is_empty():
		return
	if editor._pt_state != "ready":
		# Before ANY step, not just the windows: the tracker logs here, and an empty path
		# makes its redirect fail so the step never runs at all.
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
	# SAY SO rather than drawing nothing and letting the author wonder. The umbra
	# has no fallback at all - its whole shape is the track - so silence here is
	# indistinguishable from the effect being switched off.
	editor._set_status("⚠  The umbra can't see the body - " + why)


## stdout+stderr to one file, like [method _ft_spawn_logged].
##
## THE WINDOWS RUN AT THE LOWEST PRIORITY THE OS HANDS OUT, and pose_track.py lowers itself
## (`--background`: nice 19, or IDLE_PRIORITY_CLASS on Windows) before it loads anything.
## WHY, and it is not tidiness: mediapipe saturates every core it is given, and
## ghost's video decode and the editor's own frame both run on this machine's
## other ones. Starve the decode and `_player.stream_position` stops advancing;
## the A/V rule in `_process` then sees audio ahead of video, HOLDS the audio
## (see the long note there), and the hold cannot release while the starvation
## continues. Reported as "the sound no longer works in masking mode... it's
## breaking the audio at launch" - and nothing had touched the audio at all. A
## background job that can stall the foreground is a background job in name only.
func _pt_spawn_logged(exe: String, args: PackedStringArray) -> int:
	return Subprocess.start_logged(exe, args, _pt_log, "pose track")


## THE PUMP. Which windows are wanted is a pure function of the playhead: the one
## it is in, and the one after it (playback walks forward, and Lead already reads
## past the current frame). Anything already on disk is loaded; the nearest thing
## missing is read; everything far away is dropped.
func _pt_pump() -> void:
	if editor._player == null:
		return
	var t := editor._player.stream_position + clampf(editor._umb_lead, 0.0, 2.0)
	var here := clampi(int(floor(t / POSE_CHUNK_SECS)), 0, maxi(0, _pt_chunk_total - 1))
	var want: Array[int] = [here]
	# The guard reads the playhead itself, which is a different window from the
	# lead's whenever the playhead sits within Lead of a boundary.
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

	# EVICT WHAT WE HAVE WALKED AWAY FROM. Each window is ~1.3 MB and a long clip
	# scrubbed end to end would otherwise keep every one ever visited.
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


## Progress for the window being read, reported as the window's own progress -
## "34% of the whole clip" was the old message and it was true and useless, because
## the thing the author is waiting for is twenty seconds of it.
func _pt_poll_job(here: int) -> void:
	if _pt_job < 0:
		return
	if Subprocess.alive(_pt_job_pid):
		# Four times a second, not sixty. The child writes this once a second, so a
		# read per frame is fifteen file opens for every value that changes - on
		# the main thread, in a loop this file has already had to make quiet once.
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
		# NOT if it is already resident. The pump's own "is it on disk yet" branch
		# can reach the file in the same frame the child finishes, and loading it
		# twice DOUBLE-COUNTS its confidence into the accumulated cast direction -
		# measured, window 0 alone took the weight from 0.90 to 1.80, which would
		# have quietly outvoted every window read after it.
		if not _pt_chunks.has(done):
			_pt_load_chunk(done, path)
		editor._set_status("✓  The umbra can see her here")
	else:
		# REMEMBER THE FAILURE, or the pump re-runs the same doomed child every
		# frame for the rest of the session. A window with no pose in it at all
		# (a title card, a cutaway) is a legitimate outcome and lands here too.
		_pt_missing[done] = true
		if done == here:
			editor._set_status("⚠  No body found around " + _clock(float(done) * POSE_CHUNK_SECS))


func _pt_start_chunk(k: int) -> void:
	var script := BundledHosts.path("res://hosts/face/pose_track.py")
	if not FileAccess.file_exists(script):
		_pt_fail("hosts/face/pose_track.py is missing")
		return
	# The ORIGINAL source where we still have it, for the same reason the face
	# track prefers it: the prepared .ogv is theora q6 and its chroma blocks are
	# exactly what a segmentation model has to see past.
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


## Read one window. Rejects and DELETES anything that is not exactly the file this
## reader expects, so a stale grid or a half-written chunk is rebuilt rather than
## read as plausible nonsense.
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
	# THE HEADER'S OWN START INDEX IS THE AUTHORITY, not the filename. A window
	# whose samples do not sit where this reader thinks they do would put the ghost
	# on the wrong frame, silently, which is the whole failure class the format
	# check exists for.
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
	# APPENDED IN WHOLE BUFFERS, never cell by cell. A window is 240 samples of
	# 5184 mask cells, and a GDScript loop that copies one byte at a time is over a
	# million interpreted iterations per window - a visible hitch on a file that
	# reads off the disk in a fraction of one.
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
	# The throw, accumulated. One window measures it poorly (measured on the
	# reference clip: conf 0.97 over ten minutes, 0.45 over twenty seconds, 0.06
	# over six); weighting by each window's own confidence means a dozen of them
	# converge on the right answer while a window that measured nothing adds
	# nothing rather than dragging it toward its noise.
	var d := Vector2(dx, dy)
	if conf > 0.0 and d.length() > 1e-4:
		_pt_dir_acc += d.normalized() * conf
		_pt_dir_w += conf
	_pt_conf = _pt_dir_w
	editor._pt_dir = _pt_dir_acc.normalized() if _pt_dir_w > 0.12 else Vector2(1.0, 0.0)
	print("ghost pose: window %d ready - %d samples, body in %d, cast (%.2f, %.2f) w %.2f"
		% [k, count, found_n, editor._pt_dir.x, editor._pt_dir.y, _pt_dir_w])


## Is there a usable sample at clip time `t`, and which one? GLOBAL sample index,
## or -1. Deliberately the NEAREST sample and not an interpolation: the silhouette
## is a bitmap and cross-fading two of them makes a ghost with two outlines.
## Position smoothness comes from the field sim, which advects at frame rate over
## whatever the deposit does at 12 Hz.
func slot_at(t: float) -> int:
	if editor._pt_state != "ready" or _pt_chunk_n <= 0:
		return -1
	var i := maxi(0, int(round(t * _pt_rate)))
	if _pt_found_at(i):
		return i
	# Hold the nearest real sample rather than dropping the ghost for one frame -
	# a body that blinks out on a missed detection is a worse artifact than a body
	# a twelfth of a second stale. Bounded to within this window, because reaching
	# into one that is not loaded is how a hold becomes a jump across a gap.
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


## ...and how much the model believes it. MediaPipe reports a landmark it cannot
## see - one off the bottom of a half-body framing, or an ear behind a turned
## head - with a plausible EXTRAPOLATED position and a visibility near zero, so
## the coordinate alone never says "no". Measured on the reference clip: the hips
## come back at y = 1.37 (below the picture) on every sample, at visibility 0.00.
func vis_at(i: int, idx: int) -> float:
	var c := _pt_chunk_of(i)
	if c.is_empty():
		return 0.0
	var vis: PackedFloat32Array = c["vis"]
	return vis[(i - (i / _pt_chunk_n) * _pt_chunk_n) * _pt_points + idx]


## Upload global sample `i`'s silhouette as the field sim's source texture.
##
## R and B are the SAME mask at two dilations, and that is the whole channel
## design: R is the body the throw magnifies, B is the guard read at plain screen
## uv, and the guard is grown a cell so its exclusion starts BEFORE her outline
## rather than at it. Erring outward is the safe direction - the one property this
## effect may never trade away is staying off her.
## THE TWO CHANNELS COME FROM TWO DIFFERENT MOMENTS, and that is the whole point.
## The BODY is her silhouette at `t + Lead` - the ghost is ahead of her, which is
## the effect. The GUARD is her silhouette NOW, because the guard's job is to keep
## the ghost off the woman who is on screen, and she is on screen at `t`.
##
## Uploading one sample for both is what produced the reported artifact: with Lead
## wound up, a moving hand cut a hand-shaped hole in the ghost a third of a second
## AHEAD of the hand, and left the real hand uncovered - a hard-edged gap sliding
## through the mass with nothing where it had been.
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
	# A CENTERED THREE-TAP OVER TIME, and centered is the point. The segmentation
	# wobbles a cell or two per sample and the track runs at 12 Hz, so the raw
	# outline both shimmers and STEPS - which is most of "the edges are very
	# jittery and unstable". An EMA would fix the shimmer and buy it with lag,
	# which on this effect is the one thing that must not be spent: the Lead is
	# the whole point. Because the track is fitted OFFLINE the future is already
	# on disk, so the neighbor on each side can be weighted equally - zero phase,
	# the mask arrives no later than it did, and the wobble is gone. Same argument
	# as the face track's `_ft_point` smoothing, one dimension up.
	# Offsets of the two neighbors INSIDE THIS WINDOW's own array. A neighbor on
	# the far side of a window boundary is simply absent (-1) rather than reached
	# for: the next window may not be resident, and a half-loaded blend is worse
	# than none.
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
			# A REAL ONE-CELL MAX DILATION, not a gain on the same value. Scaling
			# the coverage up only widens the guard across the mask's own soft
			# rim, which is a cell at most and nothing at all where the rim is
			# hard - and "hard" is exactly the case (a crisp shoulder against a
			# plain wall) where the ghost would otherwise be allowed to touch her.
			# A cell of this grid is ~20 px of a 1080p frame, so this costs a
			# hairline of unpainted wall around her and buys the one property the
			# effect may never trade away.
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
			# 0.25 / 0.50 / 0.25. A missing neighbor (the window's own ends) falls
			# back to this sample rather than to zero, which would pull the whole
			# outline inward for two samples either side of every window boundary.
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
