extends CanvasLayer
class_name ConsoleView

## The in-app console - a live tail of Godot's own log file. print(), push_warning(), push_error() and
## engine SCRIPT ERRORs land in user://logs/godot*.log, which a compiled app or launcher run never shows.
## The `>_` toggle on the shared bottom-right row opens a panel tailing the newest log live. Part of the
## shared Chrome (chrome.gd), so every mode carries it.
##
## What the terminal shows, this shows: a child started with Subprocess.start has its output echoed into
## godot's log as `[tag] line`, and a Godot child of this project logs to a file of its own
## (Subprocess.own_log) rather than truncating this one. A child with a log file of its own
## (Subprocess.start_logged / start_redirected) is echoed by its owner when a step finishes (see
## mask_editor._yt_echo_log). Release builds flush the log on every line
## (application/run/flush_stdout_on_print) because ghost quits by SIGKILL.
##
## IT FOLLOWS THE NEWEST LINES ONLY FROM THE BOTTOM: what is new since it last looked is appended, whole lines only, and the
## view moves with it only where it was already at the bottom - scrolled up to read or copy, it stays put. Opened from
## closed, it is at the bottom. A selection holds the view entirely until it is cleared.

const _TAIL_BYTES := 16384
const _REFRESH_EVERY := 0.5
## The most lines kept: the oldest go once it holds more, while the newest are being followed.
const _KEEP_LINES := 3000

var _toggle: Button
var _panel: PanelContainer
var _text: RichTextLabel
var _log_path := ""
var _accum := 0.0
var _offset := -1          # bytes of the log shown so far; -1 for nothing yet, -2 for a note that there is no log
var _to_bottom := false    # opened from closed: the next refresh lands at the bottom


func _ready() -> void:
	layer = 251   # one above the exporter's furniture (250) - same row, never under it
	_toggle = Button.new()
	_toggle.text = ">_"
	_toggle.tooltip_text = "Console - the app's own log output (print, warnings, errors), live"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.custom_minimum_size = Vector2(40, 40)
	_toggle.pressed.connect(_on_toggle)
	#The row's (Chrome.row_button), which places it; with no Chrome, at its old slot.
	var ch := Chrome.of(self)
	if ch != null:
		ch.row_button(&"console", _toggle)
		ch.register_panel(&"console", func() -> void: _panel.visible = false)
	else:
		_toggle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_toggle.offset_left = -156
		_toggle.offset_top = -68
		_toggle.offset_right = -116
		_toggle.offset_bottom = -28
		add_child(_toggle)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.offset_left = -28 - 640
	_panel.offset_right = -28
	_panel.offset_top = -76 - 380
	_panel.offset_bottom = -76
	_panel.visible = false
	add_child(_panel)

	_text = RichTextLabel.new()
	_text.selection_enabled = true
	_text.scroll_following = true   # ...while at the bottom ([method _process])
	#Ctrl+C on a selection.
	_text.shortcut_keys_enabled = true
	_text.add_theme_font_size_override("normal_font_size", 12)
	_text.custom_minimum_size = Vector2(620, 360)
	_panel.add_child(_text)


func _on_toggle() -> void:
	_panel.visible = not _panel.visible
	#One panel above the row at a time: opening this closes the others (Chrome.panel_opened)
	var ch := Chrome.of(self)
	if ch != null:
		if _panel.visible:
			ch.panel_opened(&"console")
		else:
			ch.panel_closed(&"console")
	if _panel.visible:
		_accum = _REFRESH_EVERY   # first refresh lands this frame, not half a second in
		_to_bottom = true


func _process(dt: float) -> void:
	if not _panel.visible:
		return
	_accum += dt
	if _accum < _REFRESH_EVERY:
		return
	_accum = 0.0
	#A selection holds the view: rewriting the label's text drops it, and this refreshes twice a second.
	#The backlog lands the moment the selection is cleared.
	if not _text.get_selected_text().is_empty():
		return
	var at_end := _to_bottom or _at_bottom()
	var got := _read_new()
	_text.scroll_following = at_end
	if bool(got["whole"]):
		_text.text = String(got["text"])
	elif not String(got["text"]).is_empty():
		_text.add_text(String(got["text"]))
	if at_end:
		while _text.get_paragraph_count() > _KEEP_LINES:
			_text.remove_paragraph(0)
	if _to_bottom:
		_to_bottom = false
		_scroll_end.call_deferred()


## Whether the view is at the newest line (or everything fits): only then does what is new move it.
func _at_bottom() -> bool:
	var bar := _text.get_v_scroll_bar()
	return bar.value + bar.page >= bar.max_value - 2.0


func _scroll_end() -> void:
	var bar := _text.get_v_scroll_bar()
	bar.value = bar.max_value


## The current session's log. The engine writes to the configured path (user://logs/godot.log by default)
## and renames previous runs to timestamped backups, which sort above "godot.log", so "newest by filename"
## picks a stale log. Ask the project setting for the live file; fall back to newest by mtime only if the
## setting is missing.
func _resolve_log() -> String:
	var configured := String(ProjectSettings.get_setting(
		"debug/file_logging/log_path", "user://logs/godot.log"))
	if FileAccess.file_exists(configured):
		return configured
	var dir := DirAccess.open("user://logs")
	if dir == null:
		return ""
	var best := ""
	var best_mtime := 0
	for f in dir.get_files():
		if not f.ends_with(".log"):
			continue
		var p := "user://logs/" + f
		var mt := FileAccess.get_modified_time(p)
		if mt > best_mtime:
			best_mtime = mt
			best = p
	return best


## What the log has said since it was last read: `{text, whole}` - whole lines only (the rest of a line waits for its end), and
## `whole` where the view is to be drawn again from the log's last [constant _TAIL_BYTES] (the first read, a log rotated or cut
## short, or one grown too far past what was shown).
func _read_new() -> Dictionary:
	if _log_path.is_empty():
		_log_path = _resolve_log()
	var said := ""
	if _log_path.is_empty():
		said = "(no log file - is debug/file_logging/enable_file_logging off?)"
	var f := FileAccess.open(_log_path, FileAccess.READ) if said.is_empty() else null
	if f == null and said.is_empty():
		said = "(could not open %s)" % _log_path
	if f == null:
		var first := _offset != -2
		_offset = -2
		return {"text": said if first else "", "whole": first}
	var sz := int(f.get_length())
	var whole := _offset < 0 or sz < _offset or sz - _offset > _TAIL_BYTES
	var from := maxi(0, sz - _TAIL_BYTES) if whole else _offset
	if from >= sz:
		if whole:
			_offset = sz
		return {"text": "", "whole": whole}
	f.seek(from)
	var buf := f.get_buffer(sz - from)
	var last := buf.rfind(10)
	if last < 0:
		_offset = from
		return {"text": "", "whole": whole}
	_offset = from + last + 1
	var s := buf.slice(0, last + 1).get_string_from_utf8()
	# A window that starts mid-line reads as a torn first line - drop it.
	if whole and from > 0:
		var nl := s.find("\n")
		s = s.substr(nl + 1) if nl >= 0 else ""
	return {"text": s, "whole": whole}


## Lift the toggle - and the panel above it - clear of whatever the mode has put along the bottom of the
## frame. See Chrome.bottom_inset.
func set_bottom_inset(v: float) -> void:
	if _toggle != null and _toggle.get_parent() == self:      # in the row, the row moves it
		_toggle.offset_top = -68.0 - v
		_toggle.offset_bottom = -28.0 - v
	if _panel != null:
		_panel.offset_top = -76.0 - 380.0 - v
		_panel.offset_bottom = -76.0 - v
