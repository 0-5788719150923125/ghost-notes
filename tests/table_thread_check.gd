extends Node

## THE SET DRESSER'S TABLE IS BUILT OFF THE MAIN THREAD ([method TablePreview._stand]). Reported
## 2026-10-08: every picture the set dresser took froze the app for five or six seconds. On a fixture of
## its own (an episode under its own root, a small table of two things):
##
##   - THE SAME TABLE: built on a worker, out of the tree, it stands every thing where a main-thread build
##     stands it, leaves off what that leaves off, names the same light, and photographs the same, pixel for
##     pixel - with the table's own light and without it (the lamp is aimed as look_at aims it).
##   - THE APP KEEPS DRAWING while it is built: several frames, none as long as the build - the control,
##     the same table built on the main thread, is one frame at least as long as the whole build. (Not
##     tighter: on a table this small the fixed costs are most of the build, and a GPU busy elsewhere
##     stretches a frame.)
##   - GIVEN BACK MID-BUILD, the stage being built is dropped, never swapped in; and the preview stands a
##     table again afterward.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table_thread_check.gd 300
##
## A BOOT probe (the medium reaches the Director) on the GPU (a picture needs a real renderer).

const ROOT := "user://table_thread_check"

## A small set table: a lit candle and a stone, at the back, on a round top under one cloth.
const TABLE := {"materials": {"wax": {"kind": "wax", "color": "#e8dcc0"}, "slate": {"kind": "stone", "color": "#4a4a50"}},
	"top": {"shape": "round", "size": [120, 120], "material": "oak"},
	"layers": [{"name": "a cloth", "outline": "rect", "size": [90, 70], "fabric": "linen"}],
	"things": [
		{"name": "a pillar", "place": "back left", "parts": [{"shape": "lathe", "profile": [[0, 0], [2.4, 0], [2.4, 8], [0, 8]], "material": "wax", "wick": true}]},
		{"name": "a stone", "place": "back right", "parts": [{"shape": "ball", "size": [5, 3, 4], "material": "slate"}]}]}

## ...and a light of its own: a sun from the back left, and a lamp.
const LIGHT := {"sky": {"color": "#b8c8d8", "strength": 0.5},
	"sun": {"look": "sun", "from": "back left", "height": 35, "strength": 0.8},
	"lamps": [{"name": "a lantern", "look": "lantern", "from": "right"}]}

var _fails := 0
var _longest := 0
var _last := 0
var _timing := false
var _frames := 0


func _ready() -> void:
	_run.call_deferred()


func _process(_d: float) -> void:
	if not _timing:
		return
	var now := Time.get_ticks_msec()
	if _last > 0:
		_longest = maxi(_longest, now - _last)
	_last = now
	_frames += 1


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	if not TablePreview.can_set():
		_ok(false, "this run cannot stand a table (GHOST_PROBE_GPU=1, under a ghost boot)")
		_done()
		return
	var ep := _fixture()
	var plan: Dictionary = ep.read_json("plan")
	var prev := TablePreview.new(ep, plan, ProjectSettings.globalize_path(ROOT.path_join("preview")), "Check Tarot", "")
	var lit := TABLE.duplicate(true)
	lit["light"] = LIGHT
	for pair in [["with no light of its own", TABLE], ["with its own light", lit]]:
		var raw: Dictionary = pair[1]
		var tag := String(pair[0])
		# BUILT ON A WORKER: the main thread's longest frame while it is built
		_time(true)
		var t0 := Time.get_ticks_msec()
		var err: String = await prev._stand(raw)
		var worker_ms := Time.get_ticks_msec() - t0
		var worker_frames := _frames
		var worker_frame := _time(false)
		_ok(err.is_empty(), "the table %s stands on a worker: %s" % [tag, err])
		if not err.is_empty():
			continue
		var a: Dictionary = await _picture(prev, raw)
		if tag.contains("no light"):
			var ref := SpotLight3D.new()
			add_child(ref)
			ref.position = (prev._medium._lamp as SpotLight3D).position
			ref.look_at(Vector3(0.0, 0.0, -0.1), Vector3.UP)
			_ok(((prev._medium._lamp as SpotLight3D).transform as Transform3D).is_equal_approx(ref.transform),
				"the lamp is not aimed as look_at aims it: %s against %s" % [(prev._medium._lamp as SpotLight3D).transform, ref.transform])
			ref.free()
		# THE CONTROL: the same table built where the app draws, as the preview used to build it - the frame
		# it is built in timed from the frame before to the frame after
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.size = TablePreview.SHEET
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		get_tree().root.add_child(vp)
		var m = TablePreview._load(TablePreview.MEDIUM)
		m.mount(vp)
		m.bind_captions(prev._doc)
		m._key = ""
		await get_tree().process_frame
		var frame_at := Time.get_ticks_msec()
		t0 = Time.get_ticks_msec()
		m._ensure_doc()
		var main_ms := Time.get_ticks_msec() - t0
		await get_tree().process_frame
		var main_frame := Time.get_ticks_msec() - frame_at
		prev._table.queue_free()
		prev._table = vp
		prev._medium = m
		var b: Dictionary = await _picture(prev, raw)
		print("  %s: built on a worker in %d ms (%d frames, the longest %d ms); on the main thread in %d ms (a frame of %d ms)" %
			[tag, worker_ms, worker_frames, worker_frame, main_ms, main_frame])
		_ok(main_frame >= main_ms, "the control: the main-thread build was not one frame as long as the build (%d ms, built in %d)" % [main_frame, main_ms])
		_ok(worker_frames >= 3 and worker_frame < main_ms,
			"the app stopped drawing while the table %s was built on a worker: %d frames, the longest %d ms, the build %d ms" % [tag, worker_frames, worker_frame, main_ms])
		for k in ["stood", "left_off", "key", "held_down", "cards", "deck"]:
			_ok(str(a[k]) == str(b[k]), "the table %s built on a worker differs in %s: %s against %s" % [tag, k, str(a[k]), str(b[k])])
		_ok(not (a["stood"] as Array).is_empty(), "nothing stood on the table %s (the comparison proves nothing)" % tag)
		var diff := _differ(a["image"], b["image"])
		_ok(diff == 0, "the table %s built on a worker photographs differently: %d sampled pixels (-1: no picture)" % [tag, diff])
	# GIVEN BACK MID-BUILD
	var gone := func() -> void:
		await get_tree().process_frame
		await get_tree().process_frame
		prev.release()
	gone.call_deferred()
	var late: Dictionary = await prev.table(TABLE)
	_ok(String(late.get("error", "")).contains("given back") and prev._table == null,
		"a stage given back while it was built was swapped in: %s, %s" % [late.get("error", "-"), prev._table])
	var again: Dictionary = await prev.table(TABLE)
	_ok(not again.has("error") and again.get("image") != null, "the preview does not stand a table after it was given back: %s" % again.get("error", "-"))
	prev.release()
	_done()


## The main thread's longest frame since timing began ([param on] true), returned when it stops.
func _time(on: bool) -> int:
	if on:
		_longest = 0
		_last = 0
		_frames = 0
	_timing = on
	return _longest


## The table as [method TablePreview.table] photographs it, on the stage the preview holds now.
func _picture(prev: TablePreview, raw: Dictionary) -> Dictionary:
	prev._pose_spread()
	prev._medium._tick_air(TablePreview.AIR_AT)
	var out := prev._placed(CardTable.sanitize_table(raw, CardTable.sanitize_look(prev.plan.get("look", {}))))
	out["image"] = await prev._render(prev._table, TablePreview.TABLE_FRAMES)
	return out


## How many of every other pixel differ by more than a fiftieth between [param a] and [param b], -1 without both.
static func _differ(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return -1
	var n := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var d := a.get_pixel(x, y) - b.get_pixel(x, y)
			if (absf(d.r) + absf(d.g) + absf(d.b)) / 3.0 > 0.02:
				n += 1
	return n


func _fixture() -> CardEpisode:
	CardEpisode.root = ROOT
	var ep := CardEpisode.open("check-show", 4242)
	DirAccess.make_dir_recursive_absolute(ep.dir)
	for f in DirAccess.get_files_at(ep.dir):
		DirAccess.remove_absolute(ep.dir.path_join(f))
	ep.write_json("plan", {"episode_title": "A Table Built Aside", "spread": {"name": "Three", "positions": [{"name": "One"},
		{"name": "Two"}, {"name": "Three"}]}, "look": CardTable.sanitize_look({"deck_name": "The Test Deck", "candles": 1})})
	ep.write_json("draw", {"seed": ep.seed, "cards": CardDeck.shuffled(CardDeck.standard(), ep.seed, true).slice(0, 3)})
	var surf := Image.create(192, 128, false, Image.FORMAT_RGB8)
	surf.fill(Color(0.2, 0.12, 0.1))
	surf.save_png(ep.file_of("image:surface"))
	return ep


func _done() -> void:
	print("table_thread_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	get_tree().quit(1 if _fails > 0 else 0)
