extends Node

## Not a gate: what the paper engineer is shown ([PopupStudio]) - a note's spreads photographed from the views it may ask for.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/media/popup_studio_probe.gd 200 --doc <note.md> --out <dir>/s \
##       --scenes 0,1 [--design <popup.json>]
##
## Writes `<out>_<scene>_<view>.png`. Asserts only that a picture came back for each view.

var _doc := ""
var _out := "user://popup_studio"
var _scenes: Array = [0]
var _design := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--doc": _doc = args[i + 1]
			"--out": _out = args[i + 1]
			"--design": _design = args[i + 1]
			"--scenes":
				_scenes = []
				for s in String(args[i + 1]).split(","):
					_scenes.append(int(s))
	var body := FileAccess.get_file_as_string(_doc)
	var design: Variant = JSON.parse_string(FileAccess.get_file_as_string(_design)) if not _design.is_empty() else {}
	var doc := {"source": body, "title": FrontMatter.field_of(body, "title"), "popup": design if design is Dictionary else {}}
	var fails := 0
	for sc in _scenes:
		var shots: Array = await PopupStudio.look(doc, int(sc), PopupStudio.VIEWS)
		for i in shots.size():
			var path := "%s_%d_%s.png" % [_out, int(sc), String(PopupStudio.VIEWS[i])]
			(shots[i] as Image).save_png(path)
			print("popup_studio_probe: %s" % path)
		if shots.size() != PopupStudio.VIEWS.size():
			fails += 1
			print("popup_studio_probe: scene %d gave %d pictures" % [int(sc), shots.size()])
	# ...and as the engineer asks for it, through its tools
	var tools := PopupTools.new()
	tools.body = func() -> String: return body
	tools.document = func() -> Dictionary: return {}
	var res: Dictionary = await tools.call_tool("look", {"scene": int(_scenes[0]), "views": ["front"]})
	if (res.get("images", []) as Array).size() != 1:
		fails += 1
		print("popup_studio_probe: the engineer's look gave %s" % str(res))
	else:
		(res["images"][0] as Image).save_png("%s_tools.png" % _out)
	print("popup_studio_probe: %s" % ("ALL OK" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit(1 if fails > 0 else 0)
