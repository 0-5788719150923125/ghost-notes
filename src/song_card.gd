extends VBoxContainer
class_name SongCard

## SongCard - the note's song (2026-10-06): which file it is, and a way to choose one. Importing a
## song is a component of a note, not a button on the notes list - "if we want to import an audio
## file or a video file - then we should add those relevant components/attachments to the note".
##
## THE SONG IS THE NOTE'S CLOCK. main loads it as the note opens, waiting at its start - a note opens
## stopped - and the transport plays it; with no Picture attached it plays to an empty frame. So
## choosing another song is choosing another session: the card says which file was picked
## ([signal chosen]) and the panel writes the note's `song:` block and opens the note again.

const AUDIO_EXTS := ["wav", "mp3", "ogg", "oga", "flac"]

## A song was picked: its path. The panel writes it into the note and opens the note again.
signal chosen(path: String)

var _path := ""
var _name: Label
var _info: Label
var _pick: Button
var _dialog: FileDialog = null


## [param path] is the note's `song:` block's path - "" when none has been chosen yet.
func _init(path := "") -> void:
	_path = path
	add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_name = Label.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.add_theme_font_size_override("font_size", 14)
	row.add_child(_name)
	_pick = Button.new()
	_pick.focus_mode = Control.FOCUS_NONE
	_pick.pressed.connect(_open_dialog)
	row.add_child(_pick)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 12)
	_info.modulate = Color(1, 1, 1, 0.65)
	add_child(_info)
	_refresh()


## The file this note plays, "" for none.
func path() -> String:
	return _path


## Whether the note's song is there to play.
func ready_to_play() -> bool:
	return not _path.is_empty() and FileAccess.file_exists(_path)


func _refresh() -> void:
	if _path.is_empty():
		_name.text = "No song yet"
		_name.tooltip_text = ""
		_pick.text = "Choose…"
		_info.text = "Choose a song for this note: it plays from the transport, and a Picture shows a scene for it."
	elif not FileAccess.file_exists(_path):
		_name.text = "Missing: " + _path.get_file()
		_name.tooltip_text = _path
		_pick.text = "Choose…"
		_info.text = "The song is not where the note says it is - choose it again."
	else:
		_name.text = "♪  " + _path.get_file().get_basename()
		_name.tooltip_text = _path
		_pick.text = "Change…"
		_info.text = "Plays from the transport below the stage: Space plays and pauses."
	_pick.tooltip_text = "Choose a song for this note - a WAV, MP3, OGG or FLAC file."


func _open_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		return
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	# In-window, never native: the portal dialog shows nothing at all on a Linux box without
	# xdg-desktop-portal.
	_dialog.use_native_dialog = false
	_dialog.title = "Choose a song for this note"
	_dialog.filters = PackedStringArray(["*.wav, *.mp3, *.ogg, *.oga, *.flac ; Songs", "* ; Every file"])
	if not _path.is_empty():
		_dialog.current_dir = _path.get_base_dir()
	_dialog.size = Vector2i(820, 560)
	_dialog.file_selected.connect(func(p: String) -> void:
		_close_dialog()
		chosen.emit(p))
	_dialog.canceled.connect(_close_dialog)
	add_child(_dialog)
	_dialog.popup_centered()


func _close_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null
