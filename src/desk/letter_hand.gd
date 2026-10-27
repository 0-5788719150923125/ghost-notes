extends RefCounted
class_name LetterHand

## LetterHand - a letter's words in a cursive hand, as the pen's strokes.
##
## THE HAND WRITES ITS OWN LINES, NO TEX: a formula needs TeX to lay it out ([Ink]), a line of a letter
## needs only its words' widths, so this sets each word itself from the Hershey simplex SCRIPT font
## (fonts/hands/hershey/scripts.jhf, a centerline cursive made for plotters) and hands back strokes in
## the shape [method Ink.strokes_of] does - points in TeX points, y down from the baseline, x from the
## line's start - so [method Ink.schedule] and [method Ink.at] time and draw them as they do a formula's.
##
## A WORD IS WRITTEN AS A HAND WRITES CURSIVE (measured on the font: every lowercase letter leaves at its
## right margin about half way up its body, and most come in at their left margin there): each letter is
## set at the last one's advance, so its way in meets the last one's way out, and the pen stays down
## across the word. Where a letter starts elsewhere - an a, c, d, g, o or q starts its bowl at the top -
## a connecting stroke rises from the last letter to it ([method _connect]); a letter's own strokes are
## joined where a hand would not lift (the n's second hump, the t's stem retraced). THE DOTS AND CROSSES
## COME LAST ([constant MARKS]): an i's dot, a j's, a t's bar and an x's second stroke are made once the
## word is written, as a hand dots its i's. The digits and the marks the script font draws doubled (its
## numerals are two parallel lines) come from the simplex roman ([constant PRINTED]), leaned to match.
##
## THE HAND IS SEEDED, never the layout: each word is a little bigger or smaller, set a little off its
## line and turned a hair, and each line drifts - from the seed and the line's own salt - but a word's
## WIDTH is the font's ([method advance]), so where the lines break is a function of the words alone and
## the voice's rests and the desk's pages always agree ([LetterScript]).

## The cursive, and the font the digits and doubled marks come from.
const FONT := "scripts"
const ROMAN := "futural"
## What the roman writes, leaned this much to sit with the script's slant.
const PRINTED := "0123456789!\"()[]-/&#%+=<>"
const ROMAN_SLANT := 0.22
## The hand's size: one font unit, in the page's pixels (the font's capitals are 21 units tall: about
## two thirds of a rule) - and how narrow it writes, across.
const UNIT_PX := 1.4
const NARROW := 0.86
## A word's space, as a share of the font's own (which is as wide as a letter).
const SPACE := 0.72
## The strokes of a letter that are made after its word ([constant MARKS]), by the font's own order.
const MARKS := {"i": [0], "j": [0], "t": [2], "x": [1]}
## Two strokes meeting this close (font units) are one; a letter's next stroke this close after its last
## is joined to it by the pen (a retrace); two letters this close are joined by a connecting stroke.
const JOIN := 1.5
const RETRACE := 20.0
const CONNECT := 18.0
## The nib, in points.
const NIB := 0.55
## HOW FAST THE HAND WRITES, against the desk's pen at its own pace ([method Ink.schedule]'s `pace`): that is
## a careful hand setting a formula, about 3.3 cm of the page a second; a fluent cursive runs 4 to 5.
const PACE := 1.5
## How unsteady the hand is: a word's size (share), its place off the line (units), its turn (radians);
## a line's drift (radians); a point's tremor (units).
const WORD_SIZE := 0.03
const WORD_RISE := 0.45
const WORD_TURN := 0.012
const LINE_TURN := 0.004
const TREMOR := 0.07
## An underline sits this far under the baseline (units).
const UNDER := 4.0

static var _lines := {}
static var _lock := Mutex.new()


## One font unit in TeX points (what the strokes are measured in).
static func unit() -> float:
	return UNIT_PX / DeskScript.PX_PER_PT


## How wide [param word] is written, in points: its letters' advances, whatever the hand does.
static func advance(word: String) -> float:
	var w := 0.0
	for ch in _chars(word):
		var g := _glyph(ch)
		w += (float(g[1]) - float(g[0])) if not g.is_empty() else 12.0
	return w * NARROW * unit()


## A space between two words, in points.
static func space() -> float:
	var g := Ink._hershey(FONT, " ")
	return (float(g[1]) - float(g[0])) * SPACE * NARROW * unit() if not g.is_empty() else 8.0


## How tall the hand stands above its baseline and below it, in page pixels.
static func ascent_px() -> float:
	return 21.0 * UNIT_PX


static func descent_px() -> float:
	return 12.0 * UNIT_PX


## A LINE OF THE LETTER, written: [param words] (as they are written - punctuation on them), the
## [param emphasis] of each (underlined), the hand's [param seed] and the line's [param salt]. Returns
## `{strokes, width}`: strokes as [method Ink.strokes_of] gives them (`k` the word's place in the line,
## so the pen breathes between words and never inside one), width in points. The same arguments are
## the same strokes, kept once made.
static func line(words: PackedStringArray, emphasis: Array, seed: int, salt: String) -> Dictionary:
	var key := "%d|%s|%s|%s" % [seed, salt, " ".join(words), str(emphasis)]
	_lock.lock()
	var kept: Variant = _lines.get(key)
	_lock.unlock()
	if kept != null:
		return kept
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["letter-hand", seed, salt, " ".join(words)])
	var u := unit()
	var turn := rng.randfn(0.0, LINE_TURN)
	var out: Array = []
	var x := 0.0
	for wi in words.size():
		var word := String(words[wi])
		var w := advance(word)
		var strokes := _word(word, rng)
		if wi < emphasis.size() and bool(emphasis[wi]):
			strokes.append(_underline(w / u, rng))
		var size := 1.0 + rng.randfn(0.0, WORD_SIZE)
		var rise := rng.randfn(0.0, WORD_RISE)
		var spin := rng.randfn(0.0, WORD_TURN)
		for st in strokes:
			var pts := PackedVector2Array()
			for p in st as PackedVector2Array:
				var q := Vector2(p.x - w / u * 0.5, p.y + rise).rotated(spin) * size
				q.x += w / u * 0.5
				pts.append((Vector2(x / u, 0.0) + q).rotated(turn) * u)
			out.append({"name": "letter", "k": wi, "points": pts, "width": NIB})
		x += w + space()
	var got := {"strokes": out, "width": maxf(x - space(), 0.0)}
	_lock.lock()
	if _lines.size() > 4000:
		_lines.clear()
	_lines[key] = got
	_lock.unlock()
	return got


## A word's strokes in font units (x from its start, y down from its baseline), in the order the pen
## makes them: the word joined up, then its dots and crosses.
static func _word(word: String, rng: RandomNumberGenerator) -> Array:
	var chains: Array = []           # PackedVector2Array: what the pen draws without lifting
	var marks: Array = []
	var pen := Vector2.INF
	var x := 0.0
	var prev_letter := false
	for ch in _chars(word):
		var g := _glyph(ch)
		if g.is_empty():
			x += 12.0
			prev_letter = false
			pen = Vector2.INF
			continue
		var roman := _roman(ch)
		var letter := ch.to_lower() != ch.to_upper()
		var left := float(g[0])
		var skip: Array = MARKS.get(ch, [])
		var first := true
		var strokes: Array = g[2]
		for si in strokes.size():
			var pts := PackedVector2Array()
			for p in strokes[si]:
				var q := Vector2((float(p.x) - left) * NARROW + x, float(p.y) - 9.0)
				if roman:
					q.x += ROMAN_SLANT * -q.y
				pts.append(q)
			if pts.is_empty():
				continue
			if si in skip:
				marks.append(_trembled(pts, rng))
				continue
			var d := pen.distance_to(pts[0]) if pen != Vector2.INF else INF
			# a packed array out of an Array is a copy: each joined chain is put back in its place
			if d <= JOIN:
				var joined: PackedVector2Array = chains[chains.size() - 1]
				joined.append_array(pts.slice(1))
				chains[chains.size() - 1] = joined
			elif not first and d <= RETRACE:
				var joined: PackedVector2Array = chains[chains.size() - 1]
				joined.append_array(pts)
				chains[chains.size() - 1] = joined
			elif first and prev_letter and letter and ch == ch.to_lower() and d <= CONNECT:
				var joined: PackedVector2Array = chains[chains.size() - 1]
				joined.append_array(_connect(pen, pts[0]))
				joined.append_array(pts)
				chains[chains.size() - 1] = joined
			else:
				chains.append(pts)
			pen = pts[pts.size() - 1]
			first = false
		x += (float(g[1]) - left) * NARROW
		prev_letter = letter
	var out: Array = []
	for c in chains:
		out.append(_trembled(c, rng))
	out.append_array(marks)
	return out


## THE STROKE THAT JOINS TWO LETTERS, from where the last left off ([param a]) to where the next begins
## ([param b]): straight when it is short, else rising over to it, as a hand comes up to the top of an
## a or an o and turns down into it.
static func _connect(a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var d := a.distance_to(b)
	if d < 4.0:
		return out
	var c := Vector2(lerpf(a.x, b.x, 0.7), minf(a.y, b.y) - 0.35 * d)
	for i in range(1, 6):
		var t := float(i) / 6.0
		out.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return out


## An underline under a word [param w] units wide: one quick stroke, a little uneven.
static func _underline(w: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var y := UNDER + rng.randfn(0.0, 0.4)
	return PackedVector2Array([Vector2(-1.0, y + rng.randfn(0.0, 0.3)), Vector2(w * 0.5, y + 0.4),
		Vector2(w + 1.0, y - 0.3 + rng.randfn(0.0, 0.3))])


static func _trembled(pts: PackedVector2Array, rng: RandomNumberGenerator) -> PackedVector2Array:
	var phase := rng.randf() * TAU
	var out := PackedVector2Array()
	for i in pts.size():
		out.append(pts[i] + Vector2(sin(phase + i * 0.9), cos(phase * 1.3 + i * 0.7)) * TREMOR)
	return out


## The glyph [param ch] is written with: the script's, or the roman's for what [constant PRINTED] holds.
static func _glyph(ch: String) -> Array:
	return Ink._hershey(ROMAN if _roman(ch) else FONT, ch)


static func _roman(ch: String) -> bool:
	return PRINTED.contains(ch)


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
