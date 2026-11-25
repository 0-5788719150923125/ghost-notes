extends SceneTree

## tooltip_check - every tooltip is folded as it is shown ([method Boot.fold_tooltip]), shown for real: a button under the pointer,
## hovered past the tooltip's delay, and the label Godot shows the tooltip in read back (no window: headless, the pointer is at the
## window's corner, and the button stands there). Holds, each against a control:
##
## - A long tooltip is shown in lines no wider than a tooltip may be ([constant _max]), its panel no wider than that and its
##   margins, its paragraphs kept - and a word longer than a line (a path, a link) is broken where the line ends.
## - The control's own `tooltip_text` is left as it was written.
## - A tooltip rewritten every frame, as a Pipeline row's is, is shown folded all the same.
## - The control: with Boot's hook off, the same tooltip is shown unfolded, wider than a tooltip may be.
##
##     godot --headless --path . --script tests/platform/tooltip_check.gd

const LONG := "A tooltip long enough to run off the screen if it were shown as one line, said in ordinary words and then some more of them, and more again.\n\nA second paragraph, with a path in it: "
var _fails := 0
var _token := "/" + "abcdefghij".repeat(30)
var _rewrite: Button = null
## Boot, the autoload - reached through its node, never its name: named, this script would compile it before the autoloads are up.
var _boot: Node = null
var _max := 480.0
var _variation := &"TooltipLabel"


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	# ...a tooltip rewritten every frame, as a row of the Pipeline card is
	if _rewrite != null and is_instance_valid(_rewrite):
		_rewrite.tooltip_text = LONG + _token
	return false


## The label a tooltip is shown in, once it is up (waited for past the tooltip's delay, real time), or null.
func _shown(tip: String) -> Label:
	var b := Button.new()
	b.text = "hover"
	b.tooltip_text = tip
	b.position = Vector2.ZERO
	b.size = Vector2(160, 48)
	root.add_child(b)
	await process_frame
	root.notification(Viewport.NOTIFICATION_VP_MOUSE_ENTER)
	var mm := InputEventMouseMotion.new()
	root.push_input(mm)
	var until := Time.get_ticks_msec() + int(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5) * 1000.0) + 1500
	var found: Label = null
	while Time.get_ticks_msec() < until and found == null:
		await process_frame
		found = _tooltip_label(root)
	return found


func _tooltip_label(n: Node) -> Label:
	if n is Label and (n as Label).theme_type_variation == _variation:
		return n
	for c in n.get_children(true):
		var got := _tooltip_label(c)
		if got != null:
			return got
	return null


func _widest(text: String) -> float:
	var f: Font = ThemeDB.fallback_font
	var fsize := ThemeDB.get_default_theme().get_font_size("font_size", "TooltipLabel")
	var w := 0.0
	for line in text.split("\n"):
		w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x)
	return w


func _done(label: Label) -> void:
	# ...the button gone, its tooltip with it
	for c in root.get_children():
		if c is Button:
			c.free()
	for i in 3:
		await process_frame


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var boot: Node = root.get_node_or_null("Boot")
	_ok(boot != null, "Boot, the autoload that folds tooltips, is up")
	if boot != null:
		_max = float(boot.get("TIP_MAX_PX"))
		_variation = StringName(boot.get("TIP_LABEL"))
	var label := await _shown(LONG + _token)
	_ok(label != null, "the tooltip is shown")
	if label != null:
		_ok(_widest(label.text) <= _max + 1.0, "a long tooltip is shown in lines no wider than a tooltip: %d px" % int(_widest(label.text)))
		_ok(label.text.split("\n\n").size() == 2, "its paragraphs are kept")
		_ok(label.text.replace("\n", "").contains(_token.left(40)) and label.text.count("\n") > 4, "a word longer than a line is broken where the line ends")
		var panel := label.get_parent() as Window
		_ok(panel != null and panel.size.x <= int(_max) + 64, "its panel is no wider than a tooltip and its margins: %s" % str(panel.size if panel != null else Vector2i.ZERO))
		for c in root.get_children():
			if c is Button:
				_ok((c as Button).tooltip_text == LONG + _token, "the control's own tooltip is left as it was written")
	await _done(label)
	# ...rewritten every frame
	var b := Button.new()
	_rewrite = b
	b.position = Vector2.ZERO
	b.size = Vector2(160, 48)
	root.add_child(b)
	await process_frame
	root.notification(Viewport.NOTIFICATION_VP_MOUSE_ENTER)
	root.push_input(InputEventMouseMotion.new())
	var until := Time.get_ticks_msec() + 2500
	var again: Label = null
	while Time.get_ticks_msec() < until and again == null:
		await process_frame
		again = _tooltip_label(root)
	_ok(again != null and _widest(again.text) <= _max + 1.0, "a tooltip rewritten every frame is shown folded: %d px" % int(_widest(again.text) if again != null else -1.0))
	_rewrite = null
	await _done(again)
	# the control: Boot's hook off, the same tooltip unfolded
	if boot != null:
		node_added.disconnect(Callable(boot, "_hook_tooltip"))
		var bare := await _shown(LONG + _token)
		_ok(bare != null and _widest(bare.text) > _max, "the control: with Boot's hook off, the tooltip is shown unfolded: %d px" % int(_widest(bare.text) if bare != null else -1.0))
		node_added.connect(Callable(boot, "_hook_tooltip"))
		await _done(bare)
	print("tooltip_check: ", "ok" if _fails == 0 else "%d failed" % _fails)
	quit(1 if _fails > 0 else 0)
