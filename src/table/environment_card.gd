extends VBoxContainer
class_name EnvironmentCard

## EnvironmentCard - the Environment: what is round the scene a note is shown in, as a list (next/environment.md; [Surroundings]).
## Each element is a row of the card's list ([EnvironmentSection], drawn as the Props card draws props, [PropsCard]): the light, shafts
## of light, what drifts in the air, what is heard - each with its properties, Roll for another of it, Keep, Remove, and Used to set
## it aside. "+ Add to the environment" opens the Dex on what can be round a scene. Below them, a row for each thing on the Props card
## that throws light or makes a sound of its own ([method PropSection.lit], [method PropSection.heard]), its share tuned.
##
## Its block in a document is `environment:` ([constant Surroundings.KNOBS]). It hands the reading its part of the document a
## medium is drawn from ([member ReadingPanel.document_parts]: `environment`), and the sound it chose as the bed under the voice
## where no other card hands one, or where the one handed has no place of its own ([member ReadingPanel.bed], [member
## ReadingBed.under]). Changed while the note plays, the playing scene takes it at once (the live document's `environment`). A
## scene that hosts no environment reads none of it.
##
## Where a component's show makes what is round the scene ([member ReadingPanel.environment]: a table show's episode at its table,
## [EpisodeEnvironment]), the list is that show's, in place of the note's own.
##
## Each element that is heard has a Test: it alone, at the level it has under the voice, following what is changed on it until
## pressed again ([method test], [SoundTest]); and Refine…, a conversation with a designer who hears it and changes it, each change a
## version kept in the note's folder ([EnvironmentSoundDesign], [ElementVersions]). A note's scene hears its sounds as a table with no
## wind of its own does ([method heard]): a wind is planned for what is heard, or a wind element would be silent.

## The block this card keeps under a document's `ghost:` key.
const KEY := "environment"

## The list's rows, and the list drawing them.
var section: EnvironmentSection
var list: PropsCard
var _panel: ReadingPanel = null
var _spec := Surroundings.sanitize({})
## The note's folder (where a sound's Refine… and its versions are kept, "" for none) and its file.
var folder := ""
var note_path := ""
## What a Test plays, and the element it plays (-1 none).
var tester := SoundTest.new()
var _test_i := -1
## Its Level over everything heard round the scene, shown while anything is ([method _hears]), looked at again each second.
var _level_row: HBoxContainer
var _level: HSlider
var _since := 1.0


## This card for a note's panel, from what the panel says of itself ([method NoteCards.make]): its workspace, which is handed the
## environment's part of the document and, where nothing else hands one, its sound as the bed.
static func for_note(ctx: Dictionary) -> EnvironmentCard:
	var card := EnvironmentCard.new()
	card._panel = ctx.get("workspace") as ReadingPanel
	card.folder = String(ctx.get("folder", ""))
	card.note_path = String(ctx.get("path", ""))
	if card._panel != null:
		card._panel.document_parts[KEY] = func() -> Dictionary: return {KEY: card.capture()}
		if card._panel.bed.get_script() == ReadingBed:
			card._panel.bed = Bed.new(card)
		else:
			card._panel.bed.under = Bed.new(card)
	return card


func _init() -> void:
	add_theme_constant_override("separation", 8)
	_level_row = _make_level_row()
	add_child(_level_row)
	section = EnvironmentSection.new(self)
	list = PropsCard.new(sections)
	add_child(list)
	add_child(tester)


## What the list shows: the show's own where a component's show makes what is round the scene, else the note's.
func sections() -> Array:
	var shown: PropSection = _panel.environment.call() if _panel != null and is_instance_valid(_panel) else null
	return [shown if shown != null else section]


# --- the block ---------------------------------------------------------------------------------------------------------

func capture() -> Dictionary:
	return _spec.duplicate(true)


func apply(block: Dictionary) -> void:
	_spec = Surroundings.sanitize(block)
	_level.set_value_no_signal(Surroundings.level_of(_spec))
	_level.value_changed.emit(_level.value)
	list.refresh(true)


# --- its Level ---------------------------------------------------------------------------------------------------------

## The Level row: everything heard round the scene turned up or down (dB), kept in the block. The sound is part of the voice's take,
## so a change makes the take again.
func _make_level_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = "Level"
	l.custom_minimum_size = Vector2(56, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	_level = HSlider.new()
	_level.min_value = Surroundings.LEVEL_LEAST
	_level.max_value = Surroundings.LEVEL_MOST
	_level.step = 0.5
	# (written once a drag ends - each change makes the take again - so never by the wheel in passing)
	_level.scrollable = false
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level.tooltip_text = ("How loud everything heard round the scene is, in decibels: 0 as made, -6 about half, +6 about twice. It "
		+ "is laid into the voice's take, so a change makes the take again (the voice itself is not said again).")
	row.add_child(_level)
	var r := Label.new()
	r.custom_minimum_size = Vector2(56, 0)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_theme_font_size_override("font_size", 12)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(r)
	var shown := func(v: float) -> void: r.text = ("+%.1f dB" if v > 0.0 else "%.1f dB") % v
	shown.call(0.0)
	_level.value_changed.connect(shown)
	_level.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			_set_level(_level.value))
	row.visible = false
	return row


## Everything heard round the scene [param db] louder from now: kept in the block.
func _set_level(db: float) -> void:
	_spec["level"] = db
	_spec = Surroundings.sanitize(_spec)
	_changed()


## Whether anything is heard round the scene: an element of the note's, or a show's own (the bed it hands the reading).
func _hears() -> bool:
	if not Surroundings.in_use(_spec, "sound").is_empty():
		return true
	return _panel != null and is_instance_valid(_panel) and _panel.bed.of().has("make")


func _process(delta: float) -> void:
	_since += delta
	if _since < 1.0:
		return
	_since = 0.0
	_level_row.visible = _hears()


# --- what the list does ------------------------------------------------------------------------------------------------

## Element [param el] put round the scene: one of a kind a scene has once takes the place of the one there. "" done, else why not.
func add(el: Dictionary) -> String:
	var safe := Surroundings.element(el)
	if safe.is_empty():
		return "there is no such thing to add"
	var els: Array = _spec["elements"]
	if bool((Surroundings.KINDS[String(safe["kind"])] as Dictionary)["one"]):
		for i in els.size():
			if String((els[i] as Dictionary)["kind"]) == String(safe["kind"]):
				els[i] = safe
				return _changed()
	if els.size() >= Surroundings.MOST:
		return "a scene has at most %d things round it" % Surroundings.MOST
	els.append(safe)
	return _changed()


## Element [param i] taken away.
func remove(i: int) -> String:
	(_spec["elements"] as Array).remove_at(i)
	if i == _test_i:
		_test_i = -1
		tester.stop()
	elif i < _test_i:
		_test_i -= 1
	return _changed()


## Whether element [param i] is heard alone now ([method test]).
func testing(i: int) -> bool:
	return tester.playing() and _test_i == i


## Element [param i] heard alone, at the level it has under the voice, following what is changed on it; pressed again, stopped.
## "" done, else why not.
func test(i: int) -> String:
	if testing(i):
		_test_i = -1
		tester.stop()
		return ""
	var els: Array = _spec["elements"]
	if i < 0 or i >= els.size() or String((Surroundings.KINDS.get(String((els[i] as Dictionary)["kind"]), {}) as Dictionary).get("group", "")) != "sound":
		return "it makes no sound to hear"
	_test_i = i
	_keep_testing()
	return ""


## The Test made again from the element as it is now (left as it is where nothing it plays changed).
func _keep_testing() -> void:
	var els: Array = _spec["elements"]
	if _test_i < 0 or _test_i >= els.size():
		_test_i = -1
		tester.stop()
		return
	var el: Dictionary = (els[_test_i] as Dictionary).duplicate(true)
	el.erase("off")
	var made := heard({"elements": [el]})
	if (made["sound"] as Dictionary).is_empty():
		_test_i = -1
		tester.stop()
		return
	tester.play(String(made["key"]), func(rate: int, t0: float) -> SoundBed: return made_bed(made, rate, t0), Surroundings.BED_LEVEL)


## What the elements of [param spec] in use are heard as round a note's scene: `{sound, wind, ride, seed, key}` - the sound, a wind
## planned for it as a table with no wind of its own plans one (its own, or a breath: [method Soundscape.of_table]), its seed the
## sound's own, and `key` the sound as one value to tell a change by.
static func heard(spec: Dictionary) -> Dictionary:
	var sound := Surroundings.sound_of(spec)
	var key := JSON.stringify(sound)
	var made := Soundscape.of_table({"sound": sound}, hash(key))
	made["seed"] = hash(key)
	made["key"] = key
	return made


## What [method heard] gave, made into sound at [param rate] from show time [param t0].
static func made_bed(made: Dictionary, rate: int, t0: float) -> SoundBed:
	return Soundscape.new(made["sound"], made["wind"], int(made["seed"]), rate, t0, made["ride"])


## Element [param i] put in place of the one there ([param el], of the same kind: a version picked, a refinement landed). "" done,
## else why not.
func replace(i: int, el: Dictionary) -> String:
	var els: Array = _spec["elements"]
	if i < 0 or i >= els.size():
		return "it is no longer round the scene"
	var made := Surroundings.element(el)
	if made.is_empty() or String(made["kind"]) != String((els[i] as Dictionary)["kind"]):
		return "that would make it something else"
	els[i] = made
	return _changed()


## Element [param i] drawn again: a new number, every property not set drawn from it ([Roll]).
func roll(i: int) -> String:
	var el: Dictionary = (_spec["elements"] as Array)[i]
	var was := int(el["seed"])
	while int(el["seed"]) == was:
		el["seed"] = Roll.fresh()
	return _changed()


## Element [param i] set aside ([param off]) or used again.
func set_off(i: int, off: bool) -> String:
	var el: Dictionary = (_spec["elements"] as Array)[i]
	if off:
		el["off"] = true
	else:
		el.erase("off")
	return _changed()


## Property [param field] of element [param i] set to [param value], or unset (null): drawn by its number again.
func set_field(i: int, field: String, value: Variant) -> String:
	if field in Surroundings.OWN_KEYS:
		return "%s is no property of it" % field
	var el: Dictionary = ((_spec["elements"] as Array)[i] as Dictionary).duplicate(true)
	if value == null:
		el.erase(field)
	else:
		el[field] = value
	var made := Surroundings.element(el)
	if made.is_empty():
		return "that would make it nothing"
	(_spec["elements"] as Array)[i] = made
	return _changed()


## The share of thing [param name] in [param field] (`lights` or `heard`) set to [param value], or unset (null): as it is made.
func set_share(field: String, name: String, value: Variant) -> String:
	if value == null:
		(_spec[field] as Dictionary).erase(name)
	else:
		(_spec[field] as Dictionary)[name] = value
	_spec = Surroundings.sanitize(_spec)
	return _changed()


## Every thing on the panel's Props card's sections that throws light ([param kind] "lit") or makes a sound of its own ("heard"):
## `[{key, name}]`, each once.
func things(kind: String) -> Array:
	var out: Array = []
	var seen := {}
	if _panel == null:
		return out
	for sec in _panel.prop_sections:
		if not (sec is PropSection):
			continue
		for t in ((sec as PropSection).lit() if kind == "lit" else (sec as PropSection).heard()):
			var k := String((t as Dictionary).get("key", ""))
			if not k.is_empty() and not seen.has(k):
				seen[k] = true
				out.append(t)
	return out


# --- what it hands the reading -----------------------------------------------------------------------------------------

## The sound it chose, as the bed under the voice ([Soundscape]): none while nothing is heard.
class Bed extends ReadingBed:
	var card: EnvironmentCard

	func _init(c: EnvironmentCard) -> void:
		card = c

	func of(_export := false) -> Dictionary:
		var made := EnvironmentCard.heard(card._spec)
		if (made["sound"] as Dictionary).is_empty():
			return {"key": made["key"]}
		return {"key": made["key"], "make": func(rate: int, t0: float) -> SoundBed: return EnvironmentCard.made_bed(made, rate, t0)}

	func level() -> float:
		return Surroundings.BED_LEVEL

	func gain_db() -> float:
		return Surroundings.level_of(card._spec)


## The note touched, and a playing scene given the environment at once. "" (nothing went wrong), for the list to say.
func _changed() -> String:
	if _test_i >= 0:
		_keep_testing()
	if _panel == null:
		return ""
	_panel.touch()
	var subs: Node = _panel.subtitles if is_instance_valid(_panel) else null
	if subs != null and is_instance_valid(subs) and subs.get("document") is Dictionary:
		(subs.get("document") as Dictionary)[KEY] = capture()
	return ""
