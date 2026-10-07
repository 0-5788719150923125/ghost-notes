extends SceneTree

## rewrite_blocks - moves a document's ghost settings from ONE BLOCK PER PANEL to ONE BLOCK PER
## COMPONENT (next/notes.md step 5). A tool, not a gate: it writes the files it is given, and
## only with --write.
##
##   godot --headless --path . --script tests/rewrite_blocks.gd -- FILE...          # dry run
##   godot --headless --path . --script tests/rewrite_blocks.gd -- --write FILE...  # rewrite
##
## THE SHAPES. Before, a Generative chapter kept `ghost: generative:` - the cast, `illustrations`,
## and a `picture` holding the medium, the Look's filters, the bookends and the Director's dials -
## and a tarot show kept `ghost: tarot:`, the same cast and picture with its own knobs beside them.
## After, they are siblings: `voice` (turn, tab, voices, hesitate, hesitate_on), `picture` (medium,
## scene_hold, flourishes, camera, hand, film_frequency), `illustrations`, `look` (filters),
## `bookends` (intro, outro), and `tarot` (the show's knobs, its title and description) - each
## block the component's, so a chapter's voices are there in every panel. Ghost Notes reads only
## the new shape: this is the one-time rewrite the plan chose over a reader that takes both.
##
## WHAT MAKES IT SAFE. Every value of the old block must land at its new place with the same value,
## and nothing else may appear (checked leaf by leaf, then again after a round trip through the
## YAML writer); a key this tool does not know, or a document carrying BOTH old blocks (two casts -
## which is the voice?), is refused and left alone. The write itself is
## [method FrontMatter.write_block]'s: re-read from disk, one key replaced textually, the body and
## every other frontmatter line verified byte-identical, renamed into place from a checked temp file.

## Where each key of an old block goes, as a block name; `picture` is split by [constant PICTURE].
const VOICE_KEYS := ["turn", "tab", "voices", "hesitate", "hesitate_on"]
const PICTURE := {"medium": "picture", "scene_hold": "picture", "flourishes": "picture",
	"camera": "picture", "hand": "picture", "film_frequency": "picture",
	"filters": "look", "intro": "bookends", "outro": "bookends"}
## The tarot block's own keys (TarotEditor.KNOBS, and the show's YouTube title and description).
const TAROT_KEYS := ["show", "seed", "cards", "reversals", "jumpers", "writer", "writer_model",
	"writer_effort", "painter", "painter_model", "painter_effort", "episode_title", "description"]
## The order a rewritten document keeps its blocks in: the panel's.
const ORDER := ["tarot", "voice", "picture", "illustrations", "look", "bookends"]


func _initialize() -> void:
	var write := false
	var files: Array = []
	for a in OS.get_cmdline_user_args():
		if a == "--write":
			write = true
		else:
			files.append(a)
	if files.is_empty():
		print("rewrite_blocks: name the documents to rewrite (and --write to write them)")
		quit(2)
		return
	var bad := 0
	for f in files:
		if not _one(String(f), write):
			bad += 1
	print("rewrite_blocks: %d document(s), %d refused%s" % [files.size(), bad,
		"" if write else " - a dry run; nothing was written (--write writes)"])
	quit(1 if bad > 0 else 0)


## One document: reshape, verify, and write when asked. False when it was refused.
func _one(path: String, write: bool) -> bool:
	if not FileAccess.file_exists(path):
		print("  REFUSED  %s: not there" % path)
		return false
	var raw := FileAccess.get_file_as_string(path)
	var res := FrontMatter.read_block(raw)
	if not res.ok:
		print("  REFUSED  %s: its frontmatter does not parse (%s)" % [path, res.error])
		return false
	if not (res.data is Dictionary):
		print("  skip     %s: no ghost settings" % path)
		return true
	var old: Dictionary = res.data
	var r := reshape(old)
	if not String(r.error).is_empty():
		print("  REFUSED  %s: %s" % [path, r.error])
		return false
	if r.moved.is_empty():
		print("  skip     %s: already in the new shape (%s)" % [path, ", ".join(PackedStringArray(old.keys()))])
		return true
	var after: Dictionary = r.ghost
	# THE ROUND TRIP: what the YAML writer makes of the new block must read back as the new block,
	# and the text must differ from the old only inside the ghost key
	var text := FrontMatter.put_block(raw, after)
	if text.is_empty():
		print("  REFUSED  %s: the frontmatter writer refused the new block" % path)
		return false
	var back := FrontMatter.read_block(text)
	if not back.ok or not _same(back.data, after):
		print("  REFUSED  %s: the new block does not read back as written" % path)
		return false
	if String(FrontMatter.split(text).body) != String(FrontMatter.split(raw).body):
		print("  REFUSED  %s: the body would change" % path)
		return false
	print("  %s %s: %s" % ["rewrote " if write else "would   ", path, ", ".join(PackedStringArray(r.moved))])
	if not write:
		return true
	var err := FrontMatter.write_block(path, after)
	if not err.is_empty():
		print("  REFUSED  %s: %s" % [path, err])
		return false
	return true


## [param old] (a document's whole `ghost:` dictionary) in the new shape:
## `{ghost, moved: Array of "old -> new" block moves, error}`. `moved` is empty when there was
## nothing to do; `error` is set (and `ghost` empty) when the document is refused.
static func reshape(old: Dictionary) -> Dictionary:
	var panels: Array = []
	if old.get("generative") is Dictionary:
		panels.append("generative")
	if old.get("tarot") is Dictionary and _is_old_tarot(old["tarot"] as Dictionary):
		panels.append("tarot")
	if panels.is_empty():
		return {"ghost": old, "moved": [], "error": ""}
	if panels.size() > 1:
		return {"ghost": {}, "moved": [], "error": "it carries both a `generative:` and a `tarot:` block - "
			+ "two casts, and only one can be the voice. Merge them by hand first."}
	var src: String = panels[0]
	var block: Dictionary = old[src]
	var made := {}                      # new block name -> Dictionary
	for k in block:
		var key := String(k)
		var to := ""
		if key in VOICE_KEYS:
			to = "voice"
		elif key == "illustrations" and src == "generative" and block[k] is Dictionary:
			made["illustrations"] = block[k]        # the block itself, not a key inside one
			continue
		elif key in TAROT_KEYS and src == "tarot":
			to = "tarot"
		elif key == "picture" and block[k] is Dictionary:
			for pk in block[k]:
				if not PICTURE.has(String(pk)):
					return {"ghost": {}, "moved": [], "error": "`%s.picture.%s` is a key this tool does not know" % [src, pk]}
				var name: String = PICTURE[String(pk)]
				if src == "tarot" and name == "picture":
					# the tarot panel never wrote these (its medium is pinned, the table has no dials)
					return {"ghost": {}, "moved": [], "error": "`tarot.picture.%s` was never a show's - check it by hand" % pk}
				(made.get_or_add(name, {}) as Dictionary)[String(pk)] = block[k][pk]
			continue
		else:
			return {"ghost": {}, "moved": [], "error": "`%s.%s` is a key this tool does not know" % [src, key]}
		(made.get_or_add(to, {}) as Dictionary)[key] = block[k]
	for name in made:
		if old.has(name) and name != src:
			return {"ghost": {}, "moved": [], "error": "it already has a `%s:` block beside the old one" % name}
	# THE OLD BLOCK'S PLACE takes the new blocks, in the panel's order; every other key stays where it was
	var out := {}
	var moved: Array = []
	for k in old:
		if String(k) != src:
			out[k] = old[k]
			continue
		for name in ORDER:
			if made.has(name):
				out[name] = made[name]
				moved.append("%s -> %s" % [src, name])
	var err := _verify(block, src, made)
	if not err.is_empty():
		return {"ghost": {}, "moved": [], "error": err}
	return {"ghost": out, "moved": moved, "error": ""}


## A `tarot:` block in the old shape carries the cast (or the picture) beside its knobs.
static func _is_old_tarot(t: Dictionary) -> bool:
	for k in t:
		if String(k) in VOICE_KEYS or String(k) == "picture":
			return true
	return false


## EVERY OLD VALUE AT ITS NEW PLACE, AND NOTHING ELSE: the old block's leaves, each mapped to where
## it should now be, must be exactly the leaves of the blocks made from it.
static func _verify(block: Dictionary, src: String, made: Dictionary) -> String:
	var want := {}
	var old := _leaves(block, "")
	for path in old:
		want[_new_path(path, src)] = old[path]
	var got := {}
	for name in made:
		got.merge(_leaves(made[name] as Dictionary, String(name)))
	if want.size() != got.size():
		return "the move would change the number of values (%d -> %d)" % [want.size(), got.size()]
	for path in want:
		if not got.has(path) or not _same(want[path], got[path]):
			return "the value at %s would not survive the move" % path
	return ""


## `old.path` -> `new.path` for one leaf of the old block.
static func _new_path(path: String, src: String) -> String:
	var parts := path.split("/")
	var top := parts[0]
	if top in VOICE_KEYS:
		return "voice/" + path
	if top == "illustrations" and src == "generative":
		return path
	if top in TAROT_KEYS and src == "tarot":
		return "tarot/" + path
	if top == "picture" and parts.size() > 1:
		return String(PICTURE.get(parts[1], "?")) + "/" + "/".join(parts.slice(1))
	return "?/" + path


## Every leaf of [param d] by its slash-joined path. A list is a leaf: it moves whole.
static func _leaves(d: Dictionary, prefix: String) -> Dictionary:
	var out := {}
	for k in d:
		var p := String(k) if prefix.is_empty() else prefix + "/" + String(k)
		if d[k] is Dictionary and not (d[k] as Dictionary).is_empty():
			out.merge(_leaves(d[k] as Dictionary, p))
		else:
			out[p] = d[k]
	return out


## Equal as settings, as [method DocSource.same_value] decides it - numbers by value whatever their
## type (YAML reads 3, the writer may give 3.0). A copy, because a script run with --script is
## compiled before the autoloads exist, and DocSource names one.
static func _same(a: Variant, b: Variant) -> bool:
	var num := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in num and typeof(b) in num:
		return absf(float(a) - float(b)) < 0.0005
	if a is Dictionary and b is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k in a:
			if not (b as Dictionary).has(k) or not _same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _same(a[i], b[i]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b
