extends RefCounted
class_name StickerLibrary

## StickerLibrary - what a sticker book draws ([StickerBook], next/sticker_book.md), kept in the library ([Library]) to be drawn the
## same on any later night: a CHARACTER (or a thing, a character of one drawing) on the `cast` shelf, a folder by its name holding its
## model (`model.png`, cut; `model_painted.png`, as painted on its ground, what its poses are painted beside), every pose kept with it
## (`<pose>.png`) and `about.json` ({name, looks, height, thing}); a SET on the `sets` shelf the cartoon's sets hang on
## ([constant PuppetRig.SETS]: `NAME.png`, its words in `NAME.json`).
##
## A sticker step finds what was kept before it paints ([method find], [method find_pose]): the same name, and the same looks or none
## said now; a pose only of a character kept with the very model this night drew it from.

const CAST := "cast"
const ABOUT := "about.json"
const MODEL := "model.png"
const MODEL_PAINTED := "model_painted.png"

static var _shas := {}           # a file -> [modified, size, sha256]: a card asks whether a drawing is kept several times a second


## The folder character [param name] is kept in on the `cast` shelf, its name in any case ("" for a name that makes no folder).
static func folder_of(name: String) -> String:
	var safe := name.strip_edges().validate_filename()
	if safe.is_empty():
		return ""
	var root := Library.shelf(CAST)
	if not DirAccess.dir_exists_absolute(root.path_join(safe)) and DirAccess.dir_exists_absolute(root):
		for d in DirAccess.get_directories_at(root):
			if String(d).to_lower() == safe.to_lower():
				return root.path_join(String(d))
	return root.path_join(safe)


## Where set [param name] is kept on the `sets` shelf, its name in any case.
static func set_path(name: String) -> String:
	var safe := name.strip_edges().validate_filename()
	if safe.is_empty():
		return ""
	var root := Library.shelf(PuppetRig.SETS)
	if not FileAccess.file_exists(root.path_join(safe + ".png")) and DirAccess.dir_exists_absolute(root):
		for f in DirAccess.get_files_at(root):
			if String(f).to_lower() == (safe + ".png").to_lower():
				return root.path_join(String(f))
	return root.path_join(safe + ".png")


## A pose's file name in a character's folder: its key, made a name ([method StickerPoses.key_of]).
static func pose_file(pose: String) -> String:
	return pose.replace("own:", "own_").replace(" ", "_").validate_filename() + ".png"


## What character [param name] keeps (its `about.json`), {} where it is not kept.
static func about(name: String) -> Dictionary:
	var f := folder_of(name)
	if f.is_empty() or not FileAccess.file_exists(f.path_join(ABOUT)):
		return {}
	var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(f.path_join(ABOUT)))
	return got if got is Dictionary else {}


## What set [param name] keeps ({name, looks}), {} where it is not kept.
static func set_about(name: String) -> Dictionary:
	var p := set_path(name)
	if p.is_empty() or not FileAccess.file_exists(p):
		return {}
	var side := p.get_basename() + ".json"
	var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(side)) if FileAccess.file_exists(side) else null
	return got if got is Dictionary else {"name": name, "looks": ""}


## Whether what was drawn before with the words [param had] is what is wanted now with [param wanted]: the same words, or none wanted (a
## name said alone is the one drawn before).
static func same_looks(had: String, wanted: String) -> bool:
	return wanted.strip_edges().is_empty() or had.strip_edges() == wanted.strip_edges()


## The kept [param kind] ("set", "model" for a character, "thing") named [param name] whose looks are [param looks]: {file, painted, by}
## to copy in, {} for none.
static func find(kind: String, name: String, looks: String) -> Dictionary:
	if kind == "set":
		var s := set_about(name)
		if s.is_empty() or not same_looks(String(s.get("looks", "")), looks):
			return {}
		return {"file": set_path(name), "painted": "", "by": "library"}
	var a := about(name)
	if a.is_empty() or bool(a.get("thing", false)) != (kind == "thing") or not same_looks(String(a.get("looks", "")), looks):
		return {}
	var f := folder_of(name)
	if not FileAccess.file_exists(f.path_join(MODEL)):
		return {}
	return {"file": f.path_join(MODEL), "painted": f.path_join(MODEL_PAINTED), "by": "library"}


## Pose [param pose] of character [param name], kept with the very model whose digest is [param model]: {file, painted, by}, {} for none.
static func find_pose(name: String, pose: String, model: String) -> Dictionary:
	var f := folder_of(name)
	if f.is_empty() or not FileAccess.file_exists(f.path_join(MODEL)) or sha(f.path_join(MODEL)) != model:
		return {}
	var p := f.path_join(pose_file(pose))
	return {"file": p, "painted": "", "by": "library"} if FileAccess.file_exists(p) else {}


## Character (or thing, [param thing]) [param name] kept: its words, its model ([param model], cut; [param painted], as painted) and
## [param poses] (pose key -> its cut file). A character kept before is kept again whole, its poses joined to those it had where its
## model is the same. "" done, else why not.
static func keep_character(name: String, looks: String, height: float, model: String, painted: String, poses: Dictionary, thing := false) -> String:
	if not Library.writable():
		return "this session cannot write the library (read-only)"
	var f := folder_of(name)
	if f.is_empty() or not FileAccess.file_exists(model):
		return "there is no drawing of %s to keep" % name
	DirAccess.make_dir_recursive_absolute(f)
	var same := FileAccess.file_exists(f.path_join(MODEL)) and sha(f.path_join(MODEL)) == sha(model)
	if not same:
		for old in DirAccess.get_files_at(f):
			if String(old).ends_with(".png"):
				DirAccess.remove_absolute(f.path_join(String(old)))
		if DirAccess.copy_absolute(model, f.path_join(MODEL)) != OK:
			return "could not copy the model of %s into the library" % name
		if FileAccess.file_exists(painted):
			DirAccess.copy_absolute(painted, f.path_join(MODEL_PAINTED))
	for k in poses:
		if FileAccess.file_exists(String(poses[k])):
			DirAccess.copy_absolute(String(poses[k]), f.path_join(pose_file(String(k))))
	var file := FileAccess.open(f.path_join(ABOUT), FileAccess.WRITE)
	if file == null:
		return "could not write %s's words into the library" % name
	file.store_string(JSON.stringify({"name": name, "looks": looks, "height": height, "thing": thing}, "\t"))
	file.close()
	return ""


## Set [param name] kept: its picture [param file] and its words. "" done, else why not.
static func keep_set(name: String, looks: String, file: String) -> String:
	if not Library.writable():
		return "this session cannot write the library (read-only)"
	var p := set_path(name)
	if p.is_empty() or not FileAccess.file_exists(file):
		return "there is no painting of %s to keep" % name
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	if DirAccess.copy_absolute(file, p) != OK:
		return "could not copy %s into the library" % name
	var side := FileAccess.open(p.get_basename() + ".json", FileAccess.WRITE)
	if side == null:
		return "could not write %s's words into the library" % name
	side.store_string(JSON.stringify({"name": name, "looks": looks}, "\t"))
	side.close()
	return ""


## Whether character or thing [param name] is kept with the model at [param model] (the same picture), and set [param name] with the
## picture at [param file].
static func kept_character(name: String, model: String) -> bool:
	var f := folder_of(name)
	return not f.is_empty() and FileAccess.file_exists(f.path_join(MODEL)) and FileAccess.file_exists(model) \
		and sha(f.path_join(MODEL)) == sha(model)


static func kept_set(name: String, file: String) -> bool:
	var p := set_path(name)
	return not p.is_empty() and FileAccess.file_exists(p) and FileAccess.file_exists(file) and sha(p) == sha(file)


## The file at [param path]'s SHA-256, read again only once it has been written since.
static func sha(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var mt := FileAccess.get_modified_time(path)
	var size := FileAccess.get_size(path)
	var c: Array = _shas.get(path, [])
	if c.size() == 3 and int(c[0]) == mt and int(c[1]) == size:
		return String(c[2])
	var h := FileAccess.get_sha256(path)
	_shas[path] = [mt, size, h]
	return h


## Every character and thing kept: [{name, folder, about, poses: [pose files but the model]}], by name.
static func characters() -> Array:
	var out: Array = []
	var root := Library.shelf(CAST)
	if not DirAccess.dir_exists_absolute(root):
		return out
	var names := DirAccess.get_directories_at(root)
	names.sort()
	for d in names:
		var f := root.path_join(String(d))
		if not FileAccess.file_exists(f.path_join(ABOUT)) or not FileAccess.file_exists(f.path_join(MODEL)):
			continue
		var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(f.path_join(ABOUT)))
		var poses: Array = []
		for p in DirAccess.get_files_at(f):
			if String(p).ends_with(".png") and String(p) != MODEL and String(p) != MODEL_PAINTED:
				poses.append(String(p))
		poses.sort()
		out.append({"name": String((got as Dictionary).get("name", d)) if got is Dictionary else String(d), "folder": f,
			"about": got if got is Dictionary else {}, "poses": poses})
	return out
