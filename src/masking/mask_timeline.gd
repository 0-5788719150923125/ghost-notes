extends FlagStrip
class_name MaskTimeline

## MaskTimeline - the mask editor's scrub strip: the timeline's [FlagStrip] (its scrub, its two-step marker moves, its zoom,
## ruler and playhead) over the session's markers, with the clip's amplitude waveform under them. Session markers are mutated
## directly (time, plus a re-sort); MaskEditor stays the source of truth for everything else.

var session: MaskSession = null
var player: VideoStreamPlayer = null
var waveform_texture: Texture2D = null   # set by MaskEditor once generated; null draws nothing
# Hi-res waveform slice for the zoomed-in view (see MaskWaveform.poll_hi):
# same recipe as the base strip, rendered over just wavehi_span seconds, drawn
# OVER the base wherever it applies. Progressive - stale/absent just means the
# (soft) base shows.
var wavehi_texture: Texture2D = null
var wavehi_span := Vector2.ZERO


func _markers() -> Array:
	return session.markers if session != null else []


func _span_of(m: Dictionary) -> Vector2:
	return session.marker_span(m)


## Keeping the array sorted (the interpolation in MaskSession.at_time assumes sorted order) - re-sorting every motion
## event is trivial at marker-list sizes, no need to defer it to release.
func _move(m: Dictionary, t: float) -> void:
	m.time = t
	session.markers.sort_custom(func(a, b): return a.time < b.time)


func _extent() -> float:
	return session.duration


func _playhead() -> float:
	return player.stream_position if player != null else 0.0


## Distinct from "session is null" (no clip picked at all) so a clip that IS loaded but came back with a bad/zero probe
## reads as its own state, not the same blank message as never having opened anything.
func _empty_text() -> String:
	if session == null:
		return "no clip loaded"
	if session.duration <= 0.0 or tview == null:
		return "clip loaded, but duration came back 0 - re-preparing…"
	return ""


func _draw_under() -> void:
	# The amplitude waveform (rendered once via ffmpeg's showwavespic, cached next to
	# the clip - see MaskWaveform.ensure). Drawn across wherever the clip's
	# OWN span [0, duration] currently maps to on screen - not the full widget width -
	# so it stays correctly placed once the ruler can extend past a single clip
	# (secondary tracks, the overflow margin) instead of always filling edge to edge.
	if waveform_texture != null:
		var wx0 := tview.x_of(0.0)
		var wx1 := tview.x_of(session.duration)
		if wx1 > 0.0 and wx0 < size.x:
			var tw := float(waveform_texture.get_width())
			var th := float(waveform_texture.get_height())
			draw_texture_rect_region(waveform_texture, Rect2(wx0, 4, wx1 - wx0, size.y - 20),
				Rect2(0, 0, tw, th), Color(0.55, 0.68, 0.85, 0.85))
		# The crisp zoom slice, over the base for exactly its own span. The
		# backing rect re-lays the strip background first - the two textures
		# are both translucent, and hi-over-base without it doubled up into a
		# brighter band that read as a selection.
		if wavehi_texture != null and wavehi_span.y > wavehi_span.x:
			var hx0 := maxf(tview.x_of(wavehi_span.x), wx0)
			var hx1 := minf(tview.x_of(wavehi_span.y), wx1)
			if hx1 > 0.0 and hx0 < size.x and hx1 > hx0:
				var htw := float(wavehi_texture.get_width())
				var hth := float(wavehi_texture.get_height())
				# Map the clipped pixel range back into the slice's texture.
				var full_x0 := tview.x_of(wavehi_span.x)
				var full_w := maxf(tview.x_of(wavehi_span.y) - full_x0, 1.0)
				var u0 := (hx0 - full_x0) / full_w * htw
				var u1 := (hx1 - full_x0) / full_w * htw
				draw_rect(Rect2(hx0, 4, hx1 - hx0, size.y - 20), Color(0.09, 0.10, 0.13, 1.0))
				draw_texture_rect_region(wavehi_texture, Rect2(hx0, 4, hx1 - hx0, size.y - 20),
					Rect2(u0, 0, u1 - u0, hth), Color(0.55, 0.68, 0.85, 0.85))
