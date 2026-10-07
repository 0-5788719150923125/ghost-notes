extends Node

## row_check - the bottom-right row (next/notes.md step 4): one container, one panel at a time.
##
##   tests/run_boot_probe.sh tests/row_check.gd 90
##
## THE GEOMETRY, measured: the buttons stand in Chrome.ROW_ORDER, left to right, NO HOLE where a
## hidden one would be (each used to pin itself at a fixed offset, so a hidden ⤓ left a gap),
## nothing over anything else, one bottom edge, the right end ROW_MARGIN from the corner - and a
## claim on the bottom of the frame lifts the whole row as one.
##
## ONE PANEL ABOVE THE ROW AT A TIME: the Environment, the console's log and the Assistant's panel,
## each opened in turn by its own button, and every other one closed by it.
##
## `[deps] open`, READ BACK AFTER A RESTART: closing the Environment with its button is remembered
## and a fresh Chrome comes up with it closed; opening it is remembered too. (A probe's Settings
## never reach the disk; a fresh Chrome reads the same in-memory table the next launch would.)

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var had := Settings._cfg.has_section_key("deps", "open")
	var keep: Variant = Settings.read("deps", "open", true)
	var ch := await _chrome()
	await _geometry(ch)
	await _one_at_a_time(ch)
	await _remembered(ch)
	# put back what was there (in memory: a probe never writes the file)
	if not had:
		if Settings._cfg.has_section_key("deps", "open"):
			Settings._cfg.erase_section_key("deps", "open")
	else:
		Settings.write("deps", "open", keep)
	if _fails.is_empty():
		print("row_check: ALL OK")
		get_tree().quit(0)
		return
	print("row_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _chrome() -> Chrome:
	var ch: Chrome = preload("res://src/chrome.gd").new()
	add_child(ch)
	await _frames(6)
	return ch


## The row's visible buttons, left to right, with their screen rects.
func _shown(ch: Chrome) -> Array:
	var out: Array = []
	for c in ch.row.get_children():
		var b := c as Control
		if b != null and b.visible:
			out.append(b)
	return out


func _geometry(ch: Chrome) -> void:
	print("-- the row")
	var vp := get_viewport().get_visible_rect().size
	# the order: each registered button's index follows ROW_ORDER
	var order_ok := true
	var last := -1
	for c in ch.row.get_children():
		var who: StringName = ch._row_buttons.find_key(c)
		var i := Chrome.ROW_ORDER.find(who)
		if i < last:
			order_ok = false
		last = i
	_ok(order_ok and ch.row.get_child_count() >= 4,
		"the buttons stand in ROW_ORDER (%s)" % str(ch._row_buttons.keys()))
	# A HIDDEN BUTTON, on purpose: the ⤓ stays up (grayed) wherever an export is possible, and goes
	# when a surface suppresses it - the home screen, Masking with its own.
	ch.suppress_export(&"row_check")
	await _frames(3)
	_ok(not ch.exporter._btn.visible, "a suppressed ⤓ is hidden")
	var shown := _shown(ch)
	var contiguous := true
	var bottoms := true
	for k in range(1, shown.size()):
		var a: Rect2 = (shown[k - 1] as Control).get_global_rect()
		var b: Rect2 = (shown[k] as Control).get_global_rect()
		if absf(b.position.x - a.end.x - Chrome.ROW_GAP) > 0.5 or a.intersects(b):
			contiguous = false
			print("    %s ends at %.1f, %s starts at %.1f" % [shown[k - 1].text, a.end.x, shown[k].text, b.position.x])
		if absf(a.end.y - b.end.y) > 0.5:
			bottoms = false
	_ok(contiguous, "no hole where the hidden ⤓ is, and nothing over anything else (%d shown)" % shown.size())
	_ok(bottoms, "one bottom edge")
	var right: Rect2 = (shown[shown.size() - 1] as Control).get_global_rect()
	_ok(absf(right.end.x - (vp.x - Chrome.ROW_MARGIN)) < 0.5 and absf(right.end.y - (vp.y - Chrome.ROW_MARGIN)) < 0.5,
		"the row ends ROW_MARGIN from the corner (%.0f, %.0f in %.0fx%.0f)" % [right.end.x, right.end.y, vp.x, vp.y])
	# a claim lifts the whole row as one
	ch.claim_bottom(&"row_check", 120.0)
	await _frames(3)
	var lifted := true
	for b in _shown(ch):
		if absf((b as Control).get_global_rect().end.y - (vp.y - Chrome.ROW_MARGIN - 120.0)) > 0.5:
			lifted = false
	_ok(lifted, "a claim on the bottom lifts every button together")
	ch.release_bottom(&"row_check")
	ch.release_export(&"row_check")
	await _frames(3)
	# the Environment panel stands above the row
	ch.set_environment_open(true, false)
	await _frames(3)
	var env: Rect2 = ch.environment.get_global_rect()
	var over := false
	for b in _shown(ch):
		if (b as Control).get_global_rect().intersects(env):
			over = true
	_ok(not over and env.end.y <= vp.y - Chrome.ROW_TOP, "the Environment panel stands above the row, over nothing")


func _one_at_a_time(ch: Chrome) -> void:
	print("-- one panel at a time")
	var env_btn: Button = ch._row_buttons[&"environment"]
	var con_btn: Button = ch._row_buttons[&"console"]
	var ast_btn: Button = ch._row_buttons[&"assistant"]
	if not ch.environment.visible:
		env_btn.pressed.emit()
	await _frames(2)
	_ok(ch.environment.visible and _open(ch) == ["environment"], "⚙ opens the Environment (%s)" % str(_open(ch)))
	con_btn.pressed.emit()
	await _frames(2)
	_ok(_open(ch) == ["console"], ">_ opens the log and closes the rest (%s)" % str(_open(ch)))
	ast_btn.pressed.emit()
	await _frames(3)
	_ok(_open(ch) == ["assistant"], "💬 opens the Assistant and closes the rest (%s)" % str(_open(ch)))
	_ok(ch.assistant._backend_pick != null and ch.assistant._backend_pick.is_visible_in_tree(),
		"the Assistant's panel holds the picker for which assistant runs")
	env_btn.pressed.emit()
	await _frames(2)
	_ok(_open(ch) == ["environment"], "⚙ again closes the Assistant (%s)" % str(_open(ch)))
	ast_btn.pressed.emit()
	await _frames(2)
	ast_btn.pressed.emit()
	await _frames(2)
	_ok(_open(ch).is_empty(), "and a panel's own button closes it (%s)" % str(_open(ch)))


## What is open above the row, by what Chrome and the panels themselves say.
func _open(ch: Chrome) -> Array:
	var out: Array = []
	if ch.environment.visible:
		out.append("environment")
	if ch.console._panel.visible:
		out.append("console")
	if ch.assistant._panel.visible:
		out.append("assistant")
	return out


func _remembered(ch: Chrome) -> void:
	print("-- [deps] open, after a restart")
	var env_btn: Button = ch._row_buttons[&"environment"]
	if not ch.environment.visible:
		env_btn.pressed.emit()
		await _frames(2)
	env_btn.pressed.emit()          # the user closes it
	await _frames(2)
	_ok(Settings.read("deps", "open", true) == false, "closing it with ⚙ writes [deps] open = false")
	ch.queue_free()
	await _frames(3)
	var again := await _chrome()
	_ok(not again.environment.visible, "after a restart it comes up closed")
	(again._row_buttons[&"environment"] as Button).pressed.emit()
	await _frames(2)
	_ok(Settings.read("deps", "open", false) == true, "opening it writes [deps] open = true")
	again.queue_free()
	await _frames(3)
	var third := await _chrome()
	_ok(third.environment.visible, "and the next start has it open")
	# A PROBLEM OPENS IT WITHOUT WRITING: close it, then the probe reports a problem
	(third._row_buttons[&"environment"] as Button).pressed.emit()
	await _frames(2)
	third.environment.problem_found.emit()
	await _frames(2)
	_ok(third.environment.visible and Settings.read("deps", "open", true) == false,
		"a problem the probe finds opens it, and is not remembered as the user's choice")
	third.queue_free()
	await _frames(3)
