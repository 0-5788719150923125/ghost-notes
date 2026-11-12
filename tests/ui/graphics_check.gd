extends Node

## graphics_check - how finely the stage is drawn ([Graphics]) and the panel that chooses it ([GraphicsPanel]).
##
##   tests/run_boot_probe.sh tests/ui/graphics_check.gd 90
##
## - The live viewer is never slower than it was: every row's live default is what Godot drew before the menu (the
##   project's own SSAO, SSIL, subsurface, shadow and fog qualities, its filtering level, no supersampling), and an
##   export's is the finest each row offers - but supersampling, 1.5x (its cost, measured in graphics.gd's header) -
##   and never coarser than the live one. A shared row (bounce light) is one choice, off.
## - The tier reaches the stage: bound in an export, the stage is supersampled and filtered 16x and the shadow filter is
##   ultra; in the live viewer, none of that. Supersampling is held under its cap: told 2x, a 1080p export's
##   2880 x 1620 takes the whole of it, a 4K stage 1.5x.
## - The viewer's resolution is its own: unchosen, the stage is drawn a pixel to a unit of the window's canvas
##   (1920 x 1080 at any window); chosen, at that many lines, its shape kept; and an export at the size it is
##   handed whatever is chosen. Control: the live viewer, with 4K chosen, is not. Whoever sizes the stage is asked to
##   again when a row is applied, and never while the stage is being bound.
## - A shadow keeps its width as the filter's quality changes: a light on the stage, softened by [ShadowFilter] at one
##   quality, has the same blur times radius at the other. Control: the same light off the stage is not rescaled,
##   and its width changes.
## - What is kept is read, and what no option has is not: a choice written to `[graphics]` is the value; a value no
##   option offers (a hand-edited file) is the default. Bounce light reaches a medium's environment handed to
##   [method Graphics.dress], at a table's reach, and follows the row - handed in on a worker too, as a table is built
##   away: there it is as the main thread last read it, and follows the row after. Control: what the main thread read
##   forgotten, a worker reads the default.
## - The panel: a cell per row and tier, a shared row one control in both, a row only one column has none in the other; a
##   live choice applies at once, an export choice leaves the live stage as it is; "defaults" puts every row back. (A
##   probe's Settings never reach the disk; what it writes is put back in memory at the end.)

var _fails: Array = []
var _refits := 0                 # how often the stage's owner was asked to size it again


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var keep := _kept()
	_defaults()
	await _tiers()
	_shadows()
	_kept_values()
	_bounce()
	_resolution()
	await _panel()
	_restore(keep)
	Graphics.tier_override = ""
	Graphics.overrides = {}
	if _fails.is_empty():
		print("graphics_check: ALL OK")
		get_tree().quit(0)
		return
	print("graphics_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _defaults() -> void:
	print("-- defaults")
	var ps := func(name: String) -> Variant: return ProjectSettings.get_setting("rendering/" + name)
	var was := {
		"occlusion": ps.call("environment/ssao/quality"),
		"subsurface": ps.call("environment/subsurface_scattering/subsurface_scattering_quality"),
		"shadows": ps.call("lights_and_shadows/positional_shadow/soft_shadow_filter_quality"),
		"fog": ps.call("environment/volumetric_fog/volume_size"),
		"anisotropy": ps.call("textures/default_filters/anisotropic_filtering_level"),
		"supersample": 1.0,
	}
	_ok(int(ps.call("environment/ssil/quality")) == int(was["occlusion"]),
		"the project's SSIL quality is its SSAO's, so one row holds both")
	for key in Graphics.SETTINGS:
		var row: Dictionary = Graphics.SETTINGS[key]
		var values := Graphics.values_of(key)
		_ok(not String(row.get("label", "")).is_empty() and not String(row.get("blurb", "")).is_empty() and values.size() >= 2,
			"'%s' has a label, a blurb and choices" % key)
		if bool(row.get("shared", false)):
			_ok(values.has(row["default"]) and row["default"] == false, "'%s' is shared and off" % key)
			continue
		if not String(row.get("only", "")).is_empty():
			var t := String(row["only"])
			_ok(Graphics.TIERS.has(t) and values.has(row.get(t)) and not String(row.get("other", "")).is_empty(),
				"'%s' is the %s column's alone: its default among its choices, the other cell worded" % [key, t])
			_ok(key == "resolution" and row["live"] == Graphics.LINES_AS_DRAWN,
				"'%s' live default %s is what the stage always drew at" % [key, str(row.get("live"))])
			continue
		_ok(values.has(row["live"]) and values.has(row["export"]), "'%s' defaults are among its choices" % key)
		_ok(was.has(key) and row["live"] == was[key],
			"'%s' live default %s is what Godot drew before (%s)" % [key, str(row["live"]), str(was.get(key))])
		_ok(values.find(row["export"]) >= values.find(row["live"]), "'%s' export default is never coarser than live" % key)
		if key == "supersample":
			_ok(row["export"] == 1.5, "'supersample' export default is 1.5x, for its cost")
		else:
			_ok(row["export"] == values.back(), "'%s' export default is its finest (%s)" % [key, str(row["export"])])


func _tiers() -> void:
	print("-- the tier reaches the stage")
	var st := SubViewport.new()
	st.size = Vector2i(2880, 1620)
	add_child(st)
	Graphics.tier_override = "export"
	Graphics.bind_stage(st)
	_ok(is_equal_approx(st.scaling_3d_scale, 1.5) and st.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR,
		"an export supersamples a 1080p render's stage 1.5x (%.2f)" % st.scaling_3d_scale)
	_ok(st.anisotropic_filtering_level == Viewport.ANISOTROPY_16X, "an export filters 16x (%d)" % st.anisotropic_filtering_level)
	_ok(int(ProjectSettings.get_setting(ShadowFilter.QUALITY_SETTING)) == 5, "an export's shadow filter is ultra")
	Graphics.overrides = {"supersample": 2.0}
	Graphics.apply()
	_ok(is_equal_approx(st.scaling_3d_scale, 2.0), "told 2x, a 1080p render's stage takes the whole of it")
	st.size = Vector2i(3840, 2160)
	await _frames(1)
	_ok(is_equal_approx(st.scaling_3d_scale, 1.5), "a 4K stage, resized, is held to 1.5x under the cap (%.2f)" % st.scaling_3d_scale)
	Graphics.overrides = {}
	_ok(is_equal_approx(Graphics.supersample_for(Vector2i(640, 360), 1.0), 1.0)
		and is_equal_approx(Graphics.supersample_for(Vector2i(8000, 8000), 2.0), 1.0),
		"supersampling is never under 1 (off stays off; past the cap it is off)")
	Graphics.tier_override = "live"
	Graphics.apply()
	_ok(is_equal_approx(st.scaling_3d_scale, 1.0) and st.anisotropic_filtering_level == Viewport.ANISOTROPY_4X
		and int(ProjectSettings.get_setting(ShadowFilter.QUALITY_SETTING)) == 4,
		"the live viewer draws as it did: no supersampling, 4x filtering, high shadows")
	Graphics.tier_override = ""
	_ok(Graphics.tier() == "live", "a process without --export is the live viewer")


func _shadows() -> void:
	print("-- a shadow keeps its width")
	var st := Graphics.stage()
	var on := OmniLight3D.new()
	on.shadow_enabled = true
	st.add_child(on)
	var off := OmniLight3D.new()
	off.shadow_enabled = true
	add_child(off)
	Graphics.tier_override = "live"
	Graphics.apply()
	ShadowFilter.filter(on, 3.0)
	ShadowFilter.filter(off, 3.0)
	var r4 := ShadowFilter.quality_radius()
	var width_on := on.shadow_blur * r4
	var width_off := off.shadow_blur * r4
	Graphics.tier_override = "export"
	Graphics.apply()
	var r5 := ShadowFilter.quality_radius()
	_ok(r5 > r4, "the export's quality spreads a blur wider (%.1f > %.1f)" % [r5, r4])
	_ok(is_equal_approx(on.shadow_blur * r5, width_on), "a light on the stage keeps its width (%.3f, %.3f)" % [on.shadow_blur * r5, width_on])
	_ok(not is_equal_approx(off.shadow_blur * r5, width_off), "CONTROL: one off the stage, not rescaled, does not")
	Graphics.tier_override = "live"
	Graphics.apply()
	_ok(is_equal_approx(on.shadow_blur * r4, width_on), "and back at the live quality, it is as it was")
	on.queue_free()
	off.queue_free()
	Graphics.tier_override = ""


func _kept_values() -> void:
	print("-- what is kept is read")
	Settings.write(Graphics.SECTION, "live_anisotropy", 3)
	_ok(Graphics.value("anisotropy", "live") == 3, "a kept choice is the value")
	Settings.write(Graphics.SECTION, "live_anisotropy", 7)
	_ok(Graphics.value("anisotropy", "live") == Graphics.default_of("anisotropy", "live"),
		"CONTROL: a value no option offers is the default")
	Settings.write(Graphics.SECTION, "live_anisotropy", Graphics.default_of("anisotropy", "live"))
	Graphics.overrides = {"supersample": 1.5}
	_ok(Graphics.value("supersample", "live") == 1.5, "a probe's override is laid over the setting")
	Graphics.overrides = {}
	_ok(Graphics.key_of("bounce", "export") == "bounce" and Graphics.key_of("fog", "export") == "export_fog",
		"a shared row is kept once, a column's row under its tier")


func _bounce() -> void:
	print("-- bounce light reaches a medium")
	# From the default, whatever the author chose: set here in memory, as a probe's Settings never reach the disk, and theirs put back at the end
	var authors: Variant = Settings.read(Graphics.SECTION, "bounce", false)
	Settings.write(Graphics.SECTION, "bounce", false)
	Graphics.apply()
	var env := Environment.new()
	Graphics.dress(env)
	_ok(not env.ssil_enabled and is_equal_approx(env.ssil_radius, Graphics.BOUNCE_REACH),
		"handed in, it is off and at a table's reach (%.2f m)" % env.ssil_radius)
	Settings.write(Graphics.SECTION, "bounce", true)
	Graphics.apply()
	_ok(env.ssil_enabled, "chosen, it is on in the environment handed in")
	Settings.write(Graphics.SECTION, "bounce", false)
	Graphics.apply()
	_ok(not env.ssil_enabled, "and off again")
	# ...handed in on a worker, as a table is built away: as the main thread last read it, never asking the tree
	Settings.write(Graphics.SECTION, "bounce", true)
	Graphics.apply()
	var away := Environment.new()
	var worker := Thread.new()
	worker.start(func() -> bool:
		Graphics.dress(away)
		return bool(Graphics.value("bounce")))
	var read_away: bool = worker.wait_to_finish()
	_ok(read_away and away.ssil_enabled, "handed in on a worker, it is %s where it is chosen on" % ("on" if away.ssil_enabled else "off"))
	Settings.write(Graphics.SECTION, "bounce", false)
	Graphics.apply()
	_ok(not away.ssil_enabled, "and follows the row after, off again")
	# The control: what the main thread read forgotten, a worker reads the default (off)
	Settings.write(Graphics.SECTION, "bounce", true)
	Graphics._lock.lock()
	Graphics._read.clear()
	Graphics._lock.unlock()
	var forgot := Thread.new()
	forgot.start(func() -> bool: return bool(Graphics.value("bounce")))
	_ok(not bool(forgot.wait_to_finish()), "CONTROL: with nothing read on the main thread, a worker reads bounce light on")
	Settings.write(Graphics.SECTION, "bounce", authors)
	Graphics.apply()


func _resolution() -> void:
	print("-- the viewer's resolution")
	var authors: Variant = Settings.read(Graphics.SECTION, "live_resolution", Graphics.LINES_AS_DRAWN)
	Graphics.tier_override = "live"
	var frame := Vector2(1920, 1080)
	Settings.write(Graphics.SECTION, "live_resolution", Graphics.LINES_AS_DRAWN)
	_ok(Graphics.stage_size(frame) == Vector2i(1920, 1080) and Graphics.stage_size(Vector2(1344, 756)) == Vector2i(1344, 756),
		"unchosen, the stage is a pixel to a unit of the window's canvas, as it always was")
	var sizes := {720: Vector2i(1280, 720), 1440: Vector2i(2560, 1440), 2160: Vector2i(3840, 2160)}
	for lines in sizes:
		Settings.write(Graphics.SECTION, "live_resolution", lines)
		_ok(Graphics.stage_size(frame) == sizes[lines], "at %d lines a whole frame is %s (%s)" % [lines, str(sizes[lines]), str(Graphics.stage_size(frame))])
	_ok(Graphics.stage_size(Vector2(608, 1080)) == Vector2i(1216, 2160) and Graphics.stage_size(Vector2(0.2, 0.2)) == Vector2i(1, 1),
		"a portrait frame keeps its shape, and no frame is less than a pixel")
	Graphics.tier_override = "export"
	_ok(Graphics.stage_size(Vector2(2880, 1620)) == Vector2i(2880, 1620) and Graphics.value("resolution") == null
		and not Graphics.has_tier("resolution", "export") and Graphics.default_of("resolution", "export") == null,
		"an export is drawn at the size it is handed, whatever the viewer chose")
	Graphics.tier_override = "live"
	_ok(Graphics.stage_size(Vector2(2880, 1620)) == Vector2i(5760, 3240), "CONTROL: the live viewer, with 4K chosen, is not")
	Settings.write(Graphics.SECTION, "live_resolution", 999)
	_ok(Graphics.stage_size(frame) == Vector2i(1920, 1080), "a kept value no option offers is 1080p")
	# Whoever sizes the stage is asked again when a row is applied - and not while it is bound, before what shows it is built
	Settings.write(Graphics.SECTION, "live_resolution", Graphics.LINES_AS_DRAWN)
	_refits = 0
	Graphics.bind_stage(Graphics.stage(), func() -> void: _refits += 1)
	_ok(_refits == 0, "binding the stage does not ask for it to be sized")
	Graphics.apply()
	_ok(_refits == 1, "a row applied does")
	Settings.write(Graphics.SECTION, "live_resolution", authors)
	Graphics.tier_override = ""


func _panel() -> void:
	print("-- the panel")
	var p := GraphicsPanel.new()
	add_child(p)
	await _frames(2)
	var all := true
	for key in Graphics.SETTINGS:
		for t in Graphics.TIERS:
			var o := p.choice(key, t)
			if Graphics.has_tier(key, t):
				all = all and o != null and o.item_count == Graphics.values_of(key).size()
			else:
				all = all and o == null
	_ok(all, "a cell per row and tier, each with the row's choices - and none where a row is one column's alone")
	var res := p.choice("resolution", "live")
	_refits = 0
	res.select(0)
	res.item_selected.emit(0)
	_ok(Settings.read(Graphics.SECTION, "live_resolution", -1) == 720 and _refits == 1 and Graphics.stage_size(Vector2(1920, 1080)) == Vector2i(1280, 720),
		"a resolution chosen is kept, and the stage's owner is asked to size it again (%d)" % _refits)
	_ok(p.choice("bounce", "live") == p.choice("bounce", "export"), "a shared row is one control in both columns")
	var st := Graphics.stage()
	var ex := p.choice("supersample", "export")
	ex.select(0)
	ex.item_selected.emit(0)
	_ok(Settings.read(Graphics.SECTION, "export_supersample", -1.0) == 1.0 and is_equal_approx(st.scaling_3d_scale, 1.0),
		"an export choice is kept and leaves the live stage as it is")
	var lv := p.choice("supersample", "live")
	lv.select(2)
	lv.item_selected.emit(2)
	_ok(Settings.read(Graphics.SECTION, "live_supersample", -1.0) == 2.0
		and is_equal_approx(st.scaling_3d_scale, Graphics.supersample_for(st.size, 2.0)) and st.scaling_3d_scale > 1.0,
		"a live choice is kept and applied at once (%.2f on a %dx%d stage)" % [st.scaling_3d_scale, st.size.x, st.size.y])
	p.reset_all()
	_ok(Settings.read(Graphics.SECTION, "live_supersample", -1.0) == 1.0 and Settings.read(Graphics.SECTION, "export_supersample", -1.0) == 1.5
		and is_equal_approx(st.scaling_3d_scale, 1.0) and p.choice("supersample", "export").selected == 1
		and Settings.read(Graphics.SECTION, "live_resolution", -1) == Graphics.LINES_AS_DRAWN and res.selected == 1,
		"defaults puts every row back, kept, shown and applied")
	# Who asks for the stage's time: measured while anyone does, the panel closing never ending the governor's asking
	Graphics.measure(true, "governor")
	Graphics.measure(false)
	_ok(Graphics._measuring.has("governor") and not Graphics._measuring.has("panel"), "the panel's asking ends its own, never another's")
	Graphics.measure(false, "governor")
	_ok(Graphics._measuring.is_empty(), "and with nobody asking, nothing is measured")
	p.visible = false
	await _frames(1)
	p.visible = true
	await _frames(1)
	_ok(p.is_processing(), "open, it reads what the stage costs")
	p.visible = false
	await _frames(1)
	_ok(not p.is_processing(), "closed, it stops")
	p.queue_free()


func _kept() -> Dictionary:
	var out := {}
	if Settings._cfg.has_section(Graphics.SECTION):
		for k in Settings._cfg.get_section_keys(Graphics.SECTION):
			out[k] = Settings._cfg.get_value(Graphics.SECTION, k)
	return out


## The section as it was, in memory (a probe never writes the file).
func _restore(keep: Dictionary) -> void:
	if Settings._cfg.has_section(Graphics.SECTION):
		Settings._cfg.erase_section(Graphics.SECTION)
	for k in keep:
		Settings._cfg.set_value(Graphics.SECTION, k, keep[k])
