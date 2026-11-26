extends RefCounted
class_name VoiceLibrary

## VoiceLibrary - voices kept for every note (next/library.md): the library's `voices` shelf ([Library]), one file per voice,
## `<slug>.json`: `{name, line, hash, voice}`. A kept voice is who speaks and how ([constant OWN]): the model and its reader, a
## Kokoro blend or the formant voice, the tone, the pace, the pauses, the delivery dials, the ink, and how it sings
## ([constant SINGING]: what a composed Sound casting it reads). Where it is heard - the
## room ([constant ROOM]) - is never kept: it stays each note's, one narrator in a car and at a desk.
##
## A note reads a kept voice by name (`kept:` on its row, [ReadingCast]) and carries a copy of what it last read. A voice
## renamed answers to its old names too (`was`), so the notes reading it follow it.
##
## Its sample ([method sample]): the opening of the Test passage said once in the voice, a WAV on the shelf named by what the
## voice sounds like ([method sound_of]), so a rename keeps it and a change to the voice asks for another. The Voice card makes
## it ([member maker]); [method sampled] tidies the samples no voice names.
##
## Every write refuses a session that may not write the library ([method Library.writable]); [member version] counts this
## process's writes, so whatever shows the shelf knows to look again. A file from anywhere comes in through [method
## sanitized], bounded: every number finite and in its dial's range, every text short, no path where a model is named.

const SHELF := "voices"
## The ending of a voice handed on as a file ([method export_to]).
const EXPORT := ".voice.json"
## What a voice keeps when it is kept: who speaks and how. Every other field of a cast row is the room ([constant ROOM]).
const OWN := ["voice", "speaker", "blend", "formant", "tone", "pace", "pause", "pause_sentence", "pause_paragraph", "dynamics", "arc", "effort", "ink",
	"vibrato", "vibrato_rate", "drift"]
## How a voice sings, and each dial's range. A voice's hash leaves one out while it is at its default (a voice kept
## before these were is the same voice), and its spoken sample never hears them.
const SINGING := {"vibrato": [0.0, 1.0], "vibrato_rate": [3.0, 8.0], "drift": [0.0, 0.15]}
## Where a voice is heard: each note's own, never kept.
const ROOM := ["echo", "room", "resonance", "presence", "ambience", "lean", "near", "seat"]
## A kept field's value where a file gives none (a voice names its model, or it is no voice).
const DEFAULTS := {"voice": "", "speaker": 0, "blend": "", "formant": {}, "tone": 0, "pace": 1.0, "pause": 1.0, "pause_sentence": 1.0,
	"pause_paragraph": 1.0,
	"dynamics": 0.5, "arc": 0.4, "effort": 0.35, "ink": "", "vibrato": 0.15, "vibrato_rate": 5.4, "drift": 0.03}
## The Pace row's range.
const PACE_LEAST := 0.4
const PACE_MOST := 1.6
## The highest reader number a voice may name.
const SPEAKER_MOST := 9999
const NAME_MOST := 60
const LINE_MOST := 200
const ID_MOST := 80
const BLEND_MOST := 600
## The old names a voice answers to.
const WAS_MOST := 8
## A voice's file is a few kilobytes; one larger is no voice.
const FILE_MOST := 262144
## The formant voice's bounds: seeds in its lineage, keys in each of its maps, numbers in its bank, and the largest number.
const LINEAGE_MOST := 64
const MAP_MOST := 128
const BANK_MOST := 384
const NUMBER_MOST := 1.0e6
const SEED_MOST := 2147483647

## How many times this process has written the shelf: a page showing it looks again when it moves.
static var version := 0
## (name: String) -> void: makes the sample of the voice kept as `name` and calls [method sampled] once it is written. Set
## by the Voice card while it can make one; [method sample] asks it when a voice has none.
static var maker: Callable = Callable()


## The shelf's folder, absolute.
static func dir() -> String:
	return Library.shelf(SHELF)


## The kept fields of [param row] (a cast row, or a voice from anywhere): every one of [constant OWN], typed and bounded,
## nothing of the room.
static func own_of(row: Dictionary) -> Dictionary:
	var out := {}
	out["voice"] = _id(row.get("voice", ""))
	out["speaker"] = _int(row.get("speaker"), 0, 0, SPEAKER_MOST)
	out["blend"] = _blend(row.get("blend", ""))
	out["formant"] = _formant(row.get("formant", {}))
	out["tone"] = _int(row.get("tone"), 0, 0, Delivery.TONE_PRESETS.size() - 1)
	out["pace"] = _num(row.get("pace"), float(DEFAULTS["pace"]), PACE_LEAST, PACE_MOST)
	for k in ["pause", "pause_sentence", "pause_paragraph"]:
		out[k] = _num(row.get(k), float(DEFAULTS[k]), 0.0, Delivery.MAX_PAUSE_SCALE)
	for k in ["dynamics", "arc", "effort"]:
		out[k] = _num(row.get(k), float(DEFAULTS[k]), 0.0, 1.0)
	out["ink"] = _ink(row.get("ink", ""))
	for k in SINGING:
		out[k] = _num(row.get(k), float(DEFAULTS[k]), float(SINGING[k][0]), float(SINGING[k][1]))
	return out


## What [param voice] is, as a short hash: only its kept fields count, never its name, its line or its room; numbers equal
## to a millionth hash the same; the singing at its defaults and the pauses at sentence and paragraph ends equal to the Pause at
## commas are left out.
static func hash_of(voice: Dictionary) -> String:
	var own := own_of(voice)
	for k in SINGING:
		if is_equal_approx(float(own[k]), float(DEFAULTS[k])):
			own.erase(k)
	# the pauses at sentence and paragraph ends say nothing while they are the Pause at commas: a voice kept before they were apart
	# is the same voice
	for k in ["pause_sentence", "pause_paragraph"]:
		if is_equal_approx(float(own[k]), float(own["pause"])):
			own.erase(k)
	return JSON.stringify(_canon(own), "", true).sha256_text().left(16)


## What [param voice] sounds like spoken, as a short hash: [method hash_of] without the ink or how it sings. Its sample
## is named by it.
static func sound_of(voice: Dictionary) -> String:
	var own := own_of(voice)
	own["ink"] = ""
	for k in SINGING:
		own[k] = DEFAULTS[k]
	return hash_of(own)


## The entry [param voice] would be, kept as [param name] with [param line] saying what it is: `{name, line, hash, voice}`;
## {} for a voice with no name or no model.
static func entry_of(voice: Dictionary, name: String, line := "") -> Dictionary:
	var n := _text(name, NAME_MOST)
	var own := own_of(voice)
	if n.is_empty() or String(own["voice"]).is_empty():
		return {}
	return {"name": n, "line": _text(line, LINE_MOST), "hash": hash_of(own), "voice": own}


## [param voice] kept as [param name], said by [param line]; a voice of its name already kept is replaced, and keeps the old
## names it answers to. "" kept, else why not.
static func keep(voice: Dictionary, name: String, line := "") -> String:
	if not Library.writable():
		return "the library is not written from here"
	var e := entry_of(voice, name, line)
	if e.is_empty():
		return "a voice needs a name and a model to be kept"
	var had := _file_entry(_path_of(String(e["name"])))
	if had.get("was") is Array:
		e["was"] = had["was"]
	return _write(e)


## Every voice kept, sorted by name: each `{name, line, hash, voice}`, with `file` (where it is kept) and `was` (the old names
## it answers to) where it has them.
static func entries() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir()):
		return out
	for fn in DirAccess.get_files_at(dir()):
		if String(fn).ends_with(".json"):
			var e := _file_entry(dir().path_join(fn))
			if not e.is_empty():
				out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	return out


## Every voice kept, by name, sorted.
static func names() -> Array:
	return entries().map(func(e: Dictionary) -> String: return String(e["name"]))


## The voice kept as [param name], or renamed from it: its entry, {} for none.
static func read(name: String) -> Dictionary:
	var n := name.strip_edges()
	if n.is_empty():
		return {}
	var e := _file_entry(_path_of(n))
	if not e.is_empty():
		return e
	var s := Manuscript.slug(n)
	for x in entries():
		for w in ((x as Dictionary).get("was", []) as Array):
			if Manuscript.slug(String(w)) == s:
				return x
	return {}


## The name of the voice kept whose hash is [param h] ([method hash_of]), "" for none.
static func kept_as(h: String) -> String:
	for e in entries():
		if String((e as Dictionary)["hash"]) == h:
			return String((e as Dictionary)["name"])
	return ""


## The voice kept as [param name] taken off the shelf, to the trash ([method Library.trash]); its sample goes with it. "" done,
## else why not.
static func remove(name: String) -> String:
	if not Library.writable():
		return "the library is not written from here"
	var path := _path_of(name)
	if not FileAccess.file_exists(path):
		return "%s is not in the library" % name
	if Library.trash(path) != OK:
		return "could not take %s off the shelf" % name
	version += 1
	_sweep()
	return ""


## The voice kept as [param name] called [param new_name], said by [param line]; it answers to its old name too. "" done,
## else why not.
static func rename(name: String, new_name: String, line: String) -> String:
	if not Library.writable():
		return "the library is not written from here"
	var e := _file_entry(_path_of(name))
	if e.is_empty():
		return "%s is not in the library" % name
	var to := _text(new_name, NAME_MOST)
	if to.is_empty():
		return "a voice needs a name"
	var moved := Manuscript.slug(to) != Manuscript.slug(name)
	if moved and FileAccess.file_exists(_path_of(to)):
		return "another voice is called %s" % to
	var was: Array = []
	for w in (e.get("was", []) as Array) + ([String(e["name"])] if moved else []):
		if Manuscript.slug(String(w)) != Manuscript.slug(to) and not was.has(String(w)):
			was.append(String(w))
	e.erase("file")
	e["name"] = to
	e["line"] = _text(line, LINE_MOST)
	e["was"] = was.slice(maxi(0, was.size() - WAS_MOST))
	if (e["was"] as Array).is_empty():
		e.erase("was")
	var err := _write(e)
	if err.is_empty() and moved:
		DirAccess.remove_absolute(_path_of(name))
	return err


## The voice kept as [param name] written to [param path] as a file anyone can be handed: its name, line and kept fields -
## never a model's weights, which stay where they are installed. "" done, else why not.
static func export_to(name: String, path: String) -> String:
	var e := read(name)
	if e.is_empty():
		return "%s is not in the library" % name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "could not write " + path
	f.store_string(JSON.stringify({"name": e["name"], "line": e["line"], "hash": e["hash"], "voice": e["voice"]}, "\t", false, true))
	f.close()
	return ""


## The voice in the file at [param path] kept, read through [method sanitized]: the name it was kept as, or "" with [param why]
## told why not. A voice of its name already kept is never replaced by another: the one coming in takes a free name, and the
## same voice again is the one kept.
static func import_from(path: String, why: Array = []) -> String:
	if not Library.writable():
		why.append("the library is not written from here")
		return ""
	var stem := path.get_file()
	for end in [EXPORT, ".json"]:
		if stem.ends_with(end):
			stem = stem.left(-end.length())
			break
	var d: Variant = _parse(path)
	var e := sanitized(d, stem) if d is Dictionary else {}
	if e.is_empty():
		why.append("%s holds no voice" % path.get_file())
		return ""
	var base := String(e["name"])
	var name := base
	for n in range(2, 1000):
		var have := _file_entry(_path_of(name))
		if have.is_empty():
			break
		if String(have["hash"]) == String(e["hash"]):
			return String(have["name"])
		name = "%s %d" % [base.left(NAME_MOST - 4), n]
	e["name"] = name
	var err := _write(e)
	if not err.is_empty():
		why.append(err)
		return ""
	return name


## [param d] (an entry from anywhere: `{name, line, voice}`) made safe to keep, named [param fallback_name] where it names
## nothing: its entry, bounded ([method own_of]), or {} where it holds no voice.
static func sanitized(d: Dictionary, fallback_name := "") -> Dictionary:
	if not (d.get("voice") is Dictionary):
		return {}
	var name := _text(d.get("name", ""), NAME_MOST)
	if name.is_empty():
		name = _text(fallback_name, NAME_MOST)
	return entry_of(d["voice"], name, _text(d.get("line", ""), LINE_MOST))


## The sample of the voice kept as [param name]: an absolute path to a WAV, "" while there is none - and then the Voice card
## is asked to make one ([member maker]), so asking again later finds it.
static func sample(name: String) -> String:
	var e := read(name)
	if e.is_empty():
		return ""
	var p := sample_path(e["voice"])
	if FileAccess.file_exists(p):
		return p
	if maker.is_valid():
		maker.call(String(e["name"]))
	return ""


## Where the sample of [param voice] is kept, absolute: named by what it sounds like ([method sound_of]).
static func sample_path(voice: Dictionary) -> String:
	return dir().path_join(sound_of(voice) + ".wav")


## A sample was written: the samples no kept voice sounds like are let go, and [member version] moves.
static func sampled() -> void:
	version += 1
	_sweep()


# --- the shelf's files -----------------------------------------------------------------------------


static func _path_of(name: String) -> String:
	return dir().path_join(Manuscript.slug(name) + ".json")


static func _write(e: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(dir())
	var path := _path_of(String(e["name"]))
	var out := e.duplicate(true)
	out.erase("file")
	var f := FileAccess.open(path + ".part", FileAccess.WRITE)
	if f == null:
		return "could not write " + path
	f.store_string(JSON.stringify(out, "\t", false, true))
	f.close()
	if DirAccess.rename_absolute(path + ".part", path) != OK:
		return "could not move %s into place" % path
	version += 1
	return ""


## The entry in the file at [param path], read as one from anywhere is ([method sanitized]) with the old names it answers to;
## {} where it holds no voice.
static func _file_entry(path: String) -> Dictionary:
	var d: Variant = _parse(path)
	if not (d is Dictionary):
		return {}
	var e := sanitized(d, path.get_file().get_basename())
	if e.is_empty():
		return {}
	var was: Array = []
	for w in ((d as Dictionary).get("was") if (d as Dictionary).get("was") is Array else []):
		var t := _text(w, NAME_MOST)
		if not t.is_empty() and not was.has(t) and was.size() < WAS_MOST:
			was.append(t)
	if not was.is_empty():
		e["was"] = was
	e["file"] = path
	return e


## The JSON in the file at [param path], null where there is none or it is too large to be a voice.
static func _parse(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() > FILE_MOST:
		return null
	var text := f.get_as_text()
	f.close()
	return JSON.parse_string(text)


## Every sample on the shelf no kept voice sounds like, removed: a sample is made again, never kept for its own sake.
static func _sweep() -> void:
	if not Library.writable() or not DirAccess.dir_exists_absolute(dir()):
		return
	var keep := {}
	for e in entries():
		keep[sound_of((e as Dictionary)["voice"])] = true
	for fn in DirAccess.get_files_at(dir()):
		var f := String(fn)
		if (f.ends_with(".wav") and not keep.has(f.get_basename())) or f.ends_with(".wav.part"):
			DirAccess.remove_absolute(dir().path_join(f))


# --- bounds ----------------------------------------------------------------------------------------


## [param v] as a number from [param lo] to [param hi]: a text that is a number read, NaN or no number [param fallback].
static func _num(v: Variant, fallback: float, lo: float, hi: float) -> float:
	var f := fallback
	if v is float or v is int:
		f = float(v)
	elif v is String and String(v).is_valid_float():
		f = String(v).to_float()
	if is_nan(f):
		f = fallback
	return clampf(f, lo, hi)


static func _int(v: Variant, fallback: int, lo: int, hi: int) -> int:
	if v is int:
		return clampi(v, lo, hi)
	return clampi(int(_num(v, float(fallback), float(lo), float(hi))), lo, hi)


## [param v] as one line of at most [param most] characters, control characters as spaces.
static func _text(v: Variant, most: int) -> String:
	if not (v is String or v is StringName):
		return ""
	var s := String(v).left(most * 4)
	return RegEx.create_from_string("[\\x{00}-\\x{1f}\\x{7f}]+").sub(s, " ", true).strip_edges().left(most).strip_edges()


## A model's id: the last part of anything path-like, only the characters an id has, never starting with a dot.
static func _id(v: Variant) -> String:
	if not (v is String or v is StringName):
		return ""
	var s := String(v).strip_edges().left(ID_MOST * 8).replace("\\", "/").get_file()
	s = RegEx.create_from_string("[^A-Za-z0-9_.\\-]").sub(s, "", true)
	while s.begins_with("."):
		s = s.substr(1)
	return s.left(ID_MOST)


## A blend line ([VoiceBlend]): one line, short, read as a voice, each reader a pack's plain name - "" otherwise.
static func _blend(v: Variant) -> String:
	var s := _text(v, BLEND_MOST)
	if s.is_empty():
		return ""
	var b := VoiceBlend.parse(s)
	if b.is_empty():
		return ""
	var plain := RegEx.create_from_string("^[A-Za-z0-9_\\-]{1,40}$")
	for r in (b["voices"] as Array):
		if plain.search(String((r as Dictionary)["reader"])) == null:
			return ""
	return s


## An ink: a name of letters, or a hex color; "" otherwise.
static func _ink(v: Variant) -> String:
	var s := _text(v, 24)
	if s.is_empty():
		return ""
	if RegEx.create_from_string("^#?[0-9A-Fa-f]{3,8}$").search(s) != null or RegEx.create_from_string("^[A-Za-z][A-Za-z ]*$").search(s) != null:
		return s
	return ""


## A formant voice ([method FormantVoice.kept]'s shape) bounded: its lineage of whole seeds, its maps of finite numbers, its
## bank a whole number of triples; {} for one with no lineage.
static func _formant(v: Variant) -> Dictionary:
	if not (v is Dictionary):
		return {}
	var d: Dictionary = v
	var lineage: Array = []
	for s in (d.get("lineage") if d.get("lineage") is Array else []):
		if lineage.size() >= LINEAGE_MOST:
			break
		if s is int:
			lineage.append(clampi(s, -SEED_MOST, SEED_MOST))
		elif s is float and not is_nan(float(s)):
			lineage.append(int(clampf(float(s), -SEED_MOST, SEED_MOST)))
	if lineage.is_empty():
		return {}
	var out := {"lineage": lineage}
	for k in ["traits", "genome", "reception"]:
		out[k] = _numbers(d.get(k, {}))
	var bank: Array = []
	for x in (d.get("bank") if d.get("bank") is Array else []):
		if bank.size() >= BANK_MOST:
			break
		bank.append(_num(x, 0.0, -NUMBER_MOST, NUMBER_MOST))
	bank.resize(bank.size() - bank.size() % 3)
	out["bank"] = bank
	return out


## A map of names to finite numbers, at most [constant MAP_MOST] of them.
static func _numbers(v: Variant) -> Dictionary:
	var out := {}
	if not (v is Dictionary):
		return out
	for k in (v as Dictionary):
		if out.size() >= MAP_MOST:
			break
		var key := _text(str(k), 40)
		if not key.is_empty():
			out[key] = _num((v as Dictionary)[k], 0.0, -NUMBER_MOST, NUMBER_MOST)
	return out


## [param v] with every number to a millionth: what a hash is taken of.
static func _canon(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return snappedf(float(v), 0.000001)
		TYPE_DICTIONARY:
			var out := {}
			for k in (v as Dictionary):
				out[k] = _canon((v as Dictionary)[k])
			return out
		TYPE_ARRAY:
			return (v as Array).map(func(x: Variant) -> Variant: return _canon(x))
	return v
