extends RefCounted
class_name FreeLook

## FreeLook - a person looking a paused show over: the show's own eye turned about what it looks at and drawn in or out ([method
## look_by], a drag and the wheel on the stage, [StageLook]), held while the show stands still; once it plays again the eye eases back
## to the show's own, slowly ([constant SETTLE]) - never a jump, and the eye's own roll kept all the way ([method eye]). A render never
## sees it: what is exported is the show's eye.

## How slowly the eye eases back once the show plays (s: the time it takes to come most of a third of the way).
const SETTLE := 0.9
## How far ahead of the eye it turns about (m), and the nearest and farthest it is drawn (times as far).
const PIVOT := 0.9
const REACH := Vector2(0.25, 12.0)

var yaw := 0.0
var pitch := 0.0
var reach := 1.0


## Turned [param d_yaw] and tipped [param d_pitch] radians more, drawn to [param k] times as far.
func look_by(d_yaw: float, d_pitch: float, k := 1.0) -> void:
	yaw = wrapf(yaw + d_yaw, -PI, PI)
	pitch = clampf(pitch + d_pitch, -1.3, 1.3)
	reach = clampf(reach * k, REACH.x, REACH.y)


## Whether the eye is let go of at all.
func active() -> bool:
	return absf(yaw) > 1e-4 or absf(pitch) > 1e-4 or absf(reach - 1.0) > 1e-4


## Let go of entirely: the show's own eye at once.
func reset() -> void:
	yaw = 0.0
	pitch = 0.0
	reach = 1.0


## The show's eye [param base] as a person turned it: about the point [param pivot_dist] meters ahead of it, turned round the upright
## and over its own right, drawn in or out along its line. While [param held] (the show standing still) it holds; else it eases back
## over [param delta] seconds. The base's roll is kept, so the last of the way back joins it without a jump.
func eye(base: Transform3D, delta: float, held: bool, pivot_dist := PIVOT) -> Transform3D:
	if not held and active():
		var k := exp(-maxf(delta, 0.0) / SETTLE)
		yaw *= k
		pitch *= k
		reach = 1.0 + (reach - 1.0) * k
		if not active():
			reset()
	if not active():
		return base
	var pivot := base.origin - base.basis.z.normalized() * pivot_dist
	var right := base.basis.x.normalized()
	var turn := Basis(Vector3.UP, yaw) * Basis(right, pitch)
	return Transform3D(turn * base.basis, pivot + turn * (base.origin - pivot) * reach)
