extends RefCounted
class_name MaskUndo

## MaskUndo - Masking's undo and redo: snapshots of the markers, the primary clip's trim and every
## track, pushed BEFORE each change, a gesture (a slider drag, a handle dragged along the timeline)
## coalesced into one step, and the history line that says what Ctrl+Z will undo.
##
## A PART OF THE EDITOR, cut along its banners (next/structure.md, step 15): it holds the two stacks
## and reads and rebuilds the editor's session, lanes and panel through `editor`.

## The [MaskEditor] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var editor: MaskEditor

var _undo_stack: Array = []
var _redo_stack: Array = []
var _undo_descs: Array = []
var _redo_descs: Array = []
const _UNDO_LIMIT := 200

# --- undo/redo --------------------------------------------------------------------------------

## Snapshot markers + the primary clip's trim + every track onto the undo
## stack, called BEFORE a mutation - so the stack always holds "what it looked
## like before this happened". Pass a `key` for edits that repeat rapidly
## during one gesture (a slider drag, a marker or trim/track handle dragged
## along the timeline): a call whose key matches the in-flight gesture just
## extends the coalescing window instead of pushing again, so the whole
## gesture undoes in one Ctrl+Z. Leave `key` empty for one-shot actions
## (add/delete a marker, import/delete a track) - those always open a fresh
## boundary. Trim/track edits are exactly as accident-prone as marker edits -
## see the whole reason this project asked for undo in the first place - so
## they ride the same stack, not a separate one.
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


## `desc` is what a Ctrl+Z right after this action would revert - shown live
## above the Ramp/Damp buttons (see refresh_label) so undo is never a
## blind guess. Coalesced calls (matching `key`) keep the first desc: the whole
## gesture is one undo step, so it should read as the one action it is (e.g.
## "adjusted Contrast", not the field's very last no-op tick).
func push(key: String = "", desc: String = "") -> void:
	# A DRAG IS ONE ACTION IN THE HISTORY. Dragging a control back and forth to see
	# how it looks emits a change per step, and the coalescing below is on a 0.9s
	# TIMER - so every place the author paused mid-drag opened a fresh undo entry,
	# and one adjustment left a dozen of them behind. Reported exactly that way:
	# "every single place where I stop will be added to the command history".
	#
	# So while the mouse button is DOWN, the first change of a given key opens the
	# boundary and every later one folds into it, however long the pauses; the
	# boundary closes when the button comes up (cleared in _process). The marker
	# itself still updates on every step - the live preview is the whole point of
	# dragging - it is only the HISTORY that waits for the release, so one undo
	# returns to where things stood before the drag began.
	#
	# Keyed on the BUTTON rather than on Slider.drag_started/drag_ended so one rule
	# covers the color wheel and the region box too; neither has those signals and
	# both had the same fault.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if key != "" and key == editor._undo_press_key:
			return
		editor._undo_press_key = key
	else:
		editor._undo_press_key = ""
	# NO TIME-BASED COALESCING. There was a 0.9s window that merged consecutive
	# edits of the same field, and once the mouse button became the boundary above
	# it had nothing left to do except cause the OTHER half of the report: two
	# separate adjustments made within 0.9s of each other folded into one history
	# entry, so Ctrl+Z "often reverts several changes at once". A press is an
	# action, a release ends it, and anything else - a keyboard nudge, a menu pick -
	# is its own step. Nothing merges on a clock.
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


## The live preview above the Ramp/Damp buttons - see feedback/0019: "if a user
## uses undo, they have a little preview of what they would be reverting."
## _undo_descs.back() is the description passed to the push() call that
## opened the CURRENT undo step, i.e. exactly the action Ctrl+Z would revert.
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


## _selected points INTO the array a restore just replaced wholesale, so it's
## dangling - re-resolve it by time in the restored array (or drop the
## selection if that marker no longer exists there) before refreshing anything
## that reads it. Tracks went through the same wholesale replacement - the
## runtime players (see MaskTracks.runtime) need reconciling against whatever
## session.tracks now holds, same as MaskTracks._delete_track/MaskTracks.finish_import do.
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


## After undo/redo swaps session.tracks wholesale, the live VideoStreamPlayers
## in MaskTracks.runtime (built incrementally by MaskTracks.build_view) no longer
## necessarily match it 1:1 - a track undo/redo added or removed can leave too
## many or too few. Rebuild runtime state to match: free anything past the
## restored count, (re)build anything missing. Existing entries are trusted
## as-is even if that track's trim/offset changed - MaskTracks.sync reseeks on
## the next frame regardless, same as any ordinary drag.
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
