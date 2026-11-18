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
## where no other card hands one ([member ReadingPanel.bed]). Changed while the note plays, the playing scene takes it at once (the
## live document's `environment`). A scene that hosts no environment reads none of it.

## The block this card keeps under a document's `ghost:` key.
const KEY := "environment"

## The list's rows, and the list drawing them.
var section: EnvironmentSection
var list: PropsCard
var _panel: ReadingPanel = null
var _spec := Surroundings.sanitize({})


## This card for a note's panel, from what the panel says of itself ([method NoteCards.make]): its workspace, which is handed the
## environment's part of the document and, where nothing else hands one, its sound as the bed.
static func for_note(ctx: Dictionary) -> EnvironmentCard:
	var card := EnvironmentCard.new()
	card._panel = ctx.get("workspace") as ReadingPanel
	if card._panel != null:
		card._panel.document_parts[KEY] = func() -> Dictionary: return {KEY: card.capture()}
		if card._panel.bed.get_script() == ReadingBed:
			card._panel.bed = Bed.new(card)
	return card


func _init() -> void:
	add_theme_constant_override("separation", 8)
	section = EnvironmentSection.new(self)
	list = PropsCard.new(func() -> Array: return [section])
	add_child(list)


# --- the block ---------------------------------------------------------------------------------------------------------

func capture() -> Dictionary:
	return _spec.duplicate(true)


func apply(block: Dictionary) -> void:
	_spec = Surroundings.sanitize(block)
	list.refresh(true)


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
	var el: Dictionary = (_spec["elements"] as Array)[i]
	if value == null:
		el.erase(field)
	else:
		el[field] = value
	(_spec["elements"] as Array)[i] = Surroundings.element(el)
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
		var sound := Surroundings.sound_of(card._spec)
		var key := JSON.stringify(sound)
		if sound.is_empty():
			return {"key": key}
		return {"key": key, "make": func(rate: int, t0: float) -> SoundBed: return Soundscape.new(sound, {}, hash(key), rate, t0)}

	func level() -> float:
		return Surroundings.BED_LEVEL


## The note touched, and a playing scene given the environment at once. "" (nothing went wrong), for the list to say.
func _changed() -> String:
	if _panel == null:
		return ""
	_panel.touch()
	var subs: Node = _panel.subtitles if is_instance_valid(_panel) else null
	if subs != null and is_instance_valid(subs) and subs.get("document") is Dictionary:
		(subs.get("document") as Dictionary)[KEY] = capture()
	return ""
