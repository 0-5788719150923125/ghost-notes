extends Medium
class_name DeskMedium

## DeskMedium - a ghost doing math at a desk: a legal pad under a lamp, and a pen that writes on it
## by itself while the teacher reads aloud what it writes (next/proof.md, "The desk").
##
## WHAT IT DRAWS FROM: the reading's document (`_subs.document`) - its `source`, the lesson with the
## pen's marks ([DeskScript]); its `desk`, what the Proof component hands the reading
## ([method ProofEpisode.document]): every formula as TeX laid it out (`ink`) and the episode's seed,
## which is the hand's; and its `title` and `byline`, the channel's, for the title screen.
##
## IT OPENS AND CLOSES AS THE CARD TABLE DOES ([ShowOpening], the user, 2026-10-16: "the intro/outro
## doesn't inherit the behavior from cards mode"): the channel's name over the desk thrown far out of
## focus while the intro holds, the focus pulled as the lesson's first word is said, and black a beat
## after its last word, as the outro runs out.
##
## THE PEN WRITES WHAT THE VOICE SAYS, AS IT SAYS IT ([DeskScript], the user the same day: "we need to
## narrate the text being written, as it is being written"): a formula's writing runs across exactly
## the words of its dictation, on the average never faster than [constant DeskScript.MAX_PACE] of the
## pen's own pace nor slower than [constant DeskScript.MIN_PACE]; where it would lag, the voice waits
## at the dictation's end, a rest the script already gave it, and nowhere inside it.
##
## THE PEN IS ELASTIC, AND NEVER STOPS MID-WRITING (the user, 2026-10-17: "the pen stopping at weird
## moments - like halfway between drawing a straight line, pausing for a second or two ... If the
## speech is gaining too far ahead, speed-up the pen. If the pen is too far ahead of the speech, slow
## down the motions. But NEVER should we just be stopping"). The ink's clock was the share of the
## words said, which stands still in every gap between two words - a comma, a breath, a rest - so the
## nib froze mid-stroke; and where the voice rested FOR the pen, the pen, waiting for words, rested
## too. Now it follows the voice's progress smoothed, with a steady share under it ([method elastic]):
## it slows over a pause and speeds over a run of words, and is never still until its line is done.
##
## A PURE FUNCTION OF THE VOICE'S TIME. A pad item is written at `_ink_time`, a function of the words'
## times and now, so any moment can be drawn without the ones before it: a seek lands on the page as it
## was. A READING STARTED MID-WAY (a scrub that starts the voice again from a later chunk) begins where
## its first words are (the document's `start_words`, as the card table and the tablet find theirs):
## everything before them was said long ago, so it is written on the first frame - matched from the
## top instead, no word of the new reading was ever found, and the pen stood still to the end (the
## user, 2026-10-16: "scrubbing the timeline seems to have broken the pen completely"). The camera alone eases (as the book's and the tablet's do), and lands at once on a seek.
##
## WHAT IS ON THE PAGE STAYS (the user, 2026-10-19: "two graphs are drawn side-by-side. Then suddenly,
## the 2nd one disappears and is re-drawn"). A live reading's word times arrive a sentence at a time,
## a few seconds before it is heard, so a dictation of several sentences is planned on a guess at its
## end; when its last words came in later than the guess, the share written fell and the newest strokes
## were taken back. So a plan made again holds the past ([method _hold_past]): what has begun keeps its
## start and its page's turn, what is done stays done, and a line being written goes on from where it is
## to the new end ([method _ink_time]). A reading whose times are all known at once (an export) is
## never planned again, and stays a pure function of time.
##
## A DRAWING TAKES ITS TIME (the user, 2026-10-20: "a lot of the chart and picture-drawing felt REALLY
## fast, relative to the voice describing the charts ... it could have been a lot slower and there still
## would have been plenty of buffer room to prepare for the next thing"). A drawing is said in a short
## line - "axes, the graph, its corner" - and its ink is long (every tick's number and label handwritten):
## held to its line, every drawing of an episode went at three and a half to four times the hand's pace,
## 26 to 59 seconds of ink in 6 to 15, and the pen then sat 2 to 11 seconds before its next action. So
## a drawing runs on past its line, through the talk about it (the paragraph after: `about`), as slow as
## the hand's own pace ([constant DRAW_PACE]) - done [constant DRAW_SETTLE] and the nib's way before
## the pen's next action is due ([method _drawn_by]), so that action is never late. The voice is the
## same: no rest is added or taken away.
##
## THE PAD: a page of a legal pad (8.5 x 11 in), ruled, filled top to bottom - every formula on the next
## rules ([method DeskScript.lay_out]) - and TURNED only when the next would run off the foot: the
## written sheet is lifted at its foot, rolls up over the binding and is folded round the back of the
## pad, its head lifted for it, and stays there; the clean page is under it ([LegalPad]; the user: "a
## page with text on it is just 'wiped' clean, for seemingly no reason ... use all of the available
## space on a page, and then turn the page if we need more space"). A struck line gets a stroke through
## it.
##
## EACH EPISODE'S DESK IS ITS OWN ([DeskLook], from the episode's seed): the pad's paper and binding,
## the ink, the pen, the desk's top and a mat on it, the lamp, a few things lying about, and how it is lit -
## the room's light and the candles burning on it, the card table's ([DeskLight]).
##
## THE CAMERA IS THE BOOK'S KIND ([BookMedium]: "something closer to what we did with the 'book' medium,
## with a further zoom and mostly vertical orientation ... the actor swapping for a calculator, or a
## tablet, or a laptop"): a long lens, looking down at the desk from high and a little in front; wide
## over the intro and as a page turns, closer while the pen writes, following the line being written
## through one slow critically damped spring; each page its own slight yaw and tilt, and a wander over
## minutes, so it never sits dead still and never reads as a move.
##
## THE PEN has no hand (the writer is unseen). It leans to the top right of the frame from its nib
## (the user: "it should angle to the top-right, which would be a more natural writing position") -
## which also keeps what it has just written, to the left of the nib, in view. THE HAND IS ALIVE (the
## user, 2026-10-16: "A hand holding a pen would never keep it at a perfectly static angle"): the lean
## sways slowly about that direction ([method lean]), turns a little with where on the page the nib
## is, as a forearm pivoting at the elbow turns it, and its top trails the nib's travel; off the paper
## the nib drifts a few millimeters ([method drift]) - never while it writes, where it is the ink's.
##
## THE PEN POINTS AT WHAT IS SPOKEN OF ([DeskScript]'s `point`; the user: "never POINTING to any of
## it ... after 2 minutes of no movement - it's very hard to get my attention back on track"): at the
## word, the nib comes down close over the named thing - sweeping along under it when it is wide - and
## stays beside its right end, low on its height, so the pen's body leans away over clean paper and
## never onto the line below; the camera goes there.
##
## AN IDLE PEN GETS OUT OF THE WAY (the user, 2026-10-19: "as it told the story, doing nothing, for ~30
## or 60 seconds, the pen was just frozen, right in the middle of the page, covering a bunch of the
## text's visibility ... it would be better for the pen to drift to the right and top"): over a stretch
## of [constant PARK_WORDS] words or more with nothing for it to do, and before a page turns, the nib
## drifts off the pad's top right ([constant PARK]) - its body leaning on away from the page, clear of a
## turning sheet - waits there, and comes back as its next action begins ([method _waiting]). Between
## two actions closer than that it waits beside what it just did. Every move between actions is
## continuous, and as long as its way ([method _reach]): the wait starts where the action ended and the
## reach where the wait is - the nib once jumped to its rest the frame an action ended, and across the
## page (1025 px in a frame) as one was about to turn it. The plan leaves that time between them
## ([method _way]), or a reach squeezed into nothing is a jump all the same.

## The page's canvas (an 8.5 x 11 sheet) and the sheet in the world, in meters.
const PW := DeskScript.PW
const PH := DeskScript.PH
const PAD_W := LegalPad.W
const PAD_H := LegalPad.H
## The pen's body, in meters; how high it lifts between strokes and at rest; how it eases there.
const PEN_LEN := 0.135
const PEN_R := 0.0048
const LIFT := 0.004
const REST_LIFT := 0.022
const REST_EASE := 0.9
const REACH_EASE := 0.45
## The pen comes down this long before its dictation's first word.
const PEN_LEAD := 0.2
## A DRAWING TAKES ITS TIME (see the class note): never quicker than its dictation, and on past it, through
## the talk about it, to as slow as the hand's own pace - done this long, and the nib's way, before the
## pen's next action is due.
const DRAW_PACE := 1.0
const DRAW_SETTLE := 1.0
## THE PEN IS ELASTIC ([method elastic]): the voice's progress through a dictation is smoothed over
## this many seconds, and this share of the pen's progress runs steady - the least it ever moves at,
## against its average pace over the dictation.
const ELASTIC_WINDOW := 1.5
const ELASTIC_FLOOR := 0.3
## POINTING: how close over the paper the nib comes; a thing this wide (px) or wider is swept under
## (this far below it) in the first [constant POINT_SWEEP] seconds - or all of a point the next one cuts
## shorter, so it ends where the pen waits from (cut at a third of its sweep, the nib jumped 366 px in a
## frame to the sweep's end, 2026-10-20); where the nib stays, this far right of the thing's end; and the
## least time a point is held.
const POINT_LIFT := 0.0035
const POINT_WIDE := 90.0
const POINT_SWEEP := 0.9
const POINT_GAP := 14.0
const POINT_MIN := 1.0
## OUT OF THE WAY: a stretch of this many words or more with nothing for the pen (about 15 s of a
## voice) sends it off the pad - this long after its last action ends, over this long - to this place
## (px of the page: right of its edge, level with its top margin).
const PARK_WORDS := 40
const PARK_AFTER := 1.0
const PARK_EASE := 2.5
const PARK := Vector2(DeskScript.PW + 90.0, DeskScript.FIRST_RULE * 0.5)
## It goes right first, and is off the pad this long after it sets off: a page never turns sooner
## after the last action before it (the sheet lifts at its foot, where that action was). It comes back
## over the new page once this share of the turn is over: the sheet folded under and the pad's head
## down again ([method LegalPad.tilt]).
const PARK_CLEAR := 1.0
const PARK_BACK := 0.93
## How fast the nib travels to its next action between two (px of the page a second, on the average).
const REACH_SPEED := 1000.0
## THE HAND IS ALIVE: the lean's slow sway (degrees, about the vertical and in its rise), its turn
## across the page's width (degrees from the left edge to the right), how far the top trails the nib
## (seconds of its travel, at most [constant TRAIL_MAX] degrees), measured over [constant MOTION_DT];
## and the nib's drift off the paper (px, and meters of lift), full at rest and none while it writes.
const SWAY_YAW := 5.0
const SWAY_TILT := 3.0
const REACH_YAW := 10.0
const TRAIL := 1.7
const TRAIL_MAX := 7.0
const MOTION_DT := 0.1
const DRIFT_PX := 12.0
const DRIFT_LIFT := 0.003
## How it leans from its nib: up, to the right, and away from the writer - the frame's top right.
const PEN_UP := Vector3(0.42, 0.64, -0.40)
## THE CAMERA: a long lens (the book's: a wide one stood close bends the page's lines), wide enough to
## hold the whole pad with room round it for the tools still to come, closer while the pen writes;
## mostly looking down. Distances in meters, pitches in degrees above the desk.
const VFOV := 20.0
const WIDE := {"dist": 1.45, "pitch": 74.0}
## The room's light where the desk's look writes none ([DeskLight]): a warm gray.
const AMBIENT := Color(0.55, 0.5, 0.45)
const AMBIENT_ENERGY := 0.35
const LOCAL := {"dist": 0.82, "pitch": 79.0}
const SPRING_TAU := 3.2
const YAW_SPREAD := 4.0
const YAW_WANDER := 1.5
const ROLL_SPREAD := 1.0
const TILT_SPREAD := 1.5
const ANGLE_SLOW := 3.0
## How long the framing looks ahead of the pen, as the book's does (springs make every move late).
const CAM_LEAD := 2.0
## A PAGE TURN IS SEEN WHOLE: the camera stands back this long before it (its springs are slow) and
## aims this far down the page, so the pad's head, where the page goes round, is in the shot.
const TURN_BACK := 3.0
const TURN_AIM := 0.36
## The page's margin line, from its left edge (px). Its colors, the paper's and the ink's are the
## desk's look's ([member look]).
const MARGIN_X := 128.0
## A FAINT line ([constant Ink.FAINT] - a figure's grid): how thin it may be drawn (px) and how light.
const FAINT_W := 1.3
const FAINT_ALPHA := 0.38

var _subs = null
var _doc_key := ""
var _seed := 1
var _actions: Array = []           # DeskScript's, laid out
var _records := {}                 # item id -> its typeset record (a part's box in `anchors`)
var _spoken_n := 0
var _strokes := {}                 # item id -> Ink.schedule
var _follower := ReadingFollower.new()
var _built_n := -1
var _plan: Array = []              # per action: {start, end, turn_at} (seconds), INF while not placed
var _held := {}                    # action -> what was shown of it when the plan was made again
## WORKED OUT ONCE, NOT EVERY FRAME (2026-10-27, the user: "performance can be really quite laggy in the realtime
## viewer"): the plans made so far, which a frame's answers are kept for ([method _pages]), and each finished
## action's ink, the same at any later moment ([method _done_ink_of]) - a page of handwriting was rebuilt point by
## point every time a line was finished, a 20 to 35 ms frame every few seconds.
var _plan_rev := 0
var _done_ink := {}
var _pages_now := NAN
var _pages_rev := -1
var _pages_got := Vector2i.ZERO
var _by_page := {}                  # a page -> its actions, in order ([method _page_actions]), for the actions in _by_page_of
var _turning: Array = []            # ...and the actions a page is turned for, in order
var _by_kind := {}                  # ...and each kind's ([method _of_kind])
var _by_page_of: Array = []
## WHERE THE PEN'S WALK GOES ON FROM ([method pen_at]): the actions before [member _pen_k] are all done at any moment
## from [member _pen_upto] on, the last of them the pen did [member _pen_last] - for the plan [member _pen_rev].
var _pen_k := 0
var _pen_last := -1
var _pen_upto := -INF
var _pen_rev := -1
var _ink_t := {}                    # [method _ink_time] by moment, then action, for the plan [member _ink_t_rev]
var _ink_t_rev := -1
var _now := 0.0
var _last_now := -1.0
var _snap := true

var _vp: SubViewport               # the page being written: the dry page under the wet ink
var _vp_dry: SubViewport           # ...its paper, rules and finished ink, inside it
var _vp_turn: SubViewport          # the page turning away
var _canvas: PadCanvas             # the page being written: its dry ink
var _wet: PadCanvas                # and over it, what the pen is writing now
var _canvas_turn: PadCanvas
var _placeholder: GhostScene
var _root3: Node3D
var _cam: Camera3D
var _attrs: CameraAttributesPractical
var _env: Environment
var _pad: LegalPad
var _desk: Node3D                  # the desk's top and the things on it
## THE DESK'S LIGHT beyond its lamp: the room's and the candles' ([DeskLight]).
var _light := DeskLight.new()
var _stage_was := {}                  # the stage's own settings, given back on leaving it
var _lamp: SpotLight3D
var _fill: DirectionalLight3D
var _lacquer: StandardMaterial3D   # the pen's body
var _trim: StandardMaterial3D      # ...and its metal
var _pen: Node3D
var _dressed := -1                 # the seed the desk was last dressed for
## THE DESK'S LOOK ([method DeskLook.of]): its colors and what is on it, from the episode's seed.
var look: Dictionary = DeskLook.of(1)
var _blur: IntroBlur
var _title: TitleCard
# the camera's springs
var _c_aim := Vector3.ZERO
var _v_aim := Vector3.ZERO
var _c_dist := 1.45
var _v_dist := 0.0
var _c_pitch := 74.0
var _v_pitch := 0.0
var _c_yaw := 0.0
var _v_yaw := 0.0
var _c_roll := 0.0
var _v_roll := 0.0


## A page, drawn: paper, rules, and the ink on page [member page] now - all of it, or one [member part].
##
## REDRAWN ONLY WHEN WHAT IT SHOWS HAS CHANGED ([method show_page]). A redraw frees and rebuilds every
## stroke on it - each polyline is a GPU polygon of its own, some 400 on a full page - and redrawn every
## frame, the desk made and threw away tens of thousands a second over a page that stood still, all
## night after an export, until the engine crashed freeing one (2026-10-16: signal 11 in
## `free_polygon`). So the page being written is two: its `dry` ink, redrawn as a formula is finished
## or the page changes, under its `wet`, only what the pen is writing now.
class PadCanvas extends Node2D:
	var desk: DeskMedium
	var page := 0
	## "all"; "dry" - the paper, its rules and the ink finished on it; or "wet" - only the ink still
	## being written, over the dry.
	var part := "all"
	var _shown: Array = []

	## Shows page [param p] as [param state] has it (its part of [method DeskMedium.page_state]):
	## queued for a redraw only when either has changed. True when it was.
	func show_page(p: int, state: Array) -> bool:
		if p == page and state == _shown:
			return false
		page = p
		_shown = state
		queue_redraw()
		return true

	## A new lesson: the next [method show_page] redraws, whatever it shows.
	func forget() -> void:
		page = -1
		_shown = []

	func _draw() -> void:
		if desk == null:
			return
		var look: Dictionary = desk.look
		if part != "wet":
			draw_rect(Rect2(0, 0, PW, PH), look["paper"])
			var y := DeskScript.FIRST_RULE
			while y < PH - 20.0:
				draw_line(Vector2(0, y), Vector2(PW, y), look["rule"], 2.6, true)
				y += DeskScript.RULE
			draw_line(Vector2(MARGIN_X, 0), Vector2(MARGIN_X, PH), look["margin"], 2.0)
			draw_line(Vector2(MARGIN_X + 6.0, 0), Vector2(MARGIN_X + 6.0, PH), look["margin"], 1.5)
		if page < 0:
			return
		var ink: Color = look["ink"]
		var faint := Color(ink, FAINT_ALPHA)
		# what is shown is what was worked out for it this frame ([method DeskMedium.page_state]): the dry its
		# finished actions, the wet `[action, share, ...]` - never the page walked again
		var lines: Array = []
		match part:
			"dry":
				for i in _shown:
					lines.append_array(desk._done_ink_of(int(i)))
			"wet":
				for k in range(0, _shown.size(), 2):
					lines.append_array(desk._ink_of(int(_shown[k])))
			_:
				lines = desk.page_ink(page, part)
		for line in lines:
			var pts: PackedVector2Array = line["points"]
			var c := faint if bool(line.get("faint", false)) else ink
			if pts.size() >= 2:
				draw_polyline(pts, c, float(line["width"]), true)
			elif pts.size() == 1:
				draw_circle(pts[0], float(line["width"]) * 0.5, c)


# --- mount -------------------------------------------------------------------------------

func mount(st: SubViewport) -> void:
	super.mount(st)
	# THE STAGE AS THE CARD TABLE SETS IT ([constant TableMedium.STAGE]): the lamp's shadow in a slot of its own of
	# a big atlas, debanded - on the stage's own the page and the desk wore a fine diagonal moire of the lamp's
	# shadow map (2026-10-27, the user: "weird stripey rings of light across the desk and paper")
	_stage_was = {}
	for key in TableMedium.STAGE:
		_stage_was[key] = st.get(key)
		st.set(key, TableMedium.STAGE[key])
	_light.medium = self
	_placeholder = GhostScene.new()
	_placeholder.init_with_seed(1, "drift")
	_placeholder.visible = false
	add_child(_placeholder)
	# A PAGE IS RENDERED ONLY WHEN IT CHANGES (2026-10-27, the user: "performance can be really quite laggy"): both
	# had rendered every frame, a page of handwriting some 2,100 draw calls - its finished ink is a viewport of its
	# own, rendered as a line is finished; the page the pad shows is that under the line being written, rendered as
	# the pen moves; the turning page once a turn ([method _show_pages])
	_vp_dry = _page_viewport(["dry"])
	_canvas = _vp_dry.get_child(0) as PadCanvas
	_vp = _page_viewport([])
	# inside the page it is drawn under, so it is rendered before it
	remove_child(_vp_dry)
	_vp.add_child(_vp_dry)
	var under := TextureRect.new()
	under.texture = _vp_dry.get_texture()
	_vp.add_child(under)
	_wet = PadCanvas.new()
	_wet.desk = self
	_wet.part = "wet"
	_vp.add_child(_wet)
	_vp_turn = _page_viewport(["all"])
	_canvas_turn = _vp_turn.get_child(0) as PadCanvas
	_build_world()
	# THE OPENING, the card table's: the intro's blur over the desk, and the name over the blur
	_blur = IntroBlur.new(ShowOpening.INTRO_SHADER)
	add_child(_blur)
	_title = TitleCard.new()
	_title.face = CardTable.font("roman")
	_title.italic = CardTable.font(CardTable.BOOK_ITALIC)
	# IN THE PAD'S OWN INK: the card table's light name (chosen to stand out from a painted table)
	# was cream on cream over the paper; dark, its shade turns light round it (CardTable.title_shade)
	_title.ink = look["ink"]
	add_child(_title)
	_dress()


## A page's viewport, drawn by a [PadCanvas] for each of [param parts], the first at the bottom.
func _page_viewport(parts: Array) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(PW), int(PH))
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	for part in parts:
		var c := PadCanvas.new()
		c.desk = self
		c.part = String(part)
		vp.add_child(c)
	return vp


func _build_world() -> void:
	_root3 = Node3D.new()
	add_child(_root3)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.02, 0.018, 0.016)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = AMBIENT
	_env.ambient_light_energy = AMBIENT_ENERGY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.adjustment_enabled = true
	_cam = Camera3D.new()
	_cam.fov = VFOV
	_cam.near = 0.05
	_cam.far = 40.0
	_cam.environment = _env
	# the lens's own blur is the opening's, as the card table's is ([ShowOpening])
	_attrs = CameraAttributesPractical.new()
	_attrs.dof_blur_far_enabled = false
	_cam.attributes = _attrs
	_root3.add_child(_cam)
	# THE LAMP, up and to the left of the pad, so the pen's shadow falls across the page to the right
	# - a white page under the tablet's lamp (4.2, set for a dark screen) burned out to no rules at all;
	# where exactly, how warm and how bright are the desk's look's
	_lamp = SpotLight3D.new()
	_lamp.spot_range = 4.0
	_lamp.spot_angle = 42.0
	_lamp.spot_angle_attenuation = 1.4
	_lamp.shadow_enabled = true
	_lamp.shadow_bias = 0.005
	_lamp.shadow_normal_bias = 0.15
	_lamp.shadow_blur = ShadowFilter.blur(2.8)
	_root3.add_child(_lamp)
	_fill = DirectionalLight3D.new()
	_fill.light_energy = 0.18
	_root3.add_child(_fill)
	_fill.rotation_degrees = Vector3(-60.0, 35.0, 0.0)

	_pad = LegalPad.new()
	_root3.add_child(_pad)

	_pen = Node3D.new()
	_root3.add_child(_pen)
	_lacquer = StandardMaterial3D.new()
	_lacquer.metallic = 0.3
	_lacquer.roughness = 0.28
	_trim = StandardMaterial3D.new()
	_trim.metallic = 0.9
	_trim.roughness = 0.3
	# the pen's own frame: its nib at the origin, its body up along +Y
	_pen.add_child(_cyl(PEN_R * 0.85, 0.0005, 0.02, 0.01, _trim))
	_pen.add_child(_cyl(PEN_R, PEN_R * 0.92, PEN_LEN, 0.02 + PEN_LEN * 0.5, _lacquer))
	_pen.add_child(_cyl(PEN_R * 1.04, PEN_R * 1.04, 0.006, 0.02 + PEN_LEN * 0.62, _trim))


## THE DESK DRESSED in [member look]: its top and the things on it, the pad's paper and binding, the
## pen, the lamp and the title's ink - once for each seed, as a lesson is loaded.
func _dress() -> void:
	if _root3 == null or _dressed == _seed:
		return
	_dressed = _seed
	if _desk != null:
		_desk.queue_free()
	var dressed := DeskLook.dress(look, _seed, LegalPad.DESK_Y)
	_desk = dressed["node"]
	_root3.add_child(_desk)
	_pad.seed = _seed
	_pad.build(look, _vp.get_texture(), _vp_turn.get_texture())
	var lamp: Dictionary = look["lamp"]
	_lamp.light_color = lamp["color"]
	_lamp.light_energy = float(lamp["energy"]) * float(lamp.get("share", 1.0))
	_lamp.visible = float(lamp.get("share", 1.0)) > 0.0
	_lamp.position = lamp["at"]
	_lamp.look_at_from_position(_lamp.position, Vector3(0.02, 0.0, 0.02), Vector3.UP)
	_fill.light_color = look["fill"]
	# the room's light and the candles ([DeskLight]); the old flat fill only where the look writes no room
	_env.ambient_light_color = AMBIENT
	_env.ambient_light_energy = AMBIENT_ENERGY
	_light.build(look, dressed["lit"], _seed)
	_fill.visible = not _light.lights_room()
	var pen: Dictionary = look["pen"]
	_lacquer.albedo_color = pen["body"]
	_trim.albedo_color = pen["trim"]
	_title.ink = look["ink"]
	for c in [_canvas, _wet, _canvas_turn]:
		(c as PadCanvas).forget()


func _cyl(top: float, bottom: float, height: float, y: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	m.mesh = c
	m.material_override = mat
	m.position = Vector3(0.0, y, 0.0)
	return m


func begin_session() -> void:
	_seed = feed.session_seed()
	_snap = true


func release() -> void:
	_subs = null
	_doc_key = ""


# --- the Medium contract --------------------------------------------------------------------

func owns_cast() -> bool:
	return true


func take_over(_outgoing: GhostScene) -> GhostScene:
	return _placeholder


func owns_bookend() -> bool:
	return true


## The words stay the overlay's to show: the pad shows what is written, not what is said.
func bind_captions(subs) -> bool:
	_subs = subs
	_doc_key = ""
	return false


func on_stage_resized(_size: Vector2) -> void:
	if _blur != null:
		_blur.queue_redraw()
	if _title != null:
		_title.queue_redraw()


func advance(_features, delta: float, _bookend: float) -> void:
	var t := maxf(feed.show_time(), 0.0)
	_ensure_doc()
	_now = _subs.now() if _subs != null and is_instance_valid(_subs) else t
	if absf(_now - _last_now) > 1.0:
		_snap = true
	if _now < _last_now - 1.0:
		# back in time: what was shown is not the past any more
		_held = {}
		_built_n = -1
	_last_now = _now
	if _subs != null and is_instance_valid(_subs) and not _actions.is_empty():
		take_words(_subs.words)
	# UP FROM BLACK as the session starts, down to it after the last word - the desk owns its
	# bookend, as the card table does; an outro mark's fade still is the feed's
	_env.adjustment_brightness = clampf(clampf(t / 1.2, 0.0, 1.0)
		* _end_fade() * feed.live_fade, 0.0, 1.0)
	var opening := _opening()
	ShowOpening.lens(ShowOpening.pull(_now, opening, _built_n > 0), _blur, _attrs)
	_title.alpha = ShowOpening.title_alpha(_now, opening, _built_n > 0)
	_title.queue_redraw()
	_show_pages()
	_place_pen()
	_tick_camera(delta)
	_light.tick(_now)


func _exit_tree() -> void:
	_light.release()
	if stage != null and is_instance_valid(stage) and not _stage_was.is_empty():
		for key in _stage_was:
			stage.set(key, _stage_was[key])


## THE CLOSE: 1 until the lesson is over, then down to black over the outro ([method ShowOpening.end_fade]).
func _end_fade() -> float:
	return ShowOpening.end_fade(_now, _follower, _spoken_n, feed.tail())


## THE VOICE'S WORDS SO FAR (the overlay's growing `words`), matched, and the plan made again when more
## came. More of the same reading keeps what the page shows ([method _hold_past]) - taken before the new
## times are, since they move where a dictation's unheard words were guessed; a new one (fewer words)
## starts clean. Public for a gate, which hands it words as a live reading would.
func take_words(words: Array) -> void:
	var grown := words.size() != _built_n
	if grown:
		if _built_n > 0 and words.size() > _built_n:
			_hold_past()
		else:
			_held = {}
	_follower.extend(words)
	if grown:
		_built_n = words.size()
		_build_plan()


## THE LESSON OPENS with its first word, which the pen's first dictation is: INF until it is heard.
func _opening() -> float:
	return _word_t0(0)


# --- the document ------------------------------------------------------------------------------

func _ensure_doc() -> void:
	if _subs == null or not is_instance_valid(_subs):
		return
	var d: Dictionary = _subs.document
	_title.channel = String(d.get("title", ""))
	_title.byline = String(d.get("byline", ""))
	var src := String(d.get("source", ""))
	var desk: Dictionary = d.get("desk", {}) if d.get("desk") is Dictionary else {}
	var start: PackedStringArray = d.get("start_words", PackedStringArray()) \
		if d.get("start_words") is PackedStringArray else PackedStringArray()
	var key := "%d|%s|%d|%s" % [src.hash(), String(desk.get("dir", "")), int(desk.get("seed", 0)),
		" ".join(start)]
	if key == _doc_key:
		return
	_doc_key = key
	load_lesson(src, desk, start, int(d.get("start_index", -1)))


## LOAD A LESSON: [param source] (the lesson's text, the pen's marks in it) and [param desk] (`{ink,
## seed}` - the typeset items and the hand's seed); for a reading started mid-way, its first words
## [param start] (normalized), [param near] the index they are about. Public for a gate, which hands
## it one by hand.
func load_lesson(source: String, desk: Dictionary, start := PackedStringArray(), near := -1) -> void:
	_seed = int(desk.get("seed", _seed))
	look = DeskLook.of(_seed)
	_dress()
	var typeset: Dictionary = desk.get("ink", {}) if desk.get("ink") is Dictionary else {}
	var records := {}
	for r in typeset.get("items", []):
		if r is Dictionary and bool((r as Dictionary).get("ok", false)):
			records[String((r as Dictionary)["id"])] = r
	var outlines: Dictionary = typeset.get("fonts", {}) if typeset.get("fonts") is Dictionary else {}
	_strokes = {}
	var lengths := {}
	for id in records:
		var got := Ink.strokes_of(records[id], _seed, outlines)
		var sched := Ink.schedule(got["strokes"], _seed)
		_strokes[id] = sched
		lengths[id] = float(sched["length"])
	_records = records
	var parsed: Dictionary = DeskScript.parse(source, lengths, records)
	_actions = parsed["actions"]
	var spoken: PackedStringArray = parsed["spoken"]
	_spoken_n = spoken.size()
	var from := TabletScript.find_run(spoken, start, near) if not start.is_empty() else -1
	var est := PackedFloat32Array()
	if from > 0:
		# the past, spaced as a steady voice would have said it, rests and all
		for w in DeskScript.rehearsal(parsed):
			est.append(float((w as Dictionary)["t0"]))
	_follower.reset(spoken, from, est)
	_built_n = -1
	_held = {}
	_plan = []
	_plan_rev += 1
	_done_ink = {}
	for i in _actions.size():
		_plan.append({"start": INF, "end": INF, "turn_at": INF})
	_snap = true
	for c in [_canvas, _wet, _canvas_turn]:
		if c != null:
			(c as PadCanvas).forget()


## WHEN EACH ACTION HAPPENS. A written item starts as its dictation's first word is said (the pen down
## [constant PEN_LEAD] before it) and ends as the words do - no sooner than the pen can write it at
## [constant DeskScript.MAX_PACE], no later than at [constant DeskScript.MIN_PACE] - and never before
## the one before it has ended; a drawing goes on past its words ([method _drawn_by]). One with no dictation, and a strike, are performed in the rest before
## the next words. A POINT is there as its word is said and held to its sentence's end, never into
## the time the pen needs to reach what comes next. A page turn comes in the rest before the item that
## needs it, never over writing still going on nor before the pen is off the pad ([constant
## PARK_CLEAR]), and the item waits for it. No action begins before the nib can get there from the
## last ([method _way]). An action whose words have not arrived waits. What [member _held] keeps of the
## past is kept: a start, a turn, a done action's end; one under way ends no sooner than the pen can
## finish it from where it is.
func _build_plan() -> void:
	_plan_rev += 1
	var prev_end := -INF
	var last := -1                  # the last action the pen does
	for i in _actions.size():
		_plan[i] = {"start": INF, "end": INF, "turn_at": INF}
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var held: Dictionary = _held.get(i, {})
		if held.has("start") and held.has("end"):
			# DONE BEFORE THE PLAN WAS MADE AGAIN, and kept as it was - all that is worked out below for it is then
			# overwritten (a live reading makes the plan again as each sentence's words arrive)
			_plan[i] = {"start": float(held["start"]), "end": float(held["end"]), "turn_at": float(held.get("turn_at", INF))}
			prev_end = float(held["end"])
			if not (String(a["kind"]) == "point" and target_box(a).size.x < 0.0):
				last = i
			continue
		var ready := prev_end + (_way(last, i) if last >= 0 else 0.0)
		var after := int(a.get("after", 0))
		var span := int(a.get("span", 0))
		var write := float(a.get("write", 0.0))
		var start := INF
		var end := INF
		if String(a["kind"]) in DeskScript.WRITES and span > 0:
			var due := _due(i, _word_t0(after))
			if due == INF:
				break
			start = float(held.get("start", maxf(due, ready)))
			var said := _word_t1(after + span - 1)
			end = clampf(said if said < INF else start + float(span) * DeskScript.EST_WORD,
				start + write / DeskScript.MAX_PACE, start + write / DeskScript.MIN_PACE)
			end = _paced_end(i, start, end)
			if String(a["kind"]) == "draw":
				end = maxf(end, minf(start + write / DRAW_PACE, _drawn_by(i)))
		elif String(a["kind"]) == "point":
			var t0 := _word_t0(after)
			if t0 == INF:
				break
			start = float(held.get("start", maxf(t0, ready)))
			var said := _word_t1(after + maxi(span, 1) - 1)
			end = maxf(said if said < INF else start + float(span) * DeskScript.EST_WORD, start + POINT_MIN)
			if i + 1 < _actions.size():
				var next := _word_t0(int((_actions[i + 1] as Dictionary).get("after", 0)))
				if next < INF:
					end = maxf(minf(end, next - PEN_LEAD - REACH_EASE), start + 0.3)
		else:
			var before := _word_t1(after - 1) if after > 0 else maxf(feed.intro_hold, 0.6) + _blank() - 0.25
			if before == INF:
				break
			# an action the writer DECIDES on first (a letter's strike, [constant LetterScript.DECIDE]): the
			# voice and the pen both done, then that long, the pen held still
			var decide := float(a.get("decide", 0.0))
			var due := maxf(before, prev_end) + decide if decide > 0.0 else before + 0.25
			start = float(held.get("start", maxf(due, ready)))
			end = start + write
		var turn_at := float(held.get("turn_at", INF))
		if bool(a.get("turn", false)) and not held.has("start"):
			# early enough for the pen to come back over the new page behind the sheet, at its pace
			var back := DeskScript.TURN * PARK_BACK + _travel(PARK.distance_to(_action_point(a, true)))
			if not held.has("turn_at"):
				turn_at = maxf(start - back - 0.1, prev_end + PARK_CLEAR)
			var late := maxf(turn_at + DeskScript.TURN + 0.05, turn_at + back) - start
			if late > 0.0:
				start += late
				end += late
		if held.has("end"):
			end = float(held["end"])
		elif held.has("at"):
			end = maxf(end, float(held["at"]) + maxf((1.0 - float(held.get("u", 0.0))) * write / DeskScript.MAX_PACE, 0.3))
		_plan[i] = {"start": start, "end": end, "turn_at": turn_at}
		prev_end = end
		if not (String(a["kind"]) == "point" and target_box(a).size.x < 0.0):
			last = i


## HOW LONG THE NIB NEEDS to get from action [param last] to action [param next]: its way at
## [constant REACH_SPEED], never under [constant REACH_EASE] - none for a point at nothing on its page,
## which the pen leaves be. [method _build_plan] leaves it between them, so no reach is squeezed into
## nothing: a point said while a drawing was still being written began the frame the drawing ended, and
## the nib crossed 326 px in one frame (2026-10-19, the Universal Approximation episode).
func _way(last: int, next: int) -> float:
	var b: Dictionary = _actions[next]
	if String(b["kind"]) == "point" and target_box(b).size.x < 0.0:
		return 0.0
	var from := PARK if _parks(last, next) else _action_point(_actions[last], false)
	return _travel(from.distance_to(_action_point(b, true)))


## How long the nib takes over [param px] of the page between two actions: at [constant REACH_SPEED],
## never under [constant REACH_EASE].
func _travel(px: float) -> float:
	return maxf(px / REACH_SPEED, REACH_EASE)


## THE LATEST DRAWING [param i] MAY END: as the talk about it ends (a drawing with none, the next mark
## right after its line, has the voice's rest before it), and [constant DRAW_SETTLE] and the nib's way
## before the pen's next action is due - a write's pen down, a point's word, a page's turn early
## enough for the pen to come back behind the sheet ([method _build_plan] gives each the same time). A
## word not heard yet is guessed a steady word on from the last that was ([method _guess]).
func _drawn_by(i: int) -> float:
	var a: Dictionary = _actions[i]
	var about := int(a.get("about", 0))
	var by := _guess(int(a["after"]) + int(a["span"]) + about - 1, true) if about > 0 else INF
	for j in range(i + 1, _actions.size()):
		var b: Dictionary = _actions[j]
		var kind := String(b["kind"])
		if kind == "point" and target_box(b).size.x < 0.0:
			continue
		var after := int(b.get("after", 0))
		var due := _guess(after, false)
		if kind in DeskScript.WRITES and int(b.get("span", 0)) > 0:
			due -= PEN_LEAD
		elif kind != "point":
			due = _guess(after - 1, true) + 0.25
		if bool(b.get("turn", false)):
			var back := DeskScript.TURN * PARK_BACK + _travel(PARK.distance_to(_action_point(b, true)))
			due = minf(due - _way(i, j), due - back - 0.1 - PARK_CLEAR)
		else:
			due -= _way(i, j)
		return minf(by, due - DRAW_SETTLE)
	return by


## When spoken word [param si] begins (or [param ends]): heard, or guessed [constant DeskScript.EST_WORD]
## a word on from the last word heard; INF before any is.
func _guess(si: int, ends: bool) -> float:
	var t := _word_t1(si) if ends else _word_t0(si)
	if t < INF:
		return t
	var k := mini(si, _follower.said1.size()) - 1
	while k >= 0 and _follower.said1[k] == ReadingFollower.NO_TIME:
		k -= 1
	if k < 0:
		return INF
	return _follower.said1[k] + float(si - k - (0 if ends else 1)) * DeskScript.EST_WORD


## WHAT THE PAGE HAS SHOWN, taken as the plan is about to be made again at [member _now]: for each action
## begun, its start and when it began to be held; its end once done, else how much of it is written; and
## a page turn begun. [method _build_plan] keeps them, and [method _ink_time] goes on from them.
func _hold_past() -> void:
	var held := {}
	for i in _actions.size():
		var p: Dictionary = _plan[i]
		var h := {}
		if float(p["turn_at"]) <= _now:
			h["turn_at"] = float(p["turn_at"])
		if float(p["start"]) <= _now:
			h["start"] = float(p["start"])
			h["at"] = _now
			if float(p["end"]) <= _now:
				h["end"] = float(p["end"])
			else:
				h["u"] = _written(i)
		if not h.is_empty():
			held[i] = h
	_held = held


## When spoken word [param si] began and ended: INF while the voice has not reached it. A word it went
## past without matching has the time it was most likely said ([member ReadingFollower.said0]) - a
## word that waited for one held every action after it.
func _word_t0(si: int) -> float:
	if si < 0 or si >= _follower.said0.size() or _follower.said0[si] == ReadingFollower.NO_TIME:
		return INF
	return _follower.said0[si]


func _word_t1(si: int) -> float:
	if si < 0 or si >= _follower.said1.size() or _follower.said1[si] == ReadingFollower.NO_TIME:
		return INF
	return _follower.said1[si]


## HOW FAR THROUGH ITS WRITING action [param i] is at [member _now], as the ink's own clock (seconds
## of [method Ink.schedule]): a dictated item's by [method elastic], over its dictation's words; one
## written in silence at an even pace, across the rest the voice gives it. One under way when the plan
## was made again ([member _held]) goes on from what was written then: the rest of it is spread over
## what the new plan has left of it, so the ink never goes back and never jumps.
func _ink_time(i: int) -> float:
	# asked of the line being written four or five times a frame - the page, its wet ink, the pen now and a moment
	# before - and each works the dictation out word by word
	if _ink_t_rev != _plan_rev or _ink_t.size() > 8:
		_ink_t = {}
		_ink_t_rev = _plan_rev
	# by the moment exactly (a float key is the whole double), then the action
	var at_now: Dictionary = _ink_t.get_or_add(_now, {})
	if at_now.has(i):
		return at_now[i]
	var got := _ink_time_now(i)
	at_now[i] = got
	return got


func _ink_time_now(i: int) -> float:
	var u := _share(i, _now)
	var h: Dictionary = _held.get(i, {})
	if h.has("u"):
		var at := float(h["at"])
		var u0 := float(h["u"])
		var from := _share(i, at)
		var rest := (u - from) / (1.0 - from) if from < 0.98 \
			else (_now - at) / maxf(float(_plan[i]["end"]) - at, 0.01)
		u = u0 + (1.0 - u0) * clampf(rest, 0.0, 1.0)
	return _length(i) * u


## How far through its writing action [param i] is at [param t] by the plan alone, 0 to 1.
func _share(i: int, t: float) -> float:
	var a: Dictionary = _actions[i]
	var start := float(_plan[i]["start"])
	var end := float(_plan[i]["end"])
	var span := int(a.get("span", 0))
	if span <= 0:
		return clampf((t - start) / maxf(end - start, 0.01), 0.0, 1.0)
	var times := _dictation(int(a["after"]), span, start)
	return elastic(t, start, end, times[0], times[1])


## The times of the [param span] words from [param after]: [t0s, t1s], a word not heard yet placed
## after the last that was, a steady word apart ([constant DeskScript.EST_WORD]).
func _dictation(after: int, span: int, start: float) -> Array:
	var t0s := PackedFloat32Array()
	var t1s := PackedFloat32Array()
	var last := start + PEN_LEAD
	for j in span:
		var t0 := _word_t0(after + j)
		var t1 := _word_t1(after + j)
		if t0 == INF or t1 == INF:
			t0 = last + 0.05
			t1 = t0 + DeskScript.EST_WORD * 0.9
		t0s.append(t0)
		t1s.append(t1)
		last = t1
	return [t0s, t1s]


## THE PEN'S CLOCK, ELASTIC: how far through its writing (0 to 1) the pen is at [param now], for
## writing planned from [param start] to [param end] across words said at [param t0s] to [param t1s].
## A pure function, so a seek lands where the pen would be.
##
## The voice's progress through the words (a word counts as it is said) is smoothed over
## [constant ELASTIC_WINDOW], so a pause in it is a slope and not a step, and its time is stretched
## onto the pen's - the pen that lags runs the whole way behind, evenly, rather than slowing as the
## voice ends. [constant ELASTIC_FLOOR] of the pen's progress runs steady from its start to its end, so
## the pen never stands still while it writes: over a long pause it slows to about that share of its
## average pace, and makes it up over the words after. Then it is set to run from 0 at
## [param start] to 1 at [param end] exactly.
static func elastic(now: float, start: float, end: float, t0s: PackedFloat32Array,
		t1s: PackedFloat32Array) -> float:
	if now <= start:
		return 0.0
	if now >= end or t0s.is_empty():
		return clampf((now - start) / maxf(end - start, 0.01), 0.0, 1.0)
	var warp := maxf(t1s[t1s.size() - 1] - start, 0.01) / (end - start)
	var lo := _elastic_mix(start, start, end, warp, t0s, t1s)
	var hi := _elastic_mix(end, start, end, warp, t0s, t1s)
	return clampf((_elastic_mix(now, start, end, warp, t0s, t1s) - lo) / maxf(hi - lo, 1e-6), 0.0, 1.0)


## [method elastic] before it is set to run from 0 to 1: the smoothed voice at the pen's time, mixed
## with the steady share.
static func _elastic_mix(now: float, start: float, end: float, warp: float, t0s: PackedFloat32Array,
		t1s: PackedFloat32Array) -> float:
	var t := start + (now - start) * warp
	var h := ELASTIC_WINDOW * 0.5
	var voice := (_said_area(t + h, t0s, t1s) - _said_area(t - h, t0s, t1s)) / ELASTIC_WINDOW
	return (1.0 - ELASTIC_FLOOR) * voice + ELASTIC_FLOOR * (now - start) / (end - start)


## The share of words [param t0s]..[param t1s] said, summed over time up to [param t]: its integral,
## so that a window's mean is two calls. A word counts evenly across its own time; a word that starts
## before the last has ended starts as it ends.
static func _said_area(t: float, t0s: PackedFloat32Array, t1s: PackedFloat32Array) -> float:
	var step := 1.0 / float(t0s.size())
	var area := 0.0
	var level := 0.0
	var x := t0s[0]
	for j in t0s.size():
		var a := maxf(t0s[j], x)
		var b := maxf(t1s[j], a + 0.001)
		if t <= a:
			return area + level * maxf(t - x, 0.0)
		area += level * (a - x)
		if t <= b:
			var d := t - a
			return area + level * d + 0.5 * step * d * d / (b - a)
		area += (level + 0.5 * step) * (b - a)
		level += step
		x = b
	return area + (t - x)


# --- the pages ---------------------------------------------------------------------------------

## The page being written at [member _now], and the one turning away (-1 when none is): a page begins
## as the turn before it does.
func _pages() -> Vector2i:
	# asked several times a frame (the pages, the camera's arc and framing): the same moment, the same plan
	if _now == _pages_now and _plan_rev == _pages_rev:
		return _pages_got
	var page := 0
	var turning := -1
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var begin := minf(float(_plan[i]["turn_at"]), float(_plan[i]["start"]))
		if begin > _now:
			break
		page = int(a["page"])
		var ta := float(_plan[i]["turn_at"])
		turning = page - 1 if ta < INF and _now < ta + DeskScript.TURN else -1
	_pages_now = _now
	_pages_rev = _plan_rev
	_pages_got = Vector2i(page, turning)
	return _pages_got


func _show_pages() -> void:
	var p := _pages()
	var now := page_state(p.x)
	var dry := _canvas.show_page(p.x, now["dry"])
	var wet := _wet.show_page(p.x, now["wet"])
	if dry:
		_vp_dry.render_target_update_mode = SubViewport.UPDATE_ONCE
	if dry or wet:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if p.y < 0:
		_pad.show_turned(p.x, -1.0)
		return
	if _canvas_turn.show_page(p.y, page_state(p.y)["all"]):
		_vp_turn.render_target_update_mode = SubViewport.UPDATE_ONCE
	var ta := INF
	for i in _page_actions(p.x):
		if float(_plan[i]["turn_at"]) < INF:
			ta = float(_plan[i]["turn_at"])
			break
	# the pages before it lie over the pad's head, and it goes over them
	_pad.show_turned(p.y, clampf((_now - ta) / DeskScript.TURN, 0.0, 1.0))


## THE INK ON PAGE [param page] NOW, in the page's pixels: [{points, width}] - what [PadCanvas] draws;
## all of it, or the [param part] finished (`dry`) or still being written (`wet`).
func page_ink(page: int, part := "all") -> Array:
	var out: Array = []
	for i in _on_page(page):
		var done := _written(i) >= 1.0
		if part != "all" and done != (part == "dry"):
			continue
		out.append_array(_done_ink_of(i) if done else _ink_of(i))
	return out


## A FINISHED ACTION'S INK, made once: all of it, at any moment after its end ([method _ink_of]).
func _done_ink_of(i: int) -> Array:
	if not _done_ink.has(i):
		_done_ink[i] = _ink_of(i)
	return _done_ink[i]


## What page [param page] shows at [member _now], as its [PadCanvas]es key it: the actions finished
## on it (`dry`), each still being written with how much of it is (`wet`), and both (`all`).
func page_state(page: int) -> Dictionary:
	var dry: Array = []
	var wet: Array = []
	for i in _on_page(page):
		var u := _written(i)
		if u >= 1.0:
			dry.append(i)
		else:
			wet.append_array([i, u])
	return {"dry": dry, "wet": wet, "all": dry + wet}


## The actions begun on page [param page] by [member _now], in order (a strike, on the page of what it
## strikes).
func _on_page(page: int) -> Array:
	var out: Array = []
	for i in _page_actions(page):
		var a: Dictionary = _actions[i]
		if float(_plan[i]["start"]) > _now or int(a["page"]) != page or String(a["kind"]) == "point":
			continue
		if String(a["kind"]) == "strike":
			var of := int(a.get("of", -1))
			if of < 0 or int((_actions[of] as Dictionary)["page"]) != page:
				continue
		out.append(i)
	return out


## THE ACTIONS LAID ON PAGE [param page], in order - made once a lesson or a letter is laid out: the pages, the pen
## and the camera ask every frame, and walking every action of a letter from its first had cost a frame milliseconds.
func _page_actions(page: int) -> Array:
	_index()
	return _by_page.get(page, [])


## The actions of [param kind] (a tap, a point...), in order ([method _page_actions]'s index).
func _of_kind(kind: String) -> Array:
	_index()
	return _by_kind.get(kind, [])


## The actions a page is turned for, in order ([method _page_actions]'s index).
func _turn_actions() -> Array:
	_index()
	return _turning


func _index() -> void:
	if is_same(_by_page_of, _actions):
		return
	_by_page = {}
	_turning = []
	_by_kind = {}
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		(_by_page.get_or_add(int(a["page"]), []) as Array).append(i)
		(_by_kind.get_or_add(String(a["kind"]), []) as Array).append(i)
		if bool(a.get("turn", false)):
			_turning.append(i)
	_by_page_of = _actions


## How long action [param i] takes the pen: its ink's, else what the script gave it.
func _length(i: int) -> float:
	var a: Dictionary = _actions[i]
	return float((_strokes.get(String(a["id"]), {}) as Dictionary).get("length", a.get("write", 0.0)))


## How much of action [param i] is written at [member _now], 0 to 1.
func _written(i: int) -> float:
	var a: Dictionary = _actions[i]
	if String(a["kind"]) == "strike":
		return clampf((_now - float(_plan[i]["start"])) / maxf(float(a["write"]), 0.01), 0.0, 1.0)
	# DONE IS DONE: past its end its share is 1 whatever the dictation ([method _share], held or not) - and this is
	# asked of every action on the page every frame, where the dictation is worked out word by word
	if _now >= float(_plan[i]["end"]):
		return 1.0
	var length := _length(i)
	return 1.0 if length <= 0.0 else clampf(_ink_time(i) / length, 0.0, 1.0)


## Action [param i]'s ink at [member _now], as polylines in the page's pixels.
func _ink_of(i: int) -> Array:
	var a: Dictionary = _actions[i]
	var out: Array = []
	match String(a["kind"]):
		"pad", "pad-text", "draw":
			var sched: Dictionary = _strokes.get(String(a["id"]), {})
			if sched.is_empty():
				return out
			var k := float(a["k"]) * DeskScript.PX_PER_PT
			# onto the page in one native step, never point by point: a line of handwriting is thousands of them,
			# and the line being written is drawn again every frame
			var to_page := Transform2D(0.0, Vector2(k, k), 0.0, a["at"] as Vector2)
			for s in Ink.at(sched, _ink_time(i))["ink"]:
				var pts: PackedVector2Array = to_page * PackedVector2Array((s as Dictionary)["points"])
				var faint := bool((s as Dictionary).get("faint", false))
				out.append({"points": pts, "width": maxf(FAINT_W if faint else 2.4, float((s as Dictionary)["width"]) * k * 1.35),
					"faint": faint})
		"strike":
			var line := _strike_line(_actions[int(a["of"])])
			out.append({"points": PackedVector2Array([line[0], line[0].lerp(line[1], _written(i))]), "width": 3.2})
	return out


## The stroke a cross-out draws through a written action: across its middle, a little rising.
static func _strike_line(a: Dictionary) -> Array:
	var at: Vector2 = a.get("at", Vector2.ZERO)
	var w := float(a.get("w", 100.0))
	var h := float(a.get("h", 30.0))
	return [at + Vector2(-14.0, -h * 0.32), at + Vector2(w + 14.0, -h * 0.45)]


# --- the pen ---------------------------------------------------------------------------------

## WHERE THE NIB IS NOW, on the page (px), and how high above it (m): writing, it is the ink's nib;
## between strokes it lifts and travels; between actions it waits ([method _waiting]) and reaches the
## next as it begins ([method _reach]); before the first, it waits at the page's right.
func pen_at() -> Dictionary:
	var rest := {"p": Vector2(PW * 0.84, DeskScript.FIRST_RULE + DeskScript.RULE * 2.0), "lift": REST_LIFT}
	var last := -1                  # the last action the pen did
	# FROM WHERE THE LAST WALK FOUND ALL DONE (asked twice a frame, it had walked from the letter's first action): a
	# done action stays done as the time goes on, and which points aim at nothing is the layout's
	if _pen_rev != _plan_rev:
		_pen_rev = _plan_rev
		_pen_k = 0
		_pen_last = -1
		_pen_upto = -INF
	var from := 0
	if _now >= _pen_upto:
		from = _pen_k
		last = _pen_last
	for i in range(from, _actions.size()):
		var a: Dictionary = _actions[i]
		if String(a["kind"]) == "point" and target_box(a).size.x < 0.0:
			if i == _pen_k:
				_pen_k += 1
			continue        # at nothing on this page: the pen stays where it is
		var start := float(_plan[i]["start"])
		if start == INF:
			return _waiting(last, i) if last >= 0 else rest
		if _now < start:
			# on its way to the action: from where it waits to where the action begins
			var wait := _waiting(last, i) if last >= 0 else rest
			var u := _ease(clampf(1.0 - (start - _now) / _reach(last, i), 0.0, 1.0))
			return {"p": (wait["p"] as Vector2).lerp(_action_point(a, true), u),
				"lift": lerpf(float(wait["lift"]), _down(a), u)}
		if _now < float(_plan[i]["end"]):
			return _pen_during(a, i, start)
		last = i
		if i == _pen_k:
			_pen_k += 1
			_pen_last = i
			_pen_upto = maxf(_pen_upto, float(_plan[i]["end"]))
	return _waiting(last, -1) if last >= 0 else rest


## WHERE THE NIB WAITS at [member _now], after action [param last] and before action [param next] (-1:
## none comes): it settles beside the end of what it did, a little lifted; and where [method _parks]
## says the wait is long, or a page is to turn, it drifts on from there to [constant PARK] - before a
## turn at once, as the sheet will lift. One continuous way from where the action left the nib.
func _waiting(last: int, next: int) -> Dictionary:
	var a: Dictionary = _actions[last]
	var end := float(_plan[last]["end"])
	var from := _action_point(a, false)
	var s := _ease(clampf((_now - end) / REST_EASE, 0.0, 1.0))
	var p := from.lerp(_rest_near(from), s)
	var lift := lerpf(_down(a), REST_LIFT, s)
	if _parks(last, next):
		var turning := next >= 0 and bool((_actions[next] as Dictionary).get("turn", false))
		var v := (_now - end - (0.0 if turning else PARK_AFTER)) / PARK_EASE
		# right first, off the written lines (and out from under a sheet about to turn), then up the
		# pad's edge
		var cleared := PARK_CLEAR / PARK_EASE
		p = Vector2(lerpf(p.x, PARK.x, _ease(clampf(v / cleared, 0.0, 1.0))),
			lerpf(p.y, PARK.y, _ease(clampf((v - cleared * 0.75) / (1.0 - cleared * 0.75), 0.0, 1.0))))
	return {"p": p, "lift": lift}


## Does the pen get out of the way between action [param last] and action [param next] (-1: the lesson's
## end)? When [constant PARK_WORDS] words or more are said between them, or [param next] turns the page.
## Read off the script, never the voice's times, so it never changes its mind as a voice's words arrive.
func _parks(last: int, next: int) -> bool:
	var a: Dictionary = _actions[last]
	var to := _spoken_n
	if next >= 0:
		var b: Dictionary = _actions[next]
		if bool(b.get("turn", false)):
			return true
		to = int(b.get("after", 0))
	return to - (int(a.get("after", 0)) + int(a.get("span", 0))) >= PARK_WORDS


## HOW LONG THE NIB TAKES TO REACH action [param next] after action [param last] (-1: none came): its
## way from where it waits at [constant REACH_SPEED], never quicker than [constant REACH_EASE] - and
## never longer than the wait, so it sets off from where the last action left it (over a page being
## turned, once [constant PARK_BACK] of the turn is over). Every reach once took
## [constant REACH_EASE], and 30 of an episode's 110 crossed most of the page in it (2026-10-19).
func _reach(last: int, next: int) -> float:
	var to := _action_point(_actions[next], true)
	if last < 0:
		return _travel(Vector2(PW * 0.84, DeskScript.FIRST_RULE + DeskScript.RULE * 2.0).distance_to(to))
	var from := PARK if _parks(last, next) else _rest_near(_action_point(_actions[last], false))
	var free := float(_plan[last]["end"])
	if float(_plan[next]["turn_at"]) < INF:
		free = maxf(free, float(_plan[next]["turn_at"]) + DeskScript.TURN * PARK_BACK)
	return minf(_travel(from.distance_to(to)), maxf(float(_plan[next]["start"]) - free, 0.01))


## How high the nib is as action [param a] begins and ends: on the paper for writing, just over it for
## a point.
static func _down(a: Dictionary) -> float:
	return POINT_LIFT if String(a["kind"]) == "point" else 0.0


func _pen_during(a: Dictionary, i: int, start: float) -> Dictionary:
	match String(a["kind"]):
		"pad", "pad-text", "draw":
			var local := _ink_time(i)
			var sched: Dictionary = _strokes.get(String(a["id"]), {})
			var at: Vector2 = a["at"]
			var k := float(a["k"]) * DeskScript.PX_PER_PT
			var prev := Vector2.INF
			var prev_t1 := 0.0
			for s in sched.get("strokes", []):
				var st: Dictionary = s
				var t0 := float(st["t0"])
				var t1 := float(st["t1"])
				var pts: PackedVector2Array = st["points"]
				if local < t0:
					# lifted, travelling from the last stroke's end to this one's start
					var from: Vector2 = prev if prev != Vector2.INF else pts[0]
					var u := clampf((local - prev_t1) / maxf(t0 - prev_t1, 0.05), 0.0, 1.0)
					return {"p": at + from.lerp(pts[0], _ease(u)) * k, "lift": sin(u * PI) * LIFT}
				if local <= t1:
					var now_ink := Ink.at({"strokes": [st]}, local)
					var nib: Vector2 = now_ink["pen"] if now_ink["pen"] != Vector2.INF else pts[pts.size() - 1]
					return {"p": at + nib * k, "lift": 0.0}
				prev = pts[pts.size() - 1]
				prev_t1 = t1
			return {"p": at + (prev if prev != Vector2.INF else Vector2.ZERO) * k, "lift": LIFT}
		"strike":
			var of := int(a.get("of", -1))
			if of >= 0:
				var line := _strike_line(_actions[of])
				var u := clampf((_now - start) / maxf(float(a["write"]), 0.01), 0.0, 1.0)
				return {"p": (line[0] as Vector2).lerp(line[1], u), "lift": 0.0}
		"point":
			var path := point_path(a)
			var u := clampf((_now - start) / clampf(float(_plan[i]["end"]) - start, 0.05, POINT_SWEEP), 0.0, 1.0)
			var p: Vector2 = (path[0] as Vector2).lerp(path[1], _ease(u / 0.7)) if u < 0.7 \
				else (path[1] as Vector2).lerp(path[2], _ease((u - 0.7) / 0.3))
			return {"p": p, "lift": POINT_LIFT}
	return {"p": Vector2(PW * 0.84, DeskScript.FIRST_RULE + DeskScript.RULE * 2.0), "lift": REST_LIFT}


## Where an action's writing begins ([param first]) or ends, on the page.
func _action_point(a: Dictionary, first: bool) -> Vector2:
	match String(a["kind"]):
		"pad", "pad-text", "draw":
			var strokes: Array = (_strokes.get(String(a["id"]), {}) as Dictionary).get("strokes", [])
			if not strokes.is_empty():
				var pts: PackedVector2Array = (strokes[0 if first else strokes.size() - 1] as Dictionary)["points"]
				return (a["at"] as Vector2) + pts[0 if first else pts.size() - 1] * float(a["k"]) * DeskScript.PX_PER_PT
			return a.get("at", Vector2(PW * 0.5, PH * 0.3))
		"strike":
			var of := int(a.get("of", -1))
			if of >= 0:
				return _strike_line(_actions[of])[0 if first else 1]
		"point":
			return point_path(a)[0 if first else 2]
	return Vector2(PW * 0.84, DeskScript.FIRST_RULE + DeskScript.RULE * 2.0)


## WHAT A POINT POINTS AT, on the page (px): the box of the thing it names - a part's, from its ink
## record's `anchors`, else the whole thing's - or a box of negative size when that is not on the page
## the point is made over (or was never written).
func target_box(a: Dictionary) -> Rect2:
	var none := Rect2(Vector2.ZERO, Vector2(-1.0, -1.0))
	var of := int(a.get("of", -1))
	if of < 0 or of >= _actions.size():
		return none
	var t: Dictionary = _actions[of]
	if int(t["page"]) != int(a["page"]) or not t.has("at"):
		return none
	var at: Vector2 = t["at"]
	var part := String(a.get("part", ""))
	var anchors: Dictionary = (_records.get(String(t["id"]), {}) as Dictionary).get("anchors", {})
	var b: Array = anchors.get(part, []) if not part.is_empty() and anchors.get(part) is Array else []
	if b.size() == 4:
		var k := float(t["k"]) * DeskScript.PX_PER_PT
		return Rect2(at + Vector2(float(b[0]), float(b[1])) * k,
			Vector2(float(b[2]) - float(b[0]), float(b[3]) - float(b[1])) * k)
	return Rect2(at.x, at.y - float(t["h"]), float(t["w"]), float(t["h"]) + float(t["d"]))


## THE NIB'S WAY WHILE IT POINTS: `[down, along, stays]` - it comes down under a wide thing (a
## formula, a curve) and sweeps along under it, then stays beside its right end, low on its height;
## at a small one (a dot, a label, a short line) it comes straight to that place. Beside the end, the
## pen's body leans away over clean paper, and never onto a line below (an aligned block's next line
## is closer than a rule).
func point_path(a: Dictionary) -> Array:
	var b := target_box(a)
	var stays := Vector2(b.end.x + POINT_GAP * 0.5, b.position.y + b.size.y * 0.7)
	if b.size.x >= POINT_WIDE:
		var y := b.end.y + POINT_GAP * 0.5
		return [Vector2(b.position.x + b.size.x * 0.1, y), Vector2(b.end.x - b.size.x * 0.05, y), stays]
	return [stays, stays, stays]


## Where the pen rests after writing at [param p]: to its right and a little below, clear of the line.
static func _rest_near(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x + 130.0, DeskScript.MATH_X, PW - 70.0),
		clampf(p.y + 40.0, DeskScript.FIRST_RULE, PH - 80.0))


static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## A point of the page (px) in the world, [param lift] meters above it.
func _world(p: Vector2, lift: float) -> Vector3:
	var local := Vector3((p.x / PW - 0.5) * PAD_W, 0.0003 + lift, (p.y / PH - 0.5) * PAD_H)
	return _pad.transform * local


func _place_pen() -> void:
	var at := pen_at()
	var p: Vector2 = at["p"]
	var lift := float(at["lift"])
	var keep := _now
	_now = keep - MOTION_DT
	var before: Vector2 = pen_at()["p"]
	_now = keep
	var moved := (p - before) / MOTION_DT
	var d := drift(_now, _seed, lift)
	var up := lean(PEN_UP, _now, _seed, p.x / PW,
		Vector3(moved.x / PW * PAD_W, 0.0, moved.y / PH * PAD_H))
	var nib := _world(p + (d["dp"] as Vector2), lift + float(d["dlift"]))
	var x := up.cross(Vector3.FORWARD).normalized()
	var z := x.cross(up).normalized()
	_pen.global_transform = Transform3D(Basis(x, up, z), nib)


## THE PEN'S LEAN at [param now]: [param base] swayed slowly about the vertical and in its rise (the
## phases the hand's [param seed]'s), turned toward the page's top as the nib goes left
## ([param x_share], 0 at the page's left edge, 1 at its right - a forearm pivoting at the elbow), and
## its top trailing [param motion], the nib's travel across the desk (m/s). A unit vector, always within
## a few degrees of [param base]. Pure: the same moment is the same lean.
static func lean(base: Vector3, now: float, seed: int, x_share: float, motion: Vector3) -> Vector3:
	var ph := _phases(seed)
	var up := base.normalized()
	var yaw := SWAY_YAW * (0.65 * sin(TAU * now / 7.3 + ph[0]) + 0.35 * sin(TAU * now / 3.1 + ph[1])) \
		+ REACH_YAW * (0.7 - clampf(x_share, 0.0, 1.0))
	up = up.rotated(Vector3.UP, deg_to_rad(yaw))
	var flat := Vector3(up.x, 0.0, up.z)
	if flat.length() > 0.001:
		var tilt := SWAY_TILT * sin(TAU * now / 5.7 + ph[2])
		up = up.rotated(Vector3.UP.cross(flat).normalized(), deg_to_rad(tilt))
	var trail := Vector3(motion.x, 0.0, motion.z) * -TRAIL
	var most := tan(deg_to_rad(TRAIL_MAX))
	if trail.length() > most:
		trail = trail.normalized() * most
	return (up + trail).normalized()


## THE NIB'S DRIFT off the paper at [param now]: `{dp, dlift}` (px, m) - slow, a few millimeters, in
## proportion to how high it is held ([param lift] of [constant REST_LIFT]): full at rest, slight while
## it points, none while it writes, where the nib is the ink's.
static func drift(now: float, seed: int, lift: float) -> Dictionary:
	var w := clampf(lift / REST_LIFT, 0.0, 1.0)
	var ph := _phases(seed)
	var dx := 0.6 * sin(TAU * now / 9.1 + ph[3]) + 0.4 * sin(TAU * now / 4.3 + ph[4])
	var dy := 0.6 * sin(TAU * now / 8.3 + ph[5]) + 0.4 * sin(TAU * now / 3.7 + ph[6])
	return {"dp": Vector2(dx, dy) * DRIFT_PX * w, "dlift": DRIFT_LIFT * sin(TAU * now / 6.1 + ph[7]) * w}


## The hand's phases, from its seed: eight angles.
static func _phases(seed: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in 8:
		out.append(TAU * _hash01(seed, 700 + k))
	return out


# --- the camera -------------------------------------------------------------------------------

## THE FRAMING'S TARGET at [member _now]: how close (0 wide, 1 local) and where on the page. Wide until
## the lesson opens, as a page turns and once the last word is said; local on the line being written -
## looked for [constant CAM_LEAD] ahead, the springs being late.
func _framing() -> Dictionary:
	var k := 0.0
	var turn := false
	var line := Vector2(PW * 0.5, PH * 0.5)
	var opening := _opening()
	if opening < INF and _now > opening - 1.0:
		k = 1.0
	var ahead := _now + CAM_LEAD
	var page := _pages().x
	# the page's actions and the next's - an earlier page's frame nothing and turned long ago
	for i in _page_actions(page) + _page_actions(page + 1):
		var a: Dictionary = _actions[i]
		var start := float(_plan[i]["start"])
		var ta := float(_plan[i]["turn_at"])
		if ta < INF and _now > ta - TURN_BACK and _now < ta + DeskScript.TURN + 0.3:
			k = 0.0         # a turn, though what it turns for begins further ahead
			turn = true
		if start == INF or start > ahead:
			break
		if String(a["kind"]) == "point":
			# a point is framed on what it points at
			var b := target_box(a)
			if b.size.x >= 0.0 and int(a["page"]) == page:
				line = b.get_center()
			continue
		if int(a["page"]) == page and a.has("at"):
			# a drawing is framed on its middle; a line of writing, on its baseline
			var up := float(a.get("h", 0.0)) * 0.5 if String(a["kind"]) == "draw" else 0.0
			line = Vector2((a["at"] as Vector2).x + float(a["w"]) * 0.5, (a["at"] as Vector2).y - up)
	if _ended():
		k = 0.0
	return {"k": k, "line": line, "turn": turn}


## Is the lesson over at [member _now] - its last word said?
func _ended() -> bool:
	var known := _follower.known_last()
	return _spoken_n > 0 and known >= _spoken_n - 1 and _now > _follower.st1[known]


func _tick_camera(delta: float) -> void:
	var f := _framing()
	var k := float(f["k"])
	var line: Vector2 = f["line"]
	# the whole pad, its binding too, with the desk round it - and as a page turns, its head, where
	# the page goes over and round
	var wide_aim := _world(Vector2(PW * 0.5, PH * (TURN_AIM if bool(f["turn"]) else 0.45)), 0.0)
	# local: the line being written, held a little below the frame's middle, never off the pad
	var local_aim := _world(Vector2(clampf(line.x, PW * 0.35, PW * 0.65), clampf(line.y + 60.0, PH * 0.3, PH * 0.72)), 0.0)
	var aim := wide_aim.lerp(local_aim, k)
	var page := _pages().x
	var wide: Dictionary = _wide_frame()
	var close: Dictionary = _local_frame()
	var w := _wander_time()
	var yaw := (_hash01(page, 41) - 0.5) * 2.0 * YAW_SPREAD + sin(w * 0.021 + float(_seed % 97)) * YAW_WANDER
	var pitch := lerpf(float(wide["pitch"]), float(close["pitch"]), k) \
		+ (_hash01(page, 67) - 0.5) * 2.0 * TILT_SPREAD + sin(w * 0.029 + 1.3) * 0.8
	var dist := lerpf(float(wide["dist"]), float(close["dist"]), k) * (1.0 + 0.012 * sin(w * 0.033 + 2.1))
	var roll := (_hash01(page, 53) - 0.5) * 2.0 * ROLL_SPREAD + sin(w * 0.047 + 0.7) * 0.5
	if _snap:
		_snap = false
		_c_aim = aim
		_c_dist = dist
		_c_pitch = pitch
		_c_yaw = yaw
		_c_roll = roll
		_v_aim = Vector3.ZERO
		_v_dist = 0.0
		_v_pitch = 0.0
		_v_yaw = 0.0
		_v_roll = 0.0
	var tau := _spring_tau()
	var steps := maxi(1, int(ceil(delta / (1.0 / 60.0))))
	var h := delta / float(steps)
	for _i in steps:
		var res := BookMedium._spring3(_c_aim, _v_aim, aim, tau, h)
		_c_aim = res[0]
		_v_aim = res[1]
		var rd := BookMedium._spring(_c_dist, _v_dist, dist, tau, h)
		_c_dist = rd.x
		_v_dist = rd.y
		var rp := BookMedium._spring(_c_pitch, _v_pitch, pitch, tau, h)
		_c_pitch = rp.x
		_v_pitch = rp.y
		var ry := BookMedium._spring(_c_yaw, _v_yaw, yaw, tau * ANGLE_SLOW, h)
		_c_yaw = ry.x
		_v_yaw = ry.y
		var rr := BookMedium._spring(_c_roll, _v_roll, roll, tau * ANGLE_SLOW, h)
		_c_roll = rr.x
		_v_roll = rr.y
	var p := deg_to_rad(_c_pitch)
	var y := deg_to_rad(_c_yaw)
	var dir := Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p))
	_cam.position = _c_aim + dir * _c_dist
	_cam.look_at(_c_aim, Vector3.UP)
	_cam.rotate_object_local(Vector3.FORWARD, deg_to_rad(_c_roll))


## The camera's wide and close framings ([constant WIDE], [constant LOCAL]).
func _wide_frame() -> Dictionary:
	return WIDE


func _local_frame() -> Dictionary:
	return LOCAL


## The time the camera's slow wander is read at: now.
func _wander_time() -> float:
	return _now


## How slowly the camera's springs follow ([constant SPRING_TAU]).
func _spring_tau() -> float:
	return SPRING_TAU


## How long the page lies blank after the intro before anything is done on it (seconds): none at the desk.
func _blank() -> float:
	return 0.0


## WHEN DICTATED action [param i] MAY BEGIN, its first word said at [param t0] (INF while it is not): at the
## desk, as it is said - a little before, the pen's lead. INF holds the plan there until it is known.
## A medium whose pen writes ahead (a letter's, [LetterMedium]) answers for itself.
func _due(_i: int, t0: float) -> float:
	return t0 - PEN_LEAD if t0 < INF else INF


## WHEN DICTATED action [param i], begun at [param start], ends: [param end], the elastic pen's - the
## desk's writing keeps time with the words it is dictated.
func _paced_end(_i: int, _start: float, end: float) -> float:
	return end


static func _hash01(page: int, salt: int) -> float:
	return float(absi(hash(["desk-cam", page, salt])) % 10007) / 10006.0
