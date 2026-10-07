extends RefCounted
class_name NoteStore

## NoteStore - where notes live (next/notes.md step 8, "Where do notes live?"): a DEFAULT FOLDER,
## and every other folder or file the user points Ghost Notes at - "it's not realistic to prevent
## people from sourcing their own content from other projects, git repos, etc." One small interface
## (list, create, add, and a stamp for outside edits), so a database can arrive later - as an index
## rebuilt from the files, which stay the source of truth - without touching a component.
##
## A NOTE IS A MARKDOWN FILE, as a rift chapter already is: frontmatter, then a body, and its
## components are the blocks under `ghost:` ([Components.template_for] reads which template runs
## it). Creating a note writes only the block that says what it is - `voice:` for a Generative
## note, `cards:` for a show, `song:` for a song - and leaves every other block to the panel, which
## writes one the first time its card is changed: an empty block is not "the defaults" to every card
## (an empty `illustrations:` would wipe the pictures' look), and a block nobody set is no block.

## The default folder.
const DEFAULT := "user://notes"
## Where notes are made and listed from: [constant DEFAULT], or a gate's own folder.
static var root := DEFAULT
## [Settings] section: `sources`, the folders and files the user added.
const SECTION := "notes"
const EXTS := ["md", "markdown"]
## How a deleted note is thrown away, when set: a gate's seam, so a check never fills the author's
## trash. Unset, a note goes to the system's trash ([method trash]).
static var discard: Callable = Callable()


## The default folder, absolute, made if it is not there.
static func folder() -> String:
	var abs := ProjectSettings.globalize_path(root)
	DirAccess.make_dir_recursive_absolute(abs)
	return abs


## The folders and files the user added, as absolute paths.
static func sources() -> PackedStringArray:
	var v: Variant = Settings.read(SECTION, "sources", [])
	var out := PackedStringArray()
	for p in (v as Array if v is Array else []):
		out.append(String(p))
	return out


## Point Ghost Notes at [param path] - a note anywhere, or a folder of them. A note already in a
## listed folder is not added twice. Returns false when there is nothing there.
static func add(path: String) -> bool:
	var p := path.simplify_path()
	if not (FileAccess.file_exists(p) or DirAccess.dir_exists_absolute(p)):
		return false
	if _covered(p):
		return true
	var list := sources()
	list.append(p)
	Settings.write(SECTION, "sources", Array(list))
	return true


## Forget [param path] as a source. The file itself is left exactly as it is.
static func remove(path: String) -> void:
	var list := sources()
	var i := list.find(path.simplify_path())
	if i >= 0:
		list.remove_at(i)
		Settings.write(SECTION, "sources", Array(list))


## EVERY NOTE, newest first: `{path, title, mtime}` - the default folder and every source, each file
## once. The title is the frontmatter's `title:` (read textually, one line), else the file's name.
static func list() -> Array:
	var seen := {}
	var out: Array = []
	var dirs := PackedStringArray([folder()])
	var files := PackedStringArray()
	for s in sources():
		if DirAccess.dir_exists_absolute(s):
			dirs.append(s)
		elif FileAccess.file_exists(s):
			files.append(s)
	for d in dirs:
		for f in DirAccess.get_files_at(d):
			if String(f.get_extension()).to_lower() in EXTS:
				files.append(d.path_join(f))
	for f in files:
		var p := f.simplify_path()
		if seen.has(p):
			continue
		seen[p] = true
		out.append({"path": p, "title": title_of(p), "mtime": FileAccess.get_modified_time(p)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["mtime"]) > int(b["mtime"]))
	return out


## A note's title: its `title:` line, else its file name without the extension.
static func title_of(path: String) -> String:
	var t := BookLayout.field_of(FileAccess.get_file_as_string(path), "title").strip_edges()
	return t if not t.is_empty() else path.get_file().get_basename()


## Its blocks under `ghost:` - which components it has - or {} for a note with none.
static func blocks_of(path: String) -> Dictionary:
	var res := FrontMatter.read_block(FileAccess.get_file_as_string(path))
	return res.data if res.ok and res.data is Dictionary else {}


## A NEW NOTE from the template [param key], in the default folder: `title:` and the block that
## says what it is ([method Components.marker_blocks]), with [param body] and [param blocks] laid
## over them. Returns its path, or "" with the reason pushed as a warning.
static func create(key: String, title := "", body := "", blocks := {}) -> String:
	var t: Dictionary = Components.TEMPLATES.get(key, {})
	if t.is_empty():
		push_warning("ghost: no template '%s'" % key)
		return ""
	var name := title.strip_edges()
	if name.is_empty():
		name = "Untitled %s" % String(t["label"])
	var path := unique(folder().path_join(_safe(name) + ".md"))
	var ghost := Components.marker_blocks(key)
	ghost.merge(blocks, true)
	# a note with no component has no `ghost:` key at all (null removes it), not an empty one
	var err := FrontMatter.create(path, ghost if not ghost.is_empty() else null, body, "",
		FrontMatter.KEY, {"title": name})
	if not err.is_empty():
		push_warning("ghost: could not make the note %s - %s" % [path, err])
		return ""
	return path


## [param path], or the same name with " 2", " 3"... before the extension, whichever is free.
static func unique(path: String) -> String:
	if not FileAccess.file_exists(path):
		return path
	var base := path.get_basename()
	var ext := path.get_extension()
	var n := 2
	while FileAccess.file_exists("%s %d.%s" % [base, n, ext]):
		n += 1
	return "%s %d.%s" % [base, n, ext]


## When the file last changed - a list or a panel compares it to notice an edit made elsewhere.
static func stamp(path: String) -> int:
	return FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0


static func _covered(p: String) -> bool:
	if p.get_base_dir() == folder().simplify_path():
		return true
	for s in sources():
		if s == p or (DirAccess.dir_exists_absolute(s) and p.get_base_dir() == s):
			return true
	return false


## A file name from a title: what a file system refuses, taken out.
static func _safe(name: String) -> String:
	var s := name
	for c in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		s = s.replace(c, " ")
	s = s.strip_edges()
	return s if not s.is_empty() else "Untitled"


## DELETE A NOTE (2026-10-06): to the system's trash - a mistaken yes is a trip to the trash, not a
## loss - and out of the sources if it was added by hand. Returns "" once it is gone, or why not.
static func trash(path: String) -> String:
	var p := path.simplify_path()
	if not FileAccess.file_exists(p):
		return "There is no note at %s." % p
	var err: int = int(discard.call(p)) if discard.is_valid() \
		else OS.move_to_trash(ProjectSettings.globalize_path(p))
	if err != OK:
		return "%s could not be moved to the trash (error %d)." % [p.get_file(), err]
	remove(p)
	return ""


## Is [param path] in the list only because it was added by hand, on its own - so it can leave the
## list without leaving the disk? (A note in an added folder is listed with its folder.)
static func is_added(path: String) -> bool:
	return sources().has(path.simplify_path())


## Is [param path] in the default folder - a note Ghost Notes made?
static func is_own(path: String) -> bool:
	return path.simplify_path().get_base_dir() == folder().simplify_path()
