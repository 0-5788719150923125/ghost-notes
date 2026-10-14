extends Control
class_name SaveMark

## SaveMark - the small mark beside a script's file name that says where its words stand with
## the file: turning while a change made here waits for its quiet period, a tick that flashes the
## moment the change is in the file, an amber mark when a write was refused, a hollow ring when
## the script is saved nowhere.
##
## IT IS THE AUTOSAVE, SHOWN (2026-10-12, the user: "giving it a little autosave animation... if
## any actions are taken from in-app, the little autosave animation runs, and we can be sure that
## our save feature is syncing/bound to the underlying file correctly"). Saving had no sign at
## all: a dial moved was a dial written a second later, and nothing on screen said so - or said
## which file took it, which is how a script could be saved into a file nothing read. So the mark
## reads the [DocSource] it is given and nothing else: the turning is [method
## DocSource.save_state] saying "pending", the flash is [signal DocSource.written], raised only
## after a verified write, and the tooltip is the file's whole path and when it was last written.
## A mark that ticked without a write would be worse than no mark.

## The mark's box, in pixels.
const SIZE := 16.0
## How long a write's flash takes to settle back to the quiet tick, in seconds.
const FLASH_S := 1.6
## Turns per second while a change waits.
const TURNS := 0.9

const QUIET := Color(1, 1, 1, 0.45)
const SAVED := Color(0.45, 0.95, 0.65)
const WAITING := Color(0.98, 0.86, 0.45)
const FAILED := Color(1.0, 0.62, 0.3)

var _doc: DocSource
var _state := ""
var _flash := 0.0
var _turn := 0.0
## Writes seen since the mark was built: what a gate counts.
var writes := 0


func _init(doc: DocSource) -> void:
	_doc = doc
	custom_minimum_size = Vector2(SIZE, SIZE)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP      # a tooltip needs the pointer
	_doc.written.connect(_on_written)
	_doc.mode_changed.connect(func(_sync: bool) -> void: _read())
	_doc.opened.connect(func(_path: String) -> void: _read())


func _ready() -> void:
	_read()


func _on_written() -> void:
	writes += 1
	_flash = FLASH_S
	_read()
	tooltip_text = _doc.save_tip()
	queue_redraw()


## The state the mark shows now ([method DocSource.save_state]).
func state() -> String:
	return _state


## True while a write's flash is still settling.
func flashing() -> bool:
	return _flash > 0.0


func _read() -> void:
	var s := _doc.save_state()
	if s == _state:
		return
	_state = s
	tooltip_text = _doc.save_tip()
	queue_redraw()


func _process(delta: float) -> void:
	_read()
	if _state == "pending":
		_turn = fposmod(_turn + delta * TAU * TURNS, TAU)
		queue_redraw()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := SIZE * 0.5 - 2.0
	match _state:
		"none":
			draw_arc(c, r, 0.0, TAU, 24, Color(1, 1, 1, 0.28), 1.2, true)
		"pending":
			draw_arc(c, r, 0.0, TAU, 24, Color(WAITING, 0.22), 1.6, true)
			draw_arc(c, r, _turn, _turn + TAU * 0.3, 12, WAITING, 1.8, true)
		"failed":
			draw_arc(c, r, 0.0, TAU, 24, FAILED, 1.4, true)
			draw_line(c + Vector2(0, -r * 0.55), c + Vector2(0, r * 0.15), FAILED, 1.8, true)
			draw_circle(c + Vector2(0, r * 0.5), 1.0, FAILED)
		_:
			var f := _flash / FLASH_S
			# the write, seen: a ring opening out from the tick and fading as it goes
			if f > 0.0:
				draw_arc(c, r * (1.0 + (1.0 - f) * 0.45), 0.0, TAU, 24, Color(SAVED, f * 0.8), 1.4, true)
			var ink := QUIET.lerp(SAVED, ease(f, 0.5))
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.6, 0.0),
				c + Vector2(-r * 0.15, r * 0.5), c + Vector2(r * 0.65, -r * 0.5)]), ink, 1.8, true)
