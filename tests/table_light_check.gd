extends Node

## THE CARD TABLE'S OWN LIGHT ([Lights], `light` in a set dresser's `table.json`), in the medium that
## draws it ([TableMedium]). The user, 2026-10-07: "giving them a way to control both lighting and
## shadow". On a fixture of its own:
##
##   - A TABLE WITH NO LIGHT IS LIT AS EVERY TABLE WAS: the lamp, the fill, the room's out-of-shot candles,
##     the room's picture as painted - and a table rebuilt without its light goes back to that.
##   - A TABLE WITH ONE has none of those: its sky in the environment, its sun leading (every candle a
##     fill), its screens' layer cast with by the sun alone - no candle, no lamp, no lamp of its own - and
##     the room's picture casts no shadow (a low sun behind the table would throw it over the cards).
##   - IT MOVES WITH SHOW TIME and nothing else: a cloud over the sun dims the sun and the room's picture,
##     and the same moment twice is the same light.
##   - ITS EXPOSURE FOLLOWS THE CLOTH: on a pale cloth the sun is held lower than on a dark one.
##   - THE CARDS ARE NEVER IN THE DARK: with nothing in the light reaching them and no candle to lead, the
##     lamp hangs over the table after all - against a torch, which needs none.
##
##   tests/run_boot_probe.sh tests/table_light_check.gd 300
##
## A BOOT probe (the medium reaches the Director); no GPU needed.

const DIR := "user://table_light_check"

## A small set table: a lit candle and a stone, at the back.
const THINGS := {"materials": {"wax": {"kind": "wax", "color": "#e8dcc0"}, "slate": {"kind": "stone", "color": "#4a4a50"}},
	"things": [
		{"name": "a pillar", "place": "back left", "parts": [{"shape": "lathe", "profile": [[0, 0], [2.4, 0], [2.4, 8], [0, 8]], "material": "wax", "wick": true}]},
		{"name": "a stone", "place": "back right", "parts": [{"shape": "ball", "size": [5, 3, 4], "material": "slate"}]}]}

## A day: a sun through a window, clouds that cover half the sky, crows, a torch and a lantern.
const DAY := {"sky": {"color": "#b8c8d8", "strength": 0.6},
	"sun": {"look": "sun", "from": "back left", "height": 35, "strength": 0.9},
	"through": [{"name": "the window", "kind": "window", "size": [120, 160], "panes": [2, 3]}],
	"clouds": {"cover": 0.5, "size": 0.3, "speed": 0.8, "thickness": 0.9},
	"birds": {"look": "crow", "every": 20},
	"lamps": [{"name": "a torch", "look": "torch", "from": "left", "shadows": true}, {"name": "a lantern", "look": "lantern", "from": "right"}],
	"shadows": [{"name": "a beam", "parts": [{"shape": "box", "size": [300, 15, 15]}], "shadow": [0, -10], "height": 200},
		{"name": "a rope", "parts": [{"shape": "tube", "path": [[0, 0, 0], [0, -120, 0]], "radius": 1.5}], "shadow": [-20, 0], "height": 140,
			"move": {"kind": "swing", "amount": 0.6}}]}

var _fails := 0
var medium: TableMedium
var subs: Subtitles


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	_fixture()
	var stage := SubViewport.new()
	stage.size = Vector2i(640, 360)
	stage.own_world_3d = true
	add_child(stage)
	Director.detach()
	medium = Medium.make("table") as TableMedium
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	subs = preload("res://src/subtitles.gd").new()
	add_child(subs)
	medium.bind_captions(subs)

	print("a table with no light of its own")
	_lay("dark", {})
	_legacy()

	print("a table with a light of its own")
	_lay("dark", {"light": DAY})
	var rig = medium._rig
	_ok(rig != null, "the light is built")
	_ok(not medium._lamp.visible and not medium._fill.visible and medium._glows.is_empty(),
		"the lamp, the fill and the room's candles give way to it (%s, %s, %d)" % [medium._lamp.visible, medium._fill.visible, medium._glows.size()])
	_ok(medium._env.ambient_light_color.is_equal_approx(Color.html("#b8c8d8")) and medium._env.ambient_light_energy > 0.0,
		"its sky is the environment's ambient")
	_ok(rig.leads() and medium._key_flame == -1 and medium.lead_name() == "the sun", "the sun leads, every candle a fill (%s)" % medium.lead_name())
	var cast_screens := 0
	for l in medium._lights:
		cast_screens += 1 if (((l as Dictionary)["light"] as OmniLight3D).shadow_caster_mask & Lights.SCREEN_MASK) != 0 else 0
	for l in rig.lamps:
		cast_screens += 1 if (((l as Dictionary)["light"] as Light3D).shadow_caster_mask & Lights.SCREEN_MASK) != 0 else 0
	cast_screens += 1 if (medium._lamp.shadow_caster_mask & Lights.SCREEN_MASK) != 0 else 0
	_ok(cast_screens == 0 and not medium._lights.is_empty(), "no light but the sun casts with its screens (%d do)" % cast_screens)
	var shadow_casters := 0
	for l in rig.lamps:
		shadow_casters += 1 if (((l as Dictionary)["light"] as Light3D).shadow_caster_mask & Lights.CASTER_LAYER) != 0 else 0
	_ok(rig.casters.size() == 2 and shadow_casters == rig.lamps.size() and (medium._lamp.shadow_caster_mask & Lights.CASTER_LAYER) != 0,
		"the shadows out of the shot are built and every lamp casts with them (%d built, %d of %d lamps)" % [rig.casters.size(), shadow_casters, rig.lamps.size()])
	_ok(medium._backdrop.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the room's picture casts no shadow")
	_ok(not medium._seen.is_empty(), "the table the camera sees is sampled")

	print("it moves with show time")
	var clear := -1.0
	var cloudy := -1.0
	for i in 4000:
		var t := float(i) * 0.5
		var c := Lights.cloud_at(rig.field, t)
		if c < 0.01 and clear < 0.0:
			clear = t
		if c > 0.99 and cloudy < 0.0:
			cloudy = t
	medium._tick_light(clear)
	var sun_clear: float = rig.sun.light_energy
	var room_clear := float(medium._backdrop_mat.get_shader_parameter("shade"))
	medium._tick_light(cloudy)
	var sun_cloudy: float = rig.sun.light_energy
	var room_cloudy := float(medium._backdrop_mat.get_shader_parameter("shade"))
	_ok(clear >= 0.0 and cloudy >= 0.0 and sun_cloudy < sun_clear * 0.3, "a cloud dims the sun (%.2f to %.2f)" % [sun_clear, sun_cloudy])
	_ok(room_clear > 0.99 and room_cloudy < room_clear and room_cloudy > 0.3, "a cloud dims the room's picture, about a stop (%.2f to %.2f)" % [room_clear, room_cloudy])
	medium._tick_light(77.7)
	var a := _energies()
	medium._tick_light(12.0)
	var swung := ((rig.casters[1] as Dictionary)["pivot"] as Node3D).basis
	medium._tick_light(77.7)
	_ok(a == _energies(), "the same moment twice is the same light")
	_ok(not swung.is_equal_approx(((rig.casters[1] as Dictionary)["pivot"] as Node3D).basis), "the rope hangs the same at 12 s and at 77.7 s - it does not swing")

	print("its exposure follows the cloth")
	var dark_sun: float = rig.sun_energy
	var dark_hot := medium._hot_lum()
	_lay("pale", {"light": DAY})
	var pale_sun: float = medium._rig.sun_energy
	_ok(medium._hot_lum() > dark_hot and pale_sun < dark_sun, "on a pale cloth the sun is held lower (%.2f, against %.2f on a dark one)" % [pale_sun, dark_sun])

	print("the cards are never in the dark")
	_lay("dark", {"light": {"sky": {"color": "#10141c", "strength": 0.03}}}, {"materials": {}, "things": []})
	_ok(medium._lamp.visible and medium._key_flame == -1, "nothing lights the cards and no candle leads: the lamp hangs over them (%s)" % medium.lead_name())
	_lay("dark", {"light": {"sky": {"color": "#10141c", "strength": 0.03}, "lamps": [{"name": "a torch", "look": "torch", "from": "left", "strength": 0.8}]}},
		{"materials": {}, "things": []})
	_ok(not medium._lamp.visible and medium.lead_name() == "a torch", "control: a torch lights them, and no lamp is hung (%s)" % medium.lead_name())

	print("a table rebuilt without its light")
	_lay("dark", {})
	_legacy()

	Director.hold(false)
	Director.detach()
	_clear()
	print("table_light_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _legacy() -> void:
	_ok(medium._rig == null and medium._lamp.visible and medium._fill.visible, "lit by the lamp and the fill")
	_ok(medium._glows.size() >= 2 and medium._glows.size() <= 3, "the room's out-of-shot candles burn (%d)" % medium._glows.size())
	_ok(is_equal_approx(medium._env.ambient_light_energy, 0.18), "the room's own ambient (%.2f)" % medium._env.ambient_light_energy)
	var shade: Variant = medium._backdrop_mat.get_shader_parameter("shade")
	_ok(shade == null or is_equal_approx(float(shade), 1.0), "the room's picture as painted (%s)" % str(shade))


## Every light's energy, as it is now.
func _energies() -> Array:
	var out: Array = []
	if medium._rig != null:
		out.append(medium._rig.sun.light_energy if medium._rig.sun != null else 0.0)
		for l in medium._rig.lamps:
			out.append(((l as Dictionary)["light"] as Light3D).light_energy)
			out.append(((l as Dictionary)["light"] as Light3D).position)
		for b in medium._rig.bird_nodes:
			out.append((b as MeshInstance3D).visible)
		for c in medium._rig.casters:
			out.append(((c as Dictionary)["pivot"] as Node3D).transform)
	return out


## The table on [param cloth] with [param extra] beside [param things] (THINGS when not given), built anew.
func _lay(cloth: String, extra: Dictionary, things: Dictionary = THINGS) -> void:
	var dir := DIR.path_join(cloth)
	var table := things.duplicate(true)
	table.merge(extra, true)
	var f := FileAccess.open(dir.path_join("table.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(table))
	f.close()
	var cards: Array = []
	for i in 3:
		cards.append({"key": "c%d" % i, "name": "Card %d" % i, "numeral": str(i), "reversed": false, "jumper": false,
			"position": {}, "booklet": {}, "art": ""})
	var doc := {"show": "light-check", "seed": 4321, "dir": dir, "images": {"surface": dir.path_join("surface.png")},
		"plan": {"look": {"candles": 1, "frame": {"stock": "#2a2a30"}}}, "cards": cards}
	subs.document = {"source": "", "title": "Light Check", "table": doc}
	medium._key = ""
	medium._ensure_doc()


func _fixture() -> void:
	_clear()
	for cloth in ["dark", "pale"]:
		var dir := DIR.path_join(cloth)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var surf := Image.create(192, 128, false, Image.FORMAT_RGB8)
		surf.fill(Color(0.18, 0.08, 0.1) if cloth == "dark" else Color(0.93, 0.9, 0.84))
		surf.save_png(dir.path_join("surface.png"))


func _clear() -> void:
	for cloth in ["dark", "pale"]:
		var da := DirAccess.open(DIR.path_join(cloth))
		if da == null:
			continue
		for fn in da.get_files():
			da.remove(fn)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join(cloth)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
