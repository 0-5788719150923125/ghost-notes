extends HBoxContainer
class_name NoteKept

## NoteKept - what is kept of a note, on its Body card, the card every note has:
##
##   - Cache opens the folder of what is made for what the note shows: the picked episode's, else the note's own.
##   - Restore... lists every state it can go back to, newest first, each its moment and what changed: the note's every save
##     ([NoteHistory], kept as the note's file is written) and, where it shows an episode, that episode's step versions
##     ([method EpisodeFeed.versions]). Going back keeps what stood: the note put back is written as its newest save, a step put
##     back sends what stood a version back - so the list only grows.
##
## Handed by its panel: the note's [member doc], where its cache is ([member cache_dir]) and its history
## ([member history_dir]), and the episode it shows ([member feed]). Never written from a process that may
## not write the author's things.

## The note's source: what is put back is written through it, and each of its writes is kept.
var doc: DocSource
## () -> String: the folder of what is made for what the note shows now.
var cache_dir: Callable = Callable()
## () -> String: where the note's saved states are kept ("" for a note with no file).
var history_dir: Callable = Callable()
## () -> EpisodeFeed: the episode the note shows, null for none.
var feed: Callable = Callable()
## () -> void: something was put back.
var after: Callable = Callable()

var _window: AcceptDialog = null
var _list: VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 6)
	var cache := Button.new()
	cache.text = "Cache"
	cache.focus_mode = Control.FOCUS_NONE
	cache.tooltip_text = ("Open the folder of what is made for this note: the picked episode's prompts, replies, pictures and versions, "
		+ "or the note's own takes and pictures. Your note itself is wherever you keep it.")
	cache.pressed.connect(open_cache)
	add_child(cache)
	var back := Button.new()
	back.text = "Restore…"
	back.focus_mode = Control.FOCUS_NONE
	back.tooltip_text = ("Every state this note can go back to, newest first, and what changed in each: its every save, and the "
		+ "episode's steps as they stood. Going back keeps what stood now as the newest entry, so nothing is lost either way.")
	back.pressed.connect(open_restore)
	add_child(back)


func _ready() -> void:
	# Every save kept: the note as it is opened, then each time its file is written
	if doc != null and not doc.written.is_connected(keep_now):
		doc.written.connect(keep_now)
	keep_now()


## The note's file, as it stands, kept in its history (the same as the newest is kept once). "" kept, else why not.
func keep_now() -> String:
	if doc == null or not doc.is_sync() or Settings.is_read_only():
		return "nothing is kept from here"
	var dir := String(history_dir.call()) if history_dir.is_valid() else ""
	var path := doc.doc_path()
	if dir.is_empty() or path.is_empty() or not FileAccess.file_exists(path):
		return "the note has no file yet"
	return NoteHistory.record(dir, FileAccess.get_file_as_string(path))


func open_cache() -> void:
	var dir := String(cache_dir.call()) if cache_dir.is_valid() else ""
	if dir.is_empty() or Settings.is_read_only():
		return
	DirAccess.make_dir_recursive_absolute(dir)
	OS.shell_open(dir)


## Every state to go back to, newest first: `[{at, where, said, note?: entry, key?: an episode's version}]`.
func entries() -> Array:
	var out: Array = []
	var dir := String(history_dir.call()) if history_dir.is_valid() else ""
	if not dir.is_empty():
		for e in NoteHistory.entries(dir):
			out.append({"at": float((e as Dictionary)["at"]), "where": "The note", "said": String((e as Dictionary)["said"]), "note": e})
	var f: EpisodeFeed = feed.call() if feed.is_valid() else null
	if f != null:
		for v in f.versions():
			out.append({"at": float((v as Dictionary)["at"]), "where": "The episode", "said": String((v as Dictionary)["said"]),
				"key": (v as Dictionary)["key"]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) > float(b["at"]))
	return out


## Entry [param e] ([method entries]) put back: the note's text written as its file and read back into the panel - kept as its
## newest save - or an episode's step version put back. "" done, else why not.
func put_back(e: Dictionary) -> String:
	if Settings.is_read_only():
		return "this session is read-only"
	var err := ""
	if e.has("note"):
		var dir := String(history_dir.call()) if history_dir.is_valid() else ""
		var text := NoteHistory.text_of(dir, e["note"])
		var path := doc.doc_path() if doc != null else ""
		if text.is_empty() or path.is_empty():
			return "that state is no longer kept"
		doc.settle()
		keep_now()
		var f := FileAccess.open(path + ".part", FileAccess.WRITE)
		if f == null:
			return "could not write " + path
		f.store_string(text)
		f.close()
		if DirAccess.rename_absolute(path + ".part", path) != OK:
			return "could not move the note into place"
		doc.reload()
		keep_now()
	else:
		var fe: EpisodeFeed = feed.call() if feed.is_valid() else null
		err = fe.put_back(e["key"]) if fe != null else "no episode is shown"
	if err.is_empty() and after.is_valid():
		after.call()
	return err


func open_restore() -> void:
	if _window == null or not is_instance_valid(_window):
		_window = AcceptDialog.new()
		_window.title = "Restore"
		_window.ok_button_text = "Close"
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(640, 420)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_list = VBoxContainer.new()
		_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_list)
		_window.add_child(scroll)
		add_child(_window)
	_fill()
	_window.popup_centered()


func _fill() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var all := entries()
	if all.is_empty():
		var none := Label.new()
		none.text = "Nothing is kept for this note yet: each save is, from now on."
		_list.add_child(none)
		return
	for e in all:
		var row := HBoxContainer.new()
		var said := Label.new()
		said.text = "%s   %s: %s" % [Time.get_datetime_string_from_unix_time(int(float(e["at"])), true).substr(5, 11),
			String(e["where"]), String(e["said"])]
		said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		said.clip_text = true
		said.tooltip_text = String(e["said"])
		said.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(said)
		var go := Button.new()
		go.text = "Restore"
		go.focus_mode = Control.FOCUS_NONE
		go.pressed.connect(func() -> void:
			var err := put_back(e)
			if not err.is_empty():
				said.text = "Not put back: " + err
			else:
				_fill())
		row.add_child(go)
		_list.add_child(row)
