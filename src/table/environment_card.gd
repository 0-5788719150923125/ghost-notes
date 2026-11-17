extends VBoxContainer
class_name EnvironmentCard

## EnvironmentCard - the Environment: what is round the scene a note is shown in (next/environment.md; [Surroundings]). Its
## light (a preset - lamplight, candlelight, daylight, dusk, moonlight, no light - and how bright), shafts of light through the
## haze (how many, how strong), what drifts in the air and what is heard round it (each ticked together, with how much), and a
## dial for each thing in the scene that throws light - the lamp, a screen, a candle - from the Props card's sections ([method
## PropSection.lit]).
##
## Its block in a document is `environment:` ([constant Surroundings.KNOBS]). It hands the reading its part of the document a
## medium is drawn from ([member ReadingPanel.document_parts]: `environment`), and the sound it chose as the bed under the voice
## where no other card hands one ([member ReadingPanel.bed]). Changed while the note plays, the playing scene takes it at once (the
## live document's `environment`). A scene that hosts no environment reads none of it.

## The block this card keeps under a document's `ghost:` key.
const KEY := "environment"
## Light shafts, when first turned on: how many.
const RAYS_FIRST := 3
## How often the lit things the scene has are looked for again (seconds), while the card stands.
const LIT_EVERY := 1.0

var _panel: ReadingPanel = null
var _spec := Surroundings.KNOBS.duplicate(true)
var _syncing := false
var _light: OptionButton
var _bright: HSlider
var _rays_on: CheckBox
var _rays: HSlider
var _ray_strength: HSlider
var _air := {}                   # an air key -> its tick
var _air_amount: HSlider
var _sound := {}                 # a sound key -> its tick
var _sound_level: HSlider
var _lit_box: VBoxContainer
var _lit_seen := ""
var _lit_t := 0.0


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
	_build()


func _process(delta: float) -> void:
	_lit_t -= delta
	if _lit_t <= 0.0:
		_lit_t = LIT_EVERY
		_show_lit()


# --- the block ---------------------------------------------------------------------------------------------------------

func capture() -> Dictionary:
	return _spec.duplicate(true)


func apply(block: Dictionary) -> void:
	_spec = Surroundings.sanitize(block)
	_show()


# --- what it hands the reading -----------------------------------------------------------------------------------------

## The sound it chose, as the bed under the voice ([Soundscape]): none while nothing is ticked.
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
		return float(card._spec.get("sound_level", 0.5))


# --- the rows ----------------------------------------------------------------------------------------------------------

func _build() -> void:
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 8)
	add_child(lrow)
	lrow.add_child(_label("Light"))
	_light = OptionButton.new()
	_light.fit_to_longest_item = false
	_light.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_light.add_item("The scene's own")
	_light.set_item_metadata(0, "")
	_light.set_item_tooltip(0, "As the scene lights itself: a desk by its number, the Dispatch desk's hollow at night.")
	var tips := PackedStringArray(["The light the scene is in."])
	for k in Surroundings.LIGHTS:
		_light.add_item(Registry.label(Surroundings.LIGHTS, k))
		_light.set_item_metadata(_light.item_count - 1, k)
		_light.set_item_tooltip(_light.item_count - 1, Registry.blurb(Surroundings.LIGHTS, k))
		tips.append("%s: %s" % [Registry.label(Surroundings.LIGHTS, k), Registry.blurb(Surroundings.LIGHTS, k)])
	_light.tooltip_text = "\n\n".join(tips)
	_light.item_selected.connect(func(i: int) -> void: _put("light", String(_light.get_item_metadata(i))))
	lrow.add_child(_light)
	_bright = Card.slider_row(self, "Brightness", Surroundings.BRIGHTNESS.x, Surroundings.BRIGHTNESS.y, 0.05, 1.0,
		"How bright the whole scene is, over its light's own: 1 as the light is.", func(v: float) -> void: _put("brightness", v))
	_rays_on = CheckBox.new()
	_rays_on.text = "Light shafts"
	_rays_on.tooltip_text = "Shafts of light falling through the haze - through a window, a crack, the canopy. Unticked, the scene's own."
	_rays_on.toggled.connect(func(on: bool) -> void:
		if not _syncing:
			_put("rays", RAYS_FIRST if on else -1))
	add_child(_rays_on)
	_rays = Card.slider_row(self, "Shafts", 1, Surroundings.RAYS_MOST, 1, RAYS_FIRST, "How many shafts of light fall.",
		func(v: float) -> void: _put("rays", int(v)))
	_ray_strength = Card.slider_row(self, "Strength", 0.0, 1.0, 0.05, 0.6, "How strongly they light the haze.",
		func(v: float) -> void: _put("ray_strength", v))
	add_child(_label("In the air"))
	add_child(_ticks(Surroundings.AIR, _air, "air"))
	_air_amount = Card.slider_row(self, "Amount", Surroundings.AIR_AMOUNT.x, Surroundings.AIR_AMOUNT.y, 0.05, 1.0,
		"How much of what drifts: 1 as each is.", func(v: float) -> void: _put("air_amount", v))
	add_child(_label("Heard"))
	add_child(_ticks(Surroundings.SOUNDS, _sound, "sound"))
	_sound_level = Card.slider_row(self, "Level", 0.0, 1.0, 0.05, 0.5, "How loud what is heard round the scene is, under the voice.",
		func(v: float) -> void: _put("sound_level", v))
	_lit_box = VBoxContainer.new()
	_lit_box.add_theme_constant_override("separation", 6)
	add_child(_lit_box)
	_show()


## A tick for each row of [param table], into [param into] by key; each toggles its key in the block's [param field].
func _ticks(table: Dictionary, into: Dictionary, field: String) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	for k in table:
		var cb := CheckBox.new()
		cb.text = Registry.label(table, k)
		cb.tooltip_text = Registry.blurb(table, k)
		cb.toggled.connect(func(on: bool) -> void:
			if _syncing:
				return
			var list: Array = (_spec[field] as Array).duplicate()
			if on and not list.has(k):
				list.append(k)
			elif not on:
				list.erase(k)
			_put(field, Surroundings._ticks(list, table)))
		into[k] = cb
		flow.add_child(cb)
	return flow


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
	return l


## The rows as the block has them, telling no one.
func _show() -> void:
	if _light == null:
		return
	_syncing = true
	for i in _light.item_count:
		if String(_light.get_item_metadata(i)) == String(_spec["light"]):
			_light.select(i)
	_bright.set_value_no_signal(float(_spec["brightness"]))
	var rays := int(_spec["rays"])
	_rays_on.set_pressed_no_signal(rays >= 0)
	_rays.set_value_no_signal(maxi(rays, 1))
	_ray_strength.set_value_no_signal(float(_spec["ray_strength"]))
	_rays.get_parent().visible = rays >= 0
	_ray_strength.get_parent().visible = rays >= 0
	for k in _air:
		(_air[k] as CheckBox).set_pressed_no_signal(k in (_spec["air"] as Array))
	_air_amount.set_value_no_signal(float(_spec["air_amount"]))
	for k in _sound:
		(_sound[k] as CheckBox).set_pressed_no_signal(k in (_spec["sound"] as Array))
	_sound_level.set_value_no_signal(float(_spec["sound_level"]))
	_syncing = false
	_lit_seen = ""
	_show_lit()


## A dial for each thing in the scene that throws light ([method PropSection.lit] of every section on the panel), built again only
## when the things change.
func _show_lit() -> void:
	if _lit_box == null:
		return
	var lit := _lit_things()
	var key := JSON.stringify(lit)
	if key == _lit_seen:
		return
	_lit_seen = key
	for c in _lit_box.get_children():
		c.queue_free()
	if lit.is_empty():
		return
	_lit_box.add_child(_label("Lights"))
	for t in lit:
		var name := String((t as Dictionary)["key"])
		Card.slider_row(_lit_box, String((t as Dictionary)["name"]), Surroundings.LIGHT_SHARE.x, Surroundings.LIGHT_SHARE.y, 0.05,
			Surroundings.share_of(_spec, name), "How strongly %s throws its light: 1 as it is made, 0 dark." % String((t as Dictionary)["name"]).to_lower(),
			func(v: float) -> void: _set_light(name, v))


## Every thing that throws light on the panel's Props card's sections: `[{key, name}]`, each once.
func _lit_things() -> Array:
	var out: Array = []
	var seen := {}
	if _panel == null:
		return out
	for sec in _panel.prop_sections:
		if not (sec is PropSection):
			continue
		for t in (sec as PropSection).lit():
			var k := String((t as Dictionary).get("key", ""))
			if not k.is_empty() and not seen.has(k):
				seen[k] = true
				out.append(t)
	return out


func _put(field: String, v: Variant) -> void:
	if _syncing:
		return
	_spec[field] = v
	_spec = Surroundings.sanitize(_spec)
	_changed()
	if field == "rays":
		_show()


func _set_light(name: String, v: float) -> void:
	if _syncing:
		return
	(_spec["lights"] as Dictionary)[name] = v
	_changed()


## The note touched, and a playing scene given the environment at once.
func _changed() -> void:
	if _panel == null:
		return
	_panel.touch()
	var subs: Node = _panel.subtitles if is_instance_valid(_panel) else null
	if subs != null and is_instance_valid(subs) and subs.get("document") is Dictionary:
		(subs.get("document") as Dictionary)[KEY] = capture()
