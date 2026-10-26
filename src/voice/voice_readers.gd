extends RefCounted
class_name VoiceReaders

## VoiceReaders - who a multi-speaker voice's speaker NUMBER actually is.
##
## Piper's libritts voices hold hundreds of readers (904 in en_US-libritts-high) addressed by
## an index, and the index says nothing: the only way to find a voice was to step through them
## and listen. The model's own config names each index by its LibriTTS reader id
## (`speaker_id_map`: "p3615" -> 10), and LibriTTS-P (LINE, CC BY 4.0) has annotated those
## readers - perceived gender and a description of the voice ("soft, clear, calm, reassuring").
## `data/libritts_speakers.json` is that annotation, keyed by reader id (see its .LICENSE).
##
## Read only from files: the model config the voice host downloaded, and the data file. A voice
## that is not installed yet, or has no map, simply has no descriptions.
##
## ...OR SAID BY THE HOST (2026-10-25): a voice whose speakers are a list the host keeps itself -
## Kokoro's voicepacks under the one "kokoro" voice - comes with `readers` on its row, handed in by
## [method offer] as the host lists its voices, and they are described from those instead.

const DATA := "res://data/libritts_speakers.json"
const LIBRITTS_ABOUT := "Descriptions: LibriTTS-P, LINE Corporation (CC BY 4.0)."

static var _readers := {}          # reader id -> {g, d}
static var _maps := {}             # voice id -> PackedStringArray: speaker index -> reader id
static var _given := {}            # voice id -> [{reader, g, d}], in speaker order (offer)
static var _about := {}            # voice id -> who described them


## The readers the host listed with [param voice_id] (`readers` on its row), in speaker order, and
## who described them ([param about]). Asked again on every listing: what the host says now is what
## a speaker number is.
static func offer(voice_id: String, readers: Array, about := "") -> void:
	var rows: Array = []
	for r in readers:
		if r is Dictionary:
			rows.append({"reader": String(r.get("reader", "")), "g": String(r.get("g", "")),
				"d": String(r.get("d", ""))})
	_given[voice_id] = rows
	_about[voice_id] = about


## Who described [param voice_id]'s readers, said under the reader browser.
static func about_of(voice_id: String) -> String:
	var said := String(_about.get(voice_id, ""))
	return said if not said.is_empty() else LIBRITTS_ABOUT


static func _load_readers() -> void:
	if not _readers.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if parsed is Dictionary:
		_readers = (parsed as Dictionary).get("readers", {})


static func _map_of(voice_id: String) -> PackedStringArray:
	if _maps.has(voice_id):
		return _maps[voice_id]
	var out := PackedStringArray()
	var cfg := Deps.data_dir().path_join("voices/piper/%s.onnx.json" % voice_id)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(cfg)) \
		if FileAccess.file_exists(cfg) else null
	if parsed is Dictionary:
		var m: Dictionary = (parsed as Dictionary).get("speaker_id_map", {})
		out.resize(m.size())
		for key in m:
			var i := int(m[key])
			if i >= 0 and i < out.size():
				out[i] = String(key).trim_prefix("p")
	_maps[voice_id] = out
	return out


## Speaker [param index] of [param voice_id]: `{reader, g, d}` (g "F", "M" or ""), or empty
## when nothing is known about it.
static func describe(voice_id: String, index: int) -> Dictionary:
	if _given.has(voice_id):
		var rows: Array = _given[voice_id]
		return (rows[index] as Dictionary).duplicate() if index >= 0 and index < rows.size() else {}
	_load_readers()
	var m := _map_of(voice_id)
	if index < 0 or index >= m.size() or m[index].is_empty():
		return {}
	var r: Dictionary = _readers.get(m[index], {})
	return {"reader": m[index], "g": String(r.get("g", "")), "d": String(r.get("d", ""))}


## Every speaker of [param voice_id], in index order: `[{i, reader, g, d}]`.
static func all(voice_id: String) -> Array:
	var out: Array = []
	if _given.has(voice_id):
		var rows: Array = _given[voice_id]
		for i in rows.size():
			var r: Dictionary = (rows[i] as Dictionary).duplicate()
			r["i"] = i
			out.append(r)
		return out
	_load_readers()
	var m := _map_of(voice_id)
	for i in m.size():
		var r: Dictionary = _readers.get(m[i], {})
		out.append({"i": i, "reader": m[i], "g": String(r.get("g", "")), "d": String(r.get("d", ""))})
	return out


## One line for a speaker: a gender sign and the start of its description.
static func line(d: Dictionary, words := 6) -> String:
	if d.is_empty():
		return ""
	var sign: String = {"F": "♀ female", "M": "♂ male"}.get(String(d["g"]), "unannotated")
	var desc := String(d["d"]).split(", ")
	var short := ", ".join(desc.slice(0, words)) + ("…" if desc.size() > words else "")
	return "%s  ·  %s" % [sign, short] if not short.is_empty() else sign
