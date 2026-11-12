extends RefCounted
class_name SceneView

## SceneView - the camera every scene draws through.
##
## A scene draws in a coordinate system whose origin (0,0) is the screen center;
## this object maps that centered space to pixels: zoom in/out, tilt (skew), roll,
## and slide off-center. Scenes/shots set the *target* fields each frame; the
## actual transform eases toward them in commit(), so every camera move is smooth
## and gentle rather than snapping - cinematic, not jittery.

## Target framing (set by the shot, the scene's drift, and transitions).
var zoom: float = 1.0
var rotation: float = 0.0
var skew: float = 0.0
var offset: Vector2 = Vector2.ZERO

## 0..1 transition presence (1 = fully on screen).
var presence: float = 1.0

## How much of a scene's built geometry is on the paper, 0..1, and a ratchet: it only ever rises, which is why it is
## separate from [member presence].
##
## Scenes hold their contents back while they fade up (a metropolis grows out of its landscape); gating on presence is
## wrong on the way out, since presence falls through the same window on a fade to black and the contents would
## vanish early. The Director arms it at zero when it puts a scene on screen behind a fade
## ([method Director._begin_transition]) and it climbs as that scene arrives; nothing lowers it, so a scene fades out
## with everything still drawn on it. A scene that arrives on a cut starts at 1, fully built.
var reveal: float = 1.0

## Where the ratchet reaches full: geometry finishes arriving over the last fifth of the fade-up, after the scene's
## ground and atmosphere are established.
const REVEAL_AT := 0.8

## Composition bias, applied on top of the scene's own framing (the Director sets it during a LAYER transition to
## push two overlapping scenes to opposite regions so they don't collide at the focal point). The scene never touches these.
var bias_offset: Vector2 = Vector2.ZERO
var bias_zoom: float = 1.0

## Punch channel: a momentary zoom / roll / skew applied instantly (the Director drives the envelope) on top of
## everything else, e.g. a rapid-fire modulation stinger on the beat. Neutral = identity.
var pulse_zoom: float = 1.0
var pulse_rot: float = 0.0
var pulse_skew: float = 0.0

## How fast the actual transform chases the target (per second). Lower = gentler.
var smoothing: float = 5.0

# Smoothed actuals (what matrix() draws).
var _zoom := 1.0
var _rot := 0.0
var _skew := 0.0
var _off := Vector2.ZERO
var _bias_off := Vector2.ZERO
var _bias_zoom := 1.0


## Ease the actual transform toward the target. Called once per frame (and during
## pre-warm) by the Director, after the scene and any transition have written.
func commit(dt: float) -> void:
	# The geometry ratchet (see [member reveal]) - it tracks presence UP and never back down.
	reveal = maxf(reveal, smoothstep(REVEAL_AT, 1.0, presence))
	var a := 1.0 - exp(-smoothing * dt)
	_zoom = lerpf(_zoom, zoom, a)
	_rot = lerpf(_rot, rotation, a)
	_skew = lerpf(_skew, skew, a)
	_off = _off.lerp(offset, a)
	_bias_off = _bias_off.lerp(bias_offset, a)
	_bias_zoom = lerpf(_bias_zoom, bias_zoom, a)


## Snap the actual transform straight onto the target, no easing. Called at the end of a scene's pre-warm so the
## first shown frame is already settled (the ease only reaches ~95% in the pre-warm's frames).
func snap() -> void:
	_zoom = zoom
	_rot = rotation
	_skew = skew
	_off = offset
	_bias_off = bias_offset
	_bias_zoom = bias_zoom


## The zoom actually in force this frame: the eased value with the transition bias and the stinger punch folded in,
## exactly the scale [method matrix] will apply.
##
## A scene that must cover the whole frame whatever the camera does (a full-bleed ground; see
## GhostScene.paint_ground) needs this: at zoom z, the visible half-extent in the scene's own coordinates is size * 0.5 / z.
func zoom_actual() -> float:
	return _zoom * _bias_zoom * pulse_zoom


## The transform a scene pushes at the top of _draw, for the given viewport size.
func matrix(size: Vector2) -> Transform2D:
	var origin := size * 0.5 + (_off + _bias_off) * size
	var z := _zoom * _bias_zoom * pulse_zoom
	return Transform2D(_rot + pulse_rot, Vector2(z, z), _skew + pulse_skew, origin)


## The half-extent a scene must fill to cover the screen, in the scene's own centered coordinates: where the camera
## is looking, exact.
##
## Scenes draw around (0,0) and the view transform then zooms, pans, rolls and skews the canvas, so anything sized to
## the raw viewport has an edge just outside the frame that a camera move walks into shot. A fixed margin cannot be
## right: it does not know whether the shot has pulled back to 0.7 zoom or panned a third of a frame sideways.
##
## The visible region is the screen rectangle pulled back through the inverse of the very transform [method matrix]
## hands the renderer, so it accounts for zoom, offset, bias, rotation, skew and the stinger punch together by
## construction. Its corners give an axis-aligned bound, taken about the origin because that is where scenes build
## from: fill [-h, h] and the frame is covered.
##
## [param margin] covers the one frame of lag between this being asked in update() and the eased transform that will
## actually draw (see commit), plus a little for a shot still moving.
func visible_half(size: Vector2, margin := 1.06) -> Vector2:
	var inv := matrix(size).affine_inverse()
	var hx := 0.0
	var hy := 0.0
	for c in [Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]:
		var p: Vector2 = inv * c
		hx = maxf(hx, absf(p.x))
		hy = maxf(hy, absf(p.y))
	return Vector2(hx, hy) * margin
