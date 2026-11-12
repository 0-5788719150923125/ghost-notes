extends CanvasLayer
class_name Transport

## Transport - play, pause, stop and the scrub rail along the bottom of the stage: one for every mode
## (next/notes.md, "The transport").
##
## It belongs to the clock: it shows exactly when the show is timed ([method Spectrum.timed]; something
## conducts: a reading, a synthesis take, a song, a clip in Masking) and an untimed note has none. Every
## button goes through Spectrum's transport verbs, which call the registered conductor's hooks or drive a
## plain file themselves, so a mode never builds its own Play.
##
## Space is play/pause everywhere except while someone is typing; skipping a scene is N (main.gd). It is
## taken in _input, before the GUI, or a focused button would take it first. Left/right (shift: a minute)
## and Home seek.
##
## Seeking: everything that reads the clock follows a seek exactly (the baked spectrum is a timeline
## lookup, the karaoke overlay reads `Spectrum.current.time - time_base`, the bookend fade is a function
## of position). The [Director] is a simulation, not a function of t, so after a seek the show carries on
## from the scene that is up ([Echo] drifts it back toward the content); `--scene <name>` pins one. A live
## reading seeks by sentence through its conductor's `seek` (reading_panel.gd); a synthesis take cannot
## seek, and its rail does not take clicks.
##
## What is buffered is shown, lighter than what is played, from the playhead as far as the show is made
## ahead ([method Spectrum.ready_ahead]): a reading's voice made, a table's physics baked. Hovering the
## rail shows the time under the pointer. It never appears in an export (the render process returns out
## of main before Chrome is built).
##
## The bottom-right row steps up for it: the rail's click zone reaches [constant HIT] px above it, so the
## transport claims that room from Chrome ([method Chrome.claim_bottom], [method room]) while it is timed,
## and nothing positions the row by a figure of its own. Change PAD, HIT or the rail's height and the row
## follows.
##
## The note's timeline opens from here: whatever has a timeline for the note offers it ([method
## offer_timeline]: a storyboard, an episode, a lesson, the words' marks), the highest rank standing is
## the button's, and it shows even before Play. While one is open the rail steps aside (the editor's own
## strip tracks the show and seeks it) and the buttons and time stay ([constant EDITORS]).
##
## It fades with the rest of the furniture while a show plays alone (the group [constant Shell.FADES]),
## and a pointer on the rail holds it up ([method Shell.hold_up]); the rail is drawn, not a control the
## shell could find under the pointer.

const BAR_H := 4.0                  # the resting rail, px
const BAR_H_ACTIVE := 8.0           # while the pointer is over it
const PAD := 26.0                   # distance from the bottom edge to the rail
const FADE := 7.0                   # per-second ease on the reveal
const BTN := 28.0                   # the play and stop buttons, square
const GAP := 8.0
const HIT := 10.0                   # how far past the rail a pointer still counts as on it, px
const CLEARANCE := 8.0              # kept between that zone and anything above it, px
const BUFFERED := 0.32              # how strong the stretch made ahead of the playhead is drawn (the played: 0.85)
const CLAIM := &"transport"         # the key of its claim on the bottom of the frame
## The group every open timeline editor joins: while one is open the rail is not drawn and takes no click.
const EDITORS := &"timeline_editors"
const TIMELINE_TIP := "The timeline: what happens when, to be picked, moved and changed. While it is open its own strip is the scrubber."

## What offers the note's timeline ([method offer_timeline]): [{who (a WeakRef), rank, toggle, is_open, tip}].
static var _offers: Array = []
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
var _claimed := false               # holds a claim on Chrome's bottom edge now
var _holding := false               # holds the furniture up now (the pointer on the rail)
var _tl: Button                     # the timeline's button, beside Play


func _ready() -> void:
	# Above the subtitles (9) and the workspace (100), below the feedback console (128) and the exporter
	# (250), which own the corner.
	layer = 120
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_to_group(Shell.FADES)
	add_child(_root)
	_play = _button("▶", PLAY_TIP)
	_play.pressed.connect(func() -> void: Spectrum.transport_toggle())
	_stop = _button("■", "Stop")
	_stop.pressed.connect(func() -> void: Spectrum.transport_stop())
	_tl = _button("☰", TIMELINE_TIP)
	_tl.toggle_mode = true
	_tl.pressed.connect(func() -> void:
		var o := offered()
		if not o.is_empty():
			(o["toggle"] as Callable).call())
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


## [param who] offers the note's timeline: [param toggle] opens or closes it, [param is_open] says whether
## it is, [param rank] decides between two offers on one note (the words' marks 1, a storyboard 2, an
## episode or a lesson 3). Taken back by [method withdraw_timeline], or by [param who] leaving.
static func offer_timeline(who: Object, rank: int, toggle: Callable, is_open: Callable, tip := "") -> void:
	withdraw_timeline(who)
	_offers.append({"who": weakref(who), "rank": rank, "toggle": toggle, "is_open": is_open, "tip": tip})


static func withdraw_timeline(who: Object) -> void:
	_offers = _offers.filter(func(o: Dictionary) -> bool:
		var w: Variant = (o["who"] as WeakRef).get_ref()
		return w != null and w != who)


## The offer the button stands for: the highest rank whose offerer is still there, {} for none.
static func offered() -> Dictionary:
	var best := {}
	for o in _offers:
		var w: Variant = (o["who"] as WeakRef).get_ref()
		if w != null and is_instance_valid(w) and (w as Object) is Node and (w as Node).is_inside_tree() \
				and (best.is_empty() or int(o["rank"]) > int(best["rank"])):
			best = o
	return best


## Whether a timeline editor is open: the rail steps aside for it.
func editing() -> bool:
	return is_inside_tree() and get_tree().get_first_node_in_group(EDITORS) != null


## How much of the frame's bottom edge the transport takes while it shows: from the edge up past the
## rail's click zone, with [constant CLEARANCE] to spare. Static so a gate can read it.
static func room() -> float:
	return PAD + HIT + CLEARANCE


## Hold (or drop) the claim on the bottom of the frame that lifts Chrome's row above the rail. Only the
## part beyond the row's own margin is asked for: the claim is an inset on top of it.
func _claim_room(on: bool) -> void:
	if on == _claimed:
		return
	var ch := Shell.of(self)
	if ch == null:
		return
	_claimed = on
	if on:
		ch.claim_bottom(CLAIM, room() - Shell.ROW_MARGIN)
	else:
		ch.release_bottom(CLAIM)


## Hold the furniture up (or let it go) while the pointer is on the rail or dragging it.
func _hold_up(on: bool) -> void:
	if on == _holding:
		return
	var ch := Shell.of(self)
	if ch == null:
		return
	_holding = on
	ch.hold_up(CLAIM, on)


func _exit_tree() -> void:
	if _claimed:
		_claim_room(false)
	_hold_up(false)


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
	_claim_room(want > 0.0)
	_hold_up(want > 0.0 and (_dragging or _hover_x >= 0.0))
	_shown = lerpf(_shown, want, 1.0 - exp(-FADE * delta))
	# Snapped to zero only on the way out: a frame of a fraction of a millisecond (a headless run) eases
	# in by less than the threshold, and snapping then kept the bar hidden.
	if want == 0.0 and _shown < 0.004:
		_shown = 0.0
	# the timeline's button stands whenever the note offers one, played or not
	var offer := offered()
	_root.visible = _shown > 0.0 or not offer.is_empty()
	if not _root.visible:
		return
	_tl.visible = not offer.is_empty()
	if _tl.visible:
		_tl.set_pressed_no_signal(bool((offer["is_open"] as Callable).call()))
		var tip := String(offer["tip"]) if not String(offer["tip"]).is_empty() else TIMELINE_TIP
		if _tl.tooltip_text != tip:
			_tl.tooltip_text = tip
	for c in [_play, _stop, _label]:
		(c as Control).visible = _shown > 0.0
	var playing := Spectrum.transport_playing()
	# The edit dot: a reading whose script changed after it began plays the old words until stopped and
	# played again.
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
	_tl.position = Vector2(r.position.x - 3.0 * (BTN + GAP), y)
	var t := Spectrum.scrub_position()
	var total := maxf(0.0, Spectrum.scrub_length())
	_label.text = "%s / %s" % [Clock.text(t), Clock.text(total)] if total > 0.0 else Clock.text(t)
	# ...and while the show waits for what it draws to catch up ([method Spectrum.set_waiting]), says so
	if playing and Spectrum.waiting():
		_label.text += "  · catching up"
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
		var inside := _rail().grow(HIT).has_point(event.position) and not editing()
		if event.pressed and inside:
			_dragging = true
			_seek_to(event.position.x)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var over: bool = _mouse_in and not editing() and _rail().grow(HIT).has_point(event.position)
		_hover_x = event.position.x if over or _dragging else -1.0
		if _dragging:
			_seek_to(event.position.x)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and not _typing():
	# Arrow keys need no aim. Taken in _input, before the GUI, or the focused control eats them first.
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


## Whether [param event] is Space meant for the transport: plain Space, pressed (not held), and nobody
## typing into [param focus].
static func space_toggles(event: InputEvent, focus: Control) -> bool:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_SPACE:
		return false
	if k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return false
	return not (focus is TextEdit or focus is LineEdit)


## Is someone typing? Then Space, the arrows and Home are theirs: a live reading seeks by restarting from
## a sentence, which a cursor key in the script editor would trigger mid-sentence.
func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is TextEdit or f is LineEdit


## 10 s normally, 60 s with shift.
func _step(event: InputEventKey) -> float:
	return 60.0 if event.shift_pressed else 10.0


func _seek_to(x: float) -> void:
	var r := _rail()
	var f := clampf((x - r.position.x) / maxf(1.0, r.size.x), 0.0, 1.0)
	Spectrum.seek(f * Spectrum.scrub_length())


## The clickable rail, in viewport coordinates. Inset from both edges, after room for the two buttons, so
## a click meant for the start or end cannot miss the control.
func _rail() -> Rect2:
	var vp := _root.get_viewport_rect().size
	var margin := maxf(40.0, vp.x * 0.06)
	# Clear of an open side panel: the bar starts to the right of it and has the whole width back when
	# the panel is hidden.
	var left := margin
	for n in get_tree().get_nodes_in_group(SidePanel.GROUP):
		var c := n as Control
		if c != null and c.is_visible_in_tree():
			var r := c.get_global_rect()
			if r.position.x < vp.x * 0.5:
				left = maxf(left, r.end.x + 24.0)
	left += 3.0 * (BTN + GAP)
	return Rect2(Vector2(left, vp.y - PAD), Vector2(maxf(10.0, vp.x - margin - left), BAR_H))


class Painter:
	extends Control
	var owner_node: Transport

	func _draw() -> void:
		if owner_node == null:
			return
		var a: float = owner_node._shown
		# (no rail while a timeline editor is open: its own strip is the scrubber)
		if a <= 0.0 or owner_node.editing():
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
	# A dark rail under a light fill, both translucent, so the bar reads over a white tidepool and a
	# black void alike. Dimmer where it cannot be seeked (a take).
		var fill := 0.85 if seekable else 0.4
		draw_rect(r.grow(1.0), Color(0.02, 0.02, 0.03, 0.55 * a), true)
	# What is buffered ([method Spectrum.ready_ahead]): from the playhead as far as the show is made
	# ahead, lighter than what is played.
		var ahead: float = Spectrum.ready_ahead() if total > 0.0 else -1.0
		if ahead > 0.0:
			var fb := clampf((Spectrum.scrub_position() + ahead) / total, f, 1.0)
			draw_rect(Rect2(Vector2(r.position.x + r.size.x * f, r.position.y), Vector2(r.size.x * (fb - f), r.size.y)),
				Color(0.86, 0.90, 0.96, Transport.BUFFERED * a), true)
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
		var text := Clock.text(hf * total)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
		var hgt := font.get_height(FS) + 4.0
		var box := Rect2(Vector2(x - tw * 0.5 - 7.0, r.position.y - 24.0 - hgt), Vector2(tw + 14.0, hgt))
		box.position.x = clampf(box.position.x, 4.0, size.x - box.size.x - 4.0)
		draw_rect(box, Color(0.02, 0.02, 0.03, 0.8 * a), true)
		draw_string(font, Vector2(box.position.x + 7.0, box.position.y + 2.0 + font.get_ascent(FS)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FS, Color(0.95, 0.96, 0.99, a))
