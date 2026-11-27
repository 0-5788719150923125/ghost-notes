extends RefCounted
class_name DeliveryDesign

## DeliveryDesign - one delivery a note says tuned with a designer (next/delivery.md, "Tuning a delivery"): its spec as a text
## ([method DeliveryBank.spec_of], JSON) the designer changes through its tools and HEARS ([DeliveryTools], [DeliveryHearing]), in a
## conversation ([WriterChat], rules/voice/delivery.yaml) kept in the delivery's folder beside the note, with its versions
## ([DeliveryVersions]). Refine… in the delivery's Lab opens it ([DeliveryLab], [TextRefine]).
##
## A turn starts from the delivery as the note says it now. One that leaves it changed is a new version, used at once (the reading
## and the Lab's Test say it); the delivery as it stood before is kept as a version first where it was none, so a hand's change is
## never lost. One design a folder ([method at]), live across a Lab opened again: the Lab binds what it stands for each time
## ([member spec_of], [member put], [member words_of], [member hearer]).

## Something to show: a turn begun or ended, the designer at work, a version made.
signal changed

## The folder its conversation and versions are kept in.
var dir := ""
## The delivery's name, as a script says it.
var name := ""
## The note's title, for what the designer is told.
var title := ""
var chat: WriterChat
## The spec as the designer works on it, as text.
var draft := ""
## What the last turn went wrong with, "" for nothing.
var error := ""
## What the designer is doing now, as a line ("" between turns).
var doing := ""
## What the draft measured when last heard ([DeliveryHearing]'s text).
var heard := ""

## The delivery as the note says it now: `func() -> Dictionary`, {} once its Lab is gone.
var spec_of: Callable
## A spec made the version used: `func(spec: Dictionary, note: String, by: String) -> String`, "" done, else why not.
var put: Callable
## The words the author tests it on: `func() -> String`.
var words_of: Callable
## Words said with a draft and without, heard: `func(words: String, draft: Dictionary) -> Dictionary` (awaited, [method
## DeliveryHearing.hear]'s answer).
var hearer: Callable

var _from := {}
var _working := false
static var _live := {}


## The design live in [param folder] now, null for none.
static func live(folder: String) -> DeliveryDesign:
	return _live.get(ProjectSettings.globalize_path(folder))


## The design kept in [param folder] for delivery [param delivery]: the one live there, else a new one on the conversation kept there.
static func at(folder: String, delivery: String) -> DeliveryDesign:
	var key := ProjectSettings.globalize_path(folder)
	if not _live.has(key):
		_live[key] = DeliveryDesign.new(folder, delivery)
	return _live[key]


func _init(folder: String, delivery: String) -> void:
	dir = folder
	name = delivery
	chat = WriterChat.at(folder)
	chat.rules = "voice/delivery"
	chat.read_text = _read
	chat.apply = func(at_: int, gone: int, s: String) -> void: draft = draft.substr(0, at_) + s + draft.substr(at_ + gone)
	chat.about = about
	chat.toolset = func(t: TextTools) -> Object:
		var tools := DeliveryTools.new()
		tools.text = t
		tools.hear = hear
		return tools
	chat.changed.connect(_on_chat)
	_working = chat.busy()


## Whether a turn is under way.
func busy() -> bool:
	return chat.busy() or _working


func _spec() -> Dictionary:
	return spec_of.call() if spec_of.is_valid() else {}


## The text the designer sees: the draft while a turn is under way, else the delivery as the note says it now.
func _read() -> String:
	if _working or chat.busy():
		return draft
	_from = _spec()
	draft = text_of(_from)
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


## The turn that ended landed: its draft, where it changed the delivery, made the version used.
func _land() -> void:
	error = ""
	var last: Dictionary = chat.turns.back() if not chat.turns.is_empty() else {}
	var said_error := String(last.get("error", ""))
	var got := landed(draft)
	if got.has("error"):
		error = said_error if not said_error.is_empty() else String(got["error"])
		return
	var made: Dictionary = got["spec"]
	if DeliveryVersions.what(made) == DeliveryVersions.what(_from):
		error = said_error
		return
	if not DeliveryVersions.writable(dir):
		error = "this session cannot keep its versions"
		return
	if not _from.is_empty() and DeliveryVersions.of(dir, _from) < 0:
		DeliveryVersions.add(dir, _from, "", "")
	if not put.is_valid():
		DeliveryVersions.add(dir, made, String(last.get("you", "")), by_of(last))
		error = "the Lab was closed: the new version is kept, to pick on the delivery's entry"
	else:
		error = String(put.call(made, String(last.get("you", "")), by_of(last)))
	chat.seen = text_of(made)
	chat.save()


## What the designer is told it works on: rules/voice/delivery.yaml's names.
func about() -> Dictionary:
	var axes: Array = []
	for k in DeliveryBank.AXES:
		var a: Dictionary = DeliveryBank.AXES[k]
		axes.append({"key": k, "label": String(a["label"]), "blurb": String(a["blurb"]),
			"range": "%s to %s%s" % [_num(a["lo"]), _num(a["hi"]), (" " + String(a["unit"])) if not String(a["unit"]).is_empty() else ""],
			"neutral": "1" if String(a["kind"]) == "mult" else "0"})
	var acts: Array = []
	for k in DeliveryBank.ACTS:
		var c := DeliveryBank.contour_of(String(k))
		acts.append({"key": k, "blurb": String(DeliveryBank.ACTS[k]["blurb"]), "contour": JSON.stringify(c) if not c.is_empty() else "none"})
	var shapes: Array = []
	for k in DeliveryBank.SHAPES:
		shapes.append({"key": k, "blurb": String(DeliveryBank.SHAPES[k]["blurb"])})
	var blurb := DeliveryBank.blurb_of(name)
	return {"title": title, "name": name, "about": blurb if not blurb.is_empty() else "a delivery of this note's own",
		"axes": axes, "acts": acts, "shapes": shapes, "words": String(words_of.call()) if words_of.is_valid() else ""}


## The draft heard ([DeliveryTools]' `hear`): [param words] ("" the Lab's) said with it and without. `{text}` or `{error}`.
func hear(words: String) -> Dictionary:
	var got := landed(draft)
	if got.has("error"):
		return {"error": String(got["error"]) + ": read it and fix it before hearing it."}
	if not hearer.is_valid():
		return {"error": "The delivery's Lab is closed: the author has left it. Stop here."}
	var w := words if not words.strip_edges().is_empty() else (String(words_of.call()) if words_of.is_valid() else "")
	var lines := PackedStringArray(["It is: " + (DeliveryBank.line_of(got["spec"]) if not DeliveryBank.line_of(got["spec"]).is_empty() else "nothing moved")])
	for k in (got["unknown"] as Array):
		lines.append("Left out - not something a delivery takes: %s" % String(k))
	doing = "hearing it"
	changed.emit()
	var h: Dictionary = await hearer.call(w, {name: got["spec"]})
	doing = ""
	changed.emit()
	if h.has("error"):
		return {"error": "It could not be heard: %s" % String(h["error"])}
	heard = String(h["text"])
	lines.append("Said: " + DeliveryHearing.passage_of(name, w))
	lines.append(heard)
	return {"text": "\n".join(lines)}


# --- the text, pure for the gate -----------------------------------------------------------------------------------------


## Spec [param spec] as the designer reads it: JSON, every part named even where it is empty.
static func text_of(spec: Dictionary) -> String:
	var out := {"axes": spec.get("axes", {}), "brake": spec.get("brake", {}), "shape": String(spec.get("shape", "")),
		"acts": spec.get("acts", {}), "contours": spec.get("contours", {}), "emph": int(spec.get("emph", 0)),
		"secs": spec.get("secs", {})}
	return JSON.stringify(out, "\t", false)


## The text [param text] the designer left, as a spec: `{spec, unknown}` - made safe through the bank's own reading
## ([method DeliveryBank.from_spec]), and the keys, axes and acts it does not know - or `{error}` where it is no JSON object.
static func landed(text: String) -> Dictionary:
	var j := JSON.new()
	if text.strip_edges().is_empty() or j.parse(text) != OK or not (j.data is Dictionary):
		return {"error": "the delivery is not a JSON object"}
	var d: Dictionary = j.data
	var unknown: Array = []
	for k in d:
		if not String(k) in ["axes", "brake", "shape", "acts", "contours", "emph", "secs"]:
			unknown.append(String(k))
	for k in (d.get("axes", {}) if d.get("axes") is Dictionary else {}):
		if not DeliveryBank.AXES.has(String(k)):
			unknown.append("axis " + String(k))
	for k in (d.get("acts", {}) if d.get("acts") is Dictionary else {}):
		if not DeliveryBank.ACTS.has(String(k)):
			unknown.append("act " + String(k))
	for k in (d.get("secs", {}) if d.get("secs") is Dictionary else {}):
		if not DeliveryBank.RESTS.has(String(k)):
			unknown.append("rest " + String(k))
	if not String(d.get("shape", "")).is_empty() and not DeliveryBank.SHAPES.has(String(d.get("shape", ""))):
		unknown.append("shape " + String(d["shape"]))
	var spec := DeliveryBank.spec_from(DeliveryBank.from_spec(d))
	# a contour the designer drew is kept as drawn (from_spec held it to its bounds)
	return {"spec": spec, "unknown": unknown}


static func _num(x: Variant) -> String:
	return str(int(x)) if float(x) == roundf(float(x)) else str(snappedf(float(x), 0.001))


## Who made a turn's change, in a few words: the agent and its model.
static func by_of(turn: Dictionary) -> String:
	var agent := String(turn.get("agent", ""))
	var model := String(turn.get("model", ""))
	return agent if model.is_empty() else "%s %s" % [agent, model]
