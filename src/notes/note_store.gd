extends RefCounted
class_name NoteStore

## NoteStore - where notes live (next/notes.md step 8, "Where do notes live?"): a DEFAULT FOLDER,
## and every other folder or file the user points Ghost Notes at - "it's not realistic to prevent
## people from sourcing their own content from other projects, git repos, etc." One small interface
## (list, create, add, and a stamp for outside edits), so a database can arrive later - as an index
## rebuilt from the files, which stay the source of truth - without touching a component.
##
## A NOTE IS A MARKDOWN FILE, as a rift chapter already is: frontmatter, then a body, and its
## components are the blocks under `ghost:` ([method Components.attached_of]). A new note has
## none. Attaching a component writes only the block that says it is there
## ([method Components.attach_blocks]) and leaves every setting to its card, which writes one the
## first time it is changed: an empty block is not "the defaults" to every card (an empty
## `illustrations:` would wipe the pictures' look), and a block nobody set is no block.

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
	var t := FrontMatter.field_of(FileAccess.get_file_as_string(path), "title").strip_edges()
	return t if not t.is_empty() else path.get_file().get_basename()


## Its blocks under `ghost:` - which components it has - or {} for a note with none.
static func blocks_of(path: String) -> Dictionary:
	var res := FrontMatter.read_block(FileAccess.get_file_as_string(path))
	return res.data if res.ok and res.data is Dictionary else {}


## WHAT THE NOTES LIST SHOWS OF A NOTE, from one read of its file: `title` ([method title_of]),
## `preview` (its words as a reader sees them, [method preview_of] - less a first line that only says the
## title again, as a chapter's heading does), `attached` (its components,
## [method Components.attached_of]) and `words`, everything a search looks through - the title, the
## words and the components' names, lower-cased.
static func summary_of(path: String) -> Dictionary:
	var raw := FileAccess.get_file_as_string(path)
	var t := FrontMatter.field_of(raw, "title").strip_edges()
	if t.is_empty():
		t = path.get_file().get_basename()
	var res := FrontMatter.read_block(raw)
	var attached := Components.attached_of(res.data if res.ok and res.data is Dictionary else {})
	var body := plain_of(String(FrontMatter.split(raw)["body"]))
	var names := " ".join(attached.map(func(k: String) -> String: return Registry.label(Components.REGISTRY, k)))
	var lead := body.strip_edges(true, false).get_slice("\n", 0).strip_edges()
	var shown := body.strip_edges(true, false).substr(lead.length()) if _same_words(lead, t) else body
	return {"title": t, "preview": preview_of(shown), "attached": attached,
		"words": ("%s\n%s\n%s" % [t, body, names]).to_lower()}


## Do [param a] and [param b] say the same words, whatever their case and punctuation?
static func _same_words(a: String, b: String) -> bool:
	var re := RegEx.create_from_string("[^\\p{L}\\p{N}]+")
	return re.sub(a.to_lower(), "", true) == re.sub(b.to_lower(), "", true)


## A note's body as it reads, its marks left out: every `<!-- ... -->` (a reading's cues, a letter's
## sketches), and markdown's own markers - a heading's #, emphasis, a link's brackets.
static func plain_of(body: String) -> String:
	var s := body
	for pair in PLAIN:
		s = RegEx.create_from_string(String(pair[0])).sub(s, String(pair[1]), true)
	return s


## What [method plain_of] takes out, in order: a pattern and what it leaves. An underscore only at a
## word's edge (`snake_case` keeps its own).
const PLAIN := [
	["<!--[\\s\\S]*?-->", ""],
	["(?m)^[ \\t]{0,3}#{1,6}[ \\t]+", ""],
	["(?m)^[ \\t]{0,3}>[ \\t]?", ""],
	["!?\\[([^\\]]*)\\]\\([^)]*\\)", "$1"],
	["[*`]{1,3}(?=\\S)|(?<=\\S)[*`]{1,3}", ""],
	["(?<!\\w)_{1,2}(?=\\S)|(?<=\\S)_{1,2}(?!\\w)", ""],
]


## THE FIRST WORDS OF [param plain] FOR A NOTE'S TILE: its paragraphs one to a line, blank lines and
## runs of spaces closed up, cut at a word near [param most] characters.
static func preview_of(plain: String, most := 600) -> String:
	var lines: Array = []
	var n := 0
	for line in plain.split("\n"):
		var l := RegEx.create_from_string("\\s+").sub(String(line), " ", true).strip_edges()
		if l.is_empty():
			continue
		lines.append(l)
		n += l.length() + 1
		if n >= most:
			break
	var out := "\n".join(lines)
	if out.length() > most:
		var cut := out.rfind(" ", most)
		out = out.substr(0, cut if cut > most / 2 else most).strip_edges() + "…"
	return out


## A NEW NOTE in the default folder: its `title:`, [param body] and nothing attached - or
## [param blocks], for one made with components already on it (a recording, a gate). There is one
## kind of new note; "+" makes it what it becomes ([Components]). Returns its path, or "" with the
## reason pushed as a warning.
static func create(title := "", body := "", blocks := {}) -> String:
	var name := title.strip_edges()
	if name.is_empty():
		name = "Untitled"
	var path := unique(folder().path_join(_safe(name) + ".md"))
	# a note with no component has no `ghost:` key at all (null removes it), not an empty one
	var err := FrontMatter.create(path, blocks.duplicate(true) if not blocks.is_empty() else null, body, "",
		FrontMatter.KEY, {"title": name})
	if not err.is_empty():
		push_warning("ghost: could not make the note %s - %s" % [path, err])
		return ""
	return path


## A NOTE'S FILE IS NAMED AFTER ITS TITLE, AND STAYS SO (2026-10-31, the user: "a new note will get a filename
## like 'Untitled 2.md'. Can we setup a system that will name those files after the title ... and prevent
## collisions by adding a number only when two files match?"): retitled, a note whose file's name FOLLOWS its
## title is renamed to the new one's ([method retitle]).
##
## WHETHER IT FOLLOWS IS READ OFF THE NAME, NEVER KEPT ("we probably need a flag and a handler, for instances
## the user clicked on 'Save', and saved the file under a different name ... The same should be supported on
## import"): a file follows its title while its name IS the title's ([method name_of]), or that and a number
## another note made it take. Saved… under a name of the author's own, a file brought in under one (a chapter
## `43-secular-hazing.md` titled "Secular Hazing"), or renamed by hand outside the app, its name says something
## else, so it is left as it is - and stays so until its title is made to match it again. A flag kept in the
## note or in the settings would be one more thing to fall out of step with the file it describes.

## Does [param path]'s name follow the title [param title] (its own, read from the file, when empty)?
static func follows(path: String, title := "") -> bool:
	var t := title if not title.is_empty() else title_of(path)
	var stem := path.get_file().get_basename()
	var want := name_of(t)
	if stem == want:
		return true
	var tail := stem.substr(want.length() + 1)
	return stem.begins_with(want + " ") and tail.is_valid_int() and int(tail) >= 2


## The name a note titled [param title] is kept under: the title, less what a file system refuses.
static func name_of(title: String) -> String:
	return _safe(title)


## WHERE A NOTE TITLED [param title] IS KEPT, beside [param path]: its title's name, with " 2", " 3"... only
## when another file has it - [param path] itself is never in its own way.
static func path_for(path: String, title: String) -> String:
	var dir := path.get_base_dir()
	var ext := path.get_extension() if not path.get_extension().is_empty() else "md"
	var base := name_of(title)
	var n := 1
	while true:
		var p := dir.path_join("%s.%s" % [base, ext] if n == 1 else "%s %d.%s" % [base, n, ext])
		if p.simplify_path() == path.simplify_path() or not FileAccess.file_exists(p):
			return p
		n += 1
	return path


## RETITLE THE NOTE AT [param path]: its `title:` line written ([param title]; empty removes it, and the note
## is then named by its file), and the file renamed after the new title when its name followed the old one
## ([method follows]). Returns where the note is now.
static func retitle(path: String, title: String) -> String:
	var t := title.strip_edges()
	var raw := FileAccess.get_file_as_string(path)
	if FrontMatter.field_of(raw, "title").strip_edges() == t:
		return path
	var follow := follows(path)
	var err := FrontMatter.write_block(path, t if not t.is_empty() else null, "title")
	if not err.is_empty():
		push_warning("ghost: the title of %s was not written - %s" % [path.get_file(), err])
		return path
	if not follow or t.is_empty():
		return path
	return rename(path, path_for(path, t))


## THE NOTE AT [param from] MOVED TO [param to] on the disk - a rename, nothing copied - and the list told: a
## file added by hand is listed by its new path. Returns where the note is now ([param from] when it could not
## move, with the reason pushed as a warning).
static func rename(from: String, to: String) -> String:
	if to.simplify_path() == from.simplify_path():
		return from
	if FileAccess.file_exists(to):
		push_warning("ghost: %s was not renamed - %s is there already." % [from.get_file(), to.get_file()])
		return from
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))
	if err != OK:
		push_warning("ghost: %s could not be renamed to %s (error %d)." % [from.get_file(), to.get_file(), err])
		return from
	if is_added(from):
		remove(from)
		add(to)
	return to


## A NOTE MADE A MOMENT AGO AND LEFT EMPTY GOES, outright (Keep's way): New pressed and nothing written leaves no
## "Untitled 3.md" behind. Only one of Ghost Notes' own, with no words and nothing attached; the caller says it
## is new. Returns whether it went.
static func discard_if_empty(path: String) -> bool:
	if not is_own(path) or not FileAccess.file_exists(path):
		return false
	var raw := FileAccess.get_file_as_string(path)
	if not String(FrontMatter.split(raw)["body"]).strip_edges().is_empty() or not blocks_of(path).is_empty():
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


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
	s = s.strip_edges().lstrip(".").strip_edges()       # a name opening on a dot is a hidden file
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
