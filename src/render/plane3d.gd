extends RefCounted
class_name Plane3D

## Plane3D - a flat quad genuinely placed in 3D space, projected through a [Lens3D].
##
## A plane is a center plus two half-extent edge vectors (a corner is center ± u_axis ± v_axis), oriented however you
## like: laid flat and stacked for parallax, stood up as bars, tilted into depth. A real quad under a real camera,
## depth-sorted alongside the [Mesh3D] bodies. Carries a fill color and an optional bright edge.

var center := Vector3.ZERO
var u_axis := Vector3.RIGHT     ## half-width edge vector
var v_axis := Vector3.UP        ## half-height edge vector
var color := Color.WHITE
var edge := Color(0, 0, 0, 0)   ## edge stroke; alpha 0 = no edge


func _init(c := Vector3.ZERO, uax := Vector3.RIGHT, vax := Vector3.UP, col := Color.WHITE) -> void:
	center = c
	u_axis = uax
	v_axis = vax
	color = col


## The four world-space corners, counter-clockwise.
func corners() -> Array:
	return [
		center - u_axis - v_axis,
		center + u_axis - v_axis,
		center + u_axis + v_axis,
		center - u_axis + v_axis,
	]


## Project the quad through the lens and draw it at pixel scale [param u_px]
## (centered space). Skips the quad if any corner falls behind the camera, which
## keeps the projection from flipping through infinity at grazing angles.
func draw_through(ci: CanvasItem, lens: Lens3D, u_px: float) -> void:
	var poly := PackedVector2Array()
	for c in corners():
		var pr := lens.project(c)
		if pr.z <= lens.near:
			return
		poly.append(Vector2(pr.x, pr.y) * u_px)
	# an edge-on plane projects to (near-)collinear points, which the canvas cannot triangulate; same guard Mesh3D carries.
	var area := absf((poly[1].x - poly[0].x) * (poly[2].y - poly[0].y)
		- (poly[2].x - poly[0].x) * (poly[1].y - poly[0].y)) \
		+ absf((poly[2].x - poly[0].x) * (poly[3].y - poly[0].y)
		- (poly[3].x - poly[0].x) * (poly[2].y - poly[0].y))
	if area < 1.0:
		return
	ci.draw_colored_polygon(poly, color)
	if edge.a > 0.0:
		var e := poly.duplicate()
		e.append(poly[0])
		ci.draw_polyline(e, edge, 1.0, true)
