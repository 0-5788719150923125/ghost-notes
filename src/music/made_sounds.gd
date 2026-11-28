extends VBoxContainer
class_name MadeSounds

## MadeSounds - the sounds a show made for the note on its own, on the Sound card under its sound effects: each a show says it makes
## ([ShowSounds]) an entry ([EntryCard]) - what it is, what it is now, and opened, Test (heard alone) and, where the show can change
## it, Refine… (a conversation with a writer, [TextRefine], [method ShowSounds.chat_of]); where the show sets one, its Level and Muffle,
## and the same for all of them at once, heard at once ([method ShowSounds.level_of]). Its × stands grayed: a show's
## sound is there because the show makes it, and making it again is its row's on the Pipeline card. Read again each second while it
## is shown, and rebuilt only when what it lists changed.

## How often what it lists is read again (s).
const EVERY := 1.0
## A sound's Level, least and most (dB); its Muffle as the Test hears it - the low-pass's corner unmuffled and fully muffled (Hz, as
## the show's own); and the Test's own bus.
const LEVEL_LEAST := -30.0
const LEVEL_MOST := 12.0
const MUFFLE_FROM := 9000.0
const MUFFLE_TO := 450.0
const TEST_BUS := &"MadeSoundsTest"

var _sources := Callable()      # () -> Array of ShowSounds
var _stamp := "-"               # what is listed, by key and line: rebuilt only when that changes
var _since := EVERY
var _list: VBoxContainer
var _player: AudioStreamPlayer
var _playing := ""               # the key heard now
var _open := {}                  # keys of the entries open
var _paths := {}                 # key -> its sound file, as listed
var _chats := {}                 # key -> the show's conversation that changes it ([method ShowSounds.chat_of]), where it has one
var _refines := {}               # key -> its Refine… ([TextRefine]), once opened
var _sources_of := {}            # key -> the show that makes it, where it sets its level ([method ShowSounds.level_of])


func _init() -> void:
	add_theme_constant_override("separation", 6)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)
	_player = AudioStreamPlayer.new()
	_player.finished.connect(func() -> void:
		_playing = ""
		_stamp = "-")
	add_child(_player)
	visible = false


## Where its sounds come from: [param sources] () -> an Array of [ShowSounds].
func follow(sources: Callable) -> void:
	_sources = sources
	refresh()


func _process(delta: float) -> void:
	_since += delta
	if _since >= EVERY:
		refresh()


## What the shows make now, read again: rebuilt only when it changed. Whether there is any.
func refresh() -> bool:
	_since = 0.0
	var groups: Array = []
	var parts := PackedStringArray([_playing])
	for s in (_sources.call() if _sources.is_valid() else []):
		if not (s is ShowSounds):
			continue
		var list: Array = (s as ShowSounds).sounds()
		if list.is_empty():
			continue
		groups.append({"heading": (s as ShowSounds).heading(), "sounds": list, "source": s})
		for r in list:
			parts.append("%s=%s=%s" % [String((r as Dictionary)["key"]), String((r as Dictionary).get("line", "")), String((r as Dictionary).get("path", ""))])
	var stamp := "|".join(parts)
	if stamp != _stamp:
		_stamp = stamp
		_build(groups)
	visible = not groups.is_empty()
	return visible


## The keys listed now, in order.
func listed() -> PackedStringArray:
	return PackedStringArray(_paths.keys())


func _build(groups: Array) -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_paths = {}
	for g in groups:
		var head := Label.new()
		head.text = String((g as Dictionary)["heading"])
		head.add_theme_font_size_override("font_size", 12)
		head.modulate = Color(1, 1, 1, 0.7)
		_list.add_child(head)
		var src: ShowSounds = (g as Dictionary)["source"] if (g as Dictionary).get("source") is ShowSounds else null
		# every sound of the show at once: its Level and Muffle under each one's own
		if src != null and not src.level_of("").is_empty():
			_list.add_child(_levels_row(src, "", "All of them", "every sound the show makes here"))
		for r in (g as Dictionary)["sounds"]:
			var key := String((r as Dictionary)["key"])
			var path := String((r as Dictionary).get("path", ""))
			_paths[key] = path
			var chat: WriterChat = (g as Dictionary)["source"].chat_of(key) if (g as Dictionary).get("source") is ShowSounds else null
			var e := EntryCard.new(String((r as Dictionary)["name"]), String((r as Dictionary).get("line", "")), String((r as Dictionary).get("tip", "")))
			e.set_remove(Callable(), "", "Made by the show, and kept. To make it again, use its row on the Pipeline card.")
			e.open = _open.has(key)
			e.toggled.connect(func(o: bool) -> void:
				if o:
					_open[key] = true
				else:
					_open.erase(key))
			var test := Button.new()
			test.text = "■ Stop" if _playing == key else "▶ Test"
			test.tooltip_text = "Hear it alone, as it is made now." if not path.is_empty() else "It is not made yet: Generate on the Pipeline card makes it."
			test.disabled = path.is_empty() and _playing != key
			test.focus_mode = Control.FOCUS_NONE
			test.pressed.connect(test_sound.bind(key))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.add_child(test)
			if chat != null:
				_chats[key] = chat
				var refine := Button.new()
				refine.text = "Refine…"
				refine.toggle_mode = true
				refine.focus_mode = Control.FOCUS_NONE
				refine.tooltip_text = "Talk it over with a writer: say what to change (softer, slower, more to the left, the other hand) and it changes what the hands do; the sound is made again from that."
				var open: TextRefine = _refines.get(key)
				refine.set_pressed_no_signal(open != null and is_instance_valid(open) and RefineDock.is_open(open))
				refine.pressed.connect(_refine.bind(key, String((r as Dictionary)["name"]), refine))
				row.add_child(refine)
			e.options.add_child(row)
			if src != null and not src.level_of(key).is_empty():
				_sources_of[key] = src
				e.options.add_child(_levels_row(src, key, "", "this sound"))
			_list.add_child(e)


## The Level and Muffle of sound [param key] of [param src] (`""`: all of them), titled [param title] ("" for none): two sliders, each
## heard at once and kept by the show; [param what] says what they change.
func _levels_row(src: ShowSounds, key: String, title: String, what: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	if not title.is_empty():
		var t := Label.new()
		t.text = title
		t.add_theme_font_size_override("font_size", 12)
		box.add_child(t)
	var now := src.level_of(key)
	var level := _slider(box, "Level", LEVEL_LEAST, LEVEL_MOST, 0.5, float(now.get("db", 0.0)),
		"How loud %s is heard, in decibels: 0 as made, -6 about half, +6 about twice. Heard at once and in the export; nothing is made again." % what,
		func(v: float) -> String: return ("+%.1f dB" if v > 0.0 else "%.1f dB") % v)
	var muffle := _slider(box, "Muffle", 0.0, 1.0, 0.05, float(now.get("muffle", 0.0)),
		"How muffled %s is, as if heard through cloth: 0 as made, 1 thick and dark. Heard at once; nothing is made again." % what,
		func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	var write := func(_v: float) -> void:
		src.set_level(key, level.value, muffle.value)
		if _playing == key or (key.is_empty() and not _playing.is_empty()):
			_tone_test(_playing)
	level.value_changed.connect(write)
	muffle.value_changed.connect(write)
	return box


## A labeled slider in [param box], its value shown by [param shown].
func _slider(box: Control, label: String, lo: float, hi: float, step: float, value: float, tip: String, shown: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(56, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = value
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.tooltip_text = tip
	sl.focus_mode = Control.FOCUS_NONE
	row.add_child(sl)
	var r := Label.new()
	r.custom_minimum_size = Vector2(56, 0)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_theme_font_size_override("font_size", 12)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = String(shown.call(value))
	sl.value_changed.connect(func(v: float) -> void: r.text = String(shown.call(v)))
	row.add_child(r)
	box.add_child(row)
	return sl


## The Test player heard as sound [param key] is: its level and every sound's, through its muffle and every sound's (the Test's own
## bus, [constant TEST_BUS], a low-pass on it).
func _tone_test(key: String) -> void:
	var src: ShowSounds = _sources_of.get(key)
	var own: Dictionary = src.level_of(key) if src != null else {}
	var all: Dictionary = src.level_of("") if src != null else {}
	_player.volume_db = float(own.get("db", 0.0)) + float(all.get("db", 0.0))
	var m := clampf(float(own.get("muffle", 0.0)) + float(all.get("muffle", 0.0)), 0.0, 1.0)
	var bus := AudioServer.get_bus_index(TEST_BUS)
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, TEST_BUS)
		AudioServer.set_bus_send(bus, "Master")
		AudioServer.add_bus_effect(bus, AudioEffectLowPassFilter.new())
	var lp := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	if lp != null:
		lp.cutoff_hz = MUFFLE_FROM * pow(MUFFLE_TO / MUFFLE_FROM, m)
	AudioServer.set_bus_effect_enabled(bus, 0, m > 0.001)
	_player.bus = TEST_BUS


## Sound [param key]'s Refine… as a toggle, docked beside the card ([RefineDock]); [param button] pressed while it is open.
func _refine(key: String, name: String, button: BaseButton) -> void:
	var r: TextRefine = _refines.get(key)
	if r == null or not is_instance_valid(r):
		if not _chats.has(key):
			return
		r = TextRefine.new(_chats[key], name)
		add_child(r)
		_refines[key] = r
	r.toggle(self, button)


## Sound [param key] heard alone, or stopped where it is the one heard.
func test_sound(key: String) -> void:
	if _playing == key:
		_player.stop()
		_playing = ""
		_stamp = "-"
		refresh()
		return
	var path := String(_paths.get(key, ""))
	var stream := AudioStreamWAV.load_from_file(path) if not path.is_empty() and FileAccess.file_exists(path) else null
	if stream == null:
		return
	_player.stream = stream
	_tone_test(key)
	_player.play()
	_playing = key
	_stamp = "-"
	refresh()


## Whatever is heard stopped.
func stop() -> void:
	_player.stop()
	_playing = ""
