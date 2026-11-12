extends Node

## Does the Camera knob move the shot planner along one axis, and is the angular walk bounded?
##
##   tests/run_boot_probe.sh tests/media/comic_camera_check.gd 120
##
## Needs a real boot (it reaches Director and Settings) but not a real renderer: it reads the planning arithmetic
## out of `_tgt` before anything draws. It measures the plan only; how the camera behaves on screen is
## tests/media/comic_motion_check.gd's job.

var _fails: Array = []
## How many shots to plan per setting (arithmetic, so cheap).
const SHOTS := 600
## The Camera settings compared: the ends of Director's range and the tuned middle.
const LEVELS := [0.0, 1.0, 2.0]
## Shots planned and discarded at the start of each setting. The camera carries state across a setting change, so the
## first shots are the old pose walking off; most shots keep the azimuth, so the handover runs a couple of dozen shots.
const WARMUP := 40


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
	Director.hold(true)          # nothing but this probe advances the reading
	var comic: ComicMedium = v

	var was := Director.camera
	var swing: Array = []
	var reach: Array = []
	var jumps: Array = []
	for sev in LEVELS:
		Director.set_camera(float(sev))
		var r := _measure(comic)
		swing.append(r["swing"])
		reach.append(comic._camera._reach())
		jumps.append(r["jump"])
		print("  camera %.1f -> mean shot-to-shot swing %.1f deg, %.0f%% jump cuts, "
			% [sev, rad_to_deg(float(r["swing"])), 100.0 * float(r["jump"])]
			+ "reach %.2f, walk stayed within %.1f deg"
			% [comic._camera._reach(), rad_to_deg(float(r["worst"]))])
		# The walk is bounded by its arc at every setting (the clamp in _walk).
		if float(r["worst"]) > ComicCamera.AZ_ARC * float(sev) + 1e-4:
			_fails.append("camera %.1f: the azimuth walk reached %.3f rad, outside its %.3f arc"
				% [sev, float(r["worst"]), ComicCamera.AZ_ARC * float(sev)])

	# The knob is monotone: every step moves the camera the same way.
	for i in LEVELS.size() - 1:
		if float(swing[i + 1]) <= float(swing[i]):
			_fails.append("swing did not grow from camera %.1f to %.1f (%.4f -> %.4f rad)"
				% [LEVELS[i], LEVELS[i + 1], swing[i], swing[i + 1]])
		# So is reach, the axis that decides holding: with a follower a shot arrives when the picture gets
		# there, so calm versus busy is how far it goes, not how slowly.
		if float(reach[i + 1]) <= float(reach[i]):
			_fails.append("reach did not grow from camera %.1f to %.1f (%.2f -> %.2f)"
				% [LEVELS[i], LEVELS[i + 1], reach[i], reach[i + 1]])

	# At zero the camera never jumps and never turns, exactly.
	if float(jumps[0]) > 0.0:
		_fails.append("camera 0 still jump-cut on %.1f%% of shots" % (100.0 * float(jumps[0])))
	if float(swing[0]) > 1e-6:
		_fails.append("camera 0 still swung the camera %.4f rad per shot" % float(swing[0]))

	_check_film_fit(comic)
	_check_focal_live(comic)

	Director.set_camera(was)
	Director.hold(false)
	Director.detach()
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame
	if _fails.is_empty():
		print("comic_camera_check: ALL OK")
	else:
		for f in _fails:
			print("comic_camera_check: FAIL - %s" % f)
	# End here, once the verdict is printed: the engine's own shutdown after freeing real scenes dies or hangs
	# (tests/run_scene_smoke.sh). A SIGKILL on ourselves, as main._shutdown does, skips it. check.sh reads the
	# verdict from the log, never the exit code.
	OS.kill(OS.get_process_id())


## Plan SHOTS shots at the current setting and report what the planner chose.
func _measure(comic: ComicMedium) -> Dictionary:
	comic._spread = ComicSpread.new(hash(["cam", Director.camera]))
	comic._spread_i = 3
	comic._film_at = -1
	comic._roll_plan()
	comic._read = int(comic._plan[0])
	comic._camera.choose_look()
	var swing := 0.0
	var jumps := 0
	var worst := 0.0
	var n := 0
	for m in SHOTS + WARMUP:
		var before: float = float(comic._camera._cam.az)
		comic._camera.begin_shot(comic._read % comic._spread.panels.size())
		# The planner's answer is the target; the follower's business is how the camera gets there.
		var az: float = float(comic._camera._tgt.az)
		if m >= WARMUP:
			swing += absf(angle_difference(before, az))
			worst = maxf(worst, absf(comic._camera._az_walk))
			if bool(ComicCamera.SHOTS[String(comic._camera._shot["kind"])].get("hard", false)):
				jumps += 1
			n += 1
		# Stand the camera on its target so the next shot is planned from where this one led.
		comic._camera._cam = (comic._camera._tgt as Dictionary).duplicate()
	return {
		"swing": swing / maxf(1.0, float(n)),
		"jump": float(jumps) / maxf(1.0, float(n)),
		"worst": worst,
	}


## Is the whole video on screen when the video is what is looked at?
##
## Other panels are framed on height alone and may overflow the sides; footage must not be cropped. Asserted here
## because the film panel is the first entry of the reading plan and is gone before the look probe's first capture.
## Drives place_eye on the widest panel of a spread with and without the film flag, comparing the contain path
## against the shot it replaces.
func _check_film_fit(comic: ComicMedium) -> void:
	comic._spread = ComicSpread.new(hash(["filmfit"]))
	comic._spread_i = 3
	comic._camera._att = Vector3(0.3, 0.35, 0.15)
	comic._camera.att_basis = Basis.from_euler(comic._camera._att)
	# The widest panel on the sheet - the one a height-only fit crops hardest.
	var wide := 0
	for i in comic._spread.panels.size():
		if comic._spread.panel_aspect(i) > comic._spread.panel_aspect(wide):
			wide = i
	comic._read = wide
	comic._plan = [wide]
	comic._step = 0
	var out := {}
	for as_film in [false, true]:
		comic._film_at = wide if as_film else -1
		# Pin the whole camera state, not just the aim (az/el/roll/fov carry over from earlier checks), so both
		# framings are measured from the same station.
		comic._camera._cam["aim"] = comic._spread.panel_center(wide)
		comic._camera._cam["fill"] = 1.2
		comic._camera._cam["az"] = 0.6
		comic._camera._cam["el"] = deg_to_rad(52.0)
		comic._camera._cam["roll"] = 0.08
		comic._camera._cam["fov"] = 46.0
		comic._camera.place_eye()
		comic._camera.prepare_lens()
		out[as_film] = comic._camera.read_panel_fit()
		out["cov%s" % as_film] = comic._camera.page_coverage()
	print("  widest panel (aspect %.2f): as a scene %.2f of frame (page covers %.2f), "
		% [comic._spread.panel_aspect(wide), out[false], out["covfalse"]]
		+ "as film %.2f (page covers %.2f)" % [out[true], out["covtrue"]])
	if float(out[true]) > 1.0:
		_fails.append("a film panel being read is cropped by the frame (%.2f of it)"
			% float(out[true]))
	# The contain path must actually act, or the assertion above passes on a panel that fits anyway.
	if float(out[false]) <= 1.0:
		print("  (note: this panel fits even without containing, so the contrast is weak)")
	comic._film_at = -1


## Is the panel being read ever frozen?
##
## The liveness sort puts every panel below its warm-up ahead of every warm one and LIVE_MAX is three, so the three
## panels cast by a page turn could take the whole budget and freeze the current scene. Casts a full spread (every
## panel cold) and asserts the read panel survives it.
func _check_focal_live(comic: ComicMedium) -> void:
	comic._spread = ComicSpread.new(hash(["focal"]))
	comic._spread_i = 11
	comic._film_at = -1
	var n := comic._spread.panels.size()
	comic._cast = []
	comic._cast.resize(n)
	comic._warm = []
	comic._warm.resize(n)
	comic._warm.fill(0)
	# Stand in for a cast spread: every panel holds a scene and none has drawn yet.
	for i in n:
		var sc := GhostScene.new()
		comic._slots[comic._pool * ComicMedium.POOL + i].add_child(sc)
		comic._cast[i] = sc
	var missed := 0
	for i in n:
		comic._read = i
		comic._update_liveness()
		if not comic._live.has(i):
			missed += 1
	print("  every panel of a freshly cast %d-panel spread read in turn -> focal frozen %d time(s)"
		% [n, missed])
	if missed > 0:
		_fails.append("the panel being READ was frozen on %d of %d panels - its scene stops"
			% [missed, n])
	for i in n:
		if comic._cast[i] != null and is_instance_valid(comic._cast[i]):
			comic._cast[i].queue_free()
	comic._cast = []
	comic._warm = []
