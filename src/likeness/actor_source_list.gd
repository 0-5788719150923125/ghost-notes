extends VBoxContainer
class_name ActorSourceList

## ActorSourceList - where a person's recordings come from, on a card that builds something of them (the Actor
## card; the Voice training card, for a voice alone): their SOURCES - a folder read where it is, files picked one
## by one, a link (a video, a playlist or a channel) listed and then fetched a video at a time, or for an actor a
## link for captions only, matched to the folder's videos by title ([ActorSources]) - and their videos, a tick
## each. Handed the folder and its builder ([method show_actor]); what it has to say goes out as [signal said].
##
## A VIDEO TICKED REBUILDS NO ROW (2026-10-23: every tick held the app for seconds while all of them were made
## again): the rows are made again only when a video is added, fetched or measured ([method refresh]). TICK ALL
## AND UNTICK ALL take the whole list at once.
##
## A VOICE ALONE ([method ActorFolder.sound_only]) is offered no captions-only link (Hear listens to all of it)
## and no "head" pin, and its folders' sound files are listed beside their videos.

signal said(text: String)

var _actor: ActorFolder = null
var _builder: ActorBuilder = null
var _sources_box: VBoxContainer
var _videos_box: VBoxContainer
var _videos_seen := ""
## Each video's tick, by its id.
var _ticks := {}
var _add_folder: Button
var _add_files: Button
var _add_link: Button


func _init() -> void:
	add_theme_constant_override("separation", 8)
	_sources_box = VBoxContainer.new()
	add_child(_sources_box)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	add_child(srow)
	_add_folder = Button.new()
	_add_folder.text = "Add folder…"
	_add_folder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_folder.pressed.connect(_pick_folder)
	srow.add_child(_add_folder)
	_add_files = Button.new()
	_add_files.text = "Add files…"
	_add_files.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_files.pressed.connect(_pick_files)
	srow.add_child(_add_files)
	_add_link = Button.new()
	_add_link.text = "Add link…"
	_add_link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_link.pressed.connect(_ask_link)
	srow.add_child(_add_link)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 120
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_videos_box = VBoxContainer.new()
	_videos_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_videos_box)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 6)
	add_child(trow)
	for on in [true, false]:
		var all := Button.new()
		all.text = "Tick all" if on else "Untick all"
		all.tooltip_text = ("Use every video listed: Generate reads each one not read yet - a long while for many." if on
			else "Use none of them: then tick the ones that are them, in their usual setting.")
		all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		all.pressed.connect(tick_all.bind(on))
		trow.add_child(all)
	_tips()


## THE PERSON SHOWN: [param a] and the builder that fetches for it ([param b]), or nulls for none.
func show_actor(a: ActorFolder, b: ActorBuilder) -> void:
	_actor = a
	_builder = b
	_videos_seen = ""
	_tips()
	fill_sources()


## What the buttons add, as the person shown takes it.
func _tips() -> void:
	if _voice():
		_add_folder.tooltip_text = "A folder of their recordings - videos or sound files: read where it is, never copied or written. Each is listed below, ticked."
		_add_files.tooltip_text = "Recordings of theirs, picked one by one - videos or sound files: read where they are, never copied."
		_add_link.tooltip_text = "A video, a playlist or a whole channel: listed at once, then the sound of each fetched by Generate, one at a time (no picture: a playlist of hours is megabytes). A playlist added again fetches only what is new."
	else:
		_add_folder.tooltip_text = "A folder of their videos: read where it is, never copied or written. Its videos are listed below, ticked."
		_add_files.tooltip_text = "Videos of theirs, picked one by one: read where they are, never copied."
		_add_link.tooltip_text = "A video, a playlist or a whole channel: listed at once, then each video fetched (up to 1080p, with its automatic captions) by Generate, one at a time. A playlist added again fetches only what is new."


## Is the person shown a voice alone?
func _voice() -> bool:
	return _actor != null and _actor.sound_only()


func _say(text: String) -> void:
	said.emit(text)


## The sources' rows, built again whole: what each is, and for a link how its listing went and ⟳ to list it again.
func fill_sources() -> void:
	for c in _sources_box.get_children():
		c.queue_free()
	if _actor == null:
		return
	var sources: Array = _actor.data["sources"]
	for i in sources.size():
		var s: Dictionary = sources[i]
		var row := HBoxContainer.new()
		_sources_box.add_child(row)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.add_theme_font_size_override("font_size", 11)
		var what := ""
		match String(s.get("kind", "")):
			"folder":
				what = "📁 " + String(s.get("path", "")).get_file()
				l.tooltip_text = String(s.get("path", ""))
			"file":
				var p := String(s.get("path", ""))
				what = ("🎞 " if ActorFolder.VIDEO_EXTS.has(p.get_extension().to_lower()) else "🔊 ") + p.get_file()
				l.tooltip_text = p
			_:
				var t := String(s.get("title", ""))
				what = ("💬 " if bool(s.get("captions_only", false)) else "🔗 ") + (t if not t.is_empty() else String(s.get("url", "")))
				var landed: Dictionary = s.get("landed", {}) if s.get("landed") is Dictionary else {}
				if bool(s.get("captions_only", false)) and not landed.is_empty():
					what += "  (captions for %d, %d unmatched)" % [int(landed.get("matched", 0)), int(landed.get("unmatched", 0))]
				elif not landed.is_empty():
					what += "  (%d videos)" % int(s.get("count", 0))
				if not String(s.get("error", "")).is_empty():
					what += "  ⚠ " + String(s["error"])
				elif not bool(s.get("listed", false)):
					what += "  - listing…" if _builder != null and _builder.listing(i) else "  - not listed"
				l.tooltip_text = String(s.get("url", "")) + ("\nCaptions only: fetches no video; each caption is matched to a folder video by title." if bool(s.get("captions_only", false)) else "")
		l.text = what
		row.add_child(l)
		if String(s.get("kind", "")) == "link":
			var again := Button.new()
			again.text = "⟳"
			again.flat = true
			again.tooltip_text = "List this link again: new videos in a playlist or channel get rows (fetched videos are not fetched twice)."
			again.pressed.connect(list_link.bind(i))
			row.add_child(again)


func _pick_folder() -> void:
	if _actor == null:
		return
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.title = ("A folder of their recordings" if _voice() else "A folder of their videos") + " (read where it is, never copied)"
	dlg.dir_selected.connect(func(path: String) -> void:
		dlg.queue_free()
		var n := ActorSources.add_folder(_actor, path)
		_actor.save()
		fill_sources()
		_videos_seen = ""
		_say("%d %s%s found in %s. Untick any that are not them." % [n, "recording" if _voice() else "video",
			"" if n == 1 else "s", path.get_file()]))
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered_ratio(0.6)


func _pick_files() -> void:
	if _actor == null:
		return
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.title = ("Recordings of theirs" if _voice() else "Videos of theirs") + " (read where they are, never copied)"
	dlg.filters = PackedStringArray(["*." + ", *.".join(PackedStringArray(_actor.exts())) + " ; "
		+ ("Videos and sound" if _voice() else "Videos")])
	dlg.files_selected.connect(func(paths: PackedStringArray) -> void:
		dlg.queue_free()
		var n := 0
		for p in paths:
			n += ActorSources.add_file(_actor, p)
		_actor.save()
		fill_sources()
		_videos_seen = ""
		_say("%d new %s%s. Untick any that are not them." % [n, "recording" if _voice() else "video", "" if n == 1 else "s"]))
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered_ratio(0.6)


func _ask_link() -> void:
	if _actor == null:
		return
	var ask := ConfirmationDialog.new()
	ask.title = "Add a link"
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = "A video, a playlist or a channel:"
	box.add_child(l)
	var field := LineEdit.new()
	field.custom_minimum_size.x = 420
	field.placeholder_text = "https://www.youtube.com/…"
	box.add_child(field)
	var cap := CheckBox.new()
	cap.text = "Captions only - match them to the folder's videos by title"
	cap.tooltip_text = "Fetches no video: each video's automatic captions are matched to a video already in a folder source, by title, so its words get their times without the video being downloaded again."
	cap.visible = not _voice()
	box.add_child(cap)
	ask.add_child(box)
	ask.ok_button_text = "Add"
	ask.confirmed.connect(func() -> void:
		var url := field.text.strip_edges()
		ask.queue_free()
		if not url.begins_with("http"):
			_say("That is not a link.")
			return
		var i := ActorSources.add_link(_actor, url, cap.button_pressed and not _voice())
		_actor.save()
		list_link(i))
	ask.canceled.connect(ask.queue_free)
	add_child(ask)
	ask.popup_centered(Vector2i(460, 0))
	field.grab_focus()


## LIST LINK [param i]: its videos come back as rows.
func list_link(i: int) -> void:
	if _builder == null:
		return
	var err := _builder.list_link(i)
	_say(err if not err.is_empty() else "Listing the link… its videos appear below as they are found.")
	fill_sources()


## The videos' rows, built again when the videos change: a tick, the title, its length.
func refresh() -> void:
	var key := ""
	if _actor != null:
		for vid in _actor.videos():
			var v: Dictionary = _actor.video(String(vid))
			# a video ticked rebuilds no row: its box shows it already
			key += "%s|%s|%s|%s;" % [vid, v.get("path", ""), v.get("captions", ""), v.get("duration", 0.0)]
	if key == _videos_seen:
		return
	_videos_seen = key
	for c in _videos_box.get_children():
		c.queue_free()
	_ticks = {}
	if _actor == null:
		return
	var voice := _voice()
	for vid in _actor.videos():
		var v: Dictionary = _actor.video(String(vid))
		var row := HBoxContainer.new()
		_videos_box.add_child(row)
		var tick := CheckBox.new()
		tick.button_pressed = bool(v.get("ticked", true))
		tick.tooltip_text = ("Use this recording. Untick one that is not them, or not their usual voice." if voice
			else "Use this video. Untick one that is not them, or not in their usual setting.")
		var copy := _actor.copy_of(String(vid))
		if not copy.is_empty():
			tick.disabled = true
			tick.tooltip_text = "A copy of \"%s\" (the same title and length): left out." % String(_actor.video(copy).get("title", copy))
		tick.toggled.connect(func(on: bool) -> void:
			(_actor.video(String(vid)))["ticked"] = on
			_actor.save())
		_ticks[String(vid)] = tick
		row.add_child(tick)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.add_theme_font_size_override("font_size", 11)
		var dur := float(v.get("duration", 0.0))
		var marks := ""
		if _actor.is_link(String(vid)) and _actor.video_path(String(vid)).is_empty():
			marks += "↓ "
		elif _actor.video_path(String(vid)).is_empty():
			marks += "⚠ missing "
		if not copy.is_empty():
			marks += "⧉ copy "
		if FileAccess.file_exists(String(v.get("captions", ""))):
			marks += "💬 "
		l.text = marks + String(v.get("title", vid)) + ("  %s" % Clock.text(dur) if dur > 0.0 else "")
		l.tooltip_text = String(v.get("path", v.get("url", ""))) + "\n↓ not fetched yet · 💬 has captions · ⧉ a copy of another, left out"
		row.add_child(l)
		if voice:
			continue
		# THE HEAD PINNED to a few alike videos (ActorFolder.head_videos): the rest stay ticked for everything else
		var pin := Button.new()
		pin.toggle_mode = true
		pin.flat = true
		pin.text = "head"
		pin.add_theme_font_size_override("font_size", 10)
		pin.button_pressed = bool(v.get("head", false))
		pin.modulate.a = 1.0 if pin.button_pressed else 0.45
		pin.tooltip_text = ("Learn their head of splats from this video. With any pinned, the head learns from the pinned "
			+ "alone - a few alike videos (one room, one light, the same clothes) - and every ticked video is still "
			+ "used for everything else: the voice, the mouth, the motion. With none pinned it learns from the Head "
			+ "videos with the most of them facing the camera.")
		pin.toggled.connect(func(on: bool) -> void:
			if on:
				(_actor.video(String(vid)))["head"] = true
			else:
				(_actor.video(String(vid))).erase("head")
			pin.modulate.a = 1.0 if on else 0.45
			_actor.save())
		row.add_child(pin)


## TICK ALL, OR UNTICK ALL: every video of theirs used, or none - one save, every box set.
func tick_all(on: bool) -> void:
	if _actor == null:
		return
	for vid in _actor.videos():
		(_actor.video(String(vid)))["ticked"] = on
	_actor.save()
	for vid in _ticks:
		if is_instance_valid(_ticks[vid]):
			(_ticks[vid] as CheckBox).set_pressed_no_signal(on)
	_say(("Every video of theirs is used: Generate reads the ones not read yet." if on
		else "No video is used: tick the ones that are them, in their usual setting."))
