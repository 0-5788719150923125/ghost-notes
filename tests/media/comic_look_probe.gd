extends Node

## Not a gate: drives a real comic-medium session and writes PNGs. It asserts only that a frame is not uniform.
## (city_look_probe.gd and clown_look_probe.gd are the same kind of probe.)
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/media/comic_look_probe.gd 240 \
##       --out /tmp/comic --cuts 9 --seed 404
##
## GHOST_PROBE_GPU is required: it reaches Director and Spectrum (a real boot) and reads pixels back (a real
## renderer; --headless returns nothing). It drives the medium directly, one cut being `host_for` plus a scene as
## the Director does, rather than waiting for musical cues.

const W := 1280
const H := 720
const DT := 1.0 / 30.0

var _out := "user://comic"
## Which medium to drive: `comic`, or `full` to compare against the plain ghost look.
var _medium_key := "comic"
var _cuts := 9
var _shots: Array = []          # cut indices to photograph; default = every third
var _wrote := 0
var _flat := 0
var _thin := 0                    # frames where the page did not cover the frame
var _static := 0                  # shots where the camera had stopped moving
var _cropped := 0                 # shots where a FILM panel was cropped by the frame
## Frames to let the camera travel before photographing. The default covers the slowest pan; a long settle shows
## what the camera does after its move has run out (see _static).
var _settle := 90
## Spread-coordinate units per second of aim travel under which the camera counts as stopped (one unit is a page
## width). The aim is measured, not the eye: the sheet's attitude drifts forever (ComicCamera.DRIFT), so the eye
## keeps moving even when the framing is locked.
const STILL := 0.010
var _medium: Medium = null
var _live: GhostScene = null      # the scene in the open panel; this probe drives it


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_args()
	await _shoot()
	print("comic_look_probe: wrote %d frame(s) under %s" % [_wrote, _out])
	if _flat > 0:
		print("comic_look_probe: %d frame(s) were UNIFORM - the page did not draw." % _flat)
	if _thin > 0:
		print("comic_look_probe: %d frame(s) showed DESK - the page did not cover." % _thin)
	if _static > 0:
		print("comic_look_probe: %d shot(s) had a STOPPED camera - the move ran out and nothing replaced it." % _static)
	if _cropped > 0:
		print("comic_look_probe: %d shot(s) CROPPED THE FILM - the whole video was not on screen." % _cropped)
	for _i in 6:
		await get_tree().process_frame
	get_tree().quit(1 if _flat > 0 else 0)


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			break
		match args[i]:
			"--out": _out = args[i + 1]
			"--medium": _medium_key = args[i + 1]
			"--cuts": _cuts = int(args[i + 1])
			"--settle": _settle = int(args[i + 1])
			"--shots":
				_shots = []
				for s in String(args[i + 1]).split(","):
					_shots.append(int(s))
			# Footage on the page: pass a prepared .ogv and every page gives a panel to it. It goes through Films'
			# probe seam, since a probe may not write the library in Settings.
			"--film":
				var path := String(args[i + 1])
				var dur := Films._probe_duration(path)
				Films.use_for_test([{"source": path, "slug": Films._slug(path),
					"name": path.get_file().get_basename(), "duration": maxf(dur, 1.0)}], 1.0)
				print("comic_look_probe: film %s (%.1fs) on every page" % [path, dur])


## Shoots one session. The seed is the Director's: pass `--seed N`, resolved as every songless boot does.
func _shoot() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(W, H)
	stage.transparent_bg = false
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)

	# A real session, so the medium samples its paper and its pages off a real seed. The Director's own scheduling
	# is not driven here (no audio); the cuts below are.
	Director.detach()
	var medium: Medium = Medium.make(_medium_key)
	_medium = medium
	medium.mount(stage)
	Director.attach(stage, medium)
	# Pin the seed attach() resolved at random (no audio, so no fingerprint), so file names match the seed and runs
	# compare; re-rolling begin_session makes it take (the medium samples paper, ink and first page there).
	# Freeze the Director's own cutting (hold(), as the feedback console does) so only this probe advances the
	# reading; the probe ticks the focal scene itself.
	Director.hold(true)
	# Adopt what attach() set up rather than replacing it: under a cast-owning medium Director._current is one of
	# the page's panels.
	_live = Director._current
	print("--- %s seed %d: %s ---" % [
		_medium_key, Director.session_seed(), _page_line(medium)])

	var t := 0.0
	for cut in _cuts:
		var comic := medium is ComicMedium
		var was_spread: int = medium._spread_i if comic else 0
		# Stand in for main._process, which a probe scene replaces: it promotes a finished window cut, else the probe
		# waits forever on `.part` files.
		Films.pump()
		_cut(medium)
		if comic:
			var turned: bool = medium._spread_i != was_spread
			# Which panel holds footage, on every line.
			var film := ""
			if medium._film_at >= 0:
				film = "[film p%d] " % (medium._film_at + 1)
			print("    cut %d -> spread %d, reading panel %d of %d, plan %s, live %s %s%s" % [
				cut, medium._spread_i, medium._read + 1, medium._spread.panels.size(),
				medium._plan, medium._live, film,
				("(leaf turned) " + _page_line(medium)) if turned else ""])

		else:
			print("    cut %d" % cut)
		# Let the panel's scene build and the camera ease toward the new framing.
		#
		# The scene must be ticked here: a GhostScene has no _process of its own (the Director calls update() on it,
		# see Director._tick_animation), so without it a scene that builds over time freezes black.
		# Long enough for the move to land: three seconds covers the slowest pan.
		# Camera travel is measured over the last second of the settle: whether the camera is still going anywhere
		# when it arrives.
		var was_aim := Vector2.ZERO
		var travel := 0.0
		for i in _settle:
			# The focal scene only; a cast-owning medium drives its other live panels in advance().
			if _live != null and is_instance_valid(_live):
				_live.update(Spectrum.current, DT)
				_live.view.commit(DT)
			medium.advance(Spectrum.current, DT, 1.0)
			if comic:
				var aim: Vector2 = medium._camera._cam["aim"]
				if i >= _settle - 30:
					if i > _settle - 30:
						travel += was_aim.distance_to(aim)
					was_aim = aim
			t += DT
			await get_tree().process_frame
		if _shots.is_empty() or _shots.has(cut):
			await _capture(stage, cut, travel)
	_live = null
	Director.hold(false)
	Director.detach()
	# The stage owns the medium (Medium.mount parents itself), so freeing the stage frees it.
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame


## One cut, as the Director performs one.
##
## For a cast-owning medium that is a handover and nothing else (see Director._handover): ask it to take over,
## adopt what it hands back, and build/free nothing - the panels were cast when the page turned.
func _cut(medium: Medium) -> void:
	if medium.owns_cast():
		var handed := medium.take_over(_live)
		if handed != null:
			_live = handed
		return
	var entry: Dictionary = SceneRoster.SCENES[randi() % SceneRoster.SCENES.size()]
	var sc: GhostScene = (entry["script"] as Resource).new()
	# The Director's order: init_with_seed first, add_child second (see Director._make_scene); reversed, Node2D
	# draws the node once uninitialized.
	sc.init_with_seed(randi(), String(entry["behavior"]))
	var prev: GhostScene = _live
	medium.host_for(sc).add_child(sc)
	_live = sc
	if prev != null and is_instance_valid(prev):
		prev.queue_free()


## [param travel] is how far the eye moved over the last second of the settle, in world
## units - see the loop in _shoot.
func _capture(stage: SubViewport, cut: int, travel := -1.0) -> void:
	var img := stage.get_texture().get_image()
	var path := "%s_cut%02d.png" % [_out, cut]
	img.save_png(path)
	_wrote += 1
	var spread := _spread(img)
	if spread < 0.02:
		_flat += 1
	# Page coverage, reported per frame: below 1.0 the sheet does not reach both frame edges and the surface under
	# it is in shot.
	var cov := 1.0
	var still := false
	var fit := -1.0
	var mag := -1.0
	if _medium_key == "comic":
		cov = float(_medium.page_coverage())
		# A hair under 1 is a pixel of rounding at the frame edge, not desk in shot.
		if cov < 0.995:
			_thin += 1
		still = travel >= 0.0 and travel < STILL
		if still:
			_static += 1
		# The read panel's share of the frame, on its worst axis. Over 1 the panel overflows the picture, which is
		# wanted for an abstract field and wrong for footage: a film panel being read must come out at or under 1.
		fit = float(_medium.read_panel_fit())
		# How hard the panel's render target is magnified: a panel is rasterized into a SubViewport at a fixed size and
		# drawn as a texture, so over 1 the shot puts it across more screen pixels than it has texels (1 is 1:1).
		mag = _medium.read_panel_magnification()
		if _medium._read == _medium._film_at and fit > 1.02:
			_cropped += 1
	if _medium_key == "comic":
		print("      panels: %s" % _panel_line(_medium))
		print("      shot:   %s" % _medium.shot_debug())
	print("    %s  (luma %.3f, spread %.3f, page covers %.2f, aim moved %.4f/s, read panel %.2f of frame, texture x%.2f)%s%s%s" % [
		path, _luma(img), spread, cov, maxf(travel, 0.0), maxf(fit, 0.0), maxf(mag, 0.0),
		"  <-- UNIFORM" if spread < 0.02 else "",
		"  <-- DESK IN SHOT" if cov < 0.995 else "",
		"  <-- CAMERA STOPPED" if still else ""])


func _page_line(medium: Medium) -> String:
	if not (medium is ComicMedium):
		return "(no spread - %s draws the scene straight onto the stage)" % medium.key
	var sp: ComicSpread = medium._spread
	if sp == null:
		return "(no spread yet)"
	var aspects := ""
	for i in sp.panels.size():
		aspects += "%.2f%s " % [sp.panel_aspect(i), "|" if sp.side_of(i) == 0 else ""]
	var left: int = sp.pages[0].panels.size()
	var right: int = sp.pages[1].panels.size()
	return "%d+%d panels, aspect %.2f, gutter %.3f, radius %.4f, panel aspects [ %s]" % [
		left, right, sp.aspect, sp.gutter, sp.radius, aspects]


## Every panel's state, per cut: `c` = a live GhostScene is parented in it, `L` = its viewport is running this
## frame, then the render target size. Black with no `c` was never cast; black at 64x64 is a slot shrunk and never
## regrown; black with a `c` at full size is a scene drawing black.
func _panel_line(medium: ComicMedium) -> String:
	var out := ""
	for i in medium._spread.panels.size():
		var vp: SubViewport = medium._slots[medium._pool * ComicMedium.POOL + i]
		var cast_ok: bool = i < medium._cast.size() and medium._cast[i] != null \
			and is_instance_valid(medium._cast[i])
		var warm: int = int(medium._warm[i]) if i < medium._warm.size() else 0
		# `w` = the panel has rendered enough frames to have a picture worth freezing.
		out += "%d[%s%s%s %d] " % [i + 1, "c" if cast_ok else "-",
			"L" if medium._live.has(i) else " ",
			"w" if warm >= ComicMedium.WARM_FRAMES else "-", warm]
	return out


func _luma(img: Image) -> float:
	var acc := 0.0
	var n := 0
	for y in range(0, img.get_height(), 7):
		for x in range(0, img.get_width(), 7):
			var c := img.get_pixel(x, y)
			acc += c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			n += 1
	return acc / float(maxi(1, n))


## Standard deviation of luma. A page that drew has paper, ink and pictures on it; a page
## that did not is one flat color, and that is what this separates.
func _spread(img: Image) -> float:
	var mean := _luma(img)
	var acc := 0.0
	var n := 0
	for y in range(0, img.get_height(), 7):
		for x in range(0, img.get_width(), 7):
			var c := img.get_pixel(x, y)
			var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			acc += (l - mean) * (l - mean)
			n += 1
	return sqrt(acc / float(maxi(1, n)))
