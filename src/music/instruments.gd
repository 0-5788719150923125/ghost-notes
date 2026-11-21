extends RefCounted
class_name Instruments

## Instruments - every instrument a composed Sound plays, as rows (next/music.md, "The instruments"): how it is made
## (`method`, the music host's: hosts/music/instruments.py) and that method's settings (`params`), with the ranges its
## seed draws some of them from (`vary`: a dotted path into `params` -> [low, high]). Two seeds of one row are siblings,
## never strangers. No samples: every sound is oscillators, noise and filters.
##
## `parts` says which parts of a song a row suits ([constant SongParts.PARTS]); a part is offered those rows. `styles`
## are the kinds of song it belongs to: a roll favors the rows sharing one with the drums' pattern ([SongParts]).

const ROWS := {
	# drums
	"kit_808": {"label": "808 kit", "method": "kit", "parts": ["drums"], "styles": ["hiphop", "pop", "funk"],
		"blurb": "The drum machine hip hop grew up on: a long booming kick, a soft snare, ticking hats.",
		"params": {"kick": {"pitch": 46.0, "sweep": 2.4, "decay": 0.55, "click": 0.15, "drive": 0.3},
			"snare": {"tone": 180.0, "body": 0.06, "decay": 0.16, "snap": 0.9, "tone_mix": 0.6},
			"hat": {"decay": 0.035, "open": 0.25, "metal": 0.7}, "clap": {"tone": 1000.0, "decay": 0.18}, "tom": {"tune": 0.9}},
		"vary": {"kick.pitch": [42.0, 52.0], "kick.decay": [0.4, 0.7], "snare.tone": [165.0, 205.0], "hat.decay": [0.025, 0.05]}},
	"kit_909": {"label": "909 kit", "method": "kit", "parts": ["drums"], "styles": ["edm", "funk"],
		"blurb": "House and techno's machine: a punchy kick with a click, a bright snare, crisp hats.",
		"params": {"kick": {"pitch": 52.0, "sweep": 2.0, "decay": 0.35, "click": 0.45, "drive": 0.35},
			"snare": {"tone": 200.0, "body": 0.05, "decay": 0.2, "snap": 1.1, "tone_mix": 0.4},
			"hat": {"decay": 0.045, "open": 0.3, "metal": 0.5}, "clap": {"tone": 1200.0, "decay": 0.15}, "tom": {"tune": 1.0}},
		"vary": {"kick.pitch": [48.0, 56.0], "kick.click": [0.3, 0.6], "snare.decay": [0.15, 0.25], "hat.metal": [0.3, 0.7]}},
	"kit_band": {"label": "Band kit", "method": "kit", "parts": ["drums"], "styles": ["rock", "pop", "funk", "blues", "folk", "ballad", "jazz", "latin", "reggae"],
		"blurb": "A drummer's kit, played close: a tight kick, a cracking snare with its wires, toms and cymbals.",
		"params": {"kick": {"pitch": 58.0, "sweep": 1.3, "decay": 0.28, "click": 0.6, "drive": 0.2},
			"snare": {"tone": 210.0, "body": 0.05, "decay": 0.22, "snap": 1.3, "tone_mix": 0.45, "low": 1500.0, "high": 9500.0},
			"hat": {"decay": 0.055, "open": 0.35, "metal": 0.4}, "crash": {"decay": 1.6}, "ride": {"decay": 1.0}, "tom": {"tune": 1.05}},
		"vary": {"kick.pitch": [54.0, 64.0], "snare.tone": [190.0, 230.0], "snare.decay": [0.18, 0.28], "tom.tune": [0.9, 1.15]}},
	"kit_rock": {"label": "Rock kit", "method": "kit", "parts": ["drums"], "styles": ["rock", "blues"],
		"blurb": "A big kit in a big room: a deep kick, a fat snare ringing out, long crashes.",
		"params": {"kick": {"pitch": 50.0, "sweep": 1.5, "decay": 0.4, "click": 0.5, "drive": 0.3},
			"snare": {"tone": 175.0, "body": 0.07, "decay": 0.3, "snap": 1.2, "tone_mix": 0.65, "low": 1200.0, "high": 8000.0, "drive": 0.2},
			"hat": {"decay": 0.06, "open": 0.4, "metal": 0.45}, "crash": {"decay": 2.0}, "ride": {"decay": 1.3}, "tom": {"tune": 0.9}},
		"vary": {"kick.pitch": [46.0, 56.0], "snare.tone": [160.0, 190.0], "snare.decay": [0.25, 0.36]}},
	"kit_edm": {"label": "Festival kit", "method": "kit", "parts": ["drums"], "styles": ["edm", "pop"],
		"blurb": "A kick driven hard enough to fill a field, a wide clap, bright hats: big-room dance music.",
		"params": {"kick": {"pitch": 48.0, "sweep": 2.6, "decay": 0.45, "click": 0.5, "drive": 0.75},
			"snare": {"tone": 200.0, "body": 0.04, "decay": 0.18, "snap": 1.2, "tone_mix": 0.35},
			"hat": {"decay": 0.04, "open": 0.32, "metal": 0.55}, "clap": {"tone": 1100.0, "decay": 0.26, "spread": 0.014},
			"crash": {"decay": 1.8}, "tom": {"tune": 1.0}},
		"vary": {"kick.pitch": [44.0, 54.0], "kick.drive": [0.6, 0.9], "clap.decay": [0.2, 0.32]}},
	"kit_trap": {"label": "Trap kit", "method": "kit", "parts": ["drums"], "styles": ["hiphop"],
		"blurb": "A kick that booms like an 808 bass, a short snappy clap, tight sizzling hats.",
		"params": {"kick": {"pitch": 44.0, "sweep": 2.2, "decay": 0.85, "click": 0.2, "drive": 0.5},
			"snare": {"tone": 230.0, "body": 0.04, "decay": 0.12, "snap": 1.4, "tone_mix": 0.3},
			"hat": {"decay": 0.022, "open": 0.2, "metal": 0.8, "tune": 1.15}, "clap": {"tone": 1400.0, "decay": 0.12, "spread": 0.009},
			"tom": {"tune": 1.1}},
		"vary": {"kick.pitch": [40.0, 50.0], "kick.decay": [0.7, 1.0], "hat.decay": [0.015, 0.03]}},
	# bass
	"synth_bass": {"label": "Synth bass", "method": "subtractive", "parts": ["bass"], "styles": ["pop", "edm", "funk"],
		"blurb": "A saw and a square an octave down through a low-pass that opens on each note: a classic synth bass.",
		"params": {"waves": [{"wave": "saw"}, {"wave": "square", "octave": -1, "level": 0.5}], "cutoff": 380.0, "env": 2.2,
			"res": 1.1, "amp": {"a": 0.003, "d": 0.25, "s": 0.6, "r": 0.06}, "fenv": {"a": 0.002, "d": 0.18, "s": 0.1, "r": 0.1}},
		"vary": {"cutoff": [280.0, 560.0], "env": [1.4, 2.8], "res": [0.8, 1.6]}},
	"sub_bass": {"label": "Sub bass", "method": "subtractive", "parts": ["bass"], "styles": ["hiphop", "edm", "ballad"],
		"blurb": "Mostly a sine, felt more than heard, with just enough edge to carry on small speakers.",
		"params": {"waves": [{"wave": "sine"}, {"wave": "saw", "level": 0.15}], "cutoff": 260.0, "env": 0.6, "res": 0.7,
			"amp": {"a": 0.006, "d": 0.4, "s": 0.85, "r": 0.1}, "fenv": {"a": 0.01, "d": 0.3, "s": 0.4, "r": 0.2}},
		"vary": {"cutoff": [200.0, 340.0]}},
	"picked_bass": {"label": "Picked bass", "method": "pluck", "parts": ["bass"], "styles": ["rock", "pop"],
		"blurb": "An electric bass played with a pick: a string's own decay, dark and round.",
		"params": {"decay": 1.4, "bright": 0.35, "pick": 0.1, "tone": 2200.0, "damp": 0.6},
		"vary": {"bright": [0.25, 0.5], "tone": [1600.0, 3000.0]}},
	"finger_bass": {"label": "Finger bass", "method": "pluck", "parts": ["bass"], "styles": ["funk", "blues", "folk", "ballad", "reggae", "jazz", "latin"],
		"blurb": "An electric bass played with the fingers: round, warm, each note dying slowly.",
		"params": {"decay": 1.8, "bright": 0.22, "pick": 0.2, "tone": 1500.0, "damp": 0.3},
		"vary": {"bright": [0.15, 0.3], "tone": [1200.0, 2000.0]}},
	"reese": {"label": "Reese bass", "method": "subtractive", "parts": ["bass"], "styles": ["edm"],
		"blurb": "Two saws a hair apart, beating against each other through a low-pass: drum and bass's growl.",
		"params": {"waves": [{"wave": "saw"}, {"wave": "saw", "detune": 14.0}], "unison": 2, "spread": 10.0, "width": 0.3,
			"cutoff": 520.0, "env": 1.2, "res": 0.9, "drive": 0.35, "amp": {"a": 0.005, "d": 0.3, "s": 0.85, "r": 0.12},
			"fenv": {"a": 0.01, "d": 0.5, "s": 0.4, "r": 0.2}},
		"vary": {"cutoff": [380.0, 720.0], "drive": [0.2, 0.5]}},
	"bass_808": {"label": "808 bass", "method": "subtractive", "parts": ["bass"], "styles": ["hiphop"],
		"blurb": "A long sine with its edge driven, sliding between notes: the bass of trap and hip hop now.",
		"params": {"waves": [{"wave": "sine"}, {"wave": "triangle", "level": 0.25}], "cutoff": 900.0, "env": 0.3, "res": 0.6,
			"drive": 0.55, "glide": 0.07, "amp": {"a": 0.004, "d": 1.2, "s": 0.7, "r": 0.15}, "fenv": {"a": 0.005, "d": 0.3, "s": 0.5, "r": 0.2}},
		"vary": {"drive": [0.4, 0.75], "glide": [0.04, 0.1]}},
	"acid": {"label": "Acid bass", "method": "subtractive", "parts": ["bass"], "styles": ["edm"],
		"blurb": "One saw through a resonant filter that snaps open on every note, sliding: acid house.",
		"params": {"waves": [{"wave": "saw"}], "cutoff": 260.0, "env": 3.6, "res": 3.2, "glide": 0.035, "drive": 0.3,
			"amp": {"a": 0.003, "d": 0.2, "s": 0.7, "r": 0.05}, "fenv": {"a": 0.002, "d": 0.16, "s": 0.05, "r": 0.08}},
		"vary": {"cutoff": [200.0, 360.0], "env": [2.8, 4.4], "res": [2.4, 4.0]}},
	# keys
	"epiano": {"label": "Electric piano", "method": "fm", "parts": ["keys"], "styles": ["funk", "pop", "ballad", "jazz"],
		"blurb": "A struck tine and its bell-like bark, the suitcase piano's slow pan: soul, funk, soft rock.",
		"params": {"ratio": 1.0, "index": 2.2, "index_decay": 0.5, "tine": 0.25, "tine_ratio": 14.0,
			"amp": {"a": 0.002, "d": 1.6, "s": 0.0, "r": 0.35}, "tremolo": 0.25, "tremolo_rate": 4.2},
		"vary": {"index": [1.6, 3.0], "tine": [0.1, 0.35], "tremolo": [0.1, 0.35]}},
	"organ": {"label": "Organ", "method": "organ", "parts": ["keys", "pad"], "styles": ["rock", "blues", "funk", "reggae", "jazz"],
		"blurb": "Drawbars, a sine a harmonic, through a spinning speaker: gospel, rock, a church.",
		"params": {"drawbars": [0.8, 0.6, 1.0, 0.0, 0.4, 0.0, 0.0, 0.0, 0.2], "click": 0.15, "leslie": 5.8, "leslie_mix": 0.4,
			"amp": {"a": 0.01, "d": 0.1, "s": 1.0, "r": 0.08}},
		"vary": {"leslie": [0.8, 6.5], "leslie_mix": [0.25, 0.55]}},
	"piano": {"label": "Piano", "method": "modal", "parts": ["keys"], "styles": ["pop", "ballad", "rock", "blues", "jazz", "folk"],
		"blurb": "A struck string's partials, each a hair sharp of the last and dying at its own rate: a piano, pedal down.",
		"params": {"ratios": [1.0, 2.002, 3.006, 4.012, 5.02, 6.03, 7.04], "decays": [3.2, 2.2, 1.6, 1.1, 0.8, 0.55, 0.4],
			"amps": [1.0, 0.55, 0.32, 0.22, 0.14, 0.08, 0.05], "length": 0.9, "hardness": 0.25},
		"vary": {"length": [0.7, 1.1], "hardness": [0.15, 0.35]}},
	"supersaw": {"label": "Supersaw", "method": "subtractive", "parts": ["keys", "pad", "lead"], "styles": ["edm", "pop"],
		"blurb": "Seven saws spread wide and detuned, bright: the chord of trance and festival anthems.",
		"params": {"waves": [{"wave": "saw"}], "unison": 7, "spread": 32.0, "width": 1.0, "cutoff": 2600.0, "env": 0.8, "res": 0.6,
			"amp": {"a": 0.005, "d": 0.4, "s": 0.8, "r": 0.35}, "fenv": {"a": 0.005, "d": 0.5, "s": 0.6, "r": 0.4}},
		"vary": {"spread": [22.0, 40.0], "cutoff": [1800.0, 3600.0]}},
	"synth_pluck": {"label": "Synth pluck", "method": "subtractive", "parts": ["keys", "lead"], "styles": ["edm", "pop"],
		"blurb": "A saw and a square snapped open and shut by the filter: dance music's short bright pluck.",
		"params": {"waves": [{"wave": "saw"}, {"wave": "square", "detune": 7.0, "level": 0.5}], "unison": 2, "spread": 12.0,
			"cutoff": 420.0, "env": 4.2, "res": 1.1, "amp": {"a": 0.002, "d": 0.32, "s": 0.0, "r": 0.18},
			"fenv": {"a": 0.001, "d": 0.12, "s": 0.0, "r": 0.1}},
		"vary": {"env": [3.4, 5.0], "amp.d": [0.22, 0.45]}},
	"clav": {"label": "Clavinet", "method": "pluck", "parts": ["keys"], "styles": ["funk"],
		"blurb": "A string struck by a hammer and damped short, bright and nasal: funk's keyboard.",
		"params": {"decay": 0.9, "bright": 0.9, "pick": 0.05, "tone": 6500.0, "damp": 0.5},
		"vary": {"bright": [0.8, 0.98], "tone": [5000.0, 8000.0]}},
	"brass": {"label": "Synth brass", "method": "subtractive", "parts": ["keys", "lead"], "styles": ["funk", "pop"],
		"blurb": "Saws whose filter swells open a moment after each note: a synth's horn section, disco and eighties pop.",
		"params": {"waves": [{"wave": "saw"}, {"wave": "saw", "detune": -8.0}], "unison": 2, "spread": 10.0, "cutoff": 700.0,
			"env": 2.0, "res": 0.7, "amp": {"a": 0.03, "d": 0.4, "s": 0.8, "r": 0.2}, "fenv": {"a": 0.09, "d": 0.5, "s": 0.5, "r": 0.2}},
		"vary": {"cutoff": [550.0, 950.0], "fenv.a": [0.06, 0.14]}},
	# pads
	"warm_pad": {"label": "Warm pad", "method": "subtractive", "parts": ["pad"], "styles": ["pop", "ballad", "rock", "edm", "folk"],
		"blurb": "Detuned saws swelling slowly through a soft low-pass: the bed under everything.",
		"params": {"waves": [{"wave": "saw"}, {"wave": "saw", "detune": 7.0}], "unison": 3, "spread": 18.0, "width": 0.8,
			"cutoff": 900.0, "env": 1.0, "res": 0.7, "amp": {"a": 1.2, "d": 1.0, "s": 0.8, "r": 1.6},
			"fenv": {"a": 1.5, "d": 2.0, "s": 0.6, "r": 1.5}},
		"vary": {"cutoff": [650.0, 1400.0], "spread": [10.0, 26.0], "amp.a": [0.6, 2.0]}},
	"glass_pad": {"label": "Glass pad", "method": "subtractive", "parts": ["pad"], "styles": ["edm", "ballad"],
		"blurb": "Triangles and a bright saw, high and cold, shimmering: ambient's bed.",
		"params": {"waves": [{"wave": "triangle"}, {"wave": "saw", "detune": -5.0, "level": 0.4, "octave": 1}], "unison": 2,
			"spread": 12.0, "cutoff": 2400.0, "env": 0.6, "res": 0.9, "amp": {"a": 0.9, "d": 1.5, "s": 0.7, "r": 2.2},
			"fenv": {"a": 1.0, "d": 2.5, "s": 0.5, "r": 2.0}},
		"vary": {"cutoff": [1800.0, 3400.0], "amp.r": [1.6, 3.0]}},
	"choir": {"label": "Choir", "method": "vox", "parts": ["pad"], "styles": ["ballad", "pop"],
		"blurb": "A wordless choir: a buzz through a sung vowel's resonances, many voices swaying.",
		"params": {"vowel": "a", "vibrato": 0.15, "amp": {"a": 0.5, "d": 0.6, "s": 0.85, "r": 1.0}},
		"vary": {"amp.a": [0.3, 0.8]}},
	"strings": {"label": "Strings", "method": "subtractive", "parts": ["pad"], "styles": ["ballad", "pop", "rock"],
		"blurb": "A section of saws bowed slowly, each player a little off the others, with vibrato: an orchestra's strings.",
		"params": {"waves": [{"wave": "saw"}], "unison": 5, "spread": 14.0, "width": 0.9, "cutoff": 1700.0, "env": 0.5, "res": 0.6,
			"vibrato": 0.08, "vibrato_rate": 5.2, "amp": {"a": 0.45, "d": 0.8, "s": 0.85, "r": 0.9},
			"fenv": {"a": 0.5, "d": 1.0, "s": 0.7, "r": 0.8}},
		"vary": {"cutoff": [1300.0, 2300.0], "amp.a": [0.3, 0.7]}},
	# leads
	"saw_lead": {"label": "Saw lead", "method": "subtractive", "parts": ["lead"], "styles": ["edm", "pop", "rock"],
		"blurb": "A singing synth lead that glides between notes, vibrato coming in as it holds.",
		"params": {"waves": [{"wave": "saw"}, {"wave": "square", "detune": 6.0, "level": 0.5}], "cutoff": 2200.0, "env": 1.2,
			"res": 1.0, "glide": 0.05, "vibrato": 0.15, "vibrato_rate": 5.6, "amp": {"a": 0.01, "d": 0.3, "s": 0.75, "r": 0.2},
			"fenv": {"a": 0.005, "d": 0.4, "s": 0.4, "r": 0.3}},
		"vary": {"cutoff": [1500.0, 3200.0], "glide": [0.02, 0.09]}},
	"square_lead": {"label": "Square lead", "method": "subtractive", "parts": ["lead"], "styles": ["pop", "edm"],
		"blurb": "A hollow pulse wave: an old game's tune, a chiptune's voice.",
		"params": {"waves": [{"wave": "pulse", "width": 0.3}], "cutoff": 3200.0, "env": 0.8, "res": 0.7, "vibrato": 0.1,
			"amp": {"a": 0.005, "d": 0.2, "s": 0.7, "r": 0.1}, "fenv": {"a": 0.005, "d": 0.3, "s": 0.5, "r": 0.2}},
		"vary": {"cutoff": [2400.0, 4200.0]}},
	"flute": {"label": "Flute", "method": "subtractive", "parts": ["lead"], "styles": ["ballad", "folk", "latin"],
		"blurb": "A soft sine with breath in it and a vibrato: a flute, a whistle.",
		"params": {"waves": [{"wave": "sine"}, {"wave": "triangle", "level": 0.2, "octave": 1}], "noise": 0.18, "cutoff": 3200.0,
			"env": 0.4, "res": 0.5, "vibrato": 0.12, "vibrato_rate": 5.0, "glide": 0.03,
			"amp": {"a": 0.05, "d": 0.2, "s": 0.85, "r": 0.15}, "fenv": {"a": 0.05, "d": 0.3, "s": 0.7, "r": 0.2}},
		"vary": {"noise": [0.1, 0.26]}},
	# strings
	"clean_guitar": {"label": "Clean guitar", "method": "pluck", "parts": ["guitar"], "styles": ["funk", "pop", "reggae", "ballad", "jazz"],
		"blurb": "A plucked steel string, bright and ringing, no amp in the way.",
		"params": {"decay": 2.5, "bright": 0.6, "pick": 0.14, "tone": 5200.0},
		"vary": {"bright": [0.45, 0.75], "decay": [1.8, 3.2]}},
	"drive_guitar": {"label": "Driven guitar", "method": "pluck", "parts": ["guitar"], "styles": ["rock", "blues"],
		"blurb": "A string through an overdriven amp and its speaker: rock's guitar, best on power chords.",
		"params": {"decay": 3.0, "bright": 0.7, "pick": 0.12, "tone": 6000.0, "drive": 0.8, "cab": 4200.0, "damp": 0.0},
		"vary": {"drive": [0.6, 1.0], "cab": [3500.0, 5000.0]}},
	"crunch_guitar": {"label": "Crunch guitar", "method": "pluck", "parts": ["guitar"], "styles": ["blues", "rock", "pop"],
		"blurb": "A string through an amp turned up just to breaking: the blues' and classic rock's edge.",
		"params": {"decay": 2.6, "bright": 0.6, "pick": 0.12, "tone": 5500.0, "drive": 0.4, "cab": 4800.0},
		"vary": {"drive": [0.3, 0.55], "cab": [4200.0, 5600.0]}},
	"metal_guitar": {"label": "High-gain guitar", "method": "pluck", "parts": ["guitar"], "styles": ["rock"],
		"blurb": "A string through an amp driven flat out and a tight speaker: punk's and metal's wall.",
		"params": {"decay": 2.4, "bright": 0.8, "pick": 0.1, "tone": 7000.0, "drive": 1.2, "cab": 3400.0},
		"vary": {"drive": [1.0, 1.4], "cab": [3000.0, 3900.0]}},
	"acoustic_guitar": {"label": "Acoustic guitar", "method": "pluck", "parts": ["guitar"], "styles": ["folk", "pop", "ballad", "latin"],
		"blurb": "Steel strings over a wooden body, bright and ringing, no amp at all.",
		"params": {"decay": 3.2, "bright": 0.72, "pick": 0.18, "tone": 7500.0},
		"vary": {"bright": [0.6, 0.82], "decay": [2.6, 3.8]}},
	# struck
	"bell": {"label": "Bell", "method": "modal", "parts": ["bells", "keys"], "styles": ["pop", "ballad"],
		"blurb": "A struck bell's inharmonic partials, each dying at its own rate (Risset's bell).",
		"params": {"ratios": [0.56, 0.92, 1.19, 1.71, 2.0, 2.74, 3.0, 3.76, 4.07], "decays": [4.0, 3.0, 2.2, 1.8, 1.5, 1.2, 1.0, 0.8, 0.6],
			"amps": [1.0, 0.67, 1.0, 1.8, 2.67, 1.67, 1.46, 1.33, 1.33], "length": 0.8, "hardness": 0.15},
		"vary": {"length": [0.5, 1.2]}},
	"marimba": {"label": "Marimba", "method": "modal", "parts": ["bells", "keys"], "styles": ["latin", "pop"],
		"blurb": "A wooden bar over its resonator: warm, short, its overtone four times up.",
		"params": {"ratios": [1.0, 3.99, 10.65], "decays": [0.9, 0.25, 0.08], "amps": [1.0, 0.35, 0.12], "length": 1.0, "hardness": 0.3},
		"vary": {"length": [0.7, 1.3]}},
	"glock": {"label": "Glockenspiel", "method": "modal", "parts": ["bells", "keys"], "styles": ["pop", "ballad"],
		"blurb": "Small steel bars struck with hard mallets: high, pure and bright.",
		"params": {"ratios": [1.0, 2.76, 5.4, 8.93], "decays": [1.6, 0.8, 0.45, 0.25], "amps": [1.0, 0.4, 0.2, 0.1], "length": 1.0, "hardness": 0.45},
		"vary": {"length": [0.8, 1.2]}},
}


## The rows a part [param part] may play, in order.
static func for_part(part: String) -> Array:
	var out: Array = []
	for k in ROWS:
		if (ROWS[k]["parts"] as Array).has(part):
			out.append(k)
	return out


## Instrument [param key] made definite by [param seed]: its `params` with each `vary` drawn in its range, and its
## `method` - what the music host is handed for a part. An unknown key is the first row the part could play.
static func resolve(key: String, seed: int) -> Dictionary:
	var row: Dictionary = ROWS.get(key, ROWS.values()[0])
	var out: Dictionary = (row["params"] as Dictionary).duplicate(true)
	out["method"] = row["method"]
	# each setting drawn by its own path, so a setting added to a row moves no other
	for path in (row.get("vary", {}) as Dictionary):
		var span: Array = row["vary"][path]
		var keys := String(path).split(".")
		var at: Dictionary = out
		for i in keys.size() - 1:
			if not (at.get(keys[i]) is Dictionary):
				at[keys[i]] = {}
			at = at[keys[i]]
		at[keys[keys.size() - 1]] = lerpf(float(span[0]), float(span[1]), Roll.unit(seed, "%s|%s" % [key, path]))
	return out
