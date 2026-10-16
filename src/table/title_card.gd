extends Node2D
class_name TitleCard

## TitleCard - THE CHANNEL'S NAME over the picture while the intro holds, and its byline under it
## ("with Pen & Ink"), on a soft shade with a halo round every letter, so it reads over whatever is
## behind it. The card table's ([TableMedium]) and the desk's ([DeskMedium]) - one title screen for
## every show a note puts up; the medium says when it shows (`alpha`) and in what faces.

## A shade behind the type, at its middle (it fades to nothing above and below), and THE HALO
## round every letter: rings of the shade, each `x` of the type's size wide at `y` alpha, soft
## from the outside in.
const BAND := 0.32
const HALO := [Vector2(0.24, 0.06), Vector2(0.16, 0.08), Vector2(0.1, 0.12), Vector2(0.06, 0.18), Vector2(0.03, 0.3)]

var channel := ""
## A line under the name in the italic face.
var byline := ""
var face: Font = null
var italic: Font = null
var alpha := 0.0
## The name's color: the set dresser's, chosen to stand out from this table ([method CardTable.title_ink]).
var ink := CardTable.color(CardTable.TITLE_INK)
var _lay := {}
var _lay_key := ""

func _draw() -> void:
	if alpha <= 0.001 or face == null or channel.is_empty():
		return
	var vp := get_viewport_rect().size
	var key := "%s|%s|%s" % [channel, byline, str(vp)]
	if key != _lay_key:
		_lay_key = key
		_lay = CardTable.title_layout(face, italic, channel, byline, vp)
	var shade := CardTable.title_shade(ink)
	# A SHADE BEHIND THE TYPE, soft above and below: the cloth is whatever the episode painted
	var box: Rect2 = _lay["box"]
	var reach := box.size.y * 0.5 + vp.y * 0.12
	_band(Rect2(0.0, box.get_center().y - reach, vp.x, reach * 2.0), shade)
	for l in _lay["lines"]:
		var d: Dictionary = l
		var f: Font = italic if bool(d["italic"]) else face
		var size := int(d["size"])
		var at := Vector2(0.0, float(d["y"]))
		for h in HALO:
			draw_string_outline(f, at, String(d["text"]), HORIZONTAL_ALIGNMENT_CENTER, vp.x, size,
				maxi(int(size * (h as Vector2).x), 1), Color(shade, (h as Vector2).y * alpha))
		draw_string(f, at, String(d["text"]), HORIZONTAL_ALIGNMENT_CENTER, vp.x, size, Color(ink, alpha))

## A band of [param shade] across [param r], clear at its top and bottom edges and [constant BAND]
## at its middle - a raised cosine, drawn as strips whose corners carry it, so it has no steps.
func _band(r: Rect2, shade: Color) -> void:
	var n := 12
	for i in n:
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		var a0 := Color(shade, BAND * alpha * (0.5 - 0.5 * cos(TAU * u0)))
		var a1 := Color(shade, BAND * alpha * (0.5 - 0.5 * cos(TAU * u1)))
		var y0 := r.position.y + r.size.y * u0
		var y1 := r.position.y + r.size.y * u1
		draw_polygon(PackedVector2Array([Vector2(r.position.x, y0), Vector2(r.end.x, y0), Vector2(r.end.x, y1), Vector2(r.position.x, y1)]),
			PackedColorArray([a0, a0, a1, a1]))
