extends RefCounted
class_name Actors

## Actors - the library of actors a Likeness plays: each a folder, `user://actors/<id>/`, shared by
## every note that uses it, as [Illustrations] and [Films] are (next/likeness.md, "The library").
##
## AN ACTOR IS BUILT FROM THEIR OWN VIDEOS and is nothing but what was made from them, a file per step
## ([ActorFolder], [ActorSteps]): the videos surveyed, cut into shots, the shots grouped into sets (one
## camera placement and one look each); from every video, their range of mouth shapes and their head's
## motion; and for the set in use, its stills, its rig and its library of their mouths and eyes. The
## Actor card makes and manages one and puts them on the stage ([ActorCard], [LikenessMedium]).
##
## ITS RULES ARE THE ILLUSTRATION LIBRARY'S: nothing builds on its own (a button is the only caller,
## since the survey costs hours of CPU and the audit quota); each step's output records what it
## was made from, so a changed input marks it STALE - flagged, and still used until it is made again.
##
## THE TEST SEAM: [method use_for_test] moves the root aside, so no gate writes the author's actors.

const ROOT := "user://actors"

## Where actors live. Moved aside under test.
static var root := ROOT


## Point the library at [param dir] instead of the author's, emptied first: a gate's actors only.
static func use_for_test(dir := "user://actors_test") -> void:
	root = dir
	var abs_dir := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(abs_dir):
		_remove_tree(abs_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)


static func _remove_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	for sub in d.get_directories():
		_remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)


## Every actor in the library, by name: `[{id, name}]`.
static func list() -> Array:
	var out: Array = []
	var base := ProjectSettings.globalize_path(root)
	var d := DirAccess.open(base)
	if d == null:
		return out
	for id in d.get_directories():
		if not FileAccess.file_exists(base.path_join(id).path_join(ActorFolder.FILE)):
			continue
		var a := ActorFolder.open(id)
		if a != null:
			out.append({"id": id, "name": a.name()})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return String(x["name"]).naturalnocasecmp_to(String(y["name"])) < 0)
	return out


## A new actor called [param name]: its folder and its `actor.json`. Its id is the name made safe
## and a short stamp, so two actors of one name are two folders.
static func create(name: String) -> ActorFolder:
	var shown := name.strip_edges()
	if shown.is_empty():
		shown = "Actor"
	var slug := ""
	for c in shown.to_lower():
		slug += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "-"
	while slug.contains("--"):
		slug = slug.replace("--", "-")
	slug = slug.strip_edges().trim_prefix("-").trim_suffix("-").substr(0, 32)
	if slug.is_empty():
		slug = "actor"
	var id := "%s-%s" % [slug, ("%x" % (int(Time.get_unix_time_from_system() * 1000.0) ^ randi())).substr(0, 6)]
	var a := ActorFolder.new()
	a.id = id
	a.dir = ProjectSettings.globalize_path(root.path_join(id))
	a.data = ActorFolder.blank(shown)
	DirAccess.make_dir_recursive_absolute(a.dir)
	a.save()
	return a


## The actor [param id], or null when the library has none of that id.
static func open(id: String) -> ActorFolder:
	return ActorFolder.open(id)


static func exists(id: String) -> bool:
	return not id.is_empty() and FileAccess.file_exists(
		ProjectSettings.globalize_path(root.path_join(id)).path_join(ActorFolder.FILE))
