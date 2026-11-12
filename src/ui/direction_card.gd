extends VBoxContainer
class_name DirectionCard

## DirectionCard - the Direction's card ([Direction]; next/direction.md): where to take what is made
## next, written beside the note's own words and handed to every agent above them. A box for the
## direction, a Refine that has the writer make a short direction a full one in the show's own terms,
## and who refines.
##
## Refine and what the writer is doing stand in the window the direction is written in
## ([method TextField.add_action]), and the refined words land in its box ([method TextField.replace]).
## It has no undo of its own. The card keeps a line of what is happening, for a window closed while a
## refine runs.
##
## The note's words are left alone: Refine writes only the direction, so a show's brief stays as its
## author keeps it, and the direction is changed for the next episode as often as it is wanted.
##
## Refine keeps what was asked: the writer reads the note (the show's brief, or a note's words) and the
## direction, and writes the direction back whole - every topic, request and emphasis kept, made precise,
## with what the note's agents need to make it (rules/agents/direction.yaml).

## The block this card keeps under `ghost:`.
const KEY := Direction.KEY
## Where a refine's job is kept, its prompt beside its answer: moved aside by a gate.
static var root := "user://directions"

var _field: TextField
var _refine: Button
var _status: Label
var _said: Label          # ...the same, in the window
var _writer: AgentPick
var _workspace: Object = null
var _job := ""
var _syncing := false


## The card for a note's panel: [param ctx]'s `workspace` is what it reads the note's words from and tells of a change.
static func for_note(ctx: Dictionary) -> DirectionCard:
	var c := DirectionCard.new()
	c._workspace = ctx.get("workspace")
	return c


func _init() -> void:
	add_theme_constant_override("separation", 6)
	_field = TextField.new("Prompt", "Where should what is made next go? - click to write it",
		("What the next episode is about or does, beyond the note's own words, and above them: every agent that makes it is "
		+ "told this first, and follows it where the note says otherwise. An episode keeps the direction it was made from, so "
		+ "change this for the next one freely. Refine, in the window, has the writer fill a line out into a full direction."))
	_field.text_changed.connect(_touch)
	add_child(_field)
	_refine = Button.new()
	_refine.text = "Refine"
	_refine.tooltip_text = ("The writer reads the note and what you wrote here - a line is enough - and writes the direction "
		+ "back whole, in the note's own terms: everything you asked kept, made precise, with what the agents need to make it. "
		+ "The note itself is left as it is. Press it again to refine further.")
	_refine.pressed.connect(refine)
	_field.add_action(_refine)
	_said = Label.new()
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.add_theme_font_size_override("font_size", 12)
	_said.visible = false
	_field.add_line(_said)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	_status.visible = false
	add_child(_status)
	# Who refines: the agent, its model and how hard it reasons - the row every card that runs agents builds ([AgentPick])
	_writer = AgentPick.writer("Who refines the direction. Takes effect at the next Refine.")
	_writer.changed.connect(func() -> void:
		if not _syncing:
			_touch())
	add_child(_writer)
	_show_buttons()


func _process(_delta: float) -> void:
	if _job.is_empty():
		return
	var st := AgentJobs.state(_job)
	if st != "done" and st != "failed":
		return
	var res := AgentJobs.result(_job)
	AgentJobs.forget(_job)
	_job = ""
	land(res)


## The direction as written now.
func text() -> String:
	return _field.text


## Refine: the writer's job, from the note's words and the direction as it stands ([method prompt]); landed by [method land].
func refine() -> void:
	if not _job.is_empty():
		return
	if _field.text.strip_edges().is_empty():
		_say("Write a direction first - a line is enough - then press Refine.")
		return
	var p := prompt(_note_title(), _note_words(), _field.text)
	var c := _writer.choice()
	var dir := ProjectSettings.globalize_path(root.path_join("jobs").path_join("%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]))
	_job = AgentJobs.submit({"kind": "text", "backend": String(c["agent"]), "tier": "best", "dir": dir,
		"system": String(p["system"]), "prompt": String(p["prompt"]), "label": "direction refine",
		"model": String(c["model"]), "effort": String(c["effort"])})
	if _job.is_empty():
		_say("This session cannot start agents.")
		return
	_say("Refining the direction…")
	_show_buttons()


## The refiner's prompt for a note titled [param title] whose words are [param words], and [param direction] as the author wrote it.
## Static and pure for the gate.
static func prompt(title: String, words: String, direction: String) -> Dictionary:
	var vars := {"title": title, "words": words.strip_edges(), "direction": direction.strip_edges(), "has_words": not words.strip_edges().is_empty()}
	return {"system": Rules.say("agents/direction.system", vars), "prompt": Rules.say("agents/direction.prompt", vars)}


## A refine's answer [param res] (`{ok, text, error}`) landed: the direction written over - or why not, said.
func land(res: Dictionary) -> void:
	if not bool(res.get("ok", false)):
		_say("⚠  The refine stopped: %s" % String(res.get("error", "its run failed")))
		_show_buttons()
		return
	var got := clean(String(res.get("text", "")))
	if got.is_empty():
		_say("⚠  The writer wrote nothing.")
		_show_buttons()
		return
	_field.replace(got)
	_touch()
	_say("The direction is refined - edit it if you like. An episode takes it up when its plan is made.")
	_show_buttons()


## A writer's answer as a direction: a fenced answer unwrapped, outer blank lines off, cut to [constant Direction.MOST].
static func clean(text: String) -> String:
	var t := text.strip_edges()
	if t.begins_with("```"):
		var nl := t.find("\n")
		t = t.substr(nl + 1) if nl >= 0 else ""
		if t.ends_with("```"):
			t = t.substr(0, t.length() - 3)
	return t.strip_edges().left(Direction.MOST)


func capture() -> Dictionary:
	var c := _writer.choice()
	return {"text": _field.text, "writer": String(c["agent"]), "writer_model": String(c["model"]), "writer_effort": String(c["effort"])}


func apply(block: Dictionary) -> void:
	if block.has("text") and not _field.editing() and _field.text != String(block["text"]):
		_field.text = String(block["text"])
	_syncing = true
	_writer.set_choice(String(block.get("writer", _writer.choice()["agent"])), String(block.get("writer_model", "")),
		String(block.get("writer_effort", "")))
	_syncing = false
	_show_buttons()


func _show_buttons() -> void:
	_refine.disabled = not _job.is_empty()


func _say(what: String) -> void:
	for l in [_status, _said]:
		(l as Label).text = what
		(l as Label).visible = not what.is_empty()


## The panel told of a change, so the note keeps it.
func _touch() -> void:
	if _workspace != null and is_instance_valid(_workspace) and _workspace.has_method("touch"):
		_workspace.call("touch")


## The note's words as the panel holds them now (its frontmatter aside), and its title.
func _note_raw() -> String:
	if _workspace == null or not is_instance_valid(_workspace) or not _workspace.has_method("doc_source"):
		return ""
	var doc: Object = _workspace.call("doc_source")
	return String(doc.call("pull")) if doc != null and doc.has_method("pull") else ""


func _note_words() -> String:
	return Manuscript.strip_frontmatter(_note_raw())


func _note_title() -> String:
	return FrontMatter.field_of(_note_raw(), "title").strip_edges()
