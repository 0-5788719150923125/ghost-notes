extends Node2D
class_name CartoonFx

## CartoonFx - the marks a cartoon draws over its puppets (next/cartoon.md): a star burst where a blow lands, dizzy stars round a
## head, dust kicked up at the feet, sweat flying, an alarm over a head, speed lines behind a runner. Flat color inked black, as
## the drawings are. One node over a stage's puppets ([method of]), stepped on the stage's clock ([method step]) - each mark lives
## a moment and goes; one that follows a puppet ([member PuppetBody]) is drawn where that puppet's bone is now.

const NAME := "CartoonFx"
## How long each kind lives (s).
const LIFE := {"pow": 0.5, "stars": 2.4, "dust": 0.7, "sweat": 0.8, "alarm": 1.1, "lines": 0.35}
const KINDS := ["pow", "stars", "dust", "sweat", "alarm", "lines"]
const INK := Color(0.06, 0.05, 0.05)

var _marks: Array = []               # {kind, at, size, t, life, seed, follow: PuppetBody | null, bone, dir}


## The stage's marks, made the first time a verb asks.
static func of(stage: Node) -> CartoonFx:
	var fx := stage.get_node_or_null(NAME) as CartoonFx
	if fx == null:
		fx = CartoonFx.new()
		fx.name = NAME
		stage.add_child(fx)
	return fx


## A mark of [param kind] at [param at] (the stage's pixels), [param size] across; following bone [param bone] of [param body]
## where one is given, and going toward [param dir] (lines, dust).
func add(kind: String, at: Vector2, size: float, body: PuppetBody = null, bone := "", dir := Vector2.ZERO) -> void:
	if not LIFE.has(kind):
		return
	_marks.append({"kind": kind, "at": at, "size": maxf(4.0, size), "t": 0.0, "life": float(LIFE[kind]),
		"seed": _marks.size() * 7 + int(at.x) % 97, "follow": body, "bone": bone, "dir": dir})


## Every mark a moment older, the spent ones gone.
func step(dt: float) -> void:
	if _marks.is_empty():
		return
	for m in _marks:
		m["t"] = float(m["t"]) + dt
	_marks = _marks.filter(func(m: Dictionary) -> bool: return float(m["t"]) < float(m["life"]))
	queue_redraw()


func _draw() -> void:
	for m in _marks:
		var at: Vector2 = m["at"]
		var body: PuppetBody = m["follow"]
		if body != null and body.node != null and is_instance_valid(body.node):
			at = body.top_point() if String(m["bone"]).is_empty() else body.point_of(String(m["bone"]))
		var k := clampf(float(m["t"]) / float(m["life"]), 0.0, 1.0)
		var s := float(m["size"])
		match String(m["kind"]):
			"pow":
				_burst(at, s * (0.55 + 0.6 * sqrt(k)), 1.0 - smoothstep(0.6, 1.0, k), int(m["seed"]))
			"stars":
				var fade := 1.0 - smoothstep(0.75, 1.0, k)
				for i in 3:
					var a := float(m["t"]) * 5.5 + TAU * float(i) / 3.0
					var p := at + Vector2(cos(a) * s * 0.45, sin(a) * s * 0.14 - s * 0.12)
					_star(p, s * (0.11 + 0.03 * sin(a)), Color(1.0, 0.86, 0.15, fade), fade)
			"dust":
				var d: Vector2 = m["dir"]
				for i in 4:
					var o := Vector2(float(i - 1.5) * s * 0.25 - d.x * s * k * 0.5, -s * 0.12 * k * float(1 + i % 2))
					var r := s * (0.1 + 0.18 * k) * (0.8 + 0.1 * float(i))
					var c := Color(0.78, 0.76, 0.72, 0.85 * (1.0 - k))
					draw_circle(at + o, r, c)
					draw_arc(at + o, r, 0.0, TAU, 20, Color(INK, 0.6 * (1.0 - k)), maxf(1.5, s * 0.015), true)
			"sweat":
				for i in 3:
					var a := -PI * 0.5 + (float(i) - 1.0) * 0.8
					var p := at + Vector2(cos(a), sin(a)) * s * (0.25 + 0.5 * k) + Vector2(0, s * 0.5 * k * k)
					_drop(p, s * 0.07, a + PI * 0.5, 1.0 - k)
			"alarm":
				var pop := 1.0 + 0.25 * sin(minf(k * 6.0, PI))
				_alarm(at - Vector2(0, s * 0.35), s * 0.32 * pop, 1.0 - smoothstep(0.8, 1.0, k))
			"lines":
				var d: Vector2 = m["dir"]
				var dd := d.normalized() if d.length() > 0.01 else Vector2.RIGHT
				for i in 5:
					var off := Vector2(-dd.y, dd.x) * (float(i) - 2.0) * s * 0.16
					var a0 := at + off - dd * s * (0.4 + 0.1 * float(i % 2))
					draw_line(a0, a0 - dd * s * 0.5 * (1.0 - k), Color(INK, 0.7 * (1.0 - k)), maxf(2.0, s * 0.02), true)


## A jagged star burst, red round yellow, inked.
func _burst(at: Vector2, r: float, a: float, seed: int) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var n := 12
	for i in n * 2:
		var ang := TAU * float(i) / float(n * 2) + float(seed % 7) * 0.1
		var jag := 1.0 if i % 2 == 0 else 0.55 + 0.08 * float((seed + i) % 3)
		outer.append(at + Vector2(cos(ang), sin(ang)) * r * jag)
		inner.append(at + Vector2(cos(ang), sin(ang)) * r * jag * 0.62)
	draw_colored_polygon(outer, Color(0.93, 0.18, 0.12, a))
	draw_colored_polygon(inner, Color(1.0, 0.88, 0.2, a))
	var loop := outer.duplicate()
	loop.append(outer[0])
	draw_polyline(loop, Color(INK, a), maxf(2.0, r * 0.05), true)


func _star(at: Vector2, r: float, col: Color, a: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI * 0.5 + TAU * float(i) / 10.0
		pts.append(at + Vector2(cos(ang), sin(ang)) * r * (1.0 if i % 2 == 0 else 0.45))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color(INK, a), maxf(1.5, r * 0.15), true)


func _drop(at: Vector2, r: float, ang: float, a: float) -> void:
	var tip := at + Vector2(cos(ang - PI * 0.5), sin(ang - PI * 0.5)) * r * 1.8
	var pts := PackedVector2Array([tip])
	for i in 9:
		var t := ang + PI * float(i) / 8.0          # the round half, away from the tip
		pts.append(at + Vector2(cos(t), sin(t)) * r)
	draw_colored_polygon(pts, Color(0.55, 0.8, 1.0, a))
	pts.append(tip)
	draw_polyline(pts, Color(INK, a), maxf(1.5, r * 0.25), true)


func _alarm(at: Vector2, h: float, a: float) -> void:
	var w := h * 0.28
	var bar := PackedVector2Array([at + Vector2(-w * 0.6, -h * 0.5), at + Vector2(w * 0.6, -h * 0.5), at + Vector2(w * 0.25, h * 0.18),
		at + Vector2(-w * 0.25, h * 0.18)])
	draw_colored_polygon(bar, Color(0.95, 0.1, 0.2, a))
	var loop := bar.duplicate()
	loop.append(bar[0])
	draw_polyline(loop, Color(INK, a), maxf(2.0, h * 0.05), true)
	draw_circle(at + Vector2(0, h * 0.38), w * 0.32, Color(0.95, 0.1, 0.2, a))
	draw_arc(at + Vector2(0, h * 0.38), w * 0.32, 0.0, TAU, 16, Color(INK, a), maxf(2.0, h * 0.05), true)
