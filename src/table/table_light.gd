extends RefCounted
class_name TableLight

## TableLight - the light on the card table: the flames and how each flickers, leans in a draft and
## licks, the glow and the heat shimmer over them, the rig the episode's `light` builds ([Lights]:
## the sun, its screens, the sky, lamps out of shot) and which of them is the key - and the contact
## shadows under what stands on the cloth.
##
## A PART OF THE TABLE, cut along its banners (next/structure.md, step 14): it holds the light's own
## state - the rig, the glows, the flames counted, the key - and reads the rest of the table through
## `medium` (its plan, its props, its camera, the wind the light shares with the air). Like
## everything on the table it is a function of show time: [method tick] and [method tick_props]
## are asked for a moment, never stepped.

## The [TableMedium] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var medium: TableMedium

## ...looked for this far round the candle, meters, on the table's lightness at this grid over the
## stretch of table the camera can see (x z, meters; 4 cm cells); and the flame height a candle's
## place is judged at.
const HEAT_R := 0.25
const HEAT_H := 0.13
const KEY_MIN := 1.0
const FILL_ENERGY := 0.35
## A table with a light of its own ([Lights]) whose sun and lamps light the cards less than this, and
## which no candle can lead, has the lamp hung over it after all.
const LAMP_FALLBACK := 0.12
var _flame_n := 0                     # flames lit so far on this table, each with its own flicker
## A candle's flame: how tall it burns (meters - what a draft must blow against, [method Winds.flame]) and
## the quad it is drawn on, standing on its wick.
const FLAME_H := 0.03
const FLAME_QUAD := 0.03
## HOW A FLAME LEANS (the user, 2026-10-11: they "lean... which is not a thing that flames should do"):
## the share of its lean that BENDS it - foot upright, tip leaned - the rest tipping the whole sprite;
## and how far its tip licks from side to side, in flame heights, in still air and fanned to a full draft.
const FLAME_BEND := 0.6
const FLAME_LICK := Vector2(0.04, 0.16)
var _glows: Array = []              # [{light, base, energy, flicker}] - candles in the room, out of shot
var _key_flame := -1                  # the key: the flame that leads the light, or -1 for the lamp
var _heat_cells := {}                 # grid cell -> its heat at HEAT_H, for this build
var _contact_tex: Texture2D = null
var _lit_cloth: Texture2D = null      # the painting the table was last lit for
var _rig = null                     # the set dresser's light, built (Lights.Rig), or null: the lamp and the room's candles
var _seen := PackedVector3Array()   # the table the camera sees, sampled (for the light), this build

# --- the flames and the light they cast --------------------------------------------------------

## A mesh close enough to a flame that its own shadow would be a false dark ring.
## Props keeps each part in a separate mesh, while its shared parent holds the final scale.
static func near_wick(mesh: MeshInstance3D, wicks: Array) -> bool:
	var bounds := mesh.get_aabb()
	var parent := mesh.get_parent() as Node3D
	var center := parent.transform * bounds.get_center()
	var half := bounds.size * parent.scale.abs() * 0.5
	for wick in wicks:
		var p := wick as Vector3
		var dx := maxf(absf(center.x - p.x) - half.x, 0.0)
		var dz := maxf(absf(center.z - p.z) - half.z, 0.0)
		if Vector2(dx, dz).length() < 0.018:
			return true
	return false


## A FLAME at [param at], the top of a wick: a wick under it (on its candle's layer, [param own])
## and the flame, flickering in its own time. Its light is its thing's ([method light_flames]); its
## own wax glows with it, through [param glow] (its material's `flame`). The flame, as
## `{mesh, base, flicker, glow}`.
func add_flame(at: Vector3, own: int, glow: Variant = null) -> Dictionary:
	var wick := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.0006
	wm.bottom_radius = 0.0008
	wm.height = 0.009
	wm.radial_segments = 6
	wm.rings = 1
	wick.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.07, 0.05, 0.04)
	wmat.roughness = 0.9
	wick.material_override = wmat
	wick.position = at + Vector3(0.0, 0.0035, 0.0)
	wick.layers = own
	medium._props.add_child(wick)
	var flame := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.012, FLAME_QUAD)
	q.subdivide_depth = 8
	flame.mesh = q
	var fm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TableMedium.FLAME_SHADER
	fm.shader = sh
	flame.material_override = fm
	flame.position = at + Vector3(0, 0.016, 0)
	medium._props.add_child(flame)
	_flame_n += 1
	return {"mesh": flame, "base": flame.position, "flicker": _flicker_of(_flame_n - 1), "glow": glow, "open": 1.0}


## A LIT THING'S ONE LIGHT, for every flame on it: a candelabra's tapers or a pillar's three wicks
## light the room as one light from among them, as near together as they are - so a candle costs
## one shadow however many flames it has. It lights everything but its own thing (render layer
## [param own]) and throws shadows from all of it: a flame lighting its own holder blew it out (an
## oil lamp's flame sits a few centimeters above its body). Its brightness follows its flames' -
## each still flickers in its own time.
func light_flames(flames: Array, own: int) -> void:
	var at := Vector3.ZERO
	for f in flames:
		at += (f as Dictionary)["base"]
	at /= float(flames.size())
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.omni_range = 1.4
	light.light_energy = 0.35
	light.shadow_caster_mask = 0xFFFFFFFF & ~own & ~Lights.SCREEN_MASK
	light.light_cull_mask = 0xFFFFFFFF & ~own
	candle_shadow(light)
	light.position = at + Vector3(0, 0.016, 0)
	medium._props.add_child(light)
	medium._lights.append({"light": light, "base": at, "light_base": light.position, "energy": 0.28, "flames": flames})


## A CANDLE'S SHADOW, SOFT BY A FILTER AND NOT BY THE FLAME'S SIZE ([ShadowFilter]): a flame stands a few
## centimeters over the cloth, so everything is lit at a graze, and sized (PCSS) it printed rings round
## itself on a card's back and drew a clock's rim on its face in stairs (feedback 0007). The filter's
## normal bias keeps the cloth out of its own shadow; the depth bias stays small (a tabletop's: at
## Godot's own a deck's shadow began centimeters in front of it), which is what keeps a card's own
## shadow. Its cube, as every omni light's here.
static func candle_shadow(light: OmniLight3D) -> void:
	ShadowFilter.filter(light, Lights.SHADOW_TEXELS)
	light.shadow_bias = 0.004
	light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	light.shadow_enabled = true


## A SHADOW-ONLY SLAB under [param foot]: the tabletop's shadow biases are larger than the gap
## under a bowl's sloping wall, so a ring of the lamp leaked in beside its base (feedback 0009). The
## slab stands a few millimeters over the cloth, draws nothing and shades what the thing already
## covers. It is on [param layer], so a candle's own flames still leave it out.
func foot_shadow(foot: PackedVector2Array, layer: int) -> void:
	var tris := Geometry2D.triangulate_polygon(foot)
	if tris.is_empty():
		return
	const H := 0.006
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, tris.size() - 2, 3):
		var a := foot[tris[i]]
		var b := foot[tris[i + 1]]
		var c := foot[tris[i + 2]]
		# top and bottom, each both ways round: no winding to get wrong in the shadow pass
		for y in [H, 0.0]:
			for q in [a, b, c, a, c, b]:
				st.add_vertex(Vector3(q.x, y, q.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	mi.layers = layer
	medium._props.add_child(mi)


## A soft shade on the cloth under [param foot] (a thing's outline where it meets it): what
## anything standing presses into the cloth.
func contact_shadow(foot: PackedVector2Array) -> Decal:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in foot:
		lo = lo.min(q)
		hi = hi.max(q)
	var size := (hi - lo).max(Vector2(0.01, 0.01))
	var contact := Decal.new()
	contact.texture_albedo = _contact_texture()
	contact.modulate = Color(0, 0, 0, 1)
	contact.albedo_mix = 0.6
	contact.size = Vector3(size.x * 1.7, 0.03, size.y * 1.7)
	contact.position = Vector3((lo.x + hi.x) * 0.5, 0.0, (lo.y + hi.y) * 0.5)
	contact.cull_mask = 1
	medium._props.add_child(contact)
	return contact


## LIGHT FROM OUTSIDE THE SHOT: two or three more candles in the room - behind the camera and off
## to the sides - never seen, only felt: a warm, shifting fill on the cloth, and on a card held up
## to the lens. Without shadows - faint fills, whose shadows would be fainter still, at six shadow
## passes each - each flickering in its own time.
## Their own dice, so the rest of the table lands where it did.
func _build_glows() -> void:
	_glows = []
	var r := RandomNumberGenerator.new()
	r.seed = hash([medium._plan.seed_value, "tarot-glows"])
	var n := r.randi_range(2, 3)
	var tries := 0
	while _glows.size() < n and tries < 60:
		tries += 1
		var at := Vector3(r.randf_range(-0.7, 0.7), r.randf_range(0.12, 0.5), medium._plan.cam_base.origin.z + r.randf_range(0.2, 0.7))
		if not _glows.is_empty() and r.randf() < 0.5:
			at = Vector3(r.randf_range(0.85, 1.4) * (1.0 if r.randf() < 0.5 else -1.0), r.randf_range(0.08, 0.45),
				r.randf_range(-0.45, 0.35))
		if _in_shot(at):
			continue
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, r.randf_range(0.6, 0.74), r.randf_range(0.3, 0.44))
		light.omni_range = 3.0
		light.shadow_enabled = false
		light.position = at
		medium._props.add_child(light)
		_glows.append({"light": light, "base": at, "energy": r.randf_range(0.12, 0.3),
			"flicker": _flicker_of("glow%d" % _glows.size())})


## Whether [param at] is inside the camera's picture (with a margin) - a light there would light
## the table from a place where nothing is burning.
func _in_shot(at: Vector3) -> bool:
	return CardTable.in_shot(medium._plan.cam_base, medium._cam.fov, at)


## THE LIGHT: the set dresser's (its table's `light`, [Lights]) - a sky, a sun and what it falls through,
## clouds, birds, lamps out of the shot - in place of the lamp and the room's out-of-shot candles; or,
## for a table that wrote none (every table set before 2026-10-07), those, as every table had them.
func build(spec: Dictionary) -> void:
	if _rig != null:
		_rig.release()
		_rig = null
	var light: Dictionary = spec.get("light", {}) if spec.get("light") is Dictionary else {}
	# ONE WIND for the light and the air: what stirs the leaves overhead blows the petals off the cloth
	medium._wind = Winds.plan(light.get("wind", {}) if light.get("wind") is Dictionary else {}, hash([medium._plan.seed_value, "wind"]))
	medium._lamp.visible = light.is_empty()
	medium._fill.visible = light.is_empty()
	if light.is_empty():
		medium._env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		medium._env.ambient_light_color = medium._plan.ambient.get("color", Color(0.5, 0.46, 0.44))
		medium._env.ambient_light_energy = float(medium._plan.ambient.get("energy", 0.18))
		_build_glows()
		return
	_glows = []
	_seen = _seen_points()
	_rig = Lights.build(light, _light_stage(), hash([medium._plan.seed_value, "light"]))
	medium._root3.add_child(_rig.root)


## Where the light stands ([method Lights.build]): the camera, the middle of the reading, the table and
## everything standing on it (a wall stands past them, a canopy over them), the table the camera sees,
## the environment, the room's picture, and what is in the shot.
func _light_stage() -> Dictionary:
	var bounds: AABB = medium._furniture.get("bounds", AABB(Vector3(-TableMedium.TABLE.x * 0.5, -TableMedium.TABLE.y, TableMedium.TABLE_Z - TableMedium.TABLE.z * 0.5), TableMedium.TABLE))
	for th in medium._things_part.on_table:
		bounds = bounds.merge((th as Dictionary)["box"] as AABB)
	return {"camera": medium._plan.cam_base, "fov": medium._cam.fov, "aspect": 16.0 / 9.0, "middle": Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y),
		"bounds": bounds, "seen": _seen, "env": medium._env, "room": medium._backdrop_mat, "in_shot": _in_shot, "wind": medium._wind}


## THE TABLE THE CAMERA SEES, sampled ([method CardTable.seen_points]).
func _seen_points() -> PackedVector3Array:
	return CardTable.seen_points(medium._plan.cam_base, medium._cam.fov, medium._top)


## HOW PALE THE PALEST THING THE LIGHT FALLS ON IS (linear luminance): the cloth where it is lightest
## that the camera sees (its 97th percentile - one pale thread is not the cloth) and the card stock, which
## lies in the spread under the same light.
func _hot_lum() -> float:
	var lums := PackedFloat32Array()
	if not medium._lum.is_empty():
		var cell := TableMedium.LUM_RECT.size / Vector2(TableMedium.LUM_GRID)
		for p in _seen:
			var gx := clampi(floori((p.x - TableMedium.LUM_RECT.position.x) / cell.x), 0, TableMedium.LUM_GRID.x - 1)
			var gy := clampi(floori((p.z - TableMedium.LUM_RECT.position.y) / cell.y), 0, TableMedium.LUM_GRID.y - 1)
			lums.append(medium._lum[gy * TableMedium.LUM_GRID.x + gx])
	var hot := 0.0
	if lums.is_empty():
		var c := medium._cloth_fallback().srgb_to_linear()
		hot = c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	else:
		lums.sort()
		hot = lums[clampi(int(lums.size() * 0.97), 0, lums.size() - 1)]
	var stock := CardTable.color(String((medium._plan.look.get("frame", {}) as Dictionary).get("stock", "#efe6d2"))).srgb_to_linear()
	return maxf(hot, (stock.r * 0.2126 + stock.g * 0.7152 + stock.b * 0.0722) * 0.85)


## The light at show time [param t].
func tick(t: float) -> void:
	if _rig != null:
		_rig.tick(t)


## WHAT LEADS THE LIGHT, in words: a candle (by its thing's name), the sun or a lamp of the table's own
## light, or the lamp.
func lead_name(by_light: Dictionary = {}) -> String:
	if _key_flame >= 0:
		return String(by_light.get(_key_flame, "a candle"))
	if _rig != null:
		if _rig.leads():
			return _rig.key_name()
		if not medium._lamp.visible:
			var name: String = _rig.key_name()
			return ("%s, faintly - nothing in the light leads it" % name) if not name.is_empty() else "nothing but the sky - the table is dim"
	return "the lamp"


## EVERY LIGHT THROWS ITS OWN SHADOW (the user, 2026-10-05: "most scenes have multiple light
## sources, and thus should probably cast multiple shadows"): every candle and the lamp, so a thing
## has a shadow for each light near it, each turned away from its own. One light had thrown them all
## (every light casting its own then gave the deck no shadow worth the name and each half of a split
## deck two - "it's all very strange"); now the KEY leads instead of casting alone: the candle
## nearest the middle of the table, bright enough to reach the cards, so the deck's long shadow
## toward the reader reads and the others are fainter. The other candles are fills, and the lamp is
## dimmed to one; with no candle at all, the lamp is the key ([member _key_flame] -1). NO CLOTH IS LIT HOTTER THAN IT CAN TAKE ([constant HEAT]): a candle
## by pale cloth is dimmer - and so are candles standing TOGETHER, whose pools add up on the cloth
## between them (two tapers side by side, each at its own limit, burned a pale cloth white through
## the bloom). A candle the cloth cannot let burn at [constant KEY_MIN] is never the key - with
## none that can, the lamp is.
func light_the_table() -> void:
	# A LIGHT OF THE TABLE'S OWN ([Lights]) is fitted to how pale the table is; where its sun or a lamp
	# leads, every candle burns as a fill
	var leads := false
	if _rig != null:
		_rig.fit(_hot_lum())
		leads = _rig.leads()
	var fields: Array = []
	var key := -1
	var best := INF
	for i in medium._lights.size():
		var base: Vector3 = (medium._lights[i] as Dictionary)["base"]
		var lb: Vector3 = (medium._lights[i] as Dictionary)["light_base"]
		var field := _heat_field(Vector3(base.x, 0.0, base.z), lb.y)
		fields.append(field)
		var d := (base * Vector3(1, 0, 1)).length()
		if not leads and TableMedium.HEAT / maxf(_field_max(field), 0.05) >= KEY_MIN and d < best:
			best = d
			key = i
	# A LIGHT IS AS BRIGHT AS ITS FLAMES: a pillar's three wicks give three flames' light, a
	# candelabra's five tapers five - capped like any other by the cloth they light
	var flames := PackedFloat32Array()
	for i in medium._lights.size():
		flames.append(float(((medium._lights[i] as Dictionary)["flames"] as Array).size()))
	var energy := PackedFloat32Array()
	for i in medium._lights.size():
		energy.append(minf((TableMedium.KEY_ENERGY if i == key else FILL_ENERGY) * flames[i], TableMedium.HEAT / maxf(_field_max(fields[i]), 0.05)))
	# the cloth's hottest spot under all of them at once, brought down to what it can take by
	# dimming every flame that reaches it - a few times, as the hottest spot moves
	for pass_ in 6:
		var total := {}
		for i in medium._lights.size():
			for c in fields[i]:
				total[c] = float(total.get(c, 0.0)) + energy[i] * float((fields[i] as Dictionary)[c])
		var hot := -1
		var most := TableMedium.HEAT
		for c in total:
			if float(total[c]) > most:
				most = float(total[c])
				hot = int(c)
		if hot < 0:
			break
		for i in medium._lights.size():
			if (fields[i] as Dictionary).has(hot):
				energy[i] *= TableMedium.HEAT / most * 0.999
	if key >= 0 and energy[key] < KEY_MIN:
		key = -1
	_key_flame = key
	for i in medium._lights.size():
		var f: Dictionary = medium._lights[i]
		f["energy"] = energy[i] if i == key else minf(energy[i], FILL_ENERGY * flames[i])
	if _rig == null:
		# the candle has to carry much of the light at the cards, or its shadow is lost under the lamp's
		medium._lamp.light_energy = medium._plan.lamp_base * (1.0 if key < 0 else 0.4)
	else:
		# A TABLE WITH A LIGHT OF ITS OWN has no lamp - unless nothing in that light reaches the cards and no
		# candle can lead: then the lamp hangs over it, so a reading is never read in the dark
		medium._lamp.visible = not leads and key < 0 and _rig.lead_level() < LAMP_FALLBACK
		medium._lamp.light_energy = medium._plan.lamp_base * 0.7
	_lit_cloth = medium._painting_tex


## The cloth's HOTTEST SPOT under a flame [param hf] above [param at] (see [method _heat_field]).
func _heat(at: Vector3, hf: float) -> float:
	return _field_max(_heat_field(at, hf))


static func _field_max(field: Dictionary) -> float:
	var m := 0.0
	for c in field:
		m = maxf(m, float(field[c]))
	return m


## HOW HOT A FLAME [param hf] above [param at] LIGHTS THE TABLE, cell by cell within [constant
## HEAT_R] ([constant LUM_GRID] over [constant LUM_RECT], keyed by cell): each cell's lightness over
## the flame's falloff - height over distance squared, which is the slant of the light times an omni
## light's 1/d at Godot's default attenuation. A table not yet built is its cloth's color.
func _heat_field(at: Vector3, hf: float) -> Dictionary:
	var out := {}
	var cell := TableMedium.LUM_RECT.size / Vector2(TableMedium.LUM_GRID)
	var g := Vector2((at.x - TableMedium.LUM_RECT.position.x) / cell.x, (at.z - TableMedium.LUM_RECT.position.y) / cell.y)
	var reach := Vector2i(ceili(HEAT_R / cell.x), ceili(HEAT_R / cell.y))
	var flat := 0.0
	if medium._lum.is_empty():
		var c := medium._cloth_fallback().srgb_to_linear()
		flat = c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	for gy in range(maxi(0, floori(g.y) - reach.y), mini(TableMedium.LUM_GRID.y, floori(g.y) + reach.y + 1)):
		for gx in range(maxi(0, floori(g.x) - reach.x), mini(TableMedium.LUM_GRID.x, floori(g.x) + reach.x + 1)):
			var r2 := Vector2((gx + 0.5 - g.x) * cell.x, (gy + 0.5 - g.y) * cell.y).length_squared()
			if r2 <= HEAT_R * HEAT_R:
				var lum := flat if medium._lum.is_empty() else medium._lum[gy * TableMedium.LUM_GRID.x + gx]
				out[gy * TableMedium.LUM_GRID.x + gx] = lum * hf / (r2 + hf * hf)
	return out


## [method _heat] at a grid cell's middle for a flame of [constant HEAT_H], kept for the build -
## a candle's place is judged at hundreds of spots.
func heat_cell(at: Vector3) -> float:
	var cell := TableMedium.LUM_RECT.size / Vector2(TableMedium.LUM_GRID)
	var gx := clampi(floori((at.x - TableMedium.LUM_RECT.position.x) / cell.x), 0, TableMedium.LUM_GRID.x - 1)
	var gy := clampi(floori((at.z - TableMedium.LUM_RECT.position.y) / cell.y), 0, TableMedium.LUM_GRID.y - 1)
	var k := gy * TableMedium.LUM_GRID.x + gx
	if not _heat_cells.has(k):
		_heat_cells[k] = _heat(Vector3(TableMedium.LUM_RECT.position.x + (gx + 0.5) * cell.x, 0.0, TableMedium.LUM_RECT.position.y + (gy + 0.5) * cell.y), HEAT_H)
	return float(_heat_cells[k])


## HOW A FLAME FLICKERS - its own way, so no two keep time: a tempo, how steadily it burns, and
## how often a draft finds it. They all shared one tempo and one swing, and pulsed together.
func _flicker_of(salt: Variant) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([medium._plan.seed_value, "flicker", salt])
	return {"seed": r.randf() * 1000.0, "rate": exp(r.randf_range(log(0.5), log(2.0))),
		"calm": r.randf_range(0.04, 0.12), "slot": r.randf_range(4.0, 12.0), "drafts": r.randf_range(0.3, 0.65),
		"salt": hash([medium._plan.seed_value, "draft", salt])}


## A flame at show time [param t]: (brightness about 1, height about 1, lean). Mostly a steady burn
## - a slow sway and a fine shiver at the flame's own tempo - and now and then a DRAFT: for a second
## or two it gutters, dims and leans. A draft is drawn per slot of the flame's own length from a
## hash, so this is a pure function of time and a render and a scrub see the same flame. The room's
## drafts are still air's ([param drafts]): in the light's wind the wind is the draft ([method tick_props]).
func _flame_at(fk: Dictionary, t: float, drafts := true) -> Vector3:
	var s := float(fk["seed"])
	var r := float(fk["rate"])
	var calm := float(fk["calm"])
	var slow := medium._noise.get_noise_2d(t * 0.8 * r, s)
	var fast := medium._noise.get_noise_2d(t * 7.0 * r, s + 31.0)
	var slot := float(fk["slot"])
	var k := floori(t / slot)
	var h := hash([int(fk["salt"]), k])
	var env := 0.0
	var strength := 0.0
	if drafts and float(h & 0xFFFF) / 65535.0 < float(fk["drafts"]):
		var dur := 0.7 + 1.8 * float((h >> 16) & 0xFF) / 255.0
		var start := float(k) * slot + (slot - dur) * float((h >> 24) & 0xFF) / 255.0
		var u := (t - start) / dur
		if u > 0.0 and u < 1.0:
			env = pow(sin(PI * u), 2.0)
			strength = 0.18 + 0.2 * float((h >> 8) & 0xFF) / 255.0
	var gust := medium._noise.get_noise_2d(t * 13.0 * r, s + 57.0)
	return Vector3(1.0 + calm * (0.65 * slow + 0.35 * fast) + env * strength * (gust - 0.35),
		1.0 + calm * 2.5 * slow + env * strength * 1.4 * gust,
		medium._noise.get_noise_2d(t * 1.3 * r, s + 7.0) * 0.4 + env * gust * 1.6)


## A soft round shade, dark at its middle, made once: what a candle's base presses into the cloth.
func _contact_texture() -> Texture2D:
	if _contact_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.85), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_contact_tex = gt
	return _contact_tex


## THE CANDLES AT SHOW TIME [param t]: each flame flickering in its own time, and IN THE LIGHT'S WIND
## ([method Winds.flame], as much of it as reaches the flame - [method Props.open_to_air]) leaning downwind,
## flickering in its eddies and guttering in a gust; its thing's light leans and dims with its flames,
## so the shadows round it lean and dance with them.
func tick_props(t: float) -> void:
	var blows := Winds.blows(medium._wind)
	# ABOARD SOMETHING THAT MOVES ([Rides]): every flame leans toward the push and stays upright in the world as
	# the deck rolls, and jumps at a jolt
	var riding := Rides.moves(medium._ride)
	var rode := Rides.flame(medium._ride, t) if riding else Vector2.ZERO
	var jolt := Rides.jolting(medium._ride, t) if riding else 0.0
	for l in medium._lights:
		# EACH FLAME IN ITS OWN TIME, and their light as bright as they are together
		var bright := 0.0
		var leans := Vector3.ZERO
		for f in (l as Dictionary)["flames"]:
			var fl := _flame_at(f["flicker"], t, not blows)
			var fast := medium._noise.get_noise_2d(t * 9.0 * float((f["flicker"] as Dictionary)["rate"]), float((f["flicker"] as Dictionary)["seed"]) + 91.0)
			var lean := Vector3(fl.z * 0.0015, 0, 0)
			var axis := Vector3.UP
			var tall := 1.0
			var draft := 0.0
			if blows:
				var w := Winds.flame(medium._wind, t, f["base"] as Vector3, FLAME_H, float(f.get("open", 1.0)))
				axis = w["axis"]
				tall = float(w["tall"])
				draft = float(w["draft"])
				fl.x *= float(w["bright"])
				lean += w["mid"] as Vector3
			if riding:
				axis = (axis + Vector3(rode.x, 0.0, rode.y)).normalized()
				lean += Vector3(rode.x, 0.0, rode.y) * FLAME_H * 0.5
				fl.x *= 1.0 - 0.25 * jolt * (0.6 + 0.4 * fast)
				tall *= 1.0 + 0.3 * jolt * fast
			var mesh: MeshInstance3D = f["mesh"]
			# A SPRITE PARALLEL TO THE PICTURE, standing on its wick: its lean as it shows on the screen split
			# into a BEND (the shader's: foot upright, tip leaned) and a tip of the whole sprite in its own
			# plane, foreshortened by what of it leans toward or away from the lens. Every flame is read
			# across the CAMERA's right, never across its own line of sight: the same draft then leans every
			# flame the same way on the screen (the user, 2026-10-11: one flame looked straight up and two
			# leaned right, in a draft that was one - the wide lens sees a flame at the edge end on)
			var root := (f["base"] as Vector3) - Vector3(0.0, FLAME_QUAD * 0.5, 0.0)
			var across := medium._cam.global_transform.basis.x * Vector3(1, 0, 1)
			across = across.normalized() if across.length() > 1e-5 else Vector3.RIGHT
			var face := across.cross(Vector3.UP)
			var shown := Vector2(axis.dot(across), axis.y)
			var rest := shown.x / maxf(absf(shown.y), 1e-3)
			var bend := clampf(rest * FLAME_BEND, -0.5, 0.5)
			var b := Basis(across, Vector3.UP, face) * Basis(Vector3.BACK, -atan(rest - bend)) \
				* Basis.from_scale(Vector3(1.0 + 0.06 * fast, fl.y * tall * shown.length(), 1.0))
			mesh.transform = Transform3D(b, root + b * Vector3(0.0, FLAME_QUAD * 0.5, 0.0) + Vector3(lean.x, 0.0, 0.0) * (0.0 if blows or riding else 1.0))
			# ...AND LICKING: a ripple climbing it at the flame's own tempo, wider the harder it is fanned
			var fk: Dictionary = f["flicker"]
			var rate := float(fk["rate"])
			var lick := lerpf(FLAME_LICK.x, FLAME_LICK.y, clampf(draft / sqrt(9.81 * FLAME_H), 0.0, 1.0))
			var ripple := medium._noise.get_noise_2d(t * 2.1 * rate, float(fk["seed"]) + 143.0)
			var fm := mesh.material_override as ShaderMaterial
			fm.set_shader_parameter("bend", bend * FLAME_QUAD)
			fm.set_shader_parameter("lick", FLAME_QUAD * lick * clampf(0.8 + 0.7 * ripple, 0.2, 1.5))
			fm.set_shader_parameter("phase", TAU * 3.2 * rate * t + 2.5 * medium._noise.get_noise_2d(t * 0.9 * rate, float(fk["seed"]) + 211.0))
			if f.get("glow") is ShaderMaterial:
				(f["glow"] as ShaderMaterial).set_shader_parameter("flame", fl.x)
			bright += fl.x
			leans += lean
		var n := maxf(float(((l as Dictionary)["flames"] as Array).size()), 1.0)
		var light: OmniLight3D = (l as Dictionary)["light"]
		light.light_energy = float((l as Dictionary)["energy"]) * bright / n
		# the light leans with its flames, so the shadows breathe with them
		light.position = ((l as Dictionary)["light_base"] as Vector3) + leans / n
	for g in _glows:
		(g["light"] as OmniLight3D).light_energy = float(g["energy"]) * _flame_at(g["flicker"], t).x
