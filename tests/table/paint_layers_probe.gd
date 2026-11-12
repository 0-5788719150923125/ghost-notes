extends SceneTree

## NOT a gate. The painting laid in layers ([PaintLayers]; next/painted_surface.md, "The painting is the design") on an episode's own
## painted face: its `face_ref.png` painted again with its table's creams (a powder or a gloss is a finish, not a color of it) and the
## station's tools, widest first - each pass's canvas, the last, and the picture side by side, and how far each stands from it.
##
##   godot --headless --path . --log-file <scratch>/x.log --script res://tests/table/paint_layers_probe.gd -- \
##       --dir=<user://table/<show>/<seed> as a path> --out=<dir> [--bare=#c89e80]
##
## Read-only: the episode is read, never written; the pictures go to `--out`.

const TOOLS := [
	{"name": "sponge", "kind": "dab", "width": 14.0},
	{"name": "flat brush", "kind": "stroke", "width": 10.0},
	{"name": "round brush", "kind": "stroke", "width": 5.0},
	{"name": "liner brush", "kind": "stroke", "width": 1.2},
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := _arg(args, "dir", "")
	var out := _arg(args, "out", "")
	var ref := Image.load_from_file(dir.path_join("face_ref.png"))
	var face: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("face.json")))
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("table.json")))
	if ref == null or face.is_empty() or table.is_empty() or out.is_empty():
		print("paint_layers_probe: --dir=<an episode with face_ref.png, face.json, table.json> and --out=<dir> are needed")
		quit(2)
		return
	var px := float(face.get("px", 3.0))
	var mm := Vector2(float(ref.get_width()), float(ref.get_height())) / px
	var mats: Variant = table.get("materials", {})
	var paints: Array = []
	for pair in (mats as Array if mats is Array else (mats as Dictionary).keys().map(func(k: String) -> Array: return [k, mats[k]])):
		var nm := String((pair as Array)[0])
		var md: Dictionary = (pair as Array)[1]
		# (...its creams: a powder, a glitter (it plays) or a gloss (all shine) is a finish over the painting, not a color of it)
		if String(md.get("kind", "")) == "cream" and float(md.get("polish", 0.0)) < 0.9 and String(md.get("play", "")).is_empty():
			paints.append({"name": nm, "color": Color.html(String(md["color"]))})
	var bare := Color.html(_arg(args, "bare", "#c89e80"))
	print("paint_layers_probe: %s, %.0f x %.0f mm, %d paints: %s" % [dir.get_file(), mm.x, mm.y, paints.size(),
		", ".join(paints.map(func(p: Dictionary) -> String: return String(p["name"])))])
	var t0 := Time.get_ticks_msec()
	var res := PaintLayers.plan(ref, mm, bare, paints, TOOLS)
	print("paint_layers_probe: planned in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var by_tool := {}
	# (...the foundation counted apart from the sponge's later dabs)
	for l in res["layers"]:
		var ld: Dictionary = l
		var key := "foundation" if bool(ld.get("base", false)) else String(ld["tool"])
		if not by_tool.has(key):
			by_tool[key] = {"layers": 0, "strokes": 0, "paints": {}}
		by_tool[key]["layers"] += 1
		by_tool[key]["strokes"] += int(ld["marks"])
		(by_tool[key]["paints"] as Dictionary)["%s %.0f%%" % [ld["paint"], float(ld["alpha"]) * 100.0]] = true
	for p in res["passes"]:
		var pd: Dictionary = p
		var bt: Dictionary = by_tool.get(String(pd["tool"]), {"layers": 0, "strokes": 0, "paints": {}})
		print("  after the %-12s off %.1f on average - %d layers, %d strokes: %s" % [pd["tool"], float(pd["off"]), int(bt["layers"]), int(bt["strokes"]),
			", ".join(PackedStringArray((bt["paints"] as Dictionary).keys()))])
	print("  the canvas against the picture itself: off %.1f on average, %.1f%% of the surface still over %.0f off" % [float(res["off"]),
		float(res["left"]) * 100.0, PaintLayers.NEED])
	DirAccess.make_dir_recursive_absolute(out)
	var canvas: Image = res["canvas"]
	var w := canvas.get_width()
	var h := canvas.get_height()
	var shown := ref.duplicate() as Image
	shown.convert(Image.FORMAT_RGBA8)
	shown.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var frames: Array = [shown]
	for p in res["passes"]:
		frames.append((p as Dictionary)["canvas"])
	frames.append(canvas)
	var strip := Image.create(w * frames.size(), h, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.08, 0.08, 0.08, 1.0))
	for i in frames.size():
		var f: Image = frames[i]
		f.convert(Image.FORMAT_RGBA8)
		strip.blend_rect(f, Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	strip.save_png(out.path_join("layers.png"))
	canvas.save_png(out.path_join("canvas.png"))
	print("paint_layers_probe: the picture, each pass and the last -> %s" % out.path_join("layers.png"))
	quit(0)


func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	for a in args:
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return fallback
