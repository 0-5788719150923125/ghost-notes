extends RefCounted
class_name LightShafts

## LightShafts - shafts of light through haze ([Surroundings]' `shafts`), as sunlight through a window, a crack or leaves is: each
## falling from its element's way (the scene's own light turned as its Direction and Steepness say), a beam strayed from it by as much
## as its Spread, the shafts of one beam parallel; a column as wide as the gap it came through all its length - never a
## cone - its edge blurring a little the further it falls (the sun's own width), running down to whatever it lands on and lighting a
## patch there its own size. Shafts come in beams: a broad one with narrower shafts inside it, all drawn added, so the light is about
## twice as bright where they cross. Each is worked out for each pixel from where the line of sight passes its axis ([constant
## SHADER]): brightest through its middle, cut where something stands inside it, faint streaks down it, the haze in it thick and thin,
## brighter looking toward the light than away (haze throws light forward), fading in below the gap and never before it lands.
##
## Its patch is the shader's too: where what is seen stands inside the shaft, what the screen shows there is made brighter, as squarely
## as it faces the light ([constant LANDS]). No light lights it: Godot sorts lights into a coarse grid of the screen by their cone's
## shape and drops one only centimeters wide, and a light shining through a disc needs a shadow map - so the patch is drawn, with no
## glint, no bounce and no shadow behind what it falls on.
##
## Built out of any tree, from each element's properties ([method Surroundings.values_of]) and its number, which places its beams; a
## pure function of show time ([method tick]): the dust drifting in them and their shimmer.

const SHADER := preload("res://shaders/light_shaft.gdshader")
## A beam's width at the Width dial's ends, a share of how far the shafts reach (the host's scale: a desk's, a hollow's).
const WIDTH := Vector2(0.006, 0.08)
## An inner shaft's width, a share of its beam's.
const INNER := Vector2(0.18, 0.5)
## How many times fatter (Variety 1) or skinnier (Variety -1) than the Width a beam may be, and the least and most a beam's radius
## may be (shares of the reach).
const VARIETY_MOST := 8.0
const BEAM_LEAST := 0.0008
const BEAM_MOST := 0.12
## How bright a shaft is through its middle at strength 1 (seen against the dark), and how many times brighter it makes what it lands
## on at strength 1.
const GLOW := 0.25
const LANDS := 24.0
## The share of its brightness a beam with shafts inside it has, and each of them: where one crosses it, the light is twice the beam's.
const SHARE := 0.75
## How far past where it lands a shaft runs on, fading - for ground lower than the box it falls on (a share of the reach).
const SINK := 0.25
## How much a shaft's edge blurs a meter below its gap (radians: the sun's width), and how soft it is at the gap (a share of its radius).
const PENUMBRA := 0.0093
const SOFT := 0.2
## The most shafts drawn, every element's together, and the lowest a shaft may fall from (degrees above the floor).
const MOST := 96
const LOWEST := 12.0


## The shafts of [param elements] (each a shafts element's properties with its `seed`), each beam landing on its own place in one of
## [param over] (boxes in the host's space, each's top where they land - shared out by each box's size), falling from [param reach] (m)
## up its way - [param toward] (the way to the scene's light) turned as the element says ([method way_of]), strayed by its Spread -
## [param color] where an element's color is unset: under one node, out of any tree.
static func build(elements: Array, color: Color, toward: Vector3, over: Array, reach: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Rays"
	var mats: Array = []
	for e in elements:
		var v: Dictionary = e
		var r := RandomNumberGenerator.new()
		r.seed = hash([int(v.get("seed", 0)), "shafts"])
		var way := way_of(toward, float(v.get("turn", 0.0)), float(v.get("steep", 0.0)))
		var spread := deg_to_rad(float(v.get("spread", 0.0)))
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("color", Color.html(String(v["color"])) if Color.html_is_valid(String(v.get("color", ""))) else color)
		mat.set_shader_parameter("strength", GLOW * float(v["strength"]))
		mat.set_shader_parameter("lands", LANDS / GLOW)
		mat.set_shader_parameter("reach", reach)
		mat.set_shader_parameter("sink", SINK * reach)
		mat.set_shader_parameter("penumbra", PENUMBRA)
		mat.set_shader_parameter("soft", SOFT)
		mat.set_shader_parameter("flicker", float(v["flicker"]))
		mats.append(mat)
		var count := int(v["count"])
		var inner := int(v["inner"])
		var variety := float(v["variety"])
		var lands := _lands(count, over, r)
		for i in count:
			if root.get_child_count() >= MOST:
				break
			var beam := beam_radius(float(v["width"]), variety, r.randf(), reach)
			var bright := 1.0 + r.randf_range(-0.45, 0.25) * absf(variety)
			var land: Vector3 = lands[i]
			var dir := strayed(way, spread, r)
			var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.BACK
			var side := up.cross(dir).normalized()
			var across := dir.cross(side).normalized()
			var shafts := [[land, beam, bright * (SHARE if inner > 0 else 1.0)]]
			for j in inner:
				var rad := beam * r.randf_range(INNER.x, INNER.y)
				var a := r.randf() * TAU
				var off := (side * cos(a) + across * sin(a)) * sqrt(r.randf()) * (beam - rad) * 0.9
				shafts.append([land + off, rad, SHARE * (1.0 + r.randf_range(-0.3, 0.2) * absf(variety))])
			for sh in shafts:
				if root.get_child_count() >= MOST:
					break
				var ray := _shaft(sh[0], float(sh[1]), float(sh[2]), r.randf() * TAU, dir, side, reach, mat)
				ray.name = "Ray %d" % root.get_child_count()
				root.add_child(ray)
	root.set_meta("shafts", mats)
	return root


## The way to an element's light: [param toward] (the scene's) turned [param turn] degrees round the vertical and [param steep] degrees
## up (below 0, down), never lower than [constant LOWEST] above the floor nor past straight up.
static func way_of(toward: Vector3, turn: float, steep: float) -> Vector3:
	var t := toward.normalized() if toward.length() > 1e-4 else Vector3.UP
	var flat := Vector2(t.x, t.z)
	var height := rad_to_deg(atan2(t.y, flat.length())) + steep
	height = clampf(height, LOWEST, 89.0)
	var round := (atan2(flat.y, flat.x) if flat.length() > 1e-4 else 0.0) - deg_to_rad(turn)
	var h := deg_to_rad(height)
	return Vector3(cos(round) * cos(h), sin(h), sin(round) * cos(h)).normalized()


## [param way] strayed by up to [param spread] (radians) in a direction drawn from [param r], never lower than [constant LOWEST].
static func strayed(way: Vector3, spread: float, r: RandomNumberGenerator) -> Vector3:
	var a := r.randf() * TAU
	var by := spread * sqrt(r.randf())
	if by <= 0.0:
		return way
	var up := Vector3.UP if absf(way.dot(Vector3.UP)) < 0.98 else Vector3.BACK
	var side := up.cross(way).normalized()
	var across := way.cross(side).normalized()
	var out := (way * cos(by) + (side * cos(a) + across * sin(a)) * sin(by)).normalized()
	if rad_to_deg(asin(clampf(out.y, -1.0, 1.0))) < LOWEST:
		out = way_of(out, 0.0, LOWEST - rad_to_deg(asin(clampf(out.y, -1.0, 1.0))))
	return out


## The shafts [param rays_root] ([method build]) at show time [param t]: the dust drifting in them, and each shimmering as its element
## says - its patch with it.
static func tick(rays_root: Node3D, t: float) -> void:
	if rays_root == null or not rays_root.has_meta("shafts"):
		return
	for mat in (rays_root.get_meta("shafts") as Array):
		(mat as ShaderMaterial).set_shader_parameter("t", t)


## A beam's radius (m) at Width [param width] and Variety [param variety] (-1 to 1), for a beam whose own draw is [param u] (0 to 1),
## falling from [param reach] up: at Variety 0 every beam is the Width's; above 0 each is up to [constant VARIETY_MOST] times fatter,
## below 0 up to as many times skinnier, as far as its draw says - the width the rest stray from in one direction. Held between
## [constant BEAM_LEAST] and [constant BEAM_MOST] of the reach.
static func beam_radius(width: float, variety: float, u: float, reach: float) -> float:
	var base := 0.5 * reach * lerpf(WIDTH.x, WIDTH.y, width)
	return clampf(base * pow(VARIETY_MOST, variety * u), BEAM_LEAST * reach, BEAM_MOST * reach)


## How lit a point [param near] (m) off the axis of a shaft of radius [param radius] is, [param below] (m) under its gap: whole inside,
## nothing past its blurred edge, a little dimmer the more its edge has blurred - line for line the shader's `lit`.
static func lit(radius: float, near: float, below: float) -> float:
	var edge := radius * SOFT + PENUMBRA * maxf(below, 0.0)
	var outer := radius + 0.5 * edge
	var inner := maxf(radius - 0.5 * edge, 0.0)
	return smoothstep(outer, inner, near) * sqrt(radius / outer)


## [param count] places to land, one in its own stretch of one of [param over], shared out by each box's size, drawn from [param r].
static func _lands(count: int, over: Array, r: RandomNumberGenerator) -> Array:
	var out: Array = []
	if over.is_empty():
		for i in count:
			out.append(Vector3.ZERO)
		return out
	var sizes: Array = over.map(func(b: AABB) -> float: return maxf(b.size.x * b.size.z, 1e-4))
	var whole: float = sizes.reduce(func(x: float, y: float) -> float: return x + y, 0.0)
	var in_box: Array = []
	var counts: Array = []
	counts.resize(over.size())
	counts.fill(0)
	for i in count:
		var at_share := (float(i) + 0.5) / float(maxi(count, 1)) * whole
		var bi := 0
		while bi < over.size() - 1 and at_share > float(sizes[bi]):
			at_share -= float(sizes[bi])
			bi += 1
		in_box.append([bi, int(counts[bi])])
		counts[bi] = int(counts[bi]) + 1
	for i in count:
		# a place in its own stretch of its box, along the box's longer side, so the beams stand apart
		var box: AABB = over[int(in_box[i][0])]
		var n := maxi(int(counts[int(in_box[i][0])]), 1)
		var u := (float(int(in_box[i][1])) + r.randf_range(0.2, 0.8)) / float(n)
		var w := r.randf()
		var along_x := box.size.x >= box.size.z
		out.append(Vector3(lerpf(box.position.x, box.end.x, u if along_x else w), box.end.y,
			lerpf(box.position.z, box.end.z, w if along_x else u)))
	return out


## One shaft drawn: a shaft of radius [param rad] along [param dir], from [param reach] up from [param land] to [constant SINK] of it
## past it, +y toward where it comes through - its mesh a column round it as wide as its edge's blur at its foot ([method mesh_radius]).
static func _shaft(land: Vector3, rad: float, glow: float, phase: float, dir: Vector3, side: Vector3, reach: float, mat: Material) -> MeshInstance3D:
	var sink := SINK * reach
	var mesh := CylinderMesh.new()
	mesh.height = reach + sink
	mesh.top_radius = mesh_radius(rad, reach)
	mesh.bottom_radius = mesh.top_radius
	mesh.radial_segments = 20
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	shaft.mesh = mesh
	shaft.material_override = mat
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.transform = Transform3D(Basis(side, dir, side.cross(dir)), land + dir * (reach - sink) * 0.5)
	shaft.set_instance_shader_parameter("radius", rad)
	shaft.set_instance_shader_parameter("glow", glow)
	shaft.set_instance_shader_parameter("phase", phase)
	return shaft


## How wide shaft [param rad]'s mesh is, falling from [param reach] up: its radius and half its edge's blur at its foot, a little over.
static func mesh_radius(rad: float, reach: float) -> float:
	return rad * (1.0 + 0.5 * SOFT) + 0.5 * PENUMBRA * reach * (1.0 + SINK) + 0.002
