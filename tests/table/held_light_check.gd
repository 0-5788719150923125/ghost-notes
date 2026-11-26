extends SceneTree

## held_light_check - the light from behind the lens on a card held up to it ([method TableLight.held_fill], [method
## TableLight.light_on], [method TableLight.fill_for], `fill` in [constant TableMedium.FOIL_SHADER]), with no renderer.
##
##   godot --headless --path . --script res://tests/table/held_light_check.gd
##
## - The light on a face: a sun as squarely as the face meets it and none from behind it; a candle falling off with its distance
##   and nothing past its range; a lamp's cone bright on its axis and dark outside it; the ambient on any face; a negative light
##   takes away. Each read off a real light node ([method TableLight.light_of]) as the renderer draws it.
## - The fill: a held face with the table's light behind it is given what it lacks of the share a lying card has; one lit from the
##   front as well as a lying card is given nothing (the control); never more than that share.
## - The shader lays it on from behind the lens, diffuse alone: an instance uniform on emission, with no specular of its own.

var _fails := 0


func _init() -> void:
	_light_on()
	_fill()
	_shader()
	print("held_light_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


## A light node posed at [param at], looking at [param look].
func _posed(l: Light3D, at: Vector3, look: Vector3) -> Dictionary:
	var xf := Transform3D(Basis.IDENTITY, at)
	if not at.is_equal_approx(look):
		xf = xf.looking_at(look, Vector3.UP if absf((look - at).normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD)
	var d := TableLight.light_of(l, xf)
	l.free()
	return d


func _light_on() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.0
	var high := _posed(sun, Vector3(0, 1, 0), Vector3.ZERO)
	var on_top := TableLight.light_on(Vector3.ZERO, Vector3.UP, [high], 0.0)
	_ok(is_equal_approx(on_top, 2.0), "a sun overhead lights a face turned up by its energy (%s)" % on_top)
	_ok(is_zero_approx(TableLight.light_on(Vector3.ZERO, Vector3.DOWN, [high], 0.0)), "and none turned away from it")
	_ok(is_equal_approx(TableLight.light_on(Vector3.ZERO, Vector3(1, 1, 0).normalized(), [high], 0.0), 2.0 * cos(PI / 4.0)),
		"as squarely as the face meets it")
	var omni := OmniLight3D.new()
	omni.light_energy = 1.0
	omni.omni_range = 2.0
	omni.omni_attenuation = 1.0
	var candle := _posed(omni, Vector3(0, 0.5, 0), Vector3(0, 0.5, 0))
	var near := TableLight.light_on(Vector3.ZERO, Vector3.UP, [candle], 0.0)
	var farther := TableLight.light_on(Vector3(0, -0.5, 0), Vector3.UP, [candle], 0.0)
	_ok(near > farther and farther > 0.0, "a candle falls off with its distance (%s, then %s)" % [near, farther])
	_ok(is_zero_approx(TableLight.light_on(Vector3(0, -2.0, 0), Vector3.UP, [candle], 0.0)), "and lights nothing past its range")
	var spot := SpotLight3D.new()
	spot.light_energy = 1.0
	spot.spot_range = 3.0
	spot.spot_angle = 20.0
	var lamp := _posed(spot, Vector3(0, 1, 0), Vector3.ZERO)
	var axis := TableLight.light_on(Vector3.ZERO, Vector3.UP, [lamp], 0.0)
	var outside := TableLight.light_on(Vector3(1.0, 0, 0), Vector3.UP, [lamp], 0.0)
	_ok(axis > 0.5 and is_zero_approx(outside), "a lamp's cone is bright on its axis (%s) and dark outside it (%s)" % [axis, outside])
	_ok(is_equal_approx(TableLight.light_on(Vector3.ZERO, Vector3.RIGHT, [], 0.3), 0.3), "the ambient lights any face")
	var dark := OmniLight3D.new()
	dark.light_negative = true
	dark.omni_range = 2.0
	_ok(TableLight.light_on(Vector3.ZERO, Vector3.UP, [_posed(dark, Vector3(0, 0.5, 0), Vector3(0, 0.5, 0))], 0.0) < 0.0, "a negative light takes away")


func _fill() -> void:
	# a candle at the back of the table: a lying card under it is lit, a card held up with its face to the lens is not
	var omni := OmniLight3D.new()
	omni.light_energy = 1.5
	omni.omni_range = 1.5
	var candle := _posed(omni, Vector3(0, 0.15, -0.3), Vector3(0, 0.15, -0.3))
	var lying := TableLight.light_on(Vector3.ZERO, Vector3.UP, [candle], 0.05)
	var held_at := Vector3(0, 0.3, 0.3)
	var toward_lens := Vector3(0, 0.2, 1).normalized()
	var face := TableLight.light_on(held_at, toward_lens, [candle], 0.05)
	var f := TableLight.fill_for(face, lying)
	_ok(face < lying * 0.3, "the control's ground: a held face with the candle behind it is in the dark (%s of %s)" % [face, lying])
	_ok(is_equal_approx(f, TableLight.FILL_SHARE * lying - face), "it is given what it lacks of the share a lying card has (%s)" % f)
	# a lamp behind the camera lights the held face from the front
	var front := OmniLight3D.new()
	front.light_energy = 1.5
	front.omni_range = 2.0
	var from_lens := _posed(front, Vector3(0, 0.4, 0.7), Vector3(0, 0.4, 0.7))
	var lit_face := TableLight.light_on(held_at, toward_lens, [candle, from_lens], 0.05)
	var lit_lying := TableLight.light_on(Vector3.ZERO, Vector3.UP, [candle, from_lens], 0.05)
	_ok(lit_face >= TableLight.FILL_SHARE * lit_lying and is_zero_approx(TableLight.fill_for(lit_face, lit_lying)),
		"the control: a held face lit from the front is given nothing (%s of %s)" % [lit_face, lit_lying])
	_ok(is_equal_approx(TableLight.fill_for(0.0, 2.0), TableLight.FILL_SHARE * 2.0) and is_zero_approx(TableLight.fill_for(-1.0, 0.0)),
		"never more than the share, never below none")


func _shader() -> void:
	var src := TableMedium.FOIL_SHADER
	_ok(src.contains("instance uniform float fill"), "the fill is an instance uniform, one card's alone")
	var emission := ""
	for line in src.split("\n"):
		if line.strip_edges().begins_with("EMISSION"):
			emission = line
	_ok(emission.contains("fill * facing"), "it is laid on as light the face gives off, as squarely as it faces behind the lens")
	_ok(not src.contains("SPECULAR = fill") and not src.contains("ROUGHNESS = fill"), "and no gloss of its own")
