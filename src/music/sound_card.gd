extends VBoxContainer
class_name SoundCard

## SoundCard - the note's Sound (next/music.md): what the show is timed by and heard with. Its first row is its
## Source - a file the note plays (what the Song card was), or a song COMPOSED for the note - mirroring the Medium
## card's Format: a way of making the sound is a source on one card, never a second component. Its block is `sound:`;
## a note written before keeps `song: {path}`, read as a file.
##
## Composed, the card is choices, not a DAW: a REFERENCE (a song file the importer reads for its grid, key, chords,
## form, drums and melody - never its sound), the tempo and key (the reference's, or drawn), the song's seed, and its
## PARTS as entries ([EntryCard]): each its pattern and instrument (rows of [SongParts] and [Instruments]), its own
## seed rolled or stepped back, its level, muted or not. The Voice entry sings the note's words ([Lyrics]): its melody
## (the reference's, composed for the words, or recited), its singer (a Kokoro reader, or a voice kept in the library)
## and how tuned it is (0 a singer's glides and vibrato, 1 every note a hard step).
##
## What is made is the Pipeline card's ([method pipeline]): the reference read, the lines sung, the mix rendered
## ([SongBake]), each a row; Generate makes what is missing. A new mix is the note's song: the panel loads it
## ([signal baked]). The score opens on the one Timeline from beside Play, as every note's timeline does
## ([SoundTimeline], [TimelineDock]). The song is exported from the bottom-right row: on a note with no video the row's
## ⤓ is the card's (`sound_export`, where the shared one is off screen), and writes the mix where the author picks, as
## WAV, FLAC, MP3 or OGG; a note with a Medium exports its video, the song in it.

## The block this card keeps under a document's `ghost:` key.
const KEY := "sound"
const SOURCES := {
	"file": {"label": "A file", "blurb": "A song from a file plays as the note's sound: its beat and spectrum drive the scenes."},
	"composed": {"label": "Composed", "blurb": "A song composed for the note from its choices and its seed, every sound synthesized, the note's words sung."},
}
const AUDIO_EXTS := ["wav", "mp3", "ogg", "oga", "flac"]
## What the mix may be saved as.
const SAVE_AS := ["wav", "flac", "mp3", "ogg"]
## The folder in the note's own folder a composed Sound keeps what it makes in.
const FOLDER := "sound"
## Its timeline's place among a note's ([method Transport.offer_timeline]): the clock's, as a reading's words.
const TIMELINE_RANK := 1

## A file was picked for the file source: its path. The panel writes it into the note and opens the note again.
signal chosen(path: String)
## A mix was made: the panel loads it as the note's song.
signal baked(path: String)
## What the card says, for the panel's status line.
signal noted(msg: String)

var _block := {}
var _note := ""                 # the note's file
var _note_folder := ""          # the note's own folder
var _bake: SongBake = null
var _section: _SoundSection = null
var _status := ""
var _made := {}                 # what the last mix was made from: {hash, at}
var _score := {}                # the score as it stands, worked out when asked
var _score_of := ""             # ...for this block and these words
var _dock: TimelineDock = null
var _open := {}                 # the part entries open
var _dialog: FileDialog = null
var _words_text := ""           # the note's words as last read (at a make, a timeline, the note re-read)
var _score_hash := ""           # the score's own hash, worked out with it
var _kept := 0                  # takes kept, counted when they change
var _after_reading := false     # a make waiting on the reference being read
var _making_hash := ""          # the score a bake under way was made from
var _ref_seen := 0              # counts the reference's readings, so a score is worked out again after one
var _ref := {}                  # the reference as read, held (read from disk at the start and after a reading)
var _ref_stamp_now := ""        # the chosen reference file as it stands: its path and when it last changed

var _source: OptionButton
var _file_box: VBoxContainer
var _file_name: Label
var _file_info: Label
var _composed_box: VBoxContainer
var _ref_name: Label
var _ref_info: Label
var _tempo: HSlider
var _key: OptionButton
var _seed_label: Label
var _form_box: VBoxContainer
var _parts_box: VBoxContainer
var _add: MenuButton
var _status_label: Label
var _save: Button              # the song's ⤓ in the bottom-right row, where a note with no video has none
var _video := false            # the note exports a video (it has a Medium): its ⤓ is the shared one
var _line: RowStatus = null    # the export's progress line, over the bottom-right row
var _saving_as := ""           # the file the mix is being exported to


## This card for a note's panel ([method NoteCards.make]): `blocks` the note's, `path` its file, `folder` its own folder
## (what is made for it is kept there).
static func for_note(ctx: Dictionary) -> SoundCard:
	var blocks: Dictionary = ctx.get("blocks", {})
	var block: Variant = blocks.get("sound", null)
	if not (block is Dictionary):
		var old: Variant = blocks.get("song", {})
		block = {"source": "file", "path": String((old as Dictionary).get("path", ""))} if old is Dictionary else {}
	var card := SoundCard.new(block as Dictionary, String(ctx.get("path", "")), String(ctx.get("folder", "")))
	card._video = bool(ctx.get("video", false))
	card._show_save()
	return card


func _init(block := {}, note := "", note_folder := "") -> void:
	_block = block.duplicate(true)
	_note = note
	_note_folder = note_folder
	add_theme_constant_override("separation", 6)
	_build()
	_section = _SoundSection.new()
	_section.card = self
	_section.owner = self
	_section.title = "Sound"
	_read_made()
	_words_text = _words()
	_load_ref()
	_refresh()


func _ready() -> void:
	var sh := Shell.of(self)
	if sh != null:
		sh.row_button(&"sound_export", _save)
	_offer_timeline()
	_line = RowStatus.new()
	add_child(_line)
	_bake = SongBake.new()
	add_child(_bake)
	_bake.said.connect(func(t: String) -> void: _say(t))
	_bake.done.connect(_on_done)
	_bake.saving.connect(func(f: float) -> void:
		_line.working("⏳  Exporting %s …  %d%%" % [_saving_as.get_file(), int(round(f * 100.0))]))


func _exit_tree() -> void:
	Transport.withdraw_timeline(self)
	if _dock != null and is_instance_valid(_dock):
		_dock.queue_free()
	# the ⤓ lives in the row, not under this card: it goes with the card
	if _save != null and is_instance_valid(_save) and not is_ancestor_of(_save):
		_save.queue_free()


# --- what the panel asks ----------------------------------------------------------------------------

## The block as it stands.
func capture() -> Dictionary:
	return _block.duplicate(true)


## The block from the note, shown.
func apply(block: Dictionary) -> void:
	_words_text = _words()
	if JSON.stringify(block) == JSON.stringify(_block):
		return
	_block = block.duplicate(true)
	_load_ref()
	_refresh()


## The file the note plays now: the file source's file, or the composed song's mix once made. "" for none.
func playable() -> String:
	if _composed():
		var mix := SongBake.mix_of(folder())
		return mix if FileAccess.file_exists(mix) else ""
	return String(_block.get("path", ""))


## Whether the note's sound is there to play.
func ready_to_play() -> bool:
	var p := playable()
	return not p.is_empty() and FileAccess.file_exists(p)


## What it hands the note's Pipeline card: the reference read, the lines sung, the mix.
func pipeline() -> PipelineSection:
	return _section


## Where the composed Sound keeps what it makes: the note's own folder's `sound/`.
func folder() -> String:
	return _note_folder.path_join(FOLDER) if not _note_folder.is_empty() else "user://sound_unsaved"


func _composed() -> bool:
	return String(_block.get("source", "composed")) == "composed"


# --- the card -----------------------------------------------------------------------------------------

func _build() -> void:
	var row := _row("Source")
	_source = OptionButton.new()
	_source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source.fit_to_longest_item = false
	for k in SOURCES:
		_source.add_item(Registry.label(SOURCES, k))
		_source.set_item_metadata(_source.item_count - 1, k)
		_source.set_item_tooltip(_source.item_count - 1, Registry.blurb(SOURCES, k))
	_source.item_selected.connect(func(i: int) -> void:
		_block["source"] = String(_source.get_item_metadata(i))
		_changed())
	row.add_child(_source)
	_file_box = VBoxContainer.new()
	add_child(_file_box)
	var fr := HBoxContainer.new()
	_file_box.add_child(fr)
	_file_name = Label.new()
	_file_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	fr.add_child(_file_name)
	fr.add_child(_button("Choose…", "Choose a song for this note - a WAV, MP3, OGG or FLAC file.", func() -> void:
		_pick_file("Choose a song for this note", func(p: String) -> void: chosen.emit(p))))
	_file_info = _small("")
	_file_box.add_child(_file_info)

	_composed_box = VBoxContainer.new()
	_composed_box.add_theme_constant_override("separation", 6)
	add_child(_composed_box)
	var rr := HBoxContainer.new()
	_composed_box.add_child(rr)
	var rl := Label.new()
	rl.text = "Reference"
	rl.custom_minimum_size = Vector2(72, 0)
	rl.add_theme_font_size_override("font_size", 12)
	rl.tooltip_text = "A song the importer reads for its patterns - its tempo, key, chords, form, drums and sung melody. Nothing of its sound is kept."
	rr.add_child(rl)
	_ref_name = Label.new()
	_ref_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ref_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rr.add_child(_ref_name)
	rr.add_child(_button("Choose…", "A song to take this one's patterns from: its grid, key, chords, form, drums and melody.", func() -> void:
		_pick_file("Choose a song to take patterns from", func(p: String) -> void:
			_block["reference"] = {"path": p}
			_load_ref()
			_changed())))
	rr.add_child(_button("×", "Compose without a reference: the tempo, key, harmony, form and melody drawn from the seed and the words.", func() -> void:
		_block.erase("reference")
		_changed()))
	_ref_info = _small("")
	_composed_box.add_child(_ref_info)
	_tempo = Card.slider_row(_composed_box, "Tempo", 0.0, 200.0, 1.0, float(_block.get("tempo", 0.0)),
		"Beats a minute; at 0, the reference's tempo (or one drawn from the seed without one).", func(v: float) -> void:
			if v <= 0.0:
				_block.erase("tempo")
			else:
				_block["tempo"] = v
			_changed(false))
	var kr := _row("Key", _composed_box)
	_key = OptionButton.new()
	_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key.fit_to_longest_item = false
	_key.tooltip_text = "The key every pitched part and the voice are in. Auto takes the reference's, or draws one from the seed."
	_key.add_item("Auto")
	_key.set_item_metadata(0, "")
	for scale in ["major", "minor", "dorian", "mixolydian", "lydian"]:
		for t in 12:
			_key.add_item(MusicTheory.key_name(t, scale))
			_key.set_item_metadata(_key.item_count - 1, MusicTheory.key_name(t, scale))
	_key.item_selected.connect(func(i: int) -> void:
		var k := String(_key.get_item_metadata(i))
		if k.is_empty():
			_block.erase("key")
		else:
			_block["key"] = k
		_changed())
	kr.add_child(_key)
	var sr := _row("Song", _composed_box)
	_seed_label = Label.new()
	_seed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_label.tooltip_text = "The song's own number: the harmony, the form and the melody it composes are drawn from it. Each part has its own."
	sr.add_child(_seed_label)
	_seed_buttons(sr, func() -> int: return int(_block.get("seed", 1)), func(v: int) -> void:
		_block["seed"] = v
		_changed())
	_form_box = VBoxContainer.new()
	_form_box.add_theme_constant_override("separation", 2)
	_composed_box.add_child(_form_box)
	_parts_box = VBoxContainer.new()
	_parts_box.add_theme_constant_override("separation", 4)
	_composed_box.add_child(_parts_box)
	_add = MenuButton.new()
	_add.text = "+ Add a part"
	_add.flat = false
	_add.tooltip_text = "Another part for the song: a drum kit, a bass, keys, a pad, a guitar, a lead, bells, a voice."
	_add.get_popup().id_pressed.connect(func(id: int) -> void:
		var k: String = SongParts.PARTS.keys()[id]
		var parts := _parts()
		parts[k] = {"seed": 1}
		_block["parts"] = parts
		_open[k] = true
		_changed())
	_composed_box.add_child(_add)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 6)
	_composed_box.add_child(br)
	# saving the song is the bottom-right row's, where a video is exported ([method _ready] hands it there)
	_save = Button.new()
	_save.text = "⤓"                    # icon-only, the row's export glyph
	_save.focus_mode = Control.FOCUS_NONE
	_save.custom_minimum_size = Vector2(40, 40)
	_save.pressed.connect(_save_audio)
	br.add_child(_save)
	_status_label = _small("")
	_status_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75, 0.85))
	add_child(_status_label)


func _refresh() -> void:
	var composed := _composed()
	for i in _source.item_count:
		if String(_source.get_item_metadata(i)) == ("composed" if composed else "file"):
			_source.select(i)
	_file_box.visible = not composed
	_composed_box.visible = composed
	_show_save()
	_offer_timeline()
	if not composed:
		var p := String(_block.get("path", ""))
		if p.is_empty():
			_file_name.text = "No song yet"
			_file_info.text = "Choose a song for this note: it plays from the transport, and a Medium shows a scene for it."
		elif not FileAccess.file_exists(p):
			_file_name.text = "Missing: " + p.get_file()
			_file_info.text = "The song is not where the note says it is - choose it again."
		else:
			_file_name.text = "♪  " + p.get_file().get_basename()
			_file_info.text = "Plays from the transport below the stage: Space plays and pauses."
		_file_name.tooltip_text = p
		return
	var ref_path := _ref_path()
	_ref_name.text = ("♪  " + ref_path.get_file().get_basename()) if not ref_path.is_empty() else "None"
	_ref_name.tooltip_text = ref_path
	var ref := _ref
	if ref_path.is_empty():
		_ref_info.text = "Composed from the seed and the words alone."
	elif needs_reading():
		_ref_info.text = "Not read yet: Generate reads it."
	else:
		_ref_info.text = "%.1f BPM · %s · %d bars · %d chords · %d bars sung" % [float(ref.get("tempo", 0.0)),
			String((ref.get("key", {}) as Dictionary).get("name", "")), int(ref.get("bars", 0)),
			(ref.get("chords", []) as Array).size(), (ref.get("voice", {}) as Dictionary).size()]
	_tempo.set_value_no_signal(float(_block.get("tempo", 0.0)))
	var key := String(_block.get("key", ""))
	for i in _key.item_count:
		if String(_key.get_item_metadata(i)) == key:
			_key.select(i)
	_seed_label.text = "#%d" % int(_block.get("seed", 1))
	_build_form()
	_build_parts()


## Where each section of the words is sung, with a reference: its first bar, moved a bar at a time (‹ ›) when the
## reading laid it wrong, which pins it there (`place`); Auto lets the reading lay it again.
func _build_form() -> void:
	for c in _form_box.get_children():
		c.queue_free()
	if _ref.is_empty():
		return
	var place: Dictionary = _block.get("place", {}) if _block.get("place", {}) is Dictionary else {}
	for sec in score().get("sections", []):
		if not (sec as Dictionary).has("lyric"):
			continue
		var i := int(sec["lyric"])
		var bar := int(sec["bar"])
		var r := _row(String(sec["label"]), _form_box)
		var at := Label.new()
		at.text = "bars %d-%d%s" % [bar + 1, bar + int(sec["bars"]), "  (pinned)" if bool(sec.get("pinned", false)) else ""]
		at.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		at.add_theme_font_size_override("font_size", 12)
		at.tooltip_text = "Where this section of the words is sung over the reference. The reading lays each section where the reference's voice sings; move it a bar when it laid it wrong."
		r.add_child(at)
		var put := func(to: int) -> void:
			var p: Dictionary = (_block.get("place", {}) as Dictionary).duplicate() if _block.get("place", {}) is Dictionary else {}
			if to < 0:
				p.erase(str(i))
			else:
				p[str(i)] = to
			if p.is_empty():
				_block.erase("place")
			else:
				_block["place"] = p
			_changed()
		r.add_child(_button("‹", "A bar earlier (pins it).", func() -> void: put.call(maxi(bar - 1, 0))))
		r.add_child(_button("›", "A bar later (pins it).", func() -> void: put.call(bar + 1)))
		if place.has(str(i)):
			r.add_child(_button("Auto", "Let the reading lay this section again.", func() -> void: put.call(-1)))


func _build_parts() -> void:
	for c in _parts_box.get_children():
		c.queue_free()
	var parts := _parts()
	var popup := _add.get_popup()
	popup.clear()
	var keys: Array = SongParts.PARTS.keys()
	for i in keys.size():
		var k: String = keys[i]
		if parts.has(k):
			_parts_box.add_child(_part_entry(k, parts[k] if parts[k] is Dictionary else {}))
		else:
			popup.add_item(Registry.label(SongParts.PARTS, k), i)
			popup.set_item_tooltip(popup.item_count - 1, Registry.blurb(SongParts.PARTS, k))
	_add.disabled = popup.item_count == 0


func _part_entry(k: String, cfg: Dictionary) -> EntryCard:
	var row: Dictionary = SongParts.PARTS[k]
	var pattern := String(cfg.get("pattern", row["pattern"]))
	var has_ref := not _ref_path().is_empty()
	if pattern == "reference" and not has_ref:
		pattern = "composed" if k == "vocal" else String(row["pattern"])
	var e := EntryCard.new(String(row["label"]), _entry_line(k, cfg), String(row["blurb"]))
	e.set_remove(func() -> void:
		var parts := _parts()
		parts.erase(k)
		_block["parts"] = parts
		_open.erase(k)
		_changed(), "Take this part out of the song.")
	e.open = bool(_open.get(k, false))
	e.toggled.connect(func(on: bool) -> void:
		_open[k] = on
		# who may sing is the voice host's to list: asked when the Voice entry is opened, the first time
		if on and k == "vocal" and VoiceReaders.all("kokoro").is_empty() and _bake != null:
			_bake.list_singers(func() -> void: _build_parts()))
	var o := e.options
	var pr := _row("Pattern", o)
	var pat := OptionButton.new()
	pat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pat.fit_to_longest_item = false
	for p in SongParts.patterns_for(k, has_ref):
		pat.add_item(Registry.label(SongParts.PATTERNS, p))
		pat.set_item_metadata(pat.item_count - 1, p)
		pat.set_item_tooltip(pat.item_count - 1, Registry.blurb(SongParts.PATTERNS, p))
		if p == pattern:
			pat.select(pat.item_count - 1)
	pat.item_selected.connect(func(i: int) -> void: _set_part(k, "pattern", String(pat.get_item_metadata(i))))
	pr.add_child(pat)
	if k == "vocal":
		_voice_rows(o, k, cfg)
	else:
		var ir := _row("Sound", o)
		var inst := OptionButton.new()
		inst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inst.fit_to_longest_item = false
		for key in Instruments.for_part(k):
			inst.add_item(Registry.label(Instruments.ROWS, key))
			inst.set_item_metadata(inst.item_count - 1, key)
			inst.set_item_tooltip(inst.item_count - 1, Registry.blurb(Instruments.ROWS, key))
			if key == String(cfg.get("instrument", row["instrument"])):
				inst.select(inst.item_count - 1)
		inst.item_selected.connect(func(i: int) -> void: _set_part(k, "instrument", String(inst.get_item_metadata(i))))
		ir.add_child(inst)
	var sr := _row("Number", o)
	var n := Label.new()
	n.text = "#%d" % int(cfg.get("seed", 1))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.tooltip_text = "This part's own number: its rhythm's details and its sound's are drawn from it. Rolling it moves no other part."
	sr.add_child(n)
	_seed_buttons(sr, func() -> int: return int((_parts().get(k, {}) as Dictionary).get("seed", 1)),
		func(v: int) -> void: _set_part(k, "seed", v))
	Card.slider_row(o, "Level", -24.0, 6.0, 0.5, float(cfg.get("level", row["level"])),
		"How loud this part is in the mix, in decibels.", func(v: float) -> void: _set_part(k, "level", v, false))
	var mute := CheckBox.new()
	mute.text = "Muted"
	mute.button_pressed = bool(cfg.get("mute", false))
	mute.tooltip_text = "Silent in the mix, kept in the song."
	mute.toggled.connect(func(on: bool) -> void:
		_set_part(k, "mute", on, false)
		e.line_label.text = _entry_line(k, _parts().get(k, {}) as Dictionary))
	o.add_child(mute)
	return e


## What a part's entry says under its name: its pattern, its sound or singer, muted.
func _entry_line(k: String, cfg: Dictionary) -> String:
	var row: Dictionary = SongParts.PARTS[k]
	var pattern := String(cfg.get("pattern", row["pattern"]))
	if pattern == "reference" and _ref_path().is_empty():
		pattern = "composed" if k == "vocal" else String(row["pattern"])
	var line := Registry.label(SongParts.PATTERNS, pattern)
	if k == "vocal":
		line += " · " + _singer_name(cfg)
	else:
		line += " · " + Registry.label(Instruments.ROWS, String(cfg.get("instrument", row["instrument"])))
	return line + (" · muted" if bool(cfg.get("mute", false)) else "")


## The Voice entry's own rows: who sings, and how tuned.
func _voice_rows(o: VBoxContainer, k: String, cfg: Dictionary) -> void:
	var sr := _row("Singer", o)
	var who := OptionButton.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.fit_to_longest_item = false
	who.tooltip_text = "Who sings: a Kokoro reader, or a voice kept in the library. Every Kokoro voice sings by the same path."
	var singer: Dictionary = cfg.get("singer", Composer.SINGER) if cfg.get("singer", Composer.SINGER) is Dictionary else Composer.SINGER
	var readers := VoiceReaders.all("kokoro")
	if readers.is_empty():
		readers = [{"i": int(singer.get("speaker", 13)), "reader": String(singer.get("name", "am_puck"))}]
	for r in readers:
		who.add_item(String(r["reader"]))
		who.set_item_metadata(who.item_count - 1, {"voice": "kokoro", "speaker": int(r["i"]), "name": String(r["reader"])})
		if String(singer.get("kept", "")).is_empty() and int(r["i"]) == int(singer.get("speaker", -1)):
			who.select(who.item_count - 1)
	for name in VoiceLibrary.names():
		who.add_item("♥ " + String(name))
		who.set_item_metadata(who.item_count - 1, {"kept": String(name), "name": String(name)})
		if String(singer.get("kept", "")) == String(name):
			who.select(who.item_count - 1)
	who.item_selected.connect(func(i: int) -> void: _set_part(k, "singer", who.get_item_metadata(i)))
	sr.add_child(who)
	Card.slider_row(o, "Tune", 0.0, 1.0, 0.05, float(cfg.get("tune", Composer.STYLE["tune"])),
		"How tuned the voice is: at 0 a singer's own glides into each note, its vibrato and drift; at 1 every note a hard step, the tuned sound of a vocoder or a pitch corrector.",
		func(v: float) -> void: _set_part(k, "tune", v, false))
	Card.slider_row(o, "Vibrato", 0.0, 1.0, 0.05, float(cfg.get("vibrato", Composer.STYLE["vibrato"])),
		"How far a held note's pitch sways, in semitones, once it has held a while.", func(v: float) -> void: _set_part(k, "vibrato", v, false))


func _singer_name(cfg: Dictionary) -> String:
	var s: Variant = cfg.get("singer", Composer.SINGER)
	return String((s as Dictionary).get("name", (s as Dictionary).get("kept", "a voice"))) if s is Dictionary else "a voice"


func _set_part(k: String, field: String, value: Variant, rebuild := true) -> void:
	var parts := _parts()
	var cfg: Dictionary = parts.get(k, {}) if parts.get(k, {}) is Dictionary else {}
	cfg[field] = value
	parts[k] = cfg
	_block["parts"] = parts
	_changed(rebuild)


func _parts() -> Dictionary:
	var p: Variant = _block.get("parts")
	if p is Dictionary and not (p as Dictionary).is_empty():
		return (p as Dictionary).duplicate(true)
	var out := {}
	for k in Composer.DEFAULT_PARTS:
		out[k] = {"seed": 1}
	return out


func _seed_buttons(row: HBoxContainer, now: Callable, put: Callable) -> void:
	row.add_child(_button("‹", "The number before.", func() -> void: put.call(maxi(int(now.call()) - 1, 1))))
	row.add_child(_button("Roll", "A new number: another variant of the same choices.", func() -> void: put.call(Roll.fresh() + 1)))
	row.add_child(_button("›", "The number after.", func() -> void: put.call(int(now.call()) + 1)))


## The block changed: shown again ([param rebuild] false for a dial, whose own row is under the hand), and the timeline
## if it is open.
func _changed(rebuild := true) -> void:
	if rebuild:
		_refresh()
	if _dock != null and is_instance_valid(_dock):
		_dock.timeline = SoundTimeline.of(score())
		_dock.reload(_dock.timeline)


func _ref_path() -> String:
	var r: Variant = _block.get("reference")
	return String((r as Dictionary).get("path", "")) if r is Dictionary else ""


func _ref_stamp() -> String:
	return _ref_stamp_now


## The reference read from the note's folder, and the chosen file's stamp, held until either changes.
func _load_ref() -> void:
	var p := _ref_path()
	_ref_stamp_now = "%s@%d" % [p, FileAccess.get_modified_time(p)] if not p.is_empty() and FileAccess.file_exists(p) else ""
	_ref = SongBake.reference_of(folder()) if not p.is_empty() else {}


# --- the score and what is made of it -------------------------------------------------------------------

## The score as the block and the note's words stand: worked out again only when either has changed.
func score() -> Dictionary:
	var made_of := JSON.stringify([_block, _words_text, _ref_seen]).sha1_text()
	if made_of != _score_of:
		_score = Composer.score(_block, {"lyrics": Lyrics.parse(_words_text), "reference": _ref})
		_score_hash = JSON.stringify(_score).sha1_text()
		_score_of = made_of
		_count_kept()
	return _score


func _words() -> String:
	if _note.is_empty() or not FileAccess.file_exists(_note):
		return ""
	return String(FrontMatter.split(FileAccess.get_file_as_string(_note)).get("body", ""))


func _read_made() -> void:
	var path := ProjectSettings.globalize_path(folder()).path_join(SongBake.MADE)
	var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	_made = got if got is Dictionary else {}


## Whether the reference wants reading: one is chosen, and what was read is not of it.
func needs_reading() -> bool:
	if _ref_path().is_empty():
		return false
	return _ref.is_empty() or String(_ref.get("stamp", "")) != _ref_stamp()


## The reference read again ([SongBake.analyze]), the lyrics' lines handed to it.
func read_reference() -> void:
	if _ref_path().is_empty() or _bake == null:
		return
	var lines: Array = []
	for l in Lyrics.lines_of(Lyrics.parse(_words())):
		lines.append({"text": l["text"], "syllables": Lyrics.syllables_of(l), "section": l["kind"]})
	_bake.analyze(_ref_path(), lines, folder())


## The song made: what is missing read and sung, then the mix rendered.
func make() -> void:
	if _bake == null or _bake.busy():
		return
	_words_text = _words()
	_load_ref()
	if needs_reading():
		_after_reading = true
		read_reference()
		return
	var s := score()
	_making_hash = _score_hash
	_bake.bake(s, folder())


## Every line sung again: the kept takes thrown away, then the song made.
func sing_again() -> void:
	var dir := ProjectSettings.globalize_path(folder()).path_join("takes")
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	_kept = 0
	make()


## How many of the score's lines have their take kept (two lines sung alike share one).
func _count_kept() -> void:
	_kept = 0
	var vocal: Dictionary = _score.get("vocal", {})
	for p in vocal.get("phrases", []):
		var wav := SongBake.take_of(folder(), vocal, p)
		if FileAccess.file_exists(wav) and FileAccess.file_exists(wav.get_basename() + ".json"):
			_kept += 1


func _on_done(job: String, ok: bool, path: String, why: String) -> void:
	if job == "save":
		if ok:
			_line.done("✓  Saved  %s" % path)
		else:
			_line.failed("⚠  The song could not be exported: %s" % why)
		return
	if not ok:
		_say("⚠  " + why)
		_after_reading = false
		_count_kept()
		return
	if job == "analyze":
		# the reference keeps what it was read from, so a new file is known to want reading
		var ref := SongBake.reference_of(folder())
		_load_ref()
		ref["stamp"] = _ref_stamp()
		ref["song"] = _ref_path()
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(ref, " "))
			f.close()
		_ref = ref
		_ref_seen += 1
		_refresh()
		if _after_reading:
			_after_reading = false
			make()
		return
	_count_kept()
	_made = {"hash": _making_hash, "at": Time.get_unix_time_from_system()}
	_show_save()
	var mf := FileAccess.open(ProjectSettings.globalize_path(folder()).path_join(SongBake.MADE), FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify(_made))
		mf.close()
	_say("✓  The song is made: %s" % path.get_file())
	baked.emit(path)


## The pipeline's rows ([PipelineRow]): the reference, the sung lines, the mix.
func pipeline_rows() -> Array:
	var out: Array = []
	var busy := _bake != null and _bake.busy()
	if not _ref_path().is_empty():
		var r := PipelineRow.new("reference", "Reference read")
		r.state = "running" if busy and _bake.job() == "analyze" else ("stale" if needs_reading() and not _ref.is_empty() else ("missing" if needs_reading() else "made"))
		r.said = _ref_info.text if _ref_info != null else ""
		r.again = "Read the reference again: its grid, key, chords, form, drums and melody."
		r.redo = read_reference
		out.append(r)
	var s := score()
	var phrases: Array = (s.get("vocal", {}) as Dictionary).get("phrases", [])
	if not phrases.is_empty():
		var t := PipelineRow.new("takes", "Lines sung")
		var kept := _kept
		t.state = "running" if busy and _bake.job() == "sing" else ("made" if kept >= phrases.size() else "missing")
		t.said = "%d lines, %d kept" % [phrases.size(), mini(kept, phrases.size())]
		t.again = "Sing every line again."
		t.asks = "Every line sung so far is thrown away." if kept > 0 else ""
		t.redo = sing_again
		out.append(t)
	var m := PipelineRow.new("mix", "Mix")
	var mix := SongBake.mix_of(folder())
	if busy and _bake.job() == "render":
		m.state = "running"
	elif busy:
		m.state = "queued"
	elif not FileAccess.file_exists(mix):
		m.state = "missing"
	else:
		m.state = "made" if String(_made.get("hash", "")) == _score_hash else "stale"
	m.said = _status if busy else ("%d parts%s, %s" % [(s.get("parts", []) as Array).size(),
		" and the voice" if not (s.get("vocal", {}) as Dictionary).is_empty() else "", Clock.text(float(s.get("length", 0.0)))])
	m.again = "Make the song again from its parts as they stand: what is kept is read back, the rest made."
	m.redo = make
	out.append(m)
	return out


func _say(text: String) -> void:
	_status = text
	if _status_label != null:
		_status_label.text = text
	noted.emit(text)


# --- the timeline -----------------------------------------------------------------------------------

## A composed Sound's timeline offered beside Play, as every note's is ([method Transport.offer_timeline]): the clock's
## own, as a reading's words are (TIMELINE_RANK), under a show's storyboard where the note has one.
func _offer_timeline() -> void:
	if not is_inside_tree():
		return
	if not _composed():
		Transport.withdraw_timeline(self)
		return
	Transport.offer_timeline(self, TIMELINE_RANK, open_timeline,
		func() -> bool: return _dock != null and is_instance_valid(_dock),
		"The song's timeline: its sections, each part's patterns and chords, and every word sung on its note.")


## The score on the one Timeline, docked under the show ([TimelineDock], read-only): its sections, each part's
## patterns and chords, every word sung on its note. Pressed again, it closes.
func open_timeline() -> void:
	if _dock != null and is_instance_valid(_dock):
		_dock.queue_free()
		_dock = null
		return
	_words_text = _words()
	_dock = TimelineDock.new()
	_dock.title = "Sound"
	_dock.timeline = SoundTimeline.of(score())
	_dock.inspector = func(what: Dictionary, box: VBoxContainer) -> void: SoundTimeline.inspect(what, box)
	_dock.closed.connect(func() -> void: _dock = null)
	get_tree().root.add_child(_dock)


# --- saving the mix ---------------------------------------------------------------------------------

## The song's ⤓: the row's export where the note exports no video (a mode's own export takes the shared one's place
## while that is off screen, as Masking's does), for a composed Sound, grayed until its song is made. A note with a
## Medium exports its video, the song in it, from the shared ⤓.
func _show_save() -> void:
	if _save == null:
		return
	var made := FileAccess.file_exists(SongBake.mix_of(folder()))
	_save.visible = _composed() and not _video
	_save.disabled = not made
	_save.tooltip_text = ("Export the song to an audio file - WAV, FLAC, MP3 or OGG, where you choose." if made
		else "Export the song to an audio file, once it is made: the Pipeline card's Generate makes it.")


func _save_audio() -> void:
	var mix := SongBake.mix_of(folder())
	if not FileAccess.file_exists(mix):
		_say("Nothing to save yet: Generate makes the song first.")
		return
	_close_dialog()
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = false
	_dialog.title = "Save the song"
	_dialog.filters = PackedStringArray(["*.wav ; WAV", "*.flac ; FLAC", "*.mp3 ; MP3", "*.ogg ; OGG"])
	_dialog.current_file = NoteStore.name_of(NoteStore.title_of(_note)) + ".wav" if not _note.is_empty() else "song.wav"
	_dialog.size = Vector2i(820, 560)
	_dialog.file_selected.connect(func(p: String) -> void:
		_close_dialog()
		_saving_as = p
		var why := _bake.save_as(mix, p)
		if not why.is_empty():
			_line.failed("⚠  " + why)
		elif p.get_extension().to_lower() != "wav":  # (a WAV is copied, and has said so already)
			_line.working("⏳  Exporting %s …" % p.get_file()))
	_dialog.canceled.connect(_close_dialog)
	add_child(_dialog)
	_dialog.popup_centered()


func _pick_file(title: String, then: Callable) -> void:
	_close_dialog()
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	# In-window, never native: the portal dialog shows nothing on a Linux box without xdg-desktop-portal.
	_dialog.use_native_dialog = false
	_dialog.title = title
	_dialog.filters = PackedStringArray(["*.wav, *.mp3, *.ogg, *.oga, *.flac ; Songs", "* ; Every file"])
	_dialog.size = Vector2i(820, 560)
	_dialog.file_selected.connect(func(p: String) -> void:
		_close_dialog()
		then.call(p))
	_dialog.canceled.connect(_close_dialog)
	add_child(_dialog)
	_dialog.popup_centered()


func _close_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


# --- small controls -----------------------------------------------------------------------------------

func _row(label: String, into: Container = null) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	(into if into != null else self).add_child(r)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
	r.add_child(l)
	return r


func _button(text: String, tip: String, act: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(act)
	return b


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(1, 1, 1, 0.7)
	return l


## What the Sound card hands the Pipeline card.
class _SoundSection extends PipelineSection:
	var card: SoundCard

	func shown() -> bool:
		return card != null and card._composed()

	func rows() -> Array:
		return card.pipeline_rows()

	func line() -> String:
		return told if not told.is_empty() else card._status

	func make() -> void:
		card.make()

	func make_tip() -> String:
		return "Make the song: the reference read, every line not kept sung, the mix rendered."

	func busy() -> bool:
		return card._bake != null and card._bake.busy()

	func missing() -> bool:
		for r in card.pipeline_rows():
			if String((r as PipelineRow).state) in ["missing", "stale"]:
				return true
		return false

	func stop() -> void:
		if card._bake != null:
			card._bake.stop()
