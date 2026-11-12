extends RefCounted
class_name Illustrations

## Illustrations - the library of generated pictures a book prints.
##
## A chapter describes its pictures in `<!-- image: ... -->` markers ([Manuscript.images]); this turns
## each description into a PNG through an [ImageGen] backend and remembers it. A medium only asks
## [method path_for].
##
## The cache avoids paying twice (a picture costs about a minute and a share of the author's quota): the
## key is [method Manuscript.image_key] of the description, files live under
## `user://illustrations/<key>/vNNN.png`, and the index of versions and the chosen one is persisted
## through [Settings].
##
## Generation is explicit: nothing starts a job on its own; the panel's buttons are the only callers of
## [method generate].
##
## A reroll is a new version, never a replacement; earlier ones stay and the panel can step back.
##
## Stale, not invalid: each version records the signature of the look it was made under
## ([method look_signature]); one made under a different look is flagged stale and still used until
## rerolled.
##
## Settings is reached by name at runtime so this file loads in a bare `--script` gate where no
## autoload exists (see [method use_for_test]).

## Pictures under `<key>/vNNN.png`, reference copies under `refs/`, job dirs under `jobs/`.
const DIR := "user://illustrations"
const SECTION := "illustrations"
## How many pictures may be painting at once: each mostly waits on the network, but more than a couple
## is a burst against the author's quota.
const MAX_JOBS := 2
## A job that runs this long is abandoned. Measured ~60 s each.
const JOB_TIMEOUT_S := 600
const IMAGE_EXTS := ["png", "jpg", "jpeg", "webp"]
## Self-reference, a switch per kind (on unless the document says otherwise): each picture is also sent
## the ones already made before it in the chapter, so they read as one hand. It rides alongside the
## static references and is never written into them. At most this many are sent: the first (which set
## the look) and the most recent, since a pile of attachments makes a model worse at matching.
const CHAIN_MAX := 4

## Bumped whenever a picture lands or the chosen version changes, so a medium holding page textures
## re-typesets without polling the disk.
static var revision := 0

## key -> job Dictionary, for the pictures being painted right now.
static var _jobs := {}
## Pictures waiting for a free slot: [{key, prompt, placement}], in request order.
static var _queue: Array = []
## key -> the last failure, for the panel. Session-only: a failure is news, not state.
static var _errors := {}

# The test seam, as in Films.use_for_test: an in-memory store instead of the author's settings, and a
# flag because an empty library is a state worth testing.
static var _test_active := false
static var _test_store := {}
static var _test_read_only := false
## Where pictures, references and jobs live; moved aside under test.
static var _root := DIR


static func use_for_test(store := {}, read_only := false) -> void:
	_test_active = true
	_test_store = store
	_test_read_only = read_only
	_root = "user://illustrations_test"
	_jobs = {}
	_queue = []
	_errors = {}
	_chapter = []
	_memo = {}


## The chapter's pictures in reading order ([method Manuscript.images] rows): what "the pictures before
## this one" means for a self-referenced kind. Set by whoever holds the text (the Illustrations panel).
static var _chapter: Array = []

static func set_chapter(images: Array) -> void:
	_chapter = images.duplicate(true)


# --- storage -----------------------------------------------------------------

static func _settings() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Settings") if tree != null else null


## What was last read or written, per key. Settings hands out a deep copy on every read and the panel
## asks every frame whether any picture changed (24 pictures in a 64-entry index cost 12.7 ms a frame).
## This library is the only writer of its section, so the held copy cannot go stale; callers that change
## a value they read write it back (_put_entry, set_*).
static var _memo := {}

static func _read(key: String, dflt: Variant) -> Variant:
	if _memo.has(key):
		return _memo[key]
	var v: Variant = dflt
	if _test_active:
		v = _test_store.get(key, dflt)
		v = v.duplicate(true) if (v is Dictionary or v is Array) else v
	else:
		var st := _settings()
		v = st.read(SECTION, key, dflt) if st != null else dflt
	_memo[key] = v
	return v


static func _write(key: String, value: Variant) -> void:
	if read_only():
		return
	_memo[key] = value
	if _test_active:
		_test_store[key] = value.duplicate(true) if (value is Dictionary or value is Array) else value
		return
	var st := _settings()
	if st != null:
		st.write(SECTION, key, value)


## A render, the offline analyzer and a test probe boot this app against the author's own settings; none
## may spend quota or rewrite the index.
static func read_only() -> bool:
	if _test_active:
		return _test_read_only
	var st := _settings()
	return st == null or bool(st.is_read_only())


# --- the look ----------------------------------------------------------------

## The style is per kind, named by the marker that asks for the picture: `image` for the pictures put
## into the book, `sketch` for the drawings its writer makes on the page (a painter's brief would turn
## a sketch into a painting). Each kind is edited, stored, signed and judged stale on its own. The
## references are the pictures' alone.
const STYLE_KINDS := ["image", "sketch"]
const STYLE_LABELS := {"image": "Pictures", "sketch": "Sketches"}


## Which style a picture of [param placement] is made under.
static func kind_of(placement: String) -> String:
	return "sketch" if placement == "sketch" else "image"


## `{kind: text}` for every kind. A library from before there were kinds held one string: the pictures'.
static func styles() -> Dictionary:
	# Not a null default: ConfigFile takes null as "no default given" and logs an error for a missing key.
	var raw: Variant = _read("styles", {})
	var out := {}
	for k in STYLE_KINDS:
		out[k] = ""
	if raw is Dictionary and not (raw as Dictionary).is_empty():
		for k in STYLE_KINDS:
			out[k] = String((raw as Dictionary).get(k, ""))
	else:
		out["image"] = String(_read("style", ""))
	return out


static func style(kind := "image") -> String:
	return String(styles().get(kind, ""))


static func set_style(text: String, kind := "image") -> void:
	var all := styles()
	all[kind] = text
	_write("styles", all)


## The reference images for [param kind], as `user://` paths of the copies this library holds. Per kind,
## like the style. A library from before there were kinds held one list: the pictures'.
static func references(kind := "image") -> Array:
	var out: Array = []
	for p in (_all_refs().get(kind, []) as Array):
		if FileAccess.file_exists(String(p)):
			out.append(String(p))
	return out


static func _all_refs() -> Dictionary:
	var raw: Variant = _read("refs_by_kind", {})     # {} not null - see styles()
	var out := {}
	for k in STYLE_KINDS:
		out[k] = []
	if raw is Dictionary and not (raw as Dictionary).is_empty():
		for k in STYLE_KINDS:
			out[k] = ((raw as Dictionary).get(k, []) as Array).duplicate()
	else:
		out["image"] = (_read("refs", []) as Array).duplicate()
	return out


## Whether [param kind] is sent its own earlier pictures. On by default.
static func self_reference(kind := "image") -> bool:
	var raw: Variant = _read("self_ref", {})
	return bool((raw as Dictionary).get(kind, true)) if raw is Dictionary else true


static func set_self_reference(on: bool, kind := "image") -> void:
	var raw: Variant = _read("self_ref", {})
	var d: Dictionary = (raw as Dictionary).duplicate() if raw is Dictionary else {}
	d[kind] = on
	_write("self_ref", d)


static func _set_refs(kind: String, list: Array) -> void:
	var all := _all_refs()
	all[kind] = list
	_write("refs_by_kind", all)


## Copy [param paths] into the library. A copy, so a reference does not vanish when the author tidies
## their Downloads folder. Named by content, so importing a file twice is one reference. Returns one
## line per file that could not be taken.
static func add_references(paths: Array, kind := "image") -> PackedStringArray:
	var errs := PackedStringArray()
	if read_only():
		errs.append("read-only session")
		return errs
	var list := references(kind)
	for src in paths:
		var dest := _take(String(src), errs)
		if not dest.is_empty() and not list.has(dest):
			list.append(dest)
	_set_refs(kind, list)
	return errs


## One file into the library, by content: the copy's `user://` path, or "" with the reason appended to
## [param errs]. A file that is already a library copy comes back as itself.
static func _take(s: String, errs: PackedStringArray) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_root.path_join("refs")))
	var ext := s.get_extension().to_lower()
	if not IMAGE_EXTS.has(ext):
		errs.append("%s: not an image" % s.get_file())
		return ""
	var bytes := FileAccess.get_file_as_bytes(s)
	if bytes.is_empty():
		errs.append("%s: unreadable" % s.get_file())
		return ""
	var dest := _root.path_join("refs").path_join(_sha(bytes).substr(0, 16) + "." + ext)
	if not FileAccess.file_exists(dest):
		var f := FileAccess.open(dest, FileAccess.WRITE)
		if f == null:
			errs.append("%s: could not copy" % s.get_file())
			return ""
		f.store_buffer(bytes)
		f.close()
	return dest


static func remove_reference(i: int, kind := "image") -> void:
	var list := references(kind)
	if i < 0 or i >= list.size():
		return
	list.remove_at(i)
	_set_refs(kind, list)
	# The copy stays: another chapter may still name this file (references are per document).


static func _sha(bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish().hex_encode()


## The signature of the look a picture is made under: the style text and the reference set (files are
## named by content, so their names are their content).
static func look_signature(style_text: String, refs: Array) -> String:
	var names := PackedStringArray()
	for r in refs:
		names.append(String(r).get_file())
	names.sort()
	return (style_text.strip_edges() + "|" + ",".join(names)).sha256_text().substr(0, 12)


## The look a [param kind] of picture is made under now. The chain of earlier pictures is not part of
## it: rerolling the first picture would otherwise mark every later one stale.
static func current_signature(kind := "image") -> String:
	# an edited reference instruction changes the look; the default does not
	var extra := ""
	for which in ["references", "self_reference"]:
		if not String(_all_prompts(which).get(kind, "")).is_empty():
			extra += "|" + ref_prompt(which, kind)
	return look_signature(style(kind) + extra, references(kind))


## How the attachments are to be used, per kind and per group - `references` (the author's reference
## images) and `self_reference` (the chapter's earlier pictures) - editable in the document as
## `reference_prompt:` / `self_reference_prompt:`, written out with these defaults. Which attachments a
## group is ("the first 3 attached images") stays internal and is prepended by [method build_prompt].
const REF_PROMPT_DEFAULTS := {
	"references": {
		"image": "STYLE REFERENCES ONLY. Match their rendering style: medium, palette, linework, texture, lighting and level of detail. Do NOT copy their subjects, characters, objects or composition - the content comes only from the description above.",
		"sketch": "STYLE REFERENCES ONLY. Match their line: pen, weight, hatching and how much is drawn. Do NOT copy their subjects or composition - the content comes only from the description above.",
	},
	"self_reference": {
		"image": "Earlier pictures from this same book. Match their rendering exactly - medium, palette, linework, texture and level of detail - so every one reads as made by the same hand. Keep a recurring character looking the same if one appears. Do NOT reuse their compositions or scenes - the content comes only from the description above.",
		"sketch": "Earlier sketches from this same notebook. Match their line exactly - pen, weight, hatching and how much is drawn - so every one reads as drawn by the same hand. Do NOT reuse their compositions - the content comes only from the description above.",
	},
}


## The instruction for [param which] group of attachments on [param kind]: the document's, or the default.
static func ref_prompt(which: String, kind := "image") -> String:
	var v := String(_all_prompts(which).get(kind, "")).strip_edges()
	return v if not v.is_empty() else String(REF_PROMPT_DEFAULTS[which][kind])


static func set_ref_prompt(which: String, text: String, kind := "image") -> void:
	var all := _all_prompts(which)
	# the default, written back, is stored as "the default" - so it keeps following it
	all[kind] = "" if text.strip_edges() == String(REF_PROMPT_DEFAULTS[which][kind]) else text
	_write("ref_prompts_" + which, all)


static func _all_prompts(which: String) -> Dictionary:
	var raw: Variant = _read("ref_prompts_" + which, {})
	return (raw as Dictionary).duplicate() if raw is Dictionary else {}


## The look as a document carries it - the painter, the style and the reference images - so a chapter
## keeps the look its pictures were made under. References are absolute paths to the library's own copies.
static func look() -> Dictionary:
	# Only what is set: [method set_look] reads a kind it is not given as none.
	var st := {}
	var refs := {}
	for k in STYLE_KINDS:
		if not style(k).strip_edges().is_empty():
			st[k] = style(k)
		var list: Array = []
		for r in references(k):
			list.append(ProjectSettings.globalize_path(String(r)))
		if not list.is_empty():
			refs[k] = list
	# Written for every kind, on or off: a default that changed later must not silently change it.
	var sr := {}
	for k in STYLE_KINDS:
		sr[k] = self_reference(k)
	var rp := {}
	var sp := {}
	for k in STYLE_KINDS:
		rp[k] = ref_prompt("references", k)
		sp[k] = ref_prompt("self_reference", k)
	var out := {"painter": backend(), "painter_model": painter_model(), "painter_effort": painter_effort(),
		"self_reference": sr, "reference_prompt": rp, "self_reference_prompt": sp}
	if not st.is_empty():
		out["style"] = st
	if not refs.is_empty():
		out["references"] = refs
	return out


## ...and back. Any image path is accepted (copied in by content, so a library copy is itself and a new
## file is imported).
##
## The block is the whole look: a style or reference list it does not name is none, not what the last
## chapter left. Only the painter carries over (it is the machine's, not the book's); a block naming
## one names its model and effort too. `style` and `references` may each be a map by kind or, as older
## documents wrote them, a bare string / list (the pictures'). Returns one line per file not taken.
static func set_look(d: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	if read_only():
		return errs
	if d.has("painter"):
		set_painter(String(d["painter"]), String(d.get("painter_model", "")), String(d.get("painter_effort", "")))
	var st: Variant = d.get("style", {})
	var rf: Variant = d.get("references", {})
	if not (st is Dictionary):
		st = {"image": String(st)}
	if rf is Array:
		rf = {"image": rf}
	elif not (rf is Dictionary):
		rf = {}
	var sr: Variant = d.get("self_reference", {})
	if sr is bool:
		sr = {"image": sr, "sketch": sr}
	elif not (sr is Dictionary):
		sr = {}
	var all_sr := {}
	var all_st := {}
	var all_rf := {}
	for k in STYLE_KINDS:
		all_st[k] = String((st as Dictionary).get(k, ""))
		var list: Array = []
		var given: Variant = (rf as Dictionary).get(k, [])
		for p in (given as Array if given is Array else []):
			var dest := _take(String(p), errs)
			if not dest.is_empty() and not list.has(dest):
				list.append(dest)
		all_rf[k] = list
		all_sr[k] = bool((sr as Dictionary).get(k, true))
	_write("self_ref", all_sr)
	_write("styles", all_st)
	for pair in [["reference_prompt", "references"], ["self_reference_prompt", "self_reference"]]:
		var given: Variant = d.get(String(pair[0]), {})
		if not (given is Dictionary):
			given = {"image": String(given)}
		var all := {}
		for k in STYLE_KINDS:
			var v := String((given as Dictionary).get(k, "")).strip_edges()
			all[k] = "" if v == String(REF_PROMPT_DEFAULTS[pair[1]][k]) else v
		_write("ref_prompts_" + String(pair[1]), all)
	_write("refs_by_kind", all_rf)
	return errs


static func backend() -> String:
	var k := String(_read("backend", ImageGen.REGISTRY.keys()[0]))
	return k if ImageGen.REGISTRY.has(k) else String(ImageGen.REGISTRY.keys()[0])


static func set_backend(key: String) -> void:
	if ImageGen.REGISTRY.has(key):
		_write("backend", key)


## The model the painter runs and how hard it reasons ([AgentPick]'s choice, "" for the cli's own),
## handed to every job.
static func painter_model() -> String:
	return String(_read("painter_model", ""))


static func painter_effort() -> String:
	return String(_read("painter_effort", ""))


## The painter, its model and its effort, as [AgentPick] chooses them.
static func set_painter(key: String, model: String, effort: String) -> void:
	if not ImageGen.REGISTRY.has(key):
		return
	set_backend(key)
	_write("painter_model", model)
	_write("painter_effort", effort)


# --- the prompt --------------------------------------------------------------

## The prompt, assembled. Pure, so the gate can hold it to its rules.
##
## The description goes in verbatim. The rest is what every picture shares - the style, what the
## references are for, the shape of the space it is printed in - and the prohibitions (an image model
## left alone captions a courtroom and frames a portrait). The references are style, not subject, and
## the prompt says so outright.
static func build_prompt(description: String, placement: String, style_text: String,
		ref_count: int, target: String, chain_count := 0, ref_text := "", chain_text := "") -> String:
	var lines := PackedStringArray()
	lines.append("Use your built-in image generation tool to create exactly ONE image, then "
		+ "save it as a PNG at this exact path: %s" % target)
	lines.append("Do not create or modify any other file. Reply with the saved path only.")
	lines.append("")
	lines.append("THE PICTURE (the author's description - follow it exactly):")
	lines.append(description.strip_edges())
	# A real animal is that animal: the description decides what each thing is; the style and
	# references only how it is drawn (a reference can otherwise win over the word).
	lines.append("Every real animal the description names is drawn as that animal, with its "
		+ "true anatomy, unmistakable at a glance: never replaced by, or mixed with, a creature from "
		+ "the references or the earlier pictures, however alike they look. Inventive creatures are "
		+ "only for what the description itself invents.")
	lines.append("")
	lines.append("FORMAT: " + placement_guide(placement))
	# A sketch is the writer's own hand, not the book's illustrator: [param style_text] and the
	# references are the sketches' own.
	var sketch := placement == "sketch"
	if not style_text.strip_edges().is_empty():
		if sketch:
			lines.append("STYLE (applies to every sketch in this notebook; the FORMAT above wins "
				+ "wherever they disagree): " + style_text.strip_edges())
		else:
			lines.append("STYLE (applies to every illustration in this book): " + style_text.strip_edges())
	# The attachments arrive in that order (the author's references, then the chain), so each group is
	# named by its place. What each group is for is the author's (see REF_PROMPT_DEFAULTS); which
	# attachments it is stays here because it depends on the counts.
	var kind := kind_of(placement)
	if ref_text.strip_edges().is_empty():
		ref_text = String(REF_PROMPT_DEFAULTS["references"][kind])
	if chain_text.strip_edges().is_empty():
		chain_text = String(REF_PROMPT_DEFAULTS["self_reference"][kind])
	var both := ref_count > 0 and chain_count > 0
	if ref_count > 0:
		lines.append("REFERENCES (%s): %s" % [
			("the first %d attached image%s" % [ref_count, "" if ref_count == 1 else "s"]) if both
				else ("the %d attached image%s" % [ref_count, "" if ref_count == 1 else "s"]),
			ref_text.strip_edges()])
	if chain_count > 0:
		lines.append("EARLIER PICTURES (%s): %s" % [
			("the last %d attached image%s" % [chain_count, "" if chain_count == 1 else "s"]) if both
				else ("the %d attached image%s" % [chain_count, "" if chain_count == 1 else "s"]),
			chain_text.strip_edges()])
	# A sketch may be labeled when its description says so; a picture never is.
	if sketch:
		lines.append("ALWAYS: no borders, no frames, no watermark, no signature; write words only "
			+ "where the description asks for them, in plain handwriting.")
	else:
		lines.append("ALWAYS: no text, no captions, no lettering, no borders, no frames, "
			+ "no watermark, no signature.")
	return "\n".join(lines)


## What each placement asks for: a plate for a full page; one clear subject for an inline picture (it
## reads at a few inches wide).
static func placement_guide(placement: String) -> String:
	if placement == "sketch":
		return ("a quick pen sketch as drawn in a research notebook: PURE BLACK INK LINES ONLY "
			+ "on a PURE WHITE background - no gray wash, no shading fills, no paper texture, no "
			+ "ruled lines, nothing behind the drawing. Hatching is fine. The white is removed "
			+ "afterwards so the lines can lie on a page, so anything that is not black line "
			+ "will be lost. LANDSCAPE, 3:2 (1536x1024), with white space around the drawing.")
	if placement == "full":
		return ("a full-page book illustration plate, PORTRAIT orientation, 2:3 aspect "
			+ "(1024x1536), composed to fill the whole page edge to edge.")
	if placement == "screen":
		return ("a picture that fills a widescreen video frame edge to edge, LANDSCAPE, 3:2 "
			+ "(1536x1024), composed so it still reads when its top and bottom are cropped to 16:9 "
			+ "- nothing that matters near those edges. The camera drifts slowly across it.")
	return ("a half-page illustration spanning the full width of a novel's text column, "
		+ "LANDSCAPE orientation, 3:2 (1536x1024), printed above or below the text on the page.")


# --- the index ---------------------------------------------------------------

## The stored record for [param key]: {prompt, placement, versions: [{file, sig, at}], current}.
static func entry(key: String) -> Dictionary:
	var idx: Dictionary = _read("index", {})
	var e: Variant = idx.get(key, {})
	return e if e is Dictionary else {}


static func _put_entry(key: String, e: Dictionary) -> void:
	var idx: Dictionary = _read("index", {})
	idx[key] = e
	_write("index", idx)


## The versions that still exist on disk, oldest first.
static func versions(key: String) -> Array:
	var out: Array = []
	for v in (entry(key).get("versions", []) as Array):
		if v is Dictionary and FileAccess.file_exists(String((v as Dictionary).get("file", ""))):
			out.append(v)
	return out


static func current_index(key: String) -> int:
	var n := versions(key).size()
	if n == 0:
		return -1
	return clampi(int(entry(key).get("current", n - 1)), 0, n - 1)


## The picture currently chosen for [param key], absolute, or "" when there is none yet.
static func path_for(key: String) -> String:
	var i := current_index(key)
	if i < 0:
		return ""
	return ProjectSettings.globalize_path(String((versions(key)[i] as Dictionary)["file"]))


static func select_version(key: String, i: int) -> void:
	var n := versions(key).size()
	if n == 0 or read_only():
		return
	var e := entry(key)
	e["current"] = clampi(i, 0, n - 1)
	_put_entry(key, e)
	revision += 1


## Delete version [param i] of [param key] - its file and its place in the index - and show the one
## before it (or, when it was the first, the next). With none left the picture is missing again.
## [method chain_refs] sends whatever is current, so deleting is how a bad picture stops being passed on.
## Returns false when nothing went.
static func delete_version(key: String, i: int) -> bool:
	if read_only():
		return false
	var vs := versions(key)
	if i < 0 or i >= vs.size():
		return false
	var file := String((vs[i] as Dictionary)["file"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	var at := current_index(key)
	vs.remove_at(i)
	var e := entry(key)
	e["versions"] = vs
	if vs.is_empty():
		e.erase("current")
	elif at >= i:
		e["current"] = maxi(at - 1, 0)
	else:
		e["current"] = at
	_put_entry(key, e)
	revision += 1
	return true


## Made under a different style or reference set than the one now in force.
static func is_stale(key: String) -> bool:
	var i := current_index(key)
	if i < 0:
		return false
	if (versions(key)[i] as Dictionary).has("imported"):
		return false                # made under no style, so no style can outdate it
	var kind := kind_of(String(entry(key).get("placement", "")))
	return String((versions(key)[i] as Dictionary).get("sig", "")) != current_signature(kind)


## "missing", "queued", "running", "ready" or "error".
static func status(key: String) -> String:
	if _jobs.has(key) or PageCapture.busy(key):
		return "running"
	for q in _queue:
		if String((q as Dictionary)["key"]) == key:
			return "queued"
	if (_errors.has(key) or not PageCapture.error_of(key).is_empty()) and current_index(key) < 0:
		return "error"
	return "ready" if current_index(key) >= 0 else "missing"


## What [param key]'s painter is doing now ([method TextGen.status_of]); "waiting its turn" while it
## is queued; "" otherwise.
static func activity(key: String) -> String:
	if _jobs.has(key):
		return TextGen.status_of(_jobs[key])
	for q in _queue:
		if String((q as Dictionary)["key"]) == key:
			return "waiting its turn"
	return ""


static func error_of(key: String) -> String:
	var e := String(_errors.get(key, ""))
	return e if not e.is_empty() else PageCapture.error_of(key)


static func busy() -> int:
	return _jobs.size() + _queue.size() + PageCapture.pending()


## Capture A real page as [param image]'s picture - a tablet page with a `url` (see
## [PageCapture]). Like generation it is explicit, and a recapture is a new version. "" when
## queued, else why not.
static func capture(image: Dictionary) -> String:
	if read_only():
		return "this session is read-only (a render or a probe) - nothing is captured here"
	var url := String(image.get("url", ""))
	if url.is_empty():
		return "not a page"
	if not url.begins_with("http://") and not url.begins_with("https://"):
		url = "https://" + url
	var err := PageCapture.request(String(image["key"]), url)
	if err.is_empty():
		pump()
	return err


# --- generation --------------------------------------------------------------

## Ask for a picture of [param image] (a [Manuscript.images] row: key, prompt, placement). A
## reroll when one already exists. Returns "" when queued, else why not.
static func generate(image: Dictionary) -> String:
	if read_only():
		return "this session is read-only (a render or a probe) - nothing is generated here"
	var key := String(image.get("key", ""))
	if key.is_empty() or String(image.get("prompt", "")).strip_edges().is_empty():
		return "no description"
	if status(key) in ["queued", "running"]:
		return ""
	if not ImageGen.make(backend()).available():
		return "%s is not installed" % Registry.label(ImageGen.REGISTRY, backend())
	_errors.erase(key)
	_queue.append({"key": key, "prompt": String(image["prompt"]),
		"placement": String(image.get("placement", "inline"))})
	pump()
	return ""


## Stop painting [param keys]: each waiting is taken out of the line, each being painted has its painter
## stopped. What was painted before stays.
static func stop(keys: Array) -> void:
	_queue = _queue.filter(func(q: Dictionary) -> bool: return not keys.has(String(q["key"])))
	for key in keys:
		if not _jobs.has(key):
			continue
		Subprocess.stop(int((_jobs[key] as Dictionary)["pid"]))
		_jobs.erase(key)


## Start what fits, notice what finished. Called from main._process and from the panel (a job is a
## subprocess and something with a frame has to see it end).
static func pump() -> void:
	if read_only():
		return
	for c in PageCapture.pump():
		var img := Image.new()
		if img.load(String(c["file"])) != OK:
			_errors[String(c["key"])] = "the capture could not be read"
			continue
		var err := _add_version(String(c["key"]), img, {"sig": "", "imported": "captured",
			"url": String(c["url"])}, String(c["url"]), "page")
		if err.is_empty():
			print("ghost: page %s captured" % String(c["url"]))
	_advance_jobs()
	while _jobs.size() < MAX_JOBS:
		var i := _next_startable()
		if i < 0:
			break
		_start(_queue.pop_at(i))


## Notice which painting jobs ended: land each, or - for a painter in steps (see [AgentJobs]) -
## let it start its next one, and the job runs on.
static func _advance_jobs() -> void:
	for key in _jobs.keys():
		var job: Dictionary = _jobs[key]
		var pid := int(job["pid"])
		if Subprocess.alive(pid):
			if int(Time.get_unix_time_from_system()) - int(job["started"]) > JOB_TIMEOUT_S:
				Subprocess.stop(pid)
				_errors[key] = "timed out after %d s" % JOB_TIMEOUT_S
				_jobs.erase(key)
			continue
		Subprocess.forget(pid)
		var next := int((job["gen"] as ImageGen.Backend).advance(job))
		if next > 0:
			job["pid"] = next
			continue
		_jobs.erase(key)
		_land(String(key), job)


## The first queued request that may start now. A self-referencing kind runs one at a time, in the
## order asked: two painting together could not reference each other.
static func _next_startable() -> int:
	for i in _queue.size():
		var kind := kind_of(String((_queue[i] as Dictionary)["placement"]))
		if not self_reference(kind):
			return i
		var busy_kind := false
		for j in _jobs.values():
			if kind_of(String((j as Dictionary)["placement"])) == kind:
				busy_kind = true
		for q in range(i):
			if kind_of(String((_queue[q] as Dictionary)["placement"])) == kind:
				busy_kind = true
		if not busy_kind:
			return i
	return -1


## The earlier pictures of [param key]'s kind in the chapter that exist now, as the chain sends
## them: the first, then the most recent, [constant CHAIN_MAX] in all, oldest first.
static func chain_refs(key: String) -> Array:
	var at := -1
	var kind := "image"
	for i in _chapter.size():
		if String((_chapter[i] as Dictionary)["key"]) == key:
			at = i
			kind = kind_of(String((_chapter[i] as Dictionary).get("placement", "")))
			break
	var made: Array = []
	for i in range(maxi(at, 0)):
		var im: Dictionary = _chapter[i]
		var k := String(im["key"])
		if kind_of(String(im.get("placement", ""))) == kind and k != key and not path_for(k).is_empty() \
				and not made.has(path_for(k)):
			made.append(path_for(k))
	if made.size() <= CHAIN_MAX:
		return made
	return [made[0]] + made.slice(made.size() - (CHAIN_MAX - 1))


static func _start(req: Dictionary) -> void:
	var key := String(req["key"])
	var gen := ImageGen.make(backend())
	var stamp := Time.get_ticks_msec()
	var dir := ProjectSettings.globalize_path(_root.path_join("jobs").path_join("%s_%d" % [key, stamp]))
	var target := dir.path_join("image.png")
	var kind := kind_of(String(req["placement"]))
	var refs: Array = []
	for r in references(kind):
		refs.append(ProjectSettings.globalize_path(String(r)))
	# The author's references first, then the chain: the prompt tells the model which is which.
	var chain: Array = chain_refs(key) if self_reference(kind) else []
	var n_static := refs.size()
	refs.append_array(chain)
	var job := {
		"key": key, "dir": dir, "target": target, "refs": refs,
		"placement": String(req["placement"]), "description": String(req["prompt"]),
		"sig": current_signature(kind), "backend": backend(),
		"model": painter_model(), "effort": painter_effort(),
		# A second of slack: file mtimes are whole seconds and the clock read is not.
		"started": int(Time.get_unix_time_from_system()) - 1,
		"prompt": build_prompt(String(req["prompt"]), String(req["placement"]), style(kind),
			n_static, target, chain.size(), ref_prompt("references", kind),
			ref_prompt("self_reference", kind)),
	}
	job["gen"] = gen
	var pid := gen.start(job)
	if pid <= 0:
		_errors[key] = gen.failure(job)
		return
	job["pid"] = pid
	_jobs[key] = job
	print("ghost: painting %s (%s, %d reference%s)" % [key, job["placement"], refs.size(),
		"" if refs.size() == 1 else "s"])


## A job ended. Take its picture into the library as a new version, or record why not.
static func _land(key: String, job: Dictionary) -> void:
	var gen: ImageGen.Backend = job["gen"]
	var made := gen.resolve(job)
	var img := Image.new()
	if made.is_empty() or img.load(made) != OK:
		_errors[key] = gen.failure(job)
		push_warning("ghost: illustration %s failed - %s" % [key, _errors[key]])
		return
	var err := _add_version(key, img, {"sig": String(job["sig"]), "backend": String(job["backend"])},
		String(job["description"]), String(job["placement"]))
	if not err.is_empty():
		_errors[key] = err
		return
	print("ghost: illustration %s ready (v%d)" % [key, versions(key).size()])
	# The job's scratch is done with once the picture is in the library; a failed job keeps its
	# directory (its event log is the only record of why).
	_remove_tree(String(job.get("dir", "")))


## [param img] into the library as [param key]'s newest version, chosen. [param rec] is the
## version's record beyond its file and time. "" on success, else why not.
static func _add_version(key: String, img: Image, rec: Dictionary, prompt: String,
		placement: String) -> String:
	var e := entry(key)
	var vs: Array = e.get("versions", [])
	# The first free number, not the count: after a delete the count names an existing file.
	var num := vs.size() + 1
	while FileAccess.file_exists(_root.path_join(key).path_join("v%03d.png" % num)):
		num += 1
	var file := _root.path_join(key).path_join("v%03d.png" % num)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(file.get_base_dir()))
	# Re-encoded rather than copied, so the library holds a real PNG whatever the painter wrote.
	if img.save_png(ProjectSettings.globalize_path(file)) != OK:
		return "could not write %s" % file
	rec["file"] = file
	rec["at"] = int(Time.get_unix_time_from_system())
	vs.append(rec)
	e["versions"] = vs
	e["current"] = vs.size() - 1
	e["prompt"] = prompt
	e["placement"] = placement
	_put_entry(key, e)
	_errors.erase(key)
	revision += 1
	return ""


## Use a picture from disk instead of painting one: [param path] becomes [param image]'s newest version
## as a generated one would, marked `imported` (made under no style, so a style change never calls it
## stale). Spends no quota. "" on success, else why not.
static func import_file(image: Dictionary, path: String) -> String:
	if read_only():
		return "this session is read-only (a render or a probe) - nothing is imported here"
	var key := String(image.get("key", ""))
	if key.is_empty():
		return "no picture to import for"
	var img := Image.new()
	if img.load(path) != OK or img.is_empty():
		return "could not read %s" % path.get_file()
	var err := _add_version(key, img, {"sig": "", "imported": path.get_file()},
		String(image.get("prompt", "")), String(image.get("placement", "inline")))
	if err.is_empty():
		print("ghost: illustration %s imported from %s" % [key, path])
	return err


## Is [param key]'s current picture one imported from disk?
static func is_imported(key: String) -> bool:
	var i := current_index(key)
	return i >= 0 and (versions(key)[i] as Dictionary).has("imported")


static func _remove_tree(dir: String) -> void:
	if dir.is_empty() or not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
