extends Node

## console_check - the in-app console ([ConsoleView]) follows the newest lines only from the bottom. Holds, each against a control:
##
## - At the bottom, what the log says next moves the view to it (the control for what follows).
## - Scrolled up to read or copy, what the log says next is appended and the view stays where it was.
## - Opened from closed, it is at the bottom, wherever it was left.
## - Only what is new is added: a line already shown is never shown twice, and a line still being written waits for its end.
##
## Needs a real boot (the console is the shared Chrome's, which reads the autoloads):
##     tests/run_boot_probe.sh tests/app/console_check.gd 120

const DIR := "user://_console_check"
var _fails := 0
var _log := ""
var _con: ConsoleView


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)


func _ready() -> void:
	_run.call_deferred()


func _say(lines: int, from: int, ending := "\n") -> void:
	var f := FileAccess.open(_log, FileAccess.READ_WRITE) if FileAccess.file_exists(_log) else FileAccess.open(_log, FileAccess.WRITE)
	f.seek_end()
	for i in lines:
		f.store_string("line %d of the log, long enough to wrap now and then in a narrow console%s" % [from + i, ending if i == lines - 1 else "\n"])
	f.close()


func _refresh() -> void:
	_con._accum = ConsoleView._REFRESH_EVERY
	_con._process(0.0)
	for i in 3:
		await get_tree().process_frame


func _bar() -> VScrollBar:
	return _con._text.get_v_scroll_bar()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_log = ProjectSettings.globalize_path(DIR).path_join("godot.log")
	DirAccess.remove_absolute(_log)
	_say(200, 0)
	_con = ConsoleView.new()
	add_child(_con)
	await get_tree().process_frame
	_con._log_path = _log
	_con._on_toggle()
	await _refresh()
	await get_tree().process_frame
	_ok(_con._at_bottom() and _bar().max_value > _bar().page, "opened, the console is at the bottom of a log longer than it shows")
	_say(20, 200)
	await _refresh()
	_ok(_con._at_bottom(), "control: at the bottom, what is said next moves the view to it")
	_bar().value = 0.0
	await get_tree().process_frame
	_say(20, 220)
	await _refresh()
	_ok(_bar().value < 1.0, "scrolled up, what is said next leaves the view where it was: %.1f" % _bar().value)
	_ok(_con._text.get_parsed_text().contains("line 239 of") and _con._text.get_parsed_text().count("line 205 of ") == 1, "only what is new is added, once")
	_say(1, 240, "")
	await _refresh()
	_ok(not _con._text.get_parsed_text().contains("line 240 of"), "a line still being written waits for its end")
	_con._on_toggle()
	_con._on_toggle()
	await _refresh()
	await get_tree().process_frame
	_ok(_con._at_bottom(), "opened from closed, it is at the bottom, wherever it was left")
	_con.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(_log)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	print("console_check: ", "ok" if _fails == 0 else "%d failed" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
