extends Shell
class_name Chrome

## Chrome - the shared session furniture every mode of ghost carries. Main creates one Chrome and any mode
## gets the standard set, so no mode assembles its overlay stack by hand and forgets a piece.
##
## What a panel asks of it is [Shell], which this extends: the row, the claims on the bottom edge, the way
## home, the note's "⋯". A panel below `app/` names Shell and never this file (docs/structure.md); what is
## here is the furniture itself and the answers that need it:
##
## - **row**         - the bottom-right row: one container holding every piece of furniture's button
##                     ([method row_button]), the ⌂ that leaves a mode among them ([method set_home]).
## - **environment** - the Environment panel (deps_panel.gd) behind the row's ⚙: what ghost runs on and
##                     what it is installing. Open until the user first closes it (`[deps] open`).
## - **graphics**    - the Graphics panel ([GraphicsPanel]) behind the row's picture: how finely the stage
##                     is drawn, live and in an export ([Graphics]).
## - **exporter**    - the ⤓ render-to-video button and background pipeline (persistent: an in-flight
##                     export survives session churn).
## - **assistant**   - the feedback browser / dispatch backend and its picker (persistent: queued work
##                     survives sessions).
## - **feedback**    - the ` console, created per session via [method attach_feedback], wired to the
##                     assistant.
## - **console**     - the `>_` log viewer (a live tail of godot's own log file).
## - **transport**   - play/pause, stop, the time and the scrub rail along the bottom of the stage, shown
##                     exactly when something conducts the clock (transport.gd). Space plays and pauses;
##                     the arrows and Home seek.
## - **provision**   - the notice at the top of the frame while ghost installs or updates its own
##                     dependencies (provisioner.gd).

var exporter: Node
var assistant: Node
var feedback: Node
var console: Node
var transport: Node
var provision: Node
var environment: DepsPanel
var graphics: GraphicsPanel

var _env_layer: CanvasLayer
var _env_button: Button
var _env_dot: Label
var _gfx_layer: CanvasLayer


## The Chrome in this tree, or null - for `app/`'s own, which reach the furniture through it. Anything
## else asks [method Shell.of].
static func of(n: Node) -> Chrome:
	return Shell.of(n) as Chrome


func _ready() -> void:
	super._ready()
	_build_environment()
	_build_graphics()
	exporter = preload("res://src/export/exporter.gd").new()
	add_child(exporter)
	assistant = preload("res://src/app/assistant.gd").new()
	add_child(assistant)
	console = preload("res://src/app/console.gd").new()
	add_child(console)
	#The transport is furniture, not a mode's own control: playing, pausing and reviewing a take are not
	#specific to any mode. It shows exactly when something conducts (see Spectrum.timed).
	transport = preload("res://src/show/transport.gd").new()
	add_child(transport)
	#An install can start from any mode, so its progress is furniture too.
	provision = preload("res://src/app/provision_badge.gd").new()
	add_child(provision)


## The row has stepped up or down: the furniture that stands on it follows.
func _inset_changed() -> void:
	for n in [exporter, assistant, console]:
		if n != null and n.has_method("set_bottom_inset"):
			n.set_bottom_inset(bottom_inset)
	_place_environment()
	_place_graphics()


func _export_suppressed(on: bool) -> void:
	if exporter != null and is_instance_valid(exporter):
		exporter.suppressed = on


## Ask, then delete the note open now - left first, then thrown away (see [DeleteDialog]).
func ask_delete() -> void:
	if not delete_blocker().is_empty():
		return
	var path := _note_path
	var del := _note_delete
	DeleteDialog.ask(self, path, func(answer: String) -> void: del.call(path, answer))


# --- the Environment ----------------------------------------------------------------------------

## The Environment panel, behind a button at the row's left end. Open until the user first closes it
## (`[deps] open`, default true, written by the button). A problem the probe finds opens it without
## writing that, and the panel's one-line state is the button's tooltip and dot, so a problem shows while
## it is closed.
func _build_environment() -> void:
	_env_layer = CanvasLayer.new()
	_env_layer.layer = ROW_LAYER - 1
	add_child(_env_layer)
	environment = preload("res://src/app/deps_panel.gd").new()
	environment.visible = false
	_env_layer.add_child(environment)
	_place_environment()
	_env_button = Button.new()
	_env_button.text = "⚙"
	_env_button.focus_mode = Control.FOCUS_NONE
	_env_button.custom_minimum_size = Vector2(40, 40)
	_env_button.tooltip_text = "Environment"
	_env_button.pressed.connect(func() -> void: set_environment_open(not environment.visible, true))
	# the dot: green when everything is there, blue while installing, red for a problem
	_env_dot = Label.new()
	_env_dot.text = "●"
	_env_dot.add_theme_font_size_override("font_size", 10)
	_env_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_env_dot.position = Vector2(27, 1)
	_env_button.add_child(_env_dot)
	row_button(&"environment", _env_button)
	register_panel(&"environment", func() -> void: _show_environment(false))
	environment.state_changed.connect(_paint_environment_button)
	environment.problem_found.connect(func() -> void: set_environment_open(true, false))
	_paint_environment_button()
	set_environment_open(bool(Settings.read("deps", "open", true)), false)


## Open or close the Environment panel. [param remember] writes `[deps] open` (the user's own click does,
## a problem the probe found does not).
func set_environment_open(on: bool, remember: bool) -> void:
	_show_environment(on)
	if on:
		panel_opened(&"environment")
	if remember:
		Settings.write("deps", "open", on)


func _show_environment(on: bool) -> void:
	environment.visible = on
	if not on:
		panel_closed(&"environment")


func _place_environment() -> void:
	if environment != null:
		environment.offset_top = -ROW_TOP - 8.0 - bottom_inset
		environment.offset_bottom = -ROW_TOP - 8.0 - bottom_inset


func _paint_environment_button() -> void:
	if _env_button == null:
		return
	var line := environment.state_line()
	_env_button.tooltip_text = line + "\n\nClick to %s the Environment panel." % ("close" if environment.visible else "open")
	_env_dot.add_theme_color_override("font_color", environment.state_color())


# --- the graphics -------------------------------------------------------------------------------

## The Graphics panel, behind the picture beside the ⚙: closed until opened, every time.
func _build_graphics() -> void:
	_gfx_layer = CanvasLayer.new()
	_gfx_layer.layer = ROW_LAYER - 1
	add_child(_gfx_layer)
	graphics = GraphicsPanel.new()
	graphics.visible = false
	_gfx_layer.add_child(graphics)
	_place_graphics()
	var b := Button.new()
	b.icon = Icons.texture("graphics", 20)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(40, 40)
	b.tooltip_text = "Graphics: how finely the picture is drawn, live and in an export."
	b.pressed.connect(func() -> void: set_graphics_open(not graphics.visible))
	row_button(&"graphics", b)
	register_panel(&"graphics", func() -> void: _show_graphics(false))


## Open or close the Graphics panel.
func set_graphics_open(on: bool) -> void:
	_show_graphics(on)
	if on:
		panel_opened(&"graphics")


func _show_graphics(on: bool) -> void:
	graphics.visible = on
	if not on:
		panel_closed(&"graphics")


func _place_graphics() -> void:
	if graphics != null:
		graphics.offset_top = -ROW_TOP - 8.0 - bottom_inset
		graphics.offset_bottom = -ROW_TOP - 8.0 - bottom_inset


# --- the feedback console -----------------------------------------------------------------------

## The ` feedback console for the current session. Idempotent: returns the live console if one is attached.
## Wired to the assistant so a submitted critique dispatches (when a backend is enabled).
func attach_feedback() -> Node:
	if feedback != null and is_instance_valid(feedback):
		return feedback
	feedback = preload("res://src/app/feedback.gd").new()
	add_child(feedback)
	if assistant != null and is_instance_valid(assistant):
		feedback.submitted.connect(assistant.enqueue)
	return feedback


# --- the transport ------------------------------------------------------------------------------

## A workspace on a clock of its own conducts the transport through its shell ([Shell]).
func conduct_transport(owner: Object, hooks: Dictionary) -> void:
	Spectrum.conduct(owner, hooks)


func release_transport(owner: Object) -> void:
	Spectrum.release_conductor(owner)


func transport_room() -> float:
	return Transport.room()


## Tear down the per-session console (the persistent pieces stay). Callers own the don't-yank-it-while-open
## courtesy (see main._end_session).
func detach_feedback() -> void:
	if feedback != null and is_instance_valid(feedback):
		feedback.queue_free()
	feedback = null
