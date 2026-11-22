extends RefCounted
class_name PuppetRig

## PuppetRig - a drawing made a puppet (next/cartoon.md), as the stage's puppet reads it: `rig.json` and its layers' pictures from
## a folder `hosts/puppet/rig.py build` wrote. A rig is named as a storyboard names it: a folder on the library's `puppets` shelf
## ([method Library.shelf]) by its name, or a folder by its path.
##
## Read once and held ([method held]): the pictures are read and mipmapped on a worker ([method read_away]) or by whoever may wait
## ([method read_now]: a worker, a render, [method NestedShow.prepared]), each layer's mesh and bone weights packed there too
## ([member meshes]); the app's thread only makes their textures and nodes. A rig's file changed on disk is read again at its next ask.
##
## `rig.json`: `size` [w, h] of the cut, `top` and `ground` (rows of its highest pixel and of its feet), `faces` (front, left,
## right), `bones` [{name, parent, head, tail, role, side}] parents first, `layers` [{name, image, points (flat x, y), tris (flat),
## weights [[[bone index, weight], ...] per point]}] drawn in order, `cavity` {color, bone} (the mouth, painted into the body),
## `eyes` [{name, bone, center, radius [rx, ry], lid}], `mouth` {hinge, open (degrees), drop (px)}, `poses` {name: {bone: deg}}.
## A painted set may keep a GROUND LINE beside its picture (`NAME.ground.json`, [method ground_file]): {line: [[x, y], ...]} as
## shares of the picture's width and height, left to right - where its characters' feet go across it (a hill's ridge), traced by
## an agent that looked at it ([CartoonProducer]); read with the picture and held ([method ground]).
## A puppet with a model sheet ([PuppetSheet]) keeps `sheet.json` and a folder of that shape per drawing; [member drawings] holds them,
## and the puppet's own data is its front's.

const SHELF := "puppets"
const FILE := "rig.json"
## The shelf painted sets hang on ([method backdrop]).
const SETS := "sets"

static var _pictures := {}           # a set's file -> {image, stamp, texture}
static var _held := {}               # folder -> PuppetRig
static var _tasks := {}              # folder -> worker task id
static var _lock := Mutex.new()

var folder := ""
var data := {}
var stamp := 0
var images := {}                     # layer name -> Image (mipmapped)
## Each layer's mesh as a Polygon2D takes it, packed on the reading's thread: layer name -> {points (PackedVector2Array, the uv
## too), polygons [PackedInt32Array], bones [[bone index, PackedFloat32Array of its weight on each point]]}.
var meshes := {}
## Its drawings by sheet key ([PuppetSheet]), each a rig of its own read with it; a puppet of one drawing is its own front.
var drawings := {}
var _textures := {}                  # layer name -> ImageTexture, made on the app's thread
var error := ""


## The folder a rig named [param name] is in: [param name] itself where it is a path, else its folder on the `puppets` shelf.
static func folder_of(name: String) -> String:
	if name.begins_with("/") or name.begins_with("user://") or name.begins_with("res://") or name.begins_with("~"):
		var p := name if not name.begins_with("~") else OS.get_environment("HOME").path_join(name.substr(1).trim_prefix("/"))
		return ProjectSettings.globalize_path(p)
	return Library.shelf(SHELF).path_join(name)


## Every rig on the `puppets` shelf, by name.
static func names() -> PackedStringArray:
	var out := PackedStringArray()
	var root := Library.shelf(SHELF)
	for d in DirAccess.get_directories_at(root):
		if FileAccess.file_exists(root.path_join(d).path_join(FILE)):
			out.append(String(d))
	out.sort()
	return out


## The rig [param name] as held, or null while it is not read yet (its reading begun on a worker, once). Its file changed since it
## was read: read again.
static func held(name: String) -> PuppetRig:
	var f := folder_of(name)
	_lock.lock()
	var r: PuppetRig = _held.get(f)
	_lock.unlock()
	if r != null and r.stamp == _stamp_of(f):
		return r
	read_away(name)
	return null


## The rig [param name] read on a worker unless it is held or being read.
static func read_away(name: String) -> void:
	var f := folder_of(name)
	_lock.lock()
	var busy := _tasks.has(f)
	var r: PuppetRig = _held.get(f)
	_lock.unlock()
	if busy or (r != null and r.stamp == _stamp_of(f)):
		return
	var task := WorkerThreadPool.add_task(func() -> void: PuppetRig.read_now(f))
	_lock.lock()
	_tasks[f] = task
	_lock.unlock()


## The rig [param name] read here, waited for (a worker's, a render's): held after, so the app's thread finds it.
static func read_now(name: String) -> PuppetRig:
	var f := folder_of(name)
	_lock.lock()
	var r0: PuppetRig = _held.get(f)
	_lock.unlock()
	if r0 != null and r0.stamp == _stamp_of(f):
		return r0
	var r := PuppetRig.new()
	r.folder = f
	r.stamp = _stamp_of(f)
	r._read()
	_lock.lock()
	_held[f] = r
	_tasks.erase(f)
	_lock.unlock()
	return r


## Everything the storyboard [param board] (its loaded form) names that is read from disk - each puppet's rig, each painted set (a
## backdrop's, and one a `change` span turns it to) -
## read here and held, waited for (a worker's: [method NestedShow.prepared], a render's own).
static func warm(board: Dictionary) -> void:
	for key in ["sequence", "tail"]:
		for e in board.get(key, []):
			if not (e is Dictionary):
				continue
			var pictures: Array = []
			for c in (e as Dictionary).get("cast", []):
				if c is Dictionary and String((c as Dictionary).get("kind", "")) == "puppet":
					read_now(String(c.get("rig", "")))
				elif c is Dictionary and String((c as Dictionary).get("kind", "")) == "backdrop":
					pictures.append(String(c.get("picture", "")))
			var track: Variant = (e as Dictionary).get("track")
			for sp in (track as Dictionary).get("spans", []) if track is Dictionary else []:
				if sp is Dictionary and String((sp as Dictionary).get("action", "")) == "change" and (sp as Dictionary).get("args") is Dictionary:
					pictures.append(String(sp["args"].get("picture", "")))
			for picture in pictures:
				var file := set_file(String(picture))
				if file.is_empty():
					continue
				_lock.lock()
				var had: Dictionary = _pictures.get(file, {})
				_lock.unlock()
				if had.get("image") == null or int(had.get("stamp", -1)) != _set_stamp(file):
					read_backdrop(file, {"stamp": _set_stamp(file), "image": null, "texture": null})


## Whether a reading begun for [param name] is still going.
static func reading(name: String) -> bool:
	var f := folder_of(name)
	_lock.lock()
	var task := int(_tasks.get(f, -1))
	_lock.unlock()
	return task >= 0 and not WorkerThreadPool.is_task_completed(task)


## The painted set [param name] - its file on the `sets` shelf (`.png` or `.jpg` after its name), or a picture's path - as a texture;
## null while it is read on a worker (begun the first time it is asked for) or where there is none.
static func backdrop(name: String) -> Texture2D:
	var file := set_file(name)
	if file.is_empty():
		return null
	_lock.lock()
	var got: Dictionary = _pictures.get(file, {})
	_lock.unlock()
	var stamp := _set_stamp(file)
	if not got.is_empty() and int(got["stamp"]) == stamp:
		if got.get("texture") == null and got.get("image") != null:
			got["texture"] = ImageTexture.create_from_image(got["image"])
		return got.get("texture")
	if got.get("task", -1) is int and int(got.get("task", -1)) >= 0 and not WorkerThreadPool.is_task_completed(int(got["task"])):
		return null
	var entry := {"stamp": stamp, "image": null, "texture": null}
	entry["task"] = WorkerThreadPool.add_task(func() -> void: PuppetRig.read_backdrop(file, entry))
	_lock.lock()
	_pictures[file] = {"stamp": -2, "task": entry["task"]}
	_lock.unlock()
	return null


## The picture at [param file] read into [param entry] and held (a worker's, or a render's own).
static func read_backdrop(file: String, entry: Dictionary) -> void:
	var img := Image.load_from_file(file)
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
	entry["image"] = img
	entry["ground"] = read_ground(ground_file(file))
	entry.erase("task")
	_lock.lock()
	_pictures[file] = entry
	_lock.unlock()


## A set's file stamped by its picture and its ground line, so either written again is read again.
static func _set_stamp(file: String) -> int:
	var g := ground_file(file)
	return maxi(int(FileAccess.get_modified_time(file)), int(FileAccess.get_modified_time(g)) if FileAccess.file_exists(g) else 0)


## Where the ground line of the set picture [param file] is kept.
static func ground_file(file: String) -> String:
	return file.get_basename() + ".ground.json"


## The ground line at [param file] (points as shares of the picture, left to right); empty where there is none or it will not read.
static func read_ground(file: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not FileAccess.file_exists(file):
		return out
	var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	for p in (got as Dictionary).get("line", []) if got is Dictionary else []:
		if p is Array and (p as Array).size() >= 2:
			out.append(Vector2(clampf(float(p[0]), 0.0, 1.0), clampf(float(p[1]), 0.0, 1.0)))
	var pts := Array(out)
	pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return PackedVector2Array(pts) if pts.size() >= 2 else PackedVector2Array()


## The ground line of the painted set [param name] as it was read with its picture ([method backdrop]); empty while it is read, or
## where the set has none.
static func ground(name: String) -> PackedVector2Array:
	var file := set_file(name)
	if file.is_empty():
		return PackedVector2Array()
	_lock.lock()
	var got: Dictionary = _pictures.get(file, {})
	_lock.unlock()
	return got.get("ground", PackedVector2Array())


## The height of [param line] (a ground line) at [param x] (a share of the picture's width), as a share of its height; NAN for none.
static func ground_at(line: PackedVector2Array, x: float) -> float:
	if line.size() < 2:
		return NAN
	if x <= line[0].x:
		return line[0].y
	for i in range(1, line.size()):
		if x <= line[i].x:
			var a := line[i - 1]
			var b := line[i]
			return lerpf(a.y, b.y, (x - a.x) / maxf(1e-6, b.x - a.x))
	return line[line.size() - 1].y


## The file of the painted set [param name] ("" where there is none).
static func set_file(name: String) -> String:
	if name.is_empty():
		return ""
	if name.begins_with("/") or name.begins_with("user://") or name.begins_with("res://") or name.begins_with("~"):
		var f := folder_of(name)
		return f if FileAccess.file_exists(f) else ""
	for ext in ["", ".png", ".jpg", ".webp"]:
		var f := Library.shelf(SETS).path_join(name + ext)
		if FileAccess.file_exists(f):
			return f
	return ""


static func _stamp_of(f: String) -> int:
	var sheet := f.path_join(PuppetSheet.FILE)
	if FileAccess.file_exists(sheet):
		var most := int(FileAccess.get_modified_time(sheet))
		var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(sheet))
		for key in (got as Dictionary).get("drawings", []) if got is Dictionary else []:
			var r := f.path_join(String(key)).path_join(FILE)
			if FileAccess.file_exists(r):
				most = maxi(most, int(FileAccess.get_modified_time(r)))
		return most
	return int(FileAccess.get_modified_time(f.path_join(FILE))) if FileAccess.file_exists(f.path_join(FILE)) else -1


func _read() -> void:
	# a model sheet: each drawing its own rig in its own folder, the front the puppet's own data
	var sheet_path := folder.path_join(PuppetSheet.FILE)
	if FileAccess.file_exists(sheet_path):
		var sheet: Variant = JSON.parse_string(FileAccess.get_file_as_string(sheet_path))
		for key in (sheet as Dictionary).get("drawings", []) if sheet is Dictionary else []:
			var d := PuppetRig.new()
			d.folder = folder.path_join(String(key))
			d._read_one()
			if d.ok():
				drawings[String(key)] = d
		var main: PuppetRig = drawings.get("front", drawings.values()[0] if not drawings.is_empty() else null)
		if main == null:
			error = "the puppet at %s has a sheet with no drawing that reads" % folder
			return
		data = main.data
		images = main.images
		error = ""
		return
	_read_one()
	if ok():
		drawings["front"] = self


func _read_one() -> void:
	var p := folder.path_join(FILE)
	if not FileAccess.file_exists(p):
		error = "no rig at %s" % folder
		return
	var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (got is Dictionary) or (got as Dictionary).get("bones", []).is_empty():
		error = "the rig at %s is not one rig.py wrote" % folder
		return
	data = got
	for layer in data.get("layers", []):
		var file := folder.path_join(String((layer as Dictionary).get("image", "")))
		var img := Image.load_from_file(file) if FileAccess.file_exists(file) else null
		if img == null:
			error = "the rig's picture %s is missing" % file
			data = {}
			return
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		images[String(layer["name"])] = img
		meshes[String(layer["name"])] = _mesh_of(layer)


## Layer [param layer]'s points, triangles and weights packed as a Polygon2D takes them ([member meshes]). Each bone's weights are
## filled as a plain array and packed once: a packed array read out of a dictionary is a copy, and a write into it is lost.
static func _mesh_of(layer: Dictionary) -> Dictionary:
	var flat: Array = layer.get("points", [])
	var pts := PackedVector2Array()
	pts.resize(flat.size() / 2)
	for i in pts.size():
		pts[i] = Vector2(float(flat[2 * i]), float(flat[2 * i + 1]))
	var tris: Array = layer.get("tris", [])
	var polys: Array = []
	for i in range(0, tris.size() - 2, 3):
		polys.append(PackedInt32Array([int(tris[i]), int(tris[i + 1]), int(tris[i + 2])]))
	var per := {}
	var ws: Array = layer.get("weights", [])
	for vi in mini(ws.size(), pts.size()):
		for pair in ws[vi]:
			var bi := int(pair[0])
			if not per.has(bi):
				var arr: Array = []
				arr.resize(pts.size())
				arr.fill(0.0)
				per[bi] = arr
			(per[bi] as Array)[vi] = float(pair[1])
	var bones: Array = []
	for bi in per:
		bones.append([int(bi), PackedFloat32Array(per[bi])])
	return {"points": pts, "polygons": polys, "bones": bones}


## Whether it was read whole.
func ok() -> bool:
	return error.is_empty() and not data.is_empty()


## The texture of layer [param layer], made the first time it is asked for (the app's thread).
func texture(layer: String) -> Texture2D:
	if not _textures.has(layer) and images.has(layer):
		_textures[layer] = ImageTexture.create_from_image(images[layer])
	return _textures.get(layer)


## Its height in pixels of the cut: its highest pixel to its feet.
func height() -> float:
	return maxf(1.0, float(data.get("ground", 1.0)) - float(data.get("top", 0.0)))


## Where it stands, in pixels of the cut: its root's x on its feet's row.
func anchor() -> Vector2:
	var b: Array = data.get("bones", [])
	var x := float((b[0] as Dictionary)["head"][0]) if not b.is_empty() else float(data.get("size", [0, 0])[0]) * 0.5
	return Vector2(x, float(data.get("ground", 0.0)))


## The bone named [param name] ({} for none).
func bone(name: String) -> Dictionary:
	for b in data.get("bones", []):
		if String((b as Dictionary)["name"]) == name:
			return b
	return {}


## The names of its bones of role [param role] (an arm's, a leg's...), on side [param side] where it is given.
func bones_of(role: String, side := "") -> PackedStringArray:
	var out := PackedStringArray()
	for b in data.get("bones", []):
		var d: Dictionary = b
		if String(d.get("role", "")) == role and (side.is_empty() or String(d.get("side", "")) == side):
			out.append(String(d["name"]))
	return out


## The children of bone [param name], in order.
func children_of(name: String) -> PackedStringArray:
	var out := PackedStringArray()
	for b in data.get("bones", []):
		if String((b as Dictionary)["parent"]) == name:
			out.append(String((b as Dictionary)["name"]))
	return out
