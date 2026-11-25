extends ShelfSection
class_name StickerShelf

## StickerShelf - what a sticker book keeps in the library ([StickerLibrary], next/sticker_book.md) on the Dex's shelves: each kept
## character or thing by its model, each of its poses, and each kept set - so a show draws the same ones on any later night. Kept
## from a game episode's Props card ([EpisodeProps], Characters and Sets); a sticker step finds them by name before it paints.

const SHELVES := [
	{"key": "cast", "label": "Characters", "tip": "The characters and things kept from a sticker book's pages: a later night that draws one of the same name draws it this way."},
	{"key": "poses", "label": "Poses", "tip": "Every pose kept with a character, drawn from its model."},
	{"key": "sets", "label": "Sets", "tip": "The places kept from a sticker book's pages (and a cartoon's painted sets): a later night set in one of the same name uses it."},
]

var thumbs := StickerThumbs.new()
var _files := {}             # offer key -> its picture's file


func title() -> String:
	return "Characters and sets"


func shelves() -> Array:
	return SHELVES


func offers() -> Array:
	var out: Array = []
	_files.clear()
	for c in StickerLibrary.characters():
		var d: Dictionary = c
		var name := String(d["name"])
		var about: Dictionary = d["about"]
		var key := "cast:" + name
		_files[key] = String(d["folder"]).path_join(StickerLibrary.MODEL)
		out.append({"key": key, "name": name, "line": "%s%d pose%s" % ["a thing - " if bool(about.get("thing", false)) else "", (d["poses"] as Array).size(),
			"" if (d["poses"] as Array).size() == 1 else "s"], "tip": String(about.get("looks", name)), "shelf": "cast", "picture": thumbs.of(_files[key]), "verbs": []})
		for p in d["poses"]:
			var pk := "pose:%s/%s" % [name, String(p)]
			_files[pk] = String(d["folder"]).path_join(String(p))
			out.append({"key": pk, "name": "%s, %s" % [name, String(p).get_basename().replace("own_", "").replace("_", " ")], "line": name,
				"tip": String(about.get("looks", name)), "shelf": "poses", "picture": thumbs.of(_files[pk]), "verbs": []})
	var root := Library.shelf(PuppetRig.SETS)
	if DirAccess.dir_exists_absolute(root):
		var files := DirAccess.get_files_at(root)
		files.sort()
		for f in files:
			if not String(f).ends_with(".png"):
				continue
			var name := String(f).get_basename()
			var about := StickerLibrary.set_about(name)
			var key := "set:" + name
			_files[key] = root.path_join(String(f))
			out.append({"key": key, "name": String(about.get("name", name)), "line": String(about.get("looks", "")).left(80), "tip": String(about.get("looks", name)),
				"shelf": "sets", "picture": thumbs.of(_files[key]), "verbs": []})
	return out


func picture(key: String) -> Variant:
	return thumbs.of(String(_files.get(key, "")))


func want_pictures(keys: Array) -> void:
	for k in keys:
		thumbs.of(String(_files.get(String(k), "")))
