extends RefCounted
class_name Drifts

## Drifts - what the wind carries: petals, blossoms, leaves, seeds, keys and feathers, falling from a
## tree overhead or blowing through the scene, settling on the table and lifted off it again by a gust
## (the user, 2026-10-08: "petals could fall from that tree ... either blowing through the scene, or
## settling on the table, or getting carried-off from the table again after another gust"). The air's
## `drift` ([Effects]): its registry, made safe there, built and posed here.
##
## EVERYTHING IS A FUNCTION OF SHOW TIME. Each piece LIVES a planned life ([method _live]): it falls -
## drifting with the air ([method Winds.carried], in closed form), swaying side to side and rocking as a
## falling leaf does, turning and tumbling - lands flat on the cloth, lies there shivering in the breeze,
## and each gust strong enough to beat its grip skids it across the cloth or carries it off over the
## edge. Lives are planned on dice of their own (a slot and a number), as far as they have been asked
## and no further, so any time, asked in any order, poses every piece the same way.
##
## NEVER THROUGH A THING: a fall whose path would pass through the table's edge or anything standing on
## it is thrown again from elsewhere; a skid stops short of what it runs into. A piece lies on the cloth,
## not on the cards: a card laid later lies over it, and one that lands where a card already lies slips
## under its edge - the table does not say where its cards are a piece could rest on.
##
## A piece is real geometry - a cupped quad cut to its outline in the shader (shaders/air_drift.gdshader),
## lit by every light on the table, glowing through where the sun is behind it, casting its small
## shadow, and blurred by the lens like everything else.

const SHADER := preload("res://shaders/air_drift.gdshader")

## WHAT CAN DRIFT: its outline (the shader's `shape`), its length (mm) and the range an agent may set it
## in, its width against its length, how fast it falls through still air (m/s), how closely it follows
## the air (1 a petal, more a seed's tuft, which a breath lifts), how far it sways and rocks as it falls
## (meters, radians) and how often (a second), how fast it tumbles end over end and turns about the
## upright (radians a second), how deep it is cupped, how much light comes through it, its colors when
## none are given, and how readily it settles where it lands.
const LOOKS := {
	"petals": {"about": "blossom petals - cherry, apple, almond, plum - small and pale, fluttering and tumbling down", "shape": 0,
		"size": 13.0, "sizes": Vector2(6.0, 25.0), "aspect": 0.78, "fall": 0.45, "carry": 1.0, "sway": 0.05, "beat": 0.9,
		"rock": 0.6, "tumble": 1.6, "spin": 1.2, "curl": 0.35, "through": 0.55, "colors": ["#f7d9e2", "#fbe9ee", "#f1c4d2"], "settle": 0.7},
	"rose petals": {"about": "rose or peony petals - broad, curled, deep-colored, heavier, falling faster", "shape": 1,
		"size": 35.0, "sizes": Vector2(20.0, 55.0), "aspect": 0.95, "fall": 0.7, "carry": 0.75, "sway": 0.06, "beat": 0.7,
		"rock": 0.45, "tumble": 0.7, "spin": 0.8, "curl": 0.6, "through": 0.4, "colors": ["#9e1530", "#b5203d", "#7d0f25"], "settle": 0.85},
	"blossoms": {"about": "whole small flowers - jasmine, frangipani, orange blossom - dropping and turning slowly as they fall", "shape": 2,
		"size": 26.0, "sizes": Vector2(12.0, 60.0), "aspect": 1.0, "fall": 0.85, "carry": 0.6, "sway": 0.03, "beat": 0.6,
		"rock": 0.25, "tumble": 0.2, "spin": 0.9, "curl": 0.3, "through": 0.35, "colors": ["#fbf6e8", "#fff1d6"], "settle": 0.85},
	"leaves": {"about": "autumn leaves - gold, rust, brown, curled - rocking down side to side as a falling leaf does", "shape": 3,
		"size": 60.0, "sizes": Vector2(30.0, 120.0), "aspect": 0.6, "fall": 0.95, "carry": 0.85, "sway": 0.12, "beat": 0.55,
		"rock": 1.0, "tumble": 0.4, "spin": 0.7, "curl": 0.45, "through": 0.45, "colors": ["#c8862b", "#9b3d1c", "#d9a441", "#7a5226"], "settle": 0.8},
	"green leaves": {"about": "green leaves torn off by the wind - a summer storm, a tree being shaken", "shape": 3,
		"size": 50.0, "sizes": Vector2(25.0, 110.0), "aspect": 0.55, "fall": 1.0, "carry": 0.85, "sway": 0.1, "beat": 0.6,
		"rock": 0.9, "tumble": 0.6, "spin": 0.8, "curl": 0.25, "through": 0.6, "colors": ["#5d7f2e", "#7a9a3a", "#4a6b25"], "settle": 0.75},
	"seeds": {"about": "dandelion seeds or thistledown - white tufts floating slowly, lifted again by any breath", "shape": 4,
		"size": 14.0, "sizes": Vector2(8.0, 25.0), "aspect": 1.0, "fall": 0.14, "carry": 1.25, "sway": 0.03, "beat": 0.35,
		"rock": 0.1, "tumble": 0.0, "spin": 0.3, "curl": 0.0, "through": 0.7, "colors": ["#f6f3ec"], "settle": 0.35},
	"spinners": {"about": "maple or sycamore keys - spinning down like little rotors", "shape": 5,
		"size": 35.0, "sizes": Vector2(22.0, 50.0), "aspect": 0.38, "fall": 0.9, "carry": 0.55, "sway": 0.0, "beat": 0.5,
		"rock": 0.0, "tumble": 0.0, "spin": 14.0, "curl": 0.1, "through": 0.5, "colors": ["#b58b4c", "#9c7a3f", "#c9a066"], "settle": 0.9},
	"feathers": {"about": "small downy feathers - drifting, rocking slowly, lifted by a breath", "shape": 6,
		"size": 40.0, "sizes": Vector2(15.0, 90.0), "aspect": 0.45, "fall": 0.3, "carry": 1.0, "sway": 0.07, "beat": 0.45,
		"rock": 0.7, "tumble": 0.25, "spin": 0.5, "curl": 0.25, "through": 0.5, "colors": ["#efe9e0", "#d9d2c6"], "settle": 0.6},
}
## WHERE THEY COME FROM.
const FROMS := {
	"above": "falling from overhead - a tree, a vine, a pergola's flowers - onto the table and round it",
	"wind": "blown in from the side the wind comes from, across the shot, some landing on the table on the way",
}

## The most pieces in the air at once an agent may ask for, of one drift; the most lying on the table at
## the start; the most drawn at once (in the air and lying), and drifts in one air.
const MAX_AIR := 40
const MAX_LYING := 60
const MAX_SHOWN := 160
const MAX_DRIFTS := 2
## How far past the time asked lives are planned (seconds: a life is planned whole when it starts), and
## the steps of time they are filed in.
const AHEAD := 2.0
const BIN := 10.0
## A fall: how many places on its way are looked at for a thing in it, and how many times it is thrown
## again from elsewhere before it is let be.
const PATH_LOOKS := 16
const THROWS := 8
## How far over the cloth a piece lies (meters), and how much higher each lying piece is than the one
## before it, so two never fight to be seen.
const REST_UP := 0.0018
const STACK := 0.00015
## The least and the most a gust must blow (m/s) to lift a piece at grip 0 and 1 (and at 1, none does).
const LIFT := Vector2(0.12, 1.4)
## The share of a fall it spends turning flat before it lands (seconds).
const LANDING := 0.45
## A lift: how high it hops (meters, at most), and how quickly.
const HOP := 0.04
const HOP_RISE := 0.35
## Further than this from the table's middle, or under the air's floor, a piece is gone (meters).
const GONE := 3.0
## The share of falls from above that come down past the table, in the room behind it.
const BEYOND := 0.3


## THE VOCABULARY, as an agent reads it: [method Effects.describe]'s lines for a drift.
static func describe() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("DRIFT: {\"name\", \"kind\": \"drift\", \"look\", \"from\", \"count\" 1-%d (how many are in the air at once), \"colors\" [\"#rrggbb\", ...] (each piece takes one), \"size\" (millimeters long, within the look's range), \"settle\" 0-1 (how many of those that land on the table stay there; the rest skid off with the next breath), \"grip\" 0-1 (how hard a gust must blow to lift one lying on the cloth and carry it off: 0 any breath, 1 none ever), \"lying\" 0-%d (how many already lie on the table when the reading begins)} - what the wind carries: they fall, sway and tumble, land flat on the cloth and lie there trembling in the breeze, and a gust skids them across it or carries them off over the edge. The light's `wind` blows them (still air when it has none). Looks, each with its size and the sizes it can be:" % [MAX_AIR, MAX_LYING])
	for k in LOOKS:
		var d: Dictionary = LOOKS[k]
		lines.append("- %s: %s (%s mm, %s to %s)" % [k, String(d["about"]), Effects._mm(float(d["size"])), Effects._mm((d["sizes"] as Vector2).x),
			Effects._mm((d["sizes"] as Vector2).y)])
	lines.append("  from:")
	for k in FROMS:
		lines.append("  - %s: %s" % [k, String(FROMS[k])])
	lines.append("  A few pieces read as a moment of the world - a tree in blossom shedding, a gust bringing leaves; dozens at once read as a storm. A lying piece never covers a card for long: the cards are laid over them.")
	return lines


## WHAT AN AGENT WROTE as a drift ([param d]), made safe - or `{}` when its look is not one.
static func sanitize(d: Dictionary) -> Dictionary:
	var look := String(d.get("look", "")).strip_edges().to_lower() if d.get("look") is String else ""
	if not LOOKS.has(look):
		return {}
	var base: Dictionary = LOOKS[look]
	var from := String(d.get("from", "above")).strip_edges().to_lower() if d.get("from") is String else "above"
	return {"kind": "drift", "name": Props._text(d.get("name", look), 80), "look": look, "from": from if FROMS.has(from) else "above",
		"count": int(Props._num(d.get("count"), 8.0, 1.0, float(MAX_AIR))),
		"colors": Effects._colors(d.get("colors", d.get("color")), base["colors"]),
		"size": Props._num(d.get("size"), float(base["size"]), (base["sizes"] as Vector2).x, (base["sizes"] as Vector2).y),
		"settle": Props._num(d.get("settle"), float(base["settle"]), 0.0, 1.0),
		"grip": Props._num(d.get("grip"), 0.5, 0.0, 1.0),
		"lying": int(Props._num(d.get("lying"), 0.0, 0.0, float(MAX_LYING)))}


## A DRIFT BUILT for [param fx] (made safe) on a host's [param stage] ([method Effects.build]: its camera,
## its `occluders` - the table first, then what stands on it - its regions, and `wind`, a [method
## Winds.plan] shared with the light, or still air) from [param salt]: its pieces drawn as one MultiMesh,
## its lives planned as they are asked for ([method at]).
static func build(fx: Dictionary, stage: Dictionary, salt: int, root: Node3D) -> Dictionary:
	var look: Dictionary = LOOKS[String(fx["look"])]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	plane.subdivide_width = 5
	plane.subdivide_depth = 5
	mm.mesh = plane
	mm.instance_count = MAX_SHOWN
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = "Drift"
	mi.multimesh = mm
	# the pieces are moved from here, anywhere in the air: their bounds would lie
	mi.custom_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("shape", int(look["shape"]))
	mat.set_shader_parameter("through", float(look["through"]))
	mi.material_override = mat
	root.add_child(mi)
	var occ: Array = stage.get("occluders", [])
	var table: AABB = occ[0] if not occ.is_empty() else AABB(Vector3(-0.6, -0.75, -0.45), Vector3(1.2, 0.75, 0.9))
	var wind: Dictionary = stage.get("wind", {}) if stage.get("wind") is Dictionary else {}
	if wind.is_empty():
		wind = Winds.plan({}, salt)
	var n_air := int(fx["count"])
	var pop := {"fx": fx, "look": look, "mm": mm, "node": mi, "mat": mat, "salt": salt, "wind": wind, "stage": stage,
		"table": table, "things": occ.slice(1), "rest_y": table.end.y + REST_UP,
		"on_top": stage.get("on_top", Callable()), "floor": Effects._air_floor(stage),
		"size": float(fx["size"]) * 0.001, "lift": LIFT.x + (LIFT.y - LIFT.x) * float(fx["grip"]),
		# a slot falls nearly all the time: as many as are asked for in the air, and a few more for the gaps
		"slots": ceili(float(n_air) * 1.3), "next": [], "made": [], "lives": [], "bins": {}, "planned": -INF, "ongoing": [],
		"resting": [], "cap": maxi(1, int(float(MAX_SHOWN - n_air * 2) / ceilf(float(n_air) * 1.3)))}
	for i in int(pop["slots"]):
		# THE SLOTS START STAGGERED, some already part way down when the show begins
		var r := RandomNumberGenerator.new()
		r.seed = hash([salt, i, "drift-start"])
		(pop["next"] as Array).append(-r.randf_range(0.0, 1.0) * _fall_time(pop))
		(pop["made"] as Array).append(0)
		(pop["resting"] as Array).append([])
	# WHAT ALREADY LIES on the table when the reading begins
	for j in int(fx["lying"]):
		var lv := _lying(pop, j)
		if not lv.is_empty():
			_add(pop, lv)
	return pop


## About how long a piece falls from out of the shot to the cloth (seconds).
static func _fall_time(pop: Dictionary) -> float:
	return 1.4 / maxf(float((pop["look"] as Dictionary)["fall"]), 0.05)


## EVERY PIECE AS IT IS at show time [param t]: `[{xf: Transform3D, color: Color, data: Color}]` - its
## place, its turn and its size, its color, and the shader's (curl, a seed of its own).
static func at(pop: Dictionary, t: float) -> Array:
	_plan_to(pop, t + AHEAD)
	var out: Array = []
	var lives: Array = pop["lives"]
	var bin: Array = (pop["bins"] as Dictionary).get(floori(t / BIN), [])
	for id in bin:
		var lv: Dictionary = lives[int(id)]
		if t < float(lv["t0"]) or t >= float(lv["end"]):
			continue
		out.append({"xf": pose(pop, lv, t), "color": lv["color"], "data": Color(float(lv["curl"]), float(lv["seed"]), 0.0, 0.0)})
		if out.size() >= MAX_SHOWN:
			break
	return out


## The pieces at [param t], drawn.
static func tick(pop: Dictionary, t: float) -> void:
	var now := at(pop, t)
	var mm: MultiMesh = pop["mm"]
	for i in now.size():
		var p: Dictionary = now[i]
		mm.set_instance_transform(i, p["xf"])
		mm.set_instance_color(i, (p["color"] as Color).srgb_to_linear())
		mm.set_instance_custom_data(i, p["data"])
	mm.visible_instance_count = now.size()


# --- the lives ---------------------------------------------------------------------------------------

## Every slot's lives planned until [param until], each filed in the bins of the times it spans.
static func _plan_to(pop: Dictionary, until: float) -> void:
	if until <= float(pop["planned"]):
		return
	var next: Array = pop["next"]
	var made: Array = pop["made"]
	var guard := 0
	while guard < 100000:
		guard += 1
		# the slot whose next piece starts first: lives are made in the order they start
		var k := -1
		for i in next.size():
			if float(next[i]) < until and (k < 0 or float(next[i]) < float(next[k])):
				k = i
		if k < 0:
			break
		var lv := _live(pop, k, int(made[k]), float(next[k]))
		made[k] = int(made[k]) + 1
		next[k] = float(lv["air_end"]) + float(lv["gap"])
		_add(pop, lv)
	# EVERY LIFE STILL GOING is filed into the bins it spans as far as the plan now runs
	var lives: Array = pop["lives"]
	var bins: Dictionary = pop["bins"]
	var still: Array = []
	for id in pop["ongoing"]:
		var lv: Dictionary = lives[int(id)]
		var last := floori(minf(float(lv["end"]), until) / BIN)
		for b in range(maxi(floori(maxf(float(lv["t0"]), -BIN * 4.0) / BIN), int(lv.get("filed", -1000000)) + 1), last + 1):
			if not bins.has(b):
				bins[b] = []
			(bins[b] as Array).append(id)
		lv["filed"] = last
		if float(lv["end"]) > until:
			still.append(id)
	pop["ongoing"] = still
	pop["planned"] = until


## A life kept, to be filed as the plan reaches it.
static func _add(pop: Dictionary, lv: Dictionary) -> void:
	(pop["ongoing"] as Array).append((pop["lives"] as Array).size())
	(pop["lives"] as Array).append(lv)


## The table's top at [param p] (xz): somewhere a piece can lie.
static func _on_top(pop: Dictionary, p: Vector2) -> bool:
	var f: Callable = pop["on_top"]
	if f.is_valid():
		return bool(f.call(p))
	var b: AABB = pop["table"]
	return p.x > b.position.x + 0.01 and p.x < b.end.x - 0.01 and p.y > b.position.z + 0.01 and p.y < b.end.z - 0.01


## Whether [param p] is inside something standing on the table (or the table itself, under its top).
static func _blocked(pop: Dictionary, p: Vector3) -> bool:
	var r := float(pop["size"]) * 0.5
	if p.y < float(pop["rest_y"]) - 0.003:
		var b: AABB = pop["table"]
		if p.y > b.position.y - r and _over_table(pop, Vector2(p.x, p.z)):
			return true
	for o in pop["things"]:
		if (o as AABB).grow(r).has_point(p):
			return true
	return false


## THE RNG of life [param j] of slot [param k]: dice of its own.
static func _dice(pop: Dictionary, k: int, j: int, what: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(pop["salt"]), k, j, what])
	return r


## A PIECE'S OWN WAYS: its size, its color, how it falls, sways, rocks, turns and tumbles.
static func _body(pop: Dictionary, r: RandomNumberGenerator) -> Dictionary:
	var look: Dictionary = pop["look"]
	var fx: Dictionary = pop["fx"]
	var colors: Array = fx["colors"]
	var size := float(pop["size"]) * r.randf_range(0.8, 1.2)
	var sway_ax := Vector2.from_angle(r.randf() * TAU)
	var tumble_ax := Vector3(r.randf_range(-1.0, 1.0), 0.0, r.randf_range(-1.0, 1.0)).normalized()
	return {"size": size, "color": Effects._col(String(colors[r.randi_range(0, colors.size() - 1)])),
		"fall": float(look["fall"]) * r.randf_range(0.8, 1.2), "c": float(look["carry"]) * r.randf_range(0.85, 1.1),
		"sway": float(look["sway"]) * r.randf_range(0.6, 1.3), "beat": float(look["beat"]) * r.randf_range(0.8, 1.25),
		"phase": r.randf() * TAU, "sway_ax": sway_ax, "rock": float(look["rock"]) * r.randf_range(0.7, 1.2),
		"tumble": float(look["tumble"]) * r.randf_range(0.5, 1.4) * (1.0 if r.randf() < 0.5 else -1.0), "tumble_ax": tumble_ax,
		"spin": float(look["spin"]) * r.randf_range(0.6, 1.4) * (1.0 if r.randf() < 0.5 else -1.0), "yaw": r.randf() * TAU,
		"curl": float(look["curl"]) * r.randf_range(0.6, 1.3), "seed": r.randf(), "aspect": float(look["aspect"]) * r.randf_range(0.85, 1.15),
		"flip": r.randf() < 0.35, "rest_yaw": r.randf() * TAU, "shiver_ax": Vector3(r.randf_range(-1.0, 1.0), 0.0, r.randf_range(-1.0, 1.0)).normalized(),
		"lift": float(pop["lift"]) * r.randf_range(0.8, 1.25)}


## LIFE [param j] OF SLOT [param k], its fall starting at [param t0]: where it starts so that it comes
## down where it was meant to (over the table or past it, or across the shot from the wind's side), and
## all it does after - landing, lying, skidding, carried off - planned to its end.
static func _live(pop: Dictionary, k: int, j: int, t0: float) -> Dictionary:
	var r := _dice(pop, k, j, "drift")
	var lv := _body(pop, r)
	lv["t0"] = t0
	lv["slot"] = k
	var wind: Dictionary = pop["wind"]
	var fx: Dictionary = pop["fx"]
	var rest_y := float(pop["rest_y"]) + STACK * float(j % 12)
	var blown := String(fx["from"]) == "wind" and float(wind["breeze"]) > 0.05
	var stage: Dictionary = pop["stage"]
	if blown:
		# borne on the wind, it sinks slowly
		lv["fall"] = float(lv["fall"]) * 0.35
	for attempt in THROWS:
		# WHERE IT IS MEANT TO COME DOWN, and how high it starts: out of the shot above it
		var target: Vector3
		if blown:
			# a place in the shot over the table, a little above the cloth, the wind carrying it there
			target = _target(pop, r, false)
			target.y = rest_y + r.randf_range(0.03, 0.3)
		else:
			target = _target(pop, r, r.randf() < BEYOND)
			target.y = rest_y if _on_top(pop, Vector2(target.x, target.z)) else float(pop["floor"])
		var start_y := _out_above(stage, target, rest_y)
		var dur := (start_y - target.y) / float(lv["fall"])
		var t_at := t0 + dur
		if blown:
			# back along the wind from the place it crosses, until out of the shot upwind
			var back := 0.5
			while back < 20.0:
				var p := Vector3(target.x, target.y, target.z) - _xz3(Winds.carried_between(wind, t_at - back, t_at) * float(lv["c"]))
				p.y = target.y + float(lv["fall"]) * back
				var s: Variant = Effects._screen(stage, p)
				if s == null or (s as Vector2).x < -0.1 or (s as Vector2).x > 1.1 or (s as Vector2).y < -0.1 or (s as Vector2).y > 1.1:
					break
				back += 0.25
			dur = back
			t_at = t0 + dur
			start_y = target.y + float(lv["fall"]) * back
		var drift := Winds.carried_between(wind, t0, t_at) * float(lv["c"])
		lv["p0"] = Vector3(target.x - drift.x, start_y, target.z - drift.y)
		# WHERE IT REALLY GOES, falling to the cloth's height: on the top it lands; past it, on to the floor
		var land := _fall_until(pop, lv, rest_y)
		lv["t1"] = land
		if land < INF:
			lv["land"] = _fall_pos(pop, lv, land, false)
		var ok := not _hits(pop, lv, rest_y)
		if ok or attempt == THROWS - 1:
			break
	# AFTER IT LANDS
	var segs: Array = []
	if float(lv["t1"]) < INF:
		var p: Vector3 = lv["land"]
		p.y = rest_y
		# a slot keeps only so many lying at once: past that, it does not settle
		var resting: Array = (pop["resting"] as Array)[k]
		var lying := 0
		for e in resting:
			lying += 1 if float(e) > float(lv["t1"]) else 0
		var settles := r.randf() < float(fx["settle"]) and lying < int(pop["cap"])
		lv["settled"] = settles
		var lift := float(lv["lift"]) if settles else LIFT.x * 0.5
		if float(fx["grip"]) >= 0.999 and settles:
			lift = INF
		segs = _after(pop, lv, p, float(lv["t1"]), lift, r)
		lv["air_end"] = float(lv["t1"])
		if settles:
			resting.append(float(segs[segs.size() - 1]["end"]) if not segs.is_empty() else Lights.HORIZON)
	else:
		lv["air_end"] = _gone_at(pop, lv)
		lv["end"] = lv["air_end"]
	lv["segs"] = segs
	if not segs.is_empty():
		lv["end"] = float((segs[segs.size() - 1] as Dictionary)["end"])
	lv["gap"] = r.randf_range(0.0, 0.35) * _fall_time(pop)
	return lv


## A piece already lying on the table when the reading begins: on the cloth the camera sees, clear of
## what stands there. {} when no clear place is found.
static func _lying(pop: Dictionary, j: int) -> Dictionary:
	var r := _dice(pop, -1, j, "lying")
	var lv := _body(pop, r)
	var rest_y := float(pop["rest_y"]) + STACK * float(j % 12)
	for i in 24:
		var p := _target(pop, r, false)
		p.y = rest_y
		if _on_top(pop, Vector2(p.x, p.z)) and not _blocked(pop, p + Vector3(0.0, 0.002, 0.0)):
			lv["t0"] = -Lights.HORIZON
			lv["t1"] = -Lights.HORIZON
			lv["p0"] = p
			lv["land"] = p
			lv["slot"] = -1
			var lift := float(lv["lift"]) if float((pop["fx"] as Dictionary)["grip"]) < 0.999 else INF
			lv["segs"] = _after(pop, lv, p, -Lights.HORIZON, lift, r)
			lv["end"] = float((lv["segs"][(lv["segs"] as Array).size() - 1] as Dictionary)["end"])
			lv["air_end"] = -Lights.HORIZON
			return lv
	return {}


## A place a piece is meant for: on the table where the camera sees it, or, [param beyond], in the room
## past its far edge.
static func _target(pop: Dictionary, r: RandomNumberGenerator, beyond: bool) -> Vector3:
	var b: AABB = pop["table"]
	if beyond:
		return Vector3(r.randf_range(b.position.x - 0.6, b.end.x + 0.6), 0.0, r.randf_range(b.position.z - 1.4, b.position.z - 0.05))
	var seen := Rect2(Vector2(maxf(b.position.x, -0.65), maxf(b.position.z, -0.42)), Vector2.ZERO).expand(
		Vector2(minf(b.end.x, 0.65), minf(b.end.z, 0.35)))
	return Vector3(r.randf_range(seen.position.x, seen.end.x), 0.0, r.randf_range(seen.position.y, seen.end.y))


## How high over [param at] a piece starts so it is out of the shot: just above the top of the picture.
static func _out_above(stage: Dictionary, at: Vector3, low: float) -> float:
	var y := maxf(at.y, low) + 0.25
	while y < 3.0:
		var s: Variant = Effects._screen(stage, Vector3(at.x, y, at.z))
		if s == null or (s as Vector2).y < -0.08:
			break
		y += 0.08
	return y + 0.1


static func _xz3(v: Vector2) -> Vector3:
	return Vector3(v.x, 0.0, v.y)


## WHERE A FALLING PIECE IS at [param t]: carried by the air from where it started, swaying, sinking at
## its own pace with a little lift at the ends of each sway; [param lands] eases the lift out before it
## lands, so it comes down on the cloth at its landing time exactly.
static func _fall_pos(pop: Dictionary, lv: Dictionary, t: float, lands := true) -> Vector3:
	var dt := t - float(lv["t0"])
	var w := TAU * float(lv["beat"]) * dt + float(lv["phase"])
	var sway := (lv["sway_ax"] as Vector2) * float(lv["sway"]) * (sin(w) - sin(float(lv["phase"])))
	var xz := Vector2((lv["p0"] as Vector3).x, (lv["p0"] as Vector3).z) + Winds.carried_between(pop["wind"], float(lv["t0"]), t) * float(lv["c"]) + sway
	var bob := float(lv["sway"]) * 0.25 * sin(w) * sin(w)
	if lands and float(lv.get("t1", INF)) < INF:
		bob *= clampf((float(lv["t1"]) - t) / 0.5, 0.0, 1.0)
	return Vector3(xz.x, (lv["p0"] as Vector3).y - float(lv["fall"]) * dt + bob, xz.y)


## When a fall reaches [param y]: its time, or INF when it comes down past the table (on to the floor).
## Its descent is steady (the lift at each sway's end is eased out to land), so the time is exact.
static func _fall_until(pop: Dictionary, lv: Dictionary, y: float) -> float:
	var p0: Vector3 = lv["p0"]
	var t := float(lv["t0"]) + (p0.y - y) / float(lv["fall"])
	var at := _fall_pos(pop, lv, t, false)
	return t if _on_top(pop, Vector2(at.x, at.z)) else INF


## Whether a fall passes through the table's edge or anything standing on it.
static func _hits(pop: Dictionary, lv: Dictionary, rest_y: float) -> bool:
	var t0 := float(lv["t0"])
	var t1 := float(lv["t1"]) if float(lv["t1"]) < INF else t0 + ((lv["p0"] as Vector3).y - float(pop["floor"])) / float(lv["fall"])
	var top := rest_y
	for o in pop["things"]:
		top = maxf(top, (o as AABB).end.y)
	var lands := float(lv["t1"]) < INF
	# only the stretch low enough to meet anything is looked at - and where it lands
	var low := t0 + maxf(((lv["p0"] as Vector3).y - top - 0.02) / float(lv["fall"]), 0.0)
	var times := PackedFloat32Array()
	for i in PATH_LOOKS:
		times.append(lerpf(low, t1, float(i) / float(PATH_LOOKS - 1)))
	if not lands:
		# past the edge, all the way down the table's side - or a cloth hanging over it
		var b: AABB = pop["table"]
		var by := t0 + ((lv["p0"] as Vector3).y - rest_y) / float(lv["fall"])
		var bottom := t0 + ((lv["p0"] as Vector3).y - b.position.y) / float(lv["fall"])
		for i in PATH_LOOKS:
			times.append(lerpf(by, bottom, float(i) / float(PATH_LOOKS - 1)))
	for t in times:
		var p := _fall_pos(pop, lv, t, lands)
		if lands and t >= t1 - 1e-4:
			p.y = rest_y + 0.002
		if _blocked(pop, p):
			return true
	return false


## When a piece that came down past the table is gone: under the air's floor, or far off.
static func _gone_at(pop: Dictionary, lv: Dictionary) -> float:
	var t := float(lv["t0"]) + ((lv["p0"] as Vector3).y - float(pop["floor"])) / float(lv["fall"])
	return minf(t, float(lv["t0"]) + 60.0)


## ALL IT DOES ONCE IT IS DOWN at [param p] at [param t]: it lies there until a gust blows past
## [param lift] (m/s); the gust skids it across the cloth to where the gust alone would take it - short
## of anything in the way - or, when that is past the table's edge, carries it off. Lying, skidding,
## carried off: `[{kind, t, end, from, to, gust}]`.
static func _after(pop: Dictionary, lv: Dictionary, p: Vector3, t: float, lift: float, r: RandomNumberGenerator) -> Array:
	var wind: Dictionary = pop["wind"]
	var segs: Array = []
	var here := p
	var now := t
	var flip := bool(lv["flip"])
	var yaw := float(lv["rest_yaw"])
	for n in 64:
		var g := Winds.next_gust(wind, maxf(now, 0.0), lift) if lift < INF else -1
		if g < 0:
			segs.append({"kind": "rest", "t": now, "end": Lights.HORIZON, "from": here, "flip": flip, "yaw": yaw})
			return segs
		var span := Winds.gust_span(wind, g)
		# it lets go as the gust nears its height
		var go := span.x + (span.z - span.x) * 0.6
		segs.append({"kind": "rest", "t": now, "end": go, "from": here, "flip": flip, "yaw": yaw})
		var stop := span.x + span.y
		var shift := Winds.gust_carried(wind, g, go, stop) * float(lv["c"])
		var to := here + _xz3(shift)
		# SHORT OF WHAT IS IN THE WAY: the first thing on its line stops it there
		var hit := 1.0
		for o in pop["things"]:
			var box: AABB = (o as AABB).grow(float(pop["size"]) * 0.5)
			var h: Variant = box.intersects_segment(here + Vector3(0.0, 0.004, 0.0), to + Vector3(0.0, 0.004, 0.0))
			if h != null:
				hit = minf(hit, maxf(((h as Vector3) - here).length() / maxf(shift.length(), 1e-5) - 0.05, 0.0))
		var turn := r.randf() < 0.4
		if hit >= 1.0 and not _over_table(pop, Vector2(to.x, to.z)):
			# CARRIED OFF, over the edge and away
			var off := {"kind": "off", "t": go, "end": go + 20.0, "from": here, "flip": flip, "yaw": yaw, "gust": g, "edge": go + 20.0}
			var stopped: Variant = _off_plan(pop, lv, off)
			if stopped == null:
				segs.append(off)
				return segs
			# a thing in its way: it fetches up against it instead
			to = stopped
			hit = 1.0
		to = here.lerp(to, minf(hit, 1.0))
		# a skid that would end off the top but not clear of the table stops at the top's edge
		if not _on_top(pop, Vector2(to.x, to.z)):
			var lo := 0.0
			var hi := 1.0
			for i in 12:
				var mid := (lo + hi) * 0.5
				var m := here.lerp(to, mid)
				if _on_top(pop, Vector2(m.x, m.z)):
					lo = mid
				else:
					hi = mid
			to = here.lerp(to, lo)
		segs.append({"kind": "skid", "t": go, "end": stop, "from": here, "to": to, "flip": flip, "yaw": yaw, "turn": turn, "gust": g,
			"hop": HOP * clampf((float((wind["peaks"] as PackedFloat32Array)[g]) - lift) / maxf(lift, 0.05), 0.15, 1.0)})
		if turn:
			flip = not flip
		yaw += r.randf_range(-1.2, 1.2)
		here = to
		now = stop
	segs.append({"kind": "rest", "t": now, "end": Lights.HORIZON, "from": here, "flip": flip, "yaw": yaw})
	return segs


## Where a piece carried off is at [param t]: lifted off the cloth as the gust takes it, carried with the
## air, sinking again once past the table's edge.
static func _off_pos(pop: Dictionary, lv: Dictionary, s: Dictionary, t: float) -> Vector3:
	var dt := t - float(s["t"])
	var from: Vector3 = s["from"]
	var xz := Vector2(from.x, from.z) + Winds.carried_between(pop["wind"], float(s["t"]), t) * float(lv["c"])
	var y := from.y + HOP * 2.0 * (1.0 - exp(-dt / HOP_RISE)) - float(lv["fall"]) * maxf(t - float(s["edge"]), 0.0)
	return Vector3(xz.x, y, xz.y)


## Whether [param p] (xz) is over the table or near enough its edge that a piece sinking there would meet
## it - or a cloth hanging over it.
static func _over_table(pop: Dictionary, p: Vector2) -> bool:
	var b: AABB = pop["table"]
	var m := 0.04
	return p.x > b.position.x - m and p.x < b.end.x + m and p.y > b.position.z - m and p.y < b.end.z + m


## A piece carried off ([param s]): when it is clear of the table, and so begins to sink, and when it is
## gone - under the air's floor. Null when it gets clear; where it was last before something standing
## on the table got in its way, when it does not.
static func _off_plan(pop: Dictionary, lv: Dictionary, s: Dictionary) -> Variant:
	var t0 := float(s["t"])
	var t := t0
	var last: Vector3 = s["from"]
	while t < t0 + 20.0:
		var p := _off_pos(pop, lv, s, t)
		if not _over_table(pop, Vector2(p.x, p.z)):
			break
		if _blocked(pop, p):
			return Vector3(last.x, (s["from"] as Vector3).y, last.z)
		last = p
		t += 0.05
	s["edge"] = t
	var top := (s["from"] as Vector3).y + HOP * 2.0
	s["end"] = t + (top - float(pop["floor"])) / maxf(float(lv["fall"]), 0.05)
	return null


# --- posed ---------------------------------------------------------------------------------------------

## LIFE [param lv] POSED at [param t]: its place, its turn and its size (x across it, z along it, y the
## way its face looks).
static func pose(pop: Dictionary, lv: Dictionary, t: float) -> Transform3D:
	var size := float(lv["size"])
	var scale := Basis.from_scale(Vector3(size * float(lv["aspect"]), size, size))
	var t1 := float(lv["t1"])
	if t < t1 or t1 >= INF:
		var at := _fall_pos(pop, lv, t)
		var b := _falling_basis(pop, lv, t)
		if t1 < INF and t > t1 - LANDING:
			# TURNING FLAT as it comes down
			var e := smoothstep(t1 - LANDING, t1, t)
			b = Basis(b.get_rotation_quaternion().slerp(_lying_basis(bool(lv["flip"]), float(lv["rest_yaw"])).get_rotation_quaternion(), e))
		return Transform3D(b * scale, at)
	for s in lv["segs"]:
		var d: Dictionary = s
		if t >= float(d["end"]):
			continue
		var flat := _lying_basis(bool(d["flip"]), float(d["yaw"]))
		match String(d["kind"]):
			"rest":
				# TREMBLING IN THE BREEZE, harder as it rises
				var shiver := 0.18 * Winds.strength_at(pop["wind"], t) * sin(17.0 * t + float(lv["seed"]) * 40.0)
				return Transform3D(Basis(lv["shiver_ax"], shiver) * flat * scale, d["from"])
			"skid":
				var u := clampf((t - float(d["t"])) / maxf(float(d["end"]) - float(d["t"]), 1e-4), 0.0, 1.0)
				var gw := Winds.swell_carry(pop["wind"], int(d["gust"]), t)
				var g0 := Winds.swell_carry(pop["wind"], int(d["gust"]), float(d["t"]))
				var g1 := Winds.swell_carry(pop["wind"], int(d["gust"]), float(d["end"]))
				var along := clampf((gw - g0) / maxf(g1 - g0, 1e-5), 0.0, 1.0)
				var at := (d["from"] as Vector3).lerp(d["to"], along)
				at.y += float(d["hop"]) * sin(PI * along)
				var b := flat
				if bool(d["turn"]):
					var axis := Vector3((d["to"] as Vector3).z - (d["from"] as Vector3).z, 0.0, (d["from"] as Vector3).x - (d["to"] as Vector3).x)
					if axis.length() > 1e-5:
						b = Basis(axis.normalized(), PI * along) * flat
				return Transform3D(b * scale, at)
			"off":
				var dt := t - float(d["t"])
				var b := Basis(Vector3.UP, float(lv["spin"]) * 2.0 * dt) * Basis(lv["tumble_ax"], (absf(float(lv["tumble"])) + 2.0) * dt) * flat
				return Transform3D(b * scale, _off_pos(pop, lv, d, t))
	return Transform3D(Basis.from_scale(Vector3.ONE * 1e-4), Vector3(0.0, -50.0, 0.0))


## Lying flat on the cloth, face up or down, turned [param yaw] about the upright.
static func _lying_basis(flip: bool, yaw: float) -> Basis:
	return Basis(Vector3.UP, yaw) * (Basis(Vector3.FORWARD, PI) if flip else Basis.IDENTITY)


## HOW A FALLING PIECE IS TURNED at [param t]: turning about the upright, rocking with its sway (tipped
## toward the way it swings, as a falling leaf rocks), and tumbling end over end; a seed's tuft keeps
## upright, its fluff to the sky.
static func _falling_basis(pop: Dictionary, lv: Dictionary, t: float) -> Basis:
	var dt := t - float(lv["t0"])
	var w := TAU * float(lv["beat"]) * dt + float(lv["phase"])
	var ax2: Vector2 = lv["sway_ax"]
	var rock_axis := Vector3(-ax2.y, 0.0, ax2.x)
	var b := Basis(Vector3.UP, float(lv["yaw"]) + float(lv["spin"]) * dt)
	b = Basis(rock_axis, float(lv["rock"]) * cos(w)) * b
	if absf(float(lv["tumble"])) > 0.0:
		b = b * Basis(Vector3.RIGHT, float(lv["tumble"]) * dt)
	if int((pop["look"] as Dictionary)["shape"]) == 5:
		# A KEY'S WING tips down from its seed as it spins
		b = b * Basis(Vector3.RIGHT, 0.35)
	return b
