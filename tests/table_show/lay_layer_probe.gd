extends Node

## lay_layer_probe - one layer of a real episode laid again, on a copy ([method TableProducer.lay_layer]; next/editing.md step 4):
## the producer's own path - the painter host's spec built as the app builds it, the host run, its layer merged in and landed -
## on an episode folder copied out of user:// (never one under it: the probe refuses), then what it did said:
##
##   rsync -a --exclude jobs <user://table/show/seed>/ ~/scratch_ghost/lay_layer/<show>/<seed>/
##   tests/run_boot_probe.sh tests/table_show/lay_layer_probe.gd 3600 --dir=$HOME/scratch_ghost/lay_layer/<show>/<seed> --layer=13
##
## Says: how long the host took, every other layer's elements in `paint/elements.json` and the design (`skin.json`) as they were,
## the layer's own elements new, and the maps that stood kept one back (`versions/_paint_prev/`). A probe: it looks, it gates nothing.

var _producer: TableProducer
var _ep: TableEpisode
var _layer := 0
var _old_paint: Array = []
var _old_skin: Array = []
var _t0 := 0
var _said := 0.0
var _limit := 3000.0


func _ready() -> void:
	var dir := _arg("dir")
	_layer = int(_arg("layer"))
	var real := ProjectSettings.globalize_path(TableEpisode.ROOT)
	if dir.is_empty() or _layer < 1 or dir.begins_with(real) or not DirAccess.dir_exists_absolute(dir):
		print("lay_layer_probe: --dir=<a COPY of an episode, outside %s> --layer=K are needed" % real)
		get_tree().quit(2)
		return
	_ep = TableEpisode.at_dir(dir)
	_old_paint = _elements(dir.path_join("paint/elements.json"))
	_old_skin = _skin(_ep)
	_producer = TableProducer.new(_ep, {})
	var err := _producer.lay_layer(_layer)
	if not err.is_empty():
		print("lay_layer_probe: refused - %s" % err)
		get_tree().quit(1)
		return
	_t0 = Time.get_ticks_msec()
	print("lay_layer_probe: laying layer %d of %d (%s) again on %s" % [_layer, _ep.layer_count(), _name_of(_layer - 1), dir])


func _process(delta: float) -> void:
	if _producer == null:
		return
	_producer.tick()
	var secs := float(Time.get_ticks_msec() - _t0) / 1000.0
	_said += delta
	if _said > 30.0:
		_said = 0.0
		print("  %.0f s: %s" % [secs, _producer.activity_of("skin")])
	if (_producer.running or _producer.busy()) and secs < _limit:
		return
	var p := _producer
	_producer = null
	if secs >= _limit:
		p.stop()
		print("lay_layer_probe: out of time after %.0f s" % secs)
		get_tree().quit(1)
		return
	var failed := p.error_of("skin")
	if not failed.is_empty():
		print("lay_layer_probe: the layer failed - %s" % failed)
		get_tree().quit(1)
		return
	_report(secs)


func _report(secs: float) -> void:
	var k := _layer - 1
	var now_paint := _elements(_ep.dir.path_join("paint/elements.json"))
	var others_old := _old_paint.filter(func(e: Dictionary) -> bool: return int(e.get("layer", -1)) != k)
	var others_now := now_paint.filter(func(e: Dictionary) -> bool: return int(e.get("layer", -1)) != k)
	var mine_old := _old_paint.filter(func(e: Dictionary) -> bool: return int(e.get("layer", -1)) == k)
	var mine_now := now_paint.filter(func(e: Dictionary) -> bool: return int(e.get("layer", -1)) == k)
	var name := _name_of(k)
	var skin_now := _skin(_ep)
	var keep_skin := func(list: Array) -> Array: return list.filter(func(e: Dictionary) -> bool: return String(e.get("stage", "")) != name)
	print("lay_layer_probe: done in %.0f s" % secs)
	print("  other layers' elements as they were: %s (%d)" % [DataPath.same(others_old, others_now), others_now.size()])
	print("  this layer's elements: %d before, %d now; ids %s -> %s" % [mine_old.size(), mine_now.size(),
		str(mine_old.map(func(e: Dictionary) -> String: return String(e["id"]))), str(mine_now.map(func(e: Dictionary) -> String: return String(e["id"])))])
	print("  the design's other layers as they were: %s (%d elements)" % [DataPath.same(keep_skin.call(_old_skin), keep_skin.call(skin_now)), skin_now.size()])
	print("  the maps that stood kept one back: %s" % DirAccess.dir_exists_absolute(_ep.dir.path_join("versions/_paint_prev")))
	get_tree().quit(0)


func _name_of(k: int) -> String:
	var l: Array = _ep.layers()
	return String((l[k] as Dictionary).get("name", "")) if k >= 0 and k < l.size() else ""


static func _elements(path: String) -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return (d as Dictionary).get("elements", []) if d is Dictionary else []


static func _skin(ep: TableEpisode) -> Array:
	var d: Variant = ep.read_json("skin")
	for g in ((d as Dictionary).get("designs", []) if d is Dictionary else []):
		if g is Dictionary:
			return (g as Dictionary).get("elements", [])
	return []


func _arg(name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--%s=" % name):
			return String(a).get_slice("=", 1)
	return ""
