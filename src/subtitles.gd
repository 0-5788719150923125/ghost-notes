extends CanvasLayer
class_name Subtitles

## Subtitles - the karaoke overlay, session-owned rather than editor-owned.
##
## Draws the current sentence at the bottom in the SOURCE spelling (caps, quotes and
## punctuation intact - the phoneme normalization never reaches the reader's
## eyes), wrapping onto up to three lines before it ever shrinks the font.
## EMPHASIS IS DRAWN AS EMPHASIS: markdown's `*italic*` and `**bold**` reach here as a
## level on the word rather than as asterisks (see TextNorm's emphasis sentinels), and
## the overlay synthesizes a slanted or emboldened face for it.
##
## The tracker is a **narrator's eye**, not a metronome: an eased cursor that
## chases the true playback position with momentum - it ramps up when the
## words run ahead, drifts when it is close, and comes to REST at pauses and
## hesitations (the target holds at a word boundary, so the eye settles there
## and waits for the voice) - weaving around the exact timing the way a
## storyteller's finger weaves over a page. Highlight hue rides the live
## harmonic signature.
##
## Timing comes from a **sidecar JSON** written next to a voice take by
## [SynthEditor] (`take_N.wav` + `take_N.json`), so the same overlay works
## everywhere the take plays: the live synthesis session, a plain `--audio`
## boot, and the export render, where no editor exists.

## THE LINE ONLY EXISTS WHILE THERE IS SOMETHING TO READ.
##
## The sentence to show used to be chosen as "the current one, or else the first one not
## yet spoken", with no bound on how far ahead that was - so through a five second intro,
## before a word had been said, the opening line sat on screen the whole time waiting for
## a voice. The same at the end: nothing brought it off, so it hung through the outro.
##
## [constant LEAD] is how long before its first word a line may appear, and [constant
## HANG] how long after its last it stays. Both are longer than an ordinary gap between
## sentences, deliberately: at a normal seam the next line's window opens before the
## previous one's closes, so the overlay never blinks between sentences. It only leaves
## when the speaking genuinely stops. A pause INSIDE a sentence never brings it off at all,
## however long - see [method span_at], which is the single rule both the plate's ease and
## the drawn text obey.
const LEAD := 0.8
const HANG := 0.7
## Seconds to ease in and out over. The whole overlay eases like everything else here -
## a line that snapped on at full brightness would be the only hard cut in the frame.
const FADE := 0.3

## HOW A LINE'S WORDS ARE REVEALED (the user, 2026-10-07: "allow for other forms of subtitle text revealing,
## and make the options available to the user"), the Director's choice ([member Director.subtitle_reveal]):
## a key and the words the Look card shows for it.
const REVEALS := {
	"karaoke": "the whole line shown, each word lit as it is spoken",
	"glitch": "the words appear as they are spoken, a few scrambled glyphs running just ahead of the voice - reaching on, falling back, reaching again",
}
## THE GLITCH ([constant REVEALS] `glitch`, after the vortex chat's GlitchedLabel, which revealed a few
## characters past its front and pushed and popped ghosts beside them): the line is WRITTEN AS IT IS SPOKEN,
## in one steady sweep ([method glitch_front]) that has every word written within GLITCH_SETTLE seconds of its
## start (from GLITCH_EARLY before it) - so the word the voice is saying is never the scrambled one - and
## goes on through a pause instead of waiting in it. Each row is centered on what is written of it. Past the
## sweep, a few letters' places show NOISE ([method glitch_reach]: it reaches on a
## letter at a time, then falls back and reaches again, as a guess retracted); beyond that, nothing yet. The
## noise is a glyph from the sets below, each letter holding its own for GLITCH_HOLD - the simple set nearest
## the front, as the old label's last steps were - now and then with a faint ghost beside it. A pure function of
## show time and the line: a render and a scrub see the same noise. Asked 2026-10-07, of the first glitch
## (every letter of the line scrambled until spoken): "the glitching would only happen a few characters ahead
## of the text ... It could predict ahead, then retract, then predict again."
const GLITCH_SETTLE := 0.28
const GLITCH_EARLY := 0.06
## How long a letter of noise holds a glyph (seconds, its own length in this range - the label stepped every
## 30-80 ms), and how often a hold's end changes it.
const GLITCH_HOLD := Vector2(0.045, 0.11)
const GLITCH_CHANGE := 0.7
## How often the noise's reach moves (steps a second - the label typed about one letter so), the most letters
## it reaches past the front and the fewest a guess reaches, and the steps in one run of guesses
## ([method glitch_reach]).
const GLITCH_STEPS := 12.0
const GLITCH_AHEAD := 10
const GLITCH_LEAST := 4
const GLITCH_RUN := 48
const GLITCH_SIMPLE := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!?#$%^&*<>-_/\\[]{}|="
const GLITCH_COMPLEX := "┌┐└┘├┤┬┴┼━┃┏┓┗┛┣┫┳┻╋※×○◎●△▲▽▼☉♠♡♢♣♤♥♦♧"


## WHEN LETTER [param ch] of [param n] in a word spoken from [param t0] to [param t1] settles into itself
## ([constant GLITCH_SETTLE]): never after the word has begun to be spoken by more than the settle.
static func settle_at(t0: float, t1: float, ch: int, n: int) -> float:
	var span := clampf(t1 - t0, 0.05, GLITCH_SETTLE)
	return t0 - GLITCH_EARLY + span * float(ch) / float(maxi(n, 1))


## WHERE THE GLITCH'S FRONT IS at [param t] (letters into the line, a fraction into the next), for the line's
## words [param spans] - [[first letter, letters, t0, t1], ...] in order: ONE STEADY SWEEP through the line,
## pauses and all, as the vortex label wrote, that is never behind the voice. Each word must be written by
## the time it settles ([method settle_at]); the sweep is the least curve over all of those that starts at
## the line's first letter and never speeds up (their upper hull) - straight through a pause rather than
## waiting at a comma for the next word (reported 2026-10-07: "the glitching stops/pauses at comma
## boundaries, waiting for the hesitation").
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


## HOW MANY LETTERS PAST THE FRONT the noise reaches at [param t] in line [param line], as vortex's label typed
## its guesses and took them back: in each run of [constant GLITCH_RUN] steps ([constant GLITCH_STEPS] a second)
## it reaches on a letter a step to a first guess ([constant GLITCH_LEAST] to [constant GLITCH_AHEAD]), holds
## it, BACKS OFF a letter a step part of the way, reaches again to a second, holds, and backs off to one - and
## rests there until the run ends. Every run starts and ends at one, so it never jumps.
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


## THE GLYPH letter [param ch] of word [param wi] shows at [param t], [param ahead] letters past the front: a
## glyph of [param simple] (always, at the front itself) or [param complex]. Each letter keeps its own time, as
## each of the label's letters stepped on its own: it holds a glyph [constant GLITCH_HOLD] seconds (its own
## length in that range, from its own moment), and at the end of a hold changes only GLITCH_CHANGE of the
## time - where every letter turning over together 16 times a second read as a boil.
static func glitch_glyph(wi: int, ch: int, t: float, ahead: int, simple: String, complex: String) -> String:
	var own := hash([wi, ch, "hold"])
	var hold := lerpf(GLITCH_HOLD.x, GLITCH_HOLD.y, float(own % 1000) / 999.0)
	var tick := floori(t / hold + float((own >> 10) % 1000) / 999.0)
	# the last tick it changed on
	for back in 8:
		if hash([wi, ch, tick, "turn"]) % 100 < int(GLITCH_CHANGE * 100.0):
			break
		tick -= 1
	var h := hash([wi, ch, tick])
	var pool := simple if (ahead <= 0 or complex.is_empty() or h % 3 != 0) else complex
	return pool[(h >> 4) % pool.length()]

var words: Array = []               # [{text, t0, t1, sentence}] - may still be GROWING
                                    # (a live VoiceStream shares its array by reference)
var loop_length := 0.0              # >0 once a streamed take loops: wrap time by this
var time_base := 0.0                # playback time when the current content started
## 0..1, eased. Multiplies every alpha the overlay draws, plate included.
var presence := 0.0
## The manuscript this reading came from, when there is one: `{source}` - the chapter's
## markdown. Carried beside the words so a medium that typesets the text ([BookMedium])
## gets it in the live session and in the export render alike (it rides the sidecar).
var document: Dictionary = {}
## True when a medium shows the words itself: the clock and the eased cursor keep running,
## because that medium reads them, and only the drawing stops.
var overlay_hidden := false
## WHERE THE FRAME IS in the window (main sets it as the stage fits): the subtitles lay out in the
## show's frame, not the window - an empty rect means the whole viewport (an export, where they are
## one). A portrait frame keeps its safe area clear ([constant SAFE]).
var frame_rect := Rect2()
## THE SAFE AREA OF A PORTRAIT FRAME, as shares of it: what every platform draws its buttons and
## captions over. Google's safe zones for 1080x1920 keep the top 288, the bottom 672 and the right
## 192 pixels clear; the left keeps a small margin of its own.
const SAFE := {"top": 0.15, "bottom": 0.35, "right": 0.178, "left": 0.044}


## WHERE A LINE OF SUBTITLES GOES in [param frame]: `{k, max_w, cx, base_y}` - the type's scale (off
## the frame's SHORT side, as the scenes size themselves: a 1080-wide portrait frame sets type as a
## 1080-tall landscape one does), the widest a line may run, the middle it is centered on, and the
## last line's baseline. A landscape frame keeps the old layout exactly (92% of its width, 70 px up
## at 1080); a portrait one lays out inside its SAFE area, which at 1080x1920 an old-style line sat
## 93.5% of the way down, under the buttons every platform draws there.
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
var _overlay: Control
var _order := {}                    # speaker -> its place among the reading's voices
var _order_of: Array = []           # ...in this words array
var _order_n := 0                   # ...read this far

## EACH VOICE LIGHTS IN COLORS OF ITS OWN (the user, 2026-10-05: "the first can remain the rainbow
## color, while the next could be a different spectrum"): the reading's first voice in the whole
## rainbow, and every voice after it, in the order they first speak, in a band of hues - [from, to],
## crossed the way listed: red through purple to blue, green to yellow, cyan to sea blue - swept
## there and back by the same flowing phase. Past the last band they come round again.
const VOICE_BANDS := [[1.0, 0.62], [0.36, 0.14], [0.44, 0.58]]


## The hue a glyph lights in, for [param phase] (any real; the flow along the text and over time):
## the phase itself on the whole wheel for the reading's first voice ([param order] 0), otherwise
## swept across that voice's band and back, eased at both ends so the band never jumps.
static func voice_hue(phase: float, order: int) -> float:
	if order <= 0:
		return fposmod(phase, 1.0)
	var band: Array = VOICE_BANDS[(order - 1) % VOICE_BANDS.size()]
	return fposmod(lerpf(float(band[0]), float(band[1]), 0.5 - 0.5 * cos(TAU * phase)), 1.0)


## Voice [param who]'s place among this reading's voices, by when each first speaks (see
## [constant VOICE_BANDS]). A word that names no voice - a synthesis take, an older sidecar - is
## the first voice's. Read on as [member words] grows; a new reading starts it over.
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


## The true position as global word progress: word index + fraction within it.
## Between words (a pause, a breath, a hesitation) the target HOLDS at the
## previous word's end - which is what lets the eased eye rest there.
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


## Sentence SPANS: `[{si, lo, hi}]` in time order, where lo/hi are the first word's start and
## the last word's end - so a span covers a sentence's INTERNAL pauses as well as its words.
## Cached, because the list is walked every frame and can run to thousands of words; rebuilt
## when it changes, which it does word by word while a take streams (a live [VoiceStream] shares
## this array by reference, and [GenerativeEditor] clears it in place between takes).
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
	for w in words:
		var si := int(w.sentence)
		if at.has(si):
			var e: Dictionary = _spans[int(at[si])]
			e.lo = minf(float(e.lo), float(w.t0))
			e.hi = maxf(float(e.hi), float(w.t1))
		else:
			at[si] = _spans.size()
			_spans.append({"si": si, "lo": float(w.t0), "hi": float(w.t1)})
	_spans_n = n
	_spans_tail = tail
	return _spans


## THE ONE RULE for what belongs on screen at [param t]: the position in [method _spans_now] of
## the sentence to show, or -1 for nothing.
##
## It is one rule now because TWO of them was the bug. The presence ease asked "is t inside this
## SENTENCE's span, +/- LEAD/HANG"; the draw asked "is t within 0.4 s of a WORD, or within LEAD
## of the next one" - and those disagree for any pause longer than 1.2 s INSIDE a sentence.
## Reported from a ch19 render, at a colon: "at exactly the same place where the colon is, the
## subtitles briefly disappeared, then reappeared... the SAME subtitles flickered". A colon is
## sent to the voice as a colon (see generative_editor._build_chunks), the model answers it with
## a clause pause, and a pause_scale over 1 stretches it past that 1.2 s - so `presence` held at
## 1.0 while the draw had no sentence to draw and returned early, taking the plate with it.
## Measured before the fix: a 1.6 s internal pause went dark 0.45 s in, for a third of a second.
##
## The order of preference is what makes one rule serve both:
##   1. t inside a span - internal pauses included, which is the fix;
##   2. else the NEXT sentence, if it starts within LEAD (it takes over at a seam, because it is
##      the one about to be spoken);
##   3. else the PREVIOUS sentence, if it ended within HANG (a line lingers rather than snapping
##      off, including in a long gap between two sentences);
##   4. else nothing - the speaking has genuinely stopped.
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


## Should anything be on screen at time [param t], and how strongly? 1 while a sentence is
## selected by [method span_at], 0 otherwise - the same question the draw asks, so the plate and
## the text can never disagree about whether there is anything to read.
func _presence_target(t: float) -> float:
	return 1.0 if span_at(t) >= 0 else 0.0


func _process(delta: float) -> void:
	if words.is_empty():
		presence = 0.0
		return
	var now := _now()
	presence = lerpf(presence, _presence_target(now), 1.0 - exp(-delta / maxf(0.01, FADE)))
	# Snap the tail of the ease to zero. An exponential never actually arrives, and a
	# plate at alpha 0.003 is still a plate - over a dark scene it is invisible, over a
	# bright one it is a faint gray bar sitting at the bottom of the frame for the whole
	# silence, which is the complaint in miniature.
	if presence < 0.004:
		presence = 0.0
	# The CURSOR keeps tracking through all of this, deliberately. It is eased over
	# several seconds, so freezing it while the line is hidden would leave it stale when
	# the next sentence arrives and it would visibly race to catch up on screen.
	var target := _target(now)
	var gap := target - _cursor
	if absf(gap) > 3.0:
		_cursor = target             # a loop seam or a restart: snap, don't chase
	else:
		# the weave: momentum grows with how far behind the eye is, so it
		# ramps to catch a run of quick words and slows as it closes in
		var rate := 3.0 + 7.0 * clampf(absf(gap) - 0.15, 0.0, 1.5)
		_cursor = lerpf(_cursor, target, 1.0 - exp(-rate * delta))
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
	# The color is a GRADIENT keyed on the CHARACTER index across the whole
	# sentence, not the word - so a band of hue drifts through the text spanning
	# several words at once, and the reader can watch it flow rather than catch
	# it word by word. HUE_SPAN sets how tight the band is (how much the hue
	# turns from one glyph to the next); HUE_DRIFT sets how fast the whole band
	# slides forward over time. LINGER is the payload of the request: a spoken
	# glyph does NOT snap back to its resting dim the instant the voice leaves
	# it - it holds its vivid gradient hue and cools over this many characters
	# behind the cursor, so the color stays long enough to rest the eye on and
	# read what the change meant.
	const HUE_SPAN := 0.011          # hue turned per character (band tightness)
	const HUE_DRIFT := 0.02          # hue slid per second (the band flows)
	const LINGER := 24.0             # characters a spoken glyph stays lit behind the cursor
	# A SECOND channel: SATURATION ebbs and flows in slow bands along the text, at
	# a tighter, differently-timed rhythm than the hue (two incommensurate waves so
	# the pattern never quite repeats). It pulls the color down toward a grounded,
	# near-gray calm in the valleys and lets it burn full in the peaks - so the line
	# is not a solid rainbow but stable regions with color activity between them.
	const SAT_SPAN := 0.17           # saturation band spatial frequency (a valley ~every 37 glyphs)
	const SAT_DRIFT := 0.09          # the bands drift per second (their own rhythm)
	const SAT_FLOOR := 0.14          # how far the grounded valleys desaturate (0 = gray)
	# EMPHASIS IS DRAWN, NOT SPELLED. `*I will never hurt you*` reaches here as a level on
	# the word (see TextNorm's emphasis sentinels), never as asterisks - printing the
	# markers would be showing the reader the source code of the typography. Godot can
	# synthesize both faces off the one theme font, so this needs no second font file:
	# `variation_embolden` thickens the outline and `variation_transform` shears it.
	const EMBOLDEN := 0.6
	## The oblique shear, as FreeType's own matrix takes it: x' = x + SLANT * y, with y up
	## in outline space, so a positive value leans the tops of the letters to the right.
	## 0.22 is about 12 degrees, which is what a real italic face runs at.
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
		# Nothing is being read: draw nothing at all, plate included. This is the
		# whole point of `presence` - an empty line still drew its dark plate, so
		# through the intro there was a black bar across the bottom of the frame
		# waiting for words.
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
		# EVERY PIXEL NUMBER BELOW IS RELATIVE TO A 1080-TALL FRAME. The export renders at a
		# multiple of the delivered size and lets ffmpeg resolve it back down (that supersample is
		# ghost's only antialiasing - see exporter.QUALITIES), so a subtitle sized in literal
		# pixels came out 1/1.5 as large in the file as it looks in the viewer. Sizing off the
		# viewport instead makes the type occupy the same FRACTION of the frame at any render
		# resolution, which is what "the same size" actually means.
		var k: float = box["k"]
		# wrap first, shrink only as a last resort
		var fs := int(round(BASE_FS * k))
		var min_fs := int(round(MIN_FS * k))
		var lines := _wrap(line_words, font, fs, max_w)
		while lines.size() > MAX_LINES and fs > min_fs:
			fs -= maxi(1, int(round(2.0 * k)))
			lines = _wrap(line_words, font, fs, max_w)
		var lh := float(fs) + 12.0 * k
		# the harmonic hue is now the BASE the gradient rides from, not the one
		# color of the whole line - each glyph turns off it by its position and
		# by time (see _glyph_color)
		var base_hue := _harmonic_hue()
		var now := owner_node._now()
		var gap := 14.0 * k
		# the cursor as a CHARACTER position within this sentence, so the lit
		# front and the lingering trail are both measured in glyphs, not words
		var ccur: float = _char_cursor(line_words)
		var glitch := Director.subtitle_reveal == "glitch"
		var base_y: float = box["base_y"]
		var y: float = base_y - (lines.size() - 1) * lh
		# THE PLATE: scenes range from black voids to white-hot fields, so
		# color alone can never keep text legible. Each line gets a rounded
		# dark plate sized to its own width (a full-width band would read as
		# broadcast furniture and cover the show), and every glyph is drawn
		# once in near-black underneath - the plate carries most of the
		# contrast, the shadow catches the edges over bright content.
		# WRITTEN AS IT IS SPOKEN (the glitch): where the sweep is ([method Subtitles.glitch_front]) and how far past
		# it the noise reaches; a letter beyond that is not drawn yet. Each row is CENTERED ON WHAT IS WRITTEN of
		# it, so the words come out of the middle of the screen, where the eye already is (asked 2026-10-07:
		# "the alignment/centering would be constantly compensating for the addition of new text") - its plate
		# round what is drawn, noise and all
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
				x0 = cx - _written(row, sweep, font, fs, gap) * 0.5
				drawn = _written(row, float(front + reach), font, fs, gap)
			starts.append(x0)
			if drawn > 0.0:
				var pad := 12.0 * k
				var plate := Rect2(x0 - pad, y - float(fs) - 4.0 * k, drawn + pad * 2.0, lh + 2.0 * k)
				draw_rect(plate, Color(0.04, 0.04, 0.05, 0.72 * vis), true)
			y += lh
		y = base_y - (lines.size() - 1) * lh
		# the pen advances glyph by glyph so the gradient can turn WITHIN a word,
		# and so a spoken glyph keeps its own lingering color independent of its
		# neighbors - the whole reason to key on characters instead of words
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
					var col := _glyph_color(base_hue, ci + ch, ccur, now, order)
					col.a *= vis
					var ahead := ci + ch - front
					if glitch and ahead >= reach:
						# NOT REACHED YET: nothing, in the letter's own place
						x += cw
						continue
					if glitch and glyph != " " and ahead >= 0:
						# NOT SAID YET: a glyph of noise in the letter's own place, centered on it so
						# the line never reflows, flickering - and now and then a ghost beside it
						var sets: Array = _glitch_set(face)
						var g := Subtitles.glitch_glyph(int(item.idx), ch, now, ahead, sets[0], sets[1])
						var gs := fs
						var gw := face.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
						if gw > cw * 1.25:
							# a wide glyph in a narrow letter's place is set smaller, not spilled on its neighbors
							gs = maxi(int(float(fs) * cw * 1.25 / gw), int(fs * 0.5))
							gw = face.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
						var gp := pos + Vector2((cw - gw) * 0.5, 0.0)
						var h := hash([int(item.idx), ch, floori(now * Subtitles.GLITCH_STEPS), "ghost"])
						# as bright as the words it stands for, near enough: the dim preview tint left it a smudge
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
					# the shadow, under every state - the edge that survives a
					# bright frame bleeding past the plate
					draw_string(face, pos + Vector2(1.5 * k, 1.5 * k), glyph,
						HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85 * vis))
					draw_string(face, pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
					x += cw
				x += gap
			y += lh

	## How wide row [param row] is up to letter [param upto] of its sentence (a fraction of the next letter, and
	## of the gap after a word, counted in), at size [param fs] - the glitch centers a row on it.
	func _written(row: Array, upto: float, font: Font, fs: int, gap: float) -> float:
		var w := 0.0
		for item in row:
			var text: String = item.word.text
			var c0 := int(item.cstart)
			if upto <= float(c0):
				break
			if upto >= float(c0 + text.length()):
				w += item.w + gap * clampf(upto - float(c0 + text.length()), 0.0, 1.0)
				continue
			var face := _face(font, int(item.word.get("emph", 0)))
			for ch in text.length():
				var cw := face.get_string_size(text.substr(ch, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				w += cw * clampf(upto - float(c0 + ch), 0.0, 1.0)
		return w

	## A single glyph's color: a hue that drifts by position AND time (the band
	## flowing through the sentence) - on the whole wheel, or across the band of the
	## voice saying it ([param order], see [method Subtitles.voice_hue]) - and a
	## brightness that tells the reading state - a muted preview ahead of the voice,
	## a vivid flare as it is spoken, then a slow cool over LINGER characters behind
	## so the color stays to be looked at rather than snapping dim the instant the
	## word ends.
	func _glyph_color(base_hue: float, ci: int, ccur: float, t: float, order := 0) -> Color:
		var hue := Subtitles.voice_hue(base_hue + float(ci) * HUE_SPAN - t * HUE_DRIFT, order)
		# the saturation band at this glyph: two incommensurate waves -> organic,
		# non-repeating valleys (grounded) and peaks (colorful). Scales the state's
		# own saturation from a near-gray floor up to full.
		var s1 := sin(float(ci) * SAT_SPAN - t * SAT_DRIFT)
		var s2 := sin(float(ci) * SAT_SPAN * 1.73 + t * SAT_DRIFT * 0.5)
		var sat_env := clampf(0.5 + 0.35 * s1 + 0.15 * s2, 0.0, 1.0)
		var sm := lerpf(SAT_FLOOR, 1.0, sat_env)        # saturation multiplier
		var d := ccur - float(ci)                       # >0 spoken (behind), <=0 waiting (ahead)
		if d <= 0.0:
			# ahead of the voice: dim but present, faintly tinted so the coming
			# color is previewed rather than a wall of gray
			return Color.from_hsv(hue, 0.22 * sm, 0.6, 0.92)
		# spoken: full flare at the front, cooling to a resting tint over LINGER
		var glow := clampf(1.0 - (d - 1.0) / LINGER, 0.0, 1.0)
		var rest := Color.from_hsv(hue, 0.34 * sm, 0.7)
		var vivid := Color.from_hsv(hue, 0.9 * sm, 1.0)
		return rest.lerp(vivid, glow)

	## The cursor expressed as a CHARACTER position within the current sentence:
	## the word-level eye (owner._cursor) resolved through the per-word character
	## offsets (item.cstart) the layout already carries. Past the last word it
	## reads as the full length so the whole sentence lingers together.
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

	## The current sentence as [{idx (global), word, w (pixel width), cstart}]
	## items. cstart is the word's first-character index WITHIN the sentence
	## (words separated by one gap character), so color can be keyed on the
	## continuous character sequence rather than reset at every word.
	func _current_sentence(t: float) -> Array:
		var all: Array = owner_node.words
		# ONE RULE, shared with the presence ease - see Subtitles.span_at for why this is not
		# its own window any more. It used to be "the sentence with a word within 0.4 s, else
		# the first one starting within LEAD", which had a dead zone in the middle of any pause
		# longer than 1.2 s and blinked the line off inside a sentence at a colon.
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

	## The glitch glyphs [param face] can draw, of [constant Subtitles.GLITCH_SIMPLE] and
	## [constant Subtitles.GLITCH_COMPLEX]: a font without box drawing shows none of it rather than tofu.
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

	## Greedy wrap into rows that fit max_w at the given font size; also fills
	## each item's pixel width.
	func _wrap(items: Array, font: Font, fs: int, max_w: float) -> Array:
		var gap := 14.0
		var lines: Array = []
		var row: Array = []
		var used := -gap
		for item in items:
			# MEASURED IN THE FACE IT WILL BE DRAWN IN. An emboldened word is wider than
			# the plain one, and the plate is sized from these numbers - measure in the
			# base font and every bold line hangs over the end of its own plate.
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
