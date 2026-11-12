extends Node

## What the eye sees in the comic medium, measured on the output (the sheet's silhouette in screen space, frame to
## frame) rather than on the plan.
##
##   tests/run_boot_probe.sh tests/media/comic_motion_check.gd 400 --seed 2491232026
##
## The seed is pinned (check.sh passes it from the line above): with no audio every run would roll a different show
## and the numbers could not be compared across builds.
##
## comic_camera_check measures the plan and comic_look_probe single frames; the defects here live between frames
## (ComicCamera.place_eye derives rake, scale and distance from step functions of the panel read). Whatever moves
## the picture shows up as screen-space displacement:
##   TELEPORTS  frames whose displacement is a large multiple of the running median. A cut may be one; several in
##              seconds is a defect. Reported with whether the framing panel changed.
##   HELD       the fraction of frames whose displacement is under a stillness threshold, measured on the picture,
##              not on the name of the active move.
##   REVERSALS  sign changes in the rendered scale (the silhouette's area), with the number of held frames
##              separating them.
##
## It also asserts, each with a control that must fail: a second attach on the same seed plays the same camera,
## frame for frame ([method _check_reattach]), and a session's end makes nothing - no scene cast, no viewport left
## running, no pick made through a Director already detached ([method _check_release]).

var _fails: Array = []
## Seconds of camera driven per setting, at FPS: long enough to contain several Director holds at the default
## pacing, short enough to share a machine.
const SECONDS := 90.0
const FPS := 30.0
## The Camera slider settings compared.
const LEVELS := [0.0, 1.0, 2.0]
## A teleport is a spike: one frame displacing at least this much of the frame, with quiet frames either side. The
## bar is absolute because the median is zero when the camera is motionless. 0.04 of the frame in one frame is 1.2
## frame widths per second, which no move travels at; the quiet-neighbor test tells a cut (exactly one large frame)
## from a fast move (many).
const TELEPORT := 0.04
const TELEPORT_QUIET := 0.01
## Held when it moves less than this fraction of the frame's short side per frame.
const STILL := 0.0012
## Frozen: the tighter bar under which the picture is stopped, not just held.
const FROZEN := 0.00004
## Frames the camera must be held for before a change of zoom direction counts as separated.
const HOLD_FRAMES := 15
## How far the rendered scale must travel in one direction (a fraction of the page's on-screen size) before a change
## of direction is a reversal, so float jitter around a static value counts for nothing.
const ZOOM_DEADBAND := 0.02
## The reattach check: frames driven after each attach, and a Director cut every so many of them (enough to reach a
## page turn, at the busy end of the Camera knob).
const REATTACH_FRAMES := 360
const REATTACH_CUT := 40


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(320, 180)
	add_child(stage)
	Director.detach()
	var v: Medium = Medium.make("comic")
	v.mount(stage)
	Director.attach(stage, v)
	var comic: ComicMedium = v as ComicMedium
	_check_pinned(comic)
	var was := Director.camera
	for sev: float in LEVELS:
		Director.set_camera(sev)
		_drive(comic, sev)
	# The book's life, on no footage: an imported clip is warmed a window at a time, so the author's library would
	# make two attaches differ.
	Films.use_for_test([], 0.0)
	Director.set_camera(2.0)
	_check_reattach(stage, comic)
	_check_release(stage, comic)
	Director.set_camera(was)
	Director.detach()
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame
	if _fails.is_empty():
		print("comic_motion_check: ALL OK")
	else:
		for f in _fails:
			print("comic_motion_check: FAIL - %s" % f)
	# End here, once the verdict is printed: the engine's own shutdown after freeing real scenes dies or hangs
	# (tests/run_scene_smoke.sh). A SIGKILL on ourselves, as main._shutdown does, skips it. check.sh reads the
	# verdict from the log, never the exit code.
	OS.kill(OS.get_process_id())


## How much does the picture move with the camera pinned?
##
## The rig is page-local: `place_eye` builds the eye offset in spread space and rotates it by the sheet's attitude,
## so the sheet's drift should leave the projection invariant (the medium states 1.1e-12 px over 60 s). Pins the
## camera and target, runs the drift and measures; anything above the float noise floor means the invariance is lost.
func _check_pinned(comic: ComicMedium) -> void:
	comic._turn_spread(0)
	var dt := 1.0 / FPS
	# Warm up before pinning: `_flat_s` and `_dist_s` are followers, so the first second after a spread turn is them
	# converging, not the page drifting.
	for _w in int(8.0 / dt):
		comic.advance(Spectrum.current, dt, 0.0)
	var pinned: Dictionary = (comic._camera._cam as Dictionary).duplicate()
	# A/B: the same run with the sheet's attitude also frozen. If the motion vanishes it is the page drift; if it
	# survives, something in place_eye is still converging or stepping.
	var worst := 0.0
	var worst_still := 0.0
	var eye_move := 0.0
	for pass_i in 2:
		var att_frozen: Basis = comic._camera.att_basis
		var prev := PackedVector2Array()
		var prev_eye: Vector3 = comic._camera._eye
		for i in int(20.0 / dt):
			comic._camera._cam = pinned.duplicate()
			comic._camera._tgt = pinned.duplicate()
			# The shot must not be holding, or the camera's advance overwrites the pinned target with the hold creep.
			comic._camera._shot["arrived"] = false
			comic.advance(Spectrum.current, dt, 0.0)
			if pass_i == 1:
				comic._camera.att_basis = att_frozen
				comic._camera.place_eye(dt)
			comic._camera.prepare_lens()
			var q := _grid(comic)
			if q.size() == prev.size() and q.size() > 0:
				for k in q.size():
					if pass_i == 0:
						worst = maxf(worst, q[k].distance_to(prev[k]))
					else:
						worst_still = maxf(worst_still, q[k].distance_to(prev[k]))
			if pass_i == 0:
				eye_move = maxf(eye_move, comic._camera._eye.distance_to(prev_eye))
			prev = q
			prev_eye = comic._camera._eye
	print("  camera+target PINNED 20s -> picture moved %.6f of frame per frame (eye moved %.6f world)"
		% [worst, eye_move])
	print("  ...and with the sheet's ATTITUDE frozen too -> %.6f" % worst_still)
	# Printed, not asserted: the residual varies run to run by orders of magnitude, so it is not a stable property.
	# Freezing the sheet's attitude does not remove it, so the rig's invariance is not the cause.


## A second attach on the same seed plays the same camera.
##
## The medium outlives a session (main owns it), so whatever a new book does not put back is inherited: the count
## that seeds every shot, the pose and its target, the walks, the sheet's attitude. Attaches twice, drives the same
## frames and cuts, and compares what the eye sees (the grid nailed to the paper) and the pose behind it.
##
## Two-sided: the same two attaches with the camera's reset skipped ([StuckCamera]) must differ.
func _check_reattach(stage: SubViewport, comic: ComicMedium) -> void:
	var a := _attached_run(stage, comic)
	var b := _attached_run(stage, comic)
	var at := _first_difference(a, b)
	print("  attached twice on seed %d, %d frames, a cut every %d -> %s"
		% [Director.session_seed(), REATTACH_FRAMES, REATTACH_CUT,
			"the same camera" if at < 0 else "a different camera from frame %d" % at])
	if at >= 0:
		_fails.append("a second attach on the same seed played another camera (from frame %d)" % at)
	var keep: ComicCamera = comic._camera
	var stuck := StuckCamera.new()
	stuck.medium = comic
	comic._camera = stuck
	var c := _attached_run(stage, comic)
	var d := _attached_run(stage, comic)
	comic._camera = keep
	var ctl := _first_difference(c, d)
	print("  ...and with the camera's reset skipped -> %s"
		% ("the same camera" if ctl < 0 else "a different camera from frame %d" % ctl))
	if ctl < 0:
		_fails.append("control: a camera never reset played the same show twice - the reattach check sees nothing")


## Attach [param comic] afresh and drive REATTACH_FRAMES frames, the Director cutting every
## REATTACH_CUT: one line a frame of what the eye sees and the pose behind it.
func _attached_run(stage: SubViewport, comic: ComicMedium) -> Array:
	Director.detach()
	Director.attach(stage, comic)
	var dt := 1.0 / FPS
	var out: Array = []
	for i in REATTACH_FRAMES:
		Director._elapsed += dt
		if i > 0 and i % REATTACH_CUT == 0:
			Director._begin_transition()
		comic.advance(Spectrum.current, dt, 0.0)
		out.append(var_to_str([comic._spread_i, comic._read, comic._camera._cam,
			comic._camera._tgt, _grid(comic)]))
	return out


## The first frame two runs disagree on, or -1.
func _first_difference(a: Array, b: Array) -> int:
	for i in mini(a.size(), b.size()):
		if String(a[i]) != String(b[i]):
			return i
	return -1 if a.size() == b.size() else mini(a.size(), b.size())


## A session's end makes nothing.
##
## release() is the teardown (the Director detached) and main calls it twice as a note closes - through
## Director.detach, and again as it clears the stage. It must not turn the spread (that casts a panel at teardown)
## or leave pick state set; a new book is opened by begin_session and nowhere else.
##
## Two-sided: a medium whose release still turns the spread ([LeakyComic]) must be caught.
func _check_release(stage: SubViewport, comic: ComicMedium) -> void:
	var found := _teardown(stage, comic)
	print("  a session torn down as main tears one down -> %s"
		% ("nothing made" if found.is_empty() else "; ".join(found)))
	for f in found:
		_fails.append(f)
	var leaky := LeakyComic.new()
	leaky.key = "comic"
	leaky.mount(stage)
	var ctl := _teardown(stage, leaky)
	print("  ...and a medium whose release turns the spread -> %s"
		% ("nothing made" if ctl.is_empty() else "; ".join(ctl)))
	if ctl.is_empty():
		_fails.append("control: a release that casts a spread passed the teardown check")
	leaky.queue_free()


## Run a short session on [param comic], tear it down as main does, and say what it made.
func _teardown(stage: SubViewport, comic: ComicMedium) -> Array:
	Director.detach()
	Director.attach(stage, comic)
	for _i in 30:
		comic.advance(Spectrum.current, 1.0 / FPS, 0.0)
	Director.detach()               # the first release, through the Director
	var out: Array = []
	var held := 0
	for sc in comic._cast:
		if sc != null and is_instance_valid(sc) and not (sc as Node).is_queued_for_deletion():
			held += 1
	if held > 0:
		out.append("the medium still holds %d cast scene(s) after its session ended" % held)
	var running := 0
	for vp: SubViewport in comic._slots:
		if vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			running += 1
	if running > 0:
		out.append("%d panel viewport(s) still running after release" % running)
	comic.release()                 # ...and again, as main._clear_stage does
	if Director._index != -1 or not Director._kind_last.is_empty():
		out.append("a second release minted a scene through the detached Director")
	return out



## Drive the medium for SECONDS and report what the picture did. The Director runs free: pinning the hold (as
## comic_look_probe does) makes every deadline infinite.
func _drive(comic: ComicMedium, sev: float) -> void:
	comic._turn_spread(0)
	var dt := 1.0 / FPS
	var steps := int(SECONDS / dt)
	var prev := PackedVector2Array()
	var prev_panel := -1
	var moves: Array = []          # per-frame screen displacement
	var areas: Array = []          # per-frame silhouette area, for the zoom direction
	var panels: Array = []         # per-frame framing panel, to tell a jump's subject
	var cuts := 0
	# The scene ends when its hold is up, fixed when the scene starts. hold_remaining() is the time left, so the
	# median is taken as when the Director expects the cut and what the medium plans against.
	Director._elapsed = 0.0
	var due := Director.hold_remaining()
	# How long a shot takes to arrive is what `held` is made of; a shot that never reaches its target holds for
	# none of its scene. Also how wide the shots are across the run: the distribution of framings.
	var fills: Array = []
	var arrivals: Array = []
	var shots := 0
	var never := 0
	var was_shot := -1
	var this_arrived := false
	for i in steps:
		Director._elapsed += dt
		# The Director must actually cut, or the medium sits on one shot. A cut on a cast-owning medium is a handover
		# and nothing else: ask it to take over, adopt what it hands back, build or free nothing.
		if Director._elapsed >= due:
			# The app's own cut, not an imitation: the Director asks the medium first and resets the clock after.
			Director._begin_transition()
			if Director._transitioning:
				_fails.append("camera %.2f: the comic declined a handover and the Director built a scene"
					% sev)
				return
			due = Director.hold_remaining()
			cuts += 1
		comic.advance(Spectrum.current, dt, 0.0)
		# Sampled every frame: begin_shot replaces `_shot` with a fresh dict and bumps `_shot_n` in one call, so
		# waiting for the counter reads the new shot's `arrived`, false by construction.
		if comic._camera._shot_n != was_shot:
			if not comic._camera._tgt.is_empty():
				fills.append(float(comic._camera._tgt.fill))
			if was_shot >= 0:
				shots += 1
				if not this_arrived:
					never += 1
			was_shot = comic._camera._shot_n
			this_arrived = false
		if not this_arrived and bool(comic._camera._shot.get("arrived", false)):
			this_arrived = true
			arrivals.append(comic._camera._shot_t)
		comic._camera.prepare_lens()
		var q := _grid(comic)
		var fp: int = comic._spread.framing_panel(comic._spread.clamp_aim(comic._camera._cam.aim))
		if q.size() == prev.size() and q.size() > 0:
			# The median sample, not the worst: one point grazing the near plane projects to a huge coordinate.
			var ds: Array = []
			for k in q.size():
				ds.append(q[k].distance_to(prev[k]))
			ds.sort()
			moves.append(float(ds[ds.size() / 2]))
			areas.append(_spread_px(q))
			panels.append(fp)
		prev = q
		prev_panel = fp
	if moves.size() < 10:
		_fails.append("camera %.2f produced no measurable picture" % sev)
		return
	# A run with no cuts measures nothing about cuts; if this trips the camera was never asked to look elsewhere.
	if cuts < 2:
		_fails.append("camera %.2f: only %d Director cuts in %.0fs - the run is not exercising them"
			% [sev, cuts, SECONDS])
	var mean_arr := 0.0
	for a in arrivals:
		mean_arr += float(a)
	mean_arr /= maxf(1.0, float(arrivals.size()))
	# The spread, not just the mean: equal means can hide every shot arriving at once.
	var lo := INF
	var hi := 0.0
	for a in arrivals:
		lo = minf(lo, float(a))
		hi = maxf(hi, float(a))
	var flo := INF
	var fhi := 0.0
	for f in fills:
		flo = minf(flo, float(f))
		fhi = maxf(fhi, float(f))
	print("  camera %.2f over %.0fs, %d cuts, %d shots: arrived in %.1fs mean (%.1f-%.1f), %d never arrived, framing %.2f-%.2f"
		% [sev, SECONDS, cuts, shots, mean_arr, 0.0 if lo == INF else lo, hi, never,
			0.0 if flo == INF else flo, fhi])
	# A shot that never arrives never holds. Most must arrive, not all: a shot cut before its approach can finish is
	# legitimate when the Director's hold is short. Every setting is held to this.
	if shots > 0 and float(never) / float(shots) > 0.5:
		_fails.append("camera %.2f: %d of %d shots never reached their target"
			% [sev, never, shots])
	_report(sev, moves, areas, panels)


func _report(sev: float, moves: Array, areas: Array, panels: Array) -> void:
	var sorted := moves.duplicate()
	sorted.sort()
	var med: float = float(sorted[sorted.size() / 2])
	var p99: float = float(sorted[int(float(sorted.size()) * 0.99)])
	var worst: float = float(sorted[sorted.size() - 1])
	# TELEPORTS: a single loud frame between quiet ones, and whether it changed the subject.
	var jumps := 0
	var same_panel := 0
	for i in range(1, moves.size() - 1):
		if float(moves[i]) < TELEPORT:
			continue
		if float(moves[i - 1]) > TELEPORT_QUIET or float(moves[i + 1]) > TELEPORT_QUIET:
			continue                       # a fast move, not a cut
		jumps += 1
		if int(panels[i]) == int(panels[i - 1]):
			same_panel += 1
	# HELD, measured on the picture...
	var held := 0
	for m in moves:
		if float(m) < STILL:
			held += 1
	# ...and the longest unbroken still run, which `held` cannot give: a good hold and a dead freeze are both held,
	# the difference is whether it ends.
	var run := 0
	var longest := 0
	for m in moves:
		if float(m) < FROZEN:
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
	# Reversals of the rendered scale, and whether a hold separated them. A direction is in force once the scale has
	# traveled ZOOM_DEADBAND that way, and a reversal counts once it has traveled that far back.
	var dir := 0
	var since_hold := 0
	var flips := 0
	var unheld := 0
	var anchor: float = float(areas[0])
	for i in range(1, areas.size()):
		if float(moves[i]) < STILL:
			since_hold += 1
		var scale: float = maxf(float(areas[i]), 1e-4)
		var travel: float = (float(areas[i]) - anchor) / scale
		if absf(travel) < ZOOM_DEADBAND:
			continue
		var nd := 1 if travel > 0.0 else -1
		anchor = float(areas[i])
		if dir != 0 and nd != dir:
			flips += 1
			if since_hold < HOLD_FRAMES:
				unheld += 1
			since_hold = 0
		dir = nd
	print("      median %.5f  p99 %.5f  worst %.5f of frame" % [med, p99, worst])
	print("      teleports %d (%d landed on the panel already framed)   held %.0f%%   frozen run %.1fs   zoom reversals %d (%d without a hold between)" % [
		jumps, same_panel, 100.0 * float(held) / float(moves.size()),
		float(longest) / FPS, flips, unheld])


## A fixed grid of points on the paper, projected: the samples are nailed to the sheet, so their screen displacement
## is the content sliding across the frame, in frame widths. The sheet is sampled rather than its silhouette,
## whose corners are the least stable points (first to cross the near plane). Points behind the eye are dropped,
## and a frame whose set of survivors differs from the last one is skipped.
func _grid(comic: ComicMedium) -> PackedVector2Array:
	var out := PackedVector2Array()
	for iy in 3:
		for ix in 5:
			var sp := Vector2(0.2 + 1.6 * float(ix) / 4.0,
				comic._spread.aspect * (0.2 + 0.6 * float(iy) / 2.0))
			var w: Vector3 = comic._spread.world(sp, comic._camera.att_basis)
			if comic._camera.lens.depth(w) <= comic._camera.lens.near:
				return PackedVector2Array()     # any sample behind the eye voids the frame
			var pr: Vector3 = comic._camera.lens.project(w)
			out.append(Vector2(pr.x, pr.y))
	return out


## How big the page is on screen: the spread of the projected grid, the rendered scale as a number.
func _spread_px(q: PackedVector2Array) -> float:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in q:
		lo = lo.min(p)
		hi = hi.max(p)
	return (hi - lo).length()


## The control for [method _check_reattach]: a camera whose reset does nothing.
class StuckCamera extends ComicCamera:
	func reset() -> void:
		pass


## The control for [method _check_release]: a release that opens the next book at once.
class LeakyComic extends ComicMedium:
	func release() -> void:
		super()
		_turn_spread(0)
