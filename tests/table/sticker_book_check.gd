extends SceneTree

## sticker_book_check - the night's book as a sticker book (next/sticker_book.md): a page is a set with its cast stuck on it in poses,
## each painted once and laid again. Holds, each against a control:
##
## - THE LEDGER: a page names a set; a new set, or someone drawn for the first time, comes with its looks, and after that by name alone
##   (control: the same page with the looks left out is refused, and nothing happened); the camera is close on one of the cast or nobody;
##   a crowd is refused; a pose said in words is kept as words, a row's by its key; only effects that are rows are kept.
## - THE GATHER: each set, character, pose (but standing, which the model is) and thing listed once, a character's looks its figure's
##   where its picture gave none; a page says its set and its cast by name. Control: a painted page (looks alone) gathers as it did.
## - THE LAYOUT: one character stands to one side of the middle facing into the frame; two face each other, the left one facing right;
##   a frame never leaves its set and is the show's frame's shape; a page after another on its set stands where it stood unless told
##   `where` (control: a page told `where: right` stands right); a close page frames tighter than a wide one; a close pose is a face
##   over the frame, and nobody else stands on the set behind it; a row too wide for a portrait frame steps back to fit.
## - THE LIBRARY: a character kept with its poses is found by name and looks, or by name alone (control: other looks are not it), a pose
##   only from the very model kept (control: another model's digest finds none); a kept set is found by name; the Dex shows each.
## - ANGLES AND CUTS: a page stands on its angle of its set (control: an angle never painted stands on the wide); a page cuts to its
##   framing whatever came before, and its cast stands still - only a page told `glide` moves from the framing before it; a close shot
##   of a creature wider than it is tall frames all of it.
## - THE OPENING: no page comes up before the table has been seen from its head; several placed before then are one page, the latest;
##   a page placed after it comes up at its own moment; the opening's camera holds over every other until then.
##
##     godot --headless --path . --script tests/table/sticker_book_check.gd

const ROOT := "user://_sticker_book_check"
var fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	OS.execute("rm", ["-rf", ProjectSettings.globalize_path(ROOT)])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	_ledger()
	_gather()
	_layout()
	_angles()
	_library()
	_opening()
	OS.execute("rm", ["-rf", ProjectSettings.globalize_path(ROOT)])
	print("sticker_book_check: ", "ok" if fails == 0 else "%d failed" % fails)
	quit(1 if fails > 0 else 0)


func _ledger() -> void:
	var g := GameLedger.new()
	var n := g.events.size()
	_check(not bool(g.page({"cast": []})["ok"]), "a page is set somewhere")
	_check(not bool(g.page({"set": "The Yard", "cast": []})["ok"]) and g.events.size() == n, "a new set says what it looks like, and nothing happened")
	_check(not bool(g.page({"set": "The Yard", "looks": "a muddy yard", "cast": [{"who": "Bea", "pose": "point"}]})["ok"]), "someone first drawn says what they look like")
	var ok := g.page({"set": "The Yard", "looks": "a muddy yard", "cast": [{"who": "Bea", "pose": "Point", "looks": "a tall woman", "height": 180},
		{"thing": "A Cake", "looks": "a lopsided cake"}], "close": "a cake", "fx": ["lines", "fireworks", "lines"], "where": "left"})
	_check(bool(ok["ok"]), "a page with its looks is shown: %s" % ok.get("words", ""))
	var e: Dictionary = ok["event"] if bool(ok["ok"]) else {}
	_check(String(e.get("set_looks", "")) == "a muddy yard" and String(e.get("close", "")) == "A Cake" and String(e.get("where", "")) == "left", "its set, close and where are kept")
	_check(e.get("fx", []) == ["lines"], "only effects that are rows, once: %s" % str(e.get("fx", [])))
	_check(String(((e.get("cast", [{}]) as Array)[0] as Dictionary).get("pose", "")) == "point", "a row's pose by its key")
	var again := g.page({"set": "the yard", "cast": [{"who": "bea", "pose": "doing a little dance"}]})
	_check(bool(again["ok"]), "named again, a set and a character need nothing more: %s" % again.get("words", ""))
	_check(String(((again["event"] as Dictionary)["cast"] as Array)[0]["pose"]) == "own:doing a little dance", "a pose in words is kept as words")
	_check(not (again["event"] as Dictionary).has("set_looks"), "a set already drawn is not drawn again")
	_check(not bool(g.page({"set": "The Yard", "cast": [{"who": "Bea"}], "close": "Milo"})["ok"]), "the camera is close only on one of the cast")
	var crowd: Array = []
	for i in GameLedger.PAGE_CAST_MOST + 1:
		crowd.append({"who": "Bea"} if i == 0 else {"thing": "T%d" % i, "looks": "a thing"})
	_check(not bool(g.page({"set": "The Yard", "cast": crowd})["ok"]), "a crowd is refused")
	g.map_down("The Field", "a field", [10, 10])
	g.place("Milo", [0, 0], "a short man")
	_check(bool(g.page({"set": "The Yard", "cast": [{"who": "Milo", "pose": "shrug"}]})["ok"]), "a figure on the board is drawn as it was set down")
	_check(g.describe().contains("SETS DRAWN SO FAR: The Yard"), "what is drawn is in the state the game master reads")


func _events() -> Array:
	var g := GameLedger.new()
	g.map_down("The Field", "a field", [10, 10])
	g.place("Milo", [0, 0], "a short man in a hat")
	g.page({"set": "The Yard", "looks": "a muddy yard", "cast": [{"who": "Milo", "pose": "stand"}, {"who": "Bea", "pose": "point", "looks": "a tall woman", "height": 180}]})
	g.page({"set": "The Yard", "cast": [{"who": "Milo", "pose": "shock"}, {"who": "Bea", "pose": "point"}], "fx": ["shake"]})
	g.page({"set": "The Yard", "cast": [{"who": "Milo", "pose": "face_shock"}], "close": "Milo"})
	g.page({"set": "The Barn", "looks": "a dark barn", "cast": [{"thing": "A Cake", "looks": "a cake", "height": 30}, {"who": "Bea", "pose": "cheer"}]})
	g.page({"set": "The Yard", "where": "right", "cast": [{"who": "Bea", "pose": "stand"}]})
	g.picture("Old", "a painted page", [])
	return g.events


func _gather() -> void:
	var b := GameBoard.gather(_events(), PackedStringArray(["Dell", "Bea"]), {}, {})
	_check((b["sets"] as Array).size() == 2 and String((b["sets"][1] as Dictionary)["name"]) == "The Barn", "each set listed once: %s" % str(b.get("sets")))
	_check((b["cast"] as Array).size() == 2, "each character once")
	var milo: Dictionary = (b["cast"] as Array)[0]
	_check(String(milo["looks"]) == "a short man in a hat", "a character's looks its figure's where its picture gave none")
	_check(is_equal_approx(float(((b["cast"] as Array)[1] as Dictionary)["height"]), 180.0), "a height kept")
	var poses: Array = (b["poses"] as Array).map(func(q: Dictionary) -> String: return "%s/%s" % [q["who"], q["pose"]])
	_check(poses == ["Bea/point", "Milo/shock", "Milo/face_shock", "Bea/cheer"], "each pose once, standing none: %s" % str(poses))
	_check((b["things"] as Array).size() == 1 and float((b["things"][0] as Dictionary)["height"]) == 30.0, "each thing once")
	var pages: Array = b["pages"]
	_check(pages.size() == 6 and String((pages[0] as Dictionary)["set"]) == "The Yard" and not (pages[0] as Dictionary)["cast"][1].has("looks"), "a page says its set and cast by name")
	_check(String((pages[5] as Dictionary).get("looks", "")) == "a painted page" and not (pages[5] as Dictionary).has("set"), "control: a painted page gathers as it did")
	var plain := GameBoard.gather([{"id": 1, "kind": "picture", "name": "P", "looks": "L"}], PackedStringArray(["Dell"]), {}, {})
	_check(not plain.has("sets") and not StickerBook.composed(plain), "control: a session of painted pages is no sticker book")


## A drawing on a clear ground, [param w] by [param h] of it in a canvas of [param cw] by [param ch], saved at [param file].
func _sticker(file: String, cw: int, ch: int, w: int, h: int) -> void:
	var img := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i((cw - w) / 2, ch - h - 4, w, h), Color(0.6, 0.4, 0.2, 1))
	img.save_png(ProjectSettings.globalize_path(ROOT).path_join(file))


func _book(aspect: float, extra := []) -> StickerBook:
	var b := GameBoard.gather(_events() + extra, PackedStringArray(["Dell", "Bea"]), {}, {})
	var dir := ProjectSettings.globalize_path(ROOT)
	for i in (b["sets"] as Array).size():
		var img := Image.create(1536, 1024, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.3, 0.5, 0.3))
		img.save_png(dir.path_join("set_%d.png" % (i + 1)))
	_sticker("model_1.png", 400, 600, 160, 560)
	_sticker("model_2.png", 400, 600, 150, 580)
	for i in (b["poses"] as Array).size():
		_sticker("pose_%d.png" % (i + 1), 400, 600, 220, 520)
	_sticker("thing_1.png", 300, 300, 200, 160)
	var book := StickerBook.new(b, dir, aspect)
	book.build()
	return book


func _inside(f: Rect2, wide: float) -> bool:
	return f.position.x >= -0.0001 and f.position.y >= -0.0001 and f.end.x <= wide + 0.0001 and f.end.y <= 1.0001


func _layout() -> void:
	var book := _book(16.0 / 9.0)
	var l0 := book.layout(0)
	var ms: Array = l0["members"]
	_check(ms.size() == 2, "two on the first page")
	_check(not bool((ms[0] as Dictionary)["flip"]) and bool((ms[1] as Dictionary)["flip"]), "two face each other: the left one right, the right one left")
	_check(((ms[0] as Dictionary)["rect"] as Rect2).get_center().x < ((ms[1] as Dictionary)["rect"] as Rect2).get_center().x, "left to right as the page lists them")
	var f0: Rect2 = l0["frame"]
	_check(_inside(f0, 1.5), "a frame never leaves its set: %s" % str(f0))
	_check(absf(f0.size.x / f0.size.y - 16.0 / 9.0) < 0.001, "a frame is the show's frame's shape")
	for m in ms:
		_check(f0.encloses((m as Dictionary)["rect"]) or ((m as Dictionary)["rect"] as Rect2).end.y > f0.end.y, "everyone on a wide page is in its frame")
	var l1 := book.layout(1)
	_check(is_equal_approx(float(l1["center"]), float(l0["center"])), "the next page on a set stands where the last stood")
	var l2 := book.layout(2)
	_check(String(l2["face"]) == "who:milo", "a close pose is a face over the frame")
	_check((l2["frame"] as Rect2).size.y < f0.size.y, "a close page frames tighter than a wide one")
	var l4 := book.layout(4)
	_check(float(l4["center"]) > float(l0["center"]), "control: a page told where: right stands to the right: %.2f, %.2f" % [float(l4["center"]), float(l0["center"])])
	var l3 := book.layout(3)
	_check(int(l3["set"]) == 1, "a page on another set is laid on it")
	# ...the nodes posed from show time alone: a page cuts to the next, its cast standing still, a face up, nobody behind it
	book.pose_at(3.02, 1, 3.0, 0, 0.0)
	var cut_frame := book._new.transform
	book.pose_at(3.02, 1, 3.0, -1, 0.0)
	_check(cut_frame.is_equal_approx(book._new.transform), "a page cuts to its own framing at once, whatever came before it")
	var milo: Sprite2D = book._new._members["who:milo"]
	book.pose_at(3.3, 1, 3.0, 0, 0.0)
	var scale_a := milo.scale
	var at_a := milo.position
	book.pose_at(4.9, 1, 3.0, 0, 0.0)
	_check(milo.scale.is_equal_approx(scale_a) and milo.position.is_equal_approx(at_a), "its cast stands still on the set: nobody bounces or breathes")
	book.pose_at(6.5, 2, 6.0, 1, 3.0)
	_check(book._face.visible, "a face is over the frame")
	var behind := false
	for k in book._new._members:
		behind = behind or (book._new._members[k] as Sprite2D).visible
	_check(not behind, "and nobody stands on the set behind it")
	book.pose_at(3.1, 1, 3.0, 0, 0.0)
	_check(not book._face.visible, "control: a wide page has no face over it")
	# a portrait frame: the row too wide for it steps back, and the frame is tall
	var tall := _book(9.0 / 16.0, [{"id": 900, "kind": "picture", "name": "", "set": "The Yard", "cast": [{"who": "Milo", "pose": "stand"}, {"who": "Bea", "pose": "stand"},
		{"thing": "A Cake"}], "fx": []}])
	var lt := tall.layout(6)
	var ft: Rect2 = lt["frame"]
	_check(absf(ft.size.x / ft.size.y - 9.0 / 16.0) < 0.001 and _inside(ft, 1.5), "a portrait frame is tall and on its set: %s" % str(ft))
	var row := Rect2()
	for i in (lt["members"] as Array).size():
		var r: Rect2 = (lt["members"][i] as Dictionary)["rect"]
		row = r if i == 0 else row.merge(r)
	_check(row.size.x <= ft.size.x * 1.001, "a row too wide for a portrait frame steps back to fit: %.3f, %.3f" % [row.size.x, ft.size.x])
	book.viewport.free()
	tall.viewport.free()


## A set seen from its angles, a page that glides, and a creature framed whole.
func _angles() -> void:
	var g := GameLedger.new()
	_check(String(g.page({"set": "The Barn", "looks": "a barn", "angle": "Reverse", "cast": []})["event"].get("angle", "")) == "reverse", "an angle is kept by its key")
	_check(not (g.page({"set": "The Barn", "angle": "upside down", "cast": []})["event"] as Dictionary).has("angle"), "control: a name that is no angle is the wide")
	var b := GameBoard.gather(g.events, PackedStringArray(["Dell"]), {}, {})
	_check((b["angles"] as Array).size() == 1 and String((b["angles"][0] as Dictionary)["angle"]) == "reverse", "each angle of a set but its wide is painted once")
	var dir := ProjectSettings.globalize_path(ROOT)
	var game := {"sets": [{"name": "The Barn", "looks": "a barn"}], "angles": [{"set": "The Barn", "angle": "reverse"}],
		"cast": [{"name": "Cow", "looks": "a cow", "height": 150.0}], "poses": [], "things": [],
		"pages": [{"set": "The Barn", "cast": [{"who": "Cow", "pose": "stand"}], "fx": []},
			{"set": "The Barn", "angle": "reverse", "cast": [{"who": "Cow", "pose": "stand"}], "fx": []},
			{"set": "The Barn", "angle": "reverse", "cast": [{"who": "Cow", "pose": "stand"}], "close": "Cow", "fx": ["glide"]},
			{"set": "The Barn", "angle": "side", "cast": [], "fx": []}]}
	var img := Image.create(1536, 1024, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.3, 0.5))
	img.save_png(dir.path_join("set_1.png"))
	img.fill(Color(0.6, 0.3, 0.3))
	img.save_png(dir.path_join("angle_1.png"))
	_sticker("model_1.png", 800, 600, 700, 420)
	var book := StickerBook.new(game, dir, 9.0 / 16.0)
	book.build()
	_check(String(book.layout(0)["backdrop"]) == "0" and String(book.layout(1)["backdrop"]) == "0:reverse", "a page stands on its angle of the set")
	_check(String(book.layout(3)["backdrop"]) == "0", "control: an angle never painted stands on the set's wide")
	var cow: Rect2 = (book.layout(2)["members"][0] as Dictionary)["rect"]
	_check((book.layout(2)["frame"] as Rect2).encloses(cow.grow(-0.001)) or (book.layout(2)["frame"] as Rect2).size.x >= cow.size.x * 0.99,
		"a close shot of a creature wider than tall frames all of it, its head with it")
	book.pose_at(9.1, 2, 9.0, 1, 6.0)
	var gliding := book._new.transform
	book.pose_at(9.1, 2, 9.0, -1, 6.0)
	_check(not gliding.is_equal_approx(book._new.transform), "a page that glides moves from the framing before it")
	book.pose_at(9.0 + StickerBook.GLIDE + 0.01, 2, 9.0, 1, 6.0)
	var arrived := book._new.transform
	book.pose_at(9.0 + StickerBook.GLIDE + 0.01, 2, 9.0, -1, 6.0)
	_check(arrived.is_equal_approx(book._new.transform), "and is at its own once the glide is done")
	book.viewport.free()


func _library() -> void:
	Library.root = ROOT.path_join("library")
	var dir := ProjectSettings.globalize_path(ROOT)
	_check(StickerLibrary.keep_character("Bea", "a tall woman", 180.0, dir.path_join("model_2.png"), "", {"point": dir.path_join("pose_1.png")}).is_empty(), "a character is kept")
	_check(StickerLibrary.find("model", "bea", "a tall woman").get("by", "") == "library", "found by name and looks")
	_check(StickerLibrary.find("model", "Bea", "").get("by", "") == "library", "and by name alone")
	_check(StickerLibrary.find("model", "Bea", "a short man").is_empty(), "control: other looks are someone else")
	_check(StickerLibrary.find("thing", "Bea", "").is_empty(), "control: a character is no thing")
	var model := FileAccess.get_sha256(dir.path_join("model_2.png"))
	_check(not StickerLibrary.find_pose("Bea", "point", model).is_empty(), "a pose of the very model kept")
	_check(StickerLibrary.find_pose("Bea", "point", "0123").is_empty(), "control: a pose drawn from another model is not hers")
	_check(StickerLibrary.kept_character("Bea", dir.path_join("model_2.png")) and not StickerLibrary.kept_character("Bea", dir.path_join("model_1.png")), "kept is the same picture")
	_check(StickerLibrary.keep_set("The Yard", "a muddy yard", dir.path_join("set_1.png")).is_empty() and StickerLibrary.find("set", "The Yard", "a muddy yard").get("by", "") == "library", "a set is kept and found")
	_check(StickerLibrary.characters().size() == 1 and (StickerLibrary.characters()[0] as Dictionary)["poses"] == ["point.png"], "what is kept is listed with its poses")
	# ...and on the Dex's shelves: a character, its pose, a set, each on its own shelf
	var shelf := StickerShelf.new()
	var on := {}
	for o in shelf.offers():
		on[String((o as Dictionary)["shelf"])] = String((o as Dictionary)["name"])
	_check(on.get("cast", "") == "Bea" and String(on.get("poses", "")).begins_with("Bea") and on.get("sets", "") == "The Yard", "the Dex shows each kept thing on its shelf: %s" % str(on))
	shelf.thumbs.settle()
	_check(shelf.picture("cast:Bea") is Image, "its pictures are read, small, off the app's thread")
	Library.root = Library.ROOT


func _opening() -> void:
	var game := {"events": [{"id": 1, "kind": "picture", "pic": 1}, {"id": 2, "kind": "picture", "pic": 2}, {"id": 3, "kind": "picture", "pic": 3}]}
	var g := TableGame.new(null, game, "", 1)
	g.schedule([{"a": {"kind": "begin"}, "t0": 6.0}, {"a": {"kind": "picture", "card": 1}, "t0": 6.4}, {"a": {"kind": "picture", "card": 2}, "t0": 8.0},
		{"a": {"kind": "picture", "card": 3}, "t0": 20.0}])
	var held := g.opening_end()
	_check(is_equal_approx(held, 6.0 + TableGame.OPENING_SEES), "the opening ends once the table has been seen: %.2f" % held)
	var p1 := {"event": 1}
	var p2 := {"event": 2}
	var p3 := {"event": 3}
	_check(is_equal_approx(g._page_at(p1), held) and is_equal_approx(g._page_at(p2), held), "no page comes up before it")
	_check(g._page_end(g._page_at(p1), 1) <= g._page_at(p1), "of two placed before it, the earlier never shows")
	_check(is_equal_approx(g._page_end(g._page_at(p2), 2), 20.0), "the latest shows until the next")
	_check(is_equal_approx(g._page_at(p3), 20.0), "control: a page after the opening comes up at its own moment")
	var top: Dictionary = g._claims.back()
	_check(String(top["sort"]) == "opening" and is_equal_approx(float(top["t1"]), held), "the opening's camera holds over every other until then")
	var at0: Vector3 = g._opening_shot(0.0)["eye"]
	var at1: Vector3 = g._opening_shot(held - TableGame.OPENING_STILL)["eye"]
	var at2: Vector3 = g._opening_shot(held)["eye"]
	_check(at0.distance_to(at1) > 0.0 and at1.is_equal_approx(at2), "it pushes in, and is still for its last moments")
	g.schedule_again({3: 20.0})
	_check(is_equal_approx(g.opening_end(), held), "a schedule of the game's own events keeps the opening")
	g.schedule([{"a": {"kind": "begin"}, "t0": INF}, {"a": {"kind": "picture", "card": 1}, "t0": INF}])
	_check(g.opening_end() == INF and float(g._claims.back()["t1"]) == INF, "an opening the voice has not reached holds the table until it does")
	g.schedule([{"a": {"kind": "spread"}, "t0": 1.0}, {"a": {"kind": "picture", "card": 1}, "t0": 2.0}])
	_check(g.opening_end() == -INF and is_equal_approx(g._page_at(p1), 2.0), "control: a show with no opening holds nothing")
