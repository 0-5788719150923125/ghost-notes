extends SceneTree

## pictures_card_check - the note's pictures, one card ([PicturesCard]).
##
##   godot --headless --path . --script tests/show/pictures_card_check.gd
##
## Which marks are pictures is the presentation's ([method Medium.pictures_of]): a novel prints every image
## mark, a sketch among them; a letter never its sketch, which its pen draws (control: the novel's has it);
## a dispatch desk finds a picture pinned to a screen (control: the plain image marks miss it); a tablet
## adds its real pages, captured, with their `url`; the full frame shows none.
##
## It comes with what shows pictures ([method Components.with_parts]): beside the Medium, and beside a show
## at a table, whose agents paint pictures of their own; never beside a voice alone (control); and it has
## no × of its own, where the Medium card has one. Every panel shows what comes with the cards it shows
## (its workspace's `hosts`; control: the table's without the Pictures card).
##
## One card: built beside the Medium card (as a letter, a dispatch desk and a tablet), which never carries a
## list of pictures of its own (control: the Pictures card holds one).
##
## It stands only while the medium shows pictures: pinned to a letter, the card stands, its list the
## letter's pictures and not its sketch, and its Pipeline section is listed; under the full frame the card
## and its section are put away (control); under a novel both are back, the sketch with them.
##
## What a show's agents painted is shown ([MadePictures], [method EpisodeFeed.made_pictures]): under the
## full frame, which shows no pictures of the note's, the card stands while the episode has a picture its
## agents made, a thumbnail of it listed; with none made it is put away again (control).
##
## Generate all is on the card, saying how many have none (a page captured is never counted) and grayed
## with none to paint; read-only, it is grayed and, pressed, says why. It is the Pipeline card's Generate:
## one function behind both.
##
## A picture that stands for a clip (its row has `clip`) is imported from a video, never painted: its row
## offers Import… and no Generate, its Pipeline row has no ⟳, and it is never owed (control: the same
## picture without `clip` is owed and offers Generate). Imported ([method Illustrations.import_clip]; the
## fixtures are made by ffmpeg's lavfi in the gate's own folder, the library is the test seam's), a video is
## decoded in the background into a version of frames: the first frame its picture, 12 fps, 480 px wide at
## most and never upscaled, 20 s at most, `clip.json` beside them, its sound a mono WAV only where the video
## had sound (control: the silent one has none). ‹ › step between clips, ✕ takes a clip's folder, a file
## that is no video fails with a reason and keeps nothing, and a read-only session refuses.
##
## A picture's entry offers Flip ([method Illustrations.set_flipped]): grayed with nothing painted, and none on a page
## captured (control); ticked, the picture served is its mirrored copy and the entry says flipped; unticked, it is
## served as made again.

const WORDS := ("Words. <!-- image: A harbor at dawn. --> More.\n\n<!-- sketch: a tree of dots -->\n\n"
	+ "Then. <!-- image: A storm over the bay. -->\n")
const DESK := ("<!-- speaker: Control -->\nThe feed. <!-- image (feed): The car park from above. -->\n\n"
	+ "<!-- image (full): Dawn over the field. -->\n")
const TABLET := ("<!-- url: news.test/a -->\n\n# An article\n\nRead this. <!-- image: A harbor at dawn. -->\n\n"
	+ "Then [the listing](https://www.shop.test/item/42).\n\n<!-- url: https://www.shop.test/item/42 -->\n")
## A picture entry for a clip, as a medium hands it to the card.
const CLIP := {"kind": "image", "prompt": "a small brown dog on a kitchen floor, spinning after its own tail",
	"placement": "screen", "clip": "dog-tail.webm"}
## The gate's own folder for the videos it decodes.
const CLIP_DIR := "user://pictures_card_check_clip"

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	Illustrations.use_for_test({}, true)
	_which()
	_comes_with()
	await _one_card()
	await _clip_rows()
	await _flip_row()
	await _clip_decode()
	Illustrations.use_for_test()
	print("pictures_card_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


## Which marks are pictures is the presentation's.
func _which() -> void:
	var book := _prompts(Medium.pictures_of("book", WORDS))
	_ok(book == ["A harbor at dawn.", "a tree of dots", "A storm over the bay."], "a novel prints every image mark, the sketch among them: %s" % str(book))
	var letter := _prompts(Medium.pictures_of("letter", WORDS))
	_ok(letter == ["A harbor at dawn.", "A storm over the bay."], "a letter's pictures, never its sketch (the control above has it): %s" % str(letter))
	var desk := _prompts(Medium.pictures_of("dispatch", DESK))
	_ok(desk == ["The car park from above.", "Dawn over the field."], "a dispatch desk finds the picture pinned to a screen: %s" % str(desk))
	_ok(_prompts(Manuscript.images(DESK)) == ["Dawn over the field."], "the control: the plain image marks miss it")
	var tab := Medium.pictures_of("tablet", TABLET)
	_ok(tab.size() == 2 and String(tab[0]["prompt"]) == "A harbor at dawn." and String(tab[1].get("url", "")) == "https://www.shop.test/item/42",
		"a tablet adds its real page, captured, with its url: %s" % str(_prompts(tab)))
	_ok(Medium.pictures_of("full", WORDS).is_empty() and Medium.pictures_of("comic", WORDS).is_empty(), "the full frame and the comic show none")
	var twice := "<!-- image: A pen on a desk. -->\n\nOne.\n\n<!-- image: A pen on a desk. -->\n\nTwo.\n"
	_ok(Medium.pictures_of("book", twice).size() == 1 and Manuscript.images(twice).size() == 2,
		"a picture shown twice is one picture to make (the control: its marks are two)")


## It comes with what shows pictures: the Medium (whose formats include the Letter and the Dispatch desk)
func _comes_with() -> void:
	_ok(Components.with_parts(["text", "voice", "medium"]).has("illustrations"), "it comes with the Medium")
	_ok(Components.with_parts(["text", "table", "voice"]).has("illustrations"), "...and with a show at a table, whose agents paint")
	_ok(not Components.with_parts(["text", "voice"]).has("illustrations"), "the control: never beside a voice alone")
	_ok(Components.attach_blocks("illustrations").is_empty() and not Components.detach_blocker("illustrations", ["text", "voice", "medium"]).is_empty(),
		"never attached or taken off by itself")
	# ...and on the panel of what it comes with: a panel shows no card its `hosts` do not list
	var unhosted := _unhosted(Components.WORKSPACES)
	_ok(unhosted.is_empty(), "every panel shows what comes with the cards it shows: missing %s" % str(unhosted))
	var cut: Dictionary = Components.WORKSPACES.duplicate(true)
	((cut["table"] as Dictionary)["hosts"] as Array).erase("illustrations")
	_ok(_unhosted(cut) == [["table", "illustrations"]], "the control: a table panel without it is found: %s" % str(_unhosted(cut)))


## `[workspace, part]` for each part that comes with a card a panel shows ([method Components.with_parts])
## but is not among its `hosts`: made for the note, and put on no panel.
static func _unhosted(workspaces: Dictionary) -> Array:
	var out: Array = []
	for ws in workspaces:
		var hosts: Variant = (workspaces[ws] as Dictionary).get("hosts")
		if not (hosts is Array):
			continue
		for k in Components.REGISTRY:
			var with: Array = (Components.REGISTRY[k] as Dictionary).get("comes_with", [])
			if not (hosts as Array).has(k) and with.any(func(h: String) -> bool: return (hosts as Array).has(h)):
				out.append([ws, k])
	return out


## One card, standing only while the medium shows pictures. (Nothing here is typed by a card's class: a
## `--script` gate compiles before the autoloads, and a card that names one would be loaded broken.)
func _one_card() -> void:
	var director: Node = root.get_node("Director")
	var cards: GDScript = load("res://src/ui/note_cards.gd")
	var panel = load("res://src/ui/side_panel.gd").new()
	panel.detach = func(_key: String) -> void: pass
	root.add_child(panel)
	var have := Components.with_parts(["text", "voice", "medium"])
	var built: Dictionary = cards.build(panel, have, {"only": ["medium", "illustrations"], "reading": true,
		"blocks": {"medium": {"format": "letter"}}})
	var pictures = built.get("illustrations")
	_ok(pictures != null and built.has("medium") and built["medium"].own() != null,
		"a letter's panel builds the Pictures card beside the Medium card, the Letter's rows on it: %s" % str(built.keys()))
	if pictures == null:
		panel.queue_free()
		return
	var crosses: Array = panel._detach_buttons.map(func(d: Array) -> String: return String(d[1]))
	_ok(crosses.has("medium") and not crosses.has("illustrations"), "the Medium card has its ×, the Pictures card none: %s" % str(crosses))
	_ok(_lists(built["medium"]) == 0 and _lists(pictures) == 1, "the Medium card with the Letter's rows carries no list of its own, the Pictures card one")
	for fmt in ["dispatch", "tablet"]:
		var other = cards.make("medium", {"reading": true, "blocks": {"medium": {"format": fmt}}})
		_ok(_lists(other) == 0, "...nor does it as a %s" % fmt)
		other.free()
	var pin := RefCounted.new()
	director.pin_medium("letter", pin)
	pictures.set_script_text(WORDS)
	var card = pictures._own_card()
	var section = pictures.pipeline()
	var listed := _prompts(pictures.list()._images)
	_ok(card != null and card.visible and listed == ["A harbor at dawn.", "A storm over the bay."] and section.shown(),
		"pinned to a letter: the card stands, listing its pictures and not its sketch, and its section is listed: %s" % str(listed))
	await process_frame
	var all = pictures.list()._all
	_ok(all.visible and all.text == "Generate all (2)" and all.disabled, "Generate all says how many have none - read-only, grayed: %s" % all.text)
	all.pressed.emit()
	_ok(pictures.list()._status.text.contains("read-only"), "pressed read-only, it says why: %s" % pictures.list()._status.text)
	director.pin_medium("full", pin)
	pictures._follow(false)
	_ok(not card.visible and not section.shown() and pictures.list()._images.is_empty(),
		"the control: under the full frame the card and its section are put away")
	# what the episode's agents painted: shown whatever the medium, and the card stood for it
	var painted := "user://pictures_card_made_check.png"
	Image.create(8, 12, false, Image.FORMAT_RGB8).save_png(painted)
	var feed := MadeFeed.new()
	feed.list = [{"path": ProjectSettings.globalize_path(painted), "label": "Picture to copy", "row": "image:face", "group": ""}]
	section.episode = func() -> EpisodeFeed: return feed
	pictures._stand()
	_ok(card.visible and pictures.made().visible and pictures.made().shown().size() == 1 and pictures.made()._flow.get_child_count() == 1,
		"under the full frame the card stands for a picture the episode's agents made, its thumbnail listed")
	feed.list = []
	pictures._stand()
	_ok(not card.visible and not pictures.made().visible, "the control: with none made, it is put away again")
	section.episode = Callable()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(painted))
	director.pin_medium("book", pin)
	pictures._follow(false)
	_ok(card.visible and section.shown() and pictures.list()._images.size() == 3, "under a novel both are back, the sketch with them")
	var made := "user://pictures_card_check.png"
	Image.create(4, 4, false, Image.FORMAT_RGB8).save_png(made)
	Illustrations.use_for_test({"index": {Manuscript.image_key("A harbor at dawn."): {"versions": [{"file": made, "sig": ""}], "current": 0}}}, true)
	director.pin_medium("tablet", pin)
	pictures.set_script_text(TABLET)
	pictures.list()._refresh()
	_ok(all.text == "Generate all" and all.disabled, "a page captured is never counted, and with every picture made there is none to paint: %s" % all.text)
	director.unpin_medium(pin)
	panel.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(made))


## A clip's row offers Import… and no Generate, and is never owed; the same picture without `clip` is.
func _clip_rows() -> void:
	Illustrations.use_for_test({}, true)
	var im := _clip_entry()
	var plain := im.duplicate()
	plain.erase("clip")
	var panel = load("res://src/media/illustration_panel.gd").new()
	root.add_child(panel)
	panel.set_pictures([im])
	var row: Control = panel._row(im)
	var said := _buttons(row)
	_ok(said.has("Import…") and said.has("Generate") and panel._owed().size() == 1 and panel._missing(),
		"a clip's row offers Generate (a painted loop) and Import…, and is owed until it has one: %s" % str(said))
	var steps: Array = panel._step_rows()
	_ok(steps.size() == 1 and String(steps[0].again).contains("loop") and String(steps[0].said) == "clip: dog-tail.webm",
		"...its Pipeline row's ⟳ paints the loop, and names the video its script wants: %s" % (String(steps[0].said) if not steps.is_empty() else "none"))
	row.free()
	panel.set_pictures([plain])
	row = panel._row(plain)
	said = _buttons(row)
	_ok(said.has("Generate") and said.has("Import…") and panel._owed().size() == 1 and panel._missing(),
		"the same picture without `clip` is owed and offers Generate as well: %s" % str(said))
	row.free()
	panel.queue_free()
	await process_frame


## Flip on a picture's entry: grayed with nothing painted, none on a page captured; ticked, the picture is flipped and its
## entry says so.
func _flip_row() -> void:
	Illustrations.use_for_test({}, false)
	var key := Manuscript.image_key("A harbor at dawn.")
	var im := {"kind": "image", "prompt": "A harbor at dawn.", "placement": "inline", "key": key}
	var page := {"kind": "image", "prompt": "www.shop.test/item/42", "placement": "page", "url": "https://www.shop.test/item/42",
		"key": "a-page-captured"}
	var panel = load("res://src/media/illustration_panel.gd").new()
	root.add_child(panel)
	panel.set_pictures([im, page])
	var row: Control = panel._row(im)
	var of_page: Control = panel._row(page)
	var flip := _check_of(row, "Flip")
	_ok(flip != null and flip.disabled and not flip.button_pressed and _check_of(of_page, "Flip") == null,
		"a picture's entry offers Flip, grayed with nothing painted; a page captured has none (the control)")
	row.free()
	of_page.free()
	var src := ProjectSettings.globalize_path("user://pictures_card_flip_check.png")
	Image.create(8, 4, false, Image.FORMAT_RGB8).save_png(src)
	Illustrations.import_file(im, src)
	var plain := Illustrations.path_for(key)
	row = panel._row(im)
	flip = _check_of(row, "Flip")
	_ok(flip != null and not flip.disabled and not flip.button_pressed, "with a picture it can be ticked")
	if flip != null:
		flip.button_pressed = true
	await _mirrored(key)
	row.free()
	row = panel._row(im)
	flip = _check_of(row, "Flip")
	_ok(Illustrations.is_flipped(key) and Illustrations.path_for(key) != plain and flip != null and flip.button_pressed
		and (row as EntryCard).line_label.text.contains("flipped"),
		"ticked, the picture served is its mirrored copy, and its entry says flipped: %s" % (row as EntryCard).line_label.text)
	if flip != null:
		flip.button_pressed = false
	_ok(not Illustrations.is_flipped(key) and Illustrations.path_for(key) == plain, "unticked, it is served as made again")
	row.free()
	Illustrations.delete_version(key, 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://illustrations_test").path_join(key))
	DirAccess.remove_absolute(src)
	panel.queue_free()
	await process_frame
	Illustrations.use_for_test({}, true)


## Until [param key]'s mirrored copy is written (a guard against a hang, never a measure of the machine).
func _mirrored(key: String) -> void:
	var until := Time.get_ticks_msec() + 60000
	while Illustrations.flipping(key) and Time.get_ticks_msec() < until:
		Illustrations.pump()
		await process_frame


## The check box saying [param words] under [param node], or null.
static func _check_of(node: Node, words: String) -> CheckBox:
	if node is CheckBox and (node as CheckBox).text == words:
		return node as CheckBox
	for c in node.get_children():
		var found := _check_of(c, words)
		if found != null:
			return found
	return null


## A video imported as a clip: decoded in the background into a version of frames, with its sound where it had one.
func _clip_decode() -> void:
	var im := _clip_entry()
	var key := String(im["key"])
	var dir := ProjectSettings.globalize_path(CLIP_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var talking := dir.path_join("talking.mkv")
	var silent := dir.path_join("silent.mkv")
	var broken := dir.path_join("broken.webm")
	OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=size=640x360:rate=25:duration=1",
		"-f", "lavfi", "-i", "sine=frequency=220:duration=1", "-c:v", "mpeg4", "-c:a", "pcm_s16le", "-shortest", talking], [])
	OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=size=320x180:rate=25:duration=21",
		"-c:v", "mpeg4", silent], [])
	var f := FileAccess.open(broken, FileAccess.WRITE)
	f.store_string("no video in here")
	f.close()
	if not FileAccess.file_exists(talking) or not FileAccess.file_exists(silent):
		_ok(false, "the clip fixtures could not be made (is ffmpeg on PATH?)")
		return
	Illustrations.use_for_test({}, true)
	_ok(Illustrations.import_clip(im, talking).contains("read-only"), "a read-only session refuses to import a clip")
	Illustrations.use_for_test({}, false)
	var asked := Illustrations.request_of(im)
	var still := im.duplicate()
	still.erase("clip")
	_ok(String(asked["placement"]) == Illustrations.LOOP and String(Illustrations.request_of(still)["placement"]) == "screen"
		and Illustrations.placement_guide(Illustrations.LOOP).contains("6 CELLS"),
		"a clip is painted as a loop, one sheet of cells (the control: the same words as a still are a screen's picture)")
	await _painted_loop(im)
	var err := Illustrations.import_clip(im, talking)
	_ok(err.is_empty() and Illustrations.status(key) == "running" and Illustrations.activity(key).contains("talking.mkv"),
		"a video imported decodes in the background, its row running and saying so: %s %s" % [err, Illustrations.activity(key)])
	await _decoded(key)
	var c := Illustrations.clip_of(key)
	_ok(not c.is_empty() and int(c["fps"]) == 12 and int(c["frames"]) in [12, 13] and c["size"] == Vector2i(480, 270)
		and c.has("sound") and FileAccess.file_exists(String(c["sound"])),
		"kept as a clip: 12 fps, a second of frames, 480 px wide, its sound beside them: %s %s" % [str(c), Illustrations.error_of(key)])
	_ok(Illustrations.path_for(key) == Illustrations.clip_frame(c, 0) and Illustrations.path_for(key).ends_with("/0000.jpg")
		and Illustrations.clip_frame(c, int(c.get("frames", 0))) == Illustrations.clip_frame(c, 0) and Illustrations.is_imported(key)
		and not Illustrations.is_stale(key), "its picture is its first frame, and past the last it wraps")
	var said: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(c.get("dir", "")).path_join("clip.json")))
	_ok(said is Dictionary and int(said.get("fps", 0)) == 12 and int(said.get("frames", 0)) == int(c.get("frames", -1))
		and said.get("size", []) == [480.0, 270.0] and String(said.get("sound", "")) == "sound.wav",
		"clip.json beside the frames says the same: %s" % str(said))
	var panel_script: GDScript = load("res://src/media/illustration_panel.gd")
	_ok(String(panel_script.call("_clip_label", im)).begins_with("clip, 12 fps, 1."), "the row says it is a clip: %s" % panel_script.call("_clip_label", im))
	Illustrations.import_clip(im, silent)
	await _decoded(key)
	var s := Illustrations.clip_of(key)
	_ok(Illustrations.versions(key).size() == 2 and int(s.get("frames", 0)) == 240 and s.get("size") == Vector2i(320, 180)
		and not s.has("sound") and not FileAccess.file_exists(String(s.get("dir", "")).path_join("sound.wav")),
		"the control: a silent video longer than 20 s keeps 240 frames, its own smaller size and no sound: %s" % str(s))
	Illustrations.select_version(key, 0)
	_ok(Illustrations.clip_of(key).has("sound"), "‹ steps back to the first clip")
	_ok(Illustrations.delete_version(key, 1) and not DirAccess.dir_exists_absolute(String(s.get("dir", "")))
		and Illustrations.versions(key).size() == 1, "✕ takes a clip's folder with it")
	Illustrations.import_clip(im, broken)
	await _decoded(key)
	_ok(Illustrations.versions(key).size() == 1 and Illustrations.status(key) == "ready" and not Illustrations.error_of(key).is_empty(),
		"a file that is no video fails with a reason and keeps nothing: %s" % Illustrations.error_of(key))
	Illustrations.delete_version(key, 0)
	_ok(Illustrations.versions(key).is_empty() and Illustrations.clip_of(key).is_empty() and Illustrations.status(key) == "error",
		"with the last clip deleted there is none")
	var lib := ProjectSettings.globalize_path("user://illustrations_test").path_join(key)
	for g in DirAccess.get_directories_at(lib):
		_ok(false, "left behind in the library: %s" % g)
	DirAccess.remove_absolute(lib)
	for p in [talking, silent, broken]:
		DirAccess.remove_absolute(p)
	DirAccess.remove_absolute(dir)
	Illustrations.use_for_test({}, true)


## A painted loop's sheet, as a painter hands it back: cut into its cells, a frame each in order, at the loop's pace, the
## sheet kept beside them; made under the look, a version like any other (the control: a cell's middle is its own color).
func _painted_loop(im: Dictionary) -> void:
	var key := String(im["key"])
	var cells := Illustrations.LOOP_CELLS
	var sheet := Image.create(1536, 1024, false, Image.FORMAT_RGB8)
	var colors: Array = []
	for k in cells.x * cells.y:
		colors.append(Color.from_hsv(float(k) / float(cells.x * cells.y), 0.8, 0.9))
		var cw := 1536 / cells.x
		var ch := 1024 / cells.y
		sheet.fill_rect(Rect2i((k % cells.x) * cw, (k / cells.x) * ch, cw, ch), colors[k])
	var err := Illustrations._keep_loop(key, sheet, {"sig": Illustrations.current_signature("image"), "backend": "test", "description": String(im["prompt"])})
	var c := Illustrations.clip_of(key)
	var right := true
	for k in int(c.get("frames", 0)):
		var f := Image.load_from_file(Illustrations.clip_frame(c, k))
		var mid := f.get_pixel(f.get_width() / 2, f.get_height() / 2) if f != null else Color.BLACK
		right = right and f != null and absf(mid.h - (colors[k] as Color).h) < 0.03
	var panel_script: GDScript = load("res://src/media/illustration_panel.gd")
	_ok(err.is_empty() and int(c.get("frames", 0)) == cells.x * cells.y and int(c.get("fps", 0)) == Illustrations.LOOP_FPS and right
		and FileAccess.file_exists(String(c.get("dir", "")).path_join(Illustrations.LOOP_SHEET)) and not Illustrations.is_imported(key)
		and not Illustrations.is_stale(key) and String(panel_script.call("_clip_label", im)) == "painted loop, 6 frames at 8 fps",
		"a painted sheet is cut into a loop, a cell a frame in order, its sheet kept: %s %s" % [err, str(c)])
	Illustrations.delete_version(key, 0)


## Until [param key]'s decode ends (a guard against a hang, never a measure of the machine).
func _decoded(key: String) -> void:
	var until := Time.get_ticks_msec() + 120000
	while Illustrations.status(key) == "running" and Time.get_ticks_msec() < until:
		Illustrations.pump()
		await process_frame


static func _clip_entry() -> Dictionary:
	var im: Dictionary = CLIP.duplicate()
	im["key"] = Manuscript.image_key(String(im["prompt"]))
	return im


## The words on every button under [param node].
static func _buttons(node: Node) -> Array:
	var out: Array = []
	if node is Button:
		out.append((node as Button).text)
	for c in node.get_children():
		out.append_array(_buttons(c))
	return out


## An episode whose agents painted what the gate says.
class MadeFeed extends EpisodeFeed:
	var list: Array = []

	func made_pictures() -> Array:
		return list


## How many picture lists [param node] holds.
static func _lists(node: Node) -> int:
	var script: Script = node.get_script()
	var n := 1 if script != null and script.resource_path == "res://src/media/illustration_panel.gd" else 0
	for c in node.get_children():
		n += _lists(c)
	return n


static func _prompts(rows: Array) -> Array:
	return rows.map(func(r: Dictionary) -> String: return String(r["prompt"]))


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1
