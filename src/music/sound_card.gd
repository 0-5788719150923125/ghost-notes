extends VBoxContainer
class_name SoundCard

## SoundCard - the note's Sound (next/music.md): what the show is timed by and heard with. Its first row is its
## Source - a file the note plays (what the Song card was), or a song COMPOSED for the note - mirroring the Medium
## card's Format: a way of making the sound is a source on one card, never a second component. Its block is `sound:`;
## a note written before keeps `song: {path}`, read as a file.
##
## Composed, the card is choices, not a DAW: a REFERENCE (a song file the importer reads for its grid, key, chords,
## form, drums and melody - never its sound), the tempo and key (the reference's, or drawn), and its PARTS as entries
## ([EntryCard]): each its pattern and instrument (rows of [SongParts] and [Instruments]), its level, muted or not, and
## a Roll that draws the part again. The Voice entry sings the note's words ([Lyrics]): its melody (the reference's,
## composed for the words, or recited), its singer (a Kokoro reader, or a voice kept in the library) and how tuned it
## is (0 a singer's glides and vibrato, 1 every note a hard step). THE SONG'S CODE is every setting at once
## ([SongCode]): it changes as anything on the card does, and a code entered there brings that song's settings back.
## EVERY PART IS USED IN THE SECTIONS IT IS GIVEN: a toggle a section of the song on its entry (a voice's, a section of
## the words), dimmed while the line-ups and the roll choose, set once one is pressed. A SONG HAS UP TO FOUR VOICES
## (next/music.md, "The voices"), each an entry of its own: what it sings (the tune, or a harmony to it) and who sings - a voice kept in the library,
## designed on a Voice card with its Tone and how it sings in its Lab, or one of Kokoro's readers ([Singers]); the card
## keeps no voice of its own. The first voice's Melody is how the tune is made.
## A ROLL DRAWS EVERY SETTING ([method Composer.rolled]): the song's Roll leaves only the reference, the parts, what is
## muted and where the words are pinned; a part's Roll draws that part alone. A setting the roll drew shows what it
## drew, dimmed; moved by hand it is set. Back (‹) walks to the song before each roll or code entered.
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
## Seconds a change waits before the stream takes it: a dial dragged is many changes.
const STREAM_SETTLE := 0.3
## The most songs Back keeps.
const HISTORY_MOST := 64
## How faint a setting the roll drew is, beside one set by hand.
const DRAWN_ALPHA := 0.55

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
var _voices := {}               # the kept voices that can sing ([method Singers.kept]), read once a library version
var _voices_at := -1

var _source: OptionButton
var _file_box: VBoxContainer
var _file_name: Label
var _file_info: Label
var _composed_box: VBoxContainer
var _ref_name: Label
var _ref_info: Label
var _tempo: HSlider
var _likeness: HSlider          # how much of the reference a roll keeps (shown with a reference)
var _roll_info: Label           # what this roll drew
var _key: OptionButton
var _code: LineEdit             # the song's settings as one code
var _form_box: VBoxContainer
var _parts_box: VBoxContainer
var _add: MenuButton
var _status_label: Label
var _save: Button              # the song's ⤓ in the bottom-right row, where a note with no video has none
var _video := false            # the note exports a video (it has a Medium): its ⤓ is the shared one
var _line: RowStatus = null    # the export's progress line, over the bottom-right row
var _stream: SongStream = null # the song heard as it is made, in a session a person plays
var _live := false             # this panel is a session a person plays, not an export's render
var _begin_stream := Callable()
var _end_stream := Callable()
var _settle := 0               # the last change's number: the stream takes the score once no later one comes
var _typed := false            # the code field holds what a person typed, not the code as the settings stand
var _history: Array = []       # the codes before each roll or code entered, the latest last (Back walks them)
var _back: Button
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
	card._live = bool(ctx.get("live", false))
	card._begin_stream = ctx.get("begin_stream", Callable())
	card._end_stream = ctx.get("end_stream", Callable())
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
	_start_stream()


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


## Whether the song is heard as it is made ([SongStream]): composed, in a session a person plays.
func streams() -> bool:
	return _composed() and _live and _begin_stream.is_valid()


func _start_stream() -> void:
	if not streams() or _stream != null:
		return
	_stream = SongStream.new()
	_stream.begin_stream = _begin_stream
	_stream.end_stream = _end_stream
	add_child(_stream)
	_stream.said.connect(func(t: String) -> void:
		if not t.is_empty():
			_say(t))
	_stream.sung.connect(func() -> void: _count_kept())
	_stream.setup(score(), folder(), _bake)


## The song an export renders ([member Exporter.take_provider]): a composed song's mix made whole from the score as it
## stands - the one kept where it was made from this score, made first where not (the reference read, every line not
## kept sung, rendered) - its sidecar written beside it; a file's own path. "" when there is none.
func export_song() -> String:
	if not _composed():
		var p := String(_block.get("path", ""))
		return p if FileAccess.file_exists(p) else ""
	if _bake == null:
		return ""
	var s := score()
	var mix := SongBake.mix_of(folder())
	while not (String(_made.get("hash", "")) == _score_hash and FileAccess.file_exists(mix)):
		if not _bake.busy():
			make()
			if not _bake.busy():
				return ""
		var got: Array = await _bake.done
		if not bool(got[1]):
			return ""
		s = score()
	SongBake.write_sidecar(s, mix)
	if _stream != null:
		_stream.takes_changed()
	return mix


## Whether there is a song for an export: composed, or a file that is there.
func can_export_song() -> bool:
	return _composed() or FileAccess.file_exists(String(_block.get("path", "")))


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
	_likeness = Card.slider_row(_composed_box, "Likeness", 0.0, 1.0, 0.05, 0.5,
		"How much of the reference a roll keeps: each thing it has - its tempo, key, form, chords, drums, bass line and tune - kept with this chance, each drawn again at every roll. At 1 the reference's own song in a new band; at 0 everything drawn afresh, only the words the same. Dimmed, the roll drew it; moved, it is set.",
		func(v: float) -> void:
			_block["likeness"] = v
			_likeness.get_parent().modulate = Color.WHITE
			_changed(false))
	_tempo = Card.slider_row(_composed_box, "Tempo", 0.0, 200.0, 1.0, 0.0,
		"Beats a minute. Dimmed, the roll drew it (in the range the drums' pattern is played at, or the reference's, as often as Likeness says); moved, it is set; at 0, drawn again.", func(v: float) -> void:
			if v <= 0.0:
				_block.erase("tempo")
			else:
				_block["tempo"] = v
			_tempo.get_parent().modulate = Color(1, 1, 1, DRAWN_ALPHA) if v <= 0.0 else Color.WHITE
			_changed(false))
	var kr := _row("Key", _composed_box)
	_key = OptionButton.new()
	_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key.fit_to_longest_item = false
	_key.tooltip_text = "The key every pitched part and the voice are in. Auto: drawn by the roll, its mode too (the reference's, as often as Likeness says)."
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
	var sr := _row("Code", _composed_box)
	_code = LineEdit.new()
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.select_all_on_focus = true
	_code.add_theme_font_size_override("font_size", 12)
	_code.tooltip_text = "Every setting of this song as one code: it changes as anything on the card does. Keep a code to come back to a song - paste it here and press Enter, and its settings come back (Escape lets it be). The note's words and the reference are not in it, so a code on another note is the same choices over its words."
	_code.text_changed.connect(func(_t: String) -> void: _typed = true)
	_code.text_submitted.connect(func(t: String) -> void:
		enter_code(t)
		_code.release_focus())
	_code.focus_exited.connect(func() -> void:
		if _typed:
			enter_code(_code.text)
		_typed = false
		_show_code())
	_code.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_cancel"):
			_typed = false
			_show_code()
			_code.release_focus()
			_code.accept_event())
	sr.add_child(_code)
	sr.add_child(_button("Copy", "Copy the song's code.", func() -> void:
		DisplayServer.clipboard_set(SongCode.of(_block))
		_say("The song's code is copied.")))
	_back = _button("‹", "Back: the song before the last roll or code entered.", back)
	sr.add_child(_back)
	sr.add_child(_button("Roll", "A new song: every setting drawn again - Likeness, the tempo, key and swing, the form, the chords, who plays where, every part's pattern, sound, level and notes, the singer and how they sing. Kept: the reference, which parts the song has, what is muted, and where the words are pinned. ‹ brings the song before back.", roll_song))
	_roll_info = _small("")
	_composed_box.add_child(_roll_info)
	_form_box = VBoxContainer.new()
	_form_box.add_theme_constant_override("separation", 2)
	_composed_box.add_child(_form_box)
	_parts_box = VBoxContainer.new()
	_parts_box.add_theme_constant_override("separation", 4)
	_composed_box.add_child(_parts_box)
	_add = MenuButton.new()
	_add.text = "+ Add a part"
	_add.flat = false
	_add.tooltip_text = "Another part for the song: a drum kit, a bass, keys, a pad, a guitar, a lead, bells, a voice (up to four)."
	_add.get_popup().id_pressed.connect(func(id: int) -> void:
		var k: String = SongParts.PARTS.keys()[id]
		var parts := _parts()
		if k == "vocal":
			for v in SongParts.voice_keys():
				if not parts.has(v):
					k = v
					break
		parts[k] = {}
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
	var sc := score()
	var like: Variant = _block.get("likeness")
	_show_dial(_likeness, float(like) if _number(like) else float((sc.get("roll", {}) as Dictionary).get("likeness", 0.5)), not _number(like))
	_likeness.get_parent().visible = not ref_path.is_empty()
	_roll_info.text = _roll_line()
	var tempo := float(_block.get("tempo", 0.0)) if _number(_block.get("tempo")) else 0.0
	_show_dial(_tempo, tempo if tempo > 0.0 else float(sc.get("tempo", 0.0)), tempo <= 0.0)
	_show_back()
	var key := String(_block.get("key", ""))
	for i in _key.item_count:
		if String(_key.get_item_metadata(i)) == key:
			_key.select(i)
	_show_code()
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
		if k == "vocal":
			var have: Array = SongParts.voice_keys().filter(func(v: String) -> bool: return parts.has(v))
			for v in have:
				_parts_box.add_child(_part_entry(v, parts[v] if parts[v] is Dictionary else {}))
			if have.size() < SongParts.VOICES_MOST:
				popup.add_item(Registry.label(SongParts.PARTS, k), i)
				popup.set_item_tooltip(popup.item_count - 1, Registry.blurb(SongParts.PARTS, k))
		elif parts.has(k):
			_parts_box.add_child(_part_entry(k, parts[k] if parts[k] is Dictionary else {}))
		else:
			popup.add_item(Registry.label(SongParts.PARTS, k), i)
			popup.set_item_tooltip(popup.item_count - 1, Registry.blurb(SongParts.PARTS, k))
	_add.disabled = popup.item_count == 0


func _part_entry(k: String, cfg: Dictionary) -> EntryCard:
	var row: Dictionary = SongParts.PARTS[SongParts.kind_of(k)]
	var voice := SongParts.is_voice(k)
	var chose := _chosen(k, cfg)
	var has_ref := not _ref.is_empty()
	var e := EntryCard.new(SongParts.label_of(k), _entry_line(k, cfg), String(row["blurb"]))
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
		if on and voice and VoiceReaders.all("kokoro").is_empty() and _bake != null:
			_bake.list_singers(func() -> void: _build_parts()))
	var o := e.options
	# a voice after the first sings the tune the first's Melody makes
	var pr := _row("Melody" if voice else "Pattern", o if not voice or k == "vocal" else null)
	if voice and k != "vocal":
		pr.queue_free()
	var pat := OptionButton.new()
	pat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pat.fit_to_longest_item = false
	_auto_item(pat, Registry.label(SongParts.PATTERNS, String(chose["pattern"])) if not cfg.has("pattern") else "", "")
	for p in SongParts.patterns_for(k, has_ref):
		pat.add_item(Registry.label(SongParts.PATTERNS, p))
		pat.set_item_metadata(pat.item_count - 1, p)
		pat.set_item_tooltip(pat.item_count - 1, Registry.blurb(SongParts.PATTERNS, p))
		if p == String(cfg.get("pattern", "")):
			pat.select(pat.item_count - 1)
	pat.item_selected.connect(func(i: int) -> void: _set_part(k, "pattern", String(pat.get_item_metadata(i))))
	pr.add_child(pat)
	if voice:
		_voice_rows(o, k, cfg)
	else:
		var ir := _row("Sound", o)
		var inst := OptionButton.new()
		inst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inst.fit_to_longest_item = false
		_auto_item(inst, Registry.label(Instruments.ROWS, String(chose["instrument"])) if not cfg.has("instrument") else "", "")
		for key in Instruments.for_part(k):
			inst.add_item(Registry.label(Instruments.ROWS, key))
			inst.set_item_metadata(inst.item_count - 1, key)
			inst.set_item_tooltip(inst.item_count - 1, Registry.blurb(Instruments.ROWS, key))
			if key == String(cfg.get("instrument", "")):
				inst.select(inst.item_count - 1)
		inst.item_selected.connect(func(i: int) -> void: _set_part(k, "instrument", String(inst.get_item_metadata(i))))
		ir.add_child(inst)
		var playing: Array = []
		var named: Array = []
		var counted := {}
		for sec in score().get("sections", []):
			var label := String(sec["label"])
			counted[label] = int(counted.get(label, 0)) + 1
			named.append({"key": sec.get("key", ""), "name": "%s %d" % [label, int(counted[label])] if int(sec.get("lyric", -1)) >= 0 or counted[label] > 1 or label not in ["Intro", "Outro"] else label})
			if (sec["parts"] as Array).has(k):
				playing.append(sec.get("key", ""))
		_used_in_row(o, k, cfg, named, playing)
	var roll := _button("Roll", "This part drawn again, alone: what of it is on Auto - %s - and the details of its notes." \
		% ("the tune itself, what it sings, the sections it sings in, its singer and how they sing" if k == "vocal" else
			("what it sings, the sections it sings in, its singer and how they sing" if voice else "its pattern and its sound")),
		func() -> void: roll_part(k))
	roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.add_child(roll)
	_drawn_dial(o, "Level", -24.0, 6.0, 0.5, cfg.get("level"), float(_sounded(k).get("level", row["level"])),
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


## What a picker offers first: Auto, the roll's choice, saying what it drew ([param drawn]) where it is the one in use.
static func _auto_item(picker: OptionButton, drawn: String, meta: Variant) -> void:
	picker.add_item("Auto · " + drawn if not drawn.is_empty() else "Auto")
	picker.set_item_metadata(picker.item_count - 1, meta)
	picker.set_item_tooltip(picker.item_count - 1, "Drawn by the roll: the song's number and this part's.")
	picker.select(picker.item_count - 1)


## What the score made of part [param k]: its pattern and sound, as the roll drew them where [param cfg] says nothing.
func _chosen(k: String, cfg: Dictionary) -> Dictionary:
	var s := score()
	if SongParts.is_voice(k):
		var v := Composer.voice_of(s, k)
		if not v.is_empty():
			return {"pattern": String(v.get("pattern", "composed")), "instrument": ""}
		return Composer.choice_of("vocal", cfg, int(_block.get("seed", 1)), _ref, false)
	else:
		for p in s.get("parts", []):
			if String(p["key"]) == k:
				return {"pattern": String(p["pattern"]), "instrument": String(p["instrument_key"])}
	return Composer.choice_of(k, cfg, int(_block.get("seed", 1)), _ref, false)


## What this roll drew of the song as a whole, and what of the reference it kept.
func _roll_line() -> String:
	var s := score()
	if s.is_empty() or not s.has("roll"):
		return ""
	var roll: Dictionary = s["roll"]
	var key: Dictionary = s["key"]
	var bits: Array = ["%d BPM" % int(roundf(float(s["tempo"]))), MusicTheory.key_name(int(key["tonic"]), String(key["scale"]))]
	if float(roll.get("swing", 0.5)) > 0.5:
		bits.append("swung")
	bits.append("%d bars" % int(s["bars"]))
	var line := " · ".join(bits)
	if not _ref.is_empty():
		var kept: Array = (roll.get("kept", []) as Array).duplicate()
		for p in s.get("parts", []):
			if String(p["pattern"]) == "reference":
				kept.append({"drums": "drums", "bass": "bass line"}.get(String(p["key"]), String(p["key"])))
		if String(((s.get("voices", []) as Array).front() if not (s.get("voices", []) as Array).is_empty() else {}).get("pattern", "")) == "reference":
			kept.append("tune")
		line += "\nFrom the reference: " + (", ".join(kept) if not kept.is_empty() else "nothing")
	return line


## What a part's entry says under its name: its pattern, its sound or singer, muted.
func _entry_line(k: String, cfg: Dictionary) -> String:
	var chose := _chosen(k, cfg)
	var line := Registry.label(SongParts.PATTERNS, String(chose["pattern"]))
	if SongParts.is_voice(k):
		var v := Composer.voice_of(score(), k)
		var bits: Array = [Registry.label(SongParts.SINGS, String(v.get("sings", "tune"))), _singer_name(k, cfg)]
		if k == "vocal":
			bits.push_front(line)
		var sections: Array = v.get("sections", [])
		var all := Lyrics.parse(_words_text).size()
		if sections.size() < all:
			bits.append(", ".join(PackedStringArray(_section_names().filter(func(n: String) -> bool:
				return sections.has(_section_names().find(n))))) if not sections.is_empty() else "sings nowhere")
		line = " · ".join(PackedStringArray(bits))
	else:
		line += " · " + Registry.label(Instruments.ROWS, String(chose["instrument"]))
	return line + (" · muted" if bool(cfg.get("mute", false)) else "")


## The Used in row of part [param k]: a toggle each of [param named] (`{key, name}`, the sections it may be used in), those
## in [param used] pressed - dimmed while its settings name none, the line-ups' and the roll's; pressing one sets them
## all as they stand, and Auto lets them be drawn again.
func _used_in_row(o: VBoxContainer, k: String, cfg: Dictionary, named: Array, used: Array) -> void:
	var set_sections := cfg.get("sections") is Array
	var ir := _row("Used in", o)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.modulate = Color.WHITE if set_sections else Color(1, 1, 1, DRAWN_ALPHA)
	ir.add_child(flow)
	for n in named:
		var key: Variant = n["key"]
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.text = String(n["name"])
		b.button_pressed = used.has(key)
		b.tooltip_text = "Whether this part is used in this section of the song. Dimmed, the line-ups and the roll chose; pressed, they are set."
		b.toggled.connect(func(on: bool) -> void:
			var now: Array = used.duplicate()
			if on and not now.has(key):
				now.append(key)
			elif not on:
				now.erase(key)
			_set_part(k, "sections", now))
		flow.add_child(b)
	if set_sections:
		ir.add_child(_button("Auto", "Let the line-ups and the roll choose the sections again.", func() -> void: _set_part(k, "sections", {})))


## Each section of the note's words named as the card shows it: its label and how many of that label so far ("Chorus 2").
func _section_names() -> Array:
	var out: Array = []
	var seen := {}
	for s in Lyrics.parse(_words_text):
		var label := String(s["label"])
		seen[label] = int(seen.get(label, 0)) + 1
		out.append("%s %d" % [label, int(seen[label])])
	return out


## A Voice entry's own rows: what it sings (the tune or a harmony), the sections of the words it sings in (a toggle
## each; dimmed, the roll's), who sings, how tuned, and through how much vocoder. How the singer sings - its size, its
## vibrato and drift - is the voice's own, set in a Voice card's Lab and kept.
func _voice_rows(o: VBoxContainer, k: String, cfg: Dictionary) -> void:
	var sung := Composer.voice_of(score(), k)
	var wr := _row("Sings", o)
	var what := OptionButton.new()
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.fit_to_longest_item = false
	_auto_item(what, Registry.label(SongParts.SINGS, String(sung.get("sings", "tune"))) if not cfg.has("sings") else "", "")
	for x in SongParts.SINGS:
		what.add_item(Registry.label(SongParts.SINGS, x))
		what.set_item_metadata(what.item_count - 1, x)
		what.set_item_tooltip(what.item_count - 1, Registry.blurb(SongParts.SINGS, x))
		if x == String(cfg.get("sings", "")):
			what.select(what.item_count - 1)
	what.item_selected.connect(func(i: int) -> void: _set_part(k, "sings", String(what.get_item_metadata(i))))
	wr.add_child(what)
	var names := _section_names()
	var named: Array = []
	for n in names.size():
		named.append({"key": n, "name": names[n]})
	_used_in_row(o, k, cfg, named, sung.get("sections", []))
	var sr := _row("Singer", o)
	var singer: Dictionary = cfg["singer"] if cfg.get("singer") is Dictionary else {}
	var who := _singer_picker(singer, _singer_name(k, cfg) if singer.is_empty() else "")
	who.item_selected.connect(func(i: int) -> void: _set_part(k, "singer", who.get_item_metadata(i)))
	sr.add_child(who)
	var style: Dictionary = sung.get("style", Composer.STYLE)
	_drawn_dial(o, "Tune", 0.0, 1.0, 0.05, cfg.get("tune"), float(style.get("tune", Composer.STYLE["tune"])),
		"How tuned the voice is: at 0 a singer's own glides into each note, its vibrato and drift; at 1 every note a hard step, the tuned sound of a vocoder or a pitch corrector.",
		func(v: float) -> void: _set_part(k, "tune", v, false))
	_drawn_dial(o, "Vocoder", 0.0, 1.0, 0.05, cfg.get("vocoder"), float(sung.get("vocoder", 0.0)),
		"How much of the voice is heard through a vocoder: a synth playing the melody's own notes, given the voice's words. At 1 the robot alone, every note exactly in tune; at 0 the voice as it sings.",
		func(v: float) -> void: _set_part(k, "vocoder", v, false))


## Who sings voice [param k] ([param cfg] its settings): the one set, or the one this roll drew.
func _singer_name(k: String, cfg: Dictionary) -> String:
	var s: Variant = cfg.get("singer") if cfg.get("singer") is Dictionary and not (cfg["singer"] as Dictionary).is_empty() \
		else Composer.voice_of(score(), k).get("singer", Composer.SINGER)
	return Singers.name_of(s) if s is Dictionary else "a voice"


## A picker of who sings, [param singer] chosen in it: Auto (the roll's, saying [param drawn]), the voices kept in the
## library that can sing (♥, first: a voice made for the song on a Voice card), then Kokoro's readers.
func _singer_picker(singer: Dictionary, drawn: String) -> OptionButton:
	var who := OptionButton.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.fit_to_longest_item = false
	who.tooltip_text = "Who sings: a voice kept in the library (♥) - made on a Voice card, its size set by its Tone and its vibrato and drift in its Lab, then kept - or one of Kokoro's readers. Auto: the roll's pick among them."
	_auto_item(who, drawn, {})
	for name in _voices:
		who.add_item("♥ " + String(name))
		who.set_item_metadata(who.item_count - 1, {"kept": String(name), "name": String(name)})
		if String(singer.get("kept", "")) == String(name):
			who.select(who.item_count - 1)
	var readers := VoiceReaders.all("kokoro")
	if readers.is_empty():
		for i in Delivery.KOKORO_READERS.size():
			readers.append({"i": i, "reader": String(Delivery.KOKORO_READERS[i])})
	for r in readers:
		who.add_item(String(r["reader"]))
		who.set_item_metadata(who.item_count - 1, {"voice": "kokoro", "speaker": int(r["i"]), "name": String(r["reader"])})
		if not singer.is_empty() and String(singer.get("kept", "")).is_empty() and int(r["i"]) == int(singer.get("speaker", -1)):
			who.select(who.item_count - 1)
	return who


## Part [param k]'s [param field] set to [param value]; an empty one (Auto) is the roll's again.
func _set_part(k: String, field: String, value: Variant, rebuild := true) -> void:
	var parts := _parts()
	var cfg: Dictionary = parts.get(k, {}) if parts.get(k, {}) is Dictionary else {}
	if (value is String and (value as String).is_empty()) or (value is Dictionary and (value as Dictionary).is_empty()):
		cfg.erase(field)
	else:
		cfg[field] = value
	parts[k] = cfg
	_block["parts"] = parts
	_changed(rebuild)


func _parts() -> Dictionary:
	var p: Variant = _block.get("parts")
	if p is Dictionary and not (p as Dictionary).is_empty():
		return (p as Dictionary).duplicate(true)
	var out := {}
	for k in Composer.default_parts(_ref, not Lyrics.parse(_words_text).is_empty()):
		out[k] = {}
	return out


## A new song: every setting drawn again but what a roll keeps ([method Composer.rolled]); Back brings this one back.
func roll_song() -> void:
	_remember()
	_block = Composer.rolled(_block, SongCode.fresh(int(_block.get("seed", 1))))
	_changed()


## Part [param k] drawn again alone: a number of its own, every setting of it drawn but whether it is muted.
func roll_part(k: String) -> void:
	_remember()
	var parts := _parts()
	var cfg: Dictionary = parts.get(k, {}) if parts.get(k, {}) is Dictionary else {}
	parts[k] = Composer.part_rolled(cfg, SongCode.fresh(int(cfg.get("seed", 1))))
	_block["parts"] = parts
	_changed()


## The song's settings from [param code] ([SongCode]), the note's words, source and reference kept: "" when it read,
## else what is wrong with it - said, and nothing changed. Back brings the song before back.
func enter_code(code: String) -> String:
	var got := SongCode.applied(_block, code)
	if String(got["why"]).is_empty() and SongCode.of(got["block"]) != SongCode.of(_block):
		_remember()
	return _put_code(got, "The song's settings are back from its code.")


## The song before the last roll or code entered.
func back() -> void:
	if not _history.is_empty():
		_put_code(SongCode.applied(_block, String(_history.pop_back())), "The song before is back.")
	_show_back()


func _put_code(got: Dictionary, said: String) -> String:
	_typed = false
	if not String(got["why"]).is_empty():
		_say("That code is %s." % String(got["why"]))
		_show_code(true)
		return String(got["why"])
	if SongCode.of(got["block"]) != SongCode.of(_block):
		_block = got["block"]
		_load_ref()
		_changed()
		_say(said)
	_show_code(true)
	return ""


## This song's code kept for Back.
func _remember() -> void:
	var c := SongCode.of(_block)
	if _history.is_empty() or String(_history.back()) != c:
		_history.append(c)
		if _history.size() > HISTORY_MOST:
			_history.pop_front()
	_show_back()


func _show_back() -> void:
	if _back != null:
		_back.disabled = _history.is_empty()


## The code as the settings stand, unless a person is typing one ([param now] true writes it anyway).
func _show_code(now := false) -> void:
	if _code != null and (now or not _typed):
		_code.text = SongCode.of(_block)


## A press anywhere outside the code field lets it go: a line edit keeps the keyboard until something else takes it,
## and most of the card takes nothing.
func _input(event: InputEvent) -> void:
	if _code == null or not _code.has_focus() or not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	var local := _code.make_input_local(event) as InputEventMouseButton
	if local != null and not Rect2(Vector2.ZERO, _code.size).has_point(local.position):
		_code.release_focus()


## Dial [param sl] showing [param v], its readout with it: dimmed where the roll drew it ([param drawn]).
static func _show_dial(sl: HSlider, v: float, drawn: bool) -> void:
	var row := sl.get_parent() as Control
	sl.set_value_no_signal(v)
	var i := sl.get_index() + 1
	if i < row.get_child_count() and row.get_child(i) is Label:
		(row.get_child(i) as Label).text = "%.2f" % v
	row.modulate = Color(1, 1, 1, DRAWN_ALPHA) if drawn else Color.WHITE


## A dial on [param box] for a setting [param set] (null where unset), showing [param drawn] dimmed where it is unset;
## moved by hand, it is set and lit.
func _drawn_dial(box: Container, label: String, lo: float, hi: float, step: float, set: Variant, drawn: float, tip: String,
		apply: Callable) -> HSlider:
	var sl := Card.slider_row(box, label, lo, hi, step, drawn, tip + " Dimmed, the roll drew it; moved, it is set.", apply)
	_show_dial(sl, float(set) if _number(set) else drawn, not _number(set))
	sl.value_changed.connect(func(_v: float) -> void: (sl.get_parent() as Control).modulate = Color.WHITE)
	return sl


## What the score made of part [param k] ([member score]): its part, or the voice.
func _sounded(k: String) -> Dictionary:
	var s := score()
	if SongParts.is_voice(k):
		return Composer.voice_of(s, k)
	for p in s.get("parts", []):
		if String(p["key"]) == k:
			return p
	return {}


static func _number(v: Variant) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT]


## The block changed: shown again ([param rebuild] false for a dial, whose own row is under the hand), the timeline if it
## is open, and the stream once the dials settle (STREAM_SETTLE).
func _changed(rebuild := true) -> void:
	if rebuild:
		_refresh()
	else:
		_show_code()
	if _stream != null and is_inside_tree():
		# counted, not timed: the timer runs on the frames' clock, which the wall clock does not keep pace with
		_settle += 1
		var mine := _settle
		get_tree().create_timer(STREAM_SETTLE).timeout.connect(func() -> void:
			if _stream != null and mine == _settle:
				_stream.update(score()))
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
	if _voices_at != VoiceLibrary.version:
		_voices = Singers.kept()
		_voices_at = VoiceLibrary.version
	var made_of := JSON.stringify([_block, _words_text, _ref_seen, _voices]).sha1_text()
	if made_of != _score_of:
		_score = score_of(_block, _words_text, _ref, _voices)
		_score_hash = stamp(_score)
		_score_of = made_of
		_count_kept()
	return _score


## The score of composed Sound [param block] over the note's words [param words], its reference as read [param ref] and the kept
## voices [param voices] ([method Singers.kept]): [method score]'s, and whoever plays the note's song without its card.
static func score_of(block: Dictionary, words: String, ref: Dictionary, voices: Dictionary) -> Dictionary:
	return Composer.score(block, {"lyrics": Lyrics.parse(words), "reference": ref, "voices": voices})


## What a mix made from [param score] is stamped with (`made.json`'s `hash`, [constant SongBake.MADE]): its keys sorted, so the same
## score read from the note or held by a card stamps alike.
static func stamp(score: Dictionary) -> String:
	return JSON.stringify(score, "", true).sha1_text()


## The mix in [param folder] marked made from a score stamped [param hash]: what is written, `{hash, at}`.
static func mark_made(folder: String, hash: String) -> Dictionary:
	var made := {"hash": hash, "at": Time.get_unix_time_from_system()}
	var mf := FileAccess.open(ProjectSettings.globalize_path(folder).path_join(SongBake.MADE), FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify(made))
		mf.close()
	return made


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
	for line in SongBake.lines_of(_score):
		var wav := SongBake.take_of(folder(), line["voice"], line["phrase"])
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
	_made = mark_made(folder(), _making_hash)
	_show_save()
	_say("✓  The song is made: %s" % path.get_file())
	# a bake keeps only the takes its lines name: the stream reads what is there now
	if _stream != null:
		_stream.takes_changed()
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
	var phrases := SongBake.lines_of(s)
	if not phrases.is_empty():
		var t := PipelineRow.new("takes", "Lines sung")
		var kept := _kept
		t.state = "running" if busy and _bake.job() == "sing" else ("made" if kept >= phrases.size() else ("on_demand" if streams() else "missing"))
		t.said = "%d lines, %d kept" % [phrases.size(), mini(kept, phrases.size())] + (" - sung as the song plays" if t.state == "on_demand" else "")
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
	# heard as it is made, the song needs no mix until it is exported or played on another note's screen, which make it; a mix made
	# from what the song was is stale all the same, since that is what is played until then
	if streams() and m.state == "missing":
		m.state = "on_demand"
	var voices := (s.get("voices", []) as Array).size()
	m.said = _status if busy else ("%d parts%s, %s" % [(s.get("parts", []) as Array).size(),
		(" and the voice" if voices == 1 else " and %d voices" % voices) if voices > 0 else "", Clock.text(float(s.get("length", 0.0)))]
		+ (" - made by an export" if m.state == "on_demand" else (" - made from the song as it was" if m.state == "stale" else "")))
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
