extends SceneTree

## splat_head_probe - NOT a gate: an avatar drawn by [SplatHead] held to the trainer's own drawing of the same
## pose (hosts/avatar/look.py writes it), frame by frame.
##
##   xvfb-run -a godot --path . --script tests/likeness/splat_head_probe.gd -- \
##       --avatar <dist/.../avatar> --look <look.py's folder> --out <folder>
##
## For each `<k>_pose.json` in the look folder it draws `<k>_room.png` and over it the face and body posed so,
## at the crop's own size, writes `<k>_godot.png`, and
## prints how far it is from `<k>_played.png` - over the whole square and where the head is (where the
## trainer's picture is not its room). They differ by more than rounding: Godot draws the splats in one
## order (back to front as the neutral face stands), the trainer sorts them per pixel as each pose stands.
##
## NOT `--headless`: the frames are rendered and read back.


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var avatar := ""
	var look := ""
	var out := ""
	for i in args.size() - 1:
		match args[i]:
			"--avatar": avatar = args[i + 1]
			"--look": look = args[i + 1]
			"--out": out = args[i + 1]
	if avatar.is_empty() or look.is_empty() or out.is_empty():
		print("splat_head_probe: give --avatar, --look and --out")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var n := 0
	while FileAccess.file_exists(look.path_join("%d_pose.json" % n)):
		var pose: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(look.path_join("%d_pose.json" % n)))
		var room := Image.load_from_file(look.path_join("%d_room.png" % n))
		var played := Image.load_from_file(look.path_join("%d_played.png" % n))
		var crop: Array = pose["crop"]
		var vp := SubViewport.new()
		vp.size = Vector2i(int(crop[2]), int(crop[3]))
		vp.disable_3d = true
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var bg := Sprite2D.new()
		bg.centered = false
		bg.texture = ImageTexture.create_from_image(room)
		vp.add_child(bg)
		var head := SplatHead.new()
		var t0 := Time.get_ticks_msec()
		var err := head.load_avatar(avatar)
		if not err.is_empty():
			print("splat_head_probe: " + err)
			quit(1)
			return
		var loaded := Time.get_ticks_msec() - t0
		head.position = Vector2.ZERO
		var r: Array = pose["rot"]
		var rot := Basis(Vector3(r[0][0], r[1][0], r[2][0]), Vector3(r[0][1], r[1][1], r[2][1]),
			Vector3(r[0][2], r[1][2], r[2][2]))
		var s: Array = pose["shift"]
		t0 = Time.get_ticks_usec()
		head.pose_face(head.face_of(PackedFloat32Array(pose["blend"])), float(pose["scale"]), rot, Vector3(s[0], s[1], s[2]))
		var at := PackedVector3Array()
		var axes: Array = []
		var units := PackedFloat32Array()
		var shown := PackedByteArray()
		var still: Array = []
		for bd in pose.get("bones", []):
			var o: Array = bd["origin"]
			var ax: Array = bd["axes"]
			at.append(Vector3(o[0], o[1], o[2]))
			axes.append(Basis(Vector3(ax[0][0], ax[0][1], ax[0][2]), Vector3(ax[1][0], ax[1][1], ax[1][2]),
				Vector3(ax[2][0], ax[2][1], ax[2][2])))
			units.append(float(bd["unit"]))
			shown.append(1 if float(bd["seen"]) >= 0.3 else 0)
			still.append(Transform2D.IDENTITY)
		head.pose_bones(at, axes, units, still, shown)
		head.upload()
		head.set_expr(head.expr_of(PackedFloat32Array(pose["blend"])))
		var posed := Time.get_ticks_usec() - t0
		vp.add_child(head)
		root.add_child(vp)
		for i in 4:
			await process_frame
		var got := vp.get_texture().get_image()
		got.convert(Image.FORMAT_RGB8)
		got.save_png(out.path_join("%d_godot.png" % n))
		print("%d: %d splats, loaded in %d ms, posed in %.1f ms; against the trainer's: %s" % [n, head.splats,
			loaded, posed / 1000.0, _compare(got, played, room)])
		vp.queue_free()
		await process_frame
		n += 1
	print("splat_head_probe: %d poses drawn" % n)
	quit(0)


## PSNR over the whole square and over the head (where the trainer's picture differs from its room by more
## than 4/255 in any channel), and the mean absolute difference there in 1/255s.
static func _compare(a: Image, b: Image, room: Image) -> String:
	b.convert(Image.FORMAT_RGB8)
	room.convert(Image.FORMAT_RGB8)
	var w := a.get_width()
	var h := a.get_height()
	var se_all := 0.0
	var se_head := 0.0
	var ad_head := 0.0
	var n_head := 0
	for y in h:
		for x in w:
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var cr := room.get_pixel(x, y)
			var d := Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b)
			se_all += d.length_squared() / 3.0
			if absf(cb.r - cr.r) > 4.0 / 255.0 or absf(cb.g - cr.g) > 4.0 / 255.0 or absf(cb.b - cr.b) > 4.0 / 255.0:
				se_head += d.length_squared() / 3.0
				ad_head += (absf(d.x) + absf(d.y) + absf(d.z)) / 3.0
				n_head += 1
	var psnr_all := -10.0 * log(maxf(se_all / (w * h), 1e-10)) / log(10.0)
	var psnr_head := -10.0 * log(maxf(se_head / maxi(n_head, 1), 1e-10)) / log(10.0)
	return "PSNR %.1f dB whole, %.1f dB on the head (%d px), mean difference there %.1f/255" % [psnr_all,
		psnr_head, n_head, ad_head / maxi(n_head, 1) * 255.0]
