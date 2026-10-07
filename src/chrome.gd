extends Node
class_name Chrome

## Chrome - the shared session furniture every mode of ghost carries.
##
## The design lesson made explicit: modes were assembling their overlay stack
## BY HAND in per-branch code (an exporter here, an assistant there, the
## feedback console only in one path), so every new mode forgot a piece -
## synthesis shipped without ` feedback and without the export button, twice.
## Ghost's own rule - composition over hand-assembly - now applies to the app
## furniture too: main creates ONE Chrome, and any mode gets the standard set:
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

## How much of the bottom-right corner the row fills: 40 px buttons on a 28 px margin. A
## panel that opens above the row stands at ROW_TOP plus a small gap.
const ROW_TOP := 68.0
const ROW_MARGIN := 28.0
const ROW_GAP := 4.0
## THE BOTTOM-RIGHT ROW, left to right (next/notes.md, "The Environment button"). Each piece of
## furniture used to pin its own 40-pixel button at a fixed offset, so a hidden ⤓ left a hole and
## a new piece meant new offsets everywhere; now it hands its button to the row, which keeps
## this order, closes up around a hidden one, and is lifted as one by [method claim_bottom].
## The Environment button is at the LEFT end so the three that were there keep their places, and
## the ⌂ left of it for the same reason (hidden on the home screen, where there is nothing to
## leave). Masking's own ⤓ takes the export slot while it suppresses the shared one.
const ROW_ORDER := [&"home", &"environment", &"console", &"mask_export", &"export", &"assistant"]
## The layer the row draws on: above the home screen (200) and every panel that opens above it,
## so a button is never under something - the 💬 sat on 126, under the home screen, unseen.
const ROW_LAYER := 253

var row: HBoxContainer
var _row_layer: CanvasLayer
var _row_buttons := {}           # who -> Button
var _env_layer: CanvasLayer
var _env_button: Button
var _env_dot: Label

## THE WAY HOME (next/notes.md step 6): every mode can be left and entered again. Main hands Chrome
## the two halves only it knows ([method set_home]): how to leave, and why the mode up now cannot
## be left this moment - an export making its take from the mode, which would be stranded. The ⌂ is
## grayed with that reason while it holds. Step 8's "‹ Notes" takes its job.
var _home_button: Button
var _home_leave := Callable()     # () -> String: "" once it has left, else why not
var _home_blocker := Callable()   # () -> String: why the mode cannot be left now, "" when it can
var _home_t := 0.0

## THE PANELS ABOVE THE ROW, one open at a time: the console's log, the Assistant's panel and the
## Environment panel all open into the same space, and nothing stopped them overlapping. Each
## registers how to close itself ([method register_panel]) and says when it opens
## ([method panel_opened]); opening one closes the others. The export's status line is not a
## panel - it is progress - so it steps aside while any panel is open ([method panel_open]).
var _panel_closers := {}         # who -> Callable
var _panels_open := {}           # who -> true while open

## HOW MUCH ROOM SOMETHING HAS CLAIMED at the bottom of the frame, in pixels -
## the largest live claim (see [method claim_bottom]). READ-ONLY: write through the
## claim API, never here.
##
## Every piece of furniture here anchors bottom-right, which is empty in most modes -
## but the Masking editor puts its marker strip and its trim/track lanes down there, so
## the row sat ON them. A surface claims its room once and the whole row steps up
## together. Claim only for something that has to be AT the bottom edge: a row that moves
## from screen to screen is harder to find, which is why the home screen does not claim.
var bottom_inset := 0.0

## THE CLAIMS ARE KEYED, and that is not tidiness - a single scalar (or a single
## `suppressed` bool) is unsafe here because of the order the notes list dismisses itself in.
## [method NotesList._open] calls into main FIRST and only then `queue_free`s, so the
## outgoing list's `_exit_tree` runs AFTER the incoming note's `_ready`. A surface that
## released by writing 0 (or `false`) would therefore undo the claim the mode had just
## made - handing the shared export button straight back on top of Masking's own one,
## which is the exact bug Exporter.suppressed exists to prevent.
##
## With a key, a release can only ever remove its own claim, so no ordering of arrivals
## and departures can produce a wrong answer.
var _bottom_claims := {}
var _export_claims := {}


## Claim [param px] of room at the bottom of the frame for [param who]. Idempotent -
## call it again with a new figure whenever the claiming surface changes size.
func claim_bottom(who: StringName, px: float) -> void:
	_bottom_claims[who] = maxf(px, 0.0)
	_apply_inset()


## Drop [param who]'s claim on the bottom of the frame. Safe to call when there is none.
func release_bottom(who: StringName) -> void:
	if _bottom_claims.erase(who):
		_apply_inset()


## Take the shared ⤓ export button off screen while [param who] is up - because that
## surface has its own export (Masking), or because it is not a session at all and there
## is nothing to render (the notes list). See [member Exporter.suppressed].
func suppress_export(who: StringName) -> void:
	_export_claims[who] = true
	_apply_suppression()


## Drop [param who]'s hold on the export button. It comes back only when nothing else
## still wants it hidden.
func release_export(who: StringName) -> void:
	if _export_claims.erase(who):
		_apply_suppression()


func _apply_inset() -> void:
	var want := 0.0
	for v in _bottom_claims.values():
		want = maxf(want, float(v))
	if is_equal_approx(want, bottom_inset):
		return
	bottom_inset = want
	_place_row()
	for n in [exporter, assistant, console]:
		if n != null and n.has_method("set_bottom_inset"):
			n.set_bottom_inset(bottom_inset)
	_place_environment()


func _apply_suppression() -> void:
	if exporter != null and is_instance_valid(exporter):
		exporter.suppressed = not _export_claims.is_empty()


func _ready() -> void:
	# Findable by a mode without knowing where in the tree it was parented - it is
	# main's child today, and a mode looking for it walked two levels and missed it.
	add_to_group("ghost_chrome")
	# THE ROW FIRST: each piece of furniture below hands its button to it as it is built.
	_build_row()
	_build_home()
	_build_environment()
	exporter = preload("res://src/exporter.gd").new()
	add_child(exporter)
	assistant = preload("res://src/assistant.gd").new()
	add_child(assistant)
	console = preload("res://src/console.gd").new()
	add_child(console)
	# THE TRANSPORT. Furniture rather than a mode's own control precisely because the lesson
	# at the top of this file is that anything a mode has to remember to add is a thing some
	# mode will forget - and playing, pausing and reviewing a long take are not specific to
	# any one of them. It shows exactly when something conducts (see Spectrum.timed).
	transport = preload("res://src/transport.gd").new()
	add_child(transport)
	# An install can start from any mode (the voice's environment, FFmpeg for a first
	# clip, an update at launch), so its progress is furniture too.
	provision = preload("res://src/provision_badge.gd").new()
	add_child(provision)


# --- the row ----------------------------------------------------------------------------------

func _build_row() -> void:
	_row_layer = CanvasLayer.new()
	_row_layer.layer = ROW_LAYER
	add_child(_row_layer)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(ROW_GAP))
	# Anchored to the corner and grown UP-LEFT from it, so the row's width is free to change - a
	# button hidden, a badge on the 💬 - without the right end ever moving.
	row.anchor_left = 1.0
	row.anchor_top = 1.0
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row_layer.add_child(row)
	_place_row()


func _place_row() -> void:
	if row == null:
		return
	row.offset_right = -ROW_MARGIN
	row.offset_bottom = -ROW_MARGIN - bottom_inset
	row.offset_left = -ROW_MARGIN
	row.offset_top = -ROW_MARGIN - bottom_inset


## Put [param b] in the row as [param who]'s button, at [param who]'s place in [constant ROW_ORDER].
## The row owns its position from then on; the furniture keeps the button and shows, hides and
## relabels it as before.
func row_button(who: StringName, b: Button) -> void:
	if b.get_parent() != null:
		b.get_parent().remove_child(b)
	_row_buttons[who] = b
	b.set_anchors_preset(Control.PRESET_TOP_LEFT)
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(b)
	var at := 0
	for k in ROW_ORDER:
		if k == who:
			break
		if _row_buttons.has(k) and is_instance_valid(_row_buttons[k]):
			at += 1
	row.move_child(b, mini(at, row.get_child_count() - 1))


## The Chrome in this tree, or null - for furniture deciding whether it joins a row or places
## its own button (a Masking session launched with --mask-edit has no Chrome yet).
static func of(n: Node) -> Chrome:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group("ghost_chrome") as Chrome


# --- the way home ------------------------------------------------------------------------------

func _build_home() -> void:
	_home_button = Button.new()
	_home_button.text = "⌂"
	_home_button.focus_mode = Control.FOCUS_NONE
	_home_button.custom_minimum_size = Vector2(40, 40)
	_home_button.visible = false
	_home_button.pressed.connect(_go_home)
	row_button(&"home", _home_button)


## A mode is up: the ⌂ shows, and pressing it calls [param leave] (which returns "" once it has
## left, or why it could not). [param blocker] says why the mode cannot be left right now, "" when
## it can. An invalid [param leave] hides the ⌂ - the home screen has nothing to leave.
func set_home(leave: Callable, blocker := Callable()) -> void:
	_home_leave = leave
	_home_blocker = blocker
	_home_button.visible = leave.is_valid()
	_paint_home()


## Back to the notes - the ⌂, and every panel's "‹ Notes" ([method back_button]).
func go_home() -> void:
	if not _home_leave.is_valid():
		return
	var why := String(_home_leave.call())
	if not why.is_empty():
		_home_button.tooltip_text = why


func _go_home() -> void:
	go_home()


## "‹ NOTES" FOR A PANEL'S HEADER (next/notes.md step 8: "Opening a note turns the panel into that
## note's cards, with '‹ Notes' at the top to go back"): the same way out as the row's ⌂, at the top
## of the panel where a person looks for it. A panel built without a Chrome (a probe) gets one that
## does nothing.
static func back_button(owner: Node) -> Button:
	var b := Button.new()
	b.text = "‹ Notes"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Back to the notes. This note's settings and its file are kept as they are."
	b.pressed.connect(func() -> void:
		var ch := Chrome.of(owner)
		if ch != null:
			ch.go_home())
	return b


func _paint_home() -> void:
	var why := String(_home_blocker.call()) if _home_blocker.is_valid() else ""
	_home_button.disabled = not why.is_empty()
	_home_button.tooltip_text = why if not why.is_empty() \
		else "Back to the notes. This note's settings and its file are kept as they are."


func _process(delta: float) -> void:
	# the reason a mode cannot be left comes and goes with an export; four times a second is plenty
	if _home_button == null or not _home_button.visible:
		return
	_home_t -= delta
	if _home_t <= 0.0:
		_home_t = 0.25
		_paint_home()


# --- the panels above the row -----------------------------------------------------------------

## [param close] hides [param who]'s panel. Called once, as the panel is built.
func register_panel(who: StringName, close: Callable) -> void:
	_panel_closers[who] = close


## [param who]'s panel has opened: every other one closes. Something that is not a panel above
## the row but would sit over one - the ` feedback console - says so too, and is not counted open.
func panel_opened(who: StringName) -> void:
	if _panel_closers.has(who):
		_panels_open[who] = true
	for k in _panel_closers.keys():
		if k != who and _panels_open.get(k, false):
			_panels_open[k] = false
			(_panel_closers[k] as Callable).call()


## [param who]'s panel has closed (by its own button, or by another opening).
func panel_closed(who: StringName) -> void:
	_panels_open[who] = false


## Is any panel open above the row? The export's progress line steps aside while one is.
func panel_open() -> bool:
	for k in _panels_open:
		if _panels_open[k]:
			return true
	return false


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
	environment = preload("res://src/deps_panel.gd").new()
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
	feedback = preload("res://src/feedback.gd").new()
	add_child(feedback)
	if assistant != null and is_instance_valid(assistant):
		feedback.submitted.connect(assistant.enqueue)
	return feedback


## Tear down the per-session console (the persistent pieces stay). Callers own
## the don't-yank-it-while-open courtesy (see main._end_session).
func detach_feedback() -> void:
	if feedback != null and is_instance_valid(feedback):
		feedback.queue_free()
	feedback = null
