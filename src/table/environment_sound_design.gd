extends RefCounted
class_name EnvironmentSoundDesign

## EnvironmentSoundDesign - one sound round a scene refined with a designer (next/environment.md, "Refining a sound"): the
## element's properties as a text the designer changes through its tools and HEARS ([EnvironmentSoundTools]), in a conversation
## ([WriterChat], rules/sound/environment.yaml) kept in the sound's folder beside the note or the episode it is round, with its
## versions ([ElementVersions]). Refine… on the sound's entry opens it ([TextRefine], [EnvironmentSection]).
##
## A turn starts from the element as it stands. One that leaves it changed is a new version, put in its place at once (so its Test
## and the scene hear it); the element as it stood before is kept as a version first where it was none, so a hand's change is never
## lost. Only what the designer changed lands, over whatever a hand changed meanwhile ([method landed]); a property it left alone and
## never set stays drawn by the element's number. One design a folder ([method at]), live across a panel built again: the section
## binds the element it stands for each time it lists it ([member element_of], [member heard_by], [member put]).

## Something to show: a turn begun or ended, the designer at work, a version made.
signal changed

## The rate a sound is heard at for its numbers, and how much of its start is passed over (its fade in, [constant Soundscape.FADE]).
const RATE := 44100
const FADED := 2.0

## The folder its conversation and versions are kept in.
var dir := ""
## The note's title, for what the designer is told.
var title := ""
var chat: WriterChat
## The element's properties as the designer works on them, as text.
var draft := ""
## What the last turn went wrong with, "" for nothing.
var error := ""
## What the designer is doing now, as a line ("" between turns).
var doing := ""
## What the draft measured when last heard ([SoundMeasure]).
var heard := {}

## The element as it stands now: `func() -> Dictionary`, {} once it is gone.
var element_of: Callable
## How it is heard where it is: `func(el: Dictionary) -> Dictionary`, `{sound, wind, ride, seed}` ([method Soundscape.of_table]).
var heard_by: Callable
## An element put in its place: `func(el: Dictionary) -> String`, "" done, else why not.
var put: Callable

var _from := {}                   # the element as it stood when the turn began
var _working := false

static var _live := {}            # folder -> its design


## The design live in [param folder] now, null for none: what a list shows a sound's refining by, making none.
static func live(folder: String) -> EnvironmentSoundDesign:
	return _live.get(ProjectSettings.globalize_path(folder))


## The design kept in [param folder]: the one live there, else a new one on the conversation kept there.
static func at(folder: String) -> EnvironmentSoundDesign:
	var key := ProjectSettings.globalize_path(folder)
	if not _live.has(key):
		_live[key] = EnvironmentSoundDesign.new(folder)
	return _live[key]


func _init(folder: String) -> void:
	dir = folder
	chat = WriterChat.at(folder)
	chat.rules = "sound/environment"
	chat.read_text = _read
	chat.apply = func(at: int, gone: int, s: String) -> void: draft = draft.substr(0, at) + s + draft.substr(at + gone)
	chat.about = about
	chat.toolset = func(t: TextTools) -> Object:
		var tools := EnvironmentSoundTools.new()
		tools.text = t
		tools.hear = hear
		return tools
	chat.changed.connect(_on_chat)
	_working = chat.busy()


## Whether a turn is under way.
func busy() -> bool:
	return chat.busy() or _working


## The element as it stands, {} where nobody holds it.
func _element() -> Dictionary:
	return element_of.call() if element_of.is_valid() else {}


## The text the designer sees: the draft while a turn is under way, else the element as it stands (where the next turn starts).
func _read() -> String:
	if _working or chat.busy():
		return draft
	var now := _element()
	_from = now.duplicate(true)
	draft = text_of(now) if not now.is_empty() else ""
	return draft


func _on_chat() -> void:
	if chat.busy():
		_working = true
		var a := chat.activity()
		doing = a if not a.is_empty() else "the designer is at work"
		changed.emit()
		return
	if not _working:
		return
	_working = false
	doing = ""
	_land()
	changed.emit()


## The turn that ended landed: its draft, where it changed the element, kept as a version and put in the element's place.
func _land() -> void:
	error = ""
	var last: Dictionary = chat.turns.back() if not chat.turns.is_empty() else {}
	var said_error := String(last.get("error", ""))
	var now := _element()
	var base := now if not now.is_empty() else _from
	if base.is_empty():
		error = "it is no longer round the scene"
		return
	var got := landed(_from if not _from.is_empty() else base, base, draft)
	if got.has("error"):
		error = said_error if not said_error.is_empty() else String(got["error"])
		return
	var made: Dictionary = got["element"]
	if EnvironmentLibrary.what(made) == EnvironmentLibrary.what(base):
		error = said_error
		return
	if not ElementVersions.writable(dir):
		error = "this session cannot keep its versions"
		return
	if not _from.is_empty() and ElementVersions.of(dir, _from) < 0:
		ElementVersions.add(dir, _from, "", "")
	if now.is_empty() or not put.is_valid():
		error = "the note was left: the new version is kept, to pick on its entry"
	else:
		error = String(put.call(made))
	# kept as it reads back where it landed (a table makes what it is handed its own), so the entry finds it among its versions
	var kept := _element() if error.is_empty() else {}
	ElementVersions.add(dir, kept if not kept.is_empty() else made, String(last.get("you", "")), by_of(last))
	chat.seen = text_of(kept if not kept.is_empty() else made)
	chat.save()


## What the designer is told it works on: rules/sound/environment.yaml's names.
func about() -> Dictionary:
	var el := _element()
	var kind := String(el.get("kind", ""))
	var fields: Array = []
	var fs := Surroundings.fields_of(kind)
	for k in fs:
		var f: Dictionary = fs[k]
		fields.append({"key": k, "label": String(f.get("label", k)), "blurb": String(f.get("blurb", "")), "range": range_of(kind, k, f)})
	var words: Array = []
	for k in Surroundings.own_keys(kind):
		if Surroundings.HEARD_WORDS.has(k):
			words.append({"key": k, "label": Registry.label(Surroundings.HEARD_WORDS, k), "blurb": Registry.blurb(Surroundings.HEARD_WORDS, k)})
	var calls: Array = []
	if kind == "creature":
		for k in Soundscape.CALLS:
			calls.append({"key": k, "about": String((Soundscape.CALLS[k] as Dictionary)["about"])})
	return {"what": "a sound round the scene", "title": title, "kind": Registry.label(Surroundings.KINDS, kind) if Surroundings.KINDS.has(kind) else kind,
		"about": Registry.blurb(Surroundings.KINDS, kind) if Surroundings.KINDS.has(kind) else "", "fields": fields, "words": words,
		"has_words": not words.is_empty(), "calls": calls, "has_calls": not calls.is_empty(), "seconds": "%d" % int(EnvironmentSoundTools.HEARD)}


## The draft heard for [param seconds], as the element would be with it ([EnvironmentSoundTools]' `hear`): `{text}` or `{error}`.
func hear(seconds: float) -> Dictionary:
	var now := _element()
	if now.is_empty() or not heard_by.is_valid():
		return {"error": "The sound is no longer round the scene: the author has left it. Stop here."}
	var got := landed(_from if not _from.is_empty() else now, now, draft)
	if got.has("error"):
		return {"error": String(got["error"]) + ": read it and fix it before hearing it."}
	var el: Dictionary = got["element"]
	var notes := PackedStringArray()
	var one := el.duplicate(true)
	one.erase("off")
	Surroundings.sound_of({"elements": [one]}, notes)
	var made: Dictionary = heard_by.call(el)
	var lines := PackedStringArray(["It is: " + Surroundings.line_of(el)])
	for k in (got["unknown"] as Array):
		lines.append("Left out - not a property or word of this sound: %s" % String(k))
	for h in (got["held"] as Array):
		lines.append("Held to its bounds: %s" % String(h))
	for n in notes:
		lines.append("Made safe: %s" % n)
	if (made.get("sound", {}) as Dictionary).is_empty():
		lines.append("It makes no sound as it stands.")
		return {"text": "\n".join(lines)}
	doing = "hearing it"
	changed.emit()
	heard = await measure(made, seconds)
	changed.emit()
	lines.append(SoundMeasure.text(heard))
	return {"text": "\n".join(lines)}


## [param made] (`{sound, wind, ride, seed}`) heard alone for [param seconds] at the level it has under the voice, on a worker:
## [SoundMeasure]'s numbers, its fade in passed over. Awaited.
static func measure(made: Dictionary, seconds: float) -> Dictionary:
	var box := {"m": {}}
	var task := WorkerThreadPool.add_task(func() -> void:
		var sc := Soundscape.new(made["sound"], made.get("wind", {}), int(made.get("seed", 0)), RATE, 0.0, made.get("ride", {}))
		sc.set_level(Surroundings.BED_LEVEL)
		var x := sc.render(int((seconds + FADED) * RATE))
		box["m"] = SoundMeasure.measure(x, RATE, FADED), false, "environment sound heard")
	var tree := Engine.get_main_loop() as SceneTree
	while tree != null and not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return box["m"]


# --- the text, pure for the gate -----------------------------------------------------------------------------------------

## Element [param el] as the designer reads it: every property of its kind as it is now (set or drawn), then the words of its own it
## has ([constant Surroundings.OWN]), as JSON.
static func text_of(el: Dictionary) -> String:
	var kind := String(el.get("kind", ""))
	var v := Surroundings.values_of(el)
	var out := {}
	for k in Surroundings.fields_of(kind):
		out[k] = snappedf(float(v[k]), 0.001) if v.get(k) is float else v.get(k)
	var own: Dictionary = el.get("own", {}) if el.get("own") is Dictionary else {}
	for k in Surroundings.own_keys(kind):
		if own.has(k):
			out[k] = own[k]
	return JSON.stringify(out, "\t", false)


## The text [param text] the designer left, landed on element [param now] where it changed what the element was when it was shown
## it ([param from]): `{element, unknown, held}` - the element made safe, the keys it does not know, and each value held to its
## bounds - or `{error}` where the text is no JSON object. A property left as it was shown stays as [param now] has it (set by a hand
## meanwhile, or drawn by its number); a word of its own taken out is gone.
static func landed(from: Dictionary, now: Dictionary, text: String) -> Dictionary:
	var j := JSON.new()
	if text.strip_edges().is_empty() or j.parse(text) != OK or not (j.data is Dictionary):
		return {"error": "the sound's properties are not a JSON object"}
	var d: Dictionary = j.data
	var kind := String(now.get("kind", ""))
	var fields := Surroundings.fields_of(kind)
	var own_keys := Surroundings.own_keys(kind)
	var was := Surroundings.values_of(from)
	var el := now.duplicate(true)
	for k in fields:
		if d.has(k) and not _same(d[k], was.get(k)):
			el[k] = d[k]
	var own_was: Dictionary = from.get("own", {}) if from.get("own") is Dictionary else {}
	var own: Dictionary = (now.get("own", {}) as Dictionary).duplicate(true) if now.get("own") is Dictionary else {}
	for k in own_keys:
		if d.has(k):
			if not _same(d[k], own_was.get(k)):
				own[k] = d[k]
		elif own_was.has(k):
			own.erase(k)
	if not own.is_empty() or now.has("own"):
		el["own"] = own
	var unknown: Array = []
	for k in d:
		if not fields.has(k) and not own_keys.has(k):
			unknown.append(String(k))
	var made := Surroundings.element(el)
	if made.is_empty():
		return {"error": "those properties make it nothing"}
	var held: Array = []
	for k in fields:
		if d.has(k) and made.has(k) and not _same(d[k], made[k]):
			held.append("%s %s, used as %s" % [k, str(d[k]), str(made[k])])
	return {"element": made, "unknown": unknown, "held": held}


## Whether [param a] and [param b] say the same: numbers within the text's rounding, the rest as JSON does.
static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return absf(float(a) - float(b)) <= 0.0006
	return JSON.stringify(a) == JSON.stringify(b)


## Property [param k] of kind [param kind] (its row [param f]) as the designer is told what it takes: a choice's options and what each
## sounds like, a number's bounds.
static func range_of(kind: String, k: String, f: Dictionary) -> String:
	if String(f.get("type", "")) == "enum":
		var about := Surroundings.heard_choices(kind, k)
		var opts := PackedStringArray()
		for o in (f.get("options", []) as Array):
			opts.append("\"%s\"%s" % [String(o), (" (%s)" % String(about[o])) if about.has(o) else ""])
		return "one of " + ", ".join(opts)
	if f.has("min") and f.has("max"):
		return "%s to %s" % [_num(f["min"]), _num(f["max"])] + (", a whole number" if String(f.get("type", "")) == "int" else "")
	return ""


## A bound as it is read: a whole number without its point.
static func _num(x: Variant) -> String:
	return str(int(x)) if float(x) == roundf(float(x)) else str(snappedf(float(x), 0.001))


## Who made a turn's change, in a few words: the agent and its model.
static func by_of(turn: Dictionary) -> String:
	var agent := String(turn.get("agent", ""))
	var model := String(turn.get("model", ""))
	return agent if model.is_empty() else "%s %s" % [agent, model]
