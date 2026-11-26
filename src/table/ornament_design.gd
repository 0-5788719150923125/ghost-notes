extends RefCounted
class_name OrnamentDesign

## OrnamentDesign - one kept ornament or texture being made and refined (next/surfaces.md): the code its designer works on through
## its tools ([OrnamentTools]), the conversation it works in ([WriterChat], kept in its folder with rules/table/ornament_designer.yaml,
## told which of the two it writes), and what a turn leaves: code that changed, passes [method Ornaments.check] and compiles is a new
## version, used from then on ([method OrnamentLibrary.add_version]) - every prop wearing it by name draws it.
##
## Made and refined in a Refine… window ([TextRefine], [method open]): its first turn is the author saying what the ornament is,
## which becomes its words. One design an ornament, held while the process runs and polled each frame by a node of its own
## ([method of]).

## Something to show: a turn begun or ended, a version kept.
signal changed

var name := ""
## What it is: [constant OrnamentLibrary.ORNAMENT] or [constant OrnamentLibrary.TEXTURE].
var kind := OrnamentLibrary.ORNAMENT
var chat: WriterChat
## The draft code.
var draft := ""
## What the last turn went wrong with, "" for nothing.
var error := ""
var window: TextRefine = null

var _was_busy := false

static var _open := {}            # name -> OrnamentDesign
static var _poller: Node = null


## The design of the ornament named [param name], made the first time it is asked for and polled from then on.
static func of(ornament: String) -> OrnamentDesign:
	var d: OrnamentDesign = _open.get(ornament)
	if d == null:
		d = OrnamentDesign.new(ornament)
		_open[ornament] = d
	if _poller == null or not is_instance_valid(_poller):
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			_poller = Poller.new()
			tree.root.add_child.call_deferred(_poller)
	return d


## The design of [param ornament] let go, where it was renamed or removed: its window closed, its conversation's turn left as it is.
static func forget(ornament: String) -> void:
	var d: OrnamentDesign = _open.get(ornament)
	if d == null:
		return
	if d.window != null and is_instance_valid(d.window):
		d.window.queue_free()
	_open.erase(ornament)


func _init(ornament: String) -> void:
	name = ornament
	kind = String(OrnamentLibrary.find(name).get("kind", OrnamentLibrary.ORNAMENT))
	draft = OrnamentLibrary.code_of(name)
	chat = WriterChat.at(OrnamentLibrary.folder(name))
	chat.rules = "table/ornament_designer"
	chat.read_text = func() -> String: return draft
	chat.apply = func(at: int, gone: int, put: String) -> void:
		draft = draft.substr(0, at) + put + draft.substr(at + gone)
	chat.about = about
	chat.toolset = func(t: TextTools) -> Object:
		var tools := OrnamentTools.new()
		tools.text = t
		tools.name = name
		tools.kind = kind
		return tools
	_was_busy = chat.busy()


## What the designer is told it works on: the system prompt's names (rules/table/ornament_designer.yaml), `texture` where it writes one.
func about() -> Dictionary:
	var texture := kind == OrnamentLibrary.TEXTURE
	return {"what": "the code of a texture" if texture else "the code of an ornament", "name": name,
		"words": String(OrnamentLibrary.find(name).get("words", "")), "language": Ornaments.describe(kind), "texture": texture}


func busy() -> bool:
	return chat.busy()


## Its Refine… window opened, beside [param host] where there is one.
func open(host: Window = null) -> void:
	if window == null or not is_instance_valid(window):
		window = TextRefine.new(chat, "the %s \"%s\"" % [kind, name])
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null or tree.root == null:
			return
		tree.root.add_child(window)
	window.open_beside(host)


## A frame's look: the turn under way polled, and once it ends, what it left kept.
func poll() -> void:
	chat.poll()
	if chat.busy():
		_was_busy = true
		return
	if not _was_busy:
		return
	_was_busy = false
	var last: Dictionary = chat.turns.back() if not chat.turns.is_empty() else {}
	error = String(last.get("error", ""))
	# what the author first said it is, where it has no words yet
	var e := OrnamentLibrary.find(name)
	if not e.is_empty() and String(e["words"]).is_empty() and not chat.turns.is_empty():
		OrnamentLibrary.set_words(name, String((chat.turns[0] as Dictionary).get("you", "")))
	keep_draft(String(last.get("reply", "")))
	changed.emit()


## The draft as a new version, where it changed, passes [method Ornaments.check] and compiles: its index, -1 for none kept ([member
## error] says why, where something was wrong).
func keep_draft(said := "") -> int:
	if draft.strip_edges().is_empty() or draft.strip_edges() == OrnamentLibrary.code_of(name).strip_edges():
		return -1
	var why := Ornaments.compile_errors(draft, kind)
	if not why.is_empty():
		error = "the code the designer left does not compile: " + why
		return -1
	return OrnamentLibrary.add_version(name, draft, said)


## What polls every open design each frame.
class Poller extends Node:
	func _process(_delta: float) -> void:
		for d in OrnamentDesign._open.values():
			(d as OrnamentDesign).poll()
