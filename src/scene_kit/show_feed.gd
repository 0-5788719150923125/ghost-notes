extends Node
class_name ShowFeed

## ShowFeed - what the show hands the parts it mounts.
##
## A scene and a medium are played by a show, and there are a few things of the show each of them
## reads: the seed its rolls derive from, the dials a person set for this note (the camera, the
## handwriting, the holds at each end), values that move as it plays (the fade at the end, the
## hold left on the scene that is up, the fishing game's pull), and a way to ask for one more
## scene. Those few things are this class. A part reads them from its `feed` and never names who
## fills them in - which is what lets `scene_kit/`, `scenes/` and `media/` sit BELOW the player
## in `src/` (docs/structure.md), and what would let another player (a preview scrubbed by a
## timeline, a show whose entries arrive while it plays) drive the same parts.
##
## THE DIRECTOR IS ONE: `director.gd` extends this, so the fields here are its own, written by
## its own setters and persisted by it, and it hands itself to what it mounts ([method
## Director.attach], `_make_scene`). Nothing is copied from one object to another, so nothing
## here can be a frame stale.
##
## HANDED, WITH A DEFAULT. Whoever mounts a part sets its `feed`. A part nobody handed one - a
## gate that builds a medium by hand, a placeholder scene - starts on the show that is up
## ([method playing]), which is what reading the autoload by name used to give it.

static var _playing: ShowFeed


## The show that is up: the first feed made in this process (the Director, an autoload), or null
## before there is one.
static func playing() -> ShowFeed:
	return _playing


func _init() -> void:
	if _playing == null:
		_playing = self


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _playing == self:
		_playing = null


# --- the note's dials ---------------------------------------------------------------------------

## Bounds on the camera severity. 0 really is "as gentle as it goes" - a camera that drifts
## and never cuts - and 2 is the far end rather than a doubling of anything in particular.
const CAMERA_MIN := 0.0
const CAMERA_MAX := 2.0
## HOW SEVERE THE CAMERA IS, for a medium that flies one (the comic, the book, the tablet). 0 is a slow,
## gentle drift that barely turns; 1 is the tuned default; the top of the range is fast,
## restless and cinematic, with real jump cuts in it.
##
## ONE KNOB OVER A WHOLE BEHAVIOR, not a new setting per symptom. It scales the angular
## excursion a shot may take, how quickly that excursion is spent, how long a move lasts, how
## much of the bag is discontinuous, how deep a push goes and how fast the sheet drifts - so
## it moves the whole camera along one axis from "slow" to "chaotic" instead of asking anyone
## to balance six numbers. The full-frame medium has no camera and ignores it.
##
## Set through [method Director.set_camera]; persisted by [Settings] as `[director] camera`.
var camera: float = 1.0
## THE NOTEBOOK'S HANDWRITING - a key of the notebook's hands, or "random" to draw
## one per session from the seed. A setting, not only a draw, because the seed comes from the
## audio's fingerprint: any change to the audio chain changed the hand (Kalam -> Caveat).
## Set through [method Director.set_hand]; persisted as `[director] hand`.
var hand := "kalam"

# --- the holds at each end ------------------------------------------------------------------------

## A note that names no holds gets these ([method Director.reset_show]).
const INTRO_DEFAULT := 5.0
const OUTRO_DEFAULT := 6.0
var intro_hold := INTRO_DEFAULT
var outro_hold := OUTRO_DEFAULT
## A LIVE reading's own fade-out, 0..1 - the outro mark's, driven by the Generative panel from
## the sample being heard. 1 always in a render, where the take's own length and bookend do it.
var live_fade := 1.0

# --- what moves as it plays -----------------------------------------------------------------------

## The METAMORPHOSIS bus: while a catch is being reeled in, its influence
## contorts the current scene - every GhostScene reads this in tick() and
## stretches its motion tempo, zoom-breathing, and pan-sweeps by it. 0 = no
## contortion; big catches push past 1.
var aura := 0.0
## Below this smoothed audio level the track is treated as SILENT and scenes never change -
## forcing a cut with nothing playing (e.g. a song's silent tail) reads as broken. Kept well
## under lull_threshold so a musical lull still cuts but true silence holds the scene.
@export var silence_floor: float = 0.03


## The seed every scene choice, shot and roll of this session derives from. A part draws its own
## from it, folded with a key of its own, so attaching or switching off one part never changes
## another's draws.
func session_seed() -> int:
	return 0


# --- the show's time ------------------------------------------------------------------------------
# A PART IS A FUNCTION OF THE TIME IT IS HANDED. A medium, the table and the scenes read the
# show's clock here, never off the audio engine: a show whose time is not a song's - a preview
# scrubbed by a timeline, a live show conducted by what its agents write - drives them by
# answering these, and they cannot tell (next/structure.md, step 11).

## WHERE THE SHOW IS, in seconds: the moment a part draws itself at - the whole timeline, the
## bookend's lead-in included, and below 0 before it starts. [Director]: the session clock.
func show_time() -> float:
	return 0.0


## How long the show is on that same clock, bookends included; 0 while nobody knows (a stream
## still being made, a live show).
func show_length() -> float:
	return 0.0


## The seconds held after the last word, on the clock the show is timed by: the take's own tail
## where the bookend was baked into it (a render), else the note's outro hold.
func tail() -> float:
	return outro_hold


## The music's harmonic signature now (12 chroma bins and a coarse shape - [HarmonicSignature]),
## empty when nothing is heard: the continuous half of harmonic seeding, a scene's palette pulled
## toward the music's key.
func signature() -> PackedFloat32Array:
	return PackedFloat32Array()


## Seconds the scene that is up may still be held, or a deliberately large number when nothing
## is cutting: a caller then uses its own natural timing ([method Director.hold_remaining]).
func hold_remaining() -> float:
	return 1e9


## One more scene, cast by the show's own rules ([method Director.mint_scene]), or null from a
## feed that casts none.
func mint_scene(_salt := 0, _quiet := false) -> GhostScene:
	return null
