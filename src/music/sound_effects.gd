extends RefCounted
class_name SoundEffects

## SoundEffects - the sounds a note's `<!-- sound: words -->` marks ask for, made from their words (next/sound_effects.md): a
## sound designer writes a PATCH ([constant SOURCES], [constant FIELDS]) and the music host makes it into sound
## (hosts/music/sound.py). Each sound is kept by its words' key ([method key_of]) in a folder of its own under [member root]:
## `sound.json` (`{words, versions: [{patch, at}], used}`), each version's sound `v<N>.wav` and what it sounds like
## `v<N>.json` (the heard numbers), the draft the designer is working on (`draft.wav`, `draft.json`) and the designer's
## conversation ([WriterChat], `chat.json`). The same words are the same sound on every note, as a picture's are. A version is
## kept, never deleted; which one plays is the sound's `used`.
##
## Read once and held ([method entry]); written whole by rename. A patch is made into sound on its own process ([method render]),
## never on this thread, and a WAV is read into frames on a worker ([method frames_of]).

const ENV := "music_venv"
const VENV := "user://music_venv"
const SCRIPT := "res://hosts/music/sound.py"
const FILE := "sound.json"
## A sound mark in a note's words: group 1 its words (the desk's `sound:` mark, [constant ScriptMarks.REGISTRY] `desk_sound`).
const MARK := "<!--\\s*sound\\s*:\\s*([^>]*?)\\s*-->"
## The rate a sound is made at (sound.py RATE, the desk's), and the loudest its loudest sample is written at (sound.py CEILING).
const RATE := 22050
const CEILING := 0.89
## What a source can be (sound.py SOURCES): each a row the designer is told.
const SOURCES := {
	"noise": {"label": "Noise", "blurb": "Hiss: `color` white (bright), pink (even) or brown (deep rumble). The start of wind, rain, roar, breath, static, a crowd."},
	"sine": {"label": "Sine", "blurb": "A pure tone on `pitch` (Hz): a whistle, a hum, a beep, a whine."},
	"saw": {"label": "Saw", "blurb": "A buzzing tone on `pitch`, every harmonic: engines, motors, a drone; dark through a low-pass."},
	"pulse": {"label": "Pulse", "blurb": "A hollow, reedy tone on `pitch`: a buzzer, an alarm, an old machine."},
	"triangle": {"label": "Triangle", "blurb": "A soft tone on `pitch`, few harmonics: a mellow hum or chime."},
	"modal": {"label": "Struck thing", "blurb": "A struck object: `modes` [[Hz, seconds to die away, level], ...] rung at each time in `hits`. Metal rings long with uneven partials, wood is short and low, glass high and bright; a can a few short high modes."},
	"pluck": {"label": "Plucked string", "blurb": "A string at `pitch` struck at each time in `hits`, ringing `decay` seconds, `bright` 0 (dull) to 1 (bright)."},
	"crackle": {"label": "Crackle", "blurb": "Random clicks, `rate` a second, each `decay` seconds long: fire, rain on a roof, gravel, static pops, a Geiger counter."},
}
## What a layer can be told (sound.py's layer fields), and the patch's own: each a row the designer is told.
const FIELDS := {
	"secs": {"label": "Seconds the voice waits", "blurb": "A patch's own: how long the voice waits for the sound before it speaks again."},
	"tail": {"label": "Tail", "blurb": "A patch's own: seconds the sound goes on after the voice comes back, under its words (0 for none). The sound is secs + tail long."},
	"gain": {"label": "Gain", "blurb": "dB. A patch's: 0 or less, the whole sound's loudness (0 its loudest sample at full level; -12 a distant or small sound). A layer's: its share in the mix."},
	"room": {"label": "Room", "blurb": "A patch's own: {\"seconds\", \"damp\" 0 bright to 1 dark, \"mix\" 0 dry to 1 all room} - a reverb round the whole sound: a hall, a stairwell, outdoors (short or none)."},
	"layers": {"label": "Layers", "blurb": "A patch's own: the sources heard together, at most 12, each with the fields below."},
	"source": {"label": "Source", "blurb": "What the layer is: one of the sources listed."},
	"at": {"label": "When", "blurb": "[start, end] seconds into the sound that the layer sounds (the whole sound if left out). A struck or plucked thing rings on past its end."},
	"level": {"label": "Level", "blurb": "A curve, 0 to 1: how loud the layer is over time. Its shape is the sound's: a quick rise and long fall, a swell, a fade."},
	"pitch": {"label": "Pitch", "blurb": "A curve in Hz: an oscillator's pitch over time; a pluck's note (its middle value)."},
	"filters": {"label": "Filters", "blurb": "[{\"kind\": \"lowpass\" | \"highpass\" | \"bandpass\", \"hz\", \"q\"}]: a low-pass's `hz` may be a curve (a sound opening up or darkening); a high- or band-pass takes its curve's middle value. `q` 0.707 is flat; higher rings."},
	"drive": {"label": "Drive", "blurb": "0 to 1: saturation, grit; over 0.6 a distorted, overdriven sound."},
	"pan": {"label": "Pan", "blurb": "A curve, -1 left to 1 right."},
	"moving": {"label": "Moving", "blurb": "{\"closest\": seconds, \"near\": meters, \"speed\": m/s}: the layer flies past - nearest `closest` seconds in, `near` meters off - its pitch Doppler-shifted, louder as it nears, darker and quieter as it goes, panned across. A jet: speed 90-150, near 150-300; a car: 15-30, 5-20."},
	"modes": {"label": "Modes", "blurb": "A struck thing's: [[Hz, seconds to die away, level], ...]."},
	"hits": {"label": "Hits", "blurb": "A struck or plucked thing's: the seconds it is struck at, e.g. [0.0, 0.31, 0.52] for a can hitting and bouncing."},
	"color": {"label": "Color", "blurb": "Noise's: white, pink or brown."},
	"rate": {"label": "Rate", "blurb": "Crackle's: clicks a second."},
	"decay": {"label": "Decay", "blurb": "Seconds a pluck rings, or a crackle's click lasts."},
	"bright": {"label": "Bright", "blurb": "A pluck's: 0 dull to 1 bright."},
}
## A curve, as the designer is told it.
const CURVE := "A CURVE is a number, a list of [seconds, value] points, or {\"points\": [[seconds, value], ...], \"ease\": \"linear\" | \"smooth\" | \"exp\"}: smooth (the default) eases between points, exp moves by ratios - a pitch or a fade heard evenly (never 0 in an exp curve: 0.001 is silence). Before its first point a curve holds that value, after its last the last's."
## The longest a sound may be (sound.py LONGEST).
const LONGEST := 60.0
## How far a sound's level may be turned, in dB either way of as made ([method set_level]): down to all but gone, up a little.
const LEVEL_RANGE := Vector2(-24.0, 12.0)

const ROOT := "user://sound_effects"
## Where the sounds are kept: a gate's own folder, never the author's.
static var root := ROOT
static var _held := {}          # key -> entry, read once


## Whether this process may write the sounds: one moved aside ([member root], a gate's own) always; the author's only from a
## session that may write the author's things, as [method Library.writable] says.
static func writable() -> bool:
	if root != ROOT:
		return true
	var tree := Engine.get_main_loop() as SceneTree
	var s: Node = tree.root.get_node_or_null("Settings") if tree != null and tree.root != null else null
	return s != null and not bool(s.call("is_read_only"))


## The key of a sound for [param words]: the same words, however wrapped, are the same sound.
static func key_of(words: String) -> String:
	return Manuscript.image_key(words)


## Every sound mark in [param text], each once, in the order first written: `[{key, words}]`.
static func marks_in(text: String) -> Array:
	var out: Array = []
	var seen := {}
	var rx := RegEx.create_from_string(MARK)
	for m in rx.search_all(text):
		var words := " ".join(m.get_string(1).strip_edges().split(" ", false)).replace("\n", " ")
		var key := key_of(words)
		if words.is_empty() or seen.has(key):
			continue
		seen[key] = true
		out.append({"key": key, "words": words})
	return out


## Sound [param key]'s folder, absolute.
static func folder(key: String) -> String:
	return ProjectSettings.globalize_path(root.path_join(key))


## Sound [param key] as kept: `{words, versions: [{patch, at}], used}` ({} for one never made). Read once and held.
static func entry(key: String) -> Dictionary:
	if _held.has(key):
		return _held[key]
	var p := folder(key).path_join(FILE)
	var e := {}
	if FileAccess.file_exists(p):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if j is Dictionary and (j as Dictionary).get("versions") is Array:
			e = j
	_held[key] = e
	return e


## The versions of sound [param key], the first first.
static func versions(key: String) -> Array:
	return entry(key).get("versions", []) as Array


## The version of sound [param key] that plays (0-based), -1 for none.
static func used(key: String) -> int:
	var n := versions(key).size()
	return clampi(int(entry(key).get("used", n - 1)), -1, n - 1) if n > 0 else -1


## Version [param v] of sound [param key]'s patch ({} for none; -1 the one used).
static func patch_of(key: String, v := -1) -> Dictionary:
	var vs := versions(key)
	var i := used(key) if v < 0 else v
	return ((vs[i] as Dictionary).get("patch", {}) as Dictionary) if i >= 0 and i < vs.size() else {}


## A new version of sound [param key] (said by [param words]) from [param patch], used from now: its index (-1 in a session
## that may not write).
static func add_version(key: String, words: String, patch: Dictionary) -> int:
	if not writable():
		return -1
	var e := entry(key).duplicate(true)
	e["words"] = words
	var vs: Array = e.get("versions", [])
	vs.append({"patch": patch.duplicate(true), "at": int(Time.get_unix_time_from_system())})
	e["versions"] = vs
	e["used"] = vs.size() - 1
	_write(key, e)
	return vs.size() - 1


## How loud sound [param key] is played, dB over as it was made (0 as made): the author's, kept with the sound and never in its
## patch, so turning it makes nothing again.
static func level_of(key: String) -> float:
	return clampf(float(entry(key).get("level", 0.0)), LEVEL_RANGE.x, LEVEL_RANGE.y)


## Sound [param key] played [param db] over as it was made.
static func set_level(key: String, db: float) -> void:
	var e := entry(key).duplicate(true)
	if e.is_empty():
		return
	e["level"] = clampf(db, LEVEL_RANGE.x, LEVEL_RANGE.y)
	_write(key, e)


## Version [param v] of sound [param key] plays from now.
static func use(key: String, v: int) -> void:
	var e := entry(key).duplicate(true)
	if v < 0 or v >= (e.get("versions", []) as Array).size():
		return
	e["used"] = v
	_write(key, e)


static func _write(key: String, e: Dictionary) -> void:
	if not writable():
		return
	var dir := folder(key)
	DirAccess.make_dir_recursive_absolute(dir)
	var p := dir.path_join(FILE)
	var f := FileAccess.open(p + ".part", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(e, "\t"))
	f.close()
	DirAccess.rename_absolute(p + ".part", p)
	_held[key] = e


## Version [param v]'s sound file (-1 the one used): its path, made or not.
static func wav_path(key: String, v := -1) -> String:
	var i := used(key) if v < 0 else v
	return folder(key).path_join("v%d.wav" % (i + 1)) if i >= 0 else ""


## What sound [param key] plays as: `{wav, secs, tail, heard}` of the version used, once it is made into sound; {} until then.
static func made(key: String) -> Dictionary:
	var wav := wav_path(key)
	if wav.is_empty() or not FileAccess.file_exists(wav):
		return {}
	var p := patch_of(key)
	return {"wav": wav, "secs": float(p.get("secs", 0.0)), "tail": float(p.get("tail", 0.0)), "heard": heard_of(key)}


## The sounds made for the marks in [param text]: `{key: {wav, secs, tail, level}}`, each mark with its version used made into sound
## (what a desk plays, at its level in dB, and the voice waits for).
static func made_in(text: String) -> Dictionary:
	var out := {}
	for m in marks_in(text):
		var got := made(String((m as Dictionary)["key"]))
		if not got.is_empty():
			out[String(m["key"])] = {"wav": got["wav"], "secs": got["secs"], "tail": got["tail"], "level": level_of(String(m["key"]))}
	return out


## What version [param v] of sound [param key] sounds like (sound.py's heard numbers), {} until it is made.
static func heard_of(key: String, v := -1) -> Dictionary:
	var wav := wav_path(key, v)
	if wav.is_empty():
		return {}
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(wav.get_basename() + ".json")) \
		if FileAccess.file_exists(wav.get_basename() + ".json") else null
	return j if j is Dictionary else {}


## The seed sound [param key]'s noise is drawn from: its own, so a sound made again is the same sound.
static func seed_of(key: String) -> int:
	return absi(hash(key)) % 1000000


## [param patch] made into sound at [param out] (a WAV; what it sounds like beside it, `.json`), on the music host's own process,
## the music environment installed first if it must be. Awaited: `{ok, wav, heard}` or `{ok: false, error}`. [param said] hears
## what it is doing (a line).
static func render(patch: Dictionary, seed: int, out: String, said := Callable()) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"ok": false, "error": "no running app to make the sound in"}
	if not writable() and out.begins_with(folder("")):
		return {"ok": false, "error": "this session is read-only"}
	if not Provision.unsupported(ENV).is_empty():
		return {"ok": false, "error": "the music environment cannot be installed here: " + Provision.unsupported(ENV)}
	while not Provision.ensure(ENV):
		if said.is_valid():
			said.call("installing the music environment (%s)" % String(Deps.entry(ENV).get("size", "")))
		await tree.create_timer(0.5).timeout
		if Subprocess.closing():
			return {"ok": false, "error": "Ghost Notes is closing"}
	var py := Deps.venv_bin(VENV, "python")
	var script := BundledHosts.path(SCRIPT)
	if not FileAccess.file_exists(py) or script.is_empty():
		return {"ok": false, "error": "the music environment is not installed"}
	var dir := out.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var stem := out.get_basename()
	var spec := stem + ".spec.json"
	var done := stem + ".done.json"
	DirAccess.remove_absolute(done)
	var f := FileAccess.open(spec, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "could not write " + spec}
	f.store_string(JSON.stringify({"patch": patch, "seed": seed, "out": out, "done": done}))
	f.close()
	var pid := Subprocess.start_logged(py, PackedStringArray(["-I", script, spec]), stem + ".log", "sound")
	if pid <= 0:
		return {"ok": false, "error": "the music host could not start"}
	if said.is_valid():
		said.call("making the sound")
	while Subprocess.alive(pid):
		await tree.process_frame
	var res: Variant = JSON.parse_string(FileAccess.get_file_as_string(done)) if FileAccess.file_exists(done) else null
	DirAccess.remove_absolute(spec)
	DirAccess.remove_absolute(done)
	if not (res is Dictionary):
		return {"ok": false, "error": "the sound could not be made (its log: %s)" % (stem + ".log")}
	if bool((res as Dictionary).get("ok", false)):
		var h := FileAccess.open(stem + ".json", FileAccess.WRITE)
		if h != null:
			h.store_string(JSON.stringify((res as Dictionary).get("heard", {})))
			h.close()
	return res


## Version [param v] of sound [param key] made into sound (-1 the one used). Awaited, as [method render].
static func make(key: String, v := -1, said := Callable()) -> Dictionary:
	var i := used(key) if v < 0 else v
	if i < 0:
		return {"ok": false, "error": "no patch is written for this sound yet"}
	return await render(patch_of(key, i), seed_of(key), wav_path(key, i), said)


## The frames of a WAV sound.py wrote (16-bit stereo at [constant RATE]): what the desk mixes. Pure: a worker reads it.
static func frames_of(wav: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	var bytes := FileAccess.get_file_as_bytes(wav)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return out
	# the chunks after the header: find `data`
	var at := 12
	while at + 8 <= bytes.size():
		var id := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		if id == "data":
			var n := mini(size, bytes.size() - at - 8) / 4
			out.resize(n)
			var p := at + 8
			for i in n:
				out[i] = Vector2(bytes.decode_s16(p) / 32768.0, bytes.decode_s16(p + 2) / 32768.0)
				p += 4
			return out
		at += 8 + size + (size & 1)
	return out


## What sound [param key]'s version [param v] sounds like, told as the designer reads it: its length, peak, onsets, how it
## fades and its loudness, brightness and pitch over time (at most [param lines] frames).
static func heard_text(h: Dictionary, lines := 90) -> String:
	if h.is_empty():
		return "(not made yet)"
	var out := PackedStringArray()
	out.append("length %.2f s; peak %.1f dB, loudest %.1f s in" % [float(h.get("seconds", 0.0)), float(h.get("peak_db", 0.0)), float(h.get("loudest_at", 0.0))])
	var onsets: Array = h.get("onsets", [])
	out.append("onsets (s): %s" % (", ".join(PackedStringArray(onsets.map(func(o: Variant) -> String: return "%.2f" % float(o)))) if not onsets.is_empty() else "none"))
	var fade: Variant = h.get("fade")
	out.append(("fades from 6 dB under its peak to 40 dB under in %.2f s" % float(fade)) if fade != null
		else "never falls 40 dB under its peak after its loud part: it ends abruptly or stays loud")
	out.append("its last tenth of a second at %.1f dB" % float(h.get("end_db", 0.0)))
	var frames: Array = h.get("frames", [])
	var step := maxi(1, ceili(float(frames.size()) / float(lines)))
	out.append("over time (s: loudness dB, brightness Hz, pitch Hz or - for no clear tone):")
	for i in range(0, frames.size(), step):
		var fr: Dictionary = frames[i]
		out.append("%.1f: %.0f dB, %s, %s" % [float(fr.get("t", 0.0)), float(fr.get("db", -120.0)),
			"-" if fr.get("bright") == null else "%d Hz" % int(fr["bright"]), "-" if fr.get("pitch") == null else "%d Hz" % int(fr["pitch"])])
	return "\n".join(out)
