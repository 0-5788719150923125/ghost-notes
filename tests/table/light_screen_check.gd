extends SceneTree

## WHAT THE SUN'S SCREENS DRAW IS WHAT [Lights] RECKONS: the set dresser is told how much of the table
## the sun reaches through a window, leaves, a lattice, an awning or a parasol from the CPU's own
## reckoning ([method Lights.sunlit]), and the shader (shaders/light_screen.gdshader, on the GPU's noise
## in shaders/light_noise.gdshaderinc) is what the viewer sees. Each screen is built by [method
## Lights.build] over a white ground lit by its sun alone, photographed from straight above, and read
## at a grid of points away from the pattern's edges (where the shadow filter blurs it): lit where the CPU
## says lit, dark where it says shaded. Two-sided: the same pictures read against the pattern on another
## salt - another noise - disagree; and a screen moving in time is read at a time that is not 0. A soft
## screen's copy (its shade grown or shrunk) in a gust is read too, both forced on the shader and the
## reckoning alike.
##
##   tests/run_quiet.sh light_screen_check
##
## A real renderer (xvfb), no window on screen.

const W := 960
const H := 720
## The stretch of table photographed (x, z; meters).
const RECT := Rect2(-0.6, -0.5, 1.2, 0.9)

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	var sun := {"look": "sun", "from": "right", "height": 50, "strength": 1.0, "softness": 0.0}
	var cases := [
		["a window", {"name": "w", "kind": "window", "at": [5, -8], "size": [70, 70], "panes": [3, 2], "bars": 4}, 0.0],
		["leaves, stirring", {"name": "l", "kind": "leaves", "cover": 0.5, "size": 10, "sway": 0.5, "soft": 0}, 7.3],
		["fronds", {"name": "f", "kind": "fronds", "cover": 0.5, "size": 8, "sway": 0.3, "soft": 0}, 2.1],
		# a soft copy's shade grown, in a gust: what each of a soft screen's suns casts, stirred harder
		["leaves, grown, in a gust", {"name": "l", "kind": "leaves", "cover": 0.5, "size": 10, "sway": 0.5, "soft": 0}, 7.3, {"grow": 0.05, "gust": 0.8}],
		["blinds, shrunk, in a gust", {"name": "b", "kind": "blinds", "size": [200, 200], "slats": 14, "open": 0.5, "turn": 20, "sway": 0.4}, 3.0, {"grow": -0.15, "gust": 1.0}],
		["a lattice of stars", {"name": "x", "kind": "lattice", "size": [200, 200], "pattern": "stars", "cell": 12, "bars": 2}, 0.0],
		["a lattice of hexes", {"name": "x", "kind": "lattice", "size": [200, 200], "pattern": "hexes", "cell": 16, "bars": 4}, 0.0],
		["blinds", {"name": "b", "kind": "blinds", "size": [200, 200], "slats": 14, "open": 0.5, "turn": 20, "sway": 0.4}, 3.0],
		["a scalloped awning", {"name": "a", "kind": "awning", "cover": 0.5, "edge": "scalloped", "sway": 0.6}, 4.0],
		["a parasol", {"name": "p", "kind": "parasol", "at": [-10, -10], "size": 110, "ribs": 8}, 0.0],
	]
	for c in cases:
		await _case(String(c[0]), sun, c[1] as Dictionary, float(c[2]), c[3] if (c as Array).size() > 3 else {})
	print("light_screen_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _case(what: String, sun: Dictionary, screen: Dictionary, t: float, force: Dictionary = {}) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = RECT.size.y
	cam.near = 0.1
	cam.far = 10.0
	cam.environment = env
	world.add_child(cam)
	cam.transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3(0.0, 0.0, -1.0)), Vector3(RECT.get_center().x, 3.0, RECT.get_center().y))
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6.0, 6.0)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color.WHITE
	gm.roughness = 1.0
	gm.metallic_specular = 0.0
	ground.material_override = gm
	world.add_child(ground)
	var light := Lights.sanitize({"sky": {"strength": 0.0}, "sun": sun, "through": [screen]})
	var bounds := AABB(Vector3(-0.95, -0.05, -0.45), Vector3(1.9, 0.3, 0.9))
	var seen := PackedVector3Array()
	for gy in 18:
		for gx in 24:
			seen.append(Vector3(RECT.position.x + (gx + 0.5) * RECT.size.x / 24.0, 0.0, RECT.position.y + (gy + 0.5) * RECT.size.y / 18.0))
	var rig := Lights.build(light, {"middle": Vector3(0.0, 0.0, -0.02), "bounds": bounds, "seen": seen, "env": env,
		"room": null, "in_shot": Callable()}, 21)
	world.add_child(rig.root)
	rig.fit(0.3)
	rig.tick(t)
	# FORCED on the shader and on the reckoning alike
	for sc in rig.screens:
		for k in force:
			((sc as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter(String(k), force[k])
	for g in rig.geom:
		((g as Dictionary)["u"] as Dictionary).merge(force, true)
	rig.sun.shadow_blur = 0.5
	rig.sun.directional_shadow_max_distance = 6.0
	rig.sun.light_energy = 1.0
	env.ambient_light_energy = 0.0
	rig.top.visible = false
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var s := rig.sun_vec
	var geom: Array = rig.geom
	# the same screen on another salt: another noise (or, for geometry, a pattern moved off its place)
	var other := []
	for g in geom:
		var o := (g as Dictionary).duplicate(true)
		(o["u"] as Dictionary)["salt"] = int((o["u"] as Dictionary)["salt"]) ^ 0x5bd1e995
		(o["u"] as Dictionary)["edge"] = float((o["u"] as Dictionary)["edge"]) + 0.15
		o["origin"] = (o["origin"] as Vector3) + Vector3(0.07, 0.0, 0.05)
		other.append(o)
	var agree := 0
	var against_other := 0
	var n := 0
	var lit_n := 0
	var bright := 0.0
	for gy in 60:
		for gx in 80:
			var p := Vector3(RECT.position.x + (gx + 0.5) * RECT.size.x / 80.0, 0.0, RECT.position.y + (gy + 0.5) * RECT.size.y / 60.0)
			var cpu := Lights.sunlit(geom, s, p, t)
			# away from the pattern's edges: the same answer a centimeter round it
			var clean := true
			for d in [Vector3(0.012, 0, 0), Vector3(-0.012, 0, 0), Vector3(0, 0, 0.012), Vector3(0, 0, -0.012)]:
				clean = clean and Lights.sunlit(geom, s, p + d, t) == cpu
			if not clean:
				continue
			var px := Vector2i(int((p.x - RECT.position.x) / RECT.size.x * W), int((p.z - RECT.position.y) / RECT.size.y * H))
			var lum := img.get_pixelv(px.clamp(Vector2i.ZERO, Vector2i(W - 1, H - 1))).get_luminance()
			bright = maxf(bright, lum)
			var gpu := lum > 0.25
			n += 1
			lit_n += 1 if cpu else 0
			agree += 1 if gpu == cpu else 0
			against_other += 1 if gpu == Lights.sunlit(other, s, p, t) else 0
	var share := float(agree) / float(maxi(n, 1))
	var share_other := float(against_other) / float(maxi(n, 1))
	_ok(bright > 0.5 and n > 1000 and lit_n > n / 20 and lit_n < n * 19 / 20,
		"%s: the instrument - %d clean points, %d lit, the brightest %.2f" % [what, n, lit_n, bright])
	_ok(share > 0.97, "%s: the shader and the reckoning agree at %.1f%% of the points" % [what, share * 100.0])
	_ok(share_other < share - 0.05, "%s: control - against another noise and place they agree at %.1f%%" % [what, share_other * 100.0])
	rig.release()
	vp.queue_free()
	await RenderingServer.frame_post_draw
