extends RefCounted
class_name SongCode

## SongCode - a composed Sound's settings as one code (next/music.md, "The song's code"): every value its `sound:` block
## sets - the song's roll, Likeness, tempo, key, where its sections are pinned, each part and all set on it - and the code
## back to them ([BlockCode]). The code changes with every change on the card; pasted back, the settings come back.
## What the song is made OVER is not in it: the note's words, the reference and the source (LEFT_OUT) stay the note's,
## so one code on another note is the same choices over its own words.
##
## A value at its default (DEFAULTS, PART_DEFAULTS) is left out, so a fresh roll is a short code and a tuned song a
## longer one. The words of WORDS are a byte each: THEY ONLY GROW - append a pattern, instrument or key at the end,
## never reorder or remove one (tests/music/song_code_check.gd pins them); a name not in them is written out.

## What the code leaves to the note.
const LEFT_OUT := ["source", "path", "reference"]
## What the block's own keys mean when they are not set: a value equal to one is left out of the code. (A setting a
## roll draws where it is unset - Likeness, a level, the vocoder - has none: set to any value, it is in.)
const DEFAULTS := {"seed": 1, "tempo": 0.0, "key": ""}
const PART_DEFAULTS := {"seed": 1, "mute": false}
## A roll's numbers: under this, so each costs a code two bytes.
const ROLL_MOST := 16384
## The words a code writes as a byte: append only.
const WORDS := [
	# the block's keys
	"seed", "parts", "pattern", "instrument", "level", "mute", "likeness", "tempo", "key", "place", "singer", "tune",
	"vibrato", "vocoder", "pan", "harmony", "voice", "speaker", "name", "kept", "drift", "vibrato_rate",
	"follow_reference", "reference", "kokoro",
	# parts
	"drums", "bass", "keys", "pad", "guitar", "lead", "bells", "vocal",
	# patterns
	"backbeat", "four_floor", "half_time", "motorik", "boom_bap", "root_eighths", "root_fifth", "follow_kick", "walking",
	"drone", "offbeat_stabs", "block", "syncopated", "arpeggio", "held", "power_eighths", "strum", "motif", "sparse",
	"composed", "recite",
	# instruments
	"kit_808", "kit_909", "kit_band", "synth_bass", "sub_bass", "picked_bass", "epiano", "organ", "warm_pad", "glass_pad",
	"choir", "saw_lead", "square_lead", "clean_guitar", "drive_guitar", "bell", "marimba",
	# modes
	"major", "minor", "dorian", "mixolydian", "lydian",
	# Kokoro's readers
	"af_alloy", "af_aoede", "af_bella", "af_heart", "af_jessica", "af_kore", "af_maple", "af_nicole", "af_nova",
	"af_river", "af_sarah", "af_sky", "af_sol", "am_adam", "am_echo", "am_eric", "am_fenrir", "am_liam", "am_michael",
	"am_onyx", "am_puck", "am_santa", "bf_alice", "bf_emma", "bf_isabella", "bf_lily", "bf_vale", "bm_daniel",
	"bm_fable", "bm_george", "bm_lewis",
	# keys
	"C major", "C# major", "D major", "Eb major", "E major", "F major", "F# major", "G major", "Ab major", "A major", "Bb major", "B major",
	"C minor", "C# minor", "D minor", "Eb minor", "E minor", "F minor", "F# minor", "G minor", "Ab minor", "A minor", "Bb minor", "B minor",
	"C dorian", "C# dorian", "D dorian", "Eb dorian", "E dorian", "F dorian", "F# dorian", "G dorian", "Ab dorian", "A dorian", "Bb dorian", "B dorian",
	"C mixolydian", "C# mixolydian", "D mixolydian", "Eb mixolydian", "E mixolydian", "F mixolydian", "F# mixolydian", "G mixolydian", "Ab mixolydian", "A mixolydian", "Bb mixolydian", "B mixolydian",
	"C lydian", "C# lydian", "D lydian", "Eb lydian", "E lydian", "F lydian", "F# lydian", "G lydian", "Ab lydian", "A lydian", "Bb lydian", "B lydian",
	# patterns
	"pop_sixteenths", "rock_drive", "punk", "shuffle", "trap", "two_step", "dembow", "funk", "disco", "breakbeat", "ballad",
	"train", "octaves", "offbeat", "boogie", "gallop", "slap", "glide", "rolling", "pounding", "anthem", "broken", "comp",
	"gated", "palm_mute", "power_held", "shuffle_riff", "scratch", "picked", "skank", "riff", "arp_lead",
	# instruments
	"kit_rock", "kit_edm", "kit_trap", "finger_bass", "reese", "bass_808", "acid", "piano", "supersaw", "synth_pluck",
	"clav", "brass", "strings", "flute", "crunch_guitar", "metal_guitar", "acoustic_guitar", "glock",
]


## The code of [param block]'s settings.
static func of(block: Dictionary) -> String:
	return BlockCode.encode(settings(block), WORDS)


## What of [param block] a code holds: every setting but LEFT_OUT, a value at its default left out.
static func settings(block: Dictionary) -> Dictionary:
	var out := {}
	for k in block:
		var key := String(k)
		var v: Variant = block[k]
		if key in LEFT_OUT or _is_default(DEFAULTS, key, v) or _empty(v):
			continue
		if key == "seed":
			v = int(v)
		elif key == "parts" and v is Dictionary:
			var parts := {}
			for p in v:
				var cfg: Dictionary = v[p] if v[p] is Dictionary else {}
				var kept := {}
				for f in cfg:
					if not _is_default(PART_DEFAULTS, String(f), cfg[f]) and not _empty(cfg[f]):
						kept[String(f)] = int(cfg[f]) if String(f) == "seed" else cfg[f]
				parts[String(p)] = kept
			v = parts
		out[key] = v
	return out


## [param block] with the settings of [param code] in place of its own, what the note keeps (LEFT_OUT) kept:
## `{block, why}`, `why` empty when the code read, else what is wrong with it (and `block` the one handed).
static func applied(block: Dictionary, code: String) -> Dictionary:
	var read := BlockCode.decode(code, WORDS)
	if not String(read["why"]).is_empty():
		return {"block": block, "why": String(read["why"])}
	if not (read["value"] is Dictionary):
		return {"block": block, "why": "not a song's settings"}
	var out: Dictionary = (read["value"] as Dictionary).duplicate(true)
	if out.has("parts") and not (out["parts"] is Dictionary):
		return {"block": block, "why": "not a song's settings (its parts are not a list of parts)"}
	for k in LEFT_OUT:
		if block.has(k):
			out[k] = block[k]
		else:
			out.erase(k)
	return {"block": out, "why": ""}


## A roll's new number, never [param was].
static func fresh(was := -1) -> int:
	var n := was
	while n == was:
		n = 2 + Roll.fresh(ROLL_MOST - 2)
	return n


static func _is_default(defaults: Dictionary, key: String, v: Variant) -> bool:
	if not defaults.has(key):
		return false
	var d: Variant = defaults[key]
	if typeof(d) in [TYPE_INT, TYPE_FLOAT] and typeof(v) in [TYPE_INT, TYPE_FLOAT]:
		return is_equal_approx(float(d), float(v))
	return typeof(d) == typeof(v) and d == v


static func _empty(v: Variant) -> bool:
	return v == null or (v is String and (v as String).is_empty()) or (v is Dictionary and (v as Dictionary).is_empty())
