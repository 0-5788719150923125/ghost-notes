extends ShowFeed

signal scene_cut                      # a new scene just took the stage (see main's governor)
signal filters_changed                # the look over the whole picture changed (see [Filters])
signal medium_changed                 # the remembered medium changed; rows that follow it re-show
signal frame_changed                  # the frame (or what the medium allows of it) changed: the stage refits

## Director - the scene registry, scheduler and transition engine (autoload).
##
## Pairs every visualizer with a motion behavior and changes scenes with the music. Two typed axes
## govern a change: lifecycle (a scene loops until cut, or is a oneshot that plays one sequence and
## reports finished()) and trigger (once a loop is past its minimum hold, the exit waits for a
## spectral cue: a beat, a movement or a lull; a maximum hold is the backstop). Most changes are
## jump cuts, some blend. Everything is seeded from the song hash, so a track always yields the same
## scenes, behaviors, triggers and cut/blend choices.


# The auto show is deterministic per song (see _resolve_seed); this salt is mixed into the seed, so
# changing it re-rolls the whole show for a fixed song.
const SEED_SALT := 3141592653589793


enum Style { CUT, DIP, FADE, LAYER }
enum Trigger { BEAT, MOVEMENT, LULL }

# How a change is performed, weighted: mostly a DIP to black (old scene out, a beat of darkness, new
# one up) so two scenes never overlap; an occasional hard CUT; a plain crossfade is rare.
const STYLE_BAG := [Style.DIP, Style.DIP, Style.DIP, Style.DIP, Style.CUT, Style.FADE, Style.LAYER]
# Exit cues, weighted: usually a beat, sometimes a section change (movement) or a drop into quiet (lull).
const TRIGGER_BAG := [Trigger.BEAT, Trigger.BEAT, Trigger.BEAT, Trigger.MOVEMENT, Trigger.MOVEMENT, Trigger.LULL]

## Don't exit a looping scene before this (seconds). Both this and max_hold are scaled by
## _pacing_scale at use: loud, fast passages shorten the holds, calm ones lengthen them. These are
## the calm-reference values.
@export var min_hold: float = 7.0
## Exit at least this often even if the chosen cue never arrives (seconds); scaled like min_hold.
@export var max_hold: float = 28.0

## Scene-pacing knobs (see _pacing_scale). The hold multiplier runs from pace_drive_scale (full
## drive, scenes cut fast) up to pace_calm_scale (quiet, scenes linger); pace_energy_gain sets how
## strongly loudness alone shortens holds.
@export var pace_drive_scale: float = 0.35
@export var pace_calm_scale: float = 1.2
@export var pace_energy_gain: float = 3.4
## Hold the final scene through the song's closing stretch: within this many seconds of the end,
## stop changing scenes (a late cut into a near-empty tail reads as a glitch).
@export var end_hold: float = 10.0
## Movement score (0..1) that satisfies a MOVEMENT trigger.
@export var movement_threshold: float = 0.6
## Energy (0..1) at or below which a LULL trigger fires.
@export var lull_threshold: float = 0.12
## Narrative tempo; higher is faster. Scene holds and the auto-mode pacing bounds shrink by it and each
## scene's keyframe phases arrive sooner. It compresses only the narrative clock, not the bodies'
## ambient animation (see GhostScene.event_scale). A storyboard overrides it with a top-level
## `sensitivity` (and per-entry `sensitivity`).
@export var sensitivity: float = 1.0
## Scene-transition pacing: a multiplier on how long a scene holds before it cuts (1.0 = baseline). It
## multiplies the auto-mode hold bounds and a burst's quick-cut bounds together, so the music-driven
## variance is kept; it never changes how a scene animates or how long a dissolve takes, and authored
## storyboard timings (`hold:`, `min_hold:`, `max_hold:`) stay literal. Set it through
## [method set_pacing]; persisted by [Settings] as `[director] pacing`.
var pacing: float = 1.0
## How readily the show throws a flourish (a burst of quick cuts or a run of beat-synced punches):
## 1.0 is the default, 0.0 turns them off, the top of the range makes them regular. Separate from
## `pacing`, which is how long an ordinary scene holds.
var flourish: float = 1.0
## The medium the show is carried on, a key from [constant Medium.REGISTRY] (`full` = full frame,
## `comic` = a comic page). See [Medium]. Held here, persisted in `user://ghost.cfg`, so the export
## render (a separate process that reads it on boot) inherits it with no flag. `--medium NAME`
## overrides it for one run.
var medium := "full"
## A medium pinned by the mode that is up, for its sessions only; "" when the author's [member
## medium] applies. Never saved. [method resolved_medium] honors it under an explicit `--medium`, and
## the exporter passes what that resolves to. A card pins it with [method pin_medium], and only it
## takes it back ([method unpin_medium]).
var medium_override := ""
var _pinned_by := 0            # the instance that pinned [member medium_override] ([method pin_medium]), 0 for none
## The frame a show is made in - "landscape" (1920x1080) or "portrait" (1080x1920) - kept beside the
## medium in the note's picture block (next/notes.md). A run uses [method resolved_frame].
var frame := "landscape"
## The look: a post-process over the whole picture as `{filter key: amount}` with only the live
## ones present (see [Filters]); filters combine. Held here for the same reason as `medium` (the
## export render inherits it from `user://ghost.cfg`). `--filter KEY=AMOUNT,...` (or `--filter none`)
## overrides it for one run.
var filters: Dictionary = {}
## How the subtitles reveal a line ([constant Subtitles.REVEALS]); an export render draws them the same way.
var subtitle_reveal := "karaoke"
## The tonemapper ([constant Tonemaps.REGISTRY]), pushed to every 3D set as it changes ([method
## Tonemaps.choose]); an export render inherits it. Filmic until a note picks another.
var tonemap: String = Tonemaps.DEFAULT
## The adjustments a person made, kept per tonemapper (key -> its adjustments); a tonemapper not here
## is at its preset.
var tonemap_adjust: Dictionary = {}
const FLOURISH_MIN := 0.0
const FLOURISH_MAX := 4.0
const PACING_MIN := 0.25
const PACING_MAX := 4.0
## Seconds a dip or blend takes end to end (cuts are instant); a dip spends the middle in darkness.
@export var transition_time: float = 2.0
## A LAYER transition is slower than a dip: the two scenes overlap and shift before the first leaves.
@export var layer_time: float = 6.0

var _host: Node = null
## Where the frame is in the window (window pixels), so a click on it can be asked of the scene showing ([method pick]).
var frame_rect := Rect2()
var _turned := {}                # who -> {filter: amount}: the Look as parts of the show turn it now ([method turn_look])
## The medium (see [Medium]), set by [method attach]; null is treated as `full`. The Director reaches
## a medium only through four vetoes: where a scene is added (_scene_host), the transition style
## (_choose_style), whether the outgoing scene may fade (_tick_schedule), and who applies the bookend.
var _medium: Medium = null
## Extra entropy for one scene pick, so a caller can mint several scenes without the Director's clock
## advancing between them (a comic page casts all its panels at once; see [method mint_scene]).
## Folded in by XOR and 0 on the Director's own path, so at 0 every expression is unchanged and the
## show stays deterministic per song. tests/scenes/scene_mix_check.gd replays a seed and compares.
var _pick_salt := 0
var _prev_time := -1.0       # last frame's music-clock position (Spectrum.current.time); the time step
                             # derives from it, not the drawn-frame delta, so scenes and cuts stay
                             # locked to the song when a heavy scene drops FPS
var _current: GhostScene = null
var _next: GhostScene = null
var _index := -1
var _elapsed := 0.0

var _transitioning := false
var _trans_t := 0.0
var _style: Style = Style.CUT
var _trigger: Trigger = Trigger.BEAT
var _beat_prev := 0.0
var _audio_ema := 0.0        # smoothed audio level (fast attack, slow release) for the silence guard
# The material's own normal level: a slow running mean of _audio_ema (~LEVEL_REF_TAU seconds, about one
# section). Loudness belongs to the content (narration ~0.09-0.14, a mastered track ~0.40), so the
# "is the music leaning in?" tests compare the fast level against this (see _lean). Bias-corrected
# (the EMA of a constant 1 is carried and divided out), so early on it is the true mean.
var _audio_ref := 0.0
var _ref_acc := 0.0
var _ref_w := 0.0
const LEVEL_REF_TAU := 30.0
var _bookend_time := 6.0     # seconds of the start fade-up-from-black and end fade-down-to-black
# Rapid-fire burst: a sparse, harmonic-gated flurry of quick jump cuts. While live, holds shrink to a
# few seconds and every exit is a hard CUT landing on the beat.
var _burst_left := 0         # quick scenes remaining in the burst (0 = normal pacing)
var _burst_min := 1.5        # this burst's minimum hold (s)
var _burst_max := 4.0        # this burst's maximum hold (s)
# Scenes until the next flurry of each kind may start. The burst and the stinger keep separate
# counters (the stinger rolls on every beat, the burst once per cut, so a shared one starves the
# burst); neither kind may begin while the other is live.
var _burst_cd := 0
var _flurry_cd := 0
var _cue_prev := 0.0    # _elapsed at the last cue offer (see _cue_taken)
# Chance of a burst at an eligible cut: BURST_BASE on an ordinary moment, BURST_BASE + BURST_GAIN when
# the material is leaning in hard, scaled by `flourish`. One roll per cut, so these are per-scene odds.
# Raising them puts a flurry on almost every subtitle (5%/15% measured 29 cuts in 184 s against a
# 25-cut baseline).
const BURST_BASE := 0.012
const BURST_GAIN := 0.05
const FLURRY_CD_MIN := 6     # never fewer scenes between flurries, whatever the pacing (see _flurry_spacing)
# Rapid-fire stinger: a run of beat-synced punches that contort, recolor and zoom the current scene,
# then settle. It rides the SceneView pulse and node tint, so it works on any scene.
#
# Zoom kicks are sampled per punch (see _drive_stinger; sting_shape_check.gd checks the outward one
# against the margin below). A punch is an accent over the camera's ordinary travel: the inward kick
# tops out at 1.5 x DRIFT_PULL, since larger kicks read as the scene exploding at any smoothness.
const STING_PUSH := Vector2(0.03, 0.12)   # inward: crops, can expose nothing
const STING_PULL := Vector2(0.015, 0.04)  # outward: walks the painted edge into shot
## What a punch is worth when the session is a reading rather than a song, applied to its camera half
## and to the length of a run: a reading may be punctuated but not interrupted. At this fraction the
## accent is a lean of a few percent.
const STING_READING := 0.45
## The overdraw margin layer-composed scenes are painted to: the literal 1.15 in [method
## GhostScene.update_layers]. A punch must stay inside it.
const LAYER_OVERDRAW := 1.15
## The largest zoom-out camera drift alone can ask for ([method GhostScene.drift_view]: `zoom` gain
## 0.08 at a view gain of 1, modulator in -1..1).
const DRIFT_PULL := 0.08
var _sting_left := 0         # beat-synced punches remaining in the run
var _sting_t := -1.0         # seconds into the live punch, < 0 when none is live
var _sting_span := 0.28      # that punch's whole envelope, sampled from the pulse period
var _sting_zoom := 0.0       # this punch's sampled kicks
var _sting_rot := 0.0
var _sting_skew := 0.0
var _sting_flash := 0.0
var _swaps := 0
var _rng := RandomNumberGenerator.new()
var _locked := -1            # >=0 pins one scene (authoring), set via --scene N
var _held := false           # the feedback console freezes cuts while open
var _kind_last := {}         # scene script path -> _swaps value when last shown
var _session_seed := 0       # base seed for this session (random per play; --seed pins)

# Manual mode: a storyboard is an ordered, authored sequence of scenes ([Storyboard], docs/stage.md).
# While _storyboard_seq is non-empty the Director walks it instead of the novelty scheduler, and each
# entry can dictate its own exit.
var _storyboard_seq: Array = []
var _storyboard_tail: Array = []     # entries cycled after a non-looping sequence ends (never freeze)
var _storyboard_name := ""           # DISPLAY name (the JSON "name" field) - for UI only
var _storyboard_source := ""         # the loadable name/path passed to load_storyboard - for re-loading (export)
var _storyboard_loop := true
var _storyboard_transition := ""    # default transition style for a storyboard ("" = cut in manual mode)
var _storyboard_sensitivity := -1.0 # storyboard-wide tempo override (<0 = fall back to the export)
var _cur_sens := 1.0                 # the ACTIVE scene's resolved sensitivity (used by the pacing bounds)
var _step := 0

# Content re-localization (manual mode). [Echo] maps what the song sounds like at each schedule
# position and matches the live harmonics against it, so the cursor answers to the music, not the
# playhead: when the audio sustains a match elsewhere (the song looped, a track re-entered its
# opening), the cursor corrects there.
var _echo: Echo = null
var _sched_starts: Array = []        # schedule start time (s) of each sequence entry
var _sched_end := 0.0                # schedule time where the sequence ends and the tail begins
var _manual_i := -1                  # index of the on-screen SEQUENCE entry (-1 = tail / auto)
var _entry_i := -1                   # ...and of the on-screen entry, the tail's counted on from the sequence's end
var _heard_t := 0.0                  # monotonic listening clock (never rewinds; lags vote against it)
var _cursor_t := 0.0                 # the cursor's continuous schedule-time claim: snapped to an entry's
                                     # start when one begins, free-running through the tail, so the echo
                                     # map covers the whole first hearing


# --- picture settings ---------------------------------------------------------
# [Settings] owns the file, the debounce and the flushing; these setters write straight through it
# (no dirty flag or save timer here).

## The bookend, in seconds: held silence before the first sound and after the last. Applied by
## [method main._begin_session] to [member Spectrum.lead_in] / [member Spectrum.tail], and read back
## by [method _bookend_fade] so the picture arrives as the silence ends. The defaults are the shortest
## that let the ambience pad finish its gesture ([constant VoiceFX.PAD_ATTACK] = 3.5 s,
## [constant VoiceFX.PAD_RELEASE] = 7 s, first tone half a second in). One range for both ends, so the
## two sliders place a value at the same position.
const INTRO_MIN := 0.0
const INTRO_MAX := 60.0
const OUTRO_MIN := 0.0
const OUTRO_MAX := 60.0


# The Director is an autoload, so this runs before attach() builds the first scene: the first hold of
# a session already uses the remembered pacing.
func _ready() -> void:
	_load_pacing()


## Set the scene-transition pacing multiplier (see [member pacing]) and remember it. Safe on every
## frame of a slider drag (an unchanged value is a no-op; the disk write is debounced). It applies to
## the scene on screen, as the hold bounds are re-derived each frame; a live burst keeps the bounds
## sampled at its start (see _maybe_start_burst). Dragging down can cut at once, once per scene.
func set_pacing(v: float) -> void:
	var p := clampf(v, PACING_MIN, PACING_MAX)
	if is_equal_approx(p, pacing):
		return
	pacing = p
	_save_pacing()



## A note starts from nothing: the medium, the frame, the look and the holds go back to their
## defaults as a note opens, and the note's own blocks then set what it asks for (a note that names
## none must not inherit the last note's). Each goes through its setter, so the signals fire and the
## settings file an export render reads agrees.
func reset_show() -> void:
	medium_override = ""
	_pinned_by = 0
	set_medium("full")
	set_frame("landscape")
	set_pacing(1.0)
	set_flourish(1.0)
	set_camera(1.0)
	set_hand("kalam")
	set_intro_hold(INTRO_DEFAULT)
	set_outro_hold(OUTRO_DEFAULT)
	set_opening(Openings.DEFAULT)
	for k in filters.keys():
		set_filter(String(k), 0.0)
	set_tonemap_all(Tonemaps.DEFAULT, {})


## Is a session attached - is there a show for a cut, a restage or the transport to act on?
func is_attached() -> bool:
	return _host != null


## The intro / outro holds, in seconds. They take effect on the next session: the lead-in is decided
## when playback starts.
func set_intro_hold(v: float) -> void:
	var s := clampf(v, INTRO_MIN, INTRO_MAX)
	if is_equal_approx(s, intro_hold):
		return
	intro_hold = s
	_save_pacing()


func set_outro_hold(v: float) -> void:
	var s := clampf(v, OUTRO_MIN, OUTRO_MAX)
	if is_equal_approx(s, outro_hold):
		return
	outro_hold = s
	_save_pacing()


## How the show opens through its intro ([constant Openings.ROWS]); an unknown key is none. Like the
## holds, it takes effect on the next reading or render.
func set_opening(key: String) -> void:
	var k := Openings.known(key)
	if k == opening:
		return
	opening = k
	_save_pacing()


## The opening the picture will show: the one set, where the medium this run uses draws one ([method
## Medium.uses] "opening"), else none; what a take records it opened with.
func opening_shown() -> String:
	return opening if Medium.uses(resolved_medium(), "opening") else Openings.DEFAULT


## The flourish knob.
func set_flourish(v: float) -> void:
	var f := clampf(v, FLOURISH_MIN, FLOURISH_MAX)
	if is_equal_approx(f, flourish):
		return
	flourish = f
	_save_pacing()


## The camera severity knob. Takes effect on the next move the medium plans, at most one shot away.
func set_camera(v: float) -> void:
	var c := clampf(v, CAMERA_MIN, CAMERA_MAX)
	if is_equal_approx(c, camera):
		return
	camera = c
	_save_pacing()


## Choose the notebook's handwriting (see [member hand]). Takes effect at once: the notebook
## re-typesets in the new hand.
func set_hand(key: String) -> void:
	var k := key if (key == "random" or NotebookLayout.HANDS.has(key)) else "kalam"
	if k == hand:
		return
	hand = k
	_save_pacing()


## Choose the medium (see [member medium]); persisted like every picture setting. Takes effect on the
## next session: swapping the presentation mid-show would mean re-hosting the live scene into another
## surface.
func set_medium(key: String) -> void:
	# a mode's own medium is pinned for its sessions, never remembered (see Medium.mode_of)
	if not Medium.REGISTRY.has(key) or not Medium.mode_of(key).is_empty() or key == medium:
		return
	medium = key
	_save_pacing()
	medium_changed.emit()
	# a medium that cannot be shown in the chosen frame falls back to landscape: the stage refits
	frame_changed.emit()


## Show the next show in [param f] ("landscape" or "portrait").
func set_frame(f: String) -> void:
	if not Medium.FRAME_SIZES.has(f) or f == frame:
		return
	frame = f
	_save_pacing()
	frame_changed.emit()


## The frame this run shows and renders in: `--frame NAME` if given, else the remembered one; landscape
## whenever the medium cannot be shown in it ([method Medium.frames]).
func resolved_frame() -> String:
	var want := frame
	var args := OS.get_cmdline_user_args()
	var i := args.find("--frame")
	if i >= 0 and i + 1 < args.size() and Medium.FRAME_SIZES.has(String(args[i + 1])):
		want = String(args[i + 1])
	return want if Medium.supports(resolved_medium(), want) else "landscape"


## Set one filter's amount, 0 being off (see [Filters.REGISTRY] for the keys). Takes effect at once on
## the running session: the post-process lives on the stage view, not inside any scene.
func set_filter(key: String, amount: float) -> void:
	if not Filters.REGISTRY.has(key):
		return
	var a := clampf(amount, 0.0, 1.0)
	var had: float = float(filters.get(key, 0.0))
	if is_equal_approx(a, had):
		return
	if a > 0.0:
		filters[key] = a
	else:
		filters.erase(key)
	_save_pacing()
	filters_changed.emit()


## The subtitles reveal their words as [param key] says ([constant Subtitles.REVEALS]); an unknown key is karaoke.
func set_subtitle_reveal(key: String) -> void:
	var k := key if Subtitles.REVEALS.has(key) else "karaoke"
	if k == subtitle_reveal:
		return
	subtitle_reveal = k
	_save_pacing()


## The tonemapper [param key] ([constant Tonemaps.REGISTRY]) with the adjustments kept for it; applies at
## once to every 3D set up now, as a filter does.
func set_tonemap(key: String) -> void:
	var k: String = Tonemaps.known(key)
	if k == tonemap:
		return
	tonemap = k
	_save_pacing()
	_push_tonemap()


## One adjustment of the tonemapper chosen now ([constant Tonemaps.ADJUSTMENTS]), kept for it alone.
func set_tonemap_adjust(name: String, value: float) -> void:
	if not Tonemaps.ADJUSTMENTS.has(name):
		return
	var a := tonemap_adjustments()
	var v := float(Tonemaps.sanitize({name: value})[name])
	if is_equal_approx(v, float(a[name])):
		return
	a[name] = v
	# back at its preset it is forgotten: a note's block names only what someone moved
	if a == Tonemaps.sanitize({}):
		tonemap_adjust.erase(tonemap)
	else:
		tonemap_adjust[tonemap] = a
	_save_pacing()
	_push_tonemap()


## [param key]'s adjustments (the chosen tonemapper's when empty), every one named: its own, else neutral.
func tonemap_adjustments(key := "") -> Dictionary:
	return Tonemaps.sanitize(tonemap_adjust.get(tonemap if key.is_empty() else key, {}))


## Every tonemapper's adjustments and the chosen [param key], as a note's block arrives ([method
## LookCard.apply]): one push for the lot.
func set_tonemap_all(key: String, adjust: Dictionary) -> void:
	tonemap_adjust = _tonemap_kept(adjust)
	tonemap = Tonemaps.known(key)
	_save_pacing()
	_push_tonemap()


## Only tonemappers that are known, each made whole.
func _tonemap_kept(adjust: Variant) -> Dictionary:
	var out := {}
	if adjust is Dictionary:
		for k in adjust:
			if Tonemaps.REGISTRY.has(String(k)):
				out[String(k)] = Tonemaps.sanitize(adjust[k])
	return out


func _push_tonemap() -> void:
	Tonemaps.choose(tonemap, tonemap_adjustments())


## How strongly [param key] is applied right now, 0 when it is off.
func filter_amount(key: String) -> float:
	return float(filters.get(key, 0.0))


## The look this run actually uses: `--filter ...` if given, else the remembered set. Read by
## [main] when it builds the stage and whenever the set changes.
func resolved_filters(turned := true) -> Dictionary:
	var over: Variant = Filters.from_args(OS.get_cmdline_user_args())
	var out: Dictionary = (over as Dictionary).duplicate() if over is Dictionary else Filters.sanitize(filters)
	# what a part of the show turns of it now ([method turn_look]: a stage's flags), live or in a render
	if turned:
		for who in _turned:
			for k in (_turned[who] as Dictionary):
				out[k] = float((_turned[who] as Dictionary)[k])
		out = Filters.sanitize(out)
	return out


## The look turned by [param who] ([method ShowFeed.turn_look]): kept until it lets go; the picture is told when it changes.
func turn_look(who: String, dials: Dictionary) -> void:
	var was: Dictionary = _turned.get(who, {})
	var same := was.size() == dials.size()
	for k in dials:
		same = same and was.has(k) and absf(float(was[k]) - float(dials[k])) < 0.002
	if same:
		return
	if dials.is_empty():
		_turned.erase(who)
	else:
		_turned[who] = dials.duplicate()
	filters_changed.emit()


func look_amount(filter: String) -> float:
	return float(Filters.sanitize(filters).get(filter, 0.0))


## Pin [param key] as the medium while [param by] is up ([member medium_override]): a mode's card that is
## its medium (the card table, the Actor), as it enters the tree. A Letter or Dispatch desk is the
## Medium card's format, so it is [member medium] itself.
func pin_medium(key: String, by: Object) -> void:
	medium_override = key
	_pinned_by = by.get_instance_id()


## Let go of the pin as [param by] leaves - only its own pin: a note reopened for a component change
## builds its new card while the old one is queued to be freed, and the old card, leaving the tree a
## frame later, must not release the new card's pin.
func unpin_medium(by: Object) -> void:
	if _pinned_by == by.get_instance_id():
		medium_override = ""
		_pinned_by = 0


## The medium this run uses: `--medium NAME` if given and known, else the remembered setting. Read by
## [main] when it builds the stage.
func resolved_medium() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--medium")
	if i >= 0 and i + 1 < args.size():
		var k := String(args[i + 1])
		if Medium.REGISTRY.has(k):
			return k
		push_warning("ghost: --medium %s is not a known medium - using %s" % [k, medium])
	if Medium.REGISTRY.has(medium_override):
		return medium_override
	return medium


func _load_pacing() -> void:
	pacing = clampf(float(Settings.read("director", "pacing", 1.0)), PACING_MIN, PACING_MAX)
	flourish = clampf(float(Settings.read("director", "flourish", 1.0)), FLOURISH_MIN, FLOURISH_MAX)
	camera = clampf(float(Settings.read("director", "camera", 1.0)), CAMERA_MIN, CAMERA_MAX)
	var h := String(Settings.read("director", "hand", "kalam"))
	hand = h if (h == "random" or NotebookLayout.HANDS.has(h)) else "kalam"
	intro_hold = clampf(float(Settings.read("director", "intro", intro_hold)), INTRO_MIN, INTRO_MAX)
	outro_hold = clampf(float(Settings.read("director", "outro", outro_hold)), OUTRO_MIN, OUTRO_MAX)
	opening = Openings.known(String(Settings.read("director", "opening", opening)))
	# `vehicle` is this key's old name; read it once so the choice survives
	var v := String(Settings.read("director", "medium", Settings.read("director", "vehicle", "full")))
	medium = v if Medium.pickable().has(v) else "full"
	var f := String(Settings.read("director", "frame", "landscape"))
	frame = f if Medium.FRAME_SIZES.has(f) else "landscape"
	# Through `sanitize`: a filter no longer in the registry would come back as a key nothing declares a
	# uniform for (a silent no-op), so it is discarded.
	filters = Filters.sanitize(Settings.read("director", "filters", {}))
	var rv := String(Settings.read("director", "subtitle_reveal", "karaoke"))
	subtitle_reveal = rv if Subtitles.REVEALS.has(rv) else "karaoke"
	tonemap = Tonemaps.known(String(Settings.read("director", "tonemap", Tonemaps.DEFAULT)))
	tonemap_adjust = _tonemap_kept(Settings.read("director", "tonemap_adjust", {}))
	_push_tonemap()


## Hand the current values to [Settings], which owns the file and the flushing; writing an unchanged
## value is a no-op.
func _save_pacing() -> void:
	Settings.write("director", "pacing", pacing)
	Settings.write("director", "flourish", flourish)
	Settings.write("director", "camera", camera)
	Settings.write("director", "hand", hand)
	Settings.write("director", "intro", intro_hold)
	Settings.write("director", "outro", outro_hold)
	Settings.write("director", "opening", opening)
	Settings.write("director", "medium", medium)
	Settings.write("director", "frame", frame)
	Settings.write("director", "filters", filters)
	Settings.write("director", "subtitle_reveal", subtitle_reveal)
	Settings.write("director", "tonemap", tonemap)
	Settings.write("director", "tonemap_adjust", tonemap_adjust)


## The medium the show is in now, null for none.
func shown_medium() -> Medium:
	return _medium if _medium != null and is_instance_valid(_medium) else null


## What is at [param at] on the frame (window pixels), as what shows it says (its own `pick`: a table names its
## thing and part, a stage its actor); {} for nothing there, a click off the frame, or nothing that picks (next/editing.md).
func pick(at: Vector2) -> Dictionary:
	if not frame_rect.has_point(at) or frame_rect.size.x <= 0.0:
		return {}
	# what the medium shows first (a table names its things), then the scene
	for who: Node in [_medium, _current]:
		if who == null or not is_instance_valid(who) or not who.has_method("pick") or not who.is_inside_tree():
			continue
		var hit: Dictionary = who.call("pick", (at - frame_rect.position) / frame_rect.size * who.get_viewport().get_visible_rect().size)
		if not hit.is_empty():
			return hit
	return {}


func attach(host: Node, medium: Medium = null) -> void:
	_host = host
	_medium = medium
	if medium != null:
		medium.feed = self             # what it reads of the show ([ShowFeed]) is handed to it
	# A fresh session hears fresh material: forget the last song's level, its reference and any flurry
	# state (attach() runs again on every take a reading restarts).
	_audio_ema = 0.0
	_ref_acc = 0.0
	_ref_w = 0.0
	_audio_ref = 0.0
	_burst_left = 0
	_burst_cd = 0
	_sting_left = 0
	_flurry_cd = 0
	if not is_equal_approx(pacing, 1.0):
		# says at once whether the session runs with a non-default hold multiplier
		print("ghost: scene pacing x%.2f (holds stretched from the remembered slider)" % pacing)
	_session_seed = _resolve_seed()
	print("ghost: session seed %d (%s)" % [_session_seed, _seed_source()])
	_rng.seed = _session_seed ^ 0x1234567
	# A start/end fade sampled per song into [3, 10] s from a hash of the seed (not a draw off _rng, which
	# would perturb the deterministic scene sequence).
	_bookend_time = 3.0 + 7.0 * (float(hash([_session_seed, "bookend"]) & 0xFFFF) / 65535.0)
	_locked = _locked_scene_arg()
	_load_storyboard_arg()
	# A storyboard's opening is authored (the-point's eye flies in over the first second), so manual
	# sessions get a short fixed bookend and the board owns its entrance.
	if is_manual():
		_bookend_time = minf(_bookend_time, 2.0)
	_echo = Echo.new()
	_heard_t = 0.0
	# After _session_seed is resolved and before the first scene is made: the medium samples its look
	# from the session seed, and the next line asks it for a host.
	if _medium != null and is_instance_valid(_medium):
		_medium.begin_session()
	# A medium that owns its cast has built the whole page; the show opens on the panel the reading
	# starts at, already alive in its own viewport.
	var opening := _handover(null)
	if opening != null:
		_current = opening
	else:
		_current = _make_scene()
		_scene_host(_current).add_child(_current)
	_arm()


## Ask a cast-owning medium for the scene to move to, and adopt what it hands back. Null means "not
## that kind of medium, or it declined this change": the caller builds a scene itself. Non-null means
## the scene is already built and parented and the outgoing one is still on the page, so there is
## nothing to add or free and no fade to play (on a comic the change of scene is the camera moving).
func _handover(outgoing: GhostScene) -> GhostScene:
	if _medium == null or not is_instance_valid(_medium) or not _medium.owns_cast():
		return null
	# The clock restarts before the medium is asked: take_over plans the incoming shot from
	# hold_remaining() ([ComicMedium] sizes its move to a share of it), which on the old clock is the
	# leftover of a hold that is over. _arm() resets it again after.
	_elapsed = 0.0
	_cue_prev = 0.0
	var sc := _medium.take_over(outgoing)
	if sc == null or not is_instance_valid(sc):
		return null
	# The hold bounds read _cur_sens, so re-derive it from the scene actually taking the stage, not from
	# whatever the last mint set.
	_cur_sens = clampf(sc.event_scale, 0.05, 20.0)
	return sc


## Where an arriving scene is added: the stage without a medium, else the surface that medium opens for
## it (a comic page's next panel). Called at the moment of arrival and nowhere else, so a medium that
## must act when the show advances (freeze the panel behind, open the next) hangs it off this one call.
func _scene_host(incoming: GhostScene) -> Node:
	if _medium != null and is_instance_valid(_medium):
		var h := _medium.host_for(incoming)
		if h != null and is_instance_valid(h):
			return h
	return _host


## The seed every scene choice, shot and param roll derives from this session: random per play unless
## pinned with `--seed N`, which the exporter passes so a render reproduces what was seen.
func session_seed() -> int:
	return _session_seed


# The show's time is the session clock ([ShowFeed]): what the parts this mounts are handed.

func show_time() -> float:
	return Spectrum.current.time


func show_length() -> float:
	return Spectrum.song_length()


func lead() -> float:
	return Spectrum.lead_in if Spectrum.bookend_baked else intro_hold


func tail() -> float:
	return Spectrum.tail if Spectrum.bookend_baked else outro_hold


func signature() -> PackedFloat32Array:
	return Spectrum.harmonic_signature()


func wait_for(who: String, on: bool) -> void:
	Spectrum.set_waiting(who, on)


func paused() -> bool:
	return Spectrum.paused


func ready_ahead(who: String, seconds: float) -> void:
	Spectrum.set_ready(who, seconds)


# The session seed, by priority:
#   1. an explicit --seed N (the exporter passes it; also the way to roll another show for the same
#      song), taken verbatim, so the export reproduces session_seed() (the salt is already in it);
#   2. the audio's fingerprint (Spectrum.song_hash) mixed with SEED_SALT: the same song and salt
#      always yield the same show;
#   3. random, only when no audio is loaded (idle preview).
func _resolve_seed() -> int:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed" and i + 1 < args.size() and args[i + 1].is_valid_int():
			return int(args[i + 1])
	if Spectrum.song_hash != 0:
		return _salt_seed(Spectrum.song_hash)
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r.randi()


# Mix the audio fingerprint with SEED_SALT into the session seed. A string hash, so a change in either
# input disperses across the whole seed.
func _salt_seed(fingerprint: int) -> int:
	return hash("%d:%d" % [fingerprint, SEED_SALT])


# Where the session seed came from, for the log line.
func _seed_source() -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--seed":
			return "--seed override"
	if Spectrum.song_hash != 0:
		return "audio fingerprint + salt %d" % SEED_SALT
	return "random (no audio)"


## Tear down the current session: free the live scene(s) and reset state, so a later attach() starts
## cleanly. Called when a session ends (main._end_session) and as a new one starts. Does not clear a
## storyboard loaded for the next session (load it after).
func detach() -> void:
	if not _turned.is_empty():
		_turned = {}
		filters_changed.emit()
	# A cast-owning medium's scenes belong to its page: still parented in their own panels, and its
	# release() lets them go. Freeing them here would leave the medium holding freed nodes.
	var borrowed := _medium != null and is_instance_valid(_medium) and _medium.owns_cast()
	if _transitioning and is_instance_valid(_next) and not borrowed:
		_next.queue_free()
	if is_instance_valid(_current) and not borrowed:
		_current.queue_free()
	_current = null
	_next = null
	_host = null
	# The medium is owned by main (mounted on main's stage, outliving a reading's restarts); detach drops the reference and tells it to release what it held for this session.
	if _medium != null and is_instance_valid(_medium):
		_medium.release()
	_medium = null
	_transitioning = false
	_trans_t = 0.0
	_index = -1
	_swaps = 0
	_step = 0
	_elapsed = 0.0
	_cue_prev = 0.0
	_held = false
	_kind_last = {}
	_storyboard_seq = []
	_storyboard_tail = []
	_storyboard_name = ""
	_storyboard_source = ""
	_echo = null
	_sched_starts = []
	_sched_end = 0.0
	_manual_i = -1
	_entry_i = -1
	_heard_t = 0.0
	_cursor_t = 0.0


## True when the Director is walking an authored storyboard (manual mode).
func is_manual() -> bool:
	return not _storyboard_seq.is_empty()


## Name of the active storyboard, or "" in auto mode.
func storyboard_name() -> String:
	return _storyboard_name


## The loadable name/path the active storyboard was loaded from (may differ from its display name).
## The exporter passes this to the render process so it re-loads the same storyboard.
func storyboard_source() -> String:
	return _storyboard_source


## Load a storyboard file by its path (`.yaml` or `.json`), switching the Director into manual mode.
## Returns true on success. Safe before attach(), where it is the board the session starts on
## (`--storyboard`, a render's). Parsing, defs expansion and validation
## live in [Storyboard]; the Director keeps the walk state.
func load_storyboard(name_or_path: String) -> bool:
	return load_board(Storyboard.load_file(name_or_path), name_or_path)


## Walk [param sb], a storyboard in its loaded form ([method Storyboard.from_data]). [param source] is
## the name or path a render can load it from again, "" for one in no file ([method storyboard_data]
## is what a render is handed then). Before attach() it is the board the session starts on; while a
## show is up the walk continues from the entry it had reached: an edit lands at the next cut, or at
## once through [method goto_entry].
func load_board(sb: Dictionary, source := "") -> bool:
	if not bool(sb.get("ok", false)):
		push_warning("ghost: %s" % String(sb.get("error", "that is not a storyboard")))
		return false
	var live := _host != null and is_manual()
	_storyboard_seq = sb.sequence
	_storyboard_tail = sb.tail
	_storyboard_loop = sb.loop
	_storyboard_name = sb.name
	_storyboard_source = source                 # how it was loaded, so the export can re-load it
	_storyboard_transition = sb.transition      # e.g. "cut" forces jump cuts
	_storyboard_sensitivity = sb.sensitivity    # narrative tempo (<0 = use the export)
	_step = mini(_step, _storyboard_seq.size() + _storyboard_tail.size()) if live else 0
	_sched_starts = _schedule_starts()
	if _host != null:
		# the map of what the song sounds like was filed under the old schedule
		_echo = Echo.new()
		_heard_t = 0.0
	print("ghost: storyboard '%s' loaded (%d scenes, loop=%s)" % [
		_storyboard_name, _storyboard_seq.size(), _storyboard_loop])
	return true


## Stop walking a storyboard: from the next cut the show is the seed's again (what a note does when
## its storyboard has nothing written in it).
func clear_storyboard() -> void:
	_storyboard_seq = []
	_storyboard_tail = []
	_storyboard_name = ""
	_storyboard_source = ""
	_storyboard_loop = true
	_storyboard_transition = ""
	_storyboard_sensitivity = -1.0
	_sched_starts = []
	_sched_end = 0.0
	_manual_i = -1
	_entry_i = -1
	_step = 0


## The storyboard being walked, as raw data a render can load ([method Storyboard.to_yaml]): the loaded
## form's own keys, every `use` expanded. {} in the seeded show.
func storyboard_data() -> Dictionary:
	if not is_manual():
		return {}
	return Storyboard.raw_of({"name": _storyboard_name, "loop": _storyboard_loop,
		"transition": _storyboard_transition, "sensitivity": _storyboard_sensitivity,
		"sequence": _storyboard_seq, "tail": _storyboard_tail})


## The tempo an entry runs at where it names none: the storyboard's, else the Director's own.
func storyboard_sensitivity() -> float:
	return _storyboard_sensitivity if _storyboard_sensitivity > 0.0 else sensitivity


## What an entry that gives no timing at all is scheduled as, in seconds (see [method _schedule_starts]).
func unauthored_hold() -> float:
	return min_hold * pacing


## Where the walk is: `entry` (index of the entry on screen: the sequence's, then the tail's counted on
## from its end; -1 in the seeded show or before one is up), `elapsed` (seconds it has been up) and
## `tail` (whether it is a tail entry). An editor's playhead.
func cursor() -> Dictionary:
	return {"entry": _entry_i if is_manual() and _current != null else -1, "elapsed": _elapsed,
		"tail": is_manual() and _entry_i >= _storyboard_seq.size()}


## Put entry [param i] on screen now (the sequence's, then the tail's counted on from its end): an
## editor's jump, so always a cut. The walk carries on from there. With [param into] seconds the entry
## is played from its start and run on to there at once, as the Echo's rejoin does ([method
## _listen_echo]); a scene is a simulation with latched verbs, so a moment inside it is reached by
## playing up to it (at most [constant INTO_MOST] s).
func goto_entry(i: int, into := 0.0) -> void:
	if _host == null or not is_manual():
		return
	_step = clampi(i, 0, _storyboard_seq.size() + _storyboard_tail.size() - 1)
	# a page that owns its cast (a comic) changes scene by its own handover
	if _medium != null and is_instance_valid(_medium) and _medium.owns_cast():
		if not _transitioning:
			_begin_transition()
		return
	if _transitioning and is_instance_valid(_next):
		_next.queue_free()
	_next = null
	_transitioning = false
	_trans_t = 0.0
	_sting_left = 0
	_sting_t = -1.0
	_burst_left = 0
	var nxt := _make_scene()
	_scene_host(nxt).add_child(nxt)
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = nxt
	_swaps += 1
	_arm()
	var left := clampf(into, 0.0, INTO_MOST)
	if left > 1e-3:
		_elapsed = left
		while left > 1e-4:
			var dt := minf(left, SIM_STEP)
			_current.update(Spectrum.current, dt)
			_current.view.commit(dt)
			left -= dt


## The show put at [param t] seconds (a render begun there, `--from`; [Stitch]): a written storyboard's
## entry then on screen, played up to its moment ([method goto_entry]). A function of show time (a
## table, a desk) needs nothing; a seeded show's walk is rolled as it goes, so a stretch of one is its own.
func seek_show(t: float) -> void:
	if not is_manual() or _sched_starts.is_empty():
		return
	var i := 0
	for k in _sched_starts.size():
		if float(_sched_starts[k]) <= t:
			i = k
	goto_entry(i, t - float(_sched_starts[i]))


## The furthest into an entry [method goto_entry] plays at once (seconds); past it a long hold would stall a frame.
const INTO_MOST := 120.0


# Cumulative schedule start time (s) of each sequence entry, mirroring _make_scene's hold scaling
# (hold / sensitivity): the coordinate system of the [Echo] map and of re-localization. Cue-exit
# entries contribute a min-hold estimate. Also stamps `_sched_end`, where the sequence hands over to
# the tail. Authored timings are literal; only an entry with no timing carries `pacing`. Computed once
# at storyboard load and then frozen, since the recorded fingerprints are filed under these times.
# The arithmetic is [method Storyboard.schedule]'s, which the editor's ruler uses too.
func _schedule_starts() -> Array:
	var s := Storyboard.schedule(_storyboard_seq, storyboard_sensitivity(), unauthored_hold())
	_sched_end = float(s["end"])
	return s["starts"]


# `--storyboard <name|path>` selects manual mode at launch.
func _load_storyboard_arg() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--storyboard" and i + 1 < args.size():
			load_storyboard(args[i + 1])
			return


# Reset the hold clock and choose the exit cue for the scene now on screen.
# A deterministic index in [0, n) from the session _rng (seeded from the song fingerprint). It does
# not mix in the live Spectrum.seed_bias(), which samples the spectrum at the instant of the call and
# is not frame-reproducible in live playback.
func _biased(n: int) -> int:
	return absi(_rng.randi()) % maxi(1, n)


func _arm() -> void:
	_elapsed = 0.0
	_cue_prev = 0.0
	_beat_prev = Spectrum.current.beat
	if _flurry_cd > 0:
		_flurry_cd -= 1            # count down the spacing between flurries of each kind
	if _burst_cd > 0:
		_burst_cd -= 1
	if _burst_left == 0:
		_maybe_start_burst()       # rarely, kick off a rapid-fire CUT burst on this scene
	# In a burst, exits land on the beat (quick + musical); otherwise the weighted cue bag.
	_trigger = Trigger.BEAT if _burst_left > 0 else TRIGGER_BAG[_biased(TRIGGER_BAG.size())]


# How hard the music is leaning in right now, 0..1, against the material's own normal level
# (_audio_ref): the surge, not the loudness. Returns -1 when the question is meaningless: this instant
# is silent or the normal level is silence (`silence_floor`), so a dead track or no audio never
# flurries. A ratio has no genre in it, where absolute gates fire for a mastered track (~0.40) and not
# for speech (~0.09-0.14).
func _lean() -> float:
	if _audio_ema < silence_floor or _audio_ref < silence_floor:
		return -1.0
	return clampf((_audio_ema - _audio_ref) / _audio_ref, 0.0, 1.0)


# The shared flurry drive, 0..1, on the spike curve (sharp onset, quick saturation). `movement` is
# content-relative (short-term flux over the passage's own baseline); `lean` is the loudness half.
func _flurry_drive(lean: float) -> float:
	return Nonlinear.apply("spike", clampf(Spectrum.current.movement + 0.5 * lean, 0.0, 1.0), 2.5)


# A sparse, non-linear chance to start a rapid-fire CUT burst: only in the auto show, only with
# audible material, weighted up by how much that material is moving (a spike curve on movement +
# lean). Rare, with a long cooldown, and never on top of a live stinger.
func _maybe_start_burst() -> void:
	if not _storyboard_seq.is_empty() or _locked >= 0 or _burst_cd > 0 or _sting_left > 0:
		return
	var lean := _lean()
	if lean < 0.0:
		return
	if _rng.randf() < (BURST_BASE + BURST_GAIN * _flurry_drive(lean)) * flourish:
		_burst_left = _rng.randi_range(2, 3)       # short - normalizes after a couple of cuts
		# The flurry rides the same `pacing` multiplier as normal holds; scaled here, where the pair is
		# sampled, so one burst keeps consistent cut lengths.
		_burst_min = _rng.randf_range(1.0, 2.0) * pacing
		_burst_max = _rng.randf_range(3.0, 5.0) * pacing
		_burst_cd = _flurry_spacing()              # then a long stretch of normal pacing
		print("ghost: BURST x%d  (%.1f-%.1fs cuts)" % [_burst_left, _burst_min, _burst_max])


# Scenes to wait before the next flurry of the same kind. Counted in cuts, not seconds (a seconds-based
# spacing would make flurries a bigger share of the cutting the calmer the passage), and divided by
# `pacing` so a slow show keeps the same spacing in listening time. Floored at FLURRY_CD_MIN.
func _flurry_spacing() -> int:
	return maxi(FLURRY_CD_MIN, int(round(float(_rng.randi_range(14, 26)) / pacing)))


# `--scene N` (or `--scene name`) pins a single scene for authoring - no changes.
func _locked_scene_arg() -> int:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--scene" and i + 1 < args.size():
			var v := args[i + 1]
			if v.is_valid_int():
				return clampi(int(v), 0, SceneRoster.SCENES.size() - 1)
			for s in SceneRoster.SCENES.size():
				if String(SceneRoster.SCENES[s].script.resource_path).contains(v):
					return s
	return -1


# The whole-show bookend fade: the picture eases up from black over the first `_bookend_time` seconds
# of the song and down to black over the final `_bookend_time` seconds, with the same modulate.a-to-black
# the scene transitions use. Runs whenever a song is loaded (live and export). Returns 1.0 (no fade)
# only when idle. Audio is never touched.
func _bookend_fade() -> float:
	var slen := Spectrum.song_length()
	if slen <= 0.0:
		return live_fade                              # idle / no song: no bookend
	var t := Spectrum.current.time
	# Past the end is not black: a stream's length is an estimate while its playback position runs on, so
	# an overrun means the length is stale, not that the show is over.
	if t > slen + 0.5:
		return 1.0
	# The fade windows follow the bookend when there is one, so the picture arrives before the held
	# silence ends, with a settle to be looked at before the first sound ([method Openings.settle]).
	# Without a bookend they use the per-song sampled length.
	var lead := Spectrum.lead_in
	var fade_in := maxf(0.5, lead - Openings.settle(lead) if lead > 0.001 else _bookend_time)
	var fade_out := maxf(0.5, Spectrum.tail if Spectrum.tail > 0.001 else _bookend_time)
	var a_in := clampf(t / fade_in, 0.0, 1.0)           # 0 at the very start -> 1 after fade_in
	var a_out := clampf((slen - t) / fade_out, 0.0, 1.0)  # 1 -> 0 over the final fade_out seconds
	return minf(minf(a_in, a_out), live_fade)


# Fixed simulation timestep. The sim advances in chunks of this size, decoupled from the drawn frame,
# so animations integrate stably and the cut schedule is exact at any render FPS.
const SIM_STEP := 1.0 / 30.0
# Cap on sim steps per render frame (a death-spiral guard): below ~2 fps the sim stops catching up and
# accepts a small drift.
const MAX_SIM_STEPS := 15
# Per-drawn-frame cap on how much music time the animation advances, so one slow frame (a scene build,
# an FPS hitch) cannot lurch the camera. The excess is banked as debt and paid down over later frames.
# STEP_CAP must exceed a normal frame's music step; DEBT_CAP bounds how far behind a slow patch may fall.
const STEP_CAP := 0.11
const DEBT_CAP := 0.4
var _time_debt := 0.0


func _process(delta: float) -> void:
	if _current == null:
		return

	# While the feedback console is open it holds the scene: freeze it entirely (no update, no redraw)
	# so a heavy draw cannot starve the main loop and lag typing.
	if _held:
		return

	# The raw advance is that of the music clock, not the drawn-frame delta: when a heavy scene lags
	# the renderer the song keeps playing, so this grows. `_prev_time < 0` marks a fresh reference
	# (first frame, a loop or a seek).
	var raw := clampf(delta, 0.0, 0.12)
	if _prev_time >= 0.0:
		var d := Spectrum.current.time - _prev_time
		raw = d if (d >= 0.0 and d <= 2.0) else clampf(delta, 0.0, 0.1)  # d<0 loop / d>2 seek -> fallback
	_prev_time = Spectrum.current.time
	# Smooth the animation step: bank the raw advance as debt and spend at most STEP_CAP per drawn
	# frame, so a scene build or an FPS hitch eases in instead of jerking the camera.
	_time_debt = minf(_time_debt + raw, DEBT_CAP)
	var anim := minf(_time_debt, STEP_CAP)
	_time_debt -= anim

	# The schedule (hold length, transition progress) runs on the raw music advance, so a scene cuts at
	# the right music time and a heavy scene cannot overrun its hold. Only the animation is smoothed.
	_tick_schedule(raw)
	_tick_animation(anim)
	if _medium != null and is_instance_valid(_medium):
		# the capped animation step: the medium's camera is picture, not schedule
		_medium.advance(Spectrum.current, anim, _bookend_fade())


# The schedule, advanced by the real music-clock step: the hold clock, transition progress and alphas,
# the smoothed audio level, the stinger, and arming the next cut. It must track the music exactly
# (never the capped animation step) or scene durations drift long.
func _tick_schedule(dt: float) -> void:
	var bookend := _bookend_fade()                  # 1, except fading from/to black at the video's ends
	# Who applies the bookend: folded into the scene's alpha it is right for a full frame, but wrong for
	# a medium that draws more than the scene (it would fade one comic panel and leave the paper lit).
	# A medium that claims it applies the number to its own root, and the scene never sees it.
	var bf := 1.0 if (_medium != null and is_instance_valid(_medium) and _medium.owns_bookend()) else bookend
	if _transitioning:
		var dur: float = layer_time if _style == Style.LAYER else transition_time
		_trans_t += dt / maxf(0.01, dur)
		var k := clampf(_trans_t, 0.0, 1.0)
		# Alphas are sequenced so a dip never shows both scenes at once.
		var a := _transition_alphas(k)
		# Held outgoing: a comic panel already inked on the paper cannot un-draw itself, so the medium
		# pins the leaving scene at full and only the arriving one fades. The full frame holds nothing.
		if _medium != null and is_instance_valid(_medium) and _medium.hold_outgoing():
			a.x = 1.0
		_current.modulate.a = a.x * bf
		_current.view.presence = a.x
		_next.modulate.a = a.y * bf
		_next.view.presence = a.y
		if k >= 1.0:
			_finish_transition()
		return
	_elapsed += dt
	# Smoothed audio level: rises fast, falls slowly, so a gap between beats is not silence but a dead
	# track (or its silent tail) is.
	var e: float = Spectrum.current.energy
	_audio_ema = lerpf(_audio_ema, e, 1.0 - exp(-(8.0 if e > _audio_ema else 0.6) * dt))
	# ...and the slow reference it is judged against (see _audio_ref): much slower than the level, so a
	# surge stands out.
	var ra := 1.0 - exp(-dt / LEVEL_REF_TAU)
	_ref_acc = lerpf(_ref_acc, _audio_ema, ra)
	_ref_w = lerpf(_ref_w, 1.0, ra)
	_audio_ref = _ref_acc / maxf(_ref_w, 1e-4)
	_drive_stinger(dt, bf)                          # rapid-fire beat-synced modulation of THIS scene
	if _listen_echo(dt):
		_beat_prev = Spectrum.current.beat
		return                                      # re-localized: the cut is already underway
	if _should_change():
		_begin_transition()
	_beat_prev = Spectrum.current.beat


# The animation, advanced by the smoothed step in fixed sub-steps and drawn once (queue_redraw is
# idempotent per frame), so under lag intermediate renders are skipped while the scenes still tick.
func _tick_animation(anim: float) -> void:
	var remaining := anim
	var steps := 0
	while remaining > 1e-5 and steps < MAX_SIM_STEPS:
		var dt := minf(remaining, SIM_STEP)
		_current.update(Spectrum.current, dt)
		_current.view.commit(dt)
		if _transitioning and _next != null:
			_next.update(Spectrum.current, dt)
			_next.view.commit(dt)
		remaining -= dt
		steps += 1


# The rapid-fire stinger: on a strong beat, sparsely start a short run of beat-synced punches; each
# zooms, rolls, skews and brightens the current scene, decaying before the next. Rides the view pulse
# and node tint, so it works on any scene.
func _drive_stinger(delta: float, bf: float) -> void:
	var f := Spectrum.current
	var beat_edge: bool = f.beat > 0.55 and _beat_prev <= 0.55
	if beat_edge:
		if _sting_left > 0:                          # land the next punch on this beat
			_sting_left -= 1
			_sting_t = 0.0
			# The punch is as long as the music is slow (a fixed decay is a different gesture at 60 and at
			# 160 BPM), bounded either side against a mis-estimated period.
			_sting_span = clampf(f.beat_period * 0.55, 0.28, 0.7)
			# Inward and outward are not symmetric: a push-in crops, while a pull-back walks the edge of the
			# painted region into shot. Layer-composed scenes are painted to a fixed 1.15x overdraw margin
			# (GhostScene.update_layers) sized for the drift's +-0.08, so outward kicks are bounded by what
			# the margin covers; inward ones keep the full range.
			_sting_zoom = _rng.randf_range(STING_PUSH.x, STING_PUSH.y)
			if _rng.randf() < 0.5:
				_sting_zoom = -_rng.randf_range(STING_PULL.x, STING_PULL.y)
			_sting_rot = _rng.randf_range(-0.055, 0.055)
			_sting_skew = _rng.randf_range(-0.04, 0.04)
			_sting_flash = _rng.randf_range(0.15, 0.35)
		elif _flurry_cd == 0 and _burst_left == 0:   # else maybe begin a run (rare, harmonic-gated)
			# Same content-relative gate as the burst (see _lean).
			var lean := _lean()
			if lean >= 0.0 and _rng.randf() < (0.02 + 0.07 * _flurry_drive(lean)) * flourish:
				# BANG, BANG (, BANG), or half of one over a reading.
				_sting_left = _rng.randi_range(1, 2) if _reading() else _rng.randi_range(2, 4)
				_flurry_cd = _flurry_spacing()
				print("ghost: STINGER x%d" % _sting_left)
	if _sting_t >= 0.0:
		_sting_t += delta
		if _sting_t >= _sting_span:
			_sting_t = -1.0                          # settled; back to the scene's own framing
	var p := _sting_env()
	# The camera half rides the scene's declared character; the flash does not. `drift_view` scales every
	# camera move by `behavior.view` (0 for a static scene, 0.3 for a fluid one), so the punch does too,
	# with a floor so the accent is present everywhere. The brightness flash stays universal: it is what
	# a static scene gets instead.
	var g: float = 0.35 + 0.65 * float(_current.behavior.get("view", 1.0))
	# ...and a reading is softer (see STING_READING).
	if _reading():
		g *= STING_READING
	# A field scene is not rolled or sheared: shot selection denies fields `canted` and `pan` so their
	# edges never swing into view (Shots.FIELD_BAG). Zoom survives, as push_in and pull_back are in that bag.
	var swing := 0.0 if _current.framing == "field" else 1.0
	_current.view.pulse_zoom = 1.0 + _sting_zoom * p * g
	_current.view.pulse_rot = _sting_rot * p * g * swing
	_current.view.pulse_skew = _sting_skew * p * g * swing
	# Brightness/tint flash via the node modulate, preserving the fade alpha. Softened over a reading by
	# less than the camera: a change of light is what a static scene gets instead of a camera move.
	var fl := 1.0 + _sting_flash * p * (0.65 if _reading() else 1.0)
	_current.modulate = Color(fl * (1.0 + 0.06 * _sting_rot), fl, fl * (1.0 - 0.06 * _sting_rot), bf)


## Is this session a reading rather than a song? `Spectrum.is_streaming()` is true when the audio is a
## take being synthesized into a stream (the Generative panel reading a chapter, or the synth editor)
## and false for a song loaded from a file: the one signal that separates "the picture is the content"
## from "the picture is the background".
func _reading() -> bool:
	return Spectrum.is_streaming()


# The punch envelope, 0 -> 1 -> 0 across `_sting_span`. A step on the beat edge (`pulse_zoom` 1.00 ->
# 1.20 between two frames) reads as the picture tearing, so the attack eases.
#
# tests/show/sting_shape_check.gd measures it: the largest change in drawn zoom between consecutive
# frames at the largest kick (0.20) stays under 5%/frame, three times the eased camera's 1.6%/frame
# (SceneView.smoothing = 5). That needs a rise of at least ~0.11 s, hence a floor on the span and a
# rise of 40% of it. The fall is squared, a soft tail.
const STING_ATTACK := 0.40


func _sting_env() -> float:
	if _sting_t < 0.0:
		return 0.0
	var k := _sting_t / maxf(0.01, _sting_span)
	if k >= 1.0:
		return 0.0
	if k < STING_ATTACK:
		return smoothstep(0.0, 1.0, k / STING_ATTACK)
	var d := (k - STING_ATTACK) / (1.0 - STING_ATTACK)
	return (1.0 - d) * (1.0 - d)


# The content clock (manual mode): feed the [Echo] map at the frontier, listen for a re-localization,
# and act on one by re-seating the cursor and cutting through the normal transition machinery (a
# stage->stage morph still carries live actors). Returns true when a correction fired this frame. The
# playhead is never consulted: a looped, doubled or trimmed song re-converges because the audio
# matches the map.
func _listen_echo(dt: float) -> bool:
	# Content-anchoring belongs to boards that follow the song (loop: false); a `loop: true` board
	# cycles by its own clock and re-localizing it would fight the author every wrap.
	if _echo == null or _storyboard_seq.is_empty() or _storyboard_loop \
			or Spectrum.song_length() <= 0.0:
		return false
	_heard_t += dt
	_cursor_t += dt
	# The roll: the map records at most one full song, so a cursor past it with the sequence finished
	# has heard everything. A looping session's next content is the top, so the arc rolls over now,
	# aligned, with no recognition latency. Echo's vote matcher below remains the backstop for trimmed,
	# doubled or cut-up audio and drift.
	if _cursor_t >= Spectrum.song_length() and _step >= _storyboard_seq.size():
		print("ghost: echo - the song's map is exhausted, rolling the arc to the top")
		_step = 0
		_begin_transition()
		_cursor_t = 0.0
		return true
	if _audio_ema < silence_floor:
		return false                   # true silence: nothing to record, nothing to recognize
	# The fast descriptor (~0.7 s of context): recognition must notice the content moving within a
	# couple of seconds.
	var sig := Spectrum.harmonic_signature_fast()
	# Write-once: only the frontier extends the map. The tail records too (the outro must own its cells
	# or its resemblance to earlier sections yanks the show backward). The map covers one hearing: past
	# one song's schedule the cursor's claim is stale and recording would poison it.
	if _cursor_t <= Spectrum.song_length():
		_echo.record(_cursor_t, sig)
	var to := _echo.listen(_heard_t, _cursor_t, sig, dt)
	if to < 0.0:
		return false
	# A match past the sequence belongs to the tail: meaningful only if the walk is not already there.
	if to >= _sched_end - 0.5:
		if _manual_i < 0 or _storyboard_tail.is_empty():
			return false
		print("ghost: echo - audio matches schedule %.1fs, re-localizing to the tail" % to)
		_step = _storyboard_seq.size()
		_begin_transition()
		_cursor_t = to
		return true
	# Head rule: a match into the opening stretch restarts the arc from the top instead of joining
	# mid-entry (recognition costs a couple of seconds and the opening entries are short, so joining
	# there would skip them). The lateness is inside Echo's self radius (NEAR), so the localizer reads
	# the offset show as "here"; the tail absorbs the shift before the next loop.
	if to <= Echo.NEAR:
		if _manual_i == 0:
			return false
		print("ghost: echo - audio matches schedule %.1fs, restarting the arc" % to)
		_step = 0
		_begin_transition()
		_cursor_t = 0.0
		return true
	var idx := 0
	for j in _sched_starts.size():
		if float(_sched_starts[j]) <= to + 0.01:
			idx = j
	if idx == _manual_i:
		return false                   # the match resolves to the entry already on screen
	print("ghost: echo - audio matches schedule %.1fs, re-localizing to entry %d" % [to, idx + 1])
	_step = idx
	_begin_transition()
	# Join the entry mid-flight: recognition costs a few seconds, so the audio sits some way into the
	# entry. Enter at that offset (fast-forward the hold clock and the scene's keyframe clock) so the
	# schedule stays aligned with the song.
	var into := clampf(to - float(_sched_starts[idx]), 0.0, 8.0)
	var incoming: GhostScene = _next if _transitioning else _current
	if into > 0.25 and incoming != null:
		_elapsed = into
		var remaining := into
		while remaining > 1e-4:
			var dt2 := minf(remaining, SIM_STEP)
			incoming.update(Spectrum.current, dt2)
			incoming.view.commit(dt2)
			remaining -= dt2
	_cursor_t = to
	return true


func _should_change() -> bool:
	if _locked >= 0 or _held:
		return false
	# A non-looping storyboard with no tail holds its final scene forever (checked first, so the last
	# entry's `hold` cannot try to re-cut into nothing). With a `tail:`, the sequence rolls into the
	# tail entries, cycling on their own exit rules until the song ends.
	if not _storyboard_seq.is_empty() and not _storyboard_loop and _storyboard_tail.is_empty() \
			and _step >= _storyboard_seq.size():
		return false
	var ex: Dictionary = _current.exit_spec
	# A fixed hold is authored timing: honor it exactly, above the auto-mode silence and tail gates
	# (heuristics for cue-based exits). Being fixed it is identical in the live analyzer and the export
	# bake, and a tightly timed piece (the-point, 33 s against a 10 s tail window) still reaches its finale.
	if ex.has("hold"):
		return _elapsed >= float(ex["hold"])
	# Never change scenes during silence: there is nothing to cut on, and a forced transition (a max-hold
	# backstop, or a LULL trigger that silence trivially satisfies) would drop a fresh scene into dead air.
	if _audio_ema < silence_floor:
		return false
	# Tail gate: hold the final scene through the song's closing stretch so a cut into a near-empty
	# fading tail does not read as a glitch. A fixed `end_hold` window off the known song length, not
	# drive-scaled: the live analyzer and the export's baked FFT read the audio slightly differently, and
	# a drive-scaled gate would cross at different moments in each and land on different last scenes.
	var slen := Spectrum.song_length()
	if slen > 0.0 and Spectrum.current.time >= slen - end_hold:
		return false
	# During a burst the backstop shrinks to a few seconds so quick scenes never linger.
	var hi: float = _burst_max if _burst_left > 0 else _scaled_bound(ex, "max", max_hold)
	if _elapsed >= hi:                               # backstop: the cue never came
		return true
	if not _ready_to_exit(ex):
		return false
	if not _trigger_fires(ex):
		return false
	# A cue is an offer, not an order (see _cue_taken): past the minimum hold it is accepted with a
	# probability that ramps with how long the scene has run.
	var lo_h: float = _burst_min if _burst_left > 0 else _scaled_bound(ex, "min", min_hold)
	return _cue_taken(lo_h, hi)


## How long the current scene is likely to have left, in seconds from now: the median, not the
## maximum (a backstop that usually does not happen). A medium that flies a camera ([ComicMedium]
## samples a move of seven to twenty seconds) sizes its shot to it. Between `lo` and `hi` the cue
## hazard is cubic (see [method _cue_taken]), so the survival curve is exp(-CUE_TOTAL * u^3) and half
## the scenes are gone by u = cbrt(ln2 / CUE_TOTAL), about 56% through the window. Returns a
## deliberately large number when cutting is frozen (the feedback console, a probe) or nothing is
## playing: a caller then uses its own natural timing.
func hold_remaining() -> float:
	if _held or _current == null or not is_instance_valid(_current):
		return 1e9
	var ex: Dictionary = _current.exit_spec
	if ex.has("hold"):
		return maxf(0.0, float(ex["hold"]) - _elapsed)
	var hi: float = _burst_max if _burst_left > 0 else _scaled_bound(ex, "max", max_hold)
	var lo: float = _burst_min if _burst_left > 0 else _scaled_bound(ex, "min", min_hold)
	var u := pow(log(2.0) / CUE_TOTAL, 1.0 / 3.0)
	var med := lo + (hi - lo) * u
	if _elapsed < med:
		return med - _elapsed
	# Past the median the scene is still running, so the answer is not zero: `maxf(0.0, med - _elapsed)`
	# would report none for most of the second half of every scene, and [ComicMedium] would keep settling
	# the shot again. Beyond the median the remaining time is the distance to the backstop, the one
	# moment the cut is certain; it shrinks to zero as that arrives.
	return maxf(0.0, hi - _elapsed)


## Take this cue, or let it pass? A ramp, not a gate: a hard `min_hold` gate is a metronome, since on
## speech onsets arrive several times a second and the next trigger past the gate lands within a frame
## or two of it. Past the minimum an arriving cue is accepted with a probability that starts near zero
## and rises with how long the scene has run (`u`, the position through the window; hazard ~ u^2).
##
## It is a rate per second, not a chance per cue: integrating the hazard over the time since the last
## offer gives speech (constant cues) and music (sparse cues) the same distribution of scene lengths.
## CUE_TOTAL is the integrated hazard across the window, the expected number of "cut now" events if the
## scene survived to the backstop; around 4 puts the median a little past halfway and leaves a couple of
## percent reaching it. Both bounds scale with `pacing`, so the shape is the same at every setting.
const CUE_TOTAL := 4.0


func _cue_taken(lo: float, hi: float) -> bool:
	var span := maxf(0.001, hi - lo)
	var u := clampf((_elapsed - lo) / span, 0.0, 1.0)
	var hazard := 3.0 * CUE_TOTAL / span * u * u     # per second; integrates to CUE_TOTAL over span
	# Time since the last offer, floored at the moment this scene became eligible so the first cue past
	# the gate cannot claim credit for the whole hold before it.
	var dt := maxf(0.0, _elapsed - maxf(_cue_prev, lo))
	_cue_prev = _elapsed
	return _rng.randf() < 1.0 - exp(-hazard * dt)


# Scene holds scale with the music's drive: how hard it is pushing right now. A loud, fast, active
# passage shrinks both hold bounds, a calm one lets them linger. Energy is the backbone (a beat-period
# estimate barely moves for fast music and stalls when onsets are missed); a quick pulse and busy
# spectral flux push it further. Returns a multiplier from `pace_drive_scale` (full drive) up to
# `pace_calm_scale`.
func _pacing_scale() -> float:
	var f := Spectrum.current
	var fast := clampf((0.58 - f.beat_period) / 0.24, 0.0, 1.0)      # 1 when the pulse is quick
	var drive := clampf(pace_energy_gain * _audio_ema + 0.45 * fast + 3.0 * f.flux, 0.0, 1.0)
	return lerpf(pace_calm_scale, pace_drive_scale, drive)


# A hold bound: a storyboard-explicit value is literal (already sensitivity-scaled in _make_scene); the
# auto default is pace-scaled, divided by the active sensitivity, then multiplied by `pacing`. Both
# bounds get the same factors, last, which preserves the variance: _pacing_scale still swings the hold
# ~3.4x across the music's drive and max/min keeps its ratio.
func _scaled_bound(ex: Dictionary, key: String, base: float) -> float:
	return float(ex[key]) if ex.has(key) else base * _pacing_scale() * pacing / maxf(0.05, _cur_sens)


# Eligibility: a oneshot when its sequence ends, a loop after the minimum hold (a short one in a burst).
func _ready_to_exit(ex: Dictionary) -> bool:
	if _current.lifecycle == "oneshot":
		return _current.finished()
	var lo: float = _burst_min if _burst_left > 0 else _scaled_bound(ex, "min", min_hold)
	return _elapsed >= lo


# Has the exit cue arrived this frame? The storyboard's trigger if the scene carries one, else the
# randomly armed trigger (auto mode).
func _trigger_fires(ex: Dictionary) -> bool:
	var trig: int = int(ex.get("trigger", _trigger))
	var f := Spectrum.current
	match trig:
		Trigger.BEAT:
			return f.beat > 0.5 and _beat_prev <= 0.5    # rising edge of a beat
		Trigger.MOVEMENT:
			return f.movement >= movement_threshold
		Trigger.LULL:
			return f.energy <= lull_threshold
	return false


## Force the next change now (bound to N in main).
func next() -> void:
	if _host == null:           # no session yet (the notes list is up)
		return
	if not _transitioning:
		_begin_transition()


## Freeze or unfreeze scene cuts (the feedback console holds the scene while you type). Scenes keep
## animating; only the exit logic is paused.
func hold(on: bool) -> void:
	_held = on


## A typed snapshot of the scene on screen, for the feedback console: identity (name, behavior, shot,
## seed, song), its typed definition (params) and the audio frame it was reacting to. Values may
## contain Godot types (Vector2, Color); FeedbackConsole.to_jsonable flattens them before writing.
func current_descriptor() -> Dictionary:
	if _current == null:
		return {}
	var f := Spectrum.current
	var d := {
		"scene": _current.scene_name,
		"render_kind": _current.render_kind,
		"behavior": _current.behavior_name,
		"shot": _current.shot_name,
		"framing": _current.framing,
		"lifecycle": _current.lifecycle,
		"seed": _current.seed_value,
		"session_seed": _session_seed,
		"song_hash": Spectrum.song_hash,
		"params": _current.params,
		"audio": {
			"time": f.time,
			"energy": f.energy,
			"beat": f.beat,
			"bass": f.bass,
			"low_mid": f.low_mid,
			"mid": f.mid,
			"high": f.high,
			"treble": f.treble,
			"flux": f.flux,
			"movement": f.movement,
		},
	}
	# A blend in flight records which style and how far (the "incoming" scene is the one being revealed).
	if _transitioning:
		d["transition"] = {
			"active": true,
			"style": _style_name(_style),
			"progress": clampf(_trans_t, 0.0, 1.0),
			"incoming": _next.scene_name if _next != null else "",
			"transition_time": transition_time,
		}
	return d


func _style_name(s: int) -> String:
	match s:
		Style.CUT: return "cut"
		Style.DIP: return "dip"
		Style.FADE: return "fade"
		Style.LAYER: return "layer"
	return "?"


# Outgoing (x) and incoming (y) alpha for transition progress k, by style. DIP sequences them so they
# never overlap: the old scene is black by ~0.38, a beat of darkness holds, the new scene fades up
# after ~0.55. FADE is a plain crossfade; anything else a linear dissolve.
func _transition_alphas(k: float) -> Vector2:
	match _style:
		Style.DIP:
			var out_a := smoothstep(0.0, 1.0, clampf(1.0 - k / 0.38, 0.0, 1.0))
			var in_a := smoothstep(0.0, 1.0, clampf((k - 0.55) / 0.45, 0.0, 1.0))
			return Vector2(out_a, in_a)
		Style.FADE:
			return Vector2(smoothstep(0.0, 1.0, 1.0 - k), smoothstep(0.0, 1.0, k))
		Style.LAYER:
			# Async overlap: the incoming fades in to a translucent level over the still-full outgoing,
			# then the outgoing fades out while the incoming solidifies. The two are offset (bias) so
			# they compose rather than collide.
			if k < 0.45:
				return Vector2(1.0, smoothstep(0.0, 1.0, k / 0.45) * 0.65)
			var kk := (k - 0.45) / 0.55
			return Vector2(1.0 - smoothstep(0.0, 1.0, kk), lerpf(0.65, 1.0, smoothstep(0.0, 1.0, kk)))
		_:
			return Vector2(1.0 - k, k)


func _begin_transition() -> void:
	if SceneRoster.SCENES.size() < 2:
		_elapsed = 0.0
		_cue_prev = 0.0
		return
	var burst_cut := _burst_left > 0      # leaving a burst scene -> a hard jump cut, no morph/blend
	if _burst_left > 0:
		_burst_left -= 1                  # consume this quick scene
	# Cast-owning medium: the change is a handover, not a construction. Taken before the stinger reset
	# below so the punch clears off the scene being left as on any other change.
	var handed := _handover(_current)
	if handed != null:
		if _current != null and is_instance_valid(_current):
			_current.view.pulse_zoom = 1.0
			_current.view.pulse_rot = 0.0
			_current.view.pulse_skew = 0.0
			_current.modulate = Color(1.0, 1.0, 1.0, _current.modulate.a)
		_sting_left = 0
		_sting_t = -1.0
		_current = handed
		_swaps += 1
		_arm()
		return
	# Clear any rapid-fire modulation so the leaving scene does not freeze mid-contortion or tint.
	_sting_left = 0
	_sting_t = -1.0
	if _current != null:
		_current.view.pulse_zoom = 1.0
		_current.view.pulse_rot = 0.0
		_current.view.pulse_skew = 0.0
		_current.modulate = Color(1.0, 1.0, 1.0, _current.modulate.a)
	var nxt := _make_scene()

	# Content-aware morph: if the incoming can grow out of the outgoing's geometry, swap instantly and
	# let it animate the morph (one eye splitting into two). Only between compatible, non-empty types,
	# and not during a burst (a flurry wants clean jump cuts).
	if not burst_cut and _current != null and not nxt.morph_in.is_empty() and nxt.morph_in == _current.morph_out:
		print("ghost: morph %s -> %s (%s)" % [_current.scene_name, nxt.scene_name, nxt.morph_in])
		var from := _current
		_scene_host(nxt).add_child(nxt)
		_current = nxt
		_swaps += 1
		nxt.begin_morph(from)         # hand over state BEFORE the source is freed
		from.queue_free()
		_arm()
		return

	_style = _choose_style()
	if burst_cut:
		_style = Style.CUT            # a burst is a run of hard jump cuts
	# A LAYER overlap only reads well when the incoming is an atmospheric wash; otherwise fall back to a dip.
	if _style == Style.LAYER and not SceneRoster.ATMOSPHERIC.has(nxt.get_script().resource_path):
		_style = Style.DIP
	if _style == Style.CUT:
		_scene_host(nxt).add_child(nxt)   # instant swap, no blend
		_current.queue_free()
		_current = nxt
		_swaps += 1
		_arm()
		return

	# Layer overlap: pan and zoom only the incoming scene into an off-center region so it composes beside
	# the outgoing one. The outgoing scene stays where it is (it just fades); the incoming eases from
	# neutral into this bias and then holds it.
	if _style == Style.LAYER:
		var ang := _rng.randf_range(0.0, TAU)
		nxt.view.bias_offset = Vector2(cos(ang), sin(ang)) * _rng.randf_range(0.16, 0.30)
		nxt.view.bias_zoom = _rng.randf_range(0.80, 1.05)
		print("ghost: layer %s under %s" % [nxt.scene_name, _current.scene_name])

	# Start the incoming scene fully transparent before it is ever drawn, or it flashes at full alpha for
	# the frame between being added and the first alpha update.
	nxt.modulate.a = 0.0
	nxt.view.presence = 0.0
	nxt.view.reveal = 0.0             # arm the geometry ratchet: it grows in with the fade-up
	_next = nxt
	_scene_host(_next).add_child(_next)   # added last -> drawn over _current
	_transitioning = true
	_trans_t = 0.0


# The transition style for leaving the current scene: its storyboard-set style (cut/dip/fade), or the
# weighted bag (mostly dip) when unspecified.
func _choose_style() -> int:
	var s: int = STYLE_BAG[_biased(STYLE_BAG.size())]
	match (_current.transition_style if _current != null else ""):
		"cut": s = Style.CUT
		"dip": s = Style.DIP
		"fade": s = Style.FADE
	# The medium has the last word, only to reject: a comic page cannot play a LAYER. The draw off
	# STYLE_BAG happens either way, so the seeded stream advances identically whatever the medium does.
	if _medium != null and is_instance_valid(_medium):
		s = _medium.style_for(s)
	return s


func _finish_transition() -> void:
	_current.queue_free()
	_current = _next
	_next = null
	_transitioning = false
	_swaps += 1
	_current.modulate.a = 1.0
	_current.view.presence = 1.0
	_current.view.reveal = 1.0
	# The survivor of a LAYER holds the position it took during the overlap; its bias stays as set.
	_arm()


# Novelty-weighted scene choice. The catalog lists several entries per scene kind (the same script
# with different behaviors), and a uniform pick clusters. Each candidate is weighted by how long its
# kind has gone unshown: a soft priority queue, not a hard rotation. Driven by the seeded _rng, so a
# given song yields the same sequence.
func _pick_index() -> int:
	if _locked >= 0:
		return _locked
	return _pick(_session_seed, _pick_salt, _swaps, _index, _kind_last, _rng)


# The pick itself, as a function of what it is handed (the session's seed, the cut number, the scene
# on screen and when each kind was last shown), so the show that will play can be asked for without
# playing it ([method forecast]) and both answers come from this one body.
func _pick(session: int, salt: int, swaps: int, index: int, kind_last: Dictionary,
		fallback: RandomNumberGenerator) -> int:
	if SceneRoster.SCENES.size() <= 1:
		return 0
	# Identity-keyed weighted selection (Efraimidis-Spirakis): each candidate gets a stable per-cut
	# uniform from a hash of (session, cut#, this scene's identity) and the largest key u^(1/weight)
	# wins. A key depends only on its own scene's identity, never on the catalog's size or order, so
	# adding an animation changes only the cuts it wins. Deterministic per song (the session seed is the
	# song fingerprint); the live Spectrum.seed_bias() is not folded in, as it is not frame-reproducible.
	var best := -1
	var best_key := -1.0
	for i in SceneRoster.SCENES.size():
		var w := _novelty(i, index, kind_last, swaps)
		if w <= 0.0:
			continue
		var h := hash([session ^ (salt * 0x27D4EB2F), swaps, _scene_key(i)])
		var u := clampf(float(h & 0xFFFFFFFF) / 4294967296.0, 1e-9, 1.0)
		var key := pow(u, 1.0 / w)
		if key > best_key:
			best_key = key
			best = i
	if best >= 0:
		return best
	return (fallback.randi() if fallback != null else 0) % SceneRoster.SCENES.size()   # all suppressed: fall back


## The seeded show written down: its first [param count] entries as a storyboard's (a scene, its motion
## and the seed that rolls its look), in the order this session's seed plays them. A function of the
## seed and the cut number, so a note can take it as the first draft of its own storyboard. No hold and
## no shot: where each cut lands is the music's, and the seeded show draws its shots as it goes. Asked
## before a show is up, the seed is the loaded song's own.
func forecast(count: int) -> Array:
	var session := _session_seed if _host != null else _resolve_seed()
	var out: Array = []
	var index := -1
	var kind_last := {}
	for k in maxi(count, 0):
		# the cut number a pick is made under: the opening scene and the one after it are both picked
		# before the first cut is counted (attach() builds one, the first change the next)
		var swaps := maxi(0, k - 1)
		index = _pick(session, 0, swaps, index, kind_last, null)
		var e: Dictionary = SceneRoster.SCENES[index]
		kind_last[String(e.script.resource_path)] = swaps
		out.append({
			"scene": String(e.script.resource_path).get_file().get_basename(),
			"behavior": String(e.behavior),
			"seed": session ^ _scene_key(index) ^ (swaps * 0x85EBCA77)})
	return out


# A stable identity for a catalog entry: a hash of (scene name, behavior), independent of its position
# in SceneRoster.SCENES, so scenes can be added or reordered without changing how the existing ones
# are chosen or look.
func _scene_key(i: int) -> int:
	var e: Dictionary = SceneRoster.SCENES[i]
	return hash(String(e.script.resource_path).get_file().get_basename() + "|" + String(e.behavior))


## How many cuts back the novelty term can see. Past this a kind is simply due, no more than any other
## due kind, which is the difference between sampling the catalog and queueing it. Chosen by measuring
## the first-repeat statistic; see tests/scenes/scene_mix_check.gd.
const NOVELTY_SPAN := 5.0

## How sharply novelty rises inside that span; 1.0 is linear in cuts-since-last-seen.
const NOVELTY_EXP := 1.0


# Selection weight for one catalog entry: 0 for the entry on screen (never an immediate repeat), tiny
# for another behavior of the same scene, otherwise a mild preference for kinds not seen lately.
# Novelty is bounded (the age clamp): unbounded, a never-shown kind outweighed a recent one 6,300 to 1
# and the order became a rotation through the whole catalog (first repeat at cut 50 of 52 kinds, against
# ~9 for a random draw; tests/scenes/scene_mix_check.gd).
func _novelty_weight(i: int) -> float:
	return _novelty(i, _index, _kind_last, _swaps)


# ...as a function of the state it reads (see [method _pick]).
func _novelty(i: int, index: int, kind_last: Dictionary, swaps: int) -> float:
	if i == index:
		return 0.0
	var kind := String(SceneRoster.SCENES[i].script.resource_path)
	if index >= 0 and kind == String(SceneRoster.SCENES[index].script.resource_path):
		return 0.05
	# An unseen kind is maximally due, not infinitely due: the -1000 sentinel is harmless as the clamp
	# decides how far novelty reaches.
	var age := float(swaps - int(kind_last.get(kind, -1000)))
	return pow(clampf(age, 1.0, NOVELTY_SPAN), NOVELTY_EXP)


# Resolve the next scene to build: from the novelty scheduler (auto mode) or the next storyboard entry
# (manual mode). Returns {script, behavior, seed, shot, exit_spec}.
func _next_entry() -> Dictionary:
	if _storyboard_seq.is_empty():
		_index = _pick_index()
		_kind_last[String(SceneRoster.SCENES[_index].script.resource_path)] = _swaps
		var e: Dictionary = SceneRoster.SCENES[_index]
		# session identity (from the song fingerprint) ^ scene identity (not its array slot) ^ history
		# (swaps). Deterministic: the same song yields the same seed every run, so a scene's structure
		# reproduces exactly. The live Spectrum.seed_bias() is not folded in (not frame-reproducible).
		var seed := _session_seed ^ _scene_key(_index) ^ (_swaps * 0x85EBCA77) \
			^ (_pick_salt * 0x165667B1)
		return {"script": e.script, "behavior": e.behavior, "seed": seed,
			"shot": "", "exit_spec": {}, "transition": "", "sensitivity": sensitivity}   # "" -> auto STYLE_BAG
	# Manual: walk the sequence (wrap when looping; past the end of a non-looping board, cycle the tail
	# entries if there are any, else hold on the last entry).
	var n := _storyboard_seq.size()
	var i: int
	var item: Dictionary
	if _storyboard_loop:
		i = _step % n
		item = _storyboard_seq[i]
	elif _step < n or _storyboard_tail.is_empty():
		i = mini(_step, n - 1)
		item = _storyboard_seq[i]
	else:
		var t := (_step - n) % _storyboard_tail.size()
		i = n + t                                    # distinct index -> distinct derived seed
		item = _storyboard_tail[t]
	_manual_i = i if i < n else -1                   # -1 = a tail entry
	_entry_i = i
	if i < n and i < _sched_starts.size():
		_cursor_t = float(_sched_starts[i])          # a sequence entry claims its scheduled start;
	_step += 1                                       # the tail free-runs from wherever it began
	var nm := String(item.get("scene", ""))
	var path := "res://src/scenes/%s.gd" % nm
	var script: Resource = load(path) if ResourceLoader.exists(path) else SceneRoster.SCENES[0].script
	if not ResourceLoader.exists(path):
		push_warning("ghost: storyboard scene '%s' not found, substituting" % nm)
	# The seed is keyed to the entry's position, never to how many times it was visited: the same
	# section of the schedule rebuilds the same scene when the audio brings the show back to it (an echo
	# re-localization, a `loop: true` wrap). (i + 1) is the value of a first pass.
	var seed2: int = int(item.get("seed",
		_session_seed ^ (i * 0x9E3779B1) ^ ((i + 1) * 0x85EBCA77)))
	# Sensitivity resolves per entry: the entry's own value, else the storyboard's, else the export.
	var sb_sens: float = _storyboard_sensitivity if _storyboard_sensitivity > 0.0 else sensitivity
	var sens: float = float(item.get("sensitivity", sb_sens))
	return {"script": script, "behavior": String(item.get("behavior", "drift")),
		"seed": seed2, "shot": String(item.get("shot", "")), "exit_spec": _parse_exit(item),
		"transition": String(item.get("transition", "")), "sensitivity": sens,
		"spec": item}   # the raw entry rides along: a data-driven scene (stage) reads it in build_params


# Translate a storyboard entry's timing into an exit_spec the scene carries (see _should_change): a
# fixed `hold`, a musical `exit` trigger, or just min/max bounds.
func _parse_exit(item: Dictionary) -> Dictionary:
	if item.has("hold"):
		return {"hold": float(item["hold"])}
	if item.has("exit"):
		# An authored bound is literal; an absent one falls back to the Director's own default, which
		# carries `pacing` like every default bound (so `exit: beat` alone obeys the slider). Both bounds
		# take the same factor. Baked when the scene is built, so a pacing change reaches these entries at
		# the next cut.
		return {
			"trigger": _trigger_from_name(String(item["exit"])),
			"min": float(item["min_hold"]) if item.has("min_hold") else min_hold * pacing,
			"max": float(item["max_hold"]) if item.has("max_hold") else max_hold * pacing}
	var d := {}
	if item.has("min_hold"):
		d["min"] = float(item["min_hold"])
	if item.has("max_hold"):
		d["max"] = float(item["max_hold"])
	return d


func _trigger_from_name(s: String) -> int:
	match s.to_lower():
		"movement":
			return Trigger.MOVEMENT
		"lull":
			return Trigger.LULL
		_:
			return Trigger.BEAT


# Instantiate and seed the next scene with its behavior, shot and exit rule.
## Build one scene, the way a cut does, without putting it on screen, for a medium that owns its cast
## ([method Medium.owns_cast]). [param salt] separates mints made at the same instant (one per panel).
## It goes through the same novelty scheduler as every pick, and `_next_entry` records each pick in
## `_kind_last`, so the panels of one page vary against each other.
func mint_scene(salt := 0, quiet := false) -> GhostScene:
	_pick_salt = salt
	_quiet_mint = quiet
	var sc := _make_scene()
	_pick_salt = 0
	_quiet_mint = false
	return sc


## Suppresses the per-cut [signal scene_cut] while casting a page: the signal means "a new scene took
## the stage, re-measure it" (see main's stage governor), and casting six panels is not six of those.
var _quiet_mint := false


func _make_scene() -> GhostScene:
	var entry := _next_entry()
	var script: Resource = entry["script"]
	var scene: GhostScene = script.new()
	scene.feed = self
	var seed: int = int(entry["seed"])
	scene.spec = entry.get("spec", {})           # BEFORE init_with_seed: build_params reads it
	scene.init_with_seed(seed, String(entry["behavior"]))
	scene.scene_name = String(script.resource_path).get_file().get_basename()
	# Telemetry only: the live harmonic bucket at the cut, not folded into the scene seed (see
	# next/harmonic_seeding.md). Stamped with the song position, so a finished render's cut list can
	# answer "what was on screen at 8:23?".
	var _t := maxf(Spectrum.current.time, 0.0)
	print("ghost: cut -> %s  at %d:%05.2f  harmonic bucket %d"
		% [scene.scene_name, int(_t / 60.0), fmod(_t, 60.0), Spectrum.harmonic_bucket(12)])
	if not _quiet_mint:
		scene_cut.emit()              # the stage governor re-measures per scene
	# Narrative tempo: higher sensitivity shrinks the hold (and any explicit min/max bounds); the scene
	# paces its keyframes as fractions of the shrunken hold, so events still land. _cur_sens also feeds
	# the auto-mode pacing bounds (see _scaled_bound).
	_cur_sens = clampf(float(entry.get("sensitivity", 1.0)), 0.05, 20.0)
	var ex: Dictionary = entry["exit_spec"]
	for k in ["hold", "min", "max"]:
		if ex.has(k):
			ex[k] = float(ex[k]) / _cur_sens
	scene.exit_spec = ex
	scene.event_scale = _cur_sens
	# Transition style, by override hierarchy (highest first): storyboard entry, the scene's own choice
	# (set in build_params), the storyboard's default, then the mode default (manual = cut, auto = ""
	# -> the weighted STYLE_BAG). A compatible morph still wins at change time.
	var entry_tr := String(entry.get("transition", ""))
	if not entry_tr.is_empty():
		scene.transition_style = entry_tr
	elif not scene.transition_style.is_empty():
		pass                                       # keep the scene's own override
	elif not _storyboard_transition.is_empty():
		scene.transition_style = _storyboard_transition
	elif not _storyboard_seq.is_empty():
		scene.transition_style = "cut"             # manual default: jump cuts
	# Camera framing: an explicit storyboard shot if valid, else by the scene's framing class
	# (expressive for subjects, gentle for fields, square for lone planes).
	var shot_name := String(entry.get("shot", ""))
	if shot_name == "" or not Shots.REGISTRY.has(shot_name):
		var bag: Array = Shots.SUBJECT_BAG
		if scene.framing == "field":
			bag = Shots.FIELD_BAG
		elif scene.framing == "plane":
			bag = Shots.PLANE_BAG
		if _storyboard_seq.is_empty():
			shot_name = bag[_rng.randi() % bag.size()]
		else:
			# Manual mode: the pick derives from the entry's own seed, not the session rng stream, so a
			# revisit (echo re-localization, loop wrap) rebuilds the same framing.
			shot_name = bag[absi(hash([seed, "shot"])) % bag.size()]
	scene.shot_name = shot_name
	scene.set_shot(Shots.make(shot_name, seed ^ 0x51ED2701))
	# Pre-warm stateful motion (growth envelopes, scroll phase, tumbling angles) and ease the camera to
	# its shot framing, so the first shown frame is settled.
	for w in 12:
		scene.update(Spectrum.current, 0.05)
		scene.view.commit(0.05)
	scene.view.snap()        # finish the ease EXACTLY, so the first shown frame doesn't slide into place
	# NB: this build burns real wall time (pre-warm + the first heavy draw) while the music clock keeps
	# advancing; the STEP_CAP / debt smoothing in _process absorbs the step, so no clock reset is needed.
	return scene


func _exit_tree() -> void:
	# Free live scenes so they don't report as leaked when the app quits.
	if is_instance_valid(_current):
		_current.queue_free()
	if is_instance_valid(_next):
		_next.queue_free()


