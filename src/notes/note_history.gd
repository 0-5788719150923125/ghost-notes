extends RefCounted
class_name NoteHistory

## NoteHistory - A NOTE'S EVERY SAVED STATE, TO GO BACK TO (the user, 2026-11-11: "change 'Copies...' to 'Restore' ... a big list of
## timestamps we could restore to ... since autosave happens on every single setting change, perhaps that list of timestamps should
## also include a note about what was changed there"). Each time a note's file is written - its autosave, after every change - its
## text is kept in a folder of the note's own (`history/` in what is made for it) with the moment and a line of what changed since the
## one before: a setting by its place in the note's blocks (`look.vignette 0.4 → 0.35`), the words by how many more or fewer.
##
## GOING BACK NEVER LOSES THE WAY FORWARD: a state put back is written as the note's file and so is kept as the newest entry - the
## state it replaced stays in the history, and "forward" is putting back a later entry. The history only grows; there are no branches
## to lose. The newest [constant KEPT] are kept.

const KEPT := 300
const INDEX := "history.json"


## THE NOTE'S TEXT [param text] KEPT in [param dir] (the newest [param kept]), the change since the one before said. "" kept, or the
## same as the newest (kept once); else why not.
static func record(dir: String, text: String, kept := KEPT) -> String:
	if dir.is_empty():
		return "the note has no folder of its own"
	var list := _index(dir)
	var before := ""
	if not list.is_empty():
		before = FileAccess.get_file_as_string(dir.path_join(String((list.back() as Dictionary)["file"])))
		if before == text:
			return ""
	DirAccess.make_dir_recursive_absolute(dir)
	var at := Time.get_unix_time_from_system()
	# ...ONE FILE EACH, though two land in one millisecond (a fast machine did: the second wrote over the first, CI 2026-11-11)
	var n := int(at * 1000.0)
	while FileAccess.file_exists(dir.path_join("%d.md" % n)):
		n += 1
	var file := "%d.md" % n
	var f := FileAccess.open(dir.path_join(file), FileAccess.WRITE)
	if f == null:
		return "could not keep the note's state in " + dir
	f.store_string(text)
	f.close()
	list.append({"at": at, "file": file, "said": summary(before, text) if not list.is_empty() else "as it was first kept"})
	while list.size() > kept:
		DirAccess.remove_absolute(dir.path_join(String((list.pop_front() as Dictionary)["file"])))
	var ix := FileAccess.open(dir.path_join(INDEX), FileAccess.WRITE)
	if ix == null:
		return "could not write the history's index"
	ix.store_string(JSON.stringify(list, "\t"))
	ix.close()
	return ""


## Every state kept in [param dir], NEWEST FIRST: `[{at (unix seconds), file, said}]`.
static func entries(dir: String) -> Array:
	var list := _index(dir)
	list.reverse()
	return list


## The text of entry [param entry] ([method entries]), "" when it is gone.
static func text_of(dir: String, entry: Dictionary) -> String:
	var p := dir.path_join(String(entry.get("file", "")))
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


## WHAT CHANGED FROM [param before] TO [param after] (two texts of one note), in a line: each setting changed by its place in the
## note's blocks, then the words; "nothing a reader sees" when only spacing changed.
static func summary(before: String, after: String) -> String:
	var a := FrontMatter.read_block(before)
	var b := FrontMatter.read_block(after)
	var changes := PackedStringArray()
	_diff(a.data if a.ok and a.data is Dictionary else {}, b.data if b.ok and b.data is Dictionary else {}, "", changes)
	var wa := _words(String(FrontMatter.split(before).body))
	var wb := _words(String(FrontMatter.split(after).body))
	if String(FrontMatter.split(before).body).strip_edges() != String(FrontMatter.split(after).body).strip_edges():
		changes.append("the words" + (", %d more" % (wb - wa) if wb > wa else (", %d fewer" % (wa - wb) if wa > wb else " changed")))
	if changes.is_empty():
		return "nothing a reader sees"
	var shown := ", ".join(changes.slice(0, 3))
	return shown + (" and %d more" % (changes.size() - 3) if changes.size() > 3 else "")


static func _diff(a: Variant, b: Variant, at: String, out: PackedStringArray) -> void:
	if a is Dictionary and b is Dictionary:
		var keys: Array = (a as Dictionary).keys()
		for k in (b as Dictionary).keys():
			if not keys.has(k):
				keys.append(k)
		for k in keys:
			var place := (at + "." + str(k)) if not at.is_empty() else str(k)
			if not (a as Dictionary).has(k):
				out.append("%s set to %s" % [place, _short((b as Dictionary)[k])])
			elif not (b as Dictionary).has(k):
				out.append("%s unset" % place)
			else:
				_diff((a as Dictionary)[k], (b as Dictionary)[k], place, out)
		return
	if not DataPath.same(a, b):
		out.append("%s %s → %s" % [at, _short(a), _short(b)])


static func _short(v: Variant) -> String:
	var s := JSON.stringify(v) if (v is Dictionary or v is Array) else str(v)
	return s if s.length() <= 24 else s.left(22) + "…"


static func _words(text: String) -> int:
	return text.replace("\n", " ").replace("\t", " ").split(" ", false).size()


static func _index(dir: String) -> Array:
	var p := dir.path_join(INDEX)
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
	return (d as Array).duplicate() if d is Array else []
