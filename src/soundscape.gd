extends RefCounted
class_name Soundscape

## Soundscape - what a place sounds like behind the reader: the wind, the sea, rain, a fire, a stream,
## the insects of a summer night. The user, 2026-10-08: "there are a lot of scenes that take place in
## places where pure environmental silence feels inappropriate. One scene was on a boat at sea: you
## might expect to hear waves oscillating and crashing ... if the wind gusts strongly, the sound
## increases in strength accordingly." The set dresser writes it as the table's `sound`, beside its
## `light` ([method describe], [method sanitize]); the reading mixes it under the voice, live and in
## the exported take alike ([ReadingPanel], the Environment dial).
##
## EVERYTHING HERE IS SYNTHESIZED, from noise and a few sines - no recordings, so nothing to license
## and nothing to fetch (the method is Farnell's, "Designing Sound", 2010):
##   - WIND is noise through band-pass filters whose center and level follow the wind's speed - a rush
##     that brightens and swells in a gust - with what it blows THROUGH on top: leaves hiss a moment
##     after a gust reaches them, rigging sings (an Aeolian tone rises in proportion to the speed),
##     eaves moan, canvas flaps.
##   - THE SEA is a wave's ENVELOPE over filtered noise - the swell gathering low, the break opening the
##     filter, the wash fizzing away for seconds - or, against a hull or a piling, slaps (a short thump
##     of band-passed noise), the slosh after them and a few bubbles.
##   - A BUBBLE is a sine whose pitch rises as it decays (Minnaert's resonance of a closing bubble):
##     the plunk of a lapping wave, the babble of a stream, the plink of rain falling on water.
##   - RAIN is a hiss and many drops, each a click through a resonance tuned by what it falls on.
##   - FIRE is a low roar, a flickering hiss and crackles - very short bursts, often in clusters.
##   - A CRICKET is a few short tone pulses, chirp after chirp; cicadas a band of noise buzzing.
##
## THE WIND IS THE TABLE'S OWN ([Winds], the light's `wind`, planned on the same seed as [TableMedium]
## plans it): its speed is read at every block of samples from the same closed-form plan the leaves,
## the swinging shadows and the drifting petals read, so a gust is heard as it is seen - the user's
## "align sound with motion". The fire roars and the rain thickens in a gust too; the sea slaps harder.
##
## ONE DIAL ([method set_level], Environment): how present the place is. Low is far and steady - a bed
## behind the voice, its gusts and breakers flattened and dulled; high is close and vivid - louder,
## brighter, every gust and crash and crackle hitting harder. It ducks a little under speech
## ([constant DUCK]), so the voice is never fought.
##
## RENDERED IN WHOLE BLOCKS of [constant CR] samples from the moment it starts, so the samples are the
## same however the caller slices its calls - live, a buffer at a time; in an export, the whole take.

## Samples per control block: the wind is read, the waves stepped and the events placed this often.
const CR := 64
const _NM := 65535
## HOW FAR A PLACE EBBS below its typical gust or wave, at most (dB): at the bottom of the dial and the
## top. A wind or a sea is never silent between its gusts and its breakers.
const FLOOR_DB := Vector2(-6.0, -11.0)
## THE WIND HEARD HOLDS (seconds): it rises toward a gust this fast and lets go of it this slowly, so a
## gust is held near its height and the air falls back only part way before the next. The plan's own
## gusts ([Winds]) rise and fall in a few seconds - right for a leaf, and heard that way they came on
## hard, held for an instant and fell away (the user, 2026-10-08: "the ramp up and down also seems
## rather fast, while the hold at volume is short ... it would decay to half-volume, or 3-quarters").
##
## IN DECIBELS, ON AN S-CURVE (the user, 2026-10-08: "are you increasing the volume in a linear fashion,
## or a logarithmic one?"). It was one smoothing stage on the speed itself - a curve steepest at its very
## start, so in what the ear hears every gust began with a jump (27 dB/s at its steepest). Now the LOG of
## the speed is smoothed, through two stages (a rise starts from no slope at all, swells, and eases into
## its height, as a fade does), and no rise may be faster than [constant RISE_MOST]. Each stage's time.
const HOLD := Vector2(0.45, 1.8)
## The fastest the wind heard may grow, in its log per second: 0.4 keeps a gust's entry, everything
## that follows the wind together (the rush's level and its widening band, the rumble), near 6 dB a
## second at the dial's middle - a fade's pace, not a jump.
const RISE_MOST := 0.4
## HEARD A MOMENT AHEAD (seconds): the plan is known before it blows, so the slow fade into a gust starts
## this much before it is seen and reaches its height as the leaves and the petals do - as a real gust
## is heard coming through the trees before it arrives. Without it a gentle entry was a late one.
const LEAD := 0.8
## ITS OWN SLOW SWELLS: periods (seconds) that never line up, and how deep they are together - the
## aperiodic rise and fall a wind and a sea have between gusts and sets.
const BREATHS := [7.3, 17.9, 41.0]
const BREATH := 0.15
## How long a place takes to fade in when it starts (seconds) - never a hard edge.
const FADE := 1.5
## BROWN NOISE, white integrated - with a leak, so its corner is about 80 Hz at the voice's rate. With
## the corner at ~10 Hz most of its power was under 50 Hz, near subsonic, and a low rumble made of it
## churned like a washing machine (measured: 5 dB of wobble against the rush's 1.4).
const BROWN := 0.977
const BROWN_IN := 0.2
## The most one ear is under the other (dB), for a sound wholly to one side.
const MOST_APART := 7.0
## How far the place is pulled down under speech, at most (a gain of 1 - DUCK).
const DUCK := 0.42
## The duck's follower: how fast it closes on a word and how slowly it lets go (seconds).
const DUCK_ATTACK := 0.03
const DUCK_RELEASE := 0.9
## THE DIAL'S LEVEL: dB at its bottom and its top, over the layers' own levels.
const LEVEL_DB := Vector2(-30.0, -2.0)
## THE LOUDEST A PLACE GETS, alone (linear): a gust at the top of the dial, a breaker, a downpour are held
## under it by a slow limiter, so the place never reaches the voice's own peaks.
const CEILING := 0.56
## How fast the limiter lets go again (seconds).
const LIMIT_RELEASE := 1.2
## ...faded in over this much of its travel, so 0 is a clean off and not a step.
const FADE_IN := 0.05

## THE VOCABULARY. What each part of `sound` is, as an agent reads it.
const LAYERS := {
	"wind": "the wind, heard - the table's own wind (the light's `wind`) when it has one, every gust heard as it moves the light and the air",
	"water": "the sea, a lake or a harbor, close by",
	"rain": "rain falling round the table, or on what is over it",
	"fire": "a fire burning nearby - a hearth, a campfire, a brazier, a stove",
	"stream": "running water - a brook, a fountain, a gutter after rain",
	"insects": "insects of a warm evening or a summer day",
}
## What the wind blows through, which is most of what it sounds like.
const THROUGH := {
	"open": "open air - a rush that swells and brightens in each gust",
	"trees": "leaves overhead or round about - they hiss and patter, a moment after each gust reaches them",
	"grass": "long grass, reeds, a field of grain - a softer, lower hiss",
	"rigging": "ropes, wires, a mast's rigging, a fence - a few thin tones that sing and rise in the gusts",
	"eaves": "a wind outside, heard from within a room - a muffled rush that moans round the eaves in a gust",
	"canvas": "an awning, a tent, a sail - it flaps and snaps in the gusts",
	"tunnel": "a tunnel, an alley, a gorge, a stairwell, a cave mouth - the air hollow and booming, a low howl in the gusts",
}
## The water, by where the table is.
const WATERS := {
	"shore": "waves breaking on a beach or rocks below - the swell gathering, the crash, the long hiss of the wash",
	"hull": "aboard a boat - the sea slapping and gurgling against the hull, the deep wash of the swell under it",
	"dock": "a dock, a jetty, a quay, a lakeshore - small waves lapping and plunking round pilings and stones, the sea further out",
}
## What the rain falls on: each drop's center (Hz), how many octaves either side, its resonance, its
## ring (seconds), and the hiss's center.
const RAINS := {
	"leaves": {"about": "leaves and foliage - a soft, dense patter", "fc": 3000.0, "spread": 0.8, "q": 1.1, "ring": 0.010, "hiss": 4200.0},
	"roof": {"about": "a roof overhead - tiles or tin, pinging and drumming", "fc": 1500.0, "spread": 0.6, "q": 3.0, "ring": 0.025, "hiss": 2400.0},
	"canvas": {"about": "an awning, a tent, an umbrella - dull thuds on taut cloth", "fc": 380.0, "spread": 0.5, "q": 1.4, "ring": 0.035, "hiss": 1500.0},
	"window": {"about": "a window of the room - ticks on the glass, the rest muffled outside", "fc": 4200.0, "spread": 0.5, "q": 2.5, "ring": 0.008, "hiss": 3200.0},
	"ground": {"about": "the ground, stones, a street - a broad, fine patter", "fc": 2600.0, "spread": 0.9, "q": 0.8, "ring": 0.006, "hiss": 3000.0},
	"water": {"about": "water - a pond, the sea, a puddle: drops plinking as they land", "fc": 2500.0, "spread": 0.6, "q": 1.0, "ring": 0.008, "hiss": 3500.0},
}
const INSECTS := {
	"crickets": "crickets in the grass - chirp after chirp, each at its own pace",
	"cicadas": "cicadas in the trees - a dry buzz that swells and fades",
}


## THE VOCABULARY, as an agent reads it ([CardPrompts.set_dresser], `insert: sounds`).
static func describe() -> String:
	var lines := PackedStringArray()
	lines.append("THE SOUND (`sound`): {\"why\", \"wind\", \"water\", \"rain\", \"fire\", \"stream\", \"insects\"} - what the place sounds like behind the reader's voice, every part optional. Leave `sound` out, or a part of it, for a quiet room: the reader alone, as every earlier table was.")
	lines.append("- why: a few words - where this is, heard.")
	lines.append("- wind: {\"through\", \"level\" 0-1, \"from\"} - %s. through:" % String(LAYERS["wind"]))
	for k in THROUGH:
		lines.append("  - %s: %s" % [k, String(THROUGH[k])])
	lines.append("  level: how loud it is beside the rest (0.7 when left out). A table whose light has a wind is heard only if `wind` is here: give it whenever the wind moving the table should be heard. WHERE IT IS HEARD: out in the open the wind is louder on the side it blows from, and the balance moves as a gust veers - nothing to write. Within walls it is heard where it gets in: give \"from\" for that opening (an open window on the reader's right is \"right\"), and it stays there. With NO wind in the light - the table in still air - a wind given here is one outside, felt by nothing on the table: give it \"strength\" 0-1, \"gusts\" 0-1 and \"every\" (seconds) as the light's wind takes them (a storm beyond the shutters, a gale round a lighthouse).")
	lines.append("- water: {\"kind\", \"size\" 0-1 (calm to rough), \"from\", \"distance\" 0-1} - %s. kind:" % String(LAYERS["water"]))
	for k in WATERS:
		lines.append("  - %s: %s" % [k, String(WATERS[k])])
	lines.append("- rain: {\"on\", \"strength\" 0-1 (a few drops to a downpour)} - %s. on:" % String(LAYERS["rain"]))
	for k in RAINS:
		lines.append("  - %s: %s" % [k, String((RAINS[k] as Dictionary)["about"])])
	lines.append("- fire: {\"size\" 0-1 (a few embers to a roaring blaze), \"from\", \"distance\" 0-1} - %s: it roars, hisses and crackles, and a gust fans it." % String(LAYERS["fire"]))
	lines.append("- stream: {\"size\" 0-1 (a trickle to a rushing brook), \"from\", \"distance\" 0-1} - %s." % String(LAYERS["stream"]))
	lines.append("- insects: {\"kind\", \"strength\" 0-1} - %s. kind:" % String(LAYERS["insects"]))
	for k in INSECTS:
		lines.append("  - %s: %s" % [k, String(INSECTS[k])])
	lines.append("  from: where a sound is, as a sun's `from` (front, right, back left, ... or degrees). distance: 0 at the table's edge, 1 far off - quieter and duller.")
	lines.append("A sound belongs to the place the room's painting and the light show: the sea where the sea is, rain where the sky is gray, no fire where none burns. Most places have one or two sounds; a quiet room none.")
	return "\n".join(lines)


## WHATEVER AN AGENT WROTE as `sound`, made safe: `{}` when nothing was written. Every part kept is
## complete. What had to change is said in [param notes].
static func sanitize(raw: Variant, notes: PackedStringArray = PackedStringArray()) -> Dictionary:
	if raw == null:
		return {}
	if not (raw is Dictionary):
		notes.append("the sound was not an object {why, wind, water, rain, fire, stream, insects} - a quiet room")
		return {}
	var d: Dictionary = raw
	var out := {}
	for k in d:
		if not LAYERS.has(String(k)) and String(k) != "why":
			notes.append("the sound has no part \"%s\" (%s) - left out" % [String(k), ", ".join(PackedStringArray(LAYERS.keys()))])
	var w: Variant = d.get("wind")
	if w is Dictionary:
		var wd: Dictionary = w
		var wind := {"through": _kind(wd.get("through"), THROUGH, "open", "the wind's `through`", notes),
			"level": Props._num(wd.get("level"), 0.7, 0.0, 1.0)}
		# heard from an opening, fixed there; left out, it leans with the wind itself
		if wd.get("from") != null:
			wind["from"] = Lights._from(wd.get("from"), 90.0, "the wind's opening", notes)
		# a wind of its own, outside: only used where the light has none. Kept in the words it was
		# written in, so a sound made safe reads the same made safe again
		if wd.get("strength") != null:
			var own := Winds.sanitize({"strength": wd.get("strength"), "gusts": wd.get("gusts"), "every": wd.get("every")}, notes)
			wind["strength"] = own["strength"]
			wind["gusts"] = own["gusts"]
			wind["every"] = own["every"]
		out["wind"] = wind
	elif w != null:
		notes.append("the wind was not an object {through, level} - left out")
	var wa: Variant = d.get("water")
	if wa is Dictionary:
		var x: Dictionary = wa
		out["water"] = {"kind": _kind(x.get("kind"), WATERS, "shore", "the water's `kind`", notes),
			"size": Props._num(x.get("size"), 0.4, 0.0, 1.0), "from": Lights._from(x.get("from"), 180.0, "the water", notes),
			"distance": Props._num(x.get("distance"), 0.3, 0.0, 1.0)}
	elif wa != null:
		notes.append("the water was not an object {kind, size, from, distance} - left out")
	var r: Variant = d.get("rain")
	if r is Dictionary:
		out["rain"] = {"on": _kind((r as Dictionary).get("on"), RAINS, "ground", "the rain's `on`", notes),
			"strength": Props._num((r as Dictionary).get("strength"), 0.4, 0.0, 1.0)}
	elif r != null:
		notes.append("the rain was not an object {on, strength} - left out")
	for key in ["fire", "stream"]:
		var v: Variant = d.get(key)
		if v is Dictionary:
			out[key] = {"size": Props._num((v as Dictionary).get("size"), 0.5 if key == "fire" else 0.4, 0.0, 1.0),
				"from": Lights._from((v as Dictionary).get("from"), 315.0 if key == "fire" else 90.0, "the " + key, notes),
				"distance": Props._num((v as Dictionary).get("distance"), 0.4, 0.0, 1.0)}
		elif v != null:
			notes.append("the %s was not an object {size, from, distance} - left out" % key)
	var ins: Variant = d.get("insects")
	if ins is Dictionary:
		out["insects"] = {"kind": _kind((ins as Dictionary).get("kind"), INSECTS, "crickets", "the insects' `kind`", notes),
			"strength": Props._num((ins as Dictionary).get("strength"), 0.5, 0.0, 1.0)}
	elif ins != null:
		notes.append("the insects were not an object {kind, strength} - left out")
	if out.is_empty():
		return {}
	out["why"] = Props._text(d.get("why", ""), 200)
	return out


static func _kind(v: Variant, table: Dictionary, fallback: String, what: String, notes: PackedStringArray) -> String:
	var s := String(v).strip_edges().to_lower() if v is String else ""
	if table.has(s):
		return s
	if v != null:
		notes.append("%s: \"%s\" is not one of %s - %s" % [what, str(v), ", ".join(PackedStringArray(table.keys())), fallback])
	return fallback


## THE SOUND IN A LINE, for the set dresser's answer and an episode's archive. "" for none.
static func summary(sound: Dictionary) -> String:
	var parts := PackedStringArray()
	if sound.get("wind") is Dictionary:
		var w: Dictionary = sound["wind"]
		parts.append("the wind through %s%s%s" % ["open air" if String(w["through"]) == "open" else ("the " + String(w["through"])),
			(", heard from the " + Lights.from_name(float(w["from"]))) if w.has("from") else "", ", silent" if float(w["level"]) < 0.01 else ""])
	if sound.get("water") is Dictionary:
		var x: Dictionary = sound["water"]
		parts.append("%s (%s)" % [{"shore": "waves on a shore", "hull": "the sea against a hull", "dock": "water lapping at a dock"}[String(x["kind"])],
			"calm" if float(x["size"]) < 0.3 else ("rough" if float(x["size"]) > 0.7 else "moderate")])
	if sound.get("rain") is Dictionary:
		parts.append("rain on %s" % ("the " + String((sound["rain"] as Dictionary)["on"])))
	if sound.get("fire") is Dictionary:
		parts.append("a fire")
	if sound.get("stream") is Dictionary:
		parts.append("a stream")
	if sound.get("insects") is Dictionary:
		parts.append(String((sound["insects"] as Dictionary)["kind"]))
	return ", ".join(parts)


## WHAT A TABLE SOUNDS LIKE: its `sound` made safe, and the wind it hears planned exactly as
## [TableMedium] plans the light's (the episode's [param seed]). `{sound, wind}`; `sound` is `{}` for a
## quiet table. THE AGENT DECIDES: a light with a wind and a sound with none is silent - the wind is
## heard only where the set dresser wrote it into the sound (the user, 2026-10-08: "we should defer to
## the agents here"; many places are silent at every level of the dial).
static func of_table(table: Dictionary, seed: int) -> Dictionary:
	var sound := sanitize(table.get("sound"))
	var light: Dictionary = Lights.sanitize(table["light"]) if table.get("light") is Dictionary else {}
	var written: Dictionary = light.get("wind", {}) if light.get("wind") is Dictionary else {}
	var plan := {}
	if not sound.has("wind"):
		return {"sound": sound, "wind": plan}
	if not written.is_empty():
		plan = Winds.plan(written, hash([seed, "wind"]))
	elif sound.get("wind") is Dictionary and (sound["wind"] as Dictionary).has("strength"):
		var own: Dictionary = sound["wind"]
		plan = Winds.plan({"from": own.get("from", 90.0), "strength": own["strength"], "gusts": own["gusts"], "every": own["every"]},
			hash([seed, "wind outside"]))
	elif sound.has("wind"):
		# a wind with no light's and none of its own: a breath, heard
		plan = Winds.plan({}, hash([seed, "wind outside"]))
	return {"sound": sound, "wind": plan}


# --- the synthesizer --------------------------------------------------------------------------------

## ONE FILTERED NOISE: a source (white, or brown - white integrated), a state-variable filter (Simper's,
## stable under modulation), a level for each ear eased across the block, an envelope struck by events
## (a difference of two exponentials - an attack and a decay) and an optional pulse (a flap, a buzz).
class Band:
	var src := 0           # 0 white, 1 brown
	var leak := BROWN      # brown's leak and its input (see BROWN)
	var leak_in := BROWN_IN
	var mode := 1          # 0 low-pass, 1 band-pass (unit peak), 2 high-pass, 3 band-pass (peak = q)
	var fc := 1000.0
	var q := 0.7
	var wide := false      # its own noise and filter for each ear
	var gl := 0.0          # each ear's level this block (eased from the last)
	var gr := 0.0
	var _gl0 := 0.0
	var _gr0 := 0.0
	var steady := 1.0      # the bed's share: a band that only rings when struck has 0
	var e1 := 0.0          # the struck envelope: e1 - e2
	var e2 := 0.0
	var k1 := 0.999        # its decay and its attack, per sample
	var k2 := 0.9
	var am_rate := 0.0     # a pulse over it (Hz; 0 none), how deep, and its phase
	var am_depth := 0.0
	var am_ph := 0.0
	var s := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])   # svf L (2), svf R (2), brown L, brown R

	func strike(amount: float, decay: float, attack: float, sr: float) -> void:
		k1 = exp(-1.0 / maxf(1.0, decay * sr))
		k2 = exp(-1.0 / maxf(1.0, attack * sr))
		# the peak of e1 - e2 struck at 1 is under 1: scaled so `amount` is the peak
		var tp := log(k2 / k1) / (log(k2) - log(k1)) if absf(log(k2) - log(k1)) > 1e-9 else 0.0
		var peak := maxf(0.05, pow(k1, tp) - pow(k2, tp))
		e1 += amount / peak
		e2 += amount / peak


var _sr := 22050.0
var _t0 := 0.0
var _n := 0                       # samples rendered, whole blocks
var _rng := 0x9e3779b9
var _sound := {}
var _wind := {}
var _bands: Array[Band] = []
var _ol := PackedFloat32Array()   # rendered and not yet handed out
var _or := PackedFloat32Array()
var _oat := 0
var _bl := PackedFloat32Array()   # this block
var _br := PackedFloat32Array()
var _gain := 0.0                  # the dial: level, how hard the moving parts hit, brightness
var _gain0 := 0.0
var _contrast := 1.0
var _snap := 1.0
var _bright := 1.0
var _lp := Vector2.ZERO
var _limit := 1.0
var _floor := 0.3                 # how far a place may ebb below its typical loudness (see _ebb)
var _task := -1                   # the worker rendering ahead ([method prefetch]), or -1
var _fresh_l := PackedFloat32Array()
var _fresh_r := PackedFloat32Array()
var _duck := 0.0
var _speed := 0.0                 # the wind heard, 0 still to ~1.3 a strong gust (eased per block)
var _gust := 0.0                  # how much of it is gust, 0-1
var _turb := 0.0                  # the air's slow raggedness, about -1 to 1
var _drift := 0.0                 # its two smoothed noises (see _air)
var _shimmer := 0.0
var _held := -1.0                 # the wind heard (m/s): quick to rise, slow to let go
var _log1 := INF                  # its two smoothing stages, in the log of the speed
var _log2 := INF
var _breath := Vector3.ZERO       # the phases of the sound's own slow swells
var _lag := 0.0                   # the leaves' wind: a moment behind the air's
var _side := 0.0                  # where the air comes from now: -1 the reader's left, 1 their right
# the sine voices (bubbles, chirps): phase step, its glide, envelope, ears
const VOICES := 32
var _vw := PackedFloat64Array()
var _vg := PackedFloat64Array()
var _ve1 := PackedFloat64Array()
var _ve2 := PackedFloat64Array()
var _vk1 := PackedFloat64Array()
var _vk2 := PackedFloat64Array()
var _vph := PackedFloat64Array()
var _vl := PackedFloat64Array()
var _vr := PackedFloat64Array()

# each layer's bands and its own state
var _w := {}
var _wa := {}
var _ra := {}
var _fi := {}
var _st := {}
var _in := {}

static var _noise := PackedFloat32Array()
static var _noise_lock := Mutex.new()


## A soundscape for [param sound] ([method sanitize]d, as [method of_table] gives it) with the wind
## [param wind] ([method Winds.plan], or `{}`), at [param sample_rate], its first sample at show time
## [param t0]. [param seed] makes the same place sound the same every time it is played.
func _init(sound: Dictionary, wind: Dictionary, seed: int, sample_rate: int, t0 := 0.0) -> void:
	_sr = float(maxi(8000, sample_rate))
	_t0 = t0
	_sound = sound
	_wind = wind
	_rng = (hash([seed, "sound"]) & 0x7FFFFFFF) | 1
	_breath = Vector3(_rand() * TAU, _rand() * TAU, _rand() * TAU)
	_bl.resize(CR)
	_br.resize(CR)
	# one by one: a packed array put in an Array literal is a copy, and resizing it there resizes nothing
	_vw.resize(VOICES)
	_vg.resize(VOICES)
	_ve1.resize(VOICES)
	_ve2.resize(VOICES)
	_vk1.resize(VOICES)
	_vk2.resize(VOICES)
	_vph.resize(VOICES)
	_vl.resize(VOICES)
	_vr.resize(VOICES)
	_table()
	_setup()
	set_level(0.5)


## Whether there is anything to hear.
func active() -> bool:
	return not _bands.is_empty() or _in.has("crickets")


## THE DIAL, 0-1: the level, how hard what moves strikes, and how bright it is - distance, in one.
func set_level(d: float) -> void:
	d = clampf(d, 0.0, 1.0)
	# on a curve: the middle of the dial is where a place usually sits, and the bottom is far away
	_gain = 0.0 if d <= 0.0 else db_to_linear(lerpf(LEVEL_DB.x, LEVEL_DB.y, pow(d, 0.75))) * smoothstep(0.0, FADE_IN, d)
	_contrast = lerpf(0.55, 1.5, d)
	_snap = lerpf(0.4, 1.25, d)
	# the floor sinks as the dial rises - more contrast, never silence: -6 dB low, -11 dB at the top
	_floor = db_to_linear(lerpf(FLOOR_DB.x, FLOOR_DB.y, d))
	var fc := lerpf(2400.0, 12000.0, d)
	_bright = 1.0 - exp(-TAU * minf(fc, _sr * 0.45) / _sr)
	if _n == 0:
		_gain0 = _gain


## THE VOICE WITH THE PLACE UNDER IT: [param voice] with this many samples of the soundscape added,
## ducked under speech, and the next call carrying on where this one stopped.
func mix(voice: PackedVector2Array) -> PackedVector2Array:
	var n := voice.size()
	_fill(n)
	var out := PackedVector2Array()
	out.resize(n)
	var d := _duck
	var ka := 1.0 - exp(-1.0 / (DUCK_ATTACK * _sr))
	var kr := 1.0 - exp(-1.0 / (DUCK_RELEASE * _sr))
	var ol := _ol
	var orr := _or
	var at := _oat
	for i in n:
		var v := voice[i]
		var a := maxf(absf(v.x), absf(v.y))
		d += (a - d) * (ka if a > d else kr)
		var g := 1.0 - DUCK * minf(1.0, d * 5.0)
		var x := v.x + ol[at + i] * g
		var y := v.y + orr[at + i] * g
		# a soft knee above 0.9, so a crash under a loud word bends rather than clips
		if absf(x) > 0.9:
			x = signf(x) * (0.9 + 0.1 * tanh((absf(x) - 0.9) * 10.0))
		if absf(y) > 0.9:
			y = signf(y) * (0.9 + 0.1 * tanh((absf(y) - 0.9) * 10.0))
		out[i] = Vector2(x, y)
	_duck = d
	_oat += n
	if _oat >= 8192:
		_ol = _ol.slice(_oat)
		_or = _or.slice(_oat)
		_oat = 0
	return out


## The soundscape alone, [param n] samples of it (for a probe, and a gate).
func render(n: int) -> PackedVector2Array:
	var silent := PackedVector2Array()
	silent.resize(n)
	var keep := _duck
	var out := mix(silent)
	_duck = keep
	return out


## RENDER AHEAD ON A WORKER, so the main thread only copies: called every frame by whoever plays it,
## it keeps [param seconds] rendered past what has been handed out. The synthesis is GDScript, sample
## by sample - a tenth of a core or more for a busy place - and on the main thread it was frame time.
## The worker alone touches the synthesis while it runs; [method mix] waits for it before going on.
func prefetch(seconds := 1.5) -> void:
	_collect(false)
	if _task < 0 and _ol.size() - _oat < int(seconds * _sr):
		_task = WorkerThreadPool.add_task(_ahead.bind(int(seconds * _sr)), false, "soundscape")


## Wait for the worker, if one is running - before this is let go.
func finish() -> void:
	_collect(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)


func _ahead(n: int) -> void:
	var l := PackedFloat32Array()
	var r := PackedFloat32Array()
	for i in ceili(float(n) / float(CR)):
		_block()
		l.append_array(_bl)
		r.append_array(_br)
	_fresh_l = l
	_fresh_r = r


func _collect(wait: bool) -> void:
	if _task < 0 or (not wait and not WorkerThreadPool.is_task_completed(_task)):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_ol.append_array(_fresh_l)
	_or.append_array(_fresh_r)
	_fresh_l = PackedFloat32Array()
	_fresh_r = PackedFloat32Array()


func _fill(n: int) -> void:
	if _ol.size() - _oat < n:
		_collect(true)
	while _ol.size() - _oat < n:
		_block()
		_ol.append_array(_bl)
		_or.append_array(_br)


static func _table() -> PackedFloat32Array:
	_noise_lock.lock()
	if _noise.is_empty():
		var r := RandomNumberGenerator.new()
		r.seed = 0x5ca9e
		var t := PackedFloat32Array()
		t.resize(_NM + 1)
		for i in t.size():
			t[i] = r.randf_range(-1.0, 1.0) * 1.7320508     # unit variance
		_noise = t
	_noise_lock.unlock()
	return _noise


func _rand() -> float:
	var x := _rng
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	_rng = x
	return float(x) / 4294967296.0


func _range(a: float, b: float) -> float:
	return a + (b - a) * _rand()


## Log-normal around 1: how hard a drop, a crackle or a slap is.
func _hard(spread: float) -> float:
	var u := maxf(1e-6, _rand())
	return exp(spread * sqrt(-2.0 * log(u)) * cos(TAU * _rand()) - 0.5 * spread * spread)


func _band(src: int, mode: int, fc: float, q: float, wide: bool) -> Band:
	var b := Band.new()
	b.src = src
	b.mode = mode
	b.fc = fc
	b.q = q
	b.wide = wide
	_bands.append(b)
	return b


## Constant-power ears for a sound at [param from] degrees (90 the reader's right), never hard to one side.
static func _ears(from: float, width := 0.8) -> Vector2:
	return _pan(sin(deg_to_rad(from)) * width)


## THE EARS for a balance [param p], -1 the left to 1 the right: the far ear never more than
## [constant MOST_APART] dB under the near one, and the power the same wherever it is. A sound to one
## side is heard in BOTH ears, quieter in the far one - the head shadows it by some 6-10 dB, not
## wholly. A pan law did this first, and a wind heard through a window on the right was all in the
## right ear (the user, 2026-10-08: "that feels terrible ... you would still hear that sound in BOTH
## ears"). The voice's own Lean holds the same line (never past 70/30, [VoiceFX]).
static func _pan(p: float) -> Vector2:
	p = clampf(p, -1.0, 1.0)
	var far := db_to_linear(-MOST_APART * absf(p))
	var near := sqrt(2.0 / (1.0 + far * far))
	far *= near
	return Vector2(far, near) if p >= 0.0 else Vector2(near, far)


func _setup() -> void:
	if _sound.get("wind") is Dictionary and not _wind.is_empty():
		var w: Dictionary = _sound["wind"]
		var through := String(w["through"])
		# THIS WIND'S TYPICAL GUST, as the sound reckons speed: its breeze and an average gust over it
		var peaks: PackedFloat32Array = _wind["peaks"]
		var mean := 0.0
		for p in peaks:
			mean += p
		mean = mean / float(peaks.size()) * 0.75 if not peaks.is_empty() else 0.0
		_w = {"level": float(w["level"]), "through": through, "at": w.get("from"),
			"ref": maxf(0.03, (float(_wind["breeze"]) + mean) / Winds.FULL),
			"rush": _band(0, 1, 500.0, 0.9, true), "low": _band(1, 0, 200.0, 0.7, false)}
		match through:
			"trees", "grass":
				_w["leaves"] = _band(0, 1, 3000.0, 0.6 if through == "trees" else 0.7, true)
				_w["fl"] = Vector2.ZERO
			"rigging":
				var tones: Array = []
				for i in 3:
					var b := _band(0, 3, 800.0, 38.0, false)
					tones.append([b, _range(420.0, 1500.0), [-0.55, 0.0, 0.55][i]])
				_w["tones"] = tones
			"tunnel":
				var f0 := _range(55.0, 95.0)
				_w["modes"] = [[_band(0, 3, f0, 6.0, false), f0, 0.05], [_band(0, 3, f0 * 2.0, 7.0, false), f0 * 2.0, 0.035],
					[_band(0, 3, f0 * 3.07, 8.0, false), f0 * 3.07, 0.02]]
			"eaves":
				# broad enough not to beat: a narrower moan whirred like something spinning
				_w["moan"] = _band(0, 3, 220.0, 3.5, false)
				_w["gap"] = _band(0, 3, 900.0, 16.0, false)
			"canvas":
				var flap := _band(0, 1, 230.0, 1.2, false)
				var snap := _band(0, 1, 1500.0, 1.4, false)
				flap.am_depth = 1.0
				snap.am_depth = 1.0
				_w["flap"] = flap
				_w["snap"] = snap
	if _sound.get("water") is Dictionary:
		var x: Dictionary = _sound["water"]
		var kind := String(x["kind"])
		_wa = {"kind": kind, "size": float(x["size"]), "from": float(x["from"]), "ears": _ears(float(x["from"])), "far": float(x["distance"]),
			"next": _range(0.5, 3.0), "waves": [], "ph": Vector2(_rand() * TAU, _rand() * TAU), "plinks": []}
		if kind == "shore":
			_wa["body"] = _band(0, 1, 500.0, 0.7, true)
			_wa["roar"] = _band(1, 0, 300.0, 0.7, false)
			_wa["fizz"] = _band(0, 1, 5000.0, 0.6, true)
		else:
			_wa["swell"] = _band(1, 0, 220.0, 0.7, false)
			_wa["wash"] = _band(0, 1, 500.0, 0.8, true)
			_wa["slaps"] = [_band(0, 1, 400.0, 1.4, false), _band(0, 1, 400.0, 1.4, false)]
			_wa["sloshes"] = [_band(0, 1, 1100.0, 1.5, false), _band(0, 1, 1100.0, 1.5, false)]
			for b in (_wa["slaps"] as Array) + (_wa["sloshes"] as Array):
				(b as Band).steady = 0.0
			for b in _wa["sloshes"]:
				(b as Band).am_depth = 0.55
			var spray := _band(0, 1, 5500.0, 0.5, true)
			spray.steady = 0.0
			_wa["spray"] = spray
			_wa["k"] = 0
	if _sound.get("rain") is Dictionary:
		var r: Dictionary = _sound["rain"]
		var on: Dictionary = RAINS[String(r["on"])]
		_ra = {"on": String(r["on"]), "strength": float(r["strength"]), "spec": on, "next": 0.0, "k": 0,
			"hiss": _band(0, 1, float(on["hiss"]), 0.5, true), "drops": []}
		if String(r["on"]) != "water":
			for i in 4:
				var b := _band(0, 1, float(on["fc"]), float(on["q"]), false)
				b.steady = 0.0
				(_ra["drops"] as Array).append(b)
		else:
			# drops on water: a small splash each, and the plink of its bubble
			for i in 2:
				var b := _band(0, 1, 3000.0, 1.0, false)
				b.steady = 0.0
				(_ra["drops"] as Array).append(b)
	if _sound.get("fire") is Dictionary:
		var f: Dictionary = _sound["fire"]
		_fi = {"size": float(f["size"]), "from": float(f["from"]), "ears": _ears(float(f["from"]), 0.7), "far": float(f["distance"]),
			"roar": _band(1, 0, 200.0, 0.7, false), "hiss": _band(0, 1, 3500.0, 0.5, true), "flame": 0.0, "flick": 0.0,
			"next": _range(0.05, 0.5), "k": 0, "crackles": [], "follow": 0}
		for i in 4:
			var b := _band(0, 1, 3000.0, 2.5, false)
			b.steady = 0.0
			(_fi["crackles"] as Array).append(b)
	if _sound.get("stream") is Dictionary:
		var s: Dictionary = _sound["stream"]
		_st = {"size": float(s["size"]), "from": float(s["from"]), "ears": _ears(float(s["from"]), 0.7), "far": float(s["distance"]),
			"burble": _band(0, 1, 700.0, 0.6, true), "low": _band(1, 0, 350.0, 0.7, false), "next": 0.0, "mod": 0.0}
	if _sound.get("insects") is Dictionary:
		var i: Dictionary = _sound["insects"]
		var kind := String(i["kind"])
		var strength := float(i["strength"])
		if kind == "crickets":
			var crickets: Array = []
			for c in 3 + int(_rand() * 3.0):
				crickets.append({"f": _range(3900.0, 5200.0), "every": _range(0.5, 1.1), "pulses": 3 + int(_rand() * 2.0),
					"gap": _range(0.026, 0.038), "amp": _range(0.35, 1.0), "ears": _ears(_range(0.0, 360.0), 0.85),
					"next": _range(0.0, 1.0), "sing": _range(4.0, 20.0)})
			_in = {"crickets": crickets, "strength": strength}
		else:
			var bands: Array = []
			for c in 2:
				var b := _band(0, 1, _range(4300.0, 6000.0), 5.0, false)
				b.am_rate = _range(150.0, 220.0)
				b.am_depth = 0.85
				bands.append({"band": b, "ears": _ears(_range(0.0, 360.0), 0.8), "t": _range(-8.0, 0.0), "rise": 3.0,
					"hold": _range(4.0, 10.0), "fall": 2.5, "rest": _range(5.0, 18.0)})
			_in = {"cicadas": bands, "strength": strength}


# --- a block ------------------------------------------------------------------------------------------

func _block() -> void:
	var t := _t0 + float(_n) / _sr
	var dt := float(CR) / _sr
	_bl.fill(0.0)
	_br.fill(0.0)
	for b in _bands:
		b._gl0 = b.gl
		b._gr0 = b.gr
	_air(t, dt)
	if not _w.is_empty():
		_wind_block(dt)
	if not _wa.is_empty():
		_water_block(t, dt)
	if not _ra.is_empty():
		_rain_block(t, dt)
	if not _fi.is_empty():
		_fire_block(t, dt)
	if not _st.is_empty():
		_stream_block(dt)
	if not _in.is_empty():
		_insects_block(t, dt)
	for b in _bands:
		_run(b)
	_run_voices()
	# the dial: level eased across the block, then the brightness of distance
	# the dial's level, and the fade in at the start (a smoothstep, eased across the block)
	var fn := FADE * _sr
	var f0 := smoothstep(0.0, fn, float(_n))
	var f1 := smoothstep(0.0, fn, float(_n + CR))
	var g0 := _gain0 * f0
	var dg := (_gain * f1 - _gain0 * f0) / float(CR)
	var a := _bright
	var lp := _lp
	var peak := 0.0
	for i in CR:
		var g := g0 + dg * float(i)
		lp.x += a * (_bl[i] * g - lp.x)
		lp.y += a * (_br[i] * g - lp.y)
		_bl[i] = lp.x
		_br[i] = lp.y
		peak = maxf(peak, maxf(absf(lp.x), absf(lp.y)))
	_lp = lp
	# THE LIMITER: closes on a block that would pass the ceiling (eased in across it), opens slowly
	var lim0 := _limit
	var lim := minf(lim0 + (1.0 - lim0) * (1.0 - exp(-dt / LIMIT_RELEASE)), CEILING / maxf(peak, 1e-9))
	if lim < 1.0 or lim0 < 1.0:
		var dl := (lim - lim0) / float(CR)
		for i in CR:
			var l := minf(lim0 + dl * float(i), CEILING / maxf(1e-9, maxf(absf(_bl[i]), absf(_br[i]))))
			_bl[i] *= l
			_br[i] *= l
	_limit = lim
	_gain0 = _gain
	_n += CR
	# ON A WORKER, A BREATH now and then: GDScript calls in a tight worker loop once starved the main
	# thread to a few frames a second (TableMedium._breathe). Not measured here (a busy place rendered
	# beside a main loop kept its frame rate), and it costs nothing.
	if (_n / CR) % 16 == 0 and OS.get_thread_caller_id() != OS.get_main_thread_id():
		OS.delay_usec(0)


## THE WIND HEARD at [param t]: the table's plan, with the quick turbulence real air has over it (the
## plan's breeze and gusts are seconds long; a gust is ragged within).
func _air(t: float, dt: float) -> void:
	if _wind.is_empty():
		return
	var s := Winds.speed_at(_wind, t + LEAD)
	var breeze := Winds.breeze_at(_wind, t + LEAD)
	# REAL AIR IS RAGGED - slowly: a drift over a second or two and a little shimmer, each a smoothed
	# noise scaled back to unit size. It was one noise at ~4 Hz moving the level by 60% and the rush's
	# pitch with it, and in a gust that churned like a washing machine.
	var k1 := 1.0 - exp(-dt / 1.5)
	var k2 := 1.0 - exp(-dt / 0.35)
	_drift += (_rand() * 2.0 - 1.0 - _drift) * k1
	_shimmer += (_rand() * 2.0 - 1.0 - _shimmer) * k2
	var drift := clampf(_drift / sqrt(k1 / 6.0), -2.0, 2.0)
	var shimmer := clampf(_shimmer / sqrt(k2 / 6.0), -2.0, 2.0)
	_turb = drift * 0.5
	var target := log(maxf(0.01, s * (1.0 + 0.12 * drift + 0.04 * shimmer)))
	if _log2 == INF:
		_log1 = target
		_log2 = target
	var k := 1.0 - exp(-dt / (HOLD.x if target > _log2 else HOLD.y))
	_log1 += (target - _log1) * k
	var was := _log2
	_log2 += (_log1 - _log2) * k
	_log2 = minf(_log2, was + RISE_MOST * dt)
	_held = exp(_log2)
	var breath := 1.0 + BREATH * (0.5 * sin(TAU * t / float(BREATHS[0]) + _breath.x)
		+ 0.3 * sin(TAU * t / float(BREATHS[1]) + _breath.y) + 0.2 * sin(TAU * t / float(BREATHS[2]) + _breath.z))
	var w := maxf(0.0, _held / Winds.FULL * breath)
	_speed = w
	_gust = clampf((_held - breeze) / Winds.FULL, 0.0, 1.0)
	_lag += (w - _lag) * (1.0 - exp(-dt / 0.35))
	# WHICH WAY IT BLOWS NOW: the breeze's way and each gust's own, by how hard each blows - so a gust
	# that veers moves the balance with it. The air comes from the opposite way it goes.
	var v: Vector2 = (_wind["dir"] as Vector2) * breeze
	var span := Winds._blowing(_wind, t)
	var dirs: PackedVector2Array = _wind["dirs"]
	var peaks: PackedFloat32Array = _wind["peaks"]
	for i in range(span.x, span.y):
		v += dirs[i] * peaks[i] * Winds.swell(_wind, i, t)
	var side := -v.x / v.length() if v.length() > 1e-5 else 0.0
	_side += (side - _side) * (1.0 - exp(-dt / 0.3))


## A PLACE EBBS AND FLOWS, NEVER TO NOTHING: [param rel] is how hard it is now beside how hard it
## usually is (1 its typical gust or wave), shaped by [param e] (the dial's contrast), with a floor
## [param f] under it - the two added as powers, so the floor is a soft knee and not a corner. Reported
## 2026-10-08 on a breeze through eaves: "a big gust of sound, which drops to 0" - the loudness was a
## power of the wind's speed alone, and a breeze between gusts is a quarter of a gust's speed, so the
## place fell 30 dB and more, silent, between every gust.
##
## Above its typical gust a place swells more gently than below it (a square root of the excess), so
## the strongest gust of a show stands out without leaping 20 dB over the rest.
static func _ebb(rel: float, e: float, f: float) -> float:
	var r := clampf(rel, 0.0, 3.0)
	if r > 1.0:
		r = 1.0 + sqrt(r - 1.0) * 0.45
	return sqrt(pow(r, 2.0 * e) + f * f)


## THE WIND HEARD, by what it blows through. Its loudness follows the wind beside the wind's own TYPICAL
## gust (`ref`, from its plan), so a light breeze ebbs and swells as much as a gale does; how strong
## the wind is sets the place's level only gently (its square root), and the agent's `level` is the
## volume. What sounds only in a gust (a moan, rigging singing, canvas flapping) waits for this wind's
## gusts, not for some absolute speed a breeze never reaches. The pitches follow the real speed.
func _wind_block(dt: float) -> void:
	# the agent's level, gently: 0.3 is quieter than the rest, not a tenth as loud
	var lvl := pow(float(_w["level"]), 0.6) * 2.6
	var w := _speed
	var c := _contrast
	var ref := float(_w["ref"])
	var rel := w / ref
	var size := sqrt(minf(ref, 1.3))
	var through := String(_w["through"])
	var rush: Band = _w["rush"]
	var low: Band = _w["low"]
	# WHERE IT IS HEARD: at the opening it gets in by, or louder on the side it blows from
	var at: Variant = _w.get("at")
	var ears := _ears(float(at), 0.85) if at != null else _pan(0.55 * _side)
	var rg := lvl * 0.3 * size * _ebb(rel, 0.9 * c, _floor)
	rush.fc = 280.0 + 1000.0 * minf(w, 1.3)
	if through == "eaves":
		rush.fc = 180.0 + 420.0 * minf(w, 1.3)
	elif through == "tunnel":
		rush.fc = 150.0 + 520.0 * minf(w, 1.3)
	elif through in ["trees", "grass"]:
		rg *= 0.6
	if through == "eaves":
		rg *= 1.4
	rush.gl = rg * ears.x
	rush.gr = rg * ears.y
	# THE RUMBLE: under the rush, and up only in a real gust
	low.fc = 220.0 + 160.0 * minf(w, 1.3)
	var lg := lvl * (0.16 if through == "tunnel" else 0.09) * size * _ebb(rel, 1.3 * c, _floor * 0.3)
	low.gl = lg * ears.x
	low.gr = lg * ears.y
	match through:
		"trees", "grass":
			var leaves: Band = _w["leaves"]
			var trees := through == "trees"
			# the leaves clatter: each ear's own flutter, sparse in a breath and dense in a gust
			var fl: Vector2 = _w["fl"]
			var k := 0.45 if trees else 0.2
			fl.x += (_rand() * _rand() * 2.2 - fl.x) * k
			fl.y += (_rand() * _rand() * 2.2 - fl.y) * k
			_w["fl"] = fl
			var lw := minf(_lag, 1.4)
			var lrel := _lag / ref
			leaves.fc = (2400.0 + 2400.0 * lw) if trees else (1600.0 + 1300.0 * lw)
			var depth := clampf(0.8 - 0.35 * lrel, 0.2, 0.8)
			var base := lvl * (0.3 if trees else 0.25) * size * _ebb(lrel, 1.1 * c, _floor)
			# leaves are all round: they lean with the wind, but less
			var le := _pan(0.3 * _side) if at == null else ears
			leaves.gl = base * (1.0 - depth + depth * fl.x) * le.x
			leaves.gr = base * (1.0 - depth + depth * fl.y) * le.y
		"rigging":
			for tone in _w["tones"]:
				var b: Band = tone[0]
				b.fc = float(tone[1]) * (0.5 + 0.7 * minf(w, 1.3)) * (1.0 + 0.01 * _turb)
				var tg := lvl * 0.04 * size * pow(smoothstep(0.6, 1.6, rel), 2.0 * c)
				var e := _pan(float(tone[2]) + 0.3 * _side) if at == null else ears
				b.gl = tg * e.x
				b.gr = tg * e.y
		"eaves":
			var moan: Band = _w["moan"]
			var gap: Band = _w["gap"]
			moan.fc = 150.0 + 230.0 * minf(w, 1.3)
			var mg := lvl * 0.1 * size * pow(smoothstep(0.4, 1.5, rel), 1.5 * c)
			moan.gl = mg * ears.x
			moan.gr = mg * ears.y
			gap.fc = 760.0 + 420.0 * minf(w, 1.3)
			var gg := lvl * 0.028 * size * pow(smoothstep(0.9, 1.8, rel), 2.0 * c)
			gap.gl = gg * ears.x
			gap.gr = gg * ears.y
		"canvas":
			var flap: Band = _w["flap"]
			var snap: Band = _w["snap"]
			var rate := (1.8 + 5.5 * minf(w, 1.3)) * (1.0 + 0.25 * _turb)
			flap.am_rate = rate
			snap.am_rate = rate
			snap.am_ph = flap.am_ph
			var fg := lvl * 0.6 * size * pow(smoothstep(0.35, 1.2, rel), 1.4 * c)
			flap.gl = fg * ears.x
			flap.gr = fg * ears.y
			var sg := lvl * 0.18 * _snap * size * pow(smoothstep(0.8, 1.7, rel), 1.6 * c)
			snap.gl = sg * ears.x
			snap.gr = sg * ears.y
		"tunnel":
			# A HOLLOW: the passage's own modes, a low howl that rises with the air and booms in a gust
			for mode in _w["modes"]:
				var b: Band = mode[0]
				b.fc = float(mode[1]) * (1.0 + 0.06 * minf(w, 1.3) + 0.01 * _turb)
				var tg := lvl * float(mode[2]) * 0.7 * size * pow(smoothstep(0.25, 1.4, rel), 1.8 * c)
				b.gl = tg * ears.x
				b.gr = tg * ears.y


func _water_block(t: float, dt: float) -> void:
	var kind := String(_wa["kind"])
	var size := float(_wa["size"])
	var e: Vector2 = _wa["ears"]
	var far := float(_wa["far"])
	var near := lerpf(1.0, 0.35, far)
	var dull := lerpf(1.0, 0.35, far)
	var c := _contrast
	var rough := size * (0.85 + 0.3 * _gust)
	if kind == "shore":
		# WAVES: each gathers, breaks, and washes away; the next often arrives before the last is gone
		var waves: Array = _wa["waves"]
		if t >= float(_wa["next"]):
			var amp := _range(0.5, 1.0) * (0.45 + 0.55 * size)
			if _rand() < 0.15:
				amp = minf(1.2, amp * 1.35)
			waves.append({"t0": t, "build": _range(1.3, 2.4), "brk": _range(0.25, 0.55), "wash": _range(2.8, 5.5) * (0.8 + 0.4 * size), "amp": amp})
			_wa["next"] = t + lerpf(11.0, 6.5, size) * _range(0.7, 1.3)
		var body := 0.0
		var bright := 0.0
		var fizz := 0.0
		var keep: Array = []
		for wv in waves:
			var d: Dictionary = wv
			var tau := t - float(d["t0"])
			var a := float(d["amp"])
			var build := float(d["build"])
			var brk := float(d["brk"])
			var wash := float(d["wash"])
			if tau < build:
				var u := tau / build
				body += a * 0.45 * u * u
				bright += a * 0.15 * u
			elif tau < build + brk:
				var v := (tau - build) / brk
				body += a * (0.45 + 0.55 * v)
				bright += a * (0.15 + 0.85 * v)
				fizz += a * 0.7 * v
			else:
				var x := tau - build - brk
				body += a * exp(-x / (wash * 0.3))
				bright += a * exp(-x / (wash * 0.22))
				fizz += a * 0.7 * exp(-x / wash)
				if x > wash * 4.0:
					continue
			keep.append(d)
		_wa["waves"] = keep
		# A BREAKER HOLDS: the water heard follows the waves up at once and lets go slowly, so a wash
		# falls back to half or so before the next set rather than to the bed
		var held := float(_wa.get("held", body))
		held += (body - held) * (1.0 - exp(-dt / (0.25 if body > held else 2.2)))
		_wa["held"] = held
		body = held
		var bed := 0.12 + 0.18 * size
		var ph: Vector2 = _wa["ph"]
		bed *= 1.0 + 0.2 * sin(0.21 * t + ph.x) + 0.12 * sin(0.53 * t + ph.y) + 0.1 * sin(0.083 * t + ph.x * 1.7)
		var bb: Band = _wa["body"]
		var rr: Band = _wa["roar"]
		var fz: Band = _wa["fizz"]
		bb.fc = (300.0 + 1700.0 * minf(bright, 1.2)) * dull
		# beside a typical breaker, and never below the floor between them
		var typical := 0.75 * (0.45 + 0.55 * size)
		var bg := 0.55 * near * typical * _ebb((body + bed) / typical, c, _floor * 1.4)
		bb.gl = bg * e.x
		bb.gr = bg * e.y
		var rg := 0.3 * near * typical * _ebb((body * 0.8 + bed) / typical, c, _floor * 1.4)
		rr.gl = rg * e.x
		rr.gr = rg * e.y
		fz.fc = 4800.0 * dull
		var fg := 0.25 * near * _snap * pow(minf(fizz, 1.2), c) * (0.7 + 0.6 * _rand())
		fz.gl = fg * (0.6 + 0.4 * e.x)
		fz.gr = fg * (0.6 + 0.4 * e.y)
		# the wash's bubbles, a few for every fizz
		var rate := 60.0 * fizz * near
		if _rand() < rate * dt:
			_bubble(_range(1500.0, 3800.0) * dull, _range(0.003, 0.008), _range(0.1, 0.3), 0.06 * near * _hard(0.6),
				_ears(float(_wa["from"]) + _range(-40.0, 40.0), 0.8))
		return
	# AGAINST A HULL OR A PILING: the swell under it, and slaps as each wave meets it
	var hull := kind == "hull"
	var ph2: Vector2 = _wa["ph"]
	# the swell rises and falls on three periods that never line up, and drifts besides
	var sdrift := float(_wa.get("drift", 0.0))
	sdrift += (_rand() * 2.0 - 1.0 - sdrift) * (1.0 - exp(-dt / 4.0))
	_wa["drift"] = sdrift
	var swell := 0.6 + 0.2 * sin(TAU * t / 8.5 + ph2.x) + 0.12 * sin(TAU * t / 5.3 + ph2.y) + 0.08 * sin(TAU * t / 13.7 + ph2.x * 2.3) \
		+ 0.1 * clampf(sdrift / sqrt((1.0 - exp(-dt / 4.0)) / 6.0), -2.0, 2.0) * 0.5
	var sw: Band = _wa["swell"]
	var wash: Band = _wa["wash"]
	sw.fc = 200.0 if hull else 260.0
	var sg := (0.4 if hull else 0.25) * near * (0.4 + 0.6 * rough) * 0.6 * _ebb(swell / 0.6, c, _floor * 1.4)
	sw.gl = sg
	sw.gr = sg
	wash.fc = (500.0 if hull else 650.0) * dull
	var wg := (0.12 if hull else 0.09) * near * (0.3 + 0.7 * rough) * 0.5 * _ebb(swell / 0.6, 1.5 * c, _floor * 1.4)
	wash.gl = wg * (0.7 + 0.3 * e.x)
	wash.gr = wg * (0.7 + 0.3 * e.y)
	if t >= float(_wa["next"]):
		var amp := _range(0.35, 1.0) * (0.45 + 0.55 * rough)
		var k := int(_wa["k"])
		_wa["k"] = k + 1
		var slap: Band = (_wa["slaps"] as Array)[k % 2]
		var slosh: Band = (_wa["sloshes"] as Array)[k % 2]
		var side := _ears(float(_wa["from"]) + _range(-60.0, 60.0), 0.9)
		slap.fc = _range(260.0, 520.0) * (1.0 if hull else 1.4) * dull
		slap.gl = side.x
		slap.gr = side.y
		slap.strike(amp * _snap * (0.14 if hull else 0.1) * near, _range(0.1, 0.2) if hull else _range(0.06, 0.12), 0.006, _sr)
		slosh.fc = _range(800.0, 1500.0) * dull
		slosh.am_rate = _range(8.0, 16.0)
		slosh.gl = side.x
		slosh.gr = side.y
		slosh.strike(amp * 0.08 * near, _range(0.4, 0.9), 0.06, _sr)
		# the bubbles after it, through the next half second
		var plinks: Array = _wa["plinks"]
		var count := (2 + int(_rand() * 3.0)) if hull else (3 + int(_rand() * 5.0))
		for j in count:
			plinks.append([t + _range(0.04, 0.6), side])
		if hull and amp > 0.8 and size > 0.5:
			var spray: Band = _wa["spray"]
			spray.gl = 1.0
			spray.gr = 1.0
			spray.strike(0.04 * near * amp, 0.7, 0.05, _sr)
		var gap := (_range(1.2, 3.8) if hull else _range(0.7, 2.6)) / (0.7 + 0.6 * size) / (1.0 + 0.5 * _gust)
		_wa["next"] = t + gap
	var due: Array = []
	for p in _wa["plinks"]:
		if t >= float(p[0]):
			_bubble(_range(450.0, 1500.0) * (1.0 if hull else 1.3), _range(0.012, 0.035), _range(0.15, 0.4),
				0.03 * near * _hard(0.5), p[1])
		else:
			due.append(p)
	_wa["plinks"] = due


func _rain_block(t: float, dt: float) -> void:
	var on := String(_ra["on"])
	var spec: Dictionary = _ra["spec"]
	var strength := float(_ra["strength"])
	var hiss: Band = _ra["hiss"]
	var hg := 0.22 * pow(strength, 0.8) * (1.0 + 0.4 * _gust) * (0.5 if on == "window" else 1.0)
	hiss.gl = hg
	hiss.gr = hg
	var rate := (12.0 + 380.0 * pow(strength, 1.4)) * (1.0 + 0.6 * _gust)
	var next := float(_ra["next"])
	if next <= 0.0:
		next = t
	var drops: Array = _ra["drops"]
	var struck := 0
	while next < t + dt and struck < drops.size():
		var k := int(_ra["k"])
		_ra["k"] = k + 1
		var b: Band = drops[k % drops.size()]
		var e := _ears(_range(0.0, 360.0), 0.9)
		var hard := _hard(0.5) * _snap
		if on == "water":
			b.fc = _range(2500.0, 6000.0)
			b.gl = e.x
			b.gr = e.y
			b.strike(0.015 * hard, 0.004, 0.0004, _sr)
			if _rand() < 0.5:
				_bubble(_range(1800.0, 4200.0), _range(0.004, 0.012), _range(0.15, 0.45), 0.02 * hard, e)
		else:
			b.fc = float(spec["fc"]) * pow(2.0, _range(-1.0, 1.0) * float(spec["spread"]))
			b.gl = e.x
			b.gr = e.y
			var amt := 0.03 * hard
			b.strike(amt, float(spec["ring"]) * _range(0.7, 1.4), 0.0003, _sr)
		struck += 1
		next += -log(maxf(1e-6, _rand())) / rate
	_ra["next"] = maxf(next, t + dt) if struck >= drops.size() else next


func _fire_block(t: float, dt: float) -> void:
	var size := float(_fi["size"])
	var e: Vector2 = _fi["ears"]
	var far := float(_fi["far"])
	var near := lerpf(1.0, 0.35, far)
	var dull := lerpf(1.0, 0.45, far)
	var fan := 1.0 + 0.8 * _gust
	var flame := float(_fi["flame"]) + (_rand() * 2.0 - 1.0 - float(_fi["flame"])) * 0.03
	var flick := float(_fi["flick"]) + (_rand() - float(_fi["flick"])) * 0.25
	_fi["flame"] = flame
	_fi["flick"] = flick
	var roar: Band = _fi["roar"]
	roar.fc = (150.0 + 120.0 * size) * (1.0 + 0.3 * _gust)
	var rg := 0.45 * near * size * fan * (0.7 + 0.5 * flame)
	roar.gl = rg * e.x
	roar.gr = rg * e.y
	var hiss: Band = _fi["hiss"]
	hiss.fc = 3500.0 * dull
	var hg := 0.06 * near * (0.3 + 0.7 * size) * (0.3 + 1.4 * flick * flick) * fan
	hiss.gl = hg * (0.5 + 0.5 * e.x)
	hiss.gr = hg * (0.5 + 0.5 * e.y)
	var crackles: Array = _fi["crackles"]
	var struck := 0
	while t >= float(_fi["next"]) and struck < crackles.size():
		var k := int(_fi["k"])
		_fi["k"] = k + 1
		var b: Band = crackles[k % crackles.size()]
		var pop := _rand() < 0.06
		b.fc = (_range(600.0, 1000.0) if pop else exp(_range(log(1300.0), log(5500.0)))) * dull
		b.q = 2.0 if pop else 2.6
		var side := _ears(float(_fi["from"]) + _range(-25.0, 25.0), 0.8)
		b.gl = side.x
		b.gr = side.y
		var amt := (0.05 if pop else 0.03) * near * _snap * _hard(0.7)
		b.strike(amt, _range(0.012, 0.02) if pop else _range(0.0012, 0.004), 0.0002, _sr)
		struck += 1
		# CRACKLES COME IN CLUSTERS: a split log often fires again a few tens of milliseconds later
		var follow := int(_fi["follow"])
		if follow > 0:
			_fi["follow"] = follow - 1
			_fi["next"] = t + _range(0.008, 0.06)
		else:
			if _rand() < 0.35:
				_fi["follow"] = 1 + int(_rand() * 3.0)
			var rate := (1.5 + 12.0 * size) * fan
			_fi["next"] = t + -log(maxf(1e-6, _rand())) / rate


func _stream_block(dt: float) -> void:
	var size := float(_st["size"])
	var e: Vector2 = _st["ears"]
	var near := lerpf(1.0, 0.35, float(_st["far"]))
	var mod := float(_st["mod"]) + (_rand() * 2.0 - 1.0 - float(_st["mod"])) * 0.06
	_st["mod"] = mod
	var bb: Band = _st["burble"]
	bb.fc = 650.0 + 400.0 * size + 150.0 * mod
	var bg := 0.22 * near * (0.3 + 0.7 * size) * (0.75 + 0.5 * mod)
	bb.gl = bg * (0.4 + 0.6 * e.x)
	bb.gr = bg * (0.4 + 0.6 * e.y)
	var low: Band = _st["low"]
	var lg := 0.18 * near * size
	low.gl = lg * e.x
	low.gr = lg * e.y
	# THE BABBLE: bubbles, many a second, each its own size
	var rate := (30.0 + 170.0 * size) * near
	var n := 0
	var p := rate * dt
	while _rand() < p and n < 4:
		n += 1
		p *= 0.8
		var f := exp(_range(log(450.0), log(2400.0))) * (1.15 - 0.35 * size)
		_bubble(f, _range(0.006, 0.025), _range(0.15, 0.5), 0.07 * near * _hard(0.6),
			_ears(float(_st["from"]) + _range(-35.0, 35.0), 0.8))


func _insects_block(t: float, dt: float) -> void:
	var strength := float(_in["strength"])
	if _in.has("crickets"):
		for c in _in["crickets"]:
			var d: Dictionary = c
			# each sings a while, then rests
			if t >= float(d["sing"]):
				d["sing"] = t + _range(4.0, 22.0)
				d["rest_until"] = t + (_range(1.5, 8.0) if _rand() < 0.45 else 0.0)
			if t < float(d.get("rest_until", 0.0)):
				continue
			if t >= float(d["next"]):
				var f := float(d["f"]) * (1.0 + 0.004 * (_rand() - 0.5))
				var queue: Array = d.get("queue", [])
				for p in int(d["pulses"]):
					queue.append(t + float(d["gap"]) * float(p))
				d["queue"] = queue
				d["next"] = t + float(d["every"]) * _range(0.92, 1.08)
				d["f_now"] = f
			var q: Array = d.get("queue", [])
			var left: Array = []
			for at in q:
				if t >= float(at):
					_bubble(float(d.get("f_now", d["f"])), 0.009, 0.0, 1.4 * strength * float(d["amp"]), d["ears"], 0.003)
				else:
					left.append(at)
			d["queue"] = left
	if _in.has("cicadas"):
		for c in _in["cicadas"]:
			var d: Dictionary = c
			var b: Band = d["band"]
			var u := t - float(d["t"])
			var rise := float(d["rise"])
			var hold := float(d["hold"])
			var fall := float(d["fall"])
			var g := 0.0
			if u < 0.0:
				g = 0.0
			elif u < rise:
				g = smoothstep(0.0, 1.0, u / rise)
			elif u < rise + hold:
				g = 1.0
			elif u < rise + hold + fall:
				g = 1.0 - smoothstep(0.0, 1.0, (u - rise - hold) / fall)
			elif u > rise + hold + fall + float(d["rest"]):
				d["t"] = t
				d["hold"] = _range(4.0, 10.0)
				d["rest"] = _range(5.0, 18.0)
			var e: Vector2 = d["ears"]
			var gg := 0.6 * strength * g
			b.gl = gg * e.x
			b.gr = gg * e.y


## A SINE THAT RISES AS IT DIES: [param f] Hz, decaying over [param decay] seconds while its pitch
## climbs by [param rise] (a fraction) over that time - a bubble closing (Minnaert). A chirp is one
## that does not rise.
func _bubble(f: float, decay: float, rise: float, amp: float, ears: Vector2, attack := 0.0004) -> void:
	if f >= _sr * 0.45 or amp <= 0.0:
		return
	# THE QUIETEST VOICE is taken, never one still sounding: cut short mid-ring, a bubble clicked
	var i := 0
	var least := INF
	for v in VOICES:
		if _ve1[v] < least:
			least = _ve1[v]
			i = v
	_vw[i] = TAU * f / _sr
	_vg[i] = pow(1.0 + rise, 1.0 / maxf(1.0, decay * _sr))
	_vk1[i] = exp(-1.0 / maxf(1.0, decay * _sr))
	_vk2[i] = exp(-1.0 / maxf(1.0, attack * _sr))
	_ve1[i] = amp
	_ve2[i] = amp
	_vph[i] = 0.0
	_vl[i] = ears.x
	_vr[i] = ears.y


func _run_voices() -> void:
	var obl := _bl
	var obr := _br
	for v in VOICES:
		var e1 := _ve1[v]
		if e1 < 2e-4:
			continue
		var e2 := _ve2[v]
		var k1 := _vk1[v]
		var k2 := _vk2[v]
		var w := _vw[v]
		var ph := _vph[v]
		var l := _vl[v]
		var r := _vr[v]
		# a phasor turned each sample - no sin() per sample; the glide is stepped per block
		var cw := cos(w)
		var sw := sin(w)
		var x := cos(ph)
		var y := sin(ph)
		for i in CR:
			var a := y * (e1 - e2)
			var nx := x * cw - y * sw
			y = x * sw + y * cw
			x = nx
			e1 *= k1
			e2 *= k2
			obl[i] += a * l
			obr[i] += a * r
		_ve1[v] = e1
		_ve2[v] = e2
		_vw[v] = minf(w * pow(_vg[v], float(CR)), PI * 0.9)
		_vph[v] = fmod(ph + w * float(CR), TAU)


## ONE BAND over the block: noise, the filter, the bed eased from the last block's level, the struck
## envelope, the pulse. The filter's output is a mix of its three taps - low-pass, band-pass, and the
## input for the high-pass - so the loop carries no branch on the mode.
func _run(b: Band) -> void:
	var steady := b.steady
	var e1 := b.e1
	var e2 := b.e2
	if steady <= 0.0 and e1 < 1e-6:
		b.e1 = 0.0
		b.e2 = 0.0
		return
	if steady > 0.0 and maxf(maxf(b.gl, b.gr), maxf(b._gl0, b._gr0)) < 1e-7 and e1 < 1e-6:
		return
	var g := tan(PI * clampf(b.fc, 20.0, _sr * 0.45) / _sr)
	var k := 1.0 / maxf(0.05, b.q)
	var a1 := 1.0 / (1.0 + g * (g + k))
	var a2 := g * a1
	var a3 := g * a2
	# the taps: input, band, low
	var mx := 0.0
	var m1 := 0.0
	var m2 := 1.0
	match b.mode:
		1:
			m1 = k
			m2 = 0.0
		2:
			mx = 1.0
			m1 = -k
			m2 = -1.0
		3:
			m1 = 1.0
			m2 = 0.0
	var nz := _noise
	var s := b.s
	var s1 := s[0]
	var s2 := s[1]
	var s3 := s[2]
	var s4 := s[3]
	var bl := s[4]
	var brn := s[5]
	var k1 := b.k1
	var k2 := b.k2
	var gl := b._gl0 * steady
	var gr := b._gr0 * steady
	var dgl := (b.gl - b._gl0) * steady / float(CR)
	var dgr := (b.gr - b._gr0) * steady / float(CR)
	# a struck envelope's ears ease across the block too: moved at a stroke under a ringing tail, they clicked
	var el := b._gl0
	var er := b._gr0
	var del := (b.gl - b._gl0) / float(CR)
	var der := (b.gr - b._gr0) / float(CR)
	var o1 := int(_rand() * 65536.0)
	var o2 := int(_rand() * 65536.0)
	var brown := b.src == 1
	var lk := b.leak
	var lki := b.leak_in
	var obl := _bl
	var obr := _br
	# the pulse over the block, as a gain per sample (a flap, a buzz, a gurgle), or none
	var am := PackedFloat32Array()
	if b.am_rate > 0.0 and b.am_depth > 0.0:
		am.resize(CR)
		var aw := TAU * b.am_rate / _sr
		var ad := b.am_depth
		var aph := b.am_ph
		for i in CR:
			var u := 0.5 + 0.5 * sin(aph)
			u *= u
			am[i] = 1.0 - ad + ad * u * u * 2.0
			aph += aw
		b.am_ph = fmod(aph, TAU)
	var pulsed := not am.is_empty()
	if not b.wide:
		for i in CR:
			var x := nz[(o1 + i) & _NM]
			if brown:
				bl = bl * lk + x * lki
				x = bl
			var v3 := x - s2
			var v1 := a1 * s1 + a2 * v3
			var v2 := s2 + a2 * s1 + a3 * v3
			s1 = 2.0 * v1 - s1
			s2 = 2.0 * v2 - s2
			var y := mx * x + m1 * v1 + m2 * v2
			var env := e1 - e2
			e1 *= k1
			e2 *= k2
			if pulsed:
				y *= am[i]
			obl[i] += y * (gl + env * el)
			obr[i] += y * (gr + env * er)
			gl += dgl
			gr += dgr
			el += del
			er += der
	else:
		for i in CR:
			var x := nz[(o1 + i) & _NM]
			var xr := nz[(o2 + i) & _NM]
			if brown:
				bl = bl * lk + x * lki
				x = bl
				brn = brn * lk + xr * lki
				xr = brn
			var v3 := x - s2
			var v1 := a1 * s1 + a2 * v3
			var v2 := s2 + a2 * s1 + a3 * v3
			s1 = 2.0 * v1 - s1
			s2 = 2.0 * v2 - s2
			var w3 := xr - s4
			var w1 := a1 * s3 + a2 * w3
			var w2 := s4 + a2 * s3 + a3 * w3
			s3 = 2.0 * w1 - s3
			s4 = 2.0 * w2 - s4
			var env := e1 - e2
			e1 *= k1
			e2 *= k2
			var m := am[i] if pulsed else 1.0
			obl[i] += (mx * x + m1 * v1 + m2 * v2) * (gl + env * el) * m
			obr[i] += (mx * xr + m1 * w1 + m2 * w2) * (gr + env * er) * m
			gl += dgl
			gr += dgr
			el += del
			er += der
	s[0] = s1
	s[1] = s2
	s[2] = s3
	s[3] = s4
	s[4] = bl
	s[5] = brn
	b.e1 = e1
	b.e2 = e2
