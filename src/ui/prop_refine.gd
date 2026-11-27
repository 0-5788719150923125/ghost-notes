extends PanelContainer
class_name PropRefine

## PropRefine - the 3D view's Refine ([PropViewer], [PropVersions]), docked into the window it is opened from ([RefineDock]: the window
## widens to hold it, or the side panel holding the card does; its Refine button opens and folds it): what to change in the prop
## shown, in words, and who changes it -
## the agent, its model and how hard it thinks ([AgentPick]) - then the agent at work: a bar that keeps moving and the line it
## reports (what it is doing, for how long, and how long since it last said anything) until its version lands or it is stopped. It
## stays open, its words kept, for the next change. The agent picked is every refine's of its kind from then on, kept between
## sessions ([method AgentPick.keep_for]).
##
## The same window refines a picture ([IllustrationPanel]'s Refine…), built with `PropRefine.new("picture", painter)`: its agent
## a painter, its words a picture's ([constant WORDS]), and what is made a new version of the picture; and a table show's table
## (`PropRefine.new("table")`, [TableRefine]), whose agent rewrites its top and cloths.

## What to change, and who changes it (`{agent, model, effort}`).
signal asked(direction: String, pick: Dictionary)
## The refining under way given up.
signal stopped


## What the window says for each kind of thing it refines: the line over the words, the words' placeholder, who refines it, and
## the Refine button's tip.
const WORDS := {
	"prop": {"say": "What to change. The agent changes only what you ask; every other part, size and color stays as it is.",
		"hint": "Which part is wrong, and how it should be instead.", "who": "Who refines the prop.",
		"go": "Have the agent make a new version from the one shown. It is added beside the others; the one shown when you close the view is the prop."},
	"table": {"say": "What to change in the table: its top, what holds it up, the cloths on it. The agent changes only what you ask; the things on it stay where they are.",
		"hint": "What is wrong with the table or its cloths, and how it should be instead.", "who": "Who refines the table.",
		"go": "Have the agent rewrite the table as you say. The table on the stage follows; the one before is kept a version back."},
	"picture": {"say": "What to change. The painter changes only what you ask; the rest of the picture stays as it is.",
		"hint": "What is wrong in the picture, and how it should be instead.", "who": "Who repaints the picture.",
		"go": "Have the painter make a new version from the one shown, changed as you say. It is shown at once; the one it was made from stays a version before it."},
}

## The kind of job the agent picked last is kept for between sessions ([method AgentPick.last_for]): a prop's refiner, a picture's.
const PICKED := {"prop": "refine_prop", "picture": "refine_picture", "table": "refine_prop"}

var _what := "prop"
var _head: Label                  # what it refines, over the words

var _text: TextEdit
var _pick: AgentPick
var _bar: ProgressBar
var _line: Label
var _go: Button
var _stop: Button
var _working := false


## A window refining a [param what] (a key of [constant WORDS]); a picture's agent starts as [param start] (`{agent, model, effort}`,
## the painter the note uses) until one is picked here.
func _init(what := "prop", start := {}) -> void:
	_what = what if WORDS.has(what) else "prop"
	var words: Dictionary = WORDS[_what]
	visible = false
	custom_minimum_size = Vector2(0, 300)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pad.add_child(col)
	_head = Label.new()
	_head.text = "Refine"
	_head.add_theme_font_size_override("font_size", 14)
	_head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_head)
	var say := Label.new()
	say.text = String(words["say"])
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(say)
	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(0, 110)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.placeholder_text = String(words["hint"])
	col.add_child(_text)
	var picture := _what == "picture"
	_pick = AgentPick.painter(String(words["who"])) if picture else AgentPick.writer(String(words["who"]))
	var was := AgentPick.last_for(String(PICKED[_what]))
	if was.is_empty() and picture:
		was = start
	if not was.is_empty():
		_pick.set_choice(String(was.get("agent", "")), String(was.get("model", "")), String(was.get("effort", "")))
	_pick.changed.connect(_remember)
	col.add_child(_pick)
	_bar = ProgressBar.new()
	_bar.indeterminate = true
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 6)
	_bar.visible = false
	col.add_child(_bar)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 11)
	_line.modulate = Color(1, 1, 1, 0.8)
	col.add_child(_line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var room := Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(room)
	_stop = Button.new()
	_stop.text = "Stop"
	_stop.tooltip_text = "Give this refining up: nothing is added."
	_stop.visible = false
	_stop.pressed.connect(func() -> void: stopped.emit())
	row.add_child(_stop)
	_go = Button.new()
	_go.text = "Refine"
	_go.tooltip_text = String(words["go"])
	_go.pressed.connect(_ask)
	row.add_child(_go)


## Opened for the thing called [param name], docked where [param from] is (the window it is shown in, or the card the Refine button
## is on: [method RefineDock.host_of]), whatever it was.
func open_for(name: String, from: Node) -> void:
	_head.text = "Refine - %s" % name
	RefineDock.open(RefineDock.host_of(from), self)
	_pick.mark_available()
	_text.grab_focus()


## The Refine button's toggle: opened for the thing called [param name] docked where [param from] is, or folded away where it stands
## open; [param button] shown pressed while it is open. Whether it is open now.
func toggle_for(name: String, from: Node, button: BaseButton = null) -> bool:
	if RefineDock.is_open(self):
		RefineDock.close(self)
		RefineDock.show_on(button, self)
		return false
	open_for(name, from)
	RefineDock.show_on(button, self)
	return true


## Folded away ([method RefineDock.close]).
func fold() -> void:
	RefineDock.close(self)


## Whether the agent is at work: the bar moves and Stop shows, and the words wait.
func working(on: bool) -> void:
	_working = on
	_bar.visible = on
	_stop.visible = on
	_go.disabled = on
	_text.editable = not on


## [param line] said under the words: what the agent is doing, or how it went.
func say(line: String) -> void:
	_line.text = line


## The words written, and the writer picked.
func direction() -> String:
	return _text.text


func pick() -> Dictionary:
	return _pick.choice()


## The words set (a gate's, or a direction to start from).
func set_direction(text: String) -> void:
	_text.text = text


func _ask() -> void:
	if _working:
		return
	if _text.text.strip_edges().is_empty():
		say("Say what to change first.")
		return
	_remember()
	asked.emit(_text.text.strip_edges(), _pick.choice())


func _remember() -> void:
	AgentPick.keep_for(String(PICKED[_what]), _pick.choice())
