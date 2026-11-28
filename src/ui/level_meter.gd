extends Control
class_name LevelMeter

## LevelMeter - a meter of what is heard, as a recorder's or a mixer's reads: each ear's peak, green, then amber past
## [constant AMBER], red past [constant RED]; each ear's highest held a moment ([constant HOLD]); and a scale. Where speech belongs is
## the amber's edge: its peaks around -12 to -6, red too loud.
##
## Placed on a panel it reads a bus as the engine measures it ([member bus], the Master by default: everything heard, the ambience
## and the bed included, after every effect). Another meter drawn its own way feeds a [LevelMeter.Reading] and draws it with
## [method draw_meter] (the Studio's flip screen). Gate: tests/ui/level_meter_check.gd.

## The scale's floor (dBFS), how fast a reading falls back (dB a second) and how long a peak is held (s).
const FLOOR := -60.0
const FALL := 24.0
const HOLD := 1.5
## Where green turns amber and amber red (dBFS), and the marks on the scale.
const AMBER := -12.0
const RED := -3.0
const TICKS := [-40.0, -20.0, -12.0, -6.0, 0.0]
const GREEN_C := Color(0.3, 0.9, 0.35)
const AMBER_C := Color(0.95, 0.8, 0.2)
const RED_C := Color(0.95, 0.25, 0.2)

## The bus it reads (empty: fed by hand, [member reading]).
var bus := &"Master"
## What it shows.
var reading := Reading.new()


## A meter's reading as it moves: each ear now (falling back) and each ear's held peak.
class Reading extends RefCounted:
	var left := LevelMeter.FLOOR
	var right := LevelMeter.FLOOR
	var held := [LevelMeter.FLOOR, LevelMeter.FLOOR]
	var _held_for := [0.0, 0.0]

	## Each ear's peak now, [param l] and [param r] (dBFS), [param dt] seconds after the last.
	func feed(l: float, r: float, dt: float) -> void:
		left = maxf(maxf(l, LevelMeter.FLOOR), left - LevelMeter.FALL * dt)
		right = maxf(maxf(r, LevelMeter.FLOOR), right - LevelMeter.FALL * dt)
		for k in 2:
			var now := l if k == 0 else r
			_held_for[k] = float(_held_for[k]) - dt
			if now >= float(held[k]) or float(_held_for[k]) <= 0.0:
				held[k] = maxf(now, LevelMeter.FLOOR)
				_held_for[k] = LevelMeter.HOLD


func _init() -> void:
	custom_minimum_size = Vector2(0, 30)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = ("Everything heard, as it leaves for your ears and the export: the voice, the show's sounds, the ambience. "
		+ "Each bar an ear's peak - green, amber past -12 dB, red past -3; the thin line its highest a moment ago. Speech belongs "
		+ "with its peaks around -12 to -6; in the red, turn a Level down.")


func _process(delta: float) -> void:
	if bus.is_empty() or not is_visible_in_tree():
		return
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	reading.feed(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0), delta)
	queue_redraw()


func _draw() -> void:
	draw_meter(self, Rect2(Vector2(14, 1), Vector2(size.x - 14 - 12, size.y - 2)), reading, get_theme_default_font(), 9, 11)


## [param r] drawn into [param rect] of [param ci]: two bars (left over right), each held peak, and the scale under them; their
## letters left of the rect in [param font] at [param letter_px], the scale's numbers at [param scale_px].
static func draw_meter(ci: CanvasItem, rect: Rect2, r: Reading, font: Font, scale_px: int, letter_px: int) -> void:
	var bar_h := rect.size.y * 0.26
	var gap := rect.size.y * 0.06
	var x0 := rect.position.x
	var x1 := rect.position.x + rect.size.x
	var at := func(db: float) -> float: return x0 + (x1 - x0) * clampf((db - FLOOR) / -FLOOR, 0.0, 1.0)
	for k in 2:
		var db := r.left if k == 0 else r.right
		var y := rect.position.y + k * (bar_h + gap)
		ci.draw_rect(Rect2(x0, y, x1 - x0, bar_h), Color(0, 0, 0, 0.45))
		var lit: float = at.call(db)
		for s in [[FLOOR, AMBER, GREEN_C], [AMBER, RED, AMBER_C], [RED, 0.0, RED_C]]:
			var a: float = at.call(float(s[0]))
			var b: float = minf(at.call(float(s[1])), lit)
			if b > a:
				ci.draw_rect(Rect2(a, y, b - a, bar_h), s[2])
		ci.draw_string(font, Vector2(x0 - letter_px - 2.0, y + bar_h * 0.95), "L" if k == 0 else "R", HORIZONTAL_ALIGNMENT_LEFT, -1, letter_px,
			Color(1, 1, 1, 0.8))
		var hd := float(r.held[k])
		if hd > FLOOR + 0.5:
			var hx: float = at.call(hd)
			ci.draw_rect(Rect2(hx - 1.5, y, 3.0, bar_h), RED_C if hd > RED else (AMBER_C if hd > AMBER else GREEN_C))
	var sy := rect.position.y + 2.0 * (bar_h + gap)
	for db in TICKS:
		var tx: float = at.call(float(db))
		ci.draw_rect(Rect2(tx - 1.0, sy, 2.0, bar_h * 0.35), Color(1, 1, 1, 0.7))
		ci.draw_string(font, Vector2(tx - scale_px, sy + bar_h * 0.35 + scale_px), str(int(db)), HORIZONTAL_ALIGNMENT_CENTER, scale_px * 2,
			scale_px, Color(1, 1, 1, 0.7))

