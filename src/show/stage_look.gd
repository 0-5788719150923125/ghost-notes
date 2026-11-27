extends Node
class_name StageLook

## StageLook - the stage looked over while the show is paused: a left-drag on the picture turns the show's eye about what it looks at,
## the wheel draws it in or out, handed to whatever medium shows the note ([method Director.look_by]; one that can be looked over
## answers `look_by`, as [StudioMedium] does with its [FreeLook]). A click that does not drag is left to whoever picks on the stage.
## Once the show plays, the medium eases its eye back.

## How far a press must move before it is a drag (px), and how far a pixel of drag turns the eye (radians).
const DRAG_FROM := 4.0
const TURN := 0.005
## How much nearer or farther a notch of the wheel draws the eye.
const NOTCH := 0.9

var _from := Vector2.ZERO
var _pressed := false
var _dragging := false


func _unhandled_input(event: InputEvent) -> void:
	if not Director.paused() or not Director.can_look():
		_pressed = false
		_dragging = false
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_pressed = mb.pressed and Director.frame_rect.has_point(mb.position)
			_from = mb.position
			if not mb.pressed and _dragging:
				_dragging = false
				get_viewport().set_input_as_handled()
			return
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and Director.frame_rect.has_point(mb.position):
			Director.look_by(0.0, 0.0, NOTCH if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / NOTCH)
			get_viewport().set_input_as_handled()
		return
	var mm := event as InputEventMouseMotion
	if mm == null or not _pressed or (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return
	if not _dragging and mm.position.distance_to(_from) < DRAG_FROM:
		return
	_dragging = true
	Director.look_by(-mm.relative.x * TURN, -mm.relative.y * TURN)
	get_viewport().set_input_as_handled()
