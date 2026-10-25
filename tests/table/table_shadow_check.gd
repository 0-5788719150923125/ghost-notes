extends SceneTree

## A CANDLE THAT GRAZES THE TABLE DRAWS ITS LIGHT AND SHADOWS CLEAN (feedback 0007: a candle printed rings
## round itself on a card's dark back, and a clock's rim drew its shadow across the face in stairs that
## crawled as the flame flickered). On the stage as the table sets it ([constant TableMedium.STAGE]), lit by
## a candle's light as [method TableLight.candle_shadow] makes it, photographed from straight above - each
## picture read against the same one with the light casting nothing, so what is left is the shadow's own:
##
##   - WHAT NOTHING STANDS IN FRONT OF KEEPS ITS LIGHT: a dark plane under a flame 7 cm up, and the top of a
##     deck 2 cm tall 35 cm off, are as bright as with no shadow at all (within [constant OPEN_LEAST]).
##   - NO RINGS: the plane's light, binned by its distance from under the flame, keeps to a running mean of
##     it within [constant RINGS_MOST] - concentric rings are what bins by distance gather.
##   - NO STAIRS: a plate [constant PLATE_H] over the plane, its edge aslant, cast from a lamp about 86 cm
##     off - a caster close over what it shades, as the clock's rim is over its face. The shadow's edge,
##     found to a fraction of a pixel in every few rows, keeps to a line within [constant STAIRS_MOST] pixels
##     (what is left is the stairs' own period, smoothed to a quarter of a millimeter's wave).
##   - THE SHADOW IS THERE: the plate's shadow is darker than half the plane lit beside it - a normal bias
##     big enough to lift every shadow off the plane would pass all of the above.
##
## Two-sided: the same scenes lit as the candles were before (a 1.5 cm light, PCSS, on a 4096 atlas without
## debanding) shade the deck's open top and stair past the bounds; and the candle's filter without its
## normal bias rings.
##
##   tests/run_quiet.sh table_shadow_check
##
## A real renderer (xvfb), no window on screen.

const W := 960
const H := 480
## The pool photographed (x, z; meters), the flame over its middle's near end, and the deck in it.
const POOL := Rect2(0.04, -0.15, 0.6, 0.3)
const FLAME := Vector3(0.0, 0.072, 0.0)
const DECK := AABB(Vector3(0.315, 0.0, -0.06), Vector3(0.07, 0.02, 0.12))
const OPEN_LEAST := 0.97
const RINGS_MOST := 0.001
const PLATE_H := 0.006
## Pixels of the plate's picture (0.04 mm each): a fifth of a millimeter, where the old stairs strayed two.
const STAIRS_MOST := 5.0
## The rows read together for each point of an edge: the filter's own grain is finer than a stair.
const EDGE_ROWS := 8

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	var off := await _shoot(POOL, _flame("off"), true)
	var off_before := await _shoot(POOL, _flame("off"), false)
	var candle := _pool(await _shoot(POOL, _flame("candle"), true), off)
	var bare := _pool(await _shoot(POOL, _flame("bare"), true), off)
	var before := _pool(await _shoot(POOL, _flame("before"), false), off_before)
	_ok(float(candle["plane"]) >= OPEN_LEAST and float(candle["deck"]) >= OPEN_LEAST,
		"open cloth and a deck's top keep their light: %.3f and %.3f of it unshadowed" % [float(candle["plane"]), float(candle["deck"])])
	_ok(float(before["deck"]) < OPEN_LEAST, "the control shades the deck's own top: %.3f" % float(before["deck"]))
	_ok(float(candle["rings"]) < RINGS_MOST, "no rings round the flame: %.3f%% off a running mean, over %d mm" % [float(candle["rings"]) * 100.0, int(candle["bins"])])
	_ok(float(bare["rings"]) > RINGS_MOST * 2.0, "the control rings (no normal bias): %.3f%%" % (float(bare["rings"]) * 100.0))
	var edge := await _plate("candle", true)
	var edge_was := await _plate("before", false)
	_ok(float(edge["stairs"]) < STAIRS_MOST, "a close caster's shadow keeps to a smooth edge: %.2f px off it" % float(edge["stairs"]))
	_ok(float(edge["dark"]) < 0.5, "the plate's shadow is there: %.2f of the lit plane" % float(edge["dark"]))
	_ok(float(edge_was["stairs"]) > STAIRS_MOST * 3.0, "the control stairs: %.2f px off a smooth edge" % float(edge_was["stairs"]))
	print("table_shadow_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


## A candle's light at [constant FLAME]: as the table makes it (`candle`), casting nothing (`off`), its
## filter with no normal bias (`bare`), or as the candles were before (`before`).
func _flame(kind: String) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.omni_range = 1.4
	light.position = FLAME
	TableLight.candle_shadow(light)
	match kind:
		"off":
			light.shadow_enabled = false
		"bare":
			light.shadow_normal_bias = 0.0
		"before":
			light.light_size = 0.015
			light.shadow_blur = 2.0
			light.shadow_normal_bias = 0.3
	return light


## [param rect] (x, z, meters) of a dark plane with a deck on it, photographed from straight above and lit
## by [param light] alone - on the stage as the table sets it, or ([param table] false) as it was before.
func _shoot(rect: Rect2, light: OmniLight3D, table: bool, also: Array = []) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for key in TableMedium.STAGE:
		vp.set(key, TableMedium.STAGE[key])
	if not table:
		vp.positional_shadow_atlas_size = 4096
		vp.use_debanding = false
	get_root().add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = rect.size.y
	cam.near = 0.1
	cam.far = 10.0
	cam.environment = env
	world.add_child(cam)
	cam.transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3(0.0, 0.0, -1.0)), Vector3(rect.get_center().x, 2.0, rect.get_center().y))
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.3, 0.3, 0.3)
	dark.roughness = 1.0
	dark.metallic_specular = 0.0
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4.0, 4.0)
	ground.mesh = pm
	ground.material_override = dark
	world.add_child(ground)
	var deck := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = DECK.size
	deck.mesh = bm
	deck.material_override = dark
	deck.position = DECK.get_center()
	world.add_child(deck)
	for n in also:
		world.add_child(n)
	world.add_child(light)
	for i in 8:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


## What a flame's shadow does to its own pool, read off [param lit] against [param off] (the same light
## casting nothing): the share of its light the open plane and the deck's top keep (`plane`, `deck`), and
## how far the plane's light, binned by distance from under the flame, strays from a running mean (`rings`).
func _pool(lit: Image, off: Image) -> Dictionary:
	var deck_px := Rect2(_px(POOL, Vector2(DECK.position.x, DECK.position.z)), _px(POOL, Vector2(DECK.end.x, DECK.end.z)) - _px(POOL, Vector2(DECK.position.x, DECK.position.z)))
	deck_px = deck_px.grow(-3.0)
	var plane := [0.0, 0.0]
	var deck := [0.0, 0.0]
	var bins := {}
	for y in H:
		for x in W:
			var o := off.get_pixel(x, y).get_luminance()
			if o < 0.02:
				continue
			var l := lit.get_pixel(x, y).get_luminance()
			var at := Vector2(POOL.position.x + (x + 0.5) / W * POOL.size.x, POOL.position.y + (y + 0.5) / H * POOL.size.y)
			if deck_px.has_point(Vector2(x, y)):
				deck[0] += l
				deck[1] += o
			elif at.x < DECK.position.x - 0.01 and at.length() > 0.1:
				# the open plane between the flame and the deck: nothing stands in front of it
				plane[0] += l
				plane[1] += o
			# rings: the plane in front of the deck and beside the wedge it shades
			var clear := at.x < DECK.position.x - 0.01 or absf(at.y) > at.x * tan(deg_to_rad(15.0))
			if clear and at.length() > 0.1 and not deck_px.has_point(Vector2(x, y)):
				var b := int(at.length() * 1000.0)
				var s: Array = bins.get(b, [0.0, 0])
				s[0] += l / o
				s[1] += 1
				bins[b] = s
	var keys := bins.keys()
	keys.sort()
	var prof := PackedFloat32Array()
	for b in keys:
		prof.append(float(bins[b][0]) / float(bins[b][1]))
	var sq := 0.0
	var n := 0
	for i in range(10, prof.size() - 10):
		var m := 0.0
		for k in range(i - 10, i + 11):
			m += prof[k]
		sq += pow(prof[i] - m / 21.0, 2.0)
		n += 1
	# a millimeter a bin from 10 to past 60 cm: fewer, and the pool was not read
	return {"plane": float(plane[0]) / maxf(float(plane[1]), 1e-6), "deck": float(deck[0]) / maxf(float(deck[1]), 1e-6),
		"rings": sqrt(sq / float(n)) if n > 400 else INF, "bins": n}


func _px(rect: Rect2, at: Vector2) -> Vector2:
	return Vector2((at.x - rect.position.x) / rect.size.x * W, (at.y - rect.position.y) / rect.size.y * H)


## A plate [constant PLATE_H] over the plane, its edge aslant, lit from about 86 cm off by a light made as
## [method _flame] makes [param kind]: how far its shadow's edge strays from a line (`stairs`, pixels) and how
## dark the shadow is (`dark`, of the lit plane).
func _plate(kind: String, table: bool) -> Dictionary:
	var rect := Rect2(0.18, -0.01, 0.04, 0.02)
	var light := _flame(kind)
	light.omni_range = 2.0
	light.position = Vector3(-0.5, 0.5, 0.0)
	# shadow-only, its +x edge through (0.19, PLATE_H, 0), turned 25 degrees off the z axis
	var plate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.4, 0.001, 0.4)
	plate.mesh = bm
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var turn := Basis(Vector3.UP, deg_to_rad(25.0))
	plate.transform = Transform3D(turn, Vector3(0.19, PLATE_H, 0.0) - turn * Vector3(0.2, 0.0, 0.0))
	var img := await _shoot(rect, light, table, [plate])
	# the shadow's level and the lit plane's: the picture's left and right edges
	var dark := 0.0
	var lit := 0.0
	for y in H:
		for x in 24:
			dark += img.get_pixel(x, y).get_luminance()
			lit += img.get_pixel(W - 1 - x, y).get_luminance()
	dark /= float(24 * H)
	lit /= float(24 * H)
	var mid := (dark + lit) * 0.5
	# where the plane comes out of the shadow, to a fraction of a pixel, in every few rows read together
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	for y0 in range(0, H, EDGE_ROWS):
		var row := PackedFloat32Array()
		row.resize(W)
		for y in range(y0, y0 + EDGE_ROWS):
			for x in W:
				row[x] += img.get_pixel(x, y).get_luminance() / float(EDGE_ROWS)
		for x in range(1, W):
			if row[x - 1] < mid and row[x] >= mid:
				xs.append(float(x - 1) + (mid - row[x - 1]) / maxf(row[x] - row[x - 1], 1e-6))
				ys.append(y0 + EDGE_ROWS * 0.5)
				break
	# its distance from the best line through it (a straight edge's shadow on a plane is straight)
	var my := 0.0
	var mx := 0.0
	for i in xs.size():
		my += ys[i]
		mx += xs[i]
	my /= maxf(float(xs.size()), 1.0)
	mx /= maxf(float(xs.size()), 1.0)
	var sxy := 0.0
	var syy := 0.0
	for i in xs.size():
		sxy += (ys[i] - my) * (xs[i] - mx)
		syy += (ys[i] - my) * (ys[i] - my)
	var slope := sxy / maxf(syy, 1e-6)
	var sq := 0.0
	for i in xs.size():
		sq += pow(xs[i] - (mx + slope * (ys[i] - my)), 2.0)
	var stairs := sqrt(sq / maxf(float(xs.size()), 1.0)) if xs.size() > H / EDGE_ROWS / 2 else INF

	return {"stairs": stairs, "dark": dark / maxf(lit, 1e-6)}
