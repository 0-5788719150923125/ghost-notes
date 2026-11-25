extends RefCounted
class_name TableGame

## TableGame - a game on the table (next/tabletop.md): the map, the paper figures, the dice and the pictures held up,
## drawn from a session's events; a part of [TableWork], as [TableAssembly] is. A pure function of show time and when
## each event was reached (`game.json`, [method schedule]): a render, a scrub and a live reading all see the same table.
##
## A die rises from where its person keeps their dice, is shaken in the hand, then goes where the record has it
## ([DiceBake]: real bodies thrown from where they sit, the same record for live and render); it lies until the next
## throw or a while passes, and goes home. Its printing is turned once so the number rolled is on the face it lands on
## ([method Dice.turn_for]).
##
## The shot goes to the dice ([method shot_at]): a die is too small to read from across a table, so as they land the
## camera eases in, and eases back after the words go on. Never fast.
##
## A figure is a painted card in a base, leaned back a little so it reads from above; when it falls it lies flat on its
## back, painting up. A move is a hop, by [Hands].
##
## The record is made when the table first stands on the stage: named by everything it depends on and kept, so a note
## opened again costs nothing. A preview draws no dice.
##
## ON A MODEL'S BOARD ([GameDiorama], the episode's `diorama.json`) the board is the map: it stands in the table's middle, a figure
## modeled for the night (`minis.json`) stands on its ground on a base, faces where it goes and WALKS there ([constant WALK]),
## and a figure with no model is its paper card. A page of the night's book (a `picture` event) covers the frame while its words go
## on, until the next page or the table wants the eye back ([method _tick_pages]): a STICKER PAGE drawn by the night's [StickerBook]
## (a set with its cast stuck on it, the camera moving across it from page to page), or a whole painted page (`page_K.png`), pushed in
## slowly, in a session told that way.
##
## THE OPENING HOLDS THE TABLE FROM ITS HEAD ([method opening_end]): pushed slowly in from the intro's start, settled, and seen
## [constant OPENING_SEES] past the show's first words before any page or other camera may take the view.
##
## THE CAMERA IS A LIST ([Cameras], the feed's `cameras`, every sort where it names none): each sort wants moments of the session
## - the dice as they land, a march as figures walk, whoever's turn it is from their seat, long narration round the model - and
## the one highest in the list has a moment two want; every change is eased, round the table rather than across it
## ([method _shot]). A pure function of show time, as the rest.

## A roll's moments (seconds): rising from where dice are kept, shaken in the air; how long it lies before going home if nothing else is thrown, and how long going home takes.
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
## The shot: the most dice it goes to, how far from them it stands (meters), how long before they stop it begins (from their rest), how long it eases in, holds on after, and eases out.
## How far from the camera's own place it comes is the dice camera's own (its `reach`, [constant Cameras.REGISTRY]).
const SHOT_DICE := 4
const SHOT_FAR := 0.56
const SHOT_LEADS := 0.55
const SHOT_IN := 1.5
const SHOT_HOLDS := 1.6
const SHOT_OUT := 3.0
## A dice camera that arrives all the way is there this long before they stop (seconds).
const SHOT_ARRIVES := 0.3
## The farthest the eye goes toward a throw's dice (meters), where its camera arrives only part of the way: from far off it goes part of that.
const DICE_TRAVEL := 1.4
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
## How far ahead of the figures a march looks (meters), in a landscape frame: room for where they are going.
const MARCH_LEAD := 0.08
## The most of the frame's width a picture held up takes: it is held farther off in a frame too narrow for it.
const HOLD_ACROSS := 0.86
const REVEAL_TAKES := 0.8
const REVEAL_LASTS := 9.0
## A map going down, a share of the show's time, and how far off it comes from.
const MAP_TAKES := 1.1
const MAP_FROM := 0.7
## How high what lies on a table lies (meters), a map over it.
const MAP_Y := 0.0012
const BASE_R := 0.46
const BASE_H := 0.0035
## A figure walking on a model's board: how fast (meters a second), the shortest and longest a walk takes (seconds), its step's bob
## (meters) and rate (steps a second). A modeled figure's base: its radius and height (meters).
const WALK := 0.045
const WALK_LEAST := 1.4
const WALK_MOST := 10.0
const BOB := 0.0018
const STEPS := 2.6
const MINI_BASE := Vector2(0.0125, 0.0035)
## A page of the night's book: how far in front of the lens it hangs (meters), how long it takes to come and go, the least it
## stays before the table may take the eye back, and how far in it is pushed (a share).
const PAGE_FAR := 0.25
const PAGE_FADE := 0.9
const PAGE_LEAST := 4.5
## The opening: once the show opens (its `begin`), how long the table is seen whole from its head before a page or any other camera
## may take the view, and how much of that the camera is settled and still at its end (seconds); how far in it is pushed by then (a
## share of the way to what it looks at), slowly from the very start of the intro - at least OPENING_PUSH, and in a frame taller than
## the table is dressed for as far as it takes for the frame's bottom to fall on the board, OPENING_MARGIN (meters) of table in front of
## it, rather than past the table into the dark, at most OPENING_PUSH_MOST ([method _opening_push]).
const OPENING_SEES := 5.0
const OPENING_STILL := 1.5
const OPENING_PUSH := 0.12
const OPENING_PUSH_MOST := 0.6
const OPENING_MARGIN := 0.08
## The longest a page is pushed in over (seconds): a page whose end is not placed yet is pushed as one held this long.
const PAGE_HOLD := 45.0
const PAGE_PUSH := 0.1
## How much of what a page loses off the frame's height comes off its bottom rather than evenly (0 even, 1 all of it).
const PAGE_TOP := 0.85
## The least a seat's camera looks down past the top of its frame (degrees): no shot round the table shows the room's horizon.
const BELOW_HORIZON := 4.0
## The table seen whole from its head, as a tilt-shift photograph of a model (0 sharp throughout, 1 the most) - the one camera that
## is not on the list ([constant Cameras.REGISTRY] `miniature`).
const HEAD_MINIATURE := 0.55
## A miniature's band in focus across the frame, either side of where the camera looks (a share of the frame's height, at none
## and at the most), and how far in front of the lens its sheet hangs (meters, short of a page).
const MINI_BAND := Vector2(0.24, 0.05)
const MINI_FAR := 0.1
const TILT_SHADER := preload("res://shaders/table_tilt.gdshader")
## A record's name changes when this does.
const BAKE_VERSION := 2
const BAKES_KEPT := 24
const PROBE_BAKES := "res://dist/game_bakes"
## Where records are kept; a gate sets it, and a show that plays while its record is made waits for it.
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
var _diorama: GameDiorama = null
var _minis := {}              # the night's modeled figures: {figures: name -> thing, materials}
var _pages: Array = []        # {node, mat, event, size}
var _claims: Array = []       # what each camera wants: {sort, rank, t0, t1, ...} ([method _plan_cameras])
var _tilt: MeshInstance3D = null
var _shot_t := NAN
var _shot_cache := {}
var _opened := INF             # when the show opened (its `begin`), seconds of show time
var _push := OPENING_PUSH      # how far in the opening pushes ([method _opening_push]), as the cameras were last planned
var _book: StickerBook = null  # the night's book as a sticker book, where its pages are stuck on sets ([StickerBook])
var _sheet: MeshInstance3D = null
var _sheet_mat: StandardMaterial3D = null


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
	_stand_board()
	_stand_maps()
	_stand_figures()
	_stand_reveals()
	_stand_pages()
	_stand_rolls()
	_stand_homes()
	_stand_tilt()
	# ...the cameras planned before any mark is placed: a live reading places a stretch's marks only as its words come, and
	# until the first, the long talk before it is already a camera's
	_plan_cameras()


## The model's board and the night's figures, where the episode has them: built here, on the worker that builds the table.
func _stand_board() -> void:
	if (game.get("board", {}) as Dictionary).is_empty() or dir.is_empty():
		return
	var d: Variant = _read_json("diorama.json")
	if d is Dictionary:
		_diorama = GameDiorama.new(d, seed_value)
		var breathe := Callable(work.medium, "_breathe") if work.medium != null and work.medium.has_method("_breathe") else Callable()
		root.add_child(_diorama.build(breathe))
	var m: Variant = _read_json("minis.json")
	if m is Dictionary and (m as Dictionary).get("figures") is Dictionary:
		_minis = m


func _read_json(file: String) -> Variant:
	var path := dir.path_join(file)
	return JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null


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


## Every life of a figure: placed on a map, moved, fallen, stood up, taken off, or swept off as its map goes. One node each, whatever else happens on the table.
func _stand_figures() -> void:
	var maps: Array = game.get("maps", [])
	var map: Dictionary = game.get("board", {}) if game.get("board") is Dictionary else {}
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


## A figure's nodes: a low base, and the painted card held in it, its pivot where it stands in its base - or, where the night's figures
## were modeled, its model on a round base, painted as a wargamer paints one: black, its rim in its player's color.
func _figure_node(life: Dictionary) -> Node3D:
	var figs: Dictionary = _minis.get("figures", {}) if _minis.get("figures") is Dictionary else {}
	if figs.get(String(life["name"])) is Dictionary:
		var made := _mini_node(life, figs[String(life["name"])])
		if made != null:
			return made
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


func _mini_node(life: Dictionary, raw: Dictionary) -> Node3D:
	var thing := raw.duplicate(true)
	thing["name"] = String(life["name"])
	var safe := Props.sanitize({"things": [thing], "materials": _minis.get("materials", {})}, [])
	if (safe["things"] as Array).is_empty():
		return null
	var built := Props.build((safe["things"] as Array)[0], safe["materials"], hash([seed_value, String(life["name"]), "mini"]))
	var node := Node3D.new()
	node.visible = false
	root.add_child(node)
	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = MINI_BASE.x * 0.94
	disc.bottom_radius = MINI_BASE.x
	disc.height = MINI_BASE.y
	disc.radial_segments = 24
	base.mesh = disc
	base.position = Vector3(0.0, MINI_BASE.y * 0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.055, 0.05)
	mat.roughness = 0.6
	base.material_override = mat
	node.add_child(base)
	if not String(life["owner"]).is_empty():
		var rim := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = MINI_BASE.x * 0.9
		ring.outer_radius = MINI_BASE.x * 1.02
		ring.rings = 24
		rim.mesh = ring
		rim.scale = Vector3(1.0, 0.25, 1.0)
		rim.position = Vector3(0.0, MINI_BASE.y * 0.85, 0.0)
		var rm := StandardMaterial3D.new()
		rm.albedo_color = _owner_color(String(life["owner"]))
		rim.material_override = rm
		node.add_child(rim)
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, MINI_BASE.y, 0.0)
	node.add_child(pivot)
	pivot.add_child(built["node"])
	life["pivot"] = pivot
	life["mini"] = true
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
			# A picture in the hand stands out of the table's dim light: it faces the lens, lit from over the table
			face.emission_enabled = true
			face.emission_texture = tex
			face.emission_energy_multiplier = 0.55
		else:
			face.albedo_color = Color(0.82, 0.78, 0.66)
		node.material_override = face
		node.visible = false
		root.add_child(node)
		_reveals.append({"node": node, "event": int(d["id"])})


## Every throw's dice, made once, its nodes hidden until wanted: its printing and its body's own material from whose they are.
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


## Where each person keeps their dice: a set lying at their place, which is where a throw is seen to begin. A die in the air is not lying there too ([method _tick_homes]).
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


## A body's turn for lying on its face [param face]: that face down.
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

## When each event was reached: the placed marks of the reading ([method ReadingFollower.place]), whose `card` is the event's id. Asked again every sentence of a live reading: nothing here is decided by when it asks.
func schedule(sched: Array) -> void:
	_times = {}
	var opened := INF
	var whole := false
	var opens := false
	for e in sched:
		var a: Dictionary = e["a"]
		if TableActions.names_event(String(a["kind"])):
			_times[int(a["card"])] = float(e["t0"])
			continue
		whole = true
		if not TableActions.source_of(String(a["kind"])).is_empty():
			opens = true
			opened = minf(opened, float(e["t0"]))
	# ...a schedule of the game's own events alone ([method schedule_again]) keeps the opening it had; one whose opening the voice has
	# not reached yet holds the table until it does; one with no opening at all holds nothing
	if whole:
		_opened = opened if opens else -INF
	_shots = []
	# ...when each page goes is worked out again from the marks placed now: a page cached before the next one was placed never went
	for p in _pages:
		(p as Dictionary).erase("_going")
	if _record.is_empty():
		_plan_cameras()
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
		_shots.append({"t0": thrown + float(rec["dur"]) - SHOT_LEADS, "t1": thrown + float(rec["dur"]) + SHOT_HOLDS, "at": at, "who": String(((r as Dictionary)["event"] as Dictionary).get("who", "")),
			"thrown": thrown})
	_plan_cameras()


func _when(id: int) -> float:
	return float(_times.get(id, INF))


# --- the record ---------------------------------------------------------------------------------------------------------------------------------------

## Whether a show has to wait: the first time a table stands with a session on it the record is made ([DiceBake]); a show waits, as for the bricks, only until it lands (seconds).
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


## A render waits whole: it never plays what has not landed.
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
	var out: Array = [GameDiorama.solid()] if _diorama != null else []
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
	_tick_pages(t)
	_tick_tilt(t)
	_tick_rolls(t)
	_tick_homes(t)


## The map down now: each its own span, sliding in over the last, which slides out.
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
		var ended := _ended(life)
		node.visible = t >= placed and t < ended + PLACE_TAKES
		if not node.visible:
			continue
		var pose := _pose(life, t)
		var dropping := clampf((t - placed) / PLACE_TAKES, 0.0, 1.0)
		var up := (1.0 - Hands.smooth(dropping)) * 0.16
		var taken := clampf((t - ended) / PLACE_TAKES, 0.0, 1.0) if ended < INF else 0.0
		up += Hands.smooth(taken) * 0.3
		var fall := float(pose["fall"])
		var drop := fall * fall
		if bool(life.get("mini", false)):
			# ...a model stands up straight, faces where it goes, and a fall tips it onto its side
			node.position = (pose["at"] as Vector3) + Vector3(0.0, up, 0.0)
			node.basis = Basis(Vector3.UP, float(pose["heading"]))
			(life["pivot"] as Node3D).basis = Basis(Vector3.FORWARD, lerpf(0.0, deg_to_rad(84.0), drop))
			continue
		node.position = (pose["at"] as Vector3) + Vector3(0.0, up + MAP_Y * 1.5, 0.0)
		# ...A fall: backward onto its back, painting up, with one small bounce
		var lean := lerpf(deg_to_rad(LEAN_BACK), deg_to_rad(89.0), drop)
		if fall >= 1.0:
			lean = deg_to_rad(89.0)
		(life["pivot"] as Node3D).basis = Basis(Vector3.RIGHT, -lean)


func _ended(life: Dictionary) -> float:
	var ended := INF
	for e in life["ends"]:
		ended = minf(ended, _when(int((e as Dictionary)["id"])))
	return ended


## Where a figure is at [param t] and how it stands: `{at, heading, fall, walking}` - on a model's board its ground under it,
## walking each move at a walker's pace; on a laid map, hopping.
func _pose(life: Dictionary, t: float) -> Dictionary:
	var map: Dictionary = life["map"]
	var model := bool(map.get("model", false))
	var at := GameBoard.at_map(map, life["from"])
	var place := Vector3(at.x, _ground(at), at.y)
	var from := place
	var fall := 0.0
	var heading := 0.0
	var walking := false
	for s in life["steps"]:
		var step: Dictionary = s
		var when := _when(int(step["id"]))
		if when > t:
			continue
		match String(step["kind"]):
			"move":
				var to2 := GameBoard.at_map(map, step["to"])
				var to := Vector3(to2.x, _ground(to2), to2.y)
				var far := Vector2(place.x, place.z).distance_to(to2)
				if far > 0.001:
					heading = atan2(to.x - place.x, to.z - place.z)
				var done := false
				if model:
					var takes := _walk_takes(far)
					var u := clampf((t - when) / takes, 0.0, 1.0)
					var lin := Hands.smooth(u)
					var p := Vector2(place.x, place.z).lerp(to2, lin)
					from = Vector3(p.x, _ground(p) + absf(sin(u * takes * STEPS * PI)) * BOB, p.y)
					walking = u < 1.0
					done = u >= 1.0
				else:
					var takes := HOP_LEAST + HOP_RATE * sqrt(far / maxf(GameBoard.cell_of(map), 0.01))
					var hop := clampf((t - when) / takes, 0.0, 1.0)
					var lin := Hands.smooth(hop)
					from = place.lerp(to, lin)
					from.y = 4.0 * lin * (1.0 - lin) * clampf(far * 0.3, HOP_HIGH.x, HOP_HIGH.y)
					done = hop >= 1.0
				if done:
					place = to
					from = to
			"fall":
				fall = clampf((t - when) / FALL_TAKES, 0.0, 1.0)
			"rise":
				fall = 1.0 - clampf((t - when) / (FALL_TAKES * 1.6), 0.0, 1.0)
	return {"at": from, "heading": heading, "fall": fall, "walking": walking}


## How long a walk of [param far] meters takes on a model's board.
static func _walk_takes(far: float) -> float:
	return clampf(far / WALK, WALK_LEAST, WALK_MOST)


## The ground's height at [param p] (meters, the table's): the model's where it stands, the table's elsewhere.
func _ground(p: Vector2) -> float:
	return _diorama.height_at(p.x, p.y) if _diorama != null else 0.0


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
		# ...held out at arm's length, or farther where the frame is too narrow for it (a portrait one): never wider than most of it
		var far := maxf(HOLD_FAR, HOLD_SIZE.x / (HOLD_ACROSS * 2.0 * _lens(fov_at(t)).x))
		var held := _eye(t) * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -far))
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
		# ...It goes home as the next throw begins, or once it has lain a while
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


## Up out of where it lay and shaken: to where the record's first key begins, closed form.
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

## The cameras in force: the feed's list ([member ShowFeed.cameras]), or every sort a table has.
func _camera_list() -> Array:
	var feed: ShowFeed = work.medium.feed if work != null and work.medium != null else null
	return Cameras.sanitize(feed.cameras if feed != null else [], true, "table")


## What each camera on the list wants of the session, worked out once a schedule is known: the dice as they land, a march as
## figures walk, whoever's turn it is, and long stretches with nothing else wanted, round the model.
func _plan_cameras() -> void:
	_claims = []
	_shot_t = NAN
	var list := _camera_list()
	var e := Cameras.entry_of(list, "dice")
	if not e.is_empty():
		for sh in _shots:
			var d: Dictionary = sh
			var stop := float(d["t1"]) - SHOT_HOLDS
			var t0 := float(d["t0"]) - SHOT_OUT * 0.6
			var ease := SHOT_OUT
			# ...one that arrives all the way cuts in: under way as the hand throws, there just before the dice stop, so they land in its frame
			if Cameras.value(e, "reach") >= 1.0:
				t0 = minf(t0, float(d.get("thrown", stop)) - SHOT_LEADS)
				ease = maxf(stop - SHOT_ARRIVES - t0, SHOT_IN)
			_claims.append({"sort": "dice", "rank": Cameras.rank(list, "dice"), "t0": t0,
				"t1": stop + Cameras.value(e, "holds"), "stop": stop, "at": d["at"], "who": d["who"], "entry": e,
				"ease": ease, "weight": Cameras.value(e, "reach")})
	e = Cameras.entry_of(list, "seat")
	if not e.is_empty():
		var turns: Array = []
		for ev in game.get("events", []):
			var d: Dictionary = ev
			if String(d.get("kind", "")) in ["turn", "roll"] and _times.has(int(d["id"])):
				turns.append({"t": float(_times[int(d["id"])]), "who": String(d.get("who", ""))})
		turns.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t"]) < float(y["t"]))
		var i := 0
		while i < turns.size():
			var who := String(turns[i]["who"])
			var t0 := float(turns[i]["t"])
			var j := i + 1
			while j < turns.size() and String(turns[j]["who"]) == who:
				j += 1
			var t1 := t0 + Cameras.value(e, "holds")
			if j < turns.size():
				# ...straight on round to the next seat, never back to the table between
				t1 = minf(t1, float(turns[j]["t"]) + Cameras.EASE) if float(turns[j]["t"]) < t1 else t1
			_claims.append({"sort": "seat", "rank": Cameras.rank(list, "seat"), "t0": t0, "t1": t1, "who": who, "entry": e})
			i = j
	e = Cameras.entry_of(list, "march")
	if not e.is_empty() and bool((game.get("board", {}) as Dictionary).get("model", false)):
		var group: Dictionary = {}
		for ev in game.get("events", []):
			var d: Dictionary = ev
			if String(d.get("kind", "")) != "move" or not _times.has(int(d["id"])):
				continue
			var t := float(_times[int(d["id"])])
			var board: Dictionary = game["board"]
			var from := GameBoard.at_map(board, d.get("from", [0, 0]))
			var to := GameBoard.at_map(board, d.get("to", [0, 0]))
			if group.is_empty() or t - float(group["t0"]) > 1.0:
				group = {"sort": "march", "rank": Cameras.rank(list, "march"), "t0": t, "t1": t, "names": [], "from": Vector2.ZERO, "to": Vector2.ZERO, "entry": e}
				_claims.append(group)
			(group["names"] as Array).append(String(d.get("figure", "")))
			var n := float((group["names"] as Array).size())
			group["from"] = (group["from"] as Vector2).lerp(from, 1.0 / n)
			group["to"] = (group["to"] as Vector2).lerp(to, 1.0 / n)
			group["t1"] = maxf(float(group["t1"]), t + _walk_takes(from.distance_to(to)) + Cameras.value(e, "lingers"))
	e = Cameras.entry_of(list, "drift")
	if not e.is_empty():
		var spans: Array = []
		for c in _claims:
			spans.append(Vector2(float((c as Dictionary)["t0"]), float((c as Dictionary)["t1"])))
		spans.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.x < y.x)
		var last := 0.0
		# ...and the talk after the last mark placed is open: what comes next is not placed yet
		spans.append(Vector2(INF, INF))
		for sp in spans:
			var gap0 := last + Cameras.value(e, "after") + Cameras.EASE
			if sp.x - gap0 > Cameras.EASE * 2.0:
				_claims.append({"sort": "drift", "rank": Cameras.rank(list, "drift"), "t0": gap0, "t1": sp.x - Cameras.EASE, "entry": e})
			last = maxf(last, sp.y)
	# ...a long way to go takes longer: no cut is quicker at its quickest than Cameras.SPEED (a smoothstep's peak is 1.5 of its mean)
	# ...measured from the shot in force before it (a seat's, a march's) or the table's head; and a throw's dice from far off are gone
	# only part of the way to (DICE_TRAVEL), as a head turns to look rather than a body walking over
	var over := _overhead()
	for c in _claims:
		var d: Dictionary = c
		if not (String(d["sort"]) in ["dice", "seat", "drift"]):
			continue
		var t0 := float(d["t0"])
		var from: Vector3 = over["eye"]
		for o in _claims:
			if o != c and String((o as Dictionary)["sort"]) in ["seat", "march"] and float((o as Dictionary)["t0"]) < t0 and t0 < float((o as Dictionary)["t1"]):
				from = _claim_shot(o, t0)["eye"]
		var full := from.distance_to(_claim_shot(d, t0)["eye"] as Vector3)
		# ...a dice camera that arrives all the way is a cut in: there in its own time however far, the one move quicker than SPEED
		if String(d["sort"]) == "dice" and float(d.get("weight", 1.0)) >= 1.0:
			continue
		if String(d["sort"]) == "dice" and full > 0.001:
			d["weight"] = minf(float(d.get("weight", 1.0)), DICE_TRAVEL / full)
		d["ease"] = maxf(float(d.get("ease", Cameras.EASE)), full * float(d.get("weight", 1.0)) * 1.5 / Cameras.SPEED)
	# ...the lowest in the list laid first, so the one above it takes what both want
	_claims.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["rank"]) > int(y["rank"]) or (int(x["rank"]) == int(y["rank"]) and float(x["t0"]) < float(y["t0"])))
	# ...and over them all, the opening: the table from its head, pushed slowly in from the intro's start and settled, until it has been
	# seen ([method opening_end]); what any other camera wanted by then it takes from there
	_push = _opening_push()
	_claims.append({"sort": "opening", "rank": -1, "t0": -INF, "t1": opening_end(), "entry": {}, "ease": Cameras.EASE})


## Where the camera is at [param t]: [param base] - the table from its head - with each camera's moments laid over it.
func shot_at(t: float, base: Transform3D) -> Transform3D:
	_cam = base
	return Cameras.transform_of(_shot(t))


## The lens at [param t] (degrees, up the frame).
func fov_at(t: float) -> float:
	return float(_shot(t)["fov"])


func _eye(t: float) -> Transform3D:
	return Cameras.transform_of(_shot(t))


func _shot(t: float) -> Dictionary:
	if t == _shot_t:
		return _shot_cache
	var mid := Vector3(GameBoard.MIDDLE.x, 0.0, GameBoard.MIDDLE.y)
	var out := _overhead()
	for c in _claims:
		var d: Dictionary = c
		var ease := float(d.get("ease", Cameras.EASE))
		var w := Hands.smooth(clampf((t - float(d["t0"])) / ease, 0.0, 1.0)) * (1.0 - Hands.smooth(clampf((t - float(d["t1"])) / ease, 0.0, 1.0))) * float(d.get("weight", 1.0))
		if w <= 0.0:
			continue
		out = Cameras.blend(out, _claim_shot(d, t), w, mid)
	out = _kept_top(out)
	_shot_t = t
	_shot_cache = out
	return out


## [param s] as a frame taller than the dressed one sees it (a portrait one, [method CardTable.lens]): turned down until its top edge is
## where a landscape frame's is, so what it gains in height is the board and the table in front - never more of the dark room past
## the model, which is built to be seen from the table's head alone. What the shot looks at sits higher in it, a third of the way down.
func _kept_top(s: Dictionary) -> Dictionary:
	var fov := float(s["fov"])
	var drop := atan(_lens(fov).y) - atan(CardTable.lens(fov).y)
	var eye: Vector3 = s["eye"]
	var ahead: Vector3 = (s["at"] as Vector3) - eye
	var right := ahead.cross(Vector3.UP)
	if drop < 1e-4 or right.length() < 1e-4 * ahead.length():
		return s
	var out := s.duplicate()
	out["at"] = eye + ahead.rotated(right.normalized(), -drop)
	return out


## The table from its head, as the format stands it.
func _overhead() -> Dictionary:
	var fwd := -_cam.basis.z
	var reach := -_cam.origin.y / fwd.y if fwd.y < -0.01 else 1.0
	return {"eye": _cam.origin, "at": _cam.origin + fwd * reach, "fov": _fov, "mini": HEAD_MINIATURE}


func _claim_shot(c: Dictionary, t: float) -> Dictionary:
	if String(c["sort"]) == "opening":
		return _opening_shot(t)
	var out := _claim_frame(c, t)
	out["mini"] = Cameras.value(c["entry"], "miniature")
	return out


## When the opening is over: [constant OPENING_SEES] after the show opens, INF until its opening is placed (-INF for a show with
## none). No page shows before it.
func opening_end() -> float:
	return _opened + OPENING_SEES if is_finite(_opened) else _opened


## The table from its head at [param t] of the opening: pushed in toward what it looks at, from the intro's start until
## [constant OPENING_STILL] before the opening ends, eased, and still from there.
func _opening_shot(t: float) -> Dictionary:
	var out := _overhead()
	var end := opening_end() - OPENING_STILL
	if not is_finite(end) or end <= 0.0:
		return out
	var u := Hands.smooth(clampf(t / end, 0.0, 1.0))
	out["eye"] = (out["eye"] as Vector3).lerp(out["at"] as Vector3, _push * u)
	return out


## How far in the opening pushes: [constant OPENING_PUSH], or as far as it takes (at most [constant OPENING_PUSH_MOST]) for the bottom of
## the frame, as it is shown ([method _kept_top]), to fall on the board's near edge with [constant OPENING_MARGIN] of table before it.
func _opening_push() -> float:
	if work == null or work.medium == null:
		return OPENING_PUSH
	var map: Dictionary = game.get("board", {}) if game.get("board") is Dictionary else {}
	var board := GameBoard.rect_of(map) if not map.is_empty() else Rect2(GameBoard.MIDDLE - GameBoard.MAP_MOST * 0.5, GameBoard.MAP_MOST)
	var near := board.end.y + OPENING_MARGIN
	var lo := OPENING_PUSH
	var hi := OPENING_PUSH_MOST
	if _bottom_z(lo) <= near:
		return lo
	if _bottom_z(hi) > near:
		return hi
	for i in 18:
		var mid := (lo + hi) * 0.5
		if _bottom_z(mid) <= near:
			hi = mid
		else:
			lo = mid
	return hi


## Where on the table the bottom of the frame falls (its distance toward the head, meters) with the head's camera pushed [param u] of
## the way in: INF where it never reaches the table.
func _bottom_z(u: float) -> float:
	var s := _overhead()
	s["eye"] = (s["eye"] as Vector3).lerp(s["at"] as Vector3, u)
	s = _kept_top(s)
	var xf := Cameras.transform_of(s)
	var lens := _lens(float(s["fov"]))
	var d := xf.basis * Vector3(0.0, -lens.y, -1.0)
	if d.y >= -1e-4:
		return INF
	return (xf.origin + d * (-xf.origin.y / d.y)).z


func _claim_frame(c: Dictionary, t: float) -> Dictionary:
	var e: Dictionary = c["entry"]
	match String(c["sort"]):
		"dice":
			var at: Vector3 = c["at"]
			var seat := GameBoard.at_seat(float((game.get("seats", {}) as Dictionary).get(String(c["who"]), 180.0)), GameBoard.HAND)
			var toward := Vector3(seat.x - at.x, 0.0, seat.y - at.y).normalized()
			var far := Cameras.value(e, "far") * 0.01
			# ...from its angle as they land, rising to its other while it holds on them, so what landed reads
			var held := maxf(float(c.get("t1", 0.0)) - float(c.get("stop", 0.0)), 0.1)
			var up := deg_to_rad(lerpf(Cameras.value(e, "rise"), Cameras.value(e, "top"), Hands.smooth(clampf((t - float(c.get("stop", t))) / held, 0.0, 1.0))))
			var lens := Cameras.value(e, "lens")
			return {"eye": at + (toward * cos(up) + Vector3.UP * sin(up)) * far, "at": at, "fov": lens if lens > 0.0 else _fov}
		"seat":
			var a := float((game.get("seats", {}) as Dictionary).get(String(c["who"]), 0.0))
			var reach := Vector2.ONE * (0.1 + Cameras.value(e, "back") * 0.01)
			var p := GameBoard.at_seat(a + 7.0, GameBoard.MAP_MOST * 0.5 + reach)
			var look := GameBoard.at_seat(a, GameBoard.MAP_MOST * 0.12)
			return _below_horizon({"eye": Vector3(p.x, Cameras.value(e, "height") * 0.01, p.y), "at": Vector3(look.x, 0.04, look.y), "fov": Cameras.value(e, "lens")})
		"march":
			var sum := Vector3.ZERO
			var n := 0
			for nm in c["names"]:
				var life := _life_at(String(nm), t)
				if not life.is_empty():
					sum += _pose(life, t)["at"] as Vector3
					n += 1
			var from: Vector2 = c["from"]
			var to: Vector2 = c["to"]
			var here := sum / float(n) if n > 0 else Vector3(from.x, _ground(from), from.y)
			var dir := Vector3(to.x - from.x, 0.0, to.y - from.y)
			dir = dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD
			var right := dir.cross(Vector3.UP)
			var side := Cameras.value(e, "side")
			# ...round from behind them to square beside (as it always stood), and past it toward ahead of them, looking back as they come
			var round := atan2(absf(side), 1.0 - absf(side)) if absf(side) <= 1.0 else PI * 0.5 * absf(side)
			var off := (-dir * cos(round) + right * signf(side) * sin(round)) * Cameras.value(e, "back") * 0.01
			var eye2 := Vector2(here.x + off.x, here.z + off.z)
			var eye := Vector3(eye2.x, maxf(_ground(eye2), here.y) + Cameras.value(e, "low") * 0.01, eye2.y)
			# ...looking a little ahead of them, as far as the frame is wide: a portrait one keeps them where a landscape one has them
			var lead := MARCH_LEAD * _lens(1.0).x / CardTable.lens(1.0).x
			return {"eye": eye, "at": here + dir * lead + Vector3.UP * 0.015, "fov": Cameras.value(e, "lens")}
		"drift":
			var ang := deg_to_rad(180.0 + (t - float(c["t0"])) * Cameras.value(e, "speed"))
			var mid := Vector3(GameBoard.MIDDLE.x, 0.0, GameBoard.MIDDLE.y)
			var r := Cameras.value(e, "reach") * 0.01
			return _below_horizon({"eye": mid + Vector3(sin(ang) * r, Cameras.value(e, "height") * 0.01, cos(ang) * r * 0.75), "at": mid + Vector3(0.0, 0.03, 0.0), "fov": Cameras.value(e, "lens")})
	return _overhead()


## [param shot] looking down far enough that the top of its frame is under the horizon: no shot round the table shows the room
## past its far edge, which is only ever built to be seen from the table's head. The top of a landscape frame's: a taller one keeps
## it there ([method _kept_top]).
static func _below_horizon(shot: Dictionary) -> Dictionary:
	var eye: Vector3 = shot["eye"]
	var at: Vector3 = shot["at"]
	var need := deg_to_rad(float(shot["fov"]) * 0.5 + BELOW_HORIZON)
	var flat := Vector2(at.x - eye.x, at.z - eye.z)
	var drop := eye.y - at.y
	if drop <= 0.0 or flat.length() < 0.001:
		return shot
	if atan2(drop, flat.length()) >= need:
		return shot
	var near := drop / tan(need)
	var p := Vector2(eye.x, eye.z) + flat.normalized() * near
	return {"eye": eye, "at": Vector3(p.x, at.y, p.y), "fov": shot["fov"]}


## The life of figure [param name] on the table at [param t], or {}.
func _life_at(name: String, t: float) -> Dictionary:
	for f in _figures:
		var life: Dictionary = f
		if String(life["name"]) == name and _when(int(life["placed"])) <= t and t < _ended(life):
			return life
	return {}


# --- the miniature -----------------------------------------------------------------------------------------------------------------------------

## The sheet that makes the table a tilt-shift photograph ([constant TILT_SHADER]): in front of the lens, under the pages.
func _stand_tilt() -> void:
	var quad := QuadMesh.new()
	_tilt = MeshInstance3D.new()
	_tilt.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = TILT_SHADER
	mat.render_priority = 50
	_tilt.material_override = mat
	_tilt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tilt.visible = false
	root.add_child(_tilt)


## The band in focus where the camera looks at [param t], as narrow as its `miniature` says; none at 0.
func _tick_tilt(t: float) -> void:
	if _tilt == null:
		return
	var s := _shot(t)
	var m := clampf(float(s.get("mini", 0.0)), 0.0, 1.0)
	_tilt.visible = m > 0.02
	if not _tilt.visible:
		return
	var eye := Cameras.transform_of(s)
	var lens := _lens(float(s["fov"]))
	var frame := lens * 2.0 * MINI_FAR * 1.05
	(_tilt.mesh as QuadMesh).size = Vector2(frame.x * 1.3, frame.y)
	_tilt.transform = eye * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -MINI_FAR))
	# ...where it looks, up the frame: the band's middle
	var v := eye.affine_inverse() * (s["at"] as Vector3)
	var up := 0.5 + 0.5 * (v.y / maxf(-v.z, 0.001)) / lens.y
	var mat := _tilt.material_override as ShaderMaterial
	mat.set_shader_parameter("focus", clampf(up, 0.1, 0.9))
	mat.set_shader_parameter("band", lerpf(MINI_BAND.x, MINI_BAND.y, m))
	mat.set_shader_parameter("strength", m)


# --- the night's book -----------------------------------------------------------------------------------------------------------------------------

## Every page of the night's book that is painted: a sheet in front of the lens, filling the frame, its picture lit as it is. A unit
## square, stretched as it plays to cover the frame the show is in ([method _page_size]).
func _stand_pages() -> void:
	var list: Array = game.get("pages", [])
	if StickerBook.composed(game):
		_stand_book()
		return
	for e in game.get("events", []):
		var d: Dictionary = e
		if String(d.get("kind", "")) != "picture":
			continue
		var pic := int(d.get("pic", 0))
		var tex := _picture("page_%d.png" % pic) if pic >= 1 and pic <= list.size() else null
		if tex == null:
			continue
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		var node := MeshInstance3D.new()
		node.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		mat.render_priority = 100
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# ...a later page always over an earlier one as it fades in: pages hang at one depth, and the sort would flip between them
		node.sorting_offset = float(pic) * 0.01
		node.visible = false
		root.add_child(node)
		_pages.append({"node": node, "mat": mat, "event": int(d["id"]), "pic": pic, "aspect": float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)})


## The night's book as a sticker book ([StickerBook]): built here on the worker, its picture one sheet in front of the lens, as a page
## is; each page an entry by its event, drawn by the book.
func _stand_book() -> void:
	_book = StickerBook.new(game, dir, work.medium.aspect() if work != null and work.medium != null else 16.0 / 9.0)
	_book.build()
	root.add_child(_book.viewport)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_sheet = MeshInstance3D.new()
	_sheet.mesh = quad
	_sheet_mat = StandardMaterial3D.new()
	_sheet_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sheet_mat.albedo_texture = _book.viewport.get_texture()
	_sheet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sheet_mat.no_depth_test = true
	_sheet_mat.render_priority = 100
	_sheet_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sheet.material_override = _sheet_mat
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheet.visible = false
	root.add_child(_sheet)
	for e in game.get("events", []):
		var d: Dictionary = e
		if String(d.get("kind", "")) == "picture" and int(d.get("pic", 0)) >= 1:
			_pages.append({"event": int(d["id"]), "pic": int(d["pic"]), "composed": true})


## When page [param p] comes up: its event's moment, held until the opening is over ([method opening_end]); INF until placed.
func _page_at(p: Dictionary) -> float:
	var at := _when(int(p["event"]))
	return at if at == INF else maxf(at, opening_end() if is_finite(opening_end()) else at)


## How big a page whose picture is [param aspect] wide for its height stands, [constant PAGE_FAR] out, to cover the frame at the
## table's own lens, whatever the frame's shape - a landscape page in a portrait frame shows its middle; a wider lens is laid over it
## as it plays.
func _page_size(aspect: float) -> Vector2:
	var frame := _lens(_fov) * 2.0 * PAGE_FAR
	return Vector2(maxf(frame.x, frame.y * aspect), maxf(frame.y, frame.x / maxf(aspect, 0.01)))


## What the camera sees at a distance of one with [param fov], in the frame the show is in ([method TableMedium.lens]).
func _lens(fov: float) -> Vector2:
	return CardTable.lens(fov, work.medium.aspect())


## When a page goes: at the next page, or once it has had its least, where the view goes back to the table - a `board`, a throw (every
## one unless told not to be) or a walk watched (`watch`). Otherwise it stays: the story is told over its pages.
func _page_end(at: float, id := -1) -> float:
	var going := INF
	var held := opening_end()
	for e in game.get("events", []):
		var d: Dictionary = e
		var k := String(d.get("kind", ""))
		if not _times.has(int(d["id"])):
			continue
		var when := float(_times[int(d["id"])])
		# ...a page placed before the opening is over comes up as it ends, and the latest of those is the one that does
		if k == "picture" and is_finite(held):
			when = maxf(when, held)
		if k == "picture" and when == at and int(d["id"]) > id and id >= 0:
			going = minf(going, when)
			continue
		if when <= at:
			continue
		if k == "picture":
			going = minf(going, when)
		elif k == "board" or (k in ["roll", "move"] and _watched(d)):
			going = minf(going, maxf(when, at + PAGE_LEAST))
	return going


## Whether the view comes back to the table for [param e]: as the game master said, or - unsaid - every throw but one behind the screen:
## the dice landing are the game, and the show cuts to them.
static func _watched(e: Dictionary) -> bool:
	if e.has("watch"):
		return bool(e["watch"])
	return String(e.get("kind", "")) == "roll" and not bool(e.get("hidden", false))


func _tick_pages(t: float) -> void:
	if _book != null:
		_tick_book(t)
		return
	for p in _pages:
		var d: Dictionary = p
		var node: MeshInstance3D = d["node"]
		var at := _page_at(d)
		if t < at or at == INF:
			node.visible = false
			continue
		var going := float(d.get("_going", NAN))
		if is_nan(going) or float(d.get("_at", NAN)) != at:
			going = _page_end(at, int(d["event"]))
			d["_going"] = going
			d["_at"] = at
		# ...a page whose next comes up the moment it does never shows (several placed before the opening was over)
		if t >= going + PAGE_FADE or going <= at:
			node.visible = false
			continue
		node.visible = true
		var show := Hands.smooth(clampf((t - at) / PAGE_FADE, 0.0, 1.0)) * (1.0 - Hands.smooth(clampf((t - going) / PAGE_FADE, 0.0, 1.0)))
		(d["mat"] as StandardMaterial3D).albedo_color = Color(1, 1, 1, show)
		# ...pushed in slowly as it is looked at, toward a point of its own
		# ...over its own time where its end is placed already, else over a long hold's
		var u := clampf((t - at) / maxf(minf(going, at + PAGE_HOLD) + PAGE_FADE - at, 0.1), 0.0, 1.0)
		var push := 1.0 + PAGE_PUSH * u
		# ...drifting sideways only, and what is cut off the frame's height (a picture wider than tall, pushed in) cut from its
		# bottom, nearly all of it: heads and faces are in a picture's upper part
		var drift := sin(float(d["pic"]) * 2.3) * 0.012 * u
		var lens := fov_at(t)
		var k := tan(deg_to_rad(lens * 0.5)) / tan(deg_to_rad(_fov * 0.5))
		var size := _page_size(float(d["aspect"]))
		var frame_h := _lens(_fov).y * 2.0 * PAGE_FAR
		var over := maxf((size.y * push - frame_h) * 0.5, 0.0)
		node.transform = _eye(t) * Transform3D(Basis.from_scale(Vector3(size.x, size.y, 1.0) * push * k), Vector3(drift * PAGE_FAR, -over * PAGE_TOP * k, -PAGE_FAR))


## The sticker book at [param t]: the page up now (or the last, fading as the view goes back to the table), drawn by the book from the
## page before it where they come back to back, and its sheet faded in from the table and out again as a page is.
func _tick_book(t: float) -> void:
	var shown: Array = []
	for p in _pages:
		var d: Dictionary = p
		var at := _page_at(d)
		if at == INF:
			continue
		var going := float(d.get("_going", NAN))
		if is_nan(going) or float(d.get("_at", NAN)) != at:
			going = _page_end(at, int(d["event"]))
			d["_going"] = going
			d["_at"] = at
		if going > at:
			shown.append({"i": int(d["pic"]) - 1, "at": at, "going": going})
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	var cur := -1
	for j in shown.size():
		var d: Dictionary = shown[j]
		if float(d["at"]) <= t and t < float(d["going"]) + PAGE_FADE:
			cur = j
	if cur < 0:
		_sheet.visible = false
		_book.show(false)
		return
	var now: Dictionary = shown[cur]
	var before: Dictionary = shown[cur - 1] if cur > 0 else {}
	var back_to_back := not before.is_empty() and absf(float(before["going"]) - float(now["at"])) < 0.05
	var show := 1.0 if back_to_back else Hands.smooth(clampf((t - float(now["at"])) / PAGE_FADE, 0.0, 1.0))
	show *= 1.0 - Hands.smooth(clampf((t - float(now["going"])) / PAGE_FADE, 0.0, 1.0))
	_book.show(true)
	_book.pose_at(t, int(now["i"]), float(now["at"]), int(before["i"]) if back_to_back else -1, float(before.get("at", 0.0)))
	_sheet.visible = true
	_sheet_mat.albedo_color = Color(1, 1, 1, show)
	var k := tan(deg_to_rad(fov_at(t) * 0.5)) / tan(deg_to_rad(_fov * 0.5))
	var frame := _lens(_fov) * 2.0 * PAGE_FAR
	_sheet.transform = _eye(t) * Transform3D(Basis.from_scale(Vector3(frame.x, frame.y, 1.0) * k), Vector3(0.0, 0.0, -PAGE_FAR))


# --- heard ------------------------------------------------------------------------------------------------------------------------------------------

## Every hit between two moments of the show, as [WorkSounds] rings them: real ones where the record has them, and a few quick soft knocks of dice shaken in a hand.
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
		# ...The shake, while it is in hand
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
	return "game: %d maps, %d figures, %d pictures, %d %spages, %d throws, %d camera moments%s; record %s" % [_maps.size(), _figures.size(), _reveals.size(), _pages.size(),
		"sticker " if _book != null else "", _rolls.size(),
		_claims.size(), ", a model's board" if _diorama != null else "", "ready" if not _record.is_empty() else ("failed" if _failed else "not yet")]
