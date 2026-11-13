extends Medium
class_name ComicMedium

## ComicMedium - the show as an open comic book, flown over by a real perspective camera.
##
## The same scenes, Director and cutting; what changes is where a scene lands: each cut fills the next
## panel of the spread, and when the spread is full the next cut turns the leaf. `Scene hold` and
## `Flourishes` keep their meanings (a burst of quick cuts is a run of small panels filling in fast).
##
## Two pages at once, as in a comic: a portrait sheet in a landscape frame leaves a wedge of desk in
## shot, a pan has one page's width to travel, and a leaf hinges on a spine. See [ComicSpread]: the
## spread is 2 pages wide by ~1.5 tall (1.33, against the frame's 1.78), so the sheet can cover the whole
## frame at a shot that still shows several panels.
##
## One live panel, the rest held: the newest panel is live in its own SubViewport and every panel behind
## it is a stopped render target (update mode DISABLED, its scene freed, its last frame still in VRAM).
## Measured in tests/media/medium_probe.gd: the texture survives the stop and the free bit-exact, so a
## held panel costs nothing. (Capturing each panel with get_image() is a synchronous readback stall.)
##
## The spread is really in 3D: two quads placed in a world and projected through a [Lens3D], free to
## rotate on X, Y and Z. Panels are drawn as subdivided grids of textured triangles whose vertices are
## each projected individually, because a two-triangle quad is affinely textured and warps (at a hard
## yaw the seam of a test texture landed 28.5 px from where perspective puts it, on a 512 px frame).
##
## The camera is a part of its own, [ComicCamera]: the shots, the follower and the lens this draws
## through. What is here is the book (the spread, its plan, its cast and its panels' render targets) and
## the drawing; where a point lies on the sheet is [ComicSpread]'s.

## How many panel slots exist: two pools of [constant ComicSpread.MAX_PANELS], alternating per spread,
## because a page turn shows both spreads at once and reusing one pool would pull the outgoing spread's
## pictures out from under it. All four half-pages carry textures during a turn, which is why a pool is
## a whole spread and not a page.
const POOL := ComicSpread.MAX_PANELS

## Panel render-target size, as a fraction of the stage's shorter side: a panel is sampled at close to
## 1:1 in the tight reading shot (which frames roughly one panel). Clamped below so a small window gets a
## legible panel and above so a 4K export does not allocate enormous targets.
const PANEL_SCALE := 1.0
const PANEL_MIN := 224
const PANEL_MAX := 1400
## What an unopened slot is sized to (64 squared is 16 KiB): there are 24 slots and a spread opens at most
## half. _open_slot grows the slot to its real size before anything draws it.
const SLOT_IDLE := 64

## Subdivision of a panel's textured grid, chosen so each cell is about this many pixels on screen,
## between these bounds. Adaptive: inside one cell the texture mapping is affine while the true mapping is
## projective, so the error scales with the cell's size on screen and how hard the panel is raked; sizing
## the cell rather than the count bounds the error at any framing.
const CELL_PX := 56.0
const GRID_MIN := 6
const GRID_MAX := 40
## Subdivision of the paper quad. It carries only a slow gradient, so it needs far less.
const PAPER_GRID := 4
## Segments per rounded corner.
const CORNER_SEGS := 5


## How many panels may run at once (see [method _update_liveness]). Three covers the panel being read plus
## the neighbors crowding the frame edges at the reading distance. Not raised for the spread: a wider shot
## makes each panel smaller, and the budget is about scene cost, not screen area.
const LIVE_MAX := POOL

## The budget does not apply to an export. LIVE_MAX is a real-time concession (the show has sixteen
## milliseconds to draw a frame); an export renders offline, one frame at a time, so every panel runs. On
## a spread of nine to twelve seen wide, the budget's frozen leftovers would be most of the picture.
const LIVE_ALL_ON_EXPORT := true

## How often a live panel that is not the one being read repaints, in frames. The panel being read is the
## one anyone looks at, and every other frame is invisible on a panel at the edge of shot: those panels are
## ticked with a matching multiple of the step, so they run at the right speed with half the samples.
## Measured on one seed, this and the height-based target sizing took the comic's active frame from 84 ms
## to 73 against the full frame's 41.
const OFF_FOCAL_PERIOD := 2
## How many render-target pixels a panel gets per pixel it covers on screen. Above 1 so a panel the camera
## is drifting toward is already sharp, and the paper's perspective foreshortening does not read as soft.
const PANEL_OVERSAMPLE := 1.35
## How much bigger a panel has to want to be before its target is re-opened, as a ratio: a target that
## chases the shot pixel for pixel reallocates every frame; this makes it a handful of steps per push-in.
const REOPEN_STEP := 1.5

## How many frames a panel must actually render before it may be frozen. A held panel keeps the last
## picture it drew (the invariant the medium rests on, tests/media/medium_probe.gd), so a panel cast, given
## two frames and frozen holds two frames of an empty scene: black (nothing culled it). On a spread with a
## budget of three and a reading plan that never visits most panels, a panel can be cast, glimpsed and
## frozen having drawn nothing, the film panel included (its player is still opening its window).
##
## So liveness is ordered by need first and distance second: a panel below its warm-up takes priority over
## one that has drawn its moment, and only once every panel has a picture does the budget follow the
## camera. 24 frames is about 0.4 s, enough for a scene's first pass and a video window's first frame.
const WARM_FRAMES := 24

## How many frames a panel must have rendered before its texture may be drawn. A SubViewport's render
## target is allocated by _open_slot and not cleared, so sampling it before the viewport has produced a
## frame draws whatever was in that VRAM (on a fresh boot, the application's own interface).
##
## Two, not one: _update_liveness raises the warm count in the same frame it resumes the viewport, which
## renders at the end of that frame, so one means "asked to draw", not "has drawn". A panel below this is
## drawn as an empty ruled frame, which is what the page shows for a panel the story has not reached.
const FIRST_DRAW := 2

## How many panels of a spread the camera actually stops on before the leaf turns (min, max). Not all of
## them: you take in the whole spread at a glance, rest on a few moments and turn, and the panels not
## rested on are drawn the whole time and every pan across the sheet passes over them. So the spread
## samples a plan of this many panels to settle on, in reading order, and turns when the plan is done. A
## denser spread gets a slightly longer plan, never one per panel.
const FOCUS := Vector2i(3, 5)

## How a spread gets read, weighted (mostly the way a page is read, sometimes not):
##
##   read  top-left, across, down and back, across, then the other page.
##   grab  something catches the eye first - the film panel if there is one, else the biggest panel on the
##         sheet - and the reading resumes in order afterwards.
##   skim  left, right, left: a glance across the spread rather than a read of it.
##
## A bag rather than a hard rule: strict reading order every time is a machine indexing a page, and the
## deviations make it read as someone looking at a comic. Six to one, because the ping-ponging is the
## exception.
const PLAN_STYLES := {"read": 6.0, "grab": 2.0, "skim": 1.0}

## How strongly a piece of footage pulls the eye first, as a probability that it opens the spread whatever
## style was rolled: a human in a video is what people look at first. Not 1.0, since a spread that always
## opens on the film is a rule the eye learns in two pages.
const FILM_FIRST := 0.72

## How long a page turn takes, in seconds.
const TURN_TIME := 1.15
## How far the leaf swings: a half turn exactly, because at pi the leaf lies flat on the left page and its
## back face (the incoming left page, see [method ComicSpread.mirror]) lands where that page is about to be
## drawn flat. Anything short of pi would have to cross-dissolve the difference.
const TURN_ARC := PI

## The spread lies on something, else the frame past the trim edge is pure black. Painted in screen space,
## not as a world quad: a surface big enough to never run out under a close raked camera has corners far
## outside the frustum, and the projection drops any quad with a corner behind the eye. A defocused
## surface has no texture to rake, so it only needs to be present and not black.
## How dark the wash goes at the corners of the frame, as a fraction of the desk color.
const DESK_VIGNETTE := 0.55
## The sheet's shadow on it: offset in page widths, and how far off the paper it is cast.
const SHADOW_OFF := Vector2(0.045, 0.055)
const SHADOW_DEPTH := 0.06

# --- state -------------------------------------------------------------------
var _slots: Array = []            # POOL * 2 SubViewports; spread s uses pool (s % 2)
var _pool := 0                    # which pool the CURRENT spread is drawing from
var _spread: ComicSpread = null
var _spread_i := -1
var _cast: Array = []             # per panel of the current spread: its GhostScene, or null
var _read := 0                    # panel the camera is reading, and the Director's current
## The panels this spread will settle on, in reading order (see FOCUS). `_read` is one of these, and
## `_step` is how far through the plan the reading has got.
var _plan: Array = []
var _step := 0
var _to_cast: Array = []          # panels still waiting to be cast, one per frame
var _prev: ComicSpread = null     # the outgoing spread, alive only through a turn
var _turn_t := -1.0               # seconds into a page turn, < 0 when none

## Which panel of this spread holds footage, or -1 for none, and the clip it holds. At most one per spread:
## a clip's position is a pure function of the show clock (see [method Films.position_at]), so two panels
## sampling the same clip at the same instant would show the same picture twice. During a turn the
## outgoing spread's panels are already stopped, so even then only one is playing.
var _film_at := -1
var _film_clip: Dictionary = {}
var _film_prev := ""              # last spread's clip path, so two running do not repeat

var _mod: ModBank = null
var _bookend := 1.0
var _panel_px := 512
var _stage_size := Vector2(1280, 720)
var _live: Array = []             # panel indices whose viewport is running this frame
## Frames each panel of the current spread has actually rendered. See WARM_FRAMES.
var _warm: Array = []
var _frame := 0                   # for the off-focal repaint phase, see OFF_FOCAL_PERIOD


# paper, sampled per session
var _ink_weight := 0.0038
var _desk := Color(0.06, 0.055, 0.07)
var _paper := Color(0.92, 0.90, 0.855)
var _ink := Color(0.07, 0.065, 0.075)
var _rng := RandomNumberGenerator.new()


## The camera, a part of its own ([ComicCamera]): the eye over the spread, the shots it takes and the lens
## the page is drawn through.
var _camera := ComicCamera.new()


func _init() -> void:
	_camera.medium = self


func mount(st: SubViewport) -> void:
	super.mount(st)
	# Never let a UV wrap even if one escapes the half-texel inset. The default is already this.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_size_targets(Vector2(st.size))
	_build_slots()


## Everything sampled, rolled here rather than in mount() because the session seed is not resolved until
## the Director attaches (see Medium.begin_session).
func begin_session() -> void:
	_rng.seed = feed.session_seed() ^ 0x0C031C
	# Paper is never pure white (a white page reads as a blank canvas) and is sampled like everything else.
	_paper = Color.from_hsv(_rng.randf_range(0.055, 0.11),
		_rng.randf_range(0.05, 0.13), _rng.randf_range(0.88, 0.95))
	# Ink is not black either. A cool near-black prints like ink; pure #000 prints like a
	# UI border.
	_ink = Color.from_hsv(_rng.randf_range(0.58, 0.72), _rng.randf_range(0.05, 0.20),
		_rng.randf_range(0.05, 0.13))
	# The surface the sheet lies on: dark enough that the paper is still the brightest thing, never black.
	_desk = Color.from_hsv(_rng.randf_range(0.02, 0.12), _rng.randf_range(0.10, 0.32),
		_rng.randf_range(0.055, 0.115))
	_ink_weight = _rng.randf_range(0.0030, 0.0052)
	_mod = ModBank.new(feed.session_seed() ^ 0x9A6E)
	_reset_book()
	_turn_spread(0)


## The session is over: let the book go, and open nothing. The medium outlives a session (main owns it;
## a reading re-attaches per take), so release resets the book rather than tearing the pool down
## (rebuilding twenty-four render targets per settings change is reallocation churn). It does not turn to
## the first spread: that would cast a panel at teardown (a scene minted through the Director, logged as a
## cut, its viewport left running), and main releases a medium twice as a note closes, the second time
## through a Director already detached. [method begin_session] opens the next book
## (tests/media/comic_motion_check.gd, "a session's end makes nothing").
func release() -> void:
	_reset_book()


## A new book: no spread, nothing planned, cast or turning, every panel let go (viewport stopped, picture
## kept), the liveness phase from zero and the camera put back ([method ComicCamera.reset]). Everything a
## session moves is put back, so a second attach on the same seed plays the first one's show
## (tests/media/comic_motion_check.gd, "a second attach").
func _reset_book() -> void:
	for i in _slots.size():
		_blank(_slots[i])
	_spread = null
	_spread_i = -1
	_pool = 0
	_cast = []
	_warm = []
	_live = []
	_frame = 0
	_to_cast = []
	_plan = []
	_step = 0
	_read = 0
	_prev = null
	_turn_t = -1.0
	_film_at = -1
	_film_clip = {}
	_film_prev = ""
	_camera.reset()


## A window resize changes what a panel is worth in pixels, but nothing is resized here: a render target
## reallocated while sampled is the corruption main's stage governor documents, and a resize also throws
## away the held panels' pictures. The new figure is remembered and applied at the next spread, where
## every target is repainted anyway.
func on_stage_resized(size: Vector2) -> void:
	_size_targets(size)
	queue_redraw()


func _size_targets(size: Vector2) -> void:
	_stage_size = size
	# A panel fills the frame at the reading distance, so it is worth close to the whole short axis.
	# Clamped below for a small window and above so a 4K export does not allocate 24 enormous targets.
	_panel_px = clampi(int(minf(size.x, size.y) * PANEL_SCALE), PANEL_MIN, PANEL_MAX)


func _build_slots() -> void:
	for i in POOL * 2:
		var vp := SubViewport.new()
		vp.size = Vector2i(SLOT_IDLE, SLOT_IDLE)
		vp.transparent_bg = false
		vp.disable_3d = true          # every scene rasterizes to the 2D canvas
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(vp)
		_slots.append(vp)


# --- the Medium contract ----------------------------------------------------

## The spread owns its cast. See [method Medium.owns_cast] - this is the whole difference
## between a page and a slideshow.
func owns_cast() -> bool:
	return true


## A Director cut moves the reading to the next panel; it builds nothing. The panel already holds a live
## scene, cast when the spread turned.
func take_over(_outgoing: GhostScene) -> GhostScene:
	if _spread == null:
		return null
	if _step + 1 >= _plan.size():
		_turn_spread(_spread_i + 1)
	elif _spread_i >= 0:
		_step += 1
		_read = int(_plan[_step])
		_camera.begin_shot(_read)
	# Cast on demand: the rest of the spread is cast one panel per frame, and a fast cut can reach a panel
	# before its turn in that queue. _cast_panel is idempotent, so this builds only the one still owed.
	_cast_panel(_read)
	return _focal()


func owns_bookend() -> bool:
	return true


func advance(features, delta: float, bookend: float) -> void:
	_bookend = bookend
	if _mod != null:
		_mod.advance(delta, _energy_of(features))
	_cast_one()
	if _turn_t >= 0.0:
		_turn_t += delta
		if _turn_t >= TURN_TIME:
			_turn_t = -1.0
			_prev = null
			# The outgoing spread's targets are now dead: nothing samples that pool until the next turn
			# opens it and _open_slot sizes a slot before anything draws it, so this is the one safe
			# moment to give the memory back.
			for i in POOL:
				var vp: SubViewport = _slots[(1 - _pool) * POOL + i]
				if vp.size.x > SLOT_IDLE or vp.size.y > SLOT_IDLE:
					vp.size = Vector2i(SLOT_IDLE, SLOT_IDLE)
	_camera.advance(delta)
	_camera.prepare_lens()
	_update_liveness()
	_tick_cast(features, delta)
	queue_redraw()


## AudioFeatures is not a type this file should import to read one number off, and a medium must work with
## no audio at all, so this asks softly rather than declaring a dependency.
func _energy_of(features) -> float:
	if features == null:
		return 0.0
	return clampf(float(features.energy), 0.0, 1.0)


# --- the book ----------------------------------------------------------------

func _focal() -> GhostScene:
	if _read < 0 or _read >= _cast.size():
		return null
	var sc = _cast[_read]
	return sc if sc != null and is_instance_valid(sc) else null


func _turn_spread(idx: int) -> void:
	if idx > 0 and _spread != null:
		_prev = _spread
		_turn_t = 0.0
	# Let the outgoing spread's cast go but not its pictures: _blank stops each viewport before freeing what
	# is inside it, so the spread turning away is still a drawn spread.
	for i in POOL:
		_blank(_slots[_pool * POOL + i])
	_spread_i = idx
	_pool = idx % 2
	_spread = ComicSpread.new(hash([feed.session_seed(), "comic-spread", idx]))
	_cast = []
	_cast.resize(_spread.panels.size())
	_warm = []
	_warm.resize(_spread.panels.size())
	_warm.fill(0)
	_read = 0
	# The panel being read is cast now (the show cannot open on an empty frame) and the rest are queued one
	# per frame: a dozen scenes in one frame is a visible hitch, so it lands under the page turn, and a
	# panel the camera reaches first is cast on demand.

	_choose_film()               # BEFORE the plan: _roll_plan forces the film panel into it
	_roll_plan()
	_read = int(_plan[0]) if not _plan.is_empty() else 0
	_step = 0
	# Every panel except the one cast below: a spread picks a plan and opens on `_plan[0]` (see _roll_plan),
	# which need not be panel 0.
	_to_cast = []
	for i in _spread.panels.size():
		if i != _read:
			_to_cast.append(i)
	_cast_panel(_read)
	_camera.new_spread(_read)


## Which panels this spread will settle on, in reading order (see FOCUS). Sampled, spread out, and it
## always includes the film panel when there is one (footage is certainly worth stopping on).
##
## Spaced by picking one panel from each of `want` equal slices of the reading order rather than by random
## indices: a random draw of four from nine clusters and leaves a page unvisited, while one per slice
## walks the spread and the choice inside each slice keeps it from being the same panels every time.
func _roll_plan() -> void:
	_plan = []
	if _spread == null:
		return
	var n := _spread.panels.size()
	if n <= 0:
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash([feed.session_seed(), "comic-plan", _spread_i])
	var want := clampi(r.randi_range(FOCUS.x, FOCUS.y), 1, n)
	var style := _pick_style(r)
	var picked: Array = []
	if style == "skim":
		# Left, right, left: alternating pages, and not sorted afterwards because the alternation is the
		# gesture (sorting would turn a glance back into a read).
		var side := 0 if r.randf() < 0.5 else 1
		for _k in want:
			var best := -1
			for i in n:
				if picked.has(i) or _spread.side_of(i) != side:
					continue
				if best < 0 or r.randf() < 0.4:
					best = i
			if best >= 0:
				picked.append(best)
			side = 1 - side
	else:
		# One per slice of the reading order, so the plan walks the spread instead of clustering.
		var seen := {}
		for k in want:
			var lo := int(floor(float(k) * float(n) / float(want)))
			var hi := int(floor(float(k + 1) * float(n) / float(want))) - 1
			var at := clampi(r.randi_range(lo, maxi(lo, hi)), 0, n - 1)
			seen[at] = true
		if _film_at >= 0:
			seen[_film_at] = true
		for i in n:                       # READING ORDER, and each panel at most once
			if seen.has(i):
				picked.append(i)
	if picked.is_empty():
		picked.append(0)
	# What catches the eye first: the film panel by preference (see FILM_FIRST), otherwise the biggest
	# panel on the sheet (the one a page designer sized to be looked at).
	var grab := -1
	if _film_at >= 0 and r.randf() < FILM_FIRST:
		grab = _film_at
	elif style == "grab":
		grab = _spread.largest_panel()
	if grab >= 0:
		# Erase then push, erase first so a grabber already in the plan moves to the front instead of
		# appearing twice; when it was not in the plan this adds one, so the result is trimmed back to the
		# sampled size below.
		picked.erase(grab)
		picked.push_front(grab)
	while picked.size() > want:
		picked.remove_at(picked.size() - 1)
	_plan = picked


func _pick_style(r: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in PLAN_STYLES:
		total += float(PLAN_STYLES[k])
	var pick := r.randf() * total
	for k in PLAN_STYLES:
		pick -= float(PLAN_STYLES[k])
		if pick <= 0.0:
			return String(k)
	return "read"


## Does this spread get a piece of footage, and if so which panel and which clip. Seeded off the spread,
## so a session replays the same footage in the same panels. A frequency of 0, or an empty library, leaves
## `_film_at` at -1 (no footage).
func _choose_film() -> void:
	_film_at = -1
	_film_clip = {}
	if _spread == null or Films.frequency() <= 0.0:
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash([feed.session_seed(), "film-spread", _spread_i])
	if r.randf() > Films.frequency():
		return
	var list := Films.clips()
	if list.is_empty():
		return
	var at := r.randi() % list.size()
	# Not the same clip twice running: with one film panel per spread and a small library the same clip
	# would land on consecutive spreads often enough to read as "that video again".
	if list.size() > 1 and String((list[at] as Dictionary).get("source", "")) == _film_prev:
		at = (at + 1) % list.size()
	_film_clip = list[at]
	_film_at = _best_panel_for(_film_clip, r)
	# Is there anything to play yet: a clip is prepared a window at a time (see Films.WINDOW), so the
	# window covering this moment may still be encoding. Asking starts that cut; not getting it back means
	# this spread goes without footage (an ordinary scene, not a blank rectangle), so film appears as often
	# as the machine can prepare it.
	if not Films.warm(_film_clip, maxf(feed.show_time(), 0.0)):
		_film_clip = {}
		_film_at = -1
		return
	_film_prev = String(_film_clip.get("source", ""))


## Which panel suits this clip's shape. Footage covers its panel, so the spare axis is cropped off (a
## 16:9 clip in a 0.45-aspect panel loses three quarters of its width): the film goes in the panel
## closest to the clip's own shape. Compared in log space (aspect is a ratio). Falls back to a plain
## random panel when the clip's shape is unknown (see Films.aspect_of).
func _best_panel_for(clip: Dictionary, r: RandomNumberGenerator) -> int:
	var n := _spread.panels.size()
	var want := Films.aspect_of(clip)
	if want <= 0.0 or n <= 1:
		return r.randi() % maxi(n, 1)
	return _spread.nearest_aspect(want)


## One queued panel per frame. See _turn_spread.
func _cast_one() -> void:
	if _to_cast.is_empty():
		return
	_cast_panel(int(_to_cast.pop_front()))


func _cast_panel(i: int) -> void:
	if _spread == null or i < 0 or i >= _cast.size():
		return
	if _cast[i] != null and is_instance_valid(_cast[i]):
		return
	var vp := _open_slot(i, _panel_px_for(i))
	# Footage, where the spread called for it. Cast directly rather than through the Director: a film is not
	# in the catalog (see FilmScene), since a scene that exists only when something was imported would make
	# the running order depend on the library.
	if i == _film_at and not _film_clip.is_empty():
		var film := FilmScene.new()
		film.feed = feed
		film.set_clip(_film_clip, maxf(feed.show_time(), 0.0))
		film.init_with_seed(hash([_spread_i, i, "film"]), "static")
		film.scene_name = "film"
		vp.add_child(film)
		_cast[i] = film
		return
	# The salt is the panel index, so the spread's panels are separate draws off the novelty scheduler (the
	# Director's clock has not moved between them, see Director.mint_scene). Quiet for every panel but the
	# one being read: casting a spread is one change of scene, not a dozen.
	var sc := feed.mint_scene(hash([_spread_i, i]) & 0xFFFF, i != _read)
	vp.add_child(sc)
	_cast[i] = sc


## Size a panel's render target to its aspect and start it running.
##
## Sized by height, because the camera is fitted by height (see ComicCamera._fit): a panel spans the frame
## vertically, so its target wants about the stage's height and its width follows from its aspect (constant
## area overshoots at the tall end: a 0.44-aspect panel half again taller than the screen, 2.3x the pixels).
##
## Every panel is sized by how big it is on screen, not by how big a panel can ever be: the cost that
## matters is total pixels, and twelve full-size targets redrawn every frame, when eleven occupy a few
## hundred pixels of the picture, is what made playing every scene unaffordable. A panel gets the
## resolution its place in the shot asks for and is re-opened larger when the camera comes to it.
func _open_slot(i: int, px := -1) -> SubViewport:
	var vp: SubViewport = _slots[_pool * POOL + i]
	var a := _spread.panel_aspect(i)
	var h := px if px > 0 else _panel_px
	var w := int(round(float(h) * a))
	var want := Vector2i(maxi(SLOT_IDLE, w), maxi(SLOT_IDLE, h))
	# Only ever grow within a spread: shrinking a live target throws away the picture and the panel flashes;
	# the pool is reset to SLOT_IDLE when the spread turns (see advance), when nothing reads from it.
	if want.x > vp.size.x or want.y > vp.size.y:
		vp.size = Vector2i(maxi(want.x, vp.size.x), maxi(want.y, vp.size.y))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.process_mode = Node.PROCESS_MODE_INHERIT
	return vp


## The resolution panel [param i] earns in the shot on screen now: its drawn height in pixels, with a floor
## so a panel in the far distance is still a picture and a ceiling at the full target so the one being read
## is as sharp as the medium can make it. This is also the pixelation answer: a panel rasterizes into its
## target and is textured onto the paper, so a shot tighter than the target magnifies a bitmap, and
## re-opening the focal panel at the resolution the camera asks for removes that at no cost to the rest.
func _panel_px_for(i: int) -> int:
	var r := _camera.panel_rect(i)
	var on_screen := maxf(r.size.y, r.size.x / maxf(_spread.panel_aspect(i), 0.01))
	# The panel being read may exceed `_panel_px`, up to the hard ceiling: that constant budgets a whole
	# spread of targets, and applying it to the one panel filling the frame left a tight shot magnifying its
	# own bitmap (1.21x on a push-in). A live scene can be drawn at any resolution; it has to be asked for one.
	var ceiling := PANEL_MAX if (i == _read or i == _film_at) else _panel_px
	return clampi(int(round(on_screen * PANEL_OVERSAMPLE)), SLOT_IDLE, ceiling)


## Stop a viewport without clearing it: the render target keeps its last frame. The order matters - stop
## first, free second - or the target repaints itself empty on the frame between the two.
func _freeze(vp: SubViewport) -> void:
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.process_mode = Node.PROCESS_MODE_DISABLED


func _resume(vp: SubViewport) -> void:
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.process_mode = Node.PROCESS_MODE_INHERIT


## Stop a viewport and release the scene inside it, keeping the picture it last drew.
func _blank(vp: SubViewport) -> void:
	_freeze(vp)
	for c in vp.get_children():
		c.queue_free()


# --- liveness ----------------------------------------------------------------

## Every panel you can see is moving, and no panel you cannot see costs anything. A dozen live scenes do not
## run (the stage governor spends its whole budget on one), so liveness follows the camera: at the reading
## distance one panel fills the frame and its neighbors crowd the edges, so one to three panels are on
## screen; the rest are stopped render targets holding their last frame and resume when the camera comes
## back. LIVE_MAX is the hard bound, ordered by distance from the panel being read.
func _update_liveness() -> void:
	if _spread == null:
		return
	var frame := Rect2(Vector2.ZERO, _stage_size).grow(_stage_size.x * 0.06)
	var mid := _stage_size * 0.5
	var want: Array = []
	for i in _cast.size():
		if _cast[i] == null or not is_instance_valid(_cast[i]):
			continue
		# A panel below its warm-up is wanted wherever it is: it has no picture yet, so leaving it out makes
		# it black, and the camera reaches most of the sheet eventually.
		var cold: bool = int(_warm[i]) < WARM_FRAMES
		var rect := _camera.panel_rect(i)
		if i != _read and not cold and not rect.intersects(frame):
			continue
		# Distance on the screen, not in the panel array: a spread's array is two contiguous blocks (the left
		# page's panels, then the right's), so ranking by index distance ranks by page and leaves a whole
		# page frozen however much of it is in shot. Screen distance keeps alive whatever is nearest the
		# middle of the picture.
		var d := rect.get_center().distance_to(mid) if i != _read else -1.0
		want.append({"i": i, "d": d, "cold": 0 if cold else 1})
	# Need first, distance second: until every panel has drawn its moment the budget goes to those that have
	# not; after that it follows what is in the middle of the shot.
	want.sort_custom(func(a, b):
		return int(a.cold) < int(b.cold) if int(a.cold) != int(b.cold) else float(a.d) < float(b.d))
	var budget := _live_budget()
	# The panel being read is always live, and so is the film: reserved before the budget is spent, not
	# merely sorted to the front. The sort puts every cold panel ahead of every warm one, and a page turn
	# casts a whole spread at once, so three cold panels would fill the whole LIVE_MAX and freeze the panel
	# the camera is looking at (the Director's own current scene) until the newcomers warmed.
	var keep: Array = []
	if _read >= 0 and _read < _cast.size() and _cast[_read] != null \
			and is_instance_valid(_cast[_read]):
		keep.append(_read)
	if _film_at >= 0 and _film_at != _read and _film_at < _cast.size() \
			and _cast[_film_at] != null and is_instance_valid(_cast[_film_at]):
		keep.append(_film_at)
	for e in want:
		if keep.size() >= budget:
			break
		if not keep.has(int(e.i)):
			keep.append(int(e.i))
	_frame += 1
	for i in _cast.size():
		if _cast[i] == null or not is_instance_valid(_cast[i]):
			continue
		var vp: SubViewport = _slots[_pool * POOL + i]
		# On this frame at all, and is it this one's turn? The read panel's turn is every frame; the others
		# are phased against each other by index so two never land on the same frame. The film panel is
		# exempt from the off-focal phasing (half the samples reads as broken playback on footage). A cold
		# panel runs every frame it is kept, phasing included. The phasing lifts on an export too, as there
		# is nothing to buy with it there.
		var every := budget >= POOL
		var on: bool = keep.has(i) and (every or i == _read or i == _film_at
			or int(_warm[i]) < WARM_FRAMES or (_frame + i) % OFF_FOCAL_PERIOD == 0)
		if on:
			_warm[i] = int(_warm[i]) + 1
			# Grow into the shot: a panel cast while small keeps that target until the camera comes to it;
			# re-opening in REOPEN_STEP jumps keeps a push-in to a handful of reallocations.
			var px := _panel_px_for(i)
			if px > vp.size.y and (i == _read or i == _film_at
					or float(px) > float(vp.size.y) * REOPEN_STEP):
				_open_slot(i, px)
			_resume(vp)
		else:
			_freeze(vp)
	_live = keep


## How many panels may run this frame. See LIVE_ALL_ON_EXPORT: the real-time budget, or none when there is
## no frame deadline. Asked of the command line rather than of main, because a medium is built before main
## has finished deciding anything and must not reach up into it.
func _live_budget() -> int:
	if LIVE_ALL_ON_EXPORT and OS.get_cmdline_user_args().has("--export"):
		return POOL
	return LIVE_MAX


## Drive every live panel except the one being read: the Director drives that one as its current scene, and
## ticking it twice would run it at double speed. The same pair of calls Director._tick_animation makes.
func _tick_cast(features, delta: float) -> void:
	var focal := _focal()
	var dt := minf(delta, 1.0 / 30.0)
	for i in _live:
		var sc = _cast[i]
		if sc == null or not is_instance_valid(sc) or sc == focal:
			continue
		# The film panel runs every frame (period 1) - see _update_liveness.
		var period := 1 if (_live_budget() >= POOL or i == _film_at
			or int(_warm[i]) < WARM_FRAMES) else OFF_FOCAL_PERIOD
		if (_frame + i) % period != 0:
			continue                      # not this panel's frame - see OFF_FOCAL_PERIOD
		# ...and when it is its frame, it is handed the whole period's worth of time, so it runs at the right
		# speed rather than 1/period of it.
		sc.update(features, dt * period)
		sc.view.commit(dt * period)


# --- what the probes read ----------------------------------------------------

## How much of the frame the sheet covers, 1.0 when it is paper to every corner. See
## [method ComicCamera.page_coverage]; read by tests/media/comic_look_probe.gd.
func page_coverage() -> float:
	return _camera.page_coverage()


## How much of the frame the panel being read takes up, on its worst axis. See
## [method ComicCamera.read_panel_fit].
func read_panel_fit() -> float:
	return _camera.read_panel_fit()


## Why the current shot is framed where it is, for the look probe. See
## [method ComicCamera.shot_debug].
func shot_debug() -> String:
	return _camera.shot_debug()


## How many screen pixels the read panel covers per texel of its render target: 1 is 1:1; above 1 the
## panel's bitmap is being magnified and will look soft or blocky. A panel is rasterized into its own
## SubViewport at a fixed size and mapped onto a quad as a texture (what makes a held panel free), which
## is also why a tight shot can pixelate: it resamples a bitmap, as it would a video.
func read_panel_magnification() -> float:
	if _spread == null or _read < 0 or _read >= _spread.panels.size():
		return 0.0
	var vp: SubViewport = _slots[_pool * POOL + _read]
	var th := maxf(float(vp.size.y), 1.0)
	return read_panel_fit() * _stage_size.y / th


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if _spread == null:
		return
	var u := minf(_stage_size.x, _stage_size.y)
	var origin := _stage_size * 0.5
	# The bookend belongs to the medium here (see Medium.owns_bookend): the whole spread fades, paper and all.
	modulate.a = 1.0
	var fade := clampf(_bookend, 0.0, 1.0)
	var att := _camera.att_basis       # the sheet's attitude, which every flat page is placed by
	_backdrop(fade)          # once per frame, under everything, including through a turn

	# A page turn, as a real leaf on a real spine. The right-hand page of the outgoing spread swings left
	# about the spine. Its front is that page; past the halfway point (the leaf edge-on, so the swap cannot
	# be seen) its back is the incoming spread's left page, mirrored about the spine so that at a half turn
	# it lands where that page is about to be drawn flat. Nothing cross-dissolves or jumps.
	#
	# Under it: the incoming right page, revealed as the leaf lifts off it, and the outgoing left page,
	# covered as the leaf comes down on it. Painter's order: both flat pages first, the leaf over them.
	if _turn_t >= 0.0 and _prev != null:
		var k := smoothstep(0.0, 1.0, clampf(_turn_t / TURN_TIME, 0.0, 1.0))
		var th := k * TURN_ARC
		_draw_leaf(_spread, 1, _pool, _is_cast, att, u, origin, fade, false)
		_draw_leaf(_prev, 0, 1 - _pool, _all_drawn, att, u, origin, fade, false)
		var hinge := att * Basis(Vector3.UP, -th)
		if th < TURN_ARC * 0.5:
			_draw_leaf(_prev, 1, 1 - _pool, _all_drawn, hinge, u, origin, fade, false)
		else:
			_draw_leaf(_spread, 0, _pool, _is_cast, hinge, u, origin, fade, true)
		return
	_draw_leaf(_spread, 0, _pool, _is_cast, att, u, origin, fade, false)
	_draw_leaf(_spread, 1, _pool, _is_cast, att, u, origin, fade, false)


## Has panel [param i] of the current spread been cast yet? (See _turn_spread's queue.)
func _is_cast(i: int) -> bool:
	return i < _cast.size() and _cast[i] != null and is_instance_valid(_cast[i]) \
		and i < _warm.size() and int(_warm[i]) >= FIRST_DRAW


## Every panel of the spread turning away carries a picture: it was fully cast before the turn started, and
## stopping its viewports kept what they had drawn.
func _all_drawn(_i: int) -> bool:
	return true


## One page of [param sp], the unit a leaf turns and everything draws in. [param side] is 0 for the left
## page and 1 for the right.
##
## [param m] is the full placement transform (see [method ComicSpread.world]): the sheet's attitude for a
## page lying flat, or that times the hinge rotation for the leaf in the air. [param mirror] reflects about
## the spine, which is how the leaf's back face draws the page printed on it.
##
## [param drawn] says which panels carry a picture: for the spread being read, "has this one been cast yet"
## (the queue casts one per frame, so a late panel is blank paper for the first few frames); for the spread
## turning away, every panel.
func _draw_leaf(sp: ComicSpread, side: int, pool: int, drawn: Callable, m: Basis,
		u: float, origin: Vector2, fade: float, mirror: bool) -> void:
	if fade <= 0.003 or sp == null:
		return
	var paper := Color(_paper.r, _paper.g, _paper.b, fade)
	var ink := Color(_ink.r, _ink.g, _ink.b, fade)
	# The sheet's shadow on the surface under it, before the sheet itself.
	_shadow_quad(sp, side, m, u, origin, fade, mirror)
	# The paper, subdivided so its gradient is per-vertex and a steeply raked page shades smoothly.
	_paper_quad(sp, side, m, u, origin, paper, mirror)
	# The panels: coplanar and never overlapping, so reading order is the order, which is also what the ink
	# wants (a canted panel's border must sit over its neighbor's paper).
	var on_page := sp.page_panels(side)
	for i in on_page:
		if bool(drawn.call(i)):
			_panel_quad(sp, int(i), pool, m, u, origin, fade, mirror)
	for i in on_page:
		_panel_ink(sp, int(i), m, u, origin, paper, ink, bool(drawn.call(i)), mirror)


## The surface the sheet lies on: a vignetted wash over the whole frame, painted first (see DESK_VIGNETTE).
func _backdrop(fade: float) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var n := 6
	for j in n + 1:
		for i in n + 1:
			var fu := float(i) / float(n)
			var fv := float(j) / float(n)
			pts.append(Vector2(fu * _stage_size.x, fv * _stage_size.y))
			var d := Vector2(fu - 0.5, fv - 0.5).length() / 0.707
			var k := lerpf(1.0, 1.0 - DESK_VIGNETTE, clampf(d * d, 0.0, 1.0))
			cols.append(Color(_desk.r * k, _desk.g * k, _desk.b * k, fade))
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			idx.append_array([a, a + 1, a + n + 2, a, a + n + 2, a + n + 1])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)


## One page's shadow on that surface - its outline, offset and pushed back. It makes the paper read as an
## object lying on something, and on the leaf it says the page has lifted.
func _shadow_quad(sp: ComicSpread, side: int, m: Basis, u: float, origin: Vector2,
		fade: float, mirror: bool) -> void:
	var lens := _camera.lens
	var poly := PackedVector2Array()
	for p in sp.page_corners(side):
		var q: Vector2 = p + Vector2(SHADOW_OFF.x, SHADOW_OFF.y * sp.aspect)
		var pr := lens.project(sp.world(q, m, mirror, SHADOW_DEPTH))
		if pr.z <= lens.near:
			return
		poly.append(Vector2(pr.x, pr.y) * u + origin)
	if _poly_area(poly) < 1.0:
		return
	draw_colored_polygon(poly, Color(0.0, 0.0, 0.0, 0.42 * fade))


## The page itself: a subdivided quad with a gentle darkening toward the edges (flat white reads as a blank
## canvas; a whisper of a gradient reads as a printed sheet).
func _paper_quad(sp: ComicSpread, side: int, m: Basis, u: float, origin: Vector2,
		paper: Color, mirror: bool) -> void:
	var lens := _camera.lens
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var ok := []
	var n := PAPER_GRID
	var x0 := float(side)
	for j in n + 1:
		for i in n + 1:
			var fu := float(i) / float(n)
			var fv := float(j) / float(n)
			var pr := lens.project(sp.world(Vector2(x0 + fu, fv * sp.aspect), m, mirror))
			var good := pr.z > lens.near
			ok.append(good)
			pts.append((Vector2(pr.x, pr.y) * u + origin) if good else Vector2.ZERO)
			# radial falloff from the sheet's center, at a few percent
			var d := Vector2(fu - 0.5, fv - 0.5).length() / 0.707
			var kk := 1.0 - 0.10 * d * d
			cols.append(Color(paper.r * kk, paper.g * kk, paper.b * kk, paper.a))
	var idx := _cells(ok, n)
	if idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)


## Index the cells of an (n+1)x(n+1) vertex grid, skipping any cell with a vertex behind the eye (abandoning
## the whole surface at one vertex would make a page vanish for a second at a rake, since the spread's far
## corners go behind the eye at otherwise good framings). Returns the buffer rather than filling one handed
## in: a PackedInt32Array is a value type, so a callee appending to a parameter appends to its own copy.
func _cells(ok: Array, n: int) -> PackedInt32Array:
	var idx := PackedInt32Array()
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + n + 1
			var d := a + n + 2
			if bool(ok[a]) and bool(ok[b]) and bool(ok[c]) and bool(ok[d]):
				idx.append_array([a, b, d, a, d, c])
	return idx


## One panel's picture: its render target mapped onto a grid-subdivided quad whose every vertex is
## projected individually. Two triangles would be affine and warp (28.5 px on a 512 px frame, measured in
## tests/media/medium_probe.gd); subdivision makes the mapping piecewise-perspective.
func _panel_quad(sp: ComicSpread, i: int, pool: int, m: Basis,
		u: float, origin: Vector2, fade: float, mirror: bool) -> void:
	var lens := _camera.lens
	var vp: SubViewport = _slots[pool * POOL + i]
	var rid := vp.get_texture().get_rid()
	if not rid.is_valid():
		return
	# Half a texel in, on every side: UVs of exactly 0 and 1 sample the outermost texel's edge, where the
	# bilinear filter reaches for a neighbor that is not there (a stray fringe along the bottom rule).
	var tw := maxf(float(vp.size.x), 1.0)
	var th := maxf(float(vp.size.y), 1.0)
	var inset := Vector2(0.5 / tw, 0.5 / th)
	var n := _grid_for(sp, i, m, u, origin, mirror)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var ok := []
	var col := Color(1, 1, 1, fade)
	for jj in n + 1:
		for ii in n + 1:
			var uv := Vector2(float(ii) / float(n), float(jj) / float(n))
			var pr := lens.project(sp.world(sp.panel_point(i, uv), m, mirror))
			var good := pr.z > lens.near
			ok.append(good)
			pts.append((Vector2(pr.x, pr.y) * u + origin) if good else Vector2.ZERO)
			# The UV is not mirrored: reflecting the page about the spine reflects where the panel is, never
			# what is printed in it (the leaf's back is a page seen from the front).
			uvs.append(inset + uv * (Vector2.ONE - inset * 2.0))
			cols.append(col)
	var idx := _cells(ok, n)
	if idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(
		get_canvas_item(), idx, pts, cols, uvs,
		PackedInt32Array(), PackedFloat32Array(), rid)


## How finely to subdivide this panel's grid: enough cells that each is about CELL_PX across on screen,
## measured off the panel's own projected size.
func _grid_for(sp: ComicSpread, i: int, m: Basis, u: float, origin: Vector2,
		mirror: bool) -> int:
	var lens := _camera.lens
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var wraps := false
	for uv in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var pr := lens.project(sp.world(sp.panel_point(i, uv), m, mirror))
		if pr.z <= lens.near:
			wraps = true
			continue
		var p := Vector2(pr.x, pr.y) * u + origin
		lo = lo.min(p)
		hi = hi.max(p)
	if wraps:
		# A corner behind the eye makes the panel unboundedly large on screen, so the projected span says
		# nothing: size it to the screen instead (a cell is never usefully finer than the frame).
		return clampi(int(ceil(maxf(_stage_size.x, _stage_size.y) / CELL_PX)),
			GRID_MIN, GRID_MAX)
	var span := maxf(hi.x - lo.x, hi.y - lo.y)
	return clampi(int(ceil(span / CELL_PX)), GRID_MIN, GRID_MAX)


## The gutter side of a panel: paper painted back over the square corners the rounded outline cuts off,
## then the ink border on top. Rounding this way rather than clipping the texture is exact under
## perspective: the corner wedges are computed in spread space and projected like every other point on the
## sheet.
func _panel_ink(sp: ComicSpread, i: int, m: Basis, u: float, origin: Vector2,
		paper: Color, ink: Color, filled: bool, mirror: bool) -> void:
	if sp.radius > 0.0004 and filled:
		for w in _corner_wedges(sp, i, m, u, origin, mirror):
			var poly: PackedVector2Array = w
			# A wedge below a pixel is skipped: the canvas triangulator rejects it outright (an error per
			# corner per panel per frame); same guard as Plane3D.
			if poly.size() >= 3 and _poly_area(poly) >= 1.0:
				draw_colored_polygon(poly, paper)
	# An unfilled panel is drawn as an empty ruled frame (the panels ahead of the story are not inked in
	# yet), lighter so it reads as ruled rather than a black hole.
	var line := ink if filled else Color(ink.r, ink.g, ink.b, ink.a * 0.35)
	# The border is drawn in runs: a rule with one point behind the eye would abandon the whole outline, so
	# the visible part is drawn and only what cannot be projected is dropped.
	for run in _rounded_runs(sp, i, m, u, origin, mirror):
		var pts: PackedVector2Array = run
		if pts.size() >= 2:
			draw_polyline(pts, line, _ink_width(), true)


## Comic rules are chunky (a hairline reads as a UI border around a video), scaled off the shorter screen
## axis so the weight is the same at 720p and 4K, and sampled per session in a narrow band.
## Twice the signed area of a polygon, absolute - the cheap "is this bigger than a pixel" test.
func _poly_area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q: Vector2 = p[i]
		var r: Vector2 = p[(i + 1) % p.size()]
		a += q.x * r.y - r.x * q.y
	return absf(a) * 0.5


func _ink_width() -> float:
	return maxf(1.5, minf(_stage_size.x, _stage_size.y) * _ink_weight)


## The panel's outline in screen space as runs of consecutive projectable points, corners rounded in spread
## space. A fully visible panel gives exactly one run, closed.
func _rounded_runs(sp: ComicSpread, i: int, m: Basis, u: float, origin: Vector2,
		mirror: bool) -> Array:
	var lens := _camera.lens
	var uv := _rounded_uv(sp, i)
	var scr := PackedVector2Array()
	var ok := []
	for p in uv:
		var pr := lens.project(sp.world(sp.panel_point(i, p), m, mirror))
		ok.append(pr.z > lens.near)
		scr.append(Vector2(pr.x, pr.y) * u + origin)
	var all := true
	for g in ok:
		if not bool(g):
			all = false
			break
	if all:
		var ring := scr.duplicate()
		ring.append(scr[0])
		return [ring]
	var out: Array = []
	var run := PackedVector2Array()
	for j in scr.size():
		if bool(ok[j]):
			run.append(scr[j])
		elif run.size() >= 2:
			out.append(run)
			run = PackedVector2Array()
		else:
			run = PackedVector2Array()
	if run.size() >= 2:
		out.append(run)
	return out


## The outline as points in the panel's own unit square. Radius is in units of the shorter side and
## converted per axis, so a wide panel's corners stay circular.
func _rounded_uv(sp: ComicSpread, i: int) -> PackedVector2Array:
	var r: Rect2 = sp.panels[i]["rect"]
	var short := minf(r.size.x, r.size.y)
	var rad := sp.radius * short
	var out := PackedVector2Array()
	if rad <= 0.0004:
		return PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var ru := rad / r.size.x
	var rv := rad / r.size.y
	# corner centers in uv, and the angle each arc sweeps from
	var arcs := [
		[Vector2(ru, rv), PI],
		[Vector2(1.0 - ru, rv), -PI * 0.5],
		[Vector2(1.0 - ru, 1.0 - rv), 0.0],
		[Vector2(ru, 1.0 - rv), PI * 0.5],
	]
	for a in arcs:
		var c: Vector2 = a[0]
		var start: float = a[1]
		for s in CORNER_SEGS + 1:
			var ang := start + (PI * 0.5) * float(s) / float(CORNER_SEGS)
			out.append(c + Vector2(cos(ang) * ru, sin(ang) * rv))
	return out


## The four corner cut-offs in screen space - the area between the square corner and the arc, painted back
## in paper so the picture stops at the rounded edge.
func _corner_wedges(sp: ComicSpread, i: int, m: Basis, u: float, origin: Vector2,
		mirror: bool) -> Array:
	var lens := _camera.lens
	var r: Rect2 = sp.panels[i]["rect"]
	var short := minf(r.size.x, r.size.y)
	var rad := sp.radius * short
	var ru := rad / r.size.x
	var rv := rad / r.size.y
	var specs := [
		[Vector2(0, 0), Vector2(ru, rv), PI],
		[Vector2(1, 0), Vector2(1.0 - ru, rv), -PI * 0.5],
		[Vector2(1, 1), Vector2(1.0 - ru, 1.0 - rv), 0.0],
		[Vector2(0, 1), Vector2(ru, 1.0 - rv), PI * 0.5],
	]
	var out: Array = []
	for sp_i in specs:
		var corner: Vector2 = sp_i[0]
		var c: Vector2 = sp_i[1]
		var start: float = sp_i[2]
		var uv := PackedVector2Array([corner])
		for s in CORNER_SEGS + 1:
			var ang := start + (PI * 0.5) * float(s) / float(CORNER_SEGS)
			uv.append(c + Vector2(cos(ang) * ru, sin(ang) * rv))
		var scr := PackedVector2Array()
		var ok := true
		for p in uv:
			var pr := lens.project(sp.world(sp.panel_point(i, p), m, mirror))
			if pr.z <= lens.near:
				ok = false
				break
			scr.append(Vector2(pr.x, pr.y) * u + origin)
		if ok:
			out.append(scr)
	return out
