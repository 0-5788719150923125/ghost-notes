extends RefCounted
class_name SoundDesign

## SoundDesign - one sound being made and refined (next/sound_effects.md): the draft patch a designer works on through its tools
## ([SoundTools]), the conversation it works in ([WriterChat], kept in the sound's folder with rules/sound/designer.yaml), and
## what a turn leaves: a patch that changed and can be made is a new version of the sound ([method SoundEffects.add_version]),
## made into sound at once and played from then on. Generate is the conversation's first turn ([method generate]); Refine… is
## every turn after ([method refine], [TextRefine]). Its owner polls it from a frame ([method poll]).
##
## The draft is the patch as JSON text, starting from the version used. A turn that leaves no valid patch keeps no version, and
## says why ([member error]).

## Something to show: a turn begun or ended, a draft heard, a version made.
signal changed

var key := ""
var words := ""
## The note's title, for what the designer is told.
var title := ""
var chat: WriterChat
## The draft patch, as text.
var draft := ""
## What the last turn or make went wrong with, "" for nothing.
var error := ""
## What it is doing now, as a line ("" for nothing).
var doing := ""
## What the draft sounded like when last rendered.
var heard := {}

var _was_busy := false
var _making := false


func _init(sound_key: String, sound_words: String, note_title := "") -> void:
	key = sound_key
	words = sound_words
	title = note_title
	var p := SoundEffects.patch_of(key)
	draft = JSON.stringify(p, "\t") if not p.is_empty() else ""
	chat = WriterChat.at(SoundEffects.folder(key))
	chat.rules = "sound/designer"
	chat.read_text = func() -> String: return draft
	chat.apply = func(at: int, gone: int, put: String) -> void:
		draft = draft.substr(0, at) + put + draft.substr(at + gone)
	chat.about = about
	chat.toolset = func(text: TextTools) -> Object:
		var t := SoundTools.new()
		t.text = text
		t.key = key
		t.rendered = func(h: Dictionary) -> void:
			heard = h
			changed.emit()
		return t
	_was_busy = chat.busy()


## What the designer is told it works on: the system prompt's names (rules/sound/designer.yaml).
func about() -> Dictionary:
	var sources: Array = []
	for k in SoundEffects.SOURCES:
		sources.append({"key": k, "label": Registry.label(SoundEffects.SOURCES, k), "blurb": Registry.blurb(SoundEffects.SOURCES, k)})
	var fields: Array = []
	for k in SoundEffects.FIELDS:
		fields.append({"key": k, "label": Registry.label(SoundEffects.FIELDS, k), "blurb": Registry.blurb(SoundEffects.FIELDS, k)})
	return {"what": "the patch of a sound", "title": title, "words": words, "sources": sources, "fields": fields,
		"curve": SoundEffects.CURVE, "longest": "%d" % int(SoundEffects.LONGEST)}


## Whether a turn is under way, or a version is being made into sound.
func busy() -> bool:
	return chat.busy() or _making


## The sound made from its words by the designer [param pick] (`{agent, model, effort}`): the conversation's first turn, or a
## turn asking for it again where versions exist. "" once begun, else why not.
func generate(pick: Dictionary) -> String:
	return refine(Rules.say("sound/designer.make", {"words": words}), pick)


## The author's [param message] to the designer [param pick]. "" once sent, else why not.
func refine(message: String, pick: Dictionary) -> String:
	error = ""
	var why := chat.send(message, pick)
	if why.is_empty():
		_was_busy = true
		doing = "the designer is at work"
	else:
		error = why
	changed.emit()
	return why


## A frame's look: the turn under way polled, and once it ends, what it left kept.
func poll() -> void:
	chat.poll()
	if chat.busy():
		var a := chat.activity()
		if a != doing:
			doing = a
			changed.emit()
		return
	if _was_busy:
		_was_busy = false
		doing = ""
		var last: Dictionary = chat.turns.back() if not chat.turns.is_empty() else {}
		if not String(last.get("error", "")).is_empty():
			error = String(last["error"])
		var v := keep_draft()
		if v >= 0:
			make(v)
		changed.emit()


## The draft as a new version, where it changed and can be made: its index, -1 for none kept ([member error] says why, where
## something was wrong).
func keep_draft() -> int:
	var j := JSON.new()
	var p: Variant = j.data if not draft.strip_edges().is_empty() and j.parse(draft) == OK else null
	if not (p is Dictionary):
		if not draft.strip_edges().is_empty():
			error = "the patch the designer left is not valid JSON"
		return -1
	var why := problem(p)
	if not why.is_empty():
		error = why
		return -1
	if JSON.stringify(p) == JSON.stringify(SoundEffects.patch_of(key)):
		return -1
	return SoundEffects.add_version(key, words, p)


## Version [param v] made into sound (-1 the one used).
func make(v := -1) -> void:
	_making = true
	doing = "making the sound"
	changed.emit()
	var res: Dictionary = await SoundEffects.make(key, v, func(line: String) -> void:
		doing = line
		changed.emit())
	_making = false
	doing = ""
	if not bool(res.get("ok", false)):
		error = String(res.get("error", "the sound could not be made"))
	changed.emit()


## Why [param p] cannot be a sound's patch, "" when it can (what sound.py's own check would refuse, said before it is asked).
static func problem(p: Dictionary) -> String:
	var secs := float(p.get("secs", 0.0)) + float(p.get("tail", 0.0))
	if secs < 0.05 or secs > SoundEffects.LONGEST:
		return "the sound is %.1f s long; a sound is 0.05 to %d s" % [secs, int(SoundEffects.LONGEST)]
	var layers: Variant = p.get("layers")
	if not (layers is Array) or (layers as Array).is_empty():
		return "the patch has no layers"
	for ly in layers:
		if not (ly is Dictionary) or not SoundEffects.SOURCES.has(String((ly as Dictionary).get("source", "noise"))):
			return "a layer's source is none the patch knows"
	return ""
