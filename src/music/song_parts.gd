extends RefCounted
class_name SongParts

## SongParts - what a composed Sound is made of, as rows (next/music.md, "The bank"): its parts ([constant PARTS]: a
## drum kit, a bass, keys, a pad, a guitar, a lead, bells, a voice), the patterns each can play ([constant PATTERNS]),
## the progressions its harmony walks ([constant PROGRESSIONS]) and the kinds of section a song has
## ([constant SECTIONS]: who plays in each). The composer ([Composer]) reads them; the Sound card offers them.
##
## A drum pattern is a bar of sixteenths a hit (`X` accented, `x` played, `o` soft, `.` rest). A pattern of any part
## named `reference` takes the part from the song a Sound imported ([member Composer] reads the reference).

## The parts: the instrument and pattern each starts with, its register (MIDI, low to high), its level (dB) and pan,
## and its effects (the music host's: hosts/music/render.py).
const PARTS := {
	"drums": {"label": "Drums", "blurb": "A drum kit: kick, snare, hats, toms and cymbals.", "instrument": "kit_band",
		"pattern": "backbeat", "register": [0, 0], "level": -2.0, "pan": 0.0, "fx": {"reverb": 0.08}},
	"bass": {"label": "Bass", "blurb": "The low line under the chords: their roots, and the notes between.", "instrument": "synth_bass",
		"pattern": "root_eighths", "register": [28, 52], "level": -4.0, "pan": 0.0, "fx": {}},
	"keys": {"label": "Keys", "blurb": "The chords played in a rhythm: an electric piano, an organ, a bell.", "instrument": "epiano",
		"pattern": "offbeat_stabs", "register": [55, 79], "level": -9.0, "pan": -0.25, "fx": {"reverb": 0.25}},
	"pad": {"label": "Pad", "blurb": "The chords held long and soft under everything, gliding from one to the next.",
		"instrument": "warm_pad", "pattern": "held", "register": [52, 76], "level": -13.0, "pan": 0.0,
		"fx": {"reverb": 0.4, "chorus": 0.4}},
	"guitar": {"label": "Guitar", "blurb": "A guitar: power chords driven through an amp, or a clean strum.",
		"instrument": "drive_guitar", "pattern": "power_eighths", "register": [40, 64], "level": -11.0, "pan": 0.3,
		"fx": {"reverb": 0.12}},
	"lead": {"label": "Lead", "blurb": "A melody of its own where nobody sings: a motif, developed.", "instrument": "saw_lead",
		"pattern": "motif", "register": [64, 88], "level": -10.0, "pan": 0.1,
		"fx": {"reverb": 0.3, "delay": {"beats": 0.75, "feedback": 0.3, "mix": 0.2}}},
	"bells": {"label": "Bells", "blurb": "A few struck notes with long tails, here and there.", "instrument": "bell",
		"pattern": "sparse", "register": [72, 96], "level": -18.0, "pan": -0.4, "fx": {"reverb": 0.5}},
	"vocal": {"label": "Voice", "blurb": "The note's words sung: its verses and choruses on a melody, by one voice.",
		"instrument": "", "pattern": "reference", "register": [48, 76], "level": 0.0, "pan": 0.0,
		"fx": {"reverb": 0.18, "delay": {"beats": 0.5, "feedback": 0.2, "mix": 0.08}}},
}

const PATTERNS := {
	# drums
	"backbeat": {"label": "Backbeat", "part": "drums", "blurb": "Rock and pop's beat: the kick on one and three, the snare on two and four.",
		"steps": {"kick": "X.......x.x.....", "snare": "....X.......X...", "hat": "x.x.x.x.x.x.x.x."}},
	"four_floor": {"label": "Four on the floor", "part": "drums", "blurb": "House and disco: a kick every beat, the clap on two and four, open hats between.",
		"steps": {"kick": "X...X...X...X...", "clap": "....X.......X...", "open_hat": "..x...x...x...x.", "hat": "o.o.o.o.o.o.o.o."}},
	"half_time": {"label": "Half time", "part": "drums", "blurb": "The snare on three alone: everything feels twice as slow and heavy.",
		"steps": {"kick": "X.........x.....", "snare": "........X.......", "hat": "x.x.x.x.x.x.x.x."}},
	"motorik": {"label": "Motorik", "part": "drums", "blurb": "Krautrock's endless road: a steady kick, a snare on the backbeat, a hat every sixteenth.",
		"steps": {"kick": "X...x...X...x...", "snare": "....X.......X...", "hat": "xoxoxoxoxoxoxoxo"}},
	"boom_bap": {"label": "Boom bap", "part": "drums", "blurb": "Hip hop's swung beat: the kick skipping, the snare hard on two and four.",
		"steps": {"kick": "X......x..x.....", "snare": "....X.......X...", "hat": "x.x.x.x.x.x.x.x."}, "swing": 0.58},
	"reference": {"label": "From the reference", "part": "", "blurb": "Taken from the song imported: its drum pattern, its bass, its melody.",
		"steps": {}},
	# bass
	"root_eighths": {"label": "Root eighths", "part": "bass", "blurb": "The chord's root on every eighth note, jumping an octave now and then: driving.",
		"steps": {}},
	"root_fifth": {"label": "Root and fifth", "part": "bass", "blurb": "The root on one, the fifth on three: country, folk, a march.", "steps": {}},
	"follow_kick": {"label": "With the kick", "part": "bass", "blurb": "A note wherever the kick drum hits: locked to the beat.", "steps": {}},
	"walking": {"label": "Walking", "part": "bass", "blurb": "A note every beat, chord tones and the step leading to the next chord: jazz.", "steps": {}},
	"drone": {"label": "Drone", "part": "bass", "blurb": "Each chord's root held as long as it lasts.", "steps": {}},
	# keys
	"offbeat_stabs": {"label": "Offbeat stabs", "part": "keys", "blurb": "Short chords on the offbeats: ska, reggae, funk.", "steps": {}},
	"block": {"label": "Block chords", "part": "keys", "blurb": "Each chord struck once and held: hymns, ballads.", "steps": {}},
	"syncopated": {"label": "Syncopated", "part": "keys", "blurb": "Chords on an even spread of the bar's sixteenths (a Euclidean rhythm): tresillo, cinquillo.", "steps": {}},
	"arpeggio": {"label": "Arpeggio", "part": "keys", "blurb": "The chord's notes one at a time, up and down, on the sixteenths.", "steps": {}},
	# pad
	"held": {"label": "Held chords", "part": "pad", "blurb": "Each chord held for as long as it lasts, its voices moving as little as they can.", "steps": {}},
	# guitar
	"power_eighths": {"label": "Power eighths", "part": "guitar", "blurb": "A root, fifth and octave on every eighth note, damped short: rock's engine.", "steps": {}},
	"strum": {"label": "Strum", "part": "guitar", "blurb": "Chords strummed down and up in a folk pattern.", "steps": {"strum": "x.x..x.xx.x..x.x"}},
	# lead
	"motif": {"label": "Motif", "part": "lead", "blurb": "A short tune of its own, repeated and varied: moved up, turned over, answered.", "steps": {}},
	# bells
	"sparse": {"label": "Sparse", "part": "bells", "blurb": "A chord tone now and then, left to ring.", "steps": {}},
	# vocal
	"composed": {"label": "Composed", "part": "vocal", "blurb": "A melody made for the words: stressed syllables on strong beats, chord tones there, a contour each line, answering lines.",
		"steps": {}},
	"recite": {"label": "Recited", "part": "vocal", "blurb": "A psalm tone: the words recited on one note, turning at the end of each line.", "steps": {}},
}

## Progressions as scale degrees (0 the tonic), a chord a bar.
const PROGRESSIONS := {
	"pop": {"label": "I-V-vi-IV", "degrees": [0, 4, 5, 3], "blurb": "The four chords of a thousand pop songs."},
	"sensitive": {"label": "vi-IV-I-V", "degrees": [5, 3, 0, 4], "blurb": "The same four turned to start on the minor: wistful."},
	"fifties": {"label": "I-vi-IV-V", "degrees": [0, 5, 3, 4], "blurb": "Doo-wop's turnaround."},
	"plagal": {"label": "I-IV", "degrees": [0, 3], "blurb": "Two chords swaying: gospel, a hymn's amen."},
	"dorian_vamp": {"label": "i-IV", "degrees": [0, 3], "blurb": "A minor chord and the major chord a fourth up: funk and soul's vamp."},
	"andalusian": {"label": "i-VII-VI-V", "degrees": [0, 6, 5, 4], "blurb": "Flamenco's descent."},
	"pedal": {"label": "One chord", "degrees": [0], "blurb": "The tonic alone: a drone, a vamp, a trance."},
}

## The kinds of section, and who plays in each (a part not listed rests there).
const SECTIONS := {
	"intro": {"label": "Intro", "blurb": "Before the voice: the place set.", "parts": ["pad", "keys", "bells", "drums"], "energy": 0.4},
	"verse": {"label": "Verse", "blurb": "The story told: the band settled under the voice.", "parts": ["drums", "bass", "keys", "pad", "vocal"], "energy": 0.6},
	"chorus": {"label": "Chorus", "blurb": "The refrain: everything in, the guitar too.", "parts": ["drums", "bass", "keys", "pad", "guitar", "vocal"], "energy": 1.0},
	"bridge": {"label": "Bridge", "blurb": "Somewhere else for a while.", "parts": ["bass", "pad", "keys", "vocal", "drums"], "energy": 0.7},
	"break": {"label": "Break", "blurb": "Between the voice's sections: the lead takes the melody.", "parts": ["drums", "bass", "keys", "pad", "guitar", "lead"], "energy": 0.8},
	"outro": {"label": "Outro", "blurb": "After the voice: the band thins away.", "parts": ["pad", "keys", "bass", "bells"], "energy": 0.4},
}


## The patterns part [param part] may play, `reference` first where [param has_reference].
static func patterns_for(part: String, has_reference := false) -> Array:
	var out: Array = []
	if has_reference and part in ["drums", "bass", "vocal"]:
		out.append("reference")
	for k in PATTERNS:
		if String(PATTERNS[k]["part"]) == part:
			out.append(k)
	return out


## The hits of a drum pattern row, `{hit: [velocity a sixteenth, 0 for none]}`.
static func drum_steps(pattern: String) -> Dictionary:
	var out := {}
	var steps: Dictionary = Registry.field(PATTERNS, pattern, "steps", {})
	for hit in steps:
		var row: Array = []
		for ch in String(steps[hit]):
			row.append({"X": 1.0, "x": 0.8, "o": 0.45}.get(ch, 0.0))
		out[hit] = row
	return out
