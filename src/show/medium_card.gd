extends VBoxContainer
class_name MediumCard

## MediumCard - what the note is shown in, one card. Its block in a document is `medium:`.
##
## The format is what the show is carried on: a row of [constant Medium.REGISTRY] that no component
## owns (the seeded show, full frame, a comic, a novel, a notebook, a tablet, a letter, a dispatch desk).
## Under it stand the shared rows (the frame, scene hold and flourishes, the camera, the handwriting, the
## films), each shown only where the format `uses` it, and under those the format's own rows (a row's
## `card`: the Letter's desk and sketch writer, the Dispatch desk's number), built from the script the
## row names. One block holds them all, only what the format uses: switching a Letter to a Tablet drops
## the desk. The note's pictures stay the Pictures card's ([PicturesCard]).
##
## A format with rows of its own hands the reading what it reads (its `walk`, its `publish`), so the
## panel is built around it: picking or leaving one writes the block and opens the note again ([member
## _reshape]), the path a component attached or detached takes. Every other pick is live (a song's show
## restaged at once, a reading's on its next Play).
##
## What it offers follows the note: a note with only a song gets the formats that need nothing but a
## sound to cut on ([method Medium.offered]), and Auto (the original show with nothing to set,
## [AutoMedium]) is first and shows nothing under the picker. A note whose block names a format it
## cannot have (a Letter whose Voice was detached) keeps it and says what it waits for ([member _held]).
##
## A table show's note (its Table brings this card) is offered Table's formats - its table, a desk - and only those
## ([method Medium.offered]): the one picked is the block's, never the remembered medium, and is what the next episode is
## made for; each episode is shown in the one it was made for ([method TableEpisode.medium]).
##
## A row a format cannot use is hidden, by each format's `uses` rather than by branching here; the rows
## move the moment the format does ([signal Director.medium_changed]). The block is kept in the note so
## a chapter opened on another machine comes up in the same medium and look. The film library stays
## behind: it is this machine's file paths.

## The block this card keeps under a document's `ghost:` key.
const KEY := "medium"

## A line for the panel's status ("Format: Comic book - takes effect on the next reading.").
signal noted(msg: String)

var _format_pick: OptionButton
var _frame_pick: OptionButton
var _hand_pick: OptionButton
var _scene_hold: HSlider
var _flourish: HSlider
var _camera: HSlider
var _film_list: VBoxContainer
var _film_freq: HSlider
var _film_status: Label
var _film_cutting := -1     # windows being cut last frame, so the status line only changes on change
var _film_dialog: FileDialog = null
var _waiting: Label         # what a format the note cannot have is waiting for
## Rows only some formats use, by the `uses` tag they answer to ([constant Medium.REGISTRY]).
var _medium_rows := {}
## Rows every format that takes settings uses: hidden only under one that takes none (Auto).
var _setting_rows: Array = []
## The formats this card offers, in the picker's order ([method Medium.offered]).
var _keys: Array = []
## Whether the note is a reading: a format picked then lands on the next one (a song's is shown at once).
var _reading := true
## The format's own rows ([constant Medium.REGISTRY] `card`), and the script they were built from ("" for none).
var _own: Control = null
var _own_card := ""
## Write the note as the cards hold it and open it again (the panel's, handed in `ctx`): a pick to or
## from a format with rows of its own.
var _reshape: Callable
## The block of a format the note cannot have, kept as it was until another is picked ({} for none).
var _held := {}
## A table show's note ([member _keys] Table's formats), the format its block names, and a block naming another format
## (a reading made a table show), kept as it was until one of Table's is picked ({} for none).
var _episodic := false
var _fmt := "table"
var _kept := {}


## This card for a note's panel, from what the panel says of itself ([method NoteCards.make]): `reading`
## (the note has a voice, so every format is offered), `provides` (an `episode`: a table show's, offered Table's formats),
## `blocks` (the note's, so the format's own rows
## stand from the first frame), `reshape` (write the note and open it again), and the whole of it handed
## on to the format's own rows (a reading's `workspace`).
static func for_note(ctx: Dictionary) -> MediumCard:
	return MediumCard.new(ctx)


func _init(ctx := {"reading": true}) -> void:
	_reading = bool(ctx.get("reading", false))
	_reshape = ctx.get("reshape", Callable())
	var blocks: Dictionary = ctx.get("blocks", {}) if ctx.get("blocks") is Dictionary else {}
	_episodic = (ctx.get("provides", []) as Array).has("episode") or Components.provided(Components.attached_of(blocks)).has("episode")
	_keys = Medium.offered(["audio", "reading", "episode"] if _episodic else (["audio", "reading"] if _reading else ["audio"]))
	if _episodic:
		var named := String((blocks.get(KEY, {}) as Dictionary).get("format", "")) if blocks.get(KEY) is Dictionary else ""
		_fmt = named if _keys.has(named) else "table"
		if not named.is_empty() and not _keys.has(named):
			_kept = (blocks[KEY] as Dictionary).duplicate(true)
	add_theme_constant_override("separation", 8)
	_format_pick = _format_option()
	_waiting = Label.new()
	_waiting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_waiting.add_theme_font_size_override("font_size", 12)
	_waiting.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
	_waiting.visible = false
	add_child(_waiting)
	_frame_pick = _frame_option()
	_setting_rows.append(_frame_pick.get_parent())
	_build_films()
	_scene_hold = Card.slider_row(self, "Scene hold", Director.PACING_MIN, Director.PACING_MAX, 0.05,
		Director.pacing,
		"How long each visual scene stays on screen before the show cuts to the next. 1 is the "
		+ "default; 2 roughly doubles it. The music still decides where in the range each scene "
		+ "lands, so the variety is kept - the whole range just moves. Nothing to do with the "
		+ "speaking voice.",
		func(v: float) -> void: Director.set_pacing(v))
	_tag("scenes", _scene_hold.get_parent())
	_flourish = Card.slider_row(self, "Flourishes", Director.FLOURISH_MIN, Director.FLOURISH_MAX, 0.05,
		Director.flourish,
		"How often the show breaks its rhythm - a burst of two or three quick cuts, or a run of "
		+ "beat-synced punches on the current scene. 0 turns them off entirely, 1 is the default. "
		+ "Set this to 0 first if the cutting feels busy: it separates 'too often' from 'too fast'.",
		func(v: float) -> void: Director.set_flourish(v))
	_tag("scenes", _flourish.get_parent())
	_camera = Card.slider_row(self, "Camera", Director.CAMERA_MIN, Director.CAMERA_MAX, 0.05,
		Director.camera,
		"How severe the camera is - one knob over the whole behavior. 0 is a slow gentle drift "
		+ "that barely turns and never cuts; 1 is the default; 2 is fast, restless and cinematic, "
		+ "with real jump cuts. It scales how far a shot may swing, how many shots that swing is "
		+ "spread over, how long a move lasts and how deep a push goes. It is shown only for the "
		+ "formats that fly a camera.",
		func(v: float) -> void: Director.set_camera(v))
	_tag("camera", _camera.get_parent())
	_hand_pick = _hand_option()
	_build_own(ctx)
	sync_medium()
	Director.medium_changed.connect(sync_medium)


## The format's own rows, for the format the note's block names (else the one this run shows): built from
## its row's `card` and handed [param ctx]. None for a format the note cannot have, which is waiting.
func _build_own(ctx: Dictionary) -> void:
	var blocks: Dictionary = ctx.get("blocks", {})
	var block: Variant = blocks.get(KEY)
	var fmt := String((block as Dictionary).get("format", "")) if block is Dictionary else ""
	if fmt.is_empty():
		fmt = _fmt if _episodic else Director.resolved_medium()
	var path := _card_of(fmt)
	if path.is_empty() or not _keys.has(fmt):
		return
	var script: GDScript = load(path) as GDScript
	if script == null:
		push_warning("ghost: the %s format's rows are not built - no script at %s" % [fmt, path])
		return
	_own = script.call("for_note", ctx) as Control
	_own_card = path
	if _own.has_signal("noted"):
		_own.connect("noted", func(msg: String) -> void: noted.emit(msg))
	var line := HSeparator.new()
	line.modulate = Color(1, 1, 1, 0.35)
	add_child(line)
	_own.set_meta("line", line)
	add_child(_own)


## The script of [param key]'s own rows ([constant Medium.REGISTRY] `card`), "" for a format with none.
static func _card_of(key: String) -> String:
	return String(Registry.field(Medium.REGISTRY, key, "card", ""))


## Show only what the format can use. Asked of the Director, not the picker: a picker driven from code
## has the `item_selected` signal without the index, and `resolved_medium` also knows a run launched
## with `--medium comic`.
func sync_medium() -> void:
	var key := _fmt if _episodic else Director.resolved_medium()
	var bare := not Medium.takes_settings(key) or not _held.is_empty()
	for row in _setting_rows:
		(row as Control).visible = not bare
	Medium.show_rows(_medium_rows, key)
	if bare:
		for tag in _medium_rows:
			for row in _medium_rows[tag] as Array:
				if is_instance_valid(row):
					(row as Control).visible = false
	if _own != null and is_instance_valid(_own):
		var mine := _held.is_empty() and _card_of(key) == _own_card
		_own.visible = mine
		(_own.get_meta("line") as Control).visible = mine
	if not _held.is_empty():
		var held := String(_held.get("format", ""))
		_waiting.text = ("⚠  The note is shown as %s, which shows a reading - attach a Voice, or pick another format."
			% Registry.label(Medium.REGISTRY, held))
		_format_pick.select(-1)
	elif _keys.has(_shown()):
		_format_pick.select(_keys.find(_shown()))
	_waiting.visible = not _held.is_empty()
	_sync_frames()


## The format the picker shows: the block's at a table show, else the remembered medium.
func _shown() -> String:
	return _fmt if _episodic else Director.medium


## A format that takes no settings was picked: the dials go back to their defaults, so what it shows is
## the same for every note (see [AutoMedium]).
func _to_defaults() -> void:
	_scene_hold.value = 1.0
	_flourish.value = 1.0
	_camera.value = 1.0
	Director.set_frame("landscape")


## The block for a document: the format, and only what it uses - its shared rows' values and its own rows' block. A
## format the note cannot have is its block as it was.
func capture() -> Dictionary:
	if not _held.is_empty():
		return _held.duplicate(true)
	if _episodic:
		if not _kept.is_empty():
			return _kept.duplicate(true)
		var mine := {"format": _fmt}
		if _own != null and _card_of(_fmt) == _own_card:
			mine.merge(_own.call("capture") as Dictionary, false)
		return mine
	var key := Director.medium
	var out := {"format": key}
	if not Medium.takes_settings(key):
		return out
	out["frame"] = Director.frame
	if Medium.uses(key, "scenes"):
		out["scene_hold"] = snappedf(Director.pacing, 0.01)
		out["flourishes"] = snappedf(Director.flourish, 0.01)
	if Medium.uses(key, "camera"):
		out["camera"] = snappedf(Director.camera, 0.01)
	if Medium.uses(key, "handwriting"):
		out["hand"] = Director.hand
	if Medium.uses(key, "films"):
		out["film_frequency"] = snappedf(Films.frequency(), 0.01)
	if _own != null and _card_of(key) == _own_card:
		out.merge(_own.call("capture") as Dictionary, false)
	return out


## ...and back. Each key the block names is set through the control a hand would use, so the card shows
## it and the Director saves it; a key it does not name is left alone. A block whose format has other own
## rows than the ones built (an edit made outside Ghost Notes) opens the note again around them.
func apply(block: Dictionary) -> void:
	var fmt := String(block.get("format", ""))
	if _episodic:
		if _keys.has(fmt):
			_fmt = fmt
			_kept = {}
		elif not fmt.is_empty():
			_kept = block.duplicate(true)
		if _own != null and _card_of(_fmt) == _own_card:
			_own.call("apply", block)
		sync_medium()
		return
	if Medium.REGISTRY.has(fmt) and Medium.mode_of(fmt).is_empty() and not _keys.has(fmt):
		_held = block.duplicate(true)
		sync_medium()
		return
	_held = {}
	if _keys.has(fmt) and fmt != Director.medium:
		Director.set_medium(fmt)
		_format_pick.select(_keys.find(fmt))
		if not Medium.takes_settings(fmt):
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
	if _own != null and _card_of(fmt) == _own_card:
		_own.call("apply", block)
	elif _keys.has(fmt) and _card_of(fmt) != _own_card and _reshape.is_valid():
		_reshape.call_deferred()
	sync_medium()


## What the format's own rows hand the note's Pipeline card (the Letter's sketches), null for none.
func pipeline() -> PipelineSection:
	if _own != null and _own.has_method("pipeline"):
		return _own.call("pipeline") as PipelineSection
	return null


## The format's own rows, null for a format with none.
func own() -> Control:
	return _own


func _process(_delta: float) -> void:
	_pump_films()


func _tag(feature: String, row: Control) -> void:
	(_medium_rows.get_or_add(feature, []) as Array).append(row)


## The format picker: what the show is carried on (see [Medium]). Built off the registry, so a new
## presentation appears by being registered. It sits at the top of the card, as the settings below are
## qualified by it. A format impossible on this machine ([constant Medium.REGISTRY] `capabilities`) is
## grayed, saying why.
func _format_option() -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var l := Label.new()
	l.text = "Format"
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
		opt.add_item(Registry.label(Medium.REGISTRY, k))
		var why := Capabilities.impossible_any(Registry.field(Medium.REGISTRY, k, "capabilities", []) as Array)
		opt.set_item_disabled(opt.item_count - 1, not why.is_empty())
		opt.set_item_tooltip(opt.item_count - 1, Registry.blurb(Medium.REGISTRY, k) + ("" if why.is_empty() else "\n\n" + why))
		tip += "\n%s - %s" % [Registry.label(Medium.REGISTRY, k), Registry.blurb(Medium.REGISTRY, k)]
	opt.tooltip_text = tip
	# The Director is the truth for this one (a whole-app setting the export render reads), so the
	# picker drives the setter, which persists it through Settings.
	opt.select(maxi(0, keys.find(_shown())))
	opt.item_selected.connect(_pick)
	row.add_child(opt)
	return opt


## The format picked: set, and where its own rows are not the ones standing, the note opened again around them.
func _pick(i: int) -> void:
	if i < 0 or i >= _keys.size():
		return
	var k := String(_keys[i])
	_held = {}
	if _episodic:
		_fmt = k
		_kept = {}
		sync_medium()
		noted.emit("Format: %s - the next episode is made for it; each is shown in the one it was made for." % Registry.label(Medium.REGISTRY, k))
		return
	if not Medium.takes_settings(k):
		_to_defaults()
	Director.set_medium(k)
	var label := Registry.label(Medium.REGISTRY, k)
	if _card_of(k) != _own_card and _reshape.is_valid():
		noted.emit("Format: %s - the note opens again with its settings." % label)
		_reshape.call_deferred()
		return
	sync_medium()
	noted.emit("Format: %s%s" % [label, " - takes effect on the next reading." if _reading else "."])


## The frame: landscape 16:9 or portrait 9:16 (next/notes.md), a property of the show kept beside the
## format. Only what the format can be shown in is offered (its row's `frames`, [method Medium.frames]);
## a frame it cannot is grayed, saying so, and the show plays in landscape.
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
		if ok else "%s has no portrait frame yet - it frames a spread or a desk a 9:16 view cannot hold - so the show is landscape."
			% Registry.label(Medium.REGISTRY, Director.resolved_medium()))


## The handwriting, the Notebook's and the Letter's (the Letter is written in the Notebook's hands,
## [Handwriting]): a named hand, or Random.
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
	opt.tooltip_text = "The hand the words are written in, each stroke drawn by the pen. Random draws one: per " \
		+ "session in the Notebook, which changes whenever the audio does; from the note's own number in a Letter, so " \
		+ "it is written the same way every time. A named hand stays put, and travels with the note. In a Letter, " \
		+ "where the lines and pages break follows it, so the voice's rests do too."
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
# The film library sits under the format picker because it only means anything to the comic, and it is
# hidden when the medium cannot use it: a control that does nothing teaches nothing, and the picker is
# the row directly above, so the controls appear where the eye already is.

## The film library block: the list, an import button and the frequency dial, in a group of its own so
## the block is shown or hidden as one (see a format's `uses`).
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


## Rebuild the list of imported clips (a handful of rows, so no diff).
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
		l.text = "  %s  ·  %s" % [String(c.get("name", "clip")), Clock.text(dur)]
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
	# In-window, never native: the portal dialog shows nothing on a Linux box without
	# xdg-desktop-portal (Masking's own importer carries the same note).
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


## Adding a clip is instant: there is no transcode, a clip is prepared a window at a time when something
## wants to play it (see Films.WINDOW), so this reads a duration and writes a row.
func _start_film_import(source: String) -> void:
	var err := Films.add(source)
	if not err.is_empty():
		_film_status.text = "⚠  " + err
		return
	_film_status.text = "✓  Added %s" % source.get_file().get_basename()
	_refresh_films()


## Polled from _process: a window cut is a subprocess, so something with a frame must notice it finished.
## [FilmScene] does the same while a panel is live, which between them covers every moment one is awaited.
func _pump_films() -> void:
	Films.pump()
	# The status line follows the cutting rather than a one-shot import.
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
