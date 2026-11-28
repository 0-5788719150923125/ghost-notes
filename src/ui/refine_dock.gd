extends RefCounted
class_name RefineDock

## RefineDock - where a Refine opens: docked INTO the window its button is in, never a window of its own - one window that widens,
## moves as one and has one ×. In a window of its own (the Body's editor, a 3D view, a lab, a picture shown whole, the Dex) the
## window widens by [constant WIDTH], its own content keeping its place on the left and the refine standing at its right; on the
## app's own window the side panel holding the button widens instead (its `dock`, [SidePanel]), and the show is fitted beside it. A
## side panel is known by its group ([constant Shell.PANELS]) and asked by name, never named as a class: its card names an autoload
## a gate with none lacks.
##
## Its button is a toggle ([method toggle]): pressed, the refine opens; pressed again, it folds away and the window narrows back. What
## it holds is kept while folded (a conversation goes on, [WriterChat]), and it opens again as it was.

## How wide a refine stands (px), and the room kept between a window and the screen's edge.
const WIDTH := 460
const GAP := 16
## What a window's content and its refine are marked with while it is open: how far the content was moved in, and the window's
## least size before it widened and how much it widened by (less than the refine where the screen had no more room).
const SHIFT := &"refine_dock_shift"
const WAS := &"refine_dock_was"
## What a refine is marked with: the button that opened it (a [WeakRef]), let go of when it is closed some other way (a ×).
const BUTTON := &"refine_dock_button"


## Where [param from] (the node a Refine button is on, or null) docks a refine: the nearest open window above it that is not the
## app's own, else the side panel holding it - or, with no node, the window that has focus, else the app's open side panel. Null for none.
static func host_of(from: Node) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if from == null:
		if tree == null or tree.root == null:
			return null
		for w in tree.root.find_children("*", "Window", true, false):
			if (w as Window).visible and (w as Window).has_focus():
				return w
		for p in tree.get_nodes_in_group(Shell.PANELS):
			if _is_panel(p) and (p as Control).is_visible_in_tree():
				return p
		return null
	var n := from
	while n != null:
		if _is_panel(n):
			return n
		# (a window not open is looked past: a refine docked in it would be docked out of sight)
		if n is Window and n != tree.root and (n as Window).visible:
			return n
		n = n.get_parent()
	return null


## Whether [param panel] stands open in a host.
static func is_open(panel: Control) -> bool:
	return panel != null and is_instance_valid(panel) and panel.visible and panel.is_inside_tree()


## The Refine button's toggle: [param panel] opened docked where [param from] is ([method host_of]), or folded away where it stands
## open; [param button] shown pressed while it is open. Whether it is open now.
static func toggle(from: Node, panel: Control, button: BaseButton = null) -> bool:
	if button != null and panel != null:
		panel.set_meta(BUTTON, weakref(button))
	if is_open(panel):
		close(panel)
	else:
		open(host_of(from), panel)
	show_on(button, panel)
	return is_open(panel)


## [param button] shown as the toggle it is: pressed while [param panel] is open.
static func show_on(button: BaseButton, panel: Control) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.toggle_mode = true
	button.set_pressed_no_signal(is_open(panel))


## [param panel] docked into [param host] (a window or a side panel) and shown. Already open there, it stays as it is.
static func open(host: Node, panel: Control) -> void:
	if panel == null or host == null:
		return
	if _is_panel(host):
		host.call("dock", panel, WIDTH)
		return
	var win := host as Window
	if win == null:
		return
	if panel.get_parent() != win:
		if panel.get_parent() != null:
			panel.get_parent().remove_child(panel)
		win.add_child(panel)
	if panel.visible and panel.has_meta(WAS):
		return
	# its own content moved in from the right, the refine standing where it was
	for c in win.get_children():
		if c == panel or not (c is Control) or (c as Control).has_meta(SHIFT):
			continue
		var cc := c as Control
		if cc.anchor_right > 0.99 and cc.anchor_left < 0.01:
			cc.offset_right -= WIDTH
			cc.set_meta(SHIFT, WIDTH)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -WIDTH
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	# (its size taken before its least size grows, which would push the size up first)
	var before := win.size
	var screen := _screen(win)
	var want := Vector2i(maxi(before.x, mini(before.x + WIDTH, screen.x - 2 * GAP)), before.y)
	panel.set_meta(WAS, [win.min_size, want.x - before.x])
	# (only ever wider: a wrapping line measured before it is laid out says nothing true of a height)
	win.min_size = Vector2i(mini(win.min_size.x + WIDTH, want.x), win.min_size.y)
	win.size = want
	if win.position.x + want.x > screen.x - GAP:
		win.position = Vector2i(maxi(GAP, screen.x - GAP - want.x), win.position.y)
	panel.show()


## [param panel] folded away: hidden, and its host narrowed back to what it was.
static func close(panel: Control) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var host := panel.get_parent()
	while host != null and not _is_panel(host) and not (host is Window):
		host = host.get_parent()
	# (its button let go of, however it was closed)
	var ref: Variant = panel.get_meta(BUTTON) if panel.has_meta(BUTTON) else null
	if ref is WeakRef and (ref as WeakRef).get_ref() is BaseButton:
		((ref as WeakRef).get_ref() as BaseButton).set_pressed_no_signal(false)
	if _is_panel(host):
		host.call("undock", panel)
		return
	panel.hide()
	var win := host as Window
	if win == null or not panel.has_meta(WAS):
		return
	var was: Array = panel.get_meta(WAS)
	panel.remove_meta(WAS)
	for c in win.get_children():
		if c is Control and (c as Control).has_meta(SHIFT):
			(c as Control).offset_right += float((c as Control).get_meta(SHIFT))
			(c as Control).remove_meta(SHIFT)
	win.min_size = was[0]
	win.size = Vector2i(maxi(win.size.x - int(was[1]), win.min_size.x), win.size.y)


## Whether [param n] is a side panel a refine docks in: one of [constant Shell.PANELS] that docks.
static func _is_panel(n: Node) -> bool:
	return n != null and n is Control and n.is_in_group(Shell.PANELS) and n.has_method("dock")


## How much room [param win] has: the app's window it is drawn in.
static func _screen(win: Window) -> Vector2i:
	var tree := win.get_tree() if win.is_inside_tree() else null
	return Vector2i(tree.root.get_visible_rect().size) if tree != null and tree.root != null else Vector2i(1600, 900)
