extends RefCounted
class_name TableGame

## TableGame - A GAME, ON THE TABLE (next/tabletop.md): the map, the paper figures, the dice and the pictures held up, drawn from a session's events: a part of [TableWork], as [TableAssembly] is. A pure function of show time and when each event was
## reached (`game.json`, [method schedule]): a render, a scrub and a live reading all see the same table.
##
## A DIE'S STORY: it rises from where its person keeps their dice, is shaken in the hand, and then goes where the record has it ([DiceBake]: real bodies, thrown from where they sit, as the same record for live and render); it lies until the next throw or a while passes, and goes home. Its
## printing is turned, once, so the number rolled is on the face it lands on ([method Dice.turn_for]), and what shows on a die is what was rolled.
##
## THE SHOT GOES TO THE DICE ([method shot_at]): a die is too small to read from across a table, and a viewer who reads it first laughs first. As they land the camera eases in to look, and eases back after the words go on. Never fast: the user of a camera that moved for every
## line, 2026-10-27: "the forward and backward zooming of the camera is nauseating".
##
## A FIGURE IS A PAINTED CARD IN A BASE, a little leaned back so it reads from above, and when it falls it lies flat on its back: its painting up, which a fallen miniature never shows. A move is a hop, by [Hands].
##
## WHAT IS IN THE RECORD IS MADE WHEN THE TABLE FIRST STANDS on the stage: named by everything it depends on, and kept, so a note opened again costs nothing. A preview draws dice nowhere.

## A roll's own moments (seconds): rising from where they are kept, shaken in the air; how long it lies before it goes home if nothing else has been thrown, and how long going home takes.
const RISE := 0.28
const SHAKE := 0.42
const LIES := 9.0
const HOME_TAKES := 0.6
## Their hand, shaking (meters, a second): a small quick round.
const SHAKE_REACH := 0.012
const SHAKE_RATE := 6.5
## How much rattling is heard in a shake.
const RATTLE_RATE := 11.0
const RATTLE_HARD := 0.28
## THE SHOT: how many dice it goes to at most, how far from them it stands (meters), how long before they stop it begins (from their rest), how long it eases in, holds on after, and eases out; and how far from the camera's own place it comes (a share).
const SHOT_DICE := 4
const SHOT_FAR := 0.56
const SHOT_LEADS := 0.55
const SHOT_IN := 1.5
const SHOT_HOLDS := 1.6
const SHOT_OUT := 2.0
const SHOT_WEIGHT := 0.75
## A figure's hop, at least and by how far it goes (seconds), and how high (a share of how far, at least and most in meters). A place from above, and a removal: seconds. A fall, then its give.
const HOP_LEAST := 0.42
const HOP_RATE := 0.1
const HOP_HIGH := Vector2(0.018, 0.05)
const PLACE_TAKES := 0.5
const FALL_TAKES := 0.34
## How far back a card leans as it stands, so a viewer above reads it (degrees).
const LEAN_BACK := 24.0
## The picture held up: in front of the lens by this far (meters), this big (meters), how long it takes to come up and how long it lasts.
const HOLD_FAR := 0.42
const HOLD_SIZE := Vector2(0.27, 0.18)
const REVEAL_TAKES := 0.8
const REVEAL_LASTS := 9.0
## A map going down, a share of the show's time, and how far off it comes from.
const MAP_TAKES := 1.1
const MAP_FROM := 0.7
## How high what lies on a table lies (meters), a map over it.
const MAP_Y := 0.0012
const BASE_R := 0.46
const BASE_H := 0.0035
## A record's name changes when this does: what the world does is the same given the same of everything else.
const BAKE_VERSION := 1
const BAKES_KEPT := 24
const PROBE_BAKES := "res://dist/game_bakes"
## Where records are kept, where a gate wants them; a gate's way to a show that plays while its record is made, for everything else run from tests/ waits for it.
static var bake_root := ""
static var live_in_tests := false
## What each person keeps at their place: one of each, as a set is.
const SET := [4, 6, 8, 10, 12, 20]

var work: TableWork
var game := {}
## An episode's folder: its pictures are here, by their steps' names.
var dir := ""
var seed_value := 0

var root: Node3D
var _maps: Array = []         # a map -> {node, rect, event, mat}
var _figures: Array = []      # one life of a figure on the table -> {node, card, spans..}
var _reveals: Array = []      # {node, event}
var _rolls: Array = []        # {event, nodes, ...} in order
var _times := {}              # an event's id -> when it happens, seconds of show time
var _record := {}             # an event's id -> {dur, dice, hits, against}
var _record_path := ""
var _pid := -1
var _baking := false
var _failed := false
var _shots: Array = []        # {t0, t1, at} in order
var _cam: Transform3D
var _fov := 40.0
var _top := "wood"
var _pictures := {}           # a picture's file -> its texture, once loaded
var _homes: Array = []        # each person's own dice, lying at their place: {node, who, shape}


func _init(owner: TableWork, game_data: Dictionary, folder: String, seed_of: int) -> void:
	work = owner
	game = game_data
	dir = folder
	seed_value = seed_of


# --- standing it up ---------------------------------------------------------------------------------------------------------------------------------

func stand() -> void:
	root = Node3D.new()
	root.name = "Game"
	work.medium._root3.add_child(root)
	_cam = work.medium._plan.cam_base
	_fov = float(work.medium._plan.fov)
	_stand_maps()
	_stand_figures()
	_stand_reveals()
	_stand_rolls()
	_stand_homes()


func _stand_maps() -> void:
	var list: Array = game.get("maps", [])
	for e in game.get("events", []):
		var d: Dictionary = e
		if String(d.get("kind", "")) != "map":
			continue
		var pic := int(d.get("pic", 0))
		var m: Dictionary = list[pic - 1] if pic >= 1 and pic <= list.size() else {}
		if m.is_empty():
			continue
		var rect := GameBoard.rect_of(m)
		var quad := PlaneMesh.new()
		quad.size = rect.size
		var node := MeshInstance3D.new()
		node.mesh = quad
		node.material_override = _map_material(m, pic)
		node.visible = false
		root.add_child(node)
		_maps.append({"node": node, "rect": rect, "event": int(d["id"])})


func _map_material(m: Dictionary, pic: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/game_map.gdshader")
	var tex := _picture("map_%d.png" % pic)
	if tex != null:
		mat.set_shader_parameter("painting", tex)
		mat.set_shader_parameter("painted", true)
	var size: Array = m.get("size", [20, 14])
	mat.set_shader_parameter("squares", Vector2(float(size[0]), float(size[1])))
	mat.set_shader_parameter("grid", bool(m.get("grid", true)))
	return mat


## EVERY LIFE OF A FIGURE: placed on a map, moved, fallen, stood up, taken off, or swept off as its map goes. One node each, whatever else happens on the table.
func _stand_figures() -> void:
	var maps: Array = game.get("maps", [])
	var map := {}
	var alive := {}
	var map_ids: Array = []
	for e in game.get("events", []):
		var d: Dictionary = e
		var what := String(d.get("kind", ""))
		var name := String(d.get("figure", ""))
		match what:
			"map":
				for k in alive:
					(alive[k] as Dictionary)["ends"].append({"id": int(d["id"]), "how": "map"})
				alive.clear()
				var pic := int(d.get("pic", 0))
				map = maps[pic - 1] if pic >= 1 and pic <= maps.size() else {}
				map_ids.append(int(d["id"]))
			"place":
				if map.is_empty():
					continue
				var life := {"name": name, "pic": int(d.get("pic", 0)), "owner": String(d.get("owner", "")), "map": map, "from": d["at"], "placed": int(d["id"]), "steps": [], "ends": [], "node": null}
				life["node"] = _figure_node(life)
				_figures.append(life)
				alive[name] = life
			"move":
				if alive.has(name):
					((alive[name] as Dictionary)["steps"] as Array).append({"id": int(d["id"]), "kind": "move", "to": d.get("to", [0, 0])})
			"fall", "rise":
				if alive.has(name):
					((alive[name] as Dictionary)["steps"] as Array).append({"id": int(d["id"]), "kind": what})
			"remove":
				if alive.has(name):
					((alive[name] as Dictionary)["ends"] as Array).append({"id": int(d["id"]), "how": "remove"})
					alive.erase(name)


## A FIGURE'S NODES: a low base, and the painted card held in it, its pivot where it stands in its base.
func _figure_node(life: Dictionary) -> Node3D:
	var w := GameBoard.figure_width(life["map"])
	var tall := w * GameBoard.FIGURE_TALL
	var node := Node3D.new()
	node.visible = false
	root.add_child(node)
	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = w * BASE_R
	disc.bottom_radius = w * BASE_R * 1.08
	disc.height = BASE_H
	disc.radial_segments = 20
	base.mesh = disc
	base.position = Vector3(0.0, BASE_H * 0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _owner_color(String(life["owner"]))
	mat.roughness = 0.5
	base.material_override = mat
	node.add_child(base)
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, BASE_H, 0.0)
	node.add_child(pivot)
	var card := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(w, tall)
	card.mesh = quad
	card.position = Vector3(0.0, tall * 0.5, 0.0)
	var face := StandardMaterial3D.new()
	face.cull_mode = BaseMaterial3D.CULL_DISABLED
	face.roughness = 0.8
	var tex := _picture("figure_%d.png" % int(life["pic"]))
	if tex != null:
		face.albedo_texture = tex
	else:
		face.albedo_color = _owner_color(String(life["owner"])).lightened(0.3)
	card.material_override = face
	pivot.add_child(card)
	life["pivot"] = pivot
	return node


func _owner_color(owner: String) -> Color:
	var set: Dictionary = (game.get("dice", {}) as Dictionary).get(owner, {})
	return Color.from_string(String(set.get("color", "")), Color(0.22, 0.2, 0.2))


func _stand_reveals() -> void:
	var list: Array = game.get("reveals", [])
	for e in game.get("events", []):
		var d: Dictionary = e
		if String(d.get("kind", "")) != "reveal":
			continue
		var pic := int(d.get("pic", 0))
		if pic < 1 or pic > list.size():
			continue
		var quad := QuadMesh.new()
		quad.size = HOLD_SIZE
		var node := MeshInstance3D.new()
		node.mesh = quad
		var face := StandardMaterial3D.new()
		face.cull_mode = BaseMaterial3D.CULL_DISABLED
		face.roughness = 0.75
		var tex := _picture("reveal_%d.png" % pic)
		if tex != null:
			face.albedo_texture = tex
			# ...A PICTURE IN THE HAND STANDS OUT OF THE TABLE'S DIM LIGHT: it faces the lens, its light is from over the table, and it is what a viewer is being shown
			face.emission_enabled = true
			face.emission_texture = tex
			face.emission_energy_multiplier = 0.55
		else:
			face.albedo_color = Color(0.82, 0.78, 0.66)
		node.material_override = face
		node.visible = false
		root.add_child(node)
		_reveals.append({"node": node, "event": int(d["id"])})


## EVERY THROW'S DICE, made once, its nodes hidden until wanted: its printing and its body's own material from whose they are.
func _stand_rolls() -> void:
	var sets: Dictionary = game.get("dice", {})
	var seats: Dictionary = game.get("seats", {})
	for e in game.get("events", []):
		var d: Dictionary = e
		if String(d.get("kind", "")) != "roll":
			continue
		var who := String(d.get("who", ""))
		var set: Dictionary = sets.get(who, {})
		var nodes: Array = []
		for t in d.get("thrown", []):
			var th: Dictionary = t
			var shape := int(th["shape"])
			var labels := Dice.labels_of(shape, int(th.get("sides", shape)), th.get("labels", PackedStringArray()))
			var n := MeshInstance3D.new()
			n.mesh = Dice.mesh_of(shape, labels)
			_paint_die(n, set)
			n.scale = Vector3.ONE * float(set.get("size", 1.0))
			n.visible = false
			root.add_child(n)
			nodes.append({"node": n, "shape": shape, "face": int(th["face"])})
		var seat := float(seats.get(who, 0.0))
		var home := GameBoard.at_seat(seat, GameBoard.HOME)
		_rolls.append({"event": d, "id": int(d["id"]), "nodes": nodes, "home": Vector3(home.x, 0.03, home.y), "hidden": bool(d.get("hidden", false)), "scale": float(set.get("size", 1.0))})


## WHERE EACH PERSON KEEPS THEIR DICE: a set lying at their place, which is where a throw is seen to begin. A die in the air is not lying there too ([method _tick_homes]).
func _stand_homes() -> void:
	var sets: Dictionary = game.get("dice", {})
	var seats: Dictionary = game.get("seats", {})
	for who in game.get("people", []):
		var set: Dictionary = sets.get(String(who), {})
		var home := GameBoard.at_seat(float(seats.get(String(who), 0.0)), GameBoard.HOME)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "game-home", String(who)])
		for k in SET.size():
			var shape := int(SET[k])
			var n := MeshInstance3D.new()
			n.mesh = Dice.mesh_of(shape, Dice.labels_of(shape, shape))
			_paint_die(n, set)
			var scale_of := float(set.get("size", 1.0))
			var lying := _lying_on(shape, rng.randi_range(0, shape - 1))
			var at := home + Vector2((float(k) - 2.5) * 0.024 * scale_of, rng.randf_range(-0.012, 0.012))
			var b := Basis(Vector3.UP, rng.randf() * TAU) * lying
			n.transform = Transform3D(b * Basis.from_scale(Vector3.ONE * scale_of), Vector3(at.x, _lift_of(shape) * scale_of + MAP_Y, at.y))
			root.add_child(n)
			_homes.append({"node": n, "who": String(who), "shape": shape})


## A BODY'S TURN FOR LYING ON ITS FACE [param face]: that face down.
static func _lying_on(shape: int, face: int) -> Basis:
	var n: Vector3 = ((Dice.solid(shape)["faces"] as Array)[face] as Dictionary)["normal"]
	return Basis(Quaternion(n, Vector3.DOWN))


## How far a die's middle stands from the table, lying on a face.
static func _lift_of(shape: int) -> float:
	return (((Dice.solid(shape)["faces"] as Array)[0] as Dictionary)["center"] as Vector3).length() * Dice.radius_of(shape)


func _tick_homes(t: float) -> void:
	var out := {}
	for r in _rolls:
		var rd: Dictionary = r
		var at := _when(int(rd["id"]))
		if at > t or t > float(rd.get("_gone", INF)):
			continue
		var who := String((rd["event"] as Dictionary).get("who", ""))
		for nd in rd["nodes"]:
			out["%s %d" % [who, int((nd as Dictionary)["shape"])]] = true
	for h in _homes:
		var d: Dictionary = h
		(d["node"] as Node3D).visible = not out.has("%s %d" % [String(d["who"]), int(d["shape"])])


func _paint_die(n: MeshInstance3D, set: Dictionary) -> void:
	var material: Dictionary = Dice.MATERIALS.get(String(set.get("material", "plastic")), Dice.MATERIALS["plastic"])
	var body := StandardMaterial3D.new()
	var color := Color.from_string(String(set.get("color", "")), Color(0.5, 0.14, 0.14))
	body.albedo_color = color
	body.metallic = float(material["metal"])
	body.roughness = float(material["rough"])
	if String(set.get("material", "")) == "glass":
		body.albedo_color = Color(color, 0.68)
		body.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	n.set_surface_override_material(0, body)
	if n.mesh.get_surface_count() > 1:
		var ink := StandardMaterial3D.new()
		ink.albedo_color = Color.from_string(String(set.get("ink", "")), Color(0.95, 0.92, 0.82))
		ink.roughness = 0.5
		ink.cull_mode = BaseMaterial3D.CULL_DISABLED
		n.set_surface_override_material(1, ink)


## A painted picture, or null where there is none yet: read once ([method Image.load_from_file], as the table's other pictures are).
func _picture(file: String) -> ImageTexture:
	var path := dir.path_join(file)
	if _pictures.has(path):
		return _pictures[path]
	var tex: ImageTexture = null
	if not dir.is_empty() and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	_pictures[path] = tex
	return tex


func clear() -> void:
	if _pid > 0 and Subprocess.alive(_pid):
		Subprocess.stop(_pid)
	_pid = -1
	if root != null and is_instance_valid(root):
		root.queue_free()
	root = null


# --- when ---------------------------------------------------------------------------------------------------------------------------------------------

## WHEN EACH EVENT WAS REACHED: the placed marks of the reading ([method ReadingFollower.place]), whose `card` is the event's id. Asked again every sentence of a live reading: nothing here is decided by when it asks.
func schedule(sched: Array) -> void:
	_times = {}
	for e in sched:
		var a: Dictionary = e["a"]
		if TableActions.names_event(String(a["kind"])):
			_times[int(a["card"])] = float(e["t0"])
	_shots = []
	if _record.is_empty():
		return
	for r in _rolls:
		var id := int((r as Dictionary)["id"])
		if bool((r as Dictionary)["hidden"]) or ((r as Dictionary)["nodes"] as Array).size() > SHOT_DICE or not _times.has(id) or not _record.has(id):
			continue
		var rec: Dictionary = _record[id]
		var thrown := float(_times[id]) + RISE + SHAKE
		var at := Vector3.ZERO
		var dice: Array = rec["dice"]
		for d in dice:
			var k: PackedFloat32Array = (d as Dictionary)["keys"]
			if k.size() >= 8:
				at += Vector3(k[k.size() - 7], k[k.size() - 6], k[k.size() - 5])
		if dice.is_empty():
			continue
		at /= float(dice.size())
		_shots.append({"t0": thrown + float(rec["dur"]) - SHOT_LEADS, "t1": thrown + float(rec["dur"]) + SHOT_HOLDS, "at": at})


func _when(id: int) -> float:
	return float(_times.get(id, INF))


# --- the record ---------------------------------------------------------------------------------------------------------------------------------------

## WHETHER A SHOW HAS TO WAIT: the first time a table stands with a session on it, the record is made ([DiceBake]); a show waits, as for the bricks, only until it lands, and it is seconds, not minutes.
func behind(_t: float) -> bool:
	if _rolls.is_empty() or not _record.is_empty():
		return false
	_begin_record()
	if _sync():
		wait_whole()
		return false
	_land_record()
	return _record.is_empty() and not _failed


## A render waits whole, and so does whatever stands a table on no stage: as [method TableAssembly._sync].
func _sync() -> bool:
	if live_in_tests:
		return false
	return work.medium == null or not work.medium.is_inside_tree() or TablePhysics.render_waits()


func ready_to(t: float) -> float:
	return INF if not _record.is_empty() or _rolls.is_empty() else t


## A RENDER WAITS WHOLE: it never plays what has not landed.
func wait_whole() -> void:
	_begin_record()
	while _record.is_empty() and not _failed:
		_land_record()
		if not _record.is_empty() or _pid <= 0 or not Subprocess.alive(_pid):
			break
		OS.delay_msec(50)
	_land_record()


func _begin_record() -> void:
	if _baking or _failed or not _record.is_empty():
		return
	_baking = true
	var root_dir := bake_root if not bake_root.is_empty() else ("user://game_bakes" if not AgentJobs.read_only() else PROBE_BAKES)
	root_dir = ProjectSettings.globalize_path(root_dir)
	DirAccess.make_dir_recursive_absolute(root_dir)
	var solids := _solids()
	var req := GameBoard.bake_request(game, solids, seed_value, "")
	var key := hash([BAKE_VERSION, str(req["rolls"]), req["seed"], solids.size(), _faces_key(solids)])
	_record_path = root_dir.path_join("%016x.bin" % key)
	if FileAccess.file_exists(_record_path):
		_read_record()
		return
	req["out"] = _record_path
	var req_path := _record_path.trim_suffix(".bin") + ".request"
	var f := FileAccess.open(req_path, FileAccess.WRITE)
	if f == null:
		_failed = true
		return
	f.store_buffer(var_to_bytes(req))
	f.close()
	var args: PackedStringArray = Subprocess.own_log("dice_bake") + TableAssembly._project_args() + PackedStringArray(["--headless", "--fixed-fps", str(DiceBake.TICKS), "--script", "res://src/table/dice_bake.gd", "--", req_path])
	_pid = Subprocess.start(OS.get_executable_path(), args, "dice")
	if _pid <= 0:
		push_warning("game: the dice could not be thrown")
		_failed = true


static func _faces_key(solids: Array) -> int:
	var n := 0
	for s in solids:
		n = hash([n, ((s as Dictionary)["faces"] as PackedVector3Array).size(), ((s as Dictionary)["faces"] as PackedVector3Array)[0] if not ((s as Dictionary)["faces"] as PackedVector3Array).is_empty() else Vector3.ZERO])
	return n


## What dice bounce off: everything stood on this table, as the table has it ([method TableWork._mesh_of]).
func _solids() -> Array:
	var out: Array = []
	for ti in work.things.size():
		var tm: TriangleMesh = work._mesh_of(ti)
		if tm != null:
			var faces := tm.get_faces()
			for i in faces.size():
				faces[i] = faces[i] / TableWork.RAY_SCALE
			out.append({"faces": faces})
	return out


func _land_record() -> void:
	if not _record.is_empty() or _record_path.is_empty():
		return
	if FileAccess.file_exists(_record_path):
		_read_record()
	elif _pid > 0 and not Subprocess.alive(_pid):
		push_warning("game: the dice were thrown and nothing was written")
		_failed = true


func _read_record() -> void:
	var f := FileAccess.open(_record_path, FileAccess.READ)
	if f == null:
		_failed = true
		return
	var got: Variant = bytes_to_var(f.get_buffer(f.get_length()))
	f.close()
	if not (got is Dictionary) or not ((got as Dictionary).get("rolls") is Dictionary):
		_failed = true
		return
	_record = (got as Dictionary)["rolls"]
	# ...each die's printing, turned so the number rolled is on the face it came to rest on
	for r in _rolls:
		var rd: Dictionary = r
		var rec: Dictionary = _record.get(int(rd["id"]), {})
		var dice: Array = rec.get("dice", [])
		var nodes: Array = rd["nodes"]
		for k in mini(dice.size(), nodes.size()):
			var nd: Dictionary = nodes[k]
			nd["turn"] = Dice.turn_for(int(nd["shape"]), int(nd["face"]), int((dice[k] as Dictionary)["face"]))
			nd["keys"] = (dice[k] as Dictionary)["keys"]
	var times := _times
	schedule_again(times)


func schedule_again(times: Dictionary) -> void:
	var sched: Array = []
	for id in times:
		sched.append({"a": {"kind": "roll", "card": id}, "t0": times[id]})
	schedule(sched)


# --- posing -------------------------------------------------------------------------------------------------------------------------------------------

func tick(t: float) -> void:
	if root == null:
		return
	if not _rolls.is_empty() and _record.is_empty():
		_land_record()
	_tick_maps(t)
	_tick_figures(t)
	_tick_reveals(t)
	_tick_rolls(t)
	_tick_homes(t)


## THE MAP DOWN NOW: each its own span, sliding in over the last, which slides out.
func _tick_maps(t: float) -> void:
	var seen := -1
	for i in _maps.size():
		if _when(int((_maps[i] as Dictionary)["event"])) <= t:
			seen = i
	for i in _maps.size():
		var m: Dictionary = _maps[i]
		var n: MeshInstance3D = m["node"]
		var at := _when(int(m["event"]))
		var rect: Rect2 = m["rect"]
		var mid := rect.get_center()
		var going := 0.0
		if i < _maps.size() - 1 and i == seen - 1:
			going = clampf((t - _when(int((_maps[i + 1] as Dictionary)["event"]))) / MAP_TAKES, 0.0, 1.0)
		var coming := clampf((t - at) / MAP_TAKES, 0.0, 1.0)
		n.visible = t >= at and i >= seen - 1 and going < 1.0
		if not n.visible:
			continue
		var off := (1.0 - Hands.smooth(coming)) * MAP_FROM - Hands.smooth(going) * MAP_FROM
		n.position = Vector3(mid.x, MAP_Y, mid.y + off * -1.0)


func _tick_figures(t: float) -> void:
	for f in _figures:
		var life: Dictionary = f
		var node: Node3D = life["node"]
		var placed := _when(int(life["placed"]))
		var ended := INF
		for e in life["ends"]:
			ended = minf(ended, _when(int((e as Dictionary)["id"])))
		node.visible = t >= placed and t < ended + PLACE_TAKES
		if not node.visible:
			continue
		var map: Dictionary = life["map"]
		var at := GameBoard.at_map(map, life["from"])
		var place := Vector3(at.x, 0.0, at.y)
		var from := place
		var fall := 0.0
		var hop := 1.0
		for s in life["steps"]:
			var step: Dictionary = s
			var when := _when(int(step["id"]))
			if when > t:
				continue
			match String(step["kind"]):
				"move":
					var to2 := GameBoard.at_map(map, step["to"])
					var to := Vector3(to2.x, 0.0, to2.y)
					var far := place.distance_to(to)
					var takes := HOP_LEAST + HOP_RATE * sqrt(far / maxf(GameBoard.cell_of(map), 0.01))
					hop = clampf((t - when) / takes, 0.0, 1.0)
					var lin := Hands.smooth(hop)
					from = place.lerp(to, lin)
					from.y = 4.0 * lin * (1.0 - lin) * clampf(far * 0.3, HOP_HIGH.x, HOP_HIGH.y)
					place = to if hop >= 1.0 else place
					if hop >= 1.0:
						from = place
				"fall":
					fall = clampf((t - when) / FALL_TAKES, 0.0, 1.0)
				"rise":
					fall = 1.0 - clampf((t - when) / (FALL_TAKES * 1.6), 0.0, 1.0)
		var dropping := clampf((t - placed) / PLACE_TAKES, 0.0, 1.0)
		var up := (1.0 - Hands.smooth(dropping)) * 0.16
		var taken := clampf((t - ended) / PLACE_TAKES, 0.0, 1.0) if ended < INF else 0.0
		up += Hands.smooth(taken) * 0.3
		node.position = from + Vector3(0.0, up + MAP_Y * 1.5, 0.0)
		# ...A FALL: backward onto its back, painting up, with one small bounce
		var drop := fall * fall
		var lean := lerpf(deg_to_rad(LEAN_BACK), deg_to_rad(89.0), drop)
		if fall >= 1.0:
			lean = deg_to_rad(89.0)
		(life["pivot"] as Node3D).basis = Basis(Vector3.RIGHT, -lean)


func _tick_reveals(t: float) -> void:
	for r in _reveals:
		var d: Dictionary = r
		var node: MeshInstance3D = d["node"]
		var at := _when(int(d["event"]))
		var going := at + REVEAL_LASTS
		# ...the next picture, or a new map, takes it away
		for o in _reveals:
			var when := _when(int((o as Dictionary)["event"]))
			if when > at and when < going:
				going = when
		node.visible = t >= at and t < going + REVEAL_TAKES
		if not node.visible:
			continue
		var up := Hands.smooth(clampf((t - at) / REVEAL_TAKES, 0.0, 1.0))
		var down := Hands.smooth(clampf((t - going) / REVEAL_TAKES, 0.0, 1.0))
		var show := up * (1.0 - down)
		var held := _cam * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -HOLD_FAR))
		var lying := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, 0.03, -0.42))
		node.transform = lying.interpolate_with(held, show)


func _tick_rolls(t: float) -> void:
	for i in _rolls.size():
		var r: Dictionary = _rolls[i]
		var nodes: Array = r["nodes"]
		var at := _when(int(r["id"]))
		var thrown := at + RISE + SHAKE
		var rec: Dictionary = _record.get(int(r["id"]), {})
		var dur := float(rec.get("dur", 2.0))
		# ...IT GOES HOME as the next throw begins, or once it has lain a while
		var gone := thrown + dur + LIES
		if i + 1 < _rolls.size():
			gone = minf(gone, _when(int((_rolls[i + 1] as Dictionary)["id"])))
		var shows := t >= at and t < gone + HOME_TAKES
		r["_gone"] = gone + HOME_TAKES
		for k in nodes.size():
			var nd: Dictionary = nodes[k]
			var n: MeshInstance3D = nd["node"]
			n.visible = shows
			if not shows:
				continue
			var turn: Basis = nd.get("turn", Basis.IDENTITY)
			var scale_of := Vector3.ONE * float(r["scale"])
			var xf: Transform3D
			var home := _home_of(r, k)
			if t < thrown:
				xf = _in_hand(t, at, home, rec, k)
			else:
				var keys: PackedFloat32Array = nd.get("keys", PackedFloat32Array())
				xf = _keyed(keys, t - thrown)
				if t >= gone:
					var lin := Hands.smooth(clampf((t - gone) / HOME_TAKES, 0.0, 1.0))
					var along := xf.origin.lerp(home.origin, lin)
					along.y += 4.0 * lin * (1.0 - lin) * 0.04
					xf = Transform3D(xf.basis.orthonormalized().slerp(home.basis, lin), along)
			n.transform = Transform3D(xf.basis.orthonormalized() * turn * Basis.from_scale(scale_of), xf.origin)


## Where this die lies when nobody is rolling it: a small row at its person's place.
func _home_of(r: Dictionary, k: int) -> Transform3D:
	var home: Vector3 = r["home"]
	var along := Vector3(cos(float(k) * 2.4), 0.0, sin(float(k) * 2.4)) * 0.018 * sqrt(float(k))
	return Transform3D(Basis(Vector3(0.3, 1.0, 0.1).normalized(), float(k) * 1.7), home + along)


## UP OUT OF WHERE IT LAY AND SHAKEN: to where the record's first key begins, closed form.
func _in_hand(t: float, at: float, home: Transform3D, rec: Dictionary, k: int) -> Transform3D:
	var dice: Array = rec.get("dice", [])
	var keys: PackedFloat32Array = (dice[k] as Dictionary)["keys"] if k < dice.size() else PackedFloat32Array()
	var first := _keyed(keys, 0.0) if keys.size() >= 8 else home
	var rising := Hands.smooth(clampf((t - at) / RISE, 0.0, 1.0))
	var p := home.origin.lerp(first.origin, rising)
	var phase := (t - at) * SHAKE_RATE * TAU + float(k) * 1.3
	var shaking := clampf((t - at - RISE * 0.5) / (RISE * 0.5), 0.0, 1.0)
	p += Vector3(cos(phase), sin(phase * 1.3) * 0.5, sin(phase)) * SHAKE_REACH * shaking
	var b := Basis(Vector3(sin(phase * 0.4 + float(k)), 1.0, cos(phase * 0.3)).normalized(), phase * 0.7)
	return Transform3D(b.slerp(first.basis, Hands.smooth(clampf((t - at - RISE) / SHAKE, 0.0, 1.0))), p)


static func _keyed(keys: PackedFloat32Array, tau: float) -> Transform3D:
	var n := keys.size() / 8
	if n == 0:
		return Transform3D.IDENTITY
	if tau <= keys[0]:
		return _key_at(keys, 0)
	if tau >= keys[(n - 1) * 8]:
		return _key_at(keys, n - 1)
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if keys[mid * 8] <= tau:
			lo = mid
		else:
			hi = mid
	var a := _key_at(keys, lo)
	var b := _key_at(keys, hi)
	var f := (tau - keys[lo * 8]) / maxf(keys[hi * 8] - keys[lo * 8], 0.0001)
	return a.interpolate_with(b, f)


static func _key_at(keys: PackedFloat32Array, i: int) -> Transform3D:
	var j := i * 8
	return Transform3D(Basis(Quaternion(keys[j + 4], keys[j + 5], keys[j + 6], keys[j + 7]).normalized()), Vector3(keys[j + 1], keys[j + 2], keys[j + 3]))


# --- the shot ---------------------------------------------------------------------------------------------------------------------------------------

## WHERE THE CAMERA IS AT [param t]: [param base], or on the way to the dice ([constant SHOT_FAR] from them, looking down at them from over their shoulder of the table), at most as far as [constant SHOT_WEIGHT] takes it.
func shot_at(t: float, base: Transform3D) -> Transform3D:
	var out := base
	for s in _shots:
		var d: Dictionary = s
		var t0 := float(d["t0"])
		var t1 := float(d["t1"])
		if t < t0 - SHOT_IN or t > t1 + SHOT_OUT:
			continue
		var w := Hands.smooth(clampf((t - (t0 - SHOT_IN)) / SHOT_IN, 0.0, 1.0)) * (1.0 - Hands.smooth(clampf((t - t1) / SHOT_OUT, 0.0, 1.0)))
		var at: Vector3 = d["at"]
		var toward := (base.origin - at).normalized()
		var eye := at + toward * SHOT_FAR
		var close := Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye)
		out = out.interpolate_with(close, w * SHOT_WEIGHT)
	return out


# --- heard ------------------------------------------------------------------------------------------------------------------------------------------

## EVERY HIT BETWEEN TWO MOMENTS OF THE SHOW, as [WorkSounds] rings them: real ones where the record has them, and a few quick soft knocks of dice shaken in a hand.
func sounds_in(t0: float, t1: float) -> Array:
	var out: Array = []
	for r in _rolls:
		var rd: Dictionary = r
		var at := _when(int(rd["id"]))
		if at >= t1 or at == INF:
			continue
		var thrown := at + RISE + SHAKE
		var set: Dictionary = (game.get("dice", {}) as Dictionary).get(String((rd["event"] as Dictionary).get("who", "")), {})
		var material: Dictionary = Dice.MATERIALS.get(String(set.get("material", "plastic")), Dice.MATERIALS["plastic"])
		var rings := String(material["sound"])
		var weight := float(material["mass"])
		var rec: Dictionary = _record.get(int(rd["id"]), {})
		# ...THE SHAKE, while it is in hand
		if at + RISE < t1 and thrown > t0 and (rd["nodes"] as Array).size() > 0:
			var k0 := ceili(maxf(t0 - at - RISE, 0.0) * RATTLE_RATE)
			var k1 := floori(minf(t1 - at - RISE, SHAKE) * RATTLE_RATE)
			var home: Vector3 = rd["home"]
			for k in range(k0, k1 + 1):
				var when := at + RISE + float(k) / RATTLE_RATE
				if when >= t0 and when < t1:
					out.append({"t": when, "kind": "hit", "against": rings, "at": home, "strength": RATTLE_HARD * (0.7 + 0.3 * sin(float(k) * 1.9)), "size": 0.018, "weight": weight * 0.4})
		if rec.is_empty():
			continue
		var hits: PackedFloat32Array = rec["hits"]
		var against: PackedStringArray = rec["against"]
		for k in against.size():
			var j := k * 6
			var when := thrown + hits[j]
			if when < t0 or when >= t1:
				continue
			var what := against[k]
			out.append({"t": when, "kind": "hit", "against": rings if what == "die" else _top, "at": Vector3(hits[j + 1], hits[j + 2], hits[j + 3]), "strength": hits[j + 4], "size": hits[j + 5], "weight": weight})
	return out


## What a report says of it: for the probes.
func report() -> String:
	return "game: %d maps, %d figures, %d pictures, %d throws; record %s" % [_maps.size(), _figures.size(), _reveals.size(), _rolls.size(), "ready" if not _record.is_empty() else ("failed" if _failed else "not yet")]
