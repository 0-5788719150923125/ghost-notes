extends SceneTree

## The Environment ([Surroundings], [EnvironmentCard]; next/environment.md): what is round a scene, chosen on its card, with no
## renderer.
##
##   godot --headless --path . --script res://tests/table/environment_check.gd
##
## - The block made safe: a light it does not know is the scene's own, ticks it does not know dropped and the rest in the registry's
##   order, numbers held to their ranges, a lit thing's share kept by its name (the control: a light it knows is kept).
## - Every preset is a row a desk can read: a lamp's share, candles, an ambient and a key, a fog color; the ones only ever chosen
##   (moonlight, no light) weigh nothing, so no desk's number draws them.
## - What drifts: each tick an effect [Effects] keeps, over a region every host names, as many as the amount says (the control: an
##   unknown tick adds none, and at twice the amount, twice the motes); haze is fog in the light's color; a mote never goes away
##   on a visit (the control: a table's motes do).
## - What is heard: each tick a part of the [Soundscape]'s sound; none ticked, silence.
## - Shafts: as many as asked, each a drawn cone and a narrow spot that does not fade, landing apart inside the box they fall over,
##   falling from the way of their light; the dust in them goes by show time.
## - The card: applied a block, it keeps it made safe and shows it; a tick changes the block, the live document a playing scene reads,
##   and touches the note; it hands the panel its part of the document and, where nothing else hands one, its sound as the bed -
##   none while nothing is heard, a Soundscape once something is (the control: a panel whose bed is another's keeps it). A dial
##   stands for each lit thing and each thing heard the panel's Props sections name, and moving one keeps that thing's share
##   alone.

var _fails := 0


## The live document's holder, as the reading's subtitles are.
class Words extends Node:
	var document := {}


## A Props section with a lamp on it, and a receiver that hisses.
class Lit extends PropSection:
	func lit() -> Array:
		return [{"key": "lamp", "name": "The lamp"}]

	func heard() -> Array:
		return [{"key": "receiver", "name": "Receiver"}]


## The panel and the card, by path: each names autoloads, which resolve only once the tree is up.
const PANEL := "res://src/reading/reading_panel.gd"
const CARD := "res://src/table/environment_card.gd"


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL: " + what)


func _run() -> void:
	await process_frame
	_block()
	_presets()
	_air()
	_sound()
	_rays()
	await _card()
	print("environment_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _block() -> void:
	var odd := Surroundings.sanitize({"light": "noon", "brightness": 9.0, "rays": 40, "air": ["snow", "smoke", "dust"],
		"sound": ["sea", 3, "rain"], "lights": {"lamp": 7.0, "terminal": 0.5}, "sound_level": -1, "heard": {"receiver": 0.25, "radio": 9}})
	_ok(String(odd["light"]).is_empty(), "a light it does not know is the scene's own")
	_ok(is_equal_approx(float(odd["brightness"]), Surroundings.BRIGHTNESS.y) and int(odd["rays"]) == Surroundings.RAYS_MOST
		and is_zero_approx(float(odd["sound_level"])), "numbers held to their ranges")
	_ok(odd["air"] == ["dust", "snow"] and odd["sound"] == ["rain", "sea"], "ticks it does not know dropped, the rest in the registry's order (%s, %s)"
		% [str(odd["air"]), str(odd["sound"])])
	_ok(is_equal_approx(float((odd["lights"] as Dictionary)["lamp"]), Surroundings.LIGHT_SHARE.y)
		and is_equal_approx(Surroundings.share_of(odd, "terminal"), 0.5) and is_equal_approx(Surroundings.share_of(odd, "radar"), 1.0),
		"a lit thing's share kept by its name, held to its range; one it does not name throws as it is made")
	_ok(is_equal_approx(Surroundings.heard_of(odd, "receiver"), 0.25) and is_equal_approx(Surroundings.heard_of(odd, "radio"), Surroundings.HEARD_SHARE.y)
		and is_equal_approx(Surroundings.heard_of(odd, "radar"), 1.0), "a thing heard is kept by its name, held to its range; one it does not name is as loud as made")
	_ok(String(Surroundings.sanitize({"light": "Moonlight"})["light"]) == "moonlight", "the control: a light it knows is kept")
	_ok(Surroundings.sanitize(null) == Surroundings.KNOBS, "no block is every key's default")


func _presets() -> void:
	var whole := true
	for k in Surroundings.LIGHTS:
		var row: Dictionary = Surroundings.LIGHTS[k]
		for f in ["label", "blurb", "weight", "lamp", "candles", "leads", "ambient", "ambient_energy", "key", "key_color", "key_strength", "fog"]:
			whole = whole and row.has(f)
		whole = whole and Color.html_is_valid(String(row["ambient"])) and Color.html_is_valid(String(row["key_color"]))
	_ok(whole, "every light is a row with a lamp's share, candles, an ambient, a key and a fog color")
	_ok(is_zero_approx(float(Surroundings.LIGHTS["moonlight"]["weight"])) and is_zero_approx(float(Surroundings.LIGHTS["darkness"]["weight"])),
		"moonlight and no light are only ever chosen")
	var moon := Color.html(String(Surroundings.LIGHTS["moonlight"]["key_color"]))
	_ok(moon.s < 0.15 and moon.v > 0.9 and String(Surroundings.LIGHTS["moonlight"]["key"]) == "moon"
		and is_zero_approx(float(Surroundings.LIGHTS["moonlight"]["lamp"])), "moonlight is the moon's, nearly white, every lamp off")


func _air() -> void:
	var fog := Color(0.2, 0.3, 0.4)
	var fx := Surroundings.effects_of(Surroundings.sanitize({"air": ["haze", "pixies", "smoke"]}), fog)
	_ok(fx.size() == 2 and String((fx[0] as Dictionary)["kind"]) == "fog" and String((fx[1] as Dictionary)["kind"]) == "motes",
		"each tick an effect Effects keeps, an unknown one none (%d)" % fx.size())
	var regions := ["far", "near", "room"]
	var kept := true
	for e in fx:
		kept = kept and String((e as Dictionary)["where"]) in regions
	_ok(kept, "over a region every host names")
	_ok(String((fx[0] as Dictionary)["color"]).trim_prefix("#") == fog.to_html(false), "haze is fog in the light's color")
	var twice := Surroundings.effects_of(Surroundings.sanitize({"air": ["pixies"], "air_amount": 2.0}), fog)
	_ok(int((twice[0] as Dictionary)["count"]) == 2 * int((fx[1] as Dictionary)["count"]),
		"the control: at twice the amount, twice the motes (%d, %d)" % [int((twice[0] as Dictionary)["count"]), int((fx[1] as Dictionary)["count"])])
	_ok(Surroundings.effects_of(Surroundings.sanitize({}), fog).is_empty(), "nothing ticked, nothing drifts")
	var stays := true
	for e in Surroundings.effects_of(Surroundings.sanitize({"air": ["dust", "pixies", "fireflies", "wisps", "embers", "snow"]}), fog):
		stays = stays and is_zero_approx(float((e as Dictionary).get("away", -1.0)))
	var visits := float((Effects.sanitize([{"kind": "motes", "look": "dust", "where": "near"}], [], ["near"], [])[0] as Dictionary)["away"])
	_ok(stays and visits > 0.0, "a mote never goes away on a visit, whose exit a moving camera can see (the control: a table's motes do, %.2f of their round)" % visits)
	var all := Surroundings.effects_of(Surroundings.sanitize({"air": Surroundings.AIR.keys()}), fog)
	_ok(all.size() == Surroundings.AIR.size(), "every tick at once is kept (%d of %d)" % [all.size(), Surroundings.AIR.size()])


func _sound() -> void:
	_ok(Surroundings.sound_of(Surroundings.sanitize({})).is_empty(), "nothing ticked, silence")
	var both := Surroundings.sound_of(Surroundings.sanitize({"sound": ["rain", "fire", "sea"]}))
	_ok(both.get("rain") is Dictionary and both.get("fire") is Dictionary and both.get("water") is Dictionary,
		"each tick a part of the Soundscape's sound, kept by its sanitize (%s)" % str(both.keys()))
	var bed := Soundscape.new(both, {}, 7, 22050, 0.0)
	_ok(bed != null, "a Soundscape is made of it")


func _rays() -> void:
	var over := AABB(Vector3(-1.0, 0.4, -1.0), Vector3(2.0, 0.0, 1.0))
	var toward := Vector3(0.3, 1.0, -0.2).normalized()
	var r := Surroundings.rays(4, 0.7, Color.WHITE, toward, over, 11, 3.0)
	_ok(r.get_child_count() == 4, "as many shafts as asked")
	var apart := true
	var inside := true
	var lit := true
	var drawn := true
	var lands: Array = []
	for c in r.get_children():
		var l := c.get_node("Light") as SpotLight3D
		var shaft := c.get_node("Shaft") as MeshInstance3D
		lit = lit and l != null and l.spot_angle < 15.0 and is_zero_approx(l.spot_attenuation)
		drawn = drawn and shaft != null and (shaft.material_override as ShaderMaterial).shader == Surroundings.SHAFT_SHADER \
			and shaft.transform.basis.y.normalized().dot(toward) > 0.99
		var down := -l.transform.basis.z
		var land := l.position + down * 3.0
		inside = inside and land.x >= over.position.x - 0.01 and land.x <= over.end.x + 0.01 and absf(land.y - over.end.y) < 0.01 \
			and down.dot(-toward) > 0.99 and shaft.position.distance_to((land + l.position) * 0.5) < 0.01
		for o in lands:
			apart = apart and (o as Vector3).distance_to(land) > 0.1
		lands.append(land)
	_ok(lit, "each a narrow spot that does not fade along its length")
	_ok(drawn, "each a drawn shaft along its light's way")
	_ok(inside, "each lands inside the box, falling from the way of its light, its shaft between")
	_ok(apart, "no two land together")
	Surroundings.tick_rays(r, 5.0)
	_ok(is_equal_approx(float((r.get_meta("shaft") as ShaderMaterial).get_shader_parameter("t")), 5.0), "the dust in them goes by show time")
	r.free()


func _card() -> void:
	var panel_script: GDScript = load(PANEL)
	var card_script: GDScript = load(CARD)
	var bed_script: GDScript = card_script.get("Bed")
	var panel: Node = panel_script.new()
	var subs := Words.new()
	panel.subtitles = subs
	var card: Control = card_script.call("for_note", {"workspace": panel})
	root.add_child(card)
	_ok(panel.bed.get_script() == bed_script and (panel.document_parts.get("environment") as Callable).is_valid(),
		"it hands the panel its part of the document and its bed")
	_ok(panel.bed.of().get("make") == null, "nothing heard: the bed makes nothing")
	card.apply({"light": "moonlight", "air": ["pixies"], "brightness": 1.5})
	var got: Dictionary = card.capture()
	_ok(String(got["light"]) == "moonlight" and got["air"] == ["pixies"] and is_equal_approx(float(got["brightness"]), 1.5),
		"applied a block, it keeps it")
	var pick: OptionButton = card.get("_light")
	_ok(String(pick.get_item_metadata(pick.selected)) == "moonlight" and ((card.get("_air") as Dictionary)["pixies"] as CheckBox).button_pressed,
		"and shows it: the light picked, the tick ticked")
	panel.set("_dirty", false)
	var rain: CheckBox = (card.get("_sound") as Dictionary)["rain"]
	rain.button_pressed = true
	_ok("rain" in (card.capture()["sound"] as Array) and bool(panel.get("_dirty")), "a tick changes the block and touches the note")
	_ok(subs.document.get("environment") is Dictionary and "rain" in (subs.document["environment"]["sound"] as Array),
		"the live document a playing scene reads has it at once")
	_ok(((panel.document_parts["environment"] as Callable).call() as Dictionary).get("environment") == card.capture(),
		"its part of the document is the block")
	var heard: Dictionary = panel.bed.of()
	_ok(heard.get("make") is Callable and ((heard["make"] as Callable).call(22050, 0.0)) is Soundscape, "something heard: a Soundscape")
	# a panel whose bed is another's keeps it
	var other: Node = panel_script.new()
	other.bed = bed_script.new(card)
	var kept: Object = other.bed
	var second: Control = card_script.call("for_note", {"workspace": other})
	_ok(other.bed == kept, "the control: a panel whose bed is another card's keeps it")
	second.free()
	other.free()
	# a dial for each lit thing
	panel.prop_sections = [Lit.new()]
	card.call("_show_lit")
	var dial := _dial_in(card.get("_lit_box"))
	_ok(dial != null, "a dial stands for the lamp the Props section names")
	if dial != null:
		dial.value = 0.4
		_ok(is_equal_approx(Surroundings.share_of(card.capture(), "lamp"), 0.4), "moving it keeps the lamp's share")
	var hiss := _dial_in(card.get("_heard_box"))
	_ok(hiss != null, "a dial stands for the receiver it hears")
	if hiss != null:
		hiss.value = 0.0
		_ok(is_zero_approx(Surroundings.heard_of(card.capture(), "receiver")) and is_equal_approx(Surroundings.share_of(card.capture(), "lamp"), 0.4),
			"turned down, the receiver is silent and the lamp as it was")
	card.queue_free()
	await process_frame
	subs.free()
	panel.free()


## The first dial among [param box]'s rows, or null.
func _dial_in(box: Node) -> HSlider:
	for row in box.get_children():
		for c in row.get_children():
			if c is HSlider:
				return c
	return null
