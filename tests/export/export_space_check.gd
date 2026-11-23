extends SceneTree

## export_space_check - an export's disk estimate: before the render it covers the busiest rate a quality has had (or the
## prior), the whole MJPEG scratch only where it is not given back; in flight it projects the MP4 from what is written; the
## kept rates stay a short list per quality; the free space read matches the disk's.
##
##   godot --headless --path . --script res://tests/export/export_space_check.gd
##
## The control is an estimate that leaves out the scratch where it is not given back, which an hour of 4K overruns by tens of
## gigabytes.

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	const GB := 1 << 30
	var px_4k := 3840.0 * 2160.0 * 60.0
	var hour := 3600.0

	# the rate planned: the prior until measured, then the busiest kept for that quality only
	_ok(is_equal_approx(ExportSpace.rate_for("4k", {}), ExportSpace.PRIOR_BPP), "an unmeasured quality plans at the prior")
	var kept := {"4k": [0.02, 0.035], "1080p": [0.3]}
	_ok(is_equal_approx(ExportSpace.rate_for("4k", kept), 0.035), "a measured quality plans at its busiest rate")
	var many := {}
	for i in 20:
		many = ExportSpace.remember(many, "4k", 0.01 * (i + 1))
	_ok((many["4k"] as Array).size() == ExportSpace.KEEP, "a quality keeps %d rates" % ExportSpace.KEEP)
	_ok(is_equal_approx(float(many["4k"][0]), 0.13), "the oldest rates go first")

	# a measured MP4: the two 4K60 exports kept so far (913 MB over 425.9 s is about 17 Mbps, 0.034 bits a pixel)
	var bpp := ExportSpace.measured(912951506, 425.9, px_4k)
	_ok(bpp > 0.03 and bpp < 0.04, "17 Mbps of 4K60 measures 0.03-0.04 bits a pixel (%.4f)" % bpp)
	_ok(ExportSpace.measured(1000000, 5.0, px_4k) == 0.0, "a few seconds measure nothing")

	# before: an hour of 4K at the prior, the scratch given back and not
	var back := ExportSpace.need_before(hour, px_4k, px_4k, ExportSpace.PRIOR_BPP, true)
	var whole := ExportSpace.need_before(hour, px_4k, px_4k, ExportSpace.PRIOR_BPP, false)
	var control := ExportSpace.padded(ExportSpace.mp4_bytes(hour, px_4k, ExportSpace.PRIOR_BPP))
	_ok(back > 25 * GB and back < 45 * GB, "an hour of 4K plans 25-45 GB with the scratch given back (%s)" % ExportSpace.size_text(back))
	_ok(whole > back + 100 * GB, "the whole scratch adds over 100 GB where it is not given back (%s)" % ExportSpace.size_text(whole))
	_ok(not (control > back + 100 * GB), "control: an estimate without the scratch misses it")
	_ok(ExportSpace.need_before(30.0, px_4k, px_4k, 0.03, true) >= ExportSpace.FLOOR, "a short export still asks a gigabyte's headroom")

	# in flight: projected from the MP4 so far, nothing before it is warm
	_ok(ExportSpace.need_more(hour, 5.0, 10 * GB, 0) == -1, "nothing projected before the first seconds are encoded")
	var more := ExportSpace.need_more(hour, 600.0, 5 * GB, 0)
	_ok(more > 25 * GB and more < 32 * GB, "5 GB in 10 minutes of an hour projects 25 GB more, padded (%s)" % ExportSpace.size_text(more))
	_ok(ExportSpace.need_more(hour, 600.0, 5 * GB, 50 * GB) > more + 49 * GB, "the scratch still to grow is added")

	# the free space read is the disk's
	var free := ExportSpace.free_at(ProjectSettings.globalize_path("res://project.godot"))
	_ok(free > 0, "the project's disk reads as having free space (%s)" % ExportSpace.size_text(free))
	_ok(ExportSpace.free_at("/no/such/folder/x.mp4") == -1, "a folder not there reads as unknown")
	_ok(ExportSpace.size_text(3 * GB / 2) == "1.5 GB" and ExportSpace.size_text(300 << 20) == "300 MB", "sizes read as GB and MB")

	_dialog()

	print("export_space_check: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(1 if _fails > 0 else 0)


## The exporter during a render that cannot fit: the dialog opens once an export, its × leaves the render going, its Stop
## ends it. Built by hand (out of the tree: its _ready would clear a live render's override.cfg), the dialog alone in the tree.
func _dialog() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	var ex = load("res://src/export/exporter.gd").new()     # by path: the class names autoloads a --script gate compiles before
	ex._build_ui()
	ex.remove_child(ex._space_dialog)
	root.add_child(ex._space_dialog)
	ex._status.text = ""
	ex._out = OS.get_cache_dir().path_join("ghost_space_check.mp4")    # never written
	ex._song_dur = 1.0e7                 # far more than any disk holds
	ex._state = "rendering"
	ex._space_asked = false
	var pops := [0]
	ex._space_dialog.about_to_popup.connect(func() -> void: pops[0] += 1)
	ex._watch_space(ExportSpace.WARM_S)
	_ok(pops[0] == 1 and ex._space_dialog.visible, "a render that cannot fit opens the dialog")
	_ok(ex._space_note.contains("may run short"), "...and says so on the progress line")
	ex._space_dialog.hide()
	ex._space_dialog.canceled.emit()     # what its × sends
	_ok(ex._state == "rendering", "its × leaves the render going")
	ex._watch_space(ExportSpace.WARM_S)
	_ok(pops[0] == 1, "it never opens again in the same export")
	_ok(ex._space_note.contains("may run short"), "...while the progress line still says it")
	ex._space_asked = false              # the control: an export that had not asked opens it again
	ex._watch_space(ExportSpace.WARM_S)
	_ok(pops[0] == 2, "control: an export that has not asked opens it")
	ex._space_dialog.custom_action.emit(&"stop")
	_ok(ex._state == "done" and not ex._space_dialog.visible, "Stop the export ends it")
	ex._space_dialog.queue_free()
	ex.free()
