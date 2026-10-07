extends CanvasLayer
class_name Transport

## Transport - play, pause, stop and the scrub rail along the bottom of the stage: ONE for every
## mode (next/notes.md, "The transport"). It grew out of the Scrubber, Chrome's seek bar.
##
## THE TRANSPORT BELONGS TO THE CLOCK. It shows exactly when the show is timed
## ([method Spectrum.timed]) - something conducts: a reading, a synthesis take, a song - and an
## untimed note has none. Every button goes through Spectrum's transport verbs, which call the
## registered conductor's hooks or drive a plain file themselves, so a mode never builds its own
## Play: four start/stop arrangements, two scrubbers and a Space that meant two things are what
## this replaced. Auto and Manual gained a pause with it.
##
## SPACE IS PLAY/PAUSE EVERYWHERE, except while someone is typing; skipping a scene is N (main.gd).
## Taken in _input, BEFORE the GUI, or a focused button would take it first - the Generative panel
## learned that from its collapse button. ←/→ (shift: a minute) and Home seek, as they always did.
##
## WHAT SEEKING DOES AND DOES NOT MOVE. Everything that READS the clock follows a seek exactly and
## immediately: the baked spectrum is a timeline lookup, the karaoke overlay reads
## `Spectrum.current.time - time_base`, the whole-show bookend fade is a function of position. The
## [Director] is the exception - a SIMULATION, not a function of t - so after a seek the show
## carries on from the scene that is up ([Echo] drifts it back toward the content). To reach a
## SCENE, `--scene <name>` pins one. A live reading seeks by SENTENCE through its conductor's
## `seek` (generative_editor.gd); a synthesis take cannot seek, and its rail does not take clicks.
##
## IT NEVER APPEARS IN AN EXPORT, and not by a check: the render process returns out of main
## before Chrome is built. HOVERING THE RAIL SHOWS THE TIME under the pointer, so a click can be
## aimed.

const BAR_H := 4.0                  # the resting rail, px
const BAR_H_ACTIVE := 8.0           # while the pointer is over it
const PAD := 26.0                   # distance from the bottom edge to the rail
const FADE := 7.0                   # per-second ease on the reveal
const BTN := 28.0                   # the play and stop buttons, square
const GAP := 8.0
const PLAY_TIP := "Play / pause (Space)"
const STALE_TIP := ("\n\nThe script changed after this reading began. ■ then ▶ reads it again "
	+ "with the new words.")

var _root: Control
var _shown := 0.0                   # 0..1 eased visibility
var _dragging := false
var _hover_x := -1.0                # the pointer's x over the rail, or -1
var _mouse_in := true               # the pointer is inside the window
var _label: Label
var _play: Button
var _stop: Button
var _painter: Control
var _stale_tip := false


func _ready() -> void:
	# Above the subtitles (9) and the workspace (100) so it is never buried, below the feedback
	# console (128) and the exporter (250), which are modal-ish and own the corner.
	layer = 120
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_play = _button("▶", PLAY_TIP)
	_play.pressed.connect(func() -> void: Spectrum.transport_toggle())
	_stop = _button("■", "Stop")
	_stop.pressed.connect(func() -> void: Spectrum.transport_stop())
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.9))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_label)
	var painter := Painter.new()
	painter.owner_node = self
	painter.set_anchors_preset(Control.PRESET_FULL_RECT)
	painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(painter)
	_painter = painter
	# a pointer that leaves the window from the rail sends no motion off it
	get_window().mouse_entered.connect(func() -> void: _mouse_in = true)
	get_window().mouse_exited.connect(func() -> void:
		_mouse_in = false
		_hover_x = -1.0)


func _button(glyph: String, tip: String) -> Button:
	var b := Button.new()
	b.text = glyph
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(BTN, BTN)
	b.add_theme_font_size_override("font_size", 13)
	_root.add_child(b)
	return b


func _process(delta: float) -> void:
	var want := 1.0 if Spectrum.timed() else 0.0
	_shown = lerpf(_shown, want, 1.0 - exp(-FADE * delta))
	# Snapped to zero only on the way OUT: a frame of a fraction of a millisecond (a headless run)
	# eases in by less than the threshold, and snapping then kept the bar hidden for good.
	if want == 0.0 and _shown < 0.004:
		_shown = 0.0
	_root.visible = _shown > 0.0
	if not _root.visible:
		return
	var playing := Spectrum.transport_playing()
	# THE EDIT DOT: a reading whose script changed after it began plays the old words until it
	# is stopped and played again - the panel's Play button carried the same dot.
	var stale := false
	var sh: Variant = Spectrum.conductor().get("stale")
	if sh is Callable and (sh as Callable).is_valid():
		stale = bool((sh as Callable).call())
	_play.text = "❚❚" if playing else ("▶•" if stale else "▶")
	# Only when it changes: Boot.wrap_tip rewrites a tooltip as it is hovered.
	if stale != _stale_tip:
		_stale_tip = stale
		_play.tooltip_text = PLAY_TIP + (STALE_TIP if stale else "")
	_play.disabled = not playing and not Spectrum.transport_can_play()
	_stop.disabled = not Spectrum.transport_can_stop()
	_play.modulate.a = _shown
	_stop.modulate.a = _shown
	var r := _rail()
	var y := r.position.y + r.size.y * 0.5 - BTN * 0.5
	_play.position = Vector2(r.position.x - 2.0 * (BTN + GAP), y)
	_stop.position = Vector2(r.position.x - (BTN + GAP), y)
	var t := Spectrum.scrub_position()
	var total := maxf(0.0, Spectrum.scrub_length())
	_label.text = "%s / %s" % [_clock(t), _clock(total)] if total > 0.0 else _clock(t)
	_label.position = Vector2(r.position.x, r.position.y - 20.0)
	_label.modulate.a = _shown
	_painter.queue_redraw()


func _input(event: InputEvent) -> void:
	if not Spectrum.timed():
		return
	if space_toggles(event, get_viewport().gui_get_focus_owner()):
		Spectrum.transport_toggle()
		get_viewport().set_input_as_handled()
		return
	if not Spectrum.seekable():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var inside := _rail().grow(10.0).has_point(event.position)
		if event.pressed and inside:
			_dragging = true
			_seek_to(event.position.x)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var over: bool = _mouse_in and _rail().grow(10.0).has_point(event.position)
		_hover_x = event.position.x if over or _dragging else -1.0
		if _dragging:
			_seek_to(event.position.x)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and not _typing():
		# Arrow keys are the control that actually gets used while watching, because they need no
		# aim. Taken in _input, BEFORE the GUI, or the focused control eats them first (in the
		# Synthesis panel a row of sliders walked the focus instead of moving the playhead).
		match event.keycode:
			KEY_LEFT:
				Spectrum.seek(Spectrum.scrub_position() - _step(event))
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				Spectrum.seek(Spectrum.scrub_position() + _step(event))
				get_viewport().set_input_as_handled()
			KEY_HOME:
				Spectrum.seek(0.0)
				get_viewport().set_input_as_handled()


## Whether [param event] is Space meant for the transport: plain Space, pressed (not held), and
## nobody typing into [param focus]. Wherever else the focus is - a panel's collapse button took
## Space for itself once, and Play stopped answering it (2026-10-05).
static func space_toggles(event: InputEvent, focus: Control) -> bool:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_SPACE:
		return false
	if k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return false
	return not (focus is TextEdit or focus is LineEdit)


## Is someone typing? Then Space, the arrows and Home are theirs, not the playhead's: a live
## reading seeks by RESTARTING from a sentence, and a cursor key pressed in the script editor did
## exactly that, silently, mid-sentence.
func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is TextEdit or f is LineEdit


## 10 s normally, 60 s with shift - the difference between "I missed a word" and "that scene was
## a couple of minutes back".
func _step(event: InputEventKey) -> float:
	return 60.0 if event.shift_pressed else 10.0


func _seek_to(x: float) -> void:
	var r := _rail()
	var f := clampf((x - r.position.x) / maxf(1.0, r.size.x), 0.0, 1.0)
	Spectrum.seek(f * Spectrum.scrub_length())


## The clickable rail, in viewport coordinates. Inset from both edges, after room for the two
## buttons, so a click meant for the very start or end cannot miss the control entirely.
func _rail() -> Rect2:
	var vp := _root.get_viewport_rect().size
	var margin := maxf(40.0, vp.x * 0.06)
	# CLEAR OF AN OPEN SIDE PANEL: the bar starts to the right of it, and has the whole width
	# back when the panel is hidden - it was drawing (and taking clicks) over the panel's rows
	var left := margin
	for n in get_tree().get_nodes_in_group(SidePanel.GROUP):
		var c := n as Control
		if c != null and c.is_visible_in_tree():
			var r := c.get_global_rect()
			if r.position.x < vp.x * 0.5:
				left = maxf(left, r.end.x + 24.0)
	left += 2.0 * (BTN + GAP)
	return Rect2(Vector2(left, vp.y - PAD), Vector2(maxf(10.0, vp.x - margin - left), BAR_H))


static func _clock(t: float) -> String:
	var s := int(maxf(0.0, t))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


class Painter:
	extends Control
	var owner_node: Transport

	func _draw() -> void:
		if owner_node == null:
			return
		var a: float = owner_node._shown
		if a <= 0.0:
			return
		var r: Rect2 = owner_node._rail()
		var seekable := Spectrum.seekable()
		var hx: float = owner_node._hover_x if seekable else -1.0
		var h := lerpf(Transport.BAR_H, Transport.BAR_H_ACTIVE,
			1.0 if owner_node._dragging or hx >= 0.0 else 0.0)
		r.position.y -= (h - Transport.BAR_H) * 0.5
		r.size.y = h
		var total: float = Spectrum.scrub_length()
		var f: float = clampf(Spectrum.scrub_position() / total, 0.0, 1.0) if total > 0.0 else 0.0
		# A dark rail under a light fill, both translucent: the bar has to be readable over a
		# white tidepool and a black void alike. Dimmer where it cannot be seeked (a take).
		var fill := 0.85 if seekable else 0.4
		draw_rect(r.grow(1.0), Color(0.02, 0.02, 0.03, 0.55 * a), true)
		draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)),
			Color(0.86, 0.90, 0.96, fill * a), true)
		if not seekable:
			return
		# The playhead, wide enough to grab.
		var px: float = r.position.x + r.size.x * f
		draw_rect(Rect2(Vector2(px - 1.5, r.position.y - 4.0), Vector2(3.0, r.size.y + 8.0)),
			Color(1, 1, 1, 0.95 * a), true)
		if hx >= 0.0:
			_draw_hover(r, hx, total, a)

	## The time under the pointer: a hairline on the rail and a pill above it, kept inside the
	## window and clear of the position label at the rail's left end.
	func _draw_hover(r: Rect2, hx: float, total: float, a: float) -> void:
		var hf := clampf((hx - r.position.x) / maxf(1.0, r.size.x), 0.0, 1.0)
		var x := r.position.x + r.size.x * hf
		draw_rect(Rect2(Vector2(x - 0.5, r.position.y - 3.0), Vector2(1.0, r.size.y + 6.0)),
			Color(1, 1, 1, 0.7 * a), true)
		var font := get_theme_default_font()
		const FS := 13
		var text := Transport._clock(hf * total)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
		var hgt := font.get_height(FS) + 4.0
		var box := Rect2(Vector2(x - tw * 0.5 - 7.0, r.position.y - 24.0 - hgt), Vector2(tw + 14.0, hgt))
		box.position.x = clampf(box.position.x, 4.0, size.x - box.size.x - 4.0)
		draw_rect(box, Color(0.02, 0.02, 0.03, 0.8 * a), true)
		draw_string(font, Vector2(box.position.x + 7.0, box.position.y + 2.0 + font.get_ascent(FS)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FS, Color(0.95, 0.96, 0.99, a))
