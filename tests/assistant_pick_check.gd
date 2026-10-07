extends Node

## assistant_pick_check - WHICH ASSISTANT RUNS, gated on what is installed ("If no AI is installed, we
## cannot support that feature and should definitely gate on it"). The picker is in the 💬 Assistant's
## own panel (step 4); its rules are [AssistantBackends]' (step 8 - they were the home screen's, and
## splash_agents_check held them until the home screen was retired).
##
##   tests/run_boot_probe.sh tests/assistant_pick_check.gd 90
##
## Through the real main scene, in two states worked out here from the registry rather than from the
## picker: this machine as it is, and no assistant CLI at all (every CLI's program hidden in
## `Deps._resolved`, the cache a launch reads - never a seam - and the Environment panel's real
## `probed` signal re-asked). In each: Off and every assistant listed, Off always choosable, a CLI
## choosable exactly when installed and saying "(not installed)" when not, the whole picker grayed
## with none, its tooltip paragraphs intact through Boot's re-flow; and for EVERY possible choice the
## choice kept as chosen, the assistant that would actually run, and the reason it would not. With
## none installed the tooltip says so, lists every supported assistant and suggests installing one,
## shows on hover although the picker is grayed, and a click opens no list. The choice is set in
## memory only: a probe's Settings never reach the disk.

var _fails: Array = []
var _pick: OptionButton


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 20:
		await get_tree().process_frame
	var chrome: Chrome = main._chrome
	var env: DepsPanel = chrome.environment
	var t0 := Time.get_ticks_msec()
	while env._rows.is_empty() and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	_pick = chrome.assistant._backend_pick
	chrome.assistant._set_expanded(true)
	for _i in 4:
		await get_tree().process_frame
	_ok(_pick != null and _pick.is_visible_in_tree(), "the Assistant's panel holds the picker")
	if _pick == null:
		return _report()
	_state("as installed")
	# --- no assistant at all
	var keep := Deps._resolved.duplicate()
	for k in AssistantBackends.REGISTRY:
		Deps._resolved[AssistantBackends.dep(k)] = ""
	env.probed.emit()
	await get_tree().process_frame
	_state("no assistant")
	var tip := _pick.tooltip_text
	_ok(tip.contains("No AI assistant is installed"), "the tooltip says no AI assistant is installed")
	for k in AssistantBackends.REGISTRY:
		_ok(tip.contains(AssistantBackends.label(k).replace(" ", " ")), "the tooltip lists the supported %s" % AssistantBackends.label(k))
	_ok(tip.contains("Install one or several of them"), "the tooltip suggests installing one or several")
	_ok(await _hover(_pick) == _pick.tooltip_text, "the grayed picker shows its tooltip on hover")
	_press(_pick)
	await get_tree().process_frame
	_ok(not _pick.get_popup().visible, "a click on the grayed picker opens nothing")
	await _hover(null)
	Deps._resolved = keep
	env.probed.emit()
	await get_tree().process_frame
	_state("back as installed")
	_report()


## The picker against the CLIs worked out here: each listed, choosable only when installed, the whole
## picker grayed with none; and for every possible choice, the assistant that would actually run.
func _state(label: String) -> void:
	var have := AssistantBackends.REGISTRY.keys().filter(func(k: String) -> bool: return Deps.has(AssistantBackends.dep(k)))
	var keys: Array = AssistantBackends.picker_keys()
	_ok(_pick.item_count == keys.size(), "%s: the picker lists Off and every assistant" % label)
	_ok(not _pick.is_item_disabled(0), "%s: Off can always be chosen" % label)
	for i in range(1, mini(keys.size(), _pick.item_count)):
		var k := String(keys[i])
		var here := have.has(k)
		_ok(_pick.is_item_disabled(i) == not here, "%s: %s is %s" % [label, k, "choosable" if here else "not choosable"])
		_ok(_pick.get_item_text(i).contains("(not installed)") == not here, "%s: %s says whether it is installed" % [label, k])
	_ok(_pick.disabled == have.is_empty(), "%s: the picker is %s" % [label, "grayed out" if have.is_empty() else "live"])
	var paras := _pick.tooltip_text.split("\n\n")
	_ok(Boot.wrap_tip(_pick.tooltip_text).split("\n\n").size() == paras.size(),
		"%s: the tooltip keeps its paragraphs through Boot's re-flow" % label)
	var was: Variant = Settings.read("assistant", "backend", "")
	for k in keys:
		Settings.write("assistant", "backend", k)
		var usable := have.has(k)
		_ok(AssistantBackends.choice() == k, "%s: the choice '%s' is kept as chosen" % [label, k])
		_ok(AssistantBackends.runnable() == (k if usable else ""),
			"%s: chosen '%s', the assistant that runs is '%s'" % [label, k, AssistantBackends.runnable()])
		_ok(AssistantBackends.gap().is_empty() == usable, "%s: chosen '%s', the reason is '%s'" % [label, k, AssistantBackends.gap()])
	Settings.write("assistant", "backend", was)


## Point at [param c] (null: move off everything) and return the tooltip that comes up, "" if none.
func _hover(c: Control) -> String:
	var at := c.get_global_rect().get_center() if c != null else Vector2(2, 2)
	for i in 4:
		var mm := InputEventMouseMotion.new()
		mm.position = at + Vector2(i, 0)
		mm.global_position = mm.position
		get_viewport().push_input(mm, true)
		await get_tree().process_frame
	if c == null:
		return ""
	_ok(get_viewport().gui_get_hovered_control() == c, "the pointer is over the %s" % c.get_class())
	await get_tree().create_timer(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5)) + 0.7).timeout
	return _tooltip_text(get_tree().root)


## A left click on [param c], as the pointer makes one.
func _press(c: Control) -> void:
	var at := c.get_global_rect().get_center()
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = at
		mb.global_position = at
		get_viewport().push_input(mb, true)


## The text of a tooltip on screen, "" when none is.
func _tooltip_text(n: Node) -> String:
	for c in n.get_children(true):
		if c is PopupPanel and (c as PopupPanel).visible:
			for l in c.get_children(true):
				if l is Label:
					return (l as Label).text
		var t := _tooltip_text(c)
		if not t.is_empty():
			return t
	return ""


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
		print("  FAIL  " + msg)


func _report() -> void:
	if _fails.is_empty():
		print("assistant_pick_check: ALL OK")
		get_tree().quit(0)
		return
	print("assistant_pick_check: %d FAILURE(S)" % _fails.size())
	get_tree().quit(1)
