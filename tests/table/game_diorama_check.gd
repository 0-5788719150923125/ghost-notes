extends SceneTree

## game_diorama_check - the model's board a game is played on ([GameDiorama]). No renderer. It holds:
##
## - a spec made safe: a hill past its height is brought down, a river's short path dropped, lists bounded, a place's thing a
##   prop's keeping its own generic name (control: one named nothing takes the place's), two places of one name kept once;
## - written to its file and read back it is the same spec, a lathe still a lathe (a thing made safe does not survive JSON, so it is
##   kept as written and made safe only where it is built);
## - the board as a map: a centimeter is a centimeter on the table ([method GameBoard.cell_of]), and a place's name, in any case
##   and with or without "the", is where it stands (control: a name no place has is nowhere);
## - the ground: a hill stands up, a river is cut below the flat board and is water there, and off the board is the table;
## - built, it has its ground, its water, its woods and its places, each place standing on its own ground, the ground flat under it;
## - its solid for the dice is a closed box of the board's size;
## - its plan from above is the board's shape, and a place is drawn on it (control: where no place is, nothing red is).
##
##   godot --headless --path . --script tests/table/game_diorama_check.gd

var _fails := 0
var _checks := 0

const SPEC := {
	"name": "the valley",
	"hills": [{"at": [100, 20], "radius": 18, "height": 99}],
	"rivers": [{"path": [[0, 60], [65, 50], [130, 62]], "width": 6, "depth": 1.4}, {"path": [[3, 3]]}],
	"roads": [{"path": [[20, 80], [60, 40]], "width": 2}],
	"woods": [{"at": [30, 20], "radius": 10, "trees": 20, "sort": "pine"}],
	"places": [
		{"name": "The Mill", "at": [40, 30], "turn": 30, "thing": {"name": "a timber watermill", "parts": [{"shape": "box", "size": [8, 6, 6], "material": "wood"}]}},
		{"name": "the mill", "at": [10, 10], "thing": {"parts": [{"shape": "box", "size": [2, 2, 2], "material": "wood"}]}},
		{"name": "The Keep", "at": [100, 20], "thing": {"parts": [{"shape": "lathe", "profile": [[0, 0], [5, 0], [5, 20], [0, 20]], "material": "stone"}]}},
	],
	"materials": {"wood": {"color": "#8a6a3a"}, "stone": {"color": "#8a8a80"}},
}


func _init() -> void:
	var d := GameDiorama.sanitize(SPEC)
	_ok(is_equal_approx(float(d["hills"][0]["height"]), GameDiorama.HILL_MOST), "a hill past its height is brought down")
	_ok((d["rivers"] as Array).size() == 1, "a river with one point is dropped")
	_ok((d["places"] as Array).size() == 2, "two places of one name are kept once")
	_ok((d["places"][0] as Dictionary).get("thing") is Dictionary and not ((d["places"][0]["thing"] as Dictionary).get("parts", []) as Array).is_empty(), "a place's thing is a prop's")
	_ok(String(d["places"][0]["thing"]["name"]) == "a timber watermill", "a place's model keeps its own generic name, the game's name the place's")
	_ok(String(d["places"][1]["thing"]["name"]) == "The Keep", "control: a model named nothing takes the place's name")
	var again := GameDiorama.sanitize(JSON.parse_string(JSON.stringify(d)))
	var shapes := func(spec: Dictionary) -> Array:
		var out: Array = []
		for p in spec["places"]:
			for q in ((p as Dictionary).get("thing", {}) as Dictionary).get("parts", []):
				out.append(String((q as Dictionary)["shape"]))
		return out
	_ok(shapes.call(again) == shapes.call(d) and shapes.call(d) == ["box", "lathe"], "a spec written to its file and read back keeps every part of every thing (%s)" % str(shapes.call(again)))
	var keep_raw: Dictionary = d["places"][1]["thing"]
	_ok(String(((keep_raw["parts"] as Array)[0] as Dictionary)["shape"]) == "lathe" and ((keep_raw["parts"] as Array)[0] as Dictionary)["profile"] is Array,
		"a lathe stays a lathe, its profile as written")
	var board := GameDiorama.board_of(d)
	_ok(is_equal_approx(GameBoard.cell_of(board), 0.01) and bool(board["model"]) and not bool(board["grid"]), "on the board a centimeter is a centimeter")
	_ok(GameDiorama.place_at(d, "mill") == [40.0, 30.0] and GameDiorama.place_at(d, "THE KEEP") == [100.0, 20.0], "a place's name is where it stands, in any case, with or without its article")
	_ok(GameDiorama.place_at(d, "the moon").is_empty(), "control: a name no place has is nowhere")
	_ok(GameDiorama.told(d).contains("The Mill at [40, 30]"), "the one running the game is told each place")

	var g := GameDiorama.new(SPEC, 7)
	var root := g.build()
	var hill := GameDiorama.world_of(Vector2(100, 26))
	var flat := GameDiorama.world_of(Vector2(70, 75))
	var river := GameDiorama.world_of(Vector2(65, 50))
	var hh := g.height_at(hill.x, hill.y)
	var fh := g.height_at(flat.x, flat.y)
	var rh := g.height_at(river.x, river.y)
	_ok(hh > fh + 0.03, "a hill stands up (%.3f over %.3f)" % [hh, fh])
	_ok(absf(rh - (GameDiorama.BOARD_H - GameDiorama.WATER_DOWN) * 0.01) < 0.0005, "a river is cut below the flat board and is water there (%.4f)" % rh)
	_ok(g.height_at(5.0, 5.0) == 0.0, "off the board is the table")
	var names := []
	for c in root.get_children():
		names.append(String(c.name))
	_ok(names.has("Ground") and names.has("Water") and names.has("Woods"), "built, it has its ground, its water and its woods (%s)" % ", ".join(names))
	_ok(g.places.size() == 2, "and its places")
	var keep: Node3D = (g.places["The Keep"] as Dictionary)["node"]
	var ground_at_keep := g.height_at(keep.position.x, keep.position.z)
	_ok(absf(keep.position.y - ground_at_keep) < 0.002, "a place stands on its own ground (%.4f, %.4f)" % [keep.position.y, ground_at_keep])
	var beside := g.height_at(keep.position.x + 0.03, keep.position.z)
	_ok(absf(beside - ground_at_keep) < 0.004, "the ground is flat under a place (%.4f, %.4f)" % [beside, ground_at_keep])
	var faces: PackedVector3Array = GameDiorama.solid()["faces"]
	var box := AABB(faces[0], Vector3.ZERO)
	for v in faces:
		box = box.expand(v)
	_ok(faces.size() == 30 and box.size.is_equal_approx(Vector3(GameDiorama.SIZE.x * 0.01, GameDiorama.BOARD_H * 0.01, GameDiorama.SIZE.y * 0.01)), "its solid is a box of the board's size")
	var img := GameDiorama.new(SPEC, 7).plan_image(260)
	_ok(img.get_width() == 260 and img.get_height() == int(260.0 * GameDiorama.SIZE.y / GameDiorama.SIZE.x), "its plan is the board's shape")
	var px := Vector2(41, 31) * (260.0 / GameDiorama.SIZE.x)
	var c := img.get_pixel(int(px.x), int(px.y))
	_ok(c.r > 0.6 and c.g < 0.35, "a place is drawn on its plan")
	var empty := img.get_pixel(int(70 * 2.0), int(75 * 2.0))
	_ok(not (empty.r > 0.6 and empty.g < 0.35), "control: where no place is, nothing red is")
	root.free()

	print("game_diorama_check: %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL: " + what)
