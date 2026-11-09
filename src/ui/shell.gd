extends Node
class_name Shell

## Shell - what a panel asks of the window it is in.
##
## A panel does not build the window's furniture and must not reach for the thing that does:
## it asks for a place in the bottom-right row, for room along the bottom edge, for the way
## back to the notes, for what can be done to the note that is open. Those questions are this
## class, and nothing else is: it knows no exporter, no assistant and no console. [Chrome]
## (`app/`) is the shell with the furniture in it, and answers the three questions that need
## furniture ([method _inset_changed], [method _export_suppressed], [method ask_delete]).
##
## That split is what lets the reading, the storyboard's dock, the transport and Masking live
## BELOW the shell in `src/` (docs/structure.md): they name this, and `app/` names them.
##
## A panel built with no shell in the tree (a probe, a gate) finds none ([method of] is null)
## and carries on: every question here has "nobody to ask" as an answer.

## The group the one shell in a tree is found by ([method of]).
const GROUP := "ghost_chrome"

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
## leave). Masking's own ⤓ takes the export slot while it suppresses the shared one. Graphics beside the
## Environment: the two panels about the machine the picture is drawn on.
const ROW_ORDER := [&"home", &"environment", &"graphics", &"console", &"mask_export", &"export", &"assistant"]
## The layer the row draws on: above the home screen (200) and every panel that opens above it,
## so a button is never under something - the 💬 sat on 126, under the home screen, unseen.
const ROW_LAYER := 253

var row: HBoxContainer
var _row_layer: CanvasLayer
var _row_buttons := {}           # who -> Button

## THE WAY HOME (next/notes.md step 6): every mode can be left and entered again. Main hands the shell
## the two halves only it knows ([method set_home]): how to leave, and why the mode up now cannot
## be left this moment - an export making its take from the mode, which would be stranded. The ⌂ is
## grayed with that reason while it holds. Step 8's "‹ Notes" takes its job.
var _home_button: Button
var _home_leave := Callable()     # () -> String: "" once it has left, else why not
var _home_blocker := Callable()   # () -> String: why the mode cannot be left now, "" when it can
var _note_path := ""             # the note open now, "" on the list
var _note_delete := Callable()    # (path, answer) -> void: main's delete_note
var _note_open := Callable()      # (path) -> String: main's open_file
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
## THE SHOW'S ROOM. Something docked along the bottom that a person works in while WATCHING the
## show - the storyboard's editor - claims the height it covers, and main fits the frame into what
## is left above it ([signal stage_room_changed], [member stage_bottom]): the picture being edited
## is seen whole, not from behind the editor. Keyed, as every claim here is.
signal stage_room_changed
var stage_bottom := 0.0
var _stage_claims := {}

## THE STAGE ALONE WHILE IT PLAYS (2026-11-07, the user: "After a few seconds of realtime playback, can we auto-hide all of
## the UI elements, including the mouse cursor? This should ONLY apply if we have also hidden the F2 panel"). [constant
## IDLE_AFTER] s into a show playing with no hand on the mouse or the keys, the furniture fades out and the pointer is hidden;
## the first move, click or key brings both back. What fades is the group [constant FADES]: the row here, the corner a hidden
## panel leaves ([SidePanel]) and the transport ([Transport]). ITS ALPHA ONLY: nothing is hidden or moved, so a claim on the
## bottom edge holds and the row comes back where it was - and a button nobody sees takes no click, because the pointer cannot
## reach one without moving.
##
## NEVER WHILE SOMETHING IS UP TO BE USED ([method _stays_up]): a side panel (the user's condition), a panel above the row, a
## dock along the bottom ([member stage_bottom]), a dialog, popup or tooltip (an embedded window), a field being typed in, the
## pointer on the furniture or a hold on it ([method hold_up]: the transport's rail), or a show catching up (its line says so).
## THE INPUT IS THE WINDOW'S ([signal Window.window_input]), heard before any node can take it: the transport takes the arrows
## for itself, and an embedded popup the motion over it (Masking's pointer once vanished inside a color picker that way). The
## pointer is hidden and shown only on the way in and out, so Masking's own hiding of it is never fought.
const FADES := &"fades_while_watching"
## The group a side panel is found by ([constant SidePanel.GROUP] is this): named here, never read off SidePanel, whose
## preloaded Card names the Settings autoload - a gate with no autoloads that builds a panel naming this class failed with it.
const PANELS := &"side_panel"
const IDLE_AFTER := 3.0
const FADE_OUT := 0.6               # s from shown to gone
const FADE_IN := 0.15               # s back
const STILL := 3.0                  # px the pointer may drift and still be resting (a mouse's jitter)
var _idle_t := 0.0
var _faded := 1.0                   # the alpha the furniture is drawn at
var _hid_pointer := false           # this shell hid the pointer, and shows it again
var _rest_at := Vector2.INF         # where the pointer last moved to
var _holds := {}                    # who -> true while it keeps the furniture up


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


## Claim [param px] at the bottom of the frame as covered for [param who]: the show is fitted
## above it. Idempotent - call it again whenever the claiming surface changes size.
func claim_stage(who: StringName, px: float) -> void:
	_stage_claims[who] = maxf(px, 0.0)
	_apply_stage()


## Drop [param who]'s claim on the show's room. Safe to call when there is none.
func release_stage(who: StringName) -> void:
	if _stage_claims.erase(who):
		_apply_stage()


func _apply_stage() -> void:
	var want := 0.0
	for v in _stage_claims.values():
		want = maxf(want, float(v))
	if is_equal_approx(want, stage_bottom):
		return
	stage_bottom = want
	stage_room_changed.emit()

func _apply_inset() -> void:
	var want := 0.0
	for v in _bottom_claims.values():
		want = maxf(want, float(v))
	if is_equal_approx(want, bottom_inset):
		return
	bottom_inset = want
	_place_row()
	_inset_changed()


func _apply_suppression() -> void:
	_export_suppressed(not _export_claims.is_empty())


## THE ` FEEDBACK CONSOLE for the session that is up: made on the first ask, the same one on every
## ask after, and wired to the Assistant by the shell that has both ([Chrome]) - so a workspace
## hands it what to describe and never builds a console or an Assistant of its own. Null from a
## shell with no furniture.
func attach_feedback() -> Node:
	return null


## THE TRANSPORT IS THE SHELL'S FURNITURE: a workspace whose clock is its own (Masking's clip) hands
## it its verbs here - the hooks of [method Spectrum.conduct] - and takes them back when it leaves
## ([method release_transport]), naming no autoload. Nothing, from a shell with no transport.
func conduct_transport(_owner: Object, _hooks: Dictionary) -> void:
	pass


func release_transport(_owner: Object) -> void:
	pass


## How much of the frame's bottom edge the transport's rail takes while it shows (0: none).
func transport_room() -> float:
	return 0.0


## The room claimed at the bottom changed ([member bottom_inset]): the row has moved already.
## For the shell with furniture, which moves the rest of it.
func _inset_changed() -> void:
	pass


## Whether anything wants the shared ⤓ off screen has changed. For the shell with an exporter.
func _export_suppressed(_on: bool) -> void:
	pass


func _ready() -> void:
	# Findable by a mode without knowing where in the tree it was parented - it is
	# main's child today, and a mode looking for it walked two levels and missed it.
	add_to_group(GROUP)
	# THE ROW FIRST: each piece of furniture hands its button to it as it is built.
	_build_row()
	_build_home()
	get_window().window_input.connect(_on_window_input)


func _exit_tree() -> void:
	_show_pointer()


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
	row.add_to_group(FADES)
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


## The shell in this tree, or null - for furniture deciding whether it joins a row or places
## its own button (a Masking session launched with --mask-edit has none yet).
static func of(n: Node) -> Shell:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group(GROUP) as Shell


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
		var ch := Shell.of(owner)
		if ch != null:
			ch.go_home())
	return b


## THE NOTE OPEN NOW, and how to delete it ([param delete]: (path, "trash" or "forget") -> void) -
## what every panel's "⋯" acts on ([method note_menu]). "" and an invalid Callable on the list.
func set_note(path: String, delete := Callable(), open := Callable()) -> void:
	_note_path = path
	_note_delete = delete
	_note_open = open


## OPEN ANOTHER FILE AS THE NOTE, from inside a note (its Script card's Open…): "" once it is open,
## or why it could not be (the note cannot be left this moment, there is no such file).
func open_file(path: String) -> String:
	if not _note_open.is_valid():
		return "No note is open."
	return String(_note_open.call(path))


## "⋯" FOR A PANEL'S HEADER (2026-10-06): what can be done to the note itself - deleting it, asked
## first ([method ask_delete]). Grayed, with the reason, while the note cannot be left (an export making
## its take). A panel built without a Chrome (a probe) gets one that does nothing.
static func note_menu(owner: Node) -> MenuButton:
	var m := MenuButton.new()
	m.text = "⋯"
	m.flat = true
	m.focus_mode = Control.FOCUS_NONE
	m.tooltip_text = "This note"
	var pop := m.get_popup()
	pop.add_item("Delete this note…", 0)
	m.about_to_popup.connect(func() -> void:
		var ch := Shell.of(owner)
		var why := ch.delete_blocker() if ch != null else "No note is open."
		pop.set_item_disabled(0, not why.is_empty())
		pop.set_item_tooltip(0, why))
	pop.id_pressed.connect(func(id: int) -> void:
		var ch := Shell.of(owner)
		if ch != null and id == 0:
			ch.ask_delete())
	return m


## Why the note open now cannot be deleted this moment, "" when it can.
func delete_blocker() -> String:
	if _note_path.is_empty() or not _note_delete.is_valid():
		return "No note is open."
	return String(_home_blocker.call()) if _home_blocker.is_valid() else ""


## Ask, then delete the note open now - left first, then thrown away. The asking is a dialog,
## which is furniture: the shell that has one answers ([Chrome]).
func ask_delete() -> void:
	pass



func _paint_home() -> void:
	var why := String(_home_blocker.call()) if _home_blocker.is_valid() else ""
	_home_button.disabled = not why.is_empty()
	_home_button.tooltip_text = why if not why.is_empty() \
		else "Back to the notes. This note's settings and its file are kept as they are."


func _process(delta: float) -> void:
	_watch(delta)
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


# --- the stage alone while it plays -------------------------------------------------------------

## Keep the furniture up while [param on] holds for [param who] (keyed, as every claim here is): something the pointer is
## using that is no control the shell can find under it - the transport's rail.
func hold_up(who: StringName, on: bool) -> void:
	if on:
		_holds[who] = true
	else:
		_holds.erase(who)


## How much the furniture shows: 1 up, 0 faded out while the show plays alone.
func furniture_alpha() -> float:
	return _faded


## A move, a click, a key or a touch: the furniture and the pointer come back. A pointer that drifts by less than
## [constant STILL] is resting.
func _on_window_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		var p: Vector2 = event.position
		if _rest_at != Vector2.INF and p.distance_to(_rest_at) <= STILL:
			return
		_rest_at = p
	elif not event.is_pressed():
		return
	elif not (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch
			or event is InputEventJoypadButton):
		return
	_idle_t = 0.0
	_show_pointer()


## One frame of watching: the time with nothing to do counts while nothing keeps the furniture up, and the furniture
## eases toward what that says. Taken in steps of at most 0.25 s, so a hitch (a table's first frame) is not a wait.
func _watch(delta: float) -> void:
	if _stays_up():
		_idle_t = 0.0
	else:
		_idle_t += minf(delta, 0.25)
	var alone := _idle_t >= IDLE_AFTER
	if alone and not _hid_pointer and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_hid_pointer = true
	elif not alone:
		_show_pointer()
	var want := 0.0 if alone else 1.0
	var was := _faded
	_faded = move_toward(_faded, want, delta / (FADE_OUT if want < _faded else FADE_IN))
	# every frame while it is down, so furniture that joins then fades too; nothing at all while it is up
	if _faded == 1.0 and was == 1.0:
		return
	for n in get_tree().get_nodes_in_group(FADES):
		var c := n as CanvasItem
		if c != null:
			c.modulate.a = _faded


## Whatever keeps the furniture up: everything but a show playing on its own with nobody at the controls.
## The transport is found in the tree, never named: a gate that runs with no autoloads (mask_tracks_check) builds
## a panel that names this class, and a `Spectrum` here failed to compile and took the whole class with it.
func _stays_up() -> bool:
	var transport := get_node_or_null(^"/root/Spectrum")
	if transport == null or not transport.transport_playing() or transport.waiting():
		return true
	if panel_open() or stage_bottom > 0.0 or not _holds.is_empty():
		return true
	for n in get_tree().get_nodes_in_group(PANELS):
		var c := n as CanvasItem
		if c != null and c.is_visible_in_tree():
			return true
	var vp := get_viewport()
	for w in vp.get_embedded_subwindows():
		if w.visible:
			return true
	var f := vp.gui_get_focus_owner()
	if (f is TextEdit or f is LineEdit) and f.is_visible_in_tree():
		return true
	var h := vp.gui_get_hovered_control()
	if h != null:
		for n in get_tree().get_nodes_in_group(FADES):
			if n == h or (n as Node).is_ancestor_of(h):
				return true
	return false


func _show_pointer() -> void:
	if not _hid_pointer:
		return
	_hid_pointer = false
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
