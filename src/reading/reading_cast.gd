extends RefCounted
class_name ReadingCast

## ReadingCast - the voices a reading is read in, a part of [ReadingPanel]: one per speaker the script cues
## ([method refresh]), each a whole settings page (the voice, the reader within it, the tone, the pace and
## pauses, the delivery dials, the room, the ink) - and the rows that edit the one on screen, with the Turn and
## Hesitate rows that belong to no one voice. On the Voice card the voice on screen is its model, Test, who reads
## and its ink; everything else of its sound is in its Lab ([ReaderBrowser]), whose rows this builds and reads.
## Its block is the document's `voice:` ([method capture], [method apply]): the Voice card's (next/notes.md).
##
## A part of its panel (next/structure.md, step 23): it asks the panel for the text the cast is read from, the
## reading on the stream (a voice changed, a pace changed, a dial moved) and the status line, and is asked a
## voice's settings by name ([method cfg_of]) by everything that reads one - the stream, the audition and the
## export.

## The [ReadingPanel] this is a part of: everything read through it is something this part is handed.
var panel: ReadingPanel

# Voices, plural and named. One tab per reader, and the tabs are whoever the script says is speaking - a line of
# its own hands the text after it to that name:
#
#     <!-- speaker: Emily White -->     (what a chapter file carries)
#     [speaker: Emily White]            (the same thing, typeable)
#
# The script is the cast list. There is no + and no x: the tabs are derived from the cues ([method refresh]) every
# time the text changes or a document is read. Text before the first cue is [constant Manuscript.NARRATOR]'s.
# A tab is a whole settings page: the voice, the reader, the tone, the pace, the pauses, the delivery dials and the
# room are all per-tab.
#
# A name that leaves the script keeps its voice ([member _stash]): it is hidden, not forgotten, and comes back
# exactly as it was.
#
# The cue must own its line (see [constant Manuscript.SPEAKER]): a mis-parsed cue silently reads the rest of the
# chapter in the wrong voice.
#
# Hesitations. `<!-- hesitation -->` anywhere in the text, mid-sentence included, is a longer rest at that point;
# `<!-- hesitation: 2.5 -->` names its own length in seconds. The Hesitate row sets the length of a bare one and
# switches them all. The rest is spliced into the take where the host reports the gap after a word, so it lands
# between two words and never inside one (see [method Splice.chunk]).
const HESITATE_DEFAULT := 1.5
const HESITATE_MAX := 6.0
var voice_pick: OptionButton
var _test: Button
var _rate: HSlider
var _rate_row: HBoxContainer
var _pause: HSlider
var voice_meta: Array = []
var _want_voice := ""          # remembered selection, applied once voices load
var _made_voice := ""          # a voice made while the note is open, the reader's once the list has it
var _fx_echo: HSlider
var _dynamics: HSlider
var _arc: HSlider
var _effort: HSlider
var _fx_res: HSlider
var _fx_room: HSlider
var _fx_presence: HSlider
var _fx_lean: HSlider
var _fx_seat: HSlider
var _fx_near: HSlider
var _fx_pad: HSlider
var _tone: OptionButton
## The reader on screen, by its number in its voice (`speaker:`): picked in the Lab.
var _speaker := 0
var _speaker_top := 100000       # the voice's last reader, once the host has listed it
var _many := false               # whether the voice on screen holds more than one reader
var _speaker_about: Label        # who reads (VoiceReaders), or the blend
var _lab: ReaderBrowser          # the Voice row's Lab… (ReaderBrowser)
## A blend of readers ([VoiceBlend]): the tab on screen's, "" for its one reader alone. Ticked in the Lab on a
## voice whose readers blend; another voice ends it.
var _blend := ""
var _blending := {}              # the backends whose readers blend, as the host said ([method offer_blends])
## Ghost Notes' own voice as the tab on screen has it ([FormantVoice], the row's `formant:`): bred in the Lab's
## fishing game, read where the tab's voice is the formant one.
var _formant := {}
var _turn: HSlider
var _hesitate: HSlider
var _hesitate_on: CheckBox
var _tabs: VBoxContainer      # one row per speaker the script names
var _cast_head: Label
var _tab_group: ButtonGroup
var _names := PackedStringArray()  # the tabs, in order of first appearance in the script
var _slots: Array = []         # [SLOT_DEFAULTS-shaped Dictionary], one per tab, beside _names
var _stash := {}               # name -> settings, for voices the script no longer cues
var _order := PackedStringArray()  # every voice's name in the order the document lists them - the first is the reader's
var slot := 0                 # which tab the controls are currently showing
var _cast_timer: Timer         # re-derives the tabs once typing pauses
var _syncing := false          # writing controls from a slot must not re-plan
var _repace_timer: Timer       # one re-plan per slider gesture, not one per pixel

## The ink: which pen this voice writes in, where the medium writes by hand (the Notebook).
## Not a sound, so changing it restarts nothing; it reaches the page at the next Play.
var _ink_pick: OptionButton
var _ink_raw := ""               # the slot's ink as stored, kept when it is a hex the list lacks


func _init(owner: ReadingPanel) -> void:
	panel = owner


# --- the Voice card's rows ------------------------------------------------------------------------


func build_cast(box: VBoxContainer) -> void:
		# The handover rest, above the tabs because it belongs to no tab: it is the silence between two of them. It
		# needs no re-synthesis (the gap is spliced in as the chunks are joined), so it takes effect at the next handover.
	var turow := HBoxContainer.new()
	turow.add_theme_constant_override("separation", 8)
	box.add_child(turow)
	var tul := Label.new()
	tul.text = "Turn"
	tul.custom_minimum_size = Vector2(72, 0)
	tul.add_theme_font_size_override("font_size", 12)
	turow.add_child(tul)
	_turn = HSlider.new()
	_turn.min_value = 0.0
	_turn.max_value = Delivery.MAX_TURN_SCALE
	_turn.step = 0.05
	_turn.value = 1.0
	_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn.tooltip_text = ("EXTRA rest when the script CHANGES SPEAKER, shown in seconds beside it, on top of "
		+ "the ordinary rest between sentences. 1 is a little over half a second - enough to "
		+ "hear one reader stop and another begin; 0 hands over on the same beat as any other "
		+ "sentence, which reads as one person changing their mind rather than as two people. "
		+ "The whole rest is capped at four seconds however far this is pushed. It applies to "
		+ "every tab, because the pause belongs to the boundary and not to either voice, and it "
		+ "takes effect at the next handover - nothing has to be generated again.")
	_turn.value_changed.connect(func(_v: float) -> void:
		if _syncing:
			return
		panel.touch())
	turow.add_child(_turn)
		# The readout is in seconds, not the dial's multiplier: what matters is how long the gap is.
	var tur := Label.new()
	tur.custom_minimum_size = Vector2(42, 0)
	tur.add_theme_font_size_override("font_size", 12)
	tur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var show_turn := func(v: float) -> void:
		tur.text = "+%.1fs" % (Delivery.TURN_GAP * v)
	show_turn.call(_turn.value)
	_turn.value_changed.connect(show_turn)
	turow.add_child(tur)

		# Hesitations are global, like Turn: a `<!-- hesitation -->` belongs to a moment in the text, not to a voice. The
		# checkbox switches every marker off at once; the dial is the length of a bare marker, and a marker that names
		# its own length keeps it.
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 8)
	box.add_child(hrow)
	_hesitate_on = CheckBox.new()
	_hesitate_on.text = "Hesitate"
	_hesitate_on.button_pressed = true
	_hesitate_on.custom_minimum_size = Vector2(72, 0)
	_hesitate_on.add_theme_font_size_override("font_size", 12)
	_hesitate_on.tooltip_text = ("Honor the script's <!-- hesitation --> markers: a longer rest "
		+ "at exactly that point, mid-sentence or between paragraphs, for dramatic effect. Off "
		+ "reads straight through them as if they were not there.")
	hrow.add_child(_hesitate_on)
	_hesitate = HSlider.new()
	_hesitate.min_value = 0.2
	_hesitate.max_value = HESITATE_MAX
	_hesitate.step = 0.05
	_hesitate.value = HESITATE_DEFAULT
	_hesitate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hesitate.tooltip_text = ("How long a bare <!-- hesitation --> rests, in seconds, on top of "
		+ "whatever pause the text already has there. A marker that names its own length - "
		+ "<!-- hesitation: 2.5 --> - keeps it whatever this says. Takes effect from the next "
		+ "chunk; nothing already made is regenerated, because the rest's length is spliced "
		+ "in rather than asked of the voice.")
	hrow.add_child(_hesitate)
	Card.readout(hrow, _hesitate, "s")
	var on_hesitate := func(_v: Variant) -> void:
		if _syncing:
			return
		_hesitate.editable = _hesitate_on.button_pressed
		panel.touch()
	_hesitate.value_changed.connect(on_hesitate)
	_hesitate_on.toggled.connect(on_hesitate)
		# Shown where the script can carry the mark, by its Script card's mode (never its settings section: a table's is
		# "cards", which offers nothing): a panel whose palette has no hesitation mark keeps the values in the voice
		# block and shows no row.
	hrow.visible = ScriptMarks.for_mode(panel.script_mode()).has("hesitation")

		# The tabs: one per name the script cues, derived rather than managed (see the note on the speaker cues above).
		# Everything below this row belongs to the selected tab; the Play button beside the voice picker does not, it
		# reads the whole script. A list with a heading, one row per person, each saying what voice they have now.
	_cast_head = Label.new()
	_cast_head.add_theme_font_size_override("font_size", 12)
	_cast_head.mouse_filter = Control.MOUSE_FILTER_STOP
	_cast_head.tooltip_text = ("The voices are the speakers the script names - a line of its "
		+ "own reading <!-- speaker: Emily --> hands the text after it to Emily - and the "
		+ "list follows the script as it changes. Pick a person to edit their voice below; "
		+ "Test hears it on its own. A name that drops out of the script keeps its settings "
		+ "for when it comes back. Play still reads the whole script.")
	box.add_child(_cast_head)
	_tabs = VBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 2)
	_tabs.tooltip_text = _cast_head.tooltip_text
	box.add_child(_tabs)
	_tab_group = ButtonGroup.new()
	_cast_timer = Timer.new()
	_cast_timer.one_shot = true
	_cast_timer.wait_time = 0.4
	_cast_timer.timeout.connect(func() -> void: refresh(panel._cast_text()))
	panel.add_child(_cast_timer)


## The voice: the model, Test and Lab… on the card, with who reads under them and the ink; the tone, the pace and
## pauses, the delivery dials and the room in the Lab ([ReaderBrowser]). Every one of them belongs to the tab that
## is showing.
func build_voice(box: VBoxContainer) -> void:
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 8)
	box.add_child(vrow)
	var vl := Label.new()
	vl.text = "Voice"
	vl.custom_minimum_size = Vector2(72, 0)
	vl.add_theme_font_size_override("font_size", 12)
	vrow.add_child(vl)
	voice_pick = OptionButton.new()
	voice_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Sized by the row, not by its longest voice: a picker as wide as "libritts high (downloads)" pushes the whole
		# panel out (see SidePanel._check_width)
	voice_pick.fit_to_longest_item = false
	voice_pick.clip_text = true
	voice_pick.tooltip_text = "Which voice model reads: a Piper model, kokoro, or formant - Ghost Notes' own synthesizer, no model at all, its voice bred in Lab…'s fishing game. A model that holds more than one reader (libritts, kokoro) picks who reads in Lab…. Each model has its own license - it appears under the panel when you pick one. Changing this regenerates whatever has not been played yet."
	voice_pick.item_selected.connect(func(_i: int) -> void:
		if not _syncing:
			_voice_picked())
	vrow.add_child(voice_pick)
	# Play and stop are the transport's, along the bottom of the stage (Space plays and pauses).

		# Audition one voice, without the chapter: reads a fixed passage (ReadingAudition.PASSAGE) in the voice on the
		# selected tab, with no stage, subtitles or Director.
	_test = Button.new()
	_test.text = "Test"
	_test.tooltip_text = ("Hear the selected tab's voice on its own: a short fixed passage, "
		+ "read with every setting on this tab and played without any visuals. The same "
		+ "words every time, so two voices - or two settings of one - can be compared by "
		+ "ear. Press again to stop. Starting a test ends a reading in progress.")
	_test.disabled = true
	_test.pressed.connect(press_test)
	vrow.add_child(_test)
	var lab := Button.new()
	lab.text = "Lab…"
	lab.focus_mode = Control.FOCUS_NONE
	lab.tooltip_text = ("The selected tab's voice, worked on in one place with Test at its top: its Tone, Pace, Pause, "
		+ "delivery dials and room, and on a voice of many readers who reads - each with their gender and a description "
		+ "(libritts: how they sound, from LibriTTS-P; kokoro: accent and Kokoro's own grade), filtered and searched. On "
		+ "kokoro, tick two or more to blend them into a new voice, and shape it across each paragraph (each reader's "
		+ "share, breath, push, noise). On formant, the fishing game that breeds its voices: every voice cast or held "
		+ "is this tab's. Every change reaches the reading as it is made.")
	lab.pressed.connect(_open_lab)
	vrow.add_child(lab)

	_speaker_about = Label.new()
	_speaker_about.add_theme_font_size_override("font_size", 11)
	_speaker_about.modulate = Color(1, 1, 1, 0.75)
	_speaker_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speaker_about.visible = false
	_speaker_about.mouse_filter = Control.MOUSE_FILTER_STOP
	_speaker_about.tooltip_text = "Who reads, on a voice of more than one reader: perceived gender and a description - for libritts how the voice sounds (LibriTTS-P, LINE Corporation, CC BY 4.0), for kokoro its accent and Kokoro's own grade of its training data - or the blend made in Lab…; on formant, the seed the tab reads in and the traits it leans on."
	box.add_child(_speaker_about)

		# The rest of the voice is the Lab's: built once, hung on the Voice row, so its rows are in the tree with the card.
	_lab = ReaderBrowser.new(self)
	var sound := _lab.build(vrow)
	sound.add_child(ReaderBrowser._heading("Delivery"))
	_build_sound(sound)
	_build_ink_row(box)


## The voice's own rows, in the Lab's column [param box]: the tone, the pace and pauses, the delivery dials, and
## under Space where the voice is (the room, its distance, its side, the bed under it).
func _build_sound(box: VBoxContainer) -> void:
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	box.add_child(trow)
	var tl := Label.new()
	tl.text = "Tone"
	tl.custom_minimum_size = Vector2(72, 0)
	tl.add_theme_font_size_override("font_size", 12)
	trow.add_child(tl)
	_tone = OptionButton.new()
	_tone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tone.tooltip_text = "The reading's overall manner: pace, pitch, how much the model varies itself, how evenly it divides the words, and whether it is whispered or muffled - all of it the VOICE, and none of it the dials below, which stay yours. The pitch shift moves the formants with it, so the reader reads as a different SIZE - which is what makes Spooky larger and lower, Excited smaller and higher. A kokoro voice takes the pace, pitch, whisper and muffle; it has no variation to set, so that part does nothing there. Regenerates the un-played chunks."
	for k in Delivery.TONE_PRESETS:
		_tone.add_item(String(k))
	_tone.item_selected.connect(func(_i: int) -> void:
		if _syncing:
			return
		capture_slot()
				# a tone changes the model's own parameters, so un-played chunks are regenerated, as a pace change does
		if panel._stream.has_reading():
			panel._stream.repace()
		panel.touch())
	trow.add_child(_tone)

		# Shown only if the backend reports duration_control: the surface is built from capabilities().
	_rate_row = HBoxContainer.new()
	_rate_row.add_theme_constant_override("separation", 8)
	_rate_row.visible = false
	box.add_child(_rate_row)
	var rl := Label.new()
	rl.text = "Pace"
	rl.custom_minimum_size = Vector2(72, 0)
	rl.add_theme_font_size_override("font_size", 12)
	_rate_row.add_child(rl)
	_rate = HSlider.new()
		# VITS length_scale is stable well past 0.7, and an audiobook read often wants slower than "slightly slow".
	_rate.min_value = 0.4
	_rate.max_value = 1.6
	_rate.step = 0.05
	_rate.value = 1.0
	_rate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rate.tooltip_text = "Speaking rate. Takes effect from the next chunk - already-generated audio keeps its pace."
	_rate.value_changed.connect(func(_v: float) -> void:
		if _syncing:
			return
		_repace_timer.start())
	_rate_row.add_child(_rate)
	Card.readout(_rate_row, _rate, "x")

		# Pause: how long the reading rests on punctuation, as a multiple of the host's default rests (roughly a tenth
		# of a second on a comma, a quarter on a colon, a third at a sentence end). VITS runs straight through a comma
		# and a colon, so the host splices the silence in around the mark.
		#
		# Always visible, unlike Pace (no duration_control needed). Not a live buffer effect like Echo/Ambience: it
		# changes what gets synthesized, so it takes the debounced re-plan path below, as a pace change does.
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	box.add_child(prow)
	var pl := Label.new()
	pl.text = "Pause"
	pl.custom_minimum_size = Vector2(72, 0)
	pl.add_theme_font_size_override("font_size", 12)
	prow.add_child(pl)
	_pause = HSlider.new()
	_pause.min_value = 0.0
	_pause.max_value = 10.0
	_pause.step = 0.05
	_pause.value = 1.0
	_pause.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause.tooltip_text = "How long to rest on punctuation - commas, semicolons, colons and sentence ends. It scales the WHOLE rest, the model's own included, so every mark keeps its share of the reading at every setting rather than the long ones running away from the short ones. 1 is the natural rest; 0 runs straight through; 10 is five times natural, a two-and-a-half second full stop, and deliberately too much for most material. A quicker Tone rests proportionally less at the same setting - that is what quicker means - so a fast reading wants a higher number here than a slow one. Takes effect from the next chunk; already-generated audio keeps its pauses."
	_pause.value_changed.connect(func(_v: float) -> void:
		if _syncing:
			return
		_repace_timer.start())
	prow.add_child(_pause)
	Card.readout(prow, _pause, "x")

		# Debounced: a slider drag emits a value per pixel, and each change throws away work in flight.
	_repace_timer = Timer.new()
	_repace_timer.wait_time = 0.3
	_repace_timer.one_shot = true
	_repace_timer.timeout.connect(func() -> void:
				# Capture first: _repace re-requests from the slot store, not from the controls.
		capture_slot()
		panel._stream.repace()
		panel._persist())
	panel.add_child(_repace_timer)

		# Ambience: the formant voice's own effects, over any PCM (VoiceFX). Off by default.
		# Delivery, not effect: the discourse layer Piper cannot supply (it never sees the paragraph, so every sentence
		# starts from the same register at the same rate). See piper._discourse_plan for the rules.
	_dynamics = _fx_slider(box, "Dynamics", 0.5,
		"How much the READING's timing follows its own structure: a sentence at the end of a "
		+ "paragraph is drawn out, a short one after a long one lands harder, a question runs a "
		+ "little quicker. 0 reads every sentence at the same rate. At the top a closing sentence "
		+ "runs about a third longer than an opening one, which is deliberately more than any "
		+ "reader would do - if a chapter seems to be getting slower and slower as it goes, this "
		+ "is the dial, not Arc.")
	_effort = _fx_slider(box, "Effort", 0.35,
		"Vocal effort across a paragraph - which is not the same as volume. A louder voice has a "
		+ "brighter source spectrum, not just a higher level, so this moves the two together: "
		+ "opening a paragraph with a little more push and easing off toward the end. Level "
		+ "alone reads as the reader standing further away; the brightness is what makes it read "
		+ "as them easing off instead. 0 is off, 1 is about 6dB and a firm tilt top to bottom.")
	_arc = _fx_slider(box, "Arc", 0.4,
		"Pitch shape ACROSS a paragraph, in semitones. A speaker opens a new paragraph in a higher "
		+ "register and settles as it goes, then resets on the next - it is what makes a paragraph "
		+ "land rather than just stop. 0 is off, 0.15 is half a semitone top to bottom, 0.4 is "
		+ "one and a half, and 1 is four. The whole travel is usable now: the shift holds the "
		+ "reader's own formants, so the register moves without the speaker changing SIZE, and "
		+ "the ceiling is set by what a speaker would actually do rather than by the DSP.")
	box.add_child(ReaderBrowser._heading("Space"))
	_fx_echo = _fx_slider(box, "Echo", 0.0,
		"The room the voice is in. Low settings are a small close room - the repeat is short enough "
		+ "to fuse with the voice rather than be heard as a separate sound. It opens out into a "
		+ "distinct slapback with a long tail as you raise it, so this changes the SIZE of the "
		+ "space, not just how loud it is.")
		# The room, the same one Masking has (see [RoomFX], which owns the dial and leaves each mode only its engine).
		# Separate from Echo above: Echo is discrete repeats, this is the diffuse tail behind them; most rooms are both.
	_fx_room = _fx_slider(box, "Room", 0.0,
		"The size of the space around the reader. Where Echo is a repeat you can hear arrive, "
		+ "this is the diffuse tail behind it - no countable events, just the room answering. "
		+ "Low is a small studio whose tail is gone before the next word; the top is a hall that "
		+ "rings for seconds. Resonance sets its color, exactly as it does in Masking: dark and "
		+ "swallowed at 0, bright and ringing at 1. It is baked into the exported take, so what "
		+ "you hear here is what renders.")
	_fx_res = _fx_slider(box, "Resonance", 0.0,
		"Sympathetic tones tuned to the reader's own pitch, ringing when the voice rings and dying "
		+ "when it stops - the room answering, rather than a chord played over the top. It follows "
		+ "the speaking register, so it moves with the voice instead of fighting it.")
	_fx_presence = _fx_slider(box, "Presence", 1.0,
		"How close the reader is. 1 is right here; lower moves them away, dulling the high end "
		+ "first the way air does and only then dropping the level. Distance is a filter before it "
		+ "is a volume, which is why this is not a master gain.")
	_fx_lean = _fx_slider(box, "Lean", 0.0,
		"The reader leaning toward one side of a microphone in the middle and back, the way an "
		+ "ASMR recording moves between your ears. Only the voice moves; the room and the bed stay "
		+ "put. 0 is still. Low settings rest at center and lean now and then, holding a side for "
		+ "a while; higher, the rests and holds get shorter and the reader crosses straight to the "
		+ "other side more often, until at 1 it is a slow, constant sway. The far ear always keeps "
		+ "at least 30% of the voice. It is in the exported take as well.")
	_fx_near = _fx_slider(box, "Near", 0.0,
		"The reader coming in close to the microphone, or backing off, a sentence at a time. Closer, "
		+ "the voice gains warmth and the room falls away; backed off, the reverse. Often the reader "
		+ "drops their voice to come in, softer and quieter, so closer is not always louder. "
		+ "0 is still. Low settings make occasional, subtle moves; higher settings move farther "
		+ "and more often, with shorter rests, until at 1 the reader is always moving in or out. "
		+ "With Lean up too, an approach often goes toward one side, and a lean reaches furthest "
		+ "up close. The softer voice is chosen when a sentence is made, so a move takes effect "
		+ "from the sentences not yet made.")
	_fx_seat = _fx_slider(box, "Seat", 0.0,
		"Where this voice sits, in degrees round the table: 0 at the far side, 90 at its right, -90 at its left, 180 at your elbow. It "
		+ "says which ear the voice is heard in, and, in a game played at a table, where its dice come from. The room stays where it is.")
	_fx_seat.min_value = -180.0
	_fx_seat.max_value = 180.0
	_fx_seat.step = 5.0
	_fx_pad = _fx_slider(box, "Ambience", 0.0,
		"A sustained ambient bed underneath, in the reader's own key - long tones that keep "
		+ "sounding through the pauses, rather than reverb of the voice. It ducks under speech and "
		+ "swells in the gaps, and it is what plays alone through the Intro hold. Any setting plays "
		+ "the bed at full level; the dial is SEVERITY - how often a low bass swell answers the "
		+ "reader's pitch moving. Low is the bed alone; higher, the bass comes more often.")


func _build_ink_row(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var l := Label.new()
	l.text = "Ink"
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	_ink_pick = OptionButton.new()
	_ink_pick.focus_mode = Control.FOCUS_NONE
	_ink_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in NotebookLayout.INKS:
		_ink_pick.add_item(String(k).capitalize())
	_ink_pick.tooltip_text = ("The pen this voice writes in, in the Notebook: a color per speaker "
		+ "tells the voices apart on the page without naming them. Black unless set. Saved on "
		+ "the voice as `ink:` - a hex color written there works too.")
	_ink_pick.item_selected.connect(func(i: int) -> void:
		if _syncing:
			return
		_ink_raw = "" if i == 0 else String(NotebookLayout.INKS.keys()[i])
		capture_slot())
	row.add_child(_ink_pick)
		# Only where the medium inks a voice's words (the Notebook's `ink`); a Letter is written in its pens' inks.
	(panel._medium_rows.get_or_add("ink", []) as Array).append(row)


## A voice/delivery slider. Every slider in this panel carries a `tip`.
func _fx_slider(box: VBoxContainer, name: String, initial: float, tip := "") -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.tooltip_text = tip          # the gap between the label and the slider
	box.add_child(row)
	var l := Label.new()
	l.text = name
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
		# A Label ignores the mouse by default, so pointing at the name would otherwise show nothing.
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.tooltip_text = tip
	row.add_child(l)
	var sl := HSlider.new()
	sl.tooltip_text = tip
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = initial
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(_v: float) -> void:
		if _syncing:
			return
		capture_slot()
		panel._stream.live_fx()
		panel.touch())
	row.add_child(sl)
	Card.readout(row, sl)
	return sl


## The script is being typed: the tabs follow it once the typing pauses.
func follow_text() -> void:
	if _cast_timer != null:
		_cast_timer.start()


## The Test button says what pressing it does now: stop the audition ([param on]), or start one.
func show_testing(on: bool) -> void:
	if _test != null:
		_test.text = "Test ■" if on else "Test"
	if _lab != null:
		_lab.show_testing(on)


## Test, the Voice card's and the Lab's: a press while a test plays always stops it, whatever was
## changed meanwhile, and only the next press starts one, in what is picked then.
func press_test() -> void:
	if _lab != null:
		_lab.hush()
	panel._on_test()


## A backend that can change its pace was found: the Pace row is shown.
func show_pace() -> void:
	if _rate_row != null:
		_rate_row.visible = true


# --- the voice block, and what is kept between sessions -------------------------------------------


## The whole cast: every voice, keyed by the name the script cues it with, including names the text no longer
## uses (so rewriting a scene does not lose a character's voice), the reader's first ([method reader]). The
## controls are captured first, since they, not [member _slots], are the truth for the tab on screen. Which voice
## is on screen is not the document's.
func capture() -> Dictionary:
	capture_slot()
	return {"turn": _turn.value, "voices": cast_dict(),
		"hesitate": _hesitate.value, "hesitate_on": _hesitate_on.button_pressed}


## The voice block, to the cast. A block with no cast changes nothing: `_merge` gives every row every key, so a
## voice written by an older build arrives with defaults, but a block with no `voices` is a document never given
## a voice, and blanking the panel's cast for it would be wrong. A list of voices is the numbered tabs this
## replaced, read the way the settings are.
func apply(cfg: Dictionary) -> void:
	var rows: Variant = cfg.get("voices", {})
	var cast: Dictionary = _merge_cast(rows as Dictionary) if rows is Dictionary \
		else _cast_from_rows(rows if rows is Array else [], panel._cast_text())
	if cast.is_empty():
		return
		# The reader is the first voice listed, whatever its name. A voice named for the reader's cue
		# ([constant Manuscript.NARRATOR]) listed after it can never be spoken, so it goes.
	var first := String(cast.keys()[0])
	if first != Manuscript.NARRATOR:
		cast.erase(Manuscript.NARRATOR)
	_stash = cast
	_order = PackedStringArray(cast.keys())
	_names = PackedStringArray()
	_slots = []
	_syncing = true
	_turn.value = clampf(float(cfg.get("turn", _turn.value)), 0.0, Delivery.MAX_TURN_SCALE)
	_hesitate.value = clampf(float(cfg.get("hesitate", _hesitate.value)),
		_hesitate.min_value, HESITATE_MAX)
	_hesitate_on.button_pressed = bool(cfg.get("hesitate_on", _hesitate_on.button_pressed))
	_hesitate.editable = _hesitate_on.button_pressed
	_syncing = false
	refresh(panel._cast_text())
		# The room, once, exactly as [method _load_persisted] does it: the chain is stateful and a tab switch alone does
		# not re-dial it.
	Delivery.apply_fx(panel._stream.fx, slot_cfg(slot))
		# Whatever is on the stream was cut against the previous cast.
	panel._stream.mark_stale()
	panel.touch()


## The cast's own state, written to [Settings] beside the draft: every voice, the Turn and Hesitate
## rows, and which voice is on screen.
func persist() -> void:
		# The controls are the truth for the tab on screen; capture before writing, or the tab being edited saves
		# what it held when last switched away from.
	capture_slot()
	Settings.write(panel.section(), "cast", cast_dict())
	Settings.write(panel.section(), "turn", _turn.value)
		# A new key, not "tab" (an int index): Settings' no-op guard compares the stored value with the new one, and
		# an int against a String is a script error.
	Settings.write(panel.section(), "tab_name", tab_name())
	Settings.write(panel.section(), "hesitate", _hesitate.value)
	Settings.write(panel.section(), "hesitate_on", _hesitate_on.button_pressed)


## ...and read back: the rows, the cast (from an older build's numbered tabs, or its single voice,
## when that is what is stored) and the tabs from the stored draft - before a document is bound.
func load_stored() -> void:
	_syncing = true
	_turn.value = clampf(float(Settings.read(panel.section(), "turn", 1.0)), 0.0, Delivery.MAX_TURN_SCALE)
	_hesitate.value = clampf(float(Settings.read(panel.section(), "hesitate", HESITATE_DEFAULT)),
		_hesitate.min_value, HESITATE_MAX)
	_hesitate_on.button_pressed = bool(Settings.read(panel.section(), "hesitate_on", true))
	_hesitate.editable = _hesitate_on.button_pressed
	_syncing = false
	var cast: Variant = Settings.read(panel.section(), "cast", {})
	if cast is Dictionary and not (cast as Dictionary).is_empty():
		_stash = _merge_cast(cast as Dictionary)
	else:
				# Migration from the numbered tabs: tab N was cued `<!-- speaker: N -->`, and tab 1 also read everything
				# before the first cue, so it becomes both "1" and the narrator.
		var rows: Variant = Settings.read(panel.section(), "slots", [])
		_stash = _cast_from_rows(rows if rows is Array else [],
			str(Settings.read(panel.section(), "text", "")))
		if _stash.is_empty():
			# ...and from the single-voice file before that, read exactly once.
			_stash[Manuscript.NARRATOR] = _merge({
				"voice": str(Settings.read(panel.section(), "voice", "")),
				"speaker": int(Settings.read(panel.section(), "speaker", 0)),
				"tone": int(Settings.read(panel.section(), "tone", 0)),
				"pace": float(Settings.read(panel.section(), "pace", 1.0)),
				"pause": float(Settings.read(panel.section(), "pause", 1.0)),
			})
	_order = PackedStringArray(_stash.keys())
	var tab: Variant = Settings.read(panel.section(), "tab_name", "")
	_names = PackedStringArray()
	_slots = []
	# From the stored draft first, so the tabs exist before the box is bound below.
	refresh(str(Settings.read(panel.section(), "text", "")), str(tab) if tab is String else "")


# --- the cast: voices, plural and named -----------------------------------------------------------


## Every voice the panel knows, shown or not: name -> settings, in the order the document lists
## them (a new one last) - so the reader stays first ([method reader]).
func cast_dict() -> Dictionary:
	var out := {}
	for k in _order:
		var i := _names.find(k)
		if i >= 0:
			out[k] = slot_cfg(i)
		elif _stash.has(k):
			out[k] = _merge(_stash[k] as Dictionary)
	for k in _stash:
		if not out.has(k):
			out[k] = _merge(_stash[k] as Dictionary)
	for i in _names.size():
		if not out.has(_names[i]):
			out[_names[i]] = slot_cfg(i)
	return out


## The reader's voice: the first one the document lists, whatever it is called. Those words, and a cue naming
## [constant Manuscript.NARRATOR] (as a table show hands a line back to its reader), are the reader's; a cast with
## no voice yet starts with one of that name.
func reader() -> String:
	return _order[0] if not _order.is_empty() else Manuscript.NARRATOR


## The voice a script's [param name] is: the reader's for [constant Manuscript.NARRATOR], else its own.
func _who(name: String) -> String:
	return reader() if name == Manuscript.NARRATOR else name


func _merge_cast(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		if d[k] is Dictionary and not str(k).strip_edges().is_empty():
			out[str(k).strip_edges()] = _merge(d[k] as Dictionary)
	return out


## The numbered tabs this replaced, as names: row i was cued `<!-- speaker: i+1 -->`, and the first row read
## everything before the first cue, so it becomes the NARRATOR, and also "1" only when the script cues `1`.
func _cast_from_rows(rows: Array, body := "") -> Dictionary:
	var cued := Manuscript.speakers(body)
	var out := {}
	for i in rows.size():
		if not (rows[i] is Dictionary):
			continue
		if i == 0:
			out[Manuscript.NARRATOR] = _merge(rows[i] as Dictionary)
			if cued.has("1"):
				out["1"] = _merge(rows[i] as Dictionary)
		else:
			out[str(i + 1)] = _merge(rows[i] as Dictionary)
	return out


## The tabs follow the script. Re-derive them from [param body]: every name it cues, in order of first
## appearance, each with its own settings (kept if it had a tab, restored if stashed, otherwise a copy of the
## first voice). Names that left the script go to [member _stash]. The tab on screen stays on the same name when
## it survives, since its index means nothing once names come and go.
##
## Cheap and idempotent (it runs on every pause in typing) and it touches nothing when the cast is unchanged, so a
## reading in progress is only marked stale by a real change.
func refresh(body: String, want := "") -> void:
	# The cards that follow the text (the book's pictures) follow it on the same beat.
	panel._script_text_changed(body)
	if _rate != null:
		capture_slot()
	var names := PackedStringArray()
	for n in Manuscript.speakers(body):
		if not names.has(_who(n)):
			names.append(_who(n))
		# Nothing written yet is not a cast of one: a show's new episode, not yet made, hands an empty script. Until
		# there are words, the tabs are every voice the note keeps; words with no cue are the reader's.
	if body.strip_edges().is_empty() and not _order.is_empty():
		names = _order.duplicate()
	if names.is_empty():
		names = PackedStringArray([reader()])
	for n in names:
		if not _order.has(n):
			_order.append(n)
	var showing := want if not want.is_empty() else tab_name()
	if names == _names and not _slots.is_empty():
		if not want.is_empty() and names.has(want) and names.find(want) != slot:
			_select_tab(names.find(want))
		return
	var old := {}
	for i in _names.size():
		old[_names[i]] = _slots[i]
	for k in old:
		_stash[k] = old[k]
	var seed_row: Dictionary = ReadingPanel.SLOT_DEFAULTS.duplicate(true)
	if not _slots.is_empty():
		seed_row = slot_cfg(0)
	elif not _stash.is_empty():
		seed_row = _merge(_stash[_stash.keys()[0]] as Dictionary)
	var slots: Array = []
	for n in names:
		if _stash.has(n):
			slots.append(_merge(_stash[n] as Dictionary))
			_stash.erase(n)
		else:
			slots.append(seed_row.duplicate())
	var changed := _names.size() > 0 and names != _names
	_names = names
	_slots = slots
	slot = maxi(0, _names.find(showing))
	_rebuild_tabs()
	_apply_slot(slot)
	if changed:
		panel._stream.mark_stale()
		panel.touch()


func tab_name() -> String:
	return _names[slot] if slot >= 0 and slot < _names.size() else ""


## A stored slot merged onto [constant SLOT_DEFAULTS]: every key present, every value the right type, and an
## index that cannot be out of range. Everything downstream reads settings through here, so a tab that vanished
## while its passages are queued degrades to the first voice rather than to a null.
func slot_cfg(i: int) -> Dictionary:
	if _slots.is_empty():
		return ReadingPanel.SLOT_DEFAULTS.duplicate(true)
	return _merge(_slots[clampi(i, 0, _slots.size() - 1)] as Dictionary)


## Which ear [param who] is heard in ([method Delivery.pan_of_seat]): what a voice over the line is placed by ([method ReadingJoin.side_between]).
func pan_of(who: String) -> float:
	return Delivery.pan_of_seat(float(cfg_of(who).get("seat", 0.0)))


## Seconds a word each engine says at pace 1, its rests counted in ([method said_word]).
const SAID_AT_PACE_ONE := {"piper": 0.52, "kokoro": 0.463}


## How long a word takes voice [param cfg] (a cast entry: its `voice`, the engine, and its `pace`) to say, in
## seconds, its sentences' rests counted in: the pace each engine was measured at, quickened by its own. What a
## show's passages are written to cover.
static func said_word(cfg: Dictionary) -> float:
	var engine := String(cfg.get("voice", ""))
	var base := float(SAID_AT_PACE_ONE.get(engine, SAID_AT_PACE_ONE["piper"]))
	return base / clampf(float(cfg.get("pace", 1.0)), 0.25, 4.0)


## The settings of the voice named [param who] - how a chunk asks, since a tab's index moves whenever the script
## gains or loses a speaker, and a reading in flight must not change voice when a name is typed further down.
func cfg_of(who: String) -> Dictionary:
	who = _who(who)
	var i := _names.find(who)
	if i >= 0:
		return slot_cfg(i)
	if _stash.has(who):
		return _merge(_stash[who] as Dictionary)
	return slot_cfg(0)


func _merge(row: Dictionary) -> Dictionary:
	var out := ReadingPanel.SLOT_DEFAULTS.duplicate(true)
	for k in out:
		if not row.has(k):
			continue
				# The defaults double as the schema: an int key stays an int through a ConfigFile round trip.
		match typeof(out[k]):
			TYPE_INT: out[k] = int(row[k])
			TYPE_FLOAT: out[k] = float(row[k])
			TYPE_DICTIONARY: out[k] = (row[k] as Dictionary).duplicate(true) if row[k] is Dictionary else {}
			_: out[k] = str(row[k])
	return out


## The controls -> the selected slot.
func capture_slot() -> void:
	if slot < 0 or slot >= _slots.size() or _rate == null:
		return
	_slots[slot] = {
		"voice": _selected_voice_id(), "speaker": _speaker, "blend": _blend, "formant": _formant.duplicate(true),
		"tone": _tone.selected, "pace": _rate.value, "pause": _pause.value,
		"dynamics": _dynamics.value, "arc": _arc.value, "effort": _effort.value,
		"echo": _fx_echo.value, "room": _fx_room.value, "resonance": _fx_res.value,
		"presence": _fx_presence.value, "ambience": _fx_pad.value, "lean": _fx_lean.value,
		"near": _fx_near.value, "seat": _fx_seat.value,
		"ink": _ink_value(),
	}
	_refresh_tab_labels()


## A slot -> the controls. Every write is inside `_syncing`, because each of these controls answers a change by
## throwing away work in flight; unguarded, showing a tab would restart the reading at the previous tab's settings.
func _apply_slot(i: int) -> void:
	var s := slot_cfg(i)
	_syncing = true
	_want_voice = String(s["voice"])
	_blend = String(s["blend"])
	_formant = (s["formant"] as Dictionary).duplicate(true)
	for k in voice_meta.size():
		if String((voice_meta[k] as Dictionary).get("id", "")) == _want_voice:
			voice_pick.select(k)
			break
	_tone.select(clampi(int(s["tone"]), 0, Delivery.TONE_PRESETS.size() - 1))
	_rate.value = float(s["pace"])
	_pause.value = float(s["pause"])
	_dynamics.value = float(s["dynamics"])
	_arc.value = float(s["arc"])
	_effort.value = float(s["effort"])
	_fx_echo.value = float(s["echo"])
	_fx_room.value = float(s["room"])
	_fx_res.value = float(s["resonance"])
	_fx_presence.value = float(s["presence"])
	_fx_pad.value = float(s["ambience"])
	_fx_lean.value = float(s["lean"])
	_fx_near.value = float(s["near"])
	_fx_seat.value = float(s.get("seat", 0.0))
	_show_ink(String(s["ink"]))
		# After the voice, because it sets how many readers there are (a speaker id only means something against its model).
	_show_voice_license()
	_speaker = clampi(int(s["speaker"]), 0, _speaker_top)
	_describe_speaker()
	_syncing = false


func _rebuild_tabs() -> void:
	if _tabs == null:
		return
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	var on := StyleBoxFlat.new()
	on.bg_color = Color(0.30, 0.55, 0.75, 0.45)
	on.border_color = Color(0.55, 0.85, 1.0, 0.9)
	on.border_width_left = 3
	on.set_content_margin_all(4)
	var off := StyleBoxFlat.new()
	off.bg_color = Color(1, 1, 1, 0.04)
	off.set_content_margin_all(4)
	off.content_margin_left = 7
	var hover := off.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 1, 1, 0.10)
	for i in _names.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _tab_group
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.set_pressed_no_signal(i == slot)
		var at := i
		b.pressed.connect(func() -> void: _on_tab_selected(at))
		_tabs.add_child(b)
	_refresh_tab_labels()


## Each row: the name, then the voice it has now (model, reader, tone), so the whole cast reads at a glance and two
## people left on the same voice are obvious.
func _refresh_tab_labels() -> void:
	if _tabs == null:
		return
	if _cast_head != null:
		_cast_head.text = "Voices (%d)  -  from the script's speaker cues" % _names.size()
	var tones := Delivery.TONE_PRESETS.keys()
	for i in mini(_tabs.get_child_count(), _names.size()):
		var s := slot_cfg(i)
		var model := String(s["voice"])
		var multi := false
		for v in voice_meta:
			if String((v as Dictionary).get("id", "")) == model:
				model = String((v as Dictionary).get("name", model))
				multi = int((v as Dictionary).get("speakers", 1)) > 1
				break
		if model.is_empty():
			model = "default voice"
		var desc := model + ((" #%d" % int(s["speaker"])) if multi else "")
		if not blend_of(s).is_empty():
			desc = model + " " + VoiceBlend.line(blend_of(s), true)
		desc += "  ·  " + String(tones[clampi(int(s["tone"]), 0, tones.size() - 1)])
		var b := _tabs.get_child(i) as Button
		b.text = "%s    %s" % [_names[i], desc]
		b.tooltip_text = "%s - %s. Pick to edit this voice." % [_names[i], desc]


func _select_tab(i: int) -> void:
	_on_tab_selected(i)
	for c in _tabs.get_children():
		(c as Button).set_pressed_no_signal(c.get_index() == slot)


func _on_tab_selected(i: int) -> void:
	if _syncing or i == slot:
		return
	capture_slot()
	slot = clampi(i, 0, _slots.size() - 1)
	_apply_slot(slot)


func _selected_voice_id() -> String:
	var i := voice_pick.selected
	if i < 0 or i >= voice_meta.size():
		return _want_voice
	return String(voice_meta[i].get("id", ""))


func _ink_value() -> String:
	return _ink_raw


func _show_ink(v: String) -> void:
	_ink_raw = v
	if _ink_pick == null:
		return
	var k := v.strip_edges().to_lower()
	var i := NotebookLayout.INKS.keys().find("black" if k.is_empty() else k)
	_ink_pick.select(i)            # -1 (nothing shown) for a hex: it is kept, not replaced
	_ink_pick.tooltip_text = _ink_pick.tooltip_text.get_slice("\n\nNow: ", 0) \
		+ ("\n\nNow: " + v if i < 0 and not v.is_empty() else "")


# --- the voices the host has: the picker, the readers, the license --------------------------------


func fill_voices(voices: Array) -> void:
	var keep := _selected_voice_id()  # asked again ([method voice_made]): what is picked stays picked
	voice_meta = voices
	# a voice whose speakers the host describes itself (kokoro's voicepacks): the Lab reads them
	for v in voices:
		if (v as Dictionary).has("readers"):
			VoiceReaders.offer(String(v.get("id", "")), v["readers"], String(v.get("readers_about", "")))
	voice_pick.clear()
	for v in voices:
		var mark := "" if bool(v.get("installed", false)) else "  (downloads)"
		voice_pick.add_item("%s%s" % [String(v.get("name", v.get("id", "?"))), mark])
	if voices.is_empty():
		panel._set_status("No voices available - see the >_ log.")
		return
	var want := keep if not keep.is_empty() else ReadingPanel.DEFAULT_VOICE
	for i in voices.size():
		if String((voices[i] as Dictionary).get("id", "")) == want:
			voice_pick.select(i)
			break
	_test.disabled = false
	_refresh_tab_labels()           # model names are known now, not just ids
	panel._can_play = true            # from here on Play is always live
	_show_voice_license()
	panel.warm_voice(_selected_voice_id())
	if not _made_voice.is_empty():
		_read_in(_made_voice)


## A voice made while the note is open (an actor's own, trained on the Actor card): the reader's from the moment
## the list asked again holds it ([method ReadingPanel.voice_made]).
func voice_made(id: String) -> void:
	_made_voice = id


func _read_in(id: String) -> void:
	var tab := _names.find(reader())
	for k in voice_meta.size():
		if String((voice_meta[k] as Dictionary).get("id", "")) != id:
			continue
		_made_voice = ""
		if tab >= 0 and tab != slot:
			_select_tab(tab)
		voice_pick.select(k)
		_voice_picked()
		return


## The voice picked: the slot keeps it, and what was read in the old one is read again.
func _voice_picked() -> void:
	_blend = ""                      # a blend is of one voice's readers
	_show_voice_license()
	panel.warm_voice(_selected_voice_id())
	capture_slot()
		# A voice change is not a re-pace: _repace keeps the stream and appends at the new setting, which for a voice
		# would splice a second speaker mid-narration, and old requests left in flight would keep both models loaded.
		# So: kill the session and read again in the new voice.
	if panel._stream.has_reading():
		panel._stream.restart()
	panel.touch()


## Under the Voice row: who reads, or the blend. Hidden on a single-speaker voice, or when nothing is known about
## the reader.
func _describe_speaker() -> void:
	if _speaker_about == null:
		return
	if _selected_voice_id() == FormantVoice.ID:
		_speaker_about.text = FormantVoice.line(FormantVoice.voice_of(_formant))
		_speaker_about.visible = not _speaker_about.text.is_empty()
		return
	var d := VoiceReaders.describe(_selected_voice_id(), _speaker)
	var mixed := VoiceBlend.line(_blend) if blends(_selected_voice_id()) else ""
	_speaker_about.text = mixed if not mixed.is_empty() else VoiceReaders.line(d, 8)
	_speaker_about.visible = _many and (not d.is_empty() or not mixed.is_empty())


## The Lab ([ReaderBrowser]): the voice on screen's readers, picked - or ticked and blended - and its own rows.
func _open_lab() -> void:
	if _lab != null:
		_lab.open()


## The reader on screen, by its number.
func speaker_now() -> int:
	return _speaker


## The formant voice on screen ([member _formant]).
func formant_now() -> Dictionary:
	return _formant.duplicate(true)


## The Lab's fishing game, to the tab on screen: Ghost Notes' own voice [param voice] ([method FormantVoice.kept]),
## regenerating what has not played.
func pick_formant(voice: Dictionary) -> void:
	if voice == _formant:
		return
	_formant = voice.duplicate(true)
	capture_slot()
	_describe_speaker()
	if panel._stream.has_reading():
		panel._stream.repace()
	panel.touch()


## The blend on screen ([member _blend]).
func blend_now() -> String:
	return _blend


## The host says backend [param backend]'s readers blend (its `describe`): never a voice's row, whose every field
## keys the takes kept in it ([TakeCache]).
func offer_blends(backend: String) -> void:
	_blending[backend] = true


## Whether voice [param id]'s readers blend: its backend's do ([method offer_blends]) and it has more than one.
func blends(id: String) -> bool:
	for v in voice_meta:
		if String((v as Dictionary).get("id", "")) == id:
			return _blending.has(String((v as Dictionary).get("backend", ""))) \
				and int((v as Dictionary).get("speakers", 1)) > 1
	return false


## How many readers voice [param id] holds, as the host listed it (1 for a voice it has not listed).
func readers_of(id: String) -> int:
	for v in voice_meta:
		if String((v as Dictionary).get("id", "")) == id:
			return int((v as Dictionary).get("speakers", 1))
	return 1


## Voice [param id]'s name, as the host listed it.
func voice_name(id: String) -> String:
	for v in voice_meta:
		if String((v as Dictionary).get("id", "")) == id:
			return String((v as Dictionary).get("name", id))
	return id if not id.is_empty() else "default voice"


## The Lab's pick, to the tab on screen: reader [param speaker] and [param blend] ("" for that reader alone),
## regenerating what has not played. The same pick again changes nothing.
func pick(speaker: int, blend: String) -> void:
	if speaker == _speaker and blend == _blend:
		return
	_blend = blend
	_speaker = clampi(speaker, 0, _speaker_top)
	capture_slot()
	_describe_speaker()
	if panel._stream.has_reading():
		panel._stream.repace()
	panel.touch()


## Always shown: these checkpoints are licensed individually and the terms are inherited through fine-tuning.
func _show_voice_license() -> void:
	var i := voice_pick.selected
	if i < 0 or i >= voice_meta.size():
		return
	var v: Dictionary = voice_meta[i]
	var n := int(v.get("speakers", 1))
		# the formant voice keeps its own prosody: the host's paragraph dials are not its
	for dial in [_dynamics, _effort, _arc]:
		if dial != null:
			(dial as Control).get_parent().visible = String(v.get("id", "")) != FormantVoice.ID
	_many = n > 1
	_speaker_top = n - 1 if n > 1 else 100000      # a voice of one keeps the number as it is
	_speaker = clampi(_speaker, 0, _speaker_top)
	_describe_speaker()
	panel._set_status("%s - %s%s" % [String(v.get("id", "")), String(v.get("license", "unknown")),
		("  (%d speakers)" % n) if n > 1 else ""])


# --- what a request reads of a voice --------------------------------------------------------------


## Which checkpoint a slot reads with. A tab may name a voice this install does not have (a config copied between
## machines, a model deleted): it reads in whatever is selected rather than falling silent.
func voice_id_of(s: Dictionary) -> String:
	var want := String(s["voice"])
	for v in voice_meta:
		if String((v as Dictionary).get("id", "")) == want:
			return want
	var i := voice_pick.selected
	if i >= 0 and i < voice_meta.size():
		return String((voice_meta[i] as Dictionary).get("id", ""))
	return ""


## A slot's reader id, clamped to what its own model holds (slots are copied when a tab is added, so a speaker
## id chosen on libritts can outlive a switch to a single-speaker voice).
func speaker_of(s: Dictionary) -> int:
	var vid := voice_id_of(s)
	for v in voice_meta:
		if String((v as Dictionary).get("id", "")) == vid:
			return clampi(int(s["speaker"]), 0, maxi(0, int((v as Dictionary).get("speakers", 1)) - 1))
	return maxi(0, int(s["speaker"]))


## A slot's blend ([VoiceBlend]) as the host is asked it: "" where its voice's readers do not blend, so a
## blend left on a slot whose voice was changed in the note by hand is never sent to a model it means nothing to.
func blend_of(s: Dictionary) -> String:
	var spec := String(s.get("blend", ""))
	return spec if not spec.is_empty() and blends(voice_id_of(s)) and not VoiceBlend.parse(spec).is_empty() else ""


## The Turn dial: the extra rest at a handover, as a multiple of [constant Delivery.TURN_GAP].
func turn_scale() -> float:
	return _turn.value if _turn != null else 1.0


## The Hesitate row as it stands, for the plan ([method ReadingPlan.make]): whether a hesitation
## rests at all, and how long a bare one rests.
func hesitation() -> Dictionary:
	return {"hesitate": _hesitate_on == null or _hesitate_on.button_pressed,
		"bare": _hesitate.value if _hesitate != null else HESITATE_DEFAULT}
