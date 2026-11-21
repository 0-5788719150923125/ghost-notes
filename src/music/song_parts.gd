extends RefCounted
class_name SongParts

## SongParts - what a composed Sound is made of, as rows (next/music.md, "The bank"): its parts ([constant PARTS]: a
## drum kit, a bass, keys, a pad, a guitar, a lead, bells, a voice), the patterns each can play ([constant PATTERNS]),
## the progressions its harmony walks ([constant PROGRESSIONS]) and the kinds of section a song has
## ([constant SECTIONS]: who plays in each). The composer ([Composer]) reads them; the Sound card offers them.
##
## A drum pattern is a bar of sixteenths a hit (`X` accented, `x` played, `o` soft, `.` rest). A pattern of any part
## named `reference` takes the part from the song a Sound imported ([member Composer] reads the reference).
##
## THE BEAT LEADS: a pattern, an instrument ([Instruments]) and a progression name the `styles` they belong to, and a
## roll favors the rows that share one with the drums' pattern - so a song drawn hangs together, and pinning the beat
## steers the rest. A drum pattern also names its `tempo` range (what a roll draws the tempo in), its feel (`swing`,
## where the song's eighths fall, or `straight`; `swing16`, its own sixteenths' lilt), how hard its kick pumps the pad
## and bass (`duck`) and whether its hats roll (`rolls`). A pattern that is `snappy` plays its instrument with a quick
## attack and release. A progression names the `modes` it is written for (none: any), a `quality` every chord takes,
## `sevenths`, and `bars` a chord where its rhythm is fixed.

## The parts: the instrument and pattern each starts with, its register (MIDI, low to high), its level (dB) and pan,
## and its effects (the music host's: hosts/music/render.py).
const PARTS := {
	"drums": {"label": "Drums", "blurb": "A drum kit: kick, snare, hats, toms and cymbals.", "instrument": "kit_band",
		"pattern": "backbeat", "register": [0, 0], "level": -2.0, "pan": 0.0, "fx": {"reverb": 0.08}},
	"bass": {"label": "Bass", "blurb": "The low line under the chords: their roots, and the notes between.", "instrument": "synth_bass",
		"pattern": "root_eighths", "register": [28, 52], "level": -4.0, "pan": 0.0, "fx": {}},
	"keys": {"label": "Keys", "blurb": "The chords played in a rhythm: a piano, an organ, a synth, a bell.", "instrument": "epiano",
		"pattern": "offbeat_stabs", "register": [55, 79], "level": -9.0, "pan": -0.25, "fx": {"reverb": 0.25}},
	"pad": {"label": "Pad", "blurb": "The chords held long and soft under everything, gliding from one to the next.",
		"instrument": "warm_pad", "pattern": "held", "register": [52, 76], "level": -13.0, "pan": 0.0,
		"fx": {"reverb": 0.4, "chorus": 0.4}},
	"guitar": {"label": "Guitar", "blurb": "A guitar: power chords driven through an amp, a clean strum, a riff.",
		"instrument": "drive_guitar", "pattern": "power_eighths", "register": [40, 64], "level": -11.0, "pan": 0.3,
		"fx": {"reverb": 0.12}},
	"lead": {"label": "Lead", "blurb": "A melody of its own where nobody sings: a motif, a riff, an arpeggio.", "instrument": "saw_lead",
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
		"steps": {"kick": "X.......x.x.....", "snare": "....X.......X...", "hat": "x.x.x.x.x.x.x.x."},
		"styles": ["rock", "pop"], "tempo": [86, 132]},
	"four_floor": {"label": "Four on the floor", "part": "drums", "blurb": "House and disco: a kick every beat, the clap on two and four, open hats between.",
		"steps": {"kick": "X...X...X...X...", "clap": "....X.......X...", "open_hat": "..x...x...x...x.", "hat": "o.o.o.o.o.o.o.o."},
		"styles": ["edm", "funk", "pop"], "tempo": [118, 130], "straight": true, "duck": 0.55},
	"half_time": {"label": "Half time", "part": "drums", "blurb": "The snare on three alone: everything feels twice as slow and heavy.",
		"steps": {"kick": "X.........x.....", "snare": "........X.......", "hat": "x.x.x.x.x.x.x.x."},
		"styles": ["ballad", "hiphop", "rock"], "tempo": [64, 88]},
	"motorik": {"label": "Motorik", "part": "drums", "blurb": "Krautrock's endless road: a steady kick, a snare on the backbeat, a hat every sixteenth.",
		"steps": {"kick": "X...x...X...x...", "snare": "....X.......X...", "hat": "xoxoxoxoxoxoxoxo"},
		"styles": ["rock", "edm"], "tempo": [112, 140], "straight": true},
	"boom_bap": {"label": "Boom bap", "part": "drums", "blurb": "Hip hop's swung beat: the kick skipping, the snare hard on two and four.",
		"steps": {"kick": "X......x..x.....", "snare": "....X.......X...", "hat": "x.x.x.x.x.x.x.x."}, "swing16": 0.58,
		"styles": ["hiphop"], "tempo": [84, 98]},
	"pop_sixteenths": {"label": "Pop sixteenths", "part": "drums", "blurb": "Pop's busy beat: the kick on one, the and of two and three, the snare on two and four, a hat every sixteenth.",
		"steps": {"kick": "X.....x.X.......", "snare": "....X.......X...", "hat": "xoxoxoxoxoxoxoxo"},
		"styles": ["pop", "funk"], "tempo": [96, 124], "straight": true},
	"rock_drive": {"label": "Driving rock", "part": "drums", "blurb": "The kick pushing on the eighths, the snare hard on two and four, the hats accented on the beat: arena rock.",
		"steps": {"kick": "X.x...x.X.x...x.", "snare": "....X.......X...", "hat": "X.x.X.x.X.x.X.x."},
		"styles": ["rock"], "tempo": [118, 152], "straight": true},
	"punk": {"label": "Punk", "part": "drums", "blurb": "The kick on every beat, the snare on every offbeat, flat out: punk's two-beat.",
		"steps": {"kick": "X...X...X...X...", "snare": "..X...X...X...X.", "hat": "x.x.x.x.x.x.x.x."},
		"styles": ["rock"], "tempo": [160, 196], "straight": true},
	"shuffle": {"label": "Shuffle", "part": "drums", "blurb": "Blues and boogie's lilt: the ride long-short in triplets, the snare on two and four, the hat's foot with it.",
		"steps": {"kick": "X.....x.X.....x.", "snare": "....X.......X...", "ride": "x.x.x.x.x.x.x.x.", "hat": "....o.......o..."},
		"swing": 0.67, "styles": ["blues", "rock"], "tempo": [84, 128]},
	"trap": {"label": "Trap", "part": "drums", "blurb": "The clap on three, the kick skipping like an 808, the hats in sixteenths breaking into rolls.",
		"steps": {"kick": "X......X..X.....", "clap": "........X.......", "hat": "x.x.x.x.xxx.x.xx"},
		"styles": ["hiphop"], "tempo": [130, 150], "straight": true, "rolls": true, "duck": 0.35},
	"two_step": {"label": "Two-step", "part": "drums", "blurb": "Drum and bass's break: the kick on one and the and of three, the snare on two and four, fast.",
		"steps": {"kick": "X.........X.....", "snare": "....X.......X...", "hat": "x.x.x.x.x.x.x.x."},
		"styles": ["edm"], "tempo": [164, 178], "straight": true},
	"dembow": {"label": "Dembow", "part": "drums", "blurb": "Reggaeton's beat: the kick on every beat, the snare tumbling three, three and two against it.",
		"steps": {"kick": "X...X...X...X...", "snare": "...X..X....X..X.", "hat": "x.x.x.x.x.x.x.x."},
		"styles": ["latin", "pop"], "tempo": [88, 102], "straight": true},
	"funk": {"label": "Funk", "part": "drums", "blurb": "The one hit hard, the kick syncopated, ghost notes on the snare between the backbeats, hats in sixteenths.",
		"steps": {"kick": "X.....X...X.x...", "snare": "....X..o.o..X..o", "hat": "xoxoxoxoxoxoxoxo"},
		"styles": ["funk"], "tempo": [92, 116]},
	"disco": {"label": "Disco", "part": "drums", "blurb": "The kick on every beat, the snare on two and four, the hat opening on every offbeat: the seventies' floor.",
		"steps": {"kick": "X...X...X...X...", "snare": "....X.......X...", "open_hat": "..x...x...x...x.", "hat": "xoxoxoxoxoxoxoxo"},
		"styles": ["funk", "edm", "pop"], "tempo": [112, 126], "straight": true, "duck": 0.45},
	"breakbeat": {"label": "Breakbeat", "part": "drums", "blurb": "A broken beat: the kick off the grid, the snare on two and four with a skip between: big beat, breaks.",
		"steps": {"kick": "X.........X.X...", "snare": "....X..x.x..X...", "hat": "x.x.x.x.x.x.x.x."},
		"styles": ["edm", "hiphop"], "tempo": [124, 140]},
	"ballad": {"label": "Ballad", "part": "drums", "blurb": "Sparse and soft: the kick on one and three, a rim click on two and four, the hats on the beat.",
		"steps": {"kick": "X.......X.......", "rim": "....x.......x...", "hat": "o...o...o...o..."},
		"styles": ["ballad", "pop", "folk"], "tempo": [62, 84]},
	"train": {"label": "Train beat", "part": "drums", "blurb": "Country's train: the snare in sixteenths, accented on two and four, the kick on one and three.",
		"steps": {"kick": "X.......X.......", "snare": "ooxoXoxoooxoXoxo", "hat": "....x.......x..."},
		"styles": ["folk"], "tempo": [104, 144], "straight": true},
	"reference": {"label": "From the reference", "part": "", "blurb": "Taken from the song imported: its drum pattern, its bass, its melody.",
		"steps": {}},
	# bass
	"root_eighths": {"label": "Root eighths", "part": "bass", "blurb": "The chord's root on every eighth note, jumping an octave now and then: driving.",
		"steps": {}, "styles": ["rock", "pop", "edm"]},
	"root_fifth": {"label": "Root and fifth", "part": "bass", "blurb": "The root on one, the fifth on three: country, folk, a march.", "steps": {},
		"styles": ["folk", "latin", "pop"]},
	"follow_kick": {"label": "With the kick", "part": "bass", "blurb": "A note wherever the kick drum hits: locked to the beat.", "steps": {},
		"styles": ["pop", "hiphop", "funk", "rock"]},
	"walking": {"label": "Walking", "part": "bass", "blurb": "A note every beat, chord tones and the step leading to the next chord: jazz.", "steps": {},
		"styles": ["jazz", "blues"]},
	"drone": {"label": "Drone", "part": "bass", "blurb": "Each chord's root held as long as it lasts.", "steps": {}, "styles": ["ballad", "edm"]},
	"octaves": {"label": "Octaves", "part": "bass", "blurb": "The root and its octave in turn on the eighths: disco's and house's bounce.", "steps": {},
		"styles": ["funk", "edm", "pop"]},
	"offbeat": {"label": "Offbeat", "part": "bass", "blurb": "A note on every offbeat, between the kicks: house and trance's pump.", "steps": {},
		"styles": ["edm"]},
	"boogie": {"label": "Boogie", "part": "bass", "blurb": "Up the chord and back on the eighths - root, third, fifth, sixth, flat seventh: boogie-woogie, blues, rock and roll.",
		"steps": {}, "styles": ["blues", "rock"]},
	"gallop": {"label": "Gallop", "part": "bass", "blurb": "An eighth and two sixteenths on every beat, on the root: a charge, metal's gallop.", "steps": {},
		"styles": ["rock"]},
	"slap": {"label": "Slap", "part": "bass", "blurb": "Funk's line: the root on the one, octaves popped on the sixteenths between, the fifth now and then.", "steps": {},
		"styles": ["funk"]},
	"glide": {"label": "808 glide", "part": "bass", "blurb": "Long notes on the kick, sliding into each other: trap's 808.", "steps": {},
		"styles": ["hiphop"]},
	"rolling": {"label": "Rolling", "part": "bass", "blurb": "The root on every sixteenth, the beats accented: drum and bass, trance.", "steps": {},
		"styles": ["edm"]},
	# keys
	"offbeat_stabs": {"label": "Offbeat stabs", "part": "keys", "blurb": "Short chords on the offbeats: ska, reggae, funk.", "steps": {},
		"styles": ["reggae", "funk", "edm"]},
	"block": {"label": "Block chords", "part": "keys", "blurb": "Each chord struck once and held: hymns, ballads.", "steps": {},
		"styles": ["ballad", "pop", "rock"]},
	"syncopated": {"label": "Syncopated", "part": "keys", "blurb": "Chords on an even spread of the bar's sixteenths (a Euclidean rhythm): tresillo, cinquillo.", "steps": {},
		"styles": ["latin", "funk"]},
	"arpeggio": {"label": "Arpeggio", "part": "keys", "blurb": "The chord's notes one at a time, up and down, on the sixteenths.", "steps": {},
		"styles": ["edm", "ballad"]},
	"pounding": {"label": "Quarter chords", "part": "keys", "blurb": "A chord on every beat, struck hard: pop piano, a rock song's drive.", "steps": {},
		"styles": ["pop", "rock"]},
	"anthem": {"label": "Anthem", "part": "keys", "blurb": "Chords in three, three and two across each half bar: a dance anthem's stabs.", "steps": {},
		"styles": ["edm", "pop"], "snappy": true},
	"broken": {"label": "Broken chords", "part": "keys", "blurb": "The root low, then the chord's notes rising and falling in eighths: a ballad's piano.", "steps": {},
		"styles": ["ballad", "pop", "folk"]},
	"comp": {"label": "Shuffle comp", "part": "keys", "blurb": "Short chords on the and of two and four, swung: blues and jazz comping.", "steps": {},
		"styles": ["blues", "jazz"]},
	# pad
	"held": {"label": "Held chords", "part": "pad", "blurb": "Each chord held for as long as it lasts, its voices moving as little as they can.", "steps": {},
		"styles": ["ballad", "pop", "rock", "folk", "blues", "jazz"]},
	"gated": {"label": "Gated", "part": "pad", "blurb": "The chord chopped into sixteenths in a pattern: trance's gate.", "steps": {},
		"styles": ["edm"], "snappy": true},
	# guitar
	"power_eighths": {"label": "Power eighths", "part": "guitar", "blurb": "A root, fifth and octave on every eighth note, damped short: rock's engine.", "steps": {},
		"styles": ["rock", "pop"]},
	"strum": {"label": "Strum", "part": "guitar", "blurb": "Chords strummed down and up in a folk pattern.", "steps": {"strum": "x.x..x.xx.x..x.x"},
		"styles": ["folk", "pop", "latin"]},
	"palm_mute": {"label": "Palm-muted", "part": "guitar", "blurb": "Power chords chugged in sixteenths, the palm on the strings, the beats accented: punk and metal.", "steps": {},
		"styles": ["rock"]},
	"power_held": {"label": "Held power chords", "part": "guitar", "blurb": "Each chord's power chord struck and left ringing: a big chorus.", "steps": {},
		"styles": ["rock", "pop"]},
	"shuffle_riff": {"label": "Shuffle riff", "part": "guitar", "blurb": "The root and fifth, then the root and sixth, rocking on the eighths: the blues' and rock and roll's riff.", "steps": {},
		"styles": ["blues", "rock"]},
	"scratch": {"label": "Funk scratch", "part": "guitar", "blurb": "Muted strings scratched in sixteenths, the chord struck on the offbeats between: funk's rhythm guitar.", "steps": {},
		"styles": ["funk"]},
	"picked": {"label": "Picked", "part": "guitar", "blurb": "The chord's notes picked one at a time on the eighths, left ringing: a ballad's guitar.", "steps": {},
		"styles": ["ballad", "folk", "pop"]},
	"skank": {"label": "Skank", "part": "guitar", "blurb": "Short chords on every offbeat, the upstroke: reggae and ska.", "steps": {},
		"styles": ["reggae"]},
	# lead
	"motif": {"label": "Motif", "part": "lead", "blurb": "A short tune of its own, repeated and varied: moved up, turned over, answered.", "steps": {}},
	"riff": {"label": "Riff", "part": "lead", "blurb": "A one-bar riff on the pentatonic, moved with the chords and repeated: rock, blues, funk.", "steps": {},
		"styles": ["rock", "blues", "funk"]},
	"arp_lead": {"label": "Arpeggiator", "part": "lead", "blurb": "The chord's notes in sixteenths, up two octaves and over: trance and synth-pop.", "steps": {},
		"styles": ["edm", "pop"], "snappy": true},
	# bells
	"sparse": {"label": "Sparse", "part": "bells", "blurb": "A chord tone now and then, left to ring.", "steps": {}},
	# vocal
	"composed": {"label": "Composed", "part": "vocal", "blurb": "A melody made for the words: stressed syllables on strong beats, chord tones there, a contour each line, answering lines.",
		"steps": {}},
	"recite": {"label": "Recited", "part": "vocal", "blurb": "A psalm tone: the words recited on one note, turning at the end of each line.", "steps": {}},
}

## Progressions as scale degrees (0 the tonic), a chord a bar.
const PROGRESSIONS := {
	"pop": {"label": "I-V-vi-IV", "degrees": [0, 4, 5, 3], "blurb": "The four chords of a thousand pop songs.",
		"modes": ["major", "mixolydian", "lydian"], "styles": ["pop", "edm", "rock", "ballad"]},
	"sensitive": {"label": "vi-IV-I-V", "degrees": [5, 3, 0, 4], "blurb": "The same four turned to start on the minor: wistful.",
		"modes": ["major"], "styles": ["pop", "edm", "ballad"]},
	"fifties": {"label": "I-vi-IV-V", "degrees": [0, 5, 3, 4], "blurb": "Doo-wop's turnaround.", "modes": ["major"], "styles": ["ballad", "pop"]},
	"plagal": {"label": "I-IV", "degrees": [0, 3], "blurb": "Two chords swaying: gospel, a hymn's amen.", "styles": ["folk", "rock", "ballad"]},
	"dorian_vamp": {"label": "i-IV", "degrees": [0, 3], "blurb": "A minor chord and the major chord a fourth up: funk and soul's vamp.",
		"modes": ["dorian"], "styles": ["funk", "latin"]},
	"andalusian": {"label": "i-VII-VI-V", "degrees": [0, 6, 5, 4], "blurb": "Flamenco's descent.", "modes": ["minor"], "styles": ["latin", "rock"]},
	"pedal": {"label": "One chord", "degrees": [0], "blurb": "The tonic alone: a drone, a vamp, a trance.", "styles": ["edm", "funk"]},
	"rock": {"label": "I-IV-V-IV", "degrees": [0, 3, 4, 3], "blurb": "Three chords and the truth: rock and roll, country, punk.",
		"modes": ["major", "mixolydian"], "styles": ["rock", "folk", "blues"]},
	"mixolydian": {"label": "I-bVII-IV-I", "degrees": [0, 6, 3, 0], "blurb": "The flat seventh's chord on the way down: classic rock's swagger.",
		"modes": ["mixolydian"], "styles": ["rock"]},
	"epic": {"label": "i-VI-III-VII", "degrees": [0, 5, 2, 6], "blurb": "The minor loop of trance, film and stadium anthems.",
		"modes": ["minor"], "styles": ["edm", "pop", "rock"]},
	"minor_rise": {"label": "i-VI-VII", "degrees": [0, 5, 6, 6], "blurb": "Up from the minor in two steps, held on the last: rock's and dance music's climb.",
		"modes": ["minor"], "styles": ["rock", "edm", "pop"]},
	"descent": {"label": "i-VII-VI-VII", "degrees": [0, 6, 5, 6], "blurb": "A step down and back up, again and again: dark and driving.",
		"modes": ["minor"], "styles": ["edm", "rock"]},
	"minor_sway": {"label": "i-VI", "degrees": [0, 5], "blurb": "The minor and the chord a third below it, swaying: hip hop, a slow dance.",
		"modes": ["minor"], "styles": ["hiphop", "edm", "ballad"]},
	"twelve_bar": {"label": "Twelve-bar blues", "degrees": [0, 0, 0, 0, 3, 3, 0, 0, 4, 3, 0, 4], "quality": "7", "bars": 1,
		"blurb": "Four bars home, two away, two home, the turn and back: every chord a dominant seventh.",
		"modes": ["major", "mixolydian"], "styles": ["blues", "rock"]},
	"minor_blues": {"label": "Minor blues", "degrees": [0, 0, 0, 0, 3, 3, 0, 0, 4, 3, 0, 4], "quality": "m7", "bars": 1,
		"blurb": "The twelve bars in minor, every chord a minor seventh: slow and late.", "modes": ["minor"], "styles": ["blues", "jazz"]},
	"two_five": {"label": "ii-V-I", "degrees": [1, 4, 0, 0], "sevenths": true, "blurb": "Jazz's cadence, in sevenths: the step home.",
		"modes": ["major"], "styles": ["jazz", "funk"]},
	"royal": {"label": "IV-V-iii-vi", "degrees": [3, 4, 2, 5], "blurb": "The royal road: a climb that never lands, pop's and anime's lift.",
		"modes": ["major"], "styles": ["pop", "edm", "ballad"]},
	"circle": {"label": "vi-ii-V-I", "degrees": [5, 1, 4, 0], "sevenths": true, "blurb": "Round the circle of fifths to home: standards and soul.",
		"modes": ["major"], "styles": ["jazz", "pop", "ballad"]},
	"funk_vamp": {"label": "I7", "degrees": [0], "quality": "7", "blurb": "One dominant seventh, played forever: funk's vamp.",
		"modes": ["mixolydian"], "styles": ["funk"]},
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


## The progressions written for mode [param scale] (a progression naming no `modes` suits any).
static func progressions_for(scale: String) -> Array:
	return PROGRESSIONS.keys().filter(func(k: String) -> bool:
		var modes: Array = Registry.field(PROGRESSIONS, k, "modes", [])
		return modes.is_empty() or modes.has(scale))


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
