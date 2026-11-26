extends SceneTree

## The library's props ([ThingLibrary], on [Library]'s own root - never the author's), with no renderer.
##
##   godot --headless --path . --script res://tests/table/thing_library_check.gd
##
## - A prop is kept by what it is, whose it was taken off its name ("Mike's glass of water" is a glass of water); the control, a
##   common noun's possessive ("a wizard's hat"), stays.
## - A prop kept is the thing alone: its parts, its scale (unless 1) and the materials they use - never where it stood, its group,
##   why it was there or that it held the cards. The control: a material on the table its parts do not use is not kept.
## - Its hash is what it is: the same prop under another name, placed and turned elsewhere, hashes the same; the control, one
##   material's color changed, does not.
## - Kept, it is read back, listed, found as kept by its hash, renamed (never over another prop's name; its former name still finds it, a name never had finds nothing) and removed to the trash
##   seam ([member Library.discard]), the author's trash never touched.
## - Put on a table it is named its own there and stands where it is told (null: placed by whoever sets the table); a material the
##   table holds the same is shared, one the table holds otherwise is renamed and the prop's parts follow the new name - the control,
##   the same material, is not renamed. [method ThingLibrary.given] writes kept props as fixed things with no `at`.
## - A file from anywhere is bounded ([method ThingLibrary.sanitized]): 60,000 parts become at most [constant Props.MAX_PARTS], a NaN
##   size a number, a path where a material goes no file read, a key a prop does not keep dropped; a file with nothing buildable is
##   refused. Export and import round-trip a prop.
## - Search finds a prop by its name, line, shapes and materials (a plural finds the singular); the control, words it shares none
##   of, finds nothing.

const ROOT := "user://thing_library_check"

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	Library.root = ROOT
	var trashed: Array = []
	Library.discard = func(path: String) -> int:
		trashed.append(path)
		return DirAccess.remove_absolute(path)
	_rmrf(ProjectSettings.globalize_path(ROOT))
	_entries()
	_hashes()
	_shelf(trashed)
	_put_on()
	_bounded()
	_search()
	_rmrf(ProjectSettings.globalize_path(ROOT))
	Library.root = Library.ROOT
	Library.discard = Callable()
	print("thing_library_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _cup(name := "tin cup", color := "#9a9a9a") -> Dictionary:
	return {"name": name, "at": [12.0, -4.0], "turn": 30.0, "place": "back left", "group": "drink", "why": "for the tea",
		"holds_cards": false, "scale": 1.0,
		"parts": [{"shape": "lathe", "profile": [[0, 0], [3, 0], [3.2, 8], [2.8, 8], [2.6, 0.5], [0, 0.5]], "material": "tin"},
			{"shape": "tube", "path": [[3, 2, 0], [5, 4, 0], [3, 6, 0]], "radius": 0.4, "material": "tin"}]}


func _mats(color := "#9a9a9a") -> Dictionary:
	return {"tin": {"kind": "metal", "color": color}, "walnut": {"kind": "wood", "color": "#5a3b22"}}


func _entries() -> void:
	var e := ThingLibrary.entry_of(_cup(), _mats(), "a small tin cup")
	var t: Dictionary = e["thing"]
	_ok(not t.has("at") and not t.has("turn") and not t.has("place") and not t.has("group") and not t.has("why") and not t.has("holds_cards"),
		"a prop kept is the thing alone, never where it stood or why (%s)" % str(t.keys()))
	_ok(not t.has("scale"), "a scale of 1 is not kept")
	_ok(ThingLibrary.generic("Mike's glass of water") == "glass of water" and ThingLibrary.generic("Old Tom’s pipe") == "pipe",
		"a prop is kept by what it is, not whose it was")
	_ok(ThingLibrary.generic("a wizard's hat") == "a wizard's hat" and ThingLibrary.generic("Tanner's") == "Tanner's",
		"control: a common noun's possessive stays, and a name that would be left empty is kept whole")
	var big := _cup()
	big["scale"] = 1.5
	_ok(float((ThingLibrary.entry_of(big, _mats())["thing"] as Dictionary).get("scale", 0.0)) == 1.5, "a scale other than 1 is kept")
	var mats: Dictionary = e["materials"]
	_ok(mats.has("tin") and not mats.has("walnut"), "it keeps the materials its parts use - the control: not one they do not (%s)" % str(mats.keys()))
	_ok(String(e["line"]) == "a small tin cup" and String(e["name"]) == "tin cup", "its name and line are kept")
	_ok(ThingLibrary.entry_of({"name": "", "parts": [{}]}, {}).is_empty() and ThingLibrary.entry_of({"name": "x", "parts": []}, {}).is_empty(),
		"a thing with no name or no part is no prop")


func _hashes() -> void:
	var h := ThingLibrary.hash_of(_cup(), _mats())
	var moved := _cup("the same cup elsewhere")
	moved["at"] = [-40.0, 10.0]
	moved["turn"] = -90.0
	moved["why"] = "another reason"
	_ok(ThingLibrary.hash_of(moved, _mats()) == h, "the same prop named, placed and turned otherwise hashes the same")
	_ok(ThingLibrary.hash_of(_cup(), _mats("#c08040")) != h, "the control: a material's color changed hashes otherwise")
	var unused := _mats()
	(unused["walnut"] as Dictionary)["color"] = "#000000"
	_ok(ThingLibrary.hash_of(_cup(), unused) == h, "a material its parts do not use counts for nothing")


func _shelf(trashed: Array) -> void:
	_ok(ThingLibrary.keep(_cup(), _mats(), "a small tin cup").is_empty(), "a prop is kept")
	_ok(ThingLibrary.names() == ["tin cup"], "it is listed (%s)" % str(ThingLibrary.names()))
	var e := ThingLibrary.read("tin cup")
	_ok(not e.is_empty() and String(e["hash"]) == ThingLibrary.hash_of(_cup(), _mats()), "it is read back, its hash its own")
	_ok(ThingLibrary.kept_as(ThingLibrary.hash_of(_cup("named otherwise"), _mats())) == "tin cup", "it is found as kept by what it is")
	_ok(ThingLibrary.kept_as(ThingLibrary.hash_of(_cup(), _mats("#ff0000"))).is_empty(), "the control: another prop is not found as it")
	var renamed := _cup()
	ThingLibrary._rename_materials(renamed, {"tin": "tin (tin cup)"})
	var rmats := {}
	for m in _mats():
		rmats["tin (tin cup)" if m == "tin" else m] = _mats()[m]
	_ok(ThingLibrary.materials_used(renamed) != ThingLibrary.materials_used(_cup()) and ThingLibrary.kept_as(ThingLibrary.hash_of(renamed, rmats)) == "tin cup",
		"its materials renamed, as a table renames one it has another of, it is still found as kept")
	var stale := ThingLibrary.read("tin cup")
	stale["hash"] = "0000000000000000"
	ThingLibrary._write(stale)
	_ok(String(ThingLibrary.read("tin cup")["hash"]) == ThingLibrary.hash_of(_cup(), _mats()), "a hash kept in its file is worked out again, never trusted")
	_ok(ThingLibrary.keep({"name": "jug", "parts": [{"shape": "box", "size": [5, 5, 5], "material": "walnut"}]}, _mats()).is_empty(), "another is kept")
	_ok(not ThingLibrary.rename("tin cup", "jug", "").is_empty(), "a prop is never renamed over another's name")
	_ok(ThingLibrary.rename("tin cup", "Pewter Cup", "the host's cup").is_empty() and ThingLibrary.names() == ["jug", "Pewter Cup"],
		"a prop is renamed (%s)" % str(ThingLibrary.names()))
	var r := ThingLibrary.read("Pewter Cup")
	_ok(String((r["thing"] as Dictionary)["name"]) == "Pewter Cup" and String(r["line"]) == "the host's cup"
		and not FileAccess.file_exists(ThingLibrary.dir().path_join(Manuscript.slug("tin cup") + ".json")),
		"renamed, its thing and line follow and the old file goes")
	_ok(String(ThingLibrary.read("tin cup").get("name", "")) == "Pewter Cup" and (r["aka"] as Array) == ["tin cup"],
		"its former name still finds it, kept among those it was known as")
	_ok(ThingLibrary.read("no such cup").is_empty(), "the control: a name nobody ever had finds nothing")
	_ok(ThingLibrary.remove("jug").is_empty() and ThingLibrary.names() == ["Pewter Cup"] and trashed.size() == 1 and String(trashed[0]).ends_with("jug.json"),
		"a prop removed goes to the trash seam (%s)" % str(trashed))
	_ok(not ThingLibrary.remove("jug").is_empty(), "removing one not kept says so")


func _put_on() -> void:
	var e := ThingLibrary.read("Pewter Cup")
	var table := {"things": [{"name": "Pewter Cup", "parts": []}], "materials": {"tin": {"kind": "metal", "color": "#9a9a9a"}}}
	var on := ThingLibrary.put_on(table, e, Vector2(-12.0, 4.0))
	var added: Dictionary = (on["things"] as Array).back()
	_ok(String(added["name"]) == "Pewter Cup 2" and added["at"] == [-12.0, 4.0], "put on a table it is named its own there, where it is told (%s)" % str(added.get("name")))
	_ok((on["materials"] as Dictionary).size() == 1 and String((added["parts"][0] as Dictionary)["material"]) == "tin",
		"the control: the same material on the table is shared, not renamed")
	var other := {"things": [], "materials": {"tin": {"kind": "metal", "color": "#ffd700"}}}
	var on2 := ThingLibrary.put_on(other, e, null)
	var t2: Dictionary = (on2["things"] as Array).back()
	var m2 := String((t2["parts"][0] as Dictionary)["material"])
	_ok(m2 != "tin" and (on2["materials"] as Dictionary).has(m2) and String(((on2["materials"] as Dictionary)[m2] as Dictionary)["color"]) == "#9a9a9a"
		and String(((on2["materials"] as Dictionary)["tin"] as Dictionary)["color"]) == "#ffd700",
		"a material the table holds otherwise is renamed, the prop's parts following it (%s)" % m2)
	_ok(not t2.has("at"), "put with no place, it is left for whoever sets the table to place")
	_ok(String((table["things"] as Array)[0]["name"]) == "Pewter Cup" and (table["things"] as Array).size() == 1, "the table handed is not changed")
	var g := ThingLibrary.given(["Pewter Cup", "not kept"])
	_ok((g["things"] as Array).size() == 1 and not ((g["things"] as Array)[0] as Dictionary).has("at") and (g["materials"] as Dictionary).has("tin"),
		"given: kept props as fixed things with no place, a name not kept left out")


func _bounded() -> void:
	var many: Array = []
	for i in 60000:
		many.append({"shape": "box", "size": [1, 1, 1], "material": "res://project.godot"})
	var e := ThingLibrary.sanitized({"name": "a heap", "thing": {"name": "a heap", "parts": many, "script": "res://src/app/main.gd",
		"at": [1, 2]}, "materials": {}})
	var parts: Array = (e.get("thing", {}) as Dictionary).get("parts", [])
	_ok(not e.is_empty() and parts.size() <= Props.MAX_PARTS, "60,000 parts become at most %d (%d)" % [Props.MAX_PARTS, parts.size()])
	_ok(not (e["thing"] as Dictionary).has("script") and not (e["thing"] as Dictionary).has("at"), "a key a prop does not keep is dropped")
	var built := Props.sanitize({"things": [e["thing"]], "materials": e["materials"]}, [])
	var used := String((((built["things"] as Array)[0] as Dictionary)["parts"] as Array)[0]["material"])
	_ok(not (built["materials"] as Dictionary).has("res://project.godot") and (built["materials"] as Dictionary).has(used),
		"a path where a material goes is only a name: built, it is a plain material (%s)" % used)
	var nan := ThingLibrary.sanitized({"thing": {"name": "odd", "parts": [{"shape": "box", "size": [NAN, INF, -5.0], "at": [NAN, 0, 0]}]}})
	var p: Dictionary = ((nan.get("thing", {}) as Dictionary).get("parts", [{}]) as Array)[0] if not nan.is_empty() else {}
	var finite := true
	for v in (p.get("size", []) as Array) + (p.get("at", []) as Array):
		finite = finite and is_finite(float(v))
	_ok(not nan.is_empty() and finite, "a NaN or infinite size is made a number (%s)" % str(p.get("size")))
	_ok(ThingLibrary.sanitized({"thing": {"name": "nothing", "parts": [{"shape": "teleporter"}]}}).is_empty(), "nothing buildable is refused")
	var out := ProjectSettings.globalize_path(ROOT).path_join("cup" + ThingLibrary.EXPORT)
	_ok(ThingLibrary.export_to("Pewter Cup", out).is_empty() and FileAccess.file_exists(out), "a prop is exported to a file")
	ThingLibrary.remove("Pewter Cup")
	var why: Array = []
	_ok(ThingLibrary.import_from(out, why) == "Pewter Cup" and not ThingLibrary.read("Pewter Cup").is_empty(), "and imported again (%s)" % str(why))
	var junk := ProjectSettings.globalize_path(ROOT).path_join("junk.prop.json")
	var f := FileAccess.open(junk, FileAccess.WRITE)
	f.store_string("{\"recipe\": \"not a prop\"}")
	f.close()
	why.clear()
	_ok(ThingLibrary.import_from(junk, why).is_empty() and not why.is_empty(), "a file holding no prop is refused, and says why")


func _search() -> void:
	ThingLibrary.keep({"name": "brass candlestick", "parts": [{"shape": "lathe", "profile": [[0, 0], [4, 0], [1, 15], [0, 15]], "material": "brass"}]},
		{"brass": {"kind": "metal", "color": "#b08d57"}}, "a tall candlestick for a taper")
	ThingLibrary.keep({"name": "stone mortar", "parts": [{"shape": "lathe", "profile": [[0, 0], [5, 0], [5, 6], [0, 6]], "material": "granite"}]},
		{"granite": {"kind": "stone", "color": "#777777"}}, "a heavy mortar for grinding")
	var a := ThingLibrary.search("a candlestick for the left")
	_ok(not a.is_empty() and String((a[0] as Dictionary)["name"]) == "brass candlestick", "a prop is found by its name (%s)" % str(a.map(func(x: Dictionary) -> String: return String(x["name"]))))
	var b := ThingLibrary.search("grinding stones")
	_ok(not b.is_empty() and String((b[0] as Dictionary)["name"]) == "stone mortar", "by its line, its material's kind and a plural")
	_ok(ThingLibrary.search("velvet umbrella").is_empty(), "the control: words it shares none of find nothing")


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
