extends CanvasLayer
class_name Subtitles

## Subtitles - the karaoke overlay, session-owned rather than editor-owned.
##
## Draws the current sentence at the bottom in the source spelling (caps, quotes and punctuation intact;
## the phoneme normalization never reaches the reader), wrapping onto up to three lines before it shrinks
## the font. Emphasis is drawn as emphasis: markdown's `*italic*` and `**bold**` reach here as a level on
## the word (see TextNorm's emphasis sentinels) and the overlay synthesizes a slanted or emboldened face.
##
## The tracker is a narrator's eye, not a metronome: an eased cursor that chases the true playback
## position with momentum, and comes to rest at pauses (the target holds at a word boundary). The base hue
## rides the live harmonic signature, and the color moves on a sea ([SubtitleSea]): the eye is a source
## whose harmonics raise waves that run back through the words already said, in live playback and baked
## exports alike.
##
## Timing comes from a sidecar JSON written next to a voice take by [SynthEditor] (`take_N.wav` +
## `take_N.json`), so the same overlay works in the live synthesis session, a plain `--audio` boot and the
## export render, where no editor exists.

## The line only exists while there is something to read. [constant LEAD] is how long before its first word
## a line may appear, and [constant HANG] how long after its last it stays. Both are longer than an
## ordinary gap between sentences, so at a normal seam the next line's window opens before the previous
## one's closes and the overlay never blinks; it leaves only when the speaking stops. A pause inside a
## sentence never brings it off (see [method span_at], the single rule both the plate's ease and the drawn
## text obey).
const LEAD := 0.8
const HANG := 0.7
## Seconds to ease in and out over (a line that snapped on would be the only hard cut in the frame).
const FADE := 0.3

## How a line's words are revealed, the Director's choice ([member Director.subtitle_reveal]): a key and
## the words the Look card shows for it.
const REVEALS := {
	"karaoke": "the whole line shown, each word lit as it is spoken",
	"glitch": "the words appear as they are spoken, a few scrambled glyphs running just ahead of the voice - reaching on, falling back, reaching again",
}
## The glitch ([constant REVEALS] `glitch`, after the vortex chat's GlitchedLabel): the line is written as
## it is spoken, in one steady sweep ([method glitch_front]) that has every word written within
## GLITCH_SETTLE seconds of its start (from GLITCH_EARLY before it), so the word being said is never the
## scrambled one, and that goes on through a pause. Each row is centered on what is written of it and the
## noise's mean reach ([constant GLITCH_CENTERED]). Past the sweep a few letters' places show noise
## ([method glitch_reach]: it reaches on a letter at a time, falls back and reaches again, as a guess
## retracted); beyond that, nothing yet. The noise is a glyph from the sets below, each letter holding its
## own for GLITCH_HOLD (the simple set nearest the front), now and then with a faint ghost beside it. A pure
## function of show time and the line: a render and a scrub see the same noise.
const GLITCH_SETTLE := 0.28
const GLITCH_EARLY := 0.06
## How long a letter of noise holds a glyph (seconds, its own length in this range), and how often a hold's
## end changes it.
const GLITCH_HOLD := Vector2(0.045, 0.11)
const GLITCH_CHANGE := 0.7
## How often the noise's reach moves (steps a second), the most letters it reaches past the front and the
## fewest a guess reaches, and the steps in one run of guesses ([method glitch_reach]).
const GLITCH_STEPS := 12.0
const GLITCH_AHEAD := 10
const GLITCH_LEAST := 4
const GLITCH_RUN := 48
## A row is centered on what is written and this many letters more: the noise's mean reach past the sweep
## (3.1 letters from the front over 400 lines, which stands half a letter behind the sweep). Centering on
## what is written alone hangs the noise off the row's right end and the line sits right of center. A
## constant, so the words hold still while the noise reaches on and backs off.
const GLITCH_CENTERED := 2.6
const GLITCH_SIMPLE := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!?#$%^&*<>-_/\\[]{}|="
const GLITCH_COMPLEX := "┌┐└┘├┤┬┴┼━┃┏┓┗┛┣┫┳┻╋※×○◎●△▲▽▼☉♠♡♢♣♤♥♦♧"


## When letter [param ch] of [param n] in a word spoken from [param t0] to [param t1] settles into itself
## ([constant GLITCH_SETTLE]): never after the word has begun by more than the settle.
static func settle_at(t0: float, t1: float, ch: int, n: int) -> float:
	var span := clampf(t1 - t0, 0.05, GLITCH_SETTLE)
	return t0 - GLITCH_EARLY + span * float(ch) / float(maxi(n, 1))


## Where the glitch's front is at [param t] (letters into the line, a fraction into the next), for the
## line's words [param spans] ([[first letter, letters, t0, t1], ...] in order): one steady sweep through
## the line, pauses and all, never behind the voice. Each word must be written by the time it settles
## ([method settle_at]); the sweep is the least curve over all of those that starts at the line's first
## letter and never speeds up (their upper hull), so it runs straight through a pause rather than waiting
## at a comma.
static func glitch_front(spans: Array, t: float) -> float:
	if spans.is_empty():
		return 0.0
	var first: Array = spans[0]
	var pts: Array = [Vector2(float(first[2]) - GLITCH_EARLY, float(first[0]))]
	for sp in spans:
		var w: Array = sp
		var n := int(w[1])
		var at := maxf(settle_at(float(w[2]), float(w[3]), n, n), pts[pts.size() - 1].x + 1e-3)
		pts.append(Vector2(at, maxf(float(int(w[0]) + n), pts[pts.size() - 1].y)))
	var hull: Array = []
	for p in pts:
		while hull.size() >= 2:
			var o: Vector2 = hull[hull.size() - 2]
			var a: Vector2 = hull[hull.size() - 1]
			if (a.x - o.x) * (p.y - o.y) - (a.y - o.y) * (p.x - o.x) >= 0.0:
				hull.pop_back()
			else:
				break
		hull.append(p)
	if t <= hull[0].x:
		return hull[0].y
	for i in range(1, hull.size()):
		var b: Vector2 = hull[i]
		if t <= b.x:
			var a: Vector2 = hull[i - 1]
			return lerpf(a.y, b.y, (t - a.x) / maxf(b.x - a.x, 1e-6))
	return hull[hull.size() - 1].y


## How many letters past the front the noise reaches at [param t] in line [param line]: in each run of
## [constant GLITCH_RUN] steps ([constant GLITCH_STEPS] a second) it reaches on a letter a step to a first
## guess ([constant GLITCH_LEAST] to [constant GLITCH_AHEAD]), holds it, backs off a letter a step part of
## the way, reaches again to a second, holds, and backs off to one, resting there until the run ends. Every
## run starts and ends at one, so it never jumps.
static func glitch_reach(line: int, t: float) -> int:
	var step := floori(t * GLITCH_STEPS)
	var run := floori(float(step) / float(GLITCH_RUN))
	var at := step - run * GLITCH_RUN
	var h := hash([line, run, "reach"])
	var p1 := GLITCH_LEAST + h % (GLITCH_AHEAD - GLITCH_LEAST + 1)
	var p2 := GLITCH_LEAST + (h >> 4) % (GLITCH_AHEAD - GLITCH_LEAST + 1)
	var mid := 1 + (h >> 8) % maxi(p1 / 2, 1)
	var holds := [1 + (h >> 12) % 3, 1 + (h >> 14) % 3]
	# the run as legs: [from, to, steps]
	var legs := [[1, p1, p1 - 1], [p1, p1, holds[0]], [p1, mid, p1 - mid], [mid, p2, p2 - mid], [p2, p2, holds[1]],
		[p2, 1, p2 - 1]]
	for leg in legs:
		var n := int(leg[2])
		if at < n:
			return int(leg[0]) + signi(int(leg[1]) - int(leg[0])) * (at + 1)
		at -= n
	return 1


## The glyph letter [param ch] of word [param wi] shows at [param t], [param ahead] letters past the front:
## a glyph of [param simple] (always, at the front itself) or [param complex]. Each letter keeps its own
## time: it holds a glyph [constant GLITCH_HOLD] seconds, and at the end of a hold changes only
## GLITCH_CHANGE of the time (every letter turning over together reads as a boil). [param pick] chooses
## again from the same moment (the overlay's way past a glyph too wide for its place).
static func glitch_glyph(wi: int, ch: int, t: float, ahead: int, simple: String, complex: String, pick := 0) -> String:
	var own := hash([wi, ch, "hold"])
	var hold := lerpf(GLITCH_HOLD.x, GLITCH_HOLD.y, float(own % 1000) / 999.0)
	var tick := floori(t / hold + float((own >> 10) % 1000) / 999.0)
	# the last tick it changed on
	for back in 8:
		if hash([wi, ch, tick, "turn"]) % 100 < int(GLITCH_CHANGE * 100.0):
			break
		tick -= 1
	var h := hash([wi, ch, tick, pick])
	var pool := simple if (ahead <= 0 or complex.is_empty() or h % 3 != 0) else complex
	return pool[(h >> 4) % pool.length()]

var words: Array = []               # [{text, t0, t1, sentence}] - may still be GROWING
                                    # (a live VoiceStream shares its array by reference)
## Every sound of the reading with its time, `[{p, t0, t1}]`, beside [member words] and shared the same
## way: what a medium whose mouth says them reads ([LikenessMedium]). Empty for a take whose voice hands
## back none.
var phones: Array = []
var loop_length := 0.0              # >0 once a streamed take loops: wrap time by this
var time_base := 0.0                # playback time when the current content started
## 0..1, eased. Multiplies every alpha the overlay draws, plate included.
var presence := 0.0
## The manuscript this reading came from, when there is one: `{source}`, the chapter's markdown. Carried
## beside the words so a medium that typesets the text ([BookMedium]) gets it live and in the export
## render alike (it rides the sidecar).
var document: Dictionary = {}
## True when a medium shows the words itself: the clock and the eased cursor keep running, because that
## medium reads them, and only the drawing stops.
var overlay_hidden := false
## A medium that shows some of the words itself says which lines are captioned (the letter: none it has
## written where they can be read, [LetterMedium]): handed a line's first and last word (indices of
## [member words]) and the time, it answers whether the line is drawn; the line eases out and in as any
## does. Unset, every line is.
var captions: Callable = Callable()
## Where the frame is in the window (main sets it as the stage fits): the subtitles lay out in the show's
## frame, not the window; an empty rect means the whole viewport (an export). A portrait frame keeps its
## safe area clear ([constant SAFE]).
var frame_rect := Rect2()
## The safe area of a portrait frame, as shares of it: what every platform draws its buttons and captions
## over (Google's safe zones for 1080x1920 keep the top 288, the bottom 672 and the right 192 pixels
## clear; the left keeps a small margin of its own).
const SAFE := {"top": 0.15, "bottom": 0.35, "right": 0.178, "left": 0.044}


## Where a line of subtitles goes in [param frame]: `{k, max_w, cx, base_y}`: the type's scale (off the
## frame's short side, as the scenes size themselves), the widest a line may run, the middle it is centered
## on, and the last line's baseline. A landscape frame keeps 92% of its width and 70 px up at 1080; a
## portrait one lays out inside its SAFE area.
static func text_area(frame: Rect2) -> Dictionary:
	var vp := frame.size
	var k := minf(vp.x, vp.y) / 1080.0
	if vp.y <= vp.x:
		return {"k": k, "max_w": vp.x * 0.92, "cx": frame.position.x + vp.x * 0.5,
			"base_y": frame.position.y + vp.y - 70.0 * k, "area": frame}
	var area := Rect2(frame.position.x + vp.x * float(SAFE["left"]), frame.position.y + vp.y * float(SAFE["top"]),
		vp.x * (1.0 - float(SAFE["left"]) - float(SAFE["right"])), vp.y * (1.0 - float(SAFE["top"]) - float(SAFE["bottom"])))
	return {"k": k, "max_w": area.size.x, "cx": area.position.x + area.size.x * 0.5, "base_y": area.end.y, "area": area}
var _cursor := 0.0                  # the narrator's eye: global word progress, eased
var _hue_sm := 0.6
## The water the line's color moves on: the eye raises its waves ([method _process]), the draw reads them.
var sea := SubtitleSea.new()
var _letters := PackedInt32Array()  # word k's first letter through the whole reading (a gap is one)
var _letters_of: Array = []         # ...in this words array
var _overlay: Control
var _order := {}                    # speaker -> its place among the reading's voices
var _order_of: Array = []           # ...in this words array
var _order_n := 0                   # ...read this far

## Voice [param who]'s place among this reading's voices, by when each first speaks (see [constant
## Scheme.VOICE_BANDS]). A word that names no voice (a synthesis take, an older sidecar) is the first
## voice's. Read on as [member words] grows; a new reading starts it over.
func voice_order(who: String) -> int:
	if who.is_empty():
		return 0
	if not is_same(_order_of, words) or _order_n > words.size():
		_order_of = words
		_order = {}
		_order_n = 0
	while _order_n < words.size():
		var w := String((words[_order_n] as Dictionary).get("speaker", ""))
		if not w.is_empty() and not _order.has(w):
			_order[w] = _order.size()
		_order_n += 1
	return int(_order.get(who, 0))


## Where word [param k] begins, in letters through the whole reading with each gap one ([param k] at the
## end: one past the last gap): the places [member sea] keeps its waves in. Read on as [member words]
## grows; a new reading, or a word that is no longer the one counted, starts it over.
func letter_of(k: int) -> int:
	var n := _letters.size() - 1
	if not is_same(_letters_of, words) or n > words.size() or (n > 0
			and _letters[n] - _letters[n - 1] != String((words[n - 1] as Dictionary).text).length() + 1):
		_letters_of = words
		_letters = PackedInt32Array([0])
	while _letters.size() <= mini(k, words.size()):
		var at := _letters.size() - 1
		_letters.append(_letters[at] + String((words[at] as Dictionary).text).length() + 1)
	return _letters[clampi(k, 0, _letters.size() - 1)]


## Where the eye is, in [method letter_of]'s letters: the word it is on and how far into it.
func _eye_letter() -> float:
	var k := clampi(floori(_cursor), 0, words.size())
	if k >= words.size():
		return float(letter_of(k))
	var frac := clampf(_cursor - float(k), 0.0, 1.0)
	return float(letter_of(k)) + frac * float(String((words[k] as Dictionary).text).length())


## The sidecar path for an audio file, or "" if none exists.
static func sidecar_for(audio_path: String) -> String:
	if audio_path.is_empty():
		return ""
	var side := audio_path.get_basename() + ".json"
	return side if FileAccess.file_exists(side) else ""


## Load a sidecar written by the synth editor. Returns false on malformed data.
func load_sidecar(path: String) -> bool:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not (parsed.get("words") is Array):
		push_warning("ghost: subtitle sidecar unreadable: " + path)
		return false
	words = parsed.words
	if parsed.get("phones") is Array:
		phones = parsed.phones
	if parsed.get("book") is Dictionary:
		document = parsed.book
	return true


func _ready() -> void:
	layer = 9
	_overlay = Overlay.new()
	_overlay.owner_node = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


## The reading's own clock: seconds into the take.
func now() -> float:
	return _now()


## The narrator's eye: global word progress (word index + fraction within it), eased.
func cursor() -> float:
	return _cursor


func _now() -> float:
	var t: float = Spectrum.current.time - time_base
	if loop_length > 0.0:
		t = fmod(maxf(t, 0.0), loop_length)
	return t


## The true position as global word progress: word index + fraction within it. Between words (a pause, a
## breath) the target holds at the previous word's end, which lets the eased eye rest there.
func _target(t: float) -> float:
	var last_end := 0.0
	for k in words.size():
		var w: Dictionary = words[k]
		if t < float(w.t0):
			return float(k)          # in the gap before word k: rest at its door
		if t < float(w.t1):
			return float(k) + (t - float(w.t0)) / maxf(0.001, float(w.t1) - float(w.t0))
		last_end = float(k) + 1.0
	return last_end


## Sentence spans: `[{si, lo, hi}]` in time order, lo/hi the first word's start and the last word's end,
## so a span covers a sentence's internal pauses. Cached, as the list is walked every frame and can run to
## thousands of words; rebuilt when it changes, which is word by word while a take streams (a live
## [VoiceStream] shares this array by reference, and [ReadingPanel] clears it in place between takes).
var _spans: Array = []
var _spans_n := -1
var _spans_tail := -1.0


func _spans_now() -> Array:
	var n := words.size()
	var tail := float(words[n - 1].t1) if n > 0 else -1.0
	if n == _spans_n and is_equal_approx(tail, _spans_tail):
		return _spans
	_spans = []
	var at := {}                       # sentence id -> its position in _spans
	for k in n:
		var w: Dictionary = words[k]
		var si := int(w.sentence)
		if at.has(si):
			var e: Dictionary = _spans[int(at[si])]
			e.lo = minf(float(e.lo), float(w.t0))
			e.hi = maxf(float(e.hi), float(w.t1))
			e.w1 = k
		else:
			at[si] = _spans.size()
			_spans.append({"si": si, "lo": float(w.t0), "hi": float(w.t1), "w0": k, "w1": k})
	_spans_n = n
	_spans_tail = tail
	return _spans


## The one rule for what belongs on screen at [param t]: the position in [method _spans_now] of the
## sentence to show, or -1 for nothing. The presence ease and the draw both use it, so a pause longer
## than 1.2 s inside a sentence (a colon with a `pause_scale` over 1) cannot leave `presence` at 1.0 with
## nothing to draw. In order of preference:
##   1. t inside a span, internal pauses included;
##   2. else the next sentence, if it starts within LEAD (it takes over at a seam);
##   3. else the previous sentence, if it ended within HANG (a line lingers rather than snapping off);
##   4. else nothing: the speaking has stopped.
func span_at(t: float) -> int:
	var spans := _spans_now()
	for i in spans.size():
		var e: Dictionary = spans[i]
		if t >= float(e.lo) and t < float(e.hi):
			return i
	var nxt := -1
	var prv := -1
	for i in spans.size():
		if t < float(spans[i].lo):
			nxt = i
			break
		prv = i
	if nxt >= 0 and float(spans[nxt].lo) - t <= LEAD:
		return nxt
	if prv >= 0 and t - float(spans[prv].hi) <= HANG:
		return prv
	return -1


## Should anything be on screen at time [param t], and how strongly? 1 while a sentence is selected by
## [method span_at] and the medium captions it ([member captions]), else 0: the question the draw asks, so
## the plate and the text cannot disagree about whether there is anything to read.
func _presence_target(t: float) -> float:
	var i := span_at(t)
	if i < 0:
		return 0.0
	if captions.is_valid():
		var e: Dictionary = _spans_now()[i]
		return 1.0 if bool(captions.call(int(e.w0), int(e.w1), t)) else 0.0
	return 1.0


func _process(delta: float) -> void:
	if words.is_empty():
		presence = 0.0
		return
	var now := _now()
	presence = lerpf(presence, _presence_target(now), 1.0 - exp(-delta / maxf(0.01, FADE)))
	# Snap the tail of the ease to zero: an exponential never arrives, and a plate at alpha 0.003 is a
	# faint gray bar over a bright scene for the whole silence.
	if presence < 0.004:
		presence = 0.0
	# The cursor keeps tracking while the line is hidden: it is eased over seconds, so freezing it would
	# leave it stale and racing to catch up on screen.
	var target := _target(now)
	var gap := target - _cursor
	if absf(gap) > 3.0:
		_cursor = target             # a loop seam or a restart: snap, don't chase
	else:
	# the weave: momentum grows with how far behind the eye is
		var rate := 3.0 + 7.0 * clampf(absf(gap) - 0.15, 0.0, 1.5)
		_cursor = lerpf(_cursor, target, 1.0 - exp(-rate * delta))
	# the sea runs on through a hidden line, as the eye does, so a line shown again is not calm
	sea.hear(Spectrum.current.bands, now)
	sea.emit(now, _eye_letter())
	if overlay_hidden:
		if _overlay.visible:
			_overlay.visible = false
		return
	_overlay.queue_redraw()


class Overlay:
	extends Control
	var owner_node: Subtitles

	const BASE_FS := 30
	const MIN_FS := 20
	const MAX_LINES := 3
	## The frame height every hard-coded pixel below is expressed against.
	const REF_H := 1080.0
	# The color is the sea's ([SubtitleSea]), keyed on the letter, not the word, so a wave runs through a
	# word and on into the next. Under it the hue turns a little from letter to letter (HUE_SPAN), so calm
	# water is not one flat tint. A said letter at rest is calm, a soft tint; where the water stands high it
	# is brighter and richer, its hue turned on (HUE_SWING), and in a trough it falls a little toward gray
	# (the trough pulling less than the crest lifts). HEIGHT is the water's height that lifts a letter all
	# the way. All of it settles with distance from the eye: the sea moves a letter SETTLE letters behind
	# the eye by a third of what it moves one beside it, so the words just said ripple and older ones rest
	# at CALM. The letters just said flare over FLARE letters behind the eye, gently.
	const HUE_SPAN := 0.0015         # hue turned per letter under the waves
	const HUE_SWING := 0.02          # hue turned at a full crest (and back at a full trough)
	const HEIGHT := 1.0
	const SAT_CALM := 0.24
	const VAL_CALM := 0.78
	const SAT_CREST := 0.26
	const VAL_CREST := 0.16
	const SAT_TROUGH := 0.08
	const VAL_TROUGH := 0.07
	const SETTLE := 24.0
	const FLARE := 8.0
	const FLARE_SAT := 0.55
	const FLARE_MIX := 0.6
	# Emphasis is drawn, not spelled: `*I will never hurt you*` reaches here as a level on the word, never
	# as asterisks. Godot synthesizes both faces off the one theme font, so no second font file:
	# `variation_embolden` thickens the outline and `variation_transform` shears it.
	const EMBOLDEN := 0.6
	## The oblique shear, as FreeType's matrix takes it: x' = x + SLANT * y, y up in outline space, so a
	## positive value leans the tops to the right. 0.22 is about 12 degrees, a real italic's.
	const SLANT := 0.22
	var _faces := {}                 # level -> Font
	var _glitch_sets := {}           # Font -> [simple, complex]: the glitch glyphs it can draw

	## The face for an emphasis level: 0 plain, 1 italic, 2 bold, 3 both.
	func _face(base: Font, level: int) -> Font:
		if level <= 0 or base == null:
			return base
		if _faces.has(level):
			return _faces[level]
		var fv := FontVariation.new()
		fv.base_font = base
		if level & 2:
			fv.variation_embolden = EMBOLDEN
		if level & 1:
			fv.variation_transform = Transform2D(Vector2(1.0, SLANT), Vector2(0.0, 1.0),
				Vector2.ZERO)
		_faces[level] = fv
		return fv

	func _draw() -> void:
		if owner_node == null or owner_node.words.is_empty():
			return
	# Nothing is being read: draw nothing at all, plate included (an empty line would still draw its
	# dark plate, a black bar waiting for words).
		var vis: float = owner_node.presence
		if vis <= 0.01:
			return
		var t: float = owner_node._now()
		var line_words: Array = _current_sentence(t)
		if line_words.is_empty():
			return
		var font := get_theme_default_font()
		var frame: Rect2 = owner_node.frame_rect if owner_node.frame_rect.has_area() else get_viewport_rect()
		var box := Subtitles.text_area(frame)
		var max_w: float = box["max_w"]
		var cx: float = box["cx"]
	# Every pixel number below is relative to a 1080-tall frame: the export renders at a multiple of the
	# delivered size and ffmpeg resolves it back down (see exporter.QUALITIES), so literal pixels would
	# come out smaller in the file than in the viewer. Sizing off the frame makes the type occupy the same
	# fraction at any render resolution.
		var k: float = box["k"]
		# wrap first, shrink only as a last resort
		var fs := int(round(BASE_FS * k))
		var min_fs := int(round(MIN_FS * k))
		var lines := _wrap(line_words, font, fs, max_w)
		while lines.size() > MAX_LINES and fs > min_fs:
			fs -= maxi(1, int(round(2.0 * k)))
			lines = _wrap(line_words, font, fs, max_w)
		var lh := float(fs) + 12.0 * k
		# the harmonic hue is the BASE the sea turns each letter from (see _glyph_color)
		var base_hue := _harmonic_hue()
		var now := owner_node._now()
		var gap := 14.0 * k
	# the cursor as a character position within this sentence, so the flare is measured in glyphs
		var ccur: float = _char_cursor(line_words)
	# the sea along this line, a letter at a time: its places are the reading's, so a wave stays in the
	# words it was raised in
		var last_item: Dictionary = line_words[line_words.size() - 1]
		var sea: PackedFloat32Array = owner_node.sea.line(float(owner_node.letter_of(int(line_words[0].idx))),
			int(last_item.cstart) + String(last_item.word.text).length(), now)
		var glitch := Director.subtitle_reveal == "glitch"
		var base_y: float = box["base_y"]
		var y: float = base_y - (lines.size() - 1) * lh
	# The plate: scenes range from black voids to white-hot fields, so color alone cannot keep text
	# legible. Each line gets a rounded dark plate sized to its own width (a full-width band would
	# cover the show), and every glyph is drawn once in near-black underneath: the plate carries the
	# contrast, the shadow catches the edges over bright content.
	# The glitch's reveal: where the sweep is ([method Subtitles.glitch_front]) and how far past it the
	# noise reaches; a letter beyond that is not drawn yet. Each row is centered on what is written of it
	# so the words come out of the middle of the screen, and on the noise's mean reach past it
	# (GLITCH_CENTERED): its plate round what is drawn, noise and all
		var sweep := 0.0
		var front := 1 << 30
		var reach := 0
		if glitch:
			var spans: Array = []
			for item in line_words:
				spans.append([int(item.cstart), String(item.word.text).length(), float(item.word.get("t0", 0.0)), float(item.word.get("t1", 0.0))])
			sweep = Subtitles.glitch_front(spans, now)
			front = floori(sweep)
			reach = Subtitles.glitch_reach(int(line_words[0].idx), now)
		var starts: Array = []
		for row in lines:
			var total := -gap
			for item in row:
				total += item.w + gap
			var x0 := cx - total * 0.5
			var drawn := total
			if glitch:
				x0 = _glitch_x(row, sweep, cx, font, fs, gap)
				drawn = _written(row, float(front + reach), font, fs, gap)
			starts.append(x0)
			if drawn > 0.0:
				var pad := 12.0 * k
				var plate := Rect2(x0 - pad, y - float(fs) - 4.0 * k, drawn + pad * 2.0, lh + 2.0 * k)
				draw_rect(plate, Color(0.04, 0.04, 0.05, 0.72 * vis), true)
			y += lh
		y = base_y - (lines.size() - 1) * lh
	# the pen advances glyph by glyph so the gradient can turn within a word and a spoken glyph keeps
	# its own lingering color
		for ri in lines.size():
			var row: Array = lines[ri]
			var x: float = starts[ri]
			for item in row:
				var text: String = item.word.text
				var ci: int = int(item.cstart)   # this word's first char, sentence-local
				var face := _face(font, int(item.word.get("emph", 0)))
				var order := owner_node.voice_order(String(item.word.get("speaker", "")))
				for ch in text.length():
					var glyph := text.substr(ch, 1)
					var cw := face.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
					var pos := Vector2(x, y)
					var col := _glyph_color(base_hue, ci + ch, ccur, sea, order)
					col.a *= vis
					var ahead := ci + ch - front
					if glitch and ahead >= reach:
						# Not reached yet: nothing, in the letter's own place
						x += cw
						continue
					if glitch and glyph != " " and ahead >= 0:
	# Not said yet: a glyph of noise in the letter's own place, centered on it so the line
	# never reflows, flickering, now and then with a ghost beside it
						var sets: Array = _glitch_set(face)
	# Always the line's own size: a glyph much wider than its letter's place is chosen again,
	# never shrunk to fit (an "i" or a comma's noise would come out at half size)
						var g := Subtitles.glitch_glyph(int(item.idx), ch, now, ahead, sets[0], sets[1])
						var gs := fs
						var gw := face.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
						var room := maxf(cw * 1.35, float(fs) * 0.45)
						for again in range(1, 6):
							if gw <= room:
								break
							g = Subtitles.glitch_glyph(int(item.idx), ch, now, ahead, sets[0], sets[1], again)
							gw = face.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
						var gp := pos + Vector2((cw - gw) * 0.5, 0.0)
						var h := hash([int(item.idx), ch, floori(now * Subtitles.GLITCH_STEPS), "ghost"])
	# as bright as the words it stands for, near enough
						col = col.lightened(0.25)
						col.a *= 0.75 + 0.25 * float(h % 7) / 6.0
						draw_string(face, gp + Vector2(1.5 * k, 1.5 * k), g, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, Color(0, 0, 0, 0.85 * vis))
						draw_string(face, gp, g, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, col)
						# a ghost beside it, most often at the far end of the reach, where the guess is newest
						if h % (3 if ahead == reach - 1 else 11) == 0:
							var ghost := Subtitles.glitch_glyph(int(item.idx), ch + 97, now, ahead + 1, sets[0], sets[1])
							var gc := col
							gc.a *= 0.35
							draw_string(face, gp + Vector2(cw * (0.6 if h % 2 == 0 else -0.6), 0.0), ghost, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, gc)
						x += cw
						continue
	# the shadow, under every state: the edge that survives a bright frame bleeding past the plate
					draw_string(face, pos + Vector2(1.5 * k, 1.5 * k), glyph,
						HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85 * vis))
					draw_string(face, pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
					x += cw
				x += gap
			y += lh

	## Where row [param row] starts, the glitch's sweep at letter [param sweep]: centered on [param cx] by what is
	## written of it and [constant Subtitles.GLITCH_CENTERED] letters of noise.
	func _glitch_x(row: Array, sweep: float, cx: float, font: Font, fs: int, gap: float) -> float:
		return cx - _written(row, sweep + Subtitles.GLITCH_CENTERED, font, fs, gap) * 0.5

	## How wide row [param row] is up to letter [param upto] of its sentence (a fraction of the next letter, and
	## of the gap after a word, counted in), at size [param fs]; the glitch centers a row on it. No gap after
	## the row's last word: its next letter is on the next row, and a trailing gap stands the row off center.
	func _written(row: Array, upto: float, font: Font, fs: int, gap: float) -> float:
		var w := 0.0
		for k in row.size():
			var item: Dictionary = row[k]
			var text: String = item.word.text
			var c0 := int(item.cstart)
			if upto <= float(c0):
				break
			if upto >= float(c0 + text.length()):
				w += item.w + (gap * clampf(upto - float(c0 + text.length()), 0.0, 1.0) if k < row.size() - 1 else 0.0)
				continue
			var face := _face(font, int(item.word.get("emph", 0)))
			for ch in text.length():
				var cw := face.get_string_size(text.substr(ch, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				w += cw * clampf(upto - float(c0 + ch), 0.0, 1.0)
		return w

	## Letter [param ci]'s color (of this sentence), the eye at letter [param ccur], on [param sea] (this
	## line's [method SubtitleSea.line]) in the voice of [param order]: the hue its place and the harmonics
	## cresting there turn it to, lit by how high the water stands there, both settling with distance from
	## the eye ([constant SETTLE]); the letters just said flare. Ahead of the voice it waits dim, faintly
	## tinted, so the coming color is previewed.
	static func _glyph_color(base_hue: float, ci: int, ccur: float, sea: PackedFloat32Array, order := 0) -> Color:
		var d := ccur - float(ci)                       # >0 spoken (behind), <=0 waiting (ahead)
		if d <= 0.0:
			return Color.from_hsv(Scheme.voice_hue(base_hue + float(ci) * HUE_SPAN, order), 0.18, 0.6, 0.92)
		var at := ci * SubtitleSea.STRIDE
		var here := at + SubtitleSea.STRIDE <= sea.size()
		var near := exp(-maxf(d - 1.0, 0.0) / SETTLE)
		var lift := clampf((sea[at] if here else 0.0) / HEIGHT, -1.0, 1.0) * near
		var pull := (sea[at + 1] if here else 0.0) * near
		var hue := Scheme.voice_hue(base_hue + float(ci) * HUE_SPAN + pull + HUE_SWING * lift, order)
		var sat := SAT_CALM + lift * (SAT_CREST if lift > 0.0 else SAT_TROUGH)
		var val := VAL_CALM + lift * (VAL_CREST if lift > 0.0 else VAL_TROUGH)
		var col := Color.from_hsv(hue, sat, clampf(val, 0.0, 1.0))
		var glow := clampf(1.0 - (d - 1.0) / FLARE, 0.0, 1.0)
		return col.lerp(Color.from_hsv(hue, FLARE_SAT, 1.0), glow * FLARE_MIX)

	## The cursor expressed as a character position within the current sentence: the word-level eye
	## (owner._cursor) resolved through the per-word character offsets (item.cstart) the layout carries.
	## Past the last word it reads as the full length so the whole sentence lingers together.
	func _char_cursor(items: Array) -> float:
		if items.is_empty():
			return 0.0
		var cw := int(floor(owner_node._cursor))
		var frac: float = owner_node._cursor - float(cw)
		for it in items:
			if int(it.idx) == cw:
				return float(it.cstart) + frac * float(String(it.word.text).length())
		var last: Dictionary = items[items.size() - 1]
		if cw < int(items[0].idx):
			return 0.0
		return float(last.cstart) + float(String(last.word.text).length()) + 1.0

	## The current sentence as [{idx (global), word, w (pixel width), cstart}] items. cstart is the word's
	## first-character index within the sentence (words separated by one gap character), so color is keyed
	## on the continuous character sequence.
	func _current_sentence(t: float) -> Array:
		var all: Array = owner_node.words
	# One rule, shared with the presence ease: see Subtitles.span_at.
		var pos: int = owner_node.span_at(t)
		if pos < 0:
			return []
		var si := int(owner_node._spans_now()[pos].si)
		var out: Array = []
		var cstart := 0
		for k in all.size():
			if int(all[k].sentence) == si:
				out.append({"idx": k, "word": all[k], "w": 0.0, "cstart": cstart})
				cstart += String(all[k].text).length() + 1   # +1 for the inter-word gap
		return out

	## The glitch glyphs [param face] can draw, of [constant Subtitles.GLITCH_SIMPLE] and [constant
	## Subtitles.GLITCH_COMPLEX]: a font without box drawing shows none of it rather than tofu.
	func _glitch_set(face: Font) -> Array:
		if _glitch_sets.has(face):
			return _glitch_sets[face]
		var out: Array = []
		for pool in [Subtitles.GLITCH_SIMPLE, Subtitles.GLITCH_COMPLEX]:
			var kept := ""
			for c in pool:
				if face.has_char(c.unicode_at(0)):
					kept += c
			out.append(kept)
		if String(out[0]).is_empty():
			out[0] = "#*+=-/\\|"
		_glitch_sets[face] = out
		return out

	## Greedy wrap into rows that fit max_w at the given font size; also fills each item's pixel width.
	func _wrap(items: Array, font: Font, fs: int, max_w: float) -> Array:
		var gap := 14.0
		var lines: Array = []
		var row: Array = []
		var used := -gap
		for item in items:
	# Measured in the face it will be drawn in: an emboldened word is wider than the plain one and
	# the plate is sized from these numbers.
			item.w = _face(font, int(item.word.get("emph", 0))).get_string_size(
				item.word.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if used + gap + item.w > max_w and not row.is_empty():
				lines.append(row)
				row = []
				used = -gap
			row.append(item)
			used += gap + item.w
		if not row.is_empty():
			lines.append(row)
		return lines

	func _harmonic_hue() -> float:
		var sig := Spectrum.harmonic_signature()
		if sig.size() >= 12:
			var best := 0
			for i in 12:
				if sig[i] > sig[best]:
					best = i
			var target := float(best) / 12.0
			var d := fposmod(target - owner_node._hue_sm + 0.5, 1.0) - 0.5
			owner_node._hue_sm = fposmod(owner_node._hue_sm + d * 0.03, 1.0)
		return owner_node._hue_sm
