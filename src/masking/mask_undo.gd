extends RefCounted
class_name MaskUndo

## MaskUndo - Masking's undo and redo: snapshots of the markers, the primary clip's trim and every track, pushed before
## each change, a gesture (a slider drag, a handle dragged along the timeline) coalesced into one step, and the history
## line that says what Ctrl+Z will undo.
##
## A part of the editor, cut along its banners (next/structure.md): it holds the two stacks and reads and rebuilds the
## editor's session, lanes and panel through `editor`.

## The [MaskEditor] this is a part of: everything read through it is something this part is handed.
var editor: MaskEditor

var _undo_stack: Array = []
var _redo_stack: Array = []
var _undo_descs: Array = []
var _redo_descs: Array = []
const _UNDO_LIMIT := 200

# --- undo/redo --------------------------------------------------------------------------------

## Snapshot markers, the primary clip's trim and every track.
func _snapshot() -> Dictionary:
	return {
		"markers": editor.session.markers.duplicate(true),
		"clip_in": editor.session.clip_in, "clip_out": editor.session.clip_out,
		"tracks": editor.session.tracks.duplicate(true),
	}


func _restore_snapshot(snap: Dictionary) -> void:
	editor.session.markers = snap.markers
	editor.session.clip_in = snap.clip_in
	editor.session.clip_out = snap.clip_out
	editor.session.tracks = snap.tracks


## Push a snapshot onto the undo stack; call it before a mutation. `desc` is what Ctrl+Z would revert, shown above
## the Ramp/Damp buttons (see refresh_label). `key` names an edit that repeats within one gesture (see below); leave it
## empty for one-shot actions, which always open a new step.
func push(key: String = "", desc: String = "") -> void:
	# While the left button is down, the first change of a key opens the step and later ones fold into it, however long
	# the pauses; it closes on release (cleared in _process). The marker still updates every step, only the history
	# waits. Keyed on the button, not Slider.drag_started, so the color wheel and region box follow the same rule.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if key != "" and key == editor._undo_press_key:
			return
		editor._undo_press_key = key
	else:
		editor._undo_press_key = ""
	# No time-based coalescing: a press is an action, a release ends it, and anything else (a keyboard nudge, a menu
	# pick) is its own step.
	_undo_stack.append(_snapshot())
	_undo_descs.append(desc)
	if _undo_stack.size() > _UNDO_LIMIT:
		_undo_stack.pop_front()
		_undo_descs.pop_front()
	_redo_stack.clear()
	_redo_descs.clear()
	refresh_label()


func undo() -> void:
	if _undo_stack.is_empty():
		return
	_redo_stack.append(_snapshot())
	_restore_snapshot(_undo_stack.pop_back())
	_redo_descs.append(_undo_descs.pop_back())
	editor._undo_press_key = ""   # the next edit must open its own fresh boundary
	_after_history_restore()


func redo() -> void:
	if _redo_stack.is_empty():
		return
	_undo_stack.append(_snapshot())
	_restore_snapshot(_redo_stack.pop_back())
	_undo_descs.append(_redo_descs.pop_back())
	editor._undo_press_key = ""
	_after_history_restore()


## The live preview above the Ramp/Damp buttons: the description of the push() that opened the current undo step,
## i.e. the action Ctrl+Z would revert.
func refresh_label() -> void:
	if editor._history_label == null:
		return
	if _undo_descs.is_empty():
		editor._history_label.text = "Undo: nothing yet"
		editor._history_label.tooltip_text = ""
	else:
		var desc: String = _undo_descs.back()
		editor._history_label.text = "Undo: " + desc
		editor._history_label.tooltip_text = "Ctrl+Z would revert: " + desc


## `_selected` points into the array a restore replaced wholesale: re-resolve it by time in the restored array (or
## drop it), then reconcile the runtime track players (see MaskTracks.runtime) as MaskTracks._delete_track and
## MaskTracks.finish_import do.
func _after_history_restore() -> void:
	if editor._selected != null:
		var t: float = float(editor._selected.get("time", -1.0))
		editor._selected = null
		for m in editor.session.markers:
			if absf(float(m.time) - t) < 0.0005:
				editor._selected = m
				break
	editor._select_generation += 1
	editor._timeline.selected = editor._selected
	reconcile_tracks()
	editor._tracks.refresh_lanes()
	editor._refresh_marker_list()
	editor._refresh_panel()
	refresh_label()
	editor._mark_dirty()


## After undo/redo swaps session.tracks wholesale, the live players in MaskTracks.runtime (built by
## MaskTracks.build_view) may not match it: free any past the restored count, build any missing. Existing entries are
## kept as they are - MaskTracks.sync reseeks on the next frame.
func reconcile_tracks() -> void:
	if editor._composition_parent == null:
		return   # render_mode / no editor UI - tracks aren't interactive there anyway
	while editor._tracks.runtime.size() > editor.session.tracks.size():
		var rt: Dictionary = editor._tracks.runtime.pop_back()
		if rt.has("player"):
			(rt.player as Node).queue_free()
		if rt.has("wrap"):
			(rt.wrap as Node).queue_free()
		if rt.has("audio") and rt.audio != null:
			(rt.audio as Node).queue_free()
	for i in editor.session.tracks.size():
		if i >= editor._tracks.runtime.size():
			editor._tracks.build_view(i)
