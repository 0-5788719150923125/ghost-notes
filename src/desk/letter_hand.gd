extends RefCounted
class_name LetterHand

## LetterHand - a letter's words in a hand, as the pen's strokes.
##
## THE HAND WRITES ITS OWN LINES, NO TEX: a formula needs TeX to lay it out ([Ink]), a line of a letter
## needs only its words' widths, so this sets each word itself and hands back strokes in the shape
## [method Ink.strokes_of] does - points in TeX points, y down from the baseline, x from the line's start -
## so [method Ink.schedule] and [method Ink.at] time and draw them as they do a formula's.
##
## THE JOURNAL'S HANDS (2026-10-27, the user of the Hershey script it had been written in: "the font looks
## awful ... the journal medium had nicer fonts"): Kalam, Caveat and Patrick Hand, the Notebook's
## ([constant NotebookLayout.HANDS]) at the Notebook's sizes, each traced once into the lines a pen draws it
## with (scripts/hand_strokes.py: its centerline cut where it branches and walked into strokes in a hand's
## order, a dot filled as a small spiral; kept in Hershey's format under fonts/hands/strokes/, which [Ink]'s
## reader takes) and written with a round nib as wide as the font's own stroke - so the page is the font,
## written. A print hand: the pen lifts between letters, and a letter's strokes that meet are one.
##
## THE HAND IS SEEDED, never the layout: each word is a little bigger or smaller, set a little off its
## line and turned a hair, and each line drifts - from the seed and the line's own salt - but a word's
## WIDTH is the font's ([method advance]), so where the lines break is a function of the words alone and
## the voice's rests and the desk's pages always agree ([LetterScript]).

## The hands, by the Notebook's names: the stroke font each is traced into, and what Hershey's format
## cannot hold, as the tracer prints it - a font unit's share of the em (`units`), the baseline (font
## units, y down), how far the hand reaches above and below it and how wide its stroke is (em).
const HANDS := {
	"caveat": {"label": "Caveat", "strokes": "res://fonts/hands/strokes/caveat.jhf",
		"units": 88, "base": 19, "ascent": 0.767, "descent": 0.223, "nib": 0.060},
	"kalam": {"label": "Kalam", "strokes": "res://fonts/hands/strokes/kalam.jhf",
		"units": 81, "base": 22, "ascent": 0.875, "descent": 0.245, "nib": 0.082},
	"patrick": {"label": "Patrick Hand", "strokes": "res://fonts/hands/strokes/patrick.jhf",
		"units": 77, "base": 18, "ascent": 0.870, "descent": 0.310, "nib": 0.0831},
}
## The hand a letter that names none is written in: the Notebook's own first choice.
const DEFAULT := "kalam"
## A word's space, as a share of the font's own.
const SPACE := 1.0
## A letter's next stroke begun this close (em) to where its last ended is the same stroke: the pen
## did not lift.
const JOIN := 0.02
## HOW FAST THE HAND WRITES, against the desk's pen at its own pace ([method Ink.schedule]'s `pace`), and
## steadily ([LetterScript]): about 48 words a minute in Kalam (at 1.5, 56: measured on the north-star
## chapter's 3,467 words) - a brisk letter-writer's; the voice reads 120 to 140, and the pen kept with it
## at that moved as no hand does.
const PACE := 2.3
## How unsteady the hand is (em of the hand): a word's size (share), its place off the line, its turn
## (radians); a line's drift (radians); a point's tremor.
const WORD_SIZE := 0.03
const WORD_RISE := 0.018
const WORD_TURN := 0.012
const LINE_TURN := 0.004
const TREMOR := 0.003
## An underline sits this far under the baseline (em).
const UNDER := 0.16
## How much wider the desk draws a stroke than its `width` says ([method DeskMedium._ink_of]): the nib
## is given that much less, so the line is the font's own width.
const DRAWN := 1.35

static var _lines := {}
static var _lock := Mutex.new()


## [param hand] if it is one of [constant HANDS], else [constant DEFAULT].
static func of(hand: String) -> String:
	return hand if HANDS.has(hand) else DEFAULT


## The body size [param hand] is written at, in the page's pixels: the Notebook's, which fills a rule.
static func size_px(hand: String) -> float:
	return float(NotebookLayout.HANDS[of(hand)]["size"])


## One font unit of [param hand] in TeX points (what the strokes are measured in).
static func unit(hand := DEFAULT) -> float:
	return size_px(hand) / float(HANDS[of(hand)]["units"]) / DeskScript.PX_PER_PT


## How wide [param word] is written, in points: its letters' advances, whatever the hand does.
static func advance(word: String, hand := DEFAULT) -> float:
	var w := 0.0
	for ch in _chars(word):
		var g := _glyph(ch, hand)
		w += (float(g[1]) - float(g[0])) if not g.is_empty() else _space_units(hand)
	return w * unit(hand)


## A space between two words, in points.
static func space(hand := DEFAULT) -> float:
	return _space_units(hand) * SPACE * unit(hand)


static func _space_units(hand: String) -> float:
	var g := _glyph(" ", hand)
	return float(g[1]) - float(g[0]) if not g.is_empty() else float(HANDS[of(hand)]["units"]) * 0.25


## How tall the hand stands above its baseline and below it, in page pixels.
static func ascent_px(hand := DEFAULT) -> float:
	return float(HANDS[of(hand)]["ascent"]) * size_px(hand)


static func descent_px(hand := DEFAULT) -> float:
	return float(HANDS[of(hand)]["descent"]) * size_px(hand)


## The nib [param hand] is written with, in points: as wide as the font's own stroke once drawn.
static func nib(hand := DEFAULT) -> float:
	return float(HANDS[of(hand)]["nib"]) * size_px(hand) / (DeskScript.PX_PER_PT * DRAWN)


## A LINE OF THE LETTER, written: [param words] (as they are written - punctuation on them), the
## [param emphasis] of each (underlined), the hand's [param seed], the line's [param salt] and the
## [param hand] it is written in. Returns `{strokes, width}`: strokes as [method Ink.strokes_of] gives them
## (`k` the word's place in the line, so the pen breathes between words and never inside one), width in
## points. The same arguments are the same strokes, kept once made.
static func line(words: PackedStringArray, emphasis: Array, seed: int, salt: String, hand := DEFAULT) -> Dictionary:
	hand = of(hand)
	var key := "%s|%d|%s|%s|%s" % [hand, seed, salt, " ".join(words), str(emphasis)]
	_lock.lock()
	var kept: Variant = _lines.get(key)
	_lock.unlock()
	if kept != null:
		return kept
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["letter-hand", seed, salt, " ".join(words)])
	var u := unit(hand)
	var em := float(HANDS[hand]["units"])
	var turn := rng.randfn(0.0, LINE_TURN)
	var pen := nib(hand)
	var out: Array = []
	var x := 0.0
	for wi in words.size():
		var word := String(words[wi])
		var w := advance(word, hand)
		var strokes := _word(word, rng, hand)
		if wi < emphasis.size() and bool(emphasis[wi]):
			strokes.append(_underline(w / u, em, rng))
		var size := 1.0 + rng.randfn(0.0, WORD_SIZE)
		var rise := rng.randfn(0.0, WORD_RISE * em)
		var spin := rng.randfn(0.0, WORD_TURN)
		for st in strokes:
			var pts := PackedVector2Array()
			for p in st as PackedVector2Array:
				var q := Vector2(p.x - w / u * 0.5, p.y + rise).rotated(spin) * size
				q.x += w / u * 0.5
				pts.append((Vector2(x / u, 0.0) + q).rotated(turn) * u)
			out.append({"name": "letter", "k": wi, "points": pts, "width": pen})
		x += w + space(hand)
	var got := {"strokes": out, "width": maxf(x - space(hand), 0.0)}
	_lock.lock()
	if _lines.size() > 4000:
		_lines.clear()
	_lines[key] = got
	_lock.unlock()
	return got


## A word's strokes in font units (x from its start, y down from its baseline), in the order the pen
## makes them: letter by letter, each as the font's tracing has it, a stroke begun where the last ended
## drawn on without a lift.
static func _word(word: String, rng: RandomNumberGenerator, hand: String) -> Array:
	var chains: Array = []           # PackedVector2Array: what the pen draws without lifting
	var pen := Vector2.INF
	var x := 0.0
	var base := float(HANDS[hand]["base"])
	var join := JOIN * float(HANDS[hand]["units"])
	for ch in _chars(word):
		var g := _glyph(ch, hand)
		if g.is_empty():
			x += _space_units(hand)
			pen = Vector2.INF
			continue
		var left := float(g[0])
		for st in g[2]:
			var pts := PackedVector2Array()
			for p in st:
				pts.append(Vector2(float(p.x) - left + x, float(p.y) - base))
			if pts.is_empty():
				continue
			# a packed array out of an Array is a copy: a joined chain is put back in its place
			if pen != Vector2.INF and pen.distance_to(pts[0]) <= join:
				var joined: PackedVector2Array = chains[chains.size() - 1]
				joined.append_array(pts.slice(1))
				chains[chains.size() - 1] = joined
			else:
				chains.append(pts)
			pen = pts[pts.size() - 1]
		x += float(g[1]) - left
	var out: Array = []
	var tremor := TREMOR * float(HANDS[hand]["units"])
	for c in chains:
		out.append(_trembled(c, tremor, rng))
	return out


## An underline under a word [param w] units wide, in a hand of [param em] units to the em: one quick
## stroke, a little uneven.
static func _underline(w: float, em: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var y := UNDER * em + rng.randfn(0.0, 0.015 * em)
	return PackedVector2Array([Vector2(-0.03 * em, y + rng.randfn(0.0, 0.01 * em)), Vector2(w * 0.5, y + 0.015 * em),
		Vector2(w + 0.03 * em, y - 0.01 * em + rng.randfn(0.0, 0.01 * em))])


static func _trembled(pts: PackedVector2Array, tremor: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var phase := rng.randf() * TAU
	var out := PackedVector2Array()
	for i in pts.size():
		out.append(pts[i] + Vector2(sin(phase + i * 0.9), cos(phase * 1.3 + i * 0.7)) * tremor)
	return out


## The glyph [param ch] is written with in [param hand]: `[left, right, strokes]`, [] when it has none.
static func _glyph(ch: String, hand: String) -> Array:
	return Ink._hershey(String(HANDS[of(hand)]["strokes"]), ch)


## [param word]'s characters as the fonts have them: typographer's quotes and dashes as a hand writes
## them, an ellipsis as its dots, anything else outside ASCII left out.
static func _chars(word: String) -> PackedStringArray:
	var out := PackedStringArray()
	for ch in word:
		match ch:
			"‘", "’":
				out.append("'")
			"“", "”":
				out.append("\"")
			"–", "—":
				out.append("-")
			"…":
				out.append_array([".", ".", "."])
			_:
				if ch.unicode_at(0) >= 32 and ch.unicode_at(0) < 127:
					out.append(ch)
	return out
