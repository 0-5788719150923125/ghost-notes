extends VBoxContainer
class_name TimelineList

## TimelineList - THE TIMELINE OPEN, AS A LIST on the panel's Timeline card (the user, 2026-11-11: "The original timeline had those
## flags in a list, along the left-hand UI panel. That was very useful ... instead of forcing users to click them on the timeline
## (which isn't always possible ... when the flags are stacked)"): every group and every item of the timeline editor open now
## ([constant TimelineDock.GROUP]: an episode's beats, acts and cues; a storyboard's entries, verbs and flags), in the order they
## come, each its time and its name; a row pressed picks it in the editor's inspector and moves the show there. The card it is on
## is shown while an editor is open and hidden otherwise - the list follows the editor, never the other way.

## What its card is for, on the card's title bar and its chip ([member Card.blurb]).
const BLURB := "The open timeline as a list: every beat, cue or entry at its time. Press one to pick it and move the show there. Shown while a timeline is open."
const POLL := 10              # frames between looks at what is open

var _editor: Node = null
var _seen := 0
var _rows: Array = []         # the rows' buttons, by item index


func _init() -> void:
	add_theme_constant_override("separation", 0)


func _ready() -> void:
	refresh()


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % POLL == 0:
		refresh()


## WHAT IS OPEN, LOOKED AT AGAIN: the card shown or hidden with it, the rows built again where its items changed.
func refresh() -> void:
	var ed := get_tree().get_first_node_in_group(TimelineDock.GROUP) if is_inside_tree() else null
	var items: Array = ed.call("timeline_items") if ed != null and ed.has_method("timeline_items") else []
	var card := _card()
	if card != null:
		card.visible = ed != null and not items.is_empty()
	var h := hash([ed.get_instance_id() if ed != null else 0, JSON.stringify(items)])
	if h == _seen:
		return
	_seen = h
	_editor = ed
	show_items(items)


## [param items] ([method TimelineDock.timeline_items]) as rows: a group's a heading, an item's its time and name beneath it.
func show_items(items: Array) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_rows = []
	for i in items.size():
		var e: Dictionary = items[i]
		var group := String(e.get("kind", "")) == "group"
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.text = ("%s  %s" if group else "      %s  %s") % [Clock.text(float(e.get("at", 0.0))), String(e.get("label", ""))]
		b.add_theme_font_size_override("font_size", 13 if group else 12)
		if not group:
			b.modulate = Color(1, 1, 1, 0.82)
		b.tooltip_text = "Pick %s in the timeline and go to it." % String(e.get("label", "it"))
		b.pressed.connect(press.bind(i))
		add_child(b)
		_rows.append(b)


## ROW [param i] PRESSED: the editor picks it and the show goes there.
func press(i: int) -> void:
	if _editor != null and is_instance_valid(_editor) and _editor.has_method("pick_item"):
		_editor.call("pick_item", i)


## How many rows are shown.
func row_count() -> int:
	return _rows.size()


func _card() -> Card:
	var n: Node = get_parent()
	while n != null and not (n is Card):
		n = n.get_parent()
	return n as Card
