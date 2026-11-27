extends VBoxContainer
class_name SoundEffectsPart

## SoundEffectsPart - the Sound card's sound effects (next/sound_effects.md): every sound the note's `<!-- sound: words -->` marks
## ask for, an entry each ([EntryCard]) under the designer picked to make them ([AgentPick]). An entry says what its sound is now
## (not made, its length and how it fades, the designer at work) and, opened, Test (heard alone), its versions (the one picked
## plays), Refine… (a conversation with the designer, [TextRefine]), Make again, Keep (to the library's Sounds shelf) and From the
## Dex… (a kept sound used as a new version). Each sound not yet made is a row of the Pipeline card's ([method rows]); Generate makes
## them ([method make_missing]). Its × stands grayed: a sound is there because its mark is, and goes with it.
##
## A part of the Sound card: the card hands it the note's words ([method refresh]) and keeps the designer picked in its block
## ([member chosen], `designer`).

## Something to say on the card's line.
signal noted(msg: String)

## The designer picked changed: `func(choice: Dictionary)`, kept in the card's block.
var chosen: Callable
## The note's title, for what the designer is told.
var title := ""

var _marks: Array = []           # [{key, words}] in the order first written
var _designs := {}               # key -> SoundDesign
var _open := {}                  # keys of the entries open
var _entries := {}               # key -> EntryCard
var _list: VBoxContainer
var _pick: AgentPick
var _empty: Label
var _player: AudioStreamPlayer
var _playing := ""               # the key heard now
var _dex: DexWindow = null
var _refines := {}               # key -> TextRefine
var _shown := {}                 # key -> the line last shown


func _init() -> void:
	add_theme_constant_override("separation", 6)
	var head := Label.new()
	head.text = "Sound effects"
	head.add_theme_font_size_override("font_size", 12)
	head.tooltip_text = "The sounds the note's script asks for with a sound mark, each made from its words by the designer below."
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(head)
	_pick = AgentPick.writer("Who designs the sounds: a writer who writes each sound as a patch the app synthesizes, hears it, and changes it until it fits its words.")
	_pick.changed.connect(func() -> void:
		if chosen.is_valid():
			chosen.call(_pick.choice()))
	add_child(_pick)
	_empty = Label.new()
	_empty.text = "No sound marks yet: a sound mark in the script (Dispatch desk: Sound) asks for one, made here from its words."
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.add_theme_font_size_override("font_size", 11)
	_empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	add_child(_empty)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)
	_player = AudioStreamPlayer.new()
	_player.finished.connect(func() -> void:
		_playing = ""
		_draw_list())
	add_child(_player)


## The designer picked, from the card's block.
func set_pick(choice: Dictionary) -> void:
	if not choice.is_empty():
		_pick.set_choice(String(choice.get("agent", "")), String(choice.get("model", "")), String(choice.get("effort", "")))


## The note's words as they stand: the sounds they ask for listed again.
func refresh(words: String) -> void:
	var marks := SoundEffects.marks_in(words)
	if JSON.stringify(marks) == JSON.stringify(_marks):
		return
	_marks = marks
	for m in _marks:
		_design(String((m as Dictionary)["key"]), String((m as Dictionary)["words"]))
	_draw_list()


## Whether the note asks for any sound.
func has_sounds() -> bool:
	return not _marks.is_empty()


func _design(key: String, words: String) -> SoundDesign:
	if not _designs.has(key):
		var d := SoundDesign.new(key, words, title)
		d.changed.connect(func() -> void: _show_line(key))
		_designs[key] = d
	return _designs[key]


func _process(_delta: float) -> void:
	for k in _designs:
		(_designs[k] as SoundDesign).poll()


# --- the list ---------------------------------------------------------------------------------------

func _draw_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_entries = {}
	_shown = {}
	_empty.visible = _marks.is_empty()
	for m in _marks:
		var key := String((m as Dictionary)["key"])
		var words := String((m as Dictionary)["words"])
		var e := EntryCard.new(words.left(64) + ("…" if words.length() > 64 else ""), line_of(key), words)
		e.set_remove(Callable(), "", "A sound is here because a sound mark in the script asks for it: take the mark out to take it away.")
		e.open = _open.has(key)
		e.toggled.connect(func(o: bool) -> void:
			if o:
				_open[key] = true
			else:
				_open.erase(key))
		_fill(e, key, words)
		_list.add_child(e)
		_entries[key] = e
		_shown[key] = line_of(key)


## Entry [param key]'s line as it stands now, said again only when it changed.
func _show_line(key: String) -> void:
	var e: EntryCard = _entries.get(key)
	if e == null or not is_instance_valid(e):
		return
	var line := line_of(key)
	if line != String(_shown.get(key, "")):
		_shown[key] = line
		e.line_label.text = line
		var d: SoundDesign = _designs.get(key)
		if d != null and not d.busy():
			_draw_list()                 # a version made or chosen: its options drawn again
		else:
			noted.emit("%s: %s" % [SoundLibrary.name_for(String(d.words if d != null else "")), line])


## What sound [param key] is now, in a line.
func line_of(key: String) -> String:
	var d: SoundDesign = _designs.get(key)
	if d != null and not d.doing.is_empty():
		return "⏳  " + d.doing
	if d != null and not d.error.is_empty():
		return "⚠  " + d.error
	var vs := SoundEffects.versions(key)
	if vs.is_empty():
		return "Not made yet: Generate makes it from its words."
	var made := SoundEffects.made(key)
	if made.is_empty():
		return "Version %d is not made into sound yet: Make again." % (SoundEffects.used(key) + 1)
	return "Version %d of %d  ·  %s" % [SoundEffects.used(key) + 1, vs.size(), heard_line(made.get("heard", {}), float(made["secs"]))]


## What a sound sounds like, in a line: its length, the voice's wait, how it ends.
static func heard_line(h: Dictionary, secs: float) -> String:
	if h.is_empty():
		return ""
	var fade: Variant = h.get("fade")
	return "%.1f s (the voice waits %.1f)  ·  %s" % [float(h.get("seconds", 0.0)), secs,
		("fades out over %.1f s" % float(fade)) if fade != null else "ends abruptly"]


func _fill(e: EntryCard, key: String, words: String) -> void:
	var o := e.options
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	o.add_child(row)
	var wav := SoundEffects.made(key).get("wav", "") as String
	var test := _button("■ Stop" if _playing == key else "▶ Test", "Hear the sound alone, as it is made now.", func() -> void: _test(key))
	test.disabled = wav.is_empty() and _playing != key
	row.add_child(test)
	var refine := _button("Refine…", "Talk the sound over with its designer: say what to change (a longer, slower fade; more weight; further away), and each change is a new version.", func() -> void: pass)
	refine.toggle_mode = true
	var open: TextRefine = _refines.get(key)
	refine.set_pressed_no_signal(open != null and is_instance_valid(open) and RefineDock.is_open(open))
	refine.pressed.connect(func() -> void: _refine(key, words, refine))
	row.add_child(refine)
	var again := _button("Make again", "Make the version picked into sound again.", func() -> void: _design(key, words).make())
	again.disabled = SoundEffects.versions(key).is_empty()
	row.add_child(again)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	o.add_child(row2)
	var vs := SoundEffects.versions(key)
	if vs.size() > 1:
		var pick := OptionButton.new()
		pick.tooltip_text = "Which version plays. Every version is kept."
		for i in vs.size():
			var p: Dictionary = (vs[i] as Dictionary).get("patch", {})
			pick.add_item("Version %d  ·  %.1f s" % [i + 1, float(p.get("secs", 0.0)) + float(p.get("tail", 0.0))])
		pick.select(SoundEffects.used(key))
		pick.item_selected.connect(func(i: int) -> void:
			SoundEffects.use(key, i)
			if SoundEffects.made(key).is_empty():
				_design(key, words).make(i)
			_draw_list())
		row2.add_child(pick)
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 6)
	o.add_child(lr)
	var ll := Label.new()
	ll.text = "Level"
	ll.custom_minimum_size = Vector2(72, 0)
	ll.add_theme_font_size_override("font_size", 12)
	ll.tooltip_text = "How loud the sound is played, in dB over as it was made: 0 as made, down to quieten it, up to bring it forward. Nothing is made again."
	ll.mouse_filter = Control.MOUSE_FILTER_STOP
	lr.add_child(ll)
	var sl := HSlider.new()
	sl.min_value = SoundEffects.LEVEL_RANGE.x
	sl.max_value = SoundEffects.LEVEL_RANGE.y
	sl.step = 0.5
	sl.value = SoundEffects.level_of(key)
	sl.tooltip_text = ll.tooltip_text
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.editable = not SoundEffects.versions(key).is_empty()
	lr.add_child(sl)
	Card.readout(lr, sl, " dB")
	sl.value_changed.connect(func(db: float) -> void:
		SoundEffects.set_level(key, db)
		if _playing == key:
			_player.volume_db = db)
	var keep := _button("Keep", "Keep this sound in your library, to use on any note (the Dex's Sounds shelf).", func() -> void: _keep(key, words))
	keep.disabled = wav.is_empty()
	row2.add_child(keep)
	row2.add_child(_button("From the Dex…", "Use a sound kept in your library as this sound's new version.", func() -> void: _from_dex(key, words)))


func _test(key: String) -> void:
	if _playing == key:
		_player.stop()
		_playing = ""
		_draw_list()
		return
	var wav := String(SoundEffects.made(key).get("wav", ""))
	var stream := AudioStreamWAV.load_from_file(wav) if not wav.is_empty() else null
	if stream == null:
		noted.emit("⚠  The sound could not be read: make it again.")
		return
	_player.stream = stream
	_player.volume_db = SoundEffects.level_of(key)
	_player.play()
	_playing = key
	_draw_list()


## Its Refine… as a toggle: the conversation docked beside the card in its panel ([RefineDock]), or folded away where it stands open;
## [param button] pressed while it is open.
func _refine(key: String, words: String, button: BaseButton = null) -> void:
	var r: TextRefine = _refines.get(key)
	if r == null or not is_instance_valid(r):
		r = TextRefine.new(_design(key, words).chat, "the sound \"%s\"" % SoundLibrary.name_for(words))
		add_child(r)
		_refines[key] = r
	r.toggle(self, button)


func _keep(key: String, words: String) -> void:
	var why := SoundLibrary.keep(SoundLibrary.name_for(words), words, SoundEffects.patch_of(key), String(SoundEffects.made(key).get("wav", "")))
	noted.emit("⚠  " + why if not why.is_empty() else "✓  Kept in your library: %s" % SoundLibrary.name_for(words))


func _from_dex(key: String, words: String) -> void:
	if _dex == null or not is_instance_valid(_dex):
		_dex = DexWindow.new()
		add_child(_dex)
	_dex.open([SoundShelf.new(func(name: String) -> void:
		var kept := SoundLibrary.find(name)
		if not kept.is_empty():
			var v := SoundEffects.add_version(key, words, kept["patch"])
			if v >= 0:
				_design(key, words).make(v)
		_dex.hide())], func(err: String) -> void:
		if not err.is_empty():
			noted.emit("⚠  " + err))


func _button(text: String, tip: String, act: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(act)
	return b


# --- what the Pipeline card shows -------------------------------------------------------------------

## A row for each sound ([PipelineRow]): made, missing, or being made; its ⟳ asks the designer for it again.
func rows() -> Array:
	var out: Array = []
	for m in _marks:
		var key := String((m as Dictionary)["key"])
		var words := String((m as Dictionary)["words"])
		var d := _design(key, words)
		var r := PipelineRow.new("sound:" + key, "Sound: " + SoundLibrary.name_for(words))
		r.state = "running" if d.busy() else ("made" if not SoundEffects.made(key).is_empty() else "missing")
		r.said = line_of(key)
		r.again = "Ask the designer to make this sound again from its words: a new version (the ones before it stay)."
		r.redo = func() -> void: _generate(key, words)
		out.append(r)
	return out


## Whether a sound is not made yet.
func missing() -> bool:
	for m in _marks:
		if SoundEffects.versions(String((m as Dictionary)["key"])).is_empty():
			return true
	return false


## Whether a sound is being made.
func busy() -> bool:
	for k in _designs:
		if (_designs[k] as SoundDesign).busy():
			return true
	return false


## Every sound not yet made asked of the designer.
func make_missing() -> void:
	for m in _marks:
		var key := String((m as Dictionary)["key"])
		if SoundEffects.versions(key).is_empty() and not _design(key, String(m["words"])).busy():
			_generate(key, String((m as Dictionary)["words"]))


## Every sound being made stopped.
func stop() -> void:
	for k in _designs:
		(_designs[k] as SoundDesign).chat.stop()


func _generate(key: String, words: String) -> void:
	var why := _design(key, words).generate(_pick.choice())
	if not why.is_empty():
		noted.emit("⚠  " + why)
