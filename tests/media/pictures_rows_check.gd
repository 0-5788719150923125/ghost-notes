extends SceneTree

## pictures_rows_check - a chapter's pictures as rows of the note's Pipeline card ([IllustrationPanel.Section];
## next/pipeline.md).
##
##   godot --headless --path . --script tests/media/pictures_rows_check.gd
##
## A ROW A PICTURE, ITS WORDS ITS NAME, not made until it is; with more than one, ALL OF THEM AGAIN IS A ROW OF ITS OWN and it asks
## what it costs, where it had been a button of the panel's (THE CONTROL: a chapter of one picture has no such row). A row's ⟳
## starts at once: its own earlier versions are kept, so it throws nothing away. LISTED WHILE THE PANEL IS SHOWN (a Picture
## card shows it under the media that print a reading - THE CONTROL: hidden, no section) and its text calls for any. What it is
## missing is what Generate makes; a page is captured, never painted, so a page alone is missing nothing Generate paints.
## STOP STOPS THEM (the card's Stop says so): this chapter's out of the line, and no other's (THE CONTROL).

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	var lib: GDScript = load("res://src/media/illustrations.gd")
	lib.use_for_test({}, false)
	var panel = load("res://src/media/illustration_panel.gd").new()
	var section = panel.pipeline()
	_ok(not section.shown() and section.rows().is_empty(), "no pictures in the text: no section")
	panel.set_script_text("Words. <!-- image: A harbor at dawn. --> More. <!-- image: A storm over the bay. -->")
	_ok(section.shown(), "pictures in the text: a section")
	panel.visible = false
	_ok(not section.shown(), "the control: its panel hidden, no section")
	panel.visible = true
	var rows: Array = section.rows()
	_ok(rows.size() == 3 and rows[0].key == "all" and rows[1].label == "A harbor at dawn." and rows[2].label == "A storm over the bay.",
		"a row a picture, its words its name, and all of them again first: %s" % str(rows.map(func(r: PipelineRow) -> String: return r.label)))
	_ok(rows[0].asks.contains("2 pictures") and rows[0].asks.contains("kept") and rows[0].state == "none",
		"all of them again asks, saying what it costs (%s)" % rows[0].asks)
	_ok(rows[1].state == "missing" and rows[1].asks.is_empty() and rows[1].again == "Paint this picture." and rows[1].open,
		"a picture not made: says so, and starts at once")
	_ok(section.missing() and not section.busy(), "what is missing is what Generate makes")
	# STOP STOPS THEM: the Pipeline card's Stop says it does
	var first_key: String = rows[1].key
	var second_key: String = rows[2].key
	lib._queue.append({"key": first_key, "prompt": "A harbor at dawn.", "placement": "inline"})
	lib._queue.append({"key": "of-another-chapter", "prompt": "Elsewhere.", "placement": "inline"})
	_ok(section.busy() and section.rows()[1].state == "queued" and not section.rows()[1].open, "waiting its turn: busy, its ⟳ waits")
	_ok(lib.status(second_key) == "missing", "control: the other is not waiting")
	section.stop()
	_ok(not section.busy() and lib.status(first_key) == "missing" and lib.status("of-another-chapter") == "queued",
		"Stop takes this chapter's out of the line, and no other's (the control)")
	lib._queue.clear()
	panel.set_script_text("Words. <!-- image: A harbor at dawn. -->")
	rows = section.rows()
	_ok(rows.size() == 1 and rows[0].key != "all", "the control: one picture has no all-of-them row")
	panel.set_script_text("Words.")
	_ok(not section.shown(), "the marks gone, so is the section")
	panel.free()
	lib.use_for_test()
	print("pictures_rows_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1
