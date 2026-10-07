extends VBoxContainer
class_name StoryboardsCard

## StoryboardsCard - the scenes by hand: the storyboards in `storyboards/`, one a click away, in a
## note with a song and a Picture (the Manual template). It was the Workspace, a panel of its own
## beside the show; a note's panel holds it now, as a card like every other component's, and the
## board picked is the note's - kept in its `scenes:` block, where a new Manual note names the default.
##
## A board picked while the song is loaded switches the show to it at once and cuts to its first
## scene; picked before a song is chosen, it is the board the show starts on.

## The block this card keeps under a note's `ghost:` key.
const KEY := "scenes"

## A line for the panel's status ("Storyboard: the-point").
signal noted(msg: String)

var _list: VBoxContainer
var _buttons := {}            # storyboard name -> Button
var _active := ""


func _init() -> void:
	add_theme_constant_override("separation", 4)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	add_child(_list)
	for n in boards():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select.bind(n))
		_list.add_child(b)
		_buttons[n] = b
	_restyle()


## Every storyboard in `storyboards/`, by name, once each whatever its format.
static func boards() -> Array:
	var names: Array = []
	var dir := DirAccess.open("res://storyboards")
	if dir == null:
		return names
	for fn in dir.get_files():
		if fn.ends_with(".yaml") or fn.ends_with(".yml") or fn.ends_with(".json"):
			if not names.has(fn.get_basename()):
				names.append(fn.get_basename())
	names.sort()
	return names


## The board the note plays.
func active() -> String:
	return _active


## The block for a note.
func capture() -> Dictionary:
	return {"storyboard": _active}


## ...and back: the board the note names, shown as the one playing.
func apply(block: Dictionary) -> void:
	var b := String(block.get("storyboard", ""))
	if not b.is_empty():
		_active = b
		_restyle()


## Switch the show to [param name] and cut to its first scene; with no show up yet, it is the board
## the show starts on.
func _select(name: String) -> void:
	if not Director.load_storyboard(name):
		noted.emit("⚠  Could not read the storyboard '%s'." % name)
		return
	_active = name
	if Director.is_attached():
		Director.next()
	_restyle()
	noted.emit("Storyboard: %s" % name)


func _restyle() -> void:
	for n in _buttons:
		var b: Button = _buttons[n]
		b.text = ("▶ " + n) if n == _active else ("   " + n)
