extends VBoxContainer
class_name VoiceTrainingCard

## VoiceTrainingCard - the Voice training component's card: teaches a voice to speak as someone does, from their
## own recordings, and the note reads in it (next/likeness.md, "A voice alone"). The user, 2026-10-26: "a new
## component/card, which we could attach to a note that already has the "Voice" component, to fine-tune a new
## voice for that component ... importing a video from file, or by pointing to a YouTube URL or playlist URL."
##
## A PERSON OF THE [Actors] LIBRARY WHOSE VOICE IS ALL THAT IS LEARNED OF THEM (A VOICE ALONE, [method
## ActorFolder.sound_only]) - their recordings (a folder, files, or links to videos, playlists or a channel, fetched as
## their sound) and the voice's steps over them ([method ActorSteps.voice_chain]: Fetch, Probe, Hear, Utterances,
## Voice), run by the Actor card's [ActorBuilder] and shown by its parts ([ActorSourceList], [ActorStepRows]).
## KOKORO IS TAUGHT THEM (2026-10-26, the user: "I likely won't use Piper models for anything other than testing now,
## given that Kokoro is so much better-sounding ... our own custom training loop would probably be perfectly fine"):
## its decoder and prosody predictor, on their sentences, on the graphics card (hosts/voice_train/kokoro_voice.py),
## and the voice written into Kokoro's own graph is published where the voice host lists Kokoro voices taught here:
## THE NOTE READS IN IT AS IT LANDS ([method ReadingPanel.voice_made]), Read in it picks it again later, and every
## Voice card lists it as "<name> (their own voice)".
##
## GENERATION IS EXPLICIT: nothing runs on open (Hear takes about a seventh of the recordings' length on the
## processor, the Voice about an hour on the graphics card). Stop keeps what is learned, and ▶ goes on from it. A
## machine that cannot train ([method ActorBuilder.cannot_train]) says why on the rows.

## The block this card keeps under a document's `ghost:` key.
const KEY := "voice_training"
## The block: the voice alone this note trains.
const KNOBS := {"id": ""}

signal noted(text: String)

var _knobs := KNOBS.duplicate(true)
var _voice: ActorFolder = null
var _builder: ActorBuilder = null
var _syncing := false
var _row_t := 0.0

var _pick: OptionButton
var _picked: Array = []
var _body: VBoxContainer       # everything below the picker: hidden with no one picked
var _name: LineEdit
var _sources: ActorSourceList
var _steps: ActorStepRows
var _gen_btn: Button
var _stop_btn: Button
var _read_btn: Button
var _line: Label
var _lessons: SpinBox
## The reading this card is on (it brings a Voice, so there is one): its status line says what the card says, and
## the voice made is read in it. Without one (a gate) the card only builds, and `noted` says.
var _panel: ReadingPanel = null


static func for_note(ctx: Dictionary) -> VoiceTrainingCard:
	var card := VoiceTrainingCard.new()
	card._panel = ctx.get("workspace") as ReadingPanel
	card._build()
	return card


func _exit_tree() -> void:
	if _builder != null:
		_builder.stop()


func _process(delta: float) -> void:
	_row_t -= delta
	if _row_t > 0.0:
		return
	_row_t = 0.25
	if _builder != null:
		_builder.tick()
	_refresh()


# --- the block ---------------------------------------------------------------------------------

func capture() -> Dictionary:
	return _knobs.duplicate(true)


func apply(cfg: Dictionary) -> void:
	var was := String(_knobs["id"])
	_knobs = KNOBS.duplicate(true)
	for k in KNOBS:
		if cfg.has(k):
			_knobs[k] = String(cfg[k])
	if String(_knobs["id"]) != was or _voice == null:
		_open(String(_knobs["id"]))


# --- whose voice ---------------------------------------------------------------------------------

func _open(id: String) -> void:
	if _builder != null:
		_builder.stop()
	_voice = Actors.open(id) if not id.is_empty() else null
	_builder = ActorBuilder.new(_voice) if _voice != null else null
	if _builder != null:
		_builder.voice_published.connect(_voice_made)
		ActorSources.rescan(_voice)
		_voice.save()
	_sources.show_actor(_voice, _builder)
	_steps.show_actor(_voice, _builder)
	_fill_pick()
	_show_voice()
	_refresh()


func _fill_pick() -> void:
	_syncing = true
	_pick.clear()
	_picked = []
	for a in Actors.list("voice"):
		_pick.add_item(String(a["name"]))
		_picked.append(String(a["id"]))
		if String(a["id"]) == String(_knobs["id"]):
			_pick.select(_pick.item_count - 1)
	_pick.add_separator()
	_picked.append("")
	_pick.add_item("New voice…")
	_picked.append("+new")
	if _voice == null:
		_pick.select(-1)
		_pick.text = "Pick a voice"
	_syncing = false


func _on_pick(i: int) -> void:
	if _syncing or i < 0 or i >= _picked.size():
		return
	var id := String(_picked[i])
	if id == "+new":
		_ask_name()
		return
	if id.is_empty():
		return
	_knobs["id"] = id
	_open(id)


func _ask_name() -> void:
	var ask := ConfirmationDialog.new()
	ask.title = "New voice"
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = "Whose voice - the person in the recordings:"
	box.add_child(l)
	var field := LineEdit.new()
	field.custom_minimum_size.x = 320
	box.add_child(field)
	ask.add_child(box)
	ask.ok_button_text = "Make"
	ask.confirmed.connect(func() -> void:
		var a := Actors.create(field.text, "voice")
		ask.queue_free()
		_knobs["id"] = a.id
		_open(a.id)
		_say("A new voice, %s: add their recordings - a folder, files or a link - then Generate." % a.name()))
	ask.canceled.connect(func() -> void:
		ask.queue_free()
		_fill_pick())
	add_child(ask)
	ask.popup_centered(Vector2i(380, 0))
	field.grab_focus()


func _show_voice() -> void:
	_body.visible = _voice != null
	if _voice == null:
		return
	_syncing = true
	_name.text = _voice.name()
	_lessons.set_value_no_signal(float(_voice.settings()["kokoro_steps"]))
	_syncing = false


## THEIR VOICE HAS LANDED: the reading this card is on asks for its voices again and reads in it
## ([method ReadingPanel.voice_made]) - the list was asked for when the note opened, an hour or more before.
func _voice_made(voice: String) -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.voice_made(voice)


## Is their voice made (stale or not)?
func made() -> bool:
	return _voice != null and _voice.state_of("kokoro_voice", "") != "missing"


func _say(text: String) -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.status(text)
	else:
		noted.emit(text)


# --- the steps ----------------------------------------------------------------------------------

## GENERATE: their voice and what it is made from, where missing or stale - never anything of a picture.
func _generate() -> void:
	if _builder == null:
		return
	if _voice.ticked().is_empty():
		_say("Add their recordings first - a folder, files or a link - and tick the ones that are them.")
		return
	_builder.start(ActorSteps.voice_chain())
	_say("Generating their voice: each recording fetched and heard (about a seventh of its length), their sentences cut, then about an hour of Kokoro's lessons on the graphics card.")


func _refresh() -> void:
	if _voice == null or _builder == null:
		return
	_voice.forget()
	_sources.refresh()
	var busy := _builder.running or _builder.busy()
	_gen_btn.disabled = busy
	_stop_btn.disabled = not busy
	_steps.refresh(busy)
	var ready := made()
	_read_btn.disabled = not ready or _panel == null
	var line := ""
	if not _builder.waiting.is_empty():
		line = "Waiting: %s - Ghost Notes fetches these itself, once (see ⚙ for progress)." % _builder.waiting
	elif ready:
		line = "Their voice is made: \"%s\" on every Voice card." % ActorBuilder.voice_name(_voice)
	elif _voice.ticked().is_empty():
		line = "Half an hour or more of their ordinary speaking voice is plenty: one person, little noise or music under it."
	_line.text = line


# --- the card itself -----------------------------------------------------------------------------

func _build() -> void:
	add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	_pick = OptionButton.new()
	_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pick.fit_to_longest_item = false
	_pick.clip_text = true
	_pick.focus_mode = Control.FOCUS_NONE
	_pick.tooltip_text = "Whose voice this note trains - each kept apart from the actors, and on every Voice card once made - or a new one."
	_pick.item_selected.connect(_on_pick)
	top.add_child(_pick)
	var folder := Button.new()
	folder.text = "Folder"
	folder.tooltip_text = "Open the voice's folder: their fetched sound, every step's files and logs, the sentences it is taught on."
	folder.pressed.connect(func() -> void:
		if _voice != null:
			OS.shell_open(_voice.dir))
	top.add_child(folder)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	add_child(_body)
	var nrow := HBoxContainer.new()
	_body.add_child(nrow)
	var nl := Label.new()
	nl.text = "Name"
	nl.custom_minimum_size.x = 64
	nl.add_theme_font_size_override("font_size", 12)
	nrow.add_child(nl)
	_name = LineEdit.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.tooltip_text = "Their name: the voice is listed as \"<name> (their own voice)\" (taken when it is made)."
	_name.text_changed.connect(func(t: String) -> void:
		if _syncing or _voice == null:
			return
		_voice.data["name"] = t.strip_edges()
		_voice.save())
	nrow.add_child(_name)

	_body.add_child(ActorCard.heading("Recordings"))
	_sources = ActorSourceList.new()
	_sources.said.connect(_say)
	_body.add_child(_sources)

	_body.add_child(ActorCard.heading("Steps"))
	_steps = ActorStepRows.new(ActorSteps.voice_chain())
	_steps.said.connect(_say)
	_body.add_child(_steps)
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 6)
	_body.add_child(grow)
	_gen_btn = Button.new()
	_gen_btn.text = "Generate"
	_gen_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gen_btn.tooltip_text = "Make their voice and whatever it needs that is missing or stale, in order: each recording fetched (its sound alone) and heard, their sentences cut, then Kokoro's lessons on the graphics card - about an hour."
	_gen_btn.pressed.connect(_generate)
	grow.add_child(_gen_btn)
	_stop_btn = Button.new()
	_stop_btn.text = "Stop"
	_stop_btn.tooltip_text = "Stop now. What is finished is kept, and the lessons go on from their last save (a few minutes back) at the next Generate."
	_stop_btn.pressed.connect(func() -> void:
		if _builder != null:
			_builder.stop())
	grow.add_child(_stop_btn)
	_read_btn = Button.new()
	_read_btn.text = "Read in it"
	_read_btn.tooltip_text = "Read this note in their voice: the Voice card's reader is set to it."
	_read_btn.pressed.connect(func() -> void:
		if _voice != null and made():
			_voice_made(ActorBuilder.voice_id(_voice)))
	grow.add_child(_read_btn)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 11)
	_line.modulate = Color(1, 1, 1, 0.7)
	_body.add_child(_line)

	var row: Dictionary = ActorSteps.SETTINGS["kokoro_steps"]
	var r := HBoxContainer.new()
	_body.add_child(r)
	var l := Label.new()
	l.text = String(row["label"])
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 12)
	l.tooltip_text = String(row["blurb"])
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	r.add_child(l)
	_lessons = SpinBox.new()
	_lessons.min_value = float(row["min"])
	_lessons.max_value = float(row["max"])
	_lessons.step = float(row["step"])
	_lessons.value = float(row["default"])
	_lessons.tooltip_text = String(row["blurb"])
	_lessons.value_changed.connect(func(v: float) -> void:
		if _syncing or _voice == null:
			return
		(_voice.data["settings"] as Dictionary)["kokoro_steps"] = v
		_voice.save())
	r.add_child(_lessons)
	_body.visible = false
	_fill_pick()
