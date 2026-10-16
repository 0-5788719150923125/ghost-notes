extends RefCounted
class_name ShowOpening

## ShowOpening - how a show at a table or a desk OPENS AND CLOSES, one way for both: the card table's
## ([TableMedium]), lifted out of it for the desk ([DeskMedium]) - the user, 2026-10-16: "the
## intro/outro doesn't inherit the behavior from cards mode. We need the blurring effect and fade and
## such." A medium hands it its own moment of opening and its voice; this says what the frame does.
##
##   THE INTRO: the channel's name ([TitleCard]) over the whole frame thrown far out of focus - a
##   Gaussian [constant CardTable.TITLE_BLUR] of the frame's height wide ([IntroBlur],
##   [constant INTRO_SHADER]) - up by 1.4 s, with nothing to be made out under it but colors.
##   THE FOCUS PULL as the show opens (the deck's shuffle, the box's opening, the pen's first word):
##   the wide blur lifts over the first [constant INTRO_LIFT] of the pull, eased through its log down to
##   [constant INTRO_SHARP] (half a pixel at 1080), and is taken off; the lens's own near-to-far pull
##   carries on from there; the name goes as the pull starts.
##   THE OUTRO: black a beat after the voice's last word, exactly as the outro's silence runs out.
##   THE THUMBNAIL: the moment the name is fully up over the blur, before the pull.
##
## Pure functions of show time, so a live reading, a scrub and an export open and close alike.

## The focus pull: it starts this long before the show opens and takes this long after it (seconds),
## from a lens this soft (CameraAttributesPractical.dof_blur_amount).
const FOCUS_PULL := Vector2(1.4, 1.6)
const FOCUS_BLUR := 0.16
## The intro's blur ([IntroBlur]) and how it lifts.
const INTRO_SHADER := preload("res://shaders/table_intro.gdshader")
const INTRO_LIFT := 0.5
const INTRO_SHARP := 0.0005


## THE NAME'S ALPHA at [param t]: up by 1.4 s, gone as the show opens at [param opening] (INF while it
## is not known) - and only then: with the show's actions [param placed] and still no opening, it is
## down (the show ends on the picture fading to black, not on the name again).
static func title_alpha(t: float, opening: float, placed: bool) -> float:
	var a := clampf((t - 0.3) / 1.1, 0.0, 1.0)
	if opening < INF:
		a *= 1.0 - clampf((t - (opening - 0.6)) / 0.9, 0.0, 1.0)
	elif placed:
		a = 0.0
	return a


## HOW FAR THE FOCUS PULL IS at [param t], 0 (the intro, all out of focus) to 1 (sharp): it runs from
## [constant FOCUS_PULL]`.x` before [param opening] to `.y` after. A show with nothing placed yet is
## still in its intro; one placed with no opening has nothing to wait for.
static func pull(t: float, opening: float, placed: bool) -> float:
	if opening < INF:
		return clampf((t - (opening - FOCUS_PULL.x)) / (FOCUS_PULL.x + FOCUS_PULL.y), 0.0, 1.0)
	return 1.0 if placed else 0.0


## The lens at [param p] of the pull: [param blur]'s sigma, and [param attrs]' depth of field (none
## for a medium whose depth is flat) - 0 the intro, 1 sharp (both off).
static func lens(p: float, blur: IntroBlur, attrs: CameraAttributesPractical) -> void:
	var k := _ease(clampf(p / INTRO_LIFT, 0.0, 1.0))
	var wide := CardTable.TITLE_BLUR
	blur.set_sigma(wide * pow(INTRO_SHARP / wide, k) if k < 1.0 else 0.0)
	if attrs == null:
		return
	if p >= 1.0:
		attrs.dof_blur_far_enabled = false
		return
	var e := _ease(p)
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = lerpf(0.04, 1.6, e * e)
	attrs.dof_blur_far_transition = lerpf(0.05, 0.6, e)
	attrs.dof_blur_amount = lerpf(FOCUS_BLUR, FOCUS_BLUR * 0.4, e)


## THE OUTRO: 1 until the voice has said the last of [param total] words ([param follower] knows when),
## then down to black - a beat after it, and black exactly as [param outro] (the take's tail in a
## render, the Director's outro live) runs out.
static func end_fade(t: float, follower: ReadingFollower, total: int, outro: float) -> float:
	var last := follower.known_last()
	if total == 0 or last < total - 1:
		return 1.0
	var o := maxf(outro, 0.0)
	var beat := minf(0.8, o * 0.15)
	return 1.0 - _ease((t - (follower.st1[last] + beat)) / maxf(o - beat, 0.05))


## WHERE THE THUMBNAIL IS TAKEN, seconds into the video: the title screen with the name fully up over
## the blur - after the name fades in (by 1.4 s) and before the focus pull, which starts
## [constant FOCUS_PULL]`.x` before the show opens at the intro's end. [param intro] is the take's
## intro hold.
static func thumbnail_moment(intro: float) -> float:
	return clampf(intro * 0.4, 1.5, maxf(1.5, intro - 1.6))


## The intro hold a take was rendered with (its sidecar's bookend), else [param fallback] - the
## caller's (the Director's: a part a show mounts never names it).
static func take_intro(take: String, fallback: float) -> float:
	var side := take.get_basename() + ".json"
	if take.is_empty() or not FileAccess.file_exists(side):
		return fallback
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(side)) != OK or not (j.data is Dictionary):
		return fallback
	var b: Variant = (j.data as Dictionary).get("bookend", {})
	return float((b as Dictionary).get("in", fallback)) if b is Dictionary else fallback


static func _ease(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
