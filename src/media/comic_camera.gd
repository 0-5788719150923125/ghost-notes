extends RefCounted
class_name ComicCamera

## ComicCamera - the eye over the spread: where the camera is, where it is going, and the lens the page
## is drawn through. A part of [ComicMedium] (next/structure.md, "One file, one job").
##
## Each spread picks one set-up ([method choose_look]: a side of the sheet, a height, a tilt, a lens, and
## the rake the sheet is turned to and drifts on) and every shot varies inside it. A cut or the leaf
## turning begins a shot ([method begin_shot]): a subject on the page and a way of looking at it, drawn
## from [constant SHOTS]. Each frame [method advance] walks the camera toward it and [method place_eye]
## turns the followed pose into an eye - framed on the panel under the aim, opened where there is none,
## never so far that the sheet stops covering the frame nor so near that the shot is inside one panel's
## artwork. [member lens] is what the medium draws through, and [method panel_rect] says where a panel
## lands on screen.
##
## It holds its own state (the sheet's attitude, the set-up and its walks, the pose and its target, the
## shot, the lenses) and reads the rest through [member medium]: the spread and the panel being read, the
## film panel, the focal scene's framing, the stage's size, the show's feed (the seed, the Camera knob, the
## hold left on the scene) and the mod bank the sheet sways on. Where a point lies on the paper and which
## panel holds it are [ComicSpread]'s. [method reset] puts all of it back as a new book finds it.
##
## The camera state is never assigned, only integrated: `_cam` follows `_tgt` exponentially every frame,
## and _cut_to is the only function that writes `_cam` outright, so the only place a discontinuity can
## come from. Continuity is a property of the follower, not a convention each shot must honor.
##
## The rake (from the panel being read), the scale (from whichever panel the aim is inside) and the
## distance (from a solve that changes branch at the film panel's edge) are step functions no shot-layer
## guard can reach, so `flat` and the eye distance are follower channels here too.
##
## Speed is a rate, not a duration: a shot has a target and a closing rate, arrives when it arrives, and
## a cut that interrupts it is graceful because the follower simply retargets.

## The [ComicMedium] this is a part of: everything read through it is something this part is handed.
var medium: ComicMedium

## How much of the frame a contained panel may fill, on its longer axis. Other panels are framed on
## height alone and overflow the sides (right for an abstract field, where any part is as good as any
## other). A piece of footage is not: a 1.9-aspect film panel framed on height is nearly twice the
## screen's width, so the subject is as likely off the picture as on it. A contained panel is fitted on
## both axes so the whole video is in shot whenever it is the one being read.
##
## Just under 1: every notch of margin pulls the camera further off the sheet, and past the covering
## distance that is paid in desk (at 0.88 the page covered only 0.63 of the frame).
const CONTAIN_FILL := 0.98
## However much the video wants revealing, the camera stops this far past the distance at which the sheet
## still covers the frame. One: going past the covering distance is the only way desk enters a shot, and
## measured on a real spread six percent past cost ten percent of the coverage. Containing that panel
## wanted 7.76 world units against a cover of 4.62, so a cap of 4.89 left the video cropped and put desk
## in the corner. The camera stops where covering stops and the video is contained as far as that allows
## (see FILM_FLATTEN).
const CONTAIN_DESK := 1.0
## How far toward square-on a contained panel pulls the sheet, 0..1. Harder than FIELD_FLATTEN: a rake
## foreshortens the sheet, so a raked page needs the camera nearer to keep paper across the frame, which
## fights containing a wide panel (containing the widest panel wanted 3.03 world units while the sheet
## stopped covering past 2.13), and a hard angle across a face reads as damage rather than depth. But
## flattening presents the panel at its full area, so the camera must retreat to fit it (a fit of 7.76
## against a cover of 4.62 at 83 degrees); 0.40 leaves the panel foreshortened, which fits nearer.
const FILM_FLATTEN := 0.40

## Spread attitude, in radians: the rest pose the book is rolled into, on all three axes. Generous, since a
## raked page is what reveals the paper has depth (a few degrees reads as a crooked scan). Yaw is tighter:
## a spread is twice as wide as the page these were tuned on, and the same yaw foreshortens the far page
## into a sliver and throws its far corners behind the eye.
##
## The sheet's attitude does not cost coverage: swept one axis at a time against page_coverage() on a real
## spread, pitch, yaw and roll each held 1.00 across their whole range, while camera elevation ran
## 0.34 / 0.84 / 1.00 from 30 / 40 / 50 degrees. See EL_MIN_DEG.
const PITCH := 0.55
const YAW := 0.44
const ROLL := 0.40
## ...and it never stops moving: radians per second of slow continuous drift, so the sheet turns under the
## camera through the whole spread.
const DRIFT := 0.035

## Camera elevation off the paper, in degrees. Never square-on (at 90 the perspective camera and the page
## agree and the panel is a flat rectangle) and never grazing (the panel foreshortens into a line).
##
## The floor decides whether there is desk in the picture: swept against page_coverage() on a real spread,
## the sheet's own pitch, yaw and roll each held 1.00 across their range while elevation ran 0.34 at 30
## degrees, 0.84 at 40 and 1.00 from 50 up. A low camera sees the sheet edge-on and it shrinks along one
## axis faster than any distance can compensate, so no framing solve can put paper across the frame.
const EL_MIN_DEG := 46.0
const EL_MAX_DEG := 72.0
## Camera roll about the view axis - the Dutch angle, on top of the page's own roll.
const CAM_ROLL := 0.22

## How far one shot may depart from the spread's set-up. A spread picks one set-up (a side, a height, a
## tilt, a lens) and a shot varies inside it: consecutive shots re-rolled independently are unrelated
## positions and the interpolation between them is a camera swinging across the page. Staying on one side
## of the subject is the 180-degree rule, so changing sides is a page turn, the one moment where a new
## set-up reads as a new scene.
const AZ_ARC := 0.42              # +/- radians of orbit around the spread's side (~24 deg)
const EL_VARY_DEG := 7.0          # +/- degrees of height off the spread's own
const ROLL_VARY := 0.05           # +/- radians of Dutch on top of the spread's own

## How much of its arc one shot may spend, as a fraction. The angles are a bounded random walk, not an
## independent draw per cut: a shot moves them by at most this fraction of the arc and the walk is clamped
## to it, so the same total excursion is reachable but spread over several shots (at a third of the arc it
## takes three or four cuts to cross), and the walk keeps its direction long enough to read as one move.
const ANG_STEP := 0.34
## The lens, chosen once per spread. Narrow: a wide lens this close to a panel bends its edges.
const FOV := Vector2(38.0, 54.0)

## How tall the panel being read is, in frames: 1.0 spans the frame exactly top to bottom; above that it
## overflows and the screen crops into it. The floor is 0.78 because a spread covers the frame at a much
## looser shot: a panel 0.78 frames tall sits inside a picture that is entirely paper and neighboring
## panels, a comic being read rather than a video with a border.
const FILL := Vector2(0.78, 1.30)
## The hard near limit, in frames of panel height: however much the spread wants covering, the camera
## stops here. Past about this the panel stops reading as a panel. Set generously: a floor that binds in
## the ordinary case (at 2.2 it came out further from the page than the covering distance, 1.66 against
## 1.24) decides every shot and vetoes the push-in that fills the frame.
const CROP_MAX := 4.5
## How far the aim is pulled from the panel's center toward the middle of its own page. A panel at the
## outer trim, framed dead on, puts the trim edge and the void behind the paper into shot. Toward the
## page, not the spread: the middle of a spread is the spine, the widest gutter, and pulling toward it
## biases every shot toward the one place with no picture; the risk is the outer trim, and the inner edge
## has a second page beyond it.
const AIM_PULL := 0.12

## The spread's own attitude eases at its own, much slower rate - it is scenery, not a move.
const PAGE_EASE := 0.7

## The lens the page is drawn through: prepared once a frame from the eye ([method prepare_lens]), read by
## the medium's drawing and by [method panel_rect].
var lens := Lens3D.new()
## The two solver lenses, allocated once (they would otherwise be three allocations per frame inside the
## bisection). Neither survives the call.
var _fit_lens := Lens3D.new()
var _cover_lens := Lens3D.new()

# The spread's attitude, eased toward a target that itself drifts. Sampled on all three axes with real
# magnitude: the point of a real 3D sheet is that it can be turned.
var _att := Vector3.ZERO
var _att_target := Vector3.ZERO
var _att_rate := Vector3.ZERO     # slow continuous drift, per second
## The attitude as a basis, rebuilt once per advance() and read by everything that places a point on the
## paper (building it per vertex is six trigonometric evaluations and a 3x3 construction, about 2500
## times a frame).
var att_basis := Basis.IDENTITY

# The camera state, in spread-local spherical coordinates rather than a world position: an azimuth around
# the aim and an elevation off the paper. That makes the rake real (an eye on the sheet's normal sees a
# flat rectangle however the sheet is rotated) and traveling between panels a move parallel to the paper.
# Keys: aim (spread coords), az, el, roll, fill, fov. See _target_for, which builds one.
## The spread's set-up: the side the camera is on, its height, its tilt and its lens. Fixed for the
## spread; see AZ_ARC.
var _az_base := 0.0
var _el_base := 1.0
var _roll_base := 0.0
var _lens_fov := 46.0
## The bounded walk each angle is currently at, as an offset from its base. See ANG_STEP.
var _az_walk := 0.0
var _el_walk := 0.0
var _roll_walk := 0.0

## Where the camera is: the pose the follower integrates, keyed as above - and where a new book
## starts it ([method reset]).
const POSE_AT_REST := {"aim": Vector2(1.0, 0.7), "az": 0.0, "el": 1.0, "roll": 0.0,
	"fill": 1.1, "fov": 52.0}
var _cam := POSE_AT_REST.duplicate()
## Where the camera is going. `_cam` follows this, every frame, and nothing else moves the
## camera - see the class doc.
var _tgt := {}
## The shot in progress: {panel, kind, rate, arrived, heading}. A shot is a subject and a way of looking
## at it, not a path; where the camera is on the way there is the follower's business.
var _shot := {}
var _shot_t := 0.0
## Seconds since the shot arrived, and the aim it arrived at: the origin the held shot creeps from
## (measured from the arrival, which bounds the creep however long the hold runs).
var _hold_t := 0.0
var _hold_from := Vector2.ZERO
## Shots begun this session, part of the seed so each is reproducible without repeating.
var _shot_n := 0
## Which way the framing is currently going: +1 tightening, -1 opening, 0 neither. Cleared when a shot
## arrives, so "no reversal without a hold between" is expressible.
var _zoom_dir := 0
## Set by a declared discontinuity, and the only thing that lets the placed rake and distance skip their
## followers. See _cut_to.
var _snap := true
## The followed halves of place_eye: the rake pulled toward square-on, and the eye distance. Both derive
## from quantities that step - see RATE_FLAT.
var _flat_s := 0.0
var _dist_s := -1.0
var _roll := 0.0                  # the roll actually in force (field-flattened)
var _eye := Vector3(0, 0, 3.0)
var _look := Vector3.ZERO
var _fov := 52.0

# --- the shot vocabulary, and the spread's set-up ---------------------------------------------

## The shot vocabulary. A cut picks one of these and the camera travels toward it. An entry is a
## destination and a speed (see the note inside the table for each key) and one follower walks toward it
## every frame, so the only discontinuity a session can contain is a call to _cut_to
## (tests/media/comic_motion_check.gd counts it).
##
## The bag is mostly gentle, with punctuation about one shot in six: a camera should be moving most of the
## time and jumping rarely (weighted the other way, two shots in five opened on a jump), which is neither
## "sit on each panel" nor "cut constantly".
const SHOTS := {
	# What each entry means. `fill` is a band multiplying the panel's natural framing (how much tighter or
	# wider than this panel reads at), so the panel's size cannot invalidate it. `aim` is how far the
	# station sits off the panel's center, in page widths. `az` is how far round it swings, in radians.
	# `rate` is how fast the follower closes on it, multiplying the severity rate. `hard` means the shot
	# begins with a cut (see _cut_to, the only place in this file that assigns the camera). Every one is a
	# distance or a speed.
	"settle":  {"w": 4.0, "fill": [0.92, 1.12], "aim": 0.04, "az": 0.00, "rate": 1.00},
	"push":    {"w": 2.5, "fill": [1.35, 2.30], "aim": 0.03, "az": 0.00, "rate": 0.75},
	"pull":    {"w": 1.5, "fill": [0.55, 0.80], "aim": 0.03, "az": 0.00, "rate": 0.75},
	"pan":     {"w": 3.0, "fill": [0.90, 1.20], "aim": 0.30, "az": 0.10, "rate": 0.70},
	"orbit":   {"w": 1.5, "fill": [0.90, 1.20], "aim": 0.05, "az": 0.55, "rate": 0.55},
	# The one that shows the page. Nothing else in this table frames more than its own panel (the widest,
	# `pull`, still leaves the subject filling most of the picture). `page` aims at the middle of the
	# panel's own page and frames wide enough that its neighbors and the gutters between them are the
	# composition.
	"page":    {"w": 2.0, "fill": [0.26, 0.46], "aim": 0.10, "az": 0.15, "rate": 0.55,
		"wide": true},
	# The quick one: the same grammar at four times the rate. A whip is a fast move, not a jump.
	"whip":    {"w": 0.5, "fill": [0.85, 1.30], "aim": 0.20, "az": 0.25, "rate": 3.20},
	# ...and the one discontinuity. It must change the subject to be allowed at all (see _worth_cutting).
	"cut":     {"w": 0.9, "fill": [0.80, 1.60], "aim": 0.08, "az": 0.80, "rate": 0.90,
		"hard": true},
}

## How deep a `push` gets, in frames of panel height.
const PUSH_FILL := Vector2(2.2, 3.8)
## What makes a jump cut worth making: it must land on a different panel, and move the aim at least this
## far in page widths. A cut is a change of subject; scale is how it is photographed. (A rule that let size
## qualify permitted seven of the eleven discontinuities in an export, including cuts on the panel already
## held.) So a cut within one panel becomes a drift. The aim distance is a second bar rather than an
## alternative: two panels can share an edge, and a cut across a gutter is the same non-event.
const CUT_MIN_AIM := 0.28

## How far a page turn may move the camera's side of the sheet, in radians at camera 1. The largest change
## of angle the grammar allows: a lean, not a walk round the table.
const TURN_AZ := 1.2
## The camera knob, applied. See [member Director.camera]; the slider is labeled "Camera" and `severity`
## is this file's word for it. Every constant that describes how much the camera does is read through
## _sev(), so the slider moves the whole behavior along one axis:
##   how far a shot travels and how wide its framing band is - see REACH_CALM
##   how fast the follower closes                            - see RATE_CALM
##   the angular arc a shot may reach, and the walk step      - how far it can swing at all
##   how far a page turn moves the set-up                     - the one big change in grammar
##   the weight of the one discontinuous shot                 - at 0 it never jump-cuts
##   the sheet's own drift rate                               - scenery reads as camera motion
##
## Reach is what makes the slider monotone in holding: scaling speed alone makes a gentle camera spend more
## of the hold traveling (71% held at camera 0 against 86% at camera 1).

## How much gentler a field scene is raked, 0..1 toward square-on. Scenes are typed `subject` or `field`
## and [Shots] gives field scenes gentle moves only; the same rule applies here, since a hard rake reads as
## foreshortening when there is an object in the panel and as warping when there is not (a fractal field
## at 30 degrees off the paper looks like a broken picture).
const FIELD_FLATTEN := 0.62

## The framing a shot falls back to when there is no panel under the aim, in frames of panel height. At
## 0.62 the nearest panel is a bit over half the frame, so the gutter being looked at is surrounded by the
## four panels it separates: a picture of a comic page. The covering solve can still refuse to go this
## wide (see place_eye), though on a spread it usually does not have to.
const OFF_FILL := 0.62


## A new book: everything this part holds put back as a fresh camera has it - the sheet's attitude, the
## set-up and its walks, the pose and its target, the shot and the count that seeds every shot, the
## followers and the eye. The medium outlives its sessions, so whatever is left out the next session
## inherits (tests/media/comic_motion_check.gd, "a second attach"). A member added to this part's state is
## added here too.
func reset() -> void:
	_att = Vector3.ZERO
	_att_target = Vector3.ZERO
	_att_rate = Vector3.ZERO
	att_basis = Basis.IDENTITY
	_az_base = 0.0
	_el_base = 1.0
	_roll_base = 0.0
	_lens_fov = 46.0
	_az_walk = 0.0
	_el_walk = 0.0
	_roll_walk = 0.0
	_cam = POSE_AT_REST.duplicate()
	_tgt = {}
	_shot = {}
	_shot_t = 0.0
	_hold_t = 0.0
	_hold_from = Vector2.ZERO
	_shot_n = 0
	_zoom_dir = 0
	_snap = true
	_flat_s = 0.0
	_dist_s = -1.0
	_roll = 0.0
	_eye = Vector3(0, 0, 3.0)
	_look = Vector3.ZERO
	_fov = 52.0
	lens = Lens3D.new()


## The spread's attitude: a real rake on all three axes, plus a slow continuous drift so the sheet is never
## still.
func choose_look() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([medium.feed.session_seed(), "comic-spread-look", medium._spread_i])
	_att_target = Vector3(
		r.randf_range(-PITCH, PITCH),
		r.randf_range(-YAW, YAW),
		r.randf_range(-ROLL, ROLL))
	_att_rate = Vector3(
		r.randf_range(-DRIFT, DRIFT),
		r.randf_range(-DRIFT, DRIFT),
		r.randf_range(-DRIFT, DRIFT) * 0.5)
	# The set-up for this spread is decided once and everything below only varies within it (see AZ_ARC).
	var sev := _sev()
	if medium._spread_i <= 0:
		_az_base = r.randf_range(0.0, TAU)      # the first spread has nowhere to come from
	else:
		# A bounded change of side, not a fresh draw: a lean rather than a walk round the table at a gentle
		# setting (this happens only every six to twelve cuts).
		_az_base += r.randf_range(-TURN_AZ, TURN_AZ) * sev
	_el_base = deg_to_rad(r.randf_range(EL_MIN_DEG, EL_MAX_DEG))
	_roll_base = r.randf_range(-CAM_ROLL, CAM_ROLL) * sev
	_lens_fov = r.randf_range(FOV.x, FOV.y)
	# The walk starts each spread where the last one left it, so a page turn is the only discontinuity in
	# the angles. The sheet's own drift is part of how busy the picture is, so it scales too.
	_att_rate *= sev


## The leaf has turned (or the book opened): this spread's set-up, then a shot on [param panel]. A new
## sheet is a new shot, not a place to ease toward, so the placed rake and distance jump to it.
func new_spread(panel: int) -> void:
	choose_look()
	_snap = true
	begin_shot(panel, true)


## One step of a bounded random walk: move [param at] by at most ANG_STEP of [param arc] and keep it inside
## +/-arc. A zero arc pins it at zero (severity 0). Clamped rather than reflected: a walk that bounces off
## its bound reads as the camera repelled by a wall; one that saturates dwells at the edge until a step
## comes back, which reads as having settled on one side.
func _walk(at: float, arc: float, r: RandomNumberGenerator) -> float:
	if arc <= 0.0:
		return 0.0
	return clampf(at + r.randf_range(-arc, arc) * ANG_STEP, -arc, arc)


## How wide the shot opens where there is no panel under the aim. See OFF_FILL, and place_eye for why this
## is a severity question.
func _open_to() -> float:
	return lerpf(float(_cam.fill), OFF_FILL, lerpf(0.45, 1.0, clampf(_sev(), 0.0, 1.0)))


# --- the camera: one target, one follower -----------------------------------------------------

## What share of the hold a shot spends arriving, at camera 0 and at camera 2. The rate is derived from
## this, not set directly: a fixed rate makes a calm camera close slowly, but the distance to close is the
## gap between two panels, which the reading plan sets, so a slow rate means a long journey and a short
## hold (53% held at camera 0 against 82% at camera 2). Express the intent (how much of the scene is spent
## looking rather than traveling) and let the rate fall out.
##
## The rate accounts for how far the shot has to go: an exponential follower closes a gap of G down to the
## arrival threshold in ln(G)/rate seconds, so the rate that arrives in time t is ln(G) / t, not 3/t (a
## shot crossing the spread starts an order of magnitude further out than one nudging within a panel).
const ARRIVE_SHARE_CALM := 0.22
const ARRIVE_SHARE_BUSY := 0.55
## ...bounded at both ends, in seconds of approach. With the hold slider at 4.0 the room in front of a shot
## is enormous, so the derived rate went to nearly zero and no shot ever arrived (the hold never began):
## anything derived from the Director's hold must be clamped, since the hold has no upper bound. The floor
## keeps an arrival from being a snap on a very short hold; the shot runs past the cut, which costs nothing
## since a cut is a new target.
## Over what fraction of the journey the approach eases out. Above it the camera travels at a constant
## rate; below it, it lands. Small, because the taper is a landing, not the shot.
const ARRIVE_TAPER := 0.28
const ARRIVE_FLOOR := 1.8
## 10: a pan may be unhurried and still has to land (at 17 a shot spent fourteen seconds of a twenty-second
## scene traveling). The variety comes from PAN_SPEED sampling inside this bound.
const ARRIVE_CEIL := 10.0
## How fast the camera crosses the paper, in page widths per second, sampled per shot. A pan has a speed,
## not a duration: sizing every arrival as a share of the hold gives a long journey and a short nudge the
## same eight seconds, so the long ones would be the fastest thing on screen. Dividing distance by a speed
## makes crossing the spine take longer than easing across a gutter. The range is wide: some transitions
## are quick, mostly gentle.
const PAN_SPEED := Vector2(0.028, 0.115)
## The angles follow slower than the aim: a pan that changes the rake at the framing's speed reads as the
## whole page swinging; lagging reads as a camera craning while it travels.
const RATE_ANGLE := 0.62
## How big a shot's journey is, at camera 0 and camera 2, multiplying the `aim` and `az` distances in shots
## and the width of its `fill` band. This makes the slider monotone in holding: scaling only speed makes a
## gentle camera make the same journeys more slowly (71% held at camera 0 against 86% at camera 1), while a
## gentle camera that makes small journeys arrives early and looks for a long time.
const REACH_CALM := 0.35
const REACH_BUSY := 1.35
## The shot has arrived when its remaining gap is under this, in the mixed units of _pose_gap (page widths
## of aim, log-ratio of framing, radians of swing). One, because _pose_gap divides each channel by its own
## tolerance first.
const ARRIVED := 1.0
## The tolerances _pose_gap normalizes by: aim in page widths, framing as a log ratio (0.06 is
## about 6%), swing in radians.
const GAP_AIM := 0.035
const GAP_FILL := 0.06
const GAP_ANG := 0.035
## The safety net for a shot that cannot converge (a target it will not reach, or a constraint fighting
## it): treated as arrived after this long so the hold can begin. It must sit above any legitimate
## arrival or it becomes the schedule; see the taper floor in _follow.
const ARRIVE_CAP := 22.0
## How long the camera must have held before it may reverse the framing. Clearing the direction the
## instant a shot arrives is not enough: a shot can arrive and be cut a moment later, and the next shot
## would reverse with nothing between (3 to 6 reversals per run measured with no hold separating them).
const ZOOM_FREE := 1.6
## The held shot still breathes: how far the target creeps during a hold, in page widths, and how long it
## takes to creep the whole way. One heading, chosen when the shot arrives (an unbiased random walk
## against the panel edge parks at the edge and jitters there). A perfectly static held shot reads as a
## photograph of a page rather than a camera looking at one.
const HOLD_CREEP := 0.05
const HOLD_CREEP_TIME := 22.0
## How fast `flat` and the eye distance follow their targets, per second: the two quantities in place_eye
## that step (see the class doc).
const RATE_FLAT := 1.3
const RATE_DIST := 2.4


## The severity in force, 0..2. Asked of the Director so the slider takes effect on the next frame.
func _sev() -> float:
	return clampf(medium.feed.camera, ShowFeed.CAMERA_MIN, ShowFeed.CAMERA_MAX)


## How far a shot travels, and how fast, at the current setting. See REACH_CALM and RATE_CALM.
func _reach() -> float:
	return lerpf(REACH_CALM, REACH_BUSY, clampf(_sev(), 0.0, 2.0) * 0.5)


## The rate that arrives inside this camera's share of the hold in front of it (see ARRIVE_SHARE_CALM).
## How long this shot should take to arrive: the distance it has to cross, at a speed sampled for this
## shot (see PAN_SPEED). The Director's hold is a ceiling on that, not the source of it.
func _arrive_time(r: RandomNumberGenerator, travel: float, kind: String) -> float:
	# Biased toward the slow end, applied to the speed: time is distance over speed, so sampling speed
	# uniformly produces mostly short transitions. Squaring the draw pushes the sample toward the gentle end.
	var u := r.randf()
	var speed := lerpf(PAN_SPEED.x, PAN_SPEED.y, u * u)
	# The table's `rate` multiplies the speed (`whip` is the quickest, `orbit` the slowest).
	speed *= float(SHOTS[kind].get("rate", 1.0)) * lerpf(0.7, 1.7, clampf(_sev(), 0.0, 2.0) * 0.5)
	var want := travel / maxf(speed, 0.001)
	var share := lerpf(ARRIVE_SHARE_CALM, ARRIVE_SHARE_BUSY, clampf(_sev(), 0.0, 2.0) * 0.5)
	var room := medium.feed.hold_remaining() * share
	return clampf(minf(want, maxf(room, ARRIVE_FLOOR)), ARRIVE_FLOOR, ARRIVE_CEIL)


## Begin a shot on [param panel]. The only entry point for "look at something else": the Director's cut
## calls it, and so does a page turn.
func begin_shot(panel: int, turned := false) -> void:
	if medium._spread == null or medium._spread.panels.is_empty():
		return
	panel = clampi(panel, 0, medium._spread.panels.size() - 1)
	var r := RandomNumberGenerator.new()
	r.seed = hash([medium.feed.session_seed(), "comic-shot", medium._spread_i, panel, _shot_n])
	_shot_n += 1
	var kind := _pick_shot(r)
	# A zoom may be continued but never reversed without a hold between: `_zoom_dir` is cleared when a shot
	# arrives, so this asks whether the camera has held since it last changed the framing.
	if (kind == "pull" and _zoom_dir > 0) or (kind == "push" and _zoom_dir < 0):
		kind = "pan"
	var tgt := _target_for(r, panel, kind)
	var hard := bool(SHOTS[kind].get("hard", false)) and _worth_cutting(tgt)
	# The heading the hold will creep along, drawn once here rather than re-drawn per breath.
	var hd := Vector2(r.randf_range(-1.0, 1.0), r.randf_range(-1.0, 1.0))
	_shot = {
		"panel": panel,
		"kind": kind,
		# `secs` and `gap0` are filled in below, once the target exists to measure against.
		"arrived": false,
		"heading": hd.normalized() if hd.length() > 0.001 else Vector2.RIGHT,
	}
	_shot_t = 0.0
	_hold_t = 0.0
	_tgt = tgt
	# The rate is sized to the journey, which can only be measured once the target is set: how far this shot
	# has to go, at the speed it drew, converted to the follower rate that gets there.
	var travel: float = (_cam.aim as Vector2).distance_to(tgt.aim) \
		+ absf(log(maxf(float(tgt.fill), 0.01) / maxf(float(_cam.fill), 0.01))) * 0.25
	_shot["secs"] = _arrive_time(r, travel, kind)
	_shot["gap0"] = maxf(_pose_gap(), 0.001)
	if hard:
		_cut_to(tgt)
	if kind == "push":
		_zoom_dir = 1
	elif kind == "pull":
		_zoom_dir = -1
	if medium._spread_i >= 0:
		print("ghost: comic %s%s -> panel %d of spread %d" % [
			kind, (" (cut)" if hard else ""), panel + 1, medium._spread_i])


## The only place this file assigns the camera. Everything else integrates toward a target, so the number
## of discontinuities in a session is the number of calls to this (what tests/media/comic_motion_check.gd
## counts).
func _cut_to(pose: Dictionary) -> void:
	_cam = pose.duplicate()
	_snap = true                  # the placed rake and distance jump with it, or it tears


## Is this jump a different shot? See CUT_MIN_AIM.
func _worth_cutting(tgt: Dictionary) -> bool:
	if (tgt.aim as Vector2).distance_to(_cam.aim) < CUT_MIN_AIM:
		return false
	var sp := medium._spread
	return sp.framing_panel(sp.clamp_aim(_cam.aim)) \
		!= sp.framing_panel(sp.clamp_aim(tgt.aim))


## Draw a shot kind, weighted, with the discontinuity scaled by severity squared so that at
## camera 0 the camera never jump-cuts at all.
func _pick_shot(r: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in SHOTS:
		total += _shot_weight(String(k))
	if total <= 0.0:
		return "settle"
	var pick := r.randf() * total
	for k in SHOTS:
		pick -= _shot_weight(String(k))
		if pick <= 0.0:
			return String(k)
	return "settle"


func _shot_weight(kind: String) -> float:
	var w := float(SHOTS[kind]["w"])
	if bool(SHOTS[kind].get("hard", false)):
		return w * pow(clampf(_sev(), 0.0, 2.0), 2.0)
	return w


## Where a shot of [param kind] on [param panel] looks from, built as an offset from the panel's natural
## framing so every entry in shots is a distance rather than an absolute; severity scales the distances
## (see REACH_CALM).
func _target_for(r: RandomNumberGenerator, panel: int, kind: String) -> Dictionary:
	var spec: Dictionary = SHOTS[kind]
	var reach := _reach()
	var sp := medium._spread
	var base := sp.panel_center(panel)
	# The film panel is framed dead center and whole (see CONTAIN_FILL). Elsewhere the aim leans toward the
	# middle of its own page, which keeps the outer trim out of shot...
	if panel != medium._film_at:
		base = base.lerp(sp.page_center(panel), AIM_PULL)
	# ...and a wide shot leans most of the way there, because its subject is the page rather than the
	# panel (not all the way: the panel being read stays the composition's anchor).
	if bool(spec.get("wide", false)):
		base = sp.panel_center(panel).lerp(sp.page_center(panel), 0.75)
	var span: Array = spec["fill"]
	# The band barely narrows as the camera calms: collapsing it would give one close-up value for the whole
	# vocabulary. What a gentle camera does less of is traveling; how varied its framing is belongs to
	# composition.
	var fill := lerpf(1.0, r.randf_range(float(span[0]), float(span[1])),
		clampf(0.6 + reach * 0.4, 0.0, 1.0))
	var off := Vector2(r.randf_range(-1.0, 1.0), r.randf_range(-1.0, 1.0))
	off = off.normalized() if off.length() > 0.001 else Vector2.RIGHT
	var aim := base + off * float(spec["aim"]) * reach
	# The angles walk, they are not re-drawn: a big change of angle is spread over several shots.
	_az_walk = _walk(_az_walk, AZ_ARC * _sev(), r)
	_el_walk = _walk(_el_walk, deg_to_rad(EL_VARY_DEG) * _sev(), r)
	_roll_walk = _walk(_roll_walk, ROLL_VARY * _sev(), r)
	# The swing scales by the slider, not by reach: reach floors at REACH_CALM so a calm camera still
	# travels, but the contract at camera 0 is that the camera never turns, exactly. Distance and angle are
	# different promises and scale by different things.
	var az := _az_base + _az_walk \
		+ float(spec["az"]) * _sev() * (1.0 if r.randf() < 0.5 else -1.0)
	# A wide shot is exempt from settle_aim: that guard walks an aim toward its panel until enough panel is
	# under it, which suits a shot of a panel and destroys a shot of the page (gutters and neighbors are in
	# its composition by design).
	return {
		"aim": sp.clamp_aim(aim) if bool(spec.get("wide", false)) \
			else sp.settle_aim(sp.clamp_aim(aim)),
		"az": az,
		"el": clampf(_el_base + _el_walk, deg_to_rad(EL_MIN_DEG), deg_to_rad(EL_MAX_DEG)),
		"roll": _roll_base + _roll_walk,
		"fill": clampf(_panel_fill(panel) * fill, FILL.x * 0.6, PUSH_FILL.y),
		"fov": _lens_fov,
	}


## The framing a panel reads at: the middle of fill, so `fill` in shots is a multiplier of "this panel,
## filling the frame the way a panel should".
func _panel_fill(_panel: int) -> float:
	return (FILL.x + FILL.y) * 0.5


## How far this shot still has to go, normalized so that 1.0 is "arrived" on every channel.
func _pose_gap() -> float:
	var g: float = (_cam.aim as Vector2).distance_to(_tgt.aim) / GAP_AIM
	var fa := maxf(float(_cam.fill), 0.01)
	var fb := maxf(float(_tgt.fill), 0.01)
	g = maxf(g, absf(log(fb / fa)) / GAP_FILL)
	g = maxf(g, absf(angle_difference(float(_cam.az), float(_tgt.az))) / GAP_ANG)
	return g


## One frame of camera. Advance the shot, then follow.
func advance(delta: float) -> void:
	# The spread turns under the camera, slowly and forever, independent of the shot (the sheet is scenery,
	# the camera the performance). The rig is page-local, so this rotates the camera and the sheet by the
	# same matrix and the projection is invariant to it: it shows as the page living, not the shot moving.
	_att_target += _att_rate * delta
	var sway := Vector3(
		medium._mod.value("tilt") * 0.09,
		medium._mod.value("sway") * 0.12,
		medium._mod.value("roll") * 0.05) if medium._mod != null else Vector3.ZERO
	_att = _att.lerp(_att_target + sway, 1.0 - exp(-PAGE_EASE * delta))
	att_basis = Basis.from_euler(_att)
	if medium._spread == null or _tgt.is_empty():
		return
	_shot_t += delta
	# Arrival is A measurement, not A clock. The shot is over when the picture has got there.
	if not bool(_shot.get("arrived", false)) \
			and (_pose_gap() < ARRIVED or _shot_t > ARRIVE_CAP):
		_shot["arrived"] = true
		_hold_t = 0.0
		_hold_from = _tgt.aim
	if bool(_shot.get("arrived", false)):
		_hold_t += delta
		# The hold is what earns A reversal - and it has to be a hold. See ZOOM_FREE.
		if _hold_t >= ZOOM_FREE:
			_zoom_dir = 0
		# ...and a held shot still breathes, along the heading this shot was given, measured from where it
		# arrived so the excursion is bounded however long the hold runs. It does not saturate (clamping
		# froze the picture after HOLD_CREEP_TIME); it keeps creeping, and settle_aim walks the aim back
		# near the panel's edge, so the drift is limited by the geometry rather than by a clock.
		var creep := _hold_t / HOLD_CREEP_TIME
		# Not scaled by reach: a held shot is held at every setting; the slider changes how far the camera
		# travels between subjects, not how still it is once arrived (scaling made a busy camera drift
		# through its holds fast enough that they stopped reading as holds).
		_tgt["aim"] = medium._spread.settle_aim(medium._spread.clamp_aim(_hold_from
			+ (_shot["heading"] as Vector2) * HOLD_CREEP * creep))
	_follow(delta)
	place_eye(delta)


## The follower, speed-limited rather than exponential. A pure exponential covers 63% of its distance in
## one time constant and then crawls, so a shot given ten seconds does nearly all its visible movement in
## the first second or two and converges invisibly after: a fast transition followed by nothing.
##
## So the journey advances at a constant fraction per second (the same ground in the ninth second as in
## the first) and eases only over the last of it, so a pan reads as a pan rather than a snap with a tail.
## It remains an integration: `_cam` is never assigned, a cut mid-journey is simply a new target, and
## nothing here can teleport the picture.
func _follow(delta: float) -> void:
	var secs := maxf(float(_shot.get("secs", 6.0)), 0.1)
	# How much of the original journey to cover this frame...
	var step := delta / secs
	# ...eased out over the last of it so the shot lands; above the taper the speed is flat (the
	# constant-rate pan).
	var left := _pose_gap() / maxf(float(_shot.get("gap0", 1.0)), 0.001)
	if left < ARRIVE_TAPER:
		# Floored well above zero: a taper that trails off to nothing means the shot never converges and
		# ARRIVE_CAP, the safety net, ends every shot at exactly its value. This lands the shot.
		step *= maxf(smoothstep(0.0, ARRIVE_TAPER, left), 0.45)
	var kp := clampf(step / maxf(left, 0.001), 0.0, 1.0)
	var ka := clampf(kp * RATE_ANGLE, 0.0, 1.0)
	_cam["aim"] = (_cam.aim as Vector2).lerp(_tgt.aim, kp)
	_cam["fill"] = lerpf(float(_cam.fill), float(_tgt.fill), kp)
	_cam["az"] = float(_cam.az) \
		+ angle_difference(float(_cam.az), float(_tgt.az)) * ka
	_cam["el"] = lerpf(float(_cam.el), float(_tgt.el), ka)
	_cam["roll"] = lerpf(float(_cam.roll), float(_tgt.roll), ka)
	_cam["fov"] = lerpf(float(_cam.fov), float(_tgt.fov), ka)


## Put the eye on its spread-local spherical offset from where the camera is aiming. The offset direction
## is built in spread space and then rotated by the sheet's attitude, so it is a fixed station relative to
## the paper: traveling from panel to panel slides the camera across the spread at a constant angle, the
## copy-stand move the eye reads as flying over a comic (building it in world space would swing the angle
## whenever the sheet moved).
func place_eye(delta := 0.0) -> void:
	if medium._spread == null:
		return
	var sp := medium._spread
	var aim: Vector2 = sp.clamp_aim(_cam.aim)
	var c := sp.world(aim, att_basis)
	# A field scene is raked gently, a subject hard - see FIELD_FLATTEN.
	var fp := sp.framing_panel(aim)
	# The film panel is shown whole (see CONTAIN_FILL), only while it is the panel the shot is built around;
	# a film at the edge of a wide shot is just another picture and does not decide the framing.
	var contain: bool = fp >= 0 and fp == medium._film_at
	var flat := maxf(_flatten(), FILM_FLATTEN if contain else 0.0)
	# Followed, not adopted: `_flatten()` reads the panel being read, so it steps the instant the Director
	# cuts between a field scene and a subject one (up to 21.7 degrees of elevation in a frame), and
	# `contain` steps as the aim crosses the film panel's edge. Nothing in the shot vocabulary sees either.
	if _snap or _dist_s < 0.0 or delta <= 0.0:
		_flat_s = flat
	else:
		_flat_s += (flat - _flat_s) * (1.0 - exp(-RATE_FLAT * delta))
	flat = _flat_s
	var el: float = lerpf(float(_cam.el), PI * 0.5, flat)
	var roll: float = float(_cam.roll) * (1.0 - flat * 0.7)
	_roll = roll
	_fov = float(_cam.fov)
	var dir := att_basis * Vector3(cos(_cam.az) * cos(el), sin(_cam.az) * cos(el), sin(el))
	# Scale is set by whichever panel the aim is inside, not the nearest center nor the one being read: a
	# traveling move spends most of its time between panels. See ComicSpread.framing_panel.
	var pw := sp.panel_world(fp, att_basis)
	_cam["aim"] = aim
	# Zoom is coupled to content (see ComicSpread.CONTENT_CORE): off a panel the requested fill is ignored
	# and the shot opens to OFF_FILL, so the camera cannot be tight on a gutter or a corner however a move
	# was planned. How far it opens is a severity question too: a 1.7x swing in the rendered framing on
	# every lateral move is invisible to the move vocabulary, buys almost nothing at a gentle setting, and
	# earns its keep at a severe one (a push at 3.8 and a gutter at that framing).
	var eff := lerpf(_open_to(), float(_cam.fill), sp.content_at(aim))
	if contain:
		eff = minf(eff, CONTAIN_FILL)
	# Two constraints, the nearer wins. The first frames the panel: near enough that it spans `eff` frames
	# top to bottom. The second frames the spread: near enough that the sheet covers the frame on both axes
	# (a spread is 1.33 wide against a 1.78 frame, so covering the width covers the height with room to
	# spare).
	# The whole video wins over the covering solve, deliberately: the two conflict on a wide panel at a
	# rake (containing it wanted 3.03 units, covering allowed 2.13), and letting the cover win crops a face
	# out of frame to keep a strip of desk off it. FILM_FLATTEN keeps the price small.
	var cov := _cover(sp.world_corners(att_basis), c, dir)
	if contain:
		cov *= CONTAIN_DESK
	var d := minf(_fit(pw, c, eff, dir, contain), cov)
	# ...and never nearer than this: pushing in until the camera is inside one panel's artwork is a shot of
	# a texture, with no page, gutter or comic in it. The near floor never applies to a contained panel: the
	# camera stops where the picture fits.
	var near := 0.0
	if not contain:
		near = _fit(pw, c, CROP_MAX, dir)
		d = maxf(d, near)
	# ...and so is the distance: `pw` changes panel as the aim crosses a gutter and the solve changes branch
	# at the film panel's edge (3.03 against 2.13 and 7.76 against 4.62 world units either side).
	if _snap or _dist_s < 0.0 or delta <= 0.0:
		_dist_s = d
		_snap = false
	else:
		_dist_s += (d - _dist_s) * (1.0 - exp(-RATE_DIST * delta))
	# The follower may lag but may not break the two constraints: `cov` is the farthest the eye may sit and
	# still have paper across the whole frame, `near` the closest without being inside one panel's artwork.
	# Easing is for the interior of the feasible range; a follower drifting outside it shows desk.
	_dist_s = minf(_dist_s, cov)
	if near > 0.0:
		_dist_s = maxf(_dist_s, near)
	_eye = c + dir * _dist_s
	_look = c


## How far toward square-on the rake is pulled for the panel currently being read: zero for a subject,
## FIELD_FLATTEN for a field.
func _flatten() -> float:
	var sc := medium._focal()
	return FIELD_FLATTEN if (sc != null and sc.framing == "field") else 0.0


## How much of the frame the sheet covers. 1.0 when there is paper under all four corners of the picture;
## below that, how far the worst corner falls outside the sheet as a fraction of half the frame height (0.92
## is a sliver of desk in one corner, 0.5 a wedge across the shot). Read by tests/media/comic_look_probe.gd.
##
## Four corners, not the bounding box of the projected sheet: a bounding box never looks up or down (a
## clean 1.00 on a frame with a band of desk across the top) and is not the sheet (a raked, rolled quad has
## a box that reaches every edge while the quad cuts a corner off).
func page_coverage() -> float:
	if medium._spread == null:
		return 1.0
	var u := minf(medium._stage_size.x, medium._stage_size.y)
	var hx := (medium._stage_size.x * 0.5) / maxf(u, 1.0)
	var hy := (medium._stage_size.y * 0.5) / maxf(u, 1.0)
	var q := _sheet_poly(medium._spread.world_corners(att_basis), lens)
	if q.size() < 3:
		return 1.0                     # every corner behind the eye: the sheet is all around
	return clampf(1.0 + _quad_clearance(q, hx, hy) / maxf(hy, 1e-4), 0.0, 1.0)


## The sheet's outline in screen space, clipped to the near plane. A perspective projection cannot express
## a point behind the eye, and a spread (4 world units across) puts its far corners behind the eye at the
## reading distance while a wedge of desk remains in the opposite corner, so abandoning the draw (or
## declaring it covered) would report 1.00 on exactly the picture the coverage number exists to catch.
## Sutherland-Hodgman against the one plane turns the quad into at most a pentagon and gives the true
## silhouette, so the corner test is exact at any framing.
func _sheet_poly(pts: Array, view: Lens3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % n]
		var da := view.depth(a) - view.near
		var db := view.depth(b) - view.near
		if da >= 0.0:
			var pa := view.project(a)
			out.append(Vector2(pa.x, pa.y))
		if (da >= 0.0) != (db >= 0.0):
			# where the edge crosses the plane, in world space, so the projection is of a point in front
			var t := da / (da - db)
			var pc := view.project(a.lerp(b, t))
			out.append(Vector2(pc.x, pc.y))
	return out


## The signed distance from the worst frame corner to the edges of the projected quad [param q], in
## unit-fraction units. Positive means every corner of the frame is inside the quad (the sheet covers the
## picture); negative is how far the worst one sticks out. The quad is convex (a planar rectangle under
## perspective), so a point is inside when it is on the same side of all four edges, and the least of the
## four signed distances, again the least over the four frame corners, gives one number. Wound from the
## quad's own signed area, since roll can put the sheet either way round on screen.
func _quad_clearance(q: PackedVector2Array, hx: float, hy: float) -> float:
	var n := q.size()
	if n < 3:
		return 0.0
	var area := 0.0
	for e in n:
		var a: Vector2 = q[e]
		var b: Vector2 = q[(e + 1) % n]
		area += a.x * b.y - b.x * a.y
	var wind := 1.0 if area >= 0.0 else -1.0
	var worst := INF
	for cx: float in [-hx, hx]:
		for cy: float in [-hy, hy]:
			for e in n:
				var a: Vector2 = q[e]
				var b: Vector2 = q[(e + 1) % n]
				var d := b - a
				var edge := d.length()
				if edge < 1e-9:
					continue
				# signed distance to the edge line, positive on the quad's inside
				var side := wind * (d.x * (cy - a.y) - d.y * (cx - a.x)) / edge
				worst = minf(worst, side)
	return 0.0 if worst == INF else worst


## How much of the frame the panel being read takes up, on its worst axis: 1.0 exactly spans the picture;
## above 1 the screen is cropping into it (intended for an abstract field, wrong for footage - see
## CONTAIN_FILL). Read by tests/media/comic_look_probe.gd.
func read_panel_fit() -> float:
	if medium._spread == null or medium._read < 0 or medium._read >= medium._spread.panels.size():
		return 0.0
	var u := minf(medium._stage_size.x, medium._stage_size.y)
	var hx := (medium._stage_size.x * 0.5) / maxf(u, 1.0)
	var hy := (medium._stage_size.y * 0.5) / maxf(u, 1.0)
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for w in medium._spread.panel_world(medium._read, att_basis):
		var pr := lens.project(w)
		if pr.z <= lens.near:
			return 99.0                # wrapping the eye: as cropped as it gets
		lo = lo.min(Vector2(pr.x, pr.y))
		hi = hi.max(Vector2(pr.x, pr.y))
	return maxf((hi.x - lo.x) / (2.0 * maxf(hx, 1e-4)),
		(hi.y - lo.y) / (2.0 * maxf(hy, 1e-4)))


## Why the current shot is framed where it is: the numbers that decide it, for the probe.
func shot_debug() -> String:
	if medium._spread == null:
		return ""
	var sp := medium._spread
	var aim: Vector2 = sp.clamp_aim(_cam.aim)
	var c := sp.world(aim, att_basis)
	var fp := sp.framing_panel(aim)
	var contain: bool = fp >= 0 and fp == medium._film_at
	var flat := maxf(_flatten(), FILM_FLATTEN if contain else 0.0)
	var el: float = lerpf(float(_cam.el), PI * 0.5, flat)
	var dir := att_basis * Vector3(cos(_cam.az) * cos(el), sin(_cam.az) * cos(el), sin(el))
	var eff := lerpf(_open_to(), float(_cam.fill), sp.content_at(aim))
	if contain:
		eff = minf(eff, CONTAIN_FILL)
	var cov_d := _cover(sp.world_corners(att_basis), c, dir)
	return "el %.0fdeg flat %.2f contain %s fit %.2f cover %.2f eye %.2f att(%.2f %.2f %.2f)" % [
		rad_to_deg(el), flat, "Y" if contain else "n",
		_fit(sp.panel_world(fp, att_basis), c, eff, dir, contain), cov_d,
		(_eye - c).length(), _att.x, _att.y, _att.z]


## The eye made into [member lens], once a frame after [method advance]: what the page is drawn through
## and [method panel_rect] measures with.
func prepare_lens() -> void:
	lens.eye = _eye
	lens.look = _look
	lens.fov = _fov
	# Camera up must not be world up: at a hard rake the view axis can come within a few degrees of it and
	# the basis collapses (Lens3D falls back and the picture rolls through 90 degrees in one frame). The
	# sheet's own up is always perpendicular to the paper's normal, so it is stable, and it makes the
	# sheet's roll show as a tilted horizon.
	var fwd := (_look - _eye)
	fwd = fwd.normalized() if fwd.length() > 1e-6 else Vector3.FORWARD
	var up := att_basis * Vector3.UP
	if absf(up.dot(fwd)) > 0.9:
		up = att_basis * Vector3.RIGHT     # grazing along the sheet's up axis
	lens.up = Basis(fwd, _roll) * up
	lens.prepare()


## The framing distance: how far along [param dir] the eye must sit for [param pts] to span [param fill]
## frames vertically. Vertical only (the difference between a comic and a slideshow of pages): fitting both
## axes would put a panel narrower than 16:9 entirely inside the frame, leaving the rest to the trim and the
## desk; on height the panel spans the frame and the sides are the gutter and neighboring panels.
##
## Solved by bisection: the view basis turns as the distance changes, so there is no single inequality to
## rearrange. Exact at any rake.
##
## The half-extent is 0.5, not 1: Lens3D projects into ghost's unit-fraction space, which the caller
## multiplies by unit() (the shorter screen axis), so the visible vertical range is +/- (H/2)/min(W,H) = +/- 0.5.
## [param contain] fits the points on both axes instead of on height alone, so nothing overflows the frame
## (see CONTAIN_FILL).
func _fit(pts: Array, c: Vector3, fill: float, dir: Vector3, contain := false) -> float:
	var u := minf(medium._stage_size.x, medium._stage_size.y)
	# fill is how many frames tall the panel should be, so a bigger fill is a nearer camera.
	var hy := (medium._stage_size.y * 0.5) / maxf(u, 1.0) * fill
	var hx := (medium._stage_size.x * 0.5) / maxf(u, 1.0) * fill
	var probe := _fit_lens
	probe.fov = _fov
	probe.look = c
	probe.up = lens.up
	var lo := 0.15
	var hi := 24.0
	for _iter in SOLVE_STEPS:
		var mid := (lo + hi) * 0.5
		probe.eye = c + dir * mid
		probe.prepare()
		var fits := true
		for pt in pts:
			var pr := probe.project(pt)
			if pr.z <= probe.near or absf(pr.y) > hy \
					or (contain and absf(pr.x) > hx):
				fits = false
				break
		if fits:
			hi = mid
		else:
			lo = mid
	return hi


## How many halvings the two solvers take: sixteen resolves the 0.15-24 bracket to about 0.0004 world units,
## far past anything a camera distance can show.
const SOLVE_STEPS := 16


## The covering distance: the farthest the eye may sit along [param dir] while [param pts] still span the
## whole frame on both axes; beyond it you can see past them. The mirror of [method _fit], bisecting the
## other way (a projection shrinks with distance, so "fits inside" is true beyond some distance and "covers"
## within one).
func _cover(pts: Array, c: Vector3, dir: Vector3) -> float:
	var u := minf(medium._stage_size.x, medium._stage_size.y)
	var hx := (medium._stage_size.x * 0.5) / maxf(u, 1.0)
	var hy := (medium._stage_size.y * 0.5) / maxf(u, 1.0)
	var probe := _cover_lens
	probe.fov = _fov
	probe.look = c
	probe.up = lens.up
	var lo := 0.15
	var hi := 24.0
	var best_d := 0.15
	var best_clear := -1e9
	for _iter in SOLVE_STEPS:
		var mid := (lo + hi) * 0.5
		probe.eye = c + dir * mid
		probe.prepare()
		# Clipped, not abandoned, when a corner goes behind the eye (see _sheet_poly). An empty polygon means
		# every corner is behind, the most covered case; reading that as "does not cover" inverts the search.
		var q := _sheet_poly(pts, probe)
		# Covers when every corner of the frame has paper under it: the same test page_coverage() reports, so
		# the solve and the measurement agree on what "covered" means.
		var clear := 1e9 if q.size() < 3 else _quad_clearance(q, hx, hy)
		# Remember the best distance seen, for the case where none of them cover - see below.
		if clear > best_clear:
			best_clear = clear
			best_d = mid
		if clear >= 0.0:
			lo = mid
		else:
			hi = mid
	# Did anything cover at all? The bisection assumes covering is true near and false far. When the sheet
	# cannot cover the frame at any distance (a hard rake and a rolled page can leave a corner off the paper
	# however close the camera gets), `lo` never moved, and returning it would hand the caller 0.15 world
	# units as a near bound, pinning the eye inside a panel's artwork. Returning a huge number instead would
	# be worse: this value is a constraint the caller takes the minimum with, so switching it between about
	# two world units and 1e9 in one frame releases that constraint completely and the camera leaves at
	# whatever speed the framing solve alone asks for (a snapped rubber band).
	#
	# So when nothing covers, return the distance that came closest to covering: approaching the boundary
	# from the uncoverable side, it approaches the boundary itself, so the value is continuous across the
	# transition.
	if best_clear < 0.0:
		return best_d
	return lo


## Panel [param i]'s bounding box on screen, for the visibility test.
func panel_rect(i: int) -> Rect2:
	var u := minf(medium._stage_size.x, medium._stage_size.y)
	var origin := medium._stage_size * 0.5
	var r := Rect2()
	var first := true
	for w in medium._spread.panel_world(i, att_basis):
		var pr := lens.project(w)
		if pr.z <= lens.near:
			return Rect2(Vector2.ZERO, medium._stage_size)    # partly behind the eye: assume on screen
		var p := Vector2(pr.x, pr.y) * u + origin
		if first:
			r = Rect2(p, Vector2.ZERO)
			first = false
		else:
			r = r.expand(p)
	return r
