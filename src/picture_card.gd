extends VBoxContainer
class_name PictureCard

## PictureCard - the picture a reading is shown in: the MEDIUM (what the show is carried on), the
## FILMS a comic cuts to, the book's PICTURES ([IllustrationPanel]), and the Director's dials -
## scene hold, flourishes, camera, handwriting (next/notes.md step 5: one card per section). Its
## block in a document is `picture:`; the pictures keep their own, `illustrations:`.
##
## WHAT IT OFFERS FOLLOWS THE NOTE: a note with only a song gets the media that need nothing but a
## sound to cut on ([method Medium.offered] - not the novel, the notebook or the tablet, which print a
## reading), and AUTO - the original show with nothing to set ([AutoMedium]) - is first, and shows
## nothing under the picker at all.
##
## A ROW A MEDIUM CANNOT USE IS HIDDEN, by [constant Medium.USES] rather than by branching here:
## "there are a number of settings currently being displayed that ONLY work with the comic book
## medium" - a control that does nothing teaches nothing. The rows move the moment the medium
## does ([signal Director.medium_changed]), though the medium itself lands at the next reading: a
## control that stayed hidden until a restart would read as the picker not having worked.
##
## They lived only in this machine's ghost.cfg once, so a chapter opened on another machine -
## Windows, first - came up in whatever medium and look THAT machine last had: "the medium didn't
## transfer, the filters didn't transfer". The film LIBRARY stays behind: it is this machine's
## file paths.

## The block this card keeps under a document's `ghost:` key.
const KEY := "picture"

## A line for the panel's status ("Medium: Comic book - takes effect on the next reading.").
signal noted(msg: String)

var _medium_pick: OptionButton
var _frame_pick: OptionButton
var _hand_pick: OptionButton
var _scene_hold: HSlider
var _flourish: HSlider
var _camera: HSlider
var _illustrations: IllustrationPanel   # the book's pictures - see illustration_panel.gd
var _film_list: VBoxContainer
var _film_freq: HSlider
var _film_status: Label
var _film_cutting := -1     # windows being cut last frame, so the status line only changes on change
var _film_dialog: FileDialog = null
## Rows only some media use, by the [constant Medium.USES] tag they answer to.
var _medium_rows := {}
## Rows every medium that takes settings uses: hidden only under one that takes none (Auto).
var _setting_rows: Array = []
## The media this card offers, in the picker's order ([method Medium.offered]).
var _keys: Array = []
## Whether the note is a reading: a medium picked then lands on the next one (a song's is shown at once).
var _reading := true


## [param reading]: whether the note is a reading (a voice reads its text), which every medium can
## show, or a song alone, which the media that print a reading cannot.
func _init(reading := true) -> void:
	_reading = reading
	_keys = Medium.offered(["audio", "reading"] if reading else ["audio"])
	add_theme_constant_override("separation", 8)
	_medium_pick = _medium_option()
	_frame_pick = _frame_option()
	_setting_rows.append(_frame_pick.get_parent())
	_build_films()
	# THE BOOK'S PICTURES, under the medium picker for the reason the films are: they only
	# mean something to the medium that prints them, and they appear the moment it is picked.
	_illustrations = preload("res://src/illustration_panel.gd").new()
	add_child(_illustrations)
	_tag("illustrations", _illustrations)
	_scene_hold = Card.slider_row(self, "Scene hold", Director.PACING_MIN, Director.PACING_MAX, 0.05,
		Director.pacing,
		"How long each visual scene stays on screen before the show cuts to the next. 1 is the "
		+ "default; 2 roughly doubles it. The music still decides where in the range each scene "
		+ "lands, so the variety is kept - the whole range just moves. Nothing to do with the "
		+ "speaking voice.",
		func(v: float) -> void: Director.set_pacing(v))
	_setting_rows.append(_scene_hold.get_parent())
	_flourish = Card.slider_row(self, "Flourishes", Director.FLOURISH_MIN, Director.FLOURISH_MAX, 0.05,
		Director.flourish,
		"How often the show breaks its rhythm - a burst of two or three quick cuts, or a run of "
		+ "beat-synced punches on the current scene. 0 turns them off entirely, 1 is the default. "
		+ "Set this to 0 first if the cutting feels busy: it separates 'too often' from 'too fast'.",
		func(v: float) -> void: Director.set_flourish(v))
	_setting_rows.append(_flourish.get_parent())
	_camera = Card.slider_row(self, "Camera", Director.CAMERA_MIN, Director.CAMERA_MAX, 0.05,
		Director.camera,
		"How severe the camera is on the Comic book medium - one knob over the whole "
		+ "behavior. 0 is a slow gentle drift that barely turns and never cuts; 1 is the "
		+ "default; 2 is fast, restless and cinematic, with real jump cuts. It scales how far "
		+ "a shot may swing, how many shots that swing is spread over, how long a move lasts "
		+ "and how deep a push goes. It is shown only for the media that fly a camera.",
		func(v: float) -> void: Director.set_camera(v))
	_tag("camera", _camera.get_parent())
	_hand_pick = _hand_option()
	sync_medium()
	Director.medium_changed.connect(sync_medium)


## Show only what the medium can use. ASKED OF THE DIRECTOR, NOT OF THE PICKER: selecting an
## item and the `item_selected` signal are separate things in Godot, so a picker driven from code
## has the signal without the index - and `resolved_medium` also knows a run launched with
## `--medium comic`, which the picker cannot.
func sync_medium() -> void:
	var key := Director.resolved_medium()
	var bare := not Medium.takes_settings(key)
	for row in _setting_rows:
		(row as Control).visible = not bare
	Medium.show_rows(_medium_rows, key)
	if bare:
		for tag in _medium_rows:
			for row in _medium_rows[tag] as Array:
				if is_instance_valid(row):
					(row as Control).visible = false
	if _keys.has(Director.medium):
		_medium_pick.select(_keys.find(Director.medium))
	_sync_frames()


## A MEDIUM THAT TAKES NO SETTINGS WAS PICKED: the dials go back to their defaults, so what it shows
## is the same for every note (see [AutoMedium]).
func _to_defaults() -> void:
	_scene_hold.value = 1.0
	_flourish.value = 1.0
	_camera.value = 1.0
	Director.set_frame("landscape")


## The chapter's text, whenever the panel reads it: the pictures list follows it.
func set_script_text(body: String) -> void:
	_illustrations.set_script_text(body)


## The book's pictures - a card of their own in the document (`illustrations:`), shown here.
func illustrations() -> IllustrationPanel:
	return _illustrations


## The block for a document: under a medium that takes no settings, its name alone.
func capture() -> Dictionary:
	if not Medium.takes_settings(Director.medium):
		return {"medium": Director.medium}
	return {"medium": Director.medium, "frame": Director.frame,
		"scene_hold": snappedf(Director.pacing, 0.01), "flourishes": snappedf(Director.flourish, 0.01),
		"camera": snappedf(Director.camera, 0.01), "hand": Director.hand,
		"film_frequency": snappedf(Films.frequency(), 0.01)}


## ...and back. Each key the block names is set through the same control a hand would use, so the
## card shows it and the Director saves it; a key it does not name is left alone.
func apply(block: Dictionary) -> void:
	var med := String(block.get("medium", ""))
	if _keys.has(med) and med != Director.medium:
		Director.set_medium(med)
		_medium_pick.select(_keys.find(med))
		if not Medium.takes_settings(med):
			_to_defaults()
			return
	if Medium.FRAME_SIZES.has(String(block.get("frame", ""))):
		Director.set_frame(String(block["frame"]))
		_sync_frames()
	if block.has("hand"):
		Director.set_hand(String(block["hand"]))
		_hand_pick.select(maxi(0, _hand_keys().find(Director.hand)))
	for pair in [["scene_hold", _scene_hold], ["flourishes", _flourish], ["camera", _camera],
			["film_frequency", _film_freq]]:
		var sl: HSlider = pair[1]
		if block.has(String(pair[0])):
			sl.value = clampf(float(block[String(pair[0])]), sl.min_value, sl.max_value)


func _process(_delta: float) -> void:
	_pump_films()


func _tag(feature: String, row: Control) -> void:
	(_medium_rows.get_or_add(feature, []) as Array).append(row)


## THE MEDIUM PICKER - what the show is carried on (see [Medium]). Built off the registry rather
## than a written-out list, so a new presentation appears here by being registered. It sits at the
## TOP of the card, above Scene hold, because it is the setting the ones below are qualified by.
func _medium_option() -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var l := Label.new()
	l.text = "Medium"
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var keys: Array = _keys
	var tip := ("What the show is drawn ON, as opposed to what drives it." + (" Takes effect on the "
		+ "next reading, not the one already playing." if _reading else "") + "\n")
	for k in keys:
		opt.add_item(String(Medium.LABELS.get(k, k)))
		tip += "\n%s - %s" % [Medium.LABELS.get(k, k), Medium.BLURBS.get(k, "")]
	opt.tooltip_text = tip
	# The DIRECTOR is the truth for this one (it is a whole-app setting and the export
	# render reads it), so the picker drives the setter rather than being bound directly -
	# and the setter is what persists it, through Settings like every other one.
	opt.select(maxi(0, keys.find(Director.medium)))
	opt.item_selected.connect(func(i: int) -> void:
		var k := String(keys[i])
		if not Medium.takes_settings(k):
			_to_defaults()
		Director.set_medium(k)
		noted.emit("Medium: %s%s" % [Medium.LABELS.get(k, k), " - takes effect on the next reading." if _reading else "."]))
	row.add_child(opt)
	return opt


## THE FRAME: landscape 16:9 or portrait 9:16 (next/notes.md step 10) - a property of the show, kept
## beside the medium. Only what the medium can be shown in is offered ([constant Medium.FRAMES]); a
## frame it cannot is grayed, saying so, and the show plays in landscape.
func _frame_option() -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var l := Label.new()
	l.text = "Frame"
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.fit_to_longest_item = false      # the panel's width is fixed; the platforms are in the tooltip
	opt.clip_text = true
	opt.add_item("Landscape  16:9")
	opt.add_item("Portrait  9:16")
	opt.item_selected.connect(func(i: int) -> void:
		Director.set_frame("portrait" if i == 1 else "landscape"))
	row.add_child(opt)
	return opt


func _sync_frames() -> void:
	if _frame_pick == null:
		return
	var ok := Medium.supports(Director.resolved_medium(), "portrait")
	_frame_pick.set_item_disabled(1, not ok)
	_frame_pick.select(1 if Director.resolved_frame() == "portrait" else 0)
	_frame_pick.tooltip_text = ("What the show is framed as - and exported at. Portrait is for Shorts, Reels and TikTok."
		if ok else "%s has no portrait frame yet - it frames a spread or a table a 9:16 view cannot hold - so the show is landscape."
			% Medium.LABELS.get(Director.resolved_medium(), Director.resolved_medium()))


## The notebook's handwriting: a named hand, or Random (drawn per session from the seed).
func _hand_option() -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var l := Label.new()
	l.text = "Handwriting"
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.tooltip_text = "The notebook's handwriting. Random draws one per session, which changes " \
		+ "whenever the audio does; a named hand stays put, and travels with the chapter."
	for k in _hand_keys():
		opt.add_item("Random" if k == "random" else String(k).capitalize())
	opt.select(maxi(0, _hand_keys().find(Director.hand)))
	opt.item_selected.connect(func(i: int) -> void:
		Director.set_hand(String(_hand_keys()[i])))
	row.add_child(opt)
	_tag("handwriting", row)
	return opt


func _hand_keys() -> Array:
	var keys: Array = NotebookLayout.HANDS.keys()
	keys.sort()
	return keys + ["random"]


# --- films: real footage in a comic panel -------------------------------------
#
# THIS SITS UNDER THE MEDIUM PICKER because it only means anything to the comic, and a
# setting is easiest to understand next to the thing it qualifies.
#
# IT IS ALSO HIDDEN WHEN THE MEDIUM CANNOT USE IT, which reverses an earlier decision worth
# recording rather than quietly overwriting. The argument for always showing it was that
# someone building a library before switching over should not have to discover that the
# controls exist somewhere else first. That is answered by WHERE it sits: the picker is the
# row directly above, so the controls appear the moment the comic is chosen, in the place the
# eye is already looking. The argument against it was the stronger one - "there are a number
# of settings currently being displayed that ONLY work with the comic book medium" - because
# a control that does nothing teaches nothing, and there were two of them.

## The film library block: the list, an import button, and the frequency dial. Built into a
## group of its own so the whole block can be shown or hidden as one (see Medium.USES).
func _build_films() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_tag("films", box)
	var head := Label.new()
	head.text = "Films"
	head.add_theme_font_size_override("font_size", 12)
	head.tooltip_text = ("Real footage, cut into the comic among the drawn panels. Adding one "
		+ "is instant - nothing is converted up front. A clip is prepared in short windows, "
		+ "cut from the original only where the show is about to look, so a two-hour film "
		+ "costs the same as a two-minute one and a page that arrives before its window is "
		+ "ready simply goes without footage.\n\n"
		+ "KEEP THE ORIGINAL FILE where it is: windows are cut from it as they are needed, so "
		+ "moving or deleting it drops the clip from the list.\n\n"
		+ "A clip does NOT start from the beginning each time it appears. It plays from wherever "
		+ "it would be if it had been looping since the show started, so it reads as one film "
		+ "running behind the page that the comic occasionally cuts into.\n\n"
		+ "Only one panel at a time ever holds footage - two showing the same clip would show "
		+ "the same picture twice, because the position is decided by the clock alone.")
	box.add_child(head)

	_film_list = VBoxContainer.new()
	_film_list.add_theme_constant_override("separation", 2)
	box.add_child(_film_list)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var add := Button.new()
	add.text = "Import a clip…"
	add.focus_mode = Control.FOCUS_NONE
	add.tooltip_text = ("Pick a video file. It is added immediately - there is no transcode "
		+ "to wait for. The parts the show actually reaches are converted in the background, "
		+ "about a minute of film at a time, and the original is only ever read from.")
	add.pressed.connect(_open_film_dialog)
	row.add_child(add)
	_film_status = Label.new()
	_film_status.add_theme_font_size_override("font_size", 11)
	_film_status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75, 0.85))
	_film_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_film_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_film_status)

	_film_freq = Card.slider_row(box, "How often", Films.FREQ_MIN, Films.FREQ_MAX, 0.05,
		Films.frequency(),
		"How often a comic page gives one of its panels to footage. This is per PAGE, not per "
		+ "panel, because only one panel may hold footage at a time - at 1 every page has one, "
		+ "at 0 none ever do. With no clips imported it does nothing.\n\n"
		+ "It is NOT competing with the scene types: a film is not one more entry drawn against "
		+ "the seventy-odd others, it is a separate decision made when the page turns. Measured, "
		+ "a page averages 3.3 panels, so 0.5 is film on about half the pages and one panel in "
		+ "seven; 1 is every page and one panel in three, which is the ceiling one-at-a-time "
		+ "allows.",
		func(v: float) -> void: Films.set_frequency(v))
	_refresh_films()


## Rebuild the list of imported clips. Cheap and total - the library is a handful of rows,
## and a diff would be more code than the thing it saves.
func _refresh_films() -> void:
	if _film_list == null or not is_instance_valid(_film_list):
		return
	for c in _film_list.get_children():
		c.queue_free()
	var list := Films.clips()
	if list.is_empty():
		var none := Label.new()
		none.text = "  (none imported)"
		none.add_theme_font_size_override("font_size", 11)
		none.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 0.6))
		_film_list.add_child(none)
		return
	for i in list.size():
		var c: Dictionary = list[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_film_list.add_child(row)
		var l := Label.new()
		var dur := float(c.get("duration", 0.0))
		l.text = "  %s  ·  %d:%02d" % [String(c.get("name", "clip")), int(dur / 60.0),
			int(fmod(dur, 60.0))]
		l.add_theme_font_size_override("font_size", 11)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.tooltip_text = String(c.get("source", ""))
		row.add_child(l)
		var x := Button.new()
		x.text = "×"
		x.focus_mode = Control.FOCUS_NONE
		x.tooltip_text = "Forget this clip and delete the windows cut from it. The original "\
			+ "file is not touched."
		var at := i
		x.pressed.connect(func() -> void:
			Films.remove(at)
			_refresh_films())
		row.add_child(x)


func _open_film_dialog() -> void:
	if _film_dialog != null and is_instance_valid(_film_dialog):
		return
	_film_dialog = FileDialog.new()
	_film_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_film_dialog.access = FileDialog.ACCESS_FILESYSTEM
	# In-window, never native: the portal dialog shows nothing at all on a Linux box
	# without xdg-desktop-portal, which is the "I pressed it and nothing happened" report
	# Masking's own importer already carries this note for.
	_film_dialog.use_native_dialog = false
	_film_dialog.title = "Import a clip for the comic"
	_film_dialog.filters = PackedStringArray(["*.mp4, *.mov, *.mkv, *.webm, *.avi, *.ogv ; Video"])
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if not downloads.is_empty():
		_film_dialog.current_dir = downloads
	_film_dialog.size = Vector2i(820, 560)
	_film_dialog.file_selected.connect(_start_film_import)
	_film_dialog.file_selected.connect(func(_p): _close_film_dialog())
	_film_dialog.canceled.connect(_close_film_dialog)
	add_child(_film_dialog)
	_film_dialog.popup_centered()


func _close_film_dialog() -> void:
	if _film_dialog != null and is_instance_valid(_film_dialog):
		_film_dialog.queue_free()
	_film_dialog = null


## ADDING A CLIP IS INSTANT. There is no transcode to wait for - a clip is prepared a
## window at a time, when something wants to play it (see Films.WINDOW), so this reads a
## duration and writes a row.
func _start_film_import(source: String) -> void:
	var err := Films.add(source)
	if not err.is_empty():
		_film_status.text = "⚠  " + err
		return
	_film_status.text = "✓  Added %s" % source.get_file().get_basename()
	_refresh_films()


## Polled from _process. A window cut is a subprocess, so something with a frame has to
## notice it finished; this is that, for as long as the card is up. [FilmScene] does
## the same while a panel is live, which between them covers every moment one is awaited.
func _pump_films() -> void:
	Films.pump()
	# The status line follows the cutting rather than a one-shot import, because "is it
	# ready" is now a question with a running answer.
	if _film_status == null or not is_instance_valid(_film_status):
		return
	var cutting := 0
	for c in Films.clips():
		if Films.busy(c):
			cutting += 1
	if cutting != _film_cutting:
		_film_cutting = cutting
		if cutting > 0:
			_film_status.text = "⏳  Preparing %d window%s…" % [cutting,
				"" if cutting == 1 else "s"]
		elif not Films.clips().is_empty():
			_film_status.text = "✓  Ready"
