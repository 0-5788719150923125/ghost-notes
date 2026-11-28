extends Node
class_name StudioScreen

## StudioScreen - the camera's flip screen (next/studio.md, "The flip screen"): what the camera sees, shown on the screen it holds
## turned toward the viewer. A second camera at the lens renders the studio's own world, its own things left out (it never sees
## itself, [constant StudioSet.CAMERA_LAYER]); the picture is mirrored, as a selfie screen shows it; over it, unmirrored, a
## recording camera's own marks: REC blinking, the take's running timecode (raw footage: it never stops), and the two audio
## meters, fed what the microphone receives left and right ([method set_levels]: the voice at the capsule and the hands' sounds,
## nothing laid on after) - the side of the microphone a sound is on, seen.
##
## Built by [method mount] under the medium; its picture is [method texture], put on the camera's `screen` face.

## The picture's size (px), the lens it sees through (vertical degrees), and how far before the glass it stands (m).
const SIZE := Vector2i(720, 480)
const FOV := 48.0
const AHEAD := 0.006
## The timecode's frames a second; the meters' floor (dBFS, [LevelMeter]'s) and how wide they are (a share of the picture), centered.
const FPS := 30.0
const FLOOR := LevelMeter.FLOOR
const METER_W := 0.5

var _see: SubViewport          # what the lens sees
var _show: SubViewport         # ...mirrored, with the marks over it: the screen's picture
var _cam: Camera3D
var _marks: Marks


## Built under [param host], seeing [param world] from [param at] (the lens, facing its +z) in [param env]'s light.
func mount(host: Node, world: World3D, at: Transform3D, env: Environment) -> void:
	_see = SubViewport.new()
	_see.size = SIZE
	_see.world_3d = world
	_see.msaa_3d = Viewport.MSAA_2X
	_see.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(_see)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.near = 0.01
	_cam.far = 30.0
	_cam.environment = env
	_cam.cull_mask = 0xFFFFF & ~(1 << (StudioSet.CAMERA_LAYER - 1))
	_see.add_child(_cam)
	_cam.current = true
	place(at)
	_show = SubViewport.new()
	_show.size = SIZE
	_show.disable_3d = true
	_show.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(_show)
	var pic := TextureRect.new()
	pic.texture = _see.get_texture()
	pic.flip_h = true
	pic.size = Vector2(SIZE)
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	_show.add_child(pic)
	_marks = Marks.new()
	_marks.size = Vector2(SIZE)
	_show.add_child(_marks)


## The lens at [param at] (its +z out through the glass).
func place(at: Transform3D) -> void:
	if _cam == null:
		return
	var fwd := at.basis.z.normalized()
	_cam.global_transform = Transform3D(Basis.looking_at(fwd, at.basis.y.normalized()), at.origin + fwd * AHEAD)


## The screen's picture.
func texture() -> Texture2D:
	return _show.get_texture() if _show != null else null


## The take at [param t] seconds (its timecode, REC blinking).
func set_time(t: float) -> void:
	if _marks != null:
		_marks.t = t
		_marks.queue_redraw()


## The meters: [param left] and [param right] (each ear's peak now, dBFS), [param dt] seconds after the last - falling back, held
## as a [LevelMeter]'s do.
func set_levels(left: float, right: float, dt: float) -> void:
	if _marks != null:
		_marks.reading.feed(left, right, dt)


func release() -> void:
	for v in [_see, _show]:
		if v != null and is_instance_valid(v):
			(v as Node).queue_free()
	_see = null
	_show = null


## A recording camera's marks over the picture.
class Marks extends Control:
	var t := 0.0
	var reading := LevelMeter.Reading.new()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var w := size.x
		var h := size.y
		var fs := int(h * 0.06)
		# REC, blinking once a second
		if fmod(t, 1.0) < 0.62:
			draw_circle(Vector2(w * 0.05, h * 0.075), h * 0.022, Color(0.92, 0.12, 0.1))
		draw_string(font, Vector2(w * 0.08, h * 0.095), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
		var frames := int(floor(t * StudioScreen.FPS))
		var tc := "%02d:%02d:%02d:%02d" % [frames / int(StudioScreen.FPS * 3600.0), (frames / int(StudioScreen.FPS * 60.0)) % 60,
			(frames / int(StudioScreen.FPS)) % 60, frames % int(StudioScreen.FPS)]
		draw_string(font, Vector2(w * 0.62, h * 0.095), tc, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
		draw_string(font, Vector2(w * 0.05, h * 0.95), "4K 30p", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.8), Color(1, 1, 1, 0.75))
		# the battery
		var bx := w * 0.86
		var by := h * 0.9
		draw_rect(Rect2(bx, by, w * 0.08, h * 0.05), Color(1, 1, 1, 0.8), false, 2.0)
		draw_rect(Rect2(bx + w * 0.08, by + h * 0.015, w * 0.008, h * 0.02), Color(1, 1, 1, 0.8))
		draw_rect(Rect2(bx + 3.0, by + 3.0, w * 0.05, h * 0.05 - 6.0), Color(1, 1, 1, 0.75))
		# the two meters, centered, the scale under them ([LevelMeter])
		var x0 := w * (0.5 - StudioScreen.METER_W * 0.5)
		LevelMeter.draw_meter(self, Rect2(x0, h * 0.8, w * StudioScreen.METER_W, h * 0.115), reading, font, int(fs * 0.5), int(fs * 0.7))
