extends Node

## What a table played hides out of the shot for nobody ([method TableMedium.hide_idle], [ShotReach]), on a fixture of its own:
##
##   - a thing written out past the frame's side that no act names, with no flame and no shadow in the frame, is hidden; the control,
##     the same thing named by an act, stands;
##   - a candle out past the other side gives light and stands, and a tall thing between it and the frame throws its shadow in and
##     stands (control: the candle taken off, the tall thing is hidden);
##   - a thing in the shot is never hidden;
##   - the free look shows what is hidden, and letting the eye go hides it again;
##   - a preview's table hides nothing ([member TableMedium.hides_idle]).
##
##   tests/run_boot_probe.sh tests/table/shot_reach_check.gd 300
##
## A boot probe (the medium reaches the Director); no GPU needed - what is hidden is geometry.

const DIR := "user://shot_reach_check"
const MATERIALS := {"wood": {"kind": "wood", "color": "#6a4a2a"}, "wax": {"kind": "wax", "color": "#e8dcc0"}}

var _fails := 0
var medium: TableMedium
var subs: Subtitles
var _script := ""


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


static func _box(name: String, size: Array, at: Array) -> Dictionary:
	return {"name": name, "at": at, "parts": [{"shape": "box", "size": size, "material": "wood"}]}


func _run() -> void:
	_clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var surf := Image.create(256, 160, false, Image.FORMAT_RGB8)
	surf.fill(Color(0.3, 0.12, 0.14))
	surf.save_png(DIR.path_join("surface.png"))
	var stage := SubViewport.new()
	stage.size = Vector2i(640, 360)
	stage.own_world_3d = true
	add_child(stage)
	Director.detach()
	medium = Medium.make("table") as TableMedium
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	subs = preload("res://src/show/subtitles.gd").new()
	add_child(subs)
	medium.bind_captions(subs)
	_script = CardReading.compose([{"kind": "shuffle", "card": 0, "text": "Shuffle the deck."},
		{"kind": "draw", "card": 1, "text": "One."}, {"kind": "spread", "card": 0, "text": "Done."}])

	var candle := {"name": "candle", "at": [74, -6], "parts": [{"shape": "lathe", "profile": [[0, 0], [2.2, 0], [2.2, 14], [0, 14]], "material": "wax", "wick": true}]}
	var things := [_box("jar", [8, 10, 8], [-64, 6]), _box("screen", [3, 22, 12], [60, -4]), candle, _box("bowl", [10, 5, 10], [0, -22])]
	_build({"materials": MATERIALS, "things": things}, null)
	var out := {}
	for th in medium._things_part.on_table:
		out[String((th as Dictionary)["name"])] = ShotReach.shown((th as Dictionary)["rect"]) < ShotReach.OUT
	_ok(out.get("jar", false) and out.get("screen", false) and out.get("candle", false) and not out.get("bowl", true),
		"the fixture: the jar, the screen and the candle stand out of the shot, the bowl in it (%s)" % str(out))
	var idle := medium.idle_names()
	_ok(idle.has("jar"), "a thing out of the shot no act names, giving nothing, is hidden (%s)" % str(idle))
	_ok(not idle.has("candle"), "a candle out of the shot gives light and stands")
	_ok(not idle.has("screen"), "a tall thing between the candle and the frame throws its shadow in and stands")
	_ok(not idle.has("bowl"), "a thing in the shot is never hidden")
	var jar := _node("jar")
	_ok(jar != null and not jar.visible, "the jar's node is hidden")
	medium.free_look(true)
	_ok(jar != null and jar.visible, "the free look shows it")
	medium.free_look(false)
	_ok(jar != null and not jar.visible, "and letting the eye go hides it again")

	_build({"materials": MATERIALS, "things": things}, {"acts": [{"name": "fetch", "beat": 1, "length": 2,
		"tracks": [{"thing": "jar", "law": "carry", "to": [-20, 0, -10], "lift": 4, "down": true}]}]})
	_ok(not medium.idle_names().has("jar"), "the control: named by an act, the jar stands (%s)" % str(medium.idle_names()))

	_build({"materials": MATERIALS, "things": [things[0], things[1], things[3]]}, null)
	_ok(medium.idle_names().has("screen"), "the control: with the candle taken off, the screen is hidden (%s)" % str(medium.idle_names()))

	medium.hides_idle = false
	_build({"materials": MATERIALS, "things": things}, null)
	_ok(medium.idle_names().is_empty(), "a preview's table hides nothing (%s)" % str(medium.idle_names()))

	Director.hold(false)
	Director.detach()
	_clear()
	print("shot_reach_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## The table with [param table] as its set dresser's and [param acts] as its `acts.json` (none: no file).
func _build(table: Dictionary, acts: Variant) -> void:
	var f := FileAccess.open(DIR.path_join("table.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(table))
	f.close()
	if acts != null:
		var a := FileAccess.open(DIR.path_join("acts.json"), FileAccess.WRITE)
		a.store_string(JSON.stringify(acts))
		a.close()
	elif FileAccess.file_exists(DIR.path_join("acts.json")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join("acts.json")))
	var cards: Array = [{"key": "c0", "name": "Card 0", "numeral": "0", "reversed": false, "jumper": false, "position": {}, "booklet": {}, "art": ""}]
	var doc := {"show": "shot-reach-check", "seed": 3, "dir": DIR, "images": {"surface": DIR.path_join("surface.png")},
		"plan": {"look": {"candles": 1}}, "cards": cards}
	subs.document = {"source": _script, "title": "Shot Reach Check", "table": doc}
	medium._key = ""
	medium._ensure_doc()


func _node(name: String) -> Node3D:
	for th in medium._things_part.on_table:
		if String((th as Dictionary)["name"]) == name:
			return (th as Dictionary)["node"]
	return null


func _clear() -> void:
	var da := DirAccess.open(DIR)
	if da == null:
		return
	for fn in da.get_files():
		da.remove(fn)
