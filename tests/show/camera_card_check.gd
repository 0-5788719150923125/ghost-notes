extends Node

## camera_card_check - the Camera card's Cameras list the format in use's cameras alone ([CameraCard], [Cameras]):
##
##   tests/run_boot_probe.sh tests/show/camera_card_check.gd 60
##
## Holds: the Dispatch desk lists its chair and the camera behind it, neither taken off, and offers nothing to add; a table
## lists the four of a game, dimmed while the note has none of its own, with "+ Add"; a camera moved at the desk is kept
## beside the note's table cameras, which stay as they were. Controls: a format with no cameras shows no list at all; a
## table's camera can be taken off.

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Director.set_cameras([])
	var card := CameraCard.new()
	add_child(card)

	Director.set_medium("dispatch")
	card.refresh()
	var shown := _shown(card)
	_ok(shown == ["From the chair", "Behind the chair"], "the Dispatch desk lists %s, not its chair and the camera behind it" % [shown])
	_ok(_entries(card).all(func(e: EntryCard) -> bool: return e._x.disabled),
		"a camera the Dispatch desk always sees through could be taken off")
	_ok(not card._add.visible, "the Dispatch desk offers a camera to add")

	# a table is a mode's own medium: its card pins it, as the Table card does
	Director.pin_medium("table", self)
	card.refresh()
	shown = _shown(card)
	_ok(shown == ["Dice", "Marching", "Their seat", "Drifting"], "a table lists %s, not the four of a game" % [shown])
	_ok(_entries(card).all(func(e: EntryCard) -> bool: return e.modulate.a < 1.0), "a table's cameras unset are not dimmed")
	_ok(card._add.visible and _entries(card).all(func(e: EntryCard) -> bool: return not e._x.disabled),
		"control: a table's camera cannot be taken off, or there is no + Add")

	# a table camera set, then the desk's camera behind the chair moved: both kept
	Director.set_cameras([{"sort": "seat", "height": 60.0}])
	Director.unpin_medium(self)
	card.refresh()
	var l := card._cameras()
	(l[Cameras.rank(l, "behind")] as Dictionary)["height"] = 120.0
	card._set_list(l)
	var seat := Cameras.entry_of(Director.cameras, "seat")
	var behind := Cameras.entry_of(Director.cameras, "behind")
	_ok(is_equal_approx(float(seat.get("height", 0.0)), 60.0), "a camera moved at the desk lost the note's table cameras (%s)" % [Director.cameras])
	_ok(is_equal_approx(float(behind.get("height", 0.0)), 120.0), "the camera behind the chair was not moved (%s)" % [Director.cameras])

	Director.set_medium("full")
	card.refresh()
	_ok(not card._head.visible and not card._list.visible and not card._add.visible,
		"control: a format with no cameras shows a Cameras list")

	Director.set_cameras([])
	card.queue_free()
	await get_tree().process_frame
	print("")
	if _fails.is_empty():
		print("camera_card_check: ALL OK")
		get_tree().quit(0)
		return
	for f in _fails:
		print("camera_card_check: FAIL - ", f)
	print("camera_card_check: %d FAILED" % _fails.size())
	get_tree().quit(1)


## The entries the card draws now (those freed by the last draw left out).
func _entries(card: CameraCard) -> Array:
	return card._list.get_children().filter(func(c: Node) -> bool: return c is EntryCard and not c.is_queued_for_deletion())


func _shown(card: CameraCard) -> Array:
	return _entries(card).map(func(e: EntryCard) -> String: return e.name_label.text)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
