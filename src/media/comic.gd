extends Medium
class_name ComicMedium

## ComicMedium - the show as an open comic book, flown over by a real perspective camera.
##
## The same scenes, the same Director, the same cutting. What changes is where a scene
## LANDS: instead of replacing the picture, each cut fills the next PANEL of the spread, and
## when the spread is full the next cut turns the leaf. So `Scene hold` and `Flourishes`
## keep their exact meanings - a burst of quick cuts becomes a run of small panels filling in
## fast, which is what a comic does with a fight.
##
## TWO PAGES AT ONCE, because that is what a comic is. The first cut of this drew ONE
## portrait page and it cost three things at the same time. A portrait sheet inside a
## landscape frame cannot cover it, so there was always a wedge of desk in shot unless the
## camera pushed in until the page stopped reading as a page. A pan had one page's width of
## content to travel before it ran onto the trim edge. And a page turn had no hinge that
## meant anything, because a leaf hinges on a SPINE and one page does not have one. See
## [ComicSpread]: the spread is 2 pages wide by ~1.5 tall, which is 1.33 against the frame's
## 1.78, so the sheet can cover the whole frame at a shot that still shows several panels.
##
## ONE LIVE PANEL, THE REST HELD. The Director runs exactly one scene (two across a
## transition) and this keeps that: the newest panel is live in its own SubViewport, and
## every panel behind it is a STOPPED render target - update mode DISABLED, its scene
## freed, its last frame still sitting in VRAM. Measured in tests/media/medium_probe.gd: the
## texture survives both the stop and the free, bit-exact, so a held panel costs nothing
## at all. That is the only reason this can ship. Six live scenes is not a thing that
## runs - the stage governor already spends its budget on one - and the alternative,
## capturing each panel with get_image(), is the synchronous readback stall that cost
## Masking its frame rate.
##
## It is also simply correct. A comic panel IS a held moment; the page is a sequence of
## them. The frame is never static anyway, because the camera and the page are always
## moving.
##
## THE SPREAD IS REALLY IN 3D. Not a sheared 2D plane faking depth - two quads placed in a
## world and projected through a [Lens3D], free to rotate on X, Y and Z at once. Panels
## are drawn as SUBDIVIDED grids of textured triangles whose vertices are each projected
## individually, because a two-triangle quad is affinely textured and warps: measured at
## a hard yaw, the seam of a two-tone test texture landed 28.5 px away from where
## perspective puts it, on a 512 px frame.
##
## THE CAMERA IS A PART OF ITS OWN, [ComicCamera]: the shots, the follower and the lens this
## draws through. What is here is the BOOK - the spread, its plan, its cast and its panels'
## render targets - and the drawing; where a point lies on the sheet is [ComicSpread]'s.

## How many panel slots exist. Two POOLS of [constant ComicSpread.MAX_PANELS], alternating
## per spread, because a page turn shows both spreads at once - reusing one pool would pull
## the outgoing spread's pictures out from under it mid-turn. All FOUR half-pages carry
## textures during a turn (the old left page under the leaf, the old right page on the
## leaf's front, the new left page on its back, the new right page revealed beneath), which
## is why a pool is a whole spread and not a page.
const POOL := ComicSpread.MAX_PANELS

## Panel render-target size, as a fraction of the stage's shorter side. A panel is sampled
## at close to 1:1 in the tight reading shot (which frames roughly one panel), so this is
## about right and not a guess; it is clamped below so a small window still gets a legible
## panel and above so a 4K export does not allocate enormous targets.
const PANEL_SCALE := 1.0
const PANEL_MIN := 224
const PANEL_MAX := 1400
## What an unopened slot is sized to. There are 24 of them now and a spread opens at most
## half; allocating every one at PANEL_SCALE up front - which is what the first cut did -
## reserved a full-size render target for a panel no page had. Sixty-four squared is
## 16 KiB, and _open_slot grows the slot to its real size before anything draws it.
const SLOT_IDLE := 64

## Subdivision of a panel's textured grid, chosen so each cell is about this many pixels on
## screen, between these bounds.
##
## ADAPTIVE, because a fixed number cannot be right. Inside one cell the texture mapping is
## affine while the true mapping is projective, so the error scales with how big the cell is
## ON SCREEN and with how hard the panel is raked. A fixed 8 was measured sufficient at one
## yaw on a 512 px frame, and this medium now puts a single panel across a whole 1280 px
## frame at a much harder rake. Sizing the CELL rather than the count bounds the error
## directly, at any framing.
##
## NOT the fix for the banding reported on fractal_zoom - that was checked, and going from 8
## to an adaptive 6-40 changed those frames not at all. Those bands are the scene's own
## float32 precision blocks, which the close framing here simply magnifies. This is a
## correctness change made because the reasoning behind the old constant no longer held, not
## a repair of anything observed.
const CELL_PX := 56.0
const GRID_MIN := 6
const GRID_MAX := 40
## Subdivision of the paper quad. It carries only a slow gradient, so it needs far less.
const PAPER_GRID := 4
## Segments per rounded corner.
const CORNER_SEGS := 5


## HOW MANY PANELS MAY RUN AT ONCE. See [method _update_liveness]: everything on screen
## moves, and the budget is what keeps that affordable. Three covers the panel being read
## plus the neighbors crowding the frame edges at the reading distance. NOT raised for the
## spread even though a wider shot puts more panels in frame - the shot is wider, so each
## panel is smaller, and the budget is about scene cost rather than about screen area.
const LIVE_MAX := POOL

## ...AND THE BUDGET DOES NOT APPLY TO AN EXPORT. Every panel runs.
##
## LIVE_MAX is a REAL-TIME concession: the show has sixteen milliseconds to draw a frame, and a
## dozen simultaneous scenes do not fit in them. An export has no such deadline - it renders
## offline, one frame at a time, and a frame that takes a second costs a second of somebody's
## afternoon rather than a stutter. Spending the budget there buys nothing and costs the thing
## the medium is for: "you're optimizing for real-time, but we are cutting videos. So we can
## just play every scene, and we should. Freezing them looks terrible."
##
## Quite right, and it is also why the frozen panels read so much worse than they used to. On a
## single page of three to six the held ones were mostly off shot; a spread of nine to twelve
## seen wide puts most of the page in frame at once, so the budget's leftovers are no longer at
## the edges - they are the picture.
const LIVE_ALL_ON_EXPORT := true

## How often a live panel that is NOT the one being read repaints, in frames.
##
## Everything visible moves - but the panel being READ is the one anyone is looking at, and
## a background moment does not need the same temporal resolution as the foreground. Every
## other frame is invisible on a panel at the edge of shot, because those panels are ticked
## with a matching multiple of the step, so they run at the RIGHT SPEED with half the
## samples rather than in slow motion.
##
## Measured on one seed against the same scenes: it and the height-based target sizing took
## the comic's active frame from 84 ms to 73 against the full frame's 41. So three live
## panels cost about 1.8x one, not 3x - the rest of the gap is the stage governor's to
## absorb, which is what it is for.
const OFF_FOCAL_PERIOD := 2
## How many render-target pixels a panel gets per pixel it covers on screen. Above 1 so a panel
## the camera is drifting toward is already sharp before it is the subject, and so the paper's
## own perspective foreshortening does not read as a soft panel.
const PANEL_OVERSAMPLE := 1.35
## How much bigger a panel has to want to be before its target is re-opened, as a ratio. A
## target that chases the shot pixel for pixel reallocates every frame; this makes it a handful
## of steps across a whole push-in.
const REOPEN_STEP := 1.5

## HOW MANY FRAMES A PANEL MUST ACTUALLY RENDER before it is allowed to be frozen.
##
## THIS IS WHAT "4 OF THE 6 FRAMES ARE PURE BLACK, AND EMPTY" WAS, and the freeze mechanism
## was working perfectly the whole time. A held panel keeps the last picture it DREW - that is
## the measured invariant the whole medium rests on (tests/media/medium_probe.gd) - and a panel
## that was cast, given two frames, and frozen has a last picture that is two frames of an
## empty scene. Which is black. Nothing culled it; it was preserved exactly as found.
##
## It only became visible with the spread. A page of three to six panels, read close, kept
## nearly all of them inside the liveness budget long enough to fill in. A spread of nine to
## twelve with the same budget of three, and a reading plan that never visits most of them,
## means a panel can be cast, glimpsed and frozen having drawn nothing at all - including the
## film panel, whose player is still opening its window in those first frames. Reported as
## "the video with the girl WAS playing, but now it's black. It's like the frame got culled."
##
## So liveness is now ordered by NEED first and distance second: a panel below its warm-up
## takes priority over one that has already drawn its moment, and only once every panel on the
## sheet has a picture does the budget go back to following the camera. Twenty-four frames is
## about four tenths of a second - enough for a scene to lay down its first pass and for a
## video window to hand over its first decoded frame.
const WARM_FRAMES := 24

## HOW MANY FRAMES A PANEL MUST HAVE RENDERED BEFORE ITS TEXTURE MAY BE DRAWN.
##
## A SubViewport's render target is allocated by _open_slot and is not cleared - it holds
## whatever was in that piece of VRAM. Sampling it before the viewport has produced a frame
## therefore draws garbage, and the garbage on a freshly booted machine is the last thing the
## compositor had there: the application's own interface. Reported as "at first load, every
## single frame starts by showing the UI itself: all of the toggles, all of the options",
## replaced a moment later by the real scene - which is exactly what "one frame early" looks
## like.
##
## TWO, not one. _update_liveness raises the warm count in the same frame it resumes the
## viewport, and the viewport renders at the END of that frame, so a count of one means "asked
## to draw", not "has drawn". A panel below this is drawn as an empty ruled frame - which is
## already what the page does for a panel the story has not reached, so it costs nothing and
## looks like nothing.
const FIRST_DRAW := 2

## HOW MANY PANELS OF A SPREAD THE CAMERA ACTUALLY STOPS ON, before the leaf turns.
##
## NOT ALL OF THEM, and that is the correction. The reading used to walk every panel in order
## and turn only when it ran out - so a nine-panel spread was nine cuts, two and a half
## minutes of one sheet, and by the end the camera was hunting for somewhere it had not
## already been. Reported as "it feels like the camera tries to focus on EVERY frame before it
## transitions to the next spread. You wouldn't really expect that, since a lot of those
## frames are already shown during transitions, or during zoom-out."
##
## That is exactly right, and it is how a page is read: you take in the whole spread at a
## glance, rest on a few moments, and turn. The panels that are not rested on are not missing -
## they are drawn the entire time, and every pan across the sheet passes over them. So the
## spread now samples a PLAN of this many panels to settle on, in reading order, and turns
## when the plan is done. A denser spread gets a slightly longer plan, but never one per panel.
const FOCUS := Vector2i(3, 5)

## HOW A SPREAD GETS READ. Weighted, and the weights are the whole statement: mostly the way a
## page is read, sometimes not.
##
##   read  top-left, across, down and back, across, then the other page. The default, and it
##         should be, because it is what the eye does with a page it is actually reading.
##   grab  something catches the eye FIRST - the film panel if there is one, else the biggest
##         panel on the sheet - and the reading resumes in order afterwards. "There are times
##         when you would turn a page, and something on the RIGHT would catch your attention
##         first."
##   skim  left, right, left - a glance across the spread rather than a read of it. "There are
##         times when you may not read the pages at all."
##
## A HARD RULE WOULD BE WRONG, which is why this is a bag and not an if. Strict reading order
## every time is a machine indexing a page; the deviations are what make it read as someone
## looking at a comic. But they are deviations - six to one against - because the report was
## that the ping-ponging is the exception that had become the rule.
const PLAN_STYLES := {"read": 6.0, "grab": 2.0, "skim": 1.0}

## HOW STRONGLY A PIECE OF FOOTAGE PULLS THE EYE FIRST, as a probability that it opens the
## spread whatever style was rolled.
##
## "For most humans, an 'actual' human in a video is the first thing they want to look at,
## every time." That is right, and it is the one place this medium should not be even-handed:
## every other panel is an abstract field, and a face is not. Not 1.0 only because a spread
## that ALWAYS opens on the film is a rule the eye learns in two pages.
const FILM_FIRST := 0.72

## How long a page turn takes, in seconds.
const TURN_TIME := 1.15
## How far the leaf swings. A HALF TURN exactly, because at pi the leaf lies flat on the
## left page and its back face - the incoming left page, see [method ComicSpread.mirror] -
## lands precisely where that page is about to be drawn flat. Anything short of pi would
## have to cross-dissolve the difference.
const TURN_ARC := PI

## THE SPREAD LIES ON SOMETHING. Without it the frame past the trim edge is pure black,
## which at a hard rake is a wedge of nothing across the shot - and black is not a
## background, it is the absence of one.
##
## PAINTED IN SCREEN SPACE, not as a world quad. A surface big enough to never run out
## under a close raked camera has corners far outside the view frustum, and the projection
## has to drop any quad with a corner behind the eye (it inverts through infinity) - so the
## world-quad version simply never drew, at any of the sizes worth having. A defocused
## surface has no texture to rake anyway; what it needs to be is present and not black.
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
## The panels this spread will settle on, in reading order - see FOCUS. `_read` is one of
## these, and `_step` is how far through the plan the reading has got.
var _plan: Array = []
var _step := 0
var _to_cast: Array = []          # panels still waiting to be cast, one per frame
var _prev: ComicSpread = null     # the outgoing spread, alive only through a turn
var _turn_t := -1.0               # seconds into a page turn, < 0 when none

## WHICH PANEL OF THIS SPREAD HOLDS FOOTAGE, or -1 for none, and the clip it holds.
##
## AT MOST ONE PER SPREAD, which is the whole answer to a question that would otherwise need
## a mechanism. A clip's position is a pure function of the show clock (see
## [method Films.position_at]), so two panels sampling the same clip at the same instant
## would show the same picture twice - and the spread is what you see at once, so one per
## spread IS one at a time. During a turn the outgoing spread's panels are already stopped,
## so even then only one is playing.
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


## THE CAMERA, a part of its own ([ComicCamera]): the eye over the spread, the shots it takes and
## the lens the page is drawn through.
var _camera := ComicCamera.new()


func _init() -> void:
	_camera.medium = self


func mount(st: SubViewport) -> void:
	super.mount(st)
	# ...and belt to the half-texel inset's braces: never let a UV wrap even if one
	# escapes the inset. The default is already this; saying so is cheap and the failure
	# it prevents (the far edge of a panel bleeding in along the near one) is not obvious
	# to diagnose.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_size_targets(Vector2(st.size))
	_build_slots()


## Everything sampled, rolled here rather than in mount() because the session seed is not
## resolved until the Director attaches (see Medium.begin_session).
func begin_session() -> void:
	_rng.seed = feed.session_seed() ^ 0x0C031C
	# Paper is never pure white - a white page reads as a blank canvas rather than as
	# printed stock - and it is sampled, like everything else here.
	_paper = Color.from_hsv(_rng.randf_range(0.055, 0.11),
		_rng.randf_range(0.05, 0.13), _rng.randf_range(0.88, 0.95))
	# Ink is not black either. A cool near-black prints like ink; pure #000 prints like a
	# UI border.
	_ink = Color.from_hsv(_rng.randf_range(0.58, 0.72), _rng.randf_range(0.05, 0.20),
		_rng.randf_range(0.05, 0.13))
	# The surface the sheet lies on: dark enough that the paper is still the brightest thing
	# in the frame by a long way, but never black.
	_desk = Color.from_hsv(_rng.randf_range(0.02, 0.12), _rng.randf_range(0.10, 0.32),
		_rng.randf_range(0.055, 0.115))
	_ink_weight = _rng.randf_range(0.0030, 0.0052)
	_mod = ModBank.new(feed.session_seed() ^ 0x9A6E)
	_reset_book()
	_turn_spread(0)


## The session is over: let the book go, and open nothing.
##
## The medium OUTLIVES a session (main owns it; the synthesis modes re-attach per take), so
## release resets the BOOK rather than tearing the pool down - rebuilding twenty-four render
## targets on every settings change is exactly the reallocation churn main's governor warns
## about. IT DOES NOT TURN TO THE FIRST SPREAD, which it used to: that cast a panel at teardown
## - a scene minted through the Director, logged as a cut, its viewport left running - and main
## releases a medium twice as a note closes, the second time through a Director already detached,
## whose pick state the mint left set for the next note's first scene. [method begin_session]
## opens the next book (tests/media/comic_motion_check.gd, "a session's end makes nothing").
func release() -> void:
	_reset_book()


## A NEW BOOK: no spread, nothing planned, cast or turning, every panel let go (its viewport
## stopped, its picture kept), the liveness phase from zero and the camera put back
## ([method ComicCamera.reset]). Everything here that a session moves is put back, so a second
## attach on the same seed plays the first one's show (tests/media/comic_motion_check.gd, "a
## second attach").
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


## A window resize changes what a panel is worth in pixels, but NOTHING is resized here.
##
## A render target reallocated while it is being sampled is the black-triangle and
## color-noise corruption main's stage governor documents at length - and worse, a resize
## also throws away the held panels' pictures. So the new figure is remembered and applied
## at the next spread, where every target is repainted from scratch anyway.
func on_stage_resized(size: Vector2) -> void:
	_size_targets(size)
	queue_redraw()


func _size_targets(size: Vector2) -> void:
	_stage_size = size
	# A panel fills the frame at the reading distance, so it is worth close to the whole
	# short axis. Clamped below so a small window still gets a legible panel, and above so
	# a 4K export does not allocate twenty-four enormous targets.
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


## A Director cut MOVES THE READING to the next panel; it does not build anything. The
## panel already holds a live scene, cast when the spread turned.
func take_over(_outgoing: GhostScene) -> GhostScene:
	if _spread == null:
		return null
	if _step + 1 >= _plan.size():
		_turn_spread(_spread_i + 1)
	elif _spread_i >= 0:
		_step += 1
		_read = int(_plan[_step])
		_camera.begin_shot(_read)
	# CAST ON DEMAND. The rest of the spread is cast one panel per frame to keep the turn
	# from hitching, and a fast cut can reach a panel before its turn in that queue comes
	# up - which handed the Director a null and left the reading stuck on the panel behind.
	# _cast_panel is idempotent, so this only ever builds the one that was still owed.
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
			# THE OUTGOING SPREAD'S TARGETS ARE NOW DEAD. Nothing samples that pool again
			# until the next turn opens it, and _open_slot sizes a slot before anything
			# draws it - so this is the one safe moment to give the memory back. Skipping
			# it kept a full spread of full-size render targets alive for the whole of the
			# next spread, which is half the medium's VRAM doing nothing.
			for i in POOL:
				var vp: SubViewport = _slots[(1 - _pool) * POOL + i]
				if vp.size.x > SLOT_IDLE or vp.size.y > SLOT_IDLE:
					vp.size = Vector2i(SLOT_IDLE, SLOT_IDLE)
	_camera.advance(delta)
	_camera.prepare_lens()
	_update_liveness()
	_tick_cast(features, delta)
	queue_redraw()


## AudioFeatures is not a type this file should have to import to read one number off, and
## a medium must keep working when there is no audio at all (a note with no song, a songless boot),
## so this asks softly rather than declaring a dependency.
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
	# Let the outgoing spread's cast go, but NOT its pictures: _blank stops each viewport
	# before freeing what is inside it, so the spread turning away is still a drawn spread.
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
	# The panel being read is cast NOW - the show cannot open on an empty frame - and the
	# rest are queued one per frame. Building a dozen scenes in one frame is a visible
	# hitch, and there is nowhere to hide it; spread over the next few frames it lands under
	# the page turn, and any panel the camera reaches before its turn is cast on demand.

	_choose_film()               # BEFORE the plan: _roll_plan forces the film panel into it
	_roll_plan()
	_read = int(_plan[0]) if not _plan.is_empty() else 0
	_step = 0
	# EVERY PANEL EXCEPT THE ONE CAST BELOW. It used to be `range(1, n)`, which was correct
	# only while the reading always opened on panel 0. It does not any more - a spread picks a
	# PLAN and opens on `_plan[0]` (see _roll_plan) - so whenever that is not panel 0, panel 0
	# was queued by nobody and cast by nobody, and stayed an empty ruled frame for the whole
	# spread. Caught by the probe's per-panel line as `1[- - 0]` on a spread whose plan began
	# at panel 2, which is exactly the "empty frame" this pass exists to remove.
	_to_cast = []
	for i in _spread.panels.size():
		if i != _read:
			_to_cast.append(i)
	_cast_panel(_read)
	_camera.new_spread(_read)


## WHICH PANELS THIS SPREAD WILL SETTLE ON, in reading order. See FOCUS.
##
## Sampled, spread out, and it always includes the FILM PANEL when there is one - a piece of
## footage on the sheet is the one moment that is certainly worth stopping on, and leaving it
## to chance means importing a video and then watching the camera ignore it.
##
## Spaced by picking one panel from each of `want` equal SLICES of the reading order rather
## than by drawing indices at random. A random draw of four from nine clusters: it will
## happily pick panels 5, 6, 7 and 8 and leave the whole left page unvisited, which reads as
## the camera getting stuck in a corner of the sheet. One per slice guarantees the plan walks
## the spread, while the choice inside each slice keeps it from being the same four panels
## every time.
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
		# LEFT, RIGHT, LEFT - alternating pages, and the order is NOT sorted afterwards
		# because the alternation IS the gesture. Sorting it would turn a glance back into a
		# read, which is the one thing this style exists not to be.
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
		# ONE PER SLICE of the reading order, so the plan walks the spread instead of
		# clustering - a free draw of four from nine will happily take 5, 6, 7 and 8 and leave
		# the whole left page unvisited, which reads as the camera stuck in a corner.
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
	# WHAT CATCHES THE EYE FIRST. The film panel by preference (see FILM_FIRST), otherwise the
	# biggest panel on the sheet, which is the one a page designer sized to be looked at.
	var grab := -1
	if _film_at >= 0 and r.randf() < FILM_FIRST:
		grab = _film_at
	elif style == "grab":
		grab = _spread.largest_panel()
	if grab >= 0:
		# ERASE THEN PUSH, and erase FIRST so a grabber that was already in the plan moves to
		# the front instead of appearing twice. When it was not in the plan this adds one, so
		# the result is trimmed back to the sampled size below - a spread that rolled "three
		# panels" and then got a fourth for free is not the plan it rolled.
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


## DOES THIS SPREAD GET A PIECE OF FOOTAGE, and if so which panel and which clip.
##
## Seeded off the spread, like everything else here, so a session replays the same footage
## in the same panels - the show is reproducible from one seed and this is not the place
## to make it stop being. A frequency of 0, or a library with nothing in it, leaves
## `_film_at` at -1 and the comic behaves exactly as it did before films existed.
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
	# NOT THE SAME CLIP TWICE RUNNING. With one film panel per spread, a small library and
	# an independent draw per spread, the same clip lands on consecutive spreads often
	# enough to read as "that video again" rather than as a library.
	if list.size() > 1 and String((list[at] as Dictionary).get("source", "")) == _film_prev:
		at = (at + 1) % list.size()
	_film_clip = list[at]
	_film_at = _best_panel_for(_film_clip, r)
	# IS THERE ANYTHING TO PLAY YET. A clip is prepared a window at a time, cut from the
	# original when something wants it (see Films.WINDOW), so the window covering this
	# moment may still be encoding. Asking starts that cut; not getting it back means this
	# spread simply goes without footage, and the panel is an ordinary scene rather than a
	# blank rectangle waiting for a file. The whole feature self-throttles on this line -
	# film appears as often as the machine can prepare it.
	if not Films.warm(_film_clip, maxf(feed.show_time(), 0.0)):
		_film_clip = {}
		_film_at = -1
		return
	_film_prev = String(_film_clip.get("source", ""))


## WHICH PANEL SUITS THIS CLIP'S SHAPE. Footage covers its panel, so whichever axis is
## spare gets cropped off - a 16:9 clip in a 0.45-aspect panel loses three quarters of its
## width, and there is no framing clever enough to make that not matter. A spread offers
## twice as many shapes as a page did, so the answer is simply to put the film in the one
## closest to the clip's own, where the crop is a trim rather than a demolition.
##
## Compared in LOG space, because aspect is a ratio: 2.0 and 0.5 are equally wrong for a
## square clip, and subtracting them would call one of them nearly right.
##
## Falls back to a plain random panel when the clip's shape is unknown, which is the honest
## answer rather than a guess - see Films.aspect_of.
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
	# FOOTAGE, where the spread called for it. Cast directly rather than through the
	# Director: a film is not in the catalog (see FilmScene), because a scene that only
	# exists when the viewer has imported something would make the running order depend on
	# the library.
	if i == _film_at and not _film_clip.is_empty():
		var film := FilmScene.new()
		film.feed = feed
		film.set_clip(_film_clip, maxf(feed.show_time(), 0.0))
		film.init_with_seed(hash([_spread_i, i, "film"]), "static")
		film.scene_name = "film"
		vp.add_child(film)
		_cast[i] = film
		return
	# The salt is the panel index, so the spread's panels are separate draws off the novelty
	# scheduler rather than the same one repeated - the Director's clock has not moved
	# between them (see Director.mint_scene). Quiet for every panel but the one being read:
	# casting a spread is one change of scene, not a dozen.
	var sc := feed.mint_scene(hash([_spread_i, i]) & 0xFFFF, i != _read)
	vp.add_child(sc)
	_cast[i] = sc


## Size a panel's render target to ITS aspect and start it running.
##
## SIZED BY HEIGHT, because the camera is fitted by height (see ComicCamera._fit): a panel spans the
## frame vertically, so its target wants about the stage's height and its width follows
## from its aspect. The obvious alternative - constant AREA - overshoots badly at the tall
## end, where it makes a 0.44-aspect panel half again taller than the screen it will be
## drawn on, for no visible gain and 2.3x the pixels.
## EVERY PANEL IS SIZED BY HOW BIG IT IS ON SCREEN, not by how big a panel can ever be.
##
## This is what pays for every scene playing at once. The budget used to be three live panels
## out of nine or twelve, and the rest were frozen render targets holding their last drawn
## frame - which is a page of stills with three moving windows in it, and a panel frozen before
## its scene had drawn anything is simply black. "You're optimizing for real-time, but we are
## cutting videos. So we can just play every scene, and we should. Freezing them looks
## terrible."
##
## Sizing every panel at `_panel_px` is what made that unaffordable: twelve 512-pixel targets
## redrawn every frame, when eleven of them occupy a few hundred pixels of the picture. The
## cost that matters is TOTAL PIXELS, not panel count, so a panel gets the resolution its place
## in the shot actually asks for and is re-opened larger when the camera comes to it.
func _open_slot(i: int, px := -1) -> SubViewport:
	var vp: SubViewport = _slots[_pool * POOL + i]
	var a := _spread.panel_aspect(i)
	var h := px if px > 0 else _panel_px
	var w := int(round(float(h) * a))
	var want := Vector2i(maxi(SLOT_IDLE, w), maxi(SLOT_IDLE, h))
	# ONLY EVER GROW WITHIN A SPREAD. Shrinking a live target throws away the picture in it and
	# the panel flashes; the pool is reset to SLOT_IDLE when the spread turns (see advance),
	# which is the one moment nothing is reading from it.
	if want.x > vp.size.x or want.y > vp.size.y:
		vp.size = Vector2i(maxi(want.x, vp.size.x), maxi(want.y, vp.size.y))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.process_mode = Node.PROCESS_MODE_INHERIT
	return vp


## The resolution panel [param i] earns in the shot on screen now: its drawn height in pixels,
## with a floor so a panel in the far distance is still a picture and a ceiling at the full
## target so the one being read is as sharp as the medium can make it.
##
## THIS IS ALSO THE PIXELATION ANSWER. A panel rasterizes into its target and is then textured
## onto the paper, so a shot tighter than the target is magnifying a bitmap - "some of the
## in-frame scenes looked a bit pixelated". Re-opening the focal panel at the resolution the
## camera is actually asking for is what removes that, and it costs nothing on the panels that
## are not being looked at.
func _panel_px_for(i: int) -> int:
	var r := _camera.panel_rect(i)
	var on_screen := maxf(r.size.y, r.size.x / maxf(_spread.panel_aspect(i), 0.01))
	# THE PANEL BEING READ MAY EXCEED `_panel_px`, up to the hard ceiling. That constant is the
	# budget for a whole spread of targets, and applying it to the ONE panel filling the frame
	# is what left a tight shot magnifying its own bitmap - measured at 1.21x on a push-in, and
	# reported as "some of the in-frame scenes looked a bit pixelated... we should be able to
	# just scale and skew the live scene, and compute pixels precisely". A live scene can
	# indeed be drawn at any resolution; it just has to be ASKED for one.
	var ceiling := PANEL_MAX if (i == _read or i == _film_at) else _panel_px
	return clampi(int(round(on_screen * PANEL_OVERSAMPLE)), SLOT_IDLE, ceiling)


## Stop a viewport WITHOUT clearing it: the render target keeps its last frame. The ORDER
## matters - stop first, free second - or the target repaints itself empty on the frame
## between the two.
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

## EVERY PANEL YOU CAN SEE IS MOVING, and no panel you cannot see costs anything.
##
## A spread whose panels arrive one at a time is a slideshow with gutters; a comic page has
## all of it drawn at once. But a dozen live scenes is not a thing that runs - the stage
## governor spends its whole budget on one - so liveness follows the CAMERA instead of the
## clock. At the reading distance one panel fills the frame and its neighbors crowd the
## edges, so what is on screen is typically one to three panels; the rest are stopped
## render targets holding their last frame, exactly as before, and they resume when the
## camera comes back to them.
##
## LIVE_MAX is the hard bound. It is ordered by distance from the panel being read, so if a
## rake ever puts more of the spread in shot than the budget allows, the ones that keep
## moving are the ones the reading is about.
func _update_liveness() -> void:
	if _spread == null:
		return
	var frame := Rect2(Vector2.ZERO, _stage_size).grow(_stage_size.x * 0.06)
	var mid := _stage_size * 0.5
	var want: Array = []
	for i in _cast.size():
		if _cast[i] == null or not is_instance_valid(_cast[i]):
			continue
		# A panel still below its warm-up is wanted WHEREVER IT IS, on screen or not. It has
		# no picture yet, so leaving it out is what makes it black - and the camera reaches
		# most of the sheet eventually, so "off screen right now" is not "never seen".
		var cold: bool = int(_warm[i]) < WARM_FRAMES
		var rect := _camera.panel_rect(i)
		if i != _read and not cold and not rect.intersects(frame):
			continue
		# DISTANCE ON THE SCREEN, not distance in the panel array.
		#
		# It used to be `absi(i - _read)`, and a spread's panel array is two CONTIGUOUS BLOCKS
		# - the left page's panels and then the right's. So ranking by index distance ranks by
		# PAGE: read a panel on the left and the three live slots all go to the left page, and
		# the entire right page is a set of frozen stills however much of it is in shot.
		# Reported as "I keep seeing instances where an entire page is disabled, while we are
		# viewing the other side of that spread." Screen distance has no idea which page a
		# panel is on; it keeps alive whatever is nearest the middle of the picture, which is
		# the only thing the eye is actually asking about.
		var d := rect.get_center().distance_to(mid) if i != _read else -1.0
		want.append({"i": i, "d": d, "cold": 0 if cold else 1})
	# NEED FIRST, DISTANCE SECOND. Until every panel has drawn its moment the budget goes to
	# the ones that have not; after that it follows what is in the middle of the shot.
	want.sort_custom(func(a, b):
		return int(a.cold) < int(b.cold) if int(a.cold) != int(b.cold) else float(a.d) < float(b.d))
	var budget := _live_budget()
	# THE PANEL BEING READ IS ALWAYS LIVE, AND SO IS THE FILM. Reserved BEFORE the budget is
	# spent, not merely sorted to the front of it.
	#
	# This is the frozen picture. The sort puts every panel still below its warm-up ahead of
	# every warm one - which is right, a panel with no picture needs frames more than a panel
	# that has one - but LIVE_MAX is three, and a page turn casts a whole spread at once. Three
	# cold panels therefore filled the entire budget and froze the panel the camera was looking
	# at: the Director's own current scene, stopped, for as long as the newcomers took to warm.
	# Reported as "the scene in that comic book frame becomes stuck, frozen, and stops moving at
	# all" and "takes a long time to start again" - and confirmed off the export, where two
	# frames a full second apart have the scene's eyes in identical positions.
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
		# On this frame at all, and if so, is it this one's turn? The read panel's turn is
		# every frame; the others are phased against each other by index so two of them
		# never land on the same frame.
		# The film panel is exempt from the off-focal phasing: half the samples looks
		# like a scene running at the right speed with a coarser clock, and looks like
		# BROKEN PLAYBACK on footage, which the eye reads at a much finer grain.
		# A COLD PANEL RUNS EVERY FRAME IT IS KEPT, phasing included: half the samples is
		# fine for a moment that is already on the paper and wrong for one still drawing it.
		# ...and the off-focal PHASING is the same concession at a finer grain, so it lifts on
		# an export too: half the samples is a scene running on a coarser clock, which is
		# cheaper and very slightly worse, and there is nothing to buy with it here.
		var every := budget >= POOL
		var on: bool = keep.has(i) and (every or i == _read or i == _film_at
			or int(_warm[i]) < WARM_FRAMES or (_frame + i) % OFF_FOCAL_PERIOD == 0)
		if on:
			_warm[i] = int(_warm[i]) + 1
			# GROW INTO THE SHOT. A panel cast while it was small on screen keeps that target
			# until the camera comes to it; re-opening in REOPEN_STEP jumps rather than every
			# frame keeps a push-in to a handful of reallocations instead of hundreds.
			var px := _panel_px_for(i)
			if px > vp.size.y and (i == _read or i == _film_at
					or float(px) > float(vp.size.y) * REOPEN_STEP):
				_open_slot(i, px)
			_resume(vp)
		else:
			_freeze(vp)
	_live = keep


## HOW MANY PANELS MAY RUN THIS FRAME. See LIVE_ALL_ON_EXPORT: the real-time budget, or no
## budget at all when there is no frame deadline to spend it against.
##
## Asked of the command line rather than of main, because a medium is built before main has
## finished deciding anything and must not reach up into it - the same reason the Director is
## asked for the session seed instead of being handed one.
func _live_budget() -> int:
	if LIVE_ALL_ON_EXPORT and OS.get_cmdline_user_args().has("--export"):
		return POOL
	return LIVE_MAX


## Drive every live panel EXCEPT the one being read - the Director drives that one, as its
## current scene, and ticking it twice would run it at double speed. This is the same pair
## of calls Director._tick_animation makes, because it is the same job.
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
		# ...and when it IS its frame, it is handed the whole period's worth of time, so it
		# runs at the right speed rather than at 1/period of it.
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


## HOW MANY SCREEN PIXELS THE READ PANEL COVERS PER TEXEL OF ITS RENDER TARGET. 1 is 1:1;
## above 1 the panel's bitmap is being magnified and will look soft or blocky.
##
## A panel is not drawn as live geometry - it is rasterized into its own SubViewport at a fixed
## size and then mapped onto a quad as a TEXTURE. That is what makes a held panel free (the
## frozen target keeps its picture for nothing) and it is also why a tight shot can pixelate:
## the shot is resampling a bitmap, exactly as it would a video.
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
	# The bookend belongs to the medium here (see Medium.owns_bookend): the whole spread
	# fades, paper and all, instead of one panel fading inside a lit page.
	modulate.a = 1.0
	var fade := clampf(_bookend, 0.0, 1.0)
	var att := _camera.att_basis       # the sheet's attitude, which every flat page is placed by
	_backdrop(fade)          # once per frame, under everything, including through a turn

	# A PAGE TURN, as a real leaf on a real spine.
	#
	# The right-hand page of the outgoing spread swings left about the spine. Its FRONT is
	# that page; past the halfway point - where the leaf is edge-on and infinitely thin, so
	# the swap cannot be seen - its BACK is the incoming spread's LEFT page, mirrored about
	# the spine so that at a half turn it lands exactly where that page is about to be drawn
	# flat. Nothing cross-dissolves and nothing jumps: the leaf simply becomes the page it
	# always was the other side of.
	#
	# Under it: the incoming RIGHT page, revealed as the leaf lifts off it, and the outgoing
	# LEFT page, covered as the leaf comes down on it. Painter's order is exactly that -
	# both flat pages first, the leaf over them.
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


## Has panel [param i] of the CURRENT spread been cast yet? (See _turn_spread's queue.)
func _is_cast(i: int) -> bool:
	return i < _cast.size() and _cast[i] != null and is_instance_valid(_cast[i]) \
		and i < _warm.size() and int(_warm[i]) >= FIRST_DRAW


## Every panel of the spread turning away carries a picture - it was fully cast before the
## turn started, and stopping its viewports kept what they had drawn.
func _all_drawn(_i: int) -> bool:
	return true


## ONE PAGE of [param sp] - the unit a leaf turns, and therefore the unit everything draws
## in. [param side] is 0 for the left page and 1 for the right.
##
## [param m] is the full placement transform (see [method ComicSpread.world]): the sheet's
## attitude for a page lying flat, or that times the hinge rotation for the leaf in the air.
## [param mirror] reflects about the spine, which is how the leaf's back face draws the page
## printed on it.
##
## [param drawn] says which panels carry a picture. For the spread being read that is "has
## this one been cast yet" - the queue casts one per frame, so for the first few frames a
## late panel is still blank paper. For the spread turning away it is every panel, because
## it was fully cast before the turn began.
func _draw_leaf(sp: ComicSpread, side: int, pool: int, drawn: Callable, m: Basis,
		u: float, origin: Vector2, fade: float, mirror: bool) -> void:
	if fade <= 0.003 or sp == null:
		return
	var paper := Color(_paper.r, _paper.g, _paper.b, fade)
	var ink := Color(_ink.r, _ink.g, _ink.b, fade)
	# The sheet's shadow on the surface under it, before the sheet itself.
	_shadow_quad(sp, side, m, u, origin, fade, mirror)
	# THE PAPER, subdivided so its gradient is per-vertex rather than per-quad, and so a
	# steeply raked page still shades smoothly across its length.
	_paper_quad(sp, side, m, u, origin, paper, mirror)
	# THE PANELS. Painter's order along the page normal is irrelevant - they are coplanar
	# and never overlap - so reading order is the order, which is also the order the ink
	# wants (a canted panel's border must sit over its neighbor's paper, not under it).
	var on_page := sp.page_panels(side)
	for i in on_page:
		if bool(drawn.call(i)):
			_panel_quad(sp, int(i), pool, m, u, origin, fade, mirror)
	for i in on_page:
		_panel_ink(sp, int(i), m, u, origin, paper, ink, bool(drawn.call(i)), mirror)


## The surface the sheet lies on: a vignetted wash over the whole frame, painted first.
## See the note on DESK_VIGNETTE for why this is not a quad in the world.
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


## One page's shadow on that surface - its outline, offset and pushed back. It is most of
## what makes the paper read as an object lying on something rather than as a rectangle
## floating in a void, and on the leaf it is what says the page has LIFTED.
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


## The page itself: a subdivided quad with a gentle darkening toward the edges. Flat white
## paper reads as a blank canvas; a whisper of a gradient reads as a printed sheet.
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


## Index the cells of an (n+1)x(n+1) vertex grid, SKIPPING any cell with a vertex behind the
## eye.
##
## The alternative - what every one of these draws used to do - is to abandon the whole
## surface the moment one vertex went behind the camera. On a single page that was rare
## enough to be invisible. On a spread it is not: the sheet is twice as wide, so at a rake
## the far corners go behind the eye at framings that are otherwise perfectly good, and a
## page that vanishes entirely for a second is a far worse artifact than a page missing the
## cell that could not be projected.
## RETURNS the buffer rather than filling one handed in: a PackedInt32Array is a value
## type in GDScript, so a callee that appends to a parameter appends to its own copy and the
## caller draws nothing at all.
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


## One panel's picture: its render target mapped onto a GRID-subdivided quad whose every
## vertex is projected individually. Two triangles would be affine and would warp (28.5 px
## on a 512 px frame, measured in tests/media/medium_probe.gd); subdivision makes the mapping
## piecewise-perspective and the error vanishes.
func _panel_quad(sp: ComicSpread, i: int, pool: int, m: Basis,
		u: float, origin: Vector2, fade: float, mirror: bool) -> void:
	var lens := _camera.lens
	var vp: SubViewport = _slots[pool * POOL + i]
	var rid := vp.get_texture().get_rid()
	if not rid.is_valid():
		return
	# HALF A TEXEL IN, on every side. UVs of exactly 0 and 1 sample the outermost texel's
	# EDGE, where the bilinear filter reaches for a neighbor that is not there - and what
	# it finds depends on the repeat mode, which showed as a stray colored fringe along
	# the bottom rule of a panel. Insetting by half a texel keeps every sample inside the
	# panel's own picture; the loss is half a pixel of a 700-pixel render.
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
			# THE UV IS NOT MIRRORED. Reflecting the page about the spine reflects where the
			# panel IS, never what is printed in it - a page seen from behind would be a
			# page seen from behind, and the leaf's back is a page seen from the FRONT.
			uvs.append(inset + uv * (Vector2.ONE - inset * 2.0))
			cols.append(col)
	var idx := _cells(ok, n)
	if idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(
		get_canvas_item(), idx, pts, cols, uvs,
		PackedInt32Array(), PackedFloat32Array(), rid)


## How finely to subdivide this panel's grid: enough cells that each is about CELL_PX across
## on screen. Measured off the panel's own projected size, so a panel filling the frame gets
## a fine grid and one at the edge of shot gets a coarse one.
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
		# A corner behind the eye means the panel is unboundedly large in screen space, so
		# the projected span says nothing. Size it to the SCREEN instead: a cell can never
		# usefully be finer than the frame it is drawn into, and the old answer here was a
		# flat GRID_MAX - a 40x40 grid, 1681 vertices, on a panel that is mostly off shot.
		return clampi(int(ceil(maxf(_stage_size.x, _stage_size.y) / CELL_PX)),
			GRID_MIN, GRID_MAX)
	var span := maxf(hi.x - lo.x, hi.y - lo.y)
	return clampi(int(ceil(span / CELL_PX)), GRID_MIN, GRID_MAX)


## The gutter side of a panel: paper painted back over the square corners the rounded
## outline cuts off, then the ink border on top.
##
## Rounding this way rather than by clipping the texture is exact under perspective and
## costs nothing: the corner wedges are computed in SPREAD space and projected like every
## other point on the sheet, so they land on the picture's corner however the page is
## raked. Clipping would have needed a stencil or a shader, for a shape the paper can
## simply cover.
func _panel_ink(sp: ComicSpread, i: int, m: Basis, u: float, origin: Vector2,
		paper: Color, ink: Color, filled: bool, mirror: bool) -> void:
	if sp.radius > 0.0004 and filled:
		for w in _corner_wedges(sp, i, m, u, origin, mirror):
			var poly: PackedVector2Array = w
			# A wedge is a few pixels across at the wide shot, and BELOW a pixel the canvas
			# triangulator rejects it outright ("Invalid polygon data, triangulation
			# failed", once per corner per panel per frame). Same guard Plane3D carries for
			# the same reason: sub-pixel geometry contributes nothing and costs an error.
			if poly.size() >= 3 and _poly_area(poly) >= 1.0:
				draw_colored_polygon(poly, paper)
	# An UNFILLED panel is drawn as an empty ruled frame - the page is a comic being
	# drawn, and the panels ahead of the story are simply not inked in yet. Lighter, so
	# it reads as ruled rather than as a black hole.
	var line := ink if filled else Color(ink.r, ink.g, ink.b, ink.a * 0.35)
	# THE BORDER IS DRAWN IN RUNS. A rule with one point behind the eye used to abandon the
	# whole outline; on a spread that happens often enough to be seen as panels losing their
	# borders in bursts, so the visible part is drawn and only the part that cannot be
	# projected is dropped.
	for run in _rounded_runs(sp, i, m, u, origin, mirror):
		var pts: PackedVector2Array = run
		if pts.size() >= 2:
			draw_polyline(pts, line, _ink_width(), true)


## Comic rules are CHUNKY - a hairline reads as a UI border around a video, which is
## exactly what this medium exists not to be. Scaled off the shorter screen axis so it
## is the same weight at 720p and at 4K, and sampled per session inside a narrow band
## (some books ink heavier than others; none ink thin).
## Twice the signed area of a polygon, absolute - the cheap "is this bigger than a pixel"
## test.
func _poly_area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q: Vector2 = p[i]
		var r: Vector2 = p[(i + 1) % p.size()]
		a += q.x * r.y - r.x * q.y
	return absf(a) * 0.5


func _ink_width() -> float:
	return maxf(1.5, minf(_stage_size.x, _stage_size.y) * _ink_weight)


## The panel's outline in screen space as RUNS of consecutive projectable points, corners
## rounded in SPREAD space. A fully visible panel gives exactly one run, closed.
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


## The outline as points in the panel's own unit square. Radius is expressed in units of
## the SHORTER side and converted per axis, so a wide panel's corners stay circular
## instead of stretching into ellipses.
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


## The four corner cut-offs, in screen space - the area between the square corner and the
## arc, which is painted back in paper so the picture stops at the rounded edge.
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
