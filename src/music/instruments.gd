extends RefCounted
class_name Instruments

## Instruments - every instrument a composed Sound plays, as rows (next/music.md, "The instruments"): how it is made
## (`method`, the music host's: hosts/music/instruments.py) and that method's settings (`params`), with the ranges its
## seed draws some of them from (`vary`: a dotted path into `params` -> [low, high]). Two seeds of one row are siblings,
## never strangers. No samples: every sound is oscillators, noise and filters.
##
## `parts` says which parts of a song a row suits ([constant SongParts.PARTS]); a part is offered those rows.

const ROWS := {
	# drums
	"kit_808": {"label": "808 kit", "method": "kit", "parts": ["drums"],
		"blurb": "The drum machine hip hop grew up on: a long booming kick, a soft snare, ticking hats.",
		"params": {"kick": {"pitch": 46.0, "sweep": 2.4, "decay": 0.55, "click": 0.15, "drive": 0.3},
			"snare": {"tone": 180.0, "body": 0.06, "decay": 0.16, "snap": 0.9, "tone_mix": 0.6},
			"hat": {"decay": 0.035, "open": 0.25, "metal": 0.7}, "clap": {"tone": 1000.0, "decay": 0.18}, "tom": {"tune": 0.9}},
		"vary": {"kick.pitch": [42.0, 52.0], "kick.decay": [0.4, 0.7], "snare.tone": [165.0, 205.0], "hat.decay": [0.025, 0.05]}},
	"kit_909": {"label": "909 kit", "method": "kit", "parts": ["drums"],
		"blurb": "House and techno's machine: a punchy kick with a click, a bright snare, crisp hats.",
		"params": {"kick": {"pitch": 52.0, "sweep": 2.0, "decay": 0.35, "click": 0.45, "drive": 0.35},
			"snare": {"tone": 200.0, "body": 0.05, "decay": 0.2, "snap": 1.1, "tone_mix": 0.4},
			"hat": {"decay": 0.045, "open": 0.3, "metal": 0.5}, "clap": {"tone": 1200.0, "decay": 0.15}, "tom": {"tune": 1.0}},
		"vary": {"kick.pitch": [48.0, 56.0], "kick.click": [0.3, 0.6], "snare.decay": [0.15, 0.25], "hat.metal": [0.3, 0.7]}},
	"kit_band": {"label": "Band kit", "method": "kit", "parts": ["drums"],
		"blurb": "A drummer's kit, played close: a tight kick, a cracking snare with its wires, toms and cymbals.",
		"params": {"kick": {"pitch": 58.0, "sweep": 1.3, "decay": 0.28, "click": 0.6, "drive": 0.2},
			"snare": {"tone": 210.0, "body": 0.05, "decay": 0.22, "snap": 1.3, "tone_mix": 0.45, "low": 1500.0, "high": 9500.0},
			"hat": {"decay": 0.055, "open": 0.35, "metal": 0.4}, "crash": {"decay": 1.6}, "ride": {"decay": 1.0}, "tom": {"tune": 1.05}},
		"vary": {"kick.pitch": [54.0, 64.0], "snare.tone": [190.0, 230.0], "snare.decay": [0.18, 0.28], "tom.tune": [0.9, 1.15]}},
	# bass
	"synth_bass": {"label": "Synth bass", "method": "subtractive", "parts": ["bass"],
		"blurb": "A saw and a square an octave down through a low-pass that opens on each note: a classic synth bass.",
		"params": {"waves": [{"wave": "saw"}, {"wave": "square", "octave": -1, "level": 0.5}], "cutoff": 380.0, "env": 2.2,
			"res": 1.1, "amp": {"a": 0.003, "d": 0.25, "s": 0.6, "r": 0.06}, "fenv": {"a": 0.002, "d": 0.18, "s": 0.1, "r": 0.1}},
		"vary": {"cutoff": [280.0, 560.0], "env": [1.4, 2.8], "res": [0.8, 1.6]}},
	"sub_bass": {"label": "Sub bass", "method": "subtractive", "parts": ["bass"],
		"blurb": "Mostly a sine, felt more than heard, with just enough edge to carry on small speakers.",
		"params": {"waves": [{"wave": "sine"}, {"wave": "saw", "level": 0.15}], "cutoff": 260.0, "env": 0.6, "res": 0.7,
			"amp": {"a": 0.006, "d": 0.4, "s": 0.85, "r": 0.1}, "fenv": {"a": 0.01, "d": 0.3, "s": 0.4, "r": 0.2}},
		"vary": {"cutoff": [200.0, 340.0]}},
	"picked_bass": {"label": "Picked bass", "method": "pluck", "parts": ["bass"],
		"blurb": "An electric bass played with a pick: a string's own decay, dark and round.",
		"params": {"decay": 1.4, "bright": 0.35, "pick": 0.1, "tone": 2200.0, "damp": 0.6},
		"vary": {"bright": [0.25, 0.5], "tone": [1600.0, 3000.0]}},
	# keys
	"epiano": {"label": "Electric piano", "method": "fm", "parts": ["keys"],
		"blurb": "A struck tine and its bell-like bark, the suitcase piano's slow pan: soul, funk, soft rock.",
		"params": {"ratio": 1.0, "index": 2.2, "index_decay": 0.5, "tine": 0.25, "tine_ratio": 14.0,
			"amp": {"a": 0.002, "d": 1.6, "s": 0.0, "r": 0.35}, "tremolo": 0.25, "tremolo_rate": 4.2},
		"vary": {"index": [1.6, 3.0], "tine": [0.1, 0.35], "tremolo": [0.1, 0.35]}},
	"organ": {"label": "Organ", "method": "organ", "parts": ["keys", "pad"],
		"blurb": "Drawbars, a sine a harmonic, through a spinning speaker: gospel, rock, a church.",
		"params": {"drawbars": [0.8, 0.6, 1.0, 0.0, 0.4, 0.0, 0.0, 0.0, 0.2], "click": 0.15, "leslie": 5.8, "leslie_mix": 0.4,
			"amp": {"a": 0.01, "d": 0.1, "s": 1.0, "r": 0.08}},
		"vary": {"leslie": [0.8, 6.5], "leslie_mix": [0.25, 0.55]}},
	# pads
	"warm_pad": {"label": "Warm pad", "method": "subtractive", "parts": ["pad"],
		"blurb": "Detuned saws swelling slowly through a soft low-pass: the bed under everything.",
		"params": {"waves": [{"wave": "saw"}, {"wave": "saw", "detune": 7.0}], "unison": 3, "spread": 18.0, "width": 0.8,
			"cutoff": 900.0, "env": 1.0, "res": 0.7, "amp": {"a": 1.2, "d": 1.0, "s": 0.8, "r": 1.6},
			"fenv": {"a": 1.5, "d": 2.0, "s": 0.6, "r": 1.5}},
		"vary": {"cutoff": [650.0, 1400.0], "spread": [10.0, 26.0], "amp.a": [0.6, 2.0]}},
	"glass_pad": {"label": "Glass pad", "method": "subtractive", "parts": ["pad"],
		"blurb": "Triangles and a bright saw, high and cold, shimmering: ambient's bed.",
		"params": {"waves": [{"wave": "triangle"}, {"wave": "saw", "detune": -5.0, "level": 0.4, "octave": 1}], "unison": 2,
			"spread": 12.0, "cutoff": 2400.0, "env": 0.6, "res": 0.9, "amp": {"a": 0.9, "d": 1.5, "s": 0.7, "r": 2.2},
			"fenv": {"a": 1.0, "d": 2.5, "s": 0.5, "r": 2.0}},
		"vary": {"cutoff": [1800.0, 3400.0], "amp.r": [1.6, 3.0]}},
	"choir": {"label": "Choir", "method": "vox", "parts": ["pad"],
		"blurb": "A wordless choir: a buzz through a sung vowel's resonances, many voices swaying.",
		"params": {"vowel": "a", "vibrato": 0.15, "amp": {"a": 0.5, "d": 0.6, "s": 0.85, "r": 1.0}},
		"vary": {"amp.a": [0.3, 0.8]}},
	# leads
	"saw_lead": {"label": "Saw lead", "method": "subtractive", "parts": ["lead"],
		"blurb": "A singing synth lead that glides between notes, vibrato coming in as it holds.",
		"params": {"waves": [{"wave": "saw"}, {"wave": "square", "detune": 6.0, "level": 0.5}], "cutoff": 2200.0, "env": 1.2,
			"res": 1.0, "glide": 0.05, "vibrato": 0.15, "vibrato_rate": 5.6, "amp": {"a": 0.01, "d": 0.3, "s": 0.75, "r": 0.2},
			"fenv": {"a": 0.005, "d": 0.4, "s": 0.4, "r": 0.3}},
		"vary": {"cutoff": [1500.0, 3200.0], "glide": [0.02, 0.09]}},
	"square_lead": {"label": "Square lead", "method": "subtractive", "parts": ["lead"],
		"blurb": "A hollow pulse wave: an old game's tune, a chiptune's voice.",
		"params": {"waves": [{"wave": "pulse", "width": 0.3}], "cutoff": 3200.0, "env": 0.8, "res": 0.7, "vibrato": 0.1,
			"amp": {"a": 0.005, "d": 0.2, "s": 0.7, "r": 0.1}, "fenv": {"a": 0.005, "d": 0.3, "s": 0.5, "r": 0.2}},
		"vary": {"cutoff": [2400.0, 4200.0]}},
	# strings
	"clean_guitar": {"label": "Clean guitar", "method": "pluck", "parts": ["guitar"],
		"blurb": "A plucked steel string, bright and ringing, no amp in the way.",
		"params": {"decay": 2.5, "bright": 0.6, "pick": 0.14, "tone": 5200.0},
		"vary": {"bright": [0.45, 0.75], "decay": [1.8, 3.2]}},
	"drive_guitar": {"label": "Driven guitar", "method": "pluck", "parts": ["guitar"],
		"blurb": "A string through an overdriven amp and its speaker: rock's guitar, best on power chords.",
		"params": {"decay": 3.0, "bright": 0.7, "pick": 0.12, "tone": 6000.0, "drive": 0.8, "cab": 4200.0, "damp": 0.0},
		"vary": {"drive": [0.6, 1.0], "cab": [3500.0, 5000.0]}},
	# struck
	"bell": {"label": "Bell", "method": "modal", "parts": ["bells", "keys"],
		"blurb": "A struck bell's inharmonic partials, each dying at its own rate (Risset's bell).",
		"params": {"ratios": [0.56, 0.92, 1.19, 1.71, 2.0, 2.74, 3.0, 3.76, 4.07], "decays": [4.0, 3.0, 2.2, 1.8, 1.5, 1.2, 1.0, 0.8, 0.6],
			"amps": [1.0, 0.67, 1.0, 1.8, 2.67, 1.67, 1.46, 1.33, 1.33], "length": 0.8, "hardness": 0.15},
		"vary": {"length": [0.5, 1.2]}},
	"marimba": {"label": "Marimba", "method": "modal", "parts": ["bells", "keys"],
		"blurb": "A wooden bar over its resonator: warm, short, its overtone four times up.",
		"params": {"ratios": [1.0, 3.99, 10.65], "decays": [0.9, 0.25, 0.08], "amps": [1.0, 0.35, 0.12], "length": 1.0, "hardness": 0.3},
		"vary": {"length": [0.7, 1.3]}},
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
