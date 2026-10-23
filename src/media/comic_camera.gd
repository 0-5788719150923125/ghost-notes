extends RefCounted
class_name ComicCamera

## ComicCamera - THE EYE OVER THE SPREAD: where the camera is, where it is going, and the lens the
## page is drawn through. A part of [ComicMedium] (next/structure.md, "One file, one job").
##
## Each spread picks one SET-UP ([method choose_look]: a side of the sheet, a height, a tilt, a
## lens, and the rake the sheet itself is turned to and drifts on), and every shot varies inside it.
## A cut, or the leaf turning, begins a SHOT ([method begin_shot]): a subject on the page and a way
## of looking at it, drawn from [constant SHOTS]. Each frame [method advance] walks the camera
## toward it and [method place_eye] turns the followed pose into an eye - framed on the panel under
## the aim, opened where there is none, never so far that the sheet stops covering the frame nor so
## near that the shot is inside one panel's artwork. [member lens] is what the medium draws through,
## and [method panel_rect] where a panel lands on screen.
##
## IT HOLDS ITS OWN STATE (the sheet's attitude, the set-up and its walks, the pose and its target,
## the shot, the lenses) and reads the rest through [member medium]: the spread and the panel being
## read, the film panel, the focal scene's framing, the stage's size, the show's feed (the seed, the
## Camera knob, the hold left on the scene) and the mod bank the sheet sways on. Where a point lies
## on the paper and which panel holds it are [ComicSpread]'s. [method reset] puts all of it back
## as a new book finds it.
##
## THE CAMERA STATE IS NEVER ASSIGNED, ONLY INTEGRATED. That sentence is the whole design, and
## everything below exists to keep it true. `_cam` follows `_tgt` exponentially, every frame,
## forever; the single exception is _cut_to, which is the only function in this file that
## writes `_cam` outright and is therefore the only place a discontinuity can come from.
##
## WHAT THIS REPLACES AND WHY. A move used to be a pair of poses, a duration and an ease curve,
## with the frame step interpolating between them. That made continuity a CONVENTION that thirteen
## branches were each expected to honor - and at least two of them did not, while the comment
## above them asserted that none did. It also meant "is the camera holding" was a question about
## which of thirteen names was active, so every fix had to be restated for each. Four rounds of
## guards were spent on defects that were all one defect: nothing owned how much the picture may
## change in a frame.
##
## THE OTHER HALF OF THE SAME BUG WAS BELOW THE MOVE LAYER. place_eye derives the rake from the
## panel being READ, the scale from whichever panel the aim is inside, and the distance from a
## solve that changes branch at the film panel's edge. Those are step functions no move-layer
## guard can reach - measured at up to 21.7 degrees of elevation in a single frame - so `flat`
## and the eye distance are follower channels here too.
##
## AND SPEED IS A RATE, NOT A DURATION. The old `_budget` sampled a duration and then capped it
## at a share of the Director's hold, so on a long hold the SAMPLE was the binding constraint
## and the slider stopped mattering: at scene hold 4.0 a "gentle" drift ran 27 s and chained
## another. There is no duration here. A shot has a target and a closing rate, it arrives when
## it arrives, and a cut that interrupts it is graceful because the follower simply retargets.

## The [ComicMedium] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var medium: ComicMedium

## HOW MUCH OF THE FRAME A CONTAINED PANEL MAY FILL, on its LONGER axis.
##
## Every other panel is framed on HEIGHT alone and allowed to overflow the sides - that is the
## whole difference between a comic read close and a slideshow of pages, and it is right for an
## abstract field, where any part of it is as good as any other part.
##
## A PIECE OF FOOTAGE IS NOT AN ABSTRACT FIELD. "It can look very strange to zoom in to a
## specific corner of the embedded video, where nothing is happening in it... a video with a
## girl speaking in it, you really don't want to focus the camera on her door to the side."
## Exactly so: a 1.9-aspect film panel framed to span the frame's height is nearly twice as
## wide as the screen, so what is on show is a third of the picture and the subject is as
## likely to be off it as on it. A contained panel is fitted on BOTH axes, so the whole video
## is in shot, whole, every time it is the one being read.
##
## JUST UNDER 1, not comfortably under it. Every notch of margin here is bought by pulling the
## camera further off the sheet, and past the covering distance that is paid for in desk: at
## 0.88 the video was whole with a pleasant border and the page covered only 0.63 of the frame,
## which is a wedge of nothing across a third of the picture. At 0.98 the video still arrives
## whole - it simply reaches the edges of the shot instead of floating inside them.
const CONTAIN_FILL := 0.98
## ...and however much the video wants revealing, the camera stops this far past the distance
## at which the sheet still covers the frame. A face cropped out of shot is worse than a sliver
## of desk; a face floating in a sea of desk is worse than both, and without a bound that is
## where an extreme panel aspect would put it.
##
## A SLIVER, and the first value was not one. At 1.22 the camera could sit 22% past the
## covering distance, and measured on a real session that produced page coverage of 0.67 -
## a third of the picture was the surface the book is lying on, which is the defect the whole
## spread exists to remove, arriving through the one door left open for it. Six percent is
## enough to rescue the ordinary conflict and not enough to be seen; past that the panel is
## simply framed as tightly as covering allows and takes the crop.
## ONE, and the argument for anything above it was wrong. Going past the covering distance is
## the ONLY way desk enters a shot, and measured on a real spread six percent past cost ten
## percent of the coverage - the relationship is far steeper than it looks. Worse, it did not
## even buy the thing it was spent on: containing that panel wanted 7.76 world units against a
## cover of 4.62, so a cap of 4.89 left the video cropped AND put desk in the corner, which is
## both prices for neither benefit. The camera now stops where covering stops, and the video is
## contained as far as that allows - see FILM_FLATTEN, which is what makes that far enough.
const CONTAIN_DESK := 1.0
## HOW FAR TOWARD SQUARE-ON A CONTAINED PANEL PULLS THE SHEET, 0..1. Harder than
## FIELD_FLATTEN, and for a stronger version of the same reason: a rake foreshortens the sheet,
## so a raked page needs the camera NEARER to keep paper across the frame - which is exactly
## the constraint that fights containing a wide panel. Measured on a rolled spread at a
## moderate rake: containing the widest panel wanted 3.03 world units while the sheet stopped
## covering the frame past 2.13. Flattening buys most of that back, and it is also just the
## right shot: a face is the most recognizable thing this medium ever puts on the page, and a
## hard angle across a face reads as damage rather than as depth.
## LOWERED FROM 0.78, and the first value had the sign of its own effect backwards. Flattening
## turns the sheet square-on, which presents the panel at its FULL area - so the harder it
## flattens, the further the camera must retreat to fit the whole panel in, and containment
## becomes unaffordable inside the covering budget (measured: a fit of 7.76 against a cover of
## 4.62 at 83 degrees). A gentler flatten leaves the panel foreshortened, which is smaller,
## which fits nearer. The face is still turned toward the camera - that was the point - it is
## simply not pressed flat against the glass.
const FILM_FLATTEN := 0.40

## SPREAD ATTITUDE, in radians - the rest pose the book is rolled into, on all three axes.
## Generous on purpose: the point of putting the paper in a real 3D world is that it can be
## TURNED, and at the reading distance a raked page is what reveals it has depth at all. A
## few degrees reads as a crooked scan rather than as a camera angle.
##
## YAW IS TIGHTER THAN IT WAS (it went to 0.85). A spread is twice as wide as the page these
## were tuned on, so the same yaw that raked one page pleasantly foreshortens the far page of
## a spread into a sliver and throws its far corners behind the eye.
##
## THE SHEET'S ATTITUDE DOES NOT COST COVERAGE, which is worth writing down because it looks
## as though it should. Swept one axis at a time against page_coverage() on a real spread:
## pitch, yaw and roll each held 1.00 across their WHOLE range, while camera elevation ran
## 0.34 / 0.84 / 1.00 / 1.00 / 1.00 / 1.00 from 30 to 80 degrees. Rake the paper as hard as you
## like; it is how low the CAMERA sits that decides whether the picture is all paper. See
## EL_MIN_DEG.
const PITCH := 0.55
const YAW := 0.44
const ROLL := 0.40
## ...and it never stops moving. Radians per second of slow continuous drift, so the sheet
## turns under the camera through the whole spread rather than settling into a pose.
const DRIFT := 0.035

## CAMERA ELEVATION off the paper, in degrees. Never square-on (at 90 the perspective
## camera and the page agree and the panel is a flat rectangle again) and never grazing
## (the panel foreshortens into a line).
##
## THE FLOOR CAME UP, from 32, and this is the one number that decides whether there is desk
## in the picture. Measured by sweeping each axis alone against page_coverage() on a real
## spread: the sheet's own pitch, yaw and roll each held 1.00 across their entire range, and
## elevation ran 0.34 at 30 degrees, 0.84 at 40, and 1.00 from 50 up. The reason is simply
## foreshortening - a low camera sees the sheet edge-on and it shrinks along one axis faster
## than any distance can compensate for, so no framing solve can put paper across the frame.
##
## Everything else was tried first and did nothing, because everything else was the wrong
## axis. A spread at 0.90 coverage for every shot it had was reported as a wedge of desk, and
## the page's roll was reduced on the assumption that a rotated rectangle was cutting the
## corners. It changed the number not at all.
const EL_MIN_DEG := 46.0
const EL_MAX_DEG := 72.0
## Camera roll about the view axis - the Dutch angle, on top of the page's own roll.
const CAM_ROLL := 0.22

## HOW FAR ONE SHOT MAY DEPART FROM THE SPREAD'S SET-UP. This is the fix for "it just bounces
## all over the place... a camera ping-ponging around at random angles".
##
## Every shot used to re-roll its azimuth over the whole circle, its elevation over the
## whole range, its roll and its focal length - independently, at every reading advance. So
## consecutive shots were unrelated positions, and the interpolation between them was a
## camera swinging across the page for no reason. Smoothing it does not help: the problem
## is not the transition, it is that there is nothing in common between where it was and
## where it is going.
##
## So a spread picks ONE set-up - a side, a height, a tilt, a lens - and a shot varies inside
## it. That is coverage rather than chaos, and staying on one side of the subject is the
## oldest rule in the grammar (the 180-degree line). Changing sides is now a PAGE turn,
## which is the one moment where a new set-up reads as a new scene rather than as a mistake.
const AZ_ARC := 0.42              # +/- radians of orbit around the spread's side (~24 deg)
const EL_VARY_DEG := 7.0          # +/- degrees of height off the spread's own
const ROLL_VARY := 0.05           # +/- radians of Dutch on top of the spread's own

## HOW MUCH OF ITS ARC ONE SHOT MAY SPEND, as a fraction. This is the fix for "the camera can
## rotate/turn A LOT every time it shifts from one frame to another".
##
## The angles used to be an INDEPENDENT DRAW per cut: every reading advance re-rolled the
## azimuth anywhere in +/-AZ_ARC, so two consecutive shots could differ by the whole 48-degree
## span, and at a cut every few seconds that is a camera swinging back and forth about a mean.
## Staying inside the arc was never the problem - the problem was arriving anywhere in it in
## one step.
##
## So the angles are a bounded RANDOM WALK instead. A shot moves them by at most this fraction
## of the arc and the walk is clamped to it, so the same total excursion is still reachable -
## it is just spread over several shots, which is what "rotates more gently, over multiple
## per-frame pans" asks for. At a third of the arc it takes three or four cuts to cross, and
## the walk keeps its direction long enough to read as one continuous move rather than as
## jitter.
const ANG_STEP := 0.34
## The lens, chosen once per spread. Narrower than it was (it went to 64): a wide lens this
## close to a panel bends its edges, which is the "unfocused, distorted" half of the report.
const FOV := Vector2(38.0, 54.0)

## HOW TALL THE PANEL BEING READ IS, in frames. 1.0 spans the frame exactly top to bottom;
## above that it overflows and the screen crops into it.
##
## THE FLOOR CAME DOWN, from 1.00 to 0.78, and that is the spread paying for itself. The old
## floor existed because a shot looser than "the panel IS the picture" put a portrait page
## inside a landscape frame and filled the rest with desk - so a wide shot was not a shot,
## it was a framing failure. A spread covers the frame at a much looser shot, so a panel at
## 0.78 frames tall now sits inside a picture that is entirely paper and neighboring
## panels. That is a comic being READ rather than a video with a border, and it is the shot
## the vocabulary was missing.
const FILL := Vector2(0.78, 1.30)
## The hard near limit, in frames of panel height - however much the spread wants covering,
## the camera stops here. Past about this the panel stops reading as a panel.
##
## SET GENEROUSLY, and the first value was not. At 2.2 this floor came out FURTHER from the
## page than the covering distance did (measured 1.66 against 1.24) and so it, not the
## framing, decided every shot - vetoing exactly the push-in that fills the frame and
## leaving the strip of desk down the side that this whole pass exists to remove. A floor
## that binds in the ordinary case is not a floor, it is the rule.
const CROP_MAX := 4.5
## How far the aim is pulled from the panel's center toward the middle of ITS OWN PAGE. A
## panel at the outer trim, framed dead on, puts the trim edge - and the void behind the
## paper - into shot; pulling the aim in keeps the sheet under the panel at every panel.
##
## TOWARD THE PAGE, NOT THE SPREAD, and that distinction only exists because of the spread.
## The middle of a spread IS THE SPINE - the widest gutter on the sheet - so pulling every
## aim toward it biases every shot toward the one place with no picture in it, which is the
## defect this pass exists to remove arriving by the other door. Pulling toward the page's
## own center keeps the original purpose exactly: the risk was always the OUTER trim, and
## the inner edge has a whole second page beyond it.
const AIM_PULL := 0.12

## The spread's own attitude eases at its own, much slower rate - it is scenery, not a move.
const PAGE_EASE := 0.7

## THE LENS THE PAGE IS DRAWN THROUGH: prepared once a frame from the eye ([method prepare_lens]),
## and read by the medium's drawing and by [method panel_rect].
var lens := Lens3D.new()
## The two solver lenses, allocated ONCE. They used to be built inside _fit and _cover,
## which is three RefCounted allocations per frame inside a 22-iteration bisection (measured
## by perf_probe). Neither survives the call, so neither needed to be new.
var _fit_lens := Lens3D.new()
var _cover_lens := Lens3D.new()

# THE SPREAD'S ATTITUDE, eased toward a target that itself DRIFTS. Sampled on all three axes
# with real magnitude: a book that only pitches a few degrees reads as a slightly crooked
# scan, and the whole reason to put the sheet in a real 3D world is that it can be turned.
var _att := Vector3.ZERO
var _att_target := Vector3.ZERO
var _att_rate := Vector3.ZERO     # slow continuous drift, per second
## The attitude as a BASIS, rebuilt once per advance() and read by everything that places a
## point on the paper. It used to be built inside the world mapping (then _page_point) - six
## trigonometric evaluations and a 3x3 construction, per vertex, roughly 2500 times a frame
## with the identical argument, and the live-performance audit (2026-09-03, perf_probe)
## attributed most of the page's ~18 ms of _draw to it. Hoisting it is exact: the value was always the same.
var att_basis := Basis.IDENTITY

# THE CAMERA STATE, expressed in SPREAD-LOCAL SPHERICAL rather than as a world position: an
# azimuth around the aim and an elevation off the paper. That is what makes the rake real -
# an eye on the sheet's normal sees a flat rectangle however the sheet is rotated - and it is
# also what makes traveling between panels a move PARALLEL TO THE PAPER, because the
# direction is held and only the point it looks at changes.
# Keys: aim (spread coords), az, el, roll, fill, fov. See _target_for, which builds one.
## The spread's SET-UP: the side the camera is on, its height, its tilt and its lens. Fixed
## for the spread; see AZ_ARC.
var _az_base := 0.0
var _el_base := 1.0
var _roll_base := 0.0
var _lens_fov := 46.0
## The bounded walk each angle is currently at, as an offset from its base. See ANG_STEP.
var _az_walk := 0.0
var _el_walk := 0.0
var _roll_walk := 0.0

## WHERE THE CAMERA IS: the pose the follower integrates, keyed as above - and where a new book
## starts it ([method reset]).
const POSE_AT_REST := {"aim": Vector2(1.0, 0.7), "az": 0.0, "el": 1.0, "roll": 0.0,
	"fill": 1.1, "fov": 52.0}
var _cam := POSE_AT_REST.duplicate()
## WHERE THE CAMERA IS GOING. `_cam` follows this, every frame, and nothing else moves the
## camera - see the class doc.
var _tgt := {}
## The shot in progress: {panel, kind, rate, arrived, heading}. A shot is a SUBJECT and a way
## of looking at it, not a path; where the camera is on the way there is the follower's
## business.
var _shot := {}
var _shot_t := 0.0
## Seconds since the shot arrived, and the aim it arrived at - the origin the held shot creeps
## from. Measuring the creep from the ARRIVAL rather than from the last frame is what bounds
## it however long the hold runs.
var _hold_t := 0.0
var _hold_from := Vector2.ZERO
## Shots begun this session, part of the seed so each is reproducible without repeating.
var _shot_n := 0
## Which way the framing is currently going: +1 tightening, -1 opening, 0 neither. Cleared
## when a shot ARRIVES, which is what makes "no reversal without a hold between" expressible.
var _zoom_dir := 0
## Set by a declared discontinuity, and the only thing that lets the placed rake and distance
## skip their followers. See _cut_to.
var _snap := true
## The followed halves of place_eye: the rake pulled toward square-on, and the eye distance.
## Both are derived from quantities that STEP - see RATE_FLAT.
var _flat_s := 0.0
var _dist_s := -1.0
var _roll := 0.0                  # the roll actually in force (field-flattened)
var _eye := Vector3(0, 0, 3.0)
var _look := Vector3.ZERO
var _fov := 52.0

# --- the shot vocabulary, and the spread's set-up ---------------------------------------------

## THE SHOT VOCABULARY. A cut picks one of these and the camera travels TOWARD it.
##
## The first cut of this had no vocabulary: every cut set a new target and the camera eased
## toward it, which is a spring settling, not a camera. It gave one behavior - bounce to
## the next panel, sit on it, bounce again - and settling on a single panel is a shot that
## should be an EVENT, not the rule.
##
## The second cut gave each entry a DURATION and an EASE CURVE and let thirteen branches
## interpolate between two poses themselves, which made continuity a convention rather than a
## property and cost four rounds of guards that never converged. An entry is now a DESTINATION
## and a SPEED - see the note inside the table for what each key means - and one follower
## walks toward it every frame, so the only discontinuity a session can contain is a call to
## _cut_to. That is a property, and tests/media/comic_motion_check.gd counts it.
##
## THE BAG IS MOSTLY GENTLE, and that is a correction. It was first weighted the other way,
## in answer to "a constant shot of a single frame should be an event, not the rule" - and
## it overshot: 41% of the weight began somewhere else entirely, so two shots in five opened
## on a jump. Read back as "it just bounces all over the place... not cinematic at all".
##
## Punctuation is now about one shot in six. The rule the two reports agree on, once both
## are taken seriously, is that a camera should be MOVING most of the time and JUMPING
## rarely - which is neither "sit on each panel" nor "cut constantly".
const SHOTS := {
	# WHAT EACH ENTRY MEANS. `fill` is a band MULTIPLYING the panel's natural framing, so a
	# shot is expressed as "how much tighter or wider than this panel reads at" rather than as
	# an absolute the panel's size can invalidate. `aim` is how far the station sits off the
	# panel's center, in page widths. `az` is how far round it swings, in radians. `rate` is
	# how fast the follower closes on it, multiplying the severity rate. `hard` means the shot
	# begins with a cut - see _cut_to, the only place in this file that assigns the camera.
	#
	# EVERY ONE OF THESE IS A DISTANCE OR A SPEED. That is the whole change: the old table gave
	# each move a DURATION and an EASE CURVE and let thirteen branches hand-roll their own
	# interpolation between two poses, which is why continuity was a convention rather than a
	# property, and why four rounds of guards never converged.
	"settle":  {"w": 4.0, "fill": [0.92, 1.12], "aim": 0.04, "az": 0.00, "rate": 1.00},
	"push":    {"w": 2.5, "fill": [1.35, 2.30], "aim": 0.03, "az": 0.00, "rate": 0.75},
	"pull":    {"w": 1.5, "fill": [0.55, 0.80], "aim": 0.03, "az": 0.00, "rate": 0.75},
	"pan":     {"w": 3.0, "fill": [0.90, 1.20], "aim": 0.30, "az": 0.10, "rate": 0.70},
	"orbit":   {"w": 1.5, "fill": [0.90, 1.20], "aim": 0.05, "az": 0.55, "rate": 0.55},
	# THE ONE THAT SHOWS THE PAGE. Nothing else in this table frames more than its own panel -
	# the widest, `pull`, still leaves the subject filling most of the picture - so the camera
	# had no way to say "here is the sheet you are reading": "it never pulls-back, to reveal the
	# greater page and multiple frames; it's just a constant bouncing around between individual
	# frames, close-up". `page` aims at the middle of the panel's own page and frames wide
	# enough that its neighbors and the gutters between them are the composition.
	"page":    {"w": 2.0, "fill": [0.26, 0.46], "aim": 0.10, "az": 0.15, "rate": 0.55,
		"wide": true},
	# The quick one. Same grammar, four times the rate - a whip is a fast move, not a jump,
	# and expressing it as a rate is what keeps it continuous however short it is.
	"whip":    {"w": 0.5, "fill": [0.85, 1.30], "aim": 0.20, "az": 0.25, "rate": 3.20},
	# ...and the one discontinuity. It must change the SUBJECT to be allowed at all, which is
	# checked in _worth_cutting rather than hoped for here.
	"cut":     {"w": 0.9, "fill": [0.80, 1.60], "aim": 0.08, "az": 0.80, "rate": 0.90,
		"hard": true},
}

## How deep a `push` gets, in frames of panel height.
const PUSH_FILL := Vector2(2.2, 3.8)
## WHAT MAKES A JUMP CUT WORTH MAKING: it must land on a DIFFERENT PANEL, and it must move
## the aim at least this far in page widths.
##
## The first draft of this rule let the jump qualify on size instead - a big enough change of
## framing or angle counted. Measured against the export, that rule would have permitted seven
## of the eleven discontinuities in it, including a 1.42x tighten at 0:22 and a ~3x widen at
## 2:01, both of them on the panel the camera was already holding. A cut is a change of
## SUBJECT; scale is how it is photographed, not what it is of. "The camera 'jumps' to correct
## its position... landing on the exact same frame. This is the kind of jarring behavior we
## MUST find a way to eliminate." So: different panel, or it is not a cut - and a cut within
## one panel becomes a drift, which gets there continuously.
##
## The aim distance is a second bar rather than an alternative, because two panels can share an
## edge and a "cut" across a gutter is the same non-event by another name.
const CUT_MIN_AIM := 0.28

## How far a page turn may move the camera's side of the sheet, in radians at camera 1. A page
## turn is the single largest change of angle the grammar allows, and re-rolling over the whole
## circle - which is what this replaced - is a walk round the table rather than a lean.
const TURN_AZ := 1.2
## THE CAMERA KNOB, applied. See [member Director.camera] for what it is - the slider is
## labeled "Camera"; `severity` is only this file's word for it.
##
## Every constant that describes how MUCH the camera does is read through _sev(), so the slider
## moves the whole behavior along one axis. What it scales, and why each belongs to it:
##   how far a shot travels and how wide its framing band is - see REACH_CALM
##   how fast the follower closes                            - see RATE_CALM
##   the angular arc a shot may reach, and the walk step      - how far it can swing at all
##   how far a page turn moves the set-up                     - the one big change in grammar
##   the weight of the one discontinuous shot                 - at 0 it never jump-cuts
##   the sheet's own drift rate                               - scenery reads as camera motion
##
## REACH IS THE ONE THAT MATTERS FOR HOLDING, and the previous design had only speed. Scaling
## speed alone means a gentle camera makes the same journeys more slowly, so it spends MORE of
## the hold traveling: measured at 71% held at camera 0 against 86% at camera 1, an inversion
## that is exactly why turning the slider down never helped.

## HOW MUCH GENTLER A FIELD SCENE IS RAKED, 0..1 toward square-on.
##
## ghost already types every scene as `subject` (a discrete object) or `field` (fills the
## frame), and [Shots] already gives field scenes the gentle moves only. The same rule
## belongs here for the same reason, and the reason is visible: a hard rake reads as
## FORESHORTENING when there is a recognizable object in the panel to be foreshortened, and
## as WARPING when there is not. A fractal field at 30 degrees off the paper does not look
## like a picture seen at an angle, it looks like a broken picture - which is exactly how it
## was reported.
const FIELD_FLATTEN := 0.62

## The framing a shot falls back to when there is no panel under the aim, in frames of panel
## height. Well under 1: at 0.62 the panel the camera is nearest is a bit over half the
## frame, so the gutter it is actually looking at is surrounded by the four panels that
## gutter separates. That is a picture of a comic page. Note the covering solve can still
## refuse to go this wide - see place_eye - and on a spread it usually does not have to.
const OFF_FILL := 0.62


## A NEW BOOK: everything this part holds put back as a fresh camera has it - the sheet's
## attitude, the set-up and its walks, the pose and its target, the shot and the count that seeds
## every shot, the followers and the eye. The medium outlives its sessions, so whatever is left
## out here the next session inherits from the last, and the same seed plays another camera
## (tests/media/comic_motion_check.gd, "a second attach"). A member added to this part's state is
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


## The spread's attitude for this spread: a real rake on all three axes, plus a slow
## continuous drift so the sheet is never still.
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
	# THE SET-UP FOR THIS SPREAD - decided ONCE, and then everything below only varies within
	# it. See the note above AZ_ARC: re-rolling these per shot is what made the camera
	# ping-pong, and no amount of smooth interpolation between two unrelated positions
	# rescues it, because the problem is that they are unrelated.
	var sev := _sev()
	if medium._spread_i <= 0:
		_az_base = r.randf_range(0.0, TAU)      # the first spread has nowhere to come from
	else:
		# A BOUNDED CHANGE OF SIDE, not a fresh draw. Re-rolling over the whole circle is the
		# largest single move the camera makes; on a spread it happens only every six to
		# twelve cuts, so it is worth having - but at a gentle setting it should be a lean
		# rather than a walk round the table.
		_az_base += r.randf_range(-TURN_AZ, TURN_AZ) * sev
	_el_base = deg_to_rad(r.randf_range(EL_MIN_DEG, EL_MAX_DEG))
	_roll_base = r.randf_range(-CAM_ROLL, CAM_ROLL) * sev
	_lens_fov = r.randf_range(FOV.x, FOV.y)
	# The walk starts each spread where the last one left it, so a page turn is the only
	# discontinuity in the angles and everything between turns is continuous.
	# The sheet's own drift is part of how busy the picture is, so it scales too.
	_att_rate *= sev


## THE LEAF HAS TURNED (or the book opened): this spread's set-up, then a shot on [param panel].
## A new sheet is a new shot, not a place to ease toward, so the placed rake and distance jump to
## it rather than following.
func new_spread(panel: int) -> void:
	choose_look()
	_snap = true
	begin_shot(panel, true)


## One step of a bounded random walk: move [param at] by at most ANG_STEP of [param arc] and
## keep it inside +/-arc. A zero arc pins it at zero, which is what severity 0 asks for.
##
## Clamped rather than reflected, deliberately. A walk that bounces off its bound reverses
## direction on contact, which reads as the camera being repelled by an invisible wall; one
## that saturates simply dwells at the edge of the arc until the next step happens to come
## back, which reads as a camera that has settled on one side.
func _walk(at: float, arc: float, r: RandomNumberGenerator) -> float:
	if arc <= 0.0:
		return 0.0
	return clampf(at + r.randf_range(-arc, arc) * ANG_STEP, -arc, arc)


## HOW WIDE THE SHOT OPENS WHERE THERE IS NO PANEL UNDER THE AIM. See OFF_FILL, and the note
## at the call site in place_eye for why this is a severity question.
func _open_to() -> float:
	return lerpf(float(_cam.fill), OFF_FILL, lerpf(0.45, 1.0, clampf(_sev(), 0.0, 1.0)))


# --- the camera: one target, one follower -----------------------------------------------------

## WHAT SHARE OF THE HOLD A SHOT SPENDS ARRIVING, at camera 0 and at camera 2.
##
## THE RATE IS DERIVED FROM THIS, NOT SET DIRECTLY, and that is the second time this file has
## had to learn the same lesson. A fixed rate makes a calm camera CLOSE SLOWLY - but the
## distance it has to close is the gap between two panels, which the reading plan sets and the
## slider does not touch. So a slow rate means a long journey between panels and a short hold
## at the end of it: measured with cuts running, 53% held at camera 0 against 82% at camera 2,
## the calm end holding LEAST. That is the same inversion as the old `_budget`, arriving by a
## different road, and the cure is the same: express the intent (how much of the scene is
## spent looking rather than traveling) and let the rate fall out of it.
##
## THE RATE ACCOUNTS FOR HOW FAR THE SHOT HAS TO GO. An exponential follower closes a gap of G
## down to the arrival threshold in ln(G)/rate seconds, so the rate that arrives in a chosen
## time is ln(G) / t - NOT the 3/t that "three time constants" suggests, which silently assumes
## every shot starts the same distance out. A shot crossing the spread starts an order of
## magnitude further out than one nudging within a panel, and with a fixed 3/t the far ones
## simply took longer: measured 12.2 s mean arrival against a 9 s ceiling.
const ARRIVE_SHARE_CALM := 0.22
const ARRIVE_SHARE_BUSY := 0.55
## ...BOUNDED AT BOTH ENDS, in seconds of approach. Both bounds are load-bearing and the
## missing one was a real defect: with the hold slider at 4.0 the room in front of a shot is
## enormous, so `share` of it is enormous, so the derived rate went to nearly zero and the
## follower crawled - measured, NO SHOT EVER ARRIVED in a 60 s run, and the hold phase
## therefore never began at all. That is the old `_budget` inversion for the third time, hiding
## inside a rate instead of a duration: any quantity derived from the Director's hold has to be
## clamped, because the hold is a user setting with no upper bound.
##
## The floor keeps an arrival from being a snap on a very short hold; the shot simply runs past
## the cut, which costs nothing because a cut is a new target rather than an interruption.
## Over what fraction of the journey the approach eases out. Above it the camera travels at a
## constant rate; below it, it lands. Small, because the taper is a landing, not the shot.
const ARRIVE_TAPER := 0.28
const ARRIVE_FLOOR := 1.8
## 10, not 17. A pan may be unhurried and still has to LAND: at 17 a shot spent fourteen
## seconds of a twenty-second scene traveling and held for 3% of it. The variety comes from
## PAN_SPEED sampling inside this bound, not from the bound itself being generous.
const ARRIVE_CEIL := 10.0
## HOW FAST THE CAMERA CROSSES THE PAPER, in page widths per second, sampled per shot.
##
## A PAN HAS A SPEED, NOT A DURATION, and that distinction is the whole of "the transitions all
## seem rather fast... I would expect more gentle, drifting camera pans". Sizing every arrival
## as a share of the hold gives a long journey and a short nudge the SAME eight seconds - so
## the long ones, which are the ones that should read as unhurried drifts across the spread,
## are the fastest thing on screen. Dividing the distance by a speed inverts that correctly:
## crossing the spine takes longer than easing across a gutter, because it is further.
##
## The range is wide on purpose. Some transitions should be quick; the complaint was that they
## ALL were, and a single tuned number cannot express "mostly gentle, occasionally not".
const PAN_SPEED := Vector2(0.028, 0.115)
## The angles follow slower than the aim. A pan that changes the rake at the same speed as the
## framing reads as the whole page swinging; letting the rake lag makes it read as a camera
## craning while it travels, which is the same motion done by something with mass.
const RATE_ANGLE := 0.62
## HOW BIG A SHOT'S JOURNEY IS, at camera 0 and camera 2, multiplying the `aim` and `az`
## distances in SHOTS and the width of its `fill` band.
##
## THIS IS WHAT MAKES THE SLIDER MONOTONE IN HOLDING, and the old design had it backwards.
## Scaling only the SPEED means a gentle camera makes the same journeys more slowly, so it
## spends MORE of the hold traveling and less of it arrived - measured on the previous build
## at 71% held at camera 0 against 86% at camera 1, which is why turning the slider down never
## helped. A gentle camera makes SMALL journeys: it arrives early and looks for a long time.
const REACH_CALM := 0.35
const REACH_BUSY := 1.35
## THE SHOT HAS ARRIVED when its remaining gap is under this, measured in the mixed units of
## _pose_gap: page widths of aim, log-ratio of framing, radians of swing. One is the threshold
## because _pose_gap divides each channel by its own tolerance first.
const ARRIVED := 1.0
## The tolerances _pose_gap normalizes by: aim in page widths, framing as a log ratio (0.06 is
## about 6%), swing in radians.
const GAP_AIM := 0.035
const GAP_FILL := 0.06
const GAP_ANG := 0.035
## A shot that cannot converge - because the Director is holding it against a target it will
## not reach, or because a constraint is fighting it - is treated as arrived after this long,
## so the hold can begin. Without it a pathological shot never holds and never says why.
## The safety net for a shot that cannot converge - a target it will not reach, or a constraint
## fighting it. It must sit ABOVE any legitimate arrival or it stops being a net and starts
## being the schedule; see the note on the taper floor in _follow.
const ARRIVE_CAP := 22.0
## HOW LONG THE CAMERA MUST HAVE HELD before it may reverse the framing.
##
## Clearing the direction the instant a shot ARRIVES is not enough: a shot can arrive and be
## cut a moment later, and the next shot is then free to reverse with nothing in between -
## measured at 3 to 6 reversals per run with no hold separating them. The report asked for a
## hold, not for a touch: "no reversing direction allowed, without first HOLDING at that
## position first."
const ZOOM_FREE := 1.6
## THE HELD SHOT STILL BREATHES. How far the target creeps during a hold, in page widths, and
## how long it takes to creep the whole way. One heading, chosen when the shot arrives.
##
## A held shot that is perfectly static reads as a photograph of a page rather than a camera
## looking at one, and the original report on this medium was a camera that froze. A heading
## rather than a walk: an unbiased random walk against the panel edge parks AT the edge and
## jitters there, which is a defect this file has shipped once already.
const HOLD_CREEP := 0.05
const HOLD_CREEP_TIME := 22.0
## How fast `flat` and the eye distance follow their targets, per second. These are the two
## quantities in place_eye that STEP - see the class doc, "the other half of the same bug".
const RATE_FLAT := 1.3
const RATE_DIST := 2.4


## The severity in force, 0..2. Asked of the Director rather than held here so the slider takes
## effect on the next frame without anything having to be pushed at the medium.
func _sev() -> float:
	return clampf(medium.feed.camera, ShowFeed.CAMERA_MIN, ShowFeed.CAMERA_MAX)


## How far a shot travels, and how fast, at the current setting. See REACH_CALM and RATE_CALM.
func _reach() -> float:
	return lerpf(REACH_CALM, REACH_BUSY, clampf(_sev(), 0.0, 2.0) * 0.5)


## The rate that arrives inside this camera's share of the hold in front of it. See
## ARRIVE_SHARE_CALM.
## How long this shot should take to arrive: the distance it has to cross, at a speed sampled
## for this shot. See PAN_SPEED. The Director's hold is a CEILING on that, not the source of
## it - a shot may not spend more than its share of the scene traveling, but within that it
## goes at its own pace.
func _arrive_time(r: RandomNumberGenerator, travel: float, kind: String) -> float:
	# BIASED TOWARD THE SLOW END, and the bias has to be applied to the SPEED to come out right
	# in the duration. Time is distance over speed, so sampling speed uniformly produces mostly
	# SHORT transitions - the fast half of the speed range covers a narrow band of durations
	# while the slow half spreads over a wide one. Squaring the draw pushes the sample toward
	# the gentle end, which is the shape asked for: "it's okay if some of them are fast... but I
	# wouldn't expect them all to be that way."
	var u := r.randf()
	var speed := lerpf(PAN_SPEED.x, PAN_SPEED.y, u * u)
	# THE TABLE'S `rate` MULTIPLIES THE SPEED. It used to DIVIDE the follower rate, which made
	# every entry mean its opposite: `whip` at 3.2 was the slowest thing in the bag and `orbit`
	# at 0.55 the quickest.
	speed *= float(SHOTS[kind].get("rate", 1.0)) * lerpf(0.7, 1.7, clampf(_sev(), 0.0, 2.0) * 0.5)
	var want := travel / maxf(speed, 0.001)
	var share := lerpf(ARRIVE_SHARE_CALM, ARRIVE_SHARE_BUSY, clampf(_sev(), 0.0, 2.0) * 0.5)
	var room := medium.feed.hold_remaining() * share
	return clampf(minf(want, maxf(room, ARRIVE_FLOOR)), ARRIVE_FLOOR, ARRIVE_CEIL)


## BEGIN A SHOT ON [param panel]. This is the only entry point for "look at something else":
## the Director's cut calls it, and so does a page turn.
func begin_shot(panel: int, turned := false) -> void:
	if medium._spread == null or medium._spread.panels.is_empty():
		return
	panel = clampi(panel, 0, medium._spread.panels.size() - 1)
	var r := RandomNumberGenerator.new()
	r.seed = hash([medium.feed.session_seed(), "comic-shot", medium._spread_i, panel, _shot_n])
	_shot_n += 1
	var kind := _pick_shot(r)
	# A ZOOM MAY BE CONTINUED BUT NEVER REVERSED WITHOUT A HOLD BETWEEN. `_zoom_dir` is cleared
	# when a shot arrives, so this asks exactly the question the report asked: has the camera
	# held since it last changed the framing? "No reversing direction allowed, without first
	# holding at that position first."
	if (kind == "pull" and _zoom_dir > 0) or (kind == "push" and _zoom_dir < 0):
		kind = "pan"
	var tgt := _target_for(r, panel, kind)
	var hard := bool(SHOTS[kind].get("hard", false)) and _worth_cutting(tgt)
	# THE HEADING THE HOLD WILL CREEP ALONG, drawn once here rather than re-drawn per breath.
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
	# THE RATE IS SIZED TO THE JOURNEY, and can only be measured once the target is set: how far
	# this shot has to go, at the speed it drew, converted to the follower rate that gets there.
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


## THE ONLY PLACE THIS FILE ASSIGNS THE CAMERA. Everything else integrates toward a target, so
## the number of discontinuities in a session is exactly the number of calls to this - which is
## a property, not a hope, and is what tests/media/comic_motion_check.gd counts.
func _cut_to(pose: Dictionary) -> void:
	_cam = pose.duplicate()
	_snap = true                  # the placed rake and distance jump with it, or it tears


## Is this jump a different SHOT? See CUT_MIN_AIM.
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


## WHERE A SHOT OF [param kind] ON [param panel] LOOKS FROM.
##
## Built as an OFFSET from the panel's own natural framing, so every entry in SHOTS is a
## distance rather than an absolute, and severity scales the distances (see REACH_CALM).
func _target_for(r: RandomNumberGenerator, panel: int, kind: String) -> Dictionary:
	var spec: Dictionary = SHOTS[kind]
	var reach := _reach()
	var sp := medium._spread
	var base := sp.panel_center(panel)
	# THE FILM PANEL IS FRAMED DEAD CENTER AND WHOLE - see CONTAIN_FILL. Everywhere else the
	# aim leans toward the middle of its own page, which keeps the outer trim out of shot...
	if panel != medium._film_at:
		base = base.lerp(sp.page_center(panel), AIM_PULL)
	# ...and a WIDE shot leans most of the way there, because its subject is the page rather
	# than the panel. Not all the way: the panel the reading is on should still be the part of
	# the sheet the composition is built around.
	if bool(spec.get("wide", false)):
		base = sp.panel_center(panel).lerp(sp.page_center(panel), 0.75)
	var span: Array = spec["fill"]
	# THE BAND BARELY NARROWS AS THE CAMERA CALMS, and it used to collapse. This was
	# `lerp(1.0, sampled, reach)` with reach floored at 0.35, which dragged EVERY framing 65% of
	# the way back to 1.04 at camera 0 - one close-up value for the whole vocabulary, which is
	# the whole of "it never pulls back... it's just a constant bouncing around between
	# individual frames, close-up". What a gentle camera should do less of is TRAVELING; how
	# varied its framing is belongs to composition, not to restlessness.
	var fill := lerpf(1.0, r.randf_range(float(span[0]), float(span[1])),
		clampf(0.6 + reach * 0.4, 0.0, 1.0))
	var off := Vector2(r.randf_range(-1.0, 1.0), r.randf_range(-1.0, 1.0))
	off = off.normalized() if off.length() > 0.001 else Vector2.RIGHT
	var aim := base + off * float(spec["aim"]) * reach
	# THE ANGLES WALK, they are not re-drawn. A shot may spend a fraction of the spread's arc,
	# so a big change of angle is spread over several shots rather than happening at one.
	_az_walk = _walk(_az_walk, AZ_ARC * _sev(), r)
	_el_walk = _walk(_el_walk, deg_to_rad(EL_VARY_DEG) * _sev(), r)
	_roll_walk = _walk(_roll_walk, ROLL_VARY * _sev(), r)
	# THE SWING SCALES BY THE SLIDER, NOT BY REACH. `reach` floors at REACH_CALM so that a calm
	# camera still travels between panels - a camera that cannot move is not the gentle end of
	# the range, it is a photograph - but the contract at camera 0 is that the camera never
	# TURNS, exactly, and a floor of 0.35 on the angular term left 3.3 degrees a shot. Distance
	# and angle are different promises and they scale by different things.
	var az := _az_base + _az_walk \
		+ float(spec["az"]) * _sev() * (1.0 if r.randf() < 0.5 else -1.0)
	# A WIDE SHOT IS EXEMPT FROM settle_aim. That guard walks an aim toward its panel until
	# enough panel is under it, which is right for a shot OF a panel and destroys a shot of the
	# page - the composition it is reaching for has gutters and neighbors in it by design.
	return {
		"aim": sp.clamp_aim(aim) if bool(spec.get("wide", false)) \
			else sp.settle_aim(sp.clamp_aim(aim)),
		"az": az,
		"el": clampf(_el_base + _el_walk, deg_to_rad(EL_MIN_DEG), deg_to_rad(EL_MAX_DEG)),
		"roll": _roll_base + _roll_walk,
		"fill": clampf(_panel_fill(panel) * fill, FILL.x * 0.6, PUSH_FILL.y),
		"fov": _lens_fov,
	}


## The framing a panel READS at - the middle of FILL, so `fill` in SHOTS is a multiplier of
## "this panel, filling the frame the way a panel should" rather than of an arbitrary number.
func _panel_fill(_panel: int) -> float:
	return (FILL.x + FILL.y) * 0.5


## HOW FAR THIS SHOT STILL HAS TO GO, normalized so that 1.0 is "arrived" on every channel.
func _pose_gap() -> float:
	var g: float = (_cam.aim as Vector2).distance_to(_tgt.aim) / GAP_AIM
	var fa := maxf(float(_cam.fill), 0.01)
	var fb := maxf(float(_tgt.fill), 0.01)
	g = maxf(g, absf(log(fb / fa)) / GAP_FILL)
	g = maxf(g, absf(angle_difference(float(_cam.az), float(_tgt.az))) / GAP_ANG)
	return g


## ONE FRAME OF CAMERA. Advance the shot, then follow.
func advance(delta: float) -> void:
	# The spread turns under the camera, slowly and forever - independent of the shot, because
	# the sheet is scenery and the camera is the performance. The rig is page-local, so this
	# rotates the camera and the sheet by the same matrix and the projection is invariant to
	# it: it shows as the page living, not as the shot moving.
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
	# ARRIVAL IS A MEASUREMENT, NOT A CLOCK. The shot is over when the picture has got there.
	if not bool(_shot.get("arrived", false)) \
			and (_pose_gap() < ARRIVED or _shot_t > ARRIVE_CAP):
		_shot["arrived"] = true
		_hold_t = 0.0
		_hold_from = _tgt.aim
	if bool(_shot.get("arrived", false)):
		_hold_t += delta
		# THE HOLD IS WHAT EARNS A REVERSAL - and it has to be a hold. See ZOOM_FREE.
		if _hold_t >= ZOOM_FREE:
			_zoom_dir = 0
		# ...AND A HELD SHOT STILL BREATHES, along the heading this shot was given. Measured
		# from where it ARRIVED, so the excursion is bounded however long the hold runs.
		# IT DOES NOT SATURATE. Clamping the creep at 1 made the held shot stop dead after
		# HOLD_CREEP_TIME, which is a freeze on any hold longer than that - the same defect an
		# earlier version shipped and a frame-by-frame reading of the export measured at 33.8
		# seconds of literally identical picture. It keeps creeping; what bounds it is
		# settle_aim, which walks the aim back when it nears the panel's edge, so the drift is
		# limited by the geometry rather than by a clock.
		var creep := _hold_t / HOLD_CREEP_TIME
		# NOT SCALED BY REACH. A held shot is held at every setting - what the slider changes is
		# how far the camera TRAVELS between subjects, not how still it can be once it has
		# arrived. Scaling the creep by reach made a busy camera drift through its own holds
		# fast enough that they stopped reading as holds at all (12% of frames still, against
		# 44% at the calm end).
		_tgt["aim"] = medium._spread.settle_aim(medium._spread.clamp_aim(_hold_from
			+ (_shot["heading"] as Vector2) * HOLD_CREEP * creep))
	_follow(delta)
	place_eye(delta)


## THE FOLLOWER, AND IT IS SPEED-LIMITED RATHER THAN EXPONENTIAL.
##
## A pure exponential covers 63% of its distance in ONE time constant and then crawls through
## the remainder, so a shot given ten seconds does nearly all of its visible movement in the
## first second or two and spends the rest converging invisibly. That is a fast transition
## followed by nothing, however long the arithmetic says the shot lasts: "when the camera
## shifts its focus from one frame to another, it does it in about 1 second. It's fast, every
## single time." The measurement agreed with the arithmetic and not with the picture, because
## it timestamped the end of the CRAWL rather than the end of the MOVEMENT.
##
## So the journey advances at a constant fraction per second - the camera covers the same
## ground in the ninth second as in the first - and eases only over the last of it, which is
## what makes a pan read as a pan rather than as a snap with a tail. It remains an integration:
## `_cam` is never assigned, a cut mid-journey is simply a new target, and nothing here can
## teleport the picture.
func _follow(delta: float) -> void:
	var secs := maxf(float(_shot.get("secs", 6.0)), 0.1)
	# How much of the ORIGINAL journey to cover this frame...
	var step := delta / secs
	# ...eased out over the last of it, so the shot lands rather than stopping dead. Above the
	# taper the speed is flat, which is the constant-rate pan.
	var left := _pose_gap() / maxf(float(_shot.get("gap0", 1.0)), 0.001)
	if left < ARRIVE_TAPER:
		# FLOORED WELL ABOVE ZERO. A taper that trails off to nothing means the shot never
		# actually converges: the last of the journey stretches past the whole budget and
		# ARRIVE_CAP - the safety net - becomes the thing that ends every shot, at exactly its
		# value. Measured, every arrival reported 14.0s, which is that constant and not a
		# camera. This lands the shot; it does not dissolve it.
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


## Put the eye on its spread-local spherical offset from where the camera is aiming.
##
## The offset direction is built in SPREAD space and then rotated by the sheet's attitude,
## so it is a fixed station relative to the paper: traveling from panel to panel slides the
## camera ACROSS the spread at a constant angle, which is the move a copy-stand shot makes
## and the one the eye reads as flying over a comic. Building it in world space instead
## would swing the angle around every time the sheet moved.
func place_eye(delta := 0.0) -> void:
	if medium._spread == null:
		return
	var sp := medium._spread
	var aim: Vector2 = sp.clamp_aim(_cam.aim)
	var c := sp.world(aim, att_basis)
	# A FIELD scene is raked gently, a subject hard - see FIELD_FLATTEN.
	var fp := sp.framing_panel(aim)
	# THE FILM PANEL IS SHOWN WHOLE - see CONTAIN_FILL. Only while it is the panel the shot is
	# actually built around; a film at the edge of a wide shot is just another picture on the
	# page and does not get to decide the framing.
	var contain: bool = fp >= 0 and fp == medium._film_at
	var flat := maxf(_flatten(), FILM_FLATTEN if contain else 0.0)
	# FOLLOWED, NOT ADOPTED. `_flatten()` reads the panel being READ, so it steps the instant
	# the Director cuts between a field scene and a subject one - up to 21.7 degrees of
	# elevation in a single frame - and `contain` steps as the aim crosses the film panel's
	# edge. Neither is a shot, and nothing in the shot vocabulary can see either.
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
	# SCALE IS SET BY WHICHEVER PANEL THE AIM IS INSIDE, not by the nearest center and not by
	# the one being read: a traveling move spends most of its time between panels, and
	# framing those seconds against a panel that is off screen puts the scale somewhere
	# arbitrary. See ComicSpread.framing_panel.
	var pw := sp.panel_world(fp, att_basis)
	_cam["aim"] = aim
	# ZOOM IS COUPLED TO CONTENT - see ComicSpread.CONTENT_CORE. Off a panel the requested fill is
	# ignored and the shot opens to OFF_FILL, so the camera physically cannot be tight on a
	# gutter or a corner however a move was planned or wherever a chain left it.
	# ...AND HOW FAR IT OPENS IS A SEVERITY QUESTION TOO. This is a 1.7x swing in the rendered
	# framing on EVERY lateral move - out at the gutter, back in on the far panel - and it is
	# invisible to the move vocabulary, so nothing above could smooth or forbid it. It buys
	# almost nothing at a gentle setting, where the camera is at 1.04 frames of panel and in no
	# danger of being tight on anything; it earns its keep at a severe one, where a push is at
	# 3.8 and a gutter at that framing is the original complaint.
	var eff := lerpf(_open_to(), float(_cam.fill), sp.content_at(aim))
	if contain:
		eff = minf(eff, CONTAIN_FILL)
	# TWO CONSTRAINTS, and the nearer wins.
	#
	# The first frames the PANEL: near enough that it spans `eff` frames top to bottom. The
	# second frames the SPREAD: near enough that the sheet covers the frame on BOTH axES. A
	# single portrait page could never satisfy the second without pushing in until the page
	# stopped reading as a page, which is why the first cut of this only ever checked the
	# width; a spread is 1.33 wide against a 1.78 frame, so covering the width covers the
	# height with room to spare and the check can finally be honest.
	# THE WHOLE VIDEO WINS OVER THE COVERING SOLVE, and that is a deliberate ordering rather
	# than an oversight. The two constraints genuinely conflict on a wide panel at a rake -
	# measured, containing it wanted 3.03 units and covering allowed only 2.13 - so one of them
	# has to give. Letting the cover win crops a speaking face out of frame to keep a strip of
	# desk off it, and between those two the answer is not close: "you really don't want to
	# focus the camera on her door to the side." FILM_FLATTEN is what keeps the price small.
	var cov := _cover(sp.world_corners(att_basis), c, dir)
	if contain:
		cov *= CONTAIN_DESK
	var d := minf(_fit(pw, c, eff, dir, contain), cov)
	# ...and never nearer than this, whatever the two constraints ask for. Pushing in until
	# the paper covers the frame is right; pushing in until the camera is INSIDE one panel's
	# artwork is a shot of a texture, with no page, no gutter and no comic in it.
	# The near floor never applies to a contained panel: its whole point is that the camera
	# stops where the picture fits, and a floor that pushes past that would crop it again.
	var near := 0.0
	if not contain:
		near = _fit(pw, c, CROP_MAX, dir)
		d = maxf(d, near)
	# ...AND SO IS THE DISTANCE. `pw` changes panel as the aim crosses a gutter and the solve
	# changes branch at the film panel's edge; this file's own measurements record 3.03 against
	# 2.13 and 7.76 against 4.62 world units for the same shot either side of that branch.
	if _snap or _dist_s < 0.0 or delta <= 0.0:
		_dist_s = d
		_snap = false
	else:
		_dist_s += (d - _dist_s) * (1.0 - exp(-RATE_DIST * delta))
	# THE FOLLOWER MAY LAG, BUT IT MAY NOT BREAK THE TWO CONSTRAINTS. `cov` is the farthest the
	# eye may sit and still have paper across the whole frame, `near` the closest it may sit
	# without being inside one panel's artwork. Easing is for the INTERIOR of the feasible
	# range; its edges are not negotiable, and a follower left to drift outside them shows desk.
	_dist_s = minf(_dist_s, cov)
	if near > 0.0:
		_dist_s = maxf(_dist_s, near)
	_eye = c + dir * _dist_s
	_look = c


## How far toward square-on the rake is pulled for the panel currently being read. Zero for
## a subject; FIELD_FLATTEN for a field. See that constant.
func _flatten() -> float:
	var sc := medium._focal()
	return FIELD_FLATTEN if (sc != null and sc.framing == "field") else 0.0


## HOW MUCH OF THE FRAME THE SHEET COVERS. 1.0 when there is paper under all four corners
## of the picture; below that, the number is how far the WORST corner falls outside the
## sheet as a fraction of half the frame height - so 0.92 is a sliver of desk in one corner
## and 0.5 is a wedge across the shot. Read by tests/media/comic_look_probe.gd, which is the only
## way "is there dead space in the frame" gets checked by something other than an eye.
##
## FOUR CORNERS, not two edges of a bounding box. The old measure took the projected sheet's
## bounding box and asked whether it reached past the left and right frame edges. That is
## wrong twice over. It never looked UP or DOWN, so it reported a clean 1.00 on a frame with
## a band of black desk across the top - the exact frame the report was about. And a
## bounding box is not the sheet: a raked, rolled quad has a box that reaches every edge
## while the quad itself cuts a corner off. A number that cannot see the defect it exists to
## catch is worse than no number.
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


## The sheet's outline in screen space, CLIPPED TO THE NEAR PLANE.
##
## A perspective projection cannot express a point behind the eye - it inverts through
## infinity - so every draw here bails out when one appears, and the two coverage tests used
## to bail out by declaring themselves covered. On a single page that was nearly honest: a
## page is 2 world units across, and a camera near enough to put a corner behind itself
## really was over the paper. A spread is 4 across. At the reading distance its far corners
## go behind the eye while there is still a wedge of desk in the opposite corner of the
## frame, and the escape hatch then reports a clean 1.00 on exactly the picture the coverage
## number exists to catch.
##
## So the outline is clipped instead of abandoned - Sutherland-Hodgman against the one
## plane, which turns the quad into at most a pentagon and costs one lerp per crossing. The
## result is the sheet's true silhouette, and the corner test below is then exact at any
## framing.
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
			# where the edge crosses the plane, in world space, so the projection of the
			# crossing point is the projection of a point that is genuinely in front
			var t := da / (da - db)
			var pc := view.project(a.lerp(b, t))
			out.append(Vector2(pc.x, pc.y))
	return out


## The signed distance from the WORST frame corner to the edges of the projected quad
## [param q], in unit-fraction units. Positive means every corner of the frame is inside the
## quad, i.e. the sheet covers the picture; negative is how far the worst one sticks out.
##
## The quad is convex (it is a planar rectangle under a perspective projection), so a point
## is inside exactly when it is on the same side of all four edges - and the least of those
## four signed distances is how much room there is to spare. Taking the least again over the
## four frame corners gives one number for "is there desk in shot, and how much".
##
## Wound from the quad's own signed area rather than assumed, because the page's roll and
## the camera's can put the sheet either way round on screen.
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


## HOW MUCH OF THE FRAME THE PANEL BEING READ TAKES UP, on its worst axis. 1.0 means it
## exactly spans the picture; above 1 the screen is cropping into it, which is the intended
## shot for an abstract field and the wrong one for a piece of footage - see CONTAIN_FILL.
## Read by tests/media/comic_look_probe.gd, so "is the whole video on screen" is a number.
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


## WHY THE CURRENT SHOT IS FRAMED WHERE IT IS - the numbers that decide it, for the probe.
## Not a pretty string for its own sake: "there is desk in this frame" has now had two fixes
## aimed at it that measured as no change at all, because both were aimed at a cause guessed
## from the outside instead of read off the shot that was failing.
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


## The eye made into [member lens], once a frame after [method advance] - what the page is drawn
## through and [method panel_rect] measures with.
func prepare_lens() -> void:
	lens.eye = _eye
	lens.look = _look
	lens.fov = _fov
	# CAMERA UP, and it must not be world up: at a hard rake the view axis can come within
	# a few degrees of it and the basis collapses (Lens3D falls back and the picture rolls
	# through 90 degrees in one frame). The sheet's own up is always perpendicular to the
	# paper's normal, so it is a stable reference - and taking it from the sheet is also what
	# makes its roll show as a tilted horizon rather than as nothing at all.
	var fwd := (_look - _eye)
	fwd = fwd.normalized() if fwd.length() > 1e-6 else Vector3.FORWARD
	var up := att_basis * Vector3.UP
	if absf(up.dot(fwd)) > 0.9:
		up = att_basis * Vector3.RIGHT     # grazing along the sheet's up axis
	lens.up = Basis(fwd, _roll) * up
	lens.prepare()


## THE FRAMING DISTANCE: how far along [param dir] the eye must sit for [param pts] to span
## [param fill] frames VERTICALLY.
##
## VERTICAL ONLY, and that is the whole difference between a comic and a slideshow of
## pages. Constraining both axes means fitting the panel ENTIRELY inside the frame, and a
## panel narrower than 16:9 - which most comic panels are - then leaves the rest of the
## picture to the page, the trim edge, and the desk beyond it. Constrained on height, the
## panel always spans the frame, and what fills the sides is the gutter and the panels next
## to it. That is what reading a comic close up actually looks like.
##
## Solved by bisection rather than in closed form, because unlike a straight-down-z camera
## the view basis turns as the distance changes, so there is no single inequality to
## rearrange. A handful of halvings on four points is nothing, and it is exact at any rake.
##
## THE HALF-EXTENT IS 0.5, NOT 1. Lens3D projects into ghost's unit-fraction space, which
## the caller multiplies by unit() = the SHORTER SCREEN AXIS - so the visible vertical range
## is +/- (H/2)/min(W,H) = +/- 0.5. Reading it as 1 puts the camera at half the distance it
## needs, which is what the first cut of this did.
## [param contain] fits the points on BOTH axes instead of on height alone, so nothing
## overflows the frame. See CONTAIN_FILL - it is what puts a whole video on screen.
func _fit(pts: Array, c: Vector3, fill: float, dir: Vector3, contain := false) -> float:
	var u := minf(medium._stage_size.x, medium._stage_size.y)
	# fill is how many FRAMES tall the panel should be, so a bigger fill is a nearer
	# camera: the allowed half-extent grows and the bisection settles closer in.
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


## How many halvings the two solvers take. Sixteen resolves the 0.15-24 bracket to about
## 0.0004 world units, which is a third of a thousandth of a page width - far past anything
## a camera distance can show, and six fewer projections per point than the 22 it was.
const SOLVE_STEPS := 16


## THE COVERING DISTANCE: the FARTHEST the eye may sit along [param dir] while [param pts]
## still span the whole frame, on BOTH axes. Beyond it you can see past them.
##
## The mirror of [method _fit], and it has to bisect the other way: a projection shrinks
## with distance, so "fits inside" is true beyond some distance and "covers" is true within
## one. Same halvings, same exactness at any rake.
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
		# CLIPPED, not abandoned, when a corner goes behind the eye - see _sheet_poly. An
		# empty polygon means every corner is behind, which is the most covered case there
		# is; reading THAT as "does not cover" inverts the whole search and drives the
		# camera inside a panel.
		var q := _sheet_poly(pts, probe)
		# Covers when every CORNER OF THE FRAME has paper under it - the same test
		# page_coverage() reports, so the solve and the measurement can never disagree about
		# what "covered" means. See _quad_clearance for why a bounding box is not enough.
		var clear := 1e9 if q.size() < 3 else _quad_clearance(q, hx, hy)
		# Remember the BEST distance seen, for the case where none of them cover - see below.
		if clear > best_clear:
			best_clear = clear
			best_d = mid
		if clear >= 0.0:
			lo = mid
		else:
			hi = mid
	# DID ANYTHING COVER AT ALL? The bisection assumes covering is true near and false far and
	# returns the boundary. When the sheet cannot cover the frame at ANY distance - a hard rake
	# and a rolled page can leave a corner of the picture off the paper however close the camera
	# gets - `lo` never moved, and returning it hands the caller 0.15 world units as a NEAR
	# bound, pinning the eye inside a panel's artwork.
	#
	# RETURNING A HUGE NUMBER INSTEAD WAS WORSE, and it is what "the camera's anchor jerks and
	# then flies to some other position... as if the camera were pulling on some rubber band,
	# which broke" actually was. This value is a CONSTRAINT the caller takes the minimum with,
	# so switching it between about two world units and 1e9 in one frame - which is what
	# happens the instant a drifting page crosses from just-coverable to not - releases that
	# constraint completely, and the camera leaves at whatever speed the framing solve alone
	# asks for. A binding constraint that vanishes is a snapped rubber band; that is not a
	# metaphor, it is the mechanism.
	#
	# So when nothing covers, return the distance that came CLOSEST to covering. Approaching the
	# boundary from the uncoverable side, that distance approaches the boundary itself, so the
	# value is continuous across the transition and there is nothing to snap.
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
