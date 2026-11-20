extends RefCounted
class_name MusicTheory

## MusicTheory - the theory a composed Sound is made of, as rows and pure functions (next/music.md, "The bank"): the
## scales, the chords a scale's degrees make, voice leading, and Euclidean rhythms. Nobody choosing a sound needs these
## words; the patterns are built from them.
##
## A pitch is a MIDI number (60 is middle C); a key is a tonic pitch class (0 is C) and a [constant SCALES] row. A chord
## is a root pitch class and a [constant QUALITIES] row. Static and free of autoloads, so a gate reads it under
## `--script`.

const NAMES := ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

## The scales and modes: the steps over the tonic, and how each feels.
const SCALES := {
	"major": {"label": "Major", "steps": [0, 2, 4, 5, 7, 9, 11], "blurb": "Ionian: bright and settled, every pop song's home."},
	"minor": {"label": "Minor", "steps": [0, 2, 3, 5, 7, 8, 10], "blurb": "Aeolian: the natural minor, dark and plain."},
	"dorian": {"label": "Dorian", "steps": [0, 2, 3, 5, 7, 9, 10], "blurb": "Minor with a raised sixth: wistful, never quite sad."},
	"mixolydian": {"label": "Mixolydian", "steps": [0, 2, 4, 5, 7, 9, 10], "blurb": "Major with a flat seventh: rock's and folk's swagger."},
	"lydian": {"label": "Lydian", "steps": [0, 2, 4, 6, 7, 9, 11], "blurb": "Major with a raised fourth: it floats, never lands."},
	"phrygian": {"label": "Phrygian", "steps": [0, 1, 3, 5, 7, 8, 10], "blurb": "Minor with a flat second: dark and close."},
	"harmonic_minor": {"label": "Harmonic minor", "steps": [0, 2, 3, 5, 7, 8, 11], "blurb": "Minor with a leading tone: the old world's drama."},
	"major_pentatonic": {"label": "Major pentatonic", "steps": [0, 2, 4, 7, 9], "blurb": "Five notes, no two a semitone apart: nothing clashes."},
	"minor_pentatonic": {"label": "Minor pentatonic", "steps": [0, 3, 5, 7, 10], "blurb": "The blues' five notes: nothing clashes, everything leans."},
}

## The chord qualities: intervals over the root.
const QUALITIES := {
	"": {"label": "Major", "intervals": [0, 4, 7], "blurb": "A major triad."},
	"m": {"label": "Minor", "intervals": [0, 3, 7], "blurb": "A minor triad."},
	"dim": {"label": "Diminished", "intervals": [0, 3, 6], "blurb": "Two minor thirds: tense, wanting to move."},
	"aug": {"label": "Augmented", "intervals": [0, 4, 8], "blurb": "Two major thirds: unresolved, dreamlike."},
	"7": {"label": "Dominant seventh", "intervals": [0, 4, 7, 10], "blurb": "A major triad with a flat seventh: it wants home."},
	"maj7": {"label": "Major seventh", "intervals": [0, 4, 7, 11], "blurb": "A major triad with a major seventh: soft and open."},
	"m7": {"label": "Minor seventh", "intervals": [0, 3, 7, 10], "blurb": "A minor triad with a flat seventh: mellow."},
	"sus2": {"label": "Suspended second", "intervals": [0, 2, 7], "blurb": "No third, a second instead: neither major nor minor."},
	"sus4": {"label": "Suspended fourth", "intervals": [0, 5, 7], "blurb": "No third, a fourth instead: it leans toward resolving."},
	"5": {"label": "Power chord", "intervals": [0, 7], "blurb": "A root and a fifth: the electric guitar's chord."},
}


## The pitch classes of the key [param tonic] in [param scale] (a [constant SCALES] key), in order.
static func scale_of(tonic: int, scale: String) -> Array:
	var out: Array = []
	for s in Registry.field(SCALES, scale, "steps", [0, 2, 4, 5, 7, 9, 11]):
		out.append((tonic + int(s)) % 12)
	return out


## The pitch of [param degree] (0 the tonic; past the scale's length it climbs an octave) of the key, in octave
## [param octave] (4 holds middle C).
static func degree_midi(tonic: int, scale: String, degree: int, octave := 4) -> int:
	var steps: Array = Registry.field(SCALES, scale, "steps", [0, 2, 4, 5, 7, 9, 11])
	var n := steps.size()
	var o := floori(float(degree) / n)
	var d := degree - o * n
	return 12 * (octave + 1 + o) + tonic + int(steps[d])


## The triad (or seventh, [param seventh]) on scale degree [param degree] of a key: {root, quality}.
static func diatonic(tonic: int, scale: String, degree: int, seventh := false) -> Dictionary:
	var pcs := scale_of(tonic, scale)
	var n := pcs.size()
	var d := posmod(degree, n)
	var root := int(pcs[d])
	var third := posmod(int(pcs[(d + 2) % n]) - root, 12)
	var fifth := posmod(int(pcs[(d + 4) % n]) - root, 12)
	var q := ""
	if third == 3 and fifth == 6:
		q = "dim"
	elif third == 4 and fifth == 8:
		q = "aug"
	elif third == 3:
		q = "m"
	if seventh and n >= 7:
		var sev := posmod(int(pcs[(d + 6) % n]) - root, 12)
		q = {"": "maj7" if sev == 11 else "7", "m": "m7"}.get(q, q)
	return {"root": root, "quality": q}


## The pitch classes of a chord.
static func chord_pcs(root: int, quality: String) -> Array:
	var out: Array = []
	for i in Registry.field(QUALITIES, quality, "intervals", [0, 4, 7]):
		out.append((root + int(i)) % 12)
	return out


## A chord's name: "Cmaj7", "Dm".
static func chord_name(root: int, quality: String) -> String:
	return String(NAMES[posmod(root, 12)]) + quality


## The nearest pitch to [param near] whose class is [param pc].
static func nearest(pc: int, near: float) -> int:
	var base := int(round(near)) - posmod(int(round(near)) - pc, 12)
	return base + 12 if absf(base + 12 - near) < absf(base - near) else base


## VOICE LEADING: the chord [param pcs] voiced as [param count] pitches within [param lo]..[param hi], each moving as
## little as it can from [param prev] (the last voicing; [] for the first, which is laid close above [param lo]). So a
## pad glides through its changes instead of jumping.
static func voice_lead(prev: Array, pcs: Array, count: int, lo: int, hi: int) -> Array:
	if pcs.is_empty():
		return []
	if prev.is_empty():
		var out: Array = []
		var at := lo
		var k := 0
		while out.size() < count:
			var pc := int(pcs[k % pcs.size()])
			var p := at + posmod(pc - at, 12)
			out.append(p)
			at = p + 1
			k += 1
		return out
	# each old voice to the nearest tone of the new chord, then every tone of the chord at least once where it can be
	var moved: Array = []
	for p in prev:
		var best := 0
		var dist := 99.0
		for pc in pcs:
			var q := nearest(int(pc), float(p))
			if absf(q - float(p)) < dist:
				dist = absf(q - float(p))
				best = q
		moved.append(clampi(best, lo, hi))
	for pc in pcs:
		var has := false
		for p in moved:
			if posmod(int(p), 12) == int(pc):
				has = true
		if not has:
			# the voice whose tone is doubled most moves to this one
			var counts := {}
			for p in moved:
				counts[posmod(int(p), 12)] = int(counts.get(posmod(int(p), 12), 0)) + 1
			for i in moved.size():
				if int(counts[posmod(int(moved[i]), 12)]) > 1:
					moved[i] = clampi(nearest(int(pc), float(moved[i])), lo, hi)
					break
	moved.sort()
	return moved.slice(0, count)


## Toussaint's Euclidean rhythm: [param k] hits spread as evenly as can be over [param n] steps, turned
## [param rotate] steps. E(3,8) is the tresillo, E(5,8) the cinquillo, E(5,16) the bossa nova.
static func euclid(k: int, n: int, rotate := 0) -> Array:
	var out: Array = []
	for i in n:
		out.append(((i * k) % n) < k)
	var turned: Array = []
	for i in n:
		turned.append(out[posmod(i - rotate, n)])
	return turned


## The key written as "C major", "F# dorian" read back: {tonic, scale}; {} when it says neither.
static func parse_key(text: String) -> Dictionary:
	var words := text.strip_edges().split(" ", false)
	if words.is_empty():
		return {}
	var tonic := NAMES.find(String(words[0]).capitalize())
	if tonic < 0:
		var flats := {"Db": 1, "D#": 3, "Gb": 6, "G#": 8, "A#": 10, "Cb": 11, "E#": 5, "Fb": 4, "B#": 0}
		tonic = int(flats.get(String(words[0]), -1))
	if tonic < 0:
		return {}
	var scale := "major" if words.size() < 2 else String(words[1]).to_lower().replace(" ", "_")
	return {"tonic": tonic, "scale": scale if SCALES.has(scale) else "major"}


## The key as words: "C major".
static func key_name(tonic: int, scale: String) -> String:
	return "%s %s" % [NAMES[posmod(tonic, 12)], Registry.label(SCALES, scale).to_lower()]
