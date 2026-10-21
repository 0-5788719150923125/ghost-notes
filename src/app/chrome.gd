extends Shell
class_name Chrome

## Chrome - the shared session furniture every mode of ghost carries.
##
## The design lesson made explicit: modes were assembling their overlay stack
## BY HAND in per-branch code (an exporter here, an assistant there, the
## feedback console only in one path), so every new mode forgot a piece -
## synthesis shipped without ` feedback and without the export button, twice.
## Ghost's own rule - composition over hand-assembly - now applies to the app
## furniture too: main creates ONE Chrome, and any mode gets the standard set.
##
## WHAT A PANEL ASKS OF IT IS [Shell], which this extends: the row, the claims on the bottom
## edge, the way home, the note's "⋯". A panel below `app/` names Shell and never this file
## (docs/structure.md); what is here is the furniture itself, and the three answers that need it:
##
## - **row**         - the bottom-right row: ONE container holding every piece of
##                     furniture's button (see [method row_button]), the ⌂ that leaves a
##                     mode among them (see [method set_home]).
## - **environment** - the Environment panel (deps_panel.gd) behind the row's ⚙: what
##                     ghost runs on and what it is installing. Open until the user
##                     first closes it (`[deps] open`).
## - **exporter**    - the ⤓ render-to-video button + background pipeline
##                     (persistent: an in-flight export survives session churn).
## - **assistant**   - the feedback browser / dispatch backend, and the picker for
##                     which assistant runs (persistent: queued work survives sessions).
## - **feedback**    - the ` console, created on demand per session via
##                     [method attach_feedback] and wired to the assistant.
## - **console**     - the `>_` log viewer (a live tail of godot's own log
##                     file), for anyone running ghost without a terminal.
## - **transport**   - play/pause, stop, the time and the scrub rail along the
##                     bottom of the stage - one for every mode, shown exactly when
##                     something conducts the clock (see transport.gd). Space plays
##                     and pauses; the arrows and Home seek.
## - **provision**   - the notice at the top of the frame while ghost installs or
##                     updates its own dependencies (see provisioner.gd).

var exporter: Node
var assistant: Node
var feedback: Node
var console: Node
var transport: Node
var provision: Node
var environment: DepsPanel

var _env_layer: CanvasLayer
var _env_button: Button
var _env_dot: Label


## The Chrome in this tree, or null - for `app/`'s own, which reach the furniture through it.
## Anything else asks [method Shell.of].
static func of(n: Node) -> Chrome:
	return Shell.of(n) as Chrome


func _ready() -> void:
	super._ready()
	_build_environment()
	exporter = preload("res://src/export/exporter.gd").new()
	add_child(exporter)
	assistant = preload("res://src/app/assistant.gd").new()
	add_child(assistant)
	console = preload("res://src/app/console.gd").new()
	add_child(console)
	# THE TRANSPORT. Furniture rather than a mode's own control precisely because the lesson
	# at the top of this file is that anything a mode has to remember to add is a thing some
	# mode will forget - and playing, pausing and reviewing a long take are not specific to
	# any one of them. It shows exactly when something conducts (see Spectrum.timed).
	transport = preload("res://src/show/transport.gd").new()
	add_child(transport)
	# An install can start from any mode (the voice's environment, FFmpeg for a first
	# clip, an update at launch), so its progress is furniture too.
	provision = preload("res://src/app/provision_badge.gd").new()
	add_child(provision)


## The row has stepped up or down: the furniture that stands on it follows.
func _inset_changed() -> void:
	for n in [exporter, assistant, console]:
		if n != null and n.has_method("set_bottom_inset"):
			n.set_bottom_inset(bottom_inset)
	_place_environment()


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

## THE ENVIRONMENT PANEL, behind a button at the row's left end - it was the home screen's alone,
## and what ghost runs on is worth seeing from every mode. OPEN UNTIL THE USER FIRST CLOSES IT
## (`[deps] open`, default true, written by the button): a first launch shows it, the user learns
## where it lives by closing it, and from then on it starts closed. A PROBLEM THE PROBE FINDS
## OPENS IT without writing that - a missing dependency must be seen - and the panel's one-line
## state is the button's tooltip and its dot, so a problem shows while it is closed.
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


## Open or close the Environment panel. [param remember] writes `[deps] open` - the user's own
## click does, a problem the probe found does not.
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


# --- the feedback console -----------------------------------------------------------------------

## The ` feedback console for the current session. Idempotent: returns the
## live console if one is already attached. Wired to the assistant so a
## submitted critique dispatches (when a backend is enabled).
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


## Tear down the per-session console (the persistent pieces stay). Callers own
## the don't-yank-it-while-open courtesy (see main._end_session).
func detach_feedback() -> void:
	if feedback != null and is_instance_valid(feedback):
		feedback.queue_free()
	feedback = null
